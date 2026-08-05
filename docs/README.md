# Documentation

This directory documents `platform-automation` as it exists today. The intent is to describe the framework, the single shipped task (`VendorMonitor`), and the ADO User Story publishing that turns every `NEW` release into a ticket.

If something here disagrees with the code, the code wins — update this file.

## Read in this order

1. [overview.md](overview.md) — what the project is, what it does today, what it is not.
2. [architecture.md](architecture.md) — end-to-end design and module boundaries.
3. [collectors.md](collectors.md) — how vendors are polled, how to add one.
4. [state-and-changes.md](state-and-changes.md) — how "new" is detected.
5. [configuration.md](configuration.md) — the JSON files and `.env` that drive every run.
6. [outputs.md](outputs.md) — what every run produces.
7. [pipeline.md](pipeline.md) — the Azure DevOps pipeline.
8. [local-run-and-verify.md](local-run-and-verify.md) — run it on your laptop.
9. [ado-integration.md](ado-integration.md) — how US creation works.
10. [modules-reference.md](modules-reference.md) — what lives in `modules/`.
11. [roadmap.md](roadmap.md) — what is stubbed, what comes next, what is explicitly not a goal.

## Vendor-specific notes

- [HANDOFF-rldatix-s3-notification.md](HANDOFF-rldatix-s3-notification.md) — RLDatix RL6 S3 source handoff. The first vendor wired into the publish flow.

## Quick reference

- Entry point: [`tasks/VendorMonitor/Run.ps1`](../tasks/VendorMonitor/Run.ps1)
- Pipeline: [`azure-pipelines/vendor-monitor.yml`](../azure-pipelines/vendor-monitor.yml)
- Config: [`config/vendors.json`](../config/vendors.json), [`config/settings.json`](../config/settings.json), [`.env`](../.env) (gitignored)
- Modules: [`modules/`](../modules/)
- Collectors: [`tasks/VendorMonitor/Collectors/`](../tasks/VendorMonitor/Collectors/)
- E2E check: [`scripts/verify-e2e.ps1`](../scripts/verify-e2e.ps1)

## Conventions used in these docs

- File paths are repo-relative.
- CLI commands assume the repo root as the working directory.
- PowerShell snippets use `pwsh` (PowerShell 7+). Do not use Windows PowerShell 5.1.
- No diagrams (none yet exist in the codebase; add a text-only flow when one would help).
