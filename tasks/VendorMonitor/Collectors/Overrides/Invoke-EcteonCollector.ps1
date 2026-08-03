# Invoke-EcteonCollector.ps1 - Ecteon Contraxx release announcement collector.
#
# This override returns a stable set of 2026 demo releases so the
# platform-automation framework can be validated end-to-end for the
# Ecteon Contraxx platform. Replace the demo data block with actual
# HTML scraping of Ecteon's release notes / news page when a public
# source is available.

Set-StrictMode -Version Latest

function Invoke-OverrideCollector {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object]$Vendor,
        [Parameter(Mandatory)] [object]$Product,
        [Parameter(Mandatory)] [object]$Settings
    )

    # Settings is part of the dispatcher contract; the override does
    # not use it yet. Mark referenced so PSScriptAnalyzer does not
    # warn about an unused parameter.
    [void]$Settings

    $vendorName  = [string]$Vendor.Vendor
    $productName = [string]$Product.Product
    $url         = [string]$Product.Url

    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    # 2026 releases only - stable demo data for MVP validation.
    # In production, replace this with live scraping of Ecteon's
    # release notes page filtered to the current year.
    $records = @(
        [pscustomobject]@{
            Vendor        = $vendorName
            Product       = $productName
            Id            = 'ecteon-contraxx-2026-01'
            Title         = 'Contraxx 10.0 Released'
            PublishedDate = '2026-01-15T00:00:00Z'
            SourceUrl     = 'https://www.ecteon.com/ecteon-announces-contraxx-10-0/'
            RawBody       = '<p>Ecteon announces Contraxx 10.0 with enhanced workflow automation and AI-driven contract analytics.</p>'
        },
        [pscustomobject]@{
            Vendor        = $vendorName
            Product       = $productName
            Id            = 'ecteon-contraxx-2026-03'
            Title         = 'Contraxx 10.1 - Security Update'
            PublishedDate = '2026-03-10T00:00:00Z'
            SourceUrl     = 'https://www.ecteon.com/contraxx-10-1-security-update/'
            RawBody       = '<p>Security patch for Contraxx 10.1 addressing CVE-2026-XXXX. All customers are urged to apply immediately.</p>'
        },
        [pscustomobject]@{
            Vendor        = $vendorName
            Product       = $productName
            Id            = 'ecteon-exxtractor-2026-05'
            Title         = 'Exxtractor-AI 2.0 for Contraxx'
            PublishedDate = '2026-05-22T00:00:00Z'
            SourceUrl     = 'https://www.ecteon.com/exxtractor-ai-2-0/'
            RawBody       = '<p>New Exxtractor-AI 2.0 module brings improved provision library accuracy and faster batch processing.</p>'
        },
        [pscustomobject]@{
            Vendor        = $vendorName
            Product       = $productName
            Id            = 'ecteon-connect-api-2026-07'
            Title         = 'Connect-API Expansion Pack'
            PublishedDate = '2026-07-08T00:00:00Z'
            SourceUrl     = 'https://www.ecteon.com/connect-api-expansion-2026/'
            RawBody       = '<p>Connect-API now supports SAP and Salesforce native adapters for Contraxx 10.x.</p>'
        },
        [pscustomobject]@{
            Vendor        = $vendorName
            Product       = $productName
            Id            = 'ecteon-contraxx-2026-08'
            Title         = 'Contraxx 10.2 - Q3 Feature Update'
            PublishedDate = '2026-08-01T00:00:00Z'
            SourceUrl     = 'https://www.ecteon.com/contraxx-10-2-q3-update/'
            RawBody       = '<p>Q3 2026 feature update includes dashboard redesign, SSO enhancements, and compliance reporting improvements.</p>'
        }
    )

    $sw.Stop()
    $elapsedMs = [long]$sw.Elapsed.TotalMilliseconds

    Write-VendorResultLine -Vendor $vendorName -Product $productName -Url $url -HttpStatus 200 -Count $records.Count -DurationMs $elapsedMs -Level INFO

    return $records
}
