Set-StrictMode -Version Latest

# PSScriptAnalyzer suppressions (file-level rationale):
#   PSAvoidUsingWriteHost - we deliberately use Write-Host for ADO
#     logging commands (##[section], ##vso[task.logissue ...],
#     ##vso[task.addattachment ...]). These must reach the host
#     stream, not the output stream, so the pipeline UI can pick
#     them up. The same lines also carry a fallback Write-Error /
#     Write-Warning for the operator.
#   PSUseShouldProcessForStateChangingFunctions - Start-TaskLog and
#     Stop-TaskLog are framework-internal, not user-facing, and
#     ShouldProcess would add no value to a script entry point.
#   PSAvoidOverwritingBuiltInCmdlets - Write-Log is the name
#     chosen by the plan; renaming to avoid the built-in
#     (PowerShell 6.1+) would break the documented public API.
# SuppressMessageAttribute is applied per function below because
# PSScriptAnalyzer does not honor module-level suppressions for
# nested function definitions.

<#
.SYNOPSIS
    Structured logging and Azure DevOps visibility helpers for the
    platform-automation framework.

.DESCRIPTION
    Logging.psm1 owns the framework's console output and the run log
    artifact (output/ExecutionLog.txt). Every entry is timestamped in
    UTC ISO 8601 and tagged with a level (INFO/WARN/ERROR/DEBUG). On
    Azure DevOps agents the same line is also emitted as an ADO
    logging command so the UI shows sections, warnings, and error
    annotations correctly. When the same script runs locally the ADO
    commands are harmless plain text.

    State for the current run lives in $Script:* variables inside the
    module. Start-TaskLog initializes it; Stop-TaskLog flushes the log
    buffer to disk and returns elapsed time.

    The module never logs secret values. Callers are responsible for
    scrubbing before passing a message.
#>

$Script:LogBuffer = New-Object System.Collections.Generic.List[string]
$Script:StartTime = $null
$Script:TaskName  = ''
$Script:LogFile   = $null
$Script:IsInRun   = $false

function Initialize-LogState {
    [CmdletBinding()]
    param(
        [string]$TaskName,
        [datetime]$StartTime,
        [string]$LogFile
    )
    $Script:TaskName  = $TaskName
    $Script:StartTime = $StartTime
    $Script:LogFile   = $LogFile
    $Script:LogBuffer = New-Object System.Collections.Generic.List[string]
    $Script:IsInRun   = $true
}

function Format-LogLine {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [datetime]$Timestamp,
        [string]$Level,
        [string]$TaskName,
        [string]$Message,
        [hashtable]$Context
    )
    $ts = $Timestamp.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    $tag = if ($TaskName) { "[$TaskName]" } else { '' }
    $ctx = ''
    if ($Context -and $Context.Count -gt 0) {
        $parts = foreach ($k in $Context.Keys) {
            $v = if ($null -eq $Context[$k]) { '' } else { [string]$Context[$k] }
            "$k=$v"
        }
        $ctx = ' ' + ($parts -join ' ')
    }
    return "$ts [$Level]$tag $Message$ctx"
}

function Start-TaskLog {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    <#
    .SYNOPSIS
        Begin a new run: initialize log state and emit the start line.
    .DESCRIPTION
        Records the start time and the task name. The first entry is
        written to the in-memory buffer; the buffer is flushed to
        disk by Stop-TaskLog. Safe to call only once per run.
    .PARAMETER TaskName
        Short name for the run (e.g. 'VendorMonitor').
    .PARAMETER LogFile
        Optional path to the run log file. Used by Stop-TaskLog
        when flushing.
    .EXAMPLE
        Start-TaskLog -TaskName 'VendorMonitor' -LogFile ./output/ExecutionLog.txt
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$TaskName,

        [string]$LogFile
    )
    if ($Script:IsInRun) {
        Write-Warning 'Start-TaskLog: a run is already in progress. Resetting log state.'
    }
    Initialize-LogState -TaskName $TaskName -StartTime (Get-Date).ToUniversalTime() -LogFile $LogFile
    $line = Format-LogLine -Timestamp $Script:StartTime -Level 'INFO' -TaskName $Script:TaskName -Message 'run start'
    $Script:LogBuffer.Add($line) | Out-Null
    Write-Host "##[section]$line"
}

function Write-Log {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
    <#
    .SYNOPSIS
        Write a structured log entry.
    .DESCRIPTION
        Adds the entry to the in-memory buffer and writes it to the
        host. On Azure DevOps agents WARN and ERROR are also emitted
        as task.logissue commands so the run shows the right badge.
        DEBUG entries are suppressed unless the host is verbose.
    .PARAMETER Message
        Human-readable message. Do not include secrets.
    .PARAMETER Level
        INFO (default), WARN, ERROR, or DEBUG.
    .PARAMETER Context
        Optional hashtable of key=value pairs to append to the line
        (vendor, url, httpStatus, ...).
    .EXAMPLE
        Write-Log -Message 'fetched article' -Level INFO -Context @{ vendor='RLDatix'; httpStatus=200; count=42 }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [ValidateSet('INFO','WARN','ERROR','DEBUG')]
        [string]$Level = 'INFO',

        [hashtable]$Context
    )

    if (-not $Script:IsInRun) {
        Initialize-LogState -TaskName 'AdHoc' -StartTime (Get-Date).ToUniversalTime() -LogFile $null
    }

    if ($Level -eq 'DEBUG' -and -not $VerbosePreference) {
        return
    }

    $line = Format-LogLine -Timestamp (Get-Date).ToUniversalTime() -Level $Level -TaskName $Script:TaskName -Message $Message -Context $Context
    $Script:LogBuffer.Add($line) | Out-Null

    switch ($Level) {
        'INFO'  { Write-Host $line }
        'DEBUG' { Write-Verbose $line }
        'WARN'  { Write-Host "##vso[task.logissue type=warning]$line"; Write-Warning $Message }
        'ERROR' { Write-Host "##vso[task.logissue type=error]$line"; Write-Error $Message -ErrorAction Continue }
    }
}

function Write-VendorResultLine {
    <#
    .SYNOPSIS
        Emit a single structured line summarizing a vendor/product
        collection attempt.
    .DESCRIPTION
        Convenience wrapper for the per-vendor summary line that
        appears in ExecutionLog.txt. All fields are encoded in the
        message so the line is one self-contained, parseable record
        (vendor, product, url, httpStatus, count, durationMs, plus an
        optional error string).
    .PARAMETER Vendor
    .PARAMETER Product
    .PARAMETER Url
    .PARAMETER HttpStatus
    .PARAMETER Count
    .PARAMETER DurationMs
    .PARAMETER Level
        INFO (default) for success, ERROR for a failed vendor.
    .PARAMETER Error
        Optional error message for the failure case.
    #>
    [CmdletBinding()]
    param(
        [string]$Vendor,
        [string]$Product,
        [string]$Url,
        [int]$HttpStatus = 0,
        [int]$Count = 0,
        [long]$DurationMs = 0,
        [ValidateSet('INFO','WARN','ERROR')]
        [string]$Level = 'INFO',
        [string]$ErrorMessage
    )
    $parts = @(
        "vendor=$Vendor",
        "product=$Product",
        "url=$Url",
        "httpStatus=$HttpStatus",
        "count=$Count",
        "durationMs=$DurationMs"
    )
    if ($ErrorMessage) { $parts += "error=$ErrorMessage" }
    Write-Log -Message ($parts -join ' ') -Level $Level
}

function Add-RunSummary {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
    <#
    .SYNOPSIS
        Attach a Markdown report to the Azure DevOps run summary tab.
    .DESCRIPTION
        Emits the ADO command
        ##vso[task.addattachment type=Distributedtask.Core.Summary;name=<Name>;]<path>
        so the file at -MarkdownPath is rendered on the run's
        Summary tab. No-op locally (the command is just echoed).
    .PARAMETER MarkdownPath
        Path to the Markdown file to attach.
    .PARAMETER Name
        Display name for the attachment. Defaults to 'VendorReport'.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$MarkdownPath,

        [ValidateNotNullOrEmpty()]
        [string]$Name = 'VendorReport'
    )
    if (-not (Test-Path -LiteralPath $MarkdownPath -PathType Leaf)) {
        Write-Log -Message "Add-RunSummary: report not found at '$MarkdownPath'" -Level WARN
        return
    }
    $abs = (Resolve-Path -LiteralPath $MarkdownPath).Path
    Write-Host "##vso[task.addattachment type=Distributedtask.Core.Summary;name=$Name;]$abs"
    Write-Log -Message "attached summary report: $Name ($abs)" -Level INFO
}

function Stop-TaskLog {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    <#
    .SYNOPSIS
        End a run: emit the end line, flush the log buffer, return
        elapsed time.
    .DESCRIPTION
        Writes the buffered log lines to -OutputPath/ExecutionLog.txt
        (creating the directory if needed) and returns the elapsed
        time in milliseconds. Returns 0 if no run was started.
    .PARAMETER OutputPath
        Directory in which ExecutionLog.txt is written. Defaults to
        the current directory.
    .EXAMPLE
        $elapsed = Stop-TaskLog -OutputPath ./output
    #>
    [CmdletBinding()]
    [OutputType([long])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath
    )

    if (-not $Script:IsInRun) {
        Write-Verbose 'Stop-TaskLog: no run in progress.'
        return 0
    }

    $end = (Get-Date).ToUniversalTime()
    $elapsedMs = [long]($end - $Script:StartTime).TotalMilliseconds
    $line = Format-LogLine -Timestamp $end -Level 'INFO' -TaskName $Script:TaskName -Message "run end durationMs=$elapsedMs"
    $Script:LogBuffer.Add($line) | Out-Null
    Write-Host "##[section]$line"

    if (-not (Test-Path -LiteralPath $OutputPath -PathType Container)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }
    $logFile = if ($Script:LogFile) { $Script:LogFile } else { Join-Path -Path $OutputPath -ChildPath 'ExecutionLog.txt' }
    $Script:LogBuffer | Set-Content -LiteralPath $logFile -Encoding utf8

    Write-Host "wrote execution log: $logFile"
    $Script:IsInRun = $false
    return $elapsedMs
}

function Get-LogBuffer {
    <#
    .SYNOPSIS
        Return the current run's buffered log lines (testing/diagnostic).
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param()
    return $Script:LogBuffer.ToArray()
}

Export-ModuleMember -Function `
    Start-TaskLog, `
    Write-Log, `
    Write-VendorResultLine, `
    Add-RunSummary, `
    Stop-TaskLog, `
    Get-LogBuffer
