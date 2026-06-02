---
title: "Investigation context — jupiter/dispatchermfrr ArgoCD auth break 2026-05-12"
type: research
domain: tech
status: complete
created: 2026-05-12
authors: [alex-torres]
related:
  - rca.md
  - fix.md
  - slack-intake.txt
---

# Investigation context

This file captures the raw probe outputs and intermediate evidence that grounds the
[`rca.md`](./rca.md) A1 facts. The RCA's Evidence Ledger references this file as the
source for re-runnable verification.

## Investigation timeline (this session)

| When (UTC) | What | Where it lives |
|---|---|---|
| 2026-05-12T~12:20 | Slack intake filed by jupiter dev | `slack-intake.txt` |
| ~12:22 | First probes (kubectl + argocd CLI auth check) | inline below |
| ~12:24 | Repository page screenshot from user | (in chat) |
| ~12:25 | Probe set drafted | `.ai/tasks/2026-05-12-001_fbe-jupiter-argocd-auth/context/probe-set.md` |
| ~12:27 | Surface 1 — Application status A1 captured | inline below |
| ~12:28 | Surface 2 — credential enumeration A1 captured | inline below |
| ~12:30 | Blast radius enumeration — 68 Apps | inline below |
| ~12:32 | Class membership confirmed; RCA drafted | `rca.md` |
| ~12:40 | Three adversaries dispatched in parallel | `.ai/tasks/2026-05-12-001_fbe-jupiter-argocd-auth/verification/adv-*.md` |
| ~12:45 | Two BLOCKING probes from socrates pre-empted | inline below |
| ~12:55 | Adversaries return; synthesis | rca.md "Adversarial Review Receipts" section |
| ~13:05 | fix.md Phase A→F runbook written | `fix.md` |

## Tool / context state probed at start

```bash
$ command -v az kubectl argocd
/opt/homebrew/bin/az
/opt/homebrew/bin/kubectl
/opt/homebrew/bin/argocd

$ kubectl config current-context
vpp-aks01-d

$ argocd context
CURRENT  NAME                      SERVER
*        argocd.dev.vpp.eneco.com  argocd.dev.vpp.eneco.com

# argocd CLI session expired (AADSTS700082) — re-login required for argocd app commands
# kubectl auth verified: yes (can get applications.argoproj.io -n argocd)
# az CLI: needs login
```

## Surface 1 — failing Application's status (A1)

```bash
$ kubectl get application dispatchermfrr -n jupiter -o jsonpath='{.status.conditions}' | python3 -m json.tool
[
    {
        "lastTransitionTime": "2026-05-10T12:45:22Z",
        "message": "Failed to load target state: failed to generate manifest for source 1 of 2: rpc error: code = Unknown desc = authentication required",
        "type": "ComparisonError"
    }
]

$ kubectl get application dispatchermfrr -n jupiter -o jsonpath='reconciledAt={.status.reconciledAt}
observedAt={.status.observedAt}
sync.status={.status.sync.status}
sync.revision={.status.sync.revision}'

reconciledAt=2026-05-12T12:15:40Z
observedAt=
sync.status=Unknown
sync.revision=
```

**Inference**: error state began 2026-05-10T12:45:22Z (5 min after PAT expiry at 12:40:13Z). ArgoCD reconciles continuously (latest 12:15:40Z) but error has NOT cleared. `lastTransitionTime` unchanged = same error continuously present, not a flapping condition.

## Surface 2 — credential enumeration (A1)

### Per-repo Repository CRs in argocd namespace

```text
repo-3194359838  | user=sa_platform_vpp@eneco.com | pw_len_b64=112 | proj=default      | url=https://enecomanagedcloud@dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/VPP-Configuration
repo-3613977198  | user=sa_platform_vpp@eneco.com | pw_len_b64=112 | proj=default      | url=https://enecomanagedcloud@dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/Myriad%20-%20VPP
repo-3703084109  | user=sa_platform_vpp@eneco.com | pw_len_b64=112 | proj=default      | url=https://enecomanagedcloud@dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/VPP.GitOps
(+ Helm OCI repos — vppacrsb.azurecr.io, vppacra.azurecr.io — not relevant to this incident)
```

### Credential templates (`repo-creds`) in argocd namespace

```text
creds-1649328519 | user=vppacra                    | pw_len_b64=60  | url=vppacra.azurecr.io/helm-agg
creds-870830599  | user=sa_platform_vpp@eneco.com  | pw_len_b64=112 | url=https://enecomanagedcloud@dev.azure.com/enecomanagedcloud/VPP%20-%20Asset%20Optimisation
repo-creds       | user=vppacra                    | pw_len_b64=44  | url=oci://vppacra.azurecr.io/helm-agg
```

**Key observation**: ONLY ONE ADO HTTPS credential template exists, and it covers `VPP - Asset Optimisation`, NOT `Myriad - VPP`. No template prefix-matches any of the 64 FBE Application Source 1 URLs (`Eneco.Vpp.Core.Dispatching`) or the 4 platform-gitops Source 1 URLs.

## Blast radius enumeration (A1)

```text
=== Count broken apps by slot / namespace ===
   8 thor
   8 operations
   8 jupiter        ← original slack intake (just one app reported)
   8 ionix
   8 afi
   7 voltex
   7 veku
   7 ishtar
   7 argocd         ← platform: product-*, rabbitmq-*, loki
```

**Total: 68 Applications.**

### Source 1 repo URL of broken apps (deduplicated)

```text
https://enecomanagedcloud@dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/Eneco.Vpp.Core.Dispatching   (× 64 FBE apps)
https://enecomanagedcloud@dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/platform-gitops             (× 4 platform apps)
null                                                                                                       (× 4 OCI-source apps; verified separately to use Myriad-VPP/_git/target-state-rabbitmq-playground + grafana.github.io OCI)
```

## Class unification probe (Claim 6 from socrates, RESOLVED with A1)

Per-app `lastTransitionTime` clustering:

```text
afi/*           → 2026-05-10T12:43-12:48
ishtar/*        → 2026-05-10T12:45-12:48
operations/*    → (clustered similar; partial output)
thor/*          → 2026-05-10T12:43-12:48
veku/*          → 2026-05-10T12:45-12:48
voltex/*        → 2026-05-10T12:45-12:48
argocd/product-*       → 2026-05-10T12:47-12:48
argocd/rabbitmq-target-state-*  → 2026-05-10T12:51
ionix/*         → 2026-05-12T12:19  ← (TODAY — see anomaly below)
jupiter/dispatchermfrr → 2026-05-10T12:45:22Z (per Surface 1)
```

All cluster within `2026-05-10T12:43:00Z ± ~10 min` — one PAT-expiry reconcile window. **Unified class confirmed.**

### Ionix anomaly (the falsifier for socrates Claim 7 — stale repo-server cache)

```text
ionix/dispatchermfrr  created=2026-05-12T12:19:05Z  condLastTransition=2026-05-12T12:19:06Z
ionix/activationmfrr  created=2026-05-12T12:19:05Z  condLastTransition=2026-05-12T12:19:05Z
... (all 8 ionix apps created same day, broken same day)
```

These Applications were created TODAY (2026-05-12T12:19:05Z) and entered `ComparisonError` at the same timestamp. Fresh Applications can have no cached "no-credential → anonymous" state — they have to resolve credentials on first lookup. Their immediate failure proves credentials are genuinely absent for fresh resolution, not stale-cache-stuck. This single data point falsifies Claim 7's competing mechanism.

## repo-server pod state probe (Claim 7 partial)

```bash
$ kubectl get pod -n argocd -l app.kubernetes.io/name=argocd-repo-server -o jsonpath='{...}'
pod=argocd-repo-server-577c7bb5b7-27bjg  startTime=2026-02-09T13:14:27Z
```

Pod has been running for ~3 months — through the previous PAT lifetime, PAT expiry, and yesterday's rotation. The fact that the 3 working Repository CRs (`VPP-Configuration`, `VPP.GitOps`, `Myriad - VPP`) currently succeed (eneco-flex-trade-optimizer/* Synced+Healthy after yesterday's rotation) proves repo-server re-reads Secret data on each fetch — Secret rotation is not blocked by pod age.

## Self-management prune probe (Claim 2F socrates — RESOLVED with A1)

```text
argocd/applicationsets                    -> dest.ns=argocd prune=true selfHeal=true
argocd/argocd                             -> dest.ns=argocd prune=false selfHeal=false
argocd/argocd-configuration               -> dest.ns=argocd prune=false selfHeal=false
argocd/product-asset-scheduling           -> dest.ns=argocd prune=true selfHeal=true (manages product-as namespace, not argocd-namespace Secrets)
argocd/product-flex-trade-optimizer       -> dest.ns=argocd prune=true selfHeal=true (same)
argocd/product-vpp-core                   -> dest.ns=argocd prune=true selfHeal=true (same)
argocd/product-vpp-dispatching            -> dest.ns=argocd prune=true selfHeal=true (same)
argocd/rabbitmq-app-of-apps               -> dest.ns=argocd prune=true selfHeal=true
```

The two Applications that manage `argocd` namespace itself (`argocd`, `argocd-configuration`) have `prune=false`. The new `creds-myriad-vpp-project` Secret will not be pruned by ArgoCD's own self-management.

## ApplicationSets observed on cluster

```text
feature-branch-environment-monitoring-stack
vpp-feature-branch-environments
vpp-product-bootstrap
```

`vpp-feature-branch-environments` is the generator for FBE slot app-of-apps (the one yesterday's PAT rotation restored). `feature-branch-environment-monitoring-stack` is a sibling ApplicationSet for monitoring; not directly relevant to this incident. `vpp-product-bootstrap` is the generator for platform `argocd/product-*` Applications — these are also affected by the same credential gap because their Source 1 is `platform-gitops`.

## What was NOT probed in this session (gaps acknowledged)

| Gap | Why blocked | Resolving probe deferred to |
|---|---|---|
| Pre-2026-05-10 credential state (how did `Eneco.Vpp.Core.Dispatching` ever work?) | No audit log; cluster etcd doesn't retain history of deleted Secrets | Phase-9 follow-up — enable ArgoCD audit logging |
| repo-server `--parallelism-limit` current value | Not probed in this session | fix.md Phase A1 (mandatory before applying) |
| `sa_platform_vpp@eneco.com` repo-level RBAC on `Eneco.Vpp.Core.Dispatching` | ADO CLI/UI access needed | fix.md Phase A0 `git ls-remote` probe (mandatory before applying) |
| ACR pull-rate budget for `vppacrsb` | `az` was not logged in during investigation | fix.md Phase A1 (`az acr show`) |
| `refresh=hard` exact source-code semantics | ArgoCD source code lookup deferred | fix.md uses `refresh=normal` to side-step the question |

These gaps do not block fix-apply — fix.md Phase A defers them to pre-apply probes with explicit decision rules. They are documented here for next-shift on-call traceability.

## Investigation artifact paths

- Probe planning + decision rules: `.ai/tasks/2026-05-12-001_fbe-jupiter-argocd-auth/context/probe-set.md`
- Adversarial reports (full):
  - `.ai/tasks/2026-05-12-001_fbe-jupiter-argocd-auth/verification/adv-socrates.md`
  - `.ai/tasks/2026-05-12-001_fbe-jupiter-argocd-auth/verification/adv-eldemoledor.md`
  - `.ai/tasks/2026-05-12-001_fbe-jupiter-argocd-auth/verification/adv-sre.md`
- Vault canonical (yesterday's incident and pattern):
  - `$SECOND_BRAIN_PATH/2-areas/work-eneco/eneco-vpp-platform/fbe-errors/2026-05-11-pat-expiry-argocd-auth-break.md`
  - `$SECOND_BRAIN_PATH/2-areas/work-eneco/eneco-vpp-platform/fbe-errors/pattern-argocd-pat-expiry-blocks-new-fbe-apps.md`
  - `$SECOND_BRAIN_PATH/2-areas/work-eneco/eneco-vpp-platform/fbe-errors/recipe-rotate-argocd-sandbox-pat.md`
