---
task_id: 2026-07-20-001
agent: sre-maniac
timestamp: 2026-07-20T07:57:19Z
status: complete
summary: |
  The preparation is directionally sound but is not safe to call monitor-ready yet. Its largest false green is treating the first observed replica delta as proof of CMC's intended target; without the authorized component and target count, that is correlation, not attribution. Replica readiness, capacity, and command proof also need temporal and scheduler-aware discriminators before the new-SRE documents can support a maintenance decision.
key_findings:
  - finding_1: The maintenance target and intended replica delta are still unconfirmed, so success cannot be graded against change intent.
  - finding_2: Snapshot convergence has no explicit stabilization window and can miss transient or delayed degradation.
  - finding_3: Utilization, scheduler reservation, and eligible-node placement are braided into one headroom claim.
  - finding_4: PROVEN is too coarse to distinguish command execution from semantically useful monitoring evidence.
---

# SRE plan attack

## Verdict

**FIX FIRST — do not label the command set maintenance-ready until the blocking attacks below are dispositioned and the corresponding plan/spec changes are live-proven.**

Evidence class: the cited plan/spec/context statements are **FACT/SOURCE-VERIFIED**. Failure mechanisms below are **THEORETICAL/INFER** until the proposed live falsifiers are run. That ceiling matters: I am not claiming production failure occurred; I am showing where the current verification method cannot distinguish success from a plausible failure.

## BRAIN SCAN

- Dangerous assumption: `desired replicas increased + pods Ready` is equivalent to successful replica maintenance.
- Hidden premise doing the most work: the first observed delta belongs to CMC, targets the intended Argo CD component, and becomes operationally effective once Kubernetes readiness converges.
- Opposite conclusion prediction: replica counts can converge while the wrong component changed, a new pod is not eligible for the expected nodes, an HPA overwrites the value, an Argo CD process is erroring behind a passing readiness probe, or node/application degradation appears after the snapshot.
- Cheapest discriminating attack: obtain the authorized component and before/after target, then capture the same identity/configuration/workload/pod/placement/resource/application signals at T0, repeatedly during transition, and across an explicit stabilization period.
- Likely failure: a one-time, exit-zero command set appears green while transient scheduling failures, delayed saturation, or an unrelated reconciliation delta is missed.
- Frame commitment: operator failure-path and goal fidelity for a zero-context SRE. The downstream actor is the on-call engineer who must decide whether to challenge CMC, keep observing, or hand over a bounded uncertainty.

## Attempted-attack ledger

### A1 — Inferred target and first-delta attribution are not change intent

- **Claim attacked:** The target is selected from VPP scope, and if the target remains unstated, “the first observed desired-count delta identifies the changed component” (`context/context-universe.md:62,90`; `plan/plan.md:28`).
- **Mechanism:** Three Argo CD instances exist. An HPA/operator/manual reconciliation can change a count during the same window. Observing a delta identifies correlation, not who intended it, whether it is the correct component, or whether the final count is correct. Waiting for the first delta also forfeits a complete target-specific T0 baseline.
- **Concrete falsifier:** **Action:** before maintenance, obtain or observe an authoritative change statement containing namespace, ArgoCD instance, component(s), old count, new count, and start/end window; compare it with the live CR/HPA/workload baseline. **If the plan is true:** the stated target exactly matches the watched object and the observed delta reaches the authorized new value. **If false:** no authoritative target exists, a different component moves, or the observed count differs from the intended new value.
- **Severity:** **CRITICAL / BLOCKING** for a success verdict and CMC attribution.
- **Required plan change:** Add a “change-intent contract” gate. Until supplied, monitor all candidates but label all deltas `UNATTRIBUTED` and do not call the maintenance successful. Ask the user/CMC for the intended component and old→new count before start if the live config cannot establish it.
- **Residual risk:** Even an announced plan can diverge from the actual executed change; runtime identity and delta correlation remain mandatory.

### A2 — Snapshot convergence can miss delayed or transient failure

- **Claim attacked:** Repeating the proven probes and seeing desired/current/ready/available converge is sufficient (`plan/plan.md:64,68,70,78`).
- **Mechanism:** readiness, metrics, events, and Argo CD reconciliation update on different clocks. A pod can become Ready, then restart or consume more resources after cache warm-up/shard rebalance. Point samples before/after erase the transition and can miss a brief outage.
- **Concrete falsifier:** **Action:** define T0 immediately before CMC starts, poll/watch the reconciliation ladder and failure signals during the change, and continue until counts are stable with no new restarts/failure events and several fresh resource/application samples have arrived. **If true:** all layers converge and remain stable for the defined observation window. **If false:** a later sample shows restart growth, Pending/Unavailable, resource pressure, endpoint loss, or application-health/reconciliation regression after the first green sample.
- **Severity:** **CRITICAL / BLOCKING** for live monitoring.
- **Required plan change:** Specify sampling interval, event-watch start, stabilization exit rule, and timestamp/capture ID. Do not invent a universal number; tie the minimum to rollout progress/readiness behavior and metrics freshness, then record the exact chosen window.
- **Residual risk:** Short-lived failures between samples remain possible; continuous event/log streams reduce but do not eliminate this.

### A3 — Kubernetes Ready is not Argo CD service effectiveness

- **Claim attacked:** Workload/pod readiness convergence plus an application summary proves service-level success (`plan/plan.md:37-50,68-70`).
- **Mechanism:** a readiness probe can pass while a repo server, API server, or application controller is erroring, leader/shard distribution is unhealthy, endpoints are incomplete, or Application status is stale. Application `Healthy/Synced` is stored status, not proof that fresh reconciliation is progressing.
- **Concrete falsifier:** **Action:** use component-specific outcome probes during the window: EndpointSlice/endpoints membership for serving components, recent component errors/restarts, ArgoCD CR/workload conditions, and application failure counts plus reconciliation freshness for a bounded sample or full authorized inventory. **If true:** new replicas become serving/active as appropriate and reconciliation continues without a new error/regression signal. **If false:** pods are Ready but endpoints are missing, component errors rise, controller/repo work stalls, or application status/freshness worsens.
- **Severity:** **HIGH**.
- **Required plan change:** Replace the generic service-outcome step with component-specific success invariants. Activate targeted component logs/error signals on endpoint or reconciliation regression, not only when replica counts disagree.
- **Residual risk:** Without component metrics or logs, active/standby or shard effectiveness may remain `UNVERIFIED`; state that explicitly rather than equating Ready with useful capacity.

### A4 — “Headroom” braids three different resource truths

- **Claim attacked:** “metrics API plus requests/limits/allocatable expose current use and schedulability” (`plan/plan.md:42-45`; `context/context-universe.md:48,71`).
- **Mechanism:** runtime utilization answers what is consumed now; scheduler reservation answers whether requested resources fit; eligibility constraints answer where the pod may run. Low cluster-average CPU/memory does not make a pod schedulable when node selectors, affinity/topology spread, taints/tolerations, or per-node requested capacity exclude the apparent free nodes.
- **Concrete falsifier:** **Action:** derive each scaled pod's effective scheduler request and placement constraints, enumerate eligible nodes, inspect per-eligible-node requested/allocatable resources and pressure, then watch Pending/FailedScheduling events. **If true:** at least the required number of eligible placements can fit and the new pods schedule without constraint/resource failures. **If false:** cluster utilization looks green but eligible nodes lack requested capacity or scheduler events reject placement.
- **Severity:** **CRITICAL / BLOCKING** for the KIV capacity claim.
- **Required plan change:** Split node KIV into three panes: (1) actual CPU/memory utilization, (2) requested/allocatable reservation, and (3) eligible placement constraints/events. Show all eligible candidate nodes before the change, not only nodes currently hosting Argo CD pods.
- **Residual risk:** Scheduler scoring, concurrent workloads, and cluster-autoscaler timing can change placement after the precheck.

### A5 — “Current hosting nodes” are not the future node set

- **Claim attacked:** Hosting-node usage is sufficient for the before/after node view (`plan/plan.md:43`; the user's requirement asks to identify nodes beforehand).
- **Mechanism:** extra replicas can land on different nodes because of topology spread, anti-affinity, rescheduling, drains, or changed capacity. Monitoring only the current node set can miss both the actual destination and the capacity bottleneck.
- **Concrete falsifier:** **Action:** record current pod→node mapping and eligible-node constraints before the change, then compare every new pod UID/node assignment during rollout against the monitored set. **If true:** every new placement is covered by node KIV and satisfies the expected spread. **If false:** a new pod lands outside the watched set or remains Pending for an unmonitored constraint.
- **Severity:** **HIGH**.
- **Required plan change:** Make node monitoring dynamically follow pod placement while retaining the precomputed eligible set; record moves/replacements by pod UID, not only pod name/count.
- **Residual risk:** A rapid reschedule between samples can be missed without watch/event capture.

### A6 — Replica resource cost is not `replicas × observed usage`

- **Claim attacked:** Current configuration makes the expected CPU/memory increment computable (`context/context-universe.md:77`; `specs/01-spec.md:18`).
- **Mechanism:** requests are scheduler reservations, limits are ceilings, and actual consumption is workload-dependent. Init containers/sidecars alter effective pod request, while controller sharding, cache warm-up, and load redistribution make actual usage nonlinear. A new idle replica can add reservation while total active workload usage barely rises—or temporarily spikes.
- **Concrete falsifier:** **Action:** calculate reservation delta from the full pod template using scheduler semantics, label it `reserved`, then separately measure per-container/pod/node actual deltas over fresh samples. **If true:** the document reports two distinct values and explains any redistribution/warm-up. **If false:** it predicts actual CPU/memory from requests/limits or multiplies one point-in-time usage sample by replica count.
- **Severity:** **HIGH**.
- **Required plan change:** Add explicit formulas and units for reservation delta, limit delta, and observed consumption delta; make them component-specific and never call requests “usage.”
- **Residual risk:** Metrics sampling and workload variance prevent an exact counterfactual; report ranges/sample times rather than deterministic forecasts.

### A7 — Metrics-unavailable fallback cannot answer whether CPU or memory spiked

- **Claim attacked:** Requests/limits, allocatable, conditions, scheduling, and events are an adequate fallback when metrics are unavailable (`plan/plan.md:44`).
- **Mechanism:** those surfaces can show reservation feasibility and hard/reactive failures, but they cannot reconstruct actual CPU/memory consumption or a short spike. Node pressure and OOM events appear late and are not a substitute for utilization telemetry.
- **Concrete falsifier:** **Action:** disable/remove the metrics result from the evidence set and ask the document to answer “Did CPU or memory spike during the change?” **If the fallback is honest:** it answers `UNKNOWN/BLOCKED`, provides only schedulability/hard-failure evidence, and states the missing telemetry. **If false:** it emits a utilization/headroom conclusion from requests or absence of pressure events.
- **Severity:** **HIGH**.
- **Required plan change:** Add a capability matrix: `actual utilization`, `reservation/schedulability`, `pressure/failure`. Mark only the first as blocked when Metrics API is unavailable; do not downgrade it into a stronger-looking proxy.
- **Residual risk:** Even available Metrics API data may be delayed/averaged and miss bursts; freshness must be printed with every conclusion.

### A8 — `PROVEN` is too coarse and permits command false greens

- **Claim attacked:** Each command status can be `PROVEN`, `BLOCKED`, or `NOT YET RUN` (`plan/plan.md:85`; `specs/01-spec.md:26-40`).
- **Mechanism:** a command can exit zero yet return an empty list, a wrong namespace/instance, truncated fields, stale data, or a view that does not discriminate desired from effective state. “Executed once” is not “fit for a live maintenance decision.”
- **Concrete falsifier:** **Action:** run each exact command against (a) the intended target and (b) a plausible wrong/empty namespace or mismatched object; inspect exit code, stderr, non-empty identity fields, timestamps, and semantic reconciliation. **If true:** the command emits target-bound evidence and fails closed or visibly disagrees in the wrong case. **If false:** both cases receive `PROVEN` or the wrong case produces an indistinguishable green table.
- **Severity:** **CRITICAL / BLOCKING** for the command-proof document.
- **Required plan change:** Replace `PROVEN` with staged proof: `EXECUTES`, `RETURNS TARGET DATA`, `SEMANTICS DISCRIMINATED`, and `MONITOR-READY`; require exact command text, shell, client version, capture time, exit/stderr result, and wrong-target/empty-result negative control.
- **Residual risk:** A command proven now can drift with permissions/context/session state; rerun the identity guard and a small canary immediately before maintenance.

### A9 — The live client/server skew is an unowned verification risk

- **Claim attacked:** The planned command surface is usable as live proof without a route change; context records `oc` 4.8.11 against OpenShift 4.20.16/Kubernetes 1.33.8 (`context/context-universe.md:60`).
- **Mechanism:** a very old client may parse, render, or discover newer server resources differently. One successful core-API command does not prove every watch, JSONPath/custom-column, metrics, or CRD command in the final guide.
- **Concrete falsifier:** **Action:** execute every exact command in the actual WSL shell with the installed client; where a server-compatible client exists, compare resource identity/count/fields. **If true:** outputs and watched transitions agree. **If false:** a command errors, omits fields/resources, or differs materially across clients.
- **Severity:** **HIGH**.
- **Required plan change:** Add client skew to the baseline and proof evidence, prefer a supported/matching client if already available, and mark any command not run with the actual maintenance client `NOT PROVEN`.
- **Residual risk:** Exact vendor support status is not established by these task files; until checked, do not claim the skew is supported.

### A10 — The baseline can be accurate and still be stale at start

- **Claim attacked:** One “Start here” current-state table plus later repeated probes provides the required starting point (`specs/01-spec.md:16`; `plan/plan.md:64`).
- **Mechanism:** HPA state, pod placement, restarts, and node load can change between preparation and 10:30. A reader may compare the maintenance against an older capture and attribute unrelated drift to CMC.
- **Concrete falsifier:** **Action:** capture a preparation baseline now and a T0 baseline immediately before the user signals maintenance start; compare identity, desired/effective counts, pod UIDs/nodes, restarts, resource samples, and application failures. **If true:** they match or pre-existing drift is separately recorded. **If false:** T0 already differs and the document has only the older “current” table.
- **Severity:** **HIGH**.
- **Required plan change:** Version the starting point with capture timestamps and add a mandatory T0 refresh/diff. Do not overwrite the earlier baseline; preserve both for attribution.
- **Residual risk:** Changes between T0 and the actual first CMC action require an event/watch stream and exact operator start time.

### A11 — Application summary can be green because status is stale or scope is sampled

- **Claim attacked:** Application summary plus failure-focused rows prevents application-red false success (`plan/plan.md:47-50`; `context/context-universe.md:50`).
- **Mechanism:** aggregate Healthy/Synced counts may remain unchanged while reconciliation stalls. Sampling can omit the affected app, and unrelated application drift can be misattributed to the replica change.
- **Concrete falsifier:** **Action:** record baseline totals/failure set and freshness indicators available to the user, then diff new/worsened failures and reconciliation timestamps during and after rollout. **If true:** no new stale/worsened cohort appears and scope is explicit. **If false:** counts stay green while freshness stops advancing, or a sampled view misses a failing application.
- **Severity:** **HIGH**.
- **Required plan change:** Define full-vs-sampled inventory, freshness signal, and before/during/after diff. Attribute only temporally correlated observations; retain alternative causes until evidence distinguishes them.
- **Residual risk:** Application status alone cannot prove end-user functionality; this maintenance proof should say that boundary plainly.

### A12 — Lens is requested, but it is not an independent truth source

- **Claim attacked:** Live resource visibility after `cmcfreelens dev` is adequate behavioral proof (`plan/plan.md:52-55`; `context/context-universe.md:35,73`).
- **Mechanism:** Lens can show a cached/stale resource list, a similarly named context, or a valid API with the wrong namespace filter. Seeing resources once does not prove the UI follows the maintenance transition.
- **Concrete falsifier:** **Action:** compare Lens cluster server/context/namespace and one changing target field or pod UID against the CLI at the same timestamp, then refresh/reopen the resource view. **If true:** identity and change agree. **If false:** Lens remains stale, points elsewhere, or omits the changed object while CLI advances.
- **Severity:** **MEDIUM** because CLI remains authoritative.
- **Required plan change:** Define Lens as a convenience view with a same-time parity check, not a second validation plane; record UI failure separately from cluster failure.
- **Residual risk:** UI refresh timing can still lag; never use Lens alone for a decision or attribution.

### A13 — No explicit stop/escalation/recovery decision exists

- **Claim attacked:** “repeat probes, record deltas/events, and update findings” is sufficient operator guidance (`plan/plan.md:64`).
- **Mechanism:** A new SRE can detect degradation but still not know when to notify CMC, refuse a success declaration, extend observation, or capture evidence before it expires. Lack of a decision rule turns monitoring into passive data collection.
- **Concrete falsifier:** **Action:** inject each scenario into the runbook reasoning: desired rises but available lags past rollout progress; Pending/FailedScheduling; new OOM/restarts; node pressure; new application regression; metrics unavailable. **If true:** each has an immediate action, escalation owner, evidence bundle, success/recovery condition, and bounded uncertainty. **If false:** the only instruction is “keep watching” or an invented generic threshold.
- **Severity:** **CRITICAL / BLOCKING** for a zero-context operator guide.
- **Required plan change:** Add an invariant-based decision table: `continue`, `challenge CMC`, `escalate`, `cannot verify`, and `recovered`, using controller deadlines/hard failure signals and evidenced local thresholds only. Explicitly avoid rollback/change commands because this task is read-only.
- **Residual risk:** Business stop/rollback authority and contractual thresholds remain external; document the owner who must decide them.

### A14 — CMC negligence framing can contaminate attribution

- **Claim attacked:** Findings during the maintenance can be reported as CMC mistakes when detected; the spec partially guards this with alternative explanations (`specs/01-spec.md:48-54,74`).
- **Mechanism:** temporal coincidence is not causation. Pre-existing pressure, HPA behavior, unrelated deployments, local AVD/Lens errors, or telemetry loss can occur during the same window.
- **Concrete falsifier:** **Action:** for every candidate finding, compare T0, exact first-observed timestamp, changed object/manager metadata when available, CMC action timestamp/statement, and at least one alternative cause. **If true:** evidence links the change mechanism to CMC's action or the entry is labeled only “observed during window.” **If false:** the finding assigns CMC ownership from timing alone.
- **Severity:** **HIGH** for reporting integrity.
- **Required plan change:** Make attribution an explicit state: `CMC-CONFIRMED`, `CMC-CORRELATED`, `PLATFORM`, `LOCAL-TOOLING`, or `UNATTRIBUTED`, with promotion evidence. Never use “negligent” as an evidence label.
- **Residual risk:** Without audit/change-record access, many actor claims cannot be promoted beyond correlated.

## Required plan/spec deltas before execution can be called ready

1. Gate on authorized target component and old→new count; otherwise use `UNATTRIBUTED` monitoring and no success verdict.
2. Add T0, during-transition, and stabilization phases with exact capture timestamps, sampling behavior, event/watch coverage, and an exit rule.
3. Split resource reasoning into actual utilization, scheduler reservation, and eligible placement; dynamically follow the actual nodes.
4. Replace generic replica readiness with component-specific service/effectiveness invariants.
5. Upgrade command proof from exit-zero to target-bound, negative-control, semantically discriminating, actual-shell/client execution.
6. Add stop/escalate/cannot-verify/recovered decisions for the new SRE.
7. Preserve evidence-safe attribution categories and baseline freshness.

## Primary cascade if these changes are not made

Unconfirmed target or snapshot-only count increase
→ wrong/unintended delta is accepted
→ pods appear Ready while placement, resource, component, or application signals lag
→ the findings log records a false success or falsely attributes a regression to CMC
→ the new SRE hands over an operational conclusion that the evidence cannot support.

## Recovery and proof ceiling

The plan is recoverable without any cluster mutation: sharpen the documents and execute the read-only negative controls/live probes. The current strongest defensible claim is **SOURCE-VERIFIED + ADVERSARIAL-ATTACKED**, not **BEHAVIORALLY MONITOR-READY**. Promotion requires the exact commands, actual WSL/client, current target, T0/during/stabilization observations, and separate verification receipts.
