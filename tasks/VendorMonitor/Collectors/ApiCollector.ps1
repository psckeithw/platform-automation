# ApiCollector.ps1 - generic, declarative JSON-API collector.
#
# This file is dot-sourced by Run.ps1. It defines Invoke-ApiCollector
# and a small date-normalization helper. It is intentionally NOT a
# .psm1: Run.ps1 picks a collector by name from config and loads it
# with a single dot-source.
#
# Adding a new JSON-API vendor (or a new product under an existing
# vendor) is a vendors.json change. No new collector code is needed.
#
# Normalized record shape (returned as [pscustomobject] per item):
#   Vendor        - the vendor name from config
#   Product       - the product name from config
#   Id            - stable record id (from FieldMap; falls back to '')
#   Title         - the release title
#   PublishedDate - ISO 8601 UTC string (e.g. '2026-07-06T15:05:15Z')
#   SourceUrl     - the canonical source URL
#   RawBody       - optional raw body, used for HTML captures and
#                   Markdown excerpts. May be empty/null.
#
# If the configured source is not generic enough to map declaratively,
# the vendor entry can carry an optional 'Script' property that names
# a custom .ps1 under tasks/VendorMonitor/Collectors/Overrides/.
# Overrides return the same normalized shape.

Set-StrictMode -Version Latest

function ConvertTo-UtcIso8601 {
    <#
    .SYNOPSIS
        Normalize a date string to ISO 8601 UTC ('Z' suffix).
    .DESCRIPTION
        Accepts the formats commonly returned by public APIs:
          * ISO 8601 already ('2026-07-06T15:05:15Z', with offset, ...)
          * Zendesk Help Center ('MM/dd/yyyy HH:mm:ss')
          * Unix epoch seconds (as a numeric string)
        Returns the value unchanged when parsing fails so the record
        still surfaces something human-readable in the report.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [AllowNull()]
        $Value
    )
    if ($null -eq $Value) { return '' }
    if ($Value -is [datetime]) { return $Value.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
    $s = [string]$Value
    if ([string]::IsNullOrWhiteSpace($s)) { return '' }

    if ($s -match '^\d{10}$') {
        try {
            return ([datetime]'1970-01-01T00:00:00Z').AddSeconds([long]$s).ToString('yyyy-MM-ddTHH:mm:ssZ')
        } catch { return $s }
    }

    $formats = [string[]]@(
        'yyyy-MM-ddTHH:mm:ssZ',
        'yyyy-MM-ddTHH:mm:ss.fffZ',
        'yyyy-MM-ddTHH:mm:sszzz',
        'yyyy-MM-ddTHH:mm:ss',
        'MM/dd/yyyy HH:mm:ss',
        'M/d/yyyy H:mm:ss',
        'yyyy-MM-dd'
    )
    $dt = [datetime]::MinValue
    $parsed = [datetime]::TryParseExact(
        $s,
        $formats,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal,
        [ref]$dt
    )
    if ($parsed) { return $dt.ToString('yyyy-MM-ddTHH:mm:ssZ') }
    return $s
}

function Get-FieldMapValue {
    <#
    .SYNOPSIS
        Read a property from a raw JSON record by FieldMap name,
        tolerant of missing/null values.
    .DESCRIPTION
        JSON values are typed by ConvertFrom-Json: a Zendesk
        'created_at' string becomes [DateTime], a count becomes
        [long], nested structures become [PSCustomObject]. This
        helper flattens them to a string for the normalized record:

          * [string]  - returned as-is
          * [DateTime] - formatted ISO 8601 UTC ('Z' suffix) so the
            downstream ConvertTo-UtcIso8601 sees a stable input
          * [bool], [int], [long], [double] - cast to string
          * everything else (arrays/objects) - serialized with
            ConvertTo-Json -Compress

        Empty results (missing field, null value) return ''.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        $Record,

        [Parameter(Mandatory)]
        [AllowNull()]
        [string]$JsonField
    )
    if ($null -eq $Record -or [string]::IsNullOrEmpty($JsonField)) { return '' }
    $prop = $Record.PSObject.Properties[$JsonField]
    if ($null -eq $prop) { return '' }
    if ($null -eq $prop.Value) { return '' }
    $v = $prop.Value
    if ($v -is [string]) { return $v }
    if ($v -is [datetime]) {
        return $v.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    }
    if ($v -is [bool] -or $v -is [int] -or $v -is [long] -or $v -is [double]) {
        return [string]$v
    }
    return ($v | ConvertTo-Json -Compress -Depth 5)
}

function Invoke-ApiCollector {
    <#
    .SYNOPSIS
        Fetch a paginated JSON endpoint and map each item to a
        normalized record.
    .DESCRIPTION
        Reads $Product.Url, follows 'next_page' up to
        $Settings.Collector.MaxPages, and applies $Product.FieldMap
        to each item to produce the normalized record. Logs a single
        vendor-result line with HTTP status, page count, and record
        count. Throws on hard failure (non-2xx after retries, missing
        ItemsPath, etc.) so the per-vendor try/catch in Run.ps1 can
        isolate the error.
    .PARAMETER Vendor
        The vendor config object (Vendors[i]).
    .PARAMETER Product
        The product config object (Vendors[i].Products[j]).
    .PARAMETER Settings
        The full settings object from config/settings.json. Used for
        Http.{UserAgent,TimeoutSec,Retries} and Collector.MaxPages.
    .OUTPUTS
        Array of normalized [pscustomobject] records.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [object]$Vendor,

        [Parameter(Mandatory)]
        [object]$Product,

        [Parameter(Mandatory)]
        [object]$Settings
    )

    $vendorName  = [string]$Vendor.Vendor
    $productName = [string]$Product.Product
    $url         = [string]$Product.Url
    $itemsPath   = [string]$Product.ItemsPath
    $fieldMap    = $Product.FieldMap
    if ($null -eq $fieldMap) {
        throw "ApiCollector[$vendorName/$productName]: FieldMap is required."
    }
    if ([string]::IsNullOrWhiteSpace($itemsPath)) {
        throw "ApiCollector[$vendorName/$productName]: ItemsPath is required."
    }
    if ([string]::IsNullOrWhiteSpace($url)) {
        throw "ApiCollector[$vendorName/$productName]: Url is required."
    }

    $maxPages = 1
    if ($Settings -and $Settings.Collector -and $Settings.Collector.MaxPages) {
        $maxPages = [int]$Settings.Collector.MaxPages
    }
    $ua = 'platform-automation/1.0'
    $timeout = 30
    $retries = 3
    if ($Settings -and $Settings.Http) {
        if ($Settings.Http.UserAgent) { $ua = [string]$Settings.Http.UserAgent }
        if ($Settings.Http.TimeoutSec) { $timeout = [int]$Settings.Http.TimeoutSec }
        if ($Settings.Http.Retries) { $retries = [int]$Settings.Http.Retries }
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $paged = Get-JsonPaged -Uri $url -ItemsPath $itemsPath -MaxPages $maxPages -Retries $retries -TimeoutSec $timeout -UserAgent $ua
    $sw.Stop()
    $elapsedMs = [long]$sw.Elapsed.TotalMilliseconds

    if (-not $paged.Success) {
        $err = "ApiCollector[$vendorName/$productName]: HTTP $($paged.StatusCode) after $($paged.Pages) page(s) - $($paged.Error)"
        Write-VendorResultLine -Vendor $vendorName -Product $productName -Url $url -HttpStatus $paged.StatusCode -Count 0 -DurationMs $elapsedMs -Level ERROR -Error $err
        throw $err
    }

    $records = New-Object System.Collections.Generic.List[object]
    foreach ($raw in @($paged.Items)) {
        $id            = Get-FieldMapValue -Record $raw -JsonField ([string]$fieldMap.Id)
        $title         = Get-FieldMapValue -Record $raw -JsonField ([string]$fieldMap.Title)
        $publishedRaw  = Get-FieldMapValue -Record $raw -JsonField ([string]$fieldMap.PublishedDate)
        $sourceUrl     = Get-FieldValueOrNull -Record $raw -JsonField ([string]$fieldMap.SourceUrl)
        $rawBody       = Get-FieldMapValue -Record $raw -JsonField ([string]$fieldMap.RawBody)

        $published = ConvertTo-UtcIso8601 -Value $publishedRaw

        $records.Add([pscustomobject]@{
            Vendor        = $vendorName
            Product       = $productName
            Id            = $id
            Title         = $title
            PublishedDate = $published
            SourceUrl     = if ($null -eq $sourceUrl) { '' } else { [string]$sourceUrl }
            RawBody       = $rawBody
        })
    }

    Write-VendorResultLine -Vendor $vendorName -Product $productName -Url $url -HttpStatus $paged.StatusCode -Count $records.Count -DurationMs $elapsedMs
    return $records.ToArray()
}

function Get-FieldValueOrNull {
    <#
    .SYNOPSIS
        Read a property as $null if absent, else return the raw value.
    .DESCRIPTION
        Used for SourceUrl so the caller can distinguish 'missing'
        from 'empty string' if it needs to.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        $Record,

        [Parameter(Mandatory)]
        [AllowNull()]
        [string]$JsonField
    )
    if ($null -eq $Record -or [string]::IsNullOrEmpty($JsonField)) { return $null }
    $prop = $Record.PSObject.Properties[$JsonField]
    if ($null -eq $prop) { return $null }
    return $prop.Value
}
