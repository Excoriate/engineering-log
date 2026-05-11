---
task_id: 2026-05-11-005
slug: cmc-alert-vpp-cluster-prod
phase: 1
status: complete
agent: claude-opus-4-7
summary: Initial task requirements mirror of P1 preflight for CMC / vpp-resource-unhealthy disaster alert on Eneco VPP production cluster.
---

# Task 2026-05-11-005 — Initial Requirements

## Request (verbatim)

> Here, troubleshoot and /rca-holistic this issue; `/Users/.../02_on_call_shift/2026_05_11_cmc_alert_vpp_cluster_prod` — `https://portal.azure.com/#view/Microsoft_OperationsManagementSuite_Workspace/Logs.Rea[…]icrosoft.OperationalInsights%2Fworkspaces%2Fvpp-log-analyt-p`. Need a proper rca. You are not able to reach production clusters; since they're openshift clusters; but at least, the necessary oc commands that I can run on my end, it also helps. From the azure side, you have all u need /eneco-tools-tradeit-mc-environmnets.

## User pre-framing

Operational, not urgency-pressuring. "Proper RCA" anchors quality bar at `/rca-holistic` skill discipline + on-call-incident-workflow rule (L1-L12, A1/A2/A3 evidence, context ledger). Tone does NOT waive any gate.

## Alert identity (A1 FACT from ServiceNow ticket)

- **Alert name**: `vpp-resource-unhealthy`
- **Alert type**: `Microsoft.Insights/scheduledQueryRules` (KQL log alert)
- **Resource ID**: `/subscriptions/f007df01-9295-491c-b0e9-e3981f2df0b0/resourceGroups/mcprd-rg-vpp-p-res/providers/microsoft.insights/scheduledqueryrules/vpp-resource-unhealthy`
- **Subscription**: `f007df01-9295-491c-b0e9-e3981f2df0b0` (Eneco VPP production)
- **Resource group**: `mcprd-rg-vpp-p-res`
- **Workspace**: `vpp-log-analyt-p` (Log Analytics)
- **Namespace**: `eneco-vpp-prd` (OpenShift)
- **Business Service**: MCLZ - OpenShift Platform
- **Host**: Eneco MCC - Production - Workload VPP
- **Severity**: Disaster (sev 0)
- **Fired at**: 2026-05-11 15:13:50
- **Intake channel**: ServiceNow (NOT Rootly — this is a key intake-lane fact)
- **Acknowledged**: No (at time of intake)

> Note: the description "CMC alert" in the user request is shorthand. The Eneco CMC (Cloud Managed Container?) acronym is not in the ubiquitous-language yet — TBD in P2 via wiki/repo lookup. The actual Azure alert name is `vpp-resource-unhealthy`.

## Classification

- DOMAIN-CLASS: investigation (RCA)
- CONTROL-PLANE-ARTIFACT: false (writes incident log files + task workspace; no brain/skill/hook/rule edits)
- CRUBVG: 10 (C1/R0/U2/B2/V2/G2 + G≥1→+1). Phase Compression Mode: Full.

## Verification capability surfaces

| Surface | Owner | Constraint |
|---------|-------|------------|
| Azure resource state, alert rule definition, fired alert payload, activity log, Log Analytics query | Coordinator via `/eneco-tools-connect-mc-environments` (PRD MC SP) | Read-only role required; if absent → escalate via dev SP cross-reference or `[UNVERIFIED[blocked]]` |
| OpenShift cluster state in `eneco-vpp-prd` namespace | User (runs `oc` on jumphost) | Coordinator produces command sheet; user produces output |
| MC-VPP-Infrastructure IaC (alert rule HCL + KQL query) | `eneco-context-repos` subagent | Read source code from ADO |
| Eneco wiki + runbooks | `eneco-context-docs` subagent | Look for `vpp-resource-unhealthy` documented runbook |
| Recent IaC changes near 2026-05-11 | git log on alert tf files | Quick coordinator probe acceptable (small surface) |
| ServiceNow ticket lifecycle, related Rootly state, multi-system convergence | Coordinator + Rootly MCP | LL-004 lesson surface — check for orphans |

## Initial Hypotheses

1. **H1**: Genuine cluster workload incident — KQL query in `vpp-resource-unhealthy` detected an unhealthy pod/operator/service in `eneco-vpp-prd` namespace. **Elimination**: Azure alert payload + oc state both fail to point to a real unhealthy resource.
2. **H2**: Noisy/structurally-flawed alert rule — generic "resource unhealthy" KQL might over-fire on transient OpenShift state (pod restart loop, brief operator outage, etc). **Elimination**: KQL query + historical fire pattern shows alert is well-tuned and rare.
3. **H3**: Multi-system convergence drift (LL-004 pattern) — ServiceNow ticket created but no matching Rootly entry / Azure alert never went to terminal state. **Elimination**: All three planes (Azure alert state, Rootly mirror, ServiceNow ticket) align.
4. **H4**: Recent IaC change to alert definition introduced misconfiguration. **Elimination**: git log on alert HCL shows no recent change OR change is correctness-preserving.

## Success Criteria

- **SC1**: Holistic RCA document with all 12 layers per on-call-incident-workflow + `/rca-holistic` skill, every load-bearing claim carrying A1/A2/A3 evidence label.
- **SC2**: Context Ledger present (zero-context reader test passes).
- **SC3**: oc command playbook: each command answers a specific diagnostic question with expected output shape + decision tree branch.
- **SC4**: Adversarial review receipts attached; no DEFER on HIGH/BLOCKING findings.
- **SC5**: User executes ≥1 oc command from playbook and produces actionable cluster-side evidence (user-outcome surface — RCA is a tool, not the goal).
- **SC6**: Files placed in `log/employer/eneco/02_on_call_shift/2026_05_11_cmc_alert_vpp_cluster_prod/` per workflow: at minimum `slack-intake.txt` (or rename to `intake.txt` since this is ServiceNow), `context.md`, `rca.md`, `fix.md`, `oc-playbook.md`.

## Counterfactual

Without proper RCA → next CMC / `vpp-resource-unhealthy` alert paged blind, same symptom-patch cycle (lesson: "symptom patch without generator"); no oc playbook → next on-call repeats discovery; durable lessons not captured → CCoE/Trade Platform pattern map stays incomplete.

## BRAIN SCAN

- **Dangerous assumption**: that the alert name `vpp-resource-unhealthy` maps cleanly to a single class of failure mechanism. Likely false — generic "resource unhealthy" can hide diverse mechanisms (pod CrashLoopBackOff, operator degraded, service endpoint down, autoscaler stuck, etc).
- **Falsifier**: KQL query in the rule definition decomposes into specific predicates → mechanism narrows; without that, RCA is shape-matching.
- **Frame**: socrates-contrarian attacks the identity claim ("CMC = vpp-resource-unhealthy = X mechanism") once IaC query is decoded.
- **Verification-method failure mode**: I produce an oc command sheet with subtly wrong syntax → user runs it → garbage output → false conclusion. Counter: sre-maniac reviews playbook for operator correctness BEFORE handover.
