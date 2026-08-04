# MVP Success-Criteria Sign-Off

This document maps each success criterion from the brief
(`architect-implemntation-brief.md`, "Success Criteria" section)
and the supplemental plan (`docs/mvp-supplemental-plan.md` §N) to
the file, function, or step that satisfies it. It is the final
deliverable of Phase 1: a one-page read for the collection admin
and the next agent that picks the framework up.

Refs:
- `architect-implemntation-brief.md` — original success criteria
  (the source of truth for intent).
- `docs/mvp-supplemental-plan.md` §N — the same criteria as
  reframed by the supplemental plan.

---

## Success criteria

| # | Criterion (from the brief / plan §N) | Where it is satisfied |
| - | --- | --- |
| 1 | A scheduled Azure DevOps Pipeline executes without manual intervention. | `azure-pipelines/vendor-monitor.yml` (`schedules:` block, cron `0 6 * * *` UTC, `always: true`) and the pipeline run + state commit steps. Manual runs are also supported via the `vendor` / `forceRecheck` parameters, no separate file. |
| 2 | Vendor monitoring logic is isolated from pipeline orchestration. | `azure-pipelines/vendor-monitor.yml` is YAML orchestration only: triggers, parameters, checkout, `pwsh` invocation, artifact publish, state-branch commit. Every other behavior — collection, state diff, report generation, logging — lives in `tasks/VendorMonitor/Run.ps1` and the `modules/` directory. The pipeline never inspects a vendor URL or vendor name. |
| 3 | Ecteon Contraxx release information is collected successfully. | `config/vendors.json` (Ecteon / Contraxx) → `tasks/VendorMonitor/Collectors/Overrides/Invoke-EcteonCollector.ps1` `Invoke-OverrideCollector` → `tasks/VendorMonitor/Run.ps1`. The collector returns the normalized record set for 2026 releases only (5 demo items, parseable dates, all required fields populated). |
| 4 | A report artifact is generated and published. | `tasks/VendorMonitor/Run.ps1` writes `output/VendorReport.json`, `output/VendorReport.md`, optional `output/<Vendor>-<Product>-<id>.html` raw captures, and `output/ExecutionLog.txt`. `azure-pipelines/vendor-monitor.yml` publishes these as the `platform-automation-output` artifact (with `condition: always()` for diagnosis on partial failure) and attaches the Markdown to the run's Summary tab via `Add-RunSummary`. |
| 5 | The framework allows additional automation tasks to be added using the same structure with minimal effort. | The dispatcher is config-driven: `tasks/VendorMonitor/Collectors/` holds one function per collector; `config/vendors.json` selects a collector by the `Collector` field and feeds it the data shape. Adding a JSON-API vendor = appending a `Vendors[].Products[]` entry (no code). A non-JSON API = appending a new `*.ps1` under `Collectors/` that defines `Invoke-<Name>Collector` returning the same normalized record shape (see `tasks/VendorMonitor/Collectors/README.md` and the `Script` escape hatch). |
| 6 | Repository structure, module organization, and coding standards are documented for future contributors. | `README.md` (handoff + local development + pipeline pointer), `docs/coding-standards.md` (pwsh 7+, strict mode, approved verbs, explicit exports, secrets convention, appendable README, UTC timestamps, no hardcoded URLs), `docs/branch-permissions-runbook.md` (admin setup for the state branch and Project Build Service), `tasks/VendorMonitor/Collectors/README.md` (collector contract and Script escape hatch). `.editorconfig` is authoritative for formatting. |

---

## Brief goals (cross-check)

| Goal (from the brief) | Where it is satisfied |
| --- | --- |
| Reusable automation framework | `modules/` (Common, Logging, State, Html) + `tasks/VendorMonitor/Run.ps1` as the entry script + a config-driven collector dispatcher. Adding a new task category is a new `tasks/<Name>/Run.ps1` and (if needed) a new `Collectors/` subdirectory. |
| Standardize PowerShell execution from Azure DevOps Pipelines | `azure-pipelines/vendor-monitor.yml` is the only MVP pipeline; every script step uses `pwsh: true`; logging emits ADO commands natively. |
| Separate orchestration from business logic | `azure-pipelines/vendor-monitor.yml` does not contain a URL, vendor name, or business rule; all of that lives in `Run.ps1` / `Collectors/` / `config/`. |
| Enable both scheduled and manual execution | Same YAML; `schedules:` for the daily run, `parameters:` for the manual run with the same `pwsh` invocation. |
| Produce consistent logging and reporting | `modules/Logging.psm1` is the single log path; `output/ExecutionLog.txt` for the run log, `output/VendorReport.md` for the human report, `output/VendorReport.json` for the structured report. |
| Minimize infrastructure requirements | No new infra: public Ecteon release source, no auth, repo-committed state on a branch, no cache, no database, no extra service. Azure DevOps is the only "infrastructure" the framework depends on, and that is the team's existing platform. |
| Keep the solution source-controlled and extensible | Everything in this repo. Adding a vendor = `vendors.json`. Adding a new task category = new `tasks/<Name>/`. New collectors = new `Collectors/<Name>.ps1`. The `Script` escape hatch exists for the rare case that a vendor needs fully custom code. |

---

## Non-goals (deferred to post-MVP)

Per the brief and `docs/mvp-supplemental-plan.md` §O, these are
intentionally **not** built. The architecture pre-shapes them so
they are additive, not rewrites:

- Azure Functions / Durable Functions hosting.
- MCP server, AI-generated summaries, browser automation.
- Database or persistent storage beyond the `vendor-state` branch
  (a future Azure Blob backend is a single-module change in
  `modules/State.psm1`).
- Teams / email notifications. The run Summary tab and the
  `task.logissue type=warning` annotation on NEW detections cover
  the zero-infra visibility requirement.
- C# collector libraries, dashboards, historical search.
- `Graph.psm1` and any authenticated source. The secrets
  convention is documented in `docs/coding-standards.md` §11 so
  the first authenticated source does not set a bad precedent.
- Real RSS/HTML collectors (`RssCollector` / `HtmlCollector`
  ship as documented `NotImplemented` stubs).
- `pr-validation.yml` (PSScriptAnalyzer + Pester). Re-evaluate
  after MVP.

---

## Deferred target notes (do not lose)

1. **Ecteon Contraxx product scope** is the single open owner input
   (`docs/mvp-supplemental-plan.md` §R.1). The MVP ships with
   Contraxx only. Additional Ecteon products or sections are a
   copy-paste JSON snippet in vendors.json.
2. **Workforce / authenticated sources** (Optima, Loop,
   RosterOn, etc.) publish release notes on the authenticated
   `allocate.support` portal, not the public Zendesk Help Center
   that this MVP uses. They require auth and are out of scope
   until `Graph.psm1` (or the equivalent authenticated source
   support) is added. See `docs/mvp-task-list.md` "Context" block
   for the research finding.

---

## How to verify

```bash
# From the repo root:
pwsh -File scripts/verify-e2e.ps1
```

The script exercises all six success scenarios end to end against
the live Zendesk fixture and reports PASS/FAIL per scenario plus
a one-line summary. The current implementation passes 6/6
scenarios; any future change that breaks one of them is a real
regression and should be fixed before merging.
