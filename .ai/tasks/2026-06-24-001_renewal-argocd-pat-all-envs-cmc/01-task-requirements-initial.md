---
task_id: 2026-06-24-001
agent: codex
status: active
summary: Initial requirements for pairing on Eneco MC ArgoCD PAT rotation across environments.
---

# Initial Requirements

## User Request

Pair with the user through renewal of all PAT tokens shown in the attached Azure DevOps token list image. The user will create the new PAT tokens and place secret values in ArgoCD UI. Codex will assist by running safe probes, validating changes, confirming AVD access, and recording sanitized work notes under:

`/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/log/employer/eneco/02_on_call_shift/2026_june/2026_06_24_renewal_argocd_pat_all_envs_cmc`

## Boundaries

- Never ask for, echo, read, screenshot, log, or persist PAT values or any ArgoCD secret fields.
- User performs PAT creation, secret copying, 1Password updates, ArgoCD password entry, and old-token revocation.
- Codex may inspect UI state and run metadata-only probes through AVD/computer-use when authorized.
- No destructive or credential-mutating UI action without immediate action-time confirmation.
- Old PATs remain rollback credentials until new PATs are applied and proven.

## Initial Inventory From Screenshot

Observed token rows, non-secret fields only:

| Token name | Organization | Status | Expires |
| --- | --- | --- | --- |
| argo-cd-devmc-asset-optimization-credentials-template | enecomanagedcloud | Active | 2027-06-22 |
| argo-cd-devmc | enecomanagedcloud | Active | 2026-06-25 |
| argo-cd-acc | enecomanagedcloud | Active | 2026-06-25 |
| argo-cd-prod | enecomanagedcloud | Active | 2026-06-25 |
| argo-cd-acc-asset-optimization-credentials-template | enecomanagedcloud | Active | 2026-06-28 |
| argo-cd-prd-asset-optimization-credentials-template | enecomanagedcloud | Active | 2026-06-29 |
| argo-cd-sandbox-asset-optimization | enecomanagedcloud | Active | 2026-07-12 |
| myriad-vpp\\library-eneco-vpp-monitoring-sa-platform-vpp-monitoring-pat-token | enecomanagedcloud | Active | 2026-09-21 |

## Success Criteria

- For every target token/template, identify the ArgoCD credential row by exact non-secret URL and environment.
- Confirm selected proof app repository URL is covered by that credential and not overridden by a longer-prefix template or repo-specific credential.
- After user creates/stores/applies the new PAT, verify by Hard Refresh that a covered proof app is `Synced` and `Healthy` with no repo-auth error.
- Revoke old PAT only after proof passes.
- Keep a sanitized log of work done, findings, proof apps, timestamps, and residual risks.

## Current Phase Goal

Load computer-use, confirm visual access to the AVD, and capture any read-only context needed to start the rotation safely.
