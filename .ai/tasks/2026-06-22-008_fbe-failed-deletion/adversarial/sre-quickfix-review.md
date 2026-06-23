---
task_id: 2026-06-22-008
agent: sre-maniac
timestamp: 2026-06-22T00:00:00Z
status: complete
summary: |
  Adversarial review of proposed "run DestroyInfra only" unblock for FBE thor stuck deletion.
  Lane 1 finds the proposal BREAKS under ADO implicit stage semantics — DestroyInfra has no
  explicit dependsOn but its job-level condition:succeeded() evaluates against implicit
  predecessor stages; with Preparation deselected ADO marks it Skipped not Run. Lanes 2-5
  surface additional collateral, TF state, and false-green risks. Lane 6 identifies a safer
  path that avoids all stage-selection guesswork.

---

# Adversarial Review — Proposed "DestroyInfra Only" Stage Selection

## Key Findings

- Lane 1: DestroyInfra job `condition: succeeded()` on a deselected Preparation = stage skipped, not run — **BREAKS**
- Lane 2: DestroyInfra is genuinely self-contained — no `stageDependencies` vars consumed — **HOLDS**
- Lane 3: substring delete on shared RG is RISKY — `thor` substring collision possible in `rg-vpp-app-sb-401`
- Lane 4: TF destroy of cleared cert secret — 404 on refresh is graceful (HOLDS), but `data.tf` source KV read is an unaddressed dependency (CONDITIONAL BREAK)
- Lane 5: green build does NOT guarantee full cleanup — soft-deleted KV + smart-detector orphan + table row may stay `used`
- Lane 6: safer path exists — empty-appconfig guard + full re-run (`bypassEnvironmentOwnerValidation=true`), or manual CLI destroy + table release + KV purge

**Target procedure:** Re-run "Feature Branch Environment - Delete" with `environment=thor`,
selecting ONLY stage `DestroyInfra`.

**Attacker role:** sre-maniac. Win condition: make the proposal FAIL, cause COLLATERAL, or
show it looks-successful-while-wrong.

---

## Lane 1 — Stage Graph: Will DestroyInfra actually RUN?

**VERDICT: BREAKS**

### Evidence

`azure-pipeline-fbe-del.yml` stage layout:

```text
Preparation          (line 63)   — no dependsOn (implicit: none)
KubernetesCleanup    (line 107)  — no dependsOn (implicit: depends on Preparation by ADO fan-out)
DestroyAppConfiguration (line 163) — explicit dependsOn: [Preparation, KubernetesCleanup]
DestroyInfra         (line 187)  — NO explicit dependsOn
  job DestroyInfra
    condition: succeeded()       (line 193)
Slacknotify          (line 360)  — explicit dependsOn: [Preparation, DestroyInfra]
```

`DestroyInfra` has no explicit `dependsOn` at the stage level. In ADO YAML, when a stage
omits `dependsOn`, it implicitly depends on the **immediately preceding stage** in document
order — here that is `DestroyAppConfiguration` (line 163), which itself requires
`Preparation` (lines 164-166).

ADO "Stages to run" UI behavior (A2 — ADO documented semantics, well-established):

> When you deselect an upstream stage, ADO marks it as **Skipped**. A Skipped stage is NOT
> the same as a Succeeded stage. The job-level `condition: succeeded()` at line 193
> evaluates the implicit predecessor (`DestroyAppConfiguration`). A deselected
> `DestroyAppConfiguration` → Skipped → `succeeded()` = FALSE → the DestroyInfra **job is
> also skipped, not run**.

There is a second variant of the risk: ADO may refuse to start the run at all if the
selected stage has an unresolved upstream dependency chain (depends on a deselected stage).
In either case, the DestroyInfra stage either (a) is skipped silently, or (b) the pipeline
refuses to validate. The pipeline does NOT execute DestroyInfra in isolation.

**Route change forced:** The proposal as written is invalid. You cannot select only
`DestroyInfra` and expect it to run. To make it run in isolation you would need to either
(a) add `dependsOn: []` to the stage (requires a code change), or (b) include enough
predecessor stages to satisfy the condition chain — which drags back in the broken
`DestroyAppConfiguration` stage, re-triggering the F2 non-idempotency failure.

The "self-contained" claim is true for variable inputs but false for ADO execution graph
semantics. Those are two different things.

---

## Lane 2 — Hidden Stage Dependency: Does DestroyInfra Consume Preparation Outputs?

**VERDICT: HOLDS (the self-containment claim on variables is correct)**

### Evidence

`DestroyAppConfiguration` (lines 163-185) explicitly maps `stageDependencies` outputs:

```yaml
variables:
  featurebranchname: $[ stageDependencies.Preparation.Environment.outputs['DetermineEnvironment.environmentName'] ]
  keyvaultname:      $[ stageDependencies.Preparation.Environment.outputs['DetermineEnvironment.keyvaultname'] ]
  adxname:           $[ stageDependencies.Preparation.Environment.outputs['DetermineEnvironment.adxname'] ]
  appconfig:         $[ stageDependencies.Preparation.Environment.outputs['DetermineEnvironment.appconfig'] ]
```

`DestroyInfra` (lines 187-358) has **no `variables:` block** and no `stageDependencies`
reference anywhere in its steps. Every parameter it uses is either:

- Compile-time: `${{parameters.environment}}` (lines 287-289, 299, 330, 354) — resolved at
  pipeline queue time from the UI parameter, not from Preparation output.
- Static pipeline vars: `$(azureSubscription)`, `$(azureResourceGroup)`,
  `$(aksDevClusterName)`, `$(patToken)` — from variable groups (lines 46-60), not stage
  outputs.
- Backend config key: `terraform.${{parameters.environment}}` (line 287) — hardcoded
  pattern with compile-time param.

The `$(keyvaultname)`, `$(appconfig)` etc. referenced in `DestroyAppConfiguration`
(lines 175-178) do NOT appear anywhere in `DestroyInfra` steps.

**However**, this finding only supports variable isolation. The ADO execution graph problem
(Lane 1) is orthogonal and remains fatal. Both must hold for the proposal to work; Lane 1
alone kills it.

---

## Lane 3 — Collateral Damage: Substring Delete on Shared RG

**VERDICT: RISKY**

### Evidence

Lines 297-316:

```bash
resources=$(az resource list --resource-group $resourceGroup \
  --query "[?contains(id, '$environment')].id" -o tsv \
  | grep -v smartDetectorAlertRules)

for resourceId in $resources; do
    if [[ "$resourceId" == *"$environment"* ]]; then
        az resource delete --ids "$resourceId"
    fi
done
```

`$environment` = `thor`. The filter is `contains(id, 'thor')`.

**Risk 1 — Substring collision in the current RG.**
`rg-vpp-app-sb-401` is a **shared sandbox RG** (evidence-ledger.md:12, `azureResourceGroup`
line 57). Any Azure resource whose ARM resource ID contains the string `thor` anywhere —
including in its parent resource's name, in a nested child resource path, or in a tag that
gets surfaced in the ID — will be deleted. The live probe (evidence-ledger.md:31) returned
`vpp-fbe-thor-vuo` and `Failure Anomalies - vpp-insights-fbe-thor`. The smart-detector is
excluded by `grep -v`. But:

- If any other FBE slot's resource ID contains `thor` as a substring (e.g. a slot named
  `xxthor` or `author`) — those resources are deleted with no warning.
- If a shared infra component's name includes `thor` (e.g. a namespace, a service bus
  entity, a cosmos DB collection URI containing the word) — same outcome.

**Risk 2 — No dry-run / no confirmation.**
The loop deletes immediately on first match. There is no `--dry-run` output before
destructive action. If the list is wrong, the delete is already in flight.

**Risk 3 — Sequential single-resource deletes without dependency ordering.**
`az resource delete --ids $resourceId` is called one resource at a time with no regard for
ARM dependency order. If resource B depends on resource A and A is deleted first, B's delete
may fail with a dependency error leaving partial state.

**Mitigation:** Before running, manually execute:
```bash
az resource list --resource-group rg-vpp-app-sb-401 \
  --query "[?contains(id,'thor')].id" -o tsv \
  | grep -v smartDetectorAlertRules
```
and verify the list contains only `vpp-fbe-thor-vuo` (now only the KV remains per live
probe). If the KV is already the only resource and TF destroy handles it, the az-delete
loop becomes a no-op and the risk collapses — but this must be confirmed before running,
not assumed.

---

## Lane 4 — Terraform Destroy Re-Run: State Stale Object Risk

**VERDICT: HOLDS on the cleared cert secret; CONDITIONAL BREAK on data source refresh**

### Evidence

**Cleared cert (the original F1 blocker):**
TF state still contains
`azurerm_key_vault_secret.copied_secrets["activationmfrr-eneco-signing-certificate"]`
(key-vault.tf:26-32, locals.tf:110). On `terraform destroy`:

1. TF performs a refresh. The secret no longer exists in Azure (evidence-ledger.md:30:
   `SecretNotFound`).
2. TF removes the resource from state on 404 during refresh (standard provider behavior for
   `azurerm_key_vault_secret` — 404 on read = resource gone = remove from state plan).
3. Destroy succeeds without attempting the delete. The F1 403 cannot recur.

This sub-claim HOLDS. A2 (standard azurerm provider 404 behavior — well established).

**New risk — data source read in `data.tf`:**

```hcl
data "azurerm_key_vault_secret" "sandbox_kv_secrets" {
  for_each     = toset(local.secrets_to_copy)
  name         = each.value
  key_vault_id = data.azurerm_key_vault.sandbox_kv.id  # data.tf:50
}
```

This reads **all 44+ secrets** from `vpp-aks-d` (the shared sandbox KV, data.tf:43-45)
during `terraform init`/`plan`/`destroy`. On `destroy`, Terraform still evaluates data
sources unless they have been explicitly removed or the destroy graph excludes them.

If `vpp-aks-d` has an access policy that requires the pipeline SP to be whitelisted, or if
the KV has firewall rules, this data read will fail during the destroy run — **not because
of thor's state, but because of the shared KV dependency baked into the module**. The
evidence ledger (MEMORY.md, eneco_vpp_agg_kv_topology.md) notes that firewalled KVs
require MC SP + whitelist. `vpp-aks-d` is the source KV (data.tf:43), not the `vpp-agg`
family, so firewall applicability is A3/UNVERIFIED — but the risk exists and is not
addressed in the proposed procedure.

**Second new risk — other manual objects in `vpp-fbe-thor-vuo`:**
The original F1 was caused by a manually-added certificate capturing a TF-managed secret.
`locals.tf:64-118` lists 44 secrets TF manages. If any other manual certificate or secret
was added to `vpp-fbe-thor-vuo` outside Terraform, the same 403 class of error can recur
on a different secret. The proposed procedure does not include a pre-flight check of current
KV certificate/secret inventory against the `secrets_to_copy` list.

Pre-flight check required:
```bash
az keyvault certificate list --vault-name vpp-fbe-thor-vuo -o table
az keyvault secret list --vault-name vpp-fbe-thor-vuo -o table
```
and verify no certificate name matches any entry in `locals.tf:64-118`.

---

## Lane 5 — Looks-Successful-While-Wrong

**VERDICT: REAL RISK — green build does NOT guarantee full cleanup**

### Three false-green scenarios

**FG-1: Storage table row still "used" after "Release environment" step fails silently.**

"Release environment in the Storage table" (lines 319-358) has:
```yaml
condition: succeeded()   # line 322
```
This means if the terraform destroy step (lines 277-291) or the az-delete loop
(lines 292-317) exits non-zero, the release step is **skipped**. The pipeline may still
show the destroy tasks as green (e.g. destroy exits 0 even with warnings) while the table
update is skipped. `featurebranchenvdetails` row stays `active='used'`, env stays assigned.

The witnessable success signal is NOT a green pipeline — it is:
```bash
az storage entity query \
  --account-name featurebranchdeployment \
  --auth-mode login \
  --table-name featurebranchenvdetails \
  --filter "env eq 'thor'"
| jq '.items[0].active'
# MUST return "unused"
```

**FG-2: Soft-deleted KV persists for 7 days.**
`az keyvault show --name vpp-fbe-thor-vuo` shows `softDeleteRetentionDays: 7`,
`purgeProtection: off` (evidence-ledger.md:28). When TF destroys the KV, Azure moves it to
soft-deleted state — it is not gone. The KV name `vpp-fbe-thor-vuo` is NOT reusable until
the 7-day retention expires or a manual purge is issued. If a re-create of `thor` is
attempted before purge, the FBE create pipeline will fail on KV provisioning with a
"name already in use (soft-deleted)" error. A new FBE create for `thor` within 7 days
**will break** unless `az keyvault purge --name vpp-fbe-thor-vuo` is run explicitly after
the destroy.

**FG-3: Smart-detector alert orphan.**
`Failure Anomalies - vpp-insights-fbe-thor` is excluded from the az-delete loop
(line 301 `grep -v smartDetectorAlertRules`). It is also not managed by TF (it is an
Azure Monitor auto-created resource on Application Insights provisioning — not in the FBE
TF module). After destroy it will remain in `rg-vpp-app-sb-401` indefinitely, referencing
a deleted Application Insights instance. This is cosmetic debris but will cause alert noise
if the monitoring team inspects the RG.

**True success signal checklist (minimum):**
1. `az storage entity query ... --filter "env eq 'thor'" | jq '.items[0].active'` → `"unused"`
2. `az keyvault show --name vpp-fbe-thor-vuo` → 404 (deleted) or soft-deleted state
3. `az resource list -g rg-vpp-app-sb-401 --query "[?contains(name,'thor')]"` → only
   smart-detector alert remains (all others gone)
4. `az keyvault purge --name vpp-fbe-thor-vuo` run if slot `thor` may be re-used within 7d

---

## Lane 6 — Safer Alternative

**VERDICT: YES, a safer path exists. The stage-selection shortcut is the wrong tool.**

### Root problem

The pipeline has two independent failure modes on re-run:

- F2: `DestroyAppConfiguration` fails because AppConfig is already gone → empty `$(appconfig)` → exit 1.
- The stage-selection proposal tries to paper over F2 by skipping the broken stage, but
  runs into ADO execution graph semantics (Lane 1) that prevent it from working.

### Safer path

**Option A — Explicit `bypassEnvironmentOwnerValidation=true` + template guard (preferred)**

The pipeline already has `bypassEnvironmentOwnerValidation` logic at lines 75-77. Use it
to ensure Preparation succeeds even if the row's `createdby` doesn't match the current
runner. Then fix the AppConfig non-idempotency with a guard in `DestroyAppConfiguration`
or in the referenced template:

```bash
# Guard pattern (in template or inline before az appconfig feature list):
if [ -z "$(appconfig)" ]; then
  echo "AppConfig already destroyed, skipping feature flag cleanup"
  exit 0
fi
```

With this guard: Preparation runs (resolves `$(appconfig)` to empty string, sets output),
DestroyAppConfiguration skips gracefully, DestroyInfra runs on a genuinely succeeded
predecessor chain, table release fires, Slacknotify fires. All stages execute in correct
order. No stage-selection guesswork.

The guard requires a code change to the `sandbox.template.yml@pipelines` template OR an
inline bypass in this pipeline before the template call.

**Option B — Manual table release + manual KV purge (break-glass fallback)**

If a code change cannot be made quickly:

1. Manually run TF destroy from the CLI (avoids the pipeline entirely):
   ```bash
   cd "VPP - Infrastructure/codebase/fbe"
   terraform init -backend-config=... -backend-config=key=terraform.thor
   terraform destroy -var environment=thor -auto-approve
   ```
2. Manually release the table row:
   ```bash
   az storage entity replace \
     --account-name featurebranchdeployment \
     --auth-mode login \
     --table-name featurebranchenvdetails \
     --entity PartitionKey=<pk> RowKey=<rk> branch="" createdby="" active='unused' env='thor' queue=<q>
   ```
3. Manually purge the KV:
   ```bash
   az keyvault purge --name vpp-fbe-thor-vuo
   ```

This is fully auditable, produces the same state, and has no stage-graph ambiguity. Higher
manual effort but zero uncertainty.

**Option C — Patch pipeline YAML: add `dependsOn: []` to DestroyInfra**

Adding `dependsOn: []` explicitly breaks the implicit ADO dependency and makes DestroyInfra
independently runnable. Combined with stage-selection (DestroyInfra only), this would work.
But it changes pipeline behavior for ALL future runs, not just this unblock — it means
DestroyInfra could be accidentally run before DestroyAppConfiguration in normal usage.
Higher risk than Option A.

**Recommendation:** Option A (guard in template + full re-run with bypass) or Option B
(manual CLI). Option C (YAML patch) is higher risk than stated. The proposed procedure
(stage-selection shortcut) should not ship without resolving Lane 1 first.

---

## BOTTOM LINE

The proposed "run DestroyInfra only" procedure DOES NOT SHIP as written. Lane 1 is a hard
blocker: ADO implicit stage dependency + `condition: succeeded()` means DestroyInfra is
skipped (not run) when its implicit predecessor DestroyAppConfiguration is deselected. The
proposal will produce a silently-skipped run — env stays assigned, KV stays alive, table
row stays `used`. Use Option A (empty-appconfig guard + full re-run) or Option B (manual
CLI destroy + table release + KV purge) instead.
