---
task_id: 2026-03-09-001
agent: coordinator
status: complete
summary: Verified facts about the Service Bus topic size warning alert
---

# Alert Facts (FACT-grade, all source-cited)

## Identity
- Name: `mcdta-vpp-sb-vpp-sbus-d-topic-size-d-warning`
  SOURCE: alert-json-view.json:4
- Resource ID: `/subscriptions/839af51e-c8dd-4bd2-944b-a7799eb2e1e4/resourceGroups/mcdta-rg-vpp-d-mon/providers/Microsoft.Insights/metricalerts/mcdta-vpp-sb-vpp-sbus-d-topic-size-d-warning`
  SOURCE: alert-json-view.json:3
- IaC module: `module "maxtopicsize_list"` with for_each over `var.servicebus_topic_size_alerts`
  SOURCE: metric-alert-service-bus.tf:100-101

## Metric Definition
- Metric: `Size` on `Microsoft.ServiceBus/Namespaces`
  SOURCE: alert-json-view.json:46-47
- Unit: BYTES (400,000,000 bytes ≈ 381 MiB / ~400 MB decimal)
  SOURCE: dev.tfvars:58 comment `#400MB` + Azure Monitor Size metric spec
- Operator: `GreaterThan`
  SOURCE: alert-json-view.json:43
- Time Aggregation: `Maximum`
  SOURCE: alert-json-view.json:57
- Evaluation Window: `PT5M` (5 minutes)
  SOURCE: alert-json-view.json:39
- Evaluation Frequency: `PT1M` (every 1 minute)
  SOURCE: alert-json-view.json:21
- Dimension: `EntityName = *` (all topics evaluated individually)
  SOURCE: alert-json-view.json:50-55

## Thresholds (All Environments — IDENTICAL)
| Alert          | Severity | Threshold       | Comment in IaC |
|----------------|----------|-----------------|----------------|
| warning        | 2        | 400,000,000 bytes | #400MB       |
| critical       | 0        | 800,000,000 bytes | #800MB       |
SOURCE: dev.tfvars:54-65 AND prd.tfvars:51-62 (values identical)

## Scope
- Namespace: `vpp-sbus-d`
  SOURCE: alert-json-view.json:19
- Resource group: `mcdta-rg-vpp-d-messaging`
  SOURCE: alert-json-view.json:19
- Topics monitored: 252 (screenshot: "252 time series monitored")

## Severity & Tags
- Severity: 2 (Warning)
  SOURCE: alert-json-view.json:16
- Tags: AppName=VPP, Environment=MC Development, Purpose=vpp_core_shared
  SOURCE: alert-json-view.json:8-12
- autoMitigate: true (auto-resolves when metric drops below threshold)
  SOURCE: alert-json-view.json:22

## Description Bug (FACT)
- Rendered description: "Action will be triggered when any topic exceeds size of 400000000Mb"
  SOURCE: alert-json-view.json:15 + screenshot
- IaC template: `"Action will be triggered when any topic exceeds size of ${each.value.threshold}Mb"`
  SOURCE: metric-alert-service-bus.tf:107
- Bug: threshold is in bytes; appending "Mb" makes it read as "400 million megabytes" (~400 PB), not ~400 MB
  Analysis: the developer intended "400 MB" but interpolated raw bytes with "Mb" suffix

## Action Groups (FACT)
| Action Group                             | Receiver Type      | Destination     | Source |
|------------------------------------------|--------------------|-----------------|--------|
| eneco-vpp-devops-actiongroup             | No receivers in dev| —               | az CLI |
| ag-trade-platform-d                      | Webhook            | rootly-trade-platform (ROOTLY) | az CLI |
| eneco-vpp-service-bus-topic-size-ag      | Webhook            | Slack via Logic App | actiongroup.tf:54-57 |

- In PRODUCTION only: OpsGenie action group added
  SOURCE: metric-alert-service-bus.tf:125-128
- Rootly paging path: `ag-trade-platform-d` → webhook `rootly-trade-platform`
  SOURCE: az monitor action-group show (live query)

## Live State (DEV — queried 2026-03-09 via enecotfvppmclogindev)
- Alert status: ENABLED (both warning and critical)
  SOURCE: az monitor metrics alert list
- Namespace max topic size: 1,024 MB (all topics)
  SOURCE: az servicebus topic list
- Topics above 400 MB threshold: 1 of 252
  - `assetplanning-asset-strike-price-schedule-created-v1`: 520.50 MB (545,782,443 bytes)
  SOURCE: az servicebus topic list (live)
- Root cause: subscription `asset-scheduling-gateway` has 3,756 unread messages on that topic
  SOURCE: az servicebus topic subscription list (live)
- Other subscriptions on breaching topic: tenant-gateway-subscription (0), dataprep (0)

## Estimated Monthly Cost
- $25.20/month for 252 time series at PT1M evaluation frequency
  SOURCE: Azure Portal screenshot
