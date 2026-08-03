Set-StrictMode -Version Latest

<#
.SYNOPSIS
    Core helpers for the platform-automation framework: configuration
    loading, HTTP with retry and pagination, output paths, UTC time.

.DESCRIPTION
    Common.psm1 is the single choke point for I/O and configuration so
    the rest of the framework can stay collector-agnostic. Conventions:

      * All HTTP goes through Invoke-HttpGetWithRetry, which never
        throws on an HTTP error - it returns @{ StatusCode; Content;
        Success; Error } so callers (and the logger) always see the
        real status.
      * All config comes from JSON files via Get-Config; URLs and
        vendor-specific strings never live in code.
      * All timestamps are UTC ISO 8601; use Get-UtcTimestamp.

    This module owns no business logic. It is imported once by the
    entry script via Import-Framework.
#>

function Import-Framework {
    <#
    .SYNOPSIS
        Sets strict mode and imports every framework module from a
        given directory.
    .DESCRIPTION
        Idempotent: re-importing a module that is already loaded is a
        no-op, so a second call is safe. This is the only function
        that the entry script needs to call to bootstrap the framework.
    .PARAMETER ModulesPath
        Directory containing the framework .psm1 files. Defaults to
        ./modules relative to the caller's working directory.
    .EXAMPLE
        Import-Framework -ModulesPath ./modules
    #>
    [CmdletBinding()]
    param(
        [string]$ModulesPath = (Join-Path -Path '.' -ChildPath 'modules')
    )

Set-StrictMode -Version Latest

# PSScriptAnalyzer suppressions: per-function attributes below
# (PSScriptAnalyzer does not honor module-level suppressions for
# nested function definitions; SuppressMessageAttribute must be
# applied to each function individually).

    if (-not (Test-Path -LiteralPath $ModulesPath -PathType Container)) {
        throw "Import-Framework: modules directory not found at '$ModulesPath'."
    }

    $modules = @('Common.psm1', 'Logging.psm1', 'State.psm1', 'Html.psm1')
    foreach ($name in $modules) {
        $path = Join-Path -Path $ModulesPath -ChildPath $name
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            Import-Module -Name $path -Force -Global -ErrorAction Stop
        }
    }
}

function Get-Config {
    <#
    .SYNOPSIS
        Load a JSON config file and validate required keys.
    .DESCRIPTION
        Parses the file at -Path and returns the resulting object.
        If -RequiredKeys is supplied, each dotted path (e.g. 'Http.UserAgent'
        or 'Vendors') is checked for presence. Errors include the
        file path and a one-line fix hint so the operator can act
        without opening the script.
    .PARAMETER Path
        Absolute or relative path to the JSON file.
    .PARAMETER RequiredKeys
        Optional array of dotted paths that must be present.
    .EXAMPLE
        $cfg = Get-Config -Path ./config/settings.json -RequiredKeys 'Http','Collector','Output','Run'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [string[]]$RequiredKeys
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Get-Config: file not found at '$Path'."
    }

    $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    try {
        $obj = $raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Get-Config: '$Path' is not valid JSON. $($_.Exception.Message)"
    }

    if ($null -eq $obj) {
        throw "Get-Config: '$Path' parsed to \$null. Check for an empty file or a top-level null."
    }

    foreach ($key in ($RequiredKeys | Where-Object { $_ })) {
        $segments = $key -split '\.'
        $cursor = $obj
        $missing = $false
        foreach ($seg in $segments) {
            if ($null -eq $cursor) { $missing = $true; break }
            $prop = $cursor.PSObject.Properties[$seg]
            if ($null -eq $prop) { $missing = $true; break }
            $cursor = $prop.Value
        }
        if ($missing) {
            throw "Get-Config: '$Path' is missing required key '$key'. Add it to the JSON and retry."
        }
    }

    return $obj
}

function Invoke-HttpGetWithRetry {
    <#
    .SYNOPSIS
        HTTP GET with exponential backoff and a structured result.
    .DESCRIPTION
        Retries on transient failures (network errors, 5xx, 429) up to
        -Retries times. Never throws on an HTTP error; always returns
        a hashtable so callers and the logger can capture the real
        status. The only exception is a parameter-binding error.
    .PARAMETER Uri
        Target URL. Query string is part of the URL.
    .PARAMETER Retries
        Total attempts (1 = no retry). Default 3.
    .PARAMETER TimeoutSec
        Per-attempt timeout in seconds. Default 30.
    .PARAMETER UserAgent
        User-Agent header. Default 'platform-automation/1.0'.
    .PARAMETER Headers
        Optional additional headers as a hashtable.
    .EXAMPLE
        $r = Invoke-HttpGetWithRetry -Uri 'https://example.com/api'
        if ($r.Success) { $r.Content | ConvertFrom-Json }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Uri,

        [ValidateRange(1, 10)]
        [int]$Retries = 3,

        [ValidateRange(1, 300)]
        [int]$TimeoutSec = 30,

        [ValidateNotNullOrEmpty()]
        [string]$UserAgent = 'platform-automation/1.0',

        [hashtable]$Headers
    )

    $result = [ordered]@{
        StatusCode = 0
        Content    = ''
        Success    = $false
        Error      = $null
    }

    $attempt = 0
    $delaySec = 1
    while ($attempt -lt $Retries) {
        $attempt++
        try {
            $iwrParams = @{
                Uri             = $Uri
                UseBasicParsing = $true
                TimeoutSec      = $TimeoutSec
                Headers         = @{ 'User-Agent' = $UserAgent }
                ErrorAction     = 'Stop'
            }
            if ($Headers) {
                foreach ($k in $Headers.Keys) { $iwrParams.Headers[$k] = $Headers[$k] }
            }
            $resp = Invoke-WebRequest @iwrParams
            $result.StatusCode = [int]$resp.StatusCode
            $result.Content    = [string]$resp.Content
            $result.Success    = ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 300)
            if (-not $result.Success) {
                $result.Error = "HTTP $($resp.StatusCode)"
            }
            return $result
        }
        catch {
            $httpStatus = 0
            $msg = $_.Exception.Message
            if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
                $httpStatus = [int]$_.Exception.Response.StatusCode
                $msg = "HTTP $httpStatus - $($_.Exception.Message)"
            }
            $result.StatusCode = $httpStatus
            $result.Error      = $msg
            $transient = ($httpStatus -eq 0) -or ($httpStatus -eq 429) -or ($httpStatus -ge 500)
            $isLast = ($attempt -ge $Retries)
            if (-not $transient -or $isLast) {
                $result.Success = $false
                return $result
            }
            Start-Sleep -Seconds $delaySec
            $delaySec = $delaySec * 2
        }
    }

    $result.Success = $false
    if (-not $result.Error) { $result.Error = 'Exhausted retries with no response' }
    return $result
}

function Get-JsonPaged {
    <#
    .SYNOPSIS
        Fetch every page of a paginated JSON endpoint and aggregate
        the array found at -ItemsPath.
    .DESCRIPTION
        Walks the response's 'next_page' field (Zendesk Help Center
        and most public APIs use this convention), up to -MaxPages
        pages, and returns a flat array of the items found at the
        dotted -ItemsPath in each page's body. Stops early on a
        non-2xx response or a malformed body and surfaces the error
        via the return object's Success flag.
    .PARAMETER Uri
        First-page URL.
    .PARAMETER ItemsPath
        Dotted path to the array of items inside each page body
        (e.g. 'articles', 'data.items').
    .PARAMETER MaxPages
        Hard cap on the number of pages fetched. Default 3.
    .PARAMETER Retries
        Per-page retry policy (passed to Invoke-HttpGetWithRetry).
    .PARAMETER TimeoutSec
        Per-page timeout.
    .PARAMETER UserAgent
        User-Agent header.
    .EXAMPLE
        $items = Get-JsonPaged -Uri $url -ItemsPath 'articles' -MaxPages 3
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Uri,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ItemsPath,

        [ValidateRange(1, 100)]
        [int]$MaxPages = 3,

        [ValidateRange(1, 10)]
        [int]$Retries = 3,

        [ValidateRange(1, 300)]
        [int]$TimeoutSec = 30,

        [ValidateNotNullOrEmpty()]
        [string]$UserAgent = 'platform-automation/1.0'
    )

    $all = New-Object System.Collections.Generic.List[object]
    $next = $Uri
    $page = 0
    $lastStatus = 0
    while ($next -and $page -lt $MaxPages) {
        $page++
        $resp = Invoke-HttpGetWithRetry -Uri $next -Retries $Retries -TimeoutSec $TimeoutSec -UserAgent $UserAgent
        $lastStatus = $resp.StatusCode
        if (-not $resp.Success) {
            return [pscustomobject]@{
                Success    = $false
                StatusCode = $resp.StatusCode
                Error      = $resp.Error
                Pages      = $page
                Items      = $all.ToArray()
            }
        }
        try {
            $body = $resp.Content | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            return [pscustomobject]@{
                Success    = $false
                StatusCode = $resp.StatusCode
                Error      = "Page $page body is not valid JSON: $($_.Exception.Message)"
                Pages      = $page
                Items      = $all.ToArray()
            }
        }

        $cursor = $body
        foreach ($seg in ($ItemsPath -split '\.')) {
            if ($null -eq $cursor) { break }
            $prop = $cursor.PSObject.Properties[$seg]
            if ($null -eq $prop) { $cursor = $null; break }
            $cursor = $prop.Value
        }
        if ($null -ne $cursor) {
            foreach ($item in @($cursor)) { $all.Add($item) }
        }

        $nextProp = $body.PSObject.Properties['next_page']
        $next = if ($nextProp) { [string]$nextProp.Value } else { $null }
        if ([string]::IsNullOrWhiteSpace($next)) { $next = $null }
    }

    return [pscustomobject]@{
        Success    = $true
        StatusCode = $lastStatus
        Error      = $null
        Pages      = $page
        Items      = $all.ToArray()
    }
}

function New-OutputDirectory {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    <#
    .SYNOPSIS
        Ensure the output directory exists.
    .DESCRIPTION
        Creates the directory if missing and returns its resolved
        absolute path. Safe to call repeatedly.
    .PARAMETER Path
        Directory to create.
    .EXAMPLE
        $dir = New-OutputDirectory -Path ./output
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
    return (Resolve-Path -LiteralPath $Path).Path
}

function ConvertTo-SafeFileName {
    <#
    .SYNOPSIS
        Sanitize a string for use as a cross-platform filename.
    .DESCRIPTION
        Replaces characters disallowed on Windows or awkward on
        Linux/macOS with '-', collapses repeats, trims, and falls
        back to 'item' for empty results. Used for raw-capture
        filenames and report labels derived from vendor/product
        data.
    .PARAMETER Name
        Input string to sanitize.
    .EXAMPLE
        ConvertTo-SafeFileName 'Release Notes: July 2026'
        # -> 'Release-Notes-July-2026'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Name
    )

    $invalid = [System.IO.Path]::GetInvalidFileNameChars() | ForEach-Object { [regex]::Escape([string]$_) }
    $clean = $Name
    if ($invalid.Count -gt 0) {
        $invalidPattern = '[' + ($invalid -join '') + ']'
        $clean = $clean -replace $invalidPattern, '-'
    }
    $winReserved = '<>:"/\|?*'
    $winPattern = '[' + [regex]::Escape($winReserved) + ']'
    $clean = $clean -replace $winPattern, '-'
    $clean = $clean -replace '\s+', '-'
    $clean = $clean -replace '-{2,}', '-'
    $clean = $clean.Trim('-', '.', ' ', '_')
    if ([string]::IsNullOrWhiteSpace($clean)) { $clean = 'item' }
    if ($clean.Length -gt 200) { $clean = $clean.Substring(0, 200) }
    return $clean
}

function Get-UtcTimestamp {
    <#
    .SYNOPSIS
        Return the current UTC time as an ISO 8601 string.
    .DESCRIPTION
        Use this anywhere a timestamp is recorded. The format ends
        in 'Z' to make the UTC nature explicit in logs and reports.
    .EXAMPLE
        Get-UtcTimestamp
        # -> '2026-08-02T22:47:13Z'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
}

Export-ModuleMember -Function `
    Import-Framework, `
    Get-Config, `
    Invoke-HttpGetWithRetry, `
    Get-JsonPaged, `
    New-OutputDirectory, `
    ConvertTo-SafeFileName, `
    Get-UtcTimestamp
