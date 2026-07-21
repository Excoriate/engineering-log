---
task_id: 2026-07-20-001
agent: codex
status: active
summary: Smallest sufficient context universe for live DEV Argo CD replica-maintenance proof.
---

# Context universe

## Decision target

Determine which read-only observations let a new SRE prove, before/during/after CMC's replica change, that the intended DEV Argo CD instance changed as expected without hiding unavailable replicas, unschedulable pods, resource pressure, or application degradation.

## Map Delta First

- Prior task map search: no task-specific predecessor found before this task was claimed.
- Repository history/status probes: blocked by the local execution policy; no Git conclusion is inferred from that block.
- Existing target artifacts: all three user-facing Markdown files existed but were empty. They are destinations, not evidence.
- Project harness and nearby operational lessons were read before planning.

## System model

```text
CMC changes ArgoCD desired state
          |
          v
Argo CD operator -> Deployment/StatefulSet desired/current/ready/available
          |                         |
          |                         v
          |                    Pods -> scheduler -> Nodes
          |                                      |  |
          v                                      |  +-> CPU/memory/pressure/events
Applications -> Sync/Health                       +----> indirect effect on other workloads

OpenShift CLI and Lens are two views of the API; Lens is not a second source of truth.
```

Feedback loop: the operator keeps reconciling the ArgoCD custom resource into workloads. If a new pod cannot schedule or start, desired replicas may rise while ready/available replicas lag; the lag, events, pod state, and node headroom explain why.

## Lane ledger

| Lane | Surface | Status | Why it is needed |
|---|---|---|---|
| Environment identity | `oc whoami`, server, project, current context | Selected; live-proven | Prevents correct commands on the wrong cluster. |
| Desired configuration | `ArgoCD/eneco-vpp` in `eneco-vpp-argocd` | Selected; resource discovered | Establishes declared replicas, autoscaling, and resource configuration. |
| Effective workload | Deployments/StatefulSets | Selected | Separates declared desire from controller reality. |
| Replica realization | Pods and placement | Selected | Shows actual pod count, readiness, restarts, age, and nodes. |
| Capacity | pod/node metrics, requests/limits, allocatable | Selected | Explains the resource consequence of added replicas. |
| Failure evidence | conditions and events | Selected | Exposes Pending, scheduling, pressure, OOM, probe, and image failures. |
| Argo CD service outcome | Applications health/sync and component availability | Selected | Prevents infrastructure-green/application-red false success. |
| Visual client | Lens/Freelens via PowerShell `cmcfreelens dev` and the fresh Windows-kubeconfig catalog row | Selected, behaviorally connected | Secondary operator view requested by the user; duplicate stale rows remain a false-negative trap. |
| Operator logs | GitOps operator logs | Skipped by default | Higher noise and privilege cost; activate only when desired state does not reconcile. |
| Prometheus queries | direct cluster monitoring endpoint | Deferred | Namespace enforcement can make values incomplete; CLI resource/metrics views are primary proof. |
| CMC change record | external ticket/runbook/SLO | Blocked/not supplied | Exact planned target replica count and contractual thresholds are not yet available. |

## Live facts established so far

- Intended API: `https://api.eneco-vpp-dev.ceap.nl:6443`.
- Intended project before target selection: `eneco-vpp`.
- CLI/server: `oc` client 4.8.11; OpenShift server 4.20.16; Kubernetes 1.33.8.
- Argo CD instances visible: `cmc-sre-gitops/sre-gitops`, `eneco-vpp-argocd/eneco-vpp`, and `openshift-gitops/openshift-gitops`.
- Maintenance target selected from the user's VPP DEV scope: namespace `eneco-vpp-argocd`, ArgoCD instance `eneco-vpp`.
- GitOps APIs are discoverable through `argoproj.io`.

These are source/runtime observations. The current replica/resource fields and effective workload counts remain pending live capture.

## Cross-surface coherence checks

1. ArgoCD CR desired values must be compared with workload `DESIRED/CURRENT/READY/AVAILABLE`.
2. Workload totals must reconcile with actual pods; differences require rollout or failure evidence.
3. Each Argo CD pod's node must exist in the node-capacity/metrics view.
4. A change is not accepted solely because the CR or desired count changed; readiness and service outcome must converge.
5. Lens must show the same DEV server/namespace/resources; catalog presence alone is insufficient.

## Highest-information fact still sought

The current `ArgoCD/eneco-vpp` replica/autoscaling/resource configuration and its realized workload counts. This separates a literal fixed-replica change from HPA-controlled behavior and makes the expected CPU/memory increment computable.

## Hypothesis impact

- H1 remains live: the CR exists and is operator-managed, but the exact fields have not yet been read.
- H2 remains a necessary companion, not a fallback: workloads provide effective-state truth even if the CR is readable.
- H3 remains live: node metrics availability has not yet been executed on the target.
- H4 remains live: the DEV Lens catalog/view is not yet configured and behaviorally verified.

## Missing-angle question and route-flip falsifier

Missing angle: does CMC intend to scale the server, repo server, application controller, ApplicationSet controller, or more than one component?

No user clarification is required yet because live configuration and workload names can identify all components, and the documentation can provide component-specific probes. If the change target remains unstated when monitoring begins, every Argo CD component will be monitored; the first observed desired-count delta identifies the changed component. If an HPA is enabled, the route flips from comparing a literal replica field to comparing HPA desired/current values and bounds.

## Context sufficiency

The selected lanes are enough to build a read-only proof ladder. The missing CMC target and contractual thresholds are explicitly blocked rather than guessed. The next route-changing evidence comes from live CR/workload/HPA/metrics probes, not more repository reading.
