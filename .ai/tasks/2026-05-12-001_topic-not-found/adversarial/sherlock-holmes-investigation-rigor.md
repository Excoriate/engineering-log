---
title: "Sherlock-Holmes adversarial review — investigation rigor"
task_id: 2026-05-12-001
agent: sherlock-holmes
status: complete
reviewer_role: investigation-rigor
attack_lane: "are alternative hypotheses sufficiently eliminated? is evidence load-bearing?"
target_artifact: log/employer/eneco/02_on_call_shift/2026_05_12_topic_not_found/rca.md
summary: "Diagnosis is Hypothesis Set, not Verified Root Cause. F1 + F2 + F4 + F6 surface defers; F3 + F5 + F7 close hypotheses."
date_received: 2026-05-12
reconstructed_from: "task notification text — original receipt was NOT written to disk by the agent (brain NN-2 violation by coordinator); reconstructed verbatim here for durable record"
---

# Sherlock Adversarial Review — FTO strike-price RCA

**Verdict on RCA's "single-resource silent failure" diagnosis: Hypothesis Set (not Verified Root Cause).** Several alt hypotheses survive the cited evidence.

## Findings

### F1 — REBUT — "yaml at deploy time was 9c6a462" not proven; only "merged commit contained strike-price" is proven.

RCA L6 (`rca.md:93`) asserts yaml at 9c6a462 already contained all 12 entries — true (`git show 9c6a462:...flex-trade-optimizer.yaml` confirms strike-price at line 230 in mc_acc block). **But this does not prove pipeline 8573 checked out 9c6a462.** `cd-general` is manual-trigger with a `branch` param (RCA L11 step 4 confirms `--branch main`). Whoever fired it at 12:50 UTC on 2026-03-18 could have specified an older sha, a feature branch, or `main` before the merge propagated. A1 evidence requires the ADO build 8573 run's `sourceVersion` — explicitly marked `A3 UNVERIFIED[blocked]` at `rca.md:139`. **The "silent failure" framing presumes the deploy used 9c6a462; that premise is INFER, not FACT.**

### F2 — DEFER (high) — Producer collision hypothesis not eliminated.

`grep strike-price` across `contracts/producers/vpp_core/` shows `asset-scheduling.yaml:88` also declares a subscription on the **same topic** `assetplanning-asset-strike-price-schedule-created-v1` in `mc_acc` — but with `subscription_name: "asset-scheduling-gateway"` (different name, A1 FACT from grep output above). So the same-identity collision the user asked about is **falsified by evidence** for these two yamls. **However**: the RCA did not enumerate ALL contracts for collisions on `flextrade-optimizer-sub` name. Defer: grep `subscription_name: "flextrade-optimizer-sub"` across `contracts/**/*.yaml` is needed; if a second contract also owns that name on a different topic, `for_each` key collision could explain a silent skip.

### F3 — REBUT — "added later via rebase" hypothesis.

`git show 3dea795:contracts/producers/vpp_core/flex-trade-optimizer.yaml` (feature-branch add commit 2026-03-16) already contains strike-price at line 44 (mc_acc block at line 230 — same offset as merged 9c6a462). No post-merge amendment. Rebase-collision hypothesis dies.

### F4 — DEFER — Topic-properties asymmetry.

`az servicebus topic show` diff (run above): strike-price `createdAt: 2025-10-20T08:34Z`, complete-power `createdAt: 2025-09-01T08:18Z`. **Strike-price was created 7 weeks AFTER complete-power.** Both Active, identical retention/dedup/partition flags. But — at the moment of the 2026-03-18 12:50 apply, was strike-price topic already in a state Terraform's AzureRM provider could see? `accessedAt` does not answer this. The 5-month gap before the apply makes this unlikely-but-not-impossible. Lock/RBAC/policy differences not probed.

### F5 — REBUT — Terragrunt `exclude`/`skip` block.

`grep -rn "exclude\|skip\|prevent_destroy" infra/terragrunt/` returned **zero matches** (probe above). No per-topic conditional drop. This alt hypothesis is eliminated.

### F6 — DEFER — `state rm` / out-of-band intervention.

RCA L8 lists this as follow-up hypothesis (`rca.md:137`) but does not probe Terraform state. Without `terragrunt state list | grep strike-price` against the ACC backend, "subsequent `state rm`" remains as plausible as "creation never happened". The fix step `rca.md:124` ("if plan shows 0 changes → `state rm` needed") implicitly admits this: the recommended fix is **diagnostic of the alt hypothesis, not curative of the diagnosed one**.

### F7 — REBUT — "11-in-2s proves single apply."

`createdAt` for complete-power confirmed `2026-03-18T12:50:20.78Z` (probe above). 2-second clustering across 11 resources is decisive for same-apply (Terraform parallelism default 10) — accept.

## Routing

Diagnosis MUST be downgraded from "single-resource silent failure" (L8 framing) to **"strike-price absent in Azure; cause indeterminate without ADO build 8573 logs + tfstate inspection"**. The fix (re-trigger 8573) is correct as a curative action because it converges all branches. **The L10 "Lessons" should not claim "silent Terragrunt failure is a recurrence-risk pattern" as a generalized lesson** — that conclusion rests on F1 which is INFER, not FACT.

**Required before promote to Verified:** (a) `az pipelines runs list --pipeline-ids 8573` filtered to 2026-03-18 to get `sourceVersion`; (b) `terragrunt state list` against ACC backend for strike-price; (c) grep `subscription_name: "flextrade-optimizer-sub"` across all contracts for name collisions.

## Coordinator post-receipt actions

- F1 → **RESOLVED**: `az pipelines runs show --id 1574478` confirmed `sourceVersion=9c6a462ab35e45a149093fc1e2542086b85def1c`. Pipeline identity corrected from 8573 (cd-general, wrong) to 8995 (cd-flex-trade-optimizer, correct).
- F2 → **REBUTTED**: `grep -rl 'subscription_name: "flextrade-optimizer-sub"' contracts/` returns only flex-trade-optimizer.yaml. No cross-contract collision.
- F4 → **REBUTTED**: `az servicebus topic show` diff of strike-price vs complete-power confirms identical Azure properties.
- F6 → **RESOLVED**: `terragrunt state list` against ACC backend (run in same session, post-cleanup) showed state HAS strike-price entries. Branch A confirmed. Plan output `2 to add, 11 to change, 1 to destroy` proves the fix path.

Files referenced (from original Sherlock receipt):
- `/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/log/employer/eneco/02_on_call_shift/2026_05_12_topic_not_found/rca.md` (lines 93, 97, 124, 137, 139, 164)
- `/Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src/enecomanagedcloud/myriad-vpp/servicebus-subscriptions-manager/contracts/producers/vpp_core/asset-scheduling.yaml:88`
- `/Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src/enecomanagedcloud/myriad-vpp/servicebus-subscriptions-manager/contracts/producers/vpp_core/flex-trade-optimizer.yaml:248`
