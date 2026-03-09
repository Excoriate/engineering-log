---
task_id: 2026-03-09-001
agent: coordinator
status: complete
summary: Spec for 02_alert-explanation.md — 1st-principles deep explanation
---

# Spec: 02_alert-explanation.md

## Summary
Deep technical explanation of how this alert works from first principles. Written for an engineer new to Azure Monitor + Service Bus who needs to deeply understand the alert before tuning it.

## Output Path
`log/employer/eneco/00_incident_sre/01_alert_service_bus_topic_size_warning/02_alert-explanation.md`

## Why
The on-call engineer receiving the Rootly page needs to understand the mechanism, not just the threshold. Without first-principles understanding, any changes to the alert are guesswork.

## Sections Required
1. **Azure Service Bus: What is a Topic?** (pub/sub, namespaces, topics, subscriptions, message lifecycle)
2. **The `Size` Metric** (what it measures: sum of message body + headers in all subscriptions' active messages; units = bytes; why it grows when consumers lag)
3. **Azure Monitor Metric Alert Lifecycle** (evaluation → armed → fired → auto-mitigate → resolved; PT5M window, PT1M frequency explained)
4. **Dimension Splitting (EntityName = *)** (how Azure Monitor evaluates PER topic independently; why this matters for this alert)
5. **Threshold Rationale** (400MB = 39% of 1024MB max; what happens at max: new messages rejected with `QuotaExceededException`)
6. **Worked Example** (if each message = 10 KB and consumer stops: after N messages, size = X MB → fires alert after Y minutes)
7. **The Action Group Chain** (how the alert triggers → action group → webhook → Rootly → on-call page)
8. **What the Alert Does NOT Tell You** (it doesn't tell you WHY the topic is growing: could be producer surge, consumer down, or both)
9. **Auto-Mitigate** (when and how it resolves automatically; PT5M look-back after condition false)

## Quality Standards
- No hedge language
- Include concrete numeric worked example
- Explain WHY each design decision was made (not just what)
- Cross-reference to IaC source at metric-alert-service-bus.tf:100-135

## Verification
- Contains: "evaluation window", "EntityName", "QuotaExceeded" or "max size", worked numeric example
- Length ≥ 400 words
- No "likely", "appears", "suggests"
