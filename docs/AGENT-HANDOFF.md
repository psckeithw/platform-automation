# Agent Handoff – RL6 Release Monitor & User Story Creation

## Session Review
- **Goal**: Detect new RL6 releases from the public RLDatix S3 bucket and automatically create a single Azure DevOps User Story per new version (targeted to `@CurrentIteration`).
- **Current state**:
  - The framework (`Run.ps1`, modules, pipeline) is in place but **no collector for the S3 XML feeds** exists.
  - `modules/AdoWorkItem.psm1` is a stub; the REST‑API logic to create a User Story is not implemented.
  - `Run.ps1` already contains a placeholder section for US creation, invoking `New-AdoWorkItem` (which is currently missing).
  - `config/vendors.json` already references a script placeholder `Invoke-RLDatixCollector.ps1` (file does not exist yet).
  - `config/settings.json` does not yet contain a `Notify` block for the User‑Story feature.
- **Artifacts created**:
  - `TASK-PLAN.md` – a detailed, ordered todo list.
  - `AGENT-HANDOFF.md` – this handoff document (the file you are reading now).

## Pending Work (high‑priority)
1. **Implement `Invoke-RLDatixCollector.ps1`**
   - Download the two XML feeds (`Enhancements and Changes.xml` and `Fixes.xml`) from the public S3 bucket.
   - Parse with PowerShell `[xml]`.
   - Group records by `ReleaseNumber`, compute enhancement/fix counts, collect distinct modules, and emit a **single normalized record per version** with fields:
     - `Vendor = "RLDatix"`
     - `Product = "RL6"`
     - `Id = "rl6-<Version>"`
     - `Title = "RL6 <Version>"`
     - `PublishedDate` – optional (use S3 object `Last-Modified` if desired).
     - `SourceUrl` – the landing page URL from `.env` (`RLDATIX_COMPARE_URL`).
     - `RawBody` – summary HTML containing counts and module list.
2. **Implement `New-AdoWorkItem` in `modules/AdoWorkItem.psm1`**
   - Use Azure DevOps REST API `POST /{org}/{project}/_apis/wit/workitems/$User%20Story?api-version=7.1`.
   - Accept parameters `Title`, `DescriptionHtml`, optional `IterationPath` (default `@CurrentIteration`).
   - Authenticate with PAT obtained from an environment variable (KV‑populated in the pipeline).
   - Return the created work‑item ID and log success/failure.
3. **Wire US creation into `tasks/VendorMonitor/Run.ps1`**
   - After the diff step, iterate `$newItems = $tagged | Where-Object { $_.ChangeStatus -eq 'NEW' }`.
   - Call `New-AdoWorkItem -Title $item.Title -DescriptionHtml $fullBody`.
   - Log the result with `Write-Log`.
4. **Update configuration**
   - Add a `Notify` block in `config/settings.json`:
     ```json
     "Notify": { "Enabled": true, "CreateUserStory": true }
     ```
   - Ensure the PAT variable group is referenced in `azure-pipelines/vendor-monitor.yml` (no code change needed if the group is already set).
5. **Verification**
   - Run locally with `pwsh -File tasks/VendorMonitor/Run.ps1 -Vendor RLDatix -OutputPath ./output -StatePath ./state`.
   - Confirm a User Story appears in Azure DevOps under the current iteration.
   - Ensure subsequent runs report the record as `UNCHANGED` and **do not create duplicate** stories.

## Handoff Prompt for the Next Agent
```
You are a Kilo sub‑agent tasked with completing the RL6 Release Monitor implementation.
Your responsibilities are:
1. Create `tasks/VendorMonitor/Collectors/Overrides/Invoke-RLDatixCollector.ps1` that fetches the two public S3 XML feeds, parses them, groups by `ReleaseNumber`, and returns one normalized record per version (as described in the pending work list).
2. Implement `New-AdoWorkItem` in `modules/AdoWorkItem.psm1` to post a User Story to Azure DevOps using the PAT from the environment.
3. Modify `tasks/VendorMonitor/Run.ps1` to call `New-AdoWorkItem` for each NEW record (skip baseline runs).
4. Add a `Notify` block to `config/settings.json` enabling user‑story creation.
5. Test the end‑to‑end flow locally and ensure the story is created under `@CurrentIteration`.
6. Commit your changes to the `dev` branch and open a pull request against `main`.

Follow existing code patterns (see `Invoke-EcteonCollector.ps1` for collector structure and `Run.ps1` for logging). Use robust error handling and log all actions.
```

---
*This handoff file was generated automatically to allow a downstream Kilo agent to resume work without ambiguity.*