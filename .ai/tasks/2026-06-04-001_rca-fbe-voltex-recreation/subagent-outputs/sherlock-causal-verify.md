---
task_id: 2026-06-04-001
agent: sherlock-holmes
timestamp: 2026-06-04T12:05:00Z
status: complete
summary: |
  Independent read-only reproduction of the voltex FBE recreation-failure causal
  chain on live vpp-aks01-d (Sandbox). VERDICT: causal chain CONFIRMED. E2/E4/E6/E7/E8
  all reproduce with exact-match live output. Alternatives a/b/c/d all REFUTED. The
  alarmengine cascade hard-blocker is precisely identified: the single seed Job
  seed-assets-alarmengine-postsync-1779187628 holds argocd.argoproj.io/hook-finalizer
  (sole finalizer-bearing terminating object in alarmengine's managed set; Deployment
  already gone, Service/Ingress finalizer-free). O1 BOUNDED, not pinned: the actor is
  the ApplicationSet (argocd-applicationset-controller), evidenced by a delete-loop in
  its log and ownerRef; the precise 13:14:51 trigger source (destroy pipeline vs prune)
  cannot be A1-pinned from surviving managedFields. Two framing corrections to the ledger
  noted (count semantics; alarmengine health=Missing not Healthy).
reproduction_status: reproducible
failure_rate: "100%"
---

# Sherlock Causal-Verify — voltex FBE recreation failure

## Key Findings

- reproduction_status: reproducible
- failure_rate: 100% (live, looping at probe time)
- top_hypothesis: ArgoCD finalizer deadlock; auto-sync skipped on deletion-in-progress; cascade wedged on seed Job hook-finalizer
- confidence: high
- recommended_next_step: escalate-to-pathologist

All probes read-only, live cluster `vpp-aks01-d` ns `argocd`, sub
`7b1ba02e-bac6-4c45-83a0-7f0d3104922e`, captured 2026-06-04 ~11:47–11:51 UTC.
kubectl context + argocd v3.4.3 confirmed at session start. No mutations issued.

## Overall verdict

**Causal chain CONFIRMED.** The diagnosis is correct on mechanism and proximate/
enabling/root structure. Two framing inaccuracies and one genuinely-open item (O1
precise trigger) are documented below. Nothing falsifies the core chain.

---

## Per-claim verdicts (E2/E4/E6/E7/E8)

### E2 — voltex-app-of-apps deletionTimestamp + finalizer + ownerRef — CONFIRMED (A1)

Command:
```bash
kubectl -n argocd get application voltex-app-of-apps \
  -o jsonpath='{.metadata.deletionTimestamp}{"\n"}{.metadata.finalizers}{"\n"}{range .metadata.ownerReferences[*]}{.kind}/{.name}{"\n"}{end}'
```
Output (exact):
```
2026-06-03T13:14:51Z
["resources-finalizer.argocd.argoproj.io"]
ApplicationSet/vpp-feature-branch-environments
```
Matches ledger byte-for-byte. sync=OutOfSync health=Progressing also confirmed.

### E4 — alarmengine deletionTimestamp + finalizer — CONFIRMED (A1), with one correction

Command:
```bash
kubectl -n voltex get application alarmengine \
  -o jsonpath='{.metadata.deletionTimestamp}{"\n"}{.metadata.finalizers}{"\n"}'
kubectl -n voltex get application alarmengine -o jsonpath='sync={.status.sync.status} health={.status.health.status}'
```
Output (exact):
```
2026-06-03T13:14:51Z
["resources-finalizer.argocd.argoproj.io"]
sync=OutOfSync health=Missing
```
deletionTimestamp + finalizer CONFIRMED, identical to E2's timestamp (same delete event).
**CORRECTION to ledger E3:** ledger called alarmengine `OutOfSync/Healthy`; live health is
**Missing** (its Deployment is already gone — see "5 objects" analysis). Likely flapped:
voltex events show `Healthy -> Missing` transition at probe time. Not material to the chain.

### E6 — "Skipping auto-sync: deletion in progress" — CONFIRMED (A1)

Command:
```bash
kubectl -n argocd logs argocd-application-controller-0 --since=20m | grep -i "deletion in progress" | grep -i voltex
```
Output (representative, both apps, live within last minutes):
```
{"app-qualified-name":"voltex/alarmengine","msg":"Skipping auto-sync: deletion in progress","time":"2026-06-04T11:47:37Z"}
{"app-qualified-name":"argocd/voltex-app-of-apps","msg":"Skipping auto-sync: deletion in progress","time":"2026-06-04T11:47:37Z"}
```
Looping continuously for BOTH app-of-apps and alarmengine. CONFIRMED. This is the enabling
cause: auto-sync (and thus child/ApplicationSet recreation) is suppressed while the deletion
is pending.

### E7 — "N objects remaining for deletion" — CONFIRMED (A1)

Command:
```bash
kubectl -n argocd logs argocd-application-controller-0 --since=20m | grep -iE "objects remaining for deletion" | grep -iE "voltex|alarmengine"
```
Output (exact, repeating):
```
{"app-qualified-name":"argocd/voltex-app-of-apps","msg":"1 objects remaining for deletion","time":"2026-06-04T11:49:31Z"}
{"app-qualified-name":"voltex/alarmengine","msg":"5 objects remaining for deletion","time":"2026-06-04T11:49:24Z"}
```
app-of-apps = `1 objects remaining`, alarmengine = `5 objects remaining`. CONFIRMED.

### E8 — seed Job hook-finalizer stuck Terminating — CONFIRMED (A1)

Command:
```bash
kubectl -n voltex get jobs -o custom-columns='NAME:.metadata.name,DELTS:.metadata.deletionTimestamp,FIN:.metadata.finalizers'
```
Output (relevant row, the ONLY finalizer-bearing job):
```
seed-assets-alarmengine-postsync-1779187628   2026-05-19T10:52:23Z   [argocd.argoproj.io/hook-finalizer]
```
Plus E9 confirmed in same scan:
```
Pod frontend-8556c9dffd-7t9w5  delTS=2026-05-18T08:29:24Z  (phase Succeeded)
Pod monitor-5b45c988c5-sr45x   delTS=2026-05-18T11:02:38Z  (phase Succeeded)
```
CONFIRMED.

---

## EXACT identity of the cascade blocker ("5 objects remaining") — refined (Attack #3)

alarmengine `.status.resources` (6 managed objects):
```bash
kubectl -n voltex get application alarmengine -o json | jq '.status.resources'
```
```
/Service                 voltex/alarmengine                              Synced
apps/Deployment          voltex/alarmengine                              OutOfSync
batch/Job                voltex/seed-assets-alarmengine-postsync-1779187628  (hook)
batch/Job                voltex/seed-assets-alarmengine-postsync-1779884943
batch/Job                voltex/seed-assets-alarmengine-postsync-1780487852
networking.k8s.io/Ingress voltex/alarmengine                             Synced
```
Per-object finalizer/delTS probe:
```bash
for r in service/alarmengine deployment/alarmengine ingress/alarmengine \
  job/...1779187628 job/...1779884943 job/...1780487852; do kubectl -n voltex get $r ...; done
```
```
Service/alarmengine   delTS=  fin=                         (clean)
deployment alarmengine: Error NotFound                      (ALREADY GONE)
Ingress/alarmengine   delTS=  fin=                         (clean)
Job ...1779187628     delTS=2026-05-19  fin=[hook-finalizer]   <-- HARD BLOCKER
Job ...1779884943     delTS=  fin=                         (clean)
Job ...1780487852     delTS=  fin=                         (clean)
```

**Finding:** the ONLY object in alarmengine's managed set carrying a finalizer + deletionTimestamp
is `seed-assets-alarmengine-postsync-1779187628` (`argocd.argoproj.io/hook-finalizer`).
Service/Ingress are finalizer-free and cascade cleanly; the Deployment is already deleted. So
**the seed Job hook-finalizer is verified as the sole hard blocker** — NOT a stuck namespace,
NOT a foregroundDeletion dependency, NOT an admission webhook (no webhook/NetworkPolicy/PDB/etc.
finalizers found in a multi-kind scan of ns voltex).

**Framing correction:** the literal "5 objects remaining" is ArgoCD's bookkeeping count of
tracked resources it has not yet confirmed deleted (Deployment record + 3 Jobs + Service/Ingress
churn), not "5 finalizer-stuck objects." Only ONE of them is actually finalizer-wedged. The
ledger's mechanism conclusion (seed Job hook-finalizer blocks the cascade) holds; the count
semantics are looser than the ledger implies. Likewise app-of-apps "1 objects remaining" = the
alarmengine Application child, consistent with E7.

Root of the wedge confirmed (E10): latest failed seed pod log:
```bash
kubectl -n voltex logs seed-assets-alarmengine-postsync-1780487852-gfdvw
```
```
base url : http://alarmengine:8080/api/alarmengine
StatusCode: 500
Exception: ... throw "Status code did not indicate success."
```
The seeding endpoint 500 → BackoffLimitExceeded → hook never reaches success → ArgoCD never
strips the hook-finalizer. CONFIRMED as the mechanistic origin of the wedge.

---

## Alternative falsification (a/b/c/d) — all REFUTED

### (a) Helm render / appconfig failure on his branch — REFUTED (A1)
app-of-apps `operationState.phase = Succeeded`, message `successfully synced (all tasks run)`;
`status.conditions = <NONE>` (no ComparisonError / no render error). Source revision resolves
(targetRevision `feature/fbe-826335-...`). The branch render is fine; the app is stuck on
deletion, not on a failed render.
```bash
kubectl -n argocd get application voltex-app-of-apps -o json | jq '.status.conditions, .status.operationState.phase'
# [] ... "Succeeded"
```

### (b) credential / source-N ComparisonError on app-of-apps — REFUTED (A1)
Same probe: `conditions = <NONE>`, no `ComparisonError`, no `InvalidSpecError`. Multi-source
Helm config present and resolving. No credential error surfaced.

### (c) ApplicationSet generator failing — REFUTED (A1)
```bash
kubectl -n argocd get applicationset vpp-feature-branch-environments -o json | jq '.status.conditions'
```
```
ErrorOccurred       = False | Successfully generated parameters for all Applications
ParametersGenerated = True  | Successfully generated parameters for all Applications
ResourcesUpToDate   = True  | ApplicationSet up to date
```
Generator healthy. The ApplicationSet is functioning; it is blocked downstream by the wedged
Application, not by its own generation.

### (d) is alarmengine the ONLY surviving child; are the other 21 genuinely absent vs filtered — CONFIRMED ABSENT (A1)
```bash
kubectl get applications -A -o json | jq '[.items[]|select(.metadata.namespace=="voltex").metadata.name]'
# ["alarmengine"]
```
Only `alarmengine` is a live Application CRD in ns `voltex`. The other 21 names DO exist — but
in OTHER FBE slots (afi, ionix, ishtar, jupiter, kidu, thor, veku, vpp, ...), proving they are
genuinely absent FOR VOLTEX, not present-but-UI-filtered. The 21 appear only in app-of-apps
`.status.resources` as desired-but-unmaterialised (no health key). CONFIRMED: 21 genuinely
absent CRDs; alarmengine is the sole surviving (and itself-terminating) child.

---

## O1 — who issued the delete @ 13:14:51 — BOUNDED, not A1-pinned (Attack #4)

Evidence FOR the ApplicationSet being the actor:
- ownerRef on voltex-app-of-apps = `ApplicationSet/vpp-feature-branch-environments` (E2).
- `argocd-applicationset-controller` log shows a **delete loop** on this exact app:
  ```bash
  kubectl -n argocd logs deployment/argocd-applicationset-controller --tail=600 | grep voltex-app-of-apps
  ```
  ```
  "msg":"Deleted application","app":"argocd/voltex-app-of-apps","time":"2026-06-04T10:01:21Z"
  ... repeating every ~3 min through 10:31:24Z ...
  "msg":"updated Application","time":"2026-06-04T10:34:24Z"
  "msg":"updated Application","time":"2026-06-04T11:41:16Z"
  ```
- managedFields (--show-managed-fields) on voltex-app-of-apps: only two managers ever —
  `argocd-applicationset-controller` (Update 10:34:24Z) and `argocd-application-controller`.
  No human/pipeline service-account manager is present.

Interpretation (A2 INFER): the delete was issued by the **ApplicationSet controller**
(prune of the generated Application), not a manual `argocd app delete` and not a separate
destroy pipeline acting directly on the CRD. The ApplicationSet repeatedly re-issued the
delete (10:01–10:31) because the finalizer wedge kept the object alive, then flipped to
`updated Application` (10:34, 11:41) — i.e. **the ApplicationSet now WANTS voltex-app-of-apps
to EXIST again** but the stale 06-03 deletionTimestamp + "deletion in progress" auto-sync skip
prevent reconciliation. This is the deadlock, independently corroborated from the
ApplicationSet side.

**Residual uncertainty (A3):** the precise actor/trigger at the original `2026-06-03T13:14:51Z`
delete cannot be A1-pinned — surviving managedFields retain only last-Update times (10:34/11:50),
not the 06-03 delete operation, and the application-controller log window does not reach back to
06-03. Whether the 13:14:51 delete was an ApplicationSet prune (git generator transiently dropped
voltex.yaml) or a destroy-pipeline-driven `argocd app delete` is NOT distinguishable from current
live state. The ledger's own O1 stance ("not pinned — A3; fix is trigger-independent") is correct.
The fix does not depend on resolving this.

---

## Where the diagnosis is corrected / refined

1. **alarmengine health** is `Missing` (Deployment gone), not `Healthy` (ledger E3). Minor.
2. **"5 objects remaining"** is an ArgoCD tracking count, not 5 finalizer-stuck objects; exactly
   ONE (the seed Job) is finalizer-wedged. Mechanism unchanged; semantics tightened.
3. **O1 is now bounded to "ApplicationSet controller issued the delete(s)"** via owner+log+
   managedFields, upgrading the ledger's fully-open O1 to: actor = ApplicationSet (A2),
   precise original trigger source = still A3.

## Residual uncertainty / handoff to pathologist
- O1 precise 06-03 trigger source (prune vs destroy pipeline) — unpinnable from live state;
  would need ADO pipeline run history (buildId 2629/destroy) or longer controller log retention.
- O4 (finalizer-strip safety) and O5 (seed 500 keeps FBE unhealthy after recreate) are
  diagnosis/forward-looking, out of this reproduction lane — flagged for pathologist. The seed
  endpoint 500 (E10) is independently confirmed and WILL re-wedge a fresh alarmengine unless
  fixed, regardless of how the current deadlock is cleared.

## Verdict table

| Claim | Verdict | Basis |
|-------|---------|-------|
| E2 | CONFIRMED | exact-match jsonpath output |
| E4 | CONFIRMED (health corrected to Missing) | exact-match jsonpath output |
| E6 | CONFIRMED | live looping controller log |
| E7 | CONFIRMED | live looping controller log (1 / 5) |
| E8 | CONFIRMED | only finalizer-bearing job = seed ...1779187628 |
| alt (a) render/appconfig | REFUTED | operationState=Succeeded, conditions=none |
| alt (b) ComparisonError | REFUTED | conditions=none |
| alt (c) ApplicationSet generator | REFUTED | ErrorOccurred=False, ParametersGenerated=True |
| alt (d) absent vs filtered | CONFIRMED ABSENT | only alarmengine live in voltex; 21 exist in other slots |
| Cascade blocker identity | CONFIRMED = seed Job hook-finalizer (sole) | per-object finalizer probe |
| O1 actor | BOUNDED = ApplicationSet controller (A2) | ownerRef + delete-loop log + managedFields |
| O1 precise trigger | OPEN (A3) | not recoverable from live state |
