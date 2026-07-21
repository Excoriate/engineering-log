---
task_id: 2026-07-20-001
agent: codex
status: active
summary: Concrete content and evidence specification for the three operational Markdown deliverables.
---

# Specification

## Deliverable 1: `probes-explanation.md`

Purpose: first read for a zero-context SRE.

Required shape:

1. `Start here` fact table with capture time, DEV API, namespace, ArgoCD instance, component replica configuration, autoscaling, requests/limits, realized workloads, pods, and nodes.
2. `Before the first probe`: AVD/Windows App -> Ubuntu/WSL boundary, required access, secret-safe identity guard, user-only credential/MFA handling, session-expiry stop, `cmcfreelens dev` location/effect, and CLI-only fallback.
3. A compact source-to-outcome diagram showing CMC -> ArgoCD CR/HPA -> workloads -> pods -> scheduler/nodes -> Argo CD application outcome.
4. A complete per-component matrix: CR field, controller mode, owned workload, replica states, resources, placement constraints, current nodes, and proof status.
5. Plain-language explanations of desired/current/updated/ready/available, why they diverge, and the difference between reserved requests, configured limits, measured use, eligible placement, and actual node placement.
6. Fixed-replica versus HPA branch.
7. New-SRE decision ladder and examples of healthy convergence versus false green, including stop/escalate/cannot-verify/recovered actions.
8. Knowledge contract, challenge defense, self-test with answers, evidence ledger, visual coverage note, and official-doc expansion links as required by the Feynman skill.
9. An answer-hidden transfer scenario where the reader diagnoses desired=3/ready=2/one Pending, chooses the next two probes, and states what would change the diagnosis.
10. No universal capacity threshold presented as an Eneco rule without evidence; threshold provenance classes are contractual, hard failure, schedulability/headroom, and baseline-relative observation.

## Deliverable 2: `argocd-openshift-command-probes.md`

Purpose: command surface for preparation and live monitoring.

Each probe must state:

- goal;
- exact read-only command;
- live proof status and capture time;
- what signal means;
- healthy pattern;
- unhealthy/ambiguous pattern;
- next probe;
- permission/metrics fallback;
- safety notes.
- execution class: `PREP-ONCE`, `START-GATED-REPEAT`, or `FAILURE-ONLY`;
- cumulative proof state: `EXECUTES`, `TARGET DATA`, `SEMANTICS DISCRIMINATED`, `MONITOR-READY`;
- target identity, capture timestamp, client version, sanitized evidence reference, and negative control.

Organize as identity guard, component matrix/baseline, hard start gate, fast repeat, stabilization, discrepancy drill-down, node/KIV control, Lens verification, and post-change comparison. A command must not be labeled proven merely because it exited zero or a similar command worked.

## Deliverable 3: `maintenance-july-20-records-findings.md`

Purpose: append-only operational evidence and learning.

Required shape:

- planned scope and evidence rules;
- pre-maintenance baseline;
- chronological event table;
- numbered finding template: timezone, first/last observed, baseline/capture ID, probe ID, exact sanitized evidence pointer, observation, evidence, mechanism, impact, alternative explanation/falsifier, attribution state, action, owner, status;
- explicit separation of CMC-attributable evidence from local tooling or platform conditions;
- before/after replica and resource delta table;
- unresolved questions and handoff.
- an exact recorded user start signal/time before any repeated probe entry.

## Actionable inventory

| Source | Derived artifact | Consumer/validator | Blocked residual |
|---|---|---|---|
| Live OpenShift DEV API | sanitized baseline facts | new SRE, independent verifier | maintenance delta not available before start |
| Official Red Hat docs | mechanism explanations | Feynman validator, fresh reader | docs do not prove installed behavior |
| AVD screenshots | proof status | verifier | token-bearing screenshot excluded |
| DEV kubeconfig helper | Lens catalog/view | live UI check | UI may fail independently of CLI |
| User start signal | maintenance timeline | findings log | cannot be fabricated before signal |

## Looks-correct-while-wrong cases

- Correct command on the wrong Argo CD instance.
- CR desired replicas increase, but workloads or pods do not converge.
- Pod count rises, but readiness/availability or applications degrade.
- Node total usage looks acceptable while the hosting node has insufficient allocatable headroom or pressure.
- `oc adm top` is unavailable, and the document silently treats resource requests as actual consumption.
- Lens context is imported but disconnected or pointed to a different API.
- A local AVD input/tooling error is attributed to CMC.
- A generic 80/90-percent threshold is mislabeled as an Eneco contract.

## Spec adequacy

The targets, evidence lanes, blocked residuals, and false-green cases are concrete. Adequacy remains conditional on the isolated plan attacks; any accepted finding must change a plan step or this specification before live proof resumes.

## Continuation deliverables

### `maintenance-july-22-records-findings.md`

Own the ACC T-minus baseline: explicit API/namespace/CR, current workload and pod counts, historical restarts, resource and placement baseline, current applications, no-event result, hypothesized DEV-equivalent delta, exact evidence boundary, and an empty start-gated ledger. It must explain why each baseline matters to Wednesday attribution.

### `argocd-replica-increase-acceptance-runbook.md`

Own the operator sequence. Required sections: scope/safety; terminology-in-context; shared-kubeconfig identity gate; preparation checklist; CMC intent contract; T0 capture; fast watch; slow resource watch; Redis topology and EndpointSlice verification; pod-to-node following; application interpretation; stabilization rule; discrepancy drills; decision ladder; evidence-writing template; end-state handoff; self-test and answer. Every command is read-only and environment-bound.

### `argocd_replica_increase_explained.md`

Own the 360-degree mental model. Required sections: knowledge contract; maintenance in one sentence; Git/Argo CD/Kubernetes first principles; operator/CR/reconciliation; component roles; workload, pod, service, EndpointSlice, node, request/limit/use concepts; replica and HA effects; DEV before/after and ACC before architectures with trust boundaries; temporal model; sync/health interpretation; scheduling/resource mathematics; false-green paths; worked scenario; self-test/answers; evidence ledger and official links. Diagrams must encode real relationships, not decorate headings.

### Continuation looks-correct-while-wrong cases

- A terminal tab says DEV while shared kubeconfig targets ACC.
- ACC begins with historical restart count `1`; an operator reports the old restart as new.
- Server and repo replica counts converge, but Redis silently remains standalone when HA was intended.
- Services exist, but EndpointSlices do not contain the new ready backends.
- All pods are Running at one instant, but late restarts or application progression occur during stabilization.
- `Synced Progressing` is misread as contradictory or automatically harmful.
- Low current CPU is treated as scheduler capacity despite requests, constraints, or node eligibility.
