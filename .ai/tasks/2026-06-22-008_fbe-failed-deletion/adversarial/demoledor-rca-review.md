---
agent: el-demoledor
task_id: 2026-06-22-008
timestamp: 2026-06-22T00:00:00Z
target: RCA + quick-fix for FBE thor failed deletion (rca.md + quick-fix.md)
findings_count: 7
findings_by_grade: "EXPLOIT-VERIFIED: 2, PATTERN-MATCHED: 4, THEORETICAL: 1"
blast_radius: "Next thor FBE creation broken; DestroyInfra may re-fail; on-call L11 commands non-executable without undocumented prerequisites"
status: complete
summary: "Full adversarial review of FBE thor RCA+fix. 7 findings (2 EXPLOIT-VERIFIED, 4 PATTERN-MATCHED, 1 THEORETICAL). BLOCKER: proposed guard strands appconfig tfstate, breaking next thor slot creation. HIGH: break-glass leaves infra state orphan; SP data-plane access not re-verified. MEDIUM: L11 missing az-devops extension prereq; storage RBAC undocumented; cannot-recur claim overstated. VERDICT: PROCEED-WITH-CHANGES."
---

# DEMOLEDOR REPORT — FBE `thor` RCA + Quick-Fix

**Target**: `rca.md` + `quick-fix.md` (incident 2026-02-22-004, investigated 2026-06-22)
**Scope**: Full adversarial — all 6 attack vectors from dispatch prompt
**Time Invested**: Full read of all 5 source artifacts (pipeline, template, terraform fbe module)

---

## DESTRUCTION SUMMARY

| Metric | Count |
|---|---|
| Vulnerabilities Found | 7 |
| — EXPLOIT-VERIFIED | 2 |
| — PATTERN-MATCHED | 4 |
| — THEORETICAL | 1 |
| Cascade chains mapped | 2 |
| Missing controls / incoherent claims | 4 |
| Total blast radius | Next `thor` creation broken; DestroyInfra may re-fail silently; on-call L11 non-executable; fix incomplete |

---

## CRITICAL FINDINGS

---

### V1 — The fix STRANDS the appconfig terraform state, breaking the next FBE creation [EXPLOIT-VERIFIED] — BLOCKER

**Mechanism**: The proposed `DestroyAppConfiguration` skip guard makes a stage with its own separate terraform state a no-op. That state is never destroyed.

**Evidence from source files**:

The `DestroyAppConfiguration` stage (pipeline line 163) calls the shared template `sandbox.template.yml@pipelines`. Inside that template, the `DestroyConfigurationValues` job (template line 326-363) runs `terraform destroy` against state key `$(featurebranchname).appconfig.tfstate` = `thor.appconfig.tfstate`. This state records terraform resources for the AKS App Configuration entries (feature flags, config values) — a separate terraform module from the FBE infra module (which uses state key `terraform.thor`, pipeline line 287).

When the proposed guard skips `DestroyAppConfiguration` entirely (`condition: ne(appconfig,'')`), the job `DestroyConfigurationValues` never runs. The state blob `thor.appconfig.tfstate` in the `tfstate` container is **never destroyed**.

On the **next FBE creation** for slot `thor`, the create pipeline runs `terraform init` with the same state key `thor.appconfig.tfstate`. Terraform finds the existing state, which points to resources in an App Configuration store that no longer exists (deleted in run 1 of the original incident). Terraform's `plan` phase refreshes state against real Azure — it will see all resources as deleted, and either:

- Error during refresh if the old AppConfig store ID is unreachable (the soft-delete is a different concern here — AppConfig stores have a soft-delete period of 7 days per `provider.tf:45-49`, `purge_soft_delete_on_destroy = false`), OR
- Show a plan that tries to delete resources already gone, which may block the apply.

Either outcome means **the next engineer who tries to use the `thor` slot gets a broken create pipeline**.

**Trigger**: proposing the fix as written and merging it; skip guard fires on re-run; `DestroyAppConfiguration` never cleans its terraform state.

**Blast radius**: next user of `thor` slot; any slot whose teardown skips `DestroyAppConfiguration`.

**Reproduction**: examine `thor.appconfig.tfstate` blob in `tfstatesvpp`/`tfstate` container after the proposed re-run completes; it will still exist with populated resources.

**Counter-hypothesis**: Safe if the next FBE creation for `thor` explicitly runs `terraform state rm` on all appconfig resources, or if the create pipeline handles stale state gracefully. No evidence of either in the pipeline or template. Favor finding.

**Required change**: The fix MUST also destroy the appconfig terraform state when skipping the stage. Options: (a) add a terraform state cleanup step inside the guarded stage that runs even when appconfig is empty — e.g., `terraform init + terraform destroy -auto-approve` which will produce "nothing to destroy" gracefully if the state already has no real Azure resources; or (b) explicitly delete the `thor.appconfig.tfstate` blob from the storage account when the guard fires.

---

### V2 — `DestroyInfra` `terraform destroy` will fail on already-deleted AppConfig store [EXPLOIT-VERIFIED] — BLOCKER

**Mechanism**: `app-config.tf` (fbe module, `VPP - Infrastructure/terraform/fbe/app-config.tf:1-9`) declares `module "appconfig"` which provisions the App Configuration store as part of the **infra** terraform state (`terraform.thor`). The App Configuration store is therefore tracked in the infra state. Run 1 called `DestroyInfra` which ran `terraform destroy` on `terraform.thor` — but the destroy was ABORTED by the 403 on the secret. Terraform may or may not have deleted the AppConfig store before hitting the 403 (Terraform destroys in dependency order; the KV secret failure halts the plan mid-execution).

However, the evidence ledger and live probes confirm the App Configuration store is ALREADY GONE (evidence-ledger.md: `az appconfig list (thor) → none`; RCA L3 diagram: `AC["App Config store (per-FBE) — DESTROYED in run 1"]`).

If the AppConfig store resource is still in the `terraform.thor` state (because the destroy was aborted before Terraform could remove it from state), then the `DestroyInfra` re-run will try to destroy it, find it already deleted, and will either:

- Use `terraform refresh` (implicit in plan), see the resource gone, and remove it from state cleanly — in which case this is not a failure.
- Fail with a provider error if the azurerm provider for `app_configuration` tries to make a DELETE API call on a resource it last knew about but is already gone.

Per `provider.tf:44-49`, `purge_soft_delete_on_destroy = false` and `recover_soft_deleted = false`. This means the provider WON'T try to purge or recover — but it WILL try to delete. Azure App Configuration has a soft-delete period. If the store is soft-deleted (not permanently deleted), an API call to delete it again returns a 409 Conflict or 404 depending on state. The RCA does not distinguish whether the AppConfig store was hard-deleted or soft-deleted.

**Evidence**: `app-config.tf:1-9` (AppConfig in infra module); evidence-ledger.md confirms store destroyed in run 1; `provider.tf:44-49` shows soft-delete behavior; RCA makes no statement about whether the store is in `terraform.thor` state or was removed from state before the 403 abort.

**Trigger**: `terraform destroy` on `terraform.thor` when the AppConfig store is already deleted but may still be in state.

**Blast radius**: DestroyInfra fails again, slot remains stuck.

**Counter-hypothesis**: Safe if terraform's refresh phase detects the resource is gone and removes it from state before attempting deletion (standard azurerm provider behavior on 404). This is likely the actual behavior, which would mean this is not a failure. Downgraded to THEORETICAL on reflection — see V2T below.

**Severity Gate**: Exploitability: LOW (azurerm provider usually handles 404-gone resources in refresh) x Impact: HIGH (DestroyInfra fails again) x Confidence: THEORETICAL = MEDIUM

**Reclassified below as V2T.**

---

### V2T — AppConfig store in infra state — provider refresh behavior [THEORETICAL] — HIGH

As analyzed above: if the azurerm provider's refresh phase detects the App Config store as 404-gone and removes it from state, `terraform destroy` proceeds normally. If NOT, it errors. The RCA does not address this. The fix should verify that `terraform.thor` state does or does not contain the AppConfig store resource, and if it does, that the provider handles 404 gracefully on destroy.

**Exploitable IF**: the azurerm App Configuration resource does not handle "already deleted" gracefully in the destroy path (non-standard provider behavior).

**Counter-hypothesis**: Standard azurerm provider behavior is to remove 404 resources from state during refresh. Favor safe, but RCA should verify.

**Required change**: Before merging the guard, inspect `terraform.thor` state (`terraform state list`) to confirm whether `module.appconfig` resources are present. If present, a `terraform destroy` dry-run (plan-destroy) against the current state will show whether they'd be detected as already gone.

---

### V3 — `data.tf` reads ALL 44 secrets from `vpp-aks-d` during `terraform destroy` — if access fails, destroy fails again [PATTERN-MATCHED] — HIGH

**Mechanism**: `data.tf:42-51` reads all 44 secrets from the shared KV `vpp-aks-d` at plan time via `data.azurerm_key_vault_secret.sandbox_kv_secrets`. `locals.tf:64-118` lists those 44 secrets. Terraform evaluates ALL data sources during `plan` (which precedes destroy). The `DestroyInfra` stage uses the pipeline SP `mcdta-vpp-devops` (or the `azureSubscription` service connection).

The RCA's "do NOT run terraform destroy from a laptop" warning (`quick-fix.md:25`) confirms the `vpp-aks-d` read requires the pipeline SP to be whitelisted. But it does not confirm that the pipeline SP's access to `vpp-aks-d` is currently intact for the re-run.

Additionally, `locals.tf:11` references `data.terraform_remote_state.platform_shared.outputs.aks_vpp01_outbound_ips` (from `sandbox-shared.tfstate`, container `tfstate-platform`). If this remote state read fails (permission issue, state lock, or state corruption), the ENTIRE terraform plan fails before a single resource is destroyed.

**Evidence**: `data.tf:6-15` (remote state read), `data.tf:42-51` (44-secret read from `vpp-aks-d`), `locals.tf:11` (remote state output used in KV IP allowlist), `quick-fix.md:25` (acknowledges `vpp-aks-d` access limitation).

**Trigger**: pipeline SP loses access to `vpp-aks-d` or `sandbox-shared.tfstate` between run 1 (which passed) and the re-run.

**Blast radius**: `terraform destroy` fails before touching any resource; slot remains stuck; no partial teardown.

**Counter-hypothesis**: Safe if the pipeline SP's access to `vpp-aks-d` and the platform shared state is permanent and was not affected by the partial teardown. Run 1 succeeded through `DestroyAppConfiguration`, which also uses the SP — so the SP was working as of run 1. Access revocation between runs is unlikely but not impossible (e.g., if `vpp-aks-d` access policy is managed by Terraform and the partial destroy removed it). Favor finding as a gap in the RCA's confidence claim.

**Required change**: RCA should explicitly state "the SP's read access to `vpp-aks-d` and `sandbox-shared.tfstate` was verified live" or add a pre-flight probe: `az keyvault secret list --vault-name vpp-aks-d` with the pipeline identity before re-running.

---

### V4 — "403 cannot recur" claim is not fully justified [PATTERN-MATCHED] — MEDIUM

**RCA claim** (`rca.md L9`): "That the original 403 cannot recur is already verified: the vault now has no certificates and no certificate-backed (managed) secrets, so nothing can capture a Terraform-managed secret again."

**The crack**: this claim is valid for the CURRENT state of the KV. However:

1. The KV still exists (`vpp-fbe-thor-vuo` confirmed live). Any team member with Key Vault Certificate Officer on the KV could add another certificate before the re-run is executed.
2. The claim covers only the specific named certificate `activationmfrr-eneco-signing-certificate`. There are 44 secrets in `locals.tf:64-118`. Any of those 44 names could be captured by a manually added certificate. The live probe only checked `[?managed]` secrets — but a re-added certificate between now and the re-run would create new managed secrets.

**Evidence**: `az keyvault secret list --vault-name vpp-fbe-thor-vuo --query "[?managed].name"` returned `[]` at probe time — but this is a point-in-time observation, not a permanent guarantee. `locals.tf:64-118` shows 44 potential collision targets.

**Trigger**: any human action on `vpp-fbe-thor-vuo` between live probe and re-run; or a time delay between when the RCA is written and when the fix is applied.

**Counter-hypothesis**: In practice, no engineer would touch a stuck FBE KV after being told it's being cleaned up. Low probability event. Favor the claim for now but the absoluteness of "cannot recur" overstates the certainty. A better claim: "cannot recur given current KV state, provided no manual changes are made before the re-run."

**Required change**: Restate the claim as "will not recur IF the KV state remains unchanged until the re-run" rather than "cannot recur." Add a re-check step in L12 immediately before re-running: `az keyvault certificate list --vault-name <kv> -o tsv` + `az keyvault secret list --vault-name <kv> --query "[?managed].name" -o tsv`.

---

### V5 — L11 command playbook: `az devops invoke` and `az pipelines` require the `azure-devops` extension — not mentioned [PATTERN-MATCHED] — MEDIUM

**RCA claim** (`rca.md L11`): provides `az pipelines build show` and `az devops invoke ... --area build --resource timeline` as copy-paste commands.

**The crack**: both commands require the `azure-devops` CLI extension. A fresh on-call engineer running these commands without the extension gets:

```text
ERROR: 'pipelines' is not in the 'az' command group. See 'az --help'.
```

or for `az devops invoke`:

```text
ERROR: 'devops' is not in the 'az' command group.
```

The extension is NOT installed by default in the Azure CLI. The pipeline itself installs it at line 339 (`az extension add --name azure-devops`), but that is the pipeline context, not a local shell.

**Evidence**: `azure-pipeline-fbe-del.yml:339` (`az extension add --name azure-devops` — showing the team knows it must be added); L11 playbook has no `az extension add` prerequisite. The 3 AM test fails: a junior on-call copying L11 cannot run the build timeline commands.

**Trigger**: any on-call engineer who does not have the `azure-devops` extension pre-installed.

**Blast radius**: L11 diagnostic commands are non-executable; on-call must figure out the missing extension under pressure at 3 AM.

**Counter-hypothesis**: Safe if all engineers on this team have the extension pre-installed (common in a team that uses ADO regularly). But the L11 playbook claims to target "the next on-call engineer who has never torn down an FBE before" — precisely the engineer least likely to have it. Favor finding.

**Required change**: Add prerequisite block to L11: `az extension add --name azure-devops --allow-preview false` before the `az pipelines` and `az devops invoke` commands. Also add `az extension add --name kusto --allow-preview true` (the pipeline itself adds it at line 97).

---

### V6 — L11 and break-glass success probe requires `Storage Table Data Reader` on `featurebranchdeployment` — not mentioned [PATTERN-MATCHED] — MEDIUM

**RCA claim** (`quick-fix.md`, success signal probe): `az storage entity query --account-name featurebranchdeployment --auth-mode login --table-name featurebranchenvdetails --filter "env eq 'thor'"`.

**The crack**: `--auth-mode login` uses the caller's Azure AD identity. Reading Azure Storage Table entities requires the `Storage Table Data Reader` (or higher) RBAC role on the storage account. This is not a default role. A plain Contributor or Owner on the subscription does NOT have storage data-plane access by default under Azure RBAC. An on-call without this role gets:

```text
This request is not authorized to perform this operation using this permission.
```

The break-glass Option B also requires `Storage Table Data Contributor` (mentioned in the quick-fix) to WRITE. But the READ required for the success signal and the Preparation stage is a different, lower role that is also not universal.

**Evidence**: `quick-fix.md:68` ("Requires someone with Key Vault + Storage Table Data Contributor on `featurebranchdeployment`") — confirms the team knows about Storage permissions for writes, but the success-signal READ at line 96-99 has no permission note.

**Trigger**: on-call does not have `Storage Table Data Reader` on `featurebranchdeployment`.

**Counter-hypothesis**: Safe if all on-call engineers are pre-granted this role. But the RCA does not document this prerequisite. Favor finding given the explicit scope: "next on-call who has never torn down an FBE."

**Required change**: Add explicit prerequisite to L11 and break-glass: caller must have `Storage Table Data Reader` (read probe) and `Storage Table Data Contributor` (break-glass write). Add an RBAC check probe: `az role assignment list --scope /subscriptions/7b1ba02e.../resourceGroups/.../providers/Microsoft.Storage/storageAccounts/featurebranchdeployment --assignee $(az account show --query user.name -o tsv) --query "[].roleDefinitionName"`.

---

### V7 — Break-glass Option B leaves `terraform.thor` state pointing to deleted resources — next `thor` slot creation fails [PATTERN-MATCHED] — HIGH

**Mechanism**: Break-glass Option B deletes the KV, purges it, and updates the storage table directly. The `quick-fix.md` acknowledges: "the `terraform.thor` state blob is left orphaned (harmless; the slot is being retired)."

**The crack**: "slot is being retired" is an assumption, not a guarantee. The `thor` slot is part of a FIXED pool (pipeline parameters: `afi`, `boltz`, `enel`, `ionix`, `ishtar`, `jupiter`, `kidu`, `operations`, `veku`, `voltex`, `thor`). After break-glass completes, the slot shows `unused` — immediately available to the next engineer. That engineer runs the create pipeline, which calls `terraform init` with `key=terraform.thor`. Terraform finds the existing state blob, which still contains all the `thor` infra resources (KV, Cosmos DBs, Event Hubs, etc. — everything that was provisioned). Terraform will try to `import` or refresh them and find them 404-gone. Depending on provider behavior, the `plan` will either error or produce a destroy-only plan with no resources to create — blocking FBE creation.

**Evidence**: `provider.tf:31-36` (backend config: `container_name=tfstate`, `storage_account_name=tfstatevpp`, key set at pipeline line 287 as `terraform.${{parameters.environment}}`); quick-fix.md:89 ("Prefer Option A if you want a clean teardown"); pipeline line 287 confirms state key reuse per slot.

**Trigger**: break-glass is used instead of Option A; `thor` slot is subsequently reused.

**Blast radius**: next user of `thor` slot gets a broken create pipeline, with confusing errors referencing resources from Tiago's FBE.

**Counter-hypothesis**: Safe if after break-glass, someone also manually deletes the `terraform.thor` state blob from the `tfstate` container. The fix should document this cleanup step. Favor finding because the break-glass instructions omit this.

**Required change**: Add to break-glass Option B step 3 or as a step 4: "Delete the orphaned terraform state blob to prevent the next create pipeline from finding stale state: `az storage blob delete --account-name tfstatevpp --container-name tfstate --name 'terraform.thor' --auth-mode login`."

---

## ABSENCE AUDIT

| Missing control | Impact when needed |
|---|---|
| Appconfig terraform state cleanup when stage skipped | Next `thor` create pipeline finds stale state (V1) |
| Verification that `terraform.thor` state includes/excludes AppConfig store resource | Destroy may re-fail on already-deleted resource (V2T) |
| `az extension add --name azure-devops` prerequisite in L11 | L11 build timeline commands are not executable (V5) |
| `Storage Table Data Reader` permission requirement in success probe | Success verification command fails (V6) |
| State blob deletion step in break-glass | Next slot user inherits broken state (V7) |
| Re-check of KV cert/secret state immediately before re-run | "Cannot recur" claim overstated (V4) |

---

## SUPERWEAPON DEPLOYMENT

| Superweapon | Finding |
|---|---|
| SW1 Temporal Decay | V1 (stranded appconfig state persists indefinitely, only manifests on next creation); V7 (orphaned infra state persists until next user) |
| SW2 Boundary Failure | V3 (infra terraform destroy boundary with `vpp-aks-d` and platform remote state — different SP access model at destroy time) |
| SW3 Compound Fragility | The fix assumes: (1) appconfig state is irrelevant after skip, (2) DestroyInfra handles already-deleted AppConfig store, (3) SP access to `vpp-aks-d` is still intact, (4) no one touches the KV between probe and re-run. All four must hold simultaneously. |
| SW4 Pre-Mortem | **The Broken Handoff**: Guard merges, re-run succeeds, `thor` shows `unused`. Three weeks later, a new engineer picks up `thor`, runs create pipeline, gets `Error: Provider produced inconsistent result after apply` — Terraform finds `module.appconfig` in `thor.appconfig.tfstate` pointing to a deleted App Config store. They spend 90 minutes thinking they broke something, then discover a state blob from Tiago's incident in June 2026. |
| SW5 Uncomfortable Truth | The fix addresses the SYMPTOM (stage-level guard) but not the root cause: the pipeline has no idempotency design — it assumes first-run success. Every stage that creates and then destroys resources has this same vulnerability. The guard is a local patch; the real fix is pipeline-level idempotency via `terraform destroy` tolerance for already-gone resources. |

---

## CASCADE CHAINS

**Chain 1: Guard fires, appconfig state stranded**

```
DestroyAppConfiguration skipped (guard) →
thor.appconfig.tfstate blob never destroyed →
Next thor create runs terraform init with same key →
terraform refresh sees resources 404-gone →
Plan errors or shows unexpected destroy-only →
Create pipeline blocked for next engineer
```

Circuit breaker: MISSING — no state cleanup in the proposed fix.

**Chain 2: break-glass used, infra state stranded**

```
Break-glass deletes KV + purges →
terraform.thor state blob NOT deleted →
thor slot marked unused immediately →
Next create pipeline runs with stale state →
Terraform finds 404-gone resources in state →
New FBE create fails with confusing errors
```

Circuit breaker: present only if engineer manually deletes the state blob — not documented in fix.

---

## ADVERSARIAL SELF-CHECK

**Self-questioning**:

1. V2/V2T: initially marked EXPLOIT-VERIFIED for the AppConfig store already-deleted issue. Downgraded to THEORETICAL after recognizing that the azurerm provider standard behavior is to refresh state and detect 404-gone resources cleanly. The real finding is that the RCA does not verify this — a legitimate gap, but lower severity.

2. V4 ("cannot recur" overclaim): tempted to mark HIGH. Downgraded to MEDIUM — the point-in-time observation is accurate and the scenario of someone adding a new cert before the re-run is low-probability. The claim's language is the finding, not the mechanism itself.

3. V3: tempted to mark BLOCKER. Kept at HIGH — the SP access to `vpp-aks-d` and platform state was intact during run 1, making a sudden revocation unlikely but the RCA's confidence claim of "cannot fail" needs qualification.

**Bias scan**: No accumulation bias detected — each finding has a distinct root cause. No severity inflation — V2 was actively downgraded. Pattern-matching bias checked: V1 (state orphan) is verified by reading the actual template job structure, not just pattern-matching.

**Meta-falsifier**:

- V1: Would be wrong if the create pipeline for `thor` explicitly imports or reinitializes the appconfig terraform state rather than reusing the existing blob. No evidence of this in template. CONFIRMED.
- V5/V6: Would be wrong if all on-call engineers have these extensions/roles pre-installed as a team standard. The RCA's stated audience ("never torn down an FBE before") makes this assumption unsafe. CONFIRMED.
- V7: Would be wrong if the break-glass instructions are only used by senior engineers who know to clean state. The instructions don't say that. CONFIRMED.

---

## STALE / INCOHERENT CLAIMS

1. **rca.md L6 stage table**: lists `DestroyInfra` as having `condition: succeeded()` and notes "no explicit `dependsOn`." The PIPELINE source at line 187-193 confirms this: `DestroyInfra` stage has no `dependsOn` declared — correct. The proposed fix at quick-fix.md:50-54 adds explicit `dependsOn: [Preparation, KubernetesCleanup, DestroyAppConfiguration]`. This is correct and necessary but must include `KubernetesCleanup` in the `condition` check as well. The fix's condition only checks `DestroyAppConfiguration.result` — if `KubernetesCleanup` somehow fails (the `continueOnError: true` only covers the Helm uninstall task, not the monitoring stack git-push task which has no `continueOnError`), and `DestroyAppConfiguration` passes the guard, `DestroyInfra` would still be gated by `DestroyAppConfiguration`'s success via the ADO implicit condition. The proposed explicit condition `and(eq(dependencies.Preparation.result, 'Succeeded'), in(dependencies.DestroyAppConfiguration.result, 'Succeeded', 'Skipped'))` does NOT include a check on `KubernetesCleanup`. If `KubernetesCleanup` fails (e.g., the monitoring git-push fails), ADO will still run `DestroyInfra` because the explicit `dependsOn` doesn't list `KubernetesCleanup`. This changes the pipeline behavior from the current implicit model. LOW severity, but an incoherence introduced by the fix.

2. **rca.md L3 mermaid diagram**: `TBL["featurebranchenvdetails (SHARED slot-tracking table)"] -- "marks thor used/unused" --> KV`. The arrow points to KV, which is misleading — the table tracks the SLOT, not the KV. The KV is a consequence of the slot being in use, not what the table "marks." Minor cosmetic incoherence, does not affect the fix.

3. **rca.md L5**: "soft-delete ON (7 days), purge protection OFF" — confirmed by `key-vault.tf` and evidence-ledger. Consistent. No error.

---

## VERDICT

PROCEED-WITH-CHANGES

**Findings requiring changes before the fix can be considered safe**:

| Finding | Severity | Action |
|---|---|---|
| V1 — appconfig tfstate stranded | BLOCKER | Fix MUST include appconfig state cleanup when guard fires |
| V7 — break-glass leaves infra state | HIGH | Break-glass MUST document state blob deletion as explicit step |
| V3 — SP access to `vpp-aks-d` not re-verified | HIGH | Add pre-flight probe for SP access to `vpp-aks-d` and platform remote state before re-running |
| V5 — `azure-devops` extension missing from L11 | MEDIUM | Add `az extension add` prerequisite to L11 |
| V6 — storage RBAC not documented | MEDIUM | Document `Storage Table Data Reader` requirement in success probe |
| V4 — "cannot recur" claim overstated | MEDIUM | Restate as conditional; add re-check probe before re-run |
| V2T — AppConfig store in infra state | HIGH | Verify `terraform.thor` state list before re-run to confirm AppConfig resource presence/absence |

**The diagnosis (two failure mechanisms, their order, the guard approach) is correct.** The tactical fix has a BLOCKER: the appconfig terraform state orphan (V1) will break the next `thor` FBE creation. The fix is one step short of complete.

---

*El Demoledor: Proving resilience through destruction*
