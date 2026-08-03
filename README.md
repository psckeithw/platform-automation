# platform-automation

Centralized, config-driven **PowerShell automation framework** orchestrated by Azure DevOps Pipelines. Pipelines orchestrate; PowerShell does the work. Phase 1 MVP delivers **Vendor Release Monitoring (RLDatix)** as the proof-of-concept.

> This README is maintained in an appendable format. Add new sections at the bottom; do not rewrite existing ones.

---

## Documents (read in this order)

1. `architect-implemntation-brief.md` — the original architecture & goals brief (source of truth for intent).
2. `docs/mvp-supplemental-plan.md` — the **implementation-ready plan** (delta/decisions that refine the brief). **Build to this.**
3. This README — project entry point + handoff instructions below.

---

## Handoff to the Next Agent (Review → Plan → Implement)

You are picking up a **greenfield MVP**. The brief and the supplemental plan are complete and the six key decisions are resolved. Your job is to review, confirm, then implement in dependency order.

### Current state
- Repo contains only: `architect-implemntation-brief.md`, `docs/mvp-supplemental-plan.md`, this README, and `.kilo/` tooling. **No code yet.**
- All design decisions are locked (see `docs/mvp-supplemental-plan.md` §A). Do not re-litigate them without a stated reason.

### Locked decisions (do not change silently)
1. Change detection = **pipeline-artifact `state.json`** behind a swappable `State.psm1` interface (no DB).
2. RLDatix source = **Zendesk Help Center public REST API**, no auth (verified live).
3. Runtime = **PowerShell 7 (`pwsh`)** on `ubuntu-latest`.
4. **No auth/secrets** — all sources public. `Graph.psm1` deferred.
5. Build **only** `azure-pipelines/vendor-monitor.yml` + `tasks/VendorMonitor/`. No other pipelines/task folders.
6. **Testing deferred** — no Pester harness; ship `docs/coding-standards.md` only.

### Step 0 — Review before coding
- Read the brief, then `docs/mvp-supplemental-plan.md` end to end.
- Re-verify the Zendesk API is still reachable (public, no auth):
  `GET https://rldatix-public.zendesk.com/api/v2/help_center/en-us/sections/19851648629532/articles.json?per_page=5`
  Expect JSON with `articles[]` each having `id`, `title`, `html_url`, `created_at`, `updated_at`, `body`.
- If any locked decision no longer holds (e.g., API now gated), stop and flag it before implementing.

### Step 1 — Implement in this dependency order (plan §M)
1. **Scaffold** — folders per plan §D, `.gitignore` (`output/`, `state/`, `.kilo/node_modules/`), `.editorconfig` (4-space, UTF-8, LF), `.gitkeep` in `output/` and `state/`, `docs/coding-standards.md`.
2. **Core modules** — `modules/Common.psm1`, `Logging.psm1`, `Utilities.psm1` (HTTP + retry), `State.psm1`; `Html.psm1` minimal. Contracts in plan §E.
3. **Config** — `config/vendors.json` (RLDatix / IntelligentContract, section `19851648629532`) + `config/settings.json`; validate in `Get-Config` (plan §G).
4. **Collector** — `tasks/VendorMonitor/Collectors/ZendeskApiCollector.ps1` → `Invoke-ZendeskApiCollector` (pagination + normalization, plan §F).
5. **Orchestration** — `tasks/VendorMonitor/Run.ps1` (collector selection, state diff, **per-vendor try/catch**, plan §H).
6. **Output** — `VendorReport.json`, `VendorReport.md`, optional raw HTML, `ExecutionLog.txt` (plan §I).
7. **Pipeline** — `azure-pipelines/vendor-monitor.yml` (schedule + manual + params, download prior `state`, run, publish `output` and `state`; plan §J).

Steps 1→7 are strictly ordered. Do not start a step until its predecessors compile/run.

### Step 2 — Verify (definition of done)
Run locally, then confirm the pipeline definition:
```bash
pwsh ./tasks/VendorMonitor/Run.ps1 \
  -ConfigPath config/vendors.json \
  -SettingsPath config/settings.json \
  -OutputPath output \
  -StatePath state \
  -Baseline
```
- First run (`-Baseline` / cold start) → all items recorded as baseline, `state/state.json` written, artifacts generated in `output/`.
- Second run **without** `-Baseline` → unchanged items reported `UNCHANGED`, only genuinely new/edited articles reported `NEW`/`CHANGED`.
- A single vendor/product failure must **not** abort the run (per-vendor try/catch) and must surface as a warning + logged HTTP status.
- Confirm all success criteria in plan §N are met.

### Guardrails
- **No business logic in YAML.** Pipelines only schedule, pass params, run PowerShell, publish artifacts.
- **No hardcoded URLs/settings** — everything via `config/`.
- **Config-driven collectors**, not per-vendor scripts (plan §B). Adding a vendor = editing `vendors.json`.
- Keep `State.psm1` the only code that knows the on-disk state format (swappable later for Blob/DB).
- UTC timestamps everywhere; structured logging via `Logging.psm1`.
- Commit/push and PR creation only when explicitly requested.

### How to add a vendor later (framework validation)
Append an entry to `config/vendors.json` with `collector: "ZendeskApi"` (or a future collector) and its `baseUrl`/`locale`/`sectionId`. No pipeline change required. A ready example: add PolicyStat as a second product using section `10457658046492`.

---

## Changelog
- 2026-08-02 — Added architecture brief, implementation-ready supplemental plan (`docs/mvp-supplemental-plan.md`), and this handoff README. No code yet; ready for implementation.
