---
task_id: 2026-06-19-openshift-csi-devmc-labels
agent: codex
status: review
summary: How CMC should fix the Dev-MC Secrets Store CSI inline volume Pod Security Admission issue.
---

# How To Fix - Secrets Store CSI inline volume admission failure

## Fix Knowledge Contract

The cluster currently treats `secrets-store.csi.k8s.io` inline CSI volumes as privileged because the `CSIDriver` object is not labeled with an OpenShift CSI ephemeral volume profile. Workload namespaces like `eneco-vpp` are lower than privileged, so OpenShift refuses new pods that mount that driver inline. Making the namespace privileged works, but it is a broad exception. The better fix is to classify the CSI driver itself in CMC GitOps, then verify that restricted namespaces can create pods using it.

## Mechanism Recap

OpenShift rejected new pods because the pod templates used an inline CSI volume from `secrets-store.csi.k8s.io`, while the CSIDriver lacked the OpenShift profile label and the namespace was below privileged. The fix must either raise the namespace admission level as an emergency mitigation or classify the driver so restricted namespaces can keep their intended posture.

## Fix Decision Table

| Time horizon | Fix | When to use it | Risk |
| --- | --- | --- | --- |
| Emergency | Add `pod-security.kubernetes.io/enforce=privileged` to the namespace. | When rollout must be unblocked immediately. | Broadens namespace-level Pod Security Admission for all pods in that namespace. |
| Durable | Add `security.openshift.io/csi-ephemeral-volume-profile=restricted` to `CSIDriver/secrets-store.csi.k8s.io` in CMC GitOps, if validated. | Preferred long-term platform fix. | Requires CMC validation that this driver is safe for restricted namespaces. |
| Preventive | Scan all namespaces/workloads using the same driver and check driver profile labels. | Before ACC/PRD rollout or after OpenShift upgrades. | Requires platform ownership and a recurring control. |

## Fix Plan

1. Locate the GitOps source that creates `CSIDriver/secrets-store.csi.k8s.io`. The live object had an ArgoCD tracking annotation pointing to `cmc-secrets-store-csi-driver`.
2. Validate the driver can be classified as `restricted` for CSI inline ephemeral volume admission. This validation belongs to CMC/platform because it changes cluster-wide security metadata.
3. Add this label to the `CSIDriver` manifest if validation passes:

```yaml
metadata:
  labels:
    security.openshift.io/csi-ephemeral-volume-profile: restricted
```

4. Sync the CMC ArgoCD app that owns the driver.
5. Verify the label is present in the live cluster.
6. Verify affected Deployments can roll out without relying on namespace-wide `enforce=privileged`.
7. Decide whether to remove the temporary namespace privileged label after the driver-level fix is proven.

## Verification

These are read-only except where clearly marked. The mutation command is shown only so the exact object and label are unambiguous; it should be implemented through GitOps, not as a permanent manual patch.

### 1. Check current driver classification

```bash
# WHY: Prove whether the cluster-scoped CSI driver is explicitly classified for inline ephemeral volume admission.
oc describe csidriver secrets-store.csi.k8s.io
```

Look for:

```text
Labels:
  security.openshift.io/csi-ephemeral-volume-profile=restricted
Volume Lifecycle Modes:
  Ephemeral
```

If `Labels: <none>` or the profile label is absent, the platform-level root cause remains.

### 2. Check namespace mitigation state

```bash
# WHY: Show whether the namespace is relying on the broad privileged workaround.
oc describe ns eneco-vpp
```

Look for:

```text
pod-security.kubernetes.io/enforce=privileged
```

If this label is present, it explains why pods can now be admitted despite the missing driver profile. It does not prove the durable fix is present.

### 3. Proposed GitOps label, not preferred as a manual permanent patch

```bash
# WHY: This is the exact live-object mutation CMC's GitOps change should produce, but the source of truth should be GitOps.
oc label csidriver secrets-store.csi.k8s.io \
  security.openshift.io/csi-ephemeral-volume-profile=restricted \
  --overwrite
```

Use the command above only under CMC change control if an emergency live patch is approved. The durable implementation should land in the manifest that ArgoCD owns.

### 4. Verify rollout behavior

```bash
# WHY: Confirm the controller path that failed before can now create pods and complete rollout.
oc rollout status deploy/assetplanning-eneco-vpp -n eneco-vpp
oc rollout status deploy/fleetoptimizersolver-eneco-vpp -n eneco-vpp
```

If rollout still fails, immediately inspect the Deployment events again:

```bash
# WHY: Get the new controller event; a different failure may be hiding after the admission issue is fixed.
oc describe deploy assetplanning-eneco-vpp -n eneco-vpp
oc describe deploy fleetoptimizersolver-eneco-vpp -n eneco-vpp
```

## What This Fix Does Not Change

`pod-security.kubernetes.io/enforce=privileged` changes the namespace admission profile. That means all pods in that namespace are evaluated against the least restrictive Pod Security Admission profile. OpenShift SCC still runs independently, so this is not the same as giving every pod root automatically, but it removes one namespace-level guardrail. If the real problem is that the CSI driver is missing its classification label, the more precise fix is to classify that driver.

## Done Criteria

The issue is durably fixed when all of these are true:

| Criterion | Evidence |
| --- | --- |
| CSIDriver has an explicit `security.openshift.io/csi-ephemeral-volume-profile` label. | `oc describe csidriver secrets-store.csi.k8s.io`. |
| Affected Deployments can roll out. | `oc rollout status` completes and `oc describe deploy` has no new forbidden `ReplicaSetCreateError`. |
| Namespace does not require permanent `enforce=privileged` solely for this CSI driver. | Namespace labels and CMC decision record. |
| Other namespaces using the same inline CSI driver are assessed. | Cluster-wide scan output or CMC ticket/PR. |
| GitOps source, not only live cluster state, contains the fix. | CMC PR merged and ArgoCD synced. |
