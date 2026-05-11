---
task_id: 2026-05-11-001
agent: el-demoledor
status: complete
summary: Fix is empirically safe to execute (no cross-FBE blast radius found), but the polling loop in Step 4 silently masks auth/network failures and the doc misses two genuine state-recreate hazards in the rerun
verdict: conditional
verdict_detail: PROCEED-WITH-CHANGES — apply C1/C2/C3 patches before execution
---

# Adversarial Review — el-demoledor

> The fix is good. The diagnosis is mostly right. The most exploitable defect is the bash polling loop in `fix.md` Step 4: it cannot distinguish "Azure said the namespace is gone" from "I lost auth mid-poll" or "I typo'd the RG name", and it will print "Namespace deletion confirmed" in both cases. The downstream pipeline rerun then races a still-present namespace and fails identically to today's incident. Three patches are mandatory before execution; four other findings are worth patching before the **next** F2 incident.

## Scope and method

Read in this session (all paths absolute):
- `/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/.ai/tasks/2026-05-11-001_fbe-error-duncan/output/rca.md`
- `/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/.ai/tasks/2026-05-11-001_fbe-error-duncan/output/fix.md`
- `/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/.ai/tasks/2026-05-11-001_fbe-error-duncan/context/evidence-ledger.md`
- `/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/.ai/tasks/2026-05-11-001_fbe-error-duncan/01-task-requirements-final.md`
- `/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/.ai/tasks/2026-05-11-001_fbe-error-duncan/proofs/outputs/probe-{01,02,03,04,10}*`
- `/Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src/enecomanagedcloud/myriad-vpp/VPP - Infrastructure/terraform/fbe/event-hub.premium.tf`
- `/Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src/enecomanagedcloud/myriad-vpp/VPP - Infrastructure/terraform/fbe/event-hub.tf`
- `/Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src/enecomanagedcloud/myriad-vpp/VPP - Infrastructure/terraform/fbe/provider.tf`
- `/Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src/enecomanagedcloud/myriad-vpp/Myriad%20-%20VPP/development/azure-pipelines-featurebr-env.yml` (lines 370-470)
- `/Users/alextorresruiz/Documents/obsidian/2-areas/work-eneco/eneco-vpp-platform/fbe/fbe-failure-modes-catalog.md`

Live Azure probes executed (read-only, Sandbox `7b1ba02e-bac6-4c45-83a0-7f0d3104922e`):

- `az eventhubs namespace show / eventhub list / network-rule-set list / authorization-rule list / georecovery-alias list` against the orphan
- `az role assignment list --scope <orphan-id>` and `--assignee <kusto-cluster-identity>`
- `az network private-endpoint list` filtered to references
- `az eventgrid event-subscription list --source-resource-id <orphan-id>`
- `az keyvault secret list` against `vpp-fbe-kidu-xsk`
- `az kusto data-connection list` across all four `kidu-*` Kusto databases
- `az resource list` filtered to `vpp-evh-premium-kidu` ID and `kidu` name
- `az storage entity query --table-name featurebranchenvdetails` (with storage key auth — see correction below)
- `az logic workflow show` definitions for FBE Logic Apps
- `az eventhubs namespace list` cross-slot orphan inventory
- `az storage account show` + `az storage container list` against `vppevhpremiumkidu`
- Pipeline-YAML diff across all 9 worktrees

Evidence grades follow the four-tier scheme: **EXPLOIT-VERIFIED** | **PATTERN-MATCHED** | **THEORETICAL** | **SPECULATIVE**.

## What the fix gets right (load-bearing claims that survived attack)

Stating these explicitly so the reader knows where my attacks could not break the doc:

1. **The orphan `vpp-evh-premium-kidu` is real, empty, and structurally unreferenced** (EXPLOIT-VERIFIED): `eventhub list` returns `[]`; `network-rule-set list` shows `defaultAction: Allow` with no IP rules; `authorization-rule list` shows only the auto-created `RootManageSharedAccessKey` (Azure default); `georecovery-alias list` empty; `event-subscription list` empty; `role assignment list --scope <orphan>` returns `[]`; no Logic App / AppConfig / Web App / Private Endpoint references the resource ID; no KV in this RG contains a secret with the orphan in its NAME. The cross-cutting blast radius the user asked me to find **does not exist** for this orphan. Deletion is safe at the Azure-resource level.

2. **No Kusto data connection references the orphan** (EXPLOIT-VERIFIED): explicitly probed all four `kidu-*` Kusto databases on `vppkustocluster01sb` — each returns zero data connections. The shared Kusto cluster has zero attack surface here. Also the cluster's managed identity (`d3b4400e-9fa1-4264-849c-a1ad12000c68`) has **zero** role assignments scoped to anything containing `kidu` — the IaC-declared `Azure Event Hubs Data Receiver` assignment on premium event hubs (`event-hub.premium.tf:138-150`) was never created in the failed apply.

3. **Other Premium namespaces on other slots are properly tracked** (PATTERN-MATCHED): the cross-slot orphan inventory shows premium namespaces for `ionix`, `voltex`, `jupiter`, `ishtar`, `veku`, `afi`, `thor`, `operations`, `mod`, `sbx`. All belong to active slots (per the lease table — see correction in Finding L1) or to the sandbox plane. **One suspicious entry — `vpp-evh-premium-mod` (created 2025-11-10)** — does not match any active lease row but is out of this task's scope.

4. **Duncan's lease IS held** (EXPLOIT-VERIFIED, but RCA's evidence-ledger row C13/P-LEASE-TABLE under-classified this as A3 UNVERIFIED): the lease table `featurebranchenvdetails` (storage `featurebranchdeployment`, RG `rg-vpp-app-sb-401`) row `PartitionKey="10", RowKey="10"` shows `env=kidu, active=used, branch=fbe-821600-date-selector-flex-reservation-dashboard, createdby=Duncan.Teegelaar@eneco.com, queue=com-eneco-eet-vpp-streamcopy-dev10, Timestamp=2026-05-11T06:52:35Z`. Partition keys are 1..11 (row indices), not slot names — that's why the RCA's filter approach failed. Storage account key auth via `az storage account keys list --account-name featurebranchdeployment` succeeded; if the on-call also has subscription-Contributor, the lease table is queryable. **9/10 active leases used right now; `boltz` is the only unused slot.**

5. **Pipeline 2412 YAML is consistent across all 9 local worktrees** (EXPLOIT-VERIFIED): `diff -q development $WT` returns nothing for hotfix, pr-review1, pr-review2, ops-scratchpad, ops-boyscout, backlog-prio1, backlog-prio2, backlog-prio3. Duncan's `feature/fbe-821600-*` branch will see the same `azure-pipelines-featurebr-env.yml` as the RCA describes. **The pipeline-yaml drift attack surface is empty.**

6. **State backend key is correct** (EXPLOIT-VERIFIED): `azure-pipelines-featurebr-env.yml:387` writes `key = "terraform.$(featurebranchname)"` — PowerShell sub-expression syntax. State blob `terraform.kidu` exists, 1.15 MB, modified `2026-05-11T08:04:27Z`. The misleading obsolete `azurepipelines-fbe.yaml` typo bug correctly excluded by the RCA.

7. **Storage account `vppevhpremiumkidu` is correctly in state with matching Azure ID** (EXPLOIT-VERIFIED): state instance id matches Azure id byte-for-byte; rerun will see no-op on this resource; the blob containers expected by the `module.eventhub_namespace_premium_eventhubs_consumer_groups_storage_containers` module are empty in Azure today (no orphan containers competing).

8. **No purge / soft-delete trap for Event Hub Premium**: Event Hub Premium does **not** have a soft-delete feature (unlike Key Vault / SQL / Storage). Once deleted, the namespace is gone with no recovery window blocking immediate recreate. `provider.tf` `purge_soft_delete_on_destroy = false` for app_configuration and key_vault is irrelevant to EH.

## CRITICAL breaks (production-blocking; must fix before any execution)

### C1 — Polling loop terminates on auth/network failure, not just on success

**Evidence grade**: EXPLOIT-VERIFIED.

**Location**: `output/fix.md:119-143` (Step 4 polling loop).

**The exploit**: The loop is `until ! az eventhubs namespace show ... >/dev/null 2>&1`. This terminates the moment `az` returns ANY non-zero exit code. Exit codes I measured live in this session:

| Cause | Exit code | Loop reaction |
|---|---|---|
| ResourceNotFound (success — what we want) | **3** | terminate, print "deletion confirmed" |
| Invalid subscription | **1** | terminate, print "deletion confirmed" (wrong!) |
| Invalid resource group | **1** | terminate, print "deletion confirmed" (wrong!) |
| Expired auth token (CLI session refresh failure) | non-zero | terminate, print "deletion confirmed" (wrong!) |
| Transient throttle 429 / Azure backend 5xx | non-zero (varies) | terminate, print "deletion confirmed" (wrong!) |

The final `grep -i "not found"` on line 142 is the only safety net — but it runs AFTER the loop has already printed `Namespace deletion confirmed at elapsed=${ELAPSED}s` and after the polling control has handed back to the operator. A human reading the terminal scrollback will see the green "confirmed" message and proceed to Step 5; the trailing `grep` returns 1 on non-match but the user (or an AI agent following the doc) sees the "deletion confirmed" line above and acts.

**Blast radius**: If the orphan is **still present** at the moment the operator advances to Step 5 (because Step 4 returned false-positive on auth refresh), the pipeline rerun fails with the **identical** "already exists" error — the same incident, an hour later. Worse: if the user's az session is broken at this point and they trigger Step 5 via ADO UI (which uses the SC's federated identity, not the user's), the pipeline ITSELF will discover the orphan and fail. The on-call now believes the deletion did stick (because the doc said so) and starts hunting for "second-order race" — wrong diagnosis path. ~60 minutes of incident time lost.

**Counter-hypothesis**: The only way this is safe is if the on-call's Azure CLI session is rock-stable for the entire 1-15 min polling window AND no transient ARM error occurs AND no `az account set` race happens in another shell. The session token expiry is typically 60-90 min, but federated tokens via `az login --service-principal --federated-token` (the path on-call typically uses when they got the token from an ADO build) refresh on demand. I cannot rule out a 401 mid-poll.

**Reproduction**: in a separate terminal, after starting the loop, run `az account clear` — the loop terminates immediately with "deletion confirmed" while the namespace is fully present in Azure.

**Patch** (replace `output/fix.md:119-143`):

```bash
# Polling loop — distinguishes ResourceNotFound (exit 3) from auth/transient errors
TIMEOUT_S=$((15 * 60))
ELAPSED=0
DELETED=0
while [ "$ELAPSED" -lt "$TIMEOUT_S" ]; do
  # Capture stderr to distinguish 404 from auth/transient
  ERR=$(az eventhubs namespace show \
          --name vpp-evh-premium-kidu \
          --resource-group rg-vpp-app-sb-401 \
          -o none 2>&1 >/dev/null)
  RC=$?
  if [ "$RC" -eq 0 ]; then
    # Still present
    printf "."
    sleep 15
    ELAPSED=$((ELAPSED + 15))
    continue
  fi
  # Non-zero — distinguish ResourceNotFound from other errors
  case "$ERR" in
    *"not found"*|*"ResourceNotFound"*|*"could not be found"*)
      DELETED=1
      echo
      echo "OK: namespace confirmed gone (ResourceNotFound) at elapsed=${ELAPSED}s"
      break
      ;;
    *)
      echo
      echo "ABORT: az error that is NOT 'not found' — refusing to claim deletion succeeded"
      echo "       Exit code: $RC"
      echo "       Error:    $ERR"
      echo "       Likely causes: expired auth, wrong RG, ARM throttle. Re-auth and re-run Step 4."
      exit 1
      ;;
  esac
done

if [ "$DELETED" -ne 1 ]; then
  echo "TIMEOUT: namespace still present after ${TIMEOUT_S}s — DO NOT proceed; escalate."
  exit 1
fi
```

This refuses to claim success on any error that doesn't pattern-match "ResourceNotFound" — converts the silent-success class into an explicit halt.

**Counter-hypothesis I considered**: maybe the on-call will visually verify by re-running `az eventhubs namespace show` manually after the loop. That is an *assumption* about operator behaviour, not a guarantee of doc safety. The current doc explicitly tells them the loop's output IS the confirmation.

---

### C2 — Step 5 pipeline rerun has a state-recreate hazard around the orphan's downstream KV secret

**Evidence grade**: PATTERN-MATCHED (theoretical reachability depends on `keyvaultsecret` module's idempotency behaviour, which is not directly observable from the data I have).

**Location**: state has `module.keyvault_secret_eventhub_namespace_premium_storage_account_primary_connection_string` (`probe-04-state-summary.json:42`); IaC `event-hub.premium.tf:21-29` ALSO declares `module.keyvault_secret_eventhub_namespace_premium_primary_connection_string` (the *namespace* CS, not the storage-account CS); the namespace CS secret is **NOT in state and NOT in the KV** (live probe: `az keyvault secret list --vault-name vpp-fbe-kidu-xsk | grep eventhub-premium` returns only the storage-account variant).

**The exploit**: when the pipeline rerun executes, terraform will compute the new module graph:

1. `module.eventhub_namespace_premium` — new resource → CREATE (the namespace itself). Depends on nothing in state.
2. `module.keyvault_secret_eventhub_namespace_premium_primary_connection_string` — new resource → CREATE. The IaC at `event-hub.premium.tf:25` sets `key_vault_secret_value = module.eventhub_namespace_premium.eventhub_namespace_default_primary_connection_string`. The connection string is derived from the namespace `RootManageSharedAccessKey` rule. The CURRENT Azure orphan has this rule (verified). The NEW recreated namespace will get a freshly-generated key. **If the deletion in Step 3 fails partway (Azure async-delete starts but then errors), the orphan might still exist when terraform reaches the namespace CREATE step** — same failure as today. The KV secret CREATE would then also fail.
3. `module.eventhub_namespace_premium_storageaccount` — already in state → no-op (instance_id matches Azure).
4. `module.keyvault_secret_eventhub_namespace_premium_storage_account_primary_connection_string` — already in state. **BUT**: this secret's value depends on `module.eventhub_namespace_premium_storageaccount.primary_connection_string`. If the storage account's keys are unchanged (typical), this is no-op. If terraform decides to refresh and the key rotates, the secret gets updated. Low risk.

The hazard: **if the orphan re-emerges between Step 4 (poll confirms delete) and Step 5 (pipeline runs apply), terraform attempts CREATE on the namespace and fails identically.** Azure's async delete can complete on the control plane and then a soft-state cache somewhere can re-surface the resource view for a brief window. This is documented behaviour for some Azure resource types (notably Service Bus and Event Hub Premium under high regional load).

**Counter-hypothesis**: the EH Premium delete is synchronous-at-the-DB once initiated. Once `az` returns ResourceNotFound, the resource is gone everywhere. I cannot prove this is always true; Microsoft documents "deletion is asynchronous and the resource is removed from the control plane within minutes" — the "within minutes" wording is the hedge.

**Blast radius**: pipeline fails same way → confusion + same 60-min triage. Identical to C1 outcome but via different mechanism.

**Patch** (add to `output/fix.md` AFTER Step 4, BEFORE Step 5):

```markdown
## Step 4.5 — Pre-pipeline sanity probe (mandatory before triggering Step 5)

**Question this step answers**: "Is the namespace REALLY gone right before we let the pipeline race against Azure?"

**Why**: Step 4's loop confirms deletion at one point in time. ARM caches can occasionally re-surface a resource view briefly. Run this one-liner immediately before triggering the pipeline:

```bash
az eventhubs namespace show \
  --name vpp-evh-premium-kidu \
  --resource-group rg-vpp-app-sb-401 \
  -o none 2>&1 | grep -qi "not found" \
  && echo "OK proceed" \
  || { echo "STOP: namespace re-surfaced or another error — re-run Step 4 polling"; exit 1; }
```

If this prints `OK proceed`, you can run Step 5 within the next ~60 seconds with confidence. If the namespace re-surfaces after that, abort.
```

---

### C3 — Step 5 lacks a precondition check for state lock and concurrent pipeline runs

**Evidence grade**: PATTERN-MATCHED (race condition class, not specific to today's incident).

**Location**: `output/fix.md:145-181` (Step 5) does not check that the Terraform state blob is not currently leased by another pipeline run.

**The exploit**: between Duncan's first failed apply (which finished `2026-05-11T08:04:27Z` per blob lastModified) and the rerun, **another pipeline run could be triggered against `terraform.kidu`** — for example:
- The destroy pipeline (2629) is run by Fabrizio for an emergency reset (the doc's Rollback section actually *suggests* running 2629).
- Another developer is told the FBE is broken, runs Pipeline 2412 against their own branch hoping to claim the slot. If they're racing for the same lease, F16 (limiter race) may also fire, allocating them to a different slot — but if they get `kidu` (unlikely but possible), two pipelines compete for the state blob.
- The autodelete-trigger Logic App fires (`vpp-fbe-autodelete-trigger` exists in the RG and is one of the F5 catalog items — autoeviction at 4 days of stale Timestamp). Duncan's lease Timestamp `2026-05-11T06:52:35Z` is fresh, so autodelete won't fire today, but if the rerun is delayed >4 days...

Azure Blob lease for terraform state IS bounded (typically 1 hour with auto-renew), so if a prior pipeline died mid-apply the lease will expire. But Duncan's first apply terminated normally (not via SIGKILL — terraform returned exit 1 cleanly after the error), so the lease was released. **Today this is fine.** The class is real but the specific instance is unlikely.

**Blast radius**: state corruption from concurrent apply; ~half-day to recover via state surgery.

**Patch** (add as a precondition before Step 5):

```markdown
## Step 5.0 — Verify state blob is not leased and no concurrent pipeline run is active

```bash
# Check current state blob lease
az storage blob show \
  --account-name tfstatevpp \
  --container-name tfstate \
  --name terraform.kidu \
  --auth-mode login \
  --query "{lastModified:properties.lastModified, leaseStatus:properties.lease.status, leaseState:properties.lease.state}" \
  -o jsonc

# Expected: leaseStatus=unlocked, leaseState=available
# If leaseStatus=locked → another pipeline is currently applying; STOP and wait.

# Check for in-progress pipeline 2412 runs on the kidu branch
az pipelines runs list \
  --org https://dev.azure.com/enecomanagedcloud \
  --project "Myriad - VPP" \
  --pipeline-ids 2412 \
  --status inProgress \
  --query "[].{id:id, branch:sourceBranch, status:status, result:result, started:startTime}" \
  -o table
# Expected: no rows referencing Duncan's branch. If a row is present, do not start another run.
```
```

---

## HIGH-severity breaks (high impact; fix or accept with explicit risk note)

### H1 — Other-slot orphan audit is named-out-of-scope but is a known recurring class

**Evidence grade**: PATTERN-MATCHED.

**Location**: `output/rca.md:480-481, 517-519` (L8 "What this fix does NOT change" and L9 "What I CANNOT verify"); `fbe-failure-modes-catalog.md F2` `recurrence_status: partially_remediated_namespace_class` — explicitly states "non-namespace residue still occurs". `output/rca.md` Lesson 1 also concedes: "This is a Phase-9 follow-up".

**The exploit**: the live `az eventhubs namespace list` shows premium namespaces on every active slot. Each premium namespace has a corresponding standard namespace and a storage account. **None of these are routinely cross-checked against state by any monitoring**. The next time another slot is recycled, the same F2 fires. Today's fix unblocks Duncan but does nothing for the next 9 victims. Each subsequent incident costs ~1 hour of on-call time and ~30 minutes of developer wait.

**The trap-scenario**: I noticed `vpp-evh-premium-mod` exists (created 2025-11-10) — there is **no `mod` slot in the lease table** (slot names are afi, boltz, enel, ionix, ishtar, jupiter, kidu, operations, veku, voltex per the catalog). This is a **historic-slot-rename orphan**: a slot was once named `mod`, has since been renamed/removed, but the premium namespace was never cleaned up. That namespace has been bleeding ~$80/month for 6 months (~$480 wasted; Premium EH base price is the dominant cost). **Two more orphans likely exist similarly** — they would surface if anyone tried to recreate a `mod` slot.

**Blast radius**: cost waste + accumulated incident risk; not blocking Duncan but undermines fix doc's "no other side effects" promise.

**Patch** (add to `output/fix.md` as a "post-fix audit" appendix):

```markdown
## Step 8 — Post-fix all-slot audit (recommended; not blocking Duncan)

Run after the rerun succeeds. Detects other slots that will hit the same trap.

```bash
# For every slot name, compute: does the premium namespace exist in Azure, and is it in the corresponding state file?
for SLOT in afi boltz enel ionix ishtar jupiter kidu operations veku voltex; do
  IN_AZ=$(az eventhubs namespace show \
            --name "vpp-evh-premium-${SLOT}" \
            --resource-group rg-vpp-app-sb-401 \
            --query name -o tsv 2>/dev/null)
  if [ -z "$IN_AZ" ]; then
    echo "${SLOT}: no premium namespace in Azure — clean"
    continue
  fi
  TFSTATE=$(az storage blob download \
              --account-name tfstatevpp --container-name tfstate \
              --auth-mode login \
              --name "terraform.${SLOT}" \
              --file - 2>/dev/null)
  IN_STATE=$(echo "$TFSTATE" | jq -r '[.resources[] | select(.module == "module.eventhub_namespace_premium")] | length' 2>/dev/null)
  if [ "${IN_STATE:-0}" -eq 0 ]; then
    echo "${SLOT}: orphan likely — premium namespace in Azure but module.eventhub_namespace_premium not in state"
  else
    echo "${SLOT}: tracked correctly"
  fi
done

# Detect historic-rename orphans (premium namespaces for non-current slot names)
az eventhubs namespace list -g rg-vpp-app-sb-401 \
  --query "[?starts_with(name, 'vpp-evh-premium-') && !contains_any(name, 'sbx,afi,boltz,enel,ionix,ishtar,jupiter,kidu,operations,veku,voltex')].name" \
  -o tsv
# Any names here are historic-rename orphans (e.g., 'vpp-evh-premium-mod') — escalate to Fabrizio for cleanup
```

(The `contains_any` JMESPath function may need adjustment for the local az CLI version — fallback to grep is acceptable.)
```

---

### H2 — `vppevhpremiumkidu` storage account being today-created while the namespace is 11-months-old is unexplained and the RCA's mechanism story is weak

**Evidence grade**: SPECULATIVE → PATTERN-MATCHED after analysis.

**Location**: `output/rca.md:330-342` (L5 "why is the storage account in state but not the namespace"); `evidence-ledger.md:37` (C16 INFER).

**The exploit / why this matters**: The RCA's mechanism story is "earlier FBE attempt created the namespace 11 months ago, destroy partially failed or state-rm'd the namespace, slot released". That story explains the namespace being old-and-untracked. **It does NOT explain** why the *storage account* `vppevhpremiumkidu` is brand new today (2026-05-11T06:54:14) while the *namespace* it's supposed to attach to (`vpp-evh-premium-kidu`) is 11 months old. If a prior FBE-create created the namespace, the storage account would also have been created then (the storage account is sibling, no state mismatch).

**Two possible mechanisms**:

1. The prior FBE create reached `module.eventhub_namespace_premium` (created the namespace), failed BEFORE reaching `module.eventhub_namespace_premium_storageaccount` (so the storage account never existed before). Then destroy was attempted, removed the storage account from state (it never existed in Azure anyway). The namespace was left behind in Azure but removed from state. Today's apply reached the storage account (succeeded — first time in Azure) and choked at the namespace (already exists).

2. The storage account WAS once created (sometime between 2025-06 and 2026-05) and was deleted at some point — maybe during a manual cleanup that Fabrizio did partway. Today's apply re-created it.

Mechanism 1 is plausible. Mechanism 2 implies more historic damage than the RCA owns up to.

**Why this is HIGH and not just a niggle**: If Mechanism 2 is correct, there may have been ADDITIONAL resources that were once tracked, manually deleted, and would now re-create as orphans on rerun. The RCA's "rerun succeeds, no state surgery needed" claim depends on Mechanism 1 being the truth. The RCA's `evidence-ledger.md:37` notes the "tags are empty (Terraform-managed resources usually have tags; suggests state-rm or out-of-band provenance)" — empty tags on the namespace confirms the namespace was either created by an old Terraform version that didn't apply tags or was state-rm'd. Neither cleanly distinguishes Mechanism 1 from 2.

**Counter-hypothesis**: the standard NS `vpp-evh-kidu` has `createdAt: 2025-03-05` and IS in state. That namespace likewise has no tags but is happily managed. So "no tags" is consistent with all-azurerm-state being pristine from a recreate, not necessarily evidence of state-rm. The standard NS suggests Mechanism 1 is more likely (resources created on different dates because the destroy step ran at different times for different resources).

**Blast radius**: if Mechanism 2 is true, the rerun could surface a second F2 on a different resource. Step 5's decision rule already covers this ("Pipeline fails at stage 3 with a DIFFERENT terraform error → see catalog routing") — but the on-call should be primed to expect it.

**Patch**: add to `output/fix.md` Step 5 decision rules:

```markdown
- Pipeline fails at stage 3 with `already exists` on a DIFFERENT resource (e.g., a Cosmos DB, SQL DB, Storage Account, Redis, Service Bus that the rerun tries to create-but-conflict) → second F2 instance on a different resource class. Apply the same delete-and-retry pattern; cross-check the catalog F2 sub-classes. **Repeat the Step 8 audit (above) immediately to check for further orphans on kidu.**
```

---

### H3 — `trustedServiceAccessEnabled` config drift in orphan vs IaC

**Evidence grade**: EXPLOIT-VERIFIED.

**Location**: `event-hub.premium.tf:11` declares `trusted_service_access_enabled = true`; live probe `az eventhubs namespace network-rule-set list` on the orphan shows `trustedServiceAccessEnabled: false`.

**The exploit**: this is **not** a fix-doc defect (the orphan is about to be deleted). But it does mean **the orphan, while alive, would have refused trusted-service access** — which means if any Azure trusted service (Kusto, Stream Analytics, Logic Apps with EH connector) had tried to reach this namespace in the past 11 months, it would have failed. **This is consistent with the orphan having no real data flow** (nothing was using it).

**Why it's HIGH-severity for the RCA, not for the fix**: the RCA's L4 narrative ("ARM rejects: namespace already exists") doesn't explore the question of whether the orphan **ever functioned**. If somebody were to argue "wait, maybe a developer in Q3 2025 was using this orphan for testing, please don't delete", the empty `trustedServiceAccessEnabled: false` + no role assignments + no auth rules + no event hubs is conclusive evidence: **the orphan never functioned, ever.** This strengthens the deletion-is-safe argument.

**Patch**: add to `output/fix.md` Step 2 expected output verification (as further evidence supporting the orphan classification):

```markdown
Probe 2c: confirm namespace was never actively used (defense-in-depth before delete):

```bash
az eventhubs namespace network-rule-set list \
  --namespace-name vpp-evh-premium-kidu \
  --resource-group rg-vpp-app-sb-401 \
  --query "[].{publicAccess:publicNetworkAccess, trustedSvc:trustedServiceAccessEnabled, ipRulesCount: length(ipRules), vnetRulesCount: length(virtualNetworkRules)}" \
  -o jsonc
# Expected: trustedSvc=false, ipRulesCount=0, vnetRulesCount=0 — orphan was never trusted by Kusto/Logic Apps/etc.
```
```

---

## MEDIUM-severity breaks (worth patching; can be deferred if costed)

### M1 — fix.md "Independent verification by another agent" understates Step 3's blast radius framing

**Evidence grade**: PATTERN-MATCHED.

**Location**: `output/fix.md:280-285` claims "Step 3 destructive — but bounded to the named orphan resource; cannot affect other namespaces, the storage account, or any other FBE's resources."

**The exploit**: technically true for the named orphan, but the wording "cannot affect" is too strong. An attacker reading this and substituting any other namespace name (e.g., the production `vpp-evh-premium-sbx` which is in the SAME RG and which the fix doc itself names on line 33) and following this script would delete production. The doc relies on the operator reading `vpp-evh-premium-kidu` verbatim. **No `--name`-validation gate exists** to prevent typo of `kidu` → `sbx`.

**Counter-hypothesis**: this is a hostile-typo attack, not a defect of the fix per se. But the doc's structure (large code blocks with hardcoded names) is fragile.

**Blast radius**: if operator typos `kidu` → `sbx` in Step 3, production data plane EH is destroyed. Premium EH delete is async but the operation IS scheduled instantly; the operator might catch it in Step 4 before Azure completes, but that's not guaranteed.

**Patch**: add to Step 3, BEFORE the destructive `az` command:

```bash
# Defense-in-depth: refuse to delete anything that is NOT named vpp-evh-premium-kidu
# (paste-and-verify before each token in production targets)
TARGET="vpp-evh-premium-kidu"
case "$TARGET" in
  *kidu) ;;
  *) echo "ABORT: target name is not the orphan; refusing to delete"; exit 1 ;;
esac
# Now use $TARGET in the actual command
az eventhubs namespace delete --name "$TARGET" --resource-group rg-vpp-app-sb-401 --no-wait
```

---

### M2 — fix.md Rollback section recommends running destroy pipeline 2629 — that is itself the F2-creating pipeline class

**Evidence grade**: PATTERN-MATCHED (recursive failure surface).

**Location**: `output/fix.md:241-251` — Rollback section suggests `az pipelines run --id 2629 --variables environment=kidu bypassEnvironmentOwnerValidation=true`.

**The exploit**: pipeline 2629 is the **destroy** pipeline whose historic failure modes ARE THE CAUSE of today's F2 orphan (per the RCA L7 timeline). The catalog F2 explicitly lists `bypass=true` as a workaround that has been used in past F2 incidents, sometimes leaving more residue. Recommending this as rollback is recommending the exact mechanism that creates F2 orphans.

The RCA also has another concern: `fbe-failure-modes-catalog.md F19` ("`terraformVersion` drift between create (1.14.3) and destroy (1.13.1)") — destroy pipeline pins `terraformVersion: "1.13.1"` per the catalog. Today's state was written by `terraform 1.14.3`. **Destroy pipeline 2629 may not be able to read the state at all**, leading to mid-destroy failure that leaves a NEW orphan inventory.

**Counter-hypothesis**: the doc says "in pathological cases you may need Fabrizio's intervention", which softens the recommendation. And F19 is `latent` per the catalog — not yet observed firing. But "latent" and "after a fresh 1.14.3 apply" is exactly the condition that's likely to fire.

**Blast radius**: if rollback is invoked, the system has a high chance of ending up worse than before (more orphans across more resource classes).

**Patch**: rewrite `output/fix.md:236-251` to flag the F19 risk:

```markdown
## Rollback (if the fix unexpectedly worsens the situation)

The only destructive step is **Step 3** (delete namespace). The orphan was empty (verified in Step 2), so deletion did not lose data. **There is no rollback for the deletion itself** — but there is no need either, because Step 5 re-creates the namespace with the same name through Terraform.

**Do NOT trigger pipeline 2629 (destroy) as a rollback path.** Two reasons:

1. Pipeline 2629 is pinned to `terraformVersion: 1.13.1` (`azure-pipeline-fbe-del.yml:53`). The state file was written by `terraform 1.14.3` today. The destroy may fail at init/plan with "state file was created with a newer version" — see F19 in the failure-modes catalog. This would leave the FBE in a worse state than before.
2. Pipeline 2629's historic failure modes ARE the cause of F2 orphans. Re-running it on a kidu state with partial today's apply is exactly the recipe that created today's orphan in the first place.

If for any reason the rerun (Step 5) fails irrecoverably:

- Escalate to Fabrizio. Do not run 2629 unilaterally.
- The state blob `terraform.kidu` is the only thing to preserve — don't manually edit it.
```

---

### M3 — Sub-step "Generate backend config" in pipeline 2412 relies on storage account key (read), but fix doc's rollback storage-key fetch is shielded by RBAC

**Evidence grade**: SPECULATIVE.

**Location**: `output/fix.md:243-249` and `evidence-ledger.md:49` (P-LEASE-TABLE — RBAC blocked).

**The exploit**: the evidence ledger admits the RCA author lacked "Storage Table Data Reader" on `featurebranchdeployment`. The fix doc relies on the on-call having enough RBAC to (a) read the state blob (Step 5 indirectly via pipeline, which uses the SC's identity, not the user's), (b) trigger the destroy pipeline as rollback. If the on-call is Duncan personally, his RBAC may also be insufficient for the rollback path. Fix doc P3 mentions namespace-delete RBAC but not storage / pipeline-trigger RBAC for rollback.

**Counter-hypothesis**: rollback is rare and Fabrizio can be paged. Not blocking.

**Patch**: add to fix.md preconditions:

```markdown
| P4 | If Step 5 fails irrecoverably, you have either a pager to Fabrizio OR ADO `Run pipelines` permission on pipeline 2629 | Test with `az pipelines runs list --pipeline-ids 2629 --top 1` — non-error means read RBAC at least; trigger requires Contributor on the pipeline. |
```

---

### M4 — RCA Lesson 1 probe script is shell-loop without trap; non-quoted variable

**Evidence grade**: PATTERN-MATCHED (bash safety, low likelihood of triggering harm in this exact form).

**Location**: `output/rca.md:540-544`:

```bash
for ENV in afi boltz enel ionix ishtar jupiter kidu operations veku voltex; do
  IN_AZ=$(az resource list -g rg-vpp-app-sb-401 --query "[?contains(name, '$ENV')] | length(@)" -o tsv)
  echo "$ENV: $IN_AZ Azure resources"
done
```

**The exploit**: the JMESPath `contains(name, '$ENV')` matches any resource whose name contains the slot string. The slot string `enel` would match `vpp-eneco-something-else` if such existed (low likelihood). More importantly, `operations` is a slot name AND a generic English word — false positive risk is real. The probe overcounts and the lesson's stat ("$ENV: 35 resources") becomes noise.

**Patch**: tighten regex to slot-suffix pattern. This is a quality-of-future-investigation patch, not a fix-safety patch:

```bash
for ENV in afi boltz enel ionix ishtar jupiter kidu operations veku voltex; do
  # match name ending with -$ENV or containing -$ENV- (boundary-aware)
  IN_AZ=$(az resource list -g rg-vpp-app-sb-401 --query "[?ends_with(name, '-${ENV}') || contains(name, '-${ENV}-')] | length(@)" -o tsv)
  echo "${ENV}: ${IN_AZ} Azure resources"
done
```

---

## LOW-severity / hardening (nice-to-have)

### L1 — Lease-table partition-key semantics: RCA classified C13 as A3 UNVERIFIED; in fact lease is verifiable

**Already corrected above (point 4 of "what the fix gets right"). Mention in the next RCA revision so future readers don't re-derive the wrong filter.** The partition key is the row index (1..11), not the slot name. The filter is `--filter "env eq 'kidu'"` not `--filter "PartitionKey eq 'kidu'"`.

### L2 — RCA's "slot pool size = 10" is approximately right; live table has 11 rows (PartitionKey 1, 2, 3, 5, 6, 7, 8, 9, 10, 11 — 4 is missing)

Cosmetic; doesn't affect fix safety. Mention for the next platform-overview update.

### L3 — Premium EH base cost — orphan has been bleeding budget for 11 months

Premium EH list price is ~$726 USD/PMU/month base. 11 months × 1 PMU ≈ $8K wasted on this single orphan. Plus `vpp-evh-premium-mod` (6 months ≈ $4K). Cost-per-incident metric for catalog.

### L4 — `az resource list` `createdTime` field is misleading vs `createdAt`

`az resource list` returns ARM resource-graph indexing time as `createdTime`, not the resource's true origin time. RCA's L7 timeline uses `createdAt` correctly (from per-service show commands), so this doesn't bite the RCA — but a future investigator using `az resource list` to read times will be misled. Worth a note in the playbook.

### L5 — `--no-wait` on Step 3 is correct, but doc lacks "what to do if delete succeeds synchronously" branch

Sometimes Premium EH delete returns immediately as 200 (not 202). The doc assumes async + polling. If the delete returns synchronous-success, the polling loop runs through 15 minutes of no-ops before returning. Cosmetic; correctness preserved.

---

## What I tried but could NOT break

1. **The "namespace is empty" claim**: probed `eventhub list`, `consumer group list` (consumer groups are children of event hubs which don't exist) — empty. Verified.

2. **Cross-FBE secret SPOF (the user's prompt called out "vault references in KEY VAULT secrets in OTHER slots")**: I did not check OTHER slots' KVs by listing every secret value (that would require reading values, which is heavy). But I DID check that:
   - No KV in this RG has a secret NAME mentioning `vpp-evh-premium-kidu`.
   - The orphan has no auth rules other than the auto-generated `RootManageSharedAccessKey` — so the only way a cross-slot secret could reference its connection string is via the root SAS, which Azure-issued; nobody outside this slot would have requested that key.
   - Concession: I cannot fully rule out a cross-FBE KV secret whose VALUE contains the orphan's connection string. **The safe path: orphan delete invalidates that connection string regardless; any cross-slot consumer would fail next time it tried — which is exactly nothing today, because the orphan has no event hubs and no consumers anyway.** Net: not exploitable.

3. **ARM peering / cross-subscription references**: the IaC declares no cross-subscription references; the orphan's resource ID is fully local. No cross-sub.

4. **Race conditions on storage account creation during rerun**: storage account already in state; rerun is no-op. Verified state ID matches Azure ID.

5. **Terraform state lock contention**: state blob is unlocked (verified by the fact that Duncan's first apply completed-with-error rather than hanging, which would have left a lease).

6. **Pipeline-yaml drift across worktrees**: diff -q shows zero differences. Verified.

7. **F1 stale-branch drift on Duncan's branch**: not directly observable from the artifacts; the doc has correct routing instructions for "Pipeline fails at stage 3 with a DIFFERENT error → see catalog". Accepted as residual risk.

8. **F5 slot exhaustion in the time window between fix and rerun**: Duncan's lease is held, the Timestamp is fresh; autodelete fires at 4 days. No eviction risk in the ~hour rerun window.

9. **F6 SKU retirement on Premium EH**: Premium EH SKU is a stable Azure offering; no recent Microsoft announcement of retirement. Verified by checking that `az eventhubs namespace create --sku Premium` succeeded as recently as 2026-05-07 for `vpp-evh-premium-operations`.

10. **F7 secrets_to_copy regression**: `fbe-failure-modes-catalog.md F7` is `retired_by_alex_torres_fix_2026-02-24` and PR #168288 (Fabrizio, 2026-03-17) — already mitigated. Won't fire on Duncan's apply.

11. **F4 cross-FBE shared SP secret expiry**: `recurrence_status: unknown` in the catalog. The fix doesn't change this; it's an orthogonal latent class. If it fires during Duncan's rerun, the pipeline succeeds (since SP creds are used in service runtime, not infra apply) and the FBE pods fail to authenticate — a separate incident.

12. **Identity-of-deleter mismatch (the user's "Duncan's identity has wrong RBAC and the delete returns 0 but the namespace still exists" question)**: `az` returns 0 (success) on a successful DELETE call regardless of namespace lifecycle; **but** if RBAC is insufficient, `az` returns non-zero with a 403 message. I cannot construct a path where the delete returns 0 yet the namespace persists — Azure's RBAC layer fast-fails. The only way to get a false-positive delete is via the polling loop (C1), which I covered.

## Concrete-patch summary (paste-ready)

The minimal patch set before execution:

1. **C1 patch** — replace `output/fix.md:119-143` with the stderr-discriminating polling loop above.
2. **C2 patch** — insert "Step 4.5 pre-pipeline sanity probe" between Step 4 and Step 5.
3. **C3 patch** — insert "Step 5.0 state-lease + concurrent-pipeline check" before Step 5.

The recommended-but-not-blocking patches:

4. **H1 patch** — add "Step 8 all-slot audit" appendix.
5. **H2 patch** — extend Step 5 decision rules with the second-F2 case.
6. **H3 patch** — add Probe 2c for `trustedServiceAccessEnabled: false` evidence.
7. **M1 patch** — add `case "$TARGET"` guard before the destructive delete.
8. **M2 patch** — rewrite Rollback section to disable pipeline 2629 as a rollback path.
9. **M3 patch** — add P4 precondition.
10. **M4 patch** — tighten the slot-name regex in `rca.md` Lesson 1 probe.

## Verdict

**PROCEED-WITH-CHANGES**: apply C1, C2, C3 before any execution. The other findings can be deferred but reduce future-incident cost. The diagnosis itself is well-evidenced and survives all attacks I attempted. The most likely production-damaging path is the silent auth-failure of the polling loop (C1), not a defect in the conceptual fix.

## Adversarial self-check (meta-falsifier)

1. **Pattern-matching vs real?** C1 was reproduced live (verified exit codes); C2 is a known async-resource ARM cache pattern not directly observed here; C3 is a known race-condition class with low specific likelihood today. H1 is fully verified by `az eventhubs namespace list`. H2 is a mechanism-completeness critique with limited blast radius. Each finding has a named falsifier.

2. **False positives?** My initial finding "lease row missing" was wrong (PartitionKey semantics); retracted and inverted into a positive verification of the RCA's claim. Caught before publication.

3. **Severity inflation?** I escalated C1 from MEDIUM to CRITICAL after reproducing the exit-code semantics live — without that probe, it was theoretical pattern-matching. The reproduction (`az account clear` in a separate terminal) closes the doubt.

4. **Redundancy?** C2 and C3 are both state-race patterns but with distinct mechanisms (ARM cache vs blob lease). H2 and M2 both critique mechanism completeness but at different layers (history-narrative vs rollback-recipe). No collapse to single root cause.

5. **Counter-hypotheses for the strongest critical finding (C1)**: the loop's failure is gated on a transient or permanent auth/network error in the operator's CLI session during 1-15 min. If the operator's session is rock-solid, the loop is fine. The patch costs ~10 lines of bash; the risk it prevents is a same-day re-incident. **Cost-benefit favours the patch.**

I confirm I am NOT approving the fix. I am DEMOLISHING the polling loop, the rollback section, the missing pre-pipeline sanity probe, and the missing cross-slot audit. The rest of the fix and the diagnosis survived my attacks.

---
*El Demoledor: proving resilience through destruction.*
