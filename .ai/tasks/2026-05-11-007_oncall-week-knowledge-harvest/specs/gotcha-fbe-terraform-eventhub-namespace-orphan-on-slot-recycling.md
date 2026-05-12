---
task_id: 2026-05-11-007
agent: claude-code
status: complete
summary: Spec for new vault gotcha — apply-time Azure Event Hub namespace orphan on FBE slot recycling; Terraform sees the resource as new while Azure already holds it. Ready to apply to llm-wiki/learnings/gotchas/.
spec_target_path: $SECOND_BRAIN_PATH/llm-wiki/learnings/gotchas/fbe-terraform-eventhub-namespace-orphan-on-slot-recycling.md
spec_action: create
spec_zone: learnings/gotchas
spec_status: ready_to_apply
---

# Spec — Gotcha: FBE Terraform Event Hub Namespace Orphan on Slot Recycling

## Target Path

`$SECOND_BRAIN_PATH/llm-wiki/learnings/gotchas/fbe-terraform-eventhub-namespace-orphan-on-slot-recycling.md`

## Frontmatter

```yaml
---
description: "An FBE-create pipeline run (Myriad - VPP / pipeline 2412) can fail at Terraform apply with `A resource with the ID ... already exists - to be managed via Terraform this resource needs to be imported into the State` when the named Event Hub Premium namespace (vpp-evh-premium-<slot>) exists in Azure (resource group rg-vpp-app-sb-401) but is not tracked in the slot's terraform.{env} state. Three uneliminated provenance paths: failed destroy with terraform state rm workaround; out-of-band create; terraform version drift (1.14.3 create vs 1.13.1 destroy → silent skip on state-version-mismatch). Regardless of provenance, the slot-release path lacks a residue-zero check, so the next tenant of the slot inherits the trap. Fix is identical: delete the orphan from Azure (if empty), then re-run the create pipeline."
type: gotcha
domain: work
status: active
source: agent
created: 2026-05-11
last_validated: 2026-05-11
severity: high
confidence: validated
scope: "Eneco VPP FBE slot lifecycle on Sandbox subscription 7b1ba02e-bac6-4c45-83a0-7f0d3104922e — applies to all 10 FBE slots (afi, boltz, enel, ionix, ishtar, jupiter, kidu, operations, veku, voltex). Same class likely applies to any Azure resource provisioned per slot if destroy pipeline lacks residue-zero check."
evidence: "log/employer/eneco/02_on_call_shift/2026_05_11_fbe_error_duncan/{rca.md,fix.md,context.md,slack-intake.txt}; ADO build 1638601 metadata; build error verbatim quoted in context.md:27-33"
tags: [eneco, vpp, fbe, terraform, terraform-state, azure-event-hubs, slot-recycling, orphan-resource, sandbox, kidu, duncan-teegelaar, mc-vpp-infrastructure]
---
```

## Body

> **Scope**: This gotcha covers the apply-time Azure-resource orphan failure class for FBE. The same mechanism applies to any per-slot Azure resource (Storage Accounts, KV, AppConfig, Cosmos, SQL DBs, …) if the destroy path doesn't enforce residue-zero before slot release.

## Trigger

When you see (any of):

- An FBE-create pipeline (ADO project `Myriad - VPP`, pipeline 2412 `azure-pipelines-featurebr-env.yml`) fails at the Terraform apply stage with error containing `already exists - to be managed via Terraform this resource needs to be imported into the State`
- The error names a resource ID like `/subscriptions/7b1ba02e-.../resourceGroups/rg-vpp-app-sb-401/providers/Microsoft.EventHub/namespaces/vpp-evh-premium-<slot>`
- A retry of the same pipeline fails FASTER than the first run (suggests steady, non-transient backend state)
- A slot that "should be" fresh (just allocated from the lease table) has Azure resources matching its name pattern from a PRIOR tenant

## Symptom

```text
##[error]Terraform command 'apply' failed with exit code '1'.
##[error]╷
│ Error: A resource with the ID "/subscriptions/7b1ba02e-bac6-4c45-83a0-7f0d3104922e/resourceGroups/rg-vpp-app-sb-401/providers/Microsoft.EventHub/namespaces/vpp-evh-premium-<slot>" already exists - to be managed via Terraform this resource needs to be imported into the State.
│
│   with module.eventhub_namespace_premium.azurerm_eventhub_namespace.eventhub_namespace,
│   on .terraform/modules/eventhub_namespace_premium/terraform/modules/event_hub_namespace/main.tf line 2, in resource "azurerm_eventhub_namespace" "eventhub_namespace":
│    2: resource "azurerm_eventhub_namespace" "eventhub_namespace" {
│
╵
```

Slack notification: `partiallySucceeded` for the build; Slack thread `1/4 Success` (or similar).

## Root Cause Mechanism

Three uneliminated provenance paths, all converging on the same observable defect:

### P1 — Failed destroy with `terraform state rm` workaround

Prior tenant's destroy pipeline encountered a state-version-mismatch or transient API error; operator unblocked the destroy with `terraform state rm module.eventhub_namespace_premium.azurerm_eventhub_namespace.eventhub_namespace` to allow the rest of the destroy to proceed. Azure side still has the namespace; state side believes it never existed.

### P2 — Out-of-band create

Someone (vendor, automation script, exploratory) created the namespace via `az` CLI / Azure portal / a different Terraform stack at some point in the past; the FBE-create pipeline NEVER tracked it. Lasts as long as nobody runs a destroy that would surface it.

### P3 — Terraform version drift (FBE F19)

**Create pipeline runs Terraform 1.14.3** (build log line "Terraform v1.14.3").
**Destroy pipeline (`azure-pipeline-fbe-del.yml`) runs Terraform 1.13.1** (per FBE F19, observed during 2026-05-11 investigation).

State files have an embedded Terraform version. When a destroy pipeline reads a state file written by a NEWER Terraform version, it can silently skip resources whose schema diverged between versions. Net effect: destroy reports success; resource remains in Azure; state row removed.

### Common composition

Regardless of provenance, the slot-release path (`azure-pipeline-fbe-del.yml`) does NOT verify zero residue against Azure before marking the slot free for reuse. The lease table thinks the slot is empty; Azure still has resources; the next tenant's create attempt hits the orphan.

## Quantification

- **Orphan age in 2026-05-11 incident**: ~11 months (createdAt 2025-06-10 for `vpp-evh-premium-kidu`)
- **Orphan emptiness**: zero event hubs, zero consumer groups, zero auth rules beyond the auto-generated `RootManageSharedAccessKey` SAS, zero IP/vnet rules, `trustedServiceAccessEnabled: false`
- **Fix execution time**: ~3 min for `az` delete + ~20 min for pipeline rerun
- **Provenance**: A3 UNVERIFIED in this session (activity-log retention expired); fix identical regardless

## Fix

### Step 1 — Confirm orphan and its emptiness

```bash
# Confirm subscription context
az account set --subscription 7b1ba02e-bac6-4c45-83a0-7f0d3104922e
az account show --query "{id:id, name:name}" -o table
# Expected: Eneco Cloud Foundation - Sandbox-Development-Test

# Confirm namespace exists and is the orphan
az eventhubs namespace show --name vpp-evh-premium-<slot> --resource-group rg-vpp-app-sb-401 \
  --query "{name:name, provisioningState:provisioningState, createdAt:createdAt, sku:sku}" -o table

# Confirm orphan is empty (zero data to preserve)
az eventhubs eventhub list --namespace-name vpp-evh-premium-<slot> --resource-group rg-vpp-app-sb-401 -o tsv
# Expected: empty output
az eventhubs namespace authorization-rule list --namespace-name vpp-evh-premium-<slot> --resource-group rg-vpp-app-sb-401 -o table
# Expected: only RootManageSharedAccessKey (auto-generated)
```

### Step 2 — Delete the orphan

```bash
az eventhubs namespace delete --name vpp-evh-premium-<slot> --resource-group rg-vpp-app-sb-401 --no-wait
# Returns ~immediately; deletion is asynchronous

# Poll until 404
while az eventhubs namespace show --name vpp-evh-premium-<slot> --resource-group rg-vpp-app-sb-401 >/dev/null 2>&1; do
  echo "$(date -u): still present, waiting 15s"
  sleep 15
done
echo "$(date -u): namespace deleted"
# Expected: ≤ 15 min
```

### Step 3 — Re-run the create pipeline

Re-trigger pipeline 2412 from the same branch (e.g., `feature/fbe-821600-date-selector-flex-reservation-dashboard`). Terraform will ADD `module.eventhub_namespace_premium.azurerm_eventhub_namespace.eventhub_namespace` to state on next apply. No manual `terraform import` is required (per fix decision in `2026_05_11_fbe_error_duncan/fix.md`).

### Why delete-recreate over `terraform import` (decision rationale)

1. The orphan is empty (no data to preserve)
2. The orphan is 11 months stale; `import` would attach it to state, then immediate next plan/apply would compute drift (network rules, SKU sub-attributes, tags) and propose modifications. The drift-debug cost exceeds fresh-create cost.
3. `terraform import` from an ADO pipeline is awkward — needs to happen inside the pipeline workdir with state lease held, and `azure-pipelines-featurebr-env.yml` has no import hook.

## Adjacent Mechanisms Worth Knowing

1. **Other slots may have similar orphans** — the lease table was not enumerable in-session due to RBAC. A Phase-9 follow-up task should audit all 10 slots:
   ```bash
   for SLOT in afi boltz enel ionix ishtar jupiter kidu operations veku voltex; do
     IN_AZ=$(az resource list -g rg-vpp-app-sb-401 \
       --query "[?ends_with(name, '-${SLOT}') || contains(name, '-${SLOT}-')] | length(@)" -o tsv)
     echo "${SLOT}: ${IN_AZ} Azure resources"
   done
   ```
2. **`vpp-evh-premium-mod`** orphan exists (createdAt 2025-11-10) for a slot name no longer in the lease table — historical rename residue. Flagged by el-demoledor; cleanup is a separate follow-up.
3. **The fix is NOT a code change** — IaC is correct; pipeline YAML is correct. The bug is in cleanup discipline (destroy didn't verify residue) and version drift between create/destroy pipelines.
4. **Convergence with ArgoCD PAT incident**: even after this orphan fix, Duncan's FBE on 2026-05-11 wouldn't fully come up because the ArgoCD ApplicationSet PAT had expired → kidu's child Applications would not generate. See [[argocd-pat-expiry-silently-fails-applicationset-generation]] and the joint episode [[2026-05-11-oncall-shift-trade-platform-quad-incident]].
5. **`vpp-evh-premium-sbx`** (sandbox plane) is a STABLE namespace shared by all slots — do NOT delete that one. The orphan pattern is per-slot suffix (`-<slot>`), not the shared sandbox plane.

## Defense (structural change, proposed)

The destroy pipeline `azure-pipeline-fbe-del.yml` should, at the end of its successful run, **verify zero residue** before releasing the slot. Pseudocode:

```bash
# After terraform destroy succeeds:
for RESOURCE_TYPE in eventhubs namespace storage account keyvault redis cosmosdb account; do
  COUNT=$(az resource list -g rg-vpp-app-sb-401 \
    --query "[?ends_with(name, '-${SLOT}') || contains(name, '-${SLOT}-')] | length(@)" -o tsv)
  if [ "$COUNT" != "0" ]; then
    echo "FAIL: residue detected for ${SLOT}: ${COUNT} resources still in Azure"
    exit 1
  fi
done

# Plus: align Terraform versions between create and destroy pipelines (F19)
```

If residue exists, the destroy pipeline FAILS and the operator must clean it before slot release. Aligning Terraform versions between create (1.14.3) and destroy (1.13.1) eliminates the silent-skip mechanism in P3.

## Verification Probes (for the next person hitting this)

```bash
# 1. Confirm the resource is the orphan (cluster/Azure truth)
az eventhubs namespace show --name vpp-evh-premium-<slot> --resource-group rg-vpp-app-sb-401 \
  --query "{name:name, createdAt:createdAt, provisioningState:provisioningState}" -o table

# 2. Confirm the slot's state file does NOT track it
# (Cannot probe directly from operator workstation; the build log's `terraform plan` output
#  shows the resource is NEW from Terraform's POV — the "already exists" error proves state absence.)

# 3. Confirm Sandbox subscription context
az account show --query "{id:id, name:name}" -o tsv
# Expected: 7b1ba02e-bac6-4c45-83a0-7f0d3104922e   Eneco Cloud Foundation - Sandbox-Development-Test
```

## Cross-Links

- [[2026-05-11-oncall-shift-trade-platform-quad-incident]] — episode of origin
- [[argocd-pat-expiry-silently-fails-applicationset-generation]] — converging incident on the same slot (kidu); both must resolve for FBE functionality
- [[stale-local-clones-need-git-log-discipline]] — sibling lesson from same RCA (Lesson 2)
- [[cross-repo-error-paths-need-topology-before-file-read]] — sibling lesson from same RCA (Lesson 3)
- [[eneco-vpp-sandbox-is-aks-not-openshift]] — sandbox infrastructure context
- Source RCA: `log/employer/eneco/02_on_call_shift/2026_05_11_fbe_error_duncan/rca.md` (787 lines)
- Source fix doc: `log/employer/eneco/02_on_call_shift/2026_05_11_fbe_error_duncan/fix.md` (31k)
- Build log: ADO build 1638601 (`Myriad - VPP / pipeline 2412`)
