---
task_id: 2026-05-11-002
agent: claude-opus-4-7
status: complete
summary: Docs map — vault notes already enumerating the procedure + gaps to fill via wiki/slack
classification: reused (vault structure already enumerated above) + newly-mapped (gap list)
phase: 2
---

# Docs map — what exists, where, and what's missing

## Vault notes (in-scope, on disk, READ in P2)

| Note (path under `2-areas/work-eneco/`) | Lines | Role | Status |
|---|---|---|---|
| `eneco-vpp-platform/fbe-errors/recipe-rotate-argocd-sandbox-pat.md` | 258 | Executable 9-step runbook (sandbox PAT) | A1 FACT (read in P2) — but is MY OWN PRIOR NOTE → INFER until source-verified |
| `eneco-vpp-platform/fbe-errors/pattern-argocd-pat-expiry-blocks-new-fbe-apps.md` | 210 | Class-level mental model + blast radius | A1 FACT (read in P2) — INFER per Agent Laundering until source-verified |
| `eneco-vpp-platform/fbe-errors/2026-05-11-pat-expiry-argocd-auth-break.md` | 138 | Incident record with A1/A2/A3 chain | A1 FACT (read in P2) |
| `eneco-vpp-platform/eneco-vpp-keyvault-secrets.md` | 45 | KV inventory (mentions ArgoCD PATs in `vpp-appsec-d`) | A1 FACT (read in P2) |
| `eneco-vpp-vppal/vppal-cert-rotation-runbook.md` | 46 | Different surface (ESP cert via ArgoCD app + KeyVault PFX) — adjacent pattern | A1 FACT (read in P2) |
| `eneco-vpp-platform/eneco-vpp-argocd-healthy-but-unreachable-troubleshooting.md` | 101 | ArgoCD troubleshooting context (SPA catch-all trap) | A1 FACT (read in P2) — used for verification step language |
| `eneco-vpp-platform/fbe/fbe-failure-modes-catalog.md` (F4 entry, lines 171-208) | 38 | Adjacent class (AAD client secret expiry on shared SP `6db398ec-...`) | A1 FACT (read in P2) |
| `eneco-vpp-landscape/eneco-mc-vpp-credentials-ci-cd.md` | 163 | TF SP credential architecture (NOT ArgoCD PATs; different surface) | A1 FACT (read in P2) — provides KV naming pattern context |

## Vault notes referenced but NOT yet read (deferred to P4 if needed)

| Note | Why deferred | Decision criterion |
|---|---|---|
| `eneco-vpp-platform/fbe-errors/_index.md` (106 lines) | Index — likely only navigation | Read if a related pattern is needed |
| `eneco-vpp-platform/fbe/fbe-operations-runbook.md` | Referenced by recipe Step 9 ("Reference per-FBE KV secret rotation F4 mitigation") | Read if F4-class context becomes needed |
| `1-projects/eneco-iac-strategy/06-azure-deep-state` §6.2.1 | Canonical 218-secret KV inventory | Read in P4 if KV-→-cluster sync probe needs the full secret list |
| `eneco-vpp-platform/eneco-vpp-gitops-access-and-namespace-model.md` | GitOps access model — relevant to who-can-rotate question | Read in P4 if RBAC/ownership question becomes blocking |
| `eneco-vpp-platform/eneco-vpp-platform-troubleshooting.md` | Master troubleshooting hub | Read if the runbook needs cross-references |

## ADO wiki surface (to query via `eneco-context-docs` in P4)

Hypothesis H2 (procedure documented in ADO wiki): `[UNVERIFIED[unknown]]` — must probe.

Search queries planned:
- `argocd pat rotation`
- `argocd secret rotation`
- `repository credentials rotation`
- `sa_platform_vpp PAT`
- `goldilocks repository`
- `cmc goldilocks`
- `feature branch environment ArgoCD`

Wiki spaces to search (per `eneco-context-docs` skill description):
- Myriad VPP architecture wiki
- Trade Platform FAQ
- Trade Platform Troubleshooting Guide
- BTM wiki
- Aggregation Layer wiki
- Runbooks (general)
- ADRs (general)
- Product designs (general)

## Slack surface (to query via `eneco-context-slack` in P4)

Hypothesis H1 (procedure described in Slack history by Fabrizio/Roel): `[UNVERIFIED[unknown]]` — must probe.

Channels to harvest:
- `#myriad-platform` (PAT renewal questions; Fabrizio's threads)
- `#myriad-alerts-devops` (PAT-expiration reports; reaction threads)
- `#myriad-env-fbe` (FBE-create result posts)
- `#mc-vpp` (MC environment context if exists)
- Direct messages to Fabrizio Zavalloni / Roel — public Slack only (cannot fetch DMs)

Search terms:
- `argocd pat` / `argo-cd pat` / `PAT rotation`
- `argo-cd-sandbox` / `argo-cd-devmc` / `argo-cd-accmc` / `argo-cd-prdmc`
- `goldilocks`
- `sa_platform_vpp` rotation
- `repository-credentials` / `repo-credentials`
- `ApplicationGenerationFromParamsError`

Authors to weight: Fabrizio Zavalloni, Roel, Trade Platform leads.

## What is missing from vault + must be sourced externally (gap list — feeds `[PENDING: ask Fabrizio]` blocks)

1. **MC cluster names + AKS/OpenShift type + RG + subscription** (sandbox is on AKS `vpp-aks01-d` — MC is unknown)
2. **MC repo what-and-where** — "goldilocks" repo: real name, URL, content
3. **KV → cluster sync mechanism** — ExternalSecrets? CSI driver? IaC? Manual?
4. **Service account identity for MC PATs** — same `sa_platform_vpp@eneco.com` as sandbox? Or different?
5. **PAT-expiry report generator** — who/what publishes the report to `#myriad-alerts-devops`? (probable: an Azure DevOps PAT-audit Logic App, scheduled query; see automation-map)
6. **Documented escalation path** — is there a Trade Platform RACI for credential rotation?
7. **Authority to mint PATs for `sa_platform_vpp@eneco.com`** — who has ADO admin / impersonation rights?
8. **Latent rotation cadence policy** — do Eneco engineering standards define an SLA (e.g., "rotate within 7 days of `Warning`")?
9. **Cert-class secrets** — user said "expired ArgoCD secrets" broadly; vault only covers PAT class. Are there ArgoCD TLS certs / mTLS-to-repo certs that also rotate? Likely no for HTTPS+PAT auth, but confirm.
