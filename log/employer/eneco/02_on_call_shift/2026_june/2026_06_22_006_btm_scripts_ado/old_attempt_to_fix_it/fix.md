---
title: BTM PR auto-tagging TF401019 — Fix
status: complete
date: 2026-06-02
---

# Fix — make `az boards` stop auto-detecting the repo

> **STATUS:** Root cause **proven** (A1, reproduced live). Fix **authored + locally
> validated** (shellcheck-clean, read-only dry-run against live work items). **NOT yet
> applied to the repo and NOT yet verified in the live pipeline** — applying it is a PR on
> `Eneco.Vpp.BehindTheMeter` (an ADO mutation), which I have not performed. Awaiting your
> go-ahead to open the PR.

## The one-sentence cause → fix

`az boards query` is called **without** `--organization/--project`, so the azure-devops CLI
auto-detects context from the git remote and calls
`…/_git/eneco.vpp.behindthemeter/vsts/info`. On the ephemeral Microsoft-hosted agent that
cache is always cold, so it fires **every run**, and the **project-scoped job token**
(`enforceJobAuthScope=true`) is denied → `TF401019`. **Tell `az boards query` the org/project
explicitly and disable detection** — the failing call disappears.

## Which `az boards` calls need what (verified)

| Command | Does it emit `/vsts/info`? | Accepts `--project`? | Needs the fix? |
|---------|:--------------------------:|:--------------------:|:--------------:|
| `az boards query` | **YES** (cold cache) — this is the failure | yes | **YES** — add `--org --project --detect false` |
| `az boards work-item show` / `update` | no (hits `/_apis/wit/...`, never the repo) | **NO** — `--project` errors `unrecognized arguments` | only `--org`/`--detect` if you want determinism |

(Verified live: `az boards work-item update --help` lists only `--org`/`--detect`, not
`--project`; Sherlock's `--debug` probe shows the update path never calls `/vsts/info`.)

## Option A — Minimal root-cause fix (one line; restores tagging)

Edit `azure-pipelines/steps/azure-boards-add-tag.sh`. Only the **query** line changes:

```diff
-done <  <(az boards query --wiql "$query" --output table | tail -n +3)
+done <  <(az boards query \
+            --organization "$SYSTEM_COLLECTIONURI" \
+            --project "$SYSTEM_TEAMPROJECT" \
+            --detect false \
+            --wiql "$query" --output table | tail -n +3)
```

`$SYSTEM_COLLECTIONURI` / `$SYSTEM_TEAMPROJECT` are predefined ADO pipeline variables. This
removes the `/vsts/info` call, the query succeeds, the loop runs, tags apply again. No pool
change, **stays on the Microsoft-hosted `ubuntu-24.04` agent**, no job split, no ADO
permission change. (Do **not** add `--project` to the `az boards work-item update` line — it
rejects it.)

> Option A restores the script's *original* behaviour — including a latent quirk: because
> `az boards query` does not return `System.Tags`, the original always wrote `System.Tags=;
> $TAG`, which **replaces** the work item's tag list. This is harmless only because BtM
> epics/features carry no other tags. Option B fixes that too.

## Option B — Hardened script (recommended)

See [`azure-boards-add-tag.fixed.sh`](./azure-boards-add-tag.fixed.sh). Same root-cause fix,
plus three correctness/safety improvements proven necessary by review:

1. **Correct contexts** — `--org --project --detect false` on `query`; `--org --detect false`
   on `work-item show/update` (no `--project`, which they reject).
2. **Tag union, never clobber** — reads each item's current `System.Tags` and writes
   `existing; $TAG` (the original silently replaced the whole tag list).
3. **Loud but non-blocking** — the tagging step has **no `continueOnError`**, so a naive
   `set -e` would let a transient WIT 5xx or a future cross-project item **fail the
   deployment**. Instead, failures emit `##vso[task.logissue type=error]` +
   `SucceededWithIssues` (orange, visible in the build summary, never blocks the deploy) —
   fixing the *silent-green* problem without introducing a *deploy-blocking* one.

Validated: `shellcheck` clean, `bash -n` clean, and a read-only dry-run against live items
(`426514` → correctly SKIPs since it has `DEV`; a tagless item → writes a clean `DEV`).

## Why the sibling-team approach is NOT the fix (your exact question)

The Agg/`.B2B` fix (PR 178802) moved tagging into a **separate job on `pool: sre-managed-linux`**
(a self-hosted "Core Platform" runner). Microsoft's docs establish that the job-auth **identity
is the project Build Service identity and is independent of the agent pool** — so the pool swap
does not change *what* is denied. Our live evidence corroborates it: **this BTM pipeline already
runs on the Microsoft-hosted pool and still fails.**

Why does the sibling pool nonetheless work? **[A2 INFER — not probed]** most likely a
pool-correlated environment difference: a different `az`/azure-devops-extension version on
`sre-managed-linux` that does not perform the cold-cache `/vsts/info` detection, **or** a broad
cached credential on the self-hosted agent. *Falsifier:* run `az version` / `az extension show
--name azure-devops` on an `sre-managed-linux` agent — if it performs the same `/vsts/info`
detection, the "different version" explanation is wrong and the real difference is
credential/scope. Either way the headline answer holds (below).

> **Answer: No, the runner switch is not the only option — and it is not the correct fix.**
> Option A fixes the actual cause with **no additional runner and no job split** (directly
> addressing your cost concern; the Microsoft-hosted job still consumes paid minutes, so this
> is "no *additional* runner", not literally free).

## Option matrix

| Option | Changes | Keeps MS-hosted pool? | Splits job? | ADO perm change? | Verdict |
|--------|---------|:---------------------:|:-----------:|:----------------:|---------|
| **A — `--org/--project/--detect false` on the query** | 1 line | ✅ | ❌ | ❌ | **Fixes the cause** |
| **B — A + union + non-blocking** (this script) | script | ✅ | ❌ | ❌ | **Recommended** |
| C — move tagging to `sre-managed-linux` (sibling) | YAML pool + extra job | ❌ | ✅ | ❌ | Works, masks cause, +1 runner |
| D — declare repo via `resources.repositories` | YAML | ✅ | ❌ | ❌ | Unneeded once detection is off |
| E — grant Build Service Read / disable `enforceJobAuthScope` | ADO settings | ✅ | ❌ | ✅ | Reduces security; unnecessary |

## Onset — why it started (your question #1)

No code changed: the script has **one commit ever (PR 101101, 2024-11-06)** and the pipeline
YAML last changed **2025-05-19**. By bisecting pipeline 4667's build history and grepping the
`Add DEV tag` log for `TF401019`:

- **2026-04-15** (build 1608485): `TF401019` **absent** → tagging worked.
- **2026-04-25** (build 1621832): `TF401019` **present** → broken (and every build since).

So it started **between 2026-04-15 and 2026-04-25, 2026**, with **no BTM change** — an external
org/platform trigger. The sibling Agg pipeline broke in the same window (its fix merged
2026-05-26), which points at an **org-level change**: most likely the `enforceJobAuthScope`
setting being enabled, or a Microsoft-hosted `ubuntu-24.04` agent `az`/extension bump that began
the cold-cache `/vsts/info` detection. **[A3 — exact date/trigger needs the org audit log]**:
*Organization settings → Pipelines → Settings* audit, or *Project settings → Repositories →
Security* audit, will name the change and date. You can also pinpoint the build to the day by
bisecting between 04-15 and 04-25 with the same log-grep method.

## Local test (your UAC: inspectable locally; ADO-side called out)

The **diagnostic path is fully runnable locally and read-only**:

```bash
az login                                    # interactive; refreshes MFA. az boards uses THIS token.
cd /path/to/Eneco.Vpp.BehindTheMeter        # so 'git log' has commits with "Related work items:"
export TAG=DEV
ORG="https://dev.azure.com/enecomanagedcloud/"; PROJ="Myriad - VPP"

# 1) Reproduce the BUG locally — see the failing call (safe, read-only):
az boards query --debug \
  --wiql "SELECT [System.Id] FROM workitems WHERE [System.AreaId]=6393" 2>&1 | grep vsts/info
#   -> GET .../_git/eneco.vpp.behindthemeter/vsts/info   (this is what 404s in the pipeline)

# 2) Prove the FIX removes it (safe, read-only):
az boards query --organization "$ORG" --project "$PROJ" --detect false --debug \
  --wiql "SELECT [System.Id] FROM workitems WHERE [System.AreaId]=6393" 2>&1 | grep -c vsts/info
#   -> 0
```

- **Safe to run:** steps 1-2 and any `az boards query` / `az boards work-item show` are
  **read-only** and need only `az login`.
- **Mutating:** running the full `azure-boards-add-tag.fixed.sh` (or any `az boards work-item
  update`) **changes real work-item tags** — run it only against a **throwaway test work item**.
- **Requires ADO (not local):** applying the fix = a **PR** to `Eneco.Vpp.BehindTheMeter`;
  confirming the live fix = a **pipeline re-run**. Both are ADO actions; I have not performed them.

### Ready-to-use PR description

```text
Title: Fix BTM PR auto-tagging — TF401019 from az boards git auto-detection

azure-boards-add-tag.sh called `az boards query` without --organization/--project, so the
azure-devops CLI auto-detected context from the git remote and called
.../_git/eneco.vpp.behindthemeter/vsts/info. On the ephemeral MS-hosted agent that cache is
always cold, so it fired every run; under the project-scoped job token (enforceJobAuthScope=
true) it returns TF401019/404. The script had no `set -e` and ran the query in a process
substitution, so the failure was swallowed and the DEV/ACC/PRD tag silently stopped applying
(green build). Started 2026-04-15..04-25 with no code change (external/platform trigger).

Fix: pass --organization "$(System.CollectionUri)" --project "$(System.TeamProject)"
--detect false to `az boards query`. Hardened script also writes the tag UNION (no clobber)
and reports failures via SucceededWithIssues (visible, non-blocking). No pool change, no job
split, no permission change.
```

## Verification (do NOT trust "pipeline green" — check the realized tag)

1. Apply Option A or B; run the deployment pipeline on a PR whose commits reference a
   `Team BtM` work item.
2. The `Add DEV tag in ADO` step log must show `Work item <id>: … -> 'DEV'` and **no `TF401019`**.
3. **Assert the realized state is the UNION**, not a clobber:
   ```bash
   az boards work-item show --org https://dev.azure.com/enecomanagedcloud/ \
     --detect false --id <work_item_id> --query "fields.\"System.Tags\""
   ```
   The result must contain `DEV` **and still contain any tags the item had before**.
4. Confirm the agent's bundled `azure-devops` extension is the one that performs `/vsts/info`
   (it almost certainly is): a single pipeline run with `system.debug: true` shows the
   `/vsts/info` call vanish post-fix — this also promotes the one remaining INFER (the exact
   ACL on the Build Service identity) to fact. Prefer this over re-introducing the bug on a
   real branch.
