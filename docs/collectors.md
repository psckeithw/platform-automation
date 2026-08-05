# Collectors

A collector turns one `(vendor, product)` pair from `config/vendors.json` into an array of normalized records. Everything past that point is generic.

## Built-in collectors

| Collector       | Status          | Purpose                                              |
| --------------- | --------------- | ---------------------------------------------------- |
| `ApiCollector`  | Implemented     | Generic paginated JSON API; declarative via `Url`, `ItemsPath`, `FieldMap`. |
| `HtmlCollector` | Stub (throws)   | Public HTML page scraping; not yet implemented.      |
| `RssCollector`  | Stub (throws)   | RSS / Atom feed parsing; not yet implemented.        |

The stubs define the dispatcher-contract function (`Invoke-HtmlCollector`, `Invoke-RssCollector`) and throw `NotImplemented` so the per-vendor try/catch in `Run.ps1` records the failure cleanly. The implementation outlines live in the file headers and in `roadmap.md`.

## Script overrides

When a vendor's source cannot be described declaratively (complex HTML, authenticated endpoints, multi-step flows), set `Collector: null` and `Script: "relative/path/to/file.ps1"`. The script is dot-sourced by `Run.ps1` and must define a function named `Invoke-OverrideCollector` with the dispatcher contract below.

The `Script` field is the escape hatch. Prefer extending `ApiCollector` or building a new generic collector before reaching for it.

The shipped example is `Collectors/Overrides/Invoke-EcteonCollector.ps1`, which returns a hardcoded set of five 2026 Ecteon Contraxx releases. It exists to exercise the full pipeline end-to-end until a real Ecteon source is identified.

## Dispatcher contract

Every collector function MUST have this signature:

```
Invoke-<Name>Collector -Vendor <object> -Product <object> -Settings <object>
```

(or `Invoke-OverrideCollector` for a `Script` override)

It MUST return an array of normalized records:

```
Vendor         string
Product        string
Id             string   stable id when present, else ''
Title          string
PublishedDate  string   ISO 8601 UTC, suffix Z
SourceUrl      string
RawBody        string   optional; used for HTML captures and excerpts
```

It MUST log exactly one `Write-VendorResultLine` per call with the fields `vendor`, `product`, `url`, `httpStatus`, `count`, `durationMs` (and `error` on failure). It MUST throw on a hard failure so the per-vendor try/catch isolates the error.

## Adding a vendor

For a JSON API source (the most common case):

1. Append an entry to `config/vendors.json`:

   ```json
   {
     "Vendor": "RLDatix",
     "Enabled": true,
     "Collector": "ApiCollector",
     "Products": [
       {
         "Product": "IntelligentContract",
         "Url": "https://rldatix-public.zendesk.com/api/v2/help_center/en-us/sections/19851648629532/articles.json?sort_by=created_at&sort_order=desc&per_page=100",
         "ItemsPath": "articles",
         "FieldMap": {
           "Id":            "id",
           "Title":         "title",
           "PublishedDate": "created_at",
           "SourceUrl":     "html_url",
           "RawBody":       "body"
         }
       }
     ]
   }
   ```

2. No code change. No pipeline change. The next run picks it up.

3. Verify locally with `-Baseline` first to seed the state, then a second run should report everything as `UNCHANGED`.

Set `Enabled: false` to suspend a vendor without removing it.

For a custom source, write `tasks/VendorMonitor/Collectors/Overrides/Invoke-<Vendor>.ps1`, set `Script` to that path, and implement the contract.

## How `ApiCollector` works

`ApiCollector.ps1` (dot-sourced by `Run.ps1`) defines `Invoke-ApiCollector`. Per product:

1. Resolves `Url`, `ItemsPath`, `FieldMap` from the product config and `MaxPages`, `UserAgent`, `TimeoutSec`, `Retries` from `settings.json`.
2. Calls `Get-JsonPaged` from `Common.psm1`. `Get-JsonPaged` follows the response's `next_page` field up to `MaxPages` pages, aggregating the array at the dotted `ItemsPath` in each page. It returns `{ Success, StatusCode, Error, Pages, Items }`.
3. For each raw item, reads each `FieldMap` field via `Get-FieldMapValue` (handles strings, dates, numbers, nested objects; empty results become `''`).
4. Normalizes the `PublishedDate` via `ConvertTo-UtcIso8601` which accepts ISO 8601, Zendesk `MM/dd/yyyy HH:mm:ss`, and Unix epoch seconds. Unparseable values pass through unchanged so they still surface in the report.
5. Builds the normalized record and appends it to the result array.
6. Logs one `Write-VendorResultLine` with the HTTP status and record count.

`Get-JsonPaged` is retry-aware: it uses `Invoke-HttpGetWithRetry` per page, so transient 5xx / 429 / network errors are retried with exponential backoff before the call is considered failed.

## Adding a new generic collector type

When the source is JSON-ish but not a simple paginated array (e.g. a GraphQL endpoint, a feed with cursor pagination, or a public API whose response shape varies by product), build a new collector file:

1. Create `tasks/VendorMonitor/Collectors/<Name>Collector.ps1`.
2. Dot-source it from `Run.ps1` (already happens automatically via the dispatcher).
3. Define `Invoke-<Name>Collector` with the dispatcher contract.
4. Reference it from a vendor entry with `"Collector": "<Name>"`.
5. Add tests to `scripts/verify-e2e.ps1` if there is a public, stable source.

## Common pitfalls

- `Url` returning 200 but no `next_page` field — pagination is implicit; either rely on per-page completeness or switch to `HtmlCollector`/`RssCollector` once those are implemented.
- `Id` missing on every record — the state map will then key off the content hash, which means a title or date edit produces a `CHANGED` but a true duplicate produces two records (state key collision will not happen because the hash differs).
- `PublishedDate` in a format not covered by `ConvertTo-UtcIso8601` — the value passes through unchanged and the report shows it as-is. Extend the format list in `ApiCollector.ps1`.
- `RawBody` being huge — it is captured into HTML files only up to `Output.MaxRawItems`, but it lives in memory for the full run. For multi-megabyte bodies, consider truncating inside the collector.
