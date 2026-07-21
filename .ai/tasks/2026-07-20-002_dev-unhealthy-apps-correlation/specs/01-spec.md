---
task_id: 2026-07-20-002
agent: codex
status: active
summary: Probe and evidence specification for the DEV application correlation investigation.
---

# Specification

- Commands are one-line, read-only, and avoid secrets/raw kubeconfig.
- Capture: timestamp, DEV API, Application sync/health/revision/operation time, deployment image, pod waiting reason/message, recent Warning events, Argo CD workload readiness/restarts.
- Never run `oc apply`, `oc patch`, `oc scale`, `oc rollout restart`, `argocd app sync`, or UI Sync/Refresh/Delete.
- The finding must distinguish:
  - immediate failure mechanism;
  - contributing desired-state change;
  - maintenance correlation;
  - actor/intent attribution.
- A claim of “not related” is too strong unless the intended maintenance diff is available. Prefer “no evidence of a causal connection in the observed planes” plus the remaining falsifier.

