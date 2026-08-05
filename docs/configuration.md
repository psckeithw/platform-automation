# Configuration

Three configuration surfaces drive every run. Two are committed JSON, one is a gitignored `.env`.

All three are loaded and validated by `Get-Config` (`modules/Common.psm1`) or by the modules that own each concern.

## `config/settings.json`

Tunable behavior shared by every collector and every run. Committed.

```json
{
  "Http": {
    "UserAgent":  "platform-automation/1.0",
    "TimeoutSec": 60,
    "Retries":    3
  },
  "Collector": {
    "MaxPages": 3
  },
  "Output": {
    "CaptureRawHtml": true,
    "MaxRawItems":    10
  },
  "Run": {
    "BaselineOnColdStart": true
  }
}
```

| Key                          | Type | Purpose                                                                 |
| ---------------------------- | ---- | ----------------------------------------------------------------------- |
| `Http.UserAgent`             | str  | Sent on every request. Set to something an admin can identify.          |
| `Http.TimeoutSec`            | int  | Per-attempt timeout. Passed through to `Invoke-WebRequest`.             |
| `Http.Retries`               | int  | Total attempts including the first. Backoff is exponential.             |
| `Collector.MaxPages`         | int  | Hard cap on pages fetched by `ApiCollector` per product.                |
| `Output.CaptureRawHtml`      | bool | If true, up to `MaxRawItems` NEW/CHANGED records get a styled HTML capture in `output/`. |
| `Output.MaxRawItems`         | int  | Cap on captures per run (across all vendors). Set to `0` to disable.    |
| `Run.BaselineOnColdStart`    | bool | If true, missing state file is treated as baseline (tag `BASELINE`). If false, the run still baselines but the behavior is identical — the flag is informational today and exists for future per-vendor policies. |

Missing any of `Http`, `Collector`, `Output`, `Run` triggers a `Get-Config` error at run start.

## `config/vendors.json`

An array of vendor entries, each with one or more products. Committed.

```json
{
  "Vendors": [
    {
      "Vendor":    "Ecteon",
      "Enabled":   true,
      "Collector": null,
      "Script":    "tasks/VendorMonitor/Collectors/Overrides/Invoke-EcteonCollector.ps1",
      "Products": [
        {
          "Product":    "Contraxx",
          "Url":        "https://www.ecteon.com/",
          "ItemsPath":  "",
          "FieldMap":   {
            "Id":            "id",
            "Title":         "title",
            "PublishedDate": "created_at",
            "SourceUrl":     "html_url",
            "RawBody":       "body"
          }
        }
      ]
    }
  ]
}
```

### Vendor-level fields

| Key         | Type     | Required | Purpose                                                              |
| ----------- | -------- | -------- | -------------------------------------------------------------------- |
| `Vendor`    | string   | yes      | Display name. Also the `-Vendor` filter argument.                    |
| `Enabled`   | bool     | yes      | If false, the entry is skipped at run time.                          |
| `Collector` | string   | one of   | Name of a built-in collector (`ApiCollector`). Loads `Collectors/<Name>Collector.ps1`. |
| `Script`    | string   | one of   | Path to a vendor-specific override script. Loads it and expects `Invoke-OverrideCollector`. |
| `Products`  | array    | yes      | One or more products under this vendor.                               |

Exactly one of `Collector` or `Script` must be set. If both are set, `Script` wins. If neither is set, the vendor errors out at run time and the run continues.

### Product-level fields

| Key         | Type   | Required for `ApiCollector` | Purpose                                                            |
| ----------- | ------ | --------------------------- | ------------------------------------------------------------------ |
| `Product`   | string | yes                         | Display name. Appears in reports and in the per-product log line.  |
| `Url`       | string | yes                         | Source URL. First-page URL for paginated endpoints.                |
| `ItemsPath` | string | yes                         | Dotted path to the array of items inside each page body (e.g. `articles`, `data.items`). |
| `FieldMap`  | object | yes                         | Maps normalized-record field names (`Id`, `Title`, `PublishedDate`, `SourceUrl`, `RawBody`) to source field names. |

For a `Script` override, the product object is passed through verbatim — the override decides which fields it reads.

## `.env`

Authentication and per-vendor URL hints. **Gitignored.** Lives at the repo root. Required when the run reaches the ADO publish step.

```
ADO_PAT=<personal access token>
AZURE_DEVOPS_ORG=<organization name>
AZURE_DEVOPS_PROJECTS=<project name>

RLDATIX_COMPARE_URL=<vendor-specific URL hint>
```

| Key                    | Required by            | Purpose                                                                 |
| ---------------------- | ---------------------- | ----------------------------------------------------------------------- |
| `ADO_PAT`              | `AdoWorkItem.psm1`     | Personal Access Token used to POST work items. Sent as Basic auth.      |
| `AZURE_DEVOPS_ORG`     | `AdoWorkItem.psm1`     | Organization name in the `dev.azure.com/{org}` URL.                     |
| `AZURE_DEVOPS_PROJECTS`| `AdoWorkItem.psm1`     | Project name in the `dev.azure.com/{org}/{project}` URL.                |
| `RLDATIX_COMPARE_URL`  | RLDatix collector      | Source URL the RLDatix S3 collector hits. Per-vendor hints live here until a generic vendor-config field is added. |

`Initialize-AdoConfig` throws a clear error if any of the three ADO keys is missing or empty.

The PAT is sensitive. `.env` is in `.gitignore` (`eadae4b chore: ignore .env ...`). The planned migration to an Azure DevOps variable group is in `roadmap.md`.

## Validation

`Get-Config` parses `settings.json` and `vendors.json` and verifies required top-level keys. Per-vendor and per-product validation is shallow today (the dispatcher re-checks at run time). `.env` is read directly by `Initialize-AdoConfig`; missing keys surface as a startup error.

## Editing workflow

1. Edit `config/vendors.json`, `config/settings.json`, or `.env` (locally only).
2. Commit JSON changes (never `.env`).
3. Run `pwsh ./scripts/verify-e2e.ps1 -KeepArtifacts` locally to confirm (where applicable).
4. Push; the pipeline picks it up on the next schedule or manual run.

## Secrets

The only secrets today are `ADO_PAT` and (eventually) anything added to `.env`. Nothing in `config/` should ever hold a secret. The migration plan to remove `.env` from the agent filesystem entirely is in `roadmap.md`.
