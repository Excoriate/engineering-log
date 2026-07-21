---
task_id: 2026-07-20-002
agent: codex
status: active
summary: Context universe for correlating two DEV application failures with the completed Argo CD replica maintenance.
---

# Context universe

## Decision target

Decide whether the two reported DEV application degradations share a causal mechanism with the Argo CD replica increase, merely overlap in time, or remain unresolved.

## Map delta first

- Updated from task `2026-07-20-001` rather than recreating the DEV Argo CD map.
- Repository status/history probes were blocked by local execution policy; no Git-state conclusion is inferred.
- New surfaces are the application specifications, workload pods/events, registry image references, and application sync/revision timestamps.

## System model

```text
Git/Helm desired image reference
          |
          v
Argo CD Application --syncs--> OpenShift workload --> Pod --> registry pull
          |                          |                  |
          |                          |                  +--> tag exists? image readable?
          |                          +--> readiness/events
          +--> Sync status / Health derived from child resources

Argo CD replica maintenance --> Argo CD control-plane pods
          |
          +--> could affect reconciliation availability/cadence
          +--> does not itself create a missing registry tag
```

The indirect feedback loop matters: a new desired image reference can be synced successfully, then the created pod fails its registry pull, so the Application becomes `Synced` and `Degraded` at the same time.

## Lane ledger

| Lane | Status | Route impact |
|---|---|---|
| DEV API/context identity | Selected; must be re-proven because prior ACC login changed shared kubeconfig | Wrong environment invalidates every observation. |
| Argo CD control-plane readiness/restarts/events | Selected | Shared instability would support a maintenance relation. |
| Application sync, health, revision, operation timestamps | Selected | Separates desired-state application changes from control-plane scaling. |
| Workload images, pods, conditions, events | Selected | Identifies the concrete failure mechanism. |
| Registry tag existence | Selected through Kubernetes pull events; direct registry API may be unavailable | `manifest unknown` is discriminating for a missing tag. |
| Prior Slack/incident context | Dispatched | May reveal an application deployment already known to users. |
| Repository desired-state history | Dispatched | May identify who/what introduced `:latest` and when. |
| Prior knowledge/vault | Dispatched | Checks recurrence without treating memory as current fact. |
| Mutation/fix | Blocked by scope | No sync, refresh, restart, patch, rollout, or image push. |

## Highest-information live probes

1. Prove DEV API and namespace.
2. List both Application objects with sync/health/revision/operation timestamps.
3. Inspect the two deployments/pods/images and recent namespace events.
4. Confirm Argo CD component desired/ready counts and restarts remain stable.

## Missing-angle question

Did the Argo CD replica work include any Git/Helm desired-state change or only the `ArgoCD` custom resource replica fields? If only control-plane replica fields changed, a workload image reference change requires a separate actor/change path.

