---
task_id: 2026-06-02-001
agent: claude-opus-4-8
status: complete
summary: Plan + adversarial-question gate for the BTM TF401019 RCA/fix package.
---

# Plan — BTM `azure-boards-add-tag.sh` TF401019 RCA + fix

## Verified causal chain (A1 unless noted)

- **L1 proximate**: `az boards query`/`az boards work-item update` run with NO `--org/--project` and detection ON, inside the checked-out repo. The azure-devops CLI auto-detects context via `GET .../myriad%20-%20vpp/_git/eneco.vpp.behindthemeter/vsts/info` (A1: live `--debug` repro). The lowercased repo id `eneco.vpp.behindthemeter` is byte-identical to the TF401019 error string. That repo-resolution call is denied for the pipeline's project-scoped job token → `TF401019 … 404`.
- **L2 enabling**: script has no `set -e`; the failing `az boards query` is inside `done < <(…)` process substitution → non-zero exit swallowed → task marked **succeeded** while tag silently not applied (A1: build 1663945 logId 43 shows the error then "succeeded").
- **L3 design/context**: `enforceJobAuthScope=true` (A1: project generalSettings) + reliance on implicit CLI git-remote auto-detection. Onset "weeks/months ago" aligns with scope enforcement / az-extension behavior change (exact date = A3, needs org audit log; NOT load-bearing).

## Fix decision

- **Primary (root-cause, cheapest, no job split, locally testable)**: pass `--org "$SYSTEM_COLLECTIONURI" --project "$SYSTEM_TEAMPROJECT" --detect false` to BOTH `az boards` calls. A1-proven to remove the failing `/vsts/info` call (repro 2b). Stays on Microsoft-hosted `ubuntu-24.04`; no ADO permission change.
- **Hardening (recommended)**: `set -euo pipefail` + empty-work-items guard + loud failure, so future breakage is a RED pipeline, not a silent missing tag.
- **Rejected as primary**: sibling team's PR 178802 approach (move tagging to `pool: sre-managed-linux`). Per MS docs the job-auth identity is pool-independent; the self-hosted pool only masks the cause (different az/extension version or cached broad credential). Costs a second runner + job split — the user's stated concern.

## 6 adversarial questions (each changes a step or names a residual)

- **Q1 assumption** — Is TF401019 from detection, or from a cross-project `work-item update`? → AreaId 6393 = `Myriad - VPP\Team BtM` (A1, same project); detection URL == error string. Detection confirmed; cross-project risk eliminated.
- **Q2 alternative** — Expired self-hosted agent PAT (LL-006)? → Failing run is on Microsoft-hosted pool with `AZURE_DEVOPS_EXT_PAT=$(System.AccessToken)`; no self-hosted agent involved. Eliminated for THIS pipeline.
- **Q3 disprove** — What falsifies "detection is the cause"? → If `--detect false` did not remove `/vsts/info` (it did, 2b), or if a fixed pipeline still failed (→ pipeline test in verification).
- **Q4 hidden complexity** — Why is same-project `/vsts/info` denied when `checkout: self` succeeds with the same token? → Residual **A2**: precise denial mechanism (collection-level resolution vs project-scope) is INFER; the fix removes the call regardless, so not load-bearing. Disclosed honestly + definitive probe named (pipeline `--debug`).
- **Q5 version** — Could az/azure-devops-extension version drift (ubuntu-24.04 vs sre-managed-linux) explain the pool-switch "working"? → Yes; documented as the masking mechanism. Local az = 2.86.0.
- **Q6 silent-fail** — Will the fix look successful while wrong? → The script swallows errors (green-but-broken). Verification MUST inspect the work item's actual tags, not just pipeline status. Hardening makes failure loud.

## Adversarial dispatch (P8) — typed, receipts to disk

- `sherlock-holmes` → attack the causal chain / alternative hypotheses. Receipt: `$T_DIR/adversarial/sherlock-causal-chain.md`.
- `sre-maniac` → attack the FIX + verification (failure modes, edge cases, rollback). Receipt: `$T_DIR/adversarial/sre-fix-failure-modes.md`.
- goal-fidelity (separate typed) → ask↔deliverable divergence vs the verbatim user corpus. Receipt: `$T_DIR/adversarial/goal-fidelity.md`.
- Each prompt: facts + target path only, no embedded verdict; write file + return path; coordinator `test -s` + read before synthesis.

## Authorization boundary

Applying the fix = external git mutation on the ADO repo (`Eneco.Vpp.BehindTheMeter`) + PR. NOT authorized in this session. Deliverable = ready patch + PR description + local test recipe; ask before any push/PR.
