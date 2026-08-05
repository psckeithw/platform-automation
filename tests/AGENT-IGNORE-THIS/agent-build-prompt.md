# Single-Agent Build Prompt — Platform-Automation MVP

Hand the block below to one agent as a single task. Design/spec details live in `docs/mvp-task-list.md` and `docs/mvp-supplemental-plan.md`.

---

```text
You are implementing the Phase-1 MVP of the platform-automation repository: a config-driven PowerShell automation framework run by Azure DevOps Pipelines, with Vendor Release Monitoring as the proof of concept. Build it end to end in ONE session, in dependency order, verifying as you go.

WORKING DIRECTORY
/mnt/shared/code/UPO/platform-automation/.kilo/worktrees/seemly-gladiolus (git branch: seemly-gladiolus)

ENVIRONMENT (already verified — do not re-litigate)
- pwsh 7.6.4 is installed and runnable. Run all PowerShell as: pwsh -NoProfile -Command ...
- Outbound HTTPS works; Invoke-RestMethod against the fixture returns data; SHA256 works.

READ FIRST (authoritative; do not contradict)
- docs/mvp-task-list.md          -> your build checklist: phases, tasks, acceptance criteria
- docs/mvp-supplemental-plan.md  -> design + module/function contracts (referenced as §A–§R)
- architect-implemntation-brief.md -> original goals / non-goals / success criteria

LOCKED DECISIONS (do NOT change; if one seems wrong, STOP and flag)
- PowerShell 7 (pwsh), Set-StrictMode -Version Latest, target agent ubuntu-latest.
- Pipelines orchestrate; PowerShell does the work. Shared code in modules/, task logic in tasks/VendorMonitor/. No business logic in YAML.
- Config-driven generic collectors selected by a "Collector" field; adding a source = editing config/vendors.json. No hardcoded URLs.
- No auth / public sources only. Secrets convention is documented, not implemented.
- State = repo-committed state/vendor-state.json, pushed by the pipeline to a dedicated "vendor-state" branch with [skip ci]. ALL state access goes through modules/State.psm1.
- Change detection = SHA-256 of "Vendor|Product|Title|PublishedDate|Url"; stable Id is the record key when present; cold start = baseline (store all, report none as NEW).
- Testing deferred (no Pester / no pr-validation). Lint optional, not gated.

VERIFICATION FIXTURE (public, no auth — use as the working config so you can test end to end; the real target is intentionally deferred, this is a placeholder)
- Url: https://rldatix-public.zendesk.com/api/v2/help_center/en-us/sections/19851648629532/articles.json?sort_by=created_at&sort_order=desc&per_page=100
- ItemsPath: articles
- FieldMap: Id=id, Title=title, PublishedDate=created_at, SourceUrl=html_url, RawBody=body

BUILD IN THIS ORDER (full specs + per-task acceptance in docs/mvp-task-list.md)
1. Scaffold: create azure-pipelines/ config/ modules/ tasks/VendorMonitor/Collectors/ state/ output/ docs/; add .editorconfig (4-space, UTF-8, LF), .gitignore (ignore output/ contents but keep output/.gitkeep; do NOT ignore state/), state/.gitkeep, output/.gitkeep. Write docs/coding-standards.md including the secrets convention (ADO variable groups -> $env:, never in repo/JSON).
2. modules/Common.psm1: Get-Config; Invoke-HttpGetWithRetry (backoff; returns @{StatusCode;Content;Success;Error}; does not throw on HTTP error); Get-JsonPaged (follow next_page up to Settings.Collector.MaxPages); New-OutputDirectory; ConvertTo-SafeFileName; Get-UtcTimestamp.
3. modules/Logging.psm1: Start-TaskLog; Write-Log (levels INFO/WARN/ERROR/DEBUG; emit ##[section] and ##vso[task.logissue type=warning|error]); Write-VendorResultLine (vendor,url,httpStatus,count,durationMs); Add-RunSummary (##vso[task.addattachment type=Distributedtask.Core.Summary;name=VendorReport;]); Stop-TaskLog -> output/ExecutionLog.txt.
4. modules/State.psm1: Get-PreviousState; Compare-ReleaseState (NEW/CHANGED/UNCHANGED via the SHA-256 hash; key=Id else hash); Save-CurrentState (keyed map {key:{title,hash,firstSeen,sourceUrl}}); baseline when previous state empty.
5. modules/Html.psm1: ConvertFrom-HtmlToText (strip tags/entities, collapse whitespace).
6. config/settings.json ({Http{UserAgent,TimeoutSec,Retries},Collector{MaxPages},Output{CaptureRawHtml,MaxRawItems},Run{BaselineOnColdStart}}) and config/vendors.json (fixture entry, PascalCase keys per §G).
7. tasks/VendorMonitor/Collectors/ApiCollector.ps1: Invoke-ApiCollector($Vendor,$Product,$Settings) -> page via Get-JsonPaged, select ItemsPath (dot-path), map via FieldMap, log status+count, return normalized records @{Vendor;Product;Id;Title;PublishedDate;SourceUrl;RawBody}; throw on hard failure.
8. Collectors/RssCollector.ps1 and HtmlCollector.ps1: throw "NotImplemented: <name> is a future collector"; document the optional "Script" escape-hatch contract in the header (same normalized record shape).
9. tasks/VendorMonitor/Run.ps1: params -ConfigPath -SettingsPath -OutputPath -StatePath -Vendor[] -ForceRecheck. Import modules; Start-TaskLog; load settings+vendors, filter Enabled + optional -Vendor; Get-PreviousState; per vendor/product in try/catch PER VENDOR (dispatch by Collector/Script, accumulate, Write-VendorResultLine); Compare-ReleaseState (bypassed by -ForceRecheck but state still updated); generate outputs; Save-CurrentState; Stop-TaskLog. Exit 0 even when NEW found; exit 1 only on framework/collection failure; a single vendor failure logs an error annotation and continues.
10. Output (in Run.ps1 or a helper): output/VendorReport.json {generatedAt, summary{vendors,new,changed,unchanged,errors}, items[]}; output/VendorReport.md (counts + NEW/CHANGED table: Vendor,Product,Published,Title,Status,URL + short excerpt via ConvertFrom-HtmlToText); optional raw HTML captures <Vendor>-<Product>-<id>.html capped by MaxRawItems; ExecutionLog.txt; call Add-RunSummary; raise a warning annotation if any NEW.
11. azure-pipelines/vendor-monitor.yml: schedules cron "0 6 * * *" UTC always:true + manual; trigger: none; parameters vendor (All + configured) and forceRecheck (bool default false) forwarded to Run.ps1; pool ubuntu-latest, pwsh:true; steps: (a) checkout persistCredentials:true; (b) read state/vendor-state.json from vendor-state branch (cold start tolerated); (c) run Run.ps1 writing to $(Build.ArtifactStagingDirectory)/output; (d) PublishPipelineArtifact platform-automation-output condition: always(); (e) commit+push updated state to vendor-state branch with message "chore(state): vendor monitor update [skip ci]". NO business logic in YAML.
12. Runbook: append to README (or docs/) how to create the vendor-state branch, grant the Project Build Service Contribute on the repo, and confirm main branch policies are untouched. Finalize README "how to run locally" and "how to add a vendor".

LOCAL VERIFICATION (run before finishing; use pwsh -NoProfile)
- Every module imports with no errors under Set-StrictMode.
- Run tasks/VendorMonitor/Run.ps1 against the fixture: it writes state/vendor-state.json and output/*, exits 0, and reports nothing as NEW (baseline).
- Delete or edit one entry in state/vendor-state.json and re-run: only the added/changed items report NEW/CHANGED; the rest UNCHANGED.
- Temporarily add a broken vendor entry: confirm other vendors still process and an error annotation is emitted; then revert.
- Confirm VendorReport.json summary counts equal items; VendorReport.md renders.

GUARDRAILS
- Do NOT commit or push anything unless explicitly asked; leave all changes in the working tree.
- Do NOT create: the other pipelines (graph-automation/ado-reporting/maintenance), other task folders, Graph.psm1, Utilities.psm1, environments.json, tests/, pr-validation.yml (all deferred).
- Stay within the file paths above; follow docs/coding-standards.md.
- If a locked decision appears wrong, STOP and report instead of deviating.

DONE WHEN
All files above exist, modules import clean, the local verification sequence passes, and each brief success criterion (plan §N) maps to an implementing file. Report what you built, the verification output, and anything you flagged.
```
