---
status: active
date: 2026-06-24
agent: codex
summary: Per-token sanitized status tracker for MC ArgoCD PAT renewal.
---

# Rotation Status

## Status Legend

- `candidate`: identified from ADO token inventory, not yet applied/proven.
- `applied-user-reported`: user reports the new PAT has been applied in ArgoCD.
- `proof-observed`: Codex observed covered app state after the user reports post-recreate proof action.
- `proof-pending`: visible state is compatible with success, but the required post-recreate Hard Refresh has not been confirmed.
- `revoke-pending`: proof passed; old PAT has not yet been revoked.
- `closed`: proof passed and old PAT revoked.

## Credentials

| Token / credential | Env | Template URL / coverage | Proof app | Current status | Evidence |
| --- | --- | --- | --- | --- | --- |
| argo-cd-devmc-asset-optimization-credentials-template | devmc | `https://enecomanagedcloud@dev.azure.com/enecomanagedcloud/VPP%20-%20Asset%20Optimisation` | `flex-trade-optimizer-app-of-apps` | `revoke-pending` | User reported template recreated and post-recreate `Hard Refresh` performed. Codex observed proof app repo URL under the Asset Optimisation prefix and visible status `Synced to HEAD` + `Healthy` at 2026-06-24 12:14 CEST with no visible repo-auth/comparison error. Old PAT revocation still pending. |
| argo-cd-devmc | devmc | `https://enecomanagedcloud@dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP` | `activationmfr-eneco-vpp` / `assetmonitor-eneco-vpp` | `revoke-pending` | Live dev-MC ArgoCD recreate form observed at 2026-06-24 12:17 CEST with Myriad VPP URL entered. At 2026-06-24 12:18 CEST the screen had returned to Applications, consistent with form completion. At 2026-06-24 12:20 CEST Codex observed proof app `activationmfr-eneco-vpp` Source 2 URL under `Myriad%20-%20VPP/_git/VPP-Configuration`, confirming prefix coverage. At 2026-06-24 12:21 CEST Codex observed `assetmonitor-eneco-vpp` is also covered by the same Source 2 URL and is `Synced` + `Healthy`; toolbar refresh kept it green. User reported dev-MC done at 2026-06-24 12:23 CEST and began revoking old PATs. |
| argo-cd-acc | acc | `https://enecomanagedcloud@dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP` | TBD | `candidate` | Initial ADO inventory. ACC ArgoCD Settings → Repositories observed at 2026-06-24 12:24 CEST with Myriad VPP credentials-template row visible. At 2026-06-24 12:26 CEST Codex observed ACC recreate form with Myriad VPP URL and username entered; password field empty on screen. Not saved/proven. |
| argo-cd-prod | prd | TBD | TBD | `candidate` | Initial ADO inventory only. |
| argo-cd-acc-asset-optimization-credentials-template | acc | `https://enecomanagedcloud@dev.azure.com/enecomanagedcloud/VPP%20-%20Asset%20Optimisation` | TBD | `candidate` | Initial ADO inventory. ACC ArgoCD Settings → Repositories observed at 2026-06-24 12:24 CEST with Asset Optimisation credentials-template row visible. At 2026-06-24 12:27 CEST Codex observed ACC recreate form with Asset Optimisation URL entered. At 2026-06-24 12:28 CEST Codex observed username entered and password field masked; no token material visible. Save/proof not observed. |
| argo-cd-prd-asset-optimization-credentials-template | prd | TBD | TBD | `candidate` | Initial ADO inventory only. |
| argo-cd-sandbox-asset-optimization | sandbox / TBD | TBD | TBD | `candidate` | Initial ADO inventory only; environment/scope still needs disambiguation. |
| myriad-vpp\\library-eneco-vpp-monitoring-sa-platform-vpp-monitoring-pat-token | monitoring / TBD | TBD | TBD | `candidate` | Initial ADO inventory only; not assumed to be ArgoCD until confirmed. |
