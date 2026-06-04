---
title: SRE adversarial review — voltex FBE recreation fix (safety, blast radius, recreation guarantee)
status: complete
timestamp: 2026-06-04T12:05:00Z
task_id: 2026-06-04-001
agent: sre-maniac
summary: |
  Adversarial demolition of the candidate fix against live Sandbox cluster vpp-aks01-d.
  Verdict: FIX FIRST. The recreation guarantee (O3) is CONFIRMED by live ApplicationSet
  controller logs — no pipeline rerun needed. Blast radius is confirmed voltex-namespace-scoped.
  But the runbook is WRONG/INCOMPLETE on three load-bearing details: (a) alarmengine has 6 managed
  resources / "5 remaining", not "1 stuck Job"; only ONE Job carries the stuck finalizer, the other
  two delete clean — the runbook's mental model of a single blocker is misleading; (b) the
  frontend/monitor zombie pods have NO finalizer and are NOT alarmengine-managed, so they do not
  block the alarmengine cascade and must not be presented as the unblock for it; (c) a SECOND control
  plane (fbe-voltex-monitoring, separate ApplicationSet) is healthy and untouched — the runbook never
  scopes it, creating risk an operator over-deletes. Step 4 (force-removing resources-finalizer) is a
  destructive escape hatch that should be gated behind a hard wait + explicit stop condition.
---

# SRE Adversarial Review — voltex FBE Recreation Fix

## Key Findings

- **O3_RECREATION**: CONFIRMED auto-recreate — ApplicationSet controller is live-reconciling voltex; logs show it created fbe-voltex-monitoring with identical syncPolicy=None. No pipeline rerun required.
- **BLAST_RADIUS**: voltex-namespace-scoped only; stuck Job tracking-id voltex_alarmengine, no cluster-scoped vpp-core objects, other slots (afi/ionix/jupiter...) untouched.
- **RUNBOOK_DEFECT**: "5 objects remaining" not 1; only Job -1779187628 has stuck hook-finalizer; frontend/monitor pods have NO finalizer and are NOT the alarmengine blocker.
- **SECOND_PLANE**: fbe-voltex-monitoring (Synced/Healthy, project=default, separate ApplicationSet) must be explicitly out-of-scope; do not delete ns voltex-monitoring.
- **STEP4_RISK**: force-removing resources-finalizer is the only genuinely destructive action; gate behind 5-min wait + stop condition; recreated alarmengine adopts by tracking-id (annotation), not ownerReference, so name-collision risk is real and must be checked.

**Verdict: FIX FIRST.** The fix is directionally correct and the recreation guarantee is now *empirically proven*, but the runbook as written is unsafe to hand to a tired on-call because it mis-states the blocker set, conflates unrelated zombie pods with the cascade blocker, ignores a second control plane, and places the only destructive action (finalizer strip) without a hard stop condition.

All evidence below is A1 (live `kubectl`/`argocd --core` against `vpp-aks01-d`, sub `7b1ba02e`, 2026-06-04 ~11:45–12:00 UTC) unless labeled.

---

## 1. ORDER / SAFETY + BLAST RADIUS

### Is stripping the hook-finalizer the minimal first step?

**Yes — and it is provably the single correct unblock for that Job.** Live evidence:

- `Job/seed-assets-alarmengine-postsync-1779187628` (ns voltex): `delTS=2026-05-19`, `finalizers=[argocd.argoproj.io/hook-finalizer]`, `tracking-id=voltex_alarmengine:batch/Job:voltex/`. (A1)
- It has **no live owned pods** (queried pods owned by this Job → empty). So stripping the finalizer deletes only the empty Job object; nothing is force-killed. (A1)
- The other two alarmengine hook Jobs (`-1779884943`, `-1780487852`) have **`finalizers=None`, `delTS=None`** → they delete cleanly when the cascade runs; they are NOT blockers. (A1)

**Runbook defect (HIGH):** The diagnosis says alarmengine's finalizer "waits on its managed objects, of which Job ... holds its own hook-finalizer." Live `alarmengine.status.resources` shows **6 managed resources** (Service, Deployment, Ingress, 3 Jobs) and the controller logs **"5 objects remaining for deletion"** (A1). The runbook's "strip the one stuck Job → cascade finishes" is *probably* correct (only one Job has a stuck finalizer), but the operator must verify the count drops, because a normal `Deployment`/`Service`/`Ingress` delete that hangs (e.g., Ingress with its own finalizer, PDB, or stuck LB) would also keep alarmengine wedged. **Do not assume one patch clears all five.**

### Blast radius — can these commands touch OTHER FBE slots or shared argocd objects?

**No. Confirmed voltex-namespace-scoped.** (A1)

- Stuck Job `tracking-id=voltex_alarmengine` → namespace `voltex`. `kubectl patch job ... -n voltex` is namespace-pinned; cannot reach afi/ionix/jupiter/ishtar/kidu/thor/veku/boltz/operations namespaces.
- All 10 other `*-app-of-apps` in the ApplicationSet status are independent objects (afi/ionix/ishtar/jupiter/kidu/thor/veku Synced-Healthy; boltz/operations OutOfSync-Progressing — *pre-existing, unrelated to voltex*). Touching voltex objects does not mutate them. (A1)
- Cluster-scoped objects matching "voltex": only `kps-voltex-prometheus` ClusterRole/Binding, created 2026-06-04 10:33 — these belong to the **separate monitoring stack**, NOT the vpp-core deletion path. The runbook does not (and must not) touch them. (A1)

**STOP-CONDITION for safety:** every command must carry `-n voltex` and a literal object name. No label selectors, no `-l`, no `--all`. A wildcard or wrong-namespace command is the only way to escape the blast radius.

---

## 2. RECREATION GUARANTEE (O3) — the decisive finding

**CONFIRMED: the ApplicationSet WILL auto-recreate `voltex-app-of-apps` once the stuck object finishes Terminating. No pipeline rerun is required.** This is the strongest evidence in the review and it *removes* a step the runbook hedged on.

Evidence (A1):
- ApplicationSet `vpp-feature-branch-environments` `status.resources` currently lists **10** app-of-apps and **voltex-app-of-apps is present** in the generated set. The generator still wants voltex. (A1)
- ApplicationSet controller log (`argocd-applicationset-controller`, image `quay.io/argoproj/argocd:v3.0.12`) shows it **actively reconciling voltex right now**: repeated `"Deleted application" voltex-app-of-apps` (it keeps re-issuing delete because the object is mid-termination), then `"updated Application" voltex-app-of-apps` at 11:41. (A1)
- **Empirical default-behavior proof:** the SAME controller, with `syncPolicy=None` (no `applicationsSync`, no `strategy`), logged `"created Application" fbe-voltex-monitoring` at 10:33 from its generator. A `syncPolicy=None` ApplicationSet on this cluster **does create Applications from the generator**. Therefore the create-path for voltex-app-of-apps is live and will fire on the next reconcile after the old object is gone. (A1)

**Mechanism of the deadlock (why it can't recreate now):** Kubernetes will not allow two objects with the same name in `argocd`. The controller wants to create a fresh `voltex-app-of-apps`, but the old one is stuck in `Terminating`. So it loops on `"Deleted application"` and cannot create. The instant the old object's finalizer clears and it disappears, the next reconcile (≤3 min cadence, observed) creates a fresh one.

**Conclusion for the runbook:** Step 5's "If not auto-recreated, re-run create pipeline 2412" is a *fallback that the evidence says will not be needed*. Keep it as a stop-condition fallback (in case the generator file is removed from VPP.GitOps HEAD — see caveat below), but the primary expectation is automatic recreation.

**Caveat (A2/A3):** I confirmed voltex is in the *generated parameter set* (live), but I did not independently fetch VPP.GitOps HEAD `feature-branch-environments/voltex.yaml` (no repo access in this lane). The local clone is stale (2025-11-18). The fact the generator currently lists voltex (A1) implies the file exists at HEAD (A2). If, between now and the fix, someone removes voltex.yaml from HEAD, the ApplicationSet would instead *prune* voltex and never recreate it — that is the one scenario requiring the pipeline rerun. Verify voltex remains in `status.resources` immediately before clearing the finalizer.

---

## 3. FINALIZER-REMOVAL RESIDUE (O4)

If Step 4 (force-remove `resources-finalizer` from alarmengine, then app-of-apps) is reached:

**What orphans:** alarmengine's managed k8s objects in ns voltex (`Service/alarmengine`, `Deployment/alarmengine`, `Ingress/alarmengine`, plus the 2 clean Jobs). Force-removing `resources-finalizer` deletes the *Application CR* immediately but leaves these k8s objects in place (that is precisely what the finalizer existed to clean up). (A2, from ArgoCD finalizer semantics + live resource list A1)

**Adoption on recreate — collision risk is REAL and must be checked:** alarmengine uses **tracking by annotation** (`argocd.argoproj.io/tracking-id=voltex-app-of-apps:.../alarmengine`), `ownerReferences=[]` (A1). When the fresh app-of-apps recreates a fresh alarmengine Application and syncs, ArgoCD adopts existing live objects **by tracking-id label/annotation match**, not by ownerReference. Same-named `Service/Deployment/Ingress alarmengine` with matching tracking-id → **adopted in place, no collision** (this is the normal, benign case). (A2)

**The genuine residue risk:** if Step 4 removes the finalizer *while objects are still mid-delete with their own finalizers* (e.g., the Ingress controller hasn't released the LB), you get half-deleted k8s objects that the recreated Application then tries to re-sync onto — possible `FailedSync`/immutable-field conflicts (e.g., Service `clusterIP`, Deployment selector). **This is why Step 4 must only run after Steps 1–3 have driven "objects remaining" toward 0, never as a shortcut.**

**Verdict on Step 4:** acceptable as a *gated last resort*, NOT as a default. It is the only command in the whole runbook that destroys ArgoCD's cleanup contract. Gate it behind an explicit 5-minute wait + a recheck that the remaining-object count is stuck (not still decreasing).

---

## 4. POST-FIX HEALTH (O5) — the fix does NOT fully restore the FBE

This is the runbook's biggest blind spot. **Clearing the deadlock recreates the topology but does NOT fix the two things that made Pester red.**

### Will the seed PostSync hook re-wedge the next deletion?

**Yes, almost certainly — unless the alarmengine API 500 is fixed.** Evidence (A1):
- The PostSync hook `POST http://alarmengine:8080/api/alarmengine → 500` → `BackoffLimitExceeded`, repeated across jobs at 16d / 7d / 23h intervals (`-1779114304`, `-1779884943`, `-1780487852` pods all `Error`). (A1)
- The hook-delete-policy is `BeforeHookCreation` — a failed hook Job is left in place until the next sync. The *original* deadlock was a `BeforeHookCreation` hook Job (`-1779187628`) that got stuck with its finalizer during a delete. **The same failure mode will recur on the next FBE teardown** if the seeding endpoint still 500s. (A2)

**So Step 6 ("fix the failing seed hook") is not optional cleanup — it is the actual root cause.** The deadlock is a *symptom*; the chronically-failing seed endpoint is the *generator of recurrence*. Recreating voltex without fixing the 500 produces a freshly-deadlock-prone FBE. The runbook ordering (fix hook "separately", last) under-rates it. Recommend: recreate to unblock Stefan now, but file the alarmengine `/api/alarmengine` 500 as the P-fix, because every future voltex teardown re-wedges otherwise.

### Does recreating the frontend Application fix the 404?

**Unproven — and probably not purely.** (A2/A3)
- The frontend 404 + `frontend`/`monitor` pods stuck `Succeeded`/Terminating since 2026-05-18 with **owning ReplicaSets already gone** (`no frontend/monitor RS`) means the frontend/monitor *workloads were already pruned in a prior cycle* — they are zombie pods, not a running-but-broken frontend. (A1)
- ns voltex currently has **0 Deployments** (A1) — there is no frontend Deployment serving anything; the 404 is "nothing is there," consistent with the half-deployed state.
- Recreating the frontend child Application *should* redeploy the frontend Deployment and restore 200 **IF** the frontend child syncs cleanly. But the frontend child is one of the 21 `NoHealthKey` (desired-but-not-materialised) children — I could not probe its sync viability because it does not exist yet. There may be a frontend-specific seed/config dependency (the same seeding pattern) that fails independently. **Cannot guarantee 404→200 from recreation alone.** (A3 — blocked: child app not materialised, cannot probe pre-creation)

**Runbook defect (MEDIUM):** Step 2 force-deletes the frontend/monitor zombie pods and the diagnosis frames them as part of the alarmengine cascade blocker. They are **not** — they have `finalizers=None` and are not alarmengine-managed (frontend/monitor belong to their own pruned child apps). Force-deleting them is *safe and good hygiene* (orphaned pods on node `aks-agentpool-...00009s`, no RS to recreate them), but it does **not** advance the alarmengine deletion. Presenting it as the unblock is misleading. Keep the step, re-label its purpose as "clear node-orphaned zombie pods" not "unblock cascade."

---

## 5. SAFEST DEFENDED RUNBOOK

Surface choice: **raw `kubectl patch` of the single stuck Job finalizer is the correct minimal surface — NOT `argocd app delete --cascade`.** Justification (A1/A2): the Applications are *already* mid-deletion (delTS set); issuing `argocd app delete` again does nothing new and `--cascade` would re-trigger the same wedged finalizer path. The wedge is a k8s finalizer on a Job, which ArgoCD's app-delete cannot reach. Patch the Job; let ArgoCD's own controller finish the cascade it is already running.

Pre-flight (run once, abort if any fails):
```bash
# P0: confirm voltex is STILL the generator's desired state (else recreation won't happen)
kubectl --context vpp-aks01-d -n argocd get applicationset vpp-feature-branch-environments \
  -o jsonpath='{range .status.resources[*]}{.name}{"\n"}{end}' | grep -x voltex-app-of-apps \
  || echo "ABORT: voltex no longer generated — pipeline rerun required, do NOT clear finalizer"
```

**Step 1 — strip the stuck hook-finalizer (minimal, scoped, non-destructive).**
```bash
kubectl --context vpp-aks01-d -n voltex patch job seed-assets-alarmengine-postsync-1779187628 \
  --type=merge -p '{"metadata":{"finalizers":[]}}'
```
Verify: `kubectl --context vpp-aks01-d -n voltex get job seed-assets-alarmengine-postsync-1779187628` → `NotFound`.
Stop-condition: if Job still present after 30s, do NOT proceed to Step 4; investigate why (admission webhook? CRD finalizer re-add?).

**Step 2 — clear node-orphaned zombie pods (hygiene; NOT the cascade unblock).**
```bash
kubectl --context vpp-aks01-d -n voltex delete pod frontend-8556c9dffd-7t9w5 monitor-5b45c988c5-sr45x \
  --grace-period=0 --force
```
Safe because: `finalizers=None`, owning ReplicaSets gone (`no frontend/monitor RS`), phase `Succeeded`. Nothing recreates them.
Verify: `kubectl ... -n voltex get pod frontend-8556c9dffd-7t9w5 monitor-5b45c988c5-sr45x` → `NotFound`.

**Step 3 — watch the cascade drain (the real success signal).**
```bash
watch -n5 'kubectl --context vpp-aks01-d -n argocd logs argocd-application-controller-0 --tail=50 \
  | grep -E "voltex/alarmengine|voltex-app-of-apps" | grep "remaining for deletion" | tail -4'
```
Expect: alarmengine "5 objects remaining" → counts down → alarmengine CR `NotFound`; then app-of-apps "1 object remaining" → app-of-apps CR `NotFound`.
Verify: `kubectl ... -n voltex get application alarmengine` → NotFound; `kubectl ... -n argocd get application voltex-app-of-apps` → NotFound (briefly) then **recreated with NEW creationTimestamp**.
**STOP-CONDITION:** if "objects remaining" does not decrease within 5 minutes after Steps 1–2, the blocker is NOT the Job — enumerate `alarmengine.status.resources` and find which of the 6 still has a finalizer/hang. Do NOT jump to Step 4 blindly.

**Step 4 — LAST RESORT ONLY (gated, destructive). Force-remove resources-finalizer.**
Pre-condition: Steps 1–3 done AND remaining count stuck >5 min AND you have identified no other k8s finalizer to clear.
```bash
# alarmengine FIRST (child), then app-of-apps (parent) — never the reverse
kubectl --context vpp-aks01-d -n voltex patch application alarmengine \
  --type=merge -p '{"metadata":{"finalizers":[]}}'
# verify alarmengine gone and count→0 before touching parent
kubectl --context vpp-aks01-d -n argocd patch application voltex-app-of-apps \
  --type=merge -p '{"metadata":{"finalizers":[]}}'
```
Residue check after recreate: `kubectl ... -n voltex get svc,deploy,ingress alarmengine` adopted by fresh app (tracking-id match) — watch for `FailedSync`/immutable-field errors; if Service clusterIP or Deployment selector conflicts, delete the conflicting object and let the fresh sync recreate it.
**ROLLBACK NOTE:** there is no rollback for finalizer removal — once removed, the CR is gone. This is why it is gated.

**Step 5 — confirm auto-recreation (expected, no pipeline rerun).**
```bash
kubectl --context vpp-aks01-d -n argocd get application voltex-app-of-apps \
  -o jsonpath='{.metadata.creationTimestamp}{"\n"}' # must be AFTER the fix time
kubectl --context vpp-aks01-d -n voltex get applications  # expect ~20+ children materialising
```
Fallback (only if P0 abort fired or no recreate in 5 min): re-run ADO create pipeline (buildId path per intake), do not manually `kubectl create`.

**Step 6 — ROOT-CAUSE fix (not optional): alarmengine `/api/alarmengine` 500.**
The recreated FBE will re-wedge on its NEXT teardown if the seed endpoint still 500s (same `BeforeHookCreation` hook-finalizer trap). Recreating voltex unblocks Stefan now; it does NOT fix the recurrence generator. Verify post-recreate:
```bash
kubectl --context vpp-aks01-d -n voltex get pods | grep seed-assets-alarmengine  # watch for fresh Error pods
kubectl --context vpp-aks01-d -n voltex logs <newest seed-assets-alarmengine pod>  # confirm 500 vs 200
```
And independently verify the frontend 404→200 — recreation alone is NOT proven to fix it (frontend child may have its own seed dependency; could not probe pre-creation).

---

## Residual risks (must be surfaced to authorizer)

1. **A3 — VPP.GitOps HEAD freshness:** recreation guarantee assumes voltex.yaml still at HEAD; P0 check mitigates but only at point-in-time.
2. **A3 — frontend 404 fix unproven:** child app not materialised; cannot pre-probe. May need separate frontend seed fix.
3. **A2 — Step 4 immutable-field collisions** on adopt-in-place if objects half-deleted; mitigated by ordering Step 4 after the cascade drains.
4. **Recurrence:** without Step 6, the alarmengine 500 reproduces this exact deadlock on the next voltex teardown (~observed 16d/7d/23h cadence of failed hooks).
