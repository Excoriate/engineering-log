---
task_id: 2026-03-09-001
agent: coordinator
status: draft
summary: Initial requirements for Service Bus Topic Size Warning SRE runbook creation
---

# Task Requirements — Initial

## Request Summary

Create a comprehensive, actionable SRE runbook for the `mcdta-vpp-sb-vpp-sbus-d-topic-size-d-warning` alert that pages Rootly on-call. The runbook must:

1. Use `enecotfvppmclogindev` (zsh alias) once to authenticate and store session credentials
2. Use confirmed az CLI read-only commands to populate all diagnosis steps
3. Be reviewed by sre-maniac/linus-torvalds for 100% fidelity and actionability
4. Live in `log/employer/eneco/00_incident_sre/01_alert_service_bus_topic_size_warning/runbook/`
5. Include Python or Go scripts if complex diagnosis requires deterministic parsing

## Known Facts from Alert JSON

- **Alert name**: `mcdta-vpp-sb-vpp-sbus-d-topic-size-d-warning`
- **Subscription**: `839af51e-c8dd-4bd2-944b-a7799eb2e1e4`
- **Alert RG**: `mcdta-rg-vpp-d-mon`
- **Messaging RG**: `mcdta-rg-vpp-d-messaging`
- **Namespace**: `vpp-sbus-d`
- **Metric**: `Size` on `Microsoft.ServiceBus/Namespaces`
- **Warning threshold**: 400,000,000 bytes (~400 MB), severity 2
- **Critical threshold**: 800,000,000 bytes (~800 MB), severity 0
- **Evaluation**: PT1M frequency, PT5M window, Maximum aggregation
- **Dimension**: EntityName = * (all 252 topics)
- **Paging path**: `ag-trade-platform-d` → Rootly webhook
- **Slack path**: `eneco-vpp-service-bus-topic-size-actiongroup` → Logic App

## Known Triggering State (2026-03-09)

- Breaching topic: `assetplanning-asset-strike-price-schedule-created-v1` at 520.50 MB
- Consumer backlog: subscription `asset-scheduling-gateway` — 3,756+ messages
- Two other subscriptions on this topic: zero pending messages
- Default TTL: PT5M — messages expire if unconsumed

## Acceptance Criteria (Initial)

1. Runbook is 100% actionable by an on-call engineer who has never seen this alert before
2. Every az CLI command is confirmed to execute without error (verified by live run)
3. Diagnosis flow covers: identify breaching topic(s) → identify lagging subscription(s) → determine root cause category → escalation path
4. Cascade risk is documented: consumer stop → topic fill → QuotaExceededException → producer crash → multi-topic starvation
5. Runbook includes Python script for deterministic JSON parsing of az CLI output
6. sre-maniac and linus-torvalds sign off on the runbook

## Open Questions

- OQ-1: What is the current state of `asset-scheduling-gateway` consumer pod? (live query needed)
- OQ-2: Are there DLQ messages on the breaching topic subscriptions?
- OQ-3: What is the current topic size at time of runbook build?
- OQ-4: What other topics are near threshold (early warning)?
- OQ-5: What are the `IncomingMessages` vs `CompleteMessage` rates? (producer vs consumer health)
- OQ-6: What alert history exists? (fire/resolve frequency)
