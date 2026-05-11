---
task_id: 2026-05-11-002
agent: claude-opus-4-7
status: complete
summary: Config map — secret resources, KV inventory, naming patterns, expiry dates
classification: newly-mapped
phase: 2
---

# Config map — secrets in scope

## The 4 PATs (verbatim from `slack-intake.txt:5-9`)

| PAT name | Expiry (MM/DD/YYYY) | Status (as of 2026-05-08 report) | Action (as of 2026-05-11) |
|---|---|---|---|
| `argo-cd-sandbox` | 05/10/2026 | Critical | Expired 2026-05-10T12:40Z; rotation PENDING (Alex took action item) |
| `argo-cd-devmc-cmc-goldilocks-repository` | 06/01/2026 | Warning | Latent — must rotate before 2026-06-01 |
| `argo-cd-accmc-cmc-goldilocks-repository` | 06/01/2026 | Warning | Latent — must rotate before 2026-06-01 |
| `argo-cd-prdmc-cmc-goldilocks-repository` | 06/01/2026 | Warning | Latent — must rotate before 2026-06-01 |

**Service account** (per intake header line 2): `sa_platform_vpp@eneco.com` (FACT)

## Naming pattern analysis

```
argo-cd-{cluster-id}[-{repo-id}]
         │              │
         │              └── only present for MC PATs (3 of 4) → suggests per-repo binding
         │
         └── 'sandbox' (1 PAT) or '{env}mc' (3 PATs: devmc, accmc, prdmc)
```

The sandbox PAT is repo-implicit (it grants access to `VPP.GitOps`, per vault evidence). The MC PATs are repo-explicit (`cmc-goldilocks-repository`), implying the MC clusters use ArgoCD with **different repository scopes** — likely each MC ArgoCD installation reads from `cmc-goldilocks` repo for managed-cloud policy/version content. `[INFER from name pattern — verify with Fabrizio or by reading the MC ArgoCD config]`

## In-cluster Secret resources (verified for sandbox per vault recipe)

```
Cluster:      vpp-aks01-d  (sandbox AKS)
Subscription: 7b1ba02e-bac6-4c45-83a0-7f0d3104922e  (Eneco MCC Sandbox)
RG:           rg-vpp-app-sb-401
Namespace:    argocd
Resource:     Secret  (kind=Opaque, label argocd.argoproj.io/secret-type=repository)
Name:         repo-NNNNNNNNNN  (10-digit, format set by ArgoCD)
Fields:
  .data.url       = base64( https://dev.azure.com/enecomanagedcloud/.../VPP.GitOps )
  .data.username  = base64( sa_platform_vpp@eneco.com )
  .data.password  = base64( <PAT value> )   ← THE rotation target
```

For MC clusters: `[UNVERIFIED[blocked: ask Fabrizio about each MC cluster's ArgoCD install path and secret naming]]`

## KeyVault surface (source of truth — INFER)

Per vault `eneco-vpp-keyvault-secrets.md` (line 27-29):

```
KV: vpp-appsec-d  (dev environment KeyVault; '-d' suffix = development)
secrets:
  argocd-repository-credentials-template-url-acc    ← Azure DevOps PAT (ACC)
  argocd-repository-credentials-template-url-devmc  ← Azure DevOps PAT (DEVMC)
```

UNKNOWNS in the KV inventory:
- Is the **sandbox** PAT also stored in `vpp-appsec-d`? Vault doesn't list it; the recipe doesn't reference KV. `[UNVERIFIED[probe: az keyvault secret list --vault-name vpp-appsec-d | jq '.[] | select(.name | contains("argocd"))']]`
- Is there a separate **`vpp-appsec-a`** / **`vpp-appsec-p`** KV for acc/prd PATs? Or are they all in dev's KV? `[UNVERIFIED[ask Fabrizio]]`
- The **prdmc** PAT — is it stored anywhere structured, or rotated only ad-hoc? `[UNVERIFIED[ask Fabrizio]]`

## Adjacent rotation surfaces (NOT in this task's primary scope but referenced)

| Surface | Class | Recipe / pattern |
|---|---|---|
| AAD shared SP `6db398ec-8cb7-4398-a944-f842aa9a67da` | F4 — shared SP client secret expiry; affects all FBEs simultaneously | Vault `fbe-failure-modes-catalog.md` F4 (lines 171-208) |
| ESP/Axual mTLS production certificate | VPPAL Kafka cert rotation | Vault `vppal-cert-rotation-runbook.md` |
| TF SP credentials (MC DTA/PRD) | Terraform CI/CD SPs in `mcc-kv-vppdeploy*` KVs | Vault `eneco-mc-vpp-credentials-ci-cd.md` |
| Per-FBE KV (`vpp-fbe-{slot}-{suffix}`) | Per-slot KV with FBE-specific secrets | Per-slot — referenced in F4 lesson |
| Snyk credentials in ADO | CI credentials for snyk-scan | Vault `eneco-snyk-credentials-ado.md` |
| Storage account keys | F18 — auth-mode mismatch | Catalogue F18 |

This task documents ONLY the ArgoCD-PAT class (4 named PATs). The proposal-rotation-automation.md will reference these adjacent classes to argue for unified credential rotation tooling.

## Run-time configuration assumptions to verify in P4

| Assumption | Probe |
|---|---|
| ApplicationSet name `vpp-feature-branch-environments` exists in MC clusters too (or only in sandbox)? | `[UNVERIFIED — likely sandbox-only because MC clusters don't have FBE]` |
| The MC ArgoCD installations use Argo's same `repo-*` Opaque Secret pattern or a different declarative pattern (`argocd-cm` declarative repos)? | `kubectl get secret -n argocd -l argocd.argoproj.io/secret-type=repository` against each MC cluster |
| The MC `cmc-goldilocks` repo is on `dev.azure.com/enecomanagedcloud/...` or elsewhere? | Read MC ArgoCD repo Secret `.data.url` |
| Whether PAT-expiry report is auto-generated from Azure DevOps PAT audit logs or from a Logic App or scheduled query? | See automation-map |
