# Fix — free the `thor` FBE (exact self-unblock runbook for Hein)

> All state below was verified live this session (2026-06-26, Sandbox `7b1ba02e-bac6-4c45-83a0-7f0d3104922e`). Every command is read-only **except** the clearly-marked ⚠️ mutations.
> **Why the pipeline route alone won't unblock you:** your run dies at the owner check; `bypassEnvironmentOwnerValidation=true` clears that, but the run then dies at `DestroyAppConfiguration` (the 06-22 idempotency bug, still unmerged — Roel's runs prove it). So either fix the pipeline first (Option A) or do the manual teardown (Option B).

## What's required (permissions) — check these first

| Action | Role needed on | Have it? |
|---|---|---|
| Purge the Key Vault | `Key Vault Contributor` on `vpp-fbe-thor-vuo` / `rg-vpp-app-sb-401` | check |
| Release the table row | **`Storage Table Data Contributor`** on storage acct `featurebranchdeployment` | check (the on-call agent did NOT have this) |
| Delete the stale state blob | `Storage Blob Data Contributor` on storage acct `tfstatevpp` | check |

If you lack the **Storage Table Data Contributor** role, you cannot release the slot manually — request it for `featurebranchdeployment`, or go with **Option A** (pipeline) and have an owner/admin run it.

---

## Step 0 — point at Sandbox + read-only pre-flight (always run this)

```bash
az account set --subscription 7b1ba02e-bac6-4c45-83a0-7f0d3104922e   # Sandbox — never trust the default sub
az account show --query name -o tsv                                   # expect: Eneco Cloud Foundation - Sandbox-Development-Test

# confirm the old 403 can't recur (no cert can capture a secret):
az keyvault certificate list --vault-name vpp-fbe-thor-vuo -o tsv                       # expect: empty
az keyvault secret list --vault-name vpp-fbe-thor-vuo --query "[?managed].name" -o tsv  # expect: empty

# confirm what's actually left:
az resource list -g rg-vpp-app-sb-401 --query "[?contains(name,'thor')].{n:name,t:type}" -o table
#   expect: ONLY vpp-fbe-thor-vuo (Key Vault) + the 'Failure Anomalies - vpp-insights-fbe-thor' smart-detector alert
```

If the certificate list is NOT empty, stop — delete the cert first (`az keyvault certificate delete`) or the original 403 returns.

---

## Option B — break-glass manual teardown (fastest self-unblock)

Run after Step 0. The minimum to **free the slot** is Step B2; B1/B3 finish the teardown so the next `thor` create is clean.

### B1 ⚠️ Delete + purge the Key Vault (one-way door — purge is irreversible; safe: this per-FBE vault is a copy sink, nothing reads from it)

```bash
az keyvault delete --name vpp-fbe-thor-vuo
az keyvault purge  --name vpp-fbe-thor-vuo          # purge-protection is OFF, so the name becomes reusable
```

### B2 ⚠️ Release the slot in the tracking table (this is the part that un-assigns it — UPDATE, never delete the row)

```bash
# 1) get the row's PartitionKey + RowKey (do NOT guess them):
az storage entity query --account-name featurebranchdeployment --auth-mode login \
  --table-name featurebranchenvdetails --filter "env eq 'thor'" \
  --query "items[].{PartitionKey:PartitionKey,RowKey:RowKey,active:active,createdby:createdby}" -o json

# 2) merge it to unused/empty owner (substitute <pk> <rk> from step 1):
az storage entity merge --account-name featurebranchdeployment --auth-mode login \
  --table-name featurebranchenvdetails \
  --entity PartitionKey=<pk> RowKey=<rk> active=unused createdby='' branch=''
```

### B3 ⚠️ Clean the stale Terraform state so the next `thor` create starts fresh

```bash
az storage blob delete --account-name tfstatevpp --container-name tfstate --auth-mode login --name 'terraform.thor'
az storage blob delete --account-name tfstatevpp --container-name tfstate --auth-mode login --name 'thor.appconfig.tfstate'
# (leave tfstate.thor — it's an unrelated 2024 legacy blob)
```

### B4 (optional) delete the cosmetic orphan alert

```bash
az resource delete -g rg-vpp-app-sb-401 --resource-type microsoft.alertsmanagement/smartDetectorAlertRules \
  --name 'Failure Anomalies - vpp-insights-fbe-thor'
```

---

## Option A — fix the pipeline, then re-run (durable; also restores auto-cleanup)

1. In repo **Myriad - VPP**, branch `development`, file `azure-pipeline-fbe-del.yml`: add the idempotency guard so `DestroyAppConfiguration` skips cleanly when the App Config store is already gone, and give `DestroyInfra` an explicit `dependsOn` + `in(...,'Succeeded','Skipped')` condition. Exact YAML is in [`../2026_06_22_004_tiago_thor_fbe_failed_deletion/quick-fix.md`](../2026_06_22_004_tiago_thor_fbe_failed_deletion/quick-fix.md) (Option A).
2. Re-run **Feature Branch Environment - Delete** (pipeline `2629`) for `environment=thor` with **`bypassEnvironmentOwnerValidation=true`** (you're not the original `createdby`).
3. This clears both walls → finishes the KV destroy → releases the slot, and fixes every future stuck slot.

---

## Witness success (check STATE, not a green build)

```bash
# 1) slot freed (the actual goal) — needs Storage Table Data Reader:
az storage entity query --account-name featurebranchdeployment --auth-mode login \
  --table-name featurebranchenvdetails --filter "env eq 'thor'" --query "items[0].active"
#    MUST be: "unused"

# 2) KV gone:
az keyvault show --name vpp-fbe-thor-vuo            # MUST be: NotFound

# 3) no leftovers:
az resource list -g rg-vpp-app-sb-401 --query "[?contains(name,'thor')]" -o table   # at most the smart-detector alert
```

A green pipeline is NOT proof — the slot-release step is conditional. The row reading `unused` is the only real success signal.
