---
task_id: 2026-03-09-001
agent: coordinator
status: complete
summary: Live Azure dev environment state queried 2026-03-09 via enecotfvppmclogindev
---

# Live Environment State (DEV — subscription 839af51e)

## Service Bus Namespace
- Name: vpp-sbus-d
- Resource group: mcdta-rg-vpp-d-messaging
- Total topics: 252
- Namespace SKU: Premium (inferred from max topic size = 1,024 MB per topic)

## Topics by Size (Top 15, queried 2026-03-09)
| Topic | Size (bytes) | Size (MB) | Status |
|-------|-------------|-----------|--------|
| assetplanning-asset-strike-price-schedule-created-v1 | 545,782,443 | 520.50 | >>> ABOVE 400MB WARN <<< |
| assetplanning-prioritized-capacity-calculation-start-created-v1 | 19,950,906 | 19.03 | OK |
| asset-asset-registered-v1 | 10,433,776 | 9.95 | OK |
| (all others) | < 2.5MB each | — | OK |

## Breaching Topic Deep-Dive
Topic: `assetplanning-asset-strike-price-schedule-created-v1`
Max size: 1,024 MB | Current: 520.50 MB (50.8% of max)
Distance to critical (800MB): 279.5 MB remaining

### Subscriptions
| Subscription | Message Count | Dead Letter | Status |
|---|---|---|---|
| tenant-gateway-subscription | 0 | — | Active |
| dataprep | 0 | — | Active |
| asset-scheduling-gateway | **3,756** | — | Active |

ROOT CAUSE: `asset-scheduling-gateway` is not consuming messages → backlog accumulates → topic size grows.

## Azure Monitor Metric (48h lookback)
Peak Maximum Size (namespace aggregate): 561.46 MB at peak
Only 1 entity above threshold (assetplanning-asset-strike-price-schedule-created-v1)

## Alert State
- mcdta-vpp-sb-vpp-sbus-d-topic-size-d-warning (severity=2): ENABLED, currently FIRING
- mcdta-vpp-sb-vpp-sbus-d-topic-size-d-critical (severity=0): ENABLED, NOT firing (520MB < 800MB)

## Rootly Paging Path (CONFIRMED)
ag-trade-platform-d → webhook receiver: "rootly-trade-platform" → Rootly incident

## Alert Cost
252 time series × $0.10/series/month ≈ $25.20/month
