---
title: voltex FBE recreation failure — evidence ledger + diagnosis (for adversarial review)
status: draft
timestamp: 2026-06-04T11:50:00Z
task_id: 2026-06-04-001
agent: claude-opus-4-8
summary: Read-only evidence ledger + working diagnosis of the voltex FBE failed-recreation incident — ArgoCD Application finalizer deadlock blocking auto-sync/recreation. Drafted for adversarial review.
---

# voltex FBE "failed recreation" — Evidence Ledger + Working Diagnosis

All evidence captured read-only from live Sandbox cluster `vpp-aks01-d`
(sub `7b1ba02e-bac6-4c45-83a0-7f0d3104922e`), context `vpp-aks01-d`/ns `argocd`,
on 2026-06-04 ~11:40–11:45 UTC. Identity: `Alex.Torres@eneco.com`.

## Symptom (from Stefan's intake)
- FBE "voltex" recreation: create pipeline (ADO buildId 1668061) reported success.
- In ArgoCD (filtered ns=voltex) he sees ONLY `voltex-app-of-apps` + `alarmengine`.
- Pester infra test failed: pods not all Running (frontend/monitor `Succeeded`),
  `[FrontEnd] should get 200` → 404.
- His suspicion: he broke vpp-config on branch
  `feature/fbe-826335-update-appconfig-with-new-tso`; can't delete branch to retry.

## Evidence (A1 = externally witnessed via kubectl/logs)

| # | Evidence | Label |
|---|----------|-------|
| E1 | `voltex-app-of-apps` (ns argocd): sync=OutOfSync, health=Progressing; syncPolicy.automated{prune:true,selfHeal:true} | A1 |
| E2 | `voltex-app-of-apps` `.metadata.deletionTimestamp=2026-06-03T13:14:51Z`, finalizers=[`resources-finalizer.argocd.argoproj.io`], ownerRef=`ApplicationSet/vpp-feature-branch-environments` | A1 |
| E3 | `voltex` ns has exactly ONE child Application CRD: `alarmengine` (OutOfSync/Healthy). Healthy slot `afi` has 20 child CRDs all Synced/Healthy. | A1 |
| E4 | `alarmengine` (ns voltex) `.metadata.deletionTimestamp=2026-06-03T13:14:51Z`, finalizers=[`resources-finalizer.argocd.argoproj.io`] | A1 |
| E5 | app-of-apps `.status.resources` lists all 22 desired children; 21 are `NoHealthKey` (desired-but-not-materialised) | A1 |
| E6 | Controller log (argocd-application-controller-0), repeated: `voltex-app-of-apps` & `voltex/alarmengine` → `"Skipping auto-sync: deletion in progress"` | A1 |
| E7 | Controller log: `alarmengine` → `"Deleting resources"` / `"5 objects remaining for deletion"` (loops); `voltex-app-of-apps` → `"1 objects remaining for deletion"` | A1 |
| E8 | `Job/seed-assets-alarmengine-postsync-1779187628` (ns voltex): deletionTimestamp=2026-05-19, finalizers=[`argocd.argoproj.io/hook-finalizer`] — STUCK terminating | A1 |
| E9 | `Pod/frontend-8556c9dffd-7t9w5` deletionTimestamp=2026-05-18, `Pod/monitor-5b45c988c5-sr45x` deletionTimestamp=2026-05-18 — stuck Terminating (show as Completed) | A1 |
| E10 | `seed-assets-alarmengine-postsync` PostSync hook (hook-delete-policy BeforeHookCreation) fails: pod log `POST http://alarmengine:8080/api/alarmengine → StatusCode: 500` → `BackoffLimitExceeded`; repeated jobs 16d/7d/23h | A1 |
| E11 | ApplicationSet `vpp-feature-branch-environments`: generator=git files `feature-branch-environments/*.yaml` from repo `VPP.GitOps` rev HEAD; conditions ErrorOccurred=False, ParametersGenerated=True, ResourcesUpToDate=True | A1 |
| E12 | `VPP.GitOps/feature-branch-environments/voltex.yaml` EXISTS (local clone; stale 2025-11-18 but file present) | A1 (existence) / A3 (HEAD freshness) |
| E13 | app-of-apps source = repo `VPP-Configuration` path `Helm/vpp-core-app-of-apps`, targetRevision=`feature/fbe-826335-update-appconfig-with-new-tso`; multi-source revision resolves (revisions=[0bc0901…]); no comparison error conditions | A1 |
| E14 | alarmengine workload itself synced fine: Service/Deployment/Ingress `Synced/Succeeded`; only the PostSync seed Job failed | A1 |

## Working Diagnosis (causal chain)

**Proximate cause:** voltex FBE is half-deployed (only `alarmengine` present;
frontend 404; Pester red) because `voltex-app-of-apps` and its `alarmengine`
child are **stuck in Terminating state** (E2,E4) — a deletion issued
2026-06-03 13:14:51 never completed.

**Enabling cause:** ArgoCD **skips auto-sync for any Application with a pending
deletion** (E6, `"Skipping auto-sync: deletion in progress"`). So (a) the stuck
app-of-apps cannot re-create its 21 missing children, and (b) the owning
ApplicationSet cannot create a fresh same-named `voltex-app-of-apps` while the
old object still exists. Deadlock.

**Mechanism (why deletion is wedged):** finalizer cascade deadlock —
- `voltex-app-of-apps` finalizer waits on 1 object = the `alarmengine`
  Application (E7).
- `alarmengine` finalizer waits on its managed objects, of which
  `Job/seed-assets-alarmengine-postsync-1779187628` holds its own
  `argocd.argoproj.io/hook-finalizer` and is itself stuck Terminating since
  2026-05-19 (E8), plus orphaned frontend/monitor pods stuck Terminating since
  2026-05-18 (E9).
- The wedged hook Job traces to a **chronically failing PostSync seed hook**:
  alarmengine's `/api/alarmengine` seeding endpoint returns HTTP 500 (E10),
  so the hook Job hits its backoff limit and never reaches the clean state
  that would let ArgoCD strip the hook-finalizer.

**Disproven user hypothesis:** the branch / vpp-config is NOT the cause.
ApplicationSet generates parameters successfully (E11), the app-of-apps source
revision resolves with no comparison error (E13). The "can't delete the branch"
detail is irrelevant. Cause is a Kubernetes/ArgoCD finalizer deadlock.

**Branch-independence note:** the FBE re-creates from VPP.GitOps `voltex.yaml`
(E12) via the ApplicationSet, independent of his feature branch state.

## Candidate Fix (Tier 1 minimal → escalate) — TO BE AUTHORISED, not yet run

Goal: let the stuck deletion complete so the ApplicationSet recreates voltex clean.

1. Strip the wedged hook-finalizer from the stuck seed Job (lets alarmengine
   cascade finish): `kubectl patch job seed-assets-alarmengine-postsync-1779187628
   -n voltex -p '{"metadata":{"finalizers":[]}}' --type=merge`.
2. Force-delete orphaned stuck pods: `kubectl delete pod frontend-… monitor-…
   -n voltex --grace-period=0 --force`.
3. Watch alarmengine + voltex-app-of-apps finish Terminating (objects-remaining → 0).
4. If still wedged after blockers cleared, last-resort remove
   `resources-finalizer.argocd.argoproj.io` from `alarmengine` then
   `voltex-app-of-apps` (residue = orphaned alarmengine workload, auto-adopted on
   recreate).
5. ApplicationSet `vpp-feature-branch-environments` recreates `voltex-app-of-apps`
   → recreates all 22 children → FBE live. If not auto-recreated, re-run create
   pipeline 2412.
6. Separately fix the failing seed hook (alarmengine API 500) or it will re-wedge.

## Open / bounded items for adversarial attack
- O1: WHO issued the delete at 13:14:51 (destroy pipeline 2629 vs manual `argocd
  app delete` vs ApplicationSet prune)? Not pinned — A3. Fix is trigger-independent.
- O2: Is `voltex.yaml` in VPP.GitOps HEAD *now* (clone stale)? Inferred yes from
  E11 ownerRef + up-to-date — A2.
- O3: Will the ApplicationSet actually auto-recreate once the stuck object clears,
  or is a pipeline rerun required?
- O4: Is removing `resources-finalizer` safe / will it orphan resources or break
  the ApplicationSet's adoption?
- O5: Does fixing the deadlock alone restore frontend 200, or is the seed-hook 500
  a separate blocker that keeps the FBE unhealthy after recreate?
