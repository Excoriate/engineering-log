---
status: active
date: 2026-06-24
agent: codex
summary: Sanitized context for MC ArgoCD PAT renewal across dev/acc/prd and related credential templates.
---

# Context

## Scope

Pairing session for renewing Azure DevOps PATs used by Eneco MC ArgoCD repository credentials. The user creates and handles the PAT values; Codex assists with safe probes, AVD/ArgoCD validation, and sanitized logging.

## Access Check

- Time: 2026-06-24 11:27:52 CEST.
- Computer-use access: confirmed.
- AVD surface: Windows App `Developer Desktop`.
- Visible state: Edge open on ArgoCD application tiles, with tabs for ArgoCD/OpenShift surfaces.
- Actions taken through AVD so far: read-only inspection only.

## Initial Token Inventory

Observed in attached Azure DevOps `Manage tokens` screenshot. Non-secret fields only.

| Token name | Organization | Status | Expires | Initial note |
| --- | --- | --- | --- | --- |
| argo-cd-devmc-asset-optimization-credentials-template | enecomanagedcloud | Active | 2027-06-22 | Appears already renewed; verify if user wants full audit. |
| argo-cd-devmc | enecomanagedcloud | Active | 2026-06-25 | Target candidate. |
| argo-cd-acc | enecomanagedcloud | Active | 2026-06-25 | Target candidate. |
| argo-cd-prod | enecomanagedcloud | Active | 2026-06-25 | Target candidate. |
| argo-cd-acc-asset-optimization-credentials-template | enecomanagedcloud | Active | 2026-06-28 | Target candidate. |
| argo-cd-prd-asset-optimization-credentials-template | enecomanagedcloud | Active | 2026-06-29 | Target candidate. |
| argo-cd-sandbox-asset-optimization | enecomanagedcloud | Active | 2026-07-12 | Target candidate; environment/scope to disambiguate. |
| myriad-vpp\\library-eneco-vpp-monitoring-sa-platform-vpp-monitoring-pat-token | enecomanagedcloud | Active | 2026-09-21 | Not assumed to be an ArgoCD credential until confirmed. |

## Safety Rules For This Session

- Do not reveal, copy into chat, screenshot, print, or log PAT values or ArgoCD secret fields.
- Do not revoke an old PAT before the new PAT is created, stored, applied, and proven.
- Do not close a rotation on ArgoCD `Save`; close only on `Hard Refresh` effect for a covered app.
- Confirm exact credential/template URL before deleting or recreating anything.
- Reject proof apps whose repo URL is outside the rotated URL prefix or overridden by a more-specific credential.
