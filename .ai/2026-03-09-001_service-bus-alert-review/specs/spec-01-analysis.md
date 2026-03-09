---
task_id: 2026-03-09-001
agent: coordinator
status: complete
summary: Spec for 01_analysis-alert.md — rigorous anatomy and diagnosis
---

# Spec: 01_analysis-alert.md

## Summary
Rigorous, FACT-anchored analysis of the Service Bus topic size warning alert. Every claim classified FACT/INFER/SPEC with source citation. Concludes with one of four diagnosis verdicts.

## Output Path
`log/employer/eneco/00_incident_sre/01_alert_service_bus_topic_size_warning/01_analysis-alert.md`

## Why
On-call engineers need to understand whether this alert is trustworthy, whether it's correctly configured, and what action is appropriate. A rigorous analysis document provides the evidentiary basis for any proposed changes and for future incident retrospectives.

## Sections Required
1. Alert Identity (name, resource ID, IaC module, subscription, env)
2. Metric Mechanics (metric name, namespace, aggregation, operator, window, frequency)
3. Threshold Analysis (value, unit, per-env comparison, max topic size vs threshold ratio)
4. Dimension & Scope (EntityName=*, 252 time series, topic coverage)
5. Action Groups & Notification Path (3 action groups, Rootly path confirmed)
6. Live State (breaching topic, consumer backlog root cause, message count)
7. Known Issues Found:
   a. Description template bug (400000000Mb)
   b. Identical thresholds dev=prd (dev Rootly paging)
8. Diagnosis (4-option analysis: Improve | Fine-tune | Remove | Keep-as-is)
9. Verdict: Fine-tune — with justification

## Claim Classification Rules
- Every factual claim: `FACT (source:line)`
- Every derived claim: `INFER (from: <fact>)`
- Every assumption: `SPEC [unverified]`
- No hedge language on technical claims

## Key Evidence to Cite
- alert-json-view.json:15 (description bug)
- alert-json-view.json:43-44 (operator + threshold)
- metric-alert-service-bus.tf:107 (description template bug)
- dev.tfvars:58 (threshold = 400000000 #400MB)
- prd.tfvars:55 (identical threshold)
- az CLI: assetplanning-asset-strike-price-schedule-created-v1 at 520.50 MB
- az CLI: asset-scheduling-gateway subscription 3,756 messages
- az CLI: ag-trade-platform-d → rootly-trade-platform webhook

## Verification
- `grep -c "FACT\|INFER\|SPEC" 01_analysis-alert.md` ≥ 15
- Contains sections: "Description Bug", "Diagnosis", "Verdict"
- Verdict is one of exactly four options
