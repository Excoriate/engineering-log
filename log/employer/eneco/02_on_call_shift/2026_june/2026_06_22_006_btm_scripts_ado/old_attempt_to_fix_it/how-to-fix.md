---
title: "Implementation Spec — Fix BTM PR auto-tagging TF401019"
status: complete
date: 2026-06-02
type: implementation-spec
executable_by: human-or-agent
target_repo: "Eneco.Vpp.BehindTheMeter (ADO project: Myriad - VPP, org: enecomanagedcloud)"
target_file: "azure-pipelines/steps/azure-boards-add-tag.sh"
---

# Implementation Spec — Fix BTM PR auto-tagging (TF401019)

> **Self-contained.** Anyone (you, a future me, or another agent) can execute this without
> reading the rest of the package. The *why* lives in [`rca.md`](./rca.md) and
> [`feynman-explanation.md`](./feynman-explanation.md); this file is the *how*. Do **not**
> deviate from the verified facts below — they were proven live on 2026-06-02.

## 0. One-paragraph problem statement

The pipeline step `azure-pipelines/steps/azure-boards-add-tag.sh` calls `az boards query`
**without** `--organization/--project`. The azure-devops CLI then auto-detects context from
the git remote by calling `GET …/_git/eneco.vpp.behindthemeter/vsts/info`; on the ephemeral
Microsoft-hosted agent this cache is always cold so it fires every run, and the project-scoped
pipeline token (`enforceJobAuthScope=true`) is **denied** → `TF401019/404`. The script has no
`set -e` and runs the query inside a process substitution, so the error is **swallowed** → the
step is **green while the DEV/ACC/PRD tag is never applied**. **Fix = make `az boards query`
explicit + detection-free.**

## 1. Goal / Acceptance criteria (done-when — all must hold)

- **AC1** — The `Add DEV tag in ADO` (and ACC/PRD) step log shows `Work item <id>: … -> 'DEV'`
  and contains **no `TF401019`**.
- **AC2** — The realized work-item state is the **union**: after a run,
  `az boards work-item show --org <org> --detect false --id <id> --query "fields.\"System.Tags\""`
  contains the env tag **and** any tags the item had before (no clobber).
- **AC3** — A transient tagging failure does **not** turn the deployment RED (cosmetic step).
  (Option B only; Option A keeps the original blocking behaviour, which today is effectively
  non-blocking because errors are swallowed.)
- **AC4** — No agent-pool change, no job split, no ADO permission/setting change.

## 2. Preconditions

| # | Requirement | Check |
|---|-------------|-------|
| P1 | Azure CLI + azure-devops extension | `az version` shows `azure-devops` (tested: az 2.86.0 / ext 1.0.2) |
| P2 | ADO auth (read+write to the repo) | `az devops project list --org https://dev.azure.com/enecomanagedcloud` returns projects. For **git push / PR create** you need write on `Eneco.Vpp.BehindTheMeter` and a valid credential (az login token or a git credential helper). Note: `az rest --resource <ADO-GUID>` may hit `AADSTS50078` (MFA) — re-run `az login` if a write call fails auth. |
| P3 | Working clone of the repo | see Step 3 |
| P4 | Decide which option | see Section 3 |

## 3. Decision — which option

- **DEFAULT: Option B (hardened).** Fixes the root cause **and** the two latent bugs the
  original hid (tag clobber; swallowed failures). Verified: `shellcheck` clean, `bash -n`
  clean, read-only dry-run correct.
- **Option A (minimal, 1 line)** — only if the team wants the smallest possible diff and is
  comfortable keeping the original's latent quirks. Restores tagging but still clobbers tags
  for items that carry others (harmless for BtM today) and still swallows non-`az-boards-query`
  errors.

Both keep the Microsoft-hosted `ubuntu-24.04` pool and need no permission change.

## 4. The exact change

### Option A — minimal (edit one call)

In `azure-pipelines/steps/azure-boards-add-tag.sh`, change **only** the `az boards query` line:

```diff
-done <  <(az boards query --wiql "$query" --output table | tail -n +3)
+done <  <(az boards query \
+            --organization "$SYSTEM_COLLECTIONURI" \
+            --project "$SYSTEM_TEAMPROJECT" \
+            --detect false \
+            --wiql "$query" --output table | tail -n +3)
```

- `$SYSTEM_COLLECTIONURI` / `$SYSTEM_TEAMPROJECT` are predefined ADO pipeline variables.
- **Do NOT** add `--project` to the `az boards work-item update` line — it errors
  `unrecognized arguments: --project` (work items are org-global by id).

### Option B — hardened (replace the whole file) — DEFAULT

Replace the entire contents of `azure-pipelines/steps/azure-boards-add-tag.sh` with the
verified script in this folder: **[`azure-boards-add-tag.fixed.sh`](./azure-boards-add-tag.fixed.sh)**
(copy it verbatim). It implements, and is commented with, all of:
1. `query_ctx=(--organization … --project … --detect false)` for `az boards query`;
   `wi_ctx=(--organization … --detect false)` for `work-item show/update` (no `--project`).
2. **Tag union** — reads each item's current `System.Tags` and writes `existing; $TAG`.
3. **Loud-but-non-blocking** — failures emit `##vso[task.logissue type=error]` +
   `##vso[task.complete result=SucceededWithIssues]` (step shows orange, deploy not blocked).
4. Empty-`work_items` guard (a second silent failure mode: `… IN ()` → query error).

> If you cannot copy the file, its exact content is the canonical Option B; reproduce it
> byte-for-byte. Re-run `shellcheck azure-boards-add-tag.sh` after — it must be CLEAN.

## 5. Step-by-step implementation (commands)

```bash
ORG="https://dev.azure.com/enecomanagedcloud"
PROJ="Myriad - VPP"
REPO="Eneco.Vpp.BehindTheMeter"
BRANCH="fix/btm-tag-az-boards-detection"

# 3. Clone (or reuse an existing clone)
git clone "https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/${REPO}"
cd "${REPO}"
git switch -c "${BRANCH}"

# 4. Apply the change
#    Option B (default): copy the verified file over the target path
cp /path/to/azure-boards-add-tag.fixed.sh azure-pipelines/steps/azure-boards-add-tag.sh
#    Option A: apply the one-line edit from Section 4 instead.

shellcheck azure-pipelines/steps/azure-boards-add-tag.sh    # must be CLEAN
bash -n   azure-pipelines/steps/azure-boards-add-tag.sh     # must be OK

# 5. Commit + push
git add azure-pipelines/steps/azure-boards-add-tag.sh
git commit -m "fix(ci): BTM tag step TF401019 — explicit az boards context, no git auto-detect"
git push -u origin "${BRANCH}"

# 6. Open the PR (fill description from fix.md "Ready-to-use PR description")
az repos pr create --org "${ORG}" --project "${PROJ}" --repository "${REPO}" \
  --source-branch "${BRANCH}" --target-branch main \
  --title "Fix BTM PR auto-tagging — TF401019 from az boards git auto-detection" \
  --description "See log/.../2026_06_02_btm_pipeline_failed_git_error/fix.md. Root cause: az boards query auto-detected the repo from the git remote (/vsts/info) and the project-scoped job token (enforceJobAuthScope=true) was denied -> TF401019, swallowed -> silent green, tag never applied. Fix: explicit --organization/--project/--detect false; hardened script also writes tag UNION and reports via SucceededWithIssues. No pool change, no job split, no permission change."
```

## 6. Verification (run after the PR deploys — do NOT trust "green")

```bash
# Pick a PR whose commits contain a "Related work items:" line for a Team BtM item.
# (a) The tag step log must show the tag line and NO TF401019.
# (b) Assert the realized union state on a tagged work item:
az boards work-item show --org https://dev.azure.com/enecomanagedcloud \
  --detect false --id <work_item_id> --query "fields.\"System.Tags\""
#   -> must contain the env tag AND any tags it had before.

# (c) Local proof the failing call is gone (read-only, optional):
az boards query --organization https://dev.azure.com/enecomanagedcloud/ \
  --project "Myriad - VPP" --detect false --debug \
  --wiql "SELECT [System.Id] FROM workitems WHERE [System.AreaId]=6393" 2>&1 | grep -c vsts/info
#   -> 0
```

Map back to acceptance: (a)→AC1, (b)→AC2, Option B step result orange-on-failure→AC3,
diff scope→AC4.

## 7. Rollback

- Revert the PR (or the single commit). The change is confined to one script file; no state,
  no infra, no settings touched → rollback is a pure `git revert`.
- Blast radius if the fix is wrong: only the tagging step (cosmetic). With Option B it cannot
  block deployments (SucceededWithIssues). With Option A behaviour is unchanged from today.

## 8. Risk / blast radius

| Axis | Assessment |
|------|-----------|
| Reversibility | Trivial — single-file `git revert`. |
| Blast radius | Tagging step only; no deploy/infra impact. Option B is non-blocking by design. |
| Auth needed | Repo **write** + PR (the only privileged action). Read-only verification needs only `az login`. |
| Behaviour change (Option B) | Now writes the tag **union** (was: overwrite) and surfaces failures as orange (was: silent). Both are improvements; confirm the team wants visible-warning semantics. |

## 9. Open follow-ups (not blocking the fix)

1. **Confirm the exact ACL** (why `checkout: self` works but `/vsts/info` is denied): run one
   pipeline build with `system.debug: true` and read the `Add DEV tag` step log — the
   `/vsts/info` call should be present pre-fix and absent post-fix. Promotes the last INFER to FACT.
2. **Date the trigger precisely**: org **Pipelines → Settings** audit (was `enforceJobAuthScope`
   enabled ~2026-04-15..04-25?) or finer build-log bisection in that window.
3. **Org-wide pattern**: the Agg/`.B2B` pipeline broke in the same window. Search other ADO
   pipelines for `az boards`/`az repos` calls lacking `--org/--project` and apply the same fix
   (this is a class problem, not a one-off — see lesson LL-018).
