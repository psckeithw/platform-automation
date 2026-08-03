# RssCollector.ps1 - RSS/Atom feed collector (FUTURE STUB).
#
# This file is dot-sourced by Run.ps1 when a vendor entry declares
# Collector = 'RssCollector'. It defines Invoke-RssCollector so the
# dispatcher contract is complete; the actual implementation is
# post-MVP per docs/mvp-supplemental-plan.md §O and throws a clear
# NotImplemented so the per-vendor try/catch in Run.ps1 can log it.
#
# Implementation notes (for whoever picks this up next):
#   * Use Invoke-HttpGetWithRetry from Common.psm1 to fetch the feed.
#   * Parse the XML with [xml]; namespaces vary by source.
#   * Map each <item>/<entry> to the normalized record shape:
#       Vendor, Product, Id (use <guid> when stable, else the link),
#       Title, PublishedDate (normalize via ConvertTo-UtcIso8601),
#       SourceUrl, RawBody (optional, for excerpts).
#   * Pagination is rare for RSS but the feed may be huge; cap item
#     count via Settings.Collector.MaxItems (add to settings.json).

Set-StrictMode -Version Latest

function Invoke-RssCollector {
    <#
    .SYNOPSIS
        Fetch an RSS/Atom feed and return normalized records.
    .DESCRIPTION
        FUTURE STUB. Throws 'NotImplemented: RssCollector is a future
        collector' so Run.ps1 can record the failure cleanly. See the
        file header for the implementation outline.
    .PARAMETER Vendor
        The vendor config object (Vendors[i]).
    .PARAMETER Product
        The product config object (Vendors[i].Products[j]).
    .PARAMETER Settings
        The full settings object from config/settings.json.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object]$Vendor,
        [Parameter(Mandatory)] [object]$Product,
        [Parameter(Mandatory)] [object]$Settings
    )
    # Settings is part of the dispatcher contract; the stub does
    # not use it yet. Mark referenced so PSScriptAnalyzer does not
    # warn about an unused parameter in the future collector.
    [void]$Settings
    $vendorName  = [string]$Vendor.Vendor
    $productName = [string]$Product.Product
    throw "NotImplemented: RssCollector is a future collector (vendor=$vendorName product=$productName). See tasks/VendorMonitor/Collectors/RssCollector.ps1 for the implementation outline."
}
