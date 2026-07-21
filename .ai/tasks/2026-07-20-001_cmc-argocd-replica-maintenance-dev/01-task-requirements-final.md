---
task_id: 2026-07-20-001
agent: codex
status: active
summary: Confirmed requirements after DEV completion and the Acceptance runbook and first-principles syllabus additions.
---

# Final requirements

## Scope delta from initial requirements

The original documents remain required and must be improved in Feynman style. DEV monitoring is now closed by the user's maintenance-over signal. The continuation adds an Acceptance pre-maintenance baseline for Wednesday, a transferable operator runbook, and a self-contained first-principles syllabus with architecture diagrams. The documents must explain concepts in the context of the operator decision instead of assuming vocabulary.

## Required user-facing outputs

1. `probes-explanation.md`: current-state baseline and first-principles mental model for a new SRE.
2. `argocd-openshift-command-probes.md`: tested read-only command set, expected signal, interpretation, failure meaning, and KIV controls.
3. `maintenance-july-20-records-findings.md`: timestamped baseline, event/finding ledger, and learning-oriented explanation without attributing fault beyond evidence.
4. `maintenance-july-22-records-findings.md`: Acceptance baseline and append-only Wednesday evidence ledger.
5. `argocd-replica-increase-acceptance-runbook.md`: identity-safe, read-only Wednesday operating sequence derived from DEV evidence but parameterized for ACC.
6. `argocd_replica_increase_explained.md`: dense, self-contained Feynman syllabus covering Argo CD, Kubernetes, replica scaling, resources, scheduling, signals, architecture, and failure interpretation.

## Confirmed operating boundary

- DEV evidence is closed against `https://api.eneco-vpp-dev.ceap.nl:6443`; Wednesday preparation targets `https://api.eneco-vpp-acc.ceap.nl:6443`.
- Target: `eneco-vpp-argocd/ArgoCD/eneco-vpp` unless live evidence proves CMC is changing a different discovered DEV instance.
- Allowed cluster actions: read-only `get`, `describe`, `top`, version/identity, and logs only when a failure requires them.
- Allowed local action: configure Lens/Freelens to consume the authenticated DEV context and behaviorally verify a live cluster view.
- Forbidden without new user authority: apply, edit, patch, scale, delete, rollout restart, sync, terminate, or mutate any cluster resource.
- Credentials and token values must never be copied to files or chat.
- Continuous/repeated monitoring begins only after the user says maintenance has started; preparation may execute individual baseline probes now.
- Terminal tab names are not identity boundaries because `oc login` updates shared kubeconfig state. Every environment sample must prove the API immediately before accepting output, preferably through explicit `ocacc`/`ocdev` wrappers.

## Acceptance criteria

1. A fresh SRE can name the target cluster, namespace, ArgoCD instance, components, desired/effective replicas, autoscaling state, resource requests/limits, and pod placement from the baseline document.
2. Every command labeled `PROVEN` was executed successfully in the live DEV session; any unexecuted or permission-blocked probe is labeled honestly.
3. Replica proof distinguishes desired, current, updated, ready, and available state and explains transient divergence.
4. Capacity proof identifies the nodes hosting Argo CD before the change and compares pod/node CPU and memory before versus after. Contractual thresholds are not invented.
5. KIV rules identify false-green states: desired changed but ready did not converge, Pending/Unschedulable, pressure/OOM/restarts, or Argo applications becoming unhealthy.
6. Lens shows the same DEV cluster live, or the exact UI/capability blocker and CLI promotion path are recorded.
7. The findings log has a baseline plus an append-only evidence structure that separates observation, interpretation, impact, action, owner, and resolution.
8. Independent adversarial and verification receipts survive, including a fresh-reader check of the Feynman explanation.
9. DEV has a final, evidence-bounded verdict that distinguishes observed stability, CMC correlation, and unconfirmed actor intent.
10. The ACC runbook prevents wrong-cluster sampling, preserves historical restart baselines, follows new pods to actual nodes, and prefers EndpointSlice over deprecated legacy Endpoints.
11. The syllabus lets a new SRE explain `Application`, `Synced`, `Healthy`, `Progressing`, CR, operator reconciliation, Deployment, StatefulSet, Service, EndpointSlice, request, limit, measured use, scheduling, readiness, and stabilization in this exact maintenance.

## Verification strategy

- Identity guard before cluster facts.
- CR -> HPA -> workload -> pod -> node -> events -> Argo application outcome reconciliation.
- Capture live screenshots as task-local evidence; publish no secret-bearing image.
- Execute a plausibly-wrong discriminator: a CR desired count alone must not pass if ready/available, pods, or node evidence disagree.
- Lens verification requires opening the cluster and observing live resources, not merely importing a context.
- Run the Feynman validator and an independent fresh-reader review on the completed explanation.

## Counterfactual and route-flip assumption

Without this baseline, CMC could change the right field while the operator, scheduler, or workloads fail to realize it, and a new SRE would have no way to explain the gap. The route-changing assumption is whether a component is fixed-replica or HPA-controlled; the live CR/HPA probes decide that before thresholds or expected counts are stated.

## Remaining external dependency

The planned target count, CMC's named component, and any approved organizational CPU/memory thresholds have not been supplied. The documents must show observed baseline and observed change, label the intended target as pending until evidenced, and use failure conditions plus headroom/delta rather than pretending a universal percentage is an Eneco contract.
