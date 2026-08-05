# Pipeline

`azure-pipelines/vendor-monitor.yml` is the only pipeline. It is orchestration only — every line of business logic lives in PowerShell under `tasks/` and `modules/`.

## Schedule

- Cron: `0 6 * * *` (daily at 06:00 UTC).
- Trigger: `none` (no CI on push). Runs are scheduled and manual only.
- Time zone: UTC. The cron expression is in UTC by Azure DevOps convention.

## Parameters

| Name           | Type    | Default | Purpose                                                                |
| -------------- | ------- | ------- | ---------------------------------------------------------------------- |
| `vendor`       | string  | `All`   | Filter; values are `All` or `RLDatix` today. Passed as `-Vendor` to `Run.ps1`. |
| `forceRecheck` | boolean | `false` | When true, every record is re-emitted with status `RECHECK`.           |

The `vendor` parameter's allowed list is hard-coded in YAML. When a new vendor is added to `config/vendors.json`, add it here too so it can be selected for a single-vendor run.

## Variables

| Name         | Value                                            | Purpose                                  |
| ------------ | ------------------------------------------------ | ---------------------------------------- |
| `stateBranch`| `vendor-state`                                   | Branch that owns `state/vendor-state.json`. |
| `outputDir`  | `$(Build.ArtifactStagingDirectory)/output`       | Where `Run.ps1` writes artifacts.        |
| `stateFile`  | `state/vendor-state.json`                        | Relative path of the state file.         |

## Step-by-step

1. **Checkout.** `checkout: self` with `persistCredentials: true`. Pipeline identity must be able to push to `vendor-state`.

2. **Fetch prior state.** Inline PowerShell that does `git fetch origin vendor-state --depth=1`, then `git show origin/vendor-state:state/vendor-state.json` into a temp file, and moves it into `./state/vendor-state.json`. If the branch or the file does not exist, the run is a cold start; `Run.ps1` will baseline.

   The PowerShell uses a backtick to escape the `:` in `origin/vendor-state:path` so the shell does not parse it as a scope-qualified variable. This is pwsh-7-on-Linux safe. If a self-hosted Windows PowerShell 5.1 agent is added later, switch the path to a single-quoted string.

3. **Configure git identity.** Inline `git config user.email` / `user.name` for the commit step.

4. **Run VendorMonitor.** Inline PowerShell that builds the argument list and invokes `pwsh ./tasks/VendorMonitor/Run.ps1`. The `-Vendor` and `-ForceRecheck` arguments are conditional on the parameters. The script's exit code is propagated; `continueOnError: false`.

5. **Publish run artifacts.** `PublishPipelineArtifact@1` for `output/` (named `platform-automation-output`) and the state file (named `platform-automation-state`). Both `condition: always()` so they exist on failure runs too.

6. **Commit updated state.** Inline PowerShell that stashes the new state into a temp file, checks out the `vendor-state` branch (creating it from `main` on first run), restores the new state, `git add` + `git commit -m "chore(state): vendor monitor update [skip ci]"` + `git push origin vendor-state`, then returns to `main`. The `[skip ci]` ensures the push does not retrigger this pipeline (which is `trigger: none` anyway, but is a defensive marker for future trigger changes).

   `condition: always()` is intentional — even on a partial failure, we want to commit whatever state was written so the next run can pick up where this one left off. Tighten with a sentinel file in a future iteration if needed.

## Admin prerequisites (one-time, per repo)

These are not enforced by YAML. They must be set up by a project admin before the first scheduled run.

1. **The `vendor-state` branch exists.** The pipeline will create it from `main` on first run if it does not, but creating it ahead of time lets branch policies be applied (if desired) and avoids an admin-noticed surprise on day one.

2. **Project Build Service has `Contribute` on the repo.** Otherwise the commit step in step 6 fails with a 403. The permission is granted under Project Settings > Repositories > Security.

3. **No pipeline variable or secret is required today.** All current sources are public. When the ADO US creation work lands, a PAT (or service connection) must be added as a secret variable and the `azure-pipelines/vendor-monitor.yml` will reference it.

## Manual run

Use the "Run pipeline" button on the pipeline. Pick `vendor = All` for a full run, or pick a single vendor to test a change without touching the rest. Set `forceRecheck = true` to force a re-emission without changing what is considered new.

## Re-running a failed run

If the run failed and the state file was not committed (step 6 exited early), the next run will see the prior state on `vendor-state`. Re-run from the pipeline UI; no manual state repair is needed.

If the state file on `vendor-state` is corrupt (manual edit, partial push), see `state-and-changes.md` for repair options.

## Future pipeline changes

When new tasks are added beyond `VendorMonitor`, either:

- Add a second YAML file under `azure-pipelines/` (e.g. `azure-pipelines/<task>.yml`) with its own schedule, or
- Add a second stage to the same YAML with a `dependsOn` and its own `Run.ps1` invocation.

The current convention is one YAML per task. Do not embed business logic in YAML under any circumstance.
