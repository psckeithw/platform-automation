Set-StrictMode -Version Latest

$script:AdoPat = $null
$script:AdoOrg = $null
$script:AdoProject = $null

function Initialize-AdoConfig {
    [CmdletBinding()]
    param()

    $envPath = Join-Path -Path '.' -ChildPath '.env'
    if (-not (Test-Path -LiteralPath $envPath -PathType Leaf)) {
        throw "Initialize-AdoConfig: .env file not found at '$envPath'"
    }

    $lines = Get-Content -LiteralPath $envPath -Encoding utf8 -ErrorAction Stop
    $vars = @{}
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) { continue }
        $eq = $trimmed.IndexOf('=')
        if ($eq -le 0) { continue }
        $key = $trimmed.Substring(0, $eq).Trim()
        $val = $trimmed.Substring($eq + 1).Trim()
        $vars[$key] = $val
    }

    $script:AdoPat     = $vars['ADO_PAT']
    $script:AdoOrg     = $vars['AZURE_DEVOPS_ORG']
    $script:AdoProject = $vars['AZURE_DEVOPS_PROJECTS']

    if ([string]::IsNullOrWhiteSpace($script:AdoPat)) { throw "Initialize-AdoConfig: ADO_PAT not found in .env" }
    if ([string]::IsNullOrWhiteSpace($script:AdoOrg)) { throw "Initialize-AdoConfig: AZURE_DEVOPS_ORG not found in .env" }
    if ([string]::IsNullOrWhiteSpace($script:AdoProject)) { throw "Initialize-AdoConfig: AZURE_DEVOPS_PROJECTS not found in .env" }
}

function New-AdoWorkItem {
    <#
    .SYNOPSIS
        Create an ADO User Story under @CurrentIteration.
    .DESCRIPTION
        Reads ADO_PAT, AZURE_DEVOPS_ORG, AZURE_DEVOPS_PROJECTS from
        .env (via Initialize-AdoConfig). Posts a User Story with
        title, HTML description, and tags.
    .PARAMETER Title
        User Story title (e.g. "RL6 6.34").
    .PARAMETER DescriptionHtml
        HTML body for the System.Description field.
    .PARAMETER Tags
        Comma-separated tags string (default: "RLDatix, RL6, Auto-Generated").
    .OUTPUTS
        The created work item ID (int).
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Title,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DescriptionHtml,

        [string]$Tags = 'RLDatix, RL6, Auto-Generated'
    )

    if (-not $script:AdoPat) { Initialize-AdoConfig }

    $uri = "https://dev.azure.com/$script:AdoOrg/$script:AdoProject/_apis/wit/workitems/`$User%20Story?api-version=7.1"

    $body = @(
        @{ op = 'add'; path = '/fields/System.Title';       value = $Title }
        @{ op = 'add'; path = '/fields/System.Description'; value = $DescriptionHtml }
        @{ op = 'add'; path = '/fields/System.Tags';        value = $Tags }
        @{ op = 'add'; path = '/fields/System.IterationPath'; value = '@CurrentIteration' }
    ) | ConvertTo-Json -Depth 3

    $token = [System.Text.Encoding]::ASCII.GetBytes(":" + $script:AdoPat)
    $base64 = [System.Convert]::ToBase64String($token)

    try {
        $resp = Invoke-RestMethod -Uri $uri -Method Patch -ContentType 'application/json-patch+json' -Body $body -Headers @{ Authorization = "Basic $base64" } -ErrorAction Stop
        $workItemId = [int]$resp.id
        Write-Log -Message "Created ADO User Story #$workItemId: $Title" -Level INFO
        return $workItemId
    }
    catch {
        $msg = "New-AdoWorkItem: failed to create '$Title': $($_.Exception.Message)"
        Write-Log -Message $msg -Level ERROR
        throw $msg
    }
}

Export-ModuleMember -Function New-AdoWorkItem, Initialize-AdoConfig
