#!/usr/bin/env pwsh
# Run.ps1 - VendorMonitor entry point.
#
# Orchestrates a single run: loads config and previous state, walks
# every enabled vendor/product through its collector (per-vendor
# try/catch isolates failures), diffs results against the prior
# state, writes the JSON/Markdown report and ExecutionLog, and
# persists the new state. Returns 0 for a successful run, 1 only
# for framework/collection errors. A run that finds new releases
# is a success, not a failure.

[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path -Path '.' -ChildPath 'config/vendors.json'),

    [string]$SettingsPath = (Join-Path -Path '.' -ChildPath 'config/settings.json'),

    [string]$OutputPath = (Join-Path -Path '.' -ChildPath 'output'),

    [string]$StatePath = (Join-Path -Path '.' -ChildPath 'state'),

    [string[]]$Vendor,

    [switch]$Baseline,

    [switch]$ForceRecheck,

    [switch]$TestMode
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Script:RunHadError = $false

try {
    Import-Module -Name (Join-Path -Path '.' -ChildPath 'modules/Common.psm1') -Force -ErrorAction Stop
    Import-Framework -ModulesPath (Join-Path -Path '.' -ChildPath 'modules') -ErrorAction Stop
}
catch {
    Write-Error "Run.ps1: failed to bootstrap framework: $($_.Exception.Message)"
    exit 1
}

Start-TaskLog -TaskName 'VendorMonitor' -LogFile (Join-Path -Path $OutputPath -ChildPath 'ExecutionLog.txt')
$outDir = New-OutputDirectory -Path $OutputPath
$generatedAt = Get-UtcTimestamp
Write-Log -Message "run begin generatedAt=$generatedAt" -Level INFO

# Outer try/catch: framework errors set the exit code; per-vendor
# failures are isolated and never trip this.
try {
    # ---------- Load config ----------
    $settings = Get-Config -Path $SettingsPath -RequiredKeys 'Http','Collector','Output','Run'
    $vendorsRaw = Get-Config -Path $ConfigPath -RequiredKeys 'Vendors'
    if ($null -eq $vendorsRaw.Vendors -or @($vendorsRaw.Vendors).Count -eq 0) {
        throw "Get-Config: '$ConfigPath' has no Vendors entries."
    }

    # Test mode: top-N per section, force NEW, create work item,
    # do NOT persist state. Intended for end-to-end debugging of the
    # collector + notifier without waiting for a real release.
    if ($TestMode) {
        Write-Log -Message "TEST MODE: state will not be saved; notifier will create a work item for the first collected record" -Level WARN
        if (-not ($settings.PSObject.Properties['Notify'])) {
            $settings | Add-Member -NotePropertyName 'Notify' -NotePropertyValue ([pscustomobject]@{
                Enabled = $true; TopNTestMode = 1; WorkItemType = 'User Story'; CreateForStatuses = @('NEW')
            }) -Force
        }
        $settings.Notify.Enabled = $true
        if (-not $settings.Notify.TopNTestMode) { $settings.Notify | Add-Member -NotePropertyName 'TopNTestMode' -NotePropertyValue 1 -Force }
    }

    $vendors = @($vendorsRaw.Vendors | Where-Object {
        $enabled = $true
        $ep = $_.PSObject.Properties['Enabled']
        if ($ep) { $enabled = [bool]$ep.Value }
        $enabled -and (-not $Vendor -or $Vendor -contains $_.Vendor)
    })
    if ($vendors.Count -eq 0) {
        Write-Log -Message "no enabled vendors matched filter (Vendor=$($Vendor -join ','))" -Level WARN
    }

    $prevState = Get-PreviousState -StatePath $StatePath
    if ($prevState.Count -eq 0) {
        Write-Log -Message "cold start: no prior state found at '$StatePath/vendor-state.json' (baseline behavior)" -Level INFO
    }
    else {
        Write-Log -Message "loaded prior state: $($prevState.Count) record(s)" -Level INFO
    }

    # ---------- Collect ----------
    $allRecords = New-Object System.Collections.Generic.List[object]
    $errors = New-Object System.Collections.Generic.List[object]

    foreach ($vendorCfg in $vendors) {
        $vendorName = [string]$vendorCfg.Vendor
        $collectorNameProp = $vendorCfg.PSObject.Properties['Collector']
        $collectorName = if ($collectorNameProp) { [string]$collectorNameProp.Value } else { '' }
        $scriptProp = $vendorCfg.PSObject.Properties['Script']
        $scriptOverride = if ($scriptProp) { [string]$scriptProp.Value } else { '' }
        $products = @($vendorCfg.Products)
        Write-Log -Message "vendor start: $vendorName collector=$collectorName products=$($products.Count)" -Level INFO

        $collectorFn = $null
        $loadedPath = $null
        try {
            if ($scriptOverride) {
                $loadedPath = if ([System.IO.Path]::IsPathRooted($scriptOverride)) {
                    $scriptOverride
                } else {
                    Join-Path -Path '.' -ChildPath $scriptOverride
                }
                . $loadedPath
                $collectorFn = Get-Command -Name 'Invoke-OverrideCollector' -ErrorAction Stop
            }
            elseif ($collectorName) {
                $loadedPath = Join-Path -Path '.' -ChildPath "tasks/VendorMonitor/Collectors/$collectorName.ps1"
                if (-not (Test-Path -LiteralPath $loadedPath -PathType Leaf)) {
                    throw "collector file not found: $loadedPath"
                }
                . $loadedPath
                $fnName = "Invoke-$($collectorName -replace '[^A-Za-z0-9]', '')"
                $collectorFn = Get-Command -Name $fnName -ErrorAction Stop
            }
            else {
                throw "vendor entry has neither 'Collector' nor 'Script' set"
            }
        }
        catch {
            $msg = "vendor=$vendorName collector setup failed: $($_.Exception.Message)"
            Write-Log -Message $msg -Level ERROR
            $errors.Add([pscustomobject]@{
                Vendor  = $vendorName
                Product = ''
                Error   = $_.Exception.Message
            })
            continue
        }

        foreach ($product in $products) {
            $productName = [string]$product.Product
            try {
                $records = & $collectorFn -Vendor $vendorCfg -Product $product -Settings $settings
                foreach ($r in @($records)) { $allRecords.Add($r) }
            }
            catch {
                $msg = "vendor=$vendorName product=$productName failed: $($_.Exception.Message)"
                Write-Log -Message $msg -Level ERROR
                $errors.Add([pscustomobject]@{
                    Vendor  = $vendorName
                    Product = $productName
                    Error   = $_.Exception.Message
                })
                Write-Host "##vso[task.logissue type=error]$msg"
            }
        }
    }

    # ---------- Diff ----------
    $comparison = $null
    if ($ForceRecheck) {
        # Treat every record as RECHECK (preserved) so the report
        # still renders useful state, but we still persist the new map.
        $baselineFlag = ($prevState.Count -eq 0)
        $comparison = [pscustomobject]@{
            Items      = $allRecords.ToArray() | ForEach-Object {
                $item = $_
                $item | Select-Object *, @{ Name='ChangeStatus'; Expression={ if ($baselineFlag) { 'BASELINE' } else { 'RECHECK' } } }
            }
            NewState   = $null
            IsBaseline = $baselineFlag
        }
        $tmp = @{}
        foreach ($item in $allRecords.ToArray()) {
            $keyInfo = Get-RecordKey -Item $item
            $tmp[$keyInfo.Key] = [ordered]@{
                title     = [string]$item.Title
                hash      = $keyInfo.Hash
                firstSeen = if ($prevState.ContainsKey($keyInfo.Key)) { [string]$prevState[$keyInfo.Key].firstSeen } else { $generatedAt }
                sourceUrl = [string]$item.SourceUrl
            }
        }
        $comparison.NewState = $tmp
    }
    elseif ($Baseline -or $prevState.Count -eq 0) {
        $comparison = [pscustomobject]@{
            Items      = $allRecords.ToArray() | ForEach-Object {
                $x = $_
                $x | Select-Object *, @{ Name='ChangeStatus'; Expression={ 'BASELINE' } }
            }
            NewState   = $null
            IsBaseline = $true
        }
        $tmp = @{}
        foreach ($item in $allRecords.ToArray()) {
            $keyInfo = Get-RecordKey -Item $item
            $tmp[$keyInfo.Key] = [ordered]@{
                title     = [string]$item.Title
                hash      = $keyInfo.Hash
                firstSeen = $generatedAt
                sourceUrl = [string]$item.SourceUrl
            }
        }
        $comparison.NewState = $tmp
    }
    else {
        $comparison = Compare-ReleaseState -Previous $prevState -Items $allRecords.ToArray()
    }

    $tagged = @($comparison.Items)

    # ---------- Outputs ----------
    $summary = [ordered]@{
        generatedAt  = $generatedAt
        isBaseline   = [bool]$comparison.IsBaseline
        forceRecheck = [bool]$ForceRecheck
        counts       = [ordered]@{
            vendors   = @($vendors | ForEach-Object { $_.Vendor } | Sort-Object -Unique).Count
            items     = $tagged.Count
            new       = @($tagged | Where-Object { $_.ChangeStatus -eq 'NEW' }).Count
            changed   = @($tagged | Where-Object { $_.ChangeStatus -eq 'CHANGED' }).Count
            unchanged = @($tagged | Where-Object { $_.ChangeStatus -eq 'UNCHANGED' }).Count
            baseline  = @($tagged | Where-Object { $_.ChangeStatus -eq 'BASELINE' }).Count
            rechecks  = @($tagged | Where-Object { $_.ChangeStatus -eq 'RECHECK' }).Count
            errors    = $errors.Count
        }
        errors      = $errors.ToArray()
    }

    $reportItems = $tagged | ForEach-Object {
        [ordered]@{
            vendor         = [string]$_.Vendor
            product        = [string]$_.Product
            title          = [string]$_.Title
            publishedDate  = [string]$_.PublishedDate
            detectedAt     = $generatedAt
            sourceUrl      = [string]$_.SourceUrl
            changeDetected = "$($_.ChangeStatus)"
        }
    }
    $report = [ordered]@{
        generatedAt = $generatedAt
        summary     = $summary
        items       = $reportItems
    }
    $reportJson = $report | ConvertTo-Json -Depth 6
    $reportPath = Join-Path -Path $outDir -ChildPath 'VendorReport.json'
    Set-Content -LiteralPath $reportPath -Value $reportJson -Encoding utf8
    Write-Log -Message "wrote $reportPath" -Level INFO

    $maxRaw = 0
    if ($settings.Output -and $settings.Output.MaxRawItems) {
        $maxRaw = [int]$settings.Output.MaxRawItems
    }
    $captureRaw = $false
    if ($settings.Output -and $settings.Output.CaptureRawHtml) {
        $captureRaw = [bool]$settings.Output.CaptureRawHtml
    }
    if ($captureRaw -and $maxRaw -gt 0) {
        $captured = 0
        foreach ($item in $tagged) {
            if ($captured -ge $maxRaw) { break }
            $body = [string]$item.RawBody
            if ([string]::IsNullOrEmpty($body)) { continue }
            $safeVendor  = ConvertTo-SafeFileName -Name $item.Vendor
            $safeProduct = ConvertTo-SafeFileName -Name $item.Product
            $safeId      = ConvertTo-SafeFileName -Name ([string]$item.Id)
            $file = Join-Path -Path $outDir -ChildPath "$safeVendor-$safeProduct-$safeId.html"
            $docTitle = "$item.Vendor / $item.Product - $($item.Title)"
            $doc = ConvertTo-HtmlDocument -Body $body -Title $docTitle -SourceUrl ([string]$item.SourceUrl) -DetectedAt $generatedAt
            Set-Content -LiteralPath $file -Value $doc -Encoding utf8
            $captured++
        }
        if ($captured -gt 0) {
            Write-Log -Message "captured $captured styled HTML file(s) (cap $maxRaw)" -Level INFO
        }
    }

    $mdLines = New-Object System.Collections.Generic.List[string]
    $mdLines.Add("# Vendor Release Report")
    $mdLines.Add("")
    $mdLines.Add("- Generated: $generatedAt")
    $mode = if ($comparison.IsBaseline) { 'baseline' } elseif ($ForceRecheck) { 'force-recheck' } else { 'diff' }
    $mdLines.Add("- Mode: $mode")
    $mdLines.Add("- Vendors: $($summary.counts.vendors) | Items: $($summary.counts.items) | NEW: $($summary.counts.new) | CHANGED: $($summary.counts.changed) | UNCHANGED: $($summary.counts.unchanged) | BASELINE: $($summary.counts.baseline) | RECHECK: $($summary.counts.rechecks) | Errors: $($summary.counts.errors)")
    $mdLines.Add("")
    $mdLines.Add("## NEW / CHANGED")
    $mdLines.Add("")
    $mdLines.Add("| Vendor | Product | Published | Title | Status | URL |")
    $mdLines.Add("| --- | --- | --- | --- | --- | --- |")
    $newOrChanged = @($tagged | Where-Object { $_.ChangeStatus -in 'NEW','CHANGED','BASELINE','RECHECK' } | Sort-Object -Property @{Expression='ChangeStatus';Descending=$true}, PublishedDate)
    if ($newOrChanged.Count -eq 0) {
        $mdLines.Add("| - | - | - | _no new or changed releases_ | - | - |")
    }
    else {
        foreach ($item in $newOrChanged) {
            $title = ([string]$item.Title)
            if ($title.Length -gt 80) { $title = $title.Substring(0, 77) + '...' }
            $url = [string]$item.SourceUrl
            $mdLines.Add("| $($item.Vendor) | $($item.Product) | $($item.PublishedDate) | $title | $($item.ChangeStatus) | $url |")
        }
    }
    $mdLines.Add("")
    if ($errors.Count -gt 0) {
        $mdLines.Add("## Errors")
        $mdLines.Add("")
        $mdLines.Add("| Vendor | Product | Error |")
        $mdLines.Add("| --- | --- | --- |")
        foreach ($e in $errors.ToArray()) {
            $mdLines.Add("| $($e.Vendor) | $($e.Product) | $($e.Error) |")
        }
        $mdLines.Add("")
    }
    $mdReportPath = Join-Path -Path $outDir -ChildPath 'VendorReport.md'
    Set-Content -LiteralPath $mdReportPath -Value ($mdLines -join "`n") -Encoding utf8
    Write-Log -Message "wrote $mdReportPath" -Level INFO

    Add-RunSummary -MarkdownPath $mdReportPath -Name 'VendorReport'
    if ($summary.counts.new -gt 0) {
        $msg = "$($summary.counts.new) NEW release(s) detected"
        Write-Log -Message $msg -Level WARN
        Write-Host "##vso[task.logissue type=warning]$msg"
    }


    # ---------- Notify (ADO User Story for new/changed vendor releases) ----------
    $notifyEnabled = $false
    $notifyStatuses = @('NEW','CHANGED')
    $workItemType = 'User Story'
    $additionalTags = @()
    if ($settings.Notify) {
        if ($settings.PSObject.Properties['Notify.Enabled'])      { $notifyEnabled = [bool]$settings.Notify.Enabled }
        if ($settings.Notify.WorkItemType)                        { $workItemType = [string]$settings.Notify.WorkItemType }
        if ($settings.Notify.CreateForStatuses)                    { $notifyStatuses = @($settings.Notify.CreateForStatuses) }
        if ($settings.Notify.AdditionalTags)                      { $additionalTags = @($settings.Notify.AdditionalTags) }
    }

    if ($TestMode) {
        # Force every collected item to NEW so the notifier fires,
        # even if the article is already in state.
        $tagged = @($tagged | ForEach-Object {
            $_ | Select-Object *, @{ Name='ChangeStatus'; Expression={ 'NEW' } }
        })
        $summary.counts.new = ($tagged | Where-Object { $_.ChangeStatus -eq 'NEW' }).Count
    }

    if ($notifyEnabled -and $tagged.Count -gt 0) {
        $notifyItems = if ($TestMode) { @($tagged | Select-Object -First 1) } else { @($tagged | Where-Object { $_.ChangeStatus -in $notifyStatuses }) }
        if ($notifyItems.Count -gt 0) {
            $org  = Get-DotEnvValue -Name 'AZURE_DEVOPS_ORG'
            $proj = Get-DotEnvValue -Name 'AZURE_DEVOPS_PROJECTS'
            $pat  = Get-DotEnvValue -Name 'ADO_PAT'
            if ([string]::IsNullOrEmpty($org) -or [string]::IsNullOrEmpty($proj) -or [string]::IsNullOrEmpty($pat)) {
                Write-Log -Message "notify skipped: AZURE_DEVOPS_ORG/PROJECTS/ADO_PAT not set (env or .env)" -Level WARN
            }
            else {
                foreach ($item in $notifyItems) {
                    $title = [string]$item.Title
                    $body = [string]$item.RawBody
                    if ([string]::IsNullOrWhiteSpace($body)) { $body = "<p>$title</p>" }
                    $fullBody = @"
$body
<p><em>Auto-generated by platform-automation VendorMonitor</em></p>
"@
                    try {
                        $workItemId = New-AdoWorkItem -Title $title -DescriptionHtml $fullBody -Tags ($additionalTags -join ',')
                        Write-Log -Message "Created User Story #$workItemId for $title" -Level INFO
                    }
                    catch {
                        $msg = "Failed to create User Story for '$title': $($_.Exception.Message)"
                        Write-Log -Message $msg -Level ERROR
                        Write-Host "##vso[task.logissue type=error]$msg"
                    }

                }
            }
        }
    }

    $stateFile = Save-CurrentState -StatePath $StatePath -State $comparison.NewState
    Write-Log -Message "wrote state: $stateFile" -Level INFO

    Write-Log -Message "run done: NEW=$($summary.counts.new) CHANGED=$($summary.counts.changed) UNCHANGED=$($summary.counts.unchanged) BASELINE=$($summary.counts.baseline) RECHECK=$($summary.counts.rechecks) ERRORS=$($summary.counts.errors)" -Level INFO
}
catch {
    $Script:RunHadError = $true
    $where = $_.InvocationInfo.PositionMessage
    Write-Log -Message "framework error: $($_.Exception.Message) at $where" -Level ERROR
    Write-Host "##vso[task.logissue type=error]framework error: $($_.Exception.Message) at $where"
}

Stop-TaskLog -OutputPath $outDir | Out-Null

if ($Script:RunHadError) { exit 1 } else { exit 0 }
