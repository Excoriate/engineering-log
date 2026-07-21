---
task_id: 2026-07-20-002
agent: codex
status: active
summary: Read-only investigation of two degraded DEV applications and their causal relation to the completed Argo CD replica maintenance.
---

# Initial requirements

- Pause documentation work.
- Investigate `espmessageproducer-eneco-vpp` and `marketinteraction-eneco-vpp` in DEV.
- Use only read-only probes; do not sync, refresh, restart, scale, patch, or delete.
- Separate three truth planes: Argo CD control-plane health, desired application state, and OpenShift workload/runtime state.
- Test at least these hypotheses:
  - missing or invalid registry image tag;
  - incorrect desired state or reconciliation caused by the Argo CD maintenance;
  - independent application change coinciding with maintenance.
- Record exact observations and timestamps in the existing DEV maintenance findings ledger when relevant.
- Do not infer CMC causation from temporal proximity.

## Acceptance

The result must identify both applications' failure mechanisms, compare them with the maintenance timeline and Argo CD health, and classify relatedness as supported, unsupported, or unresolved with a named missing probe.

