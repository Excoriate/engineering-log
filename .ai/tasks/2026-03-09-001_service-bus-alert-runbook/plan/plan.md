---
task_id: 2026-03-09-001
agent: coordinator
status: partial
summary: Plan for Service Bus Topic Size Warning SRE runbook
---

# Plan: Service Bus Topic Size Warning — SRE Runbook

## Objective

Produce a comprehensive, Rootly-page-ready SRE runbook at:
`log/employer/eneco/00_incident_sre/01_alert_service_bus_topic_size_warning/runbook/`

Containing:
- `README.md` — main runbook (60-second triage → root cause → resolution)
- `diagnose.py` — Python triage script with 0/1 exit code

Reviewed and signed off by sre-maniac and linus-torvalds subagents.

## Current State (FACT: live az CLI, 2026-03-09)

- Alert FIRED since 2026-03-08T10:24:27Z
- Breaching topic: `assetplanning-asset-strike-price-schedule-created-v1` at 552.3 MB (138%)
- Root cause: DLQ accumulation (3,796 messages) due to PT5M TTL + DeadLetteringOnMessageExpiration=True
- Consumer is running but DLQ never auto-drains → alert will not auto-resolve

## Backward Chaining from Outcome

**Desired outcome**: On-call engineer paged at 2AM resolves the alert in < 30 min without prior knowledge.

**What does that require?**
← Knows WHAT to do with DLQ (inspect, escalate to consumer team, or drain)
← Knows WHO owns the consumer (`asset-scheduling-gateway`)
← Knows WHERE to find the consumer state (kubectl/Argo)
← Knows HOW to identify the breaching topic (diagnose.py step 1)
← Knows the alert mechanics (why DLQ causes size to stay high)
← Has authenticated az CLI access (enecotfvppmclogindev)

## Execution Plan (Ordered)

1. Write `diagnose.py` Python script — identifies breaching topics, lagging subscriptions, DLQ state, producer/consumer delta. Exit 0 = healthy, Exit 1 = action required. Produces structured table output. Falsifier: `python diagnose.py --help && python diagnose.py` runs without error.

2. Write `runbook/README.md` — full SRE runbook with:
   a. Alert context (what it is, why it fires, cascade risk)
   b. Prerequisites (auth, access requirements)
   c. Step 1: Authenticate (enecotfvppmclogindev alias)
   d. Step 2: Quick triage — run diagnose.py (60 seconds to breaching topic)
   e. Step 3: Manual az CLI deep-dive (subscription-level, DLQ state, metrics)
   f. Step 4: Root cause classification tree (4 scenarios)
   g. Step 5: Resolution playbook (per scenario)
   h. Step 6: Escalation matrix (consumer team, SRE lead, dev on-call)
   i. Cascade risk section (4-stage cascade timeline)
   j. Environment variables table (dev vs prd)
   k. Known false positives and disambiguation

3. Dispatch `Agent(sre-maniac)` to review runbook for operational fidelity — produces signed-off artifact with findings.

4. Dispatch `Agent(linus-torvalds)` to review `diagnose.py` for code quality — produces signed-off artifact with findings.

5. Apply all CRITICAL/MAJOR findings from reviews. Re-verify acceptance criteria.

## Subagent Routing (NN-7)

| Domain | Agent | ROI Rationale |
|--------|-------|---------------|
| Runbook operational review | sre-maniac | SRE-domain expert for runbook fidelity: checks triage time, escalation paths, coverage gaps, actionability |
| Python code review | linus-torvalds | Code quality: error handling, exit codes, subprocess safety, clarity |

Executor (coordinator) ≠ Verifier (sre-maniac + linus) — satisfies CRUBVG ≥4 route requirement.

## Runbook Structure Design

### README.md Sections (in order)

```
# SRE Runbook: Service Bus Topic Size Warning
## Alert Summary
## Prerequisites
## Environment Configuration
## Step 1 — Authenticate
## Step 2 — Quick Triage (60 seconds)
## Step 3 — Deep Diagnosis (az CLI)
  ### 3.1 Identify Breaching Topics
  ### 3.2 Identify Lagging Subscriptions
  ### 3.3 Classify Root Cause
  ### 3.4 Check DLQ State
  ### 3.5 Check Producer/Consumer Delta
  ### 3.6 Check Alert History
## Step 4 — Root Cause Classification
## Step 5 — Resolution Playbook
  ### Scenario A: Consumer Stopped (Active Backlog)
  ### Scenario B: DLQ Accumulation (Expired Messages)
  ### Scenario C: Producer Burst
  ### Scenario D: Orphaned Subscription
## Step 6 — Escalation Matrix
## Alert Mechanics (Background)
## Cascade Risk
## Environment Reference (dev vs prd)
## Known Issues and False Positives
```

### diagnose.py Design

```python
# CLI: python diagnose.py [--namespace NS] [--resource-group RG] [--subscription SUB] [--threshold-bytes N]
# Output: ranked table of topics by size with % of threshold, subscription DLQ state, producer/consumer delta
# Exit: 0 = no topics above threshold, 1 = ≥1 topic above threshold (requires action)
# Uses: subprocess.run(["az", ...]) — no SDK dependencies required
# Dependencies: only stdlib + json
```

## Adversarial Challenge

### Q1: What if the on-call engineer can't run Python? (delivery mechanism assumption)
**Mechanism**: Runbook assumes Python 3 available. In a 2AM page scenario, if the engineer's laptop lacks Python or az CLI, the entire diagnose.py path fails. **Impact**: Engineer falls back to portal, losing the 60-second triage advantage. **Consequence**: Diagnosis time increases to 10-15 minutes navigating portal. **Evidence**: No assumption about engineer environment in current requirements. **Resolution**: Runbook section "Prerequisites" MUST include environment setup verification. All critical az CLI commands MUST also be listed as raw commands (not only via script), so the runbook is independently operable without Python.

### Q2: What if the alert description bug causes the engineer to dismiss the alert as misconfigured?
**Mechanism**: Alert description reads "400000000Mb" (381 petabytes). An engineer unfamiliar with this alert, woken at 2AM, reads this and concludes the alert threshold is nonsensical → dismisses as false positive → does nothing. Topic continues growing → reaches critical threshold (800MB) → critical page fires. If engineer also dismisses critical: topic fills to 1,024MB → QuotaExceededException → producer crash → cascade.
**Evidence**: FACT: alert-json-view.json:15 — description field confirmed "400000000Mb". INFER: this description is actively misleading. **Resolution**: Runbook MUST prominently state "IGNORE the threshold in the alert description — it is a rendering bug. The actual threshold is 400 MB." as a callout box at the very top.

### Q3: What if the DLQ grows beyond topic max (1,024 MB)?
**Mechanism**: Current DLQ: 3,796 messages × 145 KB = 552 MB. Growing at +5 msgs/5min = +0.725 MB/5min = ~8.7 MB/hour. Time to 1,024 MB from current 552 MB = ~54 hours. At 54 hours without intervention, topic reaches quota → QuotaExceededException → producer fails. **Evidence**: FACT: sizeInBytes=552,270,911 (live), DLQ growing (live metric), MaxSizeMB=1024 (live). **Resolution**: Runbook MUST include ETA calculation in Step 3 — "Estimated hours to quota exhaustion: (1024 MB - current MB) / growth rate MB/hr". This converts the alert from "something is wrong" to "you have N hours to fix it."

### Q4: What is the simplest viable alternative to this full runbook?
A one-page cheatsheet with 4 commands and a flowchart. **Why rejected**: The DLQ/TTL root cause is non-obvious. An engineer without the PT5M TTL + DeadLetteringOnMessageExpiration context will try to restart the consumer and be confused why the alert doesn't resolve. The runbook's primary value is explaining WHY the alert doesn't auto-resolve after consumer restart.

### Q5: Version/existence claims requiring probe
- `az monitor metrics list --filter "EntityName eq ..."` vs `--dimension`: confirmed LIVE — filter is correct, dimension+filter mutually exclusive. [PROBED: 2026-03-09, exit 0]
- `az servicebus topic subscription dead-letter-message list`: confirmed DOES NOT EXIST [PROBED: 2026-03-09, exit 2]. DLQ inspection requires SDK or portal. [PROBED: 2026-03-09]
- `--metric DeadletteredMessages` on `az monitor metrics list`: confirmed works [PROBED: 2026-03-09, exit 0]
- `az rest` for AlertsManagement API: confirmed works [PROBED: 2026-03-09, exit 0]
