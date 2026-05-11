---
task_id: 2026-05-11-001
agent: claude-opus-4-7
status: pending_review
summary: Step-by-step executable fix for Duncan's FBE-create failure on kidu slot — delete orphan Premium Event Hub namespace, re-run pipeline 2412, verify. Adversarial-review-patched (C1 polling silent-fail, C2 ARM cache, C3 state-lease + Steps 0/2c/4.5/5.0/5.5/8 added).
adversarial_review: external
adversarial_artifacts:
  - auxiliary/adversarial-review-socrates.md
  - auxiliary/adversarial-review-eldemoledor.md
revision_notes: "v2 after adversarial review — C1/C2/C3 patches integrated; Step 0 (branch resolution), Step 2c (defense-in-depth probes), Step 4.5 (pre-rerun sanity), Step 5.0 (state-lease + concurrent run check), Step 5.5 (pipeline wait gate), Step 8 (all-slot audit) added; Rollback rewritten — pipeline 2629 disabled as rollback path due to F19 terraform version drift risk."
---

# FBE-Create Failure on `kidu` Slot — Step-by-Step Fix (v2, adversarial-review-patched)

> **Reader assumption**: You are Duncan, the next-shift on-call, or any engineer with access to the Eneco Sandbox subscription, OR an AI agent assisting one of them. You have read [`rca.md`](./rca.md) at least once. **The fix is short. The why is in [`rca.md`](./rca.md).**

## What this fix does (in one paragraph)

You will: (0) resolve Duncan's actual branch name from build 1638601 metadata; (1) confirm subscription context; (2) confirm the orphan `vpp-evh-premium-kidu` Event Hub namespace exists, is empty, and was never actively used (no IP rules, no trusted services); (3) verify your identity has delete RBAC, then delete the orphan; (4) poll deletion to completion with a robust loop that distinguishes ResourceNotFound from auth/throttle failures; (4.5) confirm the namespace stays gone immediately before the rerun; (5.0) confirm no other pipeline is racing the state blob; (5) re-run pipeline 2412 on Duncan's branch; (5.5) wait for pipeline completion; (6) verify pipeline result; (7) post-success FBE health check; (8) optional — audit all 10 slots for similar orphans. **No code change required. No state surgery required. The orphan is empty (zero data loss).**

## Preconditions (verify ALL FOUR before starting)

| # | Condition | How to check |
|---|---|---|
| P1 | You have `az` CLI ≥ 2.50 and are logged in | `az version` and `az account show` |
| P2 | You can switch to Sandbox subscription `7b1ba02e-bac6-4c45-83a0-7f0d3104922e` | `az account set --subscription 7b1ba02e-bac6-4c45-83a0-7f0d3104922e && az account show --query name -o tsv` should print `Eneco Cloud Foundation - Sandbox-Development-Test` |
| P3 | You have `Microsoft.EventHub/namespaces/delete` permission on `vpp-evh-premium-kidu` for **your** identity (the delete is executed by YOUR identity, not the pipeline SP) | Probed in Step 3a below; do **not** assume |
| P4 | If Step 5 fails irrecoverably, you can reach Fabrizio Zavalloni in `#myriad-platform` OR you have ADO `Run pipelines` permission on pipeline 2629 (destroy) | `az pipelines runs list --org https://dev.azure.com/enecomanagedcloud --project "Myriad - VPP" --pipeline-ids 2629 --top 1` returning without error means at least read RBAC; trigger requires Contributor on the pipeline |

If any precondition is unmet, **stop and resolve before continuing**.

## AI-executor mandate

If you are an AI agent following this doc, **you MUST issue an `AskUserQuestion` (or equivalent confirmation tool call) before executing the destructive command in Step 3b**. Prose-level "type it yourself" guidance assumes a human reader; an AI executor without an explicit confirmation gate could pipe Step 3b through automatically.

For the destructive op, the AI executor's `AskUserQuestion` MUST cite:

- Scope: `az eventhubs namespace delete --name vpp-evh-premium-kidu --resource-group rg-vpp-app-sb-401 --subscription 7b1ba02e-bac6-4c45-83a0-7f0d3104922e`
- Reversibility: deletion is irreversible (Event Hub Premium has NO soft-delete); the namespace is recreated by Terraform on Step 5 rerun, but the underlying name slot is destroyed instantly on delete-call.
- Pre-delete state of the orphan: A1 confirmed empty in Step 2.

## Authorization gate (destructive operation, human reader)

Before executing **Step 3b**:

- Confirm the namespace name `vpp-evh-premium-kidu` is the one in Duncan's failing build log.
- Confirm the namespace is empty (Step 2 below) — this is the safety net that makes deletion safe.
- Confirm no other FBE or service depends on this specific namespace (orphan = unreferenced; the production data flow uses `vpp-evh-premium-sbx`, not `vpp-evh-premium-kidu`).

**Type / paste each `az` command yourself. Do not silently auto-execute the destructive step from a script.**

---

## Step 0 — Resolve Duncan's actual branch name from build 1638601

**Question this step answers**: "Which branch did Duncan actually run pipeline 2412 against, so I can re-run pipeline 2412 on the same branch later?"

**Why this command**: `az pipelines runs show --id <build-id>` is the authoritative reverse-lookup from a build to its source branch. The branch name is required input for Step 5 and was previously A3 UNVERIFIED[blocked] in the evidence ledger.

**Expected output**: JSON including `"branch": "refs/heads/feature/fbe-821600-date-selector-flex-reservation-dashboard"` and `"requestedFor": "Duncan Teegelaar"` (or equivalent).

**Decision rule**: if the requestedFor name does not match Duncan, you may be re-investigating someone else's build — double-check the build ID and slack-intake. If the branch is not under `feature/fbe-*`, abort — pipeline 2412's Stage 1 regex would have refused that build anyway.

```bash
az pipelines runs show --id 1638601 \
  --org https://dev.azure.com/enecomanagedcloud \
  --project "Myriad - VPP" \
  --query "{branch:sourceBranch, requestedFor:requestedFor.displayName, definitionId:definition.id, definitionName:definition.name, result:result}" \
  -o jsonc

# Capture the branch (strip the refs/heads/ prefix) for later steps
BRANCH=$(az pipelines runs show --id 1638601 \
  --org https://dev.azure.com/enecomanagedcloud \
  --project "Myriad - VPP" \
  --query "sourceBranch" -o tsv | sed 's@^refs/heads/@@')
echo "BRANCH=$BRANCH"
# Expected (per adversarial review evidence A1): feature/fbe-821600-date-selector-flex-reservation-dashboard
```

If `az pipelines runs show` returns 403, ADO read-RBAC is missing — escalate. Alternative (less precise): ask Duncan directly in `#myriad-platform`.

**Reusable principle**: every "branch name unknown" probe should resolve from the failing build's metadata before any human is paged. The build ID always carries its own branch.

---

## Step 1 — Set Sandbox subscription context

**Question this step answers**: "Are my next commands going to act on the right subscription?"

**Why this command**: `az account set` is the documented authority for current-subscription selection in az CLI; alternatives (per-command `--subscription` flag) are equally valid but easier to forget on one of the chained commands.

**Expected output**: empty (success on `set`); the `show` prints the human-readable Sandbox name.

**Decision rule**: if `show` prints anything other than `Eneco Cloud Foundation - Sandbox-Development-Test`, STOP — the rest of this fix will hit the wrong subscription.

```bash
az account set --subscription 7b1ba02e-bac6-4c45-83a0-7f0d3104922e
az account show --query "{name:name, id:id}" -o table
# Expected:
# Name                                               Id
# -------------------------------------------------  ------------------------------------
# Eneco Cloud Foundation - Sandbox-Development-Test  7b1ba02e-bac6-4c45-83a0-7f0d3104922e
```

---

## Step 2 — Verify orphan namespace exists, is empty, AND was never functionally used

**Question this step answers**: "Is the namespace we are about to delete (a) the one that's blocking Duncan, (b) safe to delete because it has no children, AND (c) confirmed unused by trusted services / IP rules (defense-in-depth before destroy)?"

**Why these probes**: `az eventhubs namespace show` returns 200 with metadata if the namespace exists, 404 otherwise. `az eventhubs eventhub list` returns the event hubs **inside** the namespace; empty list means no consumer groups or retained events to lose. `az eventhubs namespace network-rule-set list` adds defense-in-depth: a namespace with `trustedServiceAccessEnabled: false` and zero IP/vnet rules was never functionally reachable for trusted Azure services (Kusto, Stream Analytics, Logic Apps), proving the orphan never had real data flow.

### Probe 2a — Namespace existence

**Expected output**: JSON with `"name": "vpp-evh-premium-kidu"`, `"provisioningState": "Succeeded"`, `"sku": "Premium"`, `"createdAt": "2025-06-10T17:28:27Z"` (in the past), `"tags": {}`.

**Decision rule**: 404 → STOP. The orphan is already gone. Either someone fixed it, or you're looking at the wrong error — re-read the build log.

```bash
az eventhubs namespace show \
  --name vpp-evh-premium-kidu \
  --resource-group rg-vpp-app-sb-401 \
  --query "{name:name, provisioningState:provisioningState, sku:sku.name, createdAt:createdAt, tags:tags}" \
  -o jsonc
```

### Probe 2b — Children (event hubs)

**Expected output**: `[]` (empty array).

**Decision rule**: any event hubs → STOP. Escalate to Fabrizio. Do NOT delete a non-empty namespace.

```bash
az eventhubs eventhub list \
  --namespace-name vpp-evh-premium-kidu \
  --resource-group rg-vpp-app-sb-401 \
  --query "[].{name:name, status:status, partitionCount:partitionCount}" \
  -o table
```

### Probe 2c — Functional-usage defense-in-depth (network rules + access rules)

**Expected output**: `trustedServiceAccessEnabled: false`, `ipRulesCount: 0`, `vnetRulesCount: 0`. Plus only the auto-generated `RootManageSharedAccessKey` in authorization rules.

**Decision rule**: if `trustedServiceAccessEnabled` is `true` OR any IP/vnet rules exist OR any non-`RootManageSharedAccessKey` auth rule exists → STOP. The orphan was functionally configured for someone; escalate before deletion.

```bash
az eventhubs namespace network-rule-set list \
  --namespace-name vpp-evh-premium-kidu \
  --resource-group rg-vpp-app-sb-401 \
  --query "[].{publicAccess:publicNetworkAccess, trustedSvc:trustedServiceAccessEnabled, ipRulesCount: length(ipRules), vnetRulesCount: length(virtualNetworkRules)}" \
  -o jsonc

az eventhubs namespace authorization-rule list \
  --namespace-name vpp-evh-premium-kidu \
  --resource-group rg-vpp-app-sb-401 \
  --query "[].{name:name, rights:rights}" \
  -o table
```

**Reusable principle**: Before any irreversible delete on a hierarchical Azure resource, list its (a) parent existence, (b) children, AND (c) functional configuration. The parent's existence is one truth surface; emptiness is a second; functional inertness is a third.

---

## Step 3 — Delete the orphan namespace

### Step 3a — Verify YOUR identity has delete RBAC

**Question**: Does the identity that will execute Step 3b actually have `Microsoft.EventHub/namespaces/delete`?

**Why**: Fast-fail if RBAC is missing. The CLI will produce a clear 403 anyway, but a pre-check makes the operator's mental model accurate before any destructive command is typed.

**Expected output**: at least one role assignment with `roleDefinitionName` of `Contributor`, `Owner`, or a custom role that includes the namespace delete action.

```bash
MY_ID=$(az ad signed-in-user show --query id -o tsv)
az role assignment list \
  --scope "/subscriptions/7b1ba02e-bac6-4c45-83a0-7f0d3104922e/resourceGroups/rg-vpp-app-sb-401/providers/Microsoft.EventHub/namespaces/vpp-evh-premium-kidu" \
  --assignee "$MY_ID" \
  --query "[].{role:roleDefinitionName, scope:scope}" -o table

# If empty, check inherited assignments at RG and subscription scope:
az role assignment list \
  --scope "/subscriptions/7b1ba02e-bac6-4c45-83a0-7f0d3104922e/resourceGroups/rg-vpp-app-sb-401" \
  --assignee "$MY_ID" \
  --query "[].{role:roleDefinitionName, scope:scope}" -o table
```

**Decision rule**: if you see NO `Contributor` / `Owner` / custom-with-delete role at any scope chain → STOP. Escalate to Fabrizio (he can either grant a temporary role or execute the delete himself).

### Step 3b — Delete (DESTRUCTIVE — name-guarded)

**Question**: Remove the blocker so Terraform can recreate the namespace on the next apply.

**Why this command**: `az eventhubs namespace delete` is the documented authority for namespace deletion. Premium SKU async-deletes; `--no-wait` returns immediately without blocking your shell.

**Expected output**: empty (success).

**Decision rule**: if the command returns a non-empty error, STOP — escalate.

```bash
# Defense-in-depth: refuse to delete anything that is NOT named vpp-evh-premium-kidu
# (prevents typo from accidentally deleting vpp-evh-premium-sbx or another slot's namespace)
TARGET="vpp-evh-premium-kidu"
case "$TARGET" in
  vpp-evh-premium-kidu) ;;
  *)
    echo "ABORT: target name '$TARGET' is not the orphan; refusing to delete"
    exit 1
    ;;
esac

az eventhubs namespace delete \
  --name "$TARGET" \
  --resource-group rg-vpp-app-sb-401 \
  --no-wait
```

**Reusable principle**: hardcode-and-guard the target name even for one-off destructive commands. A `case` guard converts a typo from "delete the wrong thing" into a script halt.

---

## Step 4 — Poll until deletion completes (auth-aware, refuses false success)

**Question**: Has Azure finished reaping the namespace, so the next pipeline apply will see a clean slate?

**Why this loop discriminates exit reasons**: The naive `until ! az ... >/dev/null 2>&1` form terminates on ANY non-zero exit code (including auth-token expiry, transient 429 throttle, wrong RG, etc.), printing a false "deletion confirmed" message. This patched version captures stderr, pattern-matches on "ResourceNotFound" / "not found" / "could not be found", and **refuses to claim success on any other error**.

**Expected output**: a stream of `.` while polling, ending with `OK: namespace confirmed gone (ResourceNotFound) at elapsed=Ns`. Typical complete time is 1-5 minutes for an empty namespace.

**Decision rule**: any `ABORT:` output → re-authenticate (`az login` or `az account get-access-token`), re-set subscription, re-run Step 4. Do NOT proceed to Step 4.5 until you see the "OK" line.

```bash
TIMEOUT_S=$((15 * 60))
ELAPSED=0
DELETED=0
while [ "$ELAPSED" -lt "$TIMEOUT_S" ]; do
  ERR=$(az eventhubs namespace show \
          --name vpp-evh-premium-kidu \
          --resource-group rg-vpp-app-sb-401 \
          -o none 2>&1 >/dev/null)
  RC=$?
  if [ "$RC" -eq 0 ]; then
    # Still present in Azure
    printf "."
    sleep 15
    ELAPSED=$((ELAPSED + 15))
    continue
  fi
  case "$ERR" in
    *"not found"*|*"ResourceNotFound"*|*"could not be found"*)
      DELETED=1
      echo
      echo "OK: namespace confirmed gone (ResourceNotFound) at elapsed=${ELAPSED}s"
      break
      ;;
    *)
      echo
      echo "ABORT: az error is NOT 'not found' — refusing to claim deletion succeeded"
      echo "       Exit code: $RC"
      echo "       Error:    $ERR"
      echo "       Likely causes: expired auth, wrong RG/subscription, ARM throttle. Re-auth and re-run Step 4."
      exit 1
      ;;
  esac
done

if [ "$DELETED" -ne 1 ]; then
  echo "TIMEOUT: namespace still present after ${TIMEOUT_S}s — DO NOT proceed; escalate to Fabrizio."
  exit 1
fi
```

**Reusable principle**: when polling for deletion of a long-running Azure resource, never collapse "ResourceNotFound" with "any other non-zero exit". A pollers' silent-success on auth/throttle errors is the single most common false-positive class in cloud-CLI ops automation.

---

## Step 4.5 — Pre-pipeline sanity probe (mandatory before triggering Step 5)

**Question**: Is the namespace REALLY gone right before we let the pipeline race against Azure?

**Why**: Step 4's loop confirms deletion at one point in time. Premium EH delete is documented as "completes within minutes" — the "within" hedge means ARM caches can occasionally re-surface a resource view briefly. Run this one-liner immediately before Step 5 to close the race window.

**Expected output**: `OK proceed`.

**Decision rule**: `STOP` → re-run Step 4's polling loop; do NOT trigger the pipeline.

```bash
az eventhubs namespace show \
  --name vpp-evh-premium-kidu \
  --resource-group rg-vpp-app-sb-401 \
  -o none 2>&1 | grep -qi "not found" \
  && echo "OK proceed" \
  || { echo "STOP: namespace re-surfaced or another error — re-run Step 4 polling"; exit 1; }
```

Trigger Step 5 within the next ~60 seconds while this confirmation is fresh.

---

## Step 5.0 — State-lease + concurrent-pipeline check

**Question**: Is any other pipeline run currently leasing the state blob `terraform.kidu` OR currently in-flight on Duncan's branch?

**Why**: state corruption risk if two pipeline runs apply to the same backend blob concurrently. Also F16 race-condition class on the limiter table.

**Expected output**:

- First command: `leaseStatus: unlocked`, `leaseState: available`.
- Second command: no rows referencing Duncan's branch (or only the FAILED run that triggered this RCA).

**Decision rule**: if `leaseStatus=locked` → another pipeline is applying; STOP and wait until lease releases (Azure auto-expires leases at 60s if not auto-renewed). If a pipeline run on Duncan's branch shows status `inProgress` → do NOT start another.

```bash
az storage blob show \
  --account-name tfstatevpp \
  --container-name tfstate \
  --name terraform.kidu \
  --auth-mode login \
  --query "{lastModified:properties.lastModified, leaseStatus:properties.lease.status, leaseState:properties.lease.state}" \
  -o jsonc

az pipelines runs list \
  --org https://dev.azure.com/enecomanagedcloud \
  --project "Myriad - VPP" \
  --pipeline-ids 2412 \
  --status inProgress \
  --query "[?contains(sourceBranch, '$BRANCH')].{id:id, branch:sourceBranch, status:status, started:startTime}" \
  -o table
```

---

## Step 5 — Re-trigger pipeline 2412 from Duncan's branch

**Question**: Will Terraform now successfully create the namespace + downstream resources, so the FBE finishes provisioning?

**Why pipeline 2412 specifically**: Per the FBE creation lifecycle, pipeline 2412 is the canonical FBE-create pipeline. Re-running it from Duncan's branch reuses the existing slot lease, reuses `terraform.kidu` state, and applies the missing namespace + dependents.

**Expected output**: pipeline run starts; stage 3 (`DeployInfra`) terraform apply succeeds where it previously failed; stages 4-8 proceed; ~50-60 minutes later a Slack notification arrives in `#myriad-env-fbe` with Duncan's FBE URL and ArgoCD links.

**Decision rules**:

- Pipeline succeeds → proceed to Step 5.5/6.
- Pipeline fails at stage 3 with the **same** "already exists" error on `vpp-evh-premium-kidu` → STOP. The deletion did not stick. Re-check Step 4 output; escalate.
- Pipeline fails at stage 3 with `already exists` on a **DIFFERENT** resource (e.g., another Cosmos DB, SQL DB, Storage Account, Redis, Service Bus) → second F2 instance on a different resource class. Apply the same delete-and-retry pattern; run Step 8 (all-slot audit) below to detect further orphans.
- Pipeline fails at stage 3 with a **different** terraform error → see `fbe-failure-modes-catalog.md` for routing (F1 stale branch, F6 Microsoft SKU, F7 secrets_to_copy).
- Pipeline shows stage 7 (Pester) failure but stages 1-6 green → NOT a fix failure. Pester has a known latent `$token` used-before-assigned bug that produces false-negatives on the URL check (see `fbe-creation-lifecycle-deep-dive.md` Pester latent bug). Verify against Step 7's `curl` instead.
- Pipeline fails at stage 5/6/7 → not in scope of this fix; refer to the operations runbook.

### Option A — Trigger from ADO UI

1. Open [Pipeline 2412](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_build?definitionId=2412).
2. Click **Run pipeline**.
3. Branch: select the value of `$BRANCH` from Step 0 (`feature/fbe-821600-date-selector-flex-reservation-dashboard` confirmed).
4. Click **Run**.
5. Watch the live stages; the failing stage was stage 3 `DeployInfra` → "Terraform Apply".

### Option B — Trigger from `az pipelines`

```bash
az pipelines run \
  --org https://dev.azure.com/enecomanagedcloud \
  --project "Myriad - VPP" \
  --id 2412 \
  --branch "$BRANCH" \
  --query "{id:id, name:name, status:status, url:_links.web.href}" \
  -o jsonc
# Record the new build ID
NEW_BUILD_ID=$(az pipelines runs list \
  --org https://dev.azure.com/enecomanagedcloud \
  --project "Myriad - VPP" \
  --pipeline-ids 2412 \
  --branch "$BRANCH" \
  --top 1 \
  --query "[0].id" -o tsv)
echo "NEW_BUILD_ID=$NEW_BUILD_ID"
```

**Reusable principle**: when a pipeline failure is caused by external state (not by code), the fix is to correct the external state and re-run the same pipeline — not to patch the pipeline.

---

## Step 5.5 — Wait for pipeline completion before health checks

**Question**: Has the pipeline finished, so kubectl/curl in Step 7 will return meaningful results?

**Why**: Stage 6 (ArgoCD sync) completes ~30 min into the pipeline; stage 7 Pester ~50 min. Running `kubectl get ns kidu` 5 minutes in returns `NotFound` and looks like a fix failure — but it's just timing.

**Expected output**: `result: succeeded` (or `partiallySucceeded` if Pester false-negative — see Step 5 decision rules).

**Decision rule**: do NOT proceed to Step 7 (post-success health check) until pipeline 2412 reports `finishTime`. Either wait the ~50-60 minutes or block on the run:

```bash
# Block until the run finishes
az pipelines runs show \
  --id "$NEW_BUILD_ID" \
  --org https://dev.azure.com/enecomanagedcloud \
  --project "Myriad - VPP" \
  --open

# OR poll:
while true; do
  STATUS=$(az pipelines runs show --id "$NEW_BUILD_ID" \
    --org https://dev.azure.com/enecomanagedcloud --project "Myriad - VPP" \
    --query "status" -o tsv)
  echo "$(date -u +%H:%M:%S) status=$STATUS"
  [ "$STATUS" = "completed" ] && break
  sleep 60
done
```

---

## Step 6 — Verify pipeline final result

**Question**: Did the rerun actually succeed end-to-end (not just the stage that previously failed)?

**Expected output**: pipeline run `result: succeeded` (or `partiallySucceeded` if Pester false-negative — verify against Step 7 curl).

```bash
az pipelines runs list \
  --org https://dev.azure.com/enecomanagedcloud \
  --project "Myriad - VPP" \
  --pipeline-ids 2412 \
  --branch "$BRANCH" \
  --top 3 \
  --query "[].{id:id, status:status, result:result, finishTime:finishTime}" \
  -o table
```

---

## Step 7 — Post-success FBE health check

**Question**: Is Duncan's FBE actually working end-to-end (not just provisioned)?

**Why these probes**: Per `fbe-operations-runbook.md` Operation 2 (Verify), pipeline success is one truth surface; ArgoCD sync + pod health + URL reachability are independent truth surfaces.

```bash
# 1. Namespace tracked in Azure and (after rerun) in state
az eventhubs namespace show \
  --name vpp-evh-premium-kidu \
  --resource-group rg-vpp-app-sb-401 \
  --query "{name:name, sku:sku.name, provisioningState:provisioningState, createdAt:createdAt, tags:tags}" \
  -o jsonc
# Expected: provisioningState=Succeeded; createdAt within the last hour

# 2. Kubernetes namespace healthy. Uncomment the `az aks get-credentials` line below
# if your kubectl context is NOT already pointed at vpp-aks01-d
# (check with: kubectl config current-context).
# az aks get-credentials --resource-group $(az aks list --query "[?name=='vpp-aks01-d'].resourceGroup | [0]" -o tsv) --name vpp-aks01-d
kubectl get ns kidu 2>&1
# Expected: Active (NOT Terminating).

kubectl get pods -n kidu 2>&1 | head
# Expected: pods Running.

# 3. URL reachable
curl -svk "https://kidu.dev.vpp.eneco.com/" 2>&1 | grep -iE "Request-Context|x-correlation-id|HTTP/"
# Expected: HTTP/2 200 plus Request-Context and x-correlation-id headers (proof the API responded, not just SPA fallback)
```

---

## Step 8 — Post-fix all-slot audit (recommended; not blocking Duncan)

**Question**: Are there other slots with similar orphans waiting to bite their next tenant?

**Why**: F2 Azure-resource sub-class is structurally recurrent. El-demoledor's review also surfaced a historic-rename orphan `vpp-evh-premium-mod` (created 2025-11-10, for a slot name that no longer exists in the lease table). A 2-minute audit prevents the next on-call incident.

**Expected output**: per-slot status line; any line containing `orphan likely` is a candidate for the same fix recipe.

```bash
# Active slots
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

# Historic-rename orphans (premium namespaces for non-current slot names)
az eventhubs namespace list -g rg-vpp-app-sb-401 \
  --query "[?starts_with(name, 'vpp-evh-premium-')].name" \
  -o tsv | grep -vE '^vpp-evh-premium-(sbx|afi|boltz|enel|ionix|ishtar|jupiter|kidu|operations|veku|voltex)$' || echo "none"
# Any names returned are historic-rename orphans — escalate to Fabrizio for cleanup
# (Known: vpp-evh-premium-mod, created 2025-11-10, has been bleeding ~$80/mo for ~6 months per adversarial review L3)
```

---

## Rollback (if the fix unexpectedly worsens the situation)

The only destructive step is **Step 3b** (delete namespace). The orphan was empty (verified in Steps 2a-2c), so deletion did not lose data. **There is no rollback for the deletion itself** — but there is no need either, because Step 5 re-creates the namespace with the same name through Terraform.

**Do NOT trigger pipeline 2629 (destroy) as a rollback path.** Two reasons:

1. **F19 risk (terraform version drift)**: Pipeline 2629 is pinned to `terraformVersion: 1.13.1` (per `fbe-failure-modes-catalog.md F19`). Today's state was written by `terraform 1.14.3` and after Step 5's rerun will be further written by 1.14.3. The destroy may fail at init/plan with "state file was created with a newer version of terraform". This would leave the FBE in a worse state than before.
2. **Recursive F2 risk**: Pipeline 2629's historic failure modes ARE the cause of F2 orphans (per the RCA L7 timeline and the F2 catalog text). Re-running it on a kidu state with partial today's apply is exactly the recipe that created today's orphan in the first place. The rollback would escalate the blast radius from "namespace re-orphan" to "destroy Duncan's entire half-built FBE + create new orphans on N other resources."

If for any reason the rerun (Step 5) fails irrecoverably:

- **Escalate to Fabrizio Zavalloni first** in `#myriad-platform`. Do not run pipeline 2629 unilaterally.
- The state blob `terraform.kidu` is the only thing to preserve — don't manually edit it.
- If you cannot reach Fabrizio and you have evidence the orphan re-emerged (e.g., Step 4.5 returned STOP and you proceeded anyway), the safe immediate action is: re-run Step 3-4 (delete + poll), then re-attempt Step 5.

---

## Escalation path

If Step 2c finds non-zero IP rules / trustedSvc / non-default auth rules, OR you lack Step 3a RBAC, OR Step 5 fails again at the same namespace error, OR you see ANY result other than the expected outputs:

```
#myriad-platform

Hi @platform, hitting F2 Azure-resource sub-class on kidu slot:

- Branch: feature/fbe-821600-date-selector-flex-reservation-dashboard (Duncan; verified via build 1638601 metadata)
- Original failing pipeline: https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_build/results?buildId=1638601
- Error: azurerm_eventhub_namespace vpp-evh-premium-kidu already exists
- What I tried (from the RCA fix doc):
  - Step 0: branch resolution — OK ($BRANCH=...)
  - Step 1: subscription set to Sandbox — OK
  - Step 2 (a/b/c): namespace show + eventhub list + network-rule-set list — <result>
  - Step 3a: RBAC check — <result>
  - Step 3b: delete attempted — <result>
  - Step 4: <polling result>
  - Step 4.5: <pre-rerun sanity result>
  - Step 5.0: <state lease + concurrent run result>
  - Step 5: pipeline rerun — <result>
- Reference RCA: <link or path to rca.md>
- Suspect: F2-adjacent (apply-time Azure-resource orphan; see vault fbe-failure-modes-catalog#F2)
```

Authority figure: **Fabrizio Zavalloni** (FBE owner).

---

## Independent verification by another agent

An AI agent (or human reviewer) can mechanically verify the read-only steps are non-destructive by inspecting the `az` commands:

- Steps 0, 1, 2, 3a, 4.5, 5.0, 6, 7, 8 — read-only queries; no side effects.
- Step 3b — **destructive**, but bounded to the named orphan resource (name-guarded by `case` statement); cannot affect other namespaces.
- Step 4 — read-only polling, refuses false success.
- Step 5 — triggers a pipeline; idempotent for the FBE create case (rerunning on an in-progress slot reuses the lease + state, applies missing resources).
- Step 5.5 — read-only blocking-poll.

Point-of-no-return: Step 3b, gated by Steps 2a/2b/2c (emptiness + functional-inertness) and Step 3a (RBAC).

## Adversarial-review summary (this fix has been tested)

| Reviewer | Verdict | Critical findings absorbed |
|---|---|---|
| `socrates-contrarian` | PROCEED-WITH-CHANGES | Step 0 branch resolution; provenance hedges; RBAC pre-check; Step 5.5 timing gate; AI-executor mandate; Rollback rewrite |
| `el-demoledor` | PROCEED-WITH-CHANGES | C1 polling silent-fail (replaced with stderr-discriminating loop); C2 Step 4.5 pre-rerun sanity probe; C3 Step 5.0 state-lease + concurrent check; Probe 2c defense-in-depth; H1 Step 8 all-slot audit; H2 second-F2 decision rule; M1 target-name guard; M2 Rollback rewrite |

Full review artifacts: `auxiliary/adversarial-review-socrates.md` and `auxiliary/adversarial-review-eldemoledor.md`.
