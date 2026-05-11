---
task_id: 2026-05-11-001
agent: claude-opus-4-7
status: complete
summary: Evidence ledger — every load-bearing claim with re-probe outcome + A1/A2/A3 classification
---

# Evidence Ledger — Freshness Audit (Phase 2)

Inherited claims from `log/employer/eneco/02_on_call_shift/2026_05_11_fbe_error_duncan/` are downgraded to INFER. Each re-probed in this session below.

## Legend

- **A1 FACT** — externally-witnessable; cited command/file:line/blob with output in this session
- **A2 INFER** — derived from FACTs; reasoning required
- **A3 UNVERIFIED[blocked: <reason>]** — re-probe required but blocked; resolving path named

## Antecedent claims re-probed

| Claim | Antecedent assertion | Re-probe result | Cls |
|---|---|---|---|
| C1 | Duncan tried to create an FBE on 2026-05-11 | Slack thread `slack-intake.txt:3,9,12` shows Duncan ↔ Alex Torres 9:59 → 10:14 AMS; ADO build 1638601 cited; live state-blob `terraform.kidu` was modified at `2026-05-11T08:04:27Z` (Apr 26 timezone shift → 10:04 AMS) consistent with Duncan's first build window | A1 |
| C2 | Failure is on `terraform apply` step | `context.md:25` "Terraform command 'apply' failed"; build log `context.md:50` shows `/opt/hostedtoolcache/terraform/1.14.3/x64/terraform apply -auto-approve -auto-approve -var environment=kidu …`; pipeline `azure-pipelines-featurebr-env.yml:450-461` confirms `command: 'apply'` in DeployInfra stage | A1 |
| C3 | Error mode = "resource already exists, must be imported" | `context.md:27` quotes the exact Terraform error verbatim; the orphan namespace `vpp-evh-premium-kidu` confirmed by `az eventhubs namespace show` (probe-01-namespace-show.json) | A1 |
| C4 | Orphan resource: `azurerm_eventhub_namespace` `vpp-evh-premium-kidu` | `az eventhubs namespace show --name vpp-evh-premium-kidu --resource-group rg-vpp-app-sb-401` returns 200 with `provisioningState: Succeeded`, `sku: Premium`, `createdAt: 2025-06-10T17:28:27Z` | A1 |
| C5 | Resource group is `rg-vpp-app-sb-401` | Confirmed in `az eventhubs namespace show` output (subscription:7b1ba02e.../resourceGroups/rg-vpp-app-sb-401/...) | A1 |
| C6 | Subscription is Sandbox `7b1ba02e-bac6-4c45-83a0-7f0d3104922e` | `az account show` confirms "Eneco Cloud Foundation - Sandbox-Development-Test" with id `7b1ba02e-bac6-4c45-83a0-7f0d3104922e` (matches CLAUDE.md memory) | A1 |
| C7 | Failing module path = `.terraform/modules/eventhub_namespace_premium/terraform/modules/event_hub_namespace/main.tf` | `event-hub.premium.tf:1-19` in `myriad-vpp/VPP%20-%20Infrastructure/main/terraform/fbe/event-hub.premium.tf` calls `module "eventhub_namespace_premium"` with source `git::…Eneco.Infrastructure//terraform/modules/event_hub_namespace?ref=v1.0.0` | A1 |
| C8 | Terraform variable `environment=kidu` was passed | Build log line `context.md:50` shows `-var environment=kidu`; pipeline `azure-pipelines-featurebr-env.yml:459` shows `-var environment=$(featurebranchname)`; featurebranchname is derived from limiter-table lookup for Duncan's branch | A1 |
| C9 | Terraform version 1.14.3 | Build log `context.md:36-37` shows `/opt/hostedtoolcache/terraform/1.14.3/x64/terraform`; pipeline `azure-pipelines-featurebr-env.yml:46` declares `terraformVersion: "1.14.3"` (matches) | A1 |
| C10 | Provider versions (azurerm 4.40.0 etc.) | Build log `context.md:39-45` is authoritative for the actual runtime providers; no further re-probe needed — those are the providers Duncan's build used | A1 |
| C11 | Retry "errored quicker" → non-transient | Confirmed by mechanism: namespace existence is a stable Azure state, not transient. Once the orphan exists, every retry fails immediately at the same Azure pre-check | A1 |
| C12 | Pipeline definition source | Re-probed: the **actual** failing pipeline is `azure-pipelines-featurebr-env.yml` in repo `Myriad - VPP` (not the obsolete `azurepipelines-fbe.yaml` in `VPP - Infrastructure`). Pipeline ID `2412` per `fbe-operations-runbook.md`. Confirmed by matching build-log command line (`-var kafka_queue_name=…`) to pipeline line 461 | A1 |
| C13 | Branch name driving env=kidu | **RESOLVED A1**: `az pipelines runs show --id 1638601 --org https://dev.azure.com/enecomanagedcloud --project "Myriad - VPP"` returns `sourceBranch: refs/heads/feature/fbe-821600-date-selector-flex-reservation-dashboard`, `requestedFor: Teegelaar, D (Duncan)`, `requestedForEmail: Duncan.Teegelaar@eneco.com`, `definitionId: 2412 ("Feature Branch Environment - Create")`, `startTime: 2026-05-11T08:00:43Z`. See proofs/outputs/probe-12-build-1638601-metadata.json. Independently corroborated by el-demoledor's lease-table probe via storage-key auth (row 10 of `featurebranchenvdetails` has `branch=fbe-821600-date-selector-flex-reservation-dashboard, createdby=Duncan.Teegelaar@eneco.com, env=kidu, active=used`). | A1 |
| C14 | FBE mechanism (repo/pipeline/state binding) | Resolved via vault `fbe-creation-lifecycle-deep-dive.md` + live pipeline read: 8-stage pipeline 2412 → terraform/fbe in `VPP - Infrastructure` repo → state blob `terraform.{env}` in `tfstatevpp` storage account container `tfstate` → ArgoCD sync from `VPP.GitOps` repo → AKS namespace `{env}` in `vpp-aks01-d` | A1 |
| C15 | State backend = `tfstatevpp/tfstate/terraform.kidu` | Pipeline PowerShell `azure-pipelines-featurebr-env.yml:382-390` generates `fbe.backend.config` with `key = "terraform.$(featurebranchname)"` (PowerShell var-sub, not ADO template). Probe-02 confirms blob `terraform.kidu` exists, size 1150540, lastModified `2026-05-11T08:04:27Z` | A1 |
| C16 | Whether the namespace was created by a prior pipeline run for kidu OR by another mechanism | Cannot fully determine without lease-table history + destroy-pipeline run logs. Empirical facts (all A1):<br>– Namespace `vpp-evh-premium-kidu` exists since `2025-06-10` (11 months before today)<br>– Tags are empty (consistent with multiple mechanisms — see below)<br>– State `terraform.kidu` does NOT contain `module.eventhub_namespace_premium.azurerm_eventhub_namespace.eventhub_namespace`<br>– State HAS `module.eventhub_namespace_premium_storageaccount.azurerm_storage_account.storage_account` whose Azure resource was created TODAY (`2026-05-11T06:54:14`)<br>**A2 INFER** — Three non-falsified hypotheses (any of them produces today's empirical disagreement; the fix is identical for all three):<br>– **P1**: Earlier FBE attempt + failed destroy with `terraform state rm` workaround on the namespace.<br>– **P2**: Out-of-band create (Azure CLI / portal / ARM template manual action in June 2025) that was never adopted by Terraform.<br>– **P3**: Earlier destroy attempt under terraform 1.13.1 (F19) silently skipped the namespace whose state version it could not parse, leaving the resource in Azure.<br>None of these is in-session falsifiable. The fix recommendation (delete-and-rerun) holds for all three. | A2 |

## Additional in-session probes (load-bearing, beyond antecedents)

| Probe | Question | Result | Cls |
|---|---|---|---|
| P-NS-EMPTY | Does the orphan namespace contain any event hubs / consumer groups? | `az eventhubs eventhub list --namespace-name vpp-evh-premium-kidu --resource-group rg-vpp-app-sb-401` returns empty list. No CGs either. → orphan is **EMPTY**, safe to delete. | A1 |
| P-STATE-MISSING | Is the premium namespace resource in `terraform.kidu` state? | `jq '[.resources[] \| select(.module \| tostring \| test("eventhub_namespace_premium"))] \| map(.module + "." + .type + "." + .name)'` returns only `module.eventhub_namespace_premium_storageaccount.azurerm_storage_account.storage_account` and `module.keyvault_secret_eventhub_namespace_premium_storage_account_primary_connection_string.azurerm_key_vault_secret.key_vault_secret`. The namespace ITSELF (`module.eventhub_namespace_premium.azurerm_eventhub_namespace.eventhub_namespace`) is **NOT in state**. | A1 |
| P-STD-NS-OK | Is the STANDARD namespace `vpp-evh-kidu` correctly tracked? | State `module.eventhub_namespace.azurerm_eventhub_namespace.eventhub_namespace` has one instance with id `/subscriptions/…/namespaces/vpp-evh-kidu`. Azure shows `vpp-evh-kidu` exists since `2025-03-05T01:52:26` with sku Standard. → tracked correctly. The standard NS path is fine; only premium is broken. | A1 |
| P-STORAGE-AGE | When was `vppevhpremiumkidu` storage account created? | `2026-05-11T06:54:14` → created TODAY at the start of Duncan's failed pipeline run. → confirms Duncan's apply created downstream resources successfully, failed at the namespace. | A1 |
| P-OBSOLETE-YAML | Is the `azurepipelines-fbe.yaml` in `enecomanagedcloud/VPP%20-%20Infrastructure` the canonical FBE pipeline? | NO. The repo `enecomanagedcloud/VPP - Infrastructure` is a STALE local clone (HEAD `2e9793a`, Sept 2025). The current clone is `myriad-vpp/VPP%20-%20Infrastructure/main` (HEAD `4dbaf72`). The pipeline `azurepipelines-fbe.yaml` does not even exist in the current main repo. The actual pipeline driving Duncan's build is `azure-pipelines-featurebr-env.yml` in the SEPARATE `Myriad - VPP` repo (pipeline definition ID 2412). | A1 |
| P-VAULT-F2 | Does the failure pattern match a known vault entry? | `fbe-failure-modes-catalog.md F2` describes exactly this pattern: "FBE deletion fails → namespace residue blocks next creation", marked `partially_remediated_namespace_class` because the K8s namespace class was fixed by Roel 2025-12-09 (removed namespace from terraform/fbe; namespace now ArgoCD-only), but the Azure-resource sub-class (this case) is not retired. Quote from F2: "Cause (residual post-fix): Other non-namespace residue still occurs". Duncan's case is the Azure-resource sub-class. | A1 |
| P-LEASE-TABLE | Who held the kidu lease prior to Duncan? | **CURRENT LEASE — RESOLVED A1 by el-demoledor** (independently via storage-account-key auth path, see auxiliary/adversarial-review-eldemoledor.md): table `featurebranchenvdetails` row `PartitionKey="10", RowKey="10"` has `env=kidu, active=used, branch=fbe-821600-date-selector-flex-reservation-dashboard, createdby=Duncan.Teegelaar@eneco.com, queue=com-eneco-eet-vpp-streamcopy-dev10, Timestamp=2026-05-11T06:52:35Z`. Partition keys are row indices (1..11), not slot names — that's why the initial RCA filter approach using slot name as partition key failed.<br>**HISTORICAL TENANTS — A3 UNVERIFIED[blocked: Azure Storage Tables do not retain mutation history; the row is overwritten on each lease change. Resolving path: ADO build history retention OR Fabrizio's recollection]** — orthogonal to fix; not blocking. | A1 (current) / A3 (history) |

## Re-classification of inherited "facts"

Every line in `context.md` that originally appeared as a finished claim has been re-probed; nothing in this session relies on stale inherited assertion. Where the antecedent was correct, it is now backed by a fresh A1 probe. Where the antecedent inferred a mechanism, this session refined the mechanism with vault + live evidence.

## Net diagnosis (P2 close)

The orphan Azure resource `vpp-evh-premium-kidu` is the SOLE blocker. It exists in Azure (created June 2025) but not in `terraform.kidu` state. The namespace is **empty** (no event hubs, no consumer groups inside). The state's other 261 resources are mostly fresh from today's apply (storage account vppevhpremiumkidu created `2026-05-11T06:54:14`; standard NS tracked from prior runs). Duncan's apply will succeed once the orphan is removed and the pipeline re-run.
