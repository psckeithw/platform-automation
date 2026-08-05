# Outputs

Every run produces the same set of artifacts in `output/`. The pipeline publishes them as the `platform-automation-output` artifact.

## Files written

| File                       | Purpose                                                                                          |
| -------------------------- | ------------------------------------------------------------------------------------------------ |
| `output/VendorReport.json` | Machine-readable run summary and per-item records. The canonical artifact.                       |
| `output/VendorReport.md`   | Human-readable report. Rendered on the Azure DevOps run Summary tab.                             |
| `output/ExecutionLog.txt`  | Full structured log: start/end timestamps, per-vendor HTTP status, errors, summary.              |
| `output/<Vendor>-<Product>-<Id>.html` | Styled HTML capture of up to `Output.MaxRawItems` NEW/CHANGED records. For traceability. |
| `state/vendor-state.json`  | (Not in `output/`.) The new state map. Published separately as `platform-automation-state`.      |

`output/` is gitignored locally. On the pipeline it lives in the build agent's staging directory for the run and is published as an artifact.

## `VendorReport.json` shape

```
{
  "generatedAt": "<ISO 8601 UTC Z>",
  "summary": {
    "generatedAt":  "<ISO 8601 UTC Z>",
    "isBaseline":   <bool>,
    "forceRecheck": <bool>,
    "counts": {
      "vendors":   <int>,
      "items":     <int>,
      "new":       <int>,
      "changed":   <int>,
      "unchanged": <int>,
      "baseline":  <int>,
      "rechecks":  <int>,
      "errors":    <int>
    },
    "errors": [
      { "Vendor": "<name>", "Product": "<name or ''>", "Error": "<message>" },
      ...
    ]
  },
  "items": [
    {
      "vendor":         "<name>",
      "product":        "<name>",
      "title":          "<release title>",
      "publishedDate":  "<ISO 8601 UTC Z or original string>",
      "detectedAt":     "<ISO 8601 UTC Z>",
      "sourceUrl":      "<canonical URL>",
      "changeDetected": "BASELINE | NEW | CHANGED | UNCHANGED | RECHECK | ERROR"
    },
    ...
  ]
}
```

Every entry from every collector appears in `items[]` regardless of status. `errors[]` only contains per-vendor or per-product hard failures; per-record errors are tagged `ERROR` in `items[]` and counted in `summary.counts.errors`.

## `VendorReport.md` shape

- Header: `Generated: <timestamp>`, `Mode: baseline | diff | force-recheck`, and a one-line counts summary.
- Table `## NEW / CHANGED`: every record whose `ChangeStatus` is one of `NEW`, `CHANGED`, `BASELINE`, or `RECHECK`, sorted by status (desc) then `publishedDate`. Columns: Vendor, Product, Published, Title (truncated to 80 chars), Status, URL.
- Section `## Errors`: a table of `Vendor | Product | Error` for every hard failure.

When `Mode: baseline`, every record is in the table — that is by design, so an operator can eyeball the first run.

## `ExecutionLog.txt` shape

Plain text, one line per record. UTC timestamps in ISO 8601 with `Z`. Levels are `INFO`, `WARN`, `ERROR`, `DEBUG`. Format:

```
<timestamp> [<LEVEL>][<TaskName>] <Message> key=value key=value ...
```

Key examples: `vendor`, `product`, `url`, `httpStatus`, `count`, `durationMs`, `error`.

The log always starts with a `run start` line and ends with a `run end durationMs=<n>` line.

## Azure DevOps run Summary tab

`Logging.psm1` (`Add-RunSummary`) emits the ADO logging command `##vso[task.addattachment type=Distributedtask.Core.Summary;name=VendorReport;]<abs-path>` so `VendorReport.md` is rendered on the run's Summary tab. The command is a no-op locally.

If any items are `NEW`, an additional `##vso[task.logissue type=warning]` line is emitted so the run shows up with a yellow warning badge even when the run exits 0.

## Pipeline artifacts

The pipeline publishes two artifacts per run:

- `platform-automation-output` — `output/` directory.
- `platform-automation-state`  — `state/vendor-state.json` only, so it can be inspected without downloading the full report bundle.

Both are published with `condition: always()` so they exist even when the run fails midway.

## Captures

`Output.CaptureRawHtml: true` enables per-record HTML captures. Each capture:

- Wraps the `RawBody` in a styled HTML5 document via `ConvertTo-HtmlDocument` from `modules/Html.psm1`.
- Sets the visible header to `<Vendor> / <Product> - <Title>`.
- Adds a footer with the capture timestamp and a `source` link to `SourceUrl`.
- Filename is sanitized via `ConvertTo-SafeFileName` so it is safe on Windows and Linux.

`Output.MaxRawItems` is a hard cap across all vendors and products in the run. Set to `0` to disable.
