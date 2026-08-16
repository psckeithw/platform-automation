# Handoff – Azure DevOps User Story auto‑creation (OSS‑120B)

## Current status
- No `modules/AdoNotifier.psm1` file exists.
- `Run.ps1` has been patched to add a `workItemId` field to the JSON report and to attach the ID returned by the notifier to each item.
- The script still calls a non‑existent function `New‑RLDatixAlertWorkItem`; a proper notifier module must be added.
- `modules/AdoWorkItem.psm1` does not exist in the repo.
- `scripts/verify-e2e.ps1` now sets `ADO_TEST_MODE=1` and asserts that a `workItemId` appears for the “new” scenario.
- No `Ado` section in `config/settings.json`.
- Documentation (`docs/mvp-success-criteria.md`) has not been updated.

## Required next steps
1. Create `modules/AdoNotifier.psm1` that implements `New‑AdoWorkItem` (with a test‑mode guard).
2. Import that module in `Run.ps1` and replace the call to the missing function with `New‑AdoWorkItem`.
3. Add an `Ado` configuration block to `config/settings.json`.
4. Update `docs/mvp-success-criteria.md` to mention automatic User‑Story creation.
5. Run the e2e suite; it should now pass all scenarios.

## Verification checklist
- [ ] `modules/AdoNotifier.psm1` exists and is syntactically valid.
- [ ] `Run.ps1` imports the module and calls `New‑AdoWorkItem`.
- [ ] JSON report includes `workItemId` for NEW/CHANGED items.
- [ ] `config/settings.json` contains an `Ado` section.
- [ ] Documentation updated.
- [ ] `scripts/verify-e2e.ps1` passes.
