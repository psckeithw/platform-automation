# Architecture

End-to-end design of the platform-automation framework as it exists today. The single shipped task is `VendorMonitor`; the framework is structured so additional tasks can be added without changing the pipeline.

## Layers

There are four layers. Each layer talks only to the one below it.

1. **Pipeline** — `azure-pipelines/vendor-monitor.yml`. Owns schedule, parameters, checkout, run, artifact publish, and the commit/push of state to the `vendor-state` branch. No business logic.
2. **Entry point** — `tasks/VendorMonitor/Run.ps1`. Loads config and prior state, walks every enabled vendor/product through its collector, diffs results, writes reports, persists new state, and (when NEW items are found) publishes User Stories to Azure DevOps. Per-vendor and per-item try/catch isolates failures so one bad vendor or one bad ADO POST never aborts the run.
3. **Collectors** — `tasks/VendorMonitor/Collectors/`. Each collector turns one vendor/product config into an array of normalized records. `ApiCollector` is implemented. `HtmlCollector` and `RssCollector` are stubs. Vendor-specific overrides live in `Collectors/Overrides/` (the RLDatix S3 collector is one such override).
4. **Framework modules** — `modules/`. Pure helpers, no business logic. `Common.psm1` (config loading, HTTP with retry, paginated JSON, paths, UTC time), `Logging.psm1` (structured logs + ADO logissue commands + log file), `State.psm1` (read/write/compare vendor state), `Html.psm1` (HTML-to-text and styled capture wrapper), `AdoWorkItem.psm1` (initialize ADO config from `.env` and POST User Stories).

## Per-run sequence

1. Pipeline checks out `main`, fetches the prior `state/vendor-state.json` from the `vendor-state` branch (or detects cold start), runs `Run.ps1`, publishes `output/` as `platform-automation-output` and `state/` as `platform-automation-state`, then commits the updated state back to `vendor-state`.
2. `Run.ps1` boots: `Import-Framework` (all modules), `Start-TaskLog`, ensures the output directory exists, reads the timestamp.
3. Config is loaded and validated. Vendors are filtered by `Enabled` and the optional `-Vendor` parameter.
4. For each vendor, the collector is resolved. The vendor entry may specify `Collector: "Name"` (a built-in, dot-sources `Collectors/Name.ps1`, looks for `Invoke-Name`) or `Script: "path/to/file.ps1"` (dot-sources the script, looks for `Invoke-OverrideCollector`).
5. For each product under that vendor, the collector is called with `-Vendor`, `-Product`, `-Settings`. It returns normalized records.
6. Records are diffed against the previous state map. Each is tagged `BASELINE`, `NEW`, `CHANGED`, `UNCHANGED`, `RECHECK`, or `ERROR`. The new state map is computed.
7. The JSON report, the Markdown report, the execution log, and (optionally) up to `Output.MaxRawItems` styled HTML captures are written.
8. `Add-RunSummary` emits the ADO `##vso[task.addattachment]` command so the Markdown report appears on the pipeline run's Summary tab.
9. If any items are NEW, the run imports `modules/AdoWorkItem.psm1` (on demand) and for each NEW item calls `New-AdoWorkItem` with the title and an HTML description linking to `SourceUrl`. Failures are isolated per item and recorded in the run summary's `errors[]`.
10. If any items are NEW, a warning log line is emitted so the run surfaces prominently in the pipeline UI.
11. `Save-CurrentState` writes `state/vendor-state.json` atomically (write `.tmp`, then rename).
12. `Stop-TaskLog` flushes the in-memory buffer to `output/ExecutionLog.txt`.
13. Pipeline commits the updated state file to the `vendor-state` branch with `[skip ci]`.

## Per-vendor and per-item isolation

`Run.ps1` wraps every collector setup, every product invocation, and every ADO publish in its own try/catch. A hard failure in any one of them adds a row to the run summary's `errors[]`, emits an ADO `task.logissue type=error`, and continues. The framework exits with code 1 only on a framework-level error (config missing, module load failure, etc.).

## State boundary

`State.psm1` is the single seam between the rest of the framework and the on-disk state format. Every read and write of `vendor-state.json` goes through it. The on-disk shape can change without touching collectors or `Run.ps1`; a future Azure Blob (or database) backend is a drop-in replacement of these functions and nothing else.

The state branch is dedicated: `main` never receives the state file. Branch policies on `main` (if any) are unaffected.

## Normalized record shape

Every collector returns the same shape so downstream diffing, reporting, and US creation can treat all vendors uniformly:

```
Vendor         string   vendor name from config
Product        string   product name from config
Id             string   stable record id when present, else ''
Title          string   release title
PublishedDate  string   ISO 8601 UTC, suffix Z (e.g. 2026-07-06T15:05:15Z)
SourceUrl      string   canonical link to the release notes
RawBody        string   optional HTML or text body; used for styled captures and excerpts
```

## What lives where

| Concern              | Location                                                    |
| -------------------- | ----------------------------------------------------------- |
| Schedule, params     | `azure-pipelines/vendor-monitor.yml`                        |
| Orchestration        | `tasks/VendorMonitor/Run.ps1`                               |
| Vendor/product data  | `config/vendors.json`                                       |
| Tunable behavior     | `config/settings.json`                                      |
| Secrets / per-run hints | `.env` (gitignored)                                      |
| Collector contract   | `tasks/VendorMonitor/Collectors/README.md` (in the file, not docs/) |
| Built-in collectors  | `tasks/VendorMonitor/Collectors/ApiCollector.ps1`           |
| Future collectors    | `tasks/VendorMonitor/Collectors/{Html,Rss}Collector.ps1`    |
| Vendor overrides     | `tasks/VendorMonitor/Collectors/Overrides/`                |
| HTTP, JSON, config   | `modules/Common.psm1`                                       |
| Logging              | `modules/Logging.psm1`                                      |
| Change detection     | `modules/State.psm1`                                        |
| HTML helpers         | `modules/Html.psm1`                                         |
| ADO publish          | `modules/AdoWorkItem.psm1`                                  |
| Local e2e check      | `scripts/verify-e2e.ps1`                                    |
| RLDatix S3 handoff   | `docs/HANDOFF-rldatix-s3-notification.md`                   |
| State file           | `state/vendor-state.json` (gitignored locally, branch-only) |
| Run artifacts        | `output/`                                                   |
