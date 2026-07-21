---
task_id: 2026-07-20-001
agent: codex
status: active
summary: Initial requirements and risk model for live DEV Argo CD replica-maintenance preparation and monitoring.
---

# Initial task requirements

## Request and end state

Prepare and live-prove safe, read-only OpenShift and Argo CD monitoring commands in the already-open Windows AVD DEV session, configure Lens for the DEV cluster, write the confirmed probe guide and maintenance findings log at the two user-named paths, and wait for the user's explicit start signal before continuous maintenance monitoring.

The accepted outcome is a set of commands that were actually executed successfully against the intended DEV cluster, explain desired/current/ready replicas and node/resource implications, and distinguish a healthy rollout from Pending pods, degraded Argo CD health, capacity pressure, or events. Commands that cannot be proven must be labeled blocked rather than presented as ready.

## User pre-framing

Verbatim: "Be effective, and pragmatic. Skip ceremonies that;ll consume precious time."

My read: compress paperwork and prioritize live discriminating probes; never compress credential safety, environment identity checks, read-only scope, or independent challenge.

## Classification

- DOMAIN-CLASS: implementation plus investigation
- CONTROL-PLANE-ARTIFACT: no
- OPS-SHAPE-ATTRIBUTE: read-only cluster inspection plus reversible Lens client configuration
- Phase Compression Mode: Full, because this is a live operational investigation with credential exposure and time-sensitive monitoring decisions

## CRUBVG

- C=2: AVD, WSL, OpenShift, Argo CD operator resources, pods, nodes, metrics, Lens, and files are coupled.
- R=1: probes are read-only; Lens configuration is reversible but mutates local client state.
- U=2: Argo CD namespace, instance, CR shape, metrics availability, and permissions are unknown.
- B=1: DEV-only and read-only, but the findings guide a live maintenance decision.
- V=1: commands can be executed live, while some monitoring behavior must be witnessed during the change.
- G=1: the live login is visible, but authoritative resource topology has not yet been discovered.
- Total=8.

## System view and frames

The OpenShift API exposes Argo CD desired state, managed controller workloads, pods, scheduling, nodes, metrics, events, and application health. CMC changes desired replicas; the operator reconciles controller objects; the scheduler places new pods; node capacity and Argo CD readiness/health reveal whether the change is safe. Lens is a secondary visualization consumer of the same kubeconfig/API, not an independent truth source.

- Operator frame: the on-call engineer needs baseline, change, and convergence signals that separate harmless rollout churn from real degradation.
- Security frame: the login token visible in the supplied screenshot must not be transcribed, persisted, or echoed.
- Goal-fidelity frame: exact user-named files must contain live-proven commands and teachable findings, not speculative runbook text.
- Indirect break: scaling consumes schedulable resources; capacity pressure can delay unrelated workloads even when Argo CD itself eventually becomes Ready.

## Counterfactual

Without a pre-change baseline and tested command set, an increase could appear successful because the desired count changed while replicas remain unavailable, pods are Pending, applications become degraded, or node pressure rises unnoticed.

## Success criteria

1. The live context proves the intended DEV API/server and identity without recording credentials.
2. The Argo CD instance, namespace, desired replicas, controller workload counts, pods, nodes, and metrics capability are discovered without writes.
3. Each documented command has safe live evidence or an explicit blocked status and promotion probe.
4. Node/resource interpretation uses measured baseline, allocatable capacity, requests/limits, and change deltas; no universal threshold is invented.
5. Lens is connected through a reversible kubeconfig/catalog flow if supported by the available UI and permissions.
6. Both exact Markdown targets are preserved and updated, with no secret material.
7. An isolated operational adversary attacks false-green and wrong-target assumptions, and an independent verifier checks the final claims.

## Hypotheses

- H1: OpenShift GitOps is operator-managed and the desired replica fields are readable from an ArgoCD custom resource. Eliminate if no accessible CR or if fields do not drive managed workloads.
- H2: Effective replica state must be read from Deployments/StatefulSets because the CR is inaccessible or version-specific. Eliminate if CR and managed workload counts correlate and ownership is proven.
- H3: node-level live metrics are available through the admin-top surface. Eliminate on authorization or metrics API failure; fall back to node allocatable, requested resources, conditions, scheduling, and events.
- H4: Lens can reuse a sanitized/exported DEV kubeconfig from the already authenticated session. Eliminate if UI/import paths or filesystem bridging are blocked; document CLI as the authoritative surface and mark Lens blocked.

## Specialty and triggers

- SPECIALTY: computer-control; Eneco SRE and MC-VPP domain knowledge; Feynman teaching; SRE failure-path adversary; independent verification.
- LIBRARIAN: no initially; live cluster is authoritative. Add official OpenShift documentation only where it teaches a load-bearing public mechanism.
- FRAME-PRIMARY: SRE plus Socrates.
- EVALUATOR: yes.
- DOMAIN: yes, Eneco SRE/MC-VPP.
- TOOLS: yes.

## Brain scan and frame commitment

Dangerous assumption: the current `eneco-vpp` project is the Argo CD control-plane namespace. The cheapest falsifier is a cluster-wide, read-only discovery of ArgoCD custom resources and GitOps-labeled workloads, followed by owner/resource reconciliation.

Likely failure: a syntactically valid command selects the wrong instance, or a pod count is mistaken for desired/ready/available convergence.

Opposite-conclusion prediction: if the prepared probe set is not actually ready, a fresh execution will fail, return zero or ambiguous resources, or produce desired/current/ready counts that do not reconcile across CR, workload, pod, and node views. If ready, the same identifiers and counts will connect those layers and discrepancies will have a known explanation.

Frame commitment: dispatch an isolated SRE adversary with the user's original request and require a task-local attempted-attack ledger before finalizing the probe set. A separate verifier must challenge final command evidence and secret hygiene.

