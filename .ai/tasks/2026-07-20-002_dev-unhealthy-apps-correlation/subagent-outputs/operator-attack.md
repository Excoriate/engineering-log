---
task_id: 2026-07-20-002
agent: codex
role: operator-failure-path-adversary
timestamp: 2026-07-20T11:48:25+02:00
status: complete
summary: |
  The supplied screenshots establish one immediate workload failure, not the relationship between both applications or the preceding Argo CD maintenance. `espmessageproducer-eneco-vpp` cannot pull an image because `latest` is absent, while the failure mechanism for `marketinteraction-eneco-vpp` remains unobserved. A maintenance link needs a connecting change or event chain; current Argo health, matching timestamps, or two red tiles are not sufficient. This sidecar defines the read-only evidence and bounded Slack wording needed to avoid both false attribution and false exoneration.
key_findings:
  - finding_1: Synced plus Degraded is consistent with successfully applied desired state whose workload cannot become healthy.
  - finding_2: The missing latest tag is a confirmed proximate cause for one pod, but actor, desired-state origin, and incident correlation remain unproven.
  - finding_3: The most important alternative is maintenance-triggered pod replacement or re-pull exposing a pre-existing invalid mutable tag.
---

# Operator failure-path attack

## Attack target and evidence ceiling

The claim under attack is: “the two DEV application failures are unrelated to each other and to the Argo CD replica maintenance.” That is plausible, but the supplied screenshots do not prove it.

| Statement | State | Operational meaning |
|---|---|---|
| Both Applications display `Synced` and `Degraded`. | **Known from supplied screenshots; not yet live-reprobed** | Argo CD reports desired state applied while at least one managed resource is unhealthy. `Synced` is not a runtime-health verdict. |
| An `espmessageproducer-eneco-vpp` pod is in `ImagePullBackOff`; the registry reports tag `latest` not found. | **Known from supplied screenshots; not yet live-reprobed** | The pod cannot start because its resolved image reference is unavailable at pull time. This is the proximate failure mechanism. |
| The registry response means Argo CD scaling created the bad image reference. | **Unsupported** | A registry pull error says nothing about who wrote the workload image field. |
| `marketinteraction-eneco-vpp` has the same image failure. | **Unknown** | Its resource tree, pod state, waiting message, events, images, and logs have not been supplied. |
| The two application failures are unrelated. | **Inferred, low confidence** | There is one concrete leaf cause but not yet a second mechanism or a cross-timeline comparison. |
| The maintenance is unrelated. | **Inferred, low confidence** | A direct causal mechanism is absent from the screenshots, but a trigger/exposure path has not been eliminated. |

Current correlation confidence is below the 70% diagnosis-posting threshold. The safe statement is “no causal connection is demonstrated yet,” not “we proved there is no connection.”

## Competing failure hypotheses

### H1 — independent application failures

`espmessageproducer` references an unavailable image tag; `marketinteraction` has a separate runtime or desired-state defect.

- Supporting observation: one explicit registry-manifest failure already exists.
- Falsified by: both apps resolving to the same newly introduced image policy/revision, the same registry publication failure, a runtime dependency chain from `espmessageproducer` to `marketinteraction`, or a shared Argo operation that changed/recreated both workloads.
- Required discriminator: compare both Applications’ revisions and reconcile times, resource trees, workload images, pod creation/owner chains, waiting messages, and Warning events.

### H2 — shared desired-state or registry publication failure

A common Git/Helm change caused both workloads to reference unavailable images, or a shared image-publication/retention action removed tags they both need.

- Supporting observation if true: aligned revision/operation timestamps plus the same changed image source, registry/repository, tag policy, or image-publishing pipeline.
- Falsified by: distinct revisions and rollout times plus different concrete pod failure reasons with no runtime dependency.
- Important distinction: two failures in the same registry are not automatically related. `manifest unknown`/tag-not-found, `unauthorized`, DNS/TLS, rate limit, and pull-secret failures are different mechanisms.

### H3 — maintenance-triggered exposure, but not maintenance-created root cause

The Argo CD controller rollout/reconciliation or coincident cluster rescheduling recreated pods. Existing pods may have been running a cached image, while the new pods attempted to pull mutable `:latest` after that tag had disappeared.

- Supporting observation if true: no Application revision or pod-template change; pod creation/replacement follows the controller maintenance; old and new pods have different `imageID`/node placement; `imagePullPolicy` is `Always` or the new node lacks the cached image.
- Falsified by: the failing pod rollout started before maintenance, or a separate application revision/template generation created it after maintenance with no controller correlation.
- Classification if supported: maintenance is a **trigger/exposure event**, not the root cause. The root defect is the unpinned/unavailable image reference or broken publication process.

### H4 — the applications are related through a runtime dependency

`marketinteraction` may be unhealthy because `espmessageproducer` is unavailable, even if its own pod error is not `ImagePullBackOff`.

- Supporting observation if true: `marketinteraction` readiness/log errors name the producer’s Service, route, queue/topic, or endpoint and begin after the producer becomes unavailable.
- Falsified by: `marketinteraction` has an independent local failure before the producer outage or succeeds against the dependency while remaining unhealthy for another reason.
- Required discriminator: current/previous container logs, readiness condition messages, Service/EndpointSlice state, and ordered timestamps—not merely application health badges.

## Mechanism trace

```text
Observed user symptom
  two Argo CD Applications are Synced + Degraded
            |
            +--> espmessageproducer pod cannot pull image
            |       proximate cause: registry has no requested `latest` manifest
            |       enabling condition: desired workload asks for that image/tag
            |       root cause candidates: bad Git/Helm value, failed image publish,
            |                              tag deletion/retention, wrong repository path
            |
            +--> marketinteraction degradation
                    proximate cause: UNKNOWN until pod/resource evidence is captured

Argo CD replica maintenance
  can change reconciliation availability/timing or recreate controller pods
  cannot itself delete a registry tag
  could still expose a latent bad image by causing reconcile/pod replacement
```

This distinction is load-bearing: “Argo did not create the missing tag” does not eliminate “the maintenance triggered a fresh pull that exposed the missing tag.”

## False-green and false-correlation cases

| Looks reassuring or correlated | Why it can still be wrong | Discriminating evidence |
|---|---|---|
| Application is `Synced`. | Argo successfully applied a Deployment that references a nonexistent image. This exact state naturally becomes `Synced` + `Degraded`. | Application resource tree + Deployment image + pod waiting message. |
| Argo CD replicas are currently Ready. | Current readiness does not exclude a transient controller/repo-server outage, backlog, or forced reconciliation during maintenance. | Pod restart/creation times, Warning events, controller logs, and maintenance start/end timestamps. |
| Maintenance was closed stable. | Stable close proves recovery of the control plane, not absence of downstream workload effects. | Compare application reconcile/operation times and pod replacement times with the maintenance window. |
| The two apps turned red at roughly the same time. | A common Argo poll/reconcile interval or dashboard refresh can align symptoms without a shared cause. | First failing event timestamps and each app’s change/revision/owner chain. |
| The two apps use the same registry. | Shared hostname is not a mechanism. One repository/tag can be absent while another has auth, TLS, rate-limit, or application-start failures. | Exact image strings and exact pull-event reasons/messages for every failing container. |
| `latest` is present now. | `latest` is mutable; the tag may have been absent during the failure and republished later. | Timestamped pull events plus current/previous `imageID` digests and registry publication history. |
| Some pods using `latest` are still Running. | Nodes can run a cached digest while new/replaced pods fail to pull the same mutable tag, creating a split-brain false green. | Per-pod node, creation time, requested image, resolved `imageID`, and `imagePullPolicy`. |
| Both apps have different immediate errors. | One broad desired-state change can produce two leaf symptoms, or one app can fail downstream because the other is unavailable. | Git/Helm revision comparison and dependency-specific logs/readiness failures. |
| No recent Warning events exist. | Events expire and are aggregated; absence after retention is not evidence of absence. | Controller/workload logs and durable maintenance/audit records; mark the historical lane unresolved if gone. |
| The current Application object did not change generation. | Pods can be replaced by node drain/eviction/controller action without an Application spec change. | Deployment/ReplicaSet/pod UIDs, owner references, creation timestamps, and events. |
| `ImagePullBackOff` names `latest` as missing. | That proves pull failure, not whether the wrong repository path or wrong environment values produced the request. | Exact workload image field, Application source revision, and desired-state diff. |
| Dashboard health becomes green without intervention. | A mutable tag can be republished, hiding the publication race while leaving the unsafe `latest` contract in place. | Digest-pinned desired state and publisher history; current green is recovery, not root-cause proof. |

## Exact read-only `oc` evidence needed

### Execution boundary

These commands must run inside the CMC AVD after the operator has established the DEV OpenShift context. They are prepared evidence probes only; none was executed by this adversary. Capture command output with timestamps and keep the namespace/application identity attached to every result.

Allowed verbs here are `oc get`, `oc describe`, `oc logs`, and `oc rollout history`. Do **not** run Sync, Refresh/Hard Refresh, Restart, Rollout Restart, Scale, Patch, Apply, Delete, Prune, Exec, Rsh, Debug, or Port Forward. `oc exec` is excluded because the executed process can mutate application state even if the intended command appears observational.

### Batch 0 — prove DEV identity before trusting any evidence

```bash
date -Iseconds
oc whoami
oc whoami --show-server
oc get infrastructure cluster -o jsonpath='{.status.infrastructureName}{"\t"}{.status.platformStatus.type}{"\n"}'
oc get clusterversion version -o jsonpath='{.spec.clusterID}{"\t"}{.status.desired.version}{"\n"}'
```

Reject the entire batch if the API server/infrastructure identity is not the known DEV cluster. Do not infer environment from the current project name.

### Batch 1 — resolve both Application and destination namespaces; capture desired-state timing

Run in a POSIX shell inside the AVD. This block contains no unresolved resource placeholders; it discovers the namespaces from the named Application objects.

```bash
set -eu
for app_name in espmessageproducer-eneco-vpp marketinteraction-eneco-vpp; do
  argocd_ns="$(oc get applications.argoproj.io -A --no-headers -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name' | awk -v wanted="$app_name" '$2 == wanted {print $1}')"
  if [ -z "$argocd_ns" ]; then
    printf 'APPLICATION_NOT_FOUND\t%s\n' "$app_name"
    continue
  fi
  work_ns="$(oc -n "$argocd_ns" get applications.argoproj.io "$app_name" -o jsonpath='{.spec.destination.namespace}')"
  printf 'APP_IDENTITY\t%s\t%s\t%s\n' "$argocd_ns" "$app_name" "$work_ns"
  oc -n "$argocd_ns" get applications.argoproj.io "$app_name" -o custom-columns='NAME:.metadata.name,UID:.metadata.uid,GENERATION:.metadata.generation,CREATED:.metadata.creationTimestamp,PROJECT:.spec.project,DEST_SERVER:.spec.destination.server,DEST_NS:.spec.destination.namespace,SOURCE_REPO:.spec.source.repoURL,SOURCE_TARGET:.spec.source.targetRevision,SOURCE_REPOS:.spec.sources[*].repoURL,SOURCE_TARGETS:.spec.sources[*].targetRevision,SYNC:.status.sync.status,HEALTH:.status.health.status,SYNC_REVISION:.status.sync.revision,SYNC_REVISIONS:.status.sync.revisions[*],RECONCILED:.status.reconciledAt,OP_STARTED:.status.operationState.startedAt,OP_FINISHED:.status.operationState.finishedAt,OP_PHASE:.status.operationState.phase,INITIATOR:.status.operationState.operation.initiatedBy.username'
  oc -n "$argocd_ns" get applications.argoproj.io "$app_name" -o jsonpath='{range .status.conditions[*]}{.lastTransitionTime}{"\t"}{.type}{"\t"}{.message}{"\n"}{end}'
  oc -n "$argocd_ns" get applications.argoproj.io "$app_name" -o jsonpath='{range .metadata.managedFields[*]}{.time}{"\t"}{.manager}{"\t"}{.operation}{"\t"}{.subresource}{"\n"}{end}'
  oc -n "$argocd_ns" get applications.argoproj.io "$app_name" -o jsonpath='{range .status.resources[*]}{.kind}{"\t"}{.namespace}{"\t"}{.name}{"\t"}{.status}{"\t"}{.health.status}{"\t"}{.health.message}{"\n"}{end}'
done
```

What this discriminates:

- Same revision/time is a lead, not proof; inspect the actual desired-state diff.
- Different revisions, operation times, and unhealthy resource kinds strongly support separate change paths.
- Empty destination namespaces, duplicate Application names, or unresolvable identity block the conclusion rather than inviting guessed namespaces.

### Batch 2 — capture requested images, pull policy, actual digest, pod ownership, and events

This block resolves each destination namespace again and lists the evidence needed to distinguish missing tag, wrong repo, auth, cached-image split brain, readiness failure, crash, OOM, and runtime dependency.

```bash
set -eu
for app_name in espmessageproducer-eneco-vpp marketinteraction-eneco-vpp; do
  argocd_ns="$(oc get applications.argoproj.io -A --no-headers -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name' | awk -v wanted="$app_name" '$2 == wanted {print $1}')"
  work_ns="$(oc -n "$argocd_ns" get applications.argoproj.io "$app_name" -o jsonpath='{.spec.destination.namespace}')"
  printf 'WORKLOAD_NAMESPACE\t%s\t%s\n' "$app_name" "$work_ns"
  oc -n "$work_ns" get deployment.apps,statefulset.apps,daemonset.apps -o jsonpath='{range .items[*]}{.kind}{"\t"}{.metadata.name}{"\t"}{.metadata.generation}{"\t"}{.status.observedGeneration}{"\t"}{.metadata.creationTimestamp}{"\t"}{range .spec.template.spec.initContainers[*]}init:{.name}={.image}[{.imagePullPolicy}]{","}{end}{range .spec.template.spec.containers[*]}container:{.name}={.image}[{.imagePullPolicy}]{","}{end}{"\t"}{range .spec.template.spec.imagePullSecrets[*]}{.name}{","}{end}{"\n"}{end}'
  oc -n "$work_ns" get pods -o custom-columns='POD:.metadata.name,UID:.metadata.uid,CREATED:.metadata.creationTimestamp,NODE:.spec.nodeName,PHASE:.status.phase,READY:.status.containerStatuses[*].ready,RESTARTS:.status.containerStatuses[*].restartCount,OWNER_KIND:.metadata.ownerReferences[0].kind,OWNER_NAME:.metadata.ownerReferences[0].name,WAITING_REASON:.status.containerStatuses[*].state.waiting.reason,WAITING_MESSAGE:.status.containerStatuses[*].state.waiting.message,TERMINATED_REASON:.status.containerStatuses[*].lastState.terminated.reason,EXIT_CODE:.status.containerStatuses[*].lastState.terminated.exitCode'
  oc -n "$work_ns" get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .spec.initContainers[*]}init:{.name}={.image},{end}{range .spec.containers[*]}container:{.name}={.image},{end}{"\t"}{range .status.initContainerStatuses[*]}init:{.name}={.imageID},{end}{range .status.containerStatuses[*]}container:{.name}={.imageID},{end}{"\n"}{end}'
  oc -n "$work_ns" get events --sort-by='.metadata.creationTimestamp' -o custom-columns='CREATED:.metadata.creationTimestamp,LAST:.lastTimestamp,TYPE:.type,REASON:.reason,OBJECT_KIND:.involvedObject.kind,OBJECT_NAME:.involvedObject.name,COUNT:.count,MESSAGE:.message'
done
```

Interpret the exact registry message; do not flatten it to “pull failed”:

- `manifest unknown`, `not found`, or missing tag: requested repository/tag is absent at that timestamp.
- `unauthorized`, `denied`, or secret lookup error: authentication/pull-secret path.
- DNS, TLS, timeout, rate limit, or connection errors: registry/network availability path.
- Correct image pulled but container exits, OOMs, or fails readiness: application/runtime path, not image retrieval.

### Batch 3 — capture workload detail and logs for the unhealthy resources found in Batch 1/2

For each exact unhealthy resource name emitted by the Application resource tree, run the matching read-only commands. Substitution is intentionally blocked until Batch 1 has resolved the identifiers; do not guess them.

```bash
oc -n <RESOLVED_DESTINATION_NAMESPACE> describe deployment.apps/<RESOLVED_DEPLOYMENT_NAME>
oc -n <RESOLVED_DESTINATION_NAMESPACE> rollout history deployment.apps/<RESOLVED_DEPLOYMENT_NAME>
oc -n <RESOLVED_DESTINATION_NAMESPACE> describe pod/<RESOLVED_POD_NAME>
oc -n <RESOLVED_DESTINATION_NAMESPACE> logs pod/<RESOLVED_POD_NAME> --all-containers --tail=200 --timestamps
oc -n <RESOLVED_DESTINATION_NAMESPACE> logs pod/<RESOLVED_POD_NAME> --all-containers --previous --tail=200 --timestamps
```

The `--previous` command is meaningful only when a container restarted and a previous instance exists; `NotFound` in that case is an expected negative result, not an incident. Redact secrets/tokens before pasting logs. For a pod that never started because of `ImagePullBackOff`, Events and the waiting message carry the evidence; an empty log is not a second failure.

For the runtime-dependency hypothesis, capture Services and EndpointSlices in the two resolved namespaces:

```bash
oc -n <RESOLVED_DESTINATION_NAMESPACE> get service,endpointslice.discovery.k8s.io -o wide
```

Promote H4 only if `marketinteraction` conditions/logs name a concrete producer endpoint or dependency and the timestamp order matches. Generic connection errors do not prove which dependency failed.

### Batch 4 — capture Argo CD control-plane state and maintenance timing

Use the `argocd_ns` resolved in Batch 1. If the two applications unexpectedly live in different Argo namespaces, run the batch for both.

```bash
oc -n <RESOLVED_ARGOCD_NAMESPACE> get argocd.argoproj.io -o custom-columns='NAME:.metadata.name,UID:.metadata.uid,GENERATION:.metadata.generation,CREATED:.metadata.creationTimestamp,CONTROLLER_REPLICAS:.spec.controller.replicas,SERVER_REPLICAS:.spec.server.replicas,REPO_REPLICAS:.spec.repo.replicas,HA_ENABLED:.spec.ha.enabled'
oc -n <RESOLVED_ARGOCD_NAMESPACE> get argocd.argoproj.io -o jsonpath='{range .items[*].metadata.managedFields[*]}{.time}{"\t"}{.manager}{"\t"}{.operation}{"\n"}{end}'
oc -n <RESOLVED_ARGOCD_NAMESPACE> get deployment.apps,statefulset.apps -o custom-columns='KIND:.kind,NAME:.metadata.name,GENERATION:.metadata.generation,OBSERVED:.status.observedGeneration,DESIRED:.spec.replicas,READY:.status.readyReplicas,UPDATED:.status.updatedReplicas,AVAILABLE:.status.availableReplicas,CURRENT:.status.currentReplicas,CREATED:.metadata.creationTimestamp'
oc -n <RESOLVED_ARGOCD_NAMESPACE> get pods -o custom-columns='POD:.metadata.name,UID:.metadata.uid,CREATED:.metadata.creationTimestamp,PHASE:.status.phase,READY:.status.containerStatuses[*].ready,RESTARTS:.status.containerStatuses[*].restartCount,NODE:.spec.nodeName,OWNER:.metadata.ownerReferences[0].name'
oc -n <RESOLVED_ARGOCD_NAMESPACE> get events --sort-by='.metadata.creationTimestamp' -o custom-columns='CREATED:.metadata.creationTimestamp,LAST:.lastTimestamp,TYPE:.type,REASON:.reason,OBJECT_KIND:.involvedObject.kind,OBJECT_NAME:.involvedObject.name,COUNT:.count,MESSAGE:.message'
```

Then collect bounded controller/repo-server logs covering the maintenance window. Resolve the exact pod names from the preceding output first:

```bash
oc -n <RESOLVED_ARGOCD_NAMESPACE> logs pod/<RESOLVED_APPLICATION_CONTROLLER_POD> --all-containers --since=6h --timestamps --prefix
oc -n <RESOLVED_ARGOCD_NAMESPACE> logs pod/<RESOLVED_REPO_SERVER_POD> --all-containers --since=6h --timestamps --prefix
```

Search the captured logs for both Application names and for reconciliation errors, cache invalidation, queue/backlog, leader changes, repository/render failures, timeouts, and panics. A log line must include its timestamp and pod identity. Current green replicas without the historical log/event window do not eliminate a transient link.

### Batch 5 — evidence `oc` cannot supply by itself

Obtain these authoritative records before saying “unrelated”:

1. Maintenance start/end timestamps and the exact applied diff. Confirm whether it changed only Argo CD replica fields or also Git/Helm/Application/workload image values.
2. Desired-state repository commit(s) corresponding to both `.status.sync.revision` values, including image-field blame/history.
3. Registry publication/retention history for each exact requested repository/tag/digest.
4. If Kubernetes events/logs have expired, cluster audit or durable observability records for controller operations and pod creation/deletion.

If the exact maintenance diff is unavailable, the strongest allowed conclusion is “no link is visible in the observed runtime and control-plane evidence”; it is not a proof of independence.

## What would link or unlink the maintenance

### Evidence that links it directly

A direct maintenance link needs at least one connecting mechanism plus ordered timestamps:

- The maintenance diff changed either Application source/revision, Helm values, image repository/tag, pull policy, or a shared generated manifest consumed by these workloads.
- Controller/repo-server logs show the maintenance operation rendered or applied a wrong workload spec for the named apps.
- Both Application operations were initiated by the same maintenance actor/change and the resulting resource revisions introduced their failures.

“Happened during the window” without one of these bridges is correlation only.

### Evidence that links it only as a trigger/exposure

Classify the maintenance as a trigger—but not the root cause—if all of the following hold:

1. Desired Application revision and workload pod-template generation did not change.
2. Argo controller rollout/reconciliation or a maintenance-caused reschedule replaced the workload pod after the maintenance began.
3. The replacement pod attempted a fresh pull of the already-configured `:latest` image and failed because the tag was absent, while an older pod/node had a cached digest or remained running.

The causal sentence would then be: “The maintenance exposed an existing unsafe image reference by triggering a new pull; it did not remove or create the registry tag.”

### Evidence that supports unlinking it

The maintenance relation becomes unsupported with high confidence only when the evidence chain shows:

- the applied maintenance diff was limited to Argo CD control-plane replica settings;
- both apps’ Application revisions, operations, workload template generations, and pod creation/failure times belong to independent application changes or predate the maintenance;
- Argo controller/repo-server replicas stayed available and their logs/events show no app-specific render/apply anomaly in the relevant window;
- each app has a concrete leaf failure with no shared changed dependency or runtime dependency chain.

Even then, phrase the conclusion as “no causal link found in the checked planes,” because historical events/logs may have expired. Do not use “impossible” or “definitively unrelated.”

## Cascade and blast radius

### If H1 is true

```text
missing image tag -> esp pod never starts -> Application remains Degraded
separate marketinteraction defect -> second Application remains Degraded
operator sees two red apps -> assumes shared platform outage -> wrong team/escalation
```

Blast radius is at least the two DEV application paths, but user/function impact remains unknown until routes/services are checked.

### If H3 or H4 is true

```text
maintenance-triggered reconcile/replacement -> new image pull -> esp unavailable
esp dependency unavailable -> marketinteraction readiness/runtime failures
two Degraded apps -> retries/backlog or delayed message flow -> broader DEV test disruption
```

Do not quantify request/message loss without queue, retry, and service metrics; none are supplied.

## Slack claim ceiling

### Safe now, using only the supplied screenshot evidence

> Both DEV apps are `Synced` but `Degraded`, which points to workload health rather than an Argo sync failure. For `espmessageproducer`, the immediate cause is confirmed: its pod cannot pull `:latest` because that tag is absent from the registry. We do not yet have the `marketinteraction` pod/event evidence or a change-and-timestamp chain tying either failure to the Argo replica increase, so the maintenance link is currently unsupported—not disproved.

This is the ceiling. Do not currently say “the incidents are unrelated” or give a root cause for `marketinteraction`.

### Allowed only after the unlinking evidence passes

> These are separate application/runtime failures, not an Argo CD control-plane failure. `espmessageproducer` is requesting an unavailable `:latest` image; `marketinteraction` is failing because of `<PROBE-CONFIRMED MECHANISM>`. The Argo replica change was limited to the control plane, and the checked revisions, rollout timestamps, controller health, and events show no causal path from that maintenance to either workload.

Replace the bracketed text only with a probe-confirmed mechanism. If any required historical evidence is unavailable, end with: “We found no causal link in the evidence still available.”

### Allowed if maintenance was only an exposure trigger

> The Argo replica work did not create the missing registry tag, but it did trigger a pod replacement/re-pull that exposed the existing `:latest` reference. The application root cause is the unavailable mutable image tag; maintenance was the trigger, not the source of the bad image.

## Operator verdict

**FIX CLAIM FIRST — do not publish “unrelated” yet.** The current screenshot evidence confirms the immediate `espmessageproducer` failure and makes a direct Argo scaling defect unlikely, but it leaves the second app’s mechanism and the maintenance-trigger path open. The decisive next action is the read-only AVD evidence batch above; no cluster mutation is justified.

## Residual risk and falsifier

- Highest-risk unresolved decision point: a controller rollout may have forced a new pull of a latent bad `:latest` reference while old cached pods appeared healthy.
- Cheapest falsifier: compare Application revision/template generation and pod creation time with the Argo controller pod creation/maintenance window; if the workload changed independently, H3 weakens; if only the pod was replaced during maintenance, H3 strengthens.
- Future-maintainer constraint not confirmed here: event/log retention must cover the maintenance window. If it does not, “no event found” has no unlinking force and the investigation remains partially unverified.

