# Platform-Automation — Supplemental MVP Plan (Delta to Architect Brief)

Status: implementation-ready
Companion to: `architect-implemntation-brief.md`
Cross-reviewed against: `architect-implementation-supplement.md` (second assessment) — see §Q for reconciliation.

This document does **not** restate the brief. It records the **delta** — the decisions, corrections, and grounded findings that refine the brief into an implementable Phase 1 MVP. Where this document and the brief differ, this document wins (and each difference is flagged).

---

## A. Decision Delta (resolved with stakeholder)

| # | Topic | Brief said / implied | Decision (delta) | Rationale |
|---|-------|----------------------|------------------|-----------|
| 1 | Change-detection persistence | "Change Detected (Yes/No)" required, but DB is a Non-Goal | **DECIDED: repo-committed `state/vendor-state.json`**, pushed to a dedicated `vendor-state` branch by the pipeline, behind a swappable `State.psm1` interface (see §Q1). | Zero new infra + fully source-controlled (both brief goals); git history is a free audit/change log; no artifact-retention/cache eviction risk; owner is a collection admin so repo write + branch config are non-issues; Blob is a later drop-in via the interface |
| 2 | RLDatix collection | "Public HTML page" implied as likely path | **Zendesk Help Center public REST API** (no auth) | Verified live; satisfies "Official API first"; far more robust than scraping |
| 3 | Runtime | Unspecified | **PowerShell 7 (`pwsh`) on `ubuntu-latest`** | Confirmed: pwsh, runs with other pwsh; zero infra |
| 4 | Auth/secrets | `Graph.psm1` module implied auth work | **None for MVP** — all sources public; convention documented (§L) | Confirmed public; defers Graph/auth; documenting the convention prevents a bad first precedent |
| 5 | Scaffolding breadth | Tree shows 4 pipelines + 5 task folders | **Only `vendor-monitor.yml` + `tasks/VendorMonitor/`**; drop `environments.json` | Keep MVP small; others are additive later; nothing varies by environment yet |
| 6 | Testing | "coding standards documented" | **Defer Pester + PR-validation pipeline**; ship lightweight standards doc only | Documentation ≠ test harness; keep simple first (see §Q5 for the deferred enforcement path) |

---

## B. Architectural Correction (challenged assumption)

**Brief tension:** the tree lists per-vendor scripts (`RLDatix.ps1`, `Microsoft.ps1`, `Atlassian.ps1`) *and* a config-driven `"Collector"` field. These conflict.

**Delta:** favor Principle #4 (config-driven). Collectors are **generic, config-selected, and declarative**, not per-vendor scripts.
- RLDatix needs **no** bespoke script — the generic `ApiCollector` reads endpoint + field mapping from `vendors.json`.
- Collector names match the brief's own example (`ApiCollector` / `RssCollector` / `HtmlCollector`), so `"Collector": "HtmlCollector"` from the brief is honored verbatim.
- **Escape hatch:** an optional `"Script"` property on a vendor entry overrides the declarative collector when config is insufficient; the script returns the same normalized record shape.
- `Graph.psm1` is **omitted** for MVP (no auth, no Graph task in scope).

Result: "add a vendor = edit JSON" stays true for any JSON API — not just Zendesk; zero duplicated collector code.

---

## C. Grounded RLDatix Findings (verified 2026-08-02)

- Host: `https://rldatix-public.zendesk.com` (Zendesk Help Center), organized into per-product sections.
- Current monthly release notes section: `19851648629532` (latest observed: "Release Notes July 2026").
- Legacy PolicyStat versioned notes section: `10457658046492`.
- Endpoint: `GET /api/v2/help_center/{locale}/sections/{sectionId}/articles.json?sort_by=created_at&sort_order=desc&per_page=100` — public, no auth, paginated via `next_page`.
- Fields consumed: `id`, `title`/`name`, `html_url`, `created_at`, `updated_at`, `edited_at`, `section_id`, `body`.
- **Verify at implementation:** exact products/sections in scope, and that the target sections are anonymously accessible (some RLDatix content sits behind the authenticated support portal, not the public KB).

---

## D. MVP Repository Structure (only what is built now)

```text
platform-automation/
├── azure-pipelines/
│   └── vendor-monitor.yml
├── config/
│   ├── vendors.json
│   └── settings.json
├── modules/
│   ├── Common.psm1        # HTTP (retry/timeout), JSON, env detection, paths
│   ├── Logging.psm1       # structured logs + ADO annotation/summary helpers
│   ├── Html.psm1          # HTML→text excerpt helpers
│   └── State.psm1         # swappable persistence + change detection
├── tasks/
│   └── VendorMonitor/
│       ├── Run.ps1
│       └── Collectors/
│           ├── ApiCollector.ps1
│           ├── RssCollector.ps1   # stub: NotImplemented (documented future)
│           └── HtmlCollector.ps1  # stub: NotImplemented (documented future)
├── state/                 # vendor-state.json committed to the vendor-state branch (§Q1)
├── output/                # gitignored; generated artifacts (.gitkeep)
├── docs/
│   ├── coding-standards.md
│   └── mvp-supplemental-plan.md   # this file
├── .editorconfig
├── .gitignore
└── README.md
```

**Explicitly NOT built in MVP:** `graph-automation.yml`, `ado-reporting.yml`, `maintenance.yml`, `pr-validation.yml`, `Graph.psm1`, `Utilities.psm1` (folded into `Common.psm1`), `environments.json`, `tests/`, and task folders `UserTermination/`, `GraphAutomation/`, `AzureDevOps/`, `ServiceNow/`.

---

## E. Module Responsibilities (pwsh 7+, `Set-StrictMode`, explicit exports; no business logic)

- **Common.psm1** — `Import-Framework`; `Get-Config($Path)` (parse + validate JSON, actionable errors); `Invoke-HttpGetWithRetry($Uri,$Retries=3,$TimeoutSec=30,$UserAgent)` (exponential backoff; returns `@{StatusCode;Content;Success;Error}` — the single choke point so logging always captures HTTP status); `Get-JsonPaged` (follow `next_page`); `New-OutputDirectory($Path)`; `ConvertTo-SafeFileName($Name)`; `Get-UtcTimestamp()`. *(HTTP/JSON helpers folded in here — no separate `Utilities.psm1`.)*
- **Logging.psm1** — `Start-TaskLog($TaskName)`; `Write-Log($Message,$Level,$Context)` (emits ADO `##[section]` / `##vso[task.logissue ...]`); `Write-VendorResultLine`; `Add-RunSummary($MarkdownPath)` (attaches report to the run's Summary tab, §J); `Stop-TaskLog($OutputPath)` → `output/ExecutionLog.txt`.
- **Html.psm1** (minimal) — `ConvertFrom-HtmlToText($Html)` for Markdown excerpts; reserved for future `HtmlCollector`.
- **State.psm1** (swappable persistence + change-detection boundary) — `Get-PreviousState($StatePath)`; `Compare-ReleaseState($Previous,$Items)` → NEW/CHANGED/UNCHANGED; `Save-CurrentState($StatePath,$Items)`. **Record key = stable `Id` when present, else the content hash.** **CHANGED is detected by a SHA-256 hash of normalized `Vendor|Product|Title|PublishedDate|Url`** (collector-agnostic — works for RSS/HTML where no `updated_at`/`id` exists). Cold start ⇒ baseline (records stored, nothing reported NEW). Only these functions know the on-disk format.

---

## F. Collector Contract

Each collector receives one product-config object and returns normalized records:

```powershell
[PSCustomObject]@{
  Vendor='RLDatix'; Product='IntelligentContract'; Id='28711097070364'
  Title='Release Notes July 2026'; PublishedDate='2026-07-06T15:05:15Z'
  SourceUrl='https://.../articles/28711097070364-...'
  RawBody='<p>...</p>'   # optional, for raw capture
}
```

Selection by config `Collector` field: `ApiCollector` (built) → `RssCollector`, `HtmlCollector` (stubs that throw `NotImplemented`, documented future). Optional `Script` overrides the collector. Ladder: API → RSS → HTML → browser → AI.

`ApiCollector` is **declarative and generic** (not Zendesk-specific): it reads `Url`, `ItemsPath` (where the array lives in the JSON), and `FieldMap` (record-field → JSON-field) from config, calls `Invoke-HttpGetWithRetry`, follows pagination up to `settings.maxPages`, maps → normalized records, logs HTTP status + count, and throws on failure (caught per-vendor in `Run.ps1`). This makes any JSON API onboard by JSON alone; Zendesk is just the first instance.

---

## G. Configuration (PascalCase, matching the brief's example)

`config/vendors.json`:
```json
{
  "Vendors": [
    {
      "Vendor": "RLDatix",
      "Enabled": true,
      "Collector": "ApiCollector",
      "Products": [
        {
          "Product": "IntelligentContract",
          "Url": "https://rldatix-public.zendesk.com/api/v2/help_center/en-us/sections/19851648629532/articles.json?sort_by=created_at&sort_order=desc&per_page=100",
          "ItemsPath": "articles",
          "FieldMap": { "Id": "id", "Title": "title", "PublishedDate": "created_at", "SourceUrl": "html_url", "RawBody": "body" }
        }
      ]
    }
  ]
}
```

`config/settings.json`:
```json
{
  "Http": { "UserAgent": "platform-automation/1.0", "TimeoutSec": 30, "Retries": 3 },
  "Collector": { "MaxPages": 3 },
  "Output": { "CaptureRawHtml": true, "MaxRawItems": 5 },
  "Run": { "BaselineOnColdStart": true }
}
```

Add a vendor/product = append JSON (e.g., PolicyStat section `10457658046492`, or a non-Zendesk API by changing `Url`/`ItemsPath`/`FieldMap`); no pipeline edit. HTML entries would instead carry `ItemSelector`/`TitleSelector`/`DateSelector`/`DateFormat` when `HtmlCollector` is implemented.

---

## H. Entry Point `tasks/VendorMonitor/Run.ps1`

Params: `-ConfigPath -SettingsPath -OutputPath -StatePath -Vendor[] -ForceRecheck`.
Flow: import framework → `Start-TaskLog` → load config/settings, filter `Enabled` + optional `-Vendor` → `Get-PreviousState` → per vendor/product in **try/catch per vendor** (dispatch collector by `Collector`/`Script`, invoke, accumulate, `Write-VendorResultLine`) → `Compare-ReleaseState` (bypassed by `-ForceRecheck`, which reports everything as-is but still updates state) → generate outputs → `Add-RunSummary` + warning annotation if any NEW → `Save-CurrentState` → `Stop-TaskLog`. Exit `0` even when NEW is found (a new release is not a failure); exit `1` only on framework/collection error. Per-vendor failures are logged as error annotations and never abort the run.

---

## I. Output Artifacts (`output/`)

- **VendorReport.json** — `{ generatedAt, summary{vendors,new,changed,unchanged,errors}, items[] }`; each item has vendor, product, title, publishedDate, detectedAt, sourceUrl, changeDetected.
- **VendorReport.md** — run header + counts, table of NEW/CHANGED (Vendor, Product, Published, Title, Status, URL), short excerpt. Covers the brief's full field set.
- **Raw HTML** (optional; `CaptureRawHtml=true`) — `RLDatix-IntelligentContract-<id>.html` up to `MaxRawItems` for traceability.
- **ExecutionLog.txt** — full run log per Logging Standards.
- **vendor-state.json** — written to `state/` and committed to the `vendor-state` branch for the next run's diff (§Q1). Also published as a run artifact for convenience/inspection.

---

## J. Pipeline `azure-pipelines/vendor-monitor.yml` (orchestration only)

- Triggers: `schedules` (cron daily `0 6 * * *` UTC, `always: true`) + manual; `trigger: none` (scheduled job, not a build).
- Parameters (kept minimal): `vendor` (dropdown: `All` + one per configured vendor) and `forceRecheck` (boolean, default `false`) → forwarded to `Run.ps1`.
- Pool: `ubuntu-latest`, `pwsh: true`.
- Steps: (1) `checkout` with `persistCredentials: true`; (2) read previous state from the `vendor-state` branch (fetch/checkout `state/vendor-state.json`; cold start = branch/file absent → baseline); (3) `pwsh ./tasks/VendorMonitor/Run.ps1 ...` writing output to `$(Build.ArtifactStagingDirectory)/output` and updating `state/vendor-state.json`; (4) publish `platform-automation-output` (`condition: always()`); (5) commit + push updated state to the `vendor-state` branch with message `chore(state): vendor monitor update [skip ci]` (skips retrigger). State is also published as an artifact for inspection.
- **Visibility (zero-infra, within non-goals — no Teams/email):** the report is attached to the run's **Summary tab** via `##vso[task.addattachment type=Distributedtask.Core.Summary;name=VendorReport;]`, and a **warning badge** is raised on NEW detections via `##vso[task.logissue type=warning]` so the run list draws the eye without any download.
- Per-vendor resilience inside PowerShell; pipeline fails only on framework-level error. Cold start ⇒ baseline + first state persist.

---

## K. Logging & Visibility Standards
Each run logs start/end/duration and per-vendor {vendor, source URL, HTTP status, item count, errors} + final summary. Consumable three ways, all native to ADO: (1) downloadable `ExecutionLog.txt` + report artifacts; (2) rendered `VendorReport.md` on the run Summary tab; (3) warning badge on NEW. Console output uses ADO logging commands.

---

## L. Coding Standards, Secrets Convention & Docs (testing deferred)
- `docs/coding-standards.md`: pwsh 7+, `Set-StrictMode`, approved-verb names, explicit `Export-ModuleMember`, param validation, comment-based help, structured `try/catch`, no hardcoded URLs (config only), UTC timestamps.
- **Secrets convention (document now, implement never in MVP):** secrets never enter the repo or JSON config; they come from ADO variable groups (optionally Key Vault–linked), injected as environment variables and read via `$env:` in scripts. Establishing this now prevents the first authenticated source from setting a bad precedent.
- `.editorconfig` (4-space, UTF-8, LF); appendable `README.md`.
- No Pester/PR-validation harness in MVP (deferred, §Q5). PSScriptAnalyzer may be run locally but is not gated.

---

## M. Implementation Stories (dependency-ordered)
1. Scaffold repo (folders, `.gitignore`, `.editorconfig`, `.gitkeep`, coding-standards + secrets convention docs, README skeleton).
2. Core modules (Common incl. HTTP/JSON/retry; Logging incl. summary/annotation helpers; State incl. hash-based diff; Html minimal).
3. Config (`vendors.json` with RLDatix `ApiCollector` + `FieldMap`, `settings.json`) + validation in `Get-Config`.
4. `ApiCollector.ps1` (declarative `ItemsPath`/`FieldMap`, pagination, normalization) + `Rss`/`Html` stubs + `Script` dispatch.
5. `Run.ps1` orchestration (collector dispatch, state diff, per-vendor try/catch, `-ForceRecheck`).
6. Output generation (JSON, Markdown, optional raw HTML, ExecutionLog, Summary-tab attachment, NEW-warning).
7. `vendor-monitor.yml` (schedule + manual params, obtain/persist state, run, publish, visibility).
8. Verify end-to-end against live Zendesk API + finalize docs.

Stories 1→7 strictly ordered; 8 validates.

---

## N. Success-Criteria Mapping
- Scheduled unattended run → Story 7.
- Logic isolated from orchestration → Stories 2–6 vs Story 7.
- RLDatix collected → Story 4 (verified API).
- Report artifact published → Stories 6–7.
- Extensible with minimal effort → declarative collectors + shared modules (2–4); a JSON-only vendor add proves it.
- Documented structure/standards → Stories 1 & 8.

---

## O. Deferred / Out of Scope (design-aware)
Azure Functions, Durable Functions, MCP, AI summarization, database storage, browser automation, Teams/email, dashboards, C# collectors, historical search, Graph auth/`Graph.psm1`, RSS/HTML collectors, Pester + PR-validation, additional pipelines/task folders. `State.psm1` interface, hash-based diff, and declarative collectors are pre-shaped so all are additive.

---

## P. Assumptions
- ADO project can schedule pipelines and publish/download pipeline artifacts on default hosted agents.
- Zendesk public API stays anonymous-accessible (verified 2026-08-02).
- `output/` staged via `Build.ArtifactStagingDirectory`; `state/vendor-state.json` lives on the `vendor-state` branch (local runs read/write it in the working tree and skip the push).
- Build-service identity is granted **Contribute** on the repo and can push to the `vendor-state` branch (owner is a collection admin — confirmed available).
- "Product" derives from config per section (PolicyStat addable via config).

---

## Q. Reconciliation with the Second Assessment (`architect-implementation-supplement.md`)

Both assessments were written independently and **agree** on: Zendesk public API as tier-1 source, config-driven generic collectors with a per-vendor `Script` escape hatch, `ubuntu-latest` + pwsh 7, no-auth/public MVP, MVP-only scaffold (drop extra pipelines/task folders/`Graph.psm1`), per-vendor `try/catch`, daily 06:00 UTC schedule, and the deferred roadmap. Refinements adopted from it into this plan:

- **Q1 — State persistence — DECIDED: repo-committed state (the second assessment's recommendation).** The owner is a DevOps **collection admin**, so the only reason to prefer the artifact approach (avoiding repo write permission) does not apply. Repo-commit wins on the brief's own goals: zero new infrastructure, fully source-controlled, and git history becomes a free release-change audit log; it also avoids artifact-retention/cache eviction that can cause false "NEW" spam. **Implementation:** `state/vendor-state.json` is committed to a dedicated **`vendor-state` branch** (not `main`, so no branch-policy friction and no state churn on `main`); pipeline checks out with `persistCredentials: true` and pushes with `[skip ci]`; grant the Project Build Service **Contribute** on the repo. Because everything sits behind the `State.psm1` interface, migrating to Azure Blob later remains a single-module change if write frequency ever outgrows git.
- **Q2 — Change detection → SHA-256 content hash** of normalized `Vendor|Product|Title|PublishedDate|Url`. Adopted (replaces my Zendesk-specific `updated_at` compare) because it is collector-agnostic and future-proofs RSS/HTML. Stable `Id` still used as the record key when available.
- **Q3 — Declarative `ApiCollector` + `ItemsPath`/`FieldMap`** and brief-matching collector names (`ApiCollector`/`RssCollector`/`HtmlCollector`). Adopted — makes *any* JSON API onboard by JSON alone, better satisfying Principle #4 at negligible extra cost.
- **Q4 — Extra visibility channels** (Summary-tab attachment + warning-badge on NEW; exit 0 for NEW, exit 1 for framework errors only). Adopted — zero infra, respects the no-notification non-goal.
- **Q5 — Testing / PR-validation: intentionally NOT adopted for MVP.** The second assessment recommends `pr-validation.yml` (PSScriptAnalyzer + Pester smoke tests) and a `tests/` folder. This **conflicts with the owner's explicit "defer testing" decision** (§A#6), so it is deferred. It remains the correct enforcement path when the owner wants it — add `pr-validation.yml` + `tests/` post-MVP.
- **Also adopted:** fold `Utilities.psm1` into `Common.psm1`; drop `environments.json`; document the secrets convention now (all consistent with "keep it simple" and the second assessment's D7/D9/D10).

**Net:** this supplement now incorporates every non-conflicting improvement from the second assessment. **Q1 (state backend) is now decided — repo-committed state on a `vendor-state` branch.** Everything is locked and implementation-ready.

---

## R. Open Owner Inputs (only true blockers)
1. **RLDatix product scope** — which products/sections to monitor (IntelligentContract `19851648629532` is the working default; PolicyStat `10457658046492` optional), and confirmation the public Zendesk KB is the intended source vs. the authenticated support portal.

*State backend (formerly open) is now decided — repo-committed state on the `vendor-state` branch (§Q1). Admin action required at implementation time: grant the Project Build Service **Contribute** on the repo.*

Everything else defaults to the recommendations above.
