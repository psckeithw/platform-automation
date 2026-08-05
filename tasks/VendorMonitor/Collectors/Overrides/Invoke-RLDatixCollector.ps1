# Invoke-RLDatixCollector.ps1 - RLDatix public release announcement collector.
#
# Replaces the demo Ecteon/Contraxx placeholder with a real pull from the
# public RLDatix knowledge base (Zendesk Help Center, no authentication).
#
# Two sections are monitored:
#   19851648629532 - Release Notes
#   19851690858140 - Announcements
#
# The Zendesk listing endpoint returns the most-recently-updated articles
# first. For each article we emit one normalized record with:
#   Vendor=RLDatix
#   Product=intelligentcontract (or 'intelligentcontract - ReleaseNote' /
#           'intelligentcontract - Announcement' so callers can tell them
#           apart in reports and notifications)
#   Id=Zendesk article id (used as the stable record key)
#   Title=article.title
#   PublishedDate=article.updated_at (ISO 8601 UTC)
#   SourceUrl=article.html_url
#   RawBody=article.body (the article HTML, optional)
#
# Test mode (-TopN 1): only the first record from each section is
# returned. This is what the VendorMonitor -TestMode flag uses so the
# notify path can be exercised end-to-end without waiting for a new
# release.

Set-StrictMode -Version Latest

$Script:RLDatixSections = @(
    @{ SectionId = '19851648629532'; Product = 'intelligentcontract - ReleaseNote' }
    @{ SectionId = '19851690858140'; Product = 'intelligentcontract - Announcement' }
)

function Invoke-OverrideCollector {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)] [object]$Vendor,
        [Parameter(Mandatory)] [object]$Product,
        [Parameter(Mandatory)] [object]$Settings,
        [int]$TopN = 0
    )

    $vendorName = [string]$Vendor.Vendor
    $sectionId  = [string]$Product.SectionId
    $productName = [string]$Product.Product

    if ([string]::IsNullOrWhiteSpace($sectionId)) {
        throw "RLDatixCollector[$vendorName/$productName]: SectionId is required."
    }

    $ua = 'platform-automation/1.0'
    $timeout = 30
    if ($Settings -and $Settings.Http) {
        if ($Settings.Http.UserAgent)  { $ua = [string]$Settings.Http.UserAgent }
        if ($Settings.Http.TimeoutSec) { $timeout = [int]$Settings.Http.TimeoutSec }
    }

    # Test mode cap: collector pulls only the first N articles from
    # the section so the notifier can be exercised end-to-end without
    # waiting for a real release. Honoured when Settings.Notify.TopNTestMode
    # is a positive integer (Run.ps1 sets this when -TestMode is passed).
    $topN = 0
    if ($Settings -and $Settings.PSObject.Properties['Notify'] -and $Settings.Notify.PSObject.Properties['TopNTestMode']) {
        $topN = [int]$Settings.Notify.TopNTestMode
    }
    if ($TopN -gt 0) { $topN = $TopN }

    $perPage = if ($topN -gt 0) { $topN } else { 25 }
    $base = "https://rldatix-public.zendesk.com/api/v2/help_center/en-us/sections/$sectionId/articles.json"
    $url  = "$base`?per_page=$perPage&sort_by=updated_at&order=desc"

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $resp = Invoke-HttpGetWithRetry -Uri $url -Retries 3 -TimeoutSec $timeout -UserAgent $ua
    $sw.Stop()
    $elapsedMs = [long]$sw.Elapsed.TotalMilliseconds

    if (-not $resp.Success) {
        $err = "RLDatixCollector[$vendorName/$productName]: HTTP $($resp.StatusCode) - $($resp.Error)"
        Write-VendorResultLine -Vendor $vendorName -Product $productName -Url $url -HttpStatus $resp.StatusCode -Count 0 -DurationMs $elapsedMs -Level ERROR -ErrorMessage $err
        throw $err
    }

    try {
        $body = $resp.Content | ConvertFrom-Json -ErrorAction Stop
    } catch {
        $err = "RLDatixCollector[$vendorName/$productName]: invalid JSON - $($_.Exception.Message)"
        Write-VendorResultLine -Vendor $vendorName -Product $productName -Url $url -HttpStatus $resp.StatusCode -Count 0 -DurationMs $elapsedMs -Level ERROR -ErrorMessage $err
        throw $err
    }

    $articles = @($body.articles)
    if ($topN -gt 0 -and $articles.Count -gt $topN) {
        $articles = $articles[0..($topN - 1)]
    }

    $records = New-Object System.Collections.Generic.List[object]
    foreach ($a in $articles) {
        $published = ''
        if ($a.updated_at) {
            try {
                $published = ([datetime]$a.updated_at).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
            } catch { $published = [string]$a.updated_at }
        }

        $records.Add([pscustomobject]@{
            Vendor        = $vendorName
            Product       = $productName
            Id            = [string]$a.id
            Title         = [string]$a.title
            PublishedDate = $published
            SourceUrl     = [string]$a.html_url
            RawBody       = [string]$a.body
        })
    }

    Write-VendorResultLine -Vendor $vendorName -Product $productName -Url $url -HttpStatus $resp.StatusCode -Count $records.Count -DurationMs $elapsedMs -Level INFO
    return $records.ToArray()
}
