# Invoke-RLDatixCollector.ps1 - RLDatix RL6 S3 XML release collector.
#
# Fetches the two public S3 XML feeds (Enhancements, Fixes), parses
# them with [xml], groups rows by ReleaseNumber, and emits one
# normalized record per version matching the Invoke-OverrideCollector
# contract that Run.ps1 dispatches to.

Set-StrictMode -Version Latest

function Invoke-OverrideCollector {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object]$Vendor,
        [Parameter(Mandatory)] [object]$Product,
        [Parameter(Mandatory)] [object]$Settings
    )

    # Settings are not used directly in this collector, but we keep the parameter
    # to conform to the collector contract.
    [void]$Settings

    $vendorName  = [string]$Vendor.Vendor
    $productName = [string]$Product.Product
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    $baseUrl = 'https://elasticbeanstalk-us-east-1-420057813367.s3.amazonaws.com/Release_Notes/RL6/release_notes_files/xml'
    $landingPage = 'https://elasticbeanstalk-us-east-1-420057813367.s3.amazonaws.com/Release_Notes/RL6/RL6_releasenotes.html'
    $feeds = @(
        @{ Url = "$baseUrl/Enhancements%20and%20Changes.xml"; Label = 'Enhancements' }
        @{ Url = "$baseUrl/Fixes.xml";                       Label = 'Fixes' }
    )

    $httpTimeout = if ($Settings.Http -and $Settings.Http.TimeoutSec) { [int]$Settings.Http.TimeoutSec } else { 30 }
    $httpRetries = if ($Settings.Http -and $Settings.Http.Retries)   { [int]$Settings.Http.Retries   } else { 3 }
    $userAgent   = if ($Settings.Http -and $Settings.Http.UserAgent) { [string]$Settings.Http.UserAgent } else { 'platform-automation/1.0' }

    $allRows = New-Object System.Collections.Generic.List[object]
    $httpStatus = 200
    foreach ($feed in $feeds) {
        $resp = Invoke-HttpGetWithRetry -Uri $feed.Url -Retries $httpRetries -TimeoutSec $httpTimeout -UserAgent $userAgent
        if (-not $resp.Success) {
            $httpStatus = $resp.StatusCode
            Write-Log -Message "RLDatix collector: $($feed.Label) feed returned HTTP $($resp.StatusCode): $($resp.Error)" -Level WARN
            continue
        }
        try {
            $xml = [xml]$resp.Content
            $rows = @($xml.ROWSET.ROW)
            $label = $feed.Label
            foreach ($row in $rows) {
                $rn = [string]$row.ReleaseNumber
                if ([string]::IsNullOrWhiteSpace($rn)) { continue }
                $allRows.Add([pscustomobject]@{
                    ReleaseNumber = $rn.Trim()
                    SummaryTitle  = ([string]$row.SummaryTitle).Trim()
                    Summary       = ([string]$row.Summary).Trim()
                    Product       = ([string]$row.Product).Trim()
                    Functionality = ([string]$row.Functionality).Trim()
                    RlRefNumber   = ([string]$row.RLRefNumber).Trim()
                    Feed          = $label
                })
            }
        }
        catch {
            Write-Log -Message "RLDatix collector: failed to parse $($feed.Label) XML: $($_.Exception.Message)" -Level ERROR
        }
    }

    $grouped = $allRows.ToArray() | Group-Object -Property ReleaseNumber

    $records = New-Object System.Collections.Generic.List[object]
    foreach ($g in $grouped) {
        $version = $g.Name
        $enhancements = @($g.Group | Where-Object { $_.Feed -eq 'Enhancements' })
        $fixes        = @($g.Group | Where-Object { $_.Feed -eq 'Fixes' })
        $modules = $g.Group |
            ForEach-Object { $_.Product } |
            Where-Object { $_ -and $_ -ne ',' } |
            ForEach-Object { $_ -split ',' } |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ } |
            Sort-Object -Unique

        $enhCount = $enhancements.Count
        $fixCount = $fixes.Count
        $moduleStr = if ($modules.Count -gt 0) { $modules -join ', ' } else { '' }

        $title = "RL6 $version"
        $id = "rl6-$version"
        $summaryHtml = "<p><strong>RL6 $version</strong> &mdash; $enhCount enhancement(s), $fixCount fix(es)</p>"
        if ($moduleStr) { $summaryHtml += "<p>Affected modules: $moduleStr</p>" }
        if ($version -match '^\d+\.\d+\.\d+$') { $summaryHtml += '<p><em>Hotfix release.</em></p>' }

        $records.Add([pscustomobject]@{
            Vendor        = $vendorName
            Product       = $productName
            Id            = $id
            Title         = $title
            PublishedDate = ''
            SourceUrl     = $landingPage
            RawBody       = $summaryHtml
        })
    }

    $sw.Stop()
    $elapsedMs = [long]$sw.Elapsed.TotalMilliseconds

    Write-VendorResultLine -Vendor $vendorName -Product $productName -Url $landingPage -HttpStatus $httpStatus -Count $records.Count -DurationMs $elapsedMs -Level INFO
    return $records.ToArray()
}
