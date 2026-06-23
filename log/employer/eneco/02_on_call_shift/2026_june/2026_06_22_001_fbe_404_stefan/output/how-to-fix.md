---
task_id: 2026-06-22-005
agent: principal-engineer-document-writer
status: review
adversarial_review: external
summary: Self-sufficient repair spec for the FBE finalizer-wedge failure class — clear a stuck resources-finalizer on a slot's app-of-apps so the 21-day-pending deletion completes and the ApplicationSet self-heals the slot from 404 to 200. Mechanism, gated preconditions, the two patch commands, expected self-heal, verification, rollback boundary, and safety gates included.
---

# How To Fix — FBE slot 404 from an ArgoCD finalizer-wedged app-of-apps

> **Companion RCA**: [`rca.md`](./rca.md). This document is the standalone repair
> spec: an engineer or agent who has never seen this incident can fix THIS class
> of failure cold from here. Read the Mechanism Recap, then do not skip the
> preconditions — finalizer removal is a one-way door.

## Fix Knowledge Contract

After reading this, the operator can:

1. explain which invariant the fix restores (a slot's app-of-apps must be
   reconcilable, not frozen mid-deletion);
2. apply the change without relying on author memory;
3. prove the control plane converged (fresh app-of-apps, children synced, URL
   200);
4. stop safely when a precondition probe disagrees;
5. name the residual risks the fix intentionally does not close.

## Mechanism Recap

A Feature Branch Environment (FBE) slot is deployed by a single ArgoCD
Application — the **app-of-apps** — that fans out into ~21 child Applications
(`frontend`, gateways, services). That app-of-apps is generated and owned by a
shared **ApplicationSet** (`vpp-feature-branch-environments`).

The failure class: the app-of-apps (and one or more children) was asked to delete,
Kubernetes stamped a `deletionTimestamp` and the
`resources-finalizer.argocd.argoproj.io` guard, and that guard **never completed**.
While an object carries a deletionTimestamp it is "being torn down" — ArgoCD will
not reconcile it to desired state, so the slot's `frontend`/gateways are never
(re)deployed. The public URL 404s because the edge proxy has no backend behind it.
Worse, the wedged object holds the `<slot>-app-of-apps` **name**, so every create-
pipeline recreate is a silent no-op (a green build that deploys nothing).

The fix restores the invariant by removing the stuck guard so the deletion
completes and the ApplicationSet — which is healthy and still targets the slot —
regenerates a fresh app-of-apps that syncs the whole slot. No pipeline re-run is
needed.

**The finalizer itself is not the bug.** `resources-finalizer.argocd.argoproj.io`
is the normal cascade-delete guard every ArgoCD Application carries — the fresh,
healthy app-of-apps the ApplicationSet regenerates carries it too. The fault is a
finalizer paired with a `deletionTimestamp` whose cleanup never completes. You are
clearing the *stuck* guard on a *dying* object, not removing finalizers from
healthy ones.

## Effort / risk rating

| Dimension | Value |
|---|---|
| Time to fix | ≈5 minutes (two patches + ~1 min self-heal + verify) |
| Complexity | Low — two `kubectl patch` commands |
| Reversibility | **ONE-WAY DOOR** — finalizer removal completes a deletion and cannot be undone; recovery is forward (the ApplicationSet recreates the slot) |
| Blast radius | One FBE slot's two ArgoCD Application CRs; managed workloads already gone |
| Authorization | Explicit current-turn user authorization required (GitOps mutation + destructive cleanup gate) |

## Preconditions to verify (read-only — these PROVE the fix is safe)

Run all of these and confirm the expected result before touching any finalizer.
The purpose is to prove (a) the wedge is real, and (b) the managed workloads are
already gone, so clearing the guard destroys nothing live.

### P1 — Confirm the cluster context

**What / why / expected**: bind to the right cluster before reading or writing;
the FBE Sandbox is direct `kubectl` (no AVD), context `vpp-aks01-d`. Expect the
context to be listed.

```bash
kubectl config get-contexts | grep vpp-aks01-d
```

### P2 — Prove the app-of-apps is wedged mid-deletion (the decisive probe)

**What / why / expected**: read the slot's app-of-apps CR directly — it is the
authoritative surface for a finalizer wedge (the UI "Deleting" badge is just these
fields rendered). Expect a **non-empty** `deletionTimestamp` and the finalizer
`resources-finalizer.argocd.argoproj.io`. If `deletionTimestamp` is empty, **STOP**
— this is not the finalizer-wedge class; do not remove any finalizer.

```bash
kubectl --context vpp-aks01-d -n argocd \
  get application operations-app-of-apps -o json | \
  jq '{deletionTimestamp:.metadata.deletionTimestamp,
       finalizers:.metadata.finalizers,
       owner:.metadata.ownerReferences}'
```

### P3 — Prove the managed workloads are already gone (safety of removal)

**What / why / expected**: P2 (the app-of-apps `deletionTimestamp`) is the
authoritative gate for *whether this is the class*; P3 is the *secondary safety*
check that the finalizer's cleanup target is already gone before you complete the
deletion. Expect the slot's web backends (`frontend`, `clientgateway`,
`gateway-nl`) to have **no live, serving Service/Pod**. A straggler child that is
**itself mid-deletion** (e.g. `assetmonitor` here, also carrying a
`deletionTimestamp`) is **tolerated, not a STOP** — clearing its finalizer too is
part of the fix.

**STOP condition (narrow):** abort only if a `frontend` Service/Pod is **Running
and serving** (a genuine live workload) **AND** the app-of-apps has **no**
`deletionTimestamp` — that combination means this is not the finalizer-wedge class.
Do **not** abort merely because the namespace is `Active` (a wedged Application
always leaves the namespace `Active` while a sibling syncs into it — the namespace
phase is not the decider; the app-of-apps `deletionTimestamp` from P2 is).

```bash
kubectl --context vpp-aks01-d -n operations get applications
kubectl --context vpp-aks01-d -n operations get pods,ingress
```

### P4 — Prove the ApplicationSet generator is healthy (self-heal will fire)

**What / why / expected**: the self-heal depends on the ApplicationSet being able
to regenerate the app-of-apps. Expect `ErrorOccurred=False`,
`ParametersGenerated=True`, `ResourcesUpToDate=True`. If `ErrorOccurred=True` with
`authentication required`, the generator is dead (PAT expiry) — a **different**
fix; STOP and rotate the PAT instead.

```bash
kubectl --context vpp-aks01-d -n argocd \
  get applicationset vpp-feature-branch-environments -o json | \
  jq -r '.status.conditions[]? | "\(.type)=\(.status)"'
```

### P5 — Confirm the 404 has no backend (not a routing problem)

**What / why / expected**: a real VPP pod stamps `x-correlation-id`. Expect a 404
from `nginx` with **no** `x-correlation-id` → undeployed backend. A 404 *with*
that header means objects exist and the path is misaligned — a different runbook;
STOP.

```bash
curl -svk "https://operations.dev.vpp.eneco.com/" 2>&1 | \
  grep -iE "HTTP/|x-correlation-id|Request-Context|server"
```

### P6 — Snapshot before mutating (one-way door)

**What / why / expected**: finalizer removal is irreversible; capture the pre-fix
objects first. Expect two YAML files written. Write failure → STOP.

```bash
kubectl --context vpp-aks01-d -n argocd get application operations-app-of-apps -o yaml \
  > operations-app-of-apps.prefix.yaml
kubectl --context vpp-aks01-d -n operations get application assetmonitor -o yaml \
  > assetmonitor.prefix.yaml
```

## Fix Plan

The ordered repair, each step gated on the prior. Steps 1–6 are the read-only
preconditions above (P1–P6); steps 7–8 are the mutation and self-heal.

| Step | Action | State / control plane changed | Why it closes the mechanism | Positive-signal proof | Stop condition |
|---|---|---|---|---|---|
| 1 | Bind context + prove the wedge (P1, P2) | — (read-only) | Confirms this is the finalizer-wedge class | non-empty `deletionTimestamp` + finalizer | P2 empty `deletionTimestamp` → not this class |
| 2 | Prove workloads gone + generator healthy (P3, P4) | — (read-only) | Confirms removal is safe and self-heal will fire | no live `frontend`; `ErrorOccurred=False` | live serving `frontend` + no deletionTimestamp, or `ErrorOccurred=True` |
| 3 | Confirm 404 has no backend (P5) | — (read-only) | Confirms undeployed, not mis-routed | 404 with no `x-correlation-id` | 404 *with* `x-correlation-id` → different runbook |
| 4 | Snapshot both wedged CRs (P6) | — (write to local file) | Preserves forensic state before a one-way door | two YAML files written | write failure |
| 5 | Patch `operations-app-of-apps` finalizers → `[]` | ArgoCD / Kubernetes | Frees the slot's app-of-apps name so it can be regenerated | `…/operations-app-of-apps patched` | patch error |
| 6 | Patch `assetmonitor` finalizers → `[]` | ArgoCD / Kubernetes | Removes the co-wedged orphan child | `…/assetmonitor patched` | patch error |
| 7 | Let the ApplicationSet self-heal (no pipeline) | ArgoCD reconcile | Fresh app-of-apps syncs the full child set | fresh app-of-apps `Synced/Healthy`; URL 200 | URL still 404 after settle → re-check P4 |

## The fix commands

Both are merge patches that set `finalizers` to empty — nothing else on the
objects changes. Each returns `application.argoproj.io/<name> patched`. Run them
only after P1–P6 pass and with explicit authorization.

```bash
# 1. Clear the wedged finalizer on the slot's app-of-apps (ns argocd).
kubectl --context vpp-aks01-d -n argocd \
  patch application operations-app-of-apps --type=merge \
  -p '{"metadata":{"finalizers":[]}}'

# 2. Clear the wedged finalizer on the orphan child (ns operations).
kubectl --context vpp-aks01-d -n operations \
  patch application assetmonitor --type=merge \
  -p '{"metadata":{"finalizers":[]}}'
```

## Why each command closes the failure

| Command | Control plane | Why it closes the mechanism |
|---|---|---|
| Patch `operations-app-of-apps` finalizers → `[]` | ArgoCD / Kubernetes | Removes the only guard blocking the 21-day-pending deletion; once the object vanishes, its name is free for the ApplicationSet to regenerate a fresh, reconcilable app-of-apps |
| Patch `assetmonitor` finalizers → `[]` | ArgoCD / Kubernetes | Removes the orphan child that was wedged the same way and occupying the namespace, so the fresh app-of-apps owns a clean slot |

## Expected self-heal behaviour

You do **not** run a pipeline. Within roughly a minute of the patches:

1. Both wedged CRs complete deletion and disappear.
2. The ApplicationSet `vpp-feature-branch-environments` (which owns the slot via
   `ownerReference controller:true` and still targets `operations`) regenerates a
   fresh `operations-app-of-apps`.
3. The fresh app-of-apps reconciles and syncs the full child set (`frontend`,
   gateways, services …) into namespace `operations`.
4. The public URL transitions from 404 to 200.

Observed in this incident (durable capture: `convergence-poll.txt` +
`post-fix-verification.txt`): fresh app-of-apps `creationTimestamp
2026-06-22T11:32:48Z`, `Synced/Healthy`, no deletionTimestamp. The **URL served 200
within ~1 min** and stayed 200 (t+1m/t+2m/t+3m); **full child health settled a few
minutes later** — Synced 21 throughout, Healthy climbed 7 → 14 → 19, reaching
21/21 Synced and Healthy at 11:49:46Z.

## Verification

Run every `kubectl` with `--context vpp-aks01-d` — the FBE pattern reuses the
`<slot>-app-of-apps` name across slots/clusters, so a context-less verify is a
silent wrong-cluster read.

| Probe | Expected fixed-state output | If output differs |
|---|---|---|
| `kubectl --context vpp-aks01-d get applications -A -o json \| jq -r '.items[] \| select(.metadata.deletionTimestamp) \| .metadata.name'` | empty (no CR carries a deletionTimestamp) | a name still listed → deletion not complete; re-probe, do not re-patch blindly |
| `kubectl --context vpp-aks01-d -n argocd get application operations-app-of-apps -o jsonpath='{.metadata.creationTimestamp} {.status.sync.status}/{.status.health.status}'` | a **new** creationTimestamp, `Synced/Healthy`, no deletionTimestamp | still old timestamp or Deleting → ApplicationSet has not regenerated; check P4 again |
| `kubectl --context vpp-aks01-d -n operations get application frontend gateway-nl clientgateway` | all present, `Synced/Healthy` (may be briefly `Progressing` while settling) | missing → children not converging; check ApplicationSet and repo-creds |
| `curl -sk -o /dev/null -w '%{http_code}\n' https://operations.dev.vpp.eneco.com/` | `200` | still `404` → backend not up yet (wait/settle) or a co-firing credential gap (P-checks) |

## Rollback boundary

There is **no rollback**. Removing a finalizer completes a deletion, which is
irreversible — the wedged object is gone for good. This is acceptable because the
object was already mid-deletion and starving the slot, and because recovery is
**forward**: the ApplicationSet recreates the slot automatically. The pre-fix
snapshots (P6) exist for the forensic record only, not as a restore path. If the
slot fails to self-heal, the recovery is to investigate the ApplicationSet
generator (P4) — never to re-add a finalizer.

## What This Fix Does Not Change

- **The trigger of the 2026-06-01 deletion.** This restores the slot but does not
  identify or prevent whatever requested the delete. Unverified in this incident
  (the 12:50 local timing did not match the 14:30 auto-evict schedule; `az` was
  not logged in to confirm). Resolve: `az login` → Logic App
  `vpp-fbe-autodelete-trigger` run history + ADO pipeline 2629 runs near 06-01.
- **Why the finalizer wedged in the first place.** The fix clears a *stuck*
  finalizer but does not explain why `resources-finalizer.argocd.argoproj.io`
  failed to complete for 21 days (a controller cycle ~06-16 did not clear it). The
  underlying ArgoCD controller behaviour that let it hang is not addressed here.
- **The destroy pipeline 2629.** Untouched — and it is **not** a rollback (see
  safety gates). The fix neither uses nor changes it.
- **The auto-evict Logic App.** The fix does not disarm `vpp-fbe-autodelete-trigger`;
  a stale limiter row can still re-delete the slot at the next 14:30 run.
- **The pipeline's green-on-no-op behaviour.** A future wedge will again present as
  a successful create build that deploys nothing.

## Operator safety gates (READ BEFORE acting)

- **NEVER run destroy pipeline 2629 to "reset" the slot.** It is **not a
  rollback**. It (a) recursive-F2 — the destroy pipeline's own failures create
  these orphans; (b) is pinned to terraform `1.13.1` against state written by
  `1.14.3`; (c) wipes the slot's 260+ resources, escalating the blast radius from
  "one stuck app-of-apps" to "entire FBE wiped". It requires a human
  platform-owner to accept residue risk — and it is not the fix anyway.
- **Beware the auto-evict Logic App.** `vpp-fbe-autodelete-trigger` (Sandbox, RG
  `rg-vpp-app-sb-401`) runs **Mon–Fri 14:30 W.Europe** and POSTs pipeline 2629
  with `bypassEnvironmentOwnerValidation=true` for any slot idle >4 days. It can
  re-delete the slot while you are repairing it; if the limiter row is stale,
  expect a possible re-break at the next 14:30 run.
- **Confirm you are on the Sandbox cluster first.** Patch only against context
  `vpp-aks01-d`. Never trust a default context; a finalizer patch on the wrong
  cluster is a wrong-blast-radius mutation.
- **Finalizer removal is destructive cleanup — gated on live proof.** Only proceed
  after P2 (wedge real) and P3 (workloads already gone) pass. Do **not** pre-stage
  the patches before those probes return.
- **Do not SYNC or re-run pipeline 2412 against a slot whose app-of-apps carries a
  deletionTimestamp.** A sync into a finalizer-wedged Application reports green and
  renders nothing — resolve the deletion first.
- **GitOps mutation requires explicit current-turn authorization.** One targeted
  fix; do not batch-disable prune/selfHeal; never echo PATs or secrets.
