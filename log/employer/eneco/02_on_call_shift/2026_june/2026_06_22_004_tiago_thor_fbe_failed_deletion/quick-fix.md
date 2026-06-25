# Quick Fix — FBE `thor` stuck deletion

> **Confidence**
> - **Diagnosis & current state: verified** (live `az` probes + ADO logs + IaC + Terraform-state blob inspection, cited below).
> - **The original blocker is already cleared** — the certificate and its backing secret are gone; the `SecretManagedByKeyVault` 403 cannot recur *as long as no certificate is re-imported* (re-check it immediately before re-running — see Pre-flight).
> - **The unblock requires one human action** (a small pipeline change + re-run, OR an authorized break-glass). I cannot execute or witness it for you (the env-release needs Storage **Table** write permission, which my account lacks). Treat success by the **witness signal**, not a green build.

---

## TL;DR

`thor` failed to delete for **two different reasons**, in sequence:

1. **Run 1** (`1683298`): a certificate `activationmfrr-eneco-signing-certificate` in KV `vpp-fbe-thor-vuo` captured the Terraform-managed secret of the same name → `terraform destroy` → `DeleteSecret` 403 `SecretManagedByKeyVault`. (The certificate was added outside Terraform — most likely by hand.)
2. You deleted that certificate (✅ correct — now verified gone). **Run 2** (`1683370`) then failed *earlier* for a *new* reason: the **delete pipeline is not idempotent**. The App Configuration store was already destroyed in run 1, so `Get Feature Flags from Azure AppConfig` ran `az appconfig feature list -n <empty>` → `argument --name/-n: expected one argument` → exit 1, **before reaching the Terraform-destroy stage**.

`thor` is now ~90% destroyed. Only the **Key Vault** + an App-Insights smart-detector alert remain, and the slot still shows **"assigned to you"** because run 1 never reached the pipeline's **"Release environment"** step.

**Verified Terraform-state facts (from the `tfstatevpp/tfstate` container):** the infra state `terraform.thor` is **full (313 KB, last written at the run-1 403)** — infra teardown is genuinely incomplete; the App-Config state `thor.appconfig.tfstate` is **already empty (184 B, destroyed at 07:12 in run 1)** — so skipping the App-Config stage on a re-run strands nothing.

---

## Do NOT do these (verified to fail / unsafe)

- ❌ **Re-run the whole pipeline unchanged** — fails again at `DestroyAppConfiguration` (empty AppConfig name). Verified by build `1683370`.
- ❌ **"Stages to run → DestroyInfra only"** — ADO **cascade-skips** it. `DestroyInfra` has no explicit `dependsOn` and no stage-level `condition`, so ADO applies the *default stage condition* `succeeded()`; its implicit predecessor `DestroyAppConfiguration` is *Skipped*, *Skipped ≠ Succeeded*, so `DestroyInfra` is skipped too. (The `condition: succeeded()` at `:193` is a **job** guard — it never even gets evaluated.) The run goes green and changes nothing.
- ❌ **`terraform destroy` from a laptop** — the FBE module reads **49** secrets from the shared KV `vpp-aks-d` (`data.tf:42-51`, `locals.tf:64-118`) *and* a shared `terraform_remote_state.platform_shared`; those reads work from the pipeline SP but may fail off-AVD, and replicating the backend/init scaffolding by hand risks state corruption.

---

## Pre-flight (run these read-only checks immediately before any unblock)

```bash
az account set --subscription 7b1ba02e-bac6-4c45-83a0-7f0d3104922e   # Sandbox — never trust default
# 1) confirm the 403 class is still dead (no cert can capture a secret):
az keyvault certificate list --vault-name vpp-fbe-thor-vuo -o tsv                       # expect: empty
az keyvault secret list --vault-name vpp-fbe-thor-vuo --query "[?managed].name" -o tsv  # expect: empty
# 2) confirm the App-Config store is really gone (why the re-run failed):
az appconfig list -g rg-vpp-app-sb-401 --query "[?contains(name,'thor')].name" -o tsv  # expect: empty
# 3) confirm what infra is left for the destroy to finish:
az resource list -g rg-vpp-app-sb-401 --query "[?contains(name,'thor')].{n:name,t:type}" -o table
#    expect: only vpp-fbe-thor-vuo (KV) + the smart-detector alert
```

If check (1) is NOT empty, a certificate has reappeared — delete it (`az keyvault certificate delete`) before proceeding, or the 403 returns.

---

## Recommended fix — make the delete pipeline idempotent, then re-run (Option A, cleanest teardown)

**Why:** the only path that finishes the teardown **and** performs the **env-release** (the "still assigned to me" part) is the pipeline's `DestroyInfra` stage. To reach it on a re-run, `DestroyAppConfiguration` must become a clean **success-noop** when the App-Config store is already gone — which is safe here because its Terraform state is already empty (184 B, verified).

**Change** (`Myriad - VPP` repo, `development` branch, `azure-pipeline-fbe-del.yml`). Use the pipeline's existing `stageDependencies` idiom (the stage already pulls `appconfig` that way at `:168-171`), and guard at the **job** level — a job `condition` is evaluated after stage variables resolve:

```yaml
- stage: DestroyAppConfiguration
  dependsOn: [Preparation, KubernetesCleanup]
  variables:
    appconfig: $[ stageDependencies.Preparation.Environment.outputs['DetermineEnvironment.appconfig'] ]
    # (kefeaturebranchname/keyvaultname/adxname as today)
  jobs:
    - job: DestroyAppConfig
      condition: ne(variables['appconfig'], '')   # NEW: skip cleanly when the store is already gone
      # ... existing template invocation moves under this job ...
```

> The existing stage invokes the shared template directly under `jobs:`. The minimal-diff alternative, if you don't want to restructure the template call into a `- job:`, is a one-line **bash guard as the first step** of the App-Config job: `if [ -z "$(appconfig)" ]; then echo "store already gone — skipping"; exit 0; fi`. Either way the stage reports **Succeeded** (not Skipped). **Do NOT** use a stage-level `condition` that dereferences `dependencies.*.outputs[...]` — that expression namespace is for stage *results* (`dependencies.<Stage>.result`), not output values; the value path is `stageDependencies` and resolves cleanly only in `variables:`/job scope. Validate in a throwaway run before merging.

Then let `DestroyInfra` run after a *Succeeded* (or, defensively, *Skipped*) App-Config stage by giving it an explicit dependency + condition (it currently has neither):

```yaml
- stage: DestroyInfra
  dependsOn: [Preparation, KubernetesCleanup, DestroyAppConfiguration]
  condition: >-
    and(eq(dependencies.Preparation.result, 'Succeeded'),
        in(dependencies.DestroyAppConfiguration.result, 'Succeeded', 'Skipped'))
  # NOTE: KubernetesCleanup is intentionally NOT in the result-check — its Helm step is
  #       continueOnError:true (:115), so its failure is non-fatal to the teardown goal.
```

Finally, re-run **Feature Branch Environment - Delete** with `environment=thor` (set `bypassEnvironmentOwnerValidation=true` if you are not the original `createdby`, `:75-77`).

A broader alternative is to guard the `az appconfig feature list` call inside the shared template `Eneco.Pipelines/azure-appconfiguration/sandbox.template.yml:118-124`, but that template is shared with the create/apply path — higher blast radius. Prefer the pipeline-local guard above.

---

## Break-glass (Option B) — fastest certain unblock if a pipeline change can't wait

Fully deterministic; requires **Key Vault** + **Storage Table Data Contributor** + **Storage Blob Data Contributor** on the Sandbox sub. After the Pre-flight checks above:

```bash
# 1) Delete + purge the last real resource (KV). Purge so the slot name is reusable
#    (7-day soft-delete, purge protection OFF).
az keyvault delete --name vpp-fbe-thor-vuo
az keyvault purge  --name vpp-fbe-thor-vuo

# 2) Release the slot in the tracking table (this is what un-assigns it from you):
az storage entity query  --account-name featurebranchdeployment --auth-mode login \
  --table-name featurebranchenvdetails --filter "env eq 'thor'"      # get PartitionKey/RowKey
az storage entity merge  --account-name featurebranchdeployment --auth-mode login \
  --table-name featurebranchenvdetails \
  --entity PartitionKey=<pk> RowKey=<rk> active=unused createdby='' branch=''

# 3) Clean the Terraform state blobs so the NEXT 'thor' create starts fresh
#    (the infra state is still full; the appconfig state is already empty but tidy it too):
az storage blob delete --account-name tfstatevpp --container-name tfstate --auth-mode login --name 'terraform.thor'
az storage blob delete --account-name tfstatevpp --container-name tfstate --auth-mode login --name 'thor.appconfig.tfstate'
```

> Step 3 is the difference between "slot looks free" and "next `thor` create works": leaving a stale `terraform.thor` (313 KB) makes the next create pipeline `terraform init` against a state full of deleted resources. Skip step 3 only if `thor` will never be recreated. (The legacy `tfstate.thor`, 13 KB, untouched since 2024, is unrelated — leave it.)

---

## Success signal (witness this, NOT a green build)

1. **Env un-assigned** (the actual ask) — needs `Storage Table Data Reader`:
   ```bash
   az storage entity query --account-name featurebranchdeployment --auth-mode login \
     --table-name featurebranchenvdetails --filter "env eq 'thor'" --query "items[0].active"
   # MUST be "unused"
   ```
2. **KV gone:** `az keyvault show --name vpp-fbe-thor-vuo` → NotFound (purge it if `thor` may be reused within 7 days).
3. **No leftovers:** `az resource list -g rg-vpp-app-sb-401 --query "[?contains(name,'thor')]"` → at most the smart-detector alert (cosmetic orphan; safe to delete manually).

---

## Evidence (all verified this session unless noted INFER)

- Manual cert → captured TF secret: `raw-requirements.md:21` (`SecretManagedByKeyVault` 403); IaC `key-vault.tf:26-32` (`copied_secrets`), `locals.tf:110` (in the 49-entry `secrets_to_copy`, `:64-118`), `data.tf:42-51`. The cert being added *by hand* is an inference (consistent with the owner's account + the 403 semantics; an automated add is not strictly ruled out) — but the fix depends only on the cert now being **gone**, which is verified.
- Cert + backing secret now gone: `az keyvault certificate list/list-deleted` → `[]`/`[]`; `az keyvault secret list [?managed]` → `[]`.
- Run 2 cause: ADO build `1683370` timeline → `DestroyAppConfiguration` → `Get Feature Flags from Azure AppConfig` → log `argument --name/-n: expected one argument`; template `sandbox.template.yml:118-124` runs `az appconfig feature list -n ${{ parameters.appConfigurationName }}`; name resolved empty at `azure-pipeline-fbe-del.yml:99/103`.
- State blobs (`tfstatevpp/tfstate`): `terraform.thor` 313 KB @07:36 (full), `thor.appconfig.tfstate` 184 B @07:12 (empty/destroyed).
- "Still assigned": run 1 never reached `Release environment in the Storage table` (`azure-pipeline-fbe-del.yml:319-358`, `:354`).
- KV: `az keyvault show vpp-fbe-thor-vuo` → RG `rg-vpp-app-sb-401`, softDelete on, retention 7d, purge protection off.

_Adversarially reviewed by `sre-maniac`, `socrates-contrarian`, and `el-demoledor`; the naive shortcuts were removed and the guard syntax + break-glass were corrected because the reviews proved the originals wrong. Full reviews + receipts in `.ai/tasks/2026-06-22-008_fbe-failed-deletion/adversarial/`._
