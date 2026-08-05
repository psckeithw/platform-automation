Set-StrictMode -Version Latest

<#
.SYNOPSIS
    Azure DevOps work item creation seam for the VendorMonitor notify path.

.DESCRIPTION
    Owns two things:
      * Get-DotEnvValue   - resolves a key from real env vars first, then
                            falls back to a .env file (for local dev).
      * New-RLDatixAlertWorkItem
                          - formats a normalized vendor record into an
                            Azure DevOps User Story (title, description,
                            tags, source provenance table, action
                            checklist) and POSTs it via the JSON-patch
                            REST API. Returns a hashtable with Success,
                            Id, Url, Title, Error.

    The module is intentionally small and has no knowledge of the rest
    of the framework beyond the normalized record shape:
        Vendor, Product, Id, Title, PublishedDate, SourceUrl, RawBody
#>

function Get-DotEnvValue {
    <#
    .SYNOPSIS
        Read a value from env, with a .env file fallback for local dev.
    .DESCRIPTION
        The Azure DevOps pipeline sets ADO_PAT / AZURE_DEVOPS_ORG /
        AZURE_DEVOPS_PROJECTS as real environment variables. For local
        developer runs, those values live in .env (KEY=VALUE per line).
        This helper checks env first so the pipeline never accidentally
        reads the committed .env, then falls back to the file.
    .PARAMETER Name
        Variable name to resolve.
    .PARAMETER EnvPath
        Path to the .env file. Defaults to '.env' (cwd).
    .OUTPUTS
        The value as a string, or $null if not found.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [string]$EnvPath = '.env'
    )

    $val = [System.Environment]::GetEnvironmentVariable($Name)
    if (-not [string]::IsNullOrEmpty($val)) { return $val }

    if (Test-Path -LiteralPath $EnvPath -PathType Leaf) {
        $pattern = '^\s*' + [regex]::Escape($Name) + '\s*='
        $line = Get-Content -LiteralPath $EnvPath -ErrorAction SilentlyContinue |
                Where-Object { $_ -match $pattern } |
                Select-Object -First 1
        if ($line) {
            $parts = $line -split '=', 2
            if ($parts.Count -eq 2) { return $parts[1].Trim() }
        }
    }
    return $null
}

function ConvertTo-HtmlText {
    <#
    .SYNOPSIS
        Strip HTML tags and collapse whitespace.
    .DESCRIPTION
        Used to render a short summary from a normalized record's
        RawBody field for inclusion in the work item description. Not a
        full sanitizer; meant only for short excerpts we control.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Html
    )
    if ([string]::IsNullOrEmpty($Html)) { return '' }
    $t = $Html -replace '<br\s*/?>', "`n"
    $t = $t -replace '</p>', "`n"
    $t = $t -replace '<[^>]+>', ' '
    $t = $t -replace '&nbsp;', ' '
    $t = $t -replace '&', '&amp;'
    $t = $t -replace '<', '&lt;'
    $t = $t -replace '>', '&gt;'
    $t = $t -replace '"', '&quot;'
    $t = $t -replace "'", '&#39;'
    $t = $t -replace '\s+', ' '
    return $t.Trim()
}

function ConvertTo-HtmlEncode {
    <#
    .SYNOPSIS
        Minimal HTML-attribute encoder for safe interpolation into the
        work item description.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Value
    )
    if ($null -eq $Value) { return '' }
    return ([string]$Value) -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;' -replace "'",'&#39;'
}

function New-RLDatixAlertWorkItem {
    <#
    .SYNOPSIS
        Create an Azure DevOps User Story that alerts Heartbeat to a
        new RLDatix intelligentcontract release announcement.
    .DESCRIPTION
        Builds:
          Title      - "[RLDatix intelligentcontract] {Title} ({Date})"
          Tags       - VendorAlert; intelligentcontract; RLDatix;
                       Announcement|ReleaseNote
          Description - HTML with summary, source link, action
                       checklist, and a provenance table so the
                       reviewer can confirm the alert is genuine.
        POSTs to https://dev.azure.com/{org}/{project}/_apis/wit/
        workitems/$User%20Story?api-version=7.1 with
        application/json-patch+json.
    .PARAMETER Item
        Normalized record (must have Vendor, Product, Title,
        PublishedDate, SourceUrl, RawBody).
    .PARAMETER Org
        Azure DevOps organisation name (e.g. 'azuredevopsdfw').
    .PARAMETER Project
        Project name (e.g. 'Heartbeat').
    .PARAMETER Pat
        Personal Access Token with Work Items (read & write) scope.
    .PARAMETER WorkItemType
        Defaults to 'User Story'.
    .PARAMETER Tags
        Additional tags. 'VendorAlert', 'RLDatix', 'intelligentcontract'
        plus an Announcement|ReleaseNote tag derived from $Item.Product
        are always included.
    .PARAMETER AreaPath
        Optional. Forwarded as System.AreaPath.
    .PARAMETER IterationPath
        Optional. Forwarded as System.IterationPath.
    .OUTPUTS
        Hashtable: @{ Success; Id; Url; Title; Error }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)] [object]$Item,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string]$Org,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string]$Project,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string]$Pat,
        [string]$WorkItemType = 'User Story',
        [string[]]$Tags = @(),
        [string]$AreaPath,
        [string]$IterationPath
    )

    $vendor  = [string]$Item.Vendor
    $product = [string]$Item.Product
    $title   = [string]$Item.Title
    $date    = [string]$Item.PublishedDate
    $url     = [string]$Item.SourceUrl
    $rawBody = [string]$Item.RawBody
    $itemId  = if ($null -ne $Item.Id) { [string]$Item.Id } else { '' }

    # Short date for the title.
    $dateShort = $date
    try {
        $parsed = [datetime]::MinValue
        $ok = [datetime]::TryParse(
            $date,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal,
            [ref]$parsed)
        if ($ok) { $dateShort = $parsed.ToString('yyyy-MM-dd') }
    } catch { }

    # Short summary (text excerpt).
    $summary = ConvertTo-HtmlText -Html $rawBody
    if ($summary.Length -gt 480) { $summary = $summary.Substring(0, 477) + '...' }

    # Decide Announcement vs ReleaseNote tag from product/section.
    $kind = 'Announcement'
    if ($product -match '(?i)release' -or $product -match '(?i)notes') { $kind = 'ReleaseNote' }

    $wiTitle = "[$vendor $product] $title ($dateShort)"

    $encTitle    = ConvertTo-HtmlEncode $title
    $encVendor   = ConvertTo-HtmlEncode $vendor
    $encProduct  = ConvertTo-HtmlEncode $product
    $encUrl      = ConvertTo-HtmlEncode $url
    $encSummary  = ConvertTo-HtmlEncode $summary
    $encItemId   = ConvertTo-HtmlEncode $itemId
    $encDate     = ConvertTo-HtmlEncode $date

    $desc = @"
<h2>New RLDatix intelligentcontract release announcement detected</h2>
<p><strong>Vendor</strong> $encVendor &nbsp;|&nbsp; <strong>Product</strong> $encProduct &nbsp;|&nbsp; <strong>Published</strong> $encDate &nbsp;|&nbsp; <strong>Kind</strong> $kind</p>
<h3>Summary</h3>
<p>$encSummary</p>
<h3>Action checklist</h3>
<ul>
  <li>Open the source URL and confirm the announcement is genuine</li>
  <li>Assess impact on our AHA environment (security, compatibility, training</li>
  <li>If a production change is required, open a change ticket and link it here</li>
  <li>Update release tracking in Heartbeat</li>
</ul>
<h3>Source provenance</h3>
<table border=1 cellpadding=4 style='border-collapse:collapse'>
<thead><tr><th>Field</th><th>Value</th</tr</thead>
<tbody>
<tr><td>Article ID</td><td>$encItemId</td</tr>
<tr><td>Title</td><td>$encTitle</td</tr>
<tr><td>Published</td><td>$encDate</td</tr>
<tr><td>Source URL</td><td><a href='$encUrl'>$encUrl</a</td</tr>
<tr><td>Detected by</td><td>platform-automation / VendorMonitor</td</tr>
</tbody>
</table>
"@

    $tagList = @('VendorAlert', 'RLDatix', 'intelligentcontract', $kind)
    foreach ($t in $Tags) { if (-not [string]::IsNullOrEmpty($t)) { $tagList += $t } }
    $tagList = $tagList | Where-Object { $_ } | Sort-Object -Unique
    $tagsStr = $tagList -join '; '

    $ops = @(
        @{ op = 'add'; path = '/fields/System.Title';       value = $wiTitle }
        @{ op = 'add'; path = '/fields/System.Description'; value = $desc }
        @{ op = 'add'; path = '/fields/System.Tags';        value = $tagsStr }
    )
    if ($AreaPath)      { $ops += @{ op='add'; path='/fields/System.AreaPath';      value=$AreaPath } }
    if ($IterationPath) { $ops += @{ op='add'; path='/fields/System.IterationPath'; value=$IterationPath } }

    $payload = $ops | ConvertTo-Json -Depth 10
    $encType = [uri]::EscapeDataString($WorkItemType)
    $uri = "https://dev.azure.com/$Org/$Project/_apis/wit/workitems/`$$encType?api-version=7.1"

    $base64 = [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("`:$Pat"))
    $headers = @{
        Authorization = "Basic $base64"
        'Content-Type' = 'application/json-patch+json'
    }

    try {
        $resp = Invoke-RestMethod -Uri $uri -Method Post -Body $payload -Headers $headers -TimeoutSec 30
        return @{
            Success = $true
            Id      = $resp.id
            Url     = $resp._links.html.href
            Title   = $wiTitle
            Error   = $null
        }
    }
    catch {
        $statusCode = 0
        $errBody = ''
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
            try {
                $stream = $_.Exception.Response.GetResponseStream()
                if ($stream) {
                    $reader = New-Object System.IO.StreamReader($stream)
                    $errBody = $reader.ReadToEnd()
                    $reader.Close()
                }
            } catch { }
        }
        return @{
            Success = $false
            Id      = $null
            Url     = $null
            Title   = $wiTitle
            Error   = "HTTP $statusCode : $errBody"
        }
    }
}

Export-ModuleMember -Function `
    Get-DotEnvValue, `
    ConvertTo-HtmlText, `
    ConvertTo-HtmlEncode, `
    New-RLDatixAlertWorkItem
