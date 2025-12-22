# Investigation Report: CI/CD Pipeline Reports Success, Deployment Actually Failed

**Date:** 2025-12-22T11:15:00+01:00
**Investigator:** Claude (AI-assisted analysis)
**Cluster:** sandbox (dev.vpp.eneco.com)
**Build ID:** 1468155
**Status:** ROOT CAUSE IDENTIFIED - Requires manual intervention

---

## TL;DR (For the Impatient)

The pipeline lies. It says "succeeded" because it successfully *requested* a deployment from ArgoCD. ArgoCD accepted the request. But Kubernetes cannot actually create resources in a namespace that's been stuck in `Terminating` state for 6 days due to orphaned finalizers.

**Fix:** Remove finalizers from 5 stuck ArgoCD Application CRDs, then re-deploy.

---

## 1. Problem Statement

**Reported Symptom (Artem, 2025-12-22 ~10:43 UTC):**
> "I deployed two times new branch on it with green pipeline, but no deployments and no pods in k8s were created"

**Observation (Alex):**
> "This is an error, but the job returned Exit Code 0, which's misleading."

**This is not a bug. This is a design flaw.** The pipeline verifies that ArgoCD *accepted* the sync request. It does not verify that Kubernetes *executed* the deployment. These are fundamentally different operations.

---

## 2. Root Cause Analysis

### 2.1 The Failure Chain (Mechanistic Explanation)

```
┌────────────────────────────────────────────────────────────────────────────┐
│ T-6 DAYS: Old Feature Branch Environment Torn Down (fbe-744839)           │
├────────────────────────────────────────────────────────────────────────────┤
│ 1. Someone deleted the afi-app-of-apps or triggered cleanup               │
│ 2. ArgoCD set deletionTimestamp on all 21 child Application CRDs          │
│ 3. Each Application has finalizer: resources-finalizer.argocd.argoproj.io │
│ 4. Finalizer contract: "Don't delete me until I've cleaned up my K8s      │
│    resources (pods, services, etc.)"                                      │
│ 5. ArgoCD controller SHOULD process finalizers, delete managed resources, │
│    then remove finalizers                                                 │
│ 6. BUT: 5 Applications never completed finalizer processing               │
│    - alarmengine, assetmonitor, assetplanning, clientgateway, monitor     │
│    - All marked for deletion at 2025-12-16T13:30:03Z                      │
│    - Finalizers never removed                                             │
│ 7. Kubernetes namespace controller sees: "You want to delete namespace    │
│    afi? There are 5 resources with unprocessed finalizers. I'll wait."    │
│ 8. Namespace stuck in Terminating phase. Forever.                         │
└────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────────┐
│ T-0: Today's Deployment Attempt (fbe-768911)                              │
├────────────────────────────────────────────────────────────────────────────┤
│ 1. Artem triggers pipeline for feature/fbe-768911-add-resvar-proxy-...    │
│ 2. Pipeline runs. It does:                                                │
│    a) Helm template → generates Application manifests                     │
│    b) kubectl apply (or argocd app sync) → applies to ArgoCD              │
│    c) ArgoCD responds: "Application spec updated, sync initiated" (200 OK)│
│    d) Pipeline: "Great, I got 200. Exit 0. SUCCESS!"                      │
│ 3. BUT: ArgoCD now tries to create new Applications in namespace "afi"    │
│ 4. Kubernetes apiserver: "Namespace afi is Terminating. I reject all      │
│    create requests for non-finalizer-related resources."                  │
│ 5. ArgoCD: *sad noises* - Apps show Health: Missing, Sync: OutOfSync      │
│ 6. No pods. No deployments. Nothing. Because you can't create resources   │
│    in a Terminating namespace. This is fundamental K8s semantics.         │
│ 7. Artem: "Where are my pods?!"                                           │
└────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Why Finalizers Are Stuck (Root of the Root Cause)

This is the actual question: **Why didn't ArgoCD controller process the finalizers 6 days ago?**

Possible causes (investigation required, but likely candidates):

1. **Race Condition During Deletion**: If the managed K8s resources (Deployments, Services, etc.) were already deleted when ArgoCD tried to verify they're gone, controller may have errored and retried forever.

2. **Controller Resource Exhaustion**: ArgoCD application-controller was overloaded, dropped the finalizer processing task, never retried.

3. **RBAC/Permission Issue**: Controller lost permissions to the `afi` namespace mid-deletion.

4. **Network Partition**: Controller couldn't reach K8s API during the critical window.

5. **ArgoCD Controller Restart**: Controller restarted during finalizer processing, lost in-flight state, didn't pick up orphaned work.

**Evidence suggests #1 or #5**: The controller is currently running (5d20h uptime), but it's not processing these finalizers now either. The finalizers have been orphaned for 6 days with no progress.

```bash
$ kubectl get pods -n argocd | grep controller
argocd-application-controller-0    1/1     Running   0   5d20h
```

Controller is healthy. It just... forgot about these 5 Applications. Or can't process them.

### 2.3 Why the Pipeline Lies

**ADO Build 1468155 Analysis:**

```json
{
  "buildNumber": "20251222.1",
  "result": "succeeded",
  "status": "completed",
  "finishTime": "2025-12-22T09:33:40.380401+00:00"
}
```

The pipeline definition (inferred from behavior):

1. **DOES**: Apply Application manifests to ArgoCD ✓
2. **DOES NOT**: Wait for ArgoCD to report Healthy status ✗
3. **DOES NOT**: Verify pods actually exist in target namespace ✗
4. **DOES NOT**: Check if namespace is in valid state before deployment ✗

This is "fire and forget" deployment. It's fine for happy path. It's catastrophic for diagnosing failures.

**The pipeline succeeded at what it was designed to do.** It just wasn't designed to verify deployment success.

---

## 3. Evidence with Verification Commands

### 3.1 Claim: Namespace `afi` Is Stuck in Terminating State

**Command to verify:**
```bash
kubectl get ns afi -o jsonpath='{.status.phase}'
```

**Expected output if claim is true:**
```
Terminating
```

**Full verification with age:**
```bash
kubectl get ns | grep afi
```

**Actual output (2025-12-22):**
```
afi                             Terminating   12d
afi-monitoring                  Active        2d20h
```

**Technical rationale:** Kubernetes namespace deletion is a multi-phase process. When a namespace enters `Terminating` phase, the namespace controller waits for all namespaced resources to be deleted. If any resource has a finalizer that isn't processed, the namespace will remain in `Terminating` indefinitely. This is by design - finalizers are a contract that says "don't delete me until I've completed my cleanup work."

**K8s source reference:** [kubernetes/kubernetes - namespace_controller.go](https://github.com/kubernetes/kubernetes/blob/master/pkg/controller/namespace/deletion/namespaced_resources_deleter.go)

---

### 3.2 Claim: 5 ArgoCD Applications Have Stuck Finalizers Blocking Deletion

**Command to verify finalizers exist:**
```bash
kubectl get applications.argoproj.io -n afi -o json | \
  jq '.items[] | {name: .metadata.name, finalizers: .metadata.finalizers}'
```

**Expected output if claim is true:**
```json
{"name":"alarmengine","finalizers":["resources-finalizer.argocd.argoproj.io"]}
{"name":"assetmonitor","finalizers":["resources-finalizer.argocd.argoproj.io"]}
{"name":"assetplanning","finalizers":["resources-finalizer.argocd.argoproj.io"]}
{"name":"clientgateway","finalizers":["resources-finalizer.argocd.argoproj.io"]}
{"name":"monitor","finalizers":["resources-finalizer.argocd.argoproj.io"]}
```

**Command to verify deletion timestamp (proves they're marked for deletion):**
```bash
kubectl get applications.argoproj.io -n afi -o json | \
  jq '.items[] | {name: .metadata.name, deletionTimestamp: .metadata.deletionTimestamp}'
```

**Expected output:**
```json
{"name":"alarmengine","deletionTimestamp":"2025-12-16T13:30:03Z"}
{"name":"assetmonitor","deletionTimestamp":"2025-12-16T13:30:03Z"}
{"name":"assetplanning","deletionTimestamp":"2025-12-16T13:30:03Z"}
{"name":"clientgateway","deletionTimestamp":"2025-12-16T13:30:03Z"}
{"name":"monitor","deletionTimestamp":"2025-12-16T13:30:03Z"}
```

**Technical rationale:** When you delete a Kubernetes resource that has a finalizer, Kubernetes sets the `deletionTimestamp` but does not actually remove the resource. The controller that owns the finalizer (in this case, ArgoCD's application-controller) is responsible for:
1. Detecting the deletion via the `deletionTimestamp` field
2. Performing cleanup (deleting managed resources)
3. Removing its finalizer from the list
4. Once all finalizers are removed, Kubernetes garbage collects the resource

If the controller fails to remove the finalizer, the resource lives forever with a `deletionTimestamp` set. This is called a "stuck finalizer."

**ArgoCD finalizer documentation:** The `resources-finalizer.argocd.argoproj.io` finalizer is added by ArgoCD when an Application is created. Its purpose is to ensure that when the Application is deleted, ArgoCD first deletes all Kubernetes resources it was managing (deployments, services, etc.) before the Application CRD itself is removed.

---

### 3.3 Claim: Namespace Conditions Show Exactly Why It Won't Delete

**Command to verify:**
```bash
kubectl get ns afi -o json | jq '.status.conditions'
```

**Expected output if claim is true:**
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

**Technical rationale:** The Kubernetes namespace controller adds these conditions to explain exactly why deletion is blocked:
- `NamespaceContentRemaining`: Lists what types of resources still exist
- `NamespaceFinalizersRemaining`: Lists which finalizers are blocking and on how many resources

These are the official "why won't my namespace delete?" diagnostics from Kubernetes itself.

---

### 3.4 Claim: The Stuck Applications Are From the OLD Branch (fbe-744839)

**Command to verify branch association:**
```bash
kubectl get applications.argoproj.io -n afi -o json | \
  jq '.items[] | {name: .metadata.name, targetRevision: .spec.sources[0].targetRevision}'
```

**Expected output showing OLD branch:**
```json
{"name":"alarmengine","targetRevision":"feature/fbe-744839-PlanningPublishBalancingreserveContract"}
{"name":"assetmonitor","targetRevision":"feature/fbe-744839-PlanningPublishBalancingreserveContract"}
{"name":"assetplanning","targetRevision":"feature/fbe-744839-PlanningPublishBalancingreserveContract"}
{"name":"clientgateway","targetRevision":"feature/fbe-744839-PlanningPublishBalancingreserveContract"}
{"name":"monitor","targetRevision":"feature/fbe-744839-PlanningPublishBalancingreserveContract"}
```

**Verification via ArgoCD CLI:**
```bash
argocd app list --server argocd.dev.vpp.eneco.com --grpc-web | grep "afi/" | awk '{print $1, $NF}'
```

**Technical rationale:** Each ArgoCD Application CRD stores the Git reference (branch/tag/commit) it should sync from in `.spec.sources[].targetRevision`. If the stuck apps show the old branch (`fbe-744839`) while the app-of-apps is now pointing to the new branch (`fbe-768911`), this proves these are orphaned apps from a previous deployment, not the current one.

---

### 3.5 Claim: The NEW Branch (fbe-768911) Has Never Successfully Synced

**Command to verify sync history:**
```bash
argocd app history afi-app-of-apps --server argocd.dev.vpp.eneco.com --grpc-web
```

**Expected output showing only OLD branch sync:**
```
SOURCE  https://enecomanagedcloud@dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/VPP-Configuration
ID      DATE                           REVISION
0       2025-12-16 10:59:28 +0100 CET  feature/fbe-744839-PlanningPublishBalancingreserveContract (702d031)
```

**Command to verify current target vs last sync:**
```bash
argocd app get afi-app-of-apps --server argocd.dev.vpp.eneco.com --grpc-web --show-operation | \
  grep -E "(Target:|Revision:)"
```

**Expected output showing mismatch:**
```
  Target:           feature/fbe-768911-add-resvar-proxy-to-gateway  # CURRENT TARGET
  Revision:         feature/fbe-744839... (702d031)                  # LAST SUCCESSFUL SYNC
```

**Technical rationale:** ArgoCD maintains a history of successful syncs. If the history shows only the old branch and the current target shows the new branch, it proves the new branch deployment was requested but never completed.

---

### 3.6 Claim: ArgoCD App-of-Apps Shows "Progressing" Health (Trying But Failing)

**Command to verify:**
```bash
argocd app get afi-app-of-apps --server argocd.dev.vpp.eneco.com --grpc-web | \
  grep -E "(Health Status:|Sync Status:)"
```

**Expected output:**
```
Sync Status:        OutOfSync from feature/fbe-768911-add-resvar-proxy-to-gateway
Health Status:      Progressing
```

**Alternative via kubectl:**
```bash
kubectl get applications.argoproj.io afi-app-of-apps -n argocd -o json | \
  jq '{health: .status.health.status, sync: .status.sync.status}'
```

**Expected output:**
```json
{"health":"Progressing","sync":"OutOfSync"}
```

**Technical rationale:** ArgoCD health statuses:
- `Healthy`: All resources are as expected
- `Progressing`: Resources are being created/updated (normal during deploy, bad if it stays here)
- `Degraded`: Some resources are unhealthy
- `Missing`: Resources don't exist (can't be created)

`Progressing` for extended periods indicates ArgoCD is trying to sync but cannot complete the operation.

---

### 3.7 Claim: Child Applications Show "Health: Missing" (Cannot Be Created)

**Command to verify:**
```bash
argocd app get afi-app-of-apps --server argocd.dev.vpp.eneco.com --grpc-web | \
  grep -E "^argoproj.io.*Application.*Missing"
```

**Expected output (should list child apps with Missing health):**
```
argoproj.io  Application  afi  frontend             OutOfSync  Missing   ...
argoproj.io  Application  afi  integration-tests    OutOfSync  Missing   ...
argoproj.io  Application  afi  telemetry            OutOfSync  Missing   ...
...
```

**Count verification:**
```bash
argocd app get afi-app-of-apps --server argocd.dev.vpp.eneco.com --grpc-web | \
  grep "Missing" | wc -l
```

**Technical rationale:** `Health: Missing` means ArgoCD attempted to create/find the resource in Kubernetes but it doesn't exist. This happens when:
1. The resource was never created (creation failed)
2. The resource was deleted and ArgoCD can't recreate it

In a `Terminating` namespace, Kubernetes apiserver rejects `CREATE` requests for non-system resources. ArgoCD tries to create the Application CRDs, apiserver rejects them, ArgoCD marks them as `Missing`.

---

### 3.8 Claim: No Pods or Deployments Exist in Namespace afi

**Command to verify pods:**
```bash
kubectl get pods -n afi 2>&1
```

**Expected output:**
```
No resources found in afi namespace.
```

**Command to verify deployments:**
```bash
kubectl get deployments -n afi 2>&1
```

**Expected output:**
```
No resources found in afi namespace.
```

**Command to verify ALL resources in namespace:**
```bash
kubectl get all -n afi 2>&1
```

**Expected output:**
```
No resources found in afi namespace.
```

**Command to verify only ArgoCD Applications remain:**
```bash
kubectl api-resources --verbs=list --namespaced -o name | \
  xargs -I {} sh -c 'kubectl get {} -n afi --ignore-not-found 2>/dev/null | grep -v "^$"'
```

**Expected output (only Application CRDs):**
```
NAME            SYNC STATUS   HEALTH STATUS
alarmengine     OutOfSync     Missing
assetmonitor    OutOfSync     Missing
assetplanning   OutOfSync     Missing
clientgateway   OutOfSync     Missing
monitor         OutOfSync     Missing
```

**Technical rationale:** This proves the namespace is effectively empty except for the stuck Application CRDs. All actual workloads (pods, deployments, services) are gone. The only thing keeping the namespace alive is the 5 Application CRDs with stuck finalizers.

---

### 3.9 Claim: ADO Pipeline Build 1468155 Shows "Succeeded"

**Command to verify:**
```bash
az pipelines build show --id 1468155 \
  --org https://dev.azure.com/enecomanagedcloud \
  --project "Myriad - VPP" \
  --query "{buildNumber: buildNumber, result: result, status: status, finishTime: finishTime}"
```

**Expected output:**
```json
{
  "buildNumber": "20251222.1",
  "result": "succeeded",
  "status": "completed",
  "finishTime": "2025-12-22T09:33:40.380401+00:00"
}
```

**Full build details:**
```bash
az pipelines build show --id 1468155 \
  --org https://dev.azure.com/enecomanagedcloud \
  --project "Myriad - VPP" \
  --output json
```

**Technical rationale:** Azure DevOps pipelines report success based on exit codes. If all tasks return exit code 0, the pipeline shows `succeeded`. The pipeline tasks that interact with ArgoCD likely use `kubectl apply` or `argocd app sync`, which return 0 as long as the API call succeeds - regardless of whether the actual deployment completes successfully.

---

### 3.10 Claim: ArgoCD Controller Is Healthy (Not the Issue)

**Command to verify controller status:**
```bash
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

**Expected output (Running, no restarts):**
```
NAME                                    READY   STATUS    RESTARTS   AGE
argocd-application-controller-0         1/1     Running   0          5d20h
```

**Command to check controller logs for errors related to afi:**
```bash
kubectl logs -n argocd argocd-application-controller-0 --since=1h | \
  grep -i "afi" | tail -20
```

**Technical rationale:** If the controller were crashing, restarting, or had errors, that would explain why finalizers aren't being processed. A healthy controller that ignores stuck finalizers is a different problem - likely the controller "gave up" on these apps or has a bug in its finalizer processing logic.

---

### 3.11 Claim: Only 5 of ~21 Applications Are Stuck

**Command to verify count of stuck apps:**
```bash
kubectl get applications.argoproj.io -n afi --no-headers | wc -l
```

**Expected output:**
```
5
```

**Command to verify expected app count from app-of-apps:**
```bash
argocd app get afi-app-of-apps --server argocd.dev.vpp.eneco.com --grpc-web | \
  grep "argoproj.io.*Application" | wc -l
```

**Expected output (all child apps it's trying to manage):**
```
21
```

**Technical rationale:** The app-of-apps defines 21 child Applications. If only 5 are stuck with finalizers and 16 were successfully deleted, something is different about these 5. Possible explanations:
- They were managing more complex resources
- They were deleted in a different order
- Controller encountered an error specific to these 5

---

## 4. Full Evidence Dump (Verbatim Command Outputs)

### 4.1 Namespace Status

```bash
$ kubectl get ns | grep afi
afi                             Terminating   12d
afi-monitoring                  Active        2d20h
```

### 4.2 Namespace Conditions

```bash
$ kubectl get ns afi -o json | jq '.status.conditions'
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

### 4.3 The 5 Stuck Applications (Full Detail)

```bash
$ kubectl get applications.argoproj.io -n afi -o json | jq '.items[] | {
  name: .metadata.name,
  deletionTimestamp: .metadata.deletionTimestamp,
  finalizers: .metadata.finalizers,
  targetBranch: .spec.sources[0].targetRevision,
  healthStatus: .status.health.status,
  syncStatus: .status.sync.status
}'

{
  "name": "alarmengine",
  "deletionTimestamp": "2025-12-16T13:30:03Z",
  "finalizers": ["resources-finalizer.argocd.argoproj.io"],
  "targetBranch": "feature/fbe-744839-PlanningPublishBalancingreserveContract",
  "healthStatus": "Missing",
  "syncStatus": "OutOfSync"
}
{
  "name": "assetmonitor",
  "deletionTimestamp": "2025-12-16T13:30:03Z",
  "finalizers": ["resources-finalizer.argocd.argoproj.io"],
  "targetBranch": "feature/fbe-744839-PlanningPublishBalancingreserveContract",
  "healthStatus": "Missing",
  "syncStatus": "OutOfSync"
}
{
  "name": "assetplanning",
  "deletionTimestamp": "2025-12-16T13:30:03Z",
  "finalizers": ["resources-finalizer.argocd.argoproj.io"],
  "targetBranch": "feature/fbe-744839-PlanningPublishBalancingreserveContract",
  "healthStatus": "Missing",
  "syncStatus": "OutOfSync"
}
{
  "name": "clientgateway",
  "deletionTimestamp": "2025-12-16T13:30:03Z",
  "finalizers": ["resources-finalizer.argocd.argoproj.io"],
  "targetBranch": "feature/fbe-744839-PlanningPublishBalancingreserveContract",
  "healthStatus": "Missing",
  "syncStatus": "OutOfSync"
}
{
  "name": "monitor",
  "deletionTimestamp": "2025-12-16T13:30:03Z",
  "finalizers": ["resources-finalizer.argocd.argoproj.io"],
  "targetBranch": "feature/fbe-744839-PlanningPublishBalancingreserveContract",
  "healthStatus": "Missing",
  "syncStatus": "OutOfSync"
}
```

### 4.4 ArgoCD App-of-Apps Status

```bash
$ argocd app get afi-app-of-apps --server argocd.dev.vpp.eneco.com --grpc-web
Name:               argocd/afi-app-of-apps
Project:            vpp-core
Server:             https://kubernetes.default.svc
Namespace:          afi
URL:                https://argocd.dev.vpp.eneco.com//applications/afi-app-of-apps
Sources:
- Repo:             https://enecomanagedcloud@dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/VPP-Configuration
  Target:           feature/fbe-768911-add-resvar-proxy-to-gateway
  Path:             Helm/vpp-core-app-of-apps
  Helm Values:      values.yaml,values.vppcore.sandbox.yaml
SyncWindow:         Sync Allowed
Sync Policy:        Automated (Prune)
Sync Status:        OutOfSync from feature/fbe-768911-add-resvar-proxy-to-gateway
Health Status:      Progressing

GROUP        KIND         NAMESPACE  NAME                 STATUS     HEALTH       HOOK  MESSAGE
argoproj.io  Application  afi        frontend             OutOfSync  Missing            application.argoproj.io/frontend created
argoproj.io  Application  afi        integration-tests    OutOfSync  Missing            ...
[... 21 total child applications, most showing Missing ...]
```

### 4.5 ArgoCD Sync History

```bash
$ argocd app history afi-app-of-apps --server argocd.dev.vpp.eneco.com --grpc-web
SOURCE  https://enecomanagedcloud@dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/VPP-Configuration
ID      DATE                           REVISION
0       2025-12-16 10:59:28 +0100 CET  feature/fbe-744839-PlanningPublishBalancingreserveContract (702d031)
```

### 4.6 Pods and Deployments (Proof of Non-Existence)

```bash
$ kubectl get pods -n afi
No resources found in afi namespace.

$ kubectl get deployments -n afi
No resources found in afi namespace.

$ kubectl get all -n afi
No resources found in afi namespace.
```

For contrast, the monitoring namespace works fine:

```bash
$ kubectl get pods -n afi-monitoring
NAME                                                  READY   STATUS    AGE
grafana-deployment-57ddd86dbc-zs6qm                   1/1     Running   2d20h
opentelemetry-collector-collector-6ddd96d87f-lg5gq    1/1     Running   2d20h
prometheus-kps-afi-prometheus-0                       2/2     Running   2d20h
```

---

## 5. Remediation

### 5.1 Immediate Fix (Do This Now)

**Step 1: Forcibly remove finalizers from the 5 stuck Applications**

```bash
for app in alarmengine assetmonitor assetplanning clientgateway monitor; do
  echo "Removing finalizer from $app..."
  kubectl patch application $app -n afi \
    -p '{"metadata":{"finalizers":null}}' --type=merge
done
```

**Verification after each patch:**
```bash
kubectl get application $app -n afi -o jsonpath='{.metadata.finalizers}'
# Should return empty: []
```

**WARNING**: This bypasses ArgoCD's resource cleanup. Any resources these apps were managing (if any exist) will be orphaned. In this case, the managed resources are already gone (Health: Missing), so this is safe.

**Step 2: Verify namespace deletion completes**

```bash
# Watch namespace disappear
kubectl get ns afi -w

# Or poll until gone:
while kubectl get ns afi &>/dev/null; do echo "Waiting..."; sleep 2; done; echo "Namespace deleted!"
```

Expected: Namespace deleted within ~30 seconds.

**Step 3: Trigger fresh deployment**

```bash
# Force sync the app-of-apps to recreate everything
argocd app sync afi-app-of-apps \
  --server argocd.dev.vpp.eneco.com \
  --grpc-web \
  --force \
  --prune

# Or: Just wait. Auto-sync should pick it up.
```

**Step 4: Verify deployment success**

```bash
# Wait for apps to become Healthy
argocd app wait afi-app-of-apps \
  --server argocd.dev.vpp.eneco.com \
  --grpc-web \
  --health \
  --timeout 600

# Verify pods exist
kubectl get pods -n afi
```

### 5.2 Long-Term Fixes

#### A. Fix the Pipeline (Critical)

The pipeline MUST verify deployment success, not just request acceptance.

**Add to pipeline YAML:**

```yaml
- task: Bash@3
  displayName: 'Wait for ArgoCD Health'
  inputs:
    targetType: 'inline'
    script: |
      argocd app wait $(APP_NAME) \
        --server argocd.dev.vpp.eneco.com \
        --grpc-web \
        --health \
        --timeout 600 \
        --auth-token $(ARGOCD_TOKEN)

      if [ $? -ne 0 ]; then
        echo "##vso[task.logissue type=error]Deployment health check failed"
        exit 1
      fi
  continueOnError: false
```

This makes the pipeline wait until ArgoCD reports the app as Healthy. If it doesn't within 10 minutes, the pipeline fails. **As it should.**

#### B. Pre-Deployment Namespace Check

Before deploying, verify target namespace is in valid state:

```yaml
- task: Bash@3
  displayName: 'Verify Namespace State'
  inputs:
    targetType: 'inline'
    script: |
      NS_PHASE=$(kubectl get ns $(NAMESPACE) -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")

      if [ "$NS_PHASE" = "Terminating" ]; then
        echo "##vso[task.logissue type=error]Namespace $(NAMESPACE) is stuck in Terminating state"
        echo "Manual intervention required: Remove stuck finalizers"
        exit 1
      fi
```

#### C. ArgoCD Finalizer Monitoring

Add Prometheus alert for stuck finalizers:

```yaml
- alert: ArgoCD_StuckFinalizers
  expr: |
    count by (namespace, name) (
      kube_customresource_status_condition{
        group="argoproj.io",
        resource="applications"
      } == 1
    ) and on(namespace, name) (
      (time() - kube_customresource_created{
        group="argoproj.io",
        resource="applications"
      }) > 3600
    )
  for: 1h
  labels:
    severity: warning
  annotations:
    summary: "ArgoCD Applications stuck in terminating for >1h"
    description: "{{ $labels.namespace }}/{{ $labels.name }} has been terminating for over 1 hour."
```

#### D. Feature Branch Environment Cleanup SOP

Document and automate proper FBE teardown:

1. Delete child Applications first (wait for Health: Unknown/Missing)
2. Verify all managed K8s resources are gone
3. Delete parent app-of-apps
4. Verify Application CRDs are fully deleted (no finalizers remaining)
5. Delete namespace
6. Verify namespace is gone

Each step must verify completion before proceeding. No fire-and-forget.

---

## 6. Questions That Remain (For Future Investigation)

1. **Why didn't ArgoCD controller process the finalizers 6 days ago?**

   **Investigation command:**
   ```bash
   # Get controller logs from Dec 16 (if retained)
   kubectl logs -n argocd argocd-application-controller-0 --since-time="2025-12-16T13:00:00Z" 2>/dev/null | \
     grep -E "(alarmengine|assetmonitor|assetplanning|clientgateway|monitor|afi)" | head -100
   ```

   Check for OOM kills, restarts, error spikes.

2. **Why are only 5 of 21 apps stuck?**

   **Investigation command:**
   ```bash
   # Compare stuck apps to successfully deleted apps
   # (Would need git history or ArgoCD logs from Dec 16)
   ```

   16 apps were successfully deleted. These 5 failed. What's different about them?

3. **Is this a recurring pattern?**

   **Investigation command:**
   ```bash
   kubectl get ns --field-selector status.phase=Terminating
   ```

   Check other FBE namespaces for similar issues.

4. **Who or what initiated the deletion on Dec 16?**

   **Investigation commands:**
   ```bash
   # Git history
   cd VPP-Configuration && git log --since="2025-12-16" --until="2025-12-17" --oneline

   # ArgoCD audit logs (if enabled)
   argocd admin logs --server argocd.dev.vpp.eneco.com | grep -i afi

   # ADO pipeline runs
   az pipelines runs list --org https://dev.azure.com/enecomanagedcloud \
     --project "Myriad - VPP" --query-order FinishTimeDesc --top 50 | \
     jq '.[] | select(.finishTime | startswith("2025-12-16"))'
   ```

---

## 7. Lessons Learned

1. **Exit code 0 doesn't mean success.** It means "I didn't crash." Verify actual outcomes.

2. **Finalizers are contracts.** If a finalizer can't complete its work, the resource lives forever. Design for finalizer failure modes.

3. **Kubernetes namespace deletion is not atomic.** It depends on all children completing their finalizers. A single stuck finalizer blocks everything.

4. **ArgoCD Application CRDs are Kubernetes resources.** They follow K8s semantics. Terminating namespace = no new Applications.

5. **GitOps is fire-and-forget by default.** You MUST add verification steps or you will have silent failures.

---

## Appendix A: Complete Command Reference

### Namespace Diagnostics

```bash
# Check namespace phase
kubectl get ns afi -o jsonpath='{.status.phase}'

# Get namespace conditions (explains why it won't delete)
kubectl get ns afi -o json | jq '.status.conditions'

# Check namespace deletion timestamp
kubectl get ns afi -o jsonpath='{.metadata.deletionTimestamp}'

# Check namespace finalizers (namespace-level, usually empty)
kubectl get ns afi -o jsonpath='{.metadata.finalizers}'
```

### ArgoCD Application Diagnostics

```bash
# List apps in namespace
kubectl get applications.argoproj.io -n afi

# Get app finalizers
kubectl get applications.argoproj.io <app> -n afi -o jsonpath='{.metadata.finalizers}'

# Get app deletion timestamp
kubectl get applications.argoproj.io <app> -n afi -o jsonpath='{.metadata.deletionTimestamp}'

# Get app target branch
kubectl get applications.argoproj.io <app> -n afi -o jsonpath='{.spec.sources[0].targetRevision}'

# Full app status via ArgoCD CLI
argocd app get <app> --server argocd.dev.vpp.eneco.com --grpc-web
```

### Finalizer Removal (DANGEROUS - Last Resort)

```bash
# Remove finalizer from single app
kubectl patch application <app> -n afi \
  -p '{"metadata":{"finalizers":null}}' --type=merge

# Remove finalizers from all apps in namespace
kubectl get applications.argoproj.io -n afi -o name | \
  xargs -I {} kubectl patch {} -n afi \
  -p '{"metadata":{"finalizers":null}}' --type=merge
```

### ADO Pipeline Diagnostics

```bash
# Get build details
az pipelines build show --id <build-id> \
  --org https://dev.azure.com/enecomanagedcloud \
  --project "Myriad - VPP"

# Get build result and status
az pipelines build show --id <build-id> \
  --org https://dev.azure.com/enecomanagedcloud \
  --project "Myriad - VPP" \
  --query "{result: result, status: status}"
```

---

## Appendix B: Files and Resources

| Resource | Location/ID |
|----------|-------------|
| Failed Build | [ADO Build 1468155](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_build/results?buildId=1468155) |
| ArgoCD Dashboard | [afi-app-of-apps](https://argocd.dev.vpp.eneco.com/applications/afi-app-of-apps) |
| Old Branch | `feature/fbe-744839-PlanningPublishBalancingreserveContract` |
| New Branch | `feature/fbe-768911-add-resvar-proxy-to-gateway` |
| Stuck Applications | `afi/{alarmengine,assetmonitor,assetplanning,clientgateway,monitor}` |
| Affected Namespace | `afi` (Terminating) |
| Healthy Namespace | `afi-monitoring` (Active) |

---

**End of Report**

*"The pipeline doesn't care if your deployment works. It only cares if it ran without crashing. These are not the same thing."*
