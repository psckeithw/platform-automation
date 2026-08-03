# HtmlCollector.ps1 - public HTML page collector (FUTURE STUB).
#
# This file is dot-sourced by Run.ps1 when a vendor entry declares
# Collector = 'HtmlCollector'. It defines Invoke-HtmlCollector so the
# dispatcher contract is complete; the actual implementation is
# post-MVP per docs/mvp-supplemental-plan.md §O and throws a clear
# NotImplemented so the per-vendor try/catch in Run.ps1 can log it.
#
# Implementation notes (for whoever picks this up next):
#   * Use Invoke-HttpGetWithRetry from Common.psm1 to fetch the
#     page; capture the raw HTML into output/<Vendor>-<Product>-<id>.html
#     for traceability (capped via Settings.Output.MaxRawItems).
#   * Parse with the future selector engine; today the simplest
#     path is Select-String on item-level lines until Html.psm1
#     grows a real parser.
#   * Map each match to the normalized record shape:
#       Vendor, Product, Id (hash of URL + selector match if no
#       stable id is on the page), Title, PublishedDate (parse with
#       the date format the vendor uses), SourceUrl, RawBody
#       (the matched HTML snippet).
#   * Items without a stable Id rely on the content-hash key path
#     in State.psm1 (see Get-RecordKey).

Set-StrictMode -Version Latest

function Invoke-HtmlCollector {
    <#
    .SYNOPSIS
        Fetch a public HTML page and return normalized records.
    .DESCRIPTION
        FUTURE STUB. Throws 'NotImplemented: HtmlCollector is a
        future collector' so Run.ps1 can record the failure cleanly.
        See the file header for the implementation outline.
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
    $vendorName  = [string]$Vendor.Vendor
    $productName = [string]$Product.Product
    throw "NotImplemented: HtmlCollector is a future collector (vendor=$vendorName product=$productName). See tasks/VendorMonitor/Collectors/HtmlCollector.ps1 for the implementation outline."
}
