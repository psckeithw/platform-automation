# Invoke-OneSpanCollector.ps1 - OneSpan Sign release notes collector.
#
# Fetches the public OneSpan Sign release notes page
# (https://docs.onespan.com/docs/onespan-sign-release-notes), parses
# the embedded article metadata, and emits one normalized record per
# release matching the Invoke-OverrideCollector contract that Run.ps1
# dispatches to.

Set-StrictMode -Version Latest

function Invoke-OverrideCollector {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object]$Vendor,
        [Parameter(Mandatory)] [object]$Product,
        [Parameter(Mandatory)] [object]$Settings
    )

    [void]$Settings

    $vendorName  = [string]$Vendor.Vendor
    $productName = [string]$Product.Product
    $url         = [string]$Product.Url
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    $httpTimeout = if ($Settings.Http -and $Settings.Http.TimeoutSec) { [int]$Settings.Http.TimeoutSec } else { 30 }
    $httpRetries = if ($Settings.Http -and $Settings.Http.Retries)   { [int]$Settings.Http.Retries   } else { 3 }
    $userAgent   = if ($Settings.Http -and $Settings.Http.UserAgent) { [string]$Settings.Http.UserAgent } else { 'platform-automation/1.0' }

    $resp = Invoke-HttpGetWithRetry -Uri $url -Retries $httpRetries -TimeoutSec $httpTimeout -UserAgent $userAgent
    $httpStatus = $resp.StatusCode

    if (-not $resp.Success) {
        $msg = "OneSpan collector: HTTP $($resp.StatusCode) - $($resp.Error)"
        Write-Log -Message $msg -Level ERROR
        Write-VendorResultLine -Vendor $vendorName -Product $productName -Url $url -HttpStatus $httpStatus -Count 0 -DurationMs 0 -Level ERROR -ErrorMessage $msg
        throw $msg
    }

    $html = $resp.Content
    $records = New-Object System.Collections.Generic.List[object]

    $slugTitlePattern = 'slug":"(release-[^"]+)","title":"([^"]+)"'
    $matches = [regex]::Matches($html, $slugTitlePattern)
    $seen = @{}
    foreach ($m in $matches) {
        $slug = $m.Groups[1].Value
        $title = $m.Groups[2].Value
        if ($seen.ContainsKey($slug)) { continue }
        $seen[$slug] = $true
        if ($title -notmatch '^Release \d+\.R') { continue }
        $sourceUrl = "https://docs.onespan.com/docs/$slug.md"
        $records.Add([pscustomobject]@{
            Vendor        = $vendorName
            Product       = $productName
            Id            = $slug
            Title         = $title
            PublishedDate = ''
            SourceUrl     = $sourceUrl
            RawBody       = ''
        })
    }

    $sw.Stop()
    $elapsedMs = [long]$sw.Elapsed.TotalMilliseconds

    Write-VendorResultLine -Vendor $vendorName -Product $productName -Url $url -HttpStatus $httpStatus -Count $records.Count -DurationMs $elapsedMs -Level INFO
    return $records.ToArray()
}
