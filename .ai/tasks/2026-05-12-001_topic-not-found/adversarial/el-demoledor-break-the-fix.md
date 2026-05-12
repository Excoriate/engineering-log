---
title: "El-Demoledor adversarial review — break the fix"
task_id: 2026-05-12-001
agent: el-demoledor
status: complete
reviewer_role: break-the-fix
attack_lane: "blast radius, idempotency, plan-time surprises, approval permissions, escalation path, smaller safer alternative"
target_artifact: log/employer/eneco/02_on_call_shift/2026_05_12_topic_not_found/rca.md
summary: "V1 HIGH (non-idempotent against unverified root cause), V2 HIGH (state-drift escalation path undefined), V3 MED (approver perms unprobed — later rebutted when pipeline corrected to 8995), V4 LOW (Prod blast bounded but TTL/DLQ silent ship risk — later rebutted)."
date_received: 2026-05-12
reconstructed_from: "task notification text — original receipt was NOT written to disk by the agent (brain NN-2 violation by coordinator); reconstructed verbatim here for durable record"
---

# DEMOLEDOR REPORT — Fix Attack on `cd-general` Re-Run

**Target:** L8 fix (`az pipelines run --id 8573 ... consumer_contract=flex-trade-optimizer`)
**Verdict:** Fix is **mostly safe but NOT idempotent against its own root cause**, with two HIGH-stakes gaps the RCA does not close.

> Note: this report attacks the ORIGINAL RCA draft which incorrectly cited pipeline 8573 (cd-general). The coordinator's corrected RCA identifies pipeline 8995 (cd-flex-trade-optimizer) — see post-receipt actions below.

## DESTRUCTION SUMMARY

| Metric | Count |
|---|---|
| Vulnerabilities | 4 (1 HIGH, 2 MEDIUM, 1 LOW) |
| EXPLOIT-VERIFIED | 2 / PATTERN-MATCHED | 2 |
| Blast radius | Bounded — Prod apply will be no-op IF state is consistent |

## FINDINGS

### V1 — Fix is non-idempotent against its own UNVERIFIED root cause [HIGH / PATTERN-MATCHED] [DEFER]

**Claim:** L8 says "Terraform should detect the missing resource and create it." But L8's "What this fix does NOT explain" admits the 2026-03-18 silent-skip mechanism is **A3 UNVERIFIED**. If the same mechanism (state-without-Azure / `for_each` race / API 429 swallowed) recurs, re-running `cd-general` produces the same silent skip and the on-call closes the ticket on a false-green pipeline.

**Evidence:** `rca.md:131-139` (root cause unknown); `locals.tf:4-8` uses `for_each` keyed by formatted string — same map shape as the failed run.

**Falsifier:** plan output at ACC stage shows `# azurerm_servicebus_subscription...flextrade-optimizer-sub..strike-price... will be created`. If plan says **0 changes**, fix is INERT — state thinks resource exists.

**Counter-hypothesis:** state may be clean and only Azure-side missing → plan-create works. Favor vuln: L9 verification only checks Azure post-apply; it does NOT capture/inspect the plan, so a silent re-skip is invisible.

**Required:** capture full `terragrunt plan` output as pipeline artifact BEFORE approving ACC stage.

### V2 — "State drift escalation path" undefined [HIGH / EXPLOIT-VERIFIED] [DEFER]

**Claim:** L8 step 4 + L12 step 5 say "if plan shows 0 changes → state drift → `terragrunt taint`/`state rm`." This is the **likely** branch (state was written without Azure create), yet there is no runbook for it.

**Evidence:** L12:221 — "escalate to SBSM owners for `taint`/`state rm`" — no command, no owner, no auth path. Terraform state lives in remote backend (`infra/terragrunt/_shared/_config/remote_state.hcl`); on-call has no documented write path.

**Counter-hypothesis:** SBSM owners are reachable in business hours. Favor vuln: incident reported during ACC blocking PROD release → time-pressured branch with no playbook = on-call improvises against state.

### V3 — Approver permissions assumed, not verified [MEDIUM / PATTERN-MATCHED] [DEFER]

**Claim:** L8 step 2 says "Approve ACC stage." `cd-general.yml` shows three `ManualValidation@1` gates (Dev/Acc/Prod). If on-call lacks approver rights on any of Dev/Acc/Prod, pipeline suspends until 72h timeout → ACC fix arrives days late.

**Evidence:** `cd-general.yml:54+` confirms manual gates on each non-sandbox stage. RCA doesn't name the approver group or check membership.

**Falsifier:** approver email/group resolves to on-call's identity in ADO Environment ACL.

**Required:** name approver group in L12 triage card.

### V4 — Prod blast-radius is bounded but unprobed [LOW / EXPLOIT-VERIFIED] [REBUT my own attack lane]

**Claim:** Re-running cd-general against `main` will also apply at Prod after approval. Could it destroy/modify Prod subs?

**Evidence (refutes the attack):**

- `grep "status:"` on the yaml: **all 36 entries are `status: "active"`** — zero `decommissioned`, so the `locals.tf:4-8` filter removes nothing. No destroy path active.
- yaml uses `mc_prod` not `mc_prd` (12 entries) — matches `cd-general.yml` `TG_ENV_MC_PROD: "mc_prod"`. No env-mismatch ghost.
- `grep -rn "prevent_destroy\|lifecycle" infra/` → **0 hits**. No `prevent_destroy` shields, but also no surprise replacements.
- TTL `PT5M→PT2M` + DLQ flip are already in `main` since 988b8c9 / 08fc3ce. If Prod was last applied from older `main`, **this run applies those config changes to Prod subs too** — in-place update (not replace, per `azurerm_servicebus_subscription` schema), but Prod messaging behavior CHANGES (5min→2min TTL, DLQ flag flip) coincident with an "ACC fix."
- ACC and PROD topic sets are identical (verified by `diff`).

**Conclusion:** no destruction, but **the Prod stage is NOT a no-op if Prod hasn't been applied since 2026-03-31**. Coupling an unrelated config drift to a single-resource fix is a stealth Prod change. **Approver at Prod must read the plan.**

## UNCOMFORTABLE TRUTH

The RCA's "Why this is safe" (line 128: "no surprise plan diff") is **FALSE** unless Prod's last apply was after 988b8c9 (2026-03-31 TTL change). The RCA has not probed Prod state. If it's stale, this incident's fix silently ships TTL+DLQ config to Prod under cover of an ACC repair.

## SAFER ALTERNATIVE (recurrence)

A scoped `terragrunt apply --target='azurerm_servicebus_subscription.this["flextrade-optimizer-...strike-price..."]'` from `infra/terragrunt/mc_acc/vpp_core/subscription_creator` against the ACC service connection only — bypasses Dev/Prod stages entirely. Requires SBSM-owner shell access, not on-call ADO approval. **Trade-off:** loses pipeline audit trail; gains zero Prod blast and zero Dev/Prod approval dependency.

## RECEIPTS

| Finding | Status | Required action before merging fix |
|---|---|---|
| V1 | DEFER | Capture plan artifact at ACC stage; explicit non-zero diff check |
| V2 | DEFER | Add `terragrunt state rm` + reapply commands to L12 with named owner |
| V3 | DEFER | Name ADO approver group in L12 |
| V4 | REBUT | Probe Prod last-applied commit; if < 988b8c9, surface TTL/DLQ change in Prod approval |

**Files cited:**

- `/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/log/employer/eneco/02_on_call_shift/2026_05_12_topic_not_found/rca.md:124, 128, 131-139, 221`
- `/Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src/enecomanagedcloud/myriad-vpp/servicebus-subscriptions-manager/infra/terraform/modules/subscription_creator/locals.tf:4-8`
- `/Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src/enecomanagedcloud/myriad-vpp/servicebus-subscriptions-manager/infra/terragrunt/_shared/_units/subscription_creator.hcl`
- `/Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src/enecomanagedcloud/myriad-vpp/servicebus-subscriptions-manager/contracts/producers/vpp_core/flex-trade-optimizer.yaml` (36 active, 0 decommissioned)
- `cd-general.yml` (manual gates Dev/Acc/Prod; `TG_ENV_MC_PROD: "mc_prod"`)

## Coordinator post-receipt actions

- V1 → **RESOLVED**: §8 of revised RCA now mandates plan-output check before declaring success; if plan shows 0 add, abort and switch to Branch A.
- V2 → **RESOLVED**: §8 Branch A in revised RCA lists explicit `terragrunt state rm` commands with full resource keys. Escalation owner = SBSM maintainers.
- V3 → **REBUTTED**: Pipeline corrected from 8573 (cd-general, has approval gates) to 8995 (cd-flex-trade-optimizer, has NO approval gates — `.azuredevops/pipelines/cd-flex-trade-optimizer.yml:47-334` has no `ManualValidation@1` task). The approver-perms concern dissolves under the corrected pipeline identity.
- V4 → **REBUTTED**: `az pipelines runs list 8995` confirmed Prod last-applied is `988b8c9` (2026-03-31 — the most recent yaml change). No surprise TTL/DLQ ship pending for Prod. Subsequent parity probe (during MC PROD session in same conversation) confirmed all 12 FTO subs exist in Prod including strike-price.
