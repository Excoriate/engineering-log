---
task_id: 2026-07-20-001
agent: codex
status: active
summary: Evidence boundary for DEV close-out, ACC transfer, and first-principles teaching.
---

# Continuation evidence

## Decision target

Produce an ACC runbook and teaching syllabus that reuse the DEV evidence mechanism without treating DEV values, generic documentation, or a terminal tab label as ACC runtime proof.

## Live installed facts

- DEV before: server/repo/standalone Redis/Dex Deployments and controller StatefulSet each at one; HA off; server autoscale off; no HPA.
- DEV observed after: server three, repo two, Redis HAProxy three, Redis/Sentinel StatefulSet three, controller one, Dex one; twelve observed pods Ready/Running, zero restarts at final sample.
- DEV transient: controller CPU `24m -> 733m -> 109m`; `solver` `Synced Healthy -> Synced Progressing -> Synced Healthy`; no namespace events.
- ACC July 20 baseline: same single-replica pre-change shape; HA off; server autoscale off; no HPA; Dex/repo/server restart baselines already one.
- ACC resource baseline: controller `13m/2140Mi`, repo `1m/285Mi`, server `7m/147Mi`, Redis `2m/11Mi`, Dex `1m/161Mi`; hosting nodes at 7–8% CPU and 37–52% memory.
- Shared-state finding: ACC login changed the active kubeconfig used by a DEV-labelled terminal. The mixed sample was rejected.

## Primary documentation semantics

- Argo CD architecture: server exposes API/UI/auth/RBAC; repo server clones/caches repositories and generates manifests; application controller compares live and Git-desired state.
- Argo CD HA: Argo CD is largely stateless; Redis is a disposable cache; HA adds containers and Redis HA. Server is stateless and can be replicated; Dex uses an in-memory database; Redis HA expects three servers/sentinels.
- Kubernetes resources: scheduler placement is based on resource requests, not current `top` use; limits are enforced runtime ceilings; Pod request/limit is the sum across containers.
- Kubernetes networking: Service gives a stable access abstraction over changing Pods; EndpointSlice represents the actual backing endpoints and is preferred because legacy Endpoints is deprecated in Kubernetes 1.33.
- Kubernetes workloads: Deployment manages interchangeable Pods; StatefulSet provides stable identity and ordering.

## Proof classification

| Claim type | Highest available proof | Forbidden promotion |
|---|---|---|
| DEV/ACC counts, resources, nodes, applications | live API observation | cannot generalize beyond capture time |
| Argo CD/Kubernetes mechanism | primary-source specification | cannot claim installed configuration from docs |
| CMC actor intent | completion/window correlation only | cannot call actor-confirmed without change record/audit evidence |
| Business outcome | Argo application status only | cannot claim end-user transactions were tested |
| ACC future result | not yet observed | cannot inherit DEV outcome |

## Lane ledger

| Lane | Status | Route impact |
|---|---|---|
| DEV final Kubernetes/Argo evidence | selected | closes technical watch with bounded stable verdict |
| ACC baseline | selected | supplies T-minus comparison and historical deltas |
| CMC ACC target specification | blocked/pending | expected DEV-equivalent topology remains a hypothesis |
| Node allocatable/requested headroom | unverified | `top` cannot prove scheduler fit; events/actual placement remain mandatory |
| EndpointSlice in ACC | not yet executed | command remains Wednesday proof work, not preparation fact |
| Business transaction checks | out of supplied scope/capability | Argo application status remains an outcome proxy |
| Git history map | blocked by local policy | direct task artifacts and live evidence drive continuation |

## Missing-angle question

What observation would make the copied DEV expectation wrong? An authoritative CMC ACC target that names different counts/components, or live ACC CR/workload deltas that produce a different topology. Either result changes expected counts but not the identity and reconciliation evidence ladder.

## Route-flip falsifier

Immediately before an accepted ACC block, run `oc whoami --show-server`.

- If the output is exactly `https://api.eneco-vpp-acc.ceap.nl:6443`, continue with the ACC probes.
- If it differs, reject every value in that block and restore the intended context; do not reinterpret the output based on the tab title.

## Transition

The continuation evidence falsified literal “same maintenance means same commands and targets.” The transferable object is the reasoning ladder; environment identity, target counts, restart baselines, placement, and topology must be rebound. The trap caught was familiarity plus UI-location trust.
