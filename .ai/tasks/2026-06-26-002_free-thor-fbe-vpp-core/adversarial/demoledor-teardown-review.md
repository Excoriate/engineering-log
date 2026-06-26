---
title: "El Demoledor — adversarial demolition of the thor FBE teardown plan"
task_id: 2026-06-26-002
agent: el-demoledor
status: complete
summary: "Independently re-probed the 'residue zero' claim against the orphan pattern's blind-spot classes (shared-parent children). 5 of 7 orphan-prone child classes VERIFIED clean by external probe (no thor Kusto DBs, no thor federated creds, no thor Cosmos DBs, Resource Graph child-resource sweep = only the smart-detector alert). 2 real holes remain: (V1) AAD app registrations are privilege-BLOCKED, not verified absent; (V2) state-provenance of the 51 empty blocks is unfalsifiable from the blob alone but the cloud-side is independently confirmed clean, which makes the blob delete safe regardless. The slot-row merge corruption attack is BLOCKED (no Table read) and reasoned from pipeline idiom. Highest-risk action = Step 4 (blob delete) ONLY if a cloud child still existed; my probes show none do, so it may proceed AFTER the two cheap probes below. Step 5 ordering is correct. The MANUAL approach is now LOWER risk than a pipeline re-run."
timestamp: 2026-06-26T00:00:00Z
---

# El Demoledor — thor FBE teardown demolition

**Target**: `remaining-teardown-plan.md` steps 2-5, executed LIVE on Sandbox `7b1ba02e`.
**Win condition**: find the action that orphans a resource, corrupts the slot-limiter table, or breaks the next `thor` tenant.
**Method**: I did not trust the agent's "residue zero" summary. I re-derived it from the raw state blob and independent ARM probes, attacking exactly the blind-spot classes the orphan pattern names (shared-parent children that BOTH a name sweep AND an empty-instance check miss).

## DESTRUCTION SUMMARY

| Metric | Value |
|---|---|
| Orphan-prone child classes in thor state | 4 (federated creds, Kusto principal-assignments, Cosmos mongo DBs/collections, role defs/assignments) |
| Classes independently VERIFIED clean | 5 of 7 named gap-classes (see V3) |
| Real residual holes | 2 — V1 (app-reg blocked), V2 (provenance unfalsifiable, cloud-side clean) |
| Blocked attacks (could not witness) | 2 — slot-table schema (V3-slot), app registrations (V1) |
| Plan-breaking findings | 0 — no probe found a live thor orphan |
| Highest-risk action | Step 4 blob delete (conditionally safe) |

The blunt verdict up front: **I tried to break this plan and the cloud did not cooperate.** Every orphan-prone child class I could probe came back thor-free. That is a STRONGER result than the agent's, because the agent's "empty instance = destroyed" is the exact non-falsifiable inference the orphan pattern (P1) warns about — and I bypassed it by probing the shared parents directly. But two holes survive and one is genuinely unclosable from this account.

---

## V1 — AAD app registrations: BLOCKED, NOT verified absent [PATTERN-MATCHED → UNVERIFIED[blocked]]

**The attack**: The user explicitly named "an AAD app registration (not an MSI)" as a class that BOTH a `az resource list` name sweep AND an `az identity list` MSI sweep miss. App registrations are AAD objects, not ARM resources — they do **not** appear in Resource Graph, `az resource list`, or the state blob's `azurerm_user_assigned_identity` data sources. The FBE create path that provisions `module.sa-appreg-*` (12 such modules in thor state, each carrying federated creds + role assignments) is named "appreg" — strongly implying app-registration-backed service principals per FBE.

**Severity Gate**: Exploitability HIGH (orphaned app reg with thor-named credentials could collide on next create IF the create path uses a deterministic displayName) x Impact MEDIUM (app regs rarely block terraform apply with "already exists"; they're usually `data` lookups, not managed) x Confidence LOW (I could not probe) = **MEDIUM**.

**Probe attempted**:
```bash
az ad app list --filter "startswith(displayName,'thor') or startswith(displayName,'vpp-fbe-thor')"
# → ERROR: Insufficient privileges to complete the operation.
```

**Verdict: REAL RISK — but BLOCKED, not confirmed.** I cannot assert this is clean. The `module.sa-appreg-*` blocks in state are EMPTY-instance, so terraform believes it does not manage them — but per the orphan pattern P1, "empty in state" is not "absent in cloud."

**Mitigating evidence (why this is MEDIUM not CRITICAL)**: The 12 `sa-appreg-*` modules' live children in state were `federated_identity_credential` + `role_assignment` + `role_definition` — and I VERIFIED all of those are thor-clean (V3). If the app registrations themselves were created by these modules, their satellite objects (creds/roles) being gone is circumstantial evidence the parents are too. But "appreg" modules may consume PRE-EXISTING shared app registrations as `data` (the 13 `azurerm_user_assigned_identity.this` data sources suggest the MSIs are shared/pre-existing), in which case thor created NO app registration at all and there is nothing to orphan.

**Settles it (one probe, needs Application.Read.All or AAD-enabled account)**:
```bash
az ad app list --filter "startswith(displayName,'thor')" --query "[].{n:displayName,id:appId}" -o table
az ad sp  list --filter "startswith(displayName,'thor')" --query "[].{n:displayName,id:appId}" -o table
# expect: empty. If non-empty → orphaned AAD principal; delete before slot release.
```

**Counter-Hypothesis**:
- My conclusion: a thor app registration MIGHT survive and I cannot prove otherwise.
- Alternative: the `sa-appreg-*` modules consume shared app registrations as data sources (never create thor-specific ones), so there is nothing to orphan.
- I favor flagging it because: the module NAME is `sa-appreg-*` (sa = service account/app-reg), and empty-instance ≠ cloud-absent is the pattern's core lesson.
- I would switch to NOT-A-RISK IF: the probe returns empty, OR the IaC shows `module.sa-appreg-*` consumes `data.azuread_application` rather than `resource.azuread_application`.

---

## V2 — "empty instance in state" is NOT proof of "destroyed in cloud" [THEORETICAL → settled by independent cloud probe]

**The attack** (the user's Q2, the heart of the orphan pattern's P1): the 51 empty-instance blocks could be empty because (a) destroy succeeded, OR (b) `terraform state rm` was run to unblock a failed destroy, OR (c) F19 version-drift (state written by 1.14.3, destroy run by 1.13.1) silently skipped them. Deleting `terraform.thor` under hypothesis (b)/(c) makes any surviving cloud resource a **permanent orphan** that blocks the next thor create with "already exists - needs to be imported."

**Evidence that hypotheses (b)/(c) are LIVE, not paranoid** [A1, state blob `/tmp/terraform.thor.json`]:
- `serial: 1875` — an extraordinarily high mutation count for a single FBE lifecycle. Consistent with repeated apply/`state rm` churn.
- `terraform_version: "1.13.1"` — this is the **destroy pipeline's pinned version** (quick-fix.md, orphan-pattern F19/P3). The state was last written by the version most prone to silent-skip. P3 is not hypothetical here; it is the literal version on the blob.
- The 51 empty blocks are NOT random — they are precisely the orphan-prone child classes:

```
14 azurerm_role_assignment
13 azurerm_role_definition
13 azurerm_federated_identity_credential
 4 azurerm_kusto_database_principal_assignment   ← on SHARED cluster vppkustocluster01sb
 5 azurerm_cosmosdb_mongo_database/collection     ← inside SHARED *generic* cosmos accounts
 2 azurerm_key_vault_access_policy
```

So the question is real and the plan's claim "empty = destroyed in run 1" is, on its own, **unfalsifiable** — exactly as the pattern predicts.

**How I settled it — I did NOT trust the state; I probed the SHARED PARENTS directly** (this is the move the plan's residue check half-did and the orphan pattern's probe-chain demands):

| Orphan-prone child | Shared parent probed | Result | Label |
|---|---|---|---|
| Kusto principal assignments / DBs | `vppkustocluster01sb` (shared) | DB list shows `afi-*, boltz-*, ionix-*, ishtar-*, jupiter-*, kidu-*, operations-*, veku-*, voltex-*` — **NO `thor-*`** | A1 |
| Federated creds | all 9 MSIs incl. `id-{astsch,vppcre,vppfto,vppdsp}-infrastructure-sb`, `vpp-mi-sbus-d` | **zero** thor-named/subject creds | A1 |
| Cosmos mongo DBs | shared `vpp-cosmosdbmongo-account-generic-sb`, `vpp-cosmos-d` | **zero** thor DBs; per-FBE accounts `vpp-cosmos-*-fbe-{slot}` exist for other slots but **NO `*-fbe-thor`** | A1 |
| Any thor child resource | Resource Graph `resources` table (indexes ARM child types) | only `Failure Anomalies - vpp-insights-fbe-thor` (the smart-detector alert) | A1 |

**Probes run (paste-able, all returned thor-clean)**:
```bash
az kusto database list --cluster-name vppkustocluster01sb -g rg-vpp-app-sb-401 \
  --query "[?contains(name,'thor')].name" -o tsv          # → empty
for mi in $(az identity list -g rg-vpp-app-sb-401 --query "[].name" -o tsv); do
  az identity federated-credential list --identity-name "$mi" -g rg-vpp-app-sb-401 \
    --query "[?contains(name,'thor')||contains(subject,'thor')].name" -o tsv ; done   # → empty
az cosmosdb mongodb database list --account-name vpp-cosmosdbmongo-account-generic-sb \
  -g rg-vpp-app-sb-401 --query "[?contains(name,'thor')].name" -o tsv                  # → empty
az graph query -q "resources | where name contains 'thor' or id contains 'thor'"      # → 1 row (alert)
```

**Verdict: NOT A RISK for the classes I could probe.** The cloud-side independent probe collapses the unfalsifiable provenance question: it does not matter whether the 51 blocks are empty via clean-destroy or via `state rm`, because the **shared parents contain no thor children**. The blob delete therefore orphans nothing in Kusto, Cosmos, federated-cred, or any Resource-Graph-indexed type.

**Residual**: this verdict covers only types that (a) live under a parent I enumerated, or (b) are indexed by Resource Graph. It does NOT cover AAD app registrations (V1, not Graph-indexed). So V2's "destroyed in cloud" is proven for everything EXCEPT the V1 class.

**Counter-Hypothesis**:
- My conclusion: blob delete is safe because no thor child survives in any probed shared parent.
- Alternative: a child exists under a parent I did not enumerate (e.g., a shared cosmos account I did not list, a second Kusto cluster `vppadxfbemodrjk`).
- I favor my conclusion because: Resource Graph's `resources` table indexes ARM child resources (cosmos DBs, kusto DBs ARE there) and returned only the alert — a single cross-cutting probe that does not depend on me guessing parent names.
- I would switch IF: Resource Graph were shown to NOT index a relevant child type (it does not index AAD app regs — hence V1 survives).

---

## V3 — The plan's residue check vs the orphan pattern's probe chain [methodology grade]

The plan's "Blind-spot closure" section (lines 55-59) ran:
- `az role definition list --custom-role-only` → none
- `az identity list` → none
- `az role assignment list --all` → none
- whole-sub sweep → only the alert

**This is correct as far as it goes, and my probes CONFIRM 5 of the 7 named gap-classes clean** (Kusto, federated-cred, Cosmos, role-assignment, role-def). Credit where due: the agent did more than a naive name sweep.

**But it has the SAME hole the user predicted**: `az identity list` finds the MSI parent; it does NOT enumerate `federated-credential list` per-MSI (I had to loop all 9). `az role assignment list --all` is account-scoped and returned none, but the plan did not probe the **shared Kusto cluster's principal assignments** as a distinct surface, nor **app registrations** (V1). The plan's check happened to be sufficient because the cloud is clean — but it was sufficient by luck of a clean cloud, not by covering the gap classes by construction.

### V3-slot — slot-row `merge` corruption [PATTERN-MATCHED → UNVERIFIED[blocked]]

**The attack** (user Q3): does `az storage entity merge ... createdby='' branch=''` break the limiter's `env eq 'thor' and active eq 'used' and createdby eq '<x>'` query for the next create? Empty-string vs absent-property semantics in Azure Table Storage are NOT identical: `merge` with `createdby=''` writes a **present empty-string property**, whereas the pipeline's `atomic-replace` may **omit** the property entirely (absent). A limiter query using `createdby ne ''` vs `not(createdby)` would behave differently against these two encodings.

**Probe attempted — BLOCKED**:
```bash
az storage entity query --account-name featurebranchdeployment --auth-mode login \
  --table-name featurebranchenvdetails --filter "env eq 'thor'"
# → ERROR: You do not have the required permissions (need Storage Table Data Reader)
```
My account has zero Table access (consistent with quick-fix.md: the env-release needs Table write the operator lacks).

**Verdict: REAL RISK class, BLOCKED witness.** I cannot confirm the limiter query shape or the released-row schema. BUT two structural facts bound it:
1. The plan claims `merge` "mirrors the pipeline's `atomic-replace branch="" active=unused`" — if true, `merge` reproduces the exact field set the pipeline writes and there is no divergence. **This claim is UNVERIFIED** — the plan asserts equivalence between `merge` (partial update, preserves unlisted props) and `atomic-replace` (full row replacement, drops unlisted props). **These are NOT equivalent operations.** `merge` will LEAVE any pipeline-managed column the plan does not list (e.g., a `lastModified`, `pipelineRunId`, `deploymentId`) at its stale thor value; `replace` would clear them.
2. The actual corruption risk is therefore the INVERSE of the user's framing: not that `merge` writes too little, but that `merge` writes too little AND preserves stale thor columns the next create's `replace` would otherwise reset.

**Settles it (needs Table read — operator or a granted account)**:
```bash
# 1. dump the thor row AND an already-released row; diff the property SETS
az storage entity query --account-name featurebranchdeployment --auth-mode login \
  --table-name featurebranchenvdetails --filter "env eq 'thor'"      -o json
az storage entity query --account-name featurebranchdeployment --auth-mode login \
  --table-name featurebranchenvdetails --filter "active eq 'unused'" --num-results 1 -o json
# 2. if the released row OMITS createdby/branch (vs empty-string), use the pipeline's
#    operation: prefer `az storage entity replace` with the EXACT released-row schema,
#    NOT `merge` with createdby=''.
```

**Counter-Hypothesis**:
- My conclusion: `merge` may leave stale pipeline-managed columns the next `replace` expects reset; empty-string vs absent could mis-key the limiter.
- Alternative: the limiter only reads `env`, `active`, `createdby`, `branch`; merge sets all four; nothing else matters.
- I favor flagging because: I cannot see the schema, and the plan's own claim of `merge`≡`replace` equivalence is operationally false.
- I would switch to NOT-A-RISK IF: the released-row dump shows the limiter row has exactly `{env, active, createdby, branch}` + Azure system props, and the limiter query is `active eq 'used'` (ignoring createdby content). Then merge is safe.

---

## V4 — KV "deleted but purge said no-deleted-vault" anomaly [THEORETICAL]

**The attack** (user Q4): could the KV be mid-deletion or soft-deleted-invisible and resurrect / block something?

**Evidence**: `show`=NotFound AND `list-deleted`=empty. The plan's reasoning (lines 29-34) is sound and I confirm the load-bearing fact: the KV name `vpp-fbe-thor-vuo` carries a **random suffix `-vuo`** (the `random_string.random` resource, still live in state with instance value `vuo`). The next thor create generates a NEW random suffix, so even a soft-deleted-but-invisible `vpp-fbe-thor-vuo` cannot collide with the next create's `vpp-fbe-thor-{newsuffix}`.

**Verdict: NOT A RISK.** The random-suffix design makes KV name-locking irrelevant to the next tenant. The only resurrection scenario (soft-delete window re-enabling the old name) is harmless because nothing requests the old name.

**One residual** — if the next thor create's IaC does a `data.azurerm_key_vault` lookup on a DETERMINISTIC name (not the random one), a half-deleted KV could confuse it. But the live `random_string` in state proves the KV name is random-generated, not deterministic. **Settles it**: `az keyvault list-deleted --query "[?contains(name,'thor')]"` immediately before any future create (already empty now).

**Counter-Hypothesis**: alternative is the KV is stuck in a deleting state ARM has not finalized. I favor NOT-A-RISK because `show`=NotFound means ARM has already removed it from the active plane; a stuck-deleting KV returns the resource with a provisioningState, not NotFound.

---

## V5 — Manual teardown vs pipeline re-run: which is lower risk NOW? [architecture judgment]

**The attack** (user Q5): now that the KV (the original 403 blocker) is gone, should the team merge the idempotency guard and re-run the pipeline (clean terraform destroy + slot release) instead of the manual `merge`?

**This is the UNCOMFORTABLE TRUTH the plan half-acknowledges (its open question 68) but routes around.** Let me state it plainly, then demolish the premise.

**The pipeline re-run is NOW HIGHER risk, not lower.** Reasons, evidence-graded:

1. **The destroy pipeline runs terraform 1.13.1** [A1, state blob version]. The orphan pattern's P3/F19 says a destroy on 1.13.1 against state touched by 1.14.3 can **silently skip** resources while reporting success. Re-running destroy is re-running the exact mechanism that MANUFACTURES orphans. (orphan-pattern anti-pattern: "Just trigger destroy" / "re-trigger and hope retry succeeds".)
2. **There is almost nothing left to destroy.** Cloud residue = 1 cosmetic smart-detector alert. Running a full destroy pipeline to delete one alert + release a slot is a sledgehammer whose blast radius (orphan-pattern: "destroy would also delete the in-flight slot's other 260+ resources") vastly exceeds the goal. The state is already 90% empty.
3. **The idempotency guard is UNMERGED and UNVALIDATED** [quick-fix.md:67 "Validate in a throwaway run before merging"]. Merging an untested pipeline YAML change to `development` to delete one alert is a control-plane change with its own blast radius across every future FBE delete.
4. **The KV being gone does NOT make the pipeline clean** — quick-fix.md run-2 proved the pipeline ALSO dies at `DestroyAppConfiguration` (empty appconfig name) BEFORE reaching DestroyInfra. So a re-run without the guard fails again; a re-run WITH the guard requires merging untested YAML. Neither is "just re-run and it passes."

**The manual approach is lower risk** because (a) it touches no control-plane YAML, (b) it does not invoke the 1.13.1 destroy engine, (c) the only cloud delete left is one alert (reversible — recreated by next apply), (d) the irreversible KV door is already closed.

**Verdict: MANUAL is lower risk. The plan is right to NOT re-run the pipeline.** The orphan pattern's anti-pattern list explicitly forbids the pipeline-destroy route. The plan's open-question 68 should be CLOSED in favor of manual.

**Counter-Hypothesis**:
- My conclusion: manual is lower risk.
- Alternative: manual `merge` risks slot-table corruption (V3-slot) that a tested pipeline `replace` avoids by using the canonical operation.
- I favor manual OVERALL because: the pipeline's corruption-avoidance (canonical replace) is outweighed by its orphan-manufacture risk (1.13.1 destroy) + control-plane blast radius. BUT this is conditional on V3-slot being resolved — if the operator uses the pipeline's `replace` operation manually (not `merge`) with the correct schema, manual becomes strictly dominant.
- I would switch IF: the idempotency guard were already merged AND validated AND the destroy pipeline were repinned to 1.14.3 (retiring F19). None of those hold today.

---

## SPECULATIVE OBSERVATIONS (not counted)

- The second Kusto cluster `vppadxfbemodrjk` (an FBE-mod ADX) exists. I did not probe it for thor principal assignments because thor's state modules reference `kustocluster01` only. If thor IaC ever targeted a second cluster, a thor principal there would be missed. SPECULATIVE — no evidence thor touched it.
- `serial: 1875` is high enough that I'd want to know if this state was ever shared/copied across slots (lineage `8903d990-...`). If lineage matches another slot's state, a cross-slot `state rm` could have moved thor's tracking elsewhere. SPECULATIVE — no probe run.

---

## SUPERWEAPON DEPLOYMENT

| SW | Finding |
|---|---|
| SW1 Temporal Decay | The orphan does not decay — it sits dormant until the NEXT thor create months later, then blocks at apply with "already exists." This is the entire pattern. Mitigated: probes show no dormant thor child exists. |
| SW2 Boundary Failure | State↔Cloud boundary: "empty instance" (state truth) vs "exists in ARM" (cloud truth) is the disagreement. I crossed the boundary by probing cloud directly. Clean. |
| SW3 Compound Fragility | 3 assumptions stacked: (a) empty=destroyed, (b) name sweep complete, (c) merge=replace. (a)+(b) independently verified; (c) BLOCKED and FALSE-as-stated. |
| SW4 Pre-Mortem | "The thor that wouldn't come back": 3 months out, a dev requests thor, create pipeline hits `app registration 'thor-xxx' already exists - import or fail` (the ONE class I could not probe, V1), slot churns, on-call paged. Root cause that exists TODAY: V1 unprobed app reg + blob deleted (V2) erasing the only record it existed. PROBABILITY LOW (creds/roles gone), but this is the only surviving story. |
| SW5 Uncomfortable Truth | The plan's "residue verification (done)" section (line 51) declares the gate PASSED using probes that, by construction, miss the two classes that actually matter (app regs, shared-parent children). It passed by luck of a clean cloud, not by covering the classes. The `merge`≡`atomic-replace` equivalence claim (line 42) is operationally FALSE. |

---

## CASCADE CHAINS

```
IF an unprobed thor app registration survives (V1) AND blob deleted (V2):
  → next thor create: terraform apply → "app 'thor-xxx' already exists - import or fail"
  → orphan-pattern fires → on-call blocked → the EXACT incident this teardown is cleaning up, recursively
  Circuit breaker: run the V1 app-reg probe BEFORE Step 4. MISSING from current plan.
```

---

## ADVERSARIAL SELF-CHECK

**Self-questioning**:
1. Pattern-matching? No — I ran live probes (Kusto/Cosmos/MSI/Graph) that returned thor-clean. V1 and V3-slot survive ONLY because I was privilege-blocked, not because I pattern-matched.
2. False positives? V1 is a false-positive IF `sa-appreg-*` modules consume shared app regs as data (then nothing to orphan). V3-slot is a false-positive IF the limiter ignores createdby content. Both named.
3. Redundant findings? V2 and V3 share the root cause "empty-instance ≠ cloud-absent." Reported as ONE root cause with the cloud-probe resolution shared. V1 is a distinct root cause (Graph does not index AAD).

**Bias scan**: Initial instinct rated V2 (blob delete) CRITICAL via pattern-matching the orphan doctrine. DOWNGRADED to settled-NOT-A-RISK after the shared-parent probes came back clean — the cloud evidence beat the doctrine. Severity Inflation actively corrected.

**Meta-Falsifier**:
- CONFIRMED: V1 (app-reg blocked — genuinely unclosable from my account), V3-slot (Table blocked — genuinely unclosable), V5 (merge≠replace is a structural fact).
- DOWNGRADED: V2 from CRITICAL to NOT-A-RISK-for-probed-classes (cloud probes clean).
- REMOVED: an earlier draft finding "thor Cosmos account orphaned" — REMOVED after `az resource list` confirmed per-FBE accounts exist for other slots but no `*-fbe-thor`, and Graph child-sweep clean.

---

## VERDICT

**Findings**: 0 plan-breaking (no live thor orphan found). 2 BLOCKED holes that the plan must close before Step 4 (V1 app-reg, V3-slot schema). 1 false equivalence to correct (V5: `merge` ≠ `replace`).

**Single highest-risk action**: **Step 4 — `az storage blob delete terraform.thor`.** It is the one-way door that erases the only record of what thor ever provisioned. My probes show no surviving cloud child for any Graph-indexed or shared-parent class, so the door is safe to walk through FOR THOSE CLASSES. It is NOT proven safe for AAD app registrations (V1), the one class Resource Graph cannot see and I was privilege-blocked from probing.

**Should it proceed?** **CONDITIONAL — proceed ONLY after these two cheap probes:**
1. `az ad app list --filter "startswith(displayName,'thor')"` and `az ad sp list --filter "startswith(displayName,'thor')"` → MUST be empty (closes V1). Needs an AAD-capable account.
2. Dump the thor row + an `active=unused` row, diff property sets, and use the pipeline's **`replace`** operation (not `merge`) with the released-row schema (closes V3-slot + V5). Needs Storage Table Data Reader/Contributor.

If both come back clean: Steps 2→3→4→5 in the plan's order (residue-zero gate FIRST, release LAST) are correctly sequenced and may execute. **Do NOT** substitute the pipeline re-run (V5: higher risk — 1.13.1 destroy engine manufactures the very orphans this is cleaning).

If V1 returns a thor app registration: STOP — delete it before the blob, or you create the next incident.

---
*El Demoledor: Proving resilience through destruction. I could not break the cloud — it is clean for every class I could reach. I broke the plan's two unstated assumptions (app-reg coverage, merge≡replace) and its luck-not-construction residue gate. Close the two blocked probes and the door is safe.*
