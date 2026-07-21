---
task_id: 2026-07-20-002
agent: codex
status: confirmed
summary: Final scope for a read-only cross-plane causal investigation in DEV.
---

# Final requirements

The screenshots resolve the initial ambiguity enough to proceed: both applications are `Synced` and `Degraded`; one child pod explicitly reports `ImagePullBackOff` because registry tag `latest` is not found. The task is therefore to test whether both apps share that runtime mechanism and whether any evidence connects it to the Argo CD control-plane replica change.

## Verification strategy

- Identity: API server must be DEV before every evidence batch.
- Control plane: compare Argo CD workload desired/ready and pod restart state with the stable maintenance close.
- Desired state: capture Application sync/health/revision and the deployed workload image references.
- Runtime: capture waiting reason/message and events for both apps.
- Causality: maintenance relation requires a connecting mechanism, not timestamp proximity.
- Output: append a bounded finding to the DEV maintenance record and give the user a concise verdict.

No route-flipping question is needed before read-only probing because cluster state can determine both mechanisms; ownership of any separate application deployment can remain explicitly unknown.

