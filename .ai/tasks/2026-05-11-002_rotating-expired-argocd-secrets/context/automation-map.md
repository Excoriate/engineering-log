---
task_id: 2026-05-11-002
agent: claude-opus-4-7
status: complete
summary: Automation map — PAT-expiry monitor, KV→cluster sync, ArgoCD ApplicationSet reconcile loop
classification: newly-mapped (the rotation flow surface)
phase: 2
---

# Automation map — rotation surface dynamics

## The 4 automation surfaces involved in a rotation

```
            ┌──────────────────────────────────────────────────────────┐
            │  (1) PAT-EXPIRY ALERT GENERATOR                          │
            │  Posts table to #myriad-alerts-devops on cadence         │
            │  - Source: Azure DevOps PAT REST API (audit logs)        │
            │            OR a Logic App / scheduled scheduled query    │
            │  - Owner: [UNVERIFIED[ask Fabrizio]]                     │
            │  - Cadence: [UNVERIFIED — probably weekly]               │
            │  - Trigger: warns "Warning" >=30d before, "Critical" <14d│
            └──────────────────────────────────────────────────────────┘
                                    │
                                    ▼  (human sees alert)
            ┌──────────────────────────────────────────────────────────┐
            │  (2) HUMAN ROTATION OPERATOR                             │
            │  - Mints new PAT in ADO UI under sa_platform_vpp@…       │
            │  - Updates source-of-truth (KV or directly the Secret)   │
            │  - Verifies cluster reconciles                           │
            │  - Documents the rotation                                │
            │  Owner: Trade Platform on-call                           │
            └──────────────────────────────────────────────────────────┘
                                    │
                                    ▼  (writes new PAT)
            ┌──────────────────────────────────────────────────────────┐
            │  (3) PROPAGATION TO CLUSTER SECRET                       │
            │  Two known/possible paths:                               │
            │                                                          │
            │  SANDBOX (verified by vault recipe):                     │
            │    kubectl patch secret repo-NNNNNNNNNN -n argocd        │
            │      --type=json -p '[{"op":"replace",                   │
            │        "path":"/data/password","value":<base64-PAT>}]'   │
            │                                                          │
            │  MC clusters (devmc/accmc/prdmc): [UNVERIFIED[unknown]]  │
            │    Candidates:                                           │
            │    (a) ESO + ExternalSecret CRD                          │
            │    (b) Azure KV CSI driver + SecretProviderClass         │
            │    (c) Manual kubectl patch (same as sandbox)            │
            │    (d) IaC kubernetes_secret resource reading KV         │
            └──────────────────────────────────────────────────────────┘
                                    │
                                    ▼  (Secret data updated)
            ┌──────────────────────────────────────────────────────────┐
            │  (4) ARGOCD APPLICATIONSET RECONCILE                     │
            │  - Cadence: ~3 min default (Git generator polling)       │
            │  - Hard-refresh trigger: annotate ApplicationSet with    │
            │    argocd.argoproj.io/refresh=hard (forces fresh poll)   │
            │  - Success signal: condition type=ErrorOccurred,         │
            │    status=False, with fresh lastTransitionTime           │
            │  - Downstream: Application CRDs materialize in slot      │
            │    namespace within ~30-60s                              │
            └──────────────────────────────────────────────────────────┘
```

## Sandbox propagation path — VERIFIED by vault recipe

```
Human  --[mint PAT in ADO]-->  ADO PAT exists
       |
Human  --[kubectl patch]--->  Cluster Secret repo-NNNNNNNNNN updated  -->  ArgoCD reads new PAT on next reconcile
       |
Human  --[force-refresh]-->  ApplicationSet hard-refresh  -->  Auth recovers in ≤90s  -->  App CRDs in slot namespace  -->  Pods in 2-10 min
```

Decision rule (vault recipe Step 6): `ErrorOccurred=False` with fresh `lastTransitionTime` (within last 2 min) = auth recovered.

## MC propagation path — UNVERIFIED

If MC uses ESO/CSI/IaC-managed Secret:
1. Human mints PAT in ADO
2. Human updates **KV secret** value (`az keyvault secret set --vault-name <kv> --name argocd-repository-credentials-template-url-{env} --value <PAT>`)
3. **Cluster picks up automatically** (ESO sync interval, or pod restart for CSI driver, or next `terraform apply` for IaC path)
4. ArgoCD picks up new PAT on next reconcile

The choice of mechanism is critical for the **MC runbook** — manual kubectl patch on a CSI-driver-managed Secret would be **immediately overwritten** by the next driver sync (the wrong rotation procedure for that mechanism!). **Critical to verify in P4.**

## PAT-expiry alert flow (the upstream sensor)

`#myriad-alerts-devops` receives PAT-expiration reports listing PATs across the org. Mechanism is:

- **Most likely**: a scheduled Azure DevOps PAT audit query (via `az devops` CLI or REST API) running as a Logic App or scheduled GitHub Action / ADO pipeline, posting a table to Slack.
- **Less likely**: a custom Slack workflow + script.

`[UNVERIFIED[ask Fabrizio]]` — the **identity of the report generator** is needed for:
- Adding NEW PATs to the watchlist (post-rotation)
- Adjusting threshold (e.g., reduce "Warning" lead time)
- Triggering reset on rotation

## ApplicationSet reconcile semantics — VERIFIED

Per vault `pattern-argocd-pat-expiry-blocks-new-fbe-apps.md` line 70-78 + `recipe-rotate-argocd-sandbox-pat.md` Step 6:

- Default reconcile cadence: ~3 min for Git generator
- Hard-refresh trigger: `argocd.argoproj.io/refresh=hard` annotation
- Error condition surface: `kubectl describe applicationset` → `Status.Conditions[?(.type=="ErrorOccurred")]`
- Existing Application CRDs in etcd survive an auth break — they don't require ApplicationSet reconcile success to keep reconciling themselves (proven empirically by 8 healthy slot app-of-apps surviving the 22-hour auth break)

## Probing automation in P4 (sidecars)

Sidecar A — `eneco-context-slack` will surface:
- Who has posted prior PAT-rotation announcements (identifies the alert generator owner)
- Reaction threads to past PAT-expiry alerts (identifies past human rotation operators)
- Any prior rotation runbook posted as a Canvas / pinned message

Sidecar B — `eneco-context-docs` will surface:
- Wiki pages on credential rotation
- Wiki pages on ArgoCD architecture (which would document the KV→cluster mechanism)

Sidecar C — `eneco-context-repos` will surface:
- IaC for the ArgoCD install (likely Terraform `kubernetes_secret` or Helm chart values declaring repository secrets)
- IaC for the PAT-expiry monitor (if it's an Azure Function / Logic App, it's in a repo)
- IaC for KV secret declarations (e.g., `azurerm_key_vault_secret` for the `argocd-repository-credentials-template-url-*` entries)
