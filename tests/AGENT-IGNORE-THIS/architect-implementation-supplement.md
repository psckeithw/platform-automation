# Platform-Automation — Implementation Decisions & Supplemental Plan

**Status:** Proposed — recommendations pending owner confirmation
**Supplements:** `architect-implemntation-brief.md` (all brief goals, non-goals, and success criteria remain unchanged)
**Date:** 2026-08-02

## Purpose

The brief intentionally leaves several Phase-1-blocking questions open. This document records a concrete recommendation for each, so implementation can start without ambiguity. Each decision lists its rationale and the fallback if the recommendation is rejected. Nothing here expands the MVP scope or violates the brief's non-goals.

---

## Key Discovery: RLDatix Publishes via Zendesk Help Center

RLDatix public release notes are hosted on a Zendesk Help Center (`rldatix-public.zendesk.com`), organized into per-product sections (PolicyMed, PolicyStat, intelligentcontract, etc.).

This matters architecturally: Zendesk Help Centers expose a **public REST API** (`/api/v2/help_center/.../sections/{id}/articles.json`) and Atom feeds. The brief's collection priority list (API > RSS > HTML) can therefore be satisfied at tier 1 for the MVP vendor — no HTML scraping required. This validates the config-driven collector design: onboarding RLDatix is a `vendors.json` entry with section IDs, not custom code.

*Verify during implementation: which products/sections are in scope, and whether the target sections are anonymously accessible (some RLDatix content sits behind the support portal login at `grc-support.rldatix.com`).*

---

## Decision Register

### D1 — State persistence for change detection

**Recommendation:** Repo-committed state file at `state/vendor-state.json`. The pipeline commits updates back with `[skip ci]` after each run, using `persistCredentials: true` on checkout.

**Rationale:**
- Durable, auditable (git history *is* the change log), zero external dependencies.
- Works identically locally and in the pipeline (local runs just skip the commit).
- Pipeline Cache is best-effort and can be evicted → false "NEW" results. Previous-artifact lookup couples runs together and breaks when a run fails before publishing.

**Behavior rules:**
- First run with no state file = **baseline run**: records are stored, nothing reported as NEW (avoids alert spam on day one).
- Change detection = SHA-256 hash of normalized `Vendor|Product|Title|PublishedDate|Url` per record.
- Commit message: `chore(state): vendor monitor update [skip ci]`.

**Prerequisite:** the project's build service identity needs **Contribute** permission on the repo. If `main` has branch policies, run the schedule against a non-protected branch or a dedicated `vendor-state` branch.

**Fallback if rejected:** previous-run artifact retrieval via ADO REST API.

### D2 — Collector model

**Recommendation:** Config-first generic collectors, with a per-vendor script as escape hatch only.

- Collectors live in `tasks/VendorMonitor/Collectors/`: `ApiCollector.ps1`, `RssCollector.ps1`, `HtmlCollector.ps1`. They are task-specific business logic, not shared modules (promote to `/modules` only if a second task needs them).
- Each collector implements one contract: receives a vendor config object, returns an array of normalized records (`Vendor, Product, Title, PublishedDate, Url`).
- All parsing specifics (endpoints, JSON paths, CSS selectors, regexes, date formats) live in `vendors.json` — **adding a vendor = editing JSON**.
- Escape hatch: an optional `"Script": "RLDatix.ps1"` property in a vendor entry, invoked by the dispatcher when declarative config is insufficient. The script must return the same normalized record shape.
- `Run.ps1` owns the pipeline-agnostic workflow: load config → dispatch collectors → diff against state → generate report/artifacts → update state. Per-vendor `try/catch` so one vendor's failure doesn't stop the rest.

**Rationale:** reconciles the brief's `"Collector": "HtmlCollector"` config example with the per-vendor script files, and keeps the "little or no pipeline modification" promise for new vendors.

### D3 — Agent pool & runtime

**Recommendation:** Microsoft-hosted `ubuntu-latest` agents, PowerShell 7 (`pwsh: true` on all script steps).

**Rationale:**
- Zero infrastructure (brief goal: "minimize infrastructure requirements").
- pwsh 7 is cross-platform → identical behavior on a dev's Windows machine and the Ubuntu agent (local execution parity is a core brief requirement).
- All MVP sources are public internet endpoints; no corporate network access needed.

**Fallback if rejected:** if a future source requires corporate network access, introduce a self-hosted Windows pool at that time. Keep the pool name in a pipeline variable so this is a one-line change.

### D4 — Result consumption (no notifications in MVP)

**Recommendation:** Three zero-infrastructure visibility channels, all native to ADO:
1. **Artifacts** (per brief): `VendorReport.md`, `VendorReport.json`, raw captures, `ExecutionLog.txt`.
2. **Run Summary tab:** attach `VendorReport.md` via `##vso[task.addattachment type=Distributedtask.Core.Summary;...]` so the report renders on the pipeline run page without downloading anything.
3. **Warning annotation on NEW detection:** `##vso[task.logissue type=warning]` — the run shows a warning badge in the run list, which is enough to draw the eye. Exit code stays 0; a new release is not a failure. Exit 1 is reserved for collection/framework errors (and partial vendor failures still complete the run, with error annotations per failed vendor).

### D5 — Schedule & triggers

**Recommendation:** Daily at 06:00 UTC (`cron: '0 6 * * *'`), `always: true`, on `main`; `trigger: none` (no CI builds — this pipeline is a scheduled job, not a build).

### D6 — Manual execution parameters

**Recommendation:** Two parameters only:
- `vendor` — dropdown, `All` (default) + one entry per configured vendor.
- `forceRecheck` — boolean, default `false`; bypasses state comparison (everything reported as-is, state still updated).

Resist adding more until a concrete need exists.

### D7 — Drop `environments.json` from MVP

**Recommendation:** Remove it from the scaffold. Nothing in vendor monitoring varies by environment, and no multi-environment task exists yet. Reintroduce when a task genuinely needs environment-specific config.

### D8 — PR validation pipeline (yes, lightweight)

**Recommendation:** Add `azure-pipelines/pr-validation.yml`: PSScriptAnalyzer (fail on Error-severity findings) + Pester smoke tests over `/modules`. 

**Rationale:** the brief's success criteria demand documented coding standards and a framework future contributors can extend safely; lint + smoke tests are the cheapest enforcement mechanism. Kept deliberately small so it doesn't become scope creep.

### D9 — Scaffold scope: MVP only

**Recommendation:** Create only what the vendor monitor needs. No empty placeholder task folders (`UserTermination/`, `GraphAutomation/`, ...), no `graph-automation.yml` / `ado-reporting.yml` / `maintenance.yml`, no `Graph.psm1` or `Utilities.psm1` (HTTP/retry/JSON helpers live in `Common.psm1`). The README documents the pattern for adding tasks; empty directories document nothing and rot.

### D10 — Secrets convention (document, don't implement)

**Recommendation:** MVP needs no secrets (public sources). Establish the convention in the README now: secrets never enter the repo or JSON config; they come from ADO variable groups (or Key Vault–linked groups) injected as environment variables, read via `$env:` in scripts. This costs nothing today and prevents the first authenticated source from setting a bad precedent.

---

## Refined Config Schema

```json
{
  "vendors": [
    {
      "Vendor": "RLDatix",
      "Enabled": true,
      "Collector": "ApiCollector",
      "Products": [
        {
          "Product": "PolicyStat",
          "Url": "https://rldatix-public.zendesk.com/api/v2/help_center/en-us/sections/{section-id}/articles.json",
          "ItemsPath": "articles",
          "FieldMap": { "Title": "title", "PublishedDate": "created_at", "Url": "html_url" }
        }
      ]
    }
  ]
}
```

`Script` (optional) overrides `Collector` for that vendor. HTML-collector entries carry `ItemSelector`, `TitleSelector`, `DateSelector`, `DateFormat`, etc. instead.

---

## Revised MVP Repository Structure

```text
platform-automation/
├── azure-pipelines/
│   ├── vendor-monitor.yml          # scheduled + manual (D5, D6)
│   └── pr-validation.yml           # lint + smoke tests (D8)
├── config/
│   ├── vendors.json                # vendor definitions
│   └── settings.json               # non-secret global settings
├── modules/
│   ├── Common.psm1                 # HTTP (retry/timeout), JSON, env detection
│   ├── Logging.psm1                # structured logs + ADO annotation helpers
│   └── Html.psm1                   # HTML parsing helpers
├── tasks/
│   └── VendorMonitor/
│       ├── Run.ps1                 # entry point (local + pipeline)
│       └── Collectors/
│           ├── ApiCollector.ps1
│           ├── RssCollector.ps1
│           └── HtmlCollector.ps1
├── state/
│   └── vendor-state.json           # pipeline-maintained (D1)
├── tests/                          # Pester smoke tests (D8)
├── output/                         # gitignored working dir → published as artifacts
├── .gitignore
└── README.md
```

Changes vs. the brief's tree: removed `environments.json` (D7), the three non-MVP pipeline files and placeholder task folders (D9), `Graph.psm1`/`Utilities.psm1` (D9); added `state/`, `tests/`, `pr-validation.yml`, `.gitignore`.

---

## Implementation Stories

| # | Story | Acceptance criteria |
|---|-------|---------------------|
| S1 | Repo scaffold: folders, `.gitignore` (ignore `output/`), `settings.json`, PSScriptAnalyzer config | Structure matches this doc; lint config runs clean on empty modules |
| S2 | `Common.psm1` + `Logging.psm1` + `Html.psm1` | HTTP helper with retry (3×, backoff) + timeout; start/end/duration logging; ADO `##vso` annotation helpers |
| S3 | `vendors.json` schema + RLDatix entry | Schema doc in README; config validates on load with actionable errors |
| S4 | Collectors + normalized record contract + dispatcher escape hatch | ApiCollector returns normalized records from Zendesk API; Rss/Html collectors implemented; `Script` override honored |
| S5 | State manager | Read/diff/write `state/vendor-state.json`; hash-based change detection; baseline behavior on missing state |
| S6 | `Run.ps1` orchestration + reports | `.\tasks\VendorMonitor\Run.ps1` runs locally end-to-end; per-vendor isolation; MD + JSON + ExecutionLog in `output/` |
| S7 | `vendor-monitor.yml` | Scheduled daily 06:00 UTC + manual params; artifacts published; summary tab attachment; warning on NEW; state committed with `[skip ci]` |
| S8 | `pr-validation.yml` + Pester smoke tests | PRs trigger lint + tests; Error-severity lint fails the build |
| S9 | README contributor docs | "Add a vendor" (JSON-only) and "Add a task" walkthroughs; coding standards; secrets convention (D10) |

Suggested order: S1 → S2 → S3 → S4 → S5 → S6 → S7 → S8 → S9 (S8 can parallel S7).

---

## Open Inputs Required from Owner

1. **RLDatix product scope** — which products/sections to monitor, and confirmation the public Zendesk KB is the correct source (vs. the authenticated support portal).
2. **Schedule confirmation** — daily 06:00 UTC acceptable?
3. **State-commit permission** — can the build service get Contribute rights on the repo (or is `main` policy-protected, requiring the fallback)?
4. **PR validation appetite** — confirm D8 is wanted in MVP.
5. **Hosted pool confirmation** — no corporate-network-only sources anticipated in Phase 1?

Items 1–3 are the only true blockers; 4–5 default to the recommendations above if unanswered.

## Deferred (unchanged from brief)

Azure Functions, Durable Functions, MCP, AI summarization, database storage, browser automation, Teams/email notifications, workflow automation, dashboard UI, persistent/searchable history. The decisions above (especially D1's repo-state and D2's collector contract) are deliberately compatible with each of these future additions.
