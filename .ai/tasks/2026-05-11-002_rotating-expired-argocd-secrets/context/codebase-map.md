---
task_id: 2026-05-11-002
agent: claude-opus-4-7
status: complete
summary: Codebase map — where ArgoCD secrets and KV-→-cluster sync mechanisms live
classification: newly-mapped (rotation surface) + reused (FBE/Argo context from 2026-05-11-001_fbe-error-duncan)
phase: 2
---

# Codebase map — rotation surface

## In-cluster (ArgoCD-side) surface — sandbox

Source of the rotation procedure (vault `recipe-rotate-argocd-sandbox-pat.md`):

- Cluster: `vpp-aks01-d` (sandbox AKS)
- Resource group: `rg-vpp-app-sb-401` (confirmed via 2026-05-11-001 codebase-map line 88-90)
- Subscription: `7b1ba02e-bac6-4c45-83a0-7f0d3104922e` (per recipe Step 1)
- Namespace: `argocd`
- Secret type: `Opaque` with label `argocd.argoproj.io/secret-type=repository`
- Secret name pattern: `repo-NNNNNNNNNN` (10-digit) per recipe Step 2
- Fields: `.data.url` (base64), `.data.username` (base64, expected `sa_platform_vpp@eneco.com`), `.data.password` (base64 PAT)
- ApplicationSet: `vpp-feature-branch-environments` in `argocd` namespace
- ApplicationSet generator: Git generator reading `feature-branch-environments/*.yaml` from VPP.GitOps

## In-cluster surface — MC (dev/acc/prd) — `[UNVERIFIED[unknown]]`

The 3 MC PATs (`argo-cd-{env}mc-cmc-goldilocks-repository`) suggest:

- **`{env}mc`** → dev-MC / acc-MC / prd-MC ArgoCD installations (each MC env has its own)
- **`cmc-goldilocks`** → repo name fragment; "goldilocks" is the CCoE managed-cloud SRE policy / version-pinning repo. `[UNVERIFIED[blocked: ask Fabrizio]]`
- **`-repository`** suffix → suggests an ArgoCD repository-credentials secret (same family as sandbox `repo-*`)

UNKNOWNS to ask Fabrizio:
- Where does each MC ArgoCD installation live? (which OpenShift cluster, namespace?)
- Are MC ArgoCD repo secrets stored as Opaque `repo-*` (like sandbox) or via a different pattern (e.g., AKS Secret Provider Class / OpenShift Secret pull from KV)?
- Is "goldilocks" the literal repo name or a code name?

## Source-of-truth KV surface

Per vault `eneco-vpp-keyvault-secrets.md` (line 27-29):

```
KV: vpp-appsec-d (development KV — name fragment '-d' = dev)
├── argocd-repository-credentials-template-url-acc   # ACC env PAT
├── argocd-repository-credentials-template-url-devmc # DEVMC env PAT
└── (no entry mentioned for the sandbox PAT or prd-mc/acc-mc PATs)
```

Canonical exhaustive enumeration (per cross-ref to `1-projects/eneco-iac-strategy/06-azure-deep-state §6.2.1`): 218 secrets, 11 categories, captured 2026-04-27 — that note has the complete list (out-of-scope for direct read here; cite when needed).

### Critical map gap — KV → cluster sync mechanism

`[UNVERIFIED[unknown]]`: how does the PAT value get from `vpp-appsec-d` KV into the cluster `repo-*` Secret?

Candidates:
- **(a) External Secrets Operator (ESO)** with `ExternalSecret` CRD pulling from KV
- **(b) Azure KeyVault CSI driver** (`SecretProviderClass`) mounting the secret
- **(c) Manual `kubectl patch`** (what the vault recipe documents — implies KV is NOT the source of truth for the sandbox PAT)
- **(d) IaC `kubernetes_secret` Terraform resource** reading KV via `azurerm_key_vault_secret` data source

The vault recipe Step 5 does manual `kubectl patch`, suggesting (c) for sandbox. But the KV secrets list shows ACC + DEVMC PATs **exist in KV** — which means MC clusters likely use (a)/(b)/(d), NOT manual patch. **Critical question for Fabrizio.**

## IaC repositories likely involved (to probe in P4 via `eneco-context-repos`)

| Repo | Why it matters |
|---|---|
| `Eneco.Infrastructure` | Monorepo with platform Terraform modules; likely contains ArgoCD install/config or KV secret declarations |
| `VPP.GitOps` | ArgoCD source-of-truth Git repo; `feature-branch-environments/*.yaml` files committed by FBE pipeline |
| `VPP - Infrastructure` (covered by prior task) | FBE pipeline + sandbox/FBE Terraform — likely declares the KV `vpp-appsec-d` and per-FBE KVs |
| `MC-VPP-Infrastructure` | MC envs Terraform — declares MC ArgoCD config + MC keyvaults |
| (possibly) `Eneco.ManagedCloud` / `Eneco.Platform` | If a managed-cloud platform repo exists with ArgoCD bootstrapping |

## Worktree paths (current laptop)

- Engineering log: `/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log`
- Eneco IaC src root (per CLAUDE.md): `/Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src/enecomanagedcloud/myriad-vpp/MC-VPP-Infrastructure/main`
- VPP-Infrastructure (per 2026-05-11-001 codebase-map): `/Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src/enecomanagedcloud/VPP%20-%20Infrastructure/`
- Obsidian vault: `/Users/alextorresruiz/Documents/obsidian/2-areas/work-eneco/`
