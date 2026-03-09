---
task_id: 2026-03-09-001
agent: coordinator
status: complete
summary: Live diagnostic findings captured 2026-03-09 via enecotfvppmclogindev alias
---

# Live Diagnostic Findings — 2026-03-09

## Authentication
- Alias: `enecotfvppmclogindev` — sets ARM_TENANT_ID + ARM_SUBSCRIPTION_ID env vars
- Active subscription: `839af51e-c8dd-4bd2-944b-a7799eb2e1e4` (Eneco MCC - Development - Workload VPP)

## Alert State (Live)
- **Rule**: `mcdta-vpp-sb-vpp-sbus-d-topic-size-d-warning`
- **Monitor condition**: FIRED
- **Severity**: Sev2 (warning)
- **Fired since**: 2026-03-08T10:24:27Z (18+ hours at time of capture)
- **AutoMitigate**: True (will auto-resolve when size drops below 400MB)
- **Note**: Alert description bug confirmed — "400000000Mb" in description

## Namespace State (Live)
- **Namespace**: `vpp-sbus-d` — Active, Premium, westeurope, 1 messaging unit
- **Total topics**: 252

## Breaching Topic (Live — 2026-03-09)
- **Topic**: `assetplanning-asset-strike-price-schedule-created-v1`
- **Size**: 552,270,911 bytes = **552.3 MB** = **138.1% of 400MB warning threshold**
- **Max topic size**: 1,024 MB (538% headroom before quota)
- **Subscriptions**: 3 total

## Subscription State on Breaching Topic (Live)
| Subscription | Active | DLQ | Total | Status |
|---|---|---|---|---|
| tenant-gateway-subscription | 0 | 0 | 0 | Active |
| dataprep | 0 | 0 | 0 | Active |
| **asset-scheduling-gateway** | **5** | **3,796** | **3,801** | Active |

## ROOT CAUSE CONFIRMED
- `asset-scheduling-gateway` subscription has:
  - `DefaultMessageTimeToLive: PT5M` (5-minute expiry)
  - `DeadLetteringOnMessageExpiration: True` (expired messages → DLQ)
- **Mechanism**: Messages arrive → consumer too slow or delayed → 5-minute TTL expires → messages dead-lettered → DLQ grows → DLQ bytes count toward topic Size metric → alert stays fired
- **DLQ growth rate**: +5 messages per 5 minutes (matching producer rate of 5 msg/5min)
- **Consumer health**: 10 completions per 5 minutes (consumer IS running, draining active queue 2x faster than arrival rate)
- **Active backlog**: Only 5 messages (consumer is keeping up with new arrivals)
- **Problem**: DLQ of 3,796 messages × ~145 KB = ~550 MB is the reason alert remains fired

## Why Alert Will NOT Auto-Resolve
DLQ messages are not automatically removed. They persist until:
1. A process explicitly reads and completes/abandons them from the DLQ
2. Manual DLQ purge
3. Messages expire from DLQ (max DLQ retention is 14 days default for Service Bus)

The consumer running normally does NOT drain the DLQ.

## Metrics (Live — last 1 hour)
| Metric | Value | Interval |
|---|---|---|
| IncomingMessages | 5/5min (60/hour) | steady |
| CompleteMessage | 10/5min (120/hour) | steady |
| DeadletteredMessages | +5/5min (growing from 3,736 → 3,796) | steady growth |

## Paging Path
- Rootly: `ag-trade-platform-d` action group → `rootly-trade-platform` webhook → ENABLED
- Slack: `eneco-vpp-service-bus-topic-size-actiongroup` → Logic App webhook → ENABLED

## Confirmed Working az CLI Commands
All commands below verified exit-0 in live session:

```bash
# 1. Verify subscription context
az account show --output table

# 2. List all topics ranked by size
az servicebus topic list \
  --namespace-name vpp-sbus-d \
  --resource-group mcdta-rg-vpp-d-messaging \
  --query "[].{name:name, sizeInBytes:sizeInBytes}" \
  --output json

# 3. Show subscriptions on a topic
az servicebus topic subscription list \
  --namespace-name vpp-sbus-d \
  --resource-group mcdta-rg-vpp-d-messaging \
  --topic-name <topic> \
  --query "[].{name:name, activeMessageCount:countDetails.activeMessageCount, dlqCount:countDetails.deadLetterMessageCount, status:status}" \
  --output json

# 4. Show detailed subscription properties
az servicebus topic subscription show \
  --namespace-name vpp-sbus-d \
  --resource-group mcdta-rg-vpp-d-messaging \
  --topic-name <topic> \
  --name <subscription> \
  --output json

# 5. Producer rate (IncomingMessages) — NOTE: use --filter NOT --dimension
az monitor metrics list \
  --resource "/subscriptions/SUB/resourceGroups/mcdta-rg-vpp-d-messaging/providers/Microsoft.ServiceBus/namespaces/vpp-sbus-d" \
  --metric IncomingMessages \
  --filter "EntityName eq 'TOPIC_NAME'" \
  --interval PT5M \
  --aggregation total \
  --output json

# 6. Consumer drain rate (CompleteMessage)
az monitor metrics list \
  --resource "..." \
  --metric CompleteMessage \
  --filter "EntityName eq 'TOPIC_NAME'" \
  --interval PT5M \
  --aggregation total \
  --output json

# 7. DLQ growth metric
az monitor metrics list \
  --resource "..." \
  --metric DeadletteredMessages \
  --filter "EntityName eq 'TOPIC_NAME'" \
  --interval PT5M \
  --aggregation maximum \
  --output json

# 8. Current alert fired state
az rest \
  --method GET \
  --url "https://management.azure.com/subscriptions/SUB/providers/Microsoft.AlertsManagement/alerts?api-version=2019-03-01&targetResource=NS_RESOURCE_ID&timeRange=1d" \
  --output json
```

## CONFIRMED INCORRECT COMMANDS (do NOT include in runbook)
```bash
# DOES NOT EXIST — will error:
az servicebus topic subscription dead-letter-message list ...

# WRONG — --dimension and --filter are mutually exclusive:
az monitor metrics list --dimension "EntityName" --filter "EntityName eq 'x'" ...
```
