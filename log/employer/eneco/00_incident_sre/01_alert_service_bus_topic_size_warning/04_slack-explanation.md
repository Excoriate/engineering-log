---
task_id: 2026-03-09-001
agent: principal-engineer-document-writer
status: complete
summary: On-call runcard for Service Bus topic size warning alert — 2-paragraph Slack-ready explanation
---

The severity-2 warning [`mcdta-vpp-sb-vpp-sbus-d-topic-size-d-warning`](https://portal.azure.com/#@Eneco.onmicrosoft.com/resource/subscriptions/839af51e-c8dd-4bd2-944b-a7799eb2e1e4/resourceGroups/mcdta-rg-vpp-d-mon/providers/Microsoft.Insights/metricalerts/mcdta-vpp-sb-vpp-sbus-d-topic-size-d-warning/users) fired because topic `assetplanning-asset-strike-price-schedule-created-v1` in namespace `vpp-sbus-d` (dev) hit 520 MB, breaching the 400 MB warning threshold. The cause is a single stalled subscription: `asset-scheduling-gateway` has 3,756 messages pending while the other two subscriptions (`tenant-gateway-subscription` and `dataprep`) are both at 0. Messages are producing normally; the consumer is not draining.

Check whether the `asset-scheduling-gateway` service is running in the dev Kubernetes cluster (inspect its pods/deployment). Determine if the consumer is down due to a planned deployment, crash, or bug. Current size is 520 MB against an 800 MB critical threshold, so there is no immediate data-loss risk, but the trend will breach critical if left unresolved. Log into dev (`enecotfvppmclogindev`) and run the following to get live subscription counts:

```bash
az servicebus topic subscription list --namespace-name vpp-sbus-d --resource-group mcdta-rg-vpp-d-messaging --topic-name assetplanning-asset-strike-price-schedule-created-v1 --query '[].{name:name, msgCount:messageCount}' --output table
```

See all [namespace topics in the Azure portal](https://portal.azure.com/#@Eneco.onmicrosoft.com/resource/subscriptions/839af51e-c8dd-4bd2-944b-a7799eb2e1e4/resourceGroups/mcdta-rg-vpp-d-messaging/providers/Microsoft.ServiceBus/namespaces/vpp-sbus-d/topics) for further inspection.
