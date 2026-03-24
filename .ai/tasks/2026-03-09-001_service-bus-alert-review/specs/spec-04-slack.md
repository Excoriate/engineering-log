---
task_id: 2026-03-09-001
agent: coordinator
status: complete
summary: Spec for 04_slack-explanation.md — on-call runcard (2 paragraphs)
---

# Spec: 04_slack-explanation.md

## Summary
Ultra-condensed on-call runcard for the engineer who received the Rootly page. Two paragraphs maximum. Includes Azure Portal links, breach evidence, consumer name, and recommended action.

## Output Path
`log/employer/eneco/00_incident_sre/01_alert_service_bus_topic_size_warning/04_slack-explanation.md`

## Why
The on-call engineer needs to act fast. They don't need theory — they need: what fired, why, and what to do.

## Format
2 paragraphs, plain prose, no tables:

Paragraph 1 — WHAT & WHY:
- Name the alert (mcdta-vpp-sb-vpp-sbus-d-topic-size-d-warning)
- Name the breaching topic (assetplanning-asset-strike-price-schedule-created-v1)
- State current size vs threshold (520 MB / 400 MB)
- Identify root cause: consumer `asset-scheduling-gateway` has 3,756 unread messages
- Azure portal link to the alert

Paragraph 2 — WHAT TO DO:
- Check consumer `asset-scheduling-gateway` — is it running? pods/deployment status?
- Check if this is a known deployment gap or unexpected outage
- Azure portal link to the Service Bus namespace topic
- Azure CLI command to check subscription message count live
- Note: alert is severity 2 (warning); critical threshold is 800 MB; no immediate data loss risk

## Azure Links to Include
- Alert: https://portal.azure.com/#@Eneco.onmicrosoft.com/resource/subscriptions/839af51e-c8dd-4bd2-944b-a7799eb2e1e4/resourceGroups/mcdta-rg-vpp-d-mon/providers/Microsoft.Insights/metricalerts/mcdta-vpp-sb-vpp-sbus-d-topic-size-d-warning/users
- Namespace: https://portal.azure.com/#@Eneco.onmicrosoft.com/resource/subscriptions/839af51e-c8dd-4bd2-944b-a7799eb2e1e4/resourceGroups/mcdta-rg-vpp-d-messaging/providers/Microsoft.ServiceBus/namespaces/vpp-sbus-d/topics
- CLI cmd: `az servicebus topic subscription list --namespace-name vpp-sbus-d --resource-group mcdta-rg-vpp-d-messaging --topic-name assetplanning-asset-strike-price-schedule-created-v1 --query '[].{name:name, msgCount:messageCount}' --output table`

## Verification
- Word count ≤ 200
- Contains topic name: `assetplanning-asset-strike-price-schedule-created-v1`
- Contains subscription name: `asset-scheduling-gateway`
- Contains Azure portal link
- Contains message count (3,756)
