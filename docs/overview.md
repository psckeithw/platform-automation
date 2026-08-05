# Overview

`platform-automation` is a centralized, config-driven PowerShell framework orchestrated by Azure DevOps Pipelines. Pipelines schedule and run; PowerShell does the work.

## What it does today

The only task implemented so far is **VendorMonitor**: an overnight job that polls public release-notes sources for a list of configured vendors, diffs the result against the last successful run, and produces a structured report of NEW and CHANGED releases.

Every `NEW` release is published to Azure DevOps as a User Story (via `modules/AdoWorkItem.psm1`), with a link to the release notes embedded in the US description. The RLDatix RL6 S3 source is the first vendor wired into this flow; see `docs/HANDOFF-rldatix-s3-notification.md`.

## Who runs it

The pipeline runs unattended on a daily schedule. There is no service account, no daemon, and no UI. Configuration is committed JSON. State is a single JSON file on a dedicated `vendor-state` branch. ADO authentication is read from a gitignored `.env` file.

## What it is not

- It is not a CMS, a database, or a search index.
- It does not summarize, classify, or rewrite release notes with AI.
- It does not browse the web with a headless browser.
- It does not persist data anywhere other than the `state/vendor-state.json` file.

## High-level flow

```
Azure DevOps Pipeline (daily 06:00 UTC + manual)
        |
        v
tasks/VendorMonitor/Run.ps1
        |
        +-- load config/vendors.json, config/settings.json, .env
        +-- read prior state from state/vendor-state.json (if any)
        |
        +-- per vendor/product, dispatch to a collector:
        |     - ApiCollector  (generic JSON API, declarative)
        |     - HtmlCollector (stub; future)
        |     - RssCollector  (stub; future)
        |     - Script override (full custom code, e.g. RLDatix S3)
        |
        +-- compare current items vs. previous state
        |     tag each item BASELINE / NEW / CHANGED / UNCHANGED / RECHECK / ERROR
        |
        +-- write:
        |     output/VendorReport.json
        |     output/VendorReport.md
        |     output/ExecutionLog.txt
        |     output/<Vendor>-<Product>-<Id>.html (optional raw captures)
        |     state/vendor-state.json (atomic)
        |
        +-- for each NEW item, POST a User Story to Azure DevOps
              via modules/AdoWorkItem.psm1 (auth from .env)
```

## Where to read next

- `architecture.md` for the end-to-end design and module boundaries.
- `collectors.md` for how to add a new vendor.
- `state-and-changes.md` for how "new" is detected.
- `ado-integration.md` for how US creation works.
- `roadmap.md` for what is stubbed today and what comes next.
- `docs/HANDOFF-rldatix-s3-notification.md` for the RLDatix-specific handoff.
