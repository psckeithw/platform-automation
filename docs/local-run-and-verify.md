# Local Run and Verify

You can run `VendorMonitor` end-to-end on any machine that has PowerShell 7. The vendor-collector half runs without any secrets; the ADO-publish half requires `.env` to be present.

## Prerequisites

- PowerShell 7+ (`pwsh`). On Linux/macOS: `brew install --cask powershell` or the official installer. On Windows: install from the Microsoft Store or the MSI.
- Outbound HTTPS to the configured vendor endpoints.
- A working copy of this repository.
- For the ADO publish step to actually post a User Story: a `.env` file at the repo root with `ADO_PAT`, `AZURE_DEVOPS_ORG`, `AZURE_DEVOPS_PROJECTS` set. See `configuration.md`. If `.env` is absent the framework still runs; it just skips the publish step with a logged error and continues.

## Run the task locally

From the repo root:

```bash
pwsh -NoProfile -File ./tasks/VendorMonitor/Run.ps1 \
  -ConfigPath   ./config/vendors.json \
  -SettingsPath ./config/settings.json \
  -OutputPath   ./output \
  -StatePath    ./state \
  -Baseline
```

- `-Baseline` (or any cold start) records every record with status `BASELINE`. Nothing is reported as `NEW`. Use this the first time you ever run, or any time you want to reset the diff.
- Drop `-Baseline` on the next run to see the actual diff: every record will be `UNCHANGED` (because the source has not changed).
- `-Vendor <Name>` filters to one vendor entry. Add the name to the YAML parameter list when you want the pipeline to support it too.
- `-ForceRecheck` re-emits every record with status `RECHECK` but still updates the state map, so the next non-force run is unaffected.

Exit code is `0` on a successful run (including runs that find NEW releases and successfully publish USs, and runs that find NEW releases but fail to publish them) and `1` only on a framework-level error (config missing, module load failure). Per-vendor failures and per-item publish failures do not change the exit code; they appear in the run summary's `errors[]`.

If `ADO_PAT` is missing or invalid the publish step will fail for every `NEW` item. The rest of the run (collectors, reports, state) completes normally.

## End-to-end verification

`scripts/verify-e2e.ps1` runs six scenarios against the live Zendesk source (and a hardcoded broken vendor for the isolation check). Each scenario writes its own `output/` and `state/` under `/tmp/kilo-e2e-*` and tears them down on success unless `-KeepArtifacts` is passed.

```bash
pwsh -File ./scripts/verify-e2e.ps1
```

Expected: `6 passed, 0 failed`. Scenarios:

1. **Cold start is a baseline.** Exit 0; `counts.items == 5`, `counts.baseline == 5`, `counts.new == 0`, `counts.errors == 0`.
2. **Identical second run is all UNCHANGED.** Exit 0; `counts.unchanged == 5`, `counts.new == 0`, `counts.changed == 0`.
3. **Hash mutation is one CHANGED.** Manually overwrites one record's hash in the state file; the next run should report `counts.changed == 1`, `counts.unchanged == 4`.
4. **State entry removal is one NEW.** Removes one entry from the state file; the next run should report `counts.new == 1`, `counts.unchanged == 4`.
5. **Per-vendor isolation.** Builds a mixed config with one broken URL and one good URL, runs with `-Baseline`. Exit 0; `counts.errors == 1`, `counts.items == 105`, and `summary.errors[0].vendor == 'BrokenVendor'`.
6. **All expected artifacts present.** Checks that `output/VendorReport.json`, `output/VendorReport.md`, `output/ExecutionLog.txt`, and `state/vendor-state.json` all exist.

The script depends on outbound HTTPS to `rldatix-public.zendesk.com`. If that endpoint is unreachable from the host, scenarios 1-5 fail.

The script does not exercise the ADO publish step. To exercise that, run `Run.ps1` directly with a `.env` that contains a valid `ADO_PAT` and a vendor configuration that yields `NEW` items.

## State on disk after a run

After any non-baseline run:

```
output/
  VendorReport.json
  VendorReport.md
  ExecutionLog.txt
  (optional) <Vendor>-<Product>-<Id>.html

state/
  vendor-state.json
```

`state/` is `.gitignore`d locally. Do not commit `state/vendor-state.json` to `main`; the pipeline manages it on `vendor-state`.

## Common errors

| Symptom                                                                      | Likely cause                                                                                  |
| ---------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| `Get-Config: file not found at '<path>'.`                                    | Working directory is not the repo root, or `ConfigPath` / `SettingsPath` is wrong.             |
| `Get-Config: '<path>' is missing required key 'Vendors'.`                    | JSON file is missing a top-level key. Add it.                                                 |
| `Get-Config: '<path>' parsed to $null.`                                      | File is empty or starts with `null`.                                                          |
| `Initialize-AdoConfig: .env file not found at '<path>'`                      | `.env` missing. Either create it or accept that publish will be skipped.                      |
| `Initialize-AdoConfig: ADO_PAT not found in .env`                            | `.env` present but `ADO_PAT` is missing or empty.                                             |
| `vendor entry has neither 'Collector' nor 'Script' set`                      | The vendor config has neither field. Add one.                                                 |
| `collector file not found: tasks/VendorMonitor/Collectors/<Name>.ps1`        | `Collector` value does not match a built-in collector file name.                              |
| `NotImplemented: HtmlCollector is a future collector...`                     | You set `Collector: "HtmlCollector"` or `"RssCollector"`. Use `ApiCollector` or a `Script` override for now. |
| Every record is `NEW` on every run                                           | State file is empty or missing. Use `-Baseline` once.                                         |
| `Get-PreviousState: '<file>' is unreadable or invalid JSON`                  | State file is corrupt. See `state-and-changes.md` for repair.                                 |
| Every `NEW` item fails with `New-AdoWorkItem: failed to create '<title>': ...` | `ADO_PAT` is invalid or lacks the work-item scope, or `AZURE_DEVOPS_ORG` / `AZURE_DEVOPS_PROJECTS` are wrong. |
| Pipeline run never commits state to `vendor-state`                           | Project Build Service lacks `Contribute`. See `pipeline.md`.                                  |

## Adding a new vendor without breaking the diff

1. Add the entry to `config/vendors.json`.
2. Run locally with `-Baseline`. The new vendor is seeded.
3. Commit `config/vendors.json` only. Do not commit `state/`.
4. Push; the next pipeline run picks up the new vendor. Because the pipeline already has prior state on `vendor-state`, the new vendor's records will be tagged `BASELINE` (cold-start for that vendor, even though the run overall is a diff).
5. If the new vendor is supposed to publish USs, make sure `.env` (or its variable-group equivalent on the agent) is configured. A first publish will fail if it is not.
