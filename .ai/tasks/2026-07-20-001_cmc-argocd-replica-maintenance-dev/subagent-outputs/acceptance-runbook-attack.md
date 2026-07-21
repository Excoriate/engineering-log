---
task_id: 2026-07-20-001
agent: sre-maniac
status: complete
summary: |
  The Acceptance plan is conceptually aware of the major false-green modes, but several remain prose rather than fail-closed operator controls. The highest-risk gaps are mid-block kubeconfig drift, pod replacement resetting restart evidence, incomplete Redis HA and EndpointSlice proof, stale application or metrics data, and an observer cadence that has not been demonstrated executable. A new SRE could therefore follow the current documents faithfully and still report success from the wrong cluster, a partial topology, or a transient green snapshot. Verdict: FIX FIRST before the Wednesday runbook is promoted as monitor-ready.
key_findings:
  - finding_1: A single identity line does not make a multi-command block atomic against shared-kubeconfig changes.
  - finding_2: Count-only restart baselines lose failures when pods are replaced or recreated.
  - finding_3: Redis HA success needs topology, backend, and freshness invariants, not pod readiness alone.
  - finding_4: The proposed cadence and stabilization window are not yet operationally demonstrated.
  - finding_5: The new-SRE path lacks a timed, poisoned-scenario acceptance test.
---

# Acceptance runbook operational attack

## Verdict

**FIX FIRST — HIGH confidence in the document/control gaps; no verdict on live ACC health.**

The plan should not yet be called monitor-ready. It names most hazards, but the current proof mechanism can still be fooled by a mid-block context switch, object replacement, partial Redis HA, stale metrics or Application status, incomplete backend membership, or a late regression. These are not wording defects. They are control defects that allow the operator to follow the text and still produce a false success record.

Evidence basis:

- SOURCE-VERIFIED: the cited requirements, plan, specification, and Acceptance baseline say the quoted things.
- THEORETICAL: the failure interleavings and poisoned fixtures below were derived from the written controls; no live ACC cluster command was run by this adversarial lane.
- UNVERIFIED[blocked]: Wednesday's actual CMC intent, ACC identity at maintenance time, topology transition, runtime cadence, metrics freshness, application freshness, and late stability require live read-only execution during the authorized window.
- Safety: no cluster mutation and no cluster read were performed. This review wrote only this task-local sidecar.

Source aliases used below:

- P = .ai/tasks/2026-07-20-001_cmc-argocd-replica-maintenance-dev/plan/plan.md
- S = .ai/tasks/2026-07-20-001_cmc-argocd-replica-maintenance-dev/specs/01-spec.md
- A = log/employer/eneco/02_on_call_shift/2026_july/2026_07_20_001_cmc_argocd_replica_increase_maintenance_dev_acc/maintenance-july-22-records-findings.md

The Acceptance baseline changed while this review was in progress. The attack uses its later 168-line state, which added the identity warning, terminology, and proof ceiling. Any subsequent concurrent edit is outside this receipt.

## Isolated BRAIN SCAN

- Dangerous assumption: because the plan names a failure mode, the future runbook will enforce it under time pressure.
- Hidden premise doing the most work: a sequence of individually correct read-only commands behaves like one identity-bound, time-bounded transaction.
- Opposite-conclusion prediction: if the procedure is actually safe, a wrong-context fixture, a pod-UID replacement fixture, a desired=ready-but-updated-lags fixture, a stale metrics fixture, and a partial EndpointSlice fixture all cause an explicit non-success verdict without author assistance.
- What is not observed: no such poisoned-fixture execution or timed newcomer rehearsal is cited.
- Likely production failure: the observer records a coherent green snapshot that belongs to the wrong environment, omits a replaced failed pod, or captures only a partially realized HA topology.
- Cascade: false completion closes the watch; the evidence ledger stops accumulating; a late control-plane or application regression loses temporal attribution; Wednesday's handoff says healthy while recovery still depends on operator reconciliation.

## Attempted-attack ledger

| ID | Attack surface | Attempt | Result against current plan/baseline | Residual |
|---|---|---|---|---|
| AT-01 | Shared kubeconfig | Switch current context after the first identity line but before later commands. | **BREACH**: the warning exists, but the command block is not pinned or re-asserted per command. | Mixed-cluster capture can look internally plausible. |
| AT-02 | DEV-equivalent target | Leave CMC intent blank and let observed ACC deltas resemble DEV. | **PARTIAL BREACH**: the plan says conditional, but permits a changed object to identify intent. | Observation can be promoted into authorization. |
| AT-03 | Historical restarts | Replace a pod so restartCount returns to zero under the same human-readable role. | **BREACH**: no UID/creation/revision continuity contract. | Predecessor failure disappears from the final table. |
| AT-04 | Controller recreation | Recreate the single controller while cached Applications remain Synced Healthy. | **BREACH**: readiness and Application summary do not prove reconciliation freshness. | Control-plane blackout can be hidden by cached status. |
| AT-05 | Redis standalone→HA | Make HAProxy 3/3 while Redis/Sentinel is 2/3 or structurally incomplete. | **BREACH**: no exact topology success matrix or blocked-quorum state. | Partial HA may be declared complete. |
| AT-06 | Desired-only/ready-only | Set desired=3 and ready=3 while updated=1 or observedGeneration lags. | **PARTIAL SURVIVAL**: the plan names updated/available, but exact workload fields and revision equality are not operationalized. | Old Ready pods can mask an incomplete update. |
| AT-07 | EndpointSlice | Keep all pods Ready but publish only one stale backend. | **BREACH**: endpoint membership is named but no cardinality/UID/condition invariant is specified. | Service traffic path may remain partial. |
| AT-08 | Node averages | Keep cluster average low while all new replicas land on one constrained eligible node. | **PARTIAL SURVIVAL**: the plan demands actual placement, but no per-node reservation calculation is specified. | Average headroom can hide local saturation. |
| AT-09 | Metrics lag/unavailable | Replay the same metrics timestamp twice or omit new pods from Metrics API. | **PARTIAL BREACH**: two fresh samples are required, but freshness is not defined or measured. | Cached samples can satisfy the stabilization count. |
| AT-10 | Application sampling | Hide one Degraded Application outside a visible/sampled set. | **PARTIAL SURVIVAL**: the plan prohibits generalizing a sample, but the baseline says visible inventory without total cardinality. | Global healthy language remains possible. |
| AT-11 | Late regression | Turn green for five minutes, then restart or become Progressing at minute six. | **PARTIAL BREACH**: first green is rejected, but the safety floor can be shortened by a CMC window and lacks a late checkpoint. | Regression can occur immediately after closeout. |
| AT-12 | Observer cadence | Make each sequential probe take long enough that a nominal 15-second cycle overruns. | **BREACH**: no bounded runner, cycle-duration measurement, or missed-sample state. | The ledger can claim a cadence that never occurred. |
| AT-13 | CMC attribution | Observe the expected object/count change with no actor evidence. | **PARTIAL BREACH**: attribution states are good, but changed-object language can still imply CMC intent. | Correlation may be upgraded to causation. |
| AT-14 | New SRE under pressure | Give a zero-context operator ten minutes and poison one signal per scenario. | **BREACH / NOT TESTED**: no one-page cockpit or timed tabletop result exists yet. | Teaching quality and safe live execution remain unproven. |
| AT-15 | Event absence | Let a warning event expire or be replaced before the one-shot query. | **BREACH**: no-events-returned can look like no-events-occurred. | Ephemeral evidence can disappear before closeout. |

## Findings

### F-01 — The identity guard is not atomic against a shared-kubeconfig change

- **Attacked claim:** printing the ACC server immediately before a capture block makes every following value belong to ACC. A:62-66 states the risk and rule; A:130-143 then presents one identity call followed by ten unpinned commands. P:151-153 also treats one immediately preceding equality check as sufficient.
- **Concrete failure scenario:** the ACC tab prints the ACC API. Before the deployment, pod, metrics, or Application query, another tab performs a DEV login and changes the shared current context. The remaining commands succeed against DEV because namespace and ArgoCD names exist in both environments. The block now contains mixed ACC and DEV facts with no obvious error.
- **Mechanism and cascade:** current-context is mutable shared state; the capture block is a check-then-act sequence; every later unpinned oc invocation re-resolves that state. A mid-block switch corrupts provenance, after which healthy DEV values can falsely close the ACC watch and misattribute changes.
- **Discriminating falsifier:**
  - **Action:** run the future capture primitive against a secret-free two-context fixture while switching the fixture's current context between commands.
  - **If the control is true:** every cluster query is pinned to the named ACC context or fails before output; every row records ACC API, context, timestamp, namespace UID, and ArgoCD UID.
  - **If the control is false:** at least one unqualified oc command follows current-context and returns the alternate environment while the capture still reports ACC.
- **Severity / evidence:** CRITICAL impact; SOURCE-VERIFIED control gap plus THEORETICAL interleaving.
- **Required behavioral change:** replace the warning-plus-block with a fail-closed environment wrapper. Pin every command to an explicitly resolved ACC context or isolated kubeconfig, re-assert expected server before each accepted sample, record immutable namespace/ArgoCD UIDs, abort the whole capture on mismatch, and forbid copying partial output into the ledger. The negative fixture must be executed before monitor-ready status.

### F-02 — A live delta is not an intent contract

- **Attacked claim:** CMC intent may be established by an authoritative statement or an unambiguous changed object. P:14 and P:77 allow the latter; A:116-126 correctly calls the DEV-equivalent delta only a hypothesis.
- **Concrete failure scenario:** ACC's operator reconciles a pre-existing configuration drift or another actor changes a replica field during the maintenance window. The observed shape matches DEV: server 1→3, repo 1→2, or HA appears. The observer infers this was CMC's authorized target and declares completion even though the actual change ticket targeted a different component or count.
- **Mechanism and cascade:** observation answers what changed, not who authorized it or what end state was intended. Conflating discovery with authorization converts correlation into scope, so the runbook may monitor the wrong success criteria and later attribute unrelated reconciliation to CMC.
- **Discriminating falsifier:**
  - **Action:** execute the runbook with the CMC intent table deliberately blank while feeding it a DEV-shaped live-delta fixture.
  - **If the control is true:** the runbook permits observation but forces CANNOT VERIFY INTENDED COMPLETION and UNATTRIBUTED; it cannot populate component/count/HA intent from the fixture.
  - **If the control is false:** the observed object or DEV hypothesis becomes the success target without a named source, change ID, owner, and timestamp.
- **Severity / evidence:** HIGH; SOURCE-VERIFIED ambiguity plus THEORETICAL attribution failure.
- **Required behavioral change:** require a signed intent row before any success verdict: environment/API, namespace, CR UID, component(s), old value, new value, HA mode, allowed controller recreation, maintenance window, evidence source, source time, and CMC contact/change identifier. A live delta may route probes but must never fill authorization fields.

### F-03 — Restart counts are scoped to pod identity, not component identity

- **Attacked claim:** Wednesday instability can be detected by restart counts rising above baseline or a new pod beginning to restart. A:80-90 records role-level counts; P:39-42 asks for owner links and restart state but not durable identity.
- **Concrete failure scenario:** application-controller-0 is recreated with the same name and a new UID, or a Deployment replaces a failed replica. The predecessor had one or more restarts, then disappears. The replacement shows restartCount=0. A role-name comparison says no new restart even though the maintenance caused instability.
- **Mechanism and cascade:** restartCount belongs to the current container instance within one Pod UID. Replacement resets the counter, while Deployment pod names and StatefulSet names do not preserve container history. Count-only comparison loses the predecessor and erases evidence just when rollout churn is highest.
- **Discriminating falsifier:**
  - **Action:** feed the comparator two snapshots with the same component role but a different pod UID/creationTimestamp and a lower restartCount.
  - **If the control is true:** it records REPLACED, preserves the predecessor's final state, opens a new baseline for the successor, and does not label the lower count as recovery.
  - **If the control is false:** it compares only pod display name or role and reports zero restart delta.
- **Severity / evidence:** HIGH; SOURCE-VERIFIED missing identity fields plus Kubernetes lifecycle mechanism.
- **Required behavioral change:** T0 and every fast sample must capture pod UID, creationTimestamp, container name, restartCount, lastState termination reason/time, Ready condition transition time, owner UID, pod-template-hash or StatefulSet revision, and node. Maintain an append-only union keyed by pod UID; deletion/replacement is an event, not disappearance.

### F-04 — Controller recreation can leave cached green Application status

- **Attacked claim:** controller recreation is expected and Application status plus workload readiness demonstrates outcome. A:123 mentions possible controller recreation; A:106-114 presents current Application health; P:54-56 calls for controller reconciliation/freshness only where visible.
- **Concrete failure scenario:** the single application-controller pod is recreated. The new pod becomes Ready, but reconciliation is stalled, credentials are bad, or queues are not processing. Application CRs retain cached Synced Healthy values from before the recreation. The observer sees a Ready controller and green Applications and declares success.
- **Mechanism and cascade:** Kubernetes readiness proves the process responds to its probe; stored Application status proves the last reconciliation result, not that the replacement controller has completed a fresh reconciliation. A control-plane blackout can therefore be hidden until drift or a later sync needs processing.
- **Discriminating falsifier:**
  - **Action:** test a fixture where controller UID/revision changes but every Application status and reconciliation timestamp remains frozen.
  - **If the control is true:** completion remains blocked as RECONCILIATION FRESHNESS UNKNOWN until a post-recreation freshness signal advances or explicit failure evidence is resolved.
  - **If the control is false:** controller Ready plus unchanged Synced Healthy rows passes.
- **Severity / evidence:** HIGH; THEORETICAL false green with SOURCE-VERIFIED missing mandatory freshness gate.
- **Required behavioral change:** make controller recreation a named transition. Capture StatefulSet generation, observedGeneration, currentRevision, updateRevision, pod UID/creation time, readiness gap, and post-recreation reconciliation freshness. Prefer Application status.reconciledAt or equivalent observable advancement; use targeted controller logs/metrics only if necessary and permitted. If no freshness signal is available, conclude CANNOT VERIFY RECONCILIATION rather than healthy.

### F-05 — Redis HA requires a topology invariant, not a pod-count story

- **Attacked claim:** standalone Redis will be replaced by three HAProxy pods and a three-member Redis/Sentinel StatefulSet. A:116-124; S:96 and S:106 require Redis topology and false-green protection, but no exact pass/fail matrix is supplied.
- **Concrete failure scenario:** server and repo replicas converge; HAProxy reports 3/3 Ready; the Redis/Sentinel StatefulSet has only 2/3 Ready, one member is Pending, old standalone Redis is still selected, or the expected service points at the wrong set. Generic pod output looks mostly green and the operator declares HA complete.
- **Mechanism and cascade:** HAProxy availability, Redis member readiness, Sentinel/quorum behavior, service selection, and old-topology removal are separate invariants. Partial creation can route traffic into a non-quorate or stale data plane, causing login/session, repository, or reconciliation failures after the apparent rollout.
- **Discriminating falsifier:**
  - **Action:** run the topology evaluator on a fixture with CR HA enabled, HAProxy 3/3, Redis/Sentinel 2/3, and a stale standalone backend.
  - **If the control is true:** it blocks completion, names the failed invariant, and routes to StatefulSet conditions/events and EndpointSlice membership.
  - **If the control is false:** it passes because HAProxy and total pod counts look correct.
- **Severity / evidence:** CRITICAL impact; SOURCE-VERIFIED absent acceptance matrix plus THEORETICAL partial-topology failure.
- **Required behavioral change:** create a discovered-object topology matrix at T0 and target state: CR ha.enabled, old standalone workload/service expected presence or absence, HAProxy Deployment generation/updated/ready/available, Redis/Sentinel StatefulSet generation/currentRevision/updateRevision/current/ready, pod UIDs/roles, services/selectors, EndpointSlices, and events. If Sentinel quorum cannot be proven within allowed read-only surfaces, mark REDIS DATA-PLANE QUORUM UNVERIFIED and do not claim HA function from readiness alone.

### F-06 — Desired and Ready can agree while the new revision has not converged

- **Attacked claim:** equality of desired/current/updated/ready/available is required. P:81-83 is strong, but A:70-78 and A:130-143 expose only summarized Ready/available output and do not specify generation/revision equality.
- **Concrete failure scenario:** a Deployment has spec.replicas=3, status.replicas=3, readyReplicas=3, but updatedReplicas=1 and two old ReplicaSet pods remain Ready. Or metadata.generation exceeds status.observedGeneration. A desired+ready table says 3/3 even though the operator/workload controller has not realized the new template.
- **Mechanism and cascade:** readiness is per current pod; it is not proof those pods belong to the intended revision. A controller can serve old pods while the new revision is blocked. Closing on Ready preserves old behavior and hides the failed rollout.
- **Discriminating falsifier:**
  - **Action:** test the runbook's parser/decision table with desired=3, current=3, ready=3, available=3, updated=1, generation=12, observedGeneration=11.
  - **If the control is true:** completion fails and the next probes inspect rollout conditions, ReplicaSet/ControllerRevision ownership, and events.
  - **If the control is false:** 3/3 Ready produces success.
- **Severity / evidence:** HIGH; plan intent survives, operational proof is incomplete.
- **Required behavioral change:** print the exact state vector for every changed Deployment and StatefulSet. Deployment: generation, observedGeneration, desired, replicas, updated, ready, available, unavailable, conditions, and pod owner revision. StatefulSet: generation, observedGeneration, replicas, current, updated, ready, currentRevision, updateRevision, and pod ordinal/revision. Equality must be revision-aware.

### F-07 — Ready pods are not service backends

- **Attacked claim:** endpoint membership will prove component usefulness. P:56 and S:96 name it; A:37-49 uses a generic Endpoints step and A:124 predicts new endpoints, but no EndpointSlice invariant is defined.
- **Concrete failure scenario:** three server pods are Ready, yet the server EndpointSlice contains one old address because of selector mismatch, propagation lag, or a terminating backend. Traffic still reaches only one replica. All desired/ready counts and node checks pass.
- **Mechanism and cascade:** readiness is necessary for backend eligibility but service selection and EndpointSlice publication are separate controllers. Missing or stale backends reduce redundancy and can create a single hot endpoint, producing latency or outage after the rollout is marked complete.
- **Discriminating falsifier:**
  - **Action:** evaluate a fixture with three Ready serving pods and an EndpointSlice containing one ready targetRef UID plus one terminating stale UID.
  - **If the control is true:** it reports backend cardinality/identity mismatch and blocks service-level completion.
  - **If the control is false:** Service existence or pod readiness passes.
- **Severity / evidence:** CRITICAL impact for serving components; SOURCE-VERIFIED unspecified invariant.
- **Required behavioral change:** discover services and EndpointSlices by namespace and kubernetes.io/service-name label. For each serving component, compare service selector, expected Ready pod UIDs, EndpointSlice targetRef UIDs, ready/serving/terminating conditions, ports, and addresses. Require stable membership across at least two samples after pod readiness. Do not use deprecated legacy Endpoints as the authoritative lane.

### F-08 — Cluster or node averages do not prove placement safety

- **Attacked claim:** low measured node use plus actual placement and request-fit evidence supports capacity. A:92-104 says current nodes have 7–8% CPU and 37–52% memory and calls this substantial measured headroom; P:44-51 correctly separates use, reservation, and eligibility.
- **Concrete failure scenario:** anti-affinity, node selectors, taints, or topology constraints leave only one eligible node. All new server/repo/HA pods land there. Cluster averages remain low and the hosting-node average looked acceptable at T0, but aggregate requests on that node approach allocatable memory and a later spike causes pressure/OOM.
- **Mechanism and cascade:** scheduler feasibility and runtime saturation are per eligible node, not cluster average. Replica changes alter reservations discretely. Placement concentration can exhaust one node, then eviction/restart shifts traffic to fewer replicas and amplifies load.
- **Discriminating falsifier:**
  - **Action:** feed the capacity table a fixture with 45% fleet-average memory, one eligible target node at 92% requested memory or MemoryPressure, and all new pods placed there.
  - **If the control is true:** it blocks safe-capacity language and names the exact constrained node and reservation delta.
  - **If the control is false:** the average or measured-use percentage passes.
- **Severity / evidence:** HIGH; plan has the right lanes but no required per-node calculation/output.
- **Required behavioral change:** join every new pod UID to its actual node, then show that node's allocatable, conditions, taints/labels, measured use, aggregate scheduled requests, and incremental component request. List placement constraints and eligible nodes as far as permission allows. Replace substantial headroom with observed measured headroom only; capacity safety requires per-node reservation and eligibility evidence.

### F-09 — Two metrics samples are not fresh merely because two commands ran

- **Attacked claim:** metrics no faster than 60 seconds and at least two fresh samples are enough for stabilization. P:81-83; A:94-104 uses oc adm top, which does not display the underlying Metrics API timestamp in this table.
- **Concrete failure scenario:** metrics-server has not scraped newly created pods or returns the same cached sample twice. The operator runs two top commands one minute apart, both omit the new HA pods or replay old values, and the runbook counts them as two fresh samples.
- **Mechanism and cascade:** command time is not sample time. Metrics lag is largest exactly when pods are new. Counting invocations can falsely prove low utilization, so the watcher closes before observing the actual steady-state footprint.
- **Discriminating falsifier:**
  - **Action:** replay two metrics payloads with identical per-pod timestamps/windows, or omit pods whose creation time predates the second sample.
  - **If the control is true:** the second sample is METRICS STALE/INCOMPLETE, utilization remains UNKNOWN for missing pods, and it does not advance the stabilization counter.
  - **If the control is false:** two successful top invocations satisfy the rule.
- **Severity / evidence:** HIGH for capacity confidence; SOURCE-VERIFIED freshness undefined.
- **Required behavioral change:** when permitted, capture Metrics API timestamp/window and bind metrics rows to pod UID. Require timestamps to advance and all expected new pods to appear before calling samples fresh. If raw timestamps are unavailable, explicitly label freshness unverified; top remains a point estimate, not a stabilization counter. Metrics failure must not be replaced by requests or averages.

### F-10 — Visible or sampled Applications cannot support a fleet-wide healthy claim

- **Attacked claim:** the visible Acceptance Application inventory was Synced Healthy, including solver. A:106-114. P:54-57 says full-versus-sampled scope must be declared and forbids generalizing a sample.
- **Concrete failure scenario:** the terminal view, screenshot, or selected rows cover 99 of 100 Applications and omit one Degraded or Progressing Application. Solver is green. The operator writes Applications stayed healthy because the visible set looked green.
- **Mechanism and cascade:** sampling may be appropriate for detailed diagnosis, but health completeness is a counting problem. An omitted failure is not bounded by the sample. A single affected application can be the user-facing impact that control-plane component metrics miss.
- **Discriminating falsifier:**
  - **Action:** run the summarizer on a fixture containing 100 Applications with one Degraded record outside the detail sample.
  - **If the control is true:** total cardinality and full status distribution expose 1 Degraded; the detail sample is only for drill-down.
  - **If the control is false:** the sampled 99 produce an all-healthy conclusion.
- **Severity / evidence:** HIGH; SOURCE-VERIFIED ambiguity in visible inventory.
- **Required behavioral change:** every fast Application sample must record total count and full sync/health distribution from the complete namespace query, plus all non-Synced/non-Healthy rows. If permissions or output limits prevent completeness, state APPLICATION FLEET STATUS INCOMPLETE and never say all Applications. A deterministic cohort may be used for freshness, but not fleet health.

### F-11 — Five green minutes can still be a transient, not stabilization

- **Attacked claim:** five minutes of stable service/Application evidence plus two fresh resource samples is the default, and a CMC-defined window supersedes it. P:77-85.
- **Concrete failure scenario:** workloads and EndpointSlices converge at minute zero; the single replacement controller needs a reconciliation interval before stale credentials or queue failures appear; a server pod restarts at minute six and Applications turn Progressing at minute seven. The observer closed at minute five or earlier because the announced CMC window ended.
- **Mechanism and cascade:** failure signals have different detection latencies: readiness seconds, EndpointSlice propagation seconds, metrics roughly a scrape interval, reconciliation potentially minutes, and backoff-driven restarts later. A fixed short window can end before the slowest signal has had one discriminating opportunity.
- **Discriminating falsifier:**
  - **Action:** replay a timeline green from minute 0–5, restart at minute 6, and Application regression at minute 7.
  - **If the control is true:** the plan either remains open through the evidence floor or hands off an explicit scheduled late checkpoint; it does not issue a terminal healthy verdict at minute five.
  - **If the control is false:** the first five-minute green period closes the ledger with no residual.
- **Severity / evidence:** HIGH; temporal false green.
- **Required behavioral change:** define stabilization as the maximum of an explicit minimum wall time, at least two advancing metrics samples, at least one proven post-change controller/Application freshness advance, and component-specific readiness/backend stability. A CMC window may set coordination expectations but must not shorten the evidence safety floor. Add a late-regression checkpoint and ownership if observation must end.

### F-12 — The nominal 15-second cadence is not executable proof

- **Attacked claim:** workload/pod/event/Application state can be sampled every 15 seconds while metrics run every 60 seconds. P:81-82. The baseline offers a sequential eleven-command block at A:130-143 but no bounded live runner.
- **Concrete failure scenario:** authentication latency, API throttling, or one slow get call causes the fast sequence to take 25–40 seconds. The operator manually alternates commands, misses the controller replacement and a short FailedScheduling event, but later describes the watch as 15-second cadence.
- **Mechanism and cascade:** cadence is an observed property of completed cycles, not a configured sleep. Sequential calls, human copy/paste, and unbounded request timeouts create sampling gaps. Overlapping loops can also self-load the API and flood the terminal, making the observer the failure source.
- **Discriminating falsifier:**
  - **Action:** run the future observer against a harmless fake oc fixture where one command takes longer than its budget and another returns nonzero.
  - **If the control is true:** the cycle records start/end/duration, does not overlap, emits MISSED SAMPLE or PROBE FAILED, retains stderr/exit status, and prevents success for the uncovered interval.
  - **If the control is false:** it sleeps 15 seconds or prints timestamps while silently stretching the real interval.
- **Severity / evidence:** HIGH; unverified operational feasibility.
- **Required behavioral change:** provide one bounded, read-only fast-cycle command with a capture ID, explicit per-call request timeout, captured exit/stderr, no overlap, actual duration, and a missed-cycle state. Keep the slow metrics cycle separate. Test API-call volume and manual usability before Wednesday; if the fast bundle cannot complete inside the target interval, choose an evidenced sustainable cadence rather than falsifying the ledger.

### F-13 — Changed-object evidence and CMC attribution remain complected

- **Attacked claim:** attribution states prevent timing-only causation. P:98-100 is good, but P:14 and P:77 allow an unambiguous/clearly identified changed object to stand in for missing intent.
- **Concrete failure scenario:** the operator reconciles the controller or Redis topology in the announced window; managedFields/audit actor is not captured; a platform event or pre-existing drift produces the same object delta. The ledger labels it CMC-CORRELATED or CMC-CONFIRMED based on timing and expected shape.
- **Mechanism and cascade:** object state proves what exists now. Timing plus shape increases correlation but does not establish actor or causal mechanism. Misattribution sends the wrong escalation, creates an incorrect maintenance record, and hides a platform/controller defect.
- **Discriminating falsifier:**
  - **Action:** provide two identical object-delta fixtures, one with authoritative CMC intent/actor evidence and one without.
  - **If the control is true:** only the first can become CMC-CONFIRMED; the second remains UNATTRIBUTED or, with announced-window match only, explicitly CMC-CORRELATED with a falsifier.
  - **If the control is false:** both receive the same attribution because state and timing match.
- **Severity / evidence:** HIGH; SOURCE-VERIFIED policy inconsistency.
- **Required behavioral change:** separate three fields in every ledger row: change intent source, observed temporal correlation, and causal/actor evidence. Define exact promotion rules for CMC-CONFIRMED, CMC-CORRELATED, PLATFORM, LOCAL-TOOLING, and UNATTRIBUTED. Operator-created descendants after an authorized CR change may be maintenance-correlated without being a CMC fault.

### F-14 — The plan is not yet usable by a new SRE under time pressure

- **Attacked claim:** a new SRE can safely operate from the forthcoming runbook and understand solver/sync progression. The requirement demands this; S:96 lists the eventual runbook sections. The current baseline is educational, but A:128-146 is a command catalogue without inputs, expected outputs, capture IDs, stop codes, timing, or discrepancy branches.
- **Concrete failure scenario:** a zero-context SRE starts five minutes before CMC. They know the concepts but must infer which commands form T0, which are fast/slow, what to do on partial Redis HA, how to pin ACC, and which status blocks completion. Under pressure they run the easiest green commands and miss the backend/freshness lanes.
- **Mechanism and cascade:** distributed instructions create working-memory load. The operator must translate prose into a state machine while also watching the cluster. Ambiguity causes skipped gates, inconsistent timestamps, and unrepeatable evidence; education does not substitute for an executable cockpit.
- **Discriminating falsifier:**
  - **Action:** give a new SRE only the finished runbook and ten minutes to process five poisoned, secret-free fixtures: wrong context, blank CMC intent, desired=ready with updated lag, Redis 2/3 plus stale EndpointSlice, and solver Synced Progressing with stale reconciliation time.
  - **If the control is true:** without author help they produce the correct verdict, next two read-only probes, capture ID, and escalation/continue decision for every fixture.
  - **If the control is false:** they need another document or author explanation, or accept any poisoned scenario.
- **Severity / evidence:** HIGH; USER-GRADED/behavioral proof absent.
- **Required behavioral change:** the runbook needs a one-page cockpit before deep teaching: immutable inputs, hard stop gates, exact ordered read-only commands, expected signal, failure meaning, next probe, cadence, capture ID, and decision code. Keep solver and Synced/Healthy/Progressing explanations adjacent to the Application decision, not only in a syllabus. Run the timed zero-context tabletop and revise from mistakes.

### F-15 — No events returned is not evidence that no event occurred

- **Attacked claim:** the Acceptance baseline says no namespace events were returned. A:102. P:81 includes events in the fast watch but does not define event identity, retention, or missed-event handling.
- **Concrete failure scenario:** FailedScheduling or probe failures occur between manual samples; the relevant Event object is aggregated, replaced, expires, or falls outside the query's visible set. The final query returns no current events and the ledger records no failures.
- **Mechanism and cascade:** Kubernetes Events are best-effort, mutable/aggregated, and retention-bounded evidence. A one-shot absence cannot prove historical absence. Lost transient events remove the proximate cause for readiness delay and can falsely support a stable window.
- **Discriminating falsifier:**
  - **Action:** replay event snapshots where a Warning appears in an intermediate cycle and is absent from the final cycle.
  - **If the control is true:** the append-only ledger preserves event UID/reason/object/first-last/count from the intermediate cycle and final absence does not erase it.
  - **If the control is false:** final empty output becomes no events occurred.
- **Severity / evidence:** MEDIUM alone, HIGH when it is the only scheduling/probe evidence.
- **Required behavioral change:** state no events returned by this query at this timestamp, never no events occurred. During the authorized watch, append event deltas keyed by involved object UID, reason, first/last timestamp, and count. Treat sampling gaps as unknown history and use conditions/restart/readiness evidence as independent lanes.

## Cross-finding cascade

The worst credible chain is:

1. ACC identity is checked once.
2. Shared kubeconfig changes mid-block and later outputs come from DEV, or ACC pod replacements reset restart evidence.
3. Desired/Ready counts converge while updated revision or EndpointSlice membership lags.
4. HAProxy looks healthy while Redis/Sentinel topology is incomplete.
5. Metrics repeat a stale timestamp and the visible Application sample remains cached green.
6. The nominal five-minute/15-second watch closes without proving its real cadence or controller freshness.
7. The ledger promotes a DEV-shaped delta to CMC completion.
8. Observation stops; a minute-six restart or Progressing application is no longer tied to the maintenance window.

Blast radius cannot be quantified from the documents: Application inventory size, traffic, controller queue, Redis/Sentinel state, and live placement are not available. The plausible impact spans the entire ACC Argo CD control plane and every Application whose reconciliation depends on it.

## Required plan/runbook changes before monitor-ready

1. **Atomic environment binding:** pin each command to ACC, record API/context/namespace UID/CR UID/time per capture, and abort a mixed block.
2. **Independent intent contract:** require authoritative component/count/topology/window evidence; observation cannot authorize itself.
3. **Identity-aware temporal model:** key pods and backends by UID, preserve replacements, revisions, restart history, and event deltas.
4. **Topology-specific gates:** define Deployment, StatefulSet, controller freshness, Redis HA, service, and EndpointSlice invariants with explicit non-success states.
5. **Freshness-aware evidence:** distinguish command time from metrics/Application reconciliation time; stale or missing data becomes UNKNOWN, never green.
6. **Placement arithmetic:** join new pods to actual nodes and compare incremental requests, allocatable, conditions, and eligibility; do not promote averages to capacity safety.
7. **Bounded observer:** implement and test non-overlapping fast/slow cycles with request timeouts, exit/stderr capture, actual duration, and missed-sample handling.
8. **Temporal safety floor:** CMC's window cannot shorten evidence sufficiency; require a late-regression checkpoint or explicit handoff.
9. **Fleet-complete Application summary:** record total cardinality and full status distribution; use samples only for detail.
10. **Time-pressure validation:** run a zero-context, poisoned-fixture tabletop using only the runbook.

## Residual risks after these changes

- Sentinel/Redis quorum may not be observable through the currently authorized get/describe/top/log surfaces. If so, readiness/topology proof must be explicitly bounded; do not claim functional quorum.
- Metrics API sample timestamps or complete pod coverage may be permission-blocked. Capacity consumption then remains UNKNOWN even if scheduling succeeds.
- Application reconciliation freshness may not advance within the observation window without a natural refresh. Cached Synced Healthy must not be promoted into fresh reconciliation proof.
- Kubernetes Events may be lost before capture. The runbook can reduce but not eliminate this evidence gap.
- The live ACC topology, CMC intent, placement, endpoint membership, and late behavior remain UNVERIFIED until Wednesday's read-only execution.
- A document review cannot establish that a new SRE can use the runbook under pressure. That needs an independent timed reader/operator exercise.

## Goal-fidelity attack

The user's request is not merely to produce Markdown; it is to save Wednesday time, teach the operator what solver and sync progression mean, and make ACC readiness reusable. The current plan is faithful at the conceptual level, but its success claim would diverge from the user's goal if the documents are educational yet require the author to translate them during the maintenance.

Goal falsifier:

- **Action:** a new SRE, without coordinator context, uses only the runbook to capture an identity-safe T0 and classify the poisoned desired=3/ready=3/updated=1 plus Synced Progressing scenario.
- **If goal fidelity is true:** they explain that solver is an Argo-managed workload rather than a control-plane component, treat Synced and Progressing as compatible intent-versus-rollout states, reject replica success because the revision is incomplete, and choose the exact next two read-only probes.
- **If goal fidelity is false:** they need the author, another document, or a guessed command; the artifact saved documentation time but not operational time.

## Final adversarial disposition

- **Plan awareness:** strong.
- **Mechanism enforcement:** incomplete.
- **False-green resistance:** insufficient until F-01, F-03, F-05, F-07, F-09, F-11, and F-12 are behaviorally implemented and attacked with poisoned fixtures.
- **New-SRE usability:** unverified.
- **Live ACC readiness:** not assessed by this lane.
- **Explicit verdict:** **FIX FIRST. Do not label the Acceptance runbook MONITOR-READY or use it to issue a terminal success verdict until the blocking changes and discriminating tests above are present.**
