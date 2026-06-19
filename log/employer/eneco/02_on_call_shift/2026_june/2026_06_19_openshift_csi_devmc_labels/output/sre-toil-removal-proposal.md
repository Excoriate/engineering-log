---
task_id: 2026-06-19-openshift-csi-devmc-labels
agent: codex
status: review
summary: Toil-removal proposal for preventing recurrence of unlabeled CSI ephemeral driver admission failures.
---

# SRE Toil Removal Proposal - CSI Inline Volume Pod Security Admission Guardrails

## Toil Removal Knowledge Contract

The incident required manual diagnosis across ArgoCD, Deployment events, namespace labels, and CSIDriver metadata. The same root cause can recur in any namespace that uses inline CSI volumes from an unclassified CSI driver while the namespace is below privileged.

## RCA Evidence Base

This proposal is based on the RCA evidence that an unlabeled ephemeral CSIDriver caused OpenShift to treat inline Secrets Store CSI volumes as privileged, while multiple namespaces may use the same driver. The failure mode is detectable before rollout by combining CSIDriver profile state, workload pod-template scans, namespace security labels, and recent failed-create events.

## Options Considered

| Control | Owner | What it prevents | Implementation idea |
| --- | --- | --- | --- |
| CSIDriver profile policy | CMC/platform | Unlabeled ephemeral CSI drivers defaulting to privileged unexpectedly. | CI or admission check requiring `security.openshift.io/csi-ephemeral-volume-profile` on any CSIDriver with `volumeLifecycleModes` containing `Ephemeral`. |
| Workload recurrence scanner | SRE/platform | Hidden workloads that will fail on next rollout. | Nightly read-only scan for pod templates using `secrets-store.csi.k8s.io`, joined with namespace pod security labels and CSIDriver profile. |
| Argo event enrichment | Platform observability | Slow triage of Argo Progressing states. | Alert/runbook that maps `ReplicaSetCreateError` plus `forbidden` to admission-policy investigation. |
| Upgrade preflight | Release/platform | Discovering the mismatch only after OpenShift upgrade or rollout. | Before cluster upgrades or app rollout waves, run the CSIDriver/namespace/workload scan in Dev, ACC, and PRD. |
| Namespace exception register | Security/platform | Permanent invisible privileged namespaces. | Track every namespace with `pod-security.kubernetes.io/enforce=privileged`, owner, reason, expiry, and replacement plan. |

## Recommendation

Add the profile label to the CMC-managed `CSIDriver/secrets-store.csi.k8s.io` manifest after validation:

```yaml
metadata:
  labels:
    security.openshift.io/csi-ephemeral-volume-profile: restricted
```

Acceptance criteria:

| Criterion | Proof |
| --- | --- |
| Driver classification is in GitOps. | CMC PR includes the label in source of truth. |
| Live cluster has the label. | `oc describe csidriver secrets-store.csi.k8s.io`. |
| Affected workloads roll out. | `oc rollout status` for AssetPlanning and FleetOptimizer solver. |
| Namespace privileged workaround has a decision. | Either removed after validation or documented as accepted security policy. |
| Other environments assessed. | Scan output or tickets for ACC/PRD. |

## Suggested Read-Only Scanner

```bash
#!/usr/bin/env bash
set -euo pipefail

# WHY: Identify every workload that declares the same inline CSI driver in a pod template.
oc get deploy -A -o json | jq -r '
  .items[]
  | .metadata as $m
  | [(.spec.template.spec.volumes // [])[]?.csi?.driver]
  | unique
  | select(index("secrets-store.csi.k8s.io"))
  | "\($m.namespace)\t\($m.name)\tsecrets-store.csi.k8s.io"
'

# WHY: Identify whether the driver has the OpenShift admission profile label.
oc describe csidriver secrets-store.csi.k8s.io
```

The first version can be manual. The durable version should run as a scheduled platform check and create a ticket or alert when a namespace/workload is at risk.

## Systemic Rationale

Without the control, every incident starts from a vague Argo symptom and requires a human to rediscover the same admission path. With the control, the platform knows ahead of time: "these namespaces use inline Secrets Store CSI; this driver has or lacks the required profile; these rollouts are safe or need remediation." That turns emergency reasoning into a preflight report.

## Non-Goals

This proposal does not automate namespace privilege changes, does not remove CMC validation of the correct driver profile, and does not claim ACC/PRD are already impacted without running the scans there. The smallest useful automation is a read-only detector that opens a ticket before the next rollout fails.
