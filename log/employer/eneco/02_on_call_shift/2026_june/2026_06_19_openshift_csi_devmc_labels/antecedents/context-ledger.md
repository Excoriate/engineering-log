---
task_id: 2026-06-19-openshift-csi-devmc-labels
agent: codex
status: review
summary: Context ledger for Dev-MC OpenShift CSI inline volume Pod Security Admission RCA.
---

# Context Ledger

| Context item | Role | Evidence | Confidence | Open questions |
| --- | --- | --- | --- | --- |
| Dev-MC OpenShift cluster | Runtime environment where issue was reported. | `oc whoami --show-server` observed `https://api.eneco-vpp-dev.ceap.nl:6443`. | A1 | None for Dev-MC identity. |
| OpenShift 4.20.16 | Admission behavior version. | `oc version` observed server `4.20.16`. | A1 | None for Dev-MC version. |
| Namespace `eneco-vpp` | Workload namespace. | `oc describe ns eneco-vpp`. | A1 | Whether privileged workaround remains after durable fix. |
| AssetPlanning | Affected app Deployment. | `oc describe deploy assetplanning-eneco-vpp -n eneco-vpp`. | A1 | Whether business behavior was affected beyond rollout. |
| FleetOptimizer solver | Affected app Deployment. | `oc describe deploy fleetoptimizersolver-eneco-vpp -n eneco-vpp`. | A1 | Whether gateway or other components share same condition. |
| ArgoCD | GitOps and health reporting surface. | Browser screenshot and Argo status in live context. | A2 | Exact app source paths not inspected. |
| Deployment controller | Kubernetes controller trying to create ReplicaSet/pods. | Deployment condition `ReplicaSetCreateError`. | A1 | None. |
| API admission | Rejected pod creation request. | Deployment events reported `forbidden`. | A1 | Audit log not queried. |
| Pod Security Admission | Namespace profile enforcement mechanism. | Red Hat docs and namespace labels. | A1-doc/A1 | Cluster-level PSA config not separately dumped. |
| Security Context Constraints | Independent OpenShift security mechanism. | Red Hat docs state SCC and PSA are independent. | A1-doc | Exact service account SCC bindings not needed for primary RCA. |
| Secrets Store CSI driver | Inline CSI volume driver used by workloads. | Pod templates and CSIDriver object. | A1 | Correct security classification requires CMC validation. |
| `CSIDriver/secrets-store.csi.k8s.io` | Cluster-scoped driver metadata object. | `oc describe csidriver secrets-store.csi.k8s.io`. | A1 | Exact GitOps manifest file not inspected. |
| CMC/platform | Likely owner of driver GitOps source. | Argo tracking annotation `cmc-secrets-store-csi-driver`. | A2 | Exact repo/PR owner must be confirmed by CMC. |
| ACC/PRD | Potentially affected future environments. | Team discussion screenshot. | A3 | Not checked in this RCA. |
