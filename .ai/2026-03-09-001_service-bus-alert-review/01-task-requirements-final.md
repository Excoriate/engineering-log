---
task_id: 2026-03-09-001
agent: coordinator
status: complete
summary: Final confirmed requirements for Service Bus topic size warning alert review
---

# Task Requirements — Final (Socratically Confirmed)

## Changes vs. Initial (MANDATORY — at least 1 falsifier-changing criterion)

1. **NEW**: Diagnosis verdict now has FOUR options: Improve | Fine-tune | Remove | Keep-as-is
   - Initial had only three. "Keep-as-is" is a valid evidence-based verdict.
   - Falsifier change: final doc must explicitly argue for/against all four options.

2. **NEW**: Threshold values come from `.tfvars` files (env-specific), NOT just the `.tf`
   - `dev-alerts.tfvars` (444 lines) and `prd-alerts.tfvars` (589 lines) must both be analyzed.
   - Falsifier change: analysis must document threshold PER environment (dev/acc/prd).

3. **NEW**: `actiongroup.tf` must be read to verify Rootly webhook linkage — not assumed.
   - Falsifier: analysis must cite `actiongroup.tf:line` for the Rootly action group.

4. **CLARIFIED**: `alert-capture-screenshot.png` is an additional evidence artifact — must be
   read/described in analysis to cross-check portal view vs. JSON definition.

5. **CLARIFIED**: Live env access via `enecotfvppmclogindev` is DEV scope. Analysis must
   explicitly state that live metric values are from DEV and may differ from PRD.

## Deliverables (confirmed, numbered for directory)

| File | Content | Falsifier |
|------|---------|-----------|
| `01_analysis-alert.md` | Rigorous alert anatomy; FACT/INFER/SPEC claims; diagnosis verdict (1 of 4) | All 7 alert fields documented with IaC file:line evidence |
| `02_alert-explanation.md` | 1st-principles: Service Bus metric mechanics, threshold rationale, firing conditions | Contains: metric definition, threshold math, dimension filter, evaluation window, alert lifecycle |
| `03_proposal.md` | Change spec IF verdict is not Keep-as-is; includes before/after state, rollback | Omitted if verdict = Keep-as-is (explicitly stated) |

## Confirmed Acceptance Criteria

1. `01_analysis-alert.md`:
   - Every alert field (name, condition, threshold, metric, dimension, severity, action group)
     documented with source: alert-json-view.json:line AND metric-alert-service-bus.tf:line
   - Threshold values documented per env (dev, acc, prd) from tfvars files
   - Actiongroup Rootly linkage verified from actiongroup.tf:line
   - Live dev env metric value queried and compared to threshold
   - Diagnosis verdict = one of {Improve, Fine-tune, Remove, Keep-as-is} with evidence

2. `02_alert-explanation.md`:
   - Explains Azure Monitor metric alert lifecycle (evaluation → fire → resolve)
   - Explains Service Bus `Size` metric: what it measures, units, granularity
   - Explains why topic size matters operationally (backpressure, storage quota)
   - Contains working example: "if topic has X messages of Y bytes each, metric = Z"
   - No hedge language on technical claims

3. `03_proposal.md` (if verdict != Keep-as-is):
   - Specific Terraform change (file:line, before, after)
   - Rationale grounded in live metric observations
   - Rollback: revert commit or tfvars value restore
   - Falsifier: "after change, alert fires when [condition] and is silent when [condition]"

## Known Unknowns Resolved/Carried

| ID | Unknown | Resolution |
|----|---------|-----------|
| U1 | Threshold empirical or arbitrary | -> Read tfvars + query live metric → PROBE in Phase 4 |
| U2 | Topic name(s) and namespace(s) | -> Read servicebus-mc-lz.tf + alert JSON dimension filter |
| U3 | Historical firing frequency | -> Query via Azure CLI in dev env |
| U4 | Rootly escalation policy | -> Out of scope; note in analysis as INFER |
| U5 | IaC-managed vs. manually created | -> Verify: resource ID in JSON matches TF state |
| U6 | Current actual topic size vs. threshold | -> Azure CLI query via enecotfvppmclogindev |

## CRUBVG Final: 9 (C=2, R=1, U=2, B=1, V=1, G=2) — unchanged
