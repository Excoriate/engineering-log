# Kubernetes & ArgoCD Troubleshooting Mastery

**A Principal Engineer's Mentorship Guide**

From Zero to Hero: Learning to Troubleshoot Like a 10x SRE Through Real-World Case Study

---

## Table of Contents

1. [The Troubleshooter's Mindset](#1-the-troubleshooters-mindset)
2. [Mental Models: Understanding the Machines](#2-mental-models-understanding-the-machines)
3. [The Troubleshooting Map](#3-the-troubleshooting-map)
4. [Command Mastery: The Why Behind Every Command](#4-command-mastery-the-why-behind-every-command)
5. [The Case Study: Pipeline Green, Deployment Dead](#5-the-case-study-pipeline-green-deployment-dead)
6. [Pattern Recognition: Common Failure Modes](#6-pattern-recognition-common-failure-modes)
7. [Building Your Expertise](#7-building-your-expertise)

---

## 1. The Troubleshooter's Mindset

### 1.1 The Fundamental Truth

> "The computer is never wrong. It's doing exactly what it was told. Your job is to understand what it was told and why that differs from what you intended."

Every bug, every failure, every "mysterious behavior" has a causal explanation rooted in the mechanics of the system. There is no magic. There is only machinery you don't yet understand.

### 1.2 The 10x SRE Philosophy

**Principle 1: Observe Before Theorize**

```text
BAD:  "It's probably a network issue" → run random commands → frustration
GOOD: "What do I actually observe?" → gather evidence → form hypothesis → test
```

**Principle 2: Trace the Request Path**

Every operation in a distributed system follows a path. Your job is to find where it diverged from expectation:

```text
User Request → API Gateway → Service → Database → Response
     ↓              ↓            ↓          ↓          ↓
   "Where did expected behavior diverge from actual behavior?"
```

**Principle 3: The Blast Radius Question**

When something fails, immediately ask:
- "What else depends on this?"
- "What does this depend on?"
- "How far does this failure cascade?"

**Principle 4: Assume Nothing, Verify Everything**

```text
"The deployment succeeded" → HOW DO YOU KNOW? What evidence proves this?
"The config is correct" → HOW DO YOU KNOW? Did you validate it?
"The service is healthy" → HOW DO YOU KNOW? What health check confirmed it?
```

### 1.3 The Three Questions Framework

Before ANY troubleshooting action, answer:

| Question | Purpose |
|----------|---------|
| **What do I expect?** | Define the correct state |
| **What do I observe?** | Document the actual state |
| **What could cause the delta?** | Form testable hypotheses |

Example from our case:
- **Expected**: Pipeline green → pods running in namespace
- **Observed**: Pipeline green → no pods in namespace
- **Delta Causes**: Pipeline lies? Namespace issue? ArgoCD issue? K8s rejection?

---

## 2. Mental Models: Understanding the Machines

### 2.1 Kubernetes: The Desired State Machine

Kubernetes is NOT a "container orchestrator." It's a **desired state reconciliation engine**.

```text
┌─────────────────────────────────────────────────────────────┐
│                    THE RECONCILIATION LOOP                  │
│                                                             │
│   You declare: "I want 3 replicas of nginx"                 │
│                          ↓                                  │
│   K8s stores this in etcd: {desired: 3, actual: 0}          │
│                          ↓                                  │
│   Controller sees delta: desired(3) != actual(0)            │
│                          ↓                                  │
│   Controller acts: Create 3 pods                            │
│                          ↓                                  │
│   K8s updates: {desired: 3, actual: 3}                      │
│                          ↓                                  │
│   Controller sleeps until next delta                        │
└─────────────────────────────────────────────────────────────┘
```

**Why This Matters for Troubleshooting:**

Every "stuck" state in Kubernetes means a controller is either:
1. **Not seeing the delta** (doesn't know there's work to do)
2. **Seeing but can't act** (permissions, resources, dependencies)
3. **Acting but failing** (errors, rate limits, external dependencies)
4. **Completed its work** (even if the outcome isn't what you wanted)

### 2.2 Kubernetes Resource Lifecycle

```text
                    CREATE
                       │
                       ▼
┌────────────────────────────────────┐
│            ACTIVE STATE            │
│  • spec: what you want             │
│  • status: what actually exists    │
│  • metadata: identity + control    │
└────────────────────────────────────┘
                       │
                   DELETE request
                       │
                       ▼
┌────────────────────────────────────┐
│         HAS FINALIZERS?            │
│                                    │
│   YES → TERMINATING (waiting)      │
│   NO  → GARBAGE COLLECTED          │
└────────────────────────────────────┘
                       │
                   (if YES)
                       ▼
┌────────────────────────────────────┐
│       TERMINATING STATE            │
│  • deletionTimestamp SET           │
│  • Finalizers being processed      │
│  • Can't add new children          │
│  • Waiting for controllers         │
└────────────────────────────────────┘
                       │
               All finalizers removed
                       │
                       ▼
              GARBAGE COLLECTED
              (resource deleted)
```

### 2.3 Finalizers: The Contract System

**What is a finalizer?**

A finalizer is a controller saying: "Don't delete this resource until I've done my cleanup work."

```yaml
metadata:
  name: my-app
  finalizers:
    - resources-finalizer.argocd.argoproj.io  # ArgoCD's contract
```

**The Finalizer Contract:**

```text
Controller: "I manage resources for this object. When you delete it,
             I need to clean up those resources first. I'm adding my
             finalizer as my promise to do that cleanup. Don't garbage
             collect until I've removed my finalizer."

Kubernetes: "Understood. When delete is requested, I'll set
             deletionTimestamp but won't remove the object until
             you remove your finalizer."
```

#### 2.3.1 Finalizer Protocol Mechanics (Deep Dive)

**How Kubernetes Enforces the Contract:**

The magic isn't in the finalizer itself—it's in the **apiserver validation**:

```text
┌─────────────────────────────────────────────────────────────────────┐
│                    DELETE REQUEST FLOW                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. Client: DELETE /apis/argoproj.io/v1alpha1/applications/myapp    │
│                              ↓                                      │
│  2. Apiserver checks: Does resource have finalizers?                │
│     ├─ NO finalizers  → Immediate deletion (garbage collect)        │
│     └─ YES finalizers → Set deletionTimestamp, return 200 OK        │
│                              ↓                                      │
│  3. Resource now exists with:                                       │
│     • metadata.deletionTimestamp = "2025-12-16T13:30:03Z"           │
│     • metadata.finalizers = ["resources-finalizer.argocd..."]       │
│     • Resource is STILL in etcd, STILL queryable, STILL watchable   │
│                              ↓                                      │
│  4. Controller watching resources sees: "deletionTimestamp set!"    │
│     • Controller performs cleanup (delete managed Deployments, etc.)│
│     • Controller PATCHes resource to remove its finalizer           │
│                              ↓                                      │
│  5. Apiserver receives PATCH removing finalizer:                    │
│     • Updates finalizers list                                       │
│     • Checks: Any finalizers remaining?                             │
│       ├─ YES → Resource stays, wait for other controllers           │
│       └─ NO  → Garbage collect (actually delete from etcd)          │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

**Critical Insights Most Engineers Miss:**

1. **Finalizers are a SET, not a LIST**: Order doesn't matter. Multiple controllers can add finalizers. Each removes only its own. No coordination required.

2. **Removing a finalizer is just a PATCH**: There's no special "finalizer removal API." You literally PATCH `metadata.finalizers` to remove your entry. Any client with UPDATE permissions can do this.

   ```bash
   # This is ALL that happens when "removing a finalizer":
   kubectl patch application myapp -n afi \
     -p '{"metadata":{"finalizers":null}}' --type=merge
   ```

3. **The apiserver is the enforcer**: Controllers don't "block" deletion—the apiserver refuses to garbage collect while finalizers exist. This is validation logic in `staging/src/k8s.io/apiserver/pkg/registry/generic/registry/store.go`.

4. **deletionGracePeriodSeconds interaction**: If set, the resource enters a grace period before controllers are signaled. For most CRDs (including ArgoCD Applications), this is 0 or unset.

**Why "Controller Healthy But Ignoring" Happens:**

```text
┌─────────────────────────────────────────────────────────────────────┐
│           CONTROLLER WORK QUEUE MECHANICS                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Controller watches Applications via INFORMER:                      │
│  • Informer receives MODIFIED event (deletionTimestamp set)         │
│  • Event added to WORK QUEUE with key "afi/alarmengine"             │
│                              ↓                                      │
│  Worker goroutine picks up key, calls Reconcile():                  │
│  • Reconcile fetches Application, sees deletionTimestamp            │
│  • Attempts cleanup: delete Deployments, Services, etc.             │
│                              ↓                                      │
│  IF CLEANUP SUCCEEDS:                                               │
│  • Controller PATCHes to remove finalizer                           │
│  • Done. Resource garbage collected.                                │
│                              ↓                                      │
│  IF CLEANUP FAILS (e.g., resources already gone, API error):        │
│  • Reconcile returns error                                          │
│  • controller-runtime REQUEUES with EXPONENTIAL BACKOFF             │
│  • Backoff: 1s → 2s → 4s → 8s → ... → capped at 16 minutes          │
│                              ↓                                      │
│  IF CONTROLLER RESTARTS during backoff:                             │
│  • Work queue is IN-MEMORY ONLY                                     │
│  • Pending requeues are LOST                                        │
│  • Informer re-lists all resources on startup                       │
│  • BUT: If Application is in weird state, may not trigger reconcile │
│                              ↓                                      │
│  RESULT: "Orphaned finalizer" - resource exists, no one processing  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

**The 5 Failure Modes That Cause Stuck Finalizers:**

| # | Cause | Mechanism | Detection |
|---|-------|-----------|-----------|
| 1 | Controller crash during cleanup | Work queue lost, requeue never happens | Check controller restarts around deletionTimestamp |
| 2 | Cleanup error + max retries | Backoff exceeded, dropped from queue | Controller logs show repeated errors then silence |
| 3 | Managed resources already deleted | Controller can't verify "cleanup done" | Resources show `Health: Missing` but finalizer remains |
| 4 | RBAC permission loss | Controller can't delete managed resources | Controller logs show 403 errors |
| 5 | Resource in inconsistent state | Reconcile logic can't handle edge case | Requires code inspection or detailed logs |

**Why Finalizers Get Stuck:**

| Cause | Mechanism | Symptom |
|-------|-----------|---------|
| Controller crashed | Can't process finalizer | Resource in Terminating forever |
| Controller lost permissions | Can't delete managed resources | Finalizer never removed |
| Managed resources already gone | Controller confused about state | Finalizer stuck in retry loop |
| Controller restarted mid-cleanup | Lost in-flight state | Orphaned finalizer |

### 2.4 Namespace Deletion: The Cascade

**Critical Mental Model:**

```text
Namespace deletion is NOT "delete this folder."
Namespace deletion is "delete everything in this folder, WAIT for confirmation,
                       THEN delete the folder."

┌────────────────────────────────────────────────────────────┐
│                NAMESPACE DELETION PHASES                   │
├────────────────────────────────────────────────────────────┤
│ 1. DELETE requested                                        │
│    └─ K8s sets deletionTimestamp on namespace              │
│    └─ Namespace enters Terminating phase                   │
│    └─ NEW resource creation BLOCKED                        │
│                                                            │
│ 2. CONTENT DELETION                                        │
│    └─ K8s deletes all namespaced resources                 │
│    └─ Each resource follows its own lifecycle              │
│    └─ Finalizers processed for each resource               │
│                                                            │
│ 3. WAITING                                                 │
│    └─ Namespace controller waits for ALL resources gone    │
│    └─ Conditions updated: NamespaceContentRemaining        │
│    └─ Conditions updated: NamespaceFinalizersRemaining     │
│                                                            │
│ 4. COMPLETION (only when ALL resources gone)               │
│    └─ Namespace finalizers processed (if any)              │
│    └─ Namespace garbage collected                          │
│    └─ Namespace no longer exists                           │
└────────────────────────────────────────────────────────────┘
```

**The Blocking Behavior:**

Once a namespace is `Terminating`:
- **CREATE operations for new resources: REJECTED**
- **UPDATE operations for existing resources: ALLOWED**
- **DELETE operations: ALLOWED** (encouraged!)

This is BY DESIGN. You can't add new furniture while the house is being demolished.

#### 2.4.1 Why CREATE Is Rejected (The Mechanism)

The blocking is enforced by the `NamespaceLifecycle` admission controller—a built-in plugin compiled into kube-apiserver. When any CREATE request targets a namespace, this controller checks `namespace.status.phase`. If `Terminating`, it returns HTTP 403: `"unable to create new content in namespace X because it is being terminated"`.

This isn't configurable. You cannot disable it without recompiling Kubernetes. The semantics are fundamental to cluster integrity—partial namespace deletion would corrupt garbage collection.

**Source**: `plugin/pkg/admission/namespace/lifecycle/admission.go`

#### 2.4.2 How Conditions Are Computed

The namespace controller enumerates every GroupVersionResource (GVR) the cluster knows about—core resources (pods, secrets) plus all CRDs (applications.argoproj.io). For each GVR, it LISTs instances in the terminating namespace. Any remaining resources become `NamespaceContentRemaining`. Any resources with finalizers become `NamespaceFinalizersRemaining`.

**Critical for CRDs**: If a CRD is deleted before its instances (or discovery fails), you get `NamespaceDeletionDiscoveryFailure`—a different stuck state requiring CRD restoration.

The conditions are your diagnostic truth source. Always check them:

```bash
kubectl get ns afi -o json | jq '.status.conditions[] | {type, reason, message}'
```

### 2.5 ArgoCD: The GitOps Reconciler

ArgoCD is another reconciliation loop, layered on top of Kubernetes:

```text
┌──────────────────────────────────────────────────────────────┐
│                    ARGOCD ARCHITECTURE                       │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────┐         ┌─────────────────┐                │
│  │  Git Repo   │◄────────│ ArgoCD Server   │                │
│  │ (desired)   │         │ (API + UI)      │                │
│  └─────────────┘         └────────┬────────┘                │
│                                   │                          │
│                          ┌────────▼────────┐                │
│                          │  Application    │                │
│                          │  Controller     │                │
│                          │ (reconciler)    │                │
│                          └────────┬────────┘                │
│                                   │                          │
│                          ┌────────▼────────┐                │
│                          │   Kubernetes    │                │
│                          │   (actual)      │                │
│                          └─────────────────┘                │
│                                                              │
│  RECONCILIATION LOOP:                                        │
│  1. Read Application CRD                                     │
│  2. Fetch manifests from Git (spec.source)                   │
│  3. Compare rendered manifests vs K8s state                  │
│  4. If delta: sync (apply manifests to K8s)                  │
│  5. Update Application status (health, sync status)          │
│  6. If Application has finalizer + deletionTimestamp:        │
│     → Delete all managed K8s resources                       │
│     → Remove finalizer                                       │
│  7. Repeat                                                   │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

#### 2.5.1 Controller Internals: Why "Healthy" Controllers Ignore Stuck Resources

The Application Controller uses the standard controller-runtime pattern. Understanding this explains why a "healthy" controller can appear to ignore stuck finalizers.

**Discovery mechanism**: The controller runs an informer watching all Application CRDs. When an Application is created, modified, or deleted, the informer fires an event that enqueues that Application's key (`namespace/name`) into the work queue. The controller pops items from this queue and reconciles them.

**Triggers for reconciliation**:

1. **Watch events** — Any change to an Application CRD (create/update/delete) immediately enqueues it
2. **Refresh interval** — ArgoCD periodically re-enqueues all Applications (default: 3 minutes, controlled by `--app-resync`)
3. **Webhooks** — Git webhooks can trigger immediate reconciliation for specific Applications
4. **Manual refresh** — `argocd app refresh <app>` or UI button enqueues immediately

**Sync vs Refresh** — two distinct operations:

- **Refresh**: Compare Git manifests against cluster state, update Application status (health, sync status). Does NOT apply changes.
- **Sync**: Actually apply the Git manifests to Kubernetes. Only happens on manual trigger, auto-sync policy, or webhook.

**Why a healthy controller "ignores" stuck finalizers**: When an Application has `deletionTimestamp` set, the controller's reconcile loop enters deletion mode (step 6 above). It attempts to delete all managed resources, then remove its finalizer. If deletion fails (e.g., child resources have their own stuck finalizers, or the target namespace blocks operations), the controller:

1. Logs an error
2. Re-enqueues the Application with exponential backoff
3. Moves on to process other Applications

The backoff means the controller tries less frequently over time. After enough failures, the retry interval can reach 5+ minutes. The controller is still "healthy" (it's processing other Applications), but this specific Application's reconciliation is effectively abandoned to infrequent retries.

**Diagnostic command**: Check controller logs for your stuck Application:

```bash
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --since=10m | grep "alarmengine"
```

Look for: `FailedSync`, `ComparisonError`, or `unable to delete` messages with increasing timestamps between attempts.

### 2.6 The App-of-Apps Pattern

```text
┌─────────────────────────────────────────────────────────────┐
│                    APP-OF-APPS PATTERN                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌────────────────────────────────────────┐                │
│  │         Parent Application             │                │
│  │  (app-of-apps / afi-app-of-apps)       │                │
│  │                                        │                │
│  │  Manages: Other Application CRDs       │                │
│  │  Namespace: argocd (lives here)        │                │
│  │  Target Namespace: afi (children here) │                │
│  └──────────────────┬─────────────────────┘                │
│                     │                                       │
│        creates/manages these Application CRDs:              │
│                     │                                       │
│    ┌────────────────┼────────────────────┐                 │
│    │                │                    │                 │
│    ▼                ▼                    ▼                 │
│ ┌──────┐      ┌──────────┐        ┌───────────┐           │
│ │ App1 │      │   App2   │   ...  │   App21   │           │
│ │ afi/ │      │   afi/   │        │   afi/    │           │
│ └──┬───┘      └────┬─────┘        └─────┬─────┘           │
│    │               │                    │                  │
│    │ manages:      │ manages:           │ manages:         │
│    ▼               ▼                    ▼                  │
│ ┌──────┐      ┌──────────┐        ┌───────────┐           │
│ │Pods  │      │  Pods    │        │   Pods    │           │
│ │Svcs  │      │  Svcs    │        │   Svcs    │           │
│ │etc   │      │  etc     │        │   etc     │           │
│ └──────┘      └──────────┘        └───────────┘           │
│                                                             │
└─────────────────────────────────────────────────────────────┘

KEY INSIGHT: Child Application CRDs live IN the target namespace (afi).
             If afi is Terminating, new Applications can't be created there.
```

---

## 3. The Troubleshooting Map

### 3.1 The Master Decision Tree

When something is "not working" in K8s/ArgoCD, start here:

```text
                        SYMPTOM
                           │
           ┌───────────────┼───────────────┐
           ▼               ▼               ▼
      "No pods"    "Pods crashing"   "Service unreachable"
           │               │               │
           ▼               ▼               ▼
    [PATH A]          [PATH B]        [PATH C]
    Deployment        Container       Networking
    Investigation     Investigation   Investigation
```

### 3.2 PATH A: "No Pods" Investigation

This is our case study. Here's the systematic approach:

```text
┌─────────────────────────────────────────────────────────────────┐
│                    PATH A: NO PODS INVESTIGATION                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  STEP 1: VERIFY THE CLAIM                                       │
│  ─────────────────────────────────────                          │
│  Q: "Are there really no pods?"                                 │
│  Command: kubectl get pods -n <namespace>                       │
│  WHY: Trust but verify. Maybe they exist but are miscounted.    │
│                                                                 │
│  STEP 2: CHECK NAMESPACE STATE                                  │
│  ─────────────────────────────────                              │
│  Q: "Is the namespace in a valid state?"                        │
│  Command: kubectl get ns <namespace> -o jsonpath='{.status.phase}'│
│  WHY: Terminating namespace rejects new resource creation.      │
│  │                                                              │
│  ├─ If "Terminating" → BRANCH: Namespace Stuck Investigation    │
│  └─ If "Active" → Continue to STEP 3                            │
│                                                                 │
│  STEP 3: CHECK DEPLOYMENT/REPLICASET                            │
│  ────────────────────────────────                               │
│  Q: "Does a Deployment exist? Does it have replicas?"           │
│  Command: kubectl get deployments -n <namespace>                │
│  WHY: Pods are created by controllers (Deployments, etc.)       │
│  │                                                              │
│  ├─ If no Deployment → WHO was supposed to create it?           │
│  └─ If Deployment exists, READY=0 → BRANCH: Deployment Debug    │
│                                                                 │
│  STEP 4: CHECK ARGOCD APPLICATION                               │
│  ─────────────────────────────                                  │
│  Q: "Is ArgoCD aware of this deployment? What's its view?"      │
│  Command: argocd app get <app> --server <server> --grpc-web     │
│  WHY: ArgoCD is the deployment source. What does it see?        │
│  │                                                              │
│  ├─ Health: Missing → Resources don't exist in K8s              │
│  ├─ Health: Progressing → Stuck trying to reconcile             │
│  ├─ Health: Degraded → Resources exist but unhealthy            │
│  └─ Sync: OutOfSync → Git differs from cluster                  │
│                                                                 │
│  STEP 5: TRACE THE CREATION PATH                                │
│  ───────────────────────────────                                │
│  Q: "What happens when ArgoCD tries to create resources?"       │
│  Commands:                                                      │
│    kubectl logs -n argocd <controller-pod> | grep <app>         │
│    kubectl get events -n <namespace> --sort-by='.lastTimestamp' │
│  WHY: Events and logs show the actual failure reason.           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3.3 BRANCH: Namespace Stuck in Terminating

```text
┌─────────────────────────────────────────────────────────────────┐
│              NAMESPACE STUCK INVESTIGATION                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  STEP 1: GET NAMESPACE CONDITIONS                               │
│  ────────────────────────────────                               │
│  Command: kubectl get ns <ns> -o json | jq '.status.conditions' │
│  WHY: K8s tells you EXACTLY why it won't delete.                │
│                                                                 │
│  Look for:                                                      │
│  • NamespaceContentRemaining → Resources still exist            │
│  • NamespaceFinalizersRemaining → Finalizers blocking           │
│                                                                 │
│  STEP 2: IDENTIFY REMAINING RESOURCES                           │
│  ────────────────────────────────────                           │
│  Command:                                                       │
│    kubectl api-resources --verbs=list --namespaced -o name | \  │
│      xargs -I {} kubectl get {} -n <ns> --ignore-not-found      │
│  WHY: Find ALL resource types, not just pods/deployments.       │
│                                                                 │
│  STEP 3: CHECK FINALIZERS ON BLOCKING RESOURCES                 │
│  ──────────────────────────────────────────────                 │
│  Command:                                                       │
│    kubectl get <resource-type> -n <ns> -o json | \              │
│      jq '.items[] | {name: .metadata.name,                      │
│                      finalizers: .metadata.finalizers,          │
│                      deletionTimestamp: .metadata.deletionTimestamp}'│
│  WHY: Identify which finalizers are stuck and since when.       │
│                                                                 │
│  STEP 4: IDENTIFY THE FINALIZER OWNER                           │
│  ────────────────────────────────────                           │
│  The finalizer name tells you who owns it:                      │
│  • resources-finalizer.argocd.argoproj.io → ArgoCD              │
│  • kubernetes.io/pvc-protection → PVC controller                │
│  • foregroundDeletion → K8s garbage collector                   │
│  WHY: You need to talk to the right controller.                 │
│                                                                 │
│  STEP 5: CHECK CONTROLLER HEALTH                                │
│  ───────────────────────────────                                │
│  Command (for ArgoCD):                                          │
│    kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-application-controller│
│    kubectl logs -n argocd <controller-pod> --since=1h | grep <ns>│
│  WHY: Maybe controller crashed, restarted, or has errors.       │
│                                                                 │
│  STEP 6: DECISION POINT                                         │
│  ──────────────────────                                         │
│  ├─ Controller unhealthy → Fix controller first                 │
│  ├─ Controller healthy but ignoring → Bug or orphaned state     │
│  └─ Can't wait → Forcibly remove finalizers (CAUTION!)          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3.4 The "Why This Path?" Decision Logic

| Observation | Why This Path | What It Rules Out |
|-------------|---------------|-------------------|
| Namespace Terminating | Can't create new resources | Config errors, permissions |
| Finalizers present | Something waiting for cleanup | Immediate deletion possible |
| deletionTimestamp set | Resource marked for deletion | Resource actively managed |
| Controller healthy | Controller isn't the problem | Controller crash/restart |
| Controller ignoring | State corruption or bug | Normal operation |

### 3.5 Diagnostic Confidence Levels

When troubleshooting, explicitly categorize your findings by confidence level. This prevents overconfident conclusions and communicates uncertainty to collaborators.

**Level 1: OBSERVED** — Direct evidence from system output. You ran a command and saw the result.

- Example: "Namespace `afi` shows `STATUS: Terminating`" (you ran `kubectl get ns`)
- Certainty: Fact. The system told you this.

**Level 2: INFERRED** — Logical conclusion from observations, but not directly observed.

- Example: "The namespace has been stuck for 6 days" (you observed `AGE: 12d` + `STATUS: Terminating`, and git history shows namespace was deleted 6 days ago)
- Certainty: High probability. Your inference is based on correlated observations.

**Level 3: HYPOTHESIZED** — Plausible explanation that fits observations, but alternative explanations exist.

- Example: "The finalizer is stuck because ArgoCD controller lost track of the Application"
- Certainty: Moderate. This fits the evidence, but you haven't proven the controller lost track vs. the controller actively failing.

**Level 4: SPECULATED** — Guess without supporting evidence. Useful for generating investigation paths, dangerous as conclusions.

- Example: "Maybe there was a network partition during deletion"
- Certainty: Low. You have no evidence of network issues.

**Communicating Findings**:

- "I observed X" (Level 1) — No qualifier needed
- "Based on X and Y, I infer Z" (Level 2) — State the premises
- "I hypothesize Z because it explains X" (Level 3) — Acknowledge alternatives exist
- "One possibility is Z, but I have no direct evidence" (Level 4) — Clearly mark speculation

**Anti-pattern**: Treating hypotheses as facts. "The controller is broken" (presented as fact) vs. "I hypothesize the controller lost state, based on: healthy status, no recent logs for this Application, other Applications are syncing fine" (proper framing).

---

## 4. Command Mastery: The Why Behind Every Command

### 4.1 Namespace Investigation Commands

#### 4.1.1 `kubectl get ns`

```bash
kubectl get ns
```

**What it does**: Lists all namespaces with their status and age.

**Why use it**: First verification that namespace exists and its current phase.

**Output anatomy**:
```text
NAME                STATUS        AGE
afi                 Terminating   12d    ← RED FLAG: Stuck for 12 days!
afi-monitoring      Active        2d20h  ← Healthy namespace
kube-system         Active        90d
```

**Systems thinking**: This is your 10-second sanity check. `Terminating` for >1 hour is abnormal. `Terminating` for days means something is fundamentally stuck.

**When to use**: ALWAYS. This is step zero of any namespace-related troubleshooting.

---

#### 4.1.2 `kubectl get ns <ns> -o jsonpath='{.status.phase}'`

```bash
kubectl get ns afi -o jsonpath='{.status.phase}'
```

**What it does**: Extracts only the phase field (Active/Terminating).

**Why use it**: Scriptable, precise, no visual parsing needed.

**Output**:
```text
Terminating
```

**Systems thinking**: JSONPath queries are how you build automation. If you're checking this manually, you should eventually script it.

**When to use**: In scripts, automated checks, or when you need just the phase for a conditional.

**Alternative (for humans)**:
```bash
kubectl get ns afi -o wide
```

---

#### 4.1.3 `kubectl get ns <ns> -o json | jq '.status.conditions'`

```bash
kubectl get ns afi -o json | jq '.status.conditions'
```

**What it does**: Extracts the status conditions—Kubernetes's explanation of why the namespace is in its current state.

**Why use it**: **THIS IS THE DIAGNOSTIC GOLDMINE.** Kubernetes literally tells you what's wrong.

**Output anatomy**:
```json
[
  {
    "lastTransitionTime": "2025-12-22T09:56:43Z",
    "message": "Some resources are remaining: applications.argoproj.io has 5 resource instances",
    "reason": "SomeResourcesRemain",
    "status": "True",
    "type": "NamespaceContentRemaining"
  },
  {
    "lastTransitionTime": "2025-12-22T09:56:43Z",
    "message": "Some content in the namespace has finalizers remaining: resources-finalizer.argocd.argoproj.io in 5 resource instances",
    "reason": "SomeFinalizersRemain",
    "status": "True",
    "type": "NamespaceFinalizersRemaining"
  }
]
```

**Reading the output**:

| Condition Type | Meaning | Action |
|----------------|---------|--------|
| `NamespaceContentRemaining` | Resources still exist | Find and remove them |
| `NamespaceFinalizersRemaining` | Finalizers blocking | Identify and resolve |
| `NamespaceDeletionDiscoveryFailure` | API discovery failed | Check API server |
| `NamespaceDeletionGroupVersionParsingFailure` | GVK parsing error | Check CRDs |
| `NamespaceDeletionContentFailure` | Can't delete content | Check permissions |

**Systems thinking**: Kubernetes conditions follow a pattern: `type` tells you WHAT category of issue, `reason` tells you WHY specifically, `message` gives you ACTIONABLE details. Learn to read conditions fluently—they're your primary diagnostic tool.

**When to use**: Whenever a namespace is stuck or behaving unexpectedly.

---

#### 4.1.4 Finding All Resources in a Namespace

```bash
kubectl api-resources --verbs=list --namespaced -o name | \
  xargs -I {} sh -c 'kubectl get {} -n afi --ignore-not-found 2>/dev/null | grep -v "^$"'
```

**What it does**:
1. `kubectl api-resources --verbs=list --namespaced -o name` → List all namespaced resource types that support `list`
2. `xargs -I {} sh -c '...'` → For each resource type, run the get command
3. `kubectl get {} -n afi --ignore-not-found` → List instances of that type in namespace

**Why use it**: `kubectl get all` is a LIE. It only shows "common" resources (pods, services, deployments). It does NOT show:
- ConfigMaps
- Secrets
- Custom Resource Definitions (like ArgoCD Applications!)
- PersistentVolumeClaims
- NetworkPolicies
- etc.

**Systems thinking**: When a namespace won't delete, the blocker is almost always a resource type that `kubectl get all` doesn't show. **NEVER trust `kubectl get all` for completeness.**

**When to use**: Investigating stuck namespaces, understanding namespace contents, pre-deletion checks.

---

### 4.2 ArgoCD Application Commands

#### 4.2.1 `kubectl get applications.argoproj.io`

```bash
kubectl get applications.argoproj.io -n afi
```

**What it does**: Lists ArgoCD Application CRDs in the specified namespace.

**Why `applications.argoproj.io` instead of just `applications`?**

Kubernetes has short names and full names:
- `applications.argoproj.io` → ArgoCD's Application CRD (FULL NAME - unambiguous)
- `application` → Could be ambiguous if other CRDs exist
- `app` → Short name alias (works but less explicit)

**Systems thinking**: In troubleshooting, use FULL resource names. Ambiguity kills. `pods` is fine because it's a core resource. Custom resources deserve full names.

**Output anatomy**:
```text
NAME            SYNC STATUS   HEALTH STATUS
alarmengine     OutOfSync     Missing
assetmonitor    OutOfSync     Missing
```

**When to use**: Discovering what ArgoCD Applications exist in a namespace.

---

#### 4.2.2 Deep Application Inspection

```bash
kubectl get applications.argoproj.io -n afi -o json | \
  jq '.items[] | {
    name: .metadata.name,
    finalizers: .metadata.finalizers,
    deletionTimestamp: .metadata.deletionTimestamp,
    targetBranch: .spec.sources[0].targetRevision,
    healthStatus: .status.health.status,
    syncStatus: .status.sync.status
  }'
```

**What it does**: Extracts the critical diagnostic fields from each Application.

**Why these specific fields?**

| Field | Why It Matters |
|-------|----------------|
| `name` | Identity |
| `finalizers` | What's blocking deletion |
| `deletionTimestamp` | Is it marked for deletion? When? |
| `targetBranch` | What Git ref is it supposed to track |
| `healthStatus` | ArgoCD's view of managed resources |
| `syncStatus` | Does Git match cluster? |

**Systems thinking**: This query answers the critical questions:
1. Is it trying to delete? (deletionTimestamp)
2. What's blocking? (finalizers)
3. Is it current? (targetBranch)
4. Are resources healthy? (healthStatus)

**Output interpretation**:
```json
{
  "name": "alarmengine",
  "finalizers": ["resources-finalizer.argocd.argoproj.io"],  // BLOCKING
  "deletionTimestamp": "2025-12-16T13:30:03Z",               // Stuck since Dec 16!
  "targetBranch": "feature/fbe-744839...",                   // OLD branch
  "healthStatus": "Missing",                                 // Resources don't exist
  "syncStatus": "OutOfSync"                                  // Can't sync
}
```

**Red flags**:
- `deletionTimestamp` > 1 hour ago + finalizers present = STUCK
- `healthStatus: Missing` = ArgoCD can't find/create resources
- Old `targetBranch` = This is an orphaned Application from previous deployment

---

#### 4.2.3 ArgoCD CLI: `argocd app get`

```bash
argocd app get afi-app-of-apps \
  --server argocd.dev.vpp.eneco.com \
  --grpc-web
```

**What it does**: Gets detailed Application status from ArgoCD's perspective.

**Why use CLI instead of kubectl?**

| kubectl | argocd CLI |
|---------|------------|
| Raw K8s resource view | ArgoCD's rendered view |
| Just the Application CRD | Includes computed health, sync status |
| No Git comparison | Shows Git vs cluster delta |
| No child resources | Shows managed resources |

**Systems thinking**: kubectl shows you the CRD. argocd CLI shows you ArgoCD's INTERPRETATION of that CRD—what it's trying to do, what it sees, what's failing.

**The `--grpc-web` flag**: Required when ArgoCD server is behind a load balancer/ingress that doesn't support raw gRPC. Most production setups need this.

**Output anatomy**:
```text
Name:               argocd/afi-app-of-apps
Project:            vpp-core
Server:             https://kubernetes.default.svc
Namespace:          afi                              ← TARGET namespace
URL:                https://argocd.dev.vpp.eneco.com/applications/afi-app-of-apps
Sources:
- Repo:             https://.../_git/VPP-Configuration
  Target:           feature/fbe-768911-...           ← CURRENT target
  Path:             Helm/vpp-core-app-of-apps
Sync Status:        OutOfSync from feature/fbe-768911  ← Not synced
Health Status:      Progressing                        ← Stuck trying

GROUP        KIND         NAMESPACE  NAME          STATUS     HEALTH
argoproj.io  Application  afi        frontend      OutOfSync  Missing   ← Can't create
argoproj.io  Application  afi        backend       OutOfSync  Missing
```

**When to use**: Always when debugging ArgoCD-managed deployments. This is your primary ArgoCD diagnostic view.

---

#### 4.2.4 ArgoCD Sync History

```bash
argocd app history afi-app-of-apps \
  --server argocd.dev.vpp.eneco.com \
  --grpc-web
```

**What it does**: Shows historical sync operations—what was deployed, when, from what Git ref.

**Why use it**: Answers "Has this branch EVER successfully deployed?"

**Output anatomy**:
```text
SOURCE  https://.../_git/VPP-Configuration
ID      DATE                           REVISION
0       2025-12-16 10:59:28 +0100 CET  feature/fbe-744839... (702d031)
```

**Systems thinking**: If history shows only the OLD branch, and target shows NEW branch, the new branch was NEVER successfully synced. The sync was REQUESTED but never COMPLETED.

**This is the "pipeline lies" proof**: Pipeline said "succeeded" but sync history says "never happened."

---

### 4.3 Finalizer Removal (The Nuclear Option)

#### 4.3.1 Removing a Single Finalizer

```bash
kubectl patch application alarmengine -n afi \
  -p '{"metadata":{"finalizers":null}}' \
  --type=merge
```

**What it does**: Sets the finalizers array to null, removing all finalizers.

**Why this works**: The merge patch replaces the finalizers field entirely with null, which Kubernetes interprets as "no finalizers."

**DANGER**: This bypasses the finalizer contract. The controller won't get to do its cleanup. Any resources the Application was managing may be orphaned.

**When it's safe**:
- Resources are already gone (Health: Missing)
- You've verified nothing exists that needs cleanup
- You're willing to manually clean up orphans

**When it's NOT safe**:
- Application is actively managing resources
- You don't know what the Application manages
- In production without understanding impact

**Systems thinking**: Finalizer removal is admitting "I know the controller can't do its job, and I've verified there's nothing for it to clean up anyway." It's not "I don't want to wait."

---

#### 4.3.2 Removing Finalizers from Multiple Resources

```bash
for app in alarmengine assetmonitor assetplanning clientgateway monitor; do
  echo "Removing finalizer from $app..."
  kubectl patch application $app -n afi \
    -p '{"metadata":{"finalizers":null}}' --type=merge
done
```

**Why the loop**: Explicit is better than implicit. You see each resource being patched.

**Alternative (more dangerous)**:
```bash
kubectl get applications.argoproj.io -n afi -o name | \
  xargs -I {} kubectl patch {} -n afi \
    -p '{"metadata":{"finalizers":null}}' --type=merge
```

This patches ALL applications. Only use if you've verified they ALL need finalizer removal.

---

### 4.4 Controller Health Commands

#### 4.4.1 Check ArgoCD Controller Status

```bash
kubectl get pods -n argocd \
  -l app.kubernetes.io/name=argocd-application-controller
```

**What it does**: Lists the ArgoCD application controller pods.

**Why this specific label**: ArgoCD uses standard Kubernetes labels. `app.kubernetes.io/name` is the canonical way to select ArgoCD components.

**Output anatomy**:
```text
NAME                                    READY   STATUS    RESTARTS   AGE
argocd-application-controller-0         1/1     Running   0          5d20h
```

**What to look for**:
- `READY 1/1`: Controller is ready
- `STATUS Running`: Not crashing
- `RESTARTS 0`: Hasn't crashed recently
- `AGE`: How long since last restart

**Red flags**:
- `RESTARTS > 0` with recent restart → Controller instability
- `STATUS CrashLoopBackOff` → Controller can't start
- `READY 0/1` → Controller not ready

---

#### 4.4.2 Controller Logs

```bash
kubectl logs -n argocd argocd-application-controller-0 \
  --since=1h | grep -i "afi"
```

**What it does**: Gets controller logs from the last hour, filtered for our namespace.

**Why `--since=1h`**: Full logs can be massive. Start narrow, widen if needed.

**What to look for**:
```text
level=error msg="Failed to sync application" application=afi/alarmengine
level=warn msg="Resource not found" namespace=afi
level=info msg="Deleting application" application=afi/monitor
```

**Log levels**:
- `level=error`: Something failed
- `level=warn`: Something concerning but not fatal
- `level=info`: Normal operations

---

### 4.5 Azure DevOps Pipeline Commands

#### 4.5.1 Get Build Details

```bash
az pipelines build show --id 1468155 \
  --org https://dev.azure.com/enecomanagedcloud \
  --project "Myriad - VPP" \
  --query "{buildNumber: buildNumber, result: result, status: status, finishTime: finishTime}"
```

**What it does**: Retrieves build metadata from Azure DevOps.

**Why use it**: Verify what the pipeline actually reported vs what users claim.

**Output anatomy**:
```json
{
  "buildNumber": "20251222.1",
  "result": "succeeded",     // What the pipeline claims
  "status": "completed",
  "finishTime": "2025-12-22T09:33:40.380401+00:00"
}
```

**Systems thinking**: `result: succeeded` means "all tasks returned exit code 0." It does NOT mean "deployment worked." This distinction is critical.

---

## 5. The Case Study: Pipeline Green, Deployment Dead

### 5.1 The Timeline

```text
DAY -6 (2025-12-16):
├─ 10:59 - Branch fbe-744839 synced to afi namespace (last known good sync)
├─ 13:30 - Something triggered deletion of child Applications
├─ 13:30 - 5 Applications get deletionTimestamp, start finalizer processing
├─ 13:30 - ArgoCD controller should clean up managed resources
├─ ??:?? - SOMETHING GOES WRONG - finalizers never removed
├─ ??:?? - Namespace enters Terminating state, can't complete
└─ ??:?? - Namespace stuck in Terminating for 6 days

DAY 0 (2025-12-22):
├─ 09:30 - Artem deploys branch fbe-768911
├─ 09:33 - Pipeline reports "succeeded" (exit code 0)
├─ 09:33 - ArgoCD app-of-apps tries to create 21 new Applications in afi
├─ 09:33 - Kubernetes rejects: "Namespace afi is Terminating"
├─ 09:33 - ArgoCD marks children as Health: Missing
├─ 10:43 - Artem reports: "green pipeline, no pods"
└─ 11:00 - Investigation begins
```

### 5.2 The Investigation Path We Followed

**Step 1: Verify the symptom**
```bash
kubectl get pods -n afi
# Output: No resources found
```
Confirmed: No pods exist.

**Step 2: Check namespace state**
```bash
kubectl get ns | grep afi
# Output: afi  Terminating  12d
```
**CRITICAL FINDING**: Namespace stuck in Terminating for 12 days!

**Step 3: Get namespace conditions**
```bash
kubectl get ns afi -o json | jq '.status.conditions'
```
**CRITICAL FINDING**: "5 resource instances" with stuck finalizers

**Step 4: Identify the blocking resources**
```bash
kubectl get applications.argoproj.io -n afi
```
**CRITICAL FINDING**: 5 ArgoCD Applications with finalizers

**Step 5: Examine the Applications**
```bash
kubectl get applications.argoproj.io -n afi -o json | \
  jq '.items[] | {name: .metadata.name, deletionTimestamp: .metadata.deletionTimestamp, finalizers: .metadata.finalizers}'
```
**CRITICAL FINDING**: All 5 have `deletionTimestamp` from Dec 16 and stuck finalizers

**Step 6: Check ArgoCD's view**
```bash
argocd app get afi-app-of-apps --server argocd.dev.vpp.eneco.com --grpc-web
```
**CRITICAL FINDING**: Health: Progressing, all children Missing

**Step 7: Verify pipeline report**
```bash
az pipelines build show --id 1468155 ...
```
**CRITICAL FINDING**: `result: succeeded` - Pipeline thinks it worked!

### 5.3 The Root Cause Chain

```text
┌─────────────────────────────────────────────────────────────────┐
│                    ROOT CAUSE CHAIN                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  CAUSE 1: ArgoCD controller failed to process finalizers        │
│  ├─ 5 Applications marked for deletion Dec 16                   │
│  ├─ Controller should delete managed resources, remove finalizer│
│  ├─ Controller failed or forgot (reason unknown)                │
│  └─ Finalizers never removed                                    │
│                    ↓                                            │
│  EFFECT 1: Applications stuck in Terminating                    │
│                    ↓                                            │
│  CAUSE 2: Kubernetes namespace deletion semantics               │
│  ├─ Namespace marked for deletion (probably same time)          │
│  ├─ Namespace controller waits for all children                 │
│  ├─ 5 children have unprocessed finalizers                      │
│  └─ Namespace controller waits forever                          │
│                    ↓                                            │
│  EFFECT 2: Namespace stuck in Terminating                       │
│                    ↓                                            │
│  CAUSE 3: Kubernetes Terminating namespace semantics            │
│  ├─ Terminating namespace rejects CREATE operations             │
│  ├─ New deployment tries to create Applications                 │
│  └─ Kubernetes apiserver: "Rejected, namespace Terminating"     │
│                    ↓                                            │
│  EFFECT 3: No new resources can be created                      │
│                    ↓                                            │
│  CAUSE 4: Pipeline design flaw                                  │
│  ├─ Pipeline calls argocd app sync                              │
│  ├─ ArgoCD API returns 200 (request accepted)                   │
│  ├─ Pipeline sees 200, returns exit 0                           │
│  └─ Pipeline doesn't verify actual deployment success           │
│                    ↓                                            │
│  EFFECT 4: Pipeline reports "succeeded"                         │
│                    ↓                                            │
│  FINAL SYMPTOM: Green pipeline, no pods                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 5.4 The Fix

**Immediate**: Remove stuck finalizers
```bash
for app in alarmengine assetmonitor assetplanning clientgateway monitor; do
  kubectl patch application $app -n afi \
    -p '{"metadata":{"finalizers":null}}' --type=merge
done
```

**Verification**: Namespace should delete
```bash
kubectl get ns afi  # Should return "not found" within 30 seconds
```

**Long-term**: Fix the pipeline
```yaml
- task: Bash@3
  displayName: 'Wait for ArgoCD Health'
  inputs:
    script: |
      argocd app wait $(APP_NAME) --health --timeout 600
      if [ $? -ne 0 ]; then exit 1; fi
```

---

## 6. Pattern Recognition: Common Failure Modes

### 6.1 The Failure Pattern Catalog

#### Pattern 1: Stuck Namespace

**Symptoms**:
- Namespace shows `Terminating` for extended period
- Can't create new resources in namespace
- Namespace conditions show finalizers remaining

**Root Causes**:
1. Stuck finalizers on CRDs
2. Controller not processing finalizers
3. API resources with orphaned objects

**Investigation Path**: Section 3.3

**Fix**: Identify and remove stuck finalizers (after verifying safe)

---

#### Pattern 2: ArgoCD Health: Missing

**Symptoms**:
- ArgoCD Application shows `Health: Missing`
- `Sync Status: OutOfSync`
- No managed resources exist

**Root Causes**:
1. Namespace Terminating (can't create)
2. RBAC prevents creation
3. Resource quota exceeded
4. Invalid manifest (rejected by admission)

**Investigation**:
```bash
# Check namespace state
kubectl get ns <target-ns> -o jsonpath='{.status.phase}'

# Check events for creation errors
kubectl get events -n <target-ns> --sort-by='.lastTimestamp'

# Check controller logs
kubectl logs -n argocd deployment/argocd-application-controller | grep <app>
```

---

#### Pattern 3: ArgoCD Health: Progressing (Stuck)

**Symptoms**:
- Application stays in `Progressing` state
- Never reaches `Healthy` or `Degraded`
- Resources partially exist

**Root Causes**:
1. Pods stuck in `Pending` (resource constraints)
2. Pods stuck in `ContainerCreating` (image pull, secrets)
3. Services waiting for endpoints
4. Infinite reconciliation loop

**Investigation**:
```bash
# Check pod status
kubectl get pods -n <ns> -o wide

# Check pod events for stuck pods
kubectl describe pod <pod> -n <ns> | tail -20

# Check for resource constraints
kubectl describe nodes | grep -A5 "Allocated resources"
```

---

#### Pattern 4: Pipeline Green, Nothing Deployed

**Symptoms**:
- CI/CD pipeline reports success
- No actual resources deployed
- No errors in pipeline logs

**Root Causes**:
1. Pipeline only verifies API acceptance, not deployment completion
2. Target environment in invalid state (namespace Terminating)
3. Permissions for sync but not for verify
4. Async deployment with no wait

**Investigation**:
```bash
# Verify what pipeline actually did
az pipelines build show --id <id> --query "{result: result}"

# Check ArgoCD sync history
argocd app history <app> --server <server>

# Compare target vs actual
argocd app get <app> --server <server> | grep -E "(Target:|Revision:)"
```

---

#### Pattern 5: Application Sync Divergence

**Symptoms**:
- `Sync Status: OutOfSync`
- Application shows different revision than target
- Sync attempts fail silently

**Root Causes**:
1. Git revision no longer exists (deleted branch)
2. Sync window blocking
3. Auto-sync disabled
4. Previous sync left resources that conflict

**Investigation**:
```bash
# Check current vs target
argocd app get <app> | grep -E "(Target|Revision|Sync Status)"

# Check sync windows
argocd app get <app> | grep "SyncWindow"

# Force sync with diagnostics
argocd app sync <app> --dry-run
```

---

### 6.2 The Quick Reference Matrix

| Symptom | First Check | Likely Cause | Quick Fix |
|---------|-------------|--------------|-----------|
| Namespace Terminating | `kubectl get ns <ns> -o json \| jq '.status.conditions'` | Stuck finalizers | Remove finalizers |
| Health: Missing | `kubectl get ns <target-ns>` | Namespace Terminating | Fix namespace |
| Health: Progressing (stuck) | `kubectl describe pod <pod>` | Resource constraints | Scale cluster |
| Green pipeline, no pods | `argocd app history <app>` | Pipeline doesn't verify | Add health check |
| OutOfSync | `argocd app get <app>` | Branch deleted/renamed | Update target |

---

## 7. Building Your Expertise

### 7.1 The Learning Path

```text
LEVEL 1: OBSERVER (You are here)
├─ Can read kubectl output
├─ Understands basic K8s resources (pods, services, deployments)
├─ Follows troubleshooting guides step-by-step
└─ Knows to ask for help

LEVEL 2: PRACTITIONER
├─ Understands resource lifecycle (create, update, delete)
├─ Knows about finalizers, conditions, events
├─ Can form hypotheses and test them
├─ Knows when finalizer removal is safe
└─ Can debug common ArgoCD issues

LEVEL 3: EXPERT
├─ Deep understanding of controller patterns
├─ Can read controller logs and understand state machines
├─ Anticipates cascade effects of changes
├─ Designs systems to avoid failure modes
└─ Creates monitoring for early detection

LEVEL 4: MASTER
├─ Contributes to K8s/ArgoCD projects
├─ Writes controllers and operators
├─ Designs organization-wide reliability patterns
├─ Mentors others through complex issues
└─ Prevents entire classes of failures through architecture
```

### 7.2 Exercises to Build Skill

#### Exercise 1: Namespace Lifecycle

Create a namespace, add a pod with a finalizer, delete the namespace, observe the stuck state, remove the finalizer, observe deletion complete.

```bash
# Create namespace
kubectl create ns test-finalizers

# Create a pod with a custom finalizer
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: test-finalizers
  finalizers:
    - example.com/test-finalizer
spec:
  containers:
    - name: nginx
      image: nginx:alpine
EOF

# Delete namespace (will get stuck)
kubectl delete ns test-finalizers &

# Observe stuck state
kubectl get ns test-finalizers -o json | jq '.status.conditions'

# Remove finalizer
kubectl patch pod test-pod -n test-finalizers \
  -p '{"metadata":{"finalizers":null}}' --type=merge

# Observe completion
kubectl get ns test-finalizers  # Should be gone
```

---

#### Exercise 2: ArgoCD Application Inspection

Pick any ArgoCD Application in your cluster and fully inspect it:

```bash
# List all Applications
kubectl get applications.argoproj.io --all-namespaces

# Pick one and extract full diagnostic info
APP=<app-name>
NS=<app-namespace>

kubectl get application $APP -n $NS -o json | jq '{
  name: .metadata.name,
  namespace: .metadata.namespace,
  project: .spec.project,
  source: .spec.source,
  destination: .spec.destination,
  syncPolicy: .spec.syncPolicy,
  health: .status.health,
  sync: .status.sync,
  conditions: .status.conditions
}'
```

**Questions to answer**:
1. What Git repo does this Application sync from?
2. What namespace do its resources deploy to?
3. Is auto-sync enabled?
4. What's its current health and sync status?

---

#### Exercise 3: Simulate Pipeline Failure Mode

Understand why our case study pipeline "lied":

```bash
# Simulate: Request sync (returns immediately)
argocd app sync <app> --server <server> --grpc-web --async
echo "Exit code: $?"  # Will be 0 even if sync can't complete

# Correct: Wait for sync to complete
argocd app sync <app> --server <server> --grpc-web
argocd app wait <app> --server <server> --grpc-web --health --timeout 60
echo "Exit code: $?"  # Will be non-zero if health check fails
```

---

### 7.3 Mental Habits of Expert Troubleshooters

1. **Always verify assumptions**
   - "The deployment worked" → Show me the pods
   - "The config is correct" → Show me the applied config
   - "Nothing changed" → Show me the git diff

2. **Read error messages carefully**
   - Error messages are written by engineers for engineers
   - They usually contain the answer
   - "namespace is terminating" means EXACTLY that

3. **Build mental models**
   - How does the system ACTUALLY work, mechanically?
   - What are the state transitions?
   - What triggers each transition?

4. **Trace the path**
   - Where did the request START?
   - What did it pass through?
   - Where did it STOP (or fail)?

5. **Ask "why?" recursively**
   - "No pods" → Why? → "Namespace terminating" → Why? → "Stuck finalizers" → Why? → "Controller didn't process" → Why? → ROOT CAUSE

### 7.4 Resources for Continued Learning

**Kubernetes Documentation**:
- [Namespaces](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)
- [Finalizers](https://kubernetes.io/docs/concepts/overview/working-with-objects/finalizers/)
- [Using Finalizers](https://kubernetes.io/blog/2021/05/14/using-finalizers-to-control-deletion/)

**ArgoCD Documentation**:
- [Application CRD](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/)
- [Sync Options](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/)
- [App of Apps](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)

**Deep Dives**:
- [Kubernetes Controller Runtime](https://github.com/kubernetes-sigs/controller-runtime)
- [ArgoCD Architecture](https://argo-cd.readthedocs.io/en/stable/operator-manual/architecture/)

### 7.5 Controller-Runtime Patterns (Level 3+ Knowledge)

To truly understand why finalizers get stuck or why a controller "ignores" resources, you need to understand the controller-runtime pattern that underlies nearly every Kubernetes controller, including ArgoCD.

**The Reconciliation Loop Model**:

Every controller follows the same fundamental pattern: watch for changes, enqueue work, process work, retry on failure. The key insight is that controllers are **level-triggered**, not **edge-triggered**. They don't react to "what happened" (edge); they react to "what is the current state vs desired state" (level).

```text
┌────────────────────────────────────────────────────────────────────────────┐
│                    CONTROLLER-RUNTIME ARCHITECTURE                          │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  ┌──────────────┐                                                          │
│  │   API Server │                                                          │
│  │   (etcd)     │                                                          │
│  └──────┬───────┘                                                          │
│         │ WATCH                                                            │
│         ▼                                                                  │
│  ┌──────────────┐     ADD/UPDATE/DELETE      ┌──────────────────┐         │
│  │   Informer   │ ──────────────────────────►│   Work Queue     │         │
│  │   (cache)    │                             │  (rate-limited)  │         │
│  └──────────────┘                             └────────┬─────────┘         │
│         │                                              │                   │
│         │ Local cache reads                           │ Pop item          │
│         ▼                                              ▼                   │
│  ┌──────────────┐                             ┌──────────────────┐         │
│  │   Lister     │◄────────────────────────────│   Reconcile()    │         │
│  │   (fast)     │    Read current state       │   (your logic)   │         │
│  └──────────────┘                             └────────┬─────────┘         │
│                                                        │                   │
│                              ┌──────────────┬──────────┴──────────┐        │
│                              ▼              ▼                     ▼        │
│                        ┌──────────┐  ┌──────────────┐     ┌─────────────┐  │
│                        │ Success  │  │ Requeue      │     │ Error       │  │
│                        │ (done)   │  │ (later)      │     │ (backoff)   │  │
│                        └──────────┘  └──────────────┘     └─────────────┘  │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘

KEY INSIGHT: The work queue uses rate limiting with exponential backoff.
             After N failures, retry delay grows: 5ms → 10ms → 20ms → ... → 5min (cap)
```

**Why This Matters for Troubleshooting**:

1. **Informer cache lag**: The controller reads from local cache, not directly from etcd. If you `kubectl edit` a resource, there's a brief window where the controller sees stale state. Usually milliseconds, but under load can be seconds.

2. **Rate-limited retries**: When reconciliation fails, the item is re-enqueued with backoff. After many failures, the controller might only retry every 5 minutes. The controller is "healthy" (processing other items) but effectively ignoring this specific resource.

3. **Level-triggered idempotency**: Reconcile() can be called multiple times for the same resource. Your understanding should be: "What is the CURRENT state? What SHOULD it be? How do I get from A to B?" not "What event triggered this call?"

**Reading Controller Logs**:

When you see logs like these, you now understand what's happening:

```text
I0615 10:23:45.123456 controller.go:123] Starting workers
I0615 10:23:45.234567 controller.go:456] Successfully synced 'afi/alarmengine'
W0615 10:23:46.345678 controller.go:789] Requeuing 'afi/stuck-app' due to error: context deadline exceeded
E0615 10:28:46.456789 controller.go:789] Requeuing 'afi/stuck-app' due to error: context deadline exceeded
```

The 5-minute gap between warnings (10:23 → 10:28) tells you: this item is in exponential backoff. The controller isn't ignoring it — it's rate-limited.

**Diagnostic Commands**:

```bash
# See work queue depth (if exposed via metrics)
kubectl get --raw /metrics | grep workqueue_depth

# See retry counts (if exposed)
kubectl get --raw /metrics | grep workqueue_retries_total

# For ArgoCD specifically, check app refresh timestamps
kubectl get applications.argoproj.io -n <ns> -o json | \
  jq '.items[] | {name: .metadata.name, reconciledAt: .status.reconciledAt}'
```

**The Finalizer Contract in Controller-Runtime Terms**:

When a resource has a finalizer and gets deleted:

1. API server sets `deletionTimestamp` but does NOT delete from etcd
2. Informer fires an UPDATE event (not DELETE)
3. Reconcile() is called. It sees `deletionTimestamp != nil`
4. Reconcile() must: (a) do cleanup work, (b) remove finalizer via API call
5. Once all finalizers removed, API server deletes from etcd
6. Informer fires DELETE event (for any other watchers)

If step 4 fails (cleanup can't complete), the resource stays in limbo: `deletionTimestamp` set, finalizers present, controller in retry backoff.

---

## Appendix: Command Cheat Sheet

### Namespace Diagnostics

```bash
# Phase check
kubectl get ns <ns> -o jsonpath='{.status.phase}'

# Why won't it delete?
kubectl get ns <ns> -o json | jq '.status.conditions'

# All resources in namespace
kubectl api-resources --verbs=list --namespaced -o name | \
  xargs -I {} kubectl get {} -n <ns> --ignore-not-found 2>/dev/null
```

### ArgoCD Diagnostics

```bash
# List Applications
kubectl get applications.argoproj.io -n <ns>

# Detailed Application status (via kubectl)
kubectl get application <app> -n <ns> -o json | \
  jq '{name: .metadata.name, health: .status.health, sync: .status.sync}'

# Detailed Application status (via CLI)
argocd app get <app> --server <server> --grpc-web

# Sync history
argocd app history <app> --server <server> --grpc-web
```

### Finalizer Operations

```bash
# Check finalizers
kubectl get <resource> <name> -n <ns> -o jsonpath='{.metadata.finalizers}'

# Remove finalizers (CAUTION!)
kubectl patch <resource> <name> -n <ns> \
  -p '{"metadata":{"finalizers":null}}' --type=merge
```

### Controller Diagnostics

```bash
# ArgoCD controller status
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Controller logs
kubectl logs -n argocd argocd-application-controller-0 --since=1h | grep <keyword>
```

---

> "The best troubleshooters aren't people who memorize commands. They're people who understand systems deeply enough to ask the right questions. The commands follow naturally from the questions."

---

*Generated from real-world incident investigation, 2025-12-22*
*Case: CI/CD Pipeline Reports Success, Deployment Actually Failed*
