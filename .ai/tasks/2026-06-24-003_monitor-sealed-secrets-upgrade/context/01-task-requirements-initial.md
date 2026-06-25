---
task_id: 2026-06-24-003
agent: codex
status: draft
summary: Initial requirements for monitoring the VPP PRD Sealed Secrets Operator upgrade.
---

# Initial Requirements

## User Request

Prepare commands and a reusable script to monitor the CMC-performed upgrade:

> Sealed Secrets Operator [VPP-PRD] 2.7 -> 2.18 [CHG0504405] on the Production environment for VPP on Wednesday, June 24 at 14:30.

The user explicitly requires use of the AVD/Windows app via computer-use because a terminal is already logged in to production `oc`.

## Classification

- Domain class: implementation plus operations monitoring.
- Control-plane artifact: no for the task-local script; production OpenShift observations are high-impact read-only operations.
- Surface: OpenShift runtime, likely operator/controller upgrade.
- Route: prepare read-only monitoring script locally, then use computer-use to operate the AVD terminal for live `oc` probes.

## Success Criteria

- Identify meaningful monitoring signals for Sealed Secrets Operator upgrade health.
- Create a read-only script that can run in the logged-in production `oc` session.
- Script must avoid mutation, avoid secrets exposure, and distinguish "no resources found" from healthy.
- Script must produce actionable signals: cluster target, operator deployment/pods, version images, CRDs, SealedSecret counts, recent events, controller logs, and sampled reconciliation state.

## Route-Flip Assumptions

- If the AVD terminal is not logged into VPP PRD, live probes must stop until the user or CMC confirms the right context.
- If the operator namespace or labels are not discoverable, the script must report that explicitly rather than returning a green status.
- If no SealedSecret resources exist in VPP PRD, the monitor pivots to operator/CRD/API readiness and workload secret-consumer smoke checks.

## Safety

Read-only commands only: `oc get`, `oc describe`, `oc logs`, `oc auth can-i`, `oc whoami`, and local shell inspection. No `oc apply`, `delete`, `patch`, `rollout restart`, secret decoding, or GitOps sync actions.
