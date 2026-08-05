# Modules Reference

Five framework modules live in `modules/`. Each is a PowerShell module file (`.psm1`) imported by `Run.ps1` (or, for `AdoWorkItem.psm1`, by `Run.ps1` directly inside the publish block).

The modules own no business logic — they are helpers. All cross-cutting concerns (config loading, HTTP, time, state, logging, HTML, ADO) live here so collectors and `Run.ps1` can stay small.

## `Common.psm1`

The I/O and configuration choke point.

| Function                    | Purpose                                                                                  |
| --------------------------- | ---------------------------------------------------------------------------------------- |
| `Import-Framework`          | Imports every framework module from a directory. Idempotent.                              |
| `Get-Config`                | Loads a JSON file, returns the parsed object, optionally validates required top-level keys. |
| `Invoke-HttpGetWithRetry`   | HTTP GET with exponential backoff. Retries on network errors, 5xx, and 429. Never throws on an HTTP error — returns `{ StatusCode, Content, Success, Error }`. |
| `Get-JsonPaged`             | Walks a paginated JSON endpoint following `next_page`, up to `MaxPages`. Returns `{ Success, StatusCode, Error, Pages, Items }`. |
| `New-OutputDirectory`       | Ensures a directory exists, returns its resolved absolute path.                          |
| `ConvertTo-SafeFileName`    | Sanitizes a string for use as a cross-platform filename.                                 |
| `Get-UtcTimestamp`          | Returns the current UTC time as an ISO 8601 string ending in `Z`.                        |

Conventions enforced by this module:

- Every HTTP call goes through `Invoke-HttpGetWithRetry`. Callers must check `$result.Success` rather than catching exceptions.
- Every config file is loaded via `Get-Config`. Hardcoded URLs and vendor-specific strings are not allowed elsewhere.
- Every timestamp recorded in logs, reports, or state is produced by `Get-UtcTimestamp`.

## `Logging.psm1`

Structured logging and Azure DevOps visibility.

| Function                  | Purpose                                                                                |
| ------------------------- | -------------------------------------------------------------------------------------- |
| `Start-TaskLog`           | Begin a run. Initializes state and writes the `run start` line.                        |
| `Write-Log`               | Emit a structured log line (level: INFO/WARN/ERROR/DEBUG). WARN/ERROR also emit ADO `task.logissue` commands. |
| `Write-VendorResultLine`  | One-line summary of a collector invocation (vendor, product, url, httpStatus, count, durationMs, optional error). |
| `Add-RunSummary`          | Attach the Markdown report to the Azure DevOps run Summary tab via `task.addattachment`. |
| `Stop-TaskLog`            | End a run. Writes the buffered log to `ExecutionLog.txt` and returns elapsed ms.        |
| `Get-LogBuffer`           | Returns the current run's buffered lines (testing/diagnostics).                        |

Output rules:

- Timestamps are UTC ISO 8601 with `Z`.
- Lines on ADO agents carry `##vso[task.logissue ...]` so WARN/ERROR render with the right badge. The same lines are harmless plain text locally.
- The module never logs secret values. Callers scrub before passing a message.

State is held in module-level `$Script:` variables (`LogBuffer`, `StartTime`, `TaskName`, `LogFile`, `IsInRun`). `Start-TaskLog` initializes them; `Stop-TaskLog` flushes and resets.

## `State.psm1`

The persistence and change-detection boundary. This is the only module that reads or writes `vendor-state.json`.

| Function               | Purpose                                                                                       |
| ---------------------- | --------------------------------------------------------------------------------------------- |
| `Get-StateFilePath`    | Resolves `<StatePath>/vendor-state.json`, creating the directory if missing.                  |
| `Get-PreviousState`    | Reads the state file; returns an empty hashtable if missing or empty. Throws on corrupt JSON. |
| `Get-ContentHash`      | SHA-256 of `Vendor|Product|Title|PublishedDate|SourceUrl`.                                  |
| `Get-RecordKey`        | `id:<Id>` when the record has an Id, else `hash:<sha256>`. Returns `{ Key, Hash }`.           |
| `Compare-ReleaseState` | Tags items with `BASELINE`/`NEW`/`CHANGED`/`UNCHANGED` and produces the new state map.         |
| `Save-CurrentState`    | Writes the new state map atomically (`.tmp` + rename).                                         |

The content hash deliberately ignores the body. A change to `Title`, `PublishedDate`, or `SourceUrl` produces `CHANGED`; an edit to the body alone does not. See `state-and-changes.md` for the full reasoning.

The atomic write means a crash mid-write leaves the previous file intact.

## `Html.psm1`

Minimal HTML helpers. There is no real HTML parser — only what is needed to make captures and excerpts readable.

| Function                  | Purpose                                                                                          |
| ------------------------- | ------------------------------------------------------------------------------------------------ |
| `ConvertFrom-HtmlToText`  | Strips tags, decodes the entities Zendesk produces, collapses whitespace. Optional `MaxLength` truncates with `...`. |
| `ConvertTo-HtmlDocument`  | Wraps an HTML fragment in a styled HTML5 document for use as a capture.                          |

The future `HtmlCollector` (see `roadmap.md`) will use `ConvertFrom-HtmlToText` and may grow selector / attribute extraction helpers.

## `AdoWorkItem.psm1`

Azure DevOps Work Item creation. Imported by `Run.ps1` inside the per-item publish block (not via `Import-Framework`, because it depends on a local `.env` and is not needed for collector-only runs).

| Function               | Purpose                                                                                       |
| ---------------------- | --------------------------------------------------------------------------------------------- |
| `Initialize-AdoConfig` | Reads `.env` and populates module-scoped `$script:AdoPat`, `$script:AdoOrg`, `$script:AdoProject`. Throws if any of `ADO_PAT`, `AZURE_DEVOPS_ORG`, `AZURE_DEVOPS_PROJECTS` is missing. |
| `New-AdoWorkItem`      | Creates a User Story via `PATCH https://dev.azure.com/{org}/{project}/_apis/wit/workitems/$User%20Story?api-version=7.1`. Returns the created work item id. Tags default to `RLDatix, RL6, Auto-Generated`. IterationPath is `@CurrentIteration`. |

Secrets handling:

- The PAT is held in a module-scoped variable and never logged.
- The Basic-auth header is constructed per call; the base64 string is not cached.
- The module throws on a missing `.env` or missing keys, so misconfiguration is loud and immediate.

See `ado-integration.md` for how the publish block is wired into `Run.ps1`.

## Importing

`Run.ps1` does:

```powershell
Import-Module -Name ./modules/Common.psm1 -Force
Import-Framework -ModulesPath ./modules
```

`Import-Framework` walks the modules directory and imports `Common.psm1`, `Logging.psm1`, `State.psm1`, `Html.psm1` in that order. `AdoWorkItem.psm1` is imported on demand inside the publish block because it requires `.env`.

Adding a new framework module means adding the file under `modules/` and adding the name to the `$modules` array inside `Import-Framework` (or, for ADO-style on-demand modules, importing it explicitly where needed).

## Adding a module

1. Create `modules/<Name>.psm1`.
2. Add the file name to the `$modules` array in `Import-Framework` (in `Common.psm1`) unless the module is on-demand like `AdoWorkItem.psm1`.
3. Export only the functions that should be public, via `Export-ModuleMember -Function ...`.
4. Use `Set-StrictMode -Version Latest` at the top of the file.
5. Do not depend on `Run.ps1`; only depend on the other modules.
