---
task_id: 2026-07-20-001
agent: codex
status: complete
summary: Executed plan for DEV proof, incident separation, Feynman documentation, bounded ACC preparation, Lens-last attempt, independent review, and current-byte closure.
---

# Plan

## Safety invariant

No cluster-changing command is in this plan. Individual baseline probes may run before maintenance; continuous monitoring waits for the user's explicit start signal. Local Lens configuration is limited to the authenticated DEV kubeconfig/context.

Preparation status is **CONDITIONAL — CMC TARGET AND OLD→NEW COUNT NOT YET CONFIRMED**. Until an authoritative statement or unambiguous live change identifies them, all observed deltas are `UNATTRIBUTED`; no success verdict or CMC attribution is allowed.

## Topology and independent roles

- Root: live AVD inspection, evidence reconciliation, Lens configuration, and the three exact Markdown outputs.
- Isolated SRE adversary (`codex-sre-maniac`): attack false-green, capacity, temporal, and verification-method failure modes. If it finds a missing discriminating signal, add and prove that signal before calling the command set ready.
- Isolated goal adversary (`codex-socrates-contrarian`): attack ask-to-deliverable divergence from the user's original words. If the new-SRE or live-proof contract is missing, change the document architecture or acceptance tests before writing final content.
- Later verifier (`codex-verification-engineer`): independently check live-evidence-to-command claims and plausibly-wrong cases.
- Later fresh reader (`codex-principal-engineer-document-writer` or equivalent): attempt to learn the system from `probes-explanation.md` without coordinator context.
- Later assurance grader (`codex-apollo-assurance-marshal`): grade receipts and evidence sufficiency; different from primary verifier.

## Steps and conditional premises

1. **Lock the target identity.**
   - Premise: the intended API is DEV and target CR is `eneco-vpp-argocd/eneco-vpp`.
   - Proof: server, context, resource discovery.
   - If a different instance shows the maintenance delta, retain the identity guard and route monitoring to that evidenced instance; do not silently switch.

2. **Capture desired configuration and autoscaling.**
   - Premise: the ArgoCD CR and HPA surfaces expose replica control.
   - Proof: component replica fields, autoscaling flags/bounds, and HPAs.
   - If CR fields are absent, use explicit absent/default state plus owned workload/HPA evidence; never print an empty field as zero.
   - If HPA is enabled, treat HPA desired/current/bounds as effective control and explain why a literal replica field is not authoritative.
   - Build a complete component matrix rather than assuming the scaled component: CR field, control mode, owned workload, replica states, pod request/limit, placement constraints, current nodes, and proof reference.

3. **Capture realized workloads and placement.**
   - Premise: managed Deployments/StatefulSets and pods expose desired/current/ready/available truth.
   - Proof: workloads, pods with node placement, owner links, restart/readiness state.
   - If counts disagree, route to rollout status, conditions, events, and targeted describe/logs; do not call the change successful.

4. **Capture resource cost and node headroom.**
   - Premise: metrics API plus requests/limits/allocatable expose current use and schedulability.
   - Proof: pod/container usage, hosting-node usage, resource requests/limits, allocatable and conditions.
   - Split the evidence into three non-interchangeable panes: actual utilization, scheduler reservation, and placement eligibility/events.
   - Compute component-specific reservation delta as `replica delta × effective per-pod request`; show limit delta separately; measure consumption independently.
   - Record current pod→node placement, pod-template node selectors/affinity/tolerations/topology constraints, eligible nodes as far as permission allows, and dynamically follow every new pod's actual node.
   - If metrics are forbidden/unavailable, mark utilization/spike detection `UNKNOWN/BLOCKED`; requests/limits, allocatable, conditions, scheduling, and events prove only reservation/schedulability/hard failures.
   - If no Eneco/CMC threshold is evidenced, state no contractual threshold and use delta/headroom plus hard failure indicators.

5. **Capture service-level outcome.**
   - Premise: Argo CD application sync/health and component availability are observable.
   - Proof: application summary plus failure-focused rows, events, and component conditions.
   - Check component-specific usefulness: endpoint membership for serving components; restart/error evidence on regression; controller/repository reconciliation/freshness where visible; application before/during/after failure-set and freshness deltas.
   - If application inventory is too large or permission-limited, document full-versus-sampled scope and do not generalize a sampled view to all applications.

6. **Configure and verify Lens.**
   - Premise: `cmcfreelens dev` makes the DEV context available to Freelens/Lens.
   - Proof: open the imported cluster and observe live `eneco-vpp-argocd` resources/API server.
   - If import succeeds but resources do not load, record Lens as behaviorally blocked and retain CLI as the authoritative monitoring route.

7. **Write the three documents using one evidence vocabulary.**
   - Premise: observed baseline, command proof, and event learning are distinct reader jobs.
   - If duplicating a concept risks drift, `probes-explanation.md` owns the mental model, the probe guide owns commands, and the findings log owns time-bound observations; cross-link them.

8. **Verify and stop at the correct boundary.**
   - Premise: preparation can be finalized before the maintenance timeline exists.
   - If maintenance has not started, deliver readiness/baseline status and wait; do not fabricate during/after findings.
   - Label every command `PREP-ONCE`, `START-GATED-REPEAT`, or `FAILURE-ONLY`. Before the recorded user start signal, prohibit watches, loops, polling, sleeps, and repeated cadence.
   - When the user starts maintenance, capture a fresh T0, repeat monitor-ready probes, record deltas/events, and update findings without changing cluster state.
   - Preserve the preparation baseline and T0 separately. Observe transition and stabilization; do not stop at the first green snapshot.

## Change-intent and temporal contract

Before a success verdict, require namespace, ArgoCD instance, component(s), old count, intended new count, and maintenance window from CMC/user evidence or a clearly identified changed object. If missing, monitor every component but keep the result conditional and `UNATTRIBUTED`.

The operational default—explicitly not a contractual Eneco threshold—is:

- workload/pod/event/application state every 15 seconds during the active change;
- resource metrics no faster than 60 seconds so new samples can arrive;
- stabilization only after desired/current/updated/ready/available agree, no Pending/FailedScheduling or new restarts/failure events occur, and at least two fresh resource samples plus five minutes of stable service/application evidence have been observed.

Any CMC-defined window or component progress deadline supersedes this observer default and must be recorded. A single green sample never closes the watch.

## Proof-state contract

Command proof is cumulative:

1. `EXECUTES`: exact command ran in the actual WSL shell/client with recorded exit/stderr result.
2. `TARGET DATA`: output is non-empty or handles absence explicitly and binds API/namespace/object/time.
3. `SEMANTICS DISCRIMINATED`: a wrong-target, empty-field, or desired-only plausible error produces a visibly different/rejected result.
4. `MONITOR-READY`: the command participates in the live decision ladder and has a fallback/next action.

`PROVEN` alone is forbidden. The installed client/server skew must be printed, and every exact maintenance command must be run with that client or remain not proven.

## Decision and attribution contract

The new-SRE table must map invariant violations to `continue`, `challenge CMC`, `escalate`, `cannot verify`, or `recovered`, without authorizing cluster changes. Attribution states are `CMC-CONFIRMED`, `CMC-CORRELATED`, `PLATFORM`, `LOCAL-TOOLING`, or `UNATTRIBUTED`; timing alone cannot promote an observation to CMC fault.

## Six adversarial questions

1. **Main mechanism:** desired state is reconciled through operator-owned workloads; the discriminating observation is CR/HPA desired changing followed by workload and pod readiness convergence. A wrong-target command can still return healthy counts but will not share the target identity or observed delta.
2. **Simplest alternative:** `oc get pods` alone is cheaper but insufficient; it cannot distinguish operator desire, rollout progress, autoscaling, or capacity cause.
3. **Disproof:** run the reconciliation ladder. If desired changes but ready/available remain lower and events show scheduling/probe failures, the claim “replica increase succeeded” is false. If all layers converge on the same target without failure evidence, it survives.
4. **Hidden complexity:** concise documents can move complexity into unstated defaults. The explanation must explicitly distinguish absent fields, operator defaults, HPA control, and effective workloads.
5. **Live claims:** target identity, version, CR fields, workload counts, metrics availability, and Lens visibility all require live execution. Official docs only explain mechanisms.
6. **False-green verification:** commands can exit zero on the wrong namespace, show desired instead of ready, omit unavailable pods, or rely on incomplete metrics. Cross-plane identity/count/node/application checks must disagree in those plausible-wrong cases.

## Runtime attacks to record

- Wrong-instance discriminator: compare namespace/name/API before accepting counts.
- Desired-only false green: require ready/available and pod reconciliation.
- Metrics-unavailable case: prove fallback preserves schedulability/pressure evidence but downgrades consumption claims.
- Lens-catalog false green: require live resource view.
- Secret hygiene: search final documents and task evidence for token-shaped material without echoing any credential value.
- Target intent: compare the changed object/count with the change-intent contract; absent contract means no success verdict.
- Temporal false green: continue past first readiness convergence and test for late restarts, errors, resource deltas, or application regression.
- Scheduler false green: verify current nodes, eligibility constraints, and actual new placement rather than cluster-average metrics.
- Capability false green: remove metrics and ensure the conclusion becomes `utilization UNKNOWN`, not a proxy claim.
- Fresh-reader transfer: give a novel desired/ready/Pending scenario without the answer and require a causal diagnosis plus next two probes.

## Verification strategy

- Each command receives the cumulative proof states above, or an explicit `BLOCKED`/`NOT YET RUN` state.
- Screenshots/task artifacts prove execution; user-facing docs contain sanitized outcomes.
- Sanitized text evidence is preferred. Any retained screenshot must be visually reviewed before use, contain no token/raw kubeconfig/secret prompt, and never be the sole proof. The original user screenshot is not retained in the repository.
- Final verification maps every factual baseline value to a live observation and every teaching claim to live evidence or official documentation.
- Findings from adversaries receive Accept/Rebut/Defer dispositions with changed evidence or explicit residual risk.

## Transition ledger

Map revealed three Argo CD instances, falsifying the implicit idea that the current `eneco-vpp` project identified the control plane. H1 remains leader because the target CR exists; H2 is promoted from fallback to mandatory effective-state proof. The dangerous unknown is the exact component/target count. The cognitive trap caught was familiarity: assuming a conventional `openshift-gitops` namespace would have monitored the wrong instance.

Leader: CR plus owned-workload reconciliation.
Runner-up: workload-only inference.
Evidence advantage: an actual target CR exists and the operator contract is documented.
Cheapest flip: live replica/autoscale fields and HPA inventory.

What I was most wrong about: the starting project did not contain the Argo CD control plane; cluster-wide discovery was necessary once, but direct namespace probes should now replace it.

## Continuation after DEV maintenance completion

The user closed the DEV watch and redirected the task to documentation quality and Acceptance readiness. The transferable mechanism is not “reuse the DEV commands unchanged”; it is “reuse the evidence ladder while rebinding identity, baseline, topology, and historical deltas to ACC.”

9. **Close DEV without promoting correlation into causation.**
   - Premise: the last observed samples were stable and the user has stated maintenance is over.
   - If a late hidden failure exists outside the observed window, the record cannot exclude it; final wording must say “stable across the observed proof layers,” not “all services were unaffected.”

10. **Make environment identity non-optional.**
    - Premise: DEV and ACC tabs share kubeconfig state.
    - If `oc whoami --show-server` does not equal the expected API immediately before a block, reject that block as local-tooling evidence and do not write its values into either environment record.

11. **Transfer the evidence method to ACC.**
    - Premise: ACC currently resembles DEV's pre-change topology but has its own restart/resource/node baseline.
    - If CMC's authorized ACC targets differ from the DEV-observed topology, replace expected counts while preserving CR → workload → pod → node → endpoint → application → time verification.

12. **Teach the mechanism, not a command catalogue.**
    - Premise: a new SRE needs causal connections before operational compression.
    - If a term cannot be linked to “what it tells me, what it cannot prove, and what I do next,” expand or remove it.

13. **Validate transfer and learning independently.**
    - Premise: Markdown shape and command execution do not prove operator comprehension or safe live use.
    - If the SRE adversary can create a wrong-cluster, desired-only, first-green, restart-baseline, Redis-topology, or resource-headroom false green, revise the runbook before it is ready.
    - If a zero-context reviewer cannot explain a novel `Synced Progressing` or desired/ready/Pending scenario, revise the syllabus before completion.

### Continuation transition

DEV revealed that the most dangerous portability bug is shared state outside the visible tab: an ACC login changed what a DEV-labelled shell would query. H2 therefore wins over literal command reuse. The cognitive trap was location/identity complecting—treating a UI tab label as a kubeconfig context boundary. The cheapest discriminator is the API identity line immediately before every accepted capture.

## Accepted operational controls from the ACC attack

The SRE attack destroyed warning-only identity, count-only restart, Ready-only topology, command-time-as-metrics-time, and first-green stabilization. The runbook must implement these controls:

1. capture the ACC context once only after verifying its API, then pass `--context "$ACC_CONTEXT"` to every command; reassert the pinned API per sample and discard a whole mixed/failed sample;
2. require authoritative CMC intent fields before `COMPLETE AS INTENDED`; observed deltas may route probes but cannot authorize themselves;
3. key Pod history by UID/creation time/container/revision/node, so replacement preserves predecessor evidence;
4. compare generation/observedGeneration and revision-aware Deployment/StatefulSet vectors, not `READY` alone;
5. test Redis as a topology: old standalone path, HAProxy, Redis/Sentinel StatefulSet, Services, EndpointSlices, events, and explicitly unverified quorum if no read-only signal exists;
6. join EndpointSlice ready backends to expected ready Pod UIDs for serving components;
7. separate per-node measured use, allocatable/request reservation, placement eligibility, and actual new-pod placement;
8. call metrics fresh only if timestamp/window advances and new Pod coverage is present; otherwise label utilization `UNKNOWN`;
9. summarize the complete Application count/status distribution or label fleet coverage incomplete; use `reconciledAt` advancement where available after controller recreation;
10. use one-pass, non-overlapping fast and slow samples with start/end/duration and explicit failure/missed-sample states; observed cadence replaces claimed cadence;
11. stabilization is the maximum of component convergence, two advancing metrics samples when available, one post-change freshness signal when available, the declared minimum observation interval, and a late-checkpoint/handoff; CMC coordination timing cannot erase evidence insufficiency;
12. preserve event deltas; an empty query means only “none returned at this timestamp.”

If a control's required signal is permission- or capability-blocked, the affected claim becomes `CANNOT VERIFY`; another green layer cannot substitute for it.
