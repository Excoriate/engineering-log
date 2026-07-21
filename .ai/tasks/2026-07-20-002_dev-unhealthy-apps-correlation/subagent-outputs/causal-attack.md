---
task_id: 2026-07-20-002
agent: codex
status: complete
summary: "Causal adversarial review of the two DEV application degradations, bounded to screenshot-supplied facts and read-only discriminator recommendations."
---

# Attempted causal attack ledger

## Scope and evidence ceiling

- **KNOW (supplied screenshots):** `espmessageproducer-eneco-vpp` and `marketinteraction-eneco-vpp` are both `Synced` and `Degraded` in Argo CD.
- **KNOW (supplied screenshot):** an `espmessageproducer` pod created around 11:15 is in `ImagePullBackOff`; the registry response for `vppacra.azurecr.io/eneco-vpp/espmessageproducer:latest` says manifest tag `latest` was not found.
- **KNOW (reporter description):** the Argo CD replica increase ended earlier and appeared stable.
- **UNKNOWN:** the failing resource, exact event, and first-failure time for `marketinteraction`; Application operation history; workload owner-chain timestamps; registry/tag history; controller reconciliation history.
- No cluster, registry, CI/CD, or Argo CD access was performed. Screenshot state is not sufficient to certify a shared root cause.

## Pattern and falsifier

**Pattern:** a common top-level Argo health badge is a lossy symptom class, not a causal mechanism. Correlation requires either a common failing dependency, a common triggering operation, or aligned event/owner timelines.

**Recurrence class:** independent workload defects can become visible together when a shared observer refreshes; conversely, a shared reconciliation can expose different latent defects without being their direct failure mechanism.

**Global falsifier:** if the two apps show different first-failing resources/reasons, non-overlapping first-event times, different sync revisions, and no shared Application operation or workload recreation boundary, the shared-cause route is materially weakened. If both failures begin after the same reconcile/sync boundary or cite the same unavailable dependency, the unrelated route is weakened.

## Claims attacked

| Claim under attack | Attempted attack / plausible wrong mechanism | Cheapest live discriminator | Residual after current evidence |
|---|---|---|---|
| **C1: “The two unhealthy apps have the same root cause.”** | `Synced Degraded` only says desired manifests match while at least one child is unhealthy. Many unrelated pod, rollout, probe, job, and image failures collapse into that same badge. Only `espmessageproducer` has an evidenced child failure. | Open `marketinteraction`'s first red child and capture its exact `Reason`, `Message`, owner, and first warning timestamp; compare with the `espmessageproducer` pull event. | **Unsupported.** No failure mechanism for `marketinteraction` is in evidence, so causal equivalence cannot yet be tested.
| **C2: “The failures are unrelated.”** | A shared Application sync/reconcile, controller recovery, registry event, image-publishing failure, node event, or namespace policy change could affect both apps. Different leaf errors would not alone exclude a shared trigger. | Compare both Applications' `operationState`/sync history, revisions, first warning timestamps, and workload owner-chain creation times. Then check whether both reference an affected shared dependency. | **Plausible but unproven.** The missing tag explains one pod only; the second app remains an open causal variable.
| **C3: “The earlier Argo CD replica increase cannot be related because it ended stably.”** | Stable controller replicas rule out ongoing controller unavailability, not an earlier side effect. A leader handoff/watch re-establishment/full resync can cause pending drift or automated self-heal to be evaluated. If that reconciliation changes a Deployment template, runs a hook, or completes an interrupted sync, it can create a new workload pod; a new pod then exposes a pre-existing missing mutable tag. Reapplying an identical Deployment normally does **not** create a pod, so an operation/template/owner change is required for this route. | For the 11:15 pod, compare Pod → ReplicaSet → Deployment creation timestamps, UIDs, generations, deployment revision, and Application operation timestamps against the maintenance window. Inspect Argo controller logs only if the owner/application timeline shows a matching reconcile or sync. | **Indirect relation remains possible but has no evidence yet.** Mere temporal proximity, cache resync, or replica scaling is insufficient; the workload-creation bridge must be demonstrated.
| **C4: “The registry error is the complete root cause of `espmessageproducer`.”** | It is strong evidence for the pod's **proximal** failure mechanism: kubelet cannot resolve the exact image tag. It does not establish why `latest` is absent: never published, deleted, wrong repository/tag, failed promotion, or desired manifest pointing at the wrong mutable tag. | Confirm the exact image string and event on the failing pod; query repository/tag history and the image-publishing/promotion run for the desired revision and failure time. | **Proximal cause supported; upstream root cause unknown.** Do not claim “registry outage” from `manifest unknown`; that response is specific to the requested reference.
| **C5: “The same missing-image mechanism affects `marketinteraction`.”** | The second app may be degraded for an unrelated readiness, rollout, hook, secret/config, scheduling, or image error. The shared Argo status is not evidence for a shared image failure. | Capture the exact first red resource and event for `marketinteraction`; if it is an image-pull error, record the full image reference and registry response. | **No supporting evidence.** This claim must remain open until the second leaf error is observed.
| **C6: “The 11:15 pod creation was caused by the Argo maintenance.”** | Pod creation can instead follow a normal Deployment rollout, autoscaling, eviction, node drain, deletion, crash replacement, or independent sync. Timestamp adjacency is an alias unless the owner-chain/revision makes the failure follow an Argo operation. | Inspect Pod owner UID, ReplicaSet creation/revision, Deployment rollout history/events, and Application operation history at 11:15. | **Unproven.** A new pod is necessary for the missing mutable tag to surface, but the actor that caused replacement is unknown.

## Highest-information live checks, in order

1. **Second-app leaf failure:** exact `marketinteraction` red resource, `Reason`, `Message`, and first warning timestamp. This single observation separates same-image/shared-dependency from independent-failure classes.
2. **Cross-app time/revision alignment:** each Application's sync revision and operation start/finish time, plus first child warning. This separates shared Application operation from coincidence.
3. **11:15 owner-chain transport:** Pod → ReplicaSet → Deployment UIDs, creation times, generation/revision, and rollout events. The maintenance-related hypothesis requires the pod-creation event to follow a maintenance-linked sync/reconcile rather than an independent rollout/replacement.
4. **Artifact history:** whether `espmessageproducer:latest` existed before 11:15, when it was deleted/failed publication, and which pipeline/revision should have produced it. This distinguishes wrong desired reference from failed/removed artifact.
5. **Controller logs last:** inspect around the exact correlated timestamp only if checks 2–3 expose a controller/application operation. Broad log search first has lower information gain and high narrative-confounder risk.

## Decision boundary for the Slack answer

- **Safe now:** “For `espmessageproducer`, the observed pod is degraded because its configured `:latest` image cannot be resolved in ACR (`manifest unknown`). That is the immediate failure mechanism, not yet the upstream publishing cause.”
- **Not safe now:** “Both apps share this root cause,” “the replica maintenance caused it,” or “the replica maintenance is definitively unrelated.”
- **Promotion to ‘unrelated’:** `marketinteraction` has a different leaf failure and independent first-event/owner/revision timeline, with no shared Application operation or dependency event.
- **Promotion to ‘maintenance contributed’:** a maintenance-correlated Application operation/reconcile demonstrably created or changed the workload owner that produced the failing pod. Even then, maintenance is a **trigger/exposer**; the absent image tag remains the `espmessageproducer` failure mechanism.

## Attempted-attack result

- **Leader:** independent leaf failures or, at minimum, no demonstrated common mechanism.
- **Runner-up:** shared reconcile/rollout boundary exposed latent defects, including the missing mutable tag.
- **Evidence advantage:** the first route has a concrete failure mechanism for only one app; the second has a plausible bridge but no owner-chain or operation evidence.
- **Cheapest flip:** the exact `marketinteraction` child event plus both apps' first-event and operation timestamps.
- **Residual:** causal cross-check is **partial** until the second app's leaf error and the 11:15 pod owner chain are observed.

