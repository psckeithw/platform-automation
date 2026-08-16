# Task Plan — RL6 Release Monitor + User Story Creation

## Goal

Detect new RL6 release versions from the public RLDatix S3 bucket XML feeds, and automatically create one Azure DevOps User Story per new version under `@CurrentIteration`.

## Architecture

```
S3 XML feeds ──► Invoke-RLDatixCollector.ps1 ──► normalized records (one per version)
                                                          │
                                                          ▼
                                                  Run.ps1 (Compare-ReleaseState)
                                                          │
                                                    NEW records?
                                                          │
                                                          ▼
                                              New-AdoWorkItem (ADO REST API)
                                                          │
                                                          ▼
                                              User Story created @CurrentIteration
```

## Implementation Tasks

### 1. Build S3 RLDatix Collector

**File:** `tasks/VendorMonitor/Collectors/Overrides/Invoke-RLDatixCollector.ps1`

- GET the two XML feeds (Enhancements, Fixes) — no auth, public S3
- Parse with `[xml]` (PowerShell native)
- Group by `ReleaseNumber` across both feeds
- Emit **one normalized record per release version** with:
  - `Vendor` = `RLDatix`
  - `Product` = `RL6`
  - `Title` = `RL6 <Version>`
  - `Id` = `rl6-<version>` (stable key for state diff)
  - `PublishedDate` = S3 object `Last-Modified`
  - `SourceUrl` = RL6 landing page URL
  - `RawBody` = short summary: enhancement count + fix count + affected modules
- Follows the `Invoke-OverrideCollector` dispatch contract (same shape as `Invoke-EcteonCollector.ps1`)

### 2. Build ADO Work-Item Module

**File:** `modules/AdoWorkItem.psm1`

- Function `New-AdoWorkItem`:
  - Parameters: `Title`, `Description`, `IterationPath`, `AreaPath`, `PatToken`, `Organization`, `Project`
  - Calls `POST https://dev.azure.com/{org}/{project}/_apis/wit/workitems/$User%20Story?api-version=7.1`
  - Sets fields:
    - `System.Title` = title
    - `System.Description` = description (HTML)
    - `System.IterationPath` = `@CurrentIteration` (default)
    - `System.Tags` = `RLDatix, RL6, Auto-Generated`
  - Uses PAT from parameter (passed in, not read from env)
  - Returns the created work item ID

### 3. Wire into Run.ps1

**File:** `tasks/VendorMonitor/Run.ps1`

- After `Compare-ReleaseState`, iterate over records with `State = "NEW"`
- For each NEW record, call `New-AdoWorkItem`
- Gate with setting: `Notify.CreateUserStory: true` in `settings.json`
- Error handling: log failures per work item, continue processing remaining
- Only run when NOT in `-Baseline` mode (cold start should not create US)

### 4. Update vendors.json

**File:** `config/vendors.json`

```json
{
  "Vendor": "RLDatix",
  "Enabled": true,
  "Script": "tasks/VendorMonitor/Collectors/Overrides/Invoke-RLDatixCollector.ps1",
  "Products": [{ "Product": "RL6" }]
}
```

### 5. Update settings.json

**File:** `config/settings.json`

- Add/verify `Notify` block:
  ```json
  "Notify": {
    "Enabled": true,
    "CreateUserStory": true
  }
  ```

### 6. Update Pipeline YAML

**File:** `azure-pipelines/vendor-monitor.yml`

- Add variable group reference for ADO PAT (eventually from Key Vault)
- Ensure the pipeline step has access to `modules/AdoWorkItem.psm1`
- No structural changes needed — Run.ps1 orchestrates everything

### 7. Verify End-to-End

- Run locally:
  ```bash
  pwsh -NoProfile -File ./tasks/VendorMonitor/Run.ps1 \
    -Vendor RLDatix \
    -OutputPath ./output -StatePath ./state
  ```
- Confirm `VendorReport.json` contains NEW records for RL6 versions
- Confirm a User Story is created in ADO Heartbeat project under `@CurrentIteration`
- Confirm state is persisted so subsequent runs show UNCHANGED (no duplicate US)

## Design Decisions

| Decision | Choice |
|---|---|
| US granularity | One per release version (not per fix/enhancement) |
| US creation timing | Inline in the same pipeline run |
| PAT source | Key Vault → function env vars (not `.env` file) |
| Iteration path | `@CurrentIteration` (ADO magic value) |
| Cold start | No US created — baseline mode sets state without emitting NEW |
| Failure handling | Per-record catch; one failure does not block remaining US creation |

## Key Files

| Path | Action |
|---|---|
| `tasks/VendorMonitor/Collectors/Overrides/Invoke-RLDatixCollector.ps1` | Create (S3 XML collector) |
| `modules/AdoWorkItem.psm1` | Create (ADO US REST API) |
| `tasks/VendorMonitor/Run.ps1` | Modify (wire US creation) |
| `config/vendors.json` | Modify (add RLDatix entry) |
| `config/settings.json` | Modify (verify Notify block) |
| `azure-pipelines/vendor-monitor.yml` | Modify (add PAT variable group) |