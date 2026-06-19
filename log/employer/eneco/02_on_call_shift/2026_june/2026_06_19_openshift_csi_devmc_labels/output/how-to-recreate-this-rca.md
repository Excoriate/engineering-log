---
task_id: 2026-06-19-openshift-csi-devmc-labels
agent: codex
status: review
summary: Replay guide for recreating the Dev-MC RCA from oc commands and official docs.
---

# How To Recreate This RCA

## Recreation Knowledge Contract

This guide lets you reproduce the reasoning path, not just the final answer. You should be able to start from "ArgoCD is stuck" and independently arrive at "OpenShift admission is rejecting pods because an unlabeled ephemeral CSIDriver is treated as privileged while the namespace is lower than privileged."

## Preconditions

- You are logged in to the target OpenShift cluster with `oc`.
- You have read access to namespace `eneco-vpp` and cluster-scoped `CSIDriver` objects.
- You do not paste or store login tokens in notes. If you captured terminal screenshots, redact tokens before sharing.
- Optional: `jq` for the cluster-wide recurrence scan.

## Source Inventory

| Source | Use |
| --- | --- |
| [Observed Dev-MC session](../proofs/outputs/observed-devmc-session.md) | Shows the original `oc` observations used for the RCA. |
| [Context ledger](../antecedents/context-ledger.md) | Names the runtime, workload, namespace, driver, and owner surfaces. |
| [Input inventory](../antecedents/input-inventory.md) | Lists screenshots, raw error text, commands, and official docs. |
| [OpenShift Pod Security Admission docs](https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html/authentication_and_authorization/understanding-and-managing-pod-security-admission) | Explains namespace admission behavior. |
| [OpenShift CSI docs](https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html/storage/using-container-storage-interface-csi) | Explains CSIDriver profile behavior for inline CSI volumes. |

## Replay Steps

### 1. Anchor the cluster

```bash
# WHY: Wrong-cluster diagnosis is worse than no diagnosis.
oc whoami --show-server
oc version
```

Reasoning checkpoint: if the server is not Dev-MC, stop. If the version is not OpenShift 4.20.x, use the docs for the actual server version.

### 2. Move from ArgoCD to Kubernetes controller state

```bash
# WHY: ArgoCD reports convergence; Deployment tells whether Kubernetes can create pods.
oc get deploy -n eneco-vpp
```

Reasoning checkpoint: if the affected Deployments are not ready/up-to-date, inspect the Deployment. If they are healthy, Argo may be stale or blocked elsewhere.

### 3. Read the first failing controller event

```bash
# WHY: Deployment events name the boundary where rollout failed.
oc describe deploy assetplanning-eneco-vpp -n eneco-vpp
```

Look for:

```text
Progressing: False
Reason: ReplicaSetCreateError
Error creating: pods ... is forbidden ... inline volume ... CSIDriver secrets-store.csi.k8s.io ... namespace ... lower than privileged
```

Reasoning checkpoint: `forbidden` means admission denied the request. The pod was not scheduled, did not pull an image, and did not start. New pod logs are the wrong evidence surface.

### 4. Check whether the second affected app has the same mechanism

```bash
# WHY: Same failure in another workload points to platform/admission root cause.
oc describe deploy fleetoptimizersolver-eneco-vpp -n eneco-vpp
```

Reasoning checkpoint: if the second workload has the same inline CSI forbidden event, the shared mechanism is the CSI driver plus namespace security. If it differs, split the RCA.

### 5. Inspect the namespace side of the admission decision

```bash
# WHY: Pod Security Admission uses namespace labels as policy input.
oc describe ns eneco-vpp
```

Look for `pod-security.kubernetes.io/*` labels and OpenShift security annotations. A namespace that is restricted or otherwise lower than privileged cannot admit a pod requiring privileged under this CSI admission rule.

### 6. Inspect the driver side of the admission decision

```bash
# WHY: The event named the CSI driver; the CSIDriver object contains the driver-level admission classification.
oc describe csidriver secrets-store.csi.k8s.io
```

Look for:

```text
Labels: <none>
Volume Lifecycle Modes:
  Ephemeral
```

Reasoning checkpoint: if the driver is ephemeral and lacks `security.openshift.io/csi-ephemeral-volume-profile`, OpenShift treats it as privileged for CSI ephemeral volume admission behavior. That explains the exact forbidden event.

### 7. Scope all currently impacted and exposed namespaces

Use events for namespaces already failing:

```bash
# WHY: Find namespaces with recent failed pod creation events for this exact CSI admission error.
oc get events -A -o json | jq -r '.items[] | select((.message // "") | contains("inline volume provided by CSIDriver secrets-store.csi.k8s.io")) | [.metadata.namespace, .involvedObject.kind, .involvedObject.name, .reason, (.message | gsub("\\n"; " "))] | @tsv' | sort -u
```

Use workload templates for namespaces exposed on next rollout:

```bash
# WHY: Find workload templates across all namespaces that declare the Secrets Store CSI inline volume driver.
oc get deploy,statefulset,daemonset,job,cronjob -A -o json | jq -r 'def vols: if .kind == "CronJob" then (.spec.jobTemplate.spec.template.spec.volumes // []) else (.spec.template.spec.volumes // []) end; .items[] | select([vols[]? | select(.csi.driver == "secrets-store.csi.k8s.io")] | length > 0) | [.metadata.namespace, .kind, .metadata.name] | @tsv' | sort -u
```

Reasoning checkpoint: event output means "already observed failing"; workload-template output means "exposed to the same root cause when it rolls out." Keep those two claims separate.

### 8. Match the observation to official docs

Open the OpenShift docs for the actual cluster version and verify these concepts:

- Pod Security Admission modes include `enforce`; enforce rejects pods that do not comply with the selected profile.
- Profiles include `privileged`, `baseline`, and `restricted`.
- Pod Security Admission and SCC are independent controllers.
- CSI inline ephemeral volumes are checked against the driver profile label `security.openshift.io/csi-ephemeral-volume-profile`.
- If the driver lacks that label, the CSI Volume Admission plugin treats it as privileged for enforcement/warn/audit behavior.

Reasoning checkpoint: do not claim "namespace was explicitly enforce=restricted" unless the namespace label actually says that. The important point is lower-than-privileged admission context plus unclassified driver treated as privileged.

### 9. Explain the workaround and the durable fix

If CMC sets this namespace label:

```bash
# WHY: This shows the broad emergency mitigation that raises the namespace admission level.
oc describe ns eneco-vpp
```

Then pods can be admitted because the namespace is now privileged enough for the unclassified CSI driver. But the durable fix is driver-level classification in GitOps:

```yaml
metadata:
  labels:
    security.openshift.io/csi-ephemeral-volume-profile: restricted
```

Reasoning checkpoint: namespace privileged proves the admission mismatch; it does not prove least privilege.

### 10. Verify that the fix works

```bash
# WHY: The final proof is the previously failing rollout path.
oc rollout status deploy/assetplanning-eneco-vpp -n eneco-vpp
oc rollout status deploy/fleetoptimizersolver-eneco-vpp -n eneco-vpp
```

Then inspect events again if needed:

```bash
# WHY: Confirm the old forbidden ReplicaSetCreateError disappeared or identify the next blocker.
oc describe deploy assetplanning-eneco-vpp -n eneco-vpp
oc describe deploy fleetoptimizersolver-eneco-vpp -n eneco-vpp
```

## Reasoning Self-Test

Use these questions to test whether you really understand the RCA:

| Question | Good answer |
| --- | --- |
| Why not start with pod logs? | The new pods were denied before creation, so there may be no new pod logs. |
| Why did ArgoCD stay Progressing? | Kubernetes could not create the desired new ReplicaSet/pods, so desired state was not reached. |
| Why did namespace privileged fix it? | It raised the namespace admission profile to match the unclassified driver treated as privileged. |
| Why is driver labeling better? | It classifies the cluster-scoped object causing the privileged default instead of weakening every pod in the namespace. |
| Why could old pods still run? | Admission is checked on pod creation; existing pods are not retroactively re-created by the admission controller. |
| Why could ACC/PRD be affected? | Same OpenShift behavior plus same unlabeled driver plus same inline CSI workload pattern plus namespaces below privileged. |

## Evidence Promotion Rules

| Claim type | Minimum evidence |
| --- | --- |
| "This is happening in Dev-MC" | `oc whoami --show-server` points to Dev-MC. |
| "Deployment rollout is blocked" | `oc describe deploy` shows `ReplicaSetCreateError`. |
| "Admission rejected pod creation" | Event says `forbidden` during pod creation. |
| "CSI driver is involved" | Pod template uses CSI driver and event names the same driver. |
| "Driver is unclassified" | `oc describe csidriver` lacks `security.openshift.io/csi-ephemeral-volume-profile`. |
| "Namespace is lower than privileged" | Namespace labels/annotations and the admission event agree. |
| "Durable fix is present" | GitOps source and live CSIDriver show the profile label; rollout works without broad namespace exception. |

## Reproduction Failure Conditions

The recreation has failed if the cluster context is not Dev-MC, if `oc describe deploy` does not show a forbidden `ReplicaSetCreateError`, if the workload does not declare the Secrets Store CSI inline driver, or if the CSIDriver already has a valid profile label and the namespace is already privileged. In those cases, do not force this RCA onto the evidence; start a new hypothesis.
