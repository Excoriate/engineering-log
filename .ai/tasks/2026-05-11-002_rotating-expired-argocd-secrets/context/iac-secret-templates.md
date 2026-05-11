---
task_id: 2026-05-11-002
agent: iac-harvest-sidecar
status: complete
summary: IaC evidence for ArgoCD repo-secret management + KV-to-cluster sync mechanism
phase: 4
---

# ArgoCD Repo-Credential IaC Harvest — Findings

Scope: local clones under `/Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src/enecomanagedcloud/{myriad-vpp,vpp-assetoptimisation,ccoe,mcc-landing-zone,trade-platform}`. All claims = INFER until coordinator source-verifies.

## Big picture before per-Q answers

There is no single ArgoCD here — **three distinct ArgoCD installs with three distinct repo-secret patterns** exist across the clusters:

1. **Sandbox VPP cluster (AKS `vpp-aks01-d` in subscription `7b1ba02e-bac6-...`)** — ArgoCD installed via Kustomize from upstream manifests. Declarative repos: **Helm chart in `ArgoCD-Config/Helm/repositories/`** renders `Secret` (`argocd.argoproj.io/secret-type: repository`) with username/password from Helm `.Values` — pipeline-injected, not Terraform.
2. **MC clusters dev/acc/prd (OpenShift, subscription `839af51e-c8dd-...`)** — ArgoCD via `argoproj.io/v1beta1` Operator CR. Repo creds for **OCI/Helm registry** synced from Azure KeyVault via CSI driver (`SecretProviderClass`); **ADO Git repo creds NOT IaC-managed via CSI** — appear to be applied manually as kubectl-applied Secrets (or via the deprecated `ArgoCD-Config` Helm path).
3. **Asset-Scheduling stack** — Bitnami **SealedSecret** committed to `asset-scheduling-gitops/argocd-apps/overlays/dev/assets/reposecret-assetscheduling.yaml` (encrypted in git, decrypted by sealed-secrets controller in `eneco-vpp-argocd` namespace).

No `ExternalSecret`, `SecretStore`, or `ClusterSecretStore` exist in any local clone — **ESO is not deployed**.

---

## Q1 — Terraform `kubernetes_secret` declaring repo-* Opaque secrets

**[NOT FOUND]** No `kubernetes_secret` resource in any local Terraform clone references `argocd`, `repo-`, or `repository`. Verified across `myriad-vpp/{MC-VPP-Infrastructure,Eneco.Infrastructure,platform-infrastructure}/*/terraform/**` and `VPP%20-%20Infrastructure`. Search returned zero hits for `kubernetes_secret.*argocd|argocd.*kubernetes_secret`.

Implication: the `repo-*` Opaque secrets in the `argocd` namespace are NOT applied by Terraform. They are either Helm-rendered, CSI-synced, sealed-secret–decrypted, or `kubectl apply`d by hand.

## Q2 — ArgoCD Helm chart values declaring `configs.repositories`

**[NOT FOUND for upstream `argo-cd` chart]** — No `argo-cd` Helm values with a `configs.repositories:` block anywhere. The sandbox ArgoCD is installed via Kustomize+upstream manifest (`VPP.GitOps/argocd/base/kustomization.yaml` references `argo-cd/v2.10.5/manifests/install.yaml`), the MC clusters use the **OpenShift GitOps operator CR**, neither uses the Helm chart's `configs.repositories` mechanism.

**[FOUND — alternative pattern]** `myriad-vpp/ArgoCD-Config/Helm/repositories/templates/deployment.yaml:1-12`:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: acr-helm
  namespace: eneco-vpp-argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  name: acra
  url:  {{  .Values.repository }}
  type: helm
  username: {{ .Values.username }}
  password: {{ .Values.password }}
  enableOCI: "true"
```
`values.yaml` carries placeholder values (`local-username`/`local-password`/`vppacra.azurecr.io`) — real values are pipeline-overridden. This chart targets `eneco-vpp-argocd` namespace (NOT `argocd`) so it serves the MC clusters' Operator-installed ArgoCD, not sandbox.

## Q3 — ESO usage

**[NOT FOUND]** Zero matches for `kind: ExternalSecret`, `kind: SecretStore`, `kind: ClusterSecretStore` anywhere in the local clones. ESO is not part of the Eneco VPP platform.

## Q4 — CSI driver / SecretProviderClass

**[FOUND]** Heavy use of `secrets-store.csi.x-k8s.io/v1` SecretProviderClass with `provider: azure`. Three load-bearing instances:

**Sandbox ArgoCD — TLS+OIDC only (NOT repo creds):** `myriad-vpp/VPP.GitOps/argocd/base/secretproviderclass.yaml:1-30`:
```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: secret-provider-azure-keyvault
spec:
  parameters:
    keyvaultName: vpp-aks-d
    objects: |
      array:
        - |
          objectName: vpp-eneco-com
          objectType: secret
    resourceGroup: rg-vpp-app-sb-401
    subscriptionId: 7b1ba02e-bac6-4c45-83a0-7f0d3104922e
```
Mounts `vpp-eneco-com` cert + OIDC client secret. Does NOT supply repo creds.

**MC clusters — OCI Helm repo creds via CSI:** `myriad-vpp/platform-gitops/product/vpp-product/templates/oci-repository-secretproviderclass.yaml:1-30` is a Helm template generating a `SecretProviderClass` that fetches seven `argocd-helm-oci-repository-*` KV objects (enable-oci, name, password, project, type, url, username) into a Secret labeled `argocd.argoproj.io/secret-type: repository`, namespace `argocd`. Values rendered from `platform-gitops/products/d/vpp-core.yaml` (KV name `kv-vppcre-bootstrap-d`, RG `rg-vppcre-bootstrap-d`, sub `839af51e-c8dd-4bd2-944b-a7799eb2e1e4`).

**MC clusters — ADO Git repo creds via CSI:** [NOT FOUND]. The CSI pattern is OCI-only. No template fetches `argocd-repository-credentials-template-url-*` or any ADO PAT KV object.

## Q5 — Terraform declarations for `argocd-repository-credentials-template-url-{acc,devmc}` KV secrets

**[NOT FOUND]** No `azurerm_key_vault_secret` resource (or `data` source) anywhere in the local clones references `argocd-repository-credentials`. Verified:
- `myriad-vpp/Eneco.Infrastructure/main/terraform/platform/**/*.tf` — only `azurerm_key_vault_secret` is for SQL admin password (`sandbox/shared/sql-server.tf:1`).
- `myriad-vpp/MC-VPP-Infrastructure/main/terraform/keyvault-mc-lz.tf` — zero `azurerm_key_vault_secret` resources.
- Global grep `resource "azurerm_key_vault_secret"` across all repos returns module-internal helpers (`cmc-azure-landingzone/modules/key_vault_secret/main.tf`), platform-infrastructure Rootly, BtM, Aggregation.Mc, devops keyrotation — **none of those reference `argocd-repository-credentials`**.

Implication: these two KV secrets (`argocd-repository-credentials-template-url-acc` and `-devmc` in `vpp-appsec-d`) were created **manually via Azure Portal or `az keyvault secret set`**, NOT by Terraform. There is no IaC declarations for them, so rotation cannot be expressed as a `terraform apply`.

**Adjacent finding (relevant for runbook):** `myriad-vpp/devops/src/keyrotation/terraform/registrations.tf` IS the platform's Terraform-based SP-password rotator (quarterly odd/even rolling window via `azuread_application_password` + `rotate_when_changed`, writing `azurerm_key_vault_secret` with `ignore_changes=[value]`). It rotates **AAD app-registration SP secrets only** — registrations like `appreg-mcdta-vpp-{assetplanning,asset,frontend,assetmonitor,integration,referencesignal,assetdispatcher,telemetry,...}`. The list explicitly does NOT include any ArgoCD-related app registration (`grep -c "argocd|argo-cd|sa_platform|sa-platform" registrations.tf` = 0). ArgoCD PATs are **out of scope** of this rotator because PATs are ADO PATs minted against `sa_platform_vpp@eneco.com`, not AAD SP passwords.

## Q6 — MC-cluster ArgoCD IaC

**[FOUND — partial]** MC ArgoCD instances are deployed as OpenShift GitOps Operator CRs, NOT Helm/Terraform:
- `mcc-landing-zone/gitops-vpp/gitops-vpp/main/argocd/{dev,acc,prd}/team-vpp/eneco-vpp-argocd.yaml` — `kind: ArgoCD` `apiVersion: argoproj.io/v1beta1`, namespace `eneco-vpp-argocd`, configures controller/server/repo/redis resources, OpenShift OAuth via Dex, RBAC bindings to AAD groups (`eneco_vpp_platform`, `sre-admins`, etc.). No repo-secret config in the CR.

Repo-secret application path: nothing in this repo applies repo creds. They must be applied either by:
- Helm chart `myriad-vpp/ArgoCD-Config/Helm/repositories/` (renders to namespace `eneco-vpp-argocd`, matches MC namespace), or
- The CSI pattern in `platform-gitops/product/vpp-product/templates/oci-repository-secretproviderclass.yaml` (namespace `argocd` — namespace mismatch suggests this is sandbox), or
- Manual `kubectl apply` of a Secret with `argocd.argoproj.io/secret-type: repository`.

Sandbox ArgoCD IaC (different stack): `myriad-vpp/VPP.GitOps/argocd/base/kustomization.yaml` Kustomize-installs upstream `argo-cd/v2.10.5/manifests/install.yaml` plus the CSI secret provider; overlays in `argocd/overlays/sandbox/` provide CM, RBAC CM, ingress.

## Q7 — PAT-expiry alert generator IaC

**[FOUND]** `myriad-vpp/devops/azure-pipelines.yml:1-44` is the **PAT and AppRegistration expiry-monitoring pipeline** (ADO Pipelines, not LogicApp/Function).

Verbatim relevant block:
```yaml
trigger:
  - main
variables:
  - name: warningExpiryThresholdDays
    value: "30"
  - name: criticalExpiryThresholdDays
    value: "5"
  - group: Slack Webhooks
jobs:
  - job: RunScript
    displayName: AppRegistration and PAT Token Monitoring Job
...
      - task: AzureCLI@2
        displayName: 'PAT Tokens report'
        inputs:
          azureSubscription: "mcprd-vpp-devops"
          scriptType: 'pscore'
          scriptPath: '$(Build.SourcesDirectory)/scripts/azure-devops-pat-token-monitor.ps1'
          arguments: '-DevopsSlackWebHook "$(myriad-alerts-devops_webhook_url)" `
                      -AzureDevopsOrganization "enecomanagedcloud" `
                      -WarningThresholdInDays $(warningExpiryThresholdDays) `
                      -CriticalThresholdInDays $(criticalExpiryThresholdDays) `
                      -PatToken "$(sa-platform-vpp-monitoring-pat-token)"'
```
The PS1 script (`myriad-vpp/devops/scripts/azure-devops-pat-token-monitor.ps1:1-77`) queries `https://vssps.dev.azure.com/{org}/_apis/Token/SessionTokens` for tokens belonging to `sa_platform_vpp@eneco.com`, builds a Markdown table, posts to `$(myriad-alerts-devops_webhook_url)` from Library group "Slack Webhooks". Thresholds: warning 30d, critical 5d.

Note: the script docstring states "This script only checks the PAT tokens that belongs to the service account (itself)" — so the alert only fires for PATs **owned by `sa_platform_vpp@eneco.com`**. PATs minted by individual humans are invisible to this alert.

## Search log

| # | Pattern | Scope | Tool | Hits |
|---|---|---|---|---|
| 1 | `argocd-repository-credentials\|repo-creds\|argoproj.io/secret-type` | 5 IaC repos `.yaml/.yml` | grep -rln | 0 |
| 2 | `argocd-repository-credentials\|argocd_repo\|kubernetes_secret.*argocd` | all `.tf` | grep -rln | 0 |
| 3 | `argocd-repository-credentials-template-url` | all `.tf/.tfvars` | grep -rln | 0 |
| 4 | `argo-cd-sandbox\|argo-cd-devmc\|argo-cd-accmc\|argo-cd-prdmc\|cmc-goldilocks\|goldilocks` | all `.yaml/.yml/.tf` | grep -rln | ~30 (k8s VPA goldilocks, not the MC repo) |
| 5 | `sa_platform_vpp\|sa-platform-vpp\|vpp-appsec-d\|vpp-aks01-d` | all `.yaml/.yml/.tf` | grep -rln | ~40 (MC-VPP-Infrastructure tfvars + VPP-Configuration CSI + devops pipeline) |
| 6 | `kind: ExternalSecret\|kind: SecretStore\|kind: ClusterSecretStore` | all `.yaml/.yml` | grep -rln | 0 |
| 7 | `azurerm_key_vault_secret\|argocd` | `Eneco.Infrastructure/main/terraform/platform` | grep -rln | 2 (SQL only) |
| 8 | `resource "azurerm_key_vault_secret"` | all `.tf` | grep -rln | 30+ (no argocd) |
| 9 | `configs:\|configs.repositories\|secret-type: repo\|secret-type: repo-creds` | all `.yaml/.yml` | grep -rln | 3 hits (ArgoCD-Config, platform-gitops, asset-scheduling-gitops) |
| 10 | `argocd.argoproj.io/secret-type: repository\|repo-creds` | all `.yaml/.yml` | grep -rln | 3 (same as above) |
| 11 | `myriad-alerts-devops\|pat.*expir\|secret_expiry` | all `.tf/.yaml/.yml` | grep -rln | 2 (`devops/azure-pipelines.yml`, `devops/pipelines/tasks/check-certificate-expire.yaml`) |
| 12 | `argocd\|argo-cd\|sa_platform\|sa-platform` | `devops/src/keyrotation/terraform/registrations.tf` | grep -c | 0 |

## Belief change — which `[PENDING]` items resolve

- **PENDING(`how are repo-* secrets applied?`)** → Three patterns identified; for the failing **sandbox `vpp-feature-branch-environments`** ApplicationSet (which targets ADO Git, NOT OCI), the live cluster Secret is most likely a hand-applied `kubectl apply` because the only Helm/CSI templates we have cover OCI (CSI) or are placeholder-valued (ArgoCD-Config). **No declarative IaC declares these specific `repo-*` Opaque secrets on the sandbox cluster.**
- **PENDING(`is rotation expressible as terraform apply?`)** → **NO**. Q5 confirms `argocd-repository-credentials-template-url-{acc,devmc}` KV secrets are not Terraform-managed; rotation requires either `az keyvault secret set` (KV side) or `kubectl apply`/`argocd repo add` (cluster side).
- **PENDING(`who created the KV secrets?`)** → Out of band (manual). The `keyrotation` Terraform module only rotates AAD SP passwords, not ADO PATs.
- **PENDING(`how is the PAT-expiry alert generated?`)** → ADO Pipelines (`myriad-vpp/devops/azure-pipelines.yml`) running PowerShell, posting to Slack webhook `myriad-alerts-devops_webhook_url`. **Not a LogicApp/Function**. Only monitors `sa_platform_vpp@eneco.com`-owned PATs.
- **PENDING(`is ESO in play?`)** → **NO**. No ESO/SecretStore/ClusterSecretStore in any local clone.
- **PENDING(`MC cluster ArgoCD install mechanism?`)** → OpenShift GitOps Operator CR (`argoproj.io/v1beta1 ArgoCD`) in `mcc-landing-zone/gitops-vpp/.../argocd/{env}/team-vpp/eneco-vpp-argocd.yaml`.
- **PENDING(`sandbox install mechanism?`)** → Kustomize on top of upstream `argo-cd/v2.10.5/manifests/install.yaml` + custom `SecretProviderClass` + sandbox overlay.

## Caveats

- Search is bounded to **local clones on disk**. Repos not cloned locally (e.g., `platform-services`, `Eneco.HelmCharts/eneco-vpp-argocd*` if any) were NOT searched — possible blind spot for additional repo-secret IaC.
- The `repo-*` Opaque secrets on the LIVE sandbox cluster may have drift from any IaC — confirming actual sync mechanism requires `kubectl get secret -n argocd -o yaml | grep -E 'managed-by|argocd.argoproj.io/instance|app.kubernetes.io/managed-by'` to see if anything (Helm/Kustomize/CSI/Sealed-Secret) owns them.
- Coordinator MUST source-verify all file:line citations (paths are absolute and copy-paste runnable).
