---
task_id: 2026-03-09-001
agent: coordinator
status: draft
summary: Initial requirements for Service Bus topic size warning alert review
---

# Task Requirements — Initial

## Objective

Review an Azure Monitor alert for Service Bus topic size (warning threshold) that
is currently active and paging on-call engineers via Rootly. Produce:

1. `01_analysis-alert.md` — rigorous analysis; all claims FACT-verified
2. `02_alert-explanation.md` — deep 1st-principles explanation (what, why, how)
3. `03_proposal.md` — changes proposal IF analysis warrants improvements

## Inputs

- Alert JSON: `log/employer/eneco/00_incident_sre/01_alert_service_bus_topic_size_warning/alert-json-view.json`
- Source (IaC): `/Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src/enecomanagedcloud/myriad-vpp/MC-VPP-Infrastructure/main`
- Live env access: `enecotfvppmclogindev` alias (read-only, dev MC environment)
- Context: alert is wired to Rootly for on-call paging

## Acceptance Criteria (initial — to be challenged in Phase 3)

1. `analysis-alert.md` classifies every claim as FACT/INFER/SPEC with evidence
2. Alert threshold, condition, dimension, severity, and action group are documented
3. Diagnosis concludes one of: Improve | Fine-tune | Remove — with justification
4. `alert-explanation.md` explains from 1st principles: Service Bus metric, threshold
   rationale, firing conditions, expected vs. observed behavior
5. `proposal.md` (if changes warranted) contains specific, actionable change with
   falsifiable before/after state and rollback path
6. All claims about source code verified against actual IaC file content
7. Live env data queried via `enecotfvppmclogindev` to validate current state

## Known Unknowns (INFER — to probe in Phase 4)

- U1: Alert threshold value and whether it was set empirically or arbitrarily
- U2: Service Bus topic name(s) and namespace(s) in scope
- U3: Historical firing frequency (signal-to-noise ratio)
- U4: Rootly escalation policy linked to this alert
- U5: Whether IaC defines this alert or it was manually created in portal
- U6: Current actual topic size vs. threshold

## CRUBVG at Phase 1 Entry: 9 (C=2, R=1, U=2, B=1, V=1, G=2)
