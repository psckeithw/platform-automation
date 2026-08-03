#!/usr/bin/env pwsh
# scripts/verify-e2e.ps1 - end-to-end local verification of the
# platform-automation MVP. Walks all four scenarios from the
# T6.1 acceptance criteria and prints a PASS/FAIL summary.
#
# Run from the repo root:  pwsh -File scripts/verify-e2e.ps1
# Optional: -KeepArtifacts  to leave the test output/state dirs
#          behind instead of removing them on success.

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]
[CmdletBinding()]
param(
    [switch]$KeepArtifacts
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Reference the parameter at the top of the script so PSScriptAnalyzer
# does not warn about it being unused (it is consumed by Remove-TestDir
# below; the analyzer does not trace across function boundaries).
[void]$KeepArtifacts

$repoRoot = (Resolve-Path -Path '.').Path
$outDir   = Join-Path -Path '/tmp' -ChildPath 'kilo-e2e-output'
$stateDir = Join-Path -Path '/tmp' -ChildPath 'kilo-e2e-state'
$config   = Join-Path -Path $repoRoot -ChildPath 'config/vendors.json'
$settings = Join-Path -Path $repoRoot -ChildPath 'config/settings.json'

function Remove-TestDir {
    if ($KeepArtifacts) { return }
    Remove-Item -LiteralPath $outDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $stateDir -Recurse -Force -ErrorAction SilentlyContinue
}

function Invoke-Run {
    param([string[]]$ExtraArgs)
    $argList = @(
        '-NoProfile'
        '-File', (Join-Path -Path $repoRoot -ChildPath 'tasks/VendorMonitor/Run.ps1')
        '-ConfigPath', $config
        '-SettingsPath', $settings
        '-OutputPath', $outDir
        '-StatePath', $stateDir
    ) + $ExtraArgs
    & pwsh @argList 2>&1 | Out-Null
    return $LASTEXITCODE
}

function Read-Summary {
    $json = Join-Path -Path $outDir -ChildPath 'VendorReport.json'
    if (-not (Test-Path -LiteralPath $json -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $json -Raw | ConvertFrom-Json
}

$results = New-Object System.Collections.Generic.List[object]
function Add-Result {
    param([string]$Scenario, [bool]$Pass, [string]$Detail)
    $results.Add([pscustomobject]@{
        Scenario = $Scenario
        Pass     = $Pass
        Detail   = $Detail
    })
    $tag = if ($Pass) { 'PASS' } else { 'FAIL' }
    Write-Host "[$tag] $Scenario - $Detail"
}

try {
    # ---------- Scenario 1: cold start = baseline ----------
    Remove-TestDir
    $rc = Invoke-Run -ExtraArgs @('-Baseline')
    $sum = Read-Summary
    $ok1 = ($rc -eq 0) -and $sum -and ($sum.summary.counts.items -eq 105) -and ($sum.summary.counts.baseline -eq 105) -and ($sum.summary.counts.new -eq 0) -and ($sum.summary.counts.errors -eq 0)
    Add-Result 'Cold start = baseline' $ok1 "exit=$rc items=$($sum.summary.counts.items) baseline=$($sum.summary.counts.baseline) new=$($sum.summary.counts.new)"

    # ---------- Scenario 2: identical second run = all UNCHANGED ----------
    $rc = Invoke-Run
    $sum = Read-Summary
    $ok2 = ($rc -eq 0) -and $sum -and ($sum.summary.counts.unchanged -eq 105) -and ($sum.summary.counts.new -eq 0) -and ($sum.summary.counts.changed -eq 0)
    Add-Result 'Identical second run = all UNCHANGED' $ok2 "exit=$rc unchanged=$($sum.summary.counts.unchanged) new=$($sum.summary.counts.new) changed=$($sum.summary.counts.changed)"

    # ---------- Scenario 3: hash mutation = 1 CHANGED ----------
    $stateFile = Join-Path -Path $stateDir -ChildPath 'vendor-state.json'
    $j = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
    $first = $j.PSObject.Properties | Select-Object -First 1
    $key = $first.Name
    $first.Value.hash = 'ffff' * 16
    $map = [ordered]@{}
    foreach ($p in $j.PSObject.Properties) { $map[$p.Name] = $p.Value }
    $map[$key] = $first.Value
    $map | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $stateFile
    $rc = Invoke-Run
    $sum = Read-Summary
    $ok3 = ($rc -eq 0) -and $sum -and ($sum.summary.counts.changed -eq 1) -and ($sum.summary.counts.unchanged -eq 104)
    Add-Result 'Hash mutation = 1 CHANGED' $ok3 "exit=$rc changed=$($sum.summary.counts.changed) unchanged=$($sum.summary.counts.unchanged)"

    # ---------- Scenario 4: state entry removal = 1 NEW ----------
    $j = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
    $first = $j.PSObject.Properties | Select-Object -First 1
    $key = $first.Name
    $map = [ordered]@{}
    foreach ($p in $j.PSObject.Properties) { if ($p.Name -ne $key) { $map[$p.Name] = $p.Value } }
    $map | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $stateFile
    $rc = Invoke-Run
    $sum = Read-Summary
    $ok4 = ($rc -eq 0) -and $sum -and ($sum.summary.counts.new -eq 1) -and ($sum.summary.counts.unchanged -eq 104)
    Add-Result 'State entry removal = 1 NEW' $ok4 "exit=$rc new=$($sum.summary.counts.new) unchanged=$($sum.summary.counts.unchanged)"

    # ---------- Scenario 5: per-vendor isolation with a broken vendor ----------
    Remove-Item -LiteralPath $stateDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $outDir -Recurse -Force -ErrorAction SilentlyContinue
    $mixedConfig = '/tmp/kilo-e2e-vendors-mixed.json'
    @'
{
  "Vendors": [
    { "Vendor": "BrokenVendor", "Enabled": true, "Collector": "ApiCollector",
      "Products": [ { "Product": "BrokenProduct",
        "Url": "https://rldatix-public.zendesk.com/api/v2/help_center/en-us/sections/00000000000000/articles.json?per_page=5",
        "ItemsPath": "articles",
        "FieldMap": { "Id":"id","Title":"title","PublishedDate":"created_at","SourceUrl":"html_url","RawBody":"body" } } ] },
    { "Vendor": "RLDatix", "Enabled": true, "Collector": "ApiCollector",
      "Products": [ { "Product": "IntelligentContract",
        "Url": "https://rldatix-public.zendesk.com/api/v2/help_center/en-us/sections/19851648629532/articles.json?sort_by=created_at&sort_order=desc&per_page=100",
        "ItemsPath": "articles",
        "FieldMap": { "Id":"id","Title":"title","PublishedDate":"created_at","SourceUrl":"html_url","RawBody":"body" } } ] }
  ]
}
'@ | Set-Content -LiteralPath $mixedConfig
    $argList = @(
        '-NoProfile', '-File', (Join-Path -Path $repoRoot -ChildPath 'tasks/VendorMonitor/Run.ps1')
        '-ConfigPath', $mixedConfig
        '-SettingsPath', $settings
        '-OutputPath', $outDir
        '-StatePath', $stateDir
        '-Baseline'
    )
    & pwsh @argList 2>&1 | Out-Null
    $rc = $LASTEXITCODE
    $sum = Read-Summary
    $ok5 = ($rc -eq 0) -and $sum -and ($sum.summary.counts.errors -eq 1) -and ($sum.summary.counts.items -eq 105) -and ($sum.summary.errors.Count -eq 1) -and ($sum.summary.errors[0].vendor -eq 'BrokenVendor')
    Add-Result 'Per-vendor isolation (broken + good vendor)' $ok5 "exit=$rc errors=$($sum.summary.counts.errors) items=$($sum.summary.counts.items) badVendor=$($sum.summary.errors[0].vendor)"
    Remove-Item -LiteralPath $mixedConfig -Force -ErrorAction SilentlyContinue

    # ---------- Scenario 6: artifacts present ----------
    $expected = @('VendorReport.json','VendorReport.md','ExecutionLog.txt','vendor-state.json')
    $present = $expected | ForEach-Object {
        $p = if ($_ -eq 'vendor-state.json') { Join-Path -Path $stateDir -ChildPath $_ } else { Join-Path -Path $outDir -ChildPath $_ }
        @{ Name = $_; Present = (Test-Path -LiteralPath $p -PathType Leaf) }
    }
    $missing = @($present | Where-Object { -not $_.Present })
    $allPresent = ($missing.Count -eq 0)
    $detail = ($present | ForEach-Object { "$($_.Name)=$($_.Present)" }) -join ' '
    Add-Result 'All expected artifacts present' $allPresent $detail

    # ---------- Summary ----------
    Write-Host ''
    $pass = @($results | Where-Object { $_.Pass }).Count
    $fail = @($results | Where-Object { -not $_.Pass }).Count
    Write-Host "=================== $pass passed, $fail failed ==================="
    if ($fail -gt 0) { exit 1 }
    Remove-TestDir
    exit 0
}
catch {
    Write-Host "[FAIL] $($_.Exception.Message)"
    exit 1
}
