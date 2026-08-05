# Roadmap and Known Gaps

What is stubbed or missing in the codebase today, and what is planned next. Forward-looking only.

## Explicit non-goals

These are intentionally out of scope. Document them so they do not get re-litigated.

- **Browser automation.** No headless browser, no Playwright, no Selenium. The collectors consume HTTP responses (JSON, HTML, or XML) only.
- **Persistent database.** State is a single JSON file on a dedicated branch. No SQL, NoSQL, search index, or vector store.
- **AI summarization.** The reports describe what the source published; they do not rewrite, summarize, classify, or extract semantic content from release notes. Future scope is not precluded, but it is not a goal here.

## What is shipped

For context on what "done" looks like in this codebase.

- **ADO US creation for `NEW` items.** `modules/AdoWorkItem.psm1` posts a User Story to `dev.azure.com` with a link to the release notes in the description. Auth via `.env` (`ADO_PAT`, `AZURE_DEVOPS_ORG`, `AZURE_DEVOPS_PROJECTS`). See `ado-integration.md`.
- **RLDatix RL6 S3 source.** The first vendor wired into the publish flow. Per-version records (not per-row), keyed `rl6-<version>`, posted as User Stories titled `RL6 <version>`. See `docs/HANDOFF-rldatix-s3-notification.md`.
- **State branch isolation.** `vendor-state` branch keeps `main` clean and lets the pipeline commit state without branch-policy friction.
- **Six end-to-end scenarios covered.** `scripts/verify-e2e.ps1` walks cold start, identical re-run, hash mutation, state-entry removal, per-vendor isolation, and artifact presence.

## Known gaps (current state)

These items exist in the codebase but are partial. They work as far as they go; the next step is noted for each.

### `HtmlCollector` is a stub

`tasks/VendorMonitor/Collectors/HtmlCollector.ps1` defines the contract function and throws `NotImplemented`. Use `ApiCollector` or a `Script` override for now.

Implementation outline lives in the file header:

- Fetch with `Invoke-HttpGetWithRetry`.
- Save raw HTML to `output/<Vendor>-<Product>-<Id>.html` (capped by `Output.MaxRawItems`).
- Parse with a selector engine or `Select-String` until `Html.psm1` grows a real parser.
- Map matches to the normalized record shape, relying on the content-hash key path in `State.psm1` when no stable id is on the page.

### `RssCollector` is a stub

`tasks/VendorMonitor/Collectors/RssCollector.ps1` defines the contract function and throws `NotImplemented`. Implementation outline:

- Fetch with `Invoke-HttpGetWithRetry`.
- Parse the XML with `[xml]`; namespaces vary by source.
- Map each `<item>`/`<entry>` to the normalized record shape; prefer `<guid>` as the Id.
- Pagination is rare for feeds but cap item count via a future `Settings.Collector.MaxItems`.

### Ecteon override returns demo data

`tasks/VendorMonitor/Collectors/Overrides/Invoke-EcteonCollector.ps1` returns a hardcoded set of five 2026 Ecteon Contraxx releases. It exists so the framework can be exercised end-to-end until a real Ecteon public source is identified. Replace the hardcoded block with a real fetcher before treating any Ecteon US as production-grade.

### ADO publish idempotency

A `NEW` record whose US creation failed will be re-attempted on the next run, producing a duplicate US. The planned fix is to record the created US id back into the state map under the same record key so the diff logic skips records whose `NEW` status was already published.

### Pipeline does not inject `.env`

`azure-pipelines/vendor-monitor.yml` expects `.env` to be present on the agent at run time. The clean fix is for the pipeline to read three secret variables from a variable group and write them into `.env` before invoking `Run.ps1`. Until then, `.env` must be deployed out-of-band (or the agent image must carry it).

### Pipeline always commits state, even on partial failure

Step 6 of `vendor-monitor.yml` runs with `condition: always()` so a partial-failure run still pushes whatever state it managed to write. This is intentional but can mask real bugs by overwriting a healthy state file with a partial one. Tighten in a future iteration with a sentinel file that `Run.ps1` writes only on clean exit.

### No tests beyond the e2e script

`scripts/verify-e2e.ps1` covers six scenarios end-to-end against the live Zendesk source. There is no Pester harness, no per-module unit tests, and no mocked fixtures. Adding a unit-test layer for `State.psm1`, `AdoWorkItem.psm1`, and `ApiCollector` is on the to-do but is not blocking the framework.

### Per-vendor URL hints live in `.env`

`RLDATIX_COMPARE_URL` is the only current example. The long-term home for per-vendor hints is `config/vendors.json` (e.g. a `Hints` block) so all non-secret configuration lives in committed JSON. Migrate when a second per-vendor hint is needed.

## Planned next additions

In rough priority order.

1. **Implement `HtmlCollector`.** Most likely as soon as a vendor that needs it lands. The framework plumbing already exists; the implementation is the missing piece.
2. **Implement `RssCollector`.** Needed for vendors that publish an RSS / Atom feed but no JSON API.
3. **ADO publish idempotency.** Record created US ids in the state map so re-runs after a failed publish do not duplicate. See "Known gaps" above.
4. **Pipeline injects `.env` from a variable group.** Remove the need for `.env` to be deployed to the agent out-of-band. See "Known gaps" above.
5. **Migrate per-vendor hints from `.env` to `config/vendors.json`.** When a second per-vendor hint is needed.
6. **Per-vendor scraper complexity tier.** A short classification in `config/vendors.json` (e.g. `Tier: "declarative" | "script"`) so the run summary can flag vendors that should be migrated to a generic collector when one becomes available. Today every vendor entry implicitly carries this information via `Collector` vs `Script`; promoting it to an explicit field is a small win for reporting.
7. **Per-record optional extras.** Today the normalized record carries `RawBody` but no structured extras. Future vendors may want `Tags`, `Severity`, `AffectedVersions`, etc. Extend the normalized record shape and the state hash inputs only when the first vendor needs it.

## Out of scope but considered

These appear in the original architecture brief as future work. They remain deferred.

- Azure Function hosting.
- Shared C# collector libraries.
- Searchable historical data (the current state is "what we last saw"; going back further is not implemented).
- MCP server exposing automation data.
- Teams notifications.
- Email digests.
- Dashboard UI.

## When to update this file

- A planned item lands: move it from "Planned next additions" to "What is shipped" with a date and a one-line summary.
- A new non-goal is agreed: add it to the top of this file.
- A new gap appears: add it to "Known gaps (current state)" with the next step.
