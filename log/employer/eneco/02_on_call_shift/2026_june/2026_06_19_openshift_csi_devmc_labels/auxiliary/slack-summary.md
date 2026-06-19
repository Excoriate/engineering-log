---
task_id: 2026-06-19-openshift-csi-devmc-labels
agent: codex
status: review
summary: Slack-ready explanation for CMC and on-call discussion.
---

# Slack Summary Drafts

## Short CMC Update

Root cause looks confirmed on Dev-MC: new AssetPlanning/FleetOptimizer pods were denied at OpenShift admission, not failing inside the app. The pod templates use inline CSI volumes from `secrets-store.csi.k8s.io`; the cluster `CSIDriver/secrets-store.csi.k8s.io` had `Volume Lifecycle Modes: Ephemeral` but no `security.openshift.io/csi-ephemeral-volume-profile` label, so OpenShift treated the driver as requiring `privileged` for this admission path. `eneco-vpp` was lower than privileged, so Deployment rollout failed with `ReplicaSetCreateError` and Argo stayed Progressing/Sync failed.

The namespace workaround `pod-security.kubernetes.io/enforce=privileged` explains why it is unblocked now, but it is broader than the root cause. Preferred durable fix: CMC should classify the CSIDriver in GitOps, likely `security.openshift.io/csi-ephemeral-volume-profile=restricted` if validated safe for this driver, and then reassess whether the namespace still needs privileged enforce.

## Answer To "Should It Be Privileged Or Restricted?"

For emergency unblock, privileged on the namespace is the working mitigation because the unlabeled CSI driver is treated as privileged. For the intended steady state, we should prefer restricted namespaces and classify the CSI driver itself, if CMC validates the Secrets Store CSI driver as restricted-compatible. In other words: privileged is the workaround location; restricted is the desired namespace posture; the durable decision belongs on the CSIDriver profile label.

## Answer To "How Could This Have Happened?"

No repo needed to explicitly set `enforce=restricted` for this to happen. OpenShift CSI Volume Admission has defaults: an inline ephemeral CSI driver with no `csi-ephemeral-volume-profile` label is treated as privileged, and namespaces below privileged cannot use it. Existing pods kept running because admission is checked when a pod is created. The issue surfaced when Argo/Deployment tried to create replacement pods after the platform/admission behavior was in place.

## ACC/PRD Risk Statement

ACC/PRD are at risk if all of these are true there: OpenShift has the same CSI admission behavior, `CSIDriver/secrets-store.csi.k8s.io` is unlabeled, workloads use it as an inline CSI volume, and their namespaces are lower than privileged. We should not claim they are affected until the same `oc describe csidriver`, namespace label checks, and workload scans are run there.
