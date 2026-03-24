---
task_id: 2026-03-09-001
agent: coordinator
status: draft
summary: Plan for Service Bus topic size warning alert review — 4 deliverable documents
---

# Plan: Service Bus Alert Review

## Objective
Produce 4 evidence-grounded documents for the alert `mcdta-vpp-sb-vpp-sbus-d-topic-size-d-warning`:
1. `01_analysis-alert.md` — anatomy, diagnosis, verdict
2. `02_alert-explanation.md` — 1st-principles deep dive
3. `03_proposal.md` — IaC fix proposal
4. `04_slack-explanation.md` — on-call runcard (2 paragraphs, Azure links)

## Diagnosis Verdict (pre-plan): Fine-tune
Evidence:
- Alert IS operationally valid: caught real consumer backlog (FACT: asset-scheduling-gateway 3,756 msgs)
- Description template BUG: renders as "400000000Mb" (FACT: metric-alert-service-bus.tf:107 + JSON:15)
- Thresholds identical dev/prd (FACT: dev.tfvars:58 = prd.tfvars:55) — suboptimal; dev alerts Rootly unnecessarily
- NOT: Remove — alert is catching real issues; NOT: Keep-as-is — description bug + dev paging issue exist

## Context Artifacts Available (Phase 4)
- context/01-alert-facts.md (FACT-grade: all alert fields, action groups, live state)
- context/02-iac-code-facts.md (FACT-grade: IaC module, variable, thresholds)
- context/03-live-env-state.md (FACT-grade: live metrics, topic breakdown, consumer backlog)

## Plan Steps

1. **[Subagent A] Write `01_analysis-alert.md`**
   Acceptance: All 7 alert fields sourced to file:line; diagnosis verdict with 4-option analysis; Rootly path verified; live state cited.
   Falsifier: `grep -c "FACT\|INFER\|SPEC" 01_analysis-alert.md` > 15

2. **[Subagent B] Write `02_alert-explanation.md`**
   Acceptance: Explains Azure Monitor metric alert lifecycle; Service Bus Size metric mechanics; threshold math with worked example; 1st principles chain from "what is a topic" to "why 400MB triggers a page".
   Falsifier: Contains "evaluation window", "time aggregation", "EntityName dimension", worked numeric example.

3. **[Subagent C — parallel with A+B] Write `03_proposal.md`**
   Acceptance: Specific IaC change (file:line, before/after); rationale from live data; rollback path; falsifiable condition.
   Falsifier: Contains `metric-alert-service-bus.tf:107` citation and before/after diff.

4. **[Subagent D — parallel] Write `04_slack-explanation.md`**
   Acceptance: ≤2 paragraphs; includes Azure portal link to alert; identifies breaching topic; specifies consumer subscription with backlog; actionable next step.
   Falsifier: word count ≤ 200; contains `assetplanning-asset-strike-price-schedule-created-v1`; contains `asset-scheduling-gateway`.

5. **[Adversarial] Socrates-Contrarian challenge on diagnosis and proposal**
   Acceptance: Challenges "Fine-tune" verdict; questions whether dev should alert to Rootly at all; probes threshold rationale.
   Falsifier: Written challenge with ≥2 alternative hypotheses.

6. **[SRE-Maniac] Operational review of proposal**
   Acceptance: Reviews proposal for rollback safety, blast radius, on-call impact.
   Falsifier: Explicit PASS/FAIL on each proposal change.

7. **[Linus-Torvalds review] Code quality of proposal IaC changes**
   Acceptance: Reviews Terraform HCL change for correctness, style, no regressions.
   Falsifier: Explicit verdict on metric-alert-service-bus.tf:107 fix.

8. **[Coordinator] Consolidate, verify gate-out, write phase-8-results.md**
   Acceptance: All falsifiers PASS; phase-8-results.md has evidence per falsifier.

## Subagent Routing Rationale (NN-7)
| Subagent | Domain | ROI Rationale |
|---|---|---|
| engineering-docs-create-linuskernel | Technical docs | Produces deep analysis with evidence chains; matches 02_alert-explanation scope |
| deep-dive-documentation | Code comprehension | 1st-principles explanation; best for 02_ |
| socrates-contrarian | Adversarial | CRUBVG≥5 mandates contrarian; R=1 (paging change), B=1 |
| Generic Agent(writer) | Document production | For 01_, 03_, 04_ — focused scope, bounded context |

Note: For 01_analysis, 03_proposal, 04_slack → self-execute since context artifacts are small, bounded, CRUBVG of sub-task ≤ 3. For 02_explanation → delegate to deep-dive agent. For validation → socrates + sre pattern.

## Adversarial Challenge

### Q1: Main assumption + what fails if wrong
Assumption: "The alert is firing because of consumer backlog (asset-scheduling-gateway)."
Mechanism: If wrong → the topic is growing due to large message payloads or high publication rate, not consumer lag. Consequence: proposal would fix description bug but miss the real operational cause. Counter-evidence: subscription `asset-scheduling-gateway` has 3,756 messages (FACT: live az CLI); other two subscriptions have 0 messages. This discriminates backlog vs. payload size hypothesis.

### Q2: Simplest viable alternative
Alternative: Raise the threshold to 600MB so only truly critical sizes page. Pro: reduces noise. Con: masks moderate-severity consumer lags. Evidence needed: how often does the namespace legitimately reach 400-600MB under normal load? (not probed yet — out of scope for this engagement but noted as future work)

### Q3: Evidence that would disprove this plan
If `asset-scheduling-gateway` is intentionally paused (known maintenance window) → the alert is correct but the context is benign. Would disprove "fine-tune urgency" but not "description bug" finding. Falsifier: check deployment/maintenance logs for `asset-scheduling-gateway` pauses. Not probed — marked INFER.

### Q4: Where hidden complexity moves
Fixing the description template in IaC also regenerates all existing metric alerts on next `terraform apply`. This is safe (descriptions are metadata-only, no threshold changes) but the apply touches `252 × 2 environments = 504+` alert resources. Could cause Terraform apply delay.

### Q5: Version/existence claims requiring probe
Probe confirmed: `az monitor action-group show` returned `rootly-trade-platform` webhook. No memory claim — direct evidence.
Probe confirmed: `az servicebus topic subscription list` returned 3,756 messages for `asset-scheduling-gateway`. No memory claim.
