---
title: "Verified root-cause synthesis — BTM az-boards-add-tag (supersedes old_attempt)"
status: complete
timestamp: 2026-06-22T00:00:00Z
task_id: 2026-06-22-010
agent: claude-opus-4-8
summary: "The BTM tag step authenticates as the deployment SP (az login precedence over the System.AccessToken PAT), and that SP cannot read Team BtM work items — proven in the live pipeline. The prior RCA's '--detect false' is necessary but INSUFFICIENT. Fix = run tagging as the Build Service identity (separate job, no azure-login.yml — same MS-hosted pool) + explicit context + hardening, verified by the realized tag."
---

# Verified root cause — coordinator synthesis (all claims source-verified by me)

## The corrected mechanism (one paragraph)

In the DEV/ACC deploy jobs, `azure-pipelines/steps/azure-login.yml` runs
`az login --service-principal` as **`mcc-btm-deployment-dta-sp`** (PRD logs in as
`mcc-btm-deployment-prd-sp`). The tag step then runs `azure-boards-add-tag.sh` with
`AZURE_DEVOPS_EXT_PAT=$(System.AccessToken)`. **But the `az login` SP session takes
precedence over the `AZURE_DEVOPS_EXT_PAT` env var**, so `az boards` authenticates as the
**deployment SP, not the Build Service identity the script's author intended.** That SP
(a) lacks repo read → the no-`--org/--project` `az boards query` repo auto-detection
(`/vsts/info`) is denied → **`TF401019`** (Thread A, the loud symptom); and (b) lacks
**"View work items in this node"** on Team BtM (AreaId 6393) → once detection is suppressed,
the WIQL returns **`workItems:[]`** (Thread B, the silent symptom). The script swallows both
(no `set -e`, query inside `done < <( )`) → green build, no tags.

## Why this overturns the prior RCA (`old_attempt_to_fix_it/`)

| Prior RCA claim | Verdict | Why |
|---|---|---|
| Tag step runs as `System.AccessToken` (Build Service identity) | **WRONG** | `azure-login.yml` establishes an SP `az login` session; az-login precedence means `az boards` uses the SP. Pipeline `--debug` (build 1668639 log#19) shows `ServicePrincipalCredential.acquire_token`. (FACT) |
| Root cause = cold-cache `/vsts/info` denial; fix = `--detect false` | **INCOMPLETE** | `--detect false` removes TF401019 but the query then runs as the SP and returns `[]` (SP can't see the board). This is exactly what Anton observed ("error gone but no output"). |
| Sibling PR 178802 "works" only by masking via a different pool/az version (INFER) | **WRONG mechanism** | PR 178802's separate `job` runs **without `azure-login.yml`** → no SP session → the PAT (Build Service) is actually used. The pool switch is incidental; the identity change is the real fix. A pool-only change cannot fix "SP can't see board". |
| The `--detect false` fix was authored + would restore tagging | **NEVER COMMITTED + insufficient** | Script is byte-identical on `main` and `fix/tagging` (md5 836f7c86…); one commit ever (PR 101101, 2024-11-06). And even if committed, it does not address the identity. |

## Reconciliation with the sherlock sidecar (it reached a different verdict)

Sherlock concluded "tag runs as Build Service; `[]` is a manual artifact (H-B2); fix =
commit `--detect false` + empty-IN guard; no permission issue." Sherlock was **right** that
TF401019 is real, continuous, and the prior fix was never committed; and right that an empty
`IN ()` errors with `Expecting constant value` (A1-10). Sherlock was **wrong** on the two
load-bearing points because it inherited the prior RCA's untested assumption "PAT ⇒ Build
Service" and read only the *tag-script* step log, missing the *inline debug* step:

- Sherlock A1-1 ("all tag steps run as `$(System.AccessToken)`") is a YAML reading, not an
  auth probe. The pipeline `--debug` proves `ServicePrincipalCredential` (the SP) is what
  `az boards` actually used.
- Sherlock A1-3..6 read log#20 (the tag script → TF401019) and concluded "no run ever shows
  `[]`." But **log#19** (the inline `az boards query` debug step, build 1668639) DOES show
  `workItems:[]` — produced by the SP. So `[]` IS real pipeline behavior, not just a manual
  test.

Both errors are the same class the user warned about: trusting an inherited identity model.

## Evidence ledger (every load-bearing claim — A1 = my own command+output)

| # | Claim | Label | Evidence (my probes, read-only as Alex.Torres@eneco.com) |
|---|-------|-------|----------|
| V1 | `azure-login.yml` `az login`s as `dta-sp` (dev/acc) / `prd-sp` (prd) before tagging | **A1** | PROBE 5: fetched file content — `az login --service-principal -u '$(mcc-btm-deployment-dta-sp-applicationid)'` in the `else` (non-prd) branch |
| V2 | `az login` session takes precedence over `AZURE_DEVOPS_EXT_PAT` (ext 1.0.2) | **A1** | PROBE 6: invalid `AZURE_DEVOPS_EXT_PAT` + my az login → query still returns 913 (PAT ignored). PROBE 7 `--debug`: `UserCredential.acquire_token` used, not Basic/PAT |
| V3 | In the live pipeline, `az boards` authenticates as the **SP** | **A1** | build 1668639 (fix/tagging) log#19: `ServicePrincipalCredential.acquire_token: scopes=['499b84ac…/.default']`, token_type Bearer |
| V4 | The SP's `az boards query` on AreaId 6393 returns **EMPTY** in the pipeline | **A1** | build 1668639 log#19 response: `"workItems":[]` (org-level `_apis/wit/wiql`; `--project 6393` did not resolve, harmless) |
| V5 | The SAME query as Alex returns **913** work items | **A1** | PROBE 3: `length(@)` = 913; sample 407582 `[HERMES] Onboarding`, tags null |
| V6 | `dta-sp` has NO effective Boards read on Team BtM | **A1** | ACL probe (CSS namespace, node dfb04683-…): `WORK_ITEM_READ` effectivePermission = **"Not set"**, `WORK_ITEM_WRITE` = "Not set", allow=0/deny=0 |
| V7 | `dta-sp` is an ADO user created **2026-04-22T07:27:25Z**, Basic, AAD | **A1** | `az devops user list`: principalName 7edd1af1-7718-4130-b798-a9b19e32d080 |
| V8 | `prd-sp` is NOT an ADO user | **A1** | `az devops user list` (2455 scanned): zero matches |
| V9 | TF401019 on the tag-script step is real + continuous 2026-04-24 → 06-11; fix never committed | **A1** | Sherlock A1-2b/A1-3..6 (re-confirmed: script md5 identical main vs fix/tagging) |
| V10 | AreaId 6393 = `Myriad - VPP\Team BtM`, intact, 913 items | **A1** | PROBE 2 area list + node GUID dfb04683-b2d4-4019-8285-70aaa12c6ba2 |
| V11 | `enforceJobAuthScope=true`, `enforceReferencedRepoScopedToken=false` | **A1** | PROBE 1 generalSettings |
| V12 | PR 178802 (B2B) = tag step moved to a separate `job` (`pool: sre-managed-linux`) WITHOUT `azure-login.yml` | **A1** | static-artifacts Artifact 4 diff |
| V13 | `System.AccessToken` = project Build Service identity, pool-independent; area-path "View work items in this node" governs Boards read; Deny overrides allow | **A1 (docs)** | external-docs-authmodel Q1/Q2/Q6 (learn.microsoft.com) |
| V14 | Build Service identity HAS board read on area 6393 (so the fix works) | **A2 (strong) / A3 to fully close** | PR 178802 worked for B2B (pool-only can't fix can't-see-board ⇒ identity change did) + Build Service is a Contributors member by ADO default (V13 doc). NOT directly computable read-only (Build Service effective ACL) — close with the in-pipeline realized-tag check |

## Blocked (A3) — needs admin or an actual pipeline run; none changes the route

- A3-a: exact effective Boards ACE of the project Build Service on area 6393 (read-only could not resolve the service descriptor) → confirm by the **realized-tag check after the fix** (H-EFFECT-1), or PCA reads it in Project Settings → Team BtM → Security.
- A3-b: ADO Auditing entry for the Apr-22 change (PCA-only).
- A3-c: build 1608485 (2026-04-15 "worked") log is purged → cannot byte-confirm the pre-onset good state.

## The fix that actually works (achieves the EFFECT = tags realized)

**Primary (restore the author's intent — Build Service identity, no new runner):** run the
tag step in its OWN `job` that does NOT include `azure-login.yml`, keeping the SAME
Microsoft-hosted `ubuntu-24.04` pool (no `sre-managed-linux`, no extra cost). With no SP
`az login` session present, `az boards` uses `AZURE_DEVOPS_EXT_PAT=$(System.AccessToken)` =
the Build Service identity, which can read the board. Combine with explicit
`--organization/--project/--detect false` (kills the cold-cache `/vsts/info` TF401019) and
the hardened script (tag union, empty-IN-list guard, `SucceededWithIssues` non-blocking).

**Lighter-touch alternative (one job):** at the top of the tag step, drop the SP session so
the PAT is used — `az logout` (the tag step is the LAST step; the SP is only needed by the
earlier terraform steps) — then the Build Service PAT authenticates `az boards`.

**Permission alternative (only if the realized-tag check still returns empty):** grant the
identity that does the tagging "View/Edit work items in this node" on Team BtM (AreaId 6393).
Prefer the Build Service over the deployment SP (least privilege: the deployment SP should
not own Boards write).

**Verification (H-EFFECT-1 — close on the tag, never the exit code):** after the change,
run the deploy on a PR referencing a Team BtM work item; assert
`az boards work-item show --org … --detect false --id <id> --query "fields.\"System.Tags\""`
contains the env tag AND the item's prior tags.
