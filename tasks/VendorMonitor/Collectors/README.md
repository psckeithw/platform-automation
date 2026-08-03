# VendorMonitor/Collectors - collector contract and the Script escape hatch
#
# The framework dispatches a vendor/product to a collector based on the
# 'Collector' field in config/vendors.json. Run.ps1 looks up the
# function 'Invoke-<Collector>' and dot-sources
# tasks/VendorMonitor/Collectors/<Collector>.ps1 to define it.
#
# ## Built-in collectors
#   * ApiCollector   - generic, declarative JSON-API collector (T3.1).
#   * RssCollector   - FUTURE STUB. Throws NotImplemented.
#   * HtmlCollector  - FUTURE STUB. Throws NotImplemented.
#
# ## Dispatcher contract
# Every collector function MUST have this signature:
#
#   Invoke-<Name>Collector -Vendor <object> -Product <object> -Settings <object>
#
# It MUST return an array of normalized records:
#
#   [pscustomobject]@{
#     Vendor        = <string>
#     Product       = <string>
#     Id            = <string>     # stable id when present, else ''
#     Title         = <string>
#     PublishedDate = <string>     # ISO 8601 UTC 'Z' format
#     SourceUrl     = <string>
#     RawBody       = <string>     # optional, used for excerpts
#   }
#
# It MUST log one Write-VendorResultLine per call (vendor, product,
# url, httpStatus, count, durationMs). It MUST throw on a hard failure
# so the per-vendor try/catch in Run.ps1 isolates the error.
#
# ## The Script escape hatch
#
# Config-driven collectors cover any source that exposes a JSON API
# declaratively (ItemsPath + FieldMap). When that is not enough, a
# vendor entry may set:
#
#   {
#     "Vendor": "Acme",
#     "Collector": null,
#     "Script": "tasks/VendorMonitor/Collectors/Overrides/Invoke-Acme.ps1",
#     "Products": [ ... ]
#   }
#
# Run.ps1 dot-sources the file at 'Script' and expects it to define
# a function named 'Invoke-OverrideCollector' (the contract above,
# with a different function name so the override is unambiguous).
# The script returns the same normalized record shape. This keeps
# the dispatcher small (one lookup path) while letting a vendor
# ship fully custom code without changing the framework.
#
# Overrides are an escape hatch, not the default. Prefer a new
# generic collector or extending ApiCollector before reaching for
# the Script property.
