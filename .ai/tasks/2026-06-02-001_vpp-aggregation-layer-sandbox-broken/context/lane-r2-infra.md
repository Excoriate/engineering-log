---
task_id: 2026-06-02-001
agent: repo-infra-lane
status: complete
summary: Both Aggregation infra repos are Terraform-only (Azure KV/CosmosDB/EventHub); neither provisions the K8s `keys` secret or Kafka mTLS certs — CSI Secrets Store is the intended consumer in BOTH MC and Sandbox, so the structural delta is KV topology, not a "provider present vs absent" split.
timestamp: 2026-06-02T00:00:00Z
---

# Lane R2 — Infrastructure / IaC Authority

Scope: ADO project "Myriad - VPP", repos `Eneco.Vpp.Aggregation.Infrastructure` (= Sandbox) and `Eneco.Vpp.Aggregation.Infrastructure.Mc` (= MC dev/acc/prd). Read-only. No git mutation, no `az account set`, no kubeconfig touched.

## TL;DR for the coordinator

- **A1**: Neither repo defines a Kubernetes `keys` secret, a `SecretProviderClass`, an `ExternalSecret`, a cert-manager `Certificate`, or any Kafka certificate. They are pure Terraform repos that build Azure resources (Key Vault, CosmosDB, EventHub, Storage, AppConfig). Zero hits across `keys` / `kafka` / `certificate` / `SecretProviderClass` / `ExternalSecret` / `cert-manager` in both repos (the one "keys" hit in MC is the Terraform `keys()` HCL builtin, not a secret).
- **A2 (INFER)**: The K8s `keys` secret + its Kafka/mTLS certs are NOT owned by these two IaC repos. They are materialized by a **separate GitOps/Helm/app-deployment repo** (out of this lane's two-repo scope). These repos only build the Azure Key Vault and grant a **CSI driver identity** read access — the CSI Secrets Store driver is the intended in-cluster materializer of secrets from KV → K8s `Secret`.
- **A2 (INFER) — answer to Johnson's hypothesis**: "secrets should be installed via a secret provider" is consistent with the IaC evidence: both Sandbox AND MC Key Vaults grant access to a CSI driver service identity (see Q3). The CSI/SecretProviderClass wiring itself is just not in *these* repos.
- **A1 — answer to "sandbox is very different from MC"**: True at the **Terraform topology** level (different repo, different KV resource model, no env matrix, public KV vs private-endpoint KV — see "MC vs Sandbox provisioning delta"). But it is **NOT** the case that "MC has an automated secret provider and Sandbox has none" *within these IaC repos* — neither repo provisions the secret. The CSI consumer hook exists in both.

---

## Q1 — Top-level structure of both repos

Tool: `ado-repo-tree.sh ... --branch main`. Default branch = `main` for both (`ado-list-branches.sh`).

**A1 — `Eneco.Vpp.Aggregation.Infrastructure` (Sandbox):**

```text
README.md
azure-pipelines/  (terraform-cd.yaml, terraform-ci.yaml)
terraform/
  appconfig.tf  cosmosdb_*.tf  eventhub.tf  insights.tf
  keyvault.tf  log_analytics.tf  provider.tf  storage.tf  variables.tf
  env/sb.tfvars            <-- single environment file ("sandbox")
```

**A1 — `Eneco.Vpp.Aggregation.Infrastructure.Mc` (MC):**

```text
README.md  azure-pipelines.yml  pipeline-variables.yaml
pipelines/ (terraform-apply/-deploy/-plan templates)
terraform/
  keyvault.tf  cosmosdb*.tf  eventhub.tf  sqlserver-mc-lz.tf
  servicebus modules, virtualnetwork-mc-lz.tf, etc.
  env/
    mcc-dev/  (mcc-dev.tfvars, mcc-dev-alerts.tfvars)
    mcc-acc/  (mcc-acc.tfvars, mcc-acc-alerts.tfvars)
    mcc-prd/  (mcc-prd.tfvars, mcc-prd-alerts.tfvars)
  modules/ (appconfig, cosmosdb_account, cosmosdb_database, eventhub, servicebus)
```

**Verdict (A1):** Both are **Terraform** (no Terragrunt, no Helmfile, no ArgoCD ApplicationSet, no Kubernetes manifests). MC has a formal **3-env matrix** (`mcc-dev`/`mcc-acc`/`mcc-prd`) with per-env `.tfvars`; Sandbox has a **single** `env/sb.tfvars`. MC also has reusable local `modules/` and pipeline templates; Sandbox consumes shared modules from the `Eneco.Infrastructure` monorepo via `git::` source refs and has thin CI/CD yaml.

## Q2 — How are secrets/certificates provisioned per environment?

**A1 — Both repos build an Azure Key Vault, but only an `mssqladmin` secret is defined in IaC. No Kafka cert, no `keys` secret.**

- Sandbox `terraform/keyvault.tf`: `module "kv-vpp-agg"` (source = `Eneco.Infrastructure//terraform/modules/keyvault?ref=v1.0.0`), `module "keyVaultAccess_kv-vpp-agg"` (keyvaultaccess module, `for_each = var.vault_access`), and `module "mssqladmin"` (keyvaultsecret module) creating only secret `mssqladmin{sb}` from a `random_password`. No certificate resource, no Kafka/mTLS secret.
- MC `terraform/keyvault.tf`: `azurerm_key_vault.aks-kv` (name `…-appsec-{env}`), `azurerm_key_vault_access_policy.vault_access`, `azurerm_private_endpoint.private_endpoint_keyvault_mc_lz`, and `azurerm_key_vault_secret.mssqladmin` (again only the mssql admin password). No certificate resource, no Kafka/mTLS secret.

**A1 — No CSI `SecretProviderClass`, no External Secrets Operator, no cert-manager anywhere.**
Searches across both repos returned `NO RESULTS` for `SecretProviderClass`, `ExternalSecret`, `cert-manager`. Sandbox: `NO RESULTS` for `kafka` and `certificate`. MC: `NO RESULTS` for `kafka` and `certificate`.

**A2 (INFER):** The Kafka mTLS certs inside the K8s `keys` secret therefore originate **outside these IaC repos**. The two candidate channels are (a) a Key Vault *certificate* object that a CSI SecretProviderClass projects into the cluster as the `keys` secret, or (b) a separate GitOps/Helm chart that ships/mounts the certs. These repos provision the KV and the CSI read-access but not the cert object itself nor the K8s Secret. **Where the certs actually live (KV cert object vs pipeline var vs manual) cannot be confirmed from these two repos** — see Q4 A3.

## Q3 — THE KEY QUESTION: is there an env matrix where MC gets an automated provider but Sandbox does not?

**A1 — Both Key Vaults grant access to a CSI / cluster identity. The CSI consumer pattern exists in BOTH environments.**

- Sandbox `terraform/variables.tf` `variable "vault_access"` default list includes (lines ~63-64):
  ```hcl
  "224d933d-cf79-48e3-b00c-cbd1db1b94a8", # vpp-aks01-d-csi
  "95c57ae7-3bd4-42c4-8821-ceca18d05bd2", # vpp-aks01-d-csi
  ```
  plus `# aks-agic`, `# appreg-vpp-keyvault-sb-d` entries. → A CSI Secrets Store driver identity (`vpp-aks01-d-csi`) is explicitly granted read on the Sandbox KV.
- MC `terraform/keyvault.tf` access policy `for_each` = `concat(var.vault_access_groups, var.cluster_aad_identities, [current.object_id], var.keyvaultAccessSPN)`. MC `env/mcc-dev/mcc-dev.tfvars`:
  ```hcl
  keyvaultAccessSPN      = ["c690fcf1-…"] // appreg-vpp-keyvault-d
  cluster_aad_identities = [
    "bd658351-…", //eneco-gen-dta-4fsdz-identity
    "be11fd55-…"  //eneco-vpp-dev-zgzzt-identity
  ]
  ```
  (`cluster_aad_identities` is present in all three of `mcc-dev`/`mcc-acc`/`mcc-prd` tfvars + keyvault.tf + variables.tf — 5 hits.) → MC grants the AKS cluster/kubelet identities read on the KV, the same CSI-consumption hook.

**Verdict (A1 + A2):** The "automated provider present in MC, absent in Sandbox" framing is **not supported by these IaC repos**. Both environments wire a cluster/CSI identity into KV access. The actual `SecretProviderClass` / `keys` Secret definition is absent from BOTH (it lives in the GitOps/app layer). So if the intended mechanism is CSI, it is intended in Sandbox too — meaning the Sandbox breakage is more likely an **operational gap** (the SecretProviderClass/cert in the GitOps layer was never deployed or the KV never had the cert object) than a deliberate "Sandbox has no provider" config choice. **This points the coordinator at the GitOps/app repo + the actual KV cert inventory, not at an IaC env-matrix toggle.**

## MC vs Sandbox provisioning delta (concrete evidence)

| Dimension | Sandbox (`…Aggregation.Infrastructure`) | MC (`…Aggregation.Infrastructure.Mc`) | Evidence |
|-----------|------------------------------------------|----------------------------------------|----------|
| Repo | separate repo | separate repo | `ado-list-branches.sh` (both exist) — A1 |
| Env model | single `env/sb.tfvars` (`environment="sandbox"`), TF workspaces | matrix `mcc-dev`/`mcc-acc`/`mcc-prd` `.tfvars` | tree listings — A1 |
| KV resource | shared `Eneco.Infrastructure` modules (`keyvault`/`keyvaultaccess`/`keyvaultsecret` `@v1.0.0`), public | inline `azurerm_key_vault.aks-kv` (`-appsec-`) + **private endpoint** + network ACL allowlist | `keyvault.tf` both — A1 |
| KV access to cluster identity | `vpp-aks01-d-csi` in `vault_access` default | `cluster_aad_identities` (kubelet identities) per env | `variables.tf` / `mcc-*.tfvars` — A1 |
| `keys` secret / Kafka cert in IaC | **absent** | **absent** | search `keys`/`kafka`/`certificate` = no relevant hits — A1 |
| SecretProviderClass / ESO / cert-manager | **absent** | **absent** | search = NO RESULTS both — A1 |
| Pipeline | thin `azure-pipelines/*.yaml` | `pipeline-variables.yaml` (`terraformVersion 1.13.1`) + stage templates; no cert step | files read — A1 |

**Interpretation (A2):** The delta that is real and IaC-visible: Sandbox KV is a simpler, public, shared-module KV under app RG `rg-vpp-app-sb-401`; MC KV is a hardened private-endpoint `-appsec-` KV with a real env matrix. The delta that Johnson described ("provider in MC, manual in Sandbox") is **NOT** visible as an IaC provider-toggle — both grant CSI/cluster read on KV, and neither defines the secret. The manual creation in Sandbox is therefore best explained by the secret-materialization layer (GitOps/SecretProviderClass + the KV cert object) being absent/unbootstrapped in Sandbox, not by an intentional infra config branch. **(H1 "config delta" weakened; H2 "operational/GitOps gap" strengthened. Needs the GitOps lane + a live KV cert inventory to confirm — out of this lane's scope.)**

## Q4 — Is there an IaC/GitOps definition that would expire on a calendar (the ">6 months since cert expiry")?

**A1:** No certificate object, no rotation resource, and no cert-manager `Certificate`/`Renewal` is defined in either repo (searches = no hits; only `mssqladmin` random_password secret exists, which does not expire on a cert calendar). There is **no auto-rotation mechanism for Kafka/mTLS certs in these IaC repos.**

**A3 UNVERIFIED[blocked: cert object lives outside the two assigned repos]:** What rotates the Kafka cert (an Azure KV-managed certificate with an auto-renew policy, a manually-uploaded KV cert with a fixed `not_after`, or a cert shipped via the app/GitOps repo) cannot be determined from these two repos. Resolving path: (a) live `az keyvault certificate list` on the Sandbox `vpp-agg`/`appsec` KV (BLOCKED for me — read-only/no `az account set`); (b) the GitOps/Helm app-deploy repo. **A2 (INFER):** A manually-uploaded KV certificate or a cert baked into a static K8s secret with a fixed validity window is fully consistent with "broken for >6 months since the cert expired and nothing renewed it" — there is no IaC rotation owner in scope.

## Q5 — ArgoCD Application / ApplicationSet targeting `vpp-agg` in Sandbox

**A1:** No ArgoCD definition exists in either repo. Search for `argocd` in the MC repo = `NO RESULTS`; neither repo contains `Application`/`ApplicationSet` manifests or any GitOps directory (tree listings are 100% Terraform + pipeline yaml).

**A2 (INFER):** Whether GitOps *should* have reconciled the `keys` secret depends on an ArgoCD repo that is **outside these two IaC repos** (likely a platform/cluster-config or app-deploy repo). **A3 UNVERIFIED[blocked: ArgoCD config not in assigned repos]** — route to the GitOps lane. If the `keys` secret is meant to be a CSI-projected secret, ArgoCD would deploy the `SecretProviderClass` + the Pod/SecretSync, but the cert source (KV) still needs the cert object present; ArgoCD reconciling a SecretProviderClass does NOT itself create the underlying KV certificate.

## Hypothesis status handoff

- **H1 (MC has provider, Sandbox config omits it)** — WEAKENED. Both KVs grant CSI/cluster read; neither defines the secret in IaC. No env-matrix provider toggle found.
- **H2 (shared mechanism, Sandbox operationally unbootstrapped/failed at the GitOps/cert layer)** — STRENGTHENED. The IaC hooks (KV + CSI identity) exist in Sandbox; the missing piece is the secret-materialization layer + the KV cert object, both outside these repos.
- **H3 (certs are manually/statically provisioned with a fixed expiry, no auto-rotation)** — CONSISTENT with all IaC evidence (no rotation resource anywhere). Confirm via live KV cert inventory + GitOps repo.

## Probes run (read-only)

- `ado-list-branches.sh` both repos (default = `main`).
- `ado-repo-tree.sh` root + `/terraform` both repos on `main`; `/terraform` on Sandbox branch `sec/keyvault` (still no SecretProviderClass/cert/keys secret).
- `ado-repo-file.sh`: Sandbox `keyvault.tf`, `variables.tf`, `env/sb.tfvars`, `README.md`; MC `keyvault.tf`, `env/mcc-dev/mcc-dev.tfvars`, `modules/eventhub/main.tf`, `pipeline-variables.yaml`, `README.md`.
- `ado-repo-search.sh`: Sandbox = `keys`,`kafka`,`certificate`,`SecretProviderClass`,`ExternalSecret`,`csi`; MC = `keys`,`kafka`,`certificate`,`SecretProviderClass`,`cluster_aad_identities`,`argocd`,`cert-manager`,`secret`.

## Out-of-lane pointers for the coordinator

- The `keys` K8s secret + Kafka mTLS certs are owned by a GitOps/Helm/app-deploy repo, NOT these two IaC repos → dispatch a GitOps lane.
- A live read-only KV cert inventory (Sandbox `vpp-agg`/`appsec` KV) would settle Q4/Q5 — BLOCKED for this lane by the no-`az account set` constraint.
