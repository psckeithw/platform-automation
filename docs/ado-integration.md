# Azure DevOps Integration

Every `NEW` record is published to Azure DevOps as a User Story. The integration lives in `modules/AdoWorkItem.psm1` and is wired into `tasks/VendorMonitor/Run.ps1`. This document describes how it works today.

## Status

- **Shipped on `dev`.** No feature flag — every run that finds `NEW` items posts a User Story.
- **One vendor wired so far.** The integration is generic; the per-vendor collector decides which `NEW` records are published. The RLDatix S3 handoff in `docs/HANDOFF-rldatix-s3-notification.md` describes how RLDatix RL6 uses it.
- **What it does not change.** Collector contract, state map, or report artifacts. The JSON and Markdown reports continue to be the canonical machine- and human-readable outputs.

## What gets posted

For every record tagged `NEW`, a User Story is created with:

- **Project:** the value of `AZURE_DEVOPS_PROJECTS` in `.env`.
- **Work Item Type:** `User Story`.
- **Title:** the record's `Title` (typically `<Vendor> — <Product> — <Title>` or just `<Title>` for RLDatix RL6, which emits `<Version>` as the title).
- **Description (HTML):** an HTML body that includes a link to the release notes (`SourceUrl`) and identifying metadata.
- **Tags:** comma-separated; default `RLDatix, RL6, Auto-Generated`. The collector or caller can override.
- **Iteration Path:** `@CurrentIteration`.

The actual POST is `PATCH https://dev.azure.com/{org}/{project}/_apis/wit/workitems/$User%20Story?api-version=7.1` with a JSON Patch body.

## Authentication

Authentication is read from `.env` at the repo root by `Initialize-AdoConfig` (in `modules/AdoWorkItem.psm1`):

```
ADO_PAT=<personal access token>
AZURE_DEVOPS_ORG=<organization name>
AZURE_DEVOPS_PROJECTS=<project name>
```

Missing any of these is a hard error — the run exits with a clear message pointing at `.env`.

The PAT is sent as `Authorization: Basic <base64(:PAT)>` on every ADO request. It is read once per run and held in a module-scoped variable; it is never logged or written to disk.

`.env` is gitignored (`eadae4b chore: ignore .env (contains ADO_PAT and other secrets)`). The planned migration to a pipeline variable group is tracked in `roadmap.md`.

## Failure handling

`Run.ps1` wraps the per-item publish in its own try/catch. One failure to create a US for a single NEW record MUST NOT abort the run or stop the creation of subsequent USs. Failures are recorded in the run summary's `errors[]` with the original item's `vendor`, `product`, `sourceUrl`, and the HTTP status / error returned by ADO.

There is no automatic retry today. A transient failure (network, 5xx, 429) is logged and the run continues; the same record will be re-attempted on the next run if it is still `NEW` in state. (Idempotency is partial: the state map keys the record on its stable id, so a re-run after a failed publish does re-attempt. See "Idempotency" below for the planned improvement.)

## Idempotency

Today the integration is not idempotent against the state map: a record that was `NEW` and whose US creation failed will be re-attempted on the next run, creating a duplicate US.

The planned fix is to record the created US id back into the state map under the same record key so the diff logic skips records whose `NEW` status was already published. This is not implemented yet.

## Local dev

`Run.ps1` does not currently have a `-PublishDryRun` flag; that was planned in the earlier design. For now, the cheapest way to validate the payload shape without hitting ADO is to:

1. Temporarily replace `New-AdoWorkItem` with a stub that returns a fake id and logs the payload.
2. Or run with an `ADO_PAT` of an invalid value to force the failure path and observe the error logging.

Local runs require `.env` to be present (otherwise `Initialize-AdoConfig` throws). `.env` is not committed; copy from `.env.example` if one exists, or set the three keys manually.

## Pipeline

The Azure DevOps pipeline (`azure-pipelines/vendor-monitor.yml`) does not currently write `.env`. Either:

- The `.env` file is present in the repo at pipeline time (not recommended for secrets), or
- The pipeline must inject the three ADO variables into a `.env` file on the agent before invoking `Run.ps1`. This is tracked in `roadmap.md` under "Pipeline injects `.env` from a variable group".

## Adding a US creator for a new work-item type

`modules/AdoWorkItem.psm1` exports two functions: `Initialize-AdoConfig` and `New-AdoWorkItem`. To support Bug / Task / Epic, either:

- Extend `New-AdoWorkItem` with a `-WorkItemType` parameter and change the URI accordingly, or
- Add `New-AdoBug`, `New-AdoTask`, etc. alongside `New-AdoWorkItem`.

Decide based on whether the type-specific field shape (severity, remaining work, etc.) is needed.
