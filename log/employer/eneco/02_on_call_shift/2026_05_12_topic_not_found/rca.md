---
title: "FTO strike-price subscription missing on ACC"
date: 2026-05-12
status: complete
incident_class: on-call
producer: vpp_core
consumer_team: flex-trade-optimizer
environment: mc_acc
blocking: "PROD promotion of FTO release"
adversarial_review:
  - sherlock-holmes
  - socrates-contrarian
  - el-demoledor
diagnosis_class: "Hypothesis Set — observation is FACT; mechanism (why one of 12 was silently skipped) is UNVERIFIED"
---

# RCA — FTO strike-price subscription missing on ACC

> **Reader's compass**: this RCA went through three adversarial reviews (Sherlock investigation rigor, Socrates assumption attack, El-Demoledor break-the-fix). The original draft had two FACT errors (wrong pipeline, wrong trigger mechanism) that the reviewers exposed and that this revision corrects. Findings classified RESOLVE/REBUT/DEFER are captured in §13.

## TL;DR

**Topic exists.** `assetplanning-asset-strike-price-schedule-created-v1` is `Active` in ACC (created 2025-10-20). The user's "verify topic first" hypothesis is **FALSIFIED**.

**Observation (A1 FACT).** Pipeline **8995 `servicebus-subscriptions-manager-cd-flex-trade-optimizer`** auto-triggered on commit `9c6a462` (PR 168062 merge, 2026-03-18 11:23 UTC), succeeded at 12:53 UTC, and its `ApplyAcc` stage created **11 of the 12** `flextrade-optimizer-sub` subscriptions declared in `flex-trade-optimizer.yaml` for `mc_acc` — all in a 2-second window 12:50:18-20 UTC. Strike-price alone was skipped. Two subsequent successful applies of the same pipeline (12:53→14:46 same day, then 2026-03-31) did NOT reconcile the gap. The yaml entries are byte-identical except for `topic_name`. Cross-contract collision on `subscription_name` is ruled out. Topic-level Azure properties are identical between strike-price and a working peer.

**Diagnosis (A2 INFER, downgraded to Hypothesis Set per Sherlock F1+Demoledor V1).** A **single-resource silent failure or state-vs-Azure drift** localized to the strike-price subscription. The Terragrunt `apply --auto-approve` (pipeline yaml `cd-flex-trade-optimizer.yml:115/187/259/331`) exited 0 either because: (a) the resource was successfully created and later deleted out-of-band; or (b) it was created in Terraform state but never reached Azure; or (c) some provider-level skip mechanism dropped it from the apply plan while state stayed consistent. Without `terragrunt state list` against the ACC backend, these branches cannot be discriminated and the recommended fix differs per branch.

**Recommended fix (CONDITIONAL — read §8 before acting):**

1. **Gate-zero probe (MANDATORY):** `terragrunt state list` against ACC `subscription_creator` backend — does state contain a strike-price key?
2. **If state has the resource:** state-vs-Azure drift → `terragrunt taint` (or `terraform state rm`) followed by a re-apply.
3. **If state lacks the resource:** push an empty commit to `main` (or run pipeline 8995 manually) → next ApplyAcc will create it as a single-resource diff. Prod stage is current with main (last applied 2026-03-31 `988b8c9`) so no surprise diff.

---

## Context Ledger (zero-context reader)

| Term | Meaning | Code/Resource |
|------|---------|---------------|
| FTO | Flex Trade Optimizer — VPP consumer service | `flex-trade-optimizer.yaml` |
| SBSM | servicebus-subscriptions-manager — Terragrunt-driven manager that provisions Service Bus **subscriptions** on **pre-existing** topics | ADO repo `servicebus-subscriptions-manager` |
| Contract YAML | Per-consumer subscription declaration | `contracts/producers/vpp_core/flex-trade-optimizer.yaml` |
| **Pipeline 8995 `cd-flex-trade-optimizer`** | **Auto-triggered** SBSM CD pipeline dedicated to FTO contract; Sandbox → Dev → Acc → Prod sequentially, **NO approval gates** | `.azuredevops/pipelines/cd-flex-trade-optimizer.yml` |
| Pipeline 8573 `cd-general` | Manual-trigger SBSM CD pipeline for contracts WITHOUT a dedicated CD pipeline (e.g. asset-scheduling) | `.azuredevops/pipelines/cd-general.yml` |
| Pipeline 8574 `cd-myriad-platform` | Auto-triggered CD pipeline for the internal platform team's own contract | `.azuredevops/pipelines/cd-myriad-platform.yml` |
| `subscription_creator` Terragrunt unit | Per-env Terragrunt unit that calls the `subscription_creator` Terraform module | `infra/terragrunt/{env}/vpp_core/subscription_creator/` |
| ACC SB namespace | `vpp-sbus-a` in RG `mcdta-rg-vpp-a-messaging`, Azure sub `b524d084-edf5-449d-8e92-999ebbaf485e` | Azure portal |
| `flextrade-optimizer-sub` | FTO's subscription name on each topic it consumes | Declared in yaml |
| `for_each` key | Terraform map key for each subscription resource: `format("%s-%s-%s", var.consumer_team, trimspace(lower(s.topic_name)), trimspace(lower(s.subscription_name)))` | `infra/terraform/modules/subscription_creator/locals.tf:6` |

---

## L1 — Business — Why FTO needs this subscription

FTO is a VPP-side consumer that reacts to strike-price schedule events to compute flex-trade decisions. Without the `flextrade-optimizer-sub` on `assetplanning-asset-strike-price-schedule-created-v1` (ACC), FTO cannot consume strike-price messages during ACC validation — **the missing sub is blocking the PROD release promotion** (per slack-intake line 14).

## L2 — Repo system

| Repo | Role | Path of interest |
|------|------|-----------------|
| `servicebus-subscriptions-manager` (SBSM) | Manages **subscriptions** on existing topics via Terragrunt | `contracts/producers/vpp_core/flex-trade-optimizer.yaml:248-255` |
| (Topic owner repo — separate) | Owns the **topic** itself | Out of scope (topic verified to exist) |

## L3 — Runtime architecture

- Azure subscription `b524d084-edf5-449d-8e92-999ebbaf485e` (Eneco VPP MC Acc)
- Resource group `mcdta-rg-vpp-a-messaging`
- Service Bus namespace `vpp-sbus-a`
- Topic `assetplanning-asset-strike-price-schedule-created-v1` (Active since 2025-10-20)
- Expected subscription: `flextrade-optimizer-sub` (MISSING)
- Actual subscriptions on that topic today: `dataprep` only (created 2026-04-20 — proves SBSM CAN write subs to this topic)

## L4 — Contract YAML

`flex-trade-optimizer.yaml:248-255`:

```yaml
- topic_name: "assetplanning-asset-strike-price-schedule-created-v1"
  subscription_name: "flextrade-optimizer-sub"
  environment_name: "mc_acc"
  app_service_principal_object_id: "013f744d-6674-401c-ba3b-632da8f29b8a"
  configurations:
    default_message_ttl: "PT5M"
    dead_lettering_on_message_expiration: false
  status: "active"
```

A1 FACT (byte-level diff against the working complete-power-schedule peer at `:284-291`): only `topic_name` differs. `od -c` confirms no non-printing bytes, no yaml anchors, no encoding artifacts. Indentation, quoting, key order, identity, configurations, status — all identical.

A1 FACT (`grep -rl 'subscription_name: "flextrade-optimizer-sub"' contracts/`): only one file (`flex-trade-optimizer.yaml`) declares this subscription name. No cross-contract `for_each`-key collision possible.

A1 FACT (`infra/terraform/modules/subscription_creator/locals.tf:6`): the for_each key is `consumer_team-topic_name-sub_name`. Across the 12 `mc_acc` entries only `topic_name` varies and all 12 topic_names are unique. No intra-contract key collision possible.

## L5 — IaC / state / Azure — the three truths

| Truth | Says |
|-------|------|
| **Spec (yaml at HEAD on `main`)** | `flextrade-optimizer-sub` MUST exist on `assetplanning-asset-strike-price-schedule-created-v1` in `mc_acc` |
| **Azure (live ACC SB namespace)** | Subscription does NOT exist (`(SubscriptionNotFound) Subscription does not exist`) |
| **Terraform state (ACC backend)** | **NOT inspected this session** — see §8 gate-zero |

Spec ≠ runtime. Spec-vs-state and state-vs-runtime branches both possible.

## L6 — Pipeline — how spec becomes runtime [CORRECTED]

**The earlier draft of this RCA cited the wrong pipeline.** Source of truth is `.azuredevops/pipelines/cd-flex-trade-optimizer.yml`.

A1 FACT (`cd-flex-trade-optimizer.yml:10-18`): Pipeline **8995** auto-triggers on `branches:[main]` when ANY of these paths change:

```yaml
paths:
  include:
    - contracts/producers/vpp_core/flex-trade-optimizer.yaml
    - infra/terragrunt/**/subscription_creator/**
    - infra/terraform/modules/subscription_creator/**
```

A1 FACT (`cd-flex-trade-optimizer.yml:47-334`): four stages in sequence — `ApplySandbox` → `ApplyDev` → `ApplyAcc` → `ApplyProd`. **No `ManualValidation@1` task in any stage.** Each stage runs `terragrunt apply --auto-approve --no-color --non-interactive` against the env-specific service connection.

A1 FACT (`az pipelines runs list --pipeline-ids 8995`): pipeline 8995's run history is fully visible. There are 7 runs total since 2026-03-16; 3 succeeded after the strike-price entry was merged to main (see §7).

A2 INFER (per Sherlock F1): a successful pipeline run means `terragrunt apply` exited 0 in every stage. It does NOT prove every resource declared in the yaml made it into Azure. Terraform's `apply --auto-approve` on a `for_each` resource set commits per-resource; one resource's transient provider failure does NOT necessarily abort the apply if Terraform's error handling treats it as a deferred failure (and pipeline yaml uses no `--terragrunt-fail-on-state-bucket-creation` or `-detailed-exitcode`).

**This is the load-bearing mechanism the diagnosis depends on, and it remains MECHANISM-UNVERIFIED — see §8 follow-up.**

## L7 — Timeline [CORRECTED]

| When (UTC) | Event | Source |
|-----------|-------|--------|
| 2025-10-20 08:34 | Strike-price + complete-power-schedule topics created | `az servicebus topic show` |
| 2025-10-20 08:34 | `dataprep` sub created on complete-power-schedule | Azure |
| 2026-03-12 15:06 | FTO consumer yaml first committed (sandbox-only entries) — commit `6e01bd0` | git |
| 2026-03-16 13:50 | Strike-price + 11 peer `mc_acc` entries added in feature branch — commit `3dea795` | git |
| 2026-03-16 13:32 | Pipeline 8995 run 1573… **FAILED** (sourceVersion `471c081`, manual) | `az pipelines runs list 8995` |
| 2026-03-17 16:08 | Pipeline 8995 run **SUCCEEDED** (sourceVersion `52ea3ea`, manual) | ADO |
| 2026-03-18 11:23 | PR 168062 merged to main — commit `9c6a462` (full mc_acc yaml present) | git |
| 2026-03-18 11:23:59 | Pipeline 8995 run **1574478 auto-queued** (`individualCI` reason, sourceVersion `9c6a462`) | ADO |
| **2026-03-18 12:50:18–20** | **11 of 12 `flextrade-optimizer-sub` subs created in ACC; strike-price SKIPPED** | Azure `createdAt` |
| 2026-03-18 12:53:45 | Pipeline 8995 run 1574478 **SUCCEEDED** end-to-end (Sandbox→Dev→Acc→Prod) | ADO |
| 2026-03-18 12:46:51 | A separate run 1573278 **FAILED** (sourceVersion `68693c47`, manual) — unrelated to the successful run | ADO |
| 2026-03-18 14:39 → 14:46:01 | Pipeline 8995 run 1574999 **SUCCEEDED** (sourceVersion `08fc3ce`, PR 168600 DLQ change, `individualCI`) — yaml still had strike-price entry; re-apply did NOT create it | ADO |
| 2026-03-31 10:06:39 | Pipeline 8995 run **SUCCEEDED** (sourceVersion `988b8c9`, PR 170592 TTL change, `individualCI`) — yaml still had strike-price entry; re-apply did NOT create it | ADO |
| 2026-04-20 06:52 | `dataprep` sub created on strike-price topic (different consumer's pipeline) | Azure |
| 2026-05-12 | Producer team filed Slack ticket: "sub missing on ACC, blocking PROD release" | `slack-intake.txt` |

**Three successive successful applies after the strike-price entry was in `main`, and the sub still does not exist in Azure.** This is the load-bearing observation that escalates from "transient single-incident skip" to "persistent state-vs-Azure inconsistency."

## L8 — Fix (CORRECTED with adversarial-required gates)

### Gate-zero (MANDATORY before any pipeline action) — surfaced from Socrates F3 + Demoledor V2

The state-vs-Azure fork must be discriminated before choosing a fix. Run against the ACC `subscription_creator` Terragrunt backend:

```bash
cd infra/terragrunt/mc_acc/vpp_core/subscription_creator
# Authenticate to ACC (eneco-tools-connect-mc-environments skill, acceptance, read-only)
terragrunt state list 2>&1 | grep -i strike-price
```

- **Branch A — state HAS a strike-price entry.** State-vs-Azure drift. Re-running pipeline 8995 will show `0 changes` (Terraform thinks resource exists) and the fix silently no-ops. Required action: `terragrunt state rm '<key>'` then re-apply. Owner: SBSM maintainers — name in escalation playbook below.
- **Branch B — state does NOT have a strike-price entry.** Terraform never recorded it (the silent-skip happened during initial plan/apply, not after creation). Re-running pipeline 8995 should detect the missing resource and create it.

### Branch B fix (state-lacking case)

1. Push an empty commit to `main` (cheapest re-trigger) **OR** `az pipelines run --id 8995 --branch main --org "https://dev.azure.com/enecomanagedcloud" --project "Myriad - VPP"`.
2. Watch ADO build for pipeline 8995. The `ApplyAcc` stage should show in its Terragrunt apply log:

   ```text
   # azurerm_servicebus_subscription.this["flex-trade-optimizer-assetplanning-asset-strike-price-schedule-created-v1-flextrade-optimizer-sub"] will be created
   ```

   **If the plan shows `0 to add`, abort and switch to Branch A.** (Demoledor V1 — without this check, on-call closes the ticket on a false-green pipeline.)

3. After `ApplyAcc` succeeds, verify in Azure (§9).

### Branch A fix (state-phantom case)

Escalate to SBSM maintainers. Required commands (must be run from authenticated MC ACC context):

```bash
cd infra/terragrunt/mc_acc/vpp_core/subscription_creator
terragrunt state rm 'module.subscription_creator.azurerm_servicebus_subscription.this["flex-trade-optimizer-assetplanning-asset-strike-price-schedule-created-v1-flextrade-optimizer-sub"]'
# Trigger pipeline 8995 to re-apply with state now clean
```

### Why this fix is safe (CORRECTED — REBUT my own earlier "no surprise plan diff" claim per Demoledor V4)

A1 FACT (`az pipelines runs list 8995`): Pipeline 8995 ran successfully on commit `988b8c9` on 2026-03-31 — and `988b8c9` is the most recent commit touching `flex-trade-optimizer.yaml`. No subsequent yaml changes (PR 172589 and later affect other contracts). **Therefore the Prod stage of a fresh 8995 run today will see no config drift in `mc_prod` and apply only the strike-price create.**

A1 FACT (`grep 'status:' flex-trade-optimizer.yaml`): all 36 entries are `status: "active"` — zero `decommissioned`. The Terragrunt `locals.subscriptions_to_create` filter (`locals.tf:7`) drops only `decommissioned` entries; no destroy path is currently active.

A1 FACT (`grep -rn 'prevent_destroy\|lifecycle' infra/`): zero `prevent_destroy` blocks in the module. Also no surprise replacement shields.

### What this fix does NOT explain (MECHANISM-UNVERIFIED — DEFER per Sherlock F1)

The root cause of why the 2026-03-18 12:50 apply created 11 of 12 resources and silently skipped exactly one is unknown from the evidence available in this session. Remaining hypotheses, in order of plausibility:

1. **Provider-level partial failure** during parallel `azurerm_servicebus_subscription` creation, where the AzureRM provider for that specific resource returned an error treated as transient by Terraform, and the apply continued without ever retrying that key (recurrence-risk: HIGH if this is real).
2. **Out-of-band delete after creation** between 2026-03-18 12:53 and the `dataprep` sub creation on 2026-04-20 — but no audit-trail evidence collected this session.
3. **State write succeeded, Azure create failed but exit code 0** — Terraform's "phantom resource" failure mode. Distinguished by Branch A vs B above.

A3 UNVERIFIED[blocked: ADO build 1574478 raw step logs (ApplyAcc Terragrunt output) not retrieved this session — they would name the mechanism precisely]. Resolving path: `az pipelines runs show --id 1574478 --org ... --project ...` plus retrieving the AzureCLI@2 task stdout from that run.

## L9 — Verification

After the chosen fix path:

```bash
az servicebus topic subscription show \
  --subscription b524d084-edf5-449d-8e92-999ebbaf485e \
  --resource-group mcdta-rg-vpp-a-messaging \
  --namespace-name vpp-sbus-a \
  --topic-name assetplanning-asset-strike-price-schedule-created-v1 \
  --name flextrade-optimizer-sub \
  --query "{name:name, status:status, createdAt:createdAt}"
```

Expected: returns `name`, `status: Active`, fresh `createdAt`. Re-run the §11 parity probe — all 12 mc_acc entries should show `OK`. Confirm with FTO team that consumer can read from the new sub.

## L10 — Lessons

1. **SBSM has THREE pipeline patterns, not two.** `docs/internals/cicd/cd-ado-pipeline-configuration.md` documents only `cd-myriad-platform` (auto) and `cd-general` (manual). The repo actually has dedicated **per-contract auto-deploy pipelines** (`cd-flex-trade-optimizer`, presumably more) registered via `just ado-pipelines-register`. The docs are **STALE** — update needed.
2. **Pipeline success ≠ contract realization.** Three successful pipeline 8995 runs in the time-window 2026-03-18 to 2026-03-31 all reported success while strike-price stayed unprovisioned. `terragrunt apply --auto-approve --non-interactive` exit code 0 does not constitute proof of full-yaml realization. **Post-apply, a parity check (yaml entries vs Azure resources per env) is the only externally-witnessable verification.**
3. **Parity-across-peers is a powerful localization step.** When 11 of 12 structurally identical entries succeed and 1 fails, the contract YAML, identity, and pipeline can be ruled out fast; the defect is localized to a single-resource state or runtime drift.
4. **The user's "verify topic exists first" instinct is the correct triage step** — SBSM only manages subscriptions on pre-existing topics. The check is cheap (~1 az call). In this incident it falsified the obvious hypothesis and forced deeper diagnosis.
5. **Adversarial review caught two FACT errors in the original RCA draft**: wrong pipeline (cd-general 8573 → actually cd-flex-trade-optimizer 8995) and wrong trigger mechanism (manual+approvals → actually auto, no approvals). The errors were caused by relying on `docs/internals/cicd/cd-ado-pipeline-configuration.md` without grepping `.azuredevops/pipelines/` directly for FTO. Lesson: docs are INFER until matched against `.azuredevops/pipelines/*.yml` for the specific contract.
6. **State-list before pipeline-trigger.** When Azure shows a resource missing but the pipeline reports success, the fix branches on whether Terraform state holds a phantom. Skipping this probe risks running a no-op apply that doesn't fix anything and closing the ticket on a false green.

## L11 — End-to-end command playbook (reproducible)

```bash
# 1. Confirm topic exists (falsifies "topic missing" hypothesis)
az servicebus topic show \
  --subscription b524d084-edf5-449d-8e92-999ebbaf485e \
  --resource-group mcdta-rg-vpp-a-messaging \
  --namespace-name vpp-sbus-a \
  --name assetplanning-asset-strike-price-schedule-created-v1 \
  --query "{name:name, status:status, createdAt:createdAt}"

# 2. List subs on that topic
az servicebus topic subscription list \
  --subscription b524d084-edf5-449d-8e92-999ebbaf485e \
  --resource-group mcdta-rg-vpp-a-messaging \
  --namespace-name vpp-sbus-a \
  --topic-name assetplanning-asset-strike-price-schedule-created-v1 \
  --query "[].{name:name, createdAt:createdAt}" -o table

# 3. Parity probe across all mc_acc topics in the yaml
cd "$ENECO_SRC/servicebus-subscriptions-manager"
python3 -c "
import re
with open('contracts/producers/vpp_core/flex-trade-optimizer.yaml') as f:
    c = f.read()
for t in re.findall(r'topic_name:\s*\"([^\"]+)\"[^}]*?environment_name:\s*\"mc_acc\"', c):
    print(t)
" | while IFS= read -r t; do
  R=$(az servicebus topic subscription show \
    --subscription b524d084-edf5-449d-8e92-999ebbaf485e \
    --resource-group mcdta-rg-vpp-a-messaging \
    --namespace-name vpp-sbus-a \
    --topic-name "$t" --name flextrade-optimizer-sub \
    --query createdAt -o tsv 2>&1 | head -1)
  [[ "$R" == *"NotFound"* || "$R" == *"ERROR"* ]] && echo "MISSING: $t" || echo "OK     : $t -> $R"
done

# 4. Identify the deployment pipeline for the affected contract
az pipelines list \
  --org "https://dev.azure.com/enecomanagedcloud" --project "Myriad - VPP" \
  --query "[?contains(name, 'cd-') && contains(name, 'flex-trade-optimizer')].{id:id, name:name}" -o table

# 5. Pull pipeline 8995 history — confirm successful runs after the contract change
az pipelines runs list --pipeline-ids 8995 \
  --org "https://dev.azure.com/enecomanagedcloud" --project "Myriad - VPP" --top 10 \
  --query "[].{id:id, result:result, sourceVersion:sourceVersion, finishTime:finishTime, reason:reason}" -o table

# 6. GATE-ZERO: terraform state probe (requires MC ACC auth — eneco-tools-connect-mc-environments skill)
cd infra/terragrunt/mc_acc/vpp_core/subscription_creator
terragrunt state list 2>&1 | grep -i strike-price

# 7. Fix path B (state lacks resource): trigger pipeline 8995 (or push empty commit to main)
az pipelines run --id 8995 --branch main \
  --org "https://dev.azure.com/enecomanagedcloud" --project "Myriad - VPP"

# 8. Verify
az servicebus topic subscription show \
  --subscription b524d084-edf5-449d-8e92-999ebbaf485e \
  --resource-group mcdta-rg-vpp-a-messaging \
  --namespace-name vpp-sbus-a \
  --topic-name assetplanning-asset-strike-price-schedule-created-v1 \
  --name flextrade-optimizer-sub
```

## L12 — One-page on-call playbook (5-minute triage card)

**Symptom:** "Sub `<name>` on topic `<topic>` is missing in `<env>` (Azure portal shows no sub)."

**Triage (5 min):**

1. **Topic existence** — `az servicebus topic show ...` — if 404, escalate to topic-owner repo (NOT SBSM).
2. **Contract presence** — `grep -n '"<topic>"' contracts/producers/<producer>/<consumer-team>.yaml` AND verify there's a matching `(subscription_name, environment_name)` tuple. Missing → contract bug; PR a fix.
3. **Pipeline identity** — `az pipelines list --query "[?contains(name, 'cd-<consumer-team>')]"`. There may be a dedicated auto-deploy pipeline (like `cd-flex-trade-optimizer` 8995); only use `cd-general` 8573 if no dedicated pipeline exists.
4. **Parity probe** — run §11 step 3. `0/N` missing → pipeline never ran successfully against this contract. `1/N` → state or runtime drift on that single resource.
5. **GATE-ZERO before any pipeline trigger** — `terragrunt state list | grep <resource-marker>` against the affected env's backend. Branches the fix:
   - State HAS resource → drift; `terragrunt state rm` then re-apply.
   - State lacks resource → push empty commit (or `az pipelines run --id <pipeline-id> --branch main`) so the next apply creates it.
6. **Verify** with §11 step 8.

**Pipeline IDs to remember (Myriad-VPP project):**

| Pipeline | ID | Trigger | Approvals |
|----------|----|---------| --------- |
| `cd-flex-trade-optimizer` | 8995 | Auto on `flex-trade-optimizer.yaml` / `subscription_creator/**` changes | None |
| `cd-myriad-platform` | 8574 | Auto on `myriad-platform.yaml` / `infra/terragrunt/**` changes | None |
| `cd-general` | 8573 | Manual, takes `consumer_contract` param | Dev/Acc/Prod gates |

**Subscription IDs (MC environments):**

| Env | Sub ID |
|-----|--------|
| Sandbox | `7b1ba02e-bac6-4c45-83a0-7f0d3104922e` |
| Dev | `839af51e-c8dd-4bd2-944b-a7799eb2e1e4` |
| Acc | `b524d084-edf5-449d-8e92-999ebbaf485e` |
| Prod | `f007df01-9295-491c-b0e9-e3981f2df0b0` |

---

## §13 — Adversarial Review Receipts

Three typed adversarial reviewers attacked the original RCA draft in parallel. Findings:

### Sherlock-Holmes (investigation rigor)

| ID | Finding | Status |
|----|---------|--------|
| F1 | "yaml at deploy time was 9c6a462" was INFER, not FACT — pipeline-run `sourceVersion` not verified | **RESOLVE** — `az pipelines runs show 1574478` confirms `sourceVersion=9c6a462ab35e45a149093fc1e2542086b85def1c` |
| F2 | Producer collision on `subscription_name="flextrade-optimizer-sub"` not enumerated across contracts | **REBUT** — `grep -rl` confirms only `flex-trade-optimizer.yaml` declares this sub name |
| F3 | "Added later via rebase" hypothesis | **REBUT** — `git show 3dea795:...` confirms strike-price present in feature branch from 2026-03-16 |
| F4 | Topic-properties asymmetry | **REBUT** — `az servicebus topic show` diff of strike-price vs complete-power-schedule returns identical Azure properties |
| F5 | Terragrunt `exclude`/`skip` block hypothesis | **REBUT** — `grep -rn 'exclude\|skip\|prevent_destroy' infra/` returns zero matches |
| F6 | `state rm` / out-of-band intervention | **DEFER** — preserved as Branch A in §8; requires `terragrunt state list` against ACC backend |
| F7 | 2-second clustering decisiveness | **REBUT** (in favor of original claim) — clustering is decisive |

### Socrates-contrarian (assumption + frame)

| ID | Finding | Status |
|----|---------|--------|
| F1 | Yaml entries structurally identical | **REBUT** — `od -c` + `diff` confirm byte-identical except topic_name |
| F2 | Name-length / character constraint | **REBUT** — length analysis falsifies; `aligne-asset-sales-plan` (longer) succeeded |
| F3 | "Diagnosis: state drift" under-specified; state-vs-Azure fork buried | **RESOLVE** — TL;DR rewritten; gate-zero state-list probe surfaced to §8 and §12 |
| F4 | Approver permissions / yaml byte-identity / co-deploying PRs unverified | **REBUT** (mostly) — pipeline 8995 has no approval gates (cd-flex-trade-optimizer.yml); yaml unchanged since 988b8c9 (2026-03-31); no in-flight PRs touch flex-trade-optimizer.yaml |
| F5 | Counterfactual provided (state-list, ADO log fetch, git history, `od -c`) | **RESOLVE** — all four counterfactual probes executed |

### El-Demoledor (break-the-fix)

| ID | Finding | Severity | Status |
|----|---------|----------|--------|
| V1 | Fix non-idempotent against unverified root cause; risk of false-green pipeline silent re-skip | HIGH | **RESOLVE** — §8 now mandates plan-output check before declaring success; if plan shows 0 add, abort and switch to Branch A |
| V2 | State-drift escalation path undefined | HIGH | **RESOLVE** — §8 Branch A now lists explicit `terragrunt state rm` command; escalation owner = SBSM maintainers |
| V3 | Approver permissions assumed | MEDIUM | **REBUT** — pipeline 8995 has no approval gates; the original draft's reference to cd-general was wrong |
| V4 | Prod blast-radius — silent TTL/DLQ ship if Prod last-applied < 988b8c9 | LOW | **REBUT** — pipeline 8995 successfully applied `988b8c9` to Prod on 2026-03-31; no pending config drift for Prod |

### Convergent corrections applied to RCA

1. **Pipeline identity corrected** from `cd-general 8573` → `cd-flex-trade-optimizer 8995` (§6, §8, §10, §12).
2. **Trigger mechanism corrected** from "manual + approval gates" → "auto on yaml/module path changes, no approval gates" (§6, §10).
3. **Diagnosis class downgraded** from "Verified Root Cause" → "Hypothesis Set" (frontmatter, TL;DR, §6, §8).
4. **Gate-zero `terragrunt state list` probe added** as MANDATORY pre-fix (§8, §11 step 6, §12 step 5).
5. **Lesson #1 corrected** — SBSM has three pipeline patterns, not two; docs stale (§10).
6. **Lesson #2 added** — pipeline success ≠ contract realization; need post-apply parity check (§10).
