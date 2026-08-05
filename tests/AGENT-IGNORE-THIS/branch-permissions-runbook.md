# Branch & Permissions Runbook — `vendor-state`

This runbook is for the **collection admin** (project-level). It is
a one-time setup the pipeline needs before its first run. Once done,
no further manual work is expected unless the project identity, the
branch, or the branch policy changes.

Refs: `docs/mvp-supplemental-plan.md` §J, §Q1; `docs/mvp-task-list.md` T5.2.

---

## Why this exists

`azure-pipelines/vendor-monitor.yml` writes `state/vendor-state.json`
back to git so the next run can diff against it. The write target is
a dedicated `vendor-state` branch, not `main`:

* `main` history is not polluted with one commit per vendor scan.
* The pipeline does not interact with any policies on `main`.
* Git history on the branch is a free audit log of every state
  update (who, when, which keys changed).
* Migrating to Azure Blob later remains a single-module change
  (`modules/State.psm1`); the branch is the MVP-only storage.

The pipeline also needs the **Project Build Service** identity to
be allowed to push to that branch.

---

## 1. Create the `vendor-state` branch

The branch must exist before the pipeline's first run, otherwise the
first run auto-creates it from `main` and the first state push is
effectively a baseline-from-zero (which still works, but loses the
audit trail of "this is the seed state").

Recommended seed (matches the brief's success criteria: the first
run is a true baseline with no NEW spam):

```bash
# From a clean checkout of main:
git checkout --orphan vendor-state
git rm -rf .                  # remove everything except the path we want
mkdir -p state
echo '{}' > state/vendor-state.json
git add state/vendor-state.json
git commit -m "chore(state): seed vendor-state with empty baseline"
git push origin vendor-state
git checkout main
```

The resulting `vendor-state` branch contains exactly one commit with
an empty `state/vendor-state.json`. The pipeline's first run will
detect the file, treat it as a baseline, and overwrite it with the
first real state on its next push.

### Azure DevOps UI (alternative)

1. **Repos → Branches → New branch**.
2. Name: `vendor-state`. Base: `main`.
3. Create.
4. **Repos → Files** → switch to `vendor-state` → **New file** →
   path `state/vendor-state.json`, contents `{}` → **Commit**.

---

## 2. Grant the Project Build Service Contribute

The pipeline's git push uses the **Project Collection Build Service**
identity (e.g. `Heartbeat Build Service (orgname)`). It must have
**Contribute** (or **Contribute to pull requests** is not required —
push is direct) on the repo, scoped to the `vendor-state` branch.

### Azure DevOps UI

1. **Project Settings → Repositories → `<repo>` → Security**.
2. Find **`<ProjectName> Build Service (<OrgName>)`**. If it is not
   in the list, add it.
3. Set **Contribute** to **Allow**.
4. (Optional) Scope the permission: **Security tab → Advanced** →
   filter on the `vendor-state` branch under **Apply to** if you do
   not want the identity to have repo-wide Contribute. A scoped
   grant is recommended.

### Verify

```bash
# From a clean clone, as a non-admin user, this should succeed:
git fetch origin vendor-state
```

If the fetch is denied, the grant is missing or scoped incorrectly.

---

## 3. Confirm `main` is untouched

The pipeline never writes to `main`. After the first successful run:

* `git log --oneline origin/main -5` should show no pipeline-driven
  commits.
* `git log --oneline origin/vendor-state -5` should show the seed
  commit followed by `chore(state): vendor monitor update [skip ci]`
  commits from each run.

If a commit ever lands on `main` from a pipeline run, something has
gone wrong with the state-branch logic in the YAML — investigate
before the next run.

---

## 4. Pipeline-side configuration check

* The pipeline uses `persistCredentials: true` on checkout. This is
  required for the later `git push` to the state branch.
* The pipeline runs as `ubuntu-latest` with `pwsh: true`. No extra
  pool configuration is needed for an MVP run.
* The cron schedule `0 6 * * *` is UTC. Adjust in the YAML if a
  different time-of-day is wanted.

---

## 5. Rollback / teardown

If you need to reset the state (forget everything the pipeline has
ever seen, force a fresh baseline):

```bash
git checkout vendor-state
echo '{}' > state/vendor-state.json
git add state/vendor-state.json
git commit -m "chore(state): reset baseline"
git push origin vendor-state
```

The next scheduled run will treat the empty state as a cold start
and rebuild the baseline from the live API — no NEW detections on
the reset run.

If you need to disable the pipeline entirely, either:

* Pause the schedule in **Pipelines → vendor-monitor → Edit →
  Triggers**, or
* Set the YAML's `schedules:` block to an empty list and re-commit.

---

## 6. Day-2 admin checklist

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Pipeline log: "Branch 'vendor-state' does not exist on origin" | Runbook step 1 was skipped | Section 1 above |
| Pipeline log: "failed to push to vendor-state" / 403 | Build Service lacks Contribute | Section 2 above |
| `main` shows a state-update commit | YAML regression | Stop the pipeline, fix the YAML, audit recent state |
| Every run reports the same items as NEW | State branch was reset; or the content hash changed upstream (vendor republished) | Inspect the diff; if upstream-driven, the next run will return to UNCHANGED |
