# State and Change Detection

The whole point of `VendorMonitor` is to know what is new since the last run. State is the memory.

## Where state lives

`state/vendor-state.json` on the dedicated `vendor-state` branch. It is not on `main` and it is not in `output/`. The pipeline fetches it at the start of each run and pushes the updated version back at the end.

Locally, `state/` is `.gitignore`d (except for a `.gitkeep` placeholder). A fresh clone has no state file; the next run is treated as a cold start.

## On-disk shape

A JSON object whose keys are record keys and whose values are small descriptors:

```
{
  "<record-key>": {
    "title":     "<release title>",
    "hash":      "<lowercase hex SHA-256>",
    "firstSeen": "<ISO 8601 UTC Z timestamp>",
    "sourceUrl": "<canonical URL>"
  },
  ...
}
```

Keys are sorted alphabetically when written, which keeps diffs in PRs (when inspecting state manually) stable.

## How a record key is chosen

`State.psm1` (`Get-RecordKey`) returns the key for a normalized record:

- If the record carries a non-empty `Id`, the key is `id:<Id>` (e.g. `id:12345678901234`).
- Otherwise the key is `hash:<sha256>` where the hash is computed over the record's content (see below).

The Id path is preferred because it is stable across content edits to the same release — only the `hash` changes, which is exactly the signal we want for `CHANGED`.

## How the content hash is computed

`State.psm1` (`Get-ContentHash`) computes a SHA-256 over the five fields that define a release from the operator's perspective:

```
Vendor | Product | Title | PublishedDate | SourceUrl
```

A change to any of those five is a `CHANGED` event. Anything else (body text, internal IDs, metadata, comment counts) is intentionally ignored — the goal is to alert on edits to the release itself, not on every edit the source made to its page.

The hash is lowercase hex, 64 characters.

## Statuses

Every record surfaced by a run is tagged with one of:

| Status      | Meaning                                                                 |
| ----------- | ----------------------------------------------------------------------- |
| `BASELINE`  | First run on this vendor/product, or `-Baseline` flag set. Stored, not reported as new. Avoids the day-one alert storm. |
| `NEW`       | Record key was not in the previous state map.                           |
| `CHANGED`   | Record key was in the previous map, but its content hash differs.       |
| `UNCHANGED` | Record key was in the previous map and the hash matches.                |
| `RECHECK`  | `-ForceRecheck` flag set: every record is re-emitted as if it were just seen. State map is still updated so the next non-force run is unaffected. |
| `ERROR`     | A single bad record could not be keyed or hashed. Excluded from the new state map. Run continues. |

## What happens on cold start

A cold start is a run where `state/vendor-state.json` does not exist, or exists but is empty. This happens on:

- The first run after the `vendor-state` branch is created.
- A local clone that has never been run.
- Any run with the `-Baseline` flag.

Every record is tagged `BASELINE`. Nothing is reported as `NEW`. The state map is populated. The run exits 0.

This is intentional: on day one, we do not want a flood of `NEW` alerts for everything that has ever been published.

## What happens on a normal run

`Run.ps1` calls `Compare-ReleaseState` (`State.psm1`) which:

1. Computes each record's key and current hash.
2. Looks the key up in the previous map.
3. Applies the rules above to choose a status.
4. Builds the new state map by replacing every key seen in this run with its current values. Keys that were in the previous map but not in this run are dropped — they are no longer present in the source, so we stop tracking them.

## What happens on `-ForceRecheck`

Every record is tagged `RECHECK` (or `BASELINE` if cold start) and the state map is fully replaced. The Markdown report still renders all items, but the run summary shows `RECHECK=N` instead of `NEW=N` and does not emit the "N NEW release(s) detected" warning. Use this to force a re-emission of every release without changing what is considered "new" going forward.

## Atomic writes

`Save-CurrentState` writes to `vendor-state.json.tmp` first, then renames over the target. A crash mid-write leaves the previous file intact. The directory is created if missing.

## When state goes wrong

Symptoms and fixes:

- **Every run reports everything as `NEW`.** The state file is empty or missing. Verify the pipeline committed the state file to `vendor-state` after the last successful run, or run locally with `-Baseline`.
- **Nothing ever reports as `CHANGED`.** The source edits page content but not the five hashed fields, or the collector is producing stable `Title` / `PublishedDate` strings from a digest. Extend the hash inputs if a different field should drive change detection.
- **A run reports the same release as `NEW` repeatedly.** The collector is not returning a stable `Id` for that source. Add an `Id` mapping in `FieldMap` (or return a deterministic id from a `Script` override).
- **`vendor-state.json` is corrupt.** `Get-PreviousState` throws "unreadable or invalid JSON". Repair the file by hand or restore from a known-good commit on the branch, then run with `-Baseline` to re-seed.

## Schema evolution

`State.psm1` is the only module that knows the on-disk shape. To add or rename a field on each record, edit the `Get-ContentHash` payload and the `$newState[...] = [ordered]@{...}` block together. Existing state files will appear "all changed" on the next run after a payload change because every hash will differ — this is the expected migration behavior. To migrate cleanly, increment a schema version in the descriptor and ignore old records until they are re-fetched.
