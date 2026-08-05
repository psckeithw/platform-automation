# Coding Standards — Platform-Automation

Scope: every PowerShell module, script, and helper in this repository. The
overriding goal is consistency so the framework can be read and extended
by anyone without reverse-engineering intent. Where this document and the
architecture brief disagree, the brief and `docs/mvp-supplemental-plan.md`
win.

Refs: `architect-implemntation-brief.md` (goals & non-goals),
`docs/mvp-supplemental-plan.md` §L, `docs/mvp-task-list.md` T0.2.

---

## 1. Runtime

- **PowerShell 7+** (`pwsh`). All scripts must run cross-platform
  (`ubuntu-latest` agent). Do not use Windows-only cmdlets, modules, or
  path separators.
- `Set-StrictMode -Version Latest` at the top of every module and entry
  script. The framework modules already do this; do not turn it off.

---

## 2. Modules vs. Scripts

- Reusable, side-effect-free logic lives in **`modules/*.psm1`** and
  exports functions explicitly with `Export-ModuleMember`.
- Per-task orchestration lives in **`tasks/<TaskName>/Run.ps1`**. The
  entry script is the only thing YAML pipelines call.
- A module must not import another module. The entry script is the only
  place that orchestrates `Import-Module` calls.

### Module template

```powershell
Set-StrictMode -Version Latest

<#
.SYNOPSIS
    One-line purpose.
.DESCRIPTION
    Longer description, contract, side effects.
#>

function Verb-Noun {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Something
    )

    # ...
}

Export-ModuleMember -Function Verb-Noun
```

---

## 3. Naming

- Use **PowerShell-approved verbs** (`Get-Verb` to verify). Examples used
  in this repo: `Get-`, `Set-`, `Save-`, `Compare-`, `Write-`, `Start-`,
  `Stop-`, `Add-`, `New-`, `Convert-`, `Invoke-`, `Import-`.
- PascalCase function and parameter names. `$Script:$_` automatic
  variables are not used.
- Modules are `PascalCase.psm1`; entry scripts are `Run.ps1`.

---

## 4. Parameters & Validation

- Every public function declares `[CmdletBinding()]` and uses
  `[Parameter()]` attributes.
- Validate at the boundary: `[ValidateNotNullOrEmpty()]`,
  `[ValidateSet()]`, `[ValidateRange()]`, `[ValidateScript()]`. Fail
  early with actionable errors.
- Prefer typed parameters (`[string]`, `[int]`, `[hashtable]`,
  `[object[]]`) over loose `[object]`. When accepting arbitrary config
  objects, accept `[object]` and access named properties defensively.

---

## 5. Error Handling

- **Never** let the framework swallow an exception silently.
- Use `try { } catch { }` at boundaries the operator can act on
  (per-vendor loops, per-collector calls). Re-throw or convert to a
  structured result object with `@{ Success; StatusCode; Error }`.
- Helpers that perform I/O (HTTP, file) **return** a result object
  rather than throwing on non-fatal failures; the caller decides whether
  to throw.
- Framework / configuration errors are fatal and exit `1`. A "no new
  releases" run is **not** a failure — it exits `0`.

---

## 6. Logging

- All logging goes through `modules/Logging.psm1` (`Write-Log`,
  `Start-TaskLog`, `Stop-TaskLog`, `Write-VendorResultLine`,
  `Add-RunSummary`).
- Levels: `INFO`, `WARN`, `ERROR`, `DEBUG`. Default verbosity is
  `INFO`. Do not log secrets — ever — at any level.
- Console output uses Azure DevOps logging commands (`##[section]`,
  `##vso[task.logissue ...]`) so logs render natively in the pipeline UI.
- **UTC timestamps everywhere.** Use the framework's `Get-UtcTimestamp`
  helper. Local-time stamps are not acceptable.

---

## 7. Configuration

- **No hardcoded URLs, IDs, secrets, or vendor-specific strings in
  code.** Everything is in `config/*.json` and consumed via
  `Get-Config`.
- A vendor is added by appending to `config/vendors.json`. Adding a
  vendor must not require a code change for any JSON-API source.
- `config/*.json` is validated by `Get-Config`; validation errors must
  include the file path, the missing/invalid key, and a one-line fix
  hint.

---

## 8. State

- All state access goes through `modules/State.psm1`. No other code
  reads or writes `state/vendor-state.json`.
- The on-disk format may change without notice outside `State.psm1` —
  that is the seam that lets us migrate to Azure Blob or a database
  later without touching collectors or `Run.ps1`.
- The pipeline commits state to the dedicated `vendor-state` branch
  with `chore(state): vendor monitor update [skip ci]`. Local runs
  write the file in the working tree and skip the commit.

---

## 9. Collectors

- One collector per file under `tasks/<TaskName>/Collectors/`.
- Collector file names match the public function they define
  (`ApiCollector.ps1` defines `Invoke-ApiCollector`).
- The output is a normalized record object:
  `Vendor, Product, Id, Title, PublishedDate, SourceUrl, RawBody`
  (see `docs/mvp-supplemental-plan.md` §F). A new collector must
  return this shape — no vendor-specific record types.
- Collectors throw on hard failure. Per-vendor `try/catch` in
  `Run.ps1` is the resilience boundary.
- `RssCollector` and `HtmlCollector` ship as documented stubs that
  throw `NotImplemented`. They exist so the collector dispatcher
  contract is complete; the actual implementations are post-MVP.

---

## 10. Output & Artifacts

- All run outputs land under `output/` and are gitignored.
- The structured report is `output/VendorReport.json`; the human
  report is `output/VendorReport.md`; the run log is
  `output/ExecutionLog.txt`. Optional raw captures go alongside.
- Filenames must be safe across agents — use
  `ConvertTo-SafeFileName` for any vendor- or product-derived name.

---

## 11. Secrets Convention (documented, not implemented in MVP)

> **MVP has no authenticated sources.** This convention is established
> now so the first authenticated source does not set a bad precedent.

- **Secrets never enter the repository or JSON config.** No tokens,
  client secrets, API keys, or connection strings in any committed
  file, ever.
- Secrets come from **Azure DevOps variable groups** (optionally
  Key Vault–linked). The pipeline injects them as environment
  variables at run time.
- Scripts read them with `$env:MY_TOKEN` (or whatever name the
  variable group defines). Never echo, log, or persist the value
  to disk.
- If a secret must be passed to a child process, pass it via the
  environment, not the command line.
- Local development uses `pwsh` with environment variables set in
  the developer's shell. Do not commit a `.env` file or similar.

If you need a secret and the variable group does not exist yet, ask
the collection admin to create it; do not hardcode a placeholder.

---

## 12. Pipelines (YAML)

- YAML orchestrates only: triggers, parameters, checkout, `pwsh`
  invocation, artifact publish. **No business logic in YAML.**
- No literal URLs, IDs, or vendor lists in YAML. The pipeline receives
  parameters and forwards them to `Run.ps1`.
- `pwsh: true` on every script step.
- Scheduled and on-demand from the same YAML. Do not split a schedule
  from a manual run into two files.
- State is read from and written to the `vendor-state` branch using
  `persistCredentials: true` and `[skip ci]` on the commit message.

---

## 13. Documentation

- `README.md` is **appendable**. New sections are added at the bottom;
  do not rewrite or reorder existing ones.
- Public functions have **comment-based help** (`.SYNOPSIS`,
  `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`).
- The handoff block at the top of `README.md` is the source of truth
  for "where to start"; if you change the entry point or layout,
  update it.

---

## 14. Testing (deferred)

- No Pester, no `pr-validation.yml`, no test gate in MVP
  (`docs/mvp-supplemental-plan.md` §A#6, §Q5).
- Every module must import cleanly under `Set-StrictMode -Version
  Latest` and pass a small scripted smoke check (see each module's
  task acceptance criterion in `docs/mvp-task-list.md`).
- PSScriptAnalyzer may be run locally; warnings are not blockers.
- Post-MVP, add `pr-validation.yml` (PSScriptAnalyzer + Pester smoke
  tests) — see `docs/mvp-supplemental-plan.md` §O.

---

## 15. Editor & Formatting

- `.editorconfig` is authoritative: UTF-8, LF, final newline, 4-space
  indent (2-space for JSON/YAML/Markdown prose where it improves
  diffs).
- One statement per line. Avoid `\` line continuations inside script
  blocks; use splatting or a here-string instead.
- Trailing whitespace is trimmed by the editor. Markdown leaves
  intentional trailing spaces alone (line-break semantics).
