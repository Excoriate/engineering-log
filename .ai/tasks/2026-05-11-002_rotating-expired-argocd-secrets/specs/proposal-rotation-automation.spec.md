---
task_id: 2026-05-11-002
agent: claude-opus-4-7
status: draft
summary: Spec — proposal-rotation-automation.md
phase: 6
---

# Spec — `proposal-rotation-automation.md`

## Purpose

Forward-looking proposal for automating rotation of the 4 ArgoCD PATs + extension to adjacent credential classes. Audience: Fabrizio + Trade Platform leadership. Outcome: a starting menu of options to make a decision on.

## Target path

`/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/log/employer/eneco/02_on_call_shift/2026_05_11_rotating_expired_argocd_secrets/proposal-rotation-automation.md`

## Required sections

1. **TL;DR** — 3-bullet executive summary; 3 options + 1 recommendation
2. **Problem statement** — quantified drift:
   - Today's incident (sandbox PAT expired ~22h before remediation; FBE blast radius: 3 broken slots + 8 surviving)
   - Three more PATs expire in 21 days (06-01)
   - INC-75 (2024-11-19) already prescribed automation
   - PXQ incident 2026-05-07 (same class, 4 days ago)
   - Fabrizio DM 2026-04-10: "this is a shit job to be done and can cause outages"
   - No formal SLA; no documentation; tribal knowledge in 1 head
3. **Current state diagram** — mermaid: existing monitor (PR 140615 / `azure-devops-pat-token-monitor.ps1`) → Slack alert → human → manual rotation per cluster → human-documented
4. **Target state options** (3 options with explicit tradeoffs)
   - **Option A — ADO Workload Identity Federation (eliminate PATs)** — ROI, blast radius, mitigations, ownership, verifiability, rollback, drawbacks
   - **Option B — KV + ESO + scheduled rotation Function** — same tradeoff dimensions; note that ESO is NOT currently deployed, so cost includes platform-wide ESO install
   - **Option C — Status-quo + SLA + Grafana alert + ownership** — low-cost minimum path; buys time
5. **Comparison matrix** — Option A vs B vs C across cost / class-elimination / MTTD / toil / consistency / cross-class applicability / cutover risk / reversibility
6. **Adjacent classes** — how each option extends to F4 AAD SP, ESP cert, TF SP, BTM secrets
7. **Sequencing recommendation** — Phase 1 (now-30d), Phase 2 (30-180d), Phase 3 (180d+)
   - Phase 1 = Option C unconditionally (low cost, high MTTD impact, documents the rotation)
   - Phase 2 = Option A or B based on what IaC sidecar found (ESO absent → Option B has install cost; consider Option A for class elimination)
   - Phase 3 = extend chosen option to adjacent classes
8. **Anti-patterns** — manual KV + manual cluster patch in parallel; PAT-in-commit; restart-controllers-fixes-it; auto-rotation without verification gate (the wrong PAT scope would brick all 4 clusters at once); single-SA-shared-across-clusters
9. **Open dependencies on Fabrizio / Trade Platform** — list of decisions needed before any option can start
10. **Reference architecture sketch** — mermaid for Option A (chosen path tentatively)
11. **References** — INC-75, PXQ 2026-05-07, F4 thread, PR 140615, Fabrizio DM, Roel quotes, wiki templates (id 50903 + 68382)

## Hard requirements

| Falsifier | Test |
|---|---|
| F1 ≥3 distinct options, each with all 7 tradeoff dimensions filled | sample-review |
| F2 Named tradeoffs ("X trades A for B because Z"), NOT "X is better" | grep for tradeoff phrasing |
| F3 Cited basis per option (specific docs / vault / industry pattern) | sample |
| F4 Adjacent-class extension explicit per option | grep |
| F5 Sequencing recommendation with concrete time windows + Phase 1 doable in <3 days | grep |
| F6 Anti-patterns section ≥5 items | count |
| F7 Open dependencies on Fabrizio explicitly listed and routable to decisions | grep |

## Non-requirements

- NOT a project plan / does NOT commit engineering days beyond Phase 1
- Does NOT execute or implement (it's a proposal)
- Does NOT replace the runbook (runbook is for THIS rotation; proposal is for next quarter)
