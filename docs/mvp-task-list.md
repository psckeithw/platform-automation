# Platform-Automation MVP — Phased Task List

Purpose: an execution plan broken into small, self-contained tasks that can each be handed to a focused agent. Full design rationale lives in `docs/mvp-supplemental-plan.md` (referenced per task as "plan §X"). This file is the build checklist.

---

## Context every agent needs (read first — locked decisions)

- **Language/runtime:** PowerShell 7 (`pwsh`), cross-platform, `Set-StrictMode -Version Latest`. Target agent: `ubuntu-latest`.
- **Architecture:** Pipelines orchestrate; PowerShell does the work. Shared code in `modules/`; task logic in `tasks/VendorMonitor/`. No business logic in YAML.
- **Config-driven:** collectors are generic and selected by a `Collector` field in `config/vendors.json`. Adding a source = editing JSON, not code. No hardcoded URLs.
- **No auth / public sources only** for MVP. Secrets convention is documented but not implemented.
- **State backend (DECIDED):** repo-committed `state/vendor-state.json`, pushed by the pipeline to a dedicated **`vendor-state` branch** with `[skip ci]`. All state access goes through `modules/State.psm1`.
- **Change detection:** SHA-256 hash of normalized `Vendor|Product|Title|PublishedDate|Url`; stable `Id` is the record key when present. Cold start = baseline (record everything, report nothing as NEW).
- **Testing deferred:** no Pester/PR-validation in MVP. Lint (PSScriptAnalyzer) may run locally but is not gated.
- **Target source is DEFERRED.** Build against the example fixture below; the real vendor/section is a config change later.

### Example/verification fixture (public, no auth, confirmed working)
Use this as the working config so every phase is testable end-to-end before the real target is chosen:
- URL: `https://rldatix-public.zendesk.com/api/v2/help_center/en-us/sections/19851648629532/articles.json?sort_by=created_at&sort_order=desc&per_page=100`
- `ItemsPath`: `articles`
- `FieldMap`: `{ "Id":"id", "Title":"title", "PublishedDate":"created_at", "SourceUrl":"html_url", "RawBody":"body" }`
- Note (research finding, for later): the public RLDatix KB covers GRC/Contract Management products (intelligentcontract, PolicyStat, PolicyMed, oneSOURCE, UCM). **Workforce products (Optima, Loop, RosterOn, etc.) publish release notes on the authenticated `allocate.support` portal, not this public KB** — monitoring those will require auth and is out of MVP scope. This does not block the build.

### Definition of done for every task
- Files created exactly at the stated paths.
- `pwsh` parses/imports the file with no errors under `Set-StrictMode -Version Latest`.
- Public functions have comment-based help and explicit `Export-ModuleMember`.
- Acceptance check in the task passes.

---

## Phase 0 — Scaffold & Conventions
Small, no dependencies. Can be done first by one agent. (Ref: plan §D, §L)

### T0.1 — Repo skeleton
- **Deliverable:** directory tree + placeholders:
  ```
  azure-pipelines/  config/  modules/  tasks/VendorMonitor/Collectors/  state/  output/  docs/
  ```
  plus `output/.gitkeep`, `state/.gitkeep`, `.editorconfig` (4-space, UTF-8, LF, final newline), `.gitignore` (ignore `output/` contents except `.gitkeep`; do **not** ignore `state/`).
- **Acceptance:** tree matches plan §D; `git status` shows the folders; `.gitignore` keeps `output/` empty-tracked and leaves `state/` tracked.

### T0.2 — Coding standards + secrets convention doc
- **Deliverable:** `docs/coding-standards.md`.
- **Requirements:** pwsh 7+, `Set-StrictMode`, approved-verb names, explicit exports, param validation, comment-based help, structured `try/catch`, no hardcoded URLs, UTC timestamps. Add the **secrets convention**: never in repo/JSON; use ADO variable groups → `$env:` (document only).
- **Acceptance:** doc covers all bullets above; no code required.

### T0.3 — README build/run section
- **Deliverable:** update root `README.md` with "How to run locally", "How to add a vendor (edit `vendors.json`)", and "Where artifacts land". Keep the existing handoff/appendable format.
- **Acceptance:** a new contributor can run the task from the README alone (command + expected outputs).

---

## Phase 1 — Core Modules (framework)
The four modules are independent files and can be built **in parallel** by separate agents. `ApiCollector` (Phase 3) and `Run.ps1` (Phase 4) depend on all of them. (Ref: plan §E)

### T1.1 — `modules/Common.psm1`
- **Depends on:** T0.1
- **Functions:**
  - `Get-Config([string]$Path)` — load + parse JSON; validate required keys; throw actionable errors on malformed/missing.
  - `Invoke-HttpGetWithRetry([string]$Uri,[int]$Retries=3,[int]$TimeoutSec=30,[string]$UserAgent)` — exponential backoff; returns `@{ StatusCode; Content; Success; Error }` (never throws on HTTP error — returns the shape so callers/log capture status).
  - `Get-JsonPaged([string]$Uri,[hashtable]$HttpArgs,[int]$MaxPages)` — follow a `next_page` field; aggregate items.
  - `New-OutputDirectory([string]$Path)`, `ConvertTo-SafeFileName([string]$Name)`, `Get-UtcTimestamp()`.
- **Acceptance:** `Import-Module ./modules/Common.psm1`; `Invoke-HttpGetWithRetry` against the fixture URL returns `Success=$true`, `StatusCode=200`, non-empty `Content`; `Get-Config` throws a clear error on a malformed JSON temp file.

### T1.2 — `modules/Logging.psm1`
- **Depends on:** T0.1
- **Functions:** `Start-TaskLog($TaskName)`; `Write-Log($Message,$Level,$Context)` (levels INFO/WARN/ERROR/DEBUG; emit ADO `##[section]` and `##vso[task.logissue type=warning|error]`); `Write-VendorResultLine` (vendor, url, httpStatus, count, durationMs); `Add-RunSummary($MarkdownPath)` (emit `##vso[task.addattachment type=Distributedtask.Core.Summary;name=VendorReport;]<path>`); `Stop-TaskLog($OutputPath)` writes `output/ExecutionLog.txt` and returns elapsed.
- **Acceptance:** a scripted sequence produces console output with ADO commands and writes a non-empty `ExecutionLog.txt` with start/end/duration lines.

### T1.3 — `modules/State.psm1`  (the persistence boundary)
- **Depends on:** T0.1
- **Functions:**
  - `Get-PreviousState([string]$StatePath)` — read `vendor-state.json`; return empty state if file/branch absent (cold start).
  - `Compare-ReleaseState([object]$Previous,[object[]]$Items)` — return each item tagged `NEW` (unseen key), `CHANGED` (seen key, different content hash), or `UNCHANGED`. Content hash = SHA-256 of `"{Vendor}|{Product}|{Title}|{PublishedDate}|{SourceUrl}"`. Record key = `Id` if present else the hash.
  - `Save-CurrentState([string]$StatePath,[object[]]$Items)` — write keyed map `{ key: { title, hash, firstSeen, sourceUrl } }`.
  - Baseline rule: when previous state is empty, everything is stored and reported as baseline (not NEW-spam).
- **Acceptance:** unit-style script proves: first pass over N items → all baseline + state file written; second pass unchanged → all `UNCHANGED`; mutate one item's title → that one is `CHANGED`, add one → `NEW`.

### T1.4 — `modules/Html.psm1` (minimal)
- **Depends on:** T0.1
- **Functions:** `ConvertFrom-HtmlToText([string]$Html)` — strip tags/entities, collapse whitespace, return a short plaintext excerpt.
- **Acceptance:** `ConvertFrom-HtmlToText '<p>Hello&nbsp;<b>world</b></p>'` → `Hello world`.

---

## Phase 2 — Configuration
Depends on T1.1 (validation lives in `Get-Config`). Can run alongside Phase 1 once `Get-Config`'s contract is agreed. (Ref: plan §G)

### T2.1 — `config/settings.json`
- **Deliverable:** global non-secret settings:
  ```json
  { "Http": { "UserAgent": "platform-automation/1.0", "TimeoutSec": 30, "Retries": 3 },
    "Collector": { "MaxPages": 3 },
    "Output": { "CaptureRawHtml": true, "MaxRawItems": 5 },
    "Run": { "BaselineOnColdStart": true } }
  ```
- **Acceptance:** `Get-Config ./config/settings.json` returns an object with all keys.

### T2.2 — `config/vendors.json` (example fixture entry)
- **Deliverable:** one vendor using the fixture from the context block:
  ```json
  { "Vendors": [ { "Vendor": "RLDatix", "Enabled": true, "Collector": "ApiCollector",
      "Products": [ { "Product": "IntelligentContract",
        "Url": "https://rldatix-public.zendesk.com/api/v2/help_center/en-us/sections/19851648629532/articles.json?sort_by=created_at&sort_order=desc&per_page=100",
        "ItemsPath": "articles",
        "FieldMap": { "Id":"id","Title":"title","PublishedDate":"created_at","SourceUrl":"html_url","RawBody":"body" } } ] } ] }
  ```
  Add a comment in the README that this is the verification fixture; real target is swapped later.
- **Acceptance:** `Get-Config ./config/vendors.json` validates; `Vendors[0].Products[0].FieldMap` has 5 keys.

---

## Phase 3 — Collectors
Depends on T1.1 (HTTP/paging) and the config schema. (Ref: plan §B, §F)

### T3.1 — `tasks/VendorMonitor/Collectors/ApiCollector.ps1`
- **Depends on:** T1.1, T2.x
- **Function:** `Invoke-ApiCollector([object]$Vendor,[object]$Product,[object]$Settings)`:
  1. Call `Get-JsonPaged` on `$Product.Url` up to `Settings.Collector.MaxPages`, using `Settings.Http`.
  2. Select the array at `$Product.ItemsPath` (dot-path).
  3. Map each element to a normalized record using `$Product.FieldMap` (record-field ← json-field). Attach `Vendor`, `Product`.
  4. Log HTTP status + record count via `Write-VendorResultLine`.
  5. Throw on hard failure (caught per-vendor in `Run.ps1`).
- **Normalized record:** `@{ Vendor; Product; Id; Title; PublishedDate; SourceUrl; RawBody }`.
- **Acceptance:** run against the fixture config → returns ≥ 50 normalized records; each has non-empty `Id`, `Title`, `SourceUrl`; `PublishedDate` parseable as a date.

### T3.2 — Collector stubs + dispatch contract
- **Depends on:** T3.1
- **Deliverable:** `RssCollector.ps1` and `HtmlCollector.ps1` that `throw "NotImplemented: <name> is a future collector"`. Document the `Script` escape-hatch contract (an optional `"Script"` on a vendor entry overrides the collector; the script returns the same normalized record shape).
- **Acceptance:** invoking either stub throws the documented NotImplemented message; contract documented in the file header.

---

## Phase 4 — Task Orchestration
Depends on Phases 1–3. This is the integration task; assign after modules + collector are green. (Ref: plan §H, §I)

### T4.1 — `tasks/VendorMonitor/Run.ps1`
- **Depends on:** T1.1–T1.4, T3.1
- **Params:** `-ConfigPath -SettingsPath -OutputPath -StatePath -Vendor[] -ForceRecheck`.
- **Flow:** import modules → `Start-TaskLog` → load settings + vendors, filter `Enabled` and optional `-Vendor` → `Get-PreviousState` → for each vendor→product in **try/catch per vendor** (dispatch by `Collector`/`Script`, accumulate records) → `Compare-ReleaseState` (bypassed by `-ForceRecheck`, which still updates state) → generate outputs (T4.2) → `Save-CurrentState` → `Stop-TaskLog`. Exit `0` even on NEW; exit `1` only on framework/collection failure; a single vendor failure logs an error annotation and continues.
- **Acceptance:** `pwsh ./tasks/VendorMonitor/Run.ps1 -Baseline`-equivalent first run writes state + outputs and exits 0; a deliberately broken vendor entry does not abort the run (other vendors still processed; error annotation emitted).

### T4.2 — Output generation
- **Depends on:** T4.1 scaffolding (can be same agent)
- **Deliverable:** in `output/`: `VendorReport.json` (`{ generatedAt, summary{vendors,new,changed,unchanged,errors}, items[] }`), `VendorReport.md` (header + counts + NEW/CHANGED table with Vendor/Product/Published/Title/Status/URL + short excerpt via `ConvertFrom-HtmlToText`), optional raw HTML captures (`<Vendor>-<Product>-<id>.html`, capped by `MaxRawItems`), and `ExecutionLog.txt`. Attach the MD to the run summary via `Add-RunSummary`; raise a warning annotation if any NEW.
- **Acceptance:** after a run, all files exist; JSON `summary` counts match `items`; MD table renders; on a run with NEW items a warning annotation is emitted.

---

## Phase 5 — Pipeline & Branch Setup
Depends on Phase 4 (needs a working `Run.ps1`). (Ref: plan §J, §Q1)

### T5.1 — `azure-pipelines/vendor-monitor.yml`
- **Depends on:** T4.x
- **Requirements:**
  - Triggers: `schedules` (cron `0 6 * * *` UTC, `always: true`) + manual; `trigger: none`.
  - Parameters: `vendor` (dropdown: `All` + configured vendors) and `forceRecheck` (bool, default false) → forwarded to `Run.ps1`.
  - Pool `ubuntu-latest`; all script steps `pwsh: true`.
  - Steps: (1) `checkout` with `persistCredentials: true`; (2) fetch/checkout `state/vendor-state.json` from the `vendor-state` branch (cold start tolerated); (3) run `Run.ps1` writing output to `$(Build.ArtifactStagingDirectory)/output`; (4) `PublishPipelineArtifact` `platform-automation-output` (`condition: always()`); (5) commit + push updated `state/vendor-state.json` to `vendor-state` with `chore(state): vendor monitor update [skip ci]`.
- **Acceptance:** YAML validates; no business logic in the file; state read/write targets the `vendor-state` branch; artifacts published on always().

### T5.2 — Branch + permissions runbook (admin)
- **Depends on:** none (documentation/ops)
- **Deliverable:** short runbook in `docs/` (or README appendix): create the `vendor-state` branch (empty/orphan with `state/vendor-state.json`), grant the **Project Build Service** `Contribute` on the repo, confirm `main` policies untouched.
- **Acceptance:** steps are copy-pasteable; owner (collection admin) can execute without further questions.

---

## Phase 6 — Verify & Finalize
Depends on Phases 4–5. (Ref: plan §N)

### T6.1 — End-to-end local verification
- **Depends on:** T4.x
- **Actions:** run `Run.ps1` twice against the fixture: first run = baseline (state written, nothing NEW); mutate/remove a state entry and re-run to prove NEW/CHANGED detection; confirm per-vendor isolation with a broken entry.
- **Acceptance:** documented run log showing baseline → no-change → detected-change behavior; all artifacts present.

### T6.2 — Docs finalize + success-criteria sign-off
- **Depends on:** all
- **Actions:** finalize README "add a vendor" walkthrough; map each brief success criterion (plan §N) to where it's satisfied; note the deferred target and the workforce/auth caveat.
- **Acceptance:** every success criterion in plan §N has a pointer to the implementing file/step.

---

## Dependency & parallelization summary

- **Wave 1 (parallel):** T0.1 → then T0.2, T0.3, and all of T1.1/T1.2/T1.3/T1.4 in parallel.
- **Wave 2 (parallel after Common):** T2.1, T2.2, T3.1 (T3.1 needs T1.1). T3.2 after T3.1.
- **Wave 3 (integration):** T4.1 + T4.2 (single agent) after Phases 1–3.
- **Wave 4:** T5.1 after T4; T5.2 anytime (ops).
- **Wave 5:** T6.1, T6.2 last.

Critical path: T0.1 → T1.1 → T3.1 → T4.1/T4.2 → T5.1 → T6.1.

## Handoff notes for small agents
- Give each agent: this task's block + `docs/mvp-supplemental-plan.md` (for the referenced §) + the "Context every agent needs" block above.
- Agents should not change locked decisions; if a decision seems wrong, flag it, don't silently deviate.
- Only commit/push when explicitly asked; keep changes scoped to the task's stated files.

## Deferred (post-MVP, do not build now)
Real target selection (incl. any authenticated workforce/Optima source), RSS/HTML collectors, Pester + `pr-validation.yml` + `tests/`, `Graph.psm1`/auth, additional pipelines and task folders, Azure Blob state backend (drop-in via `State.psm1`).
