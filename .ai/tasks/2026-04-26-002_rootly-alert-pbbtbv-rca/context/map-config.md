---
task_id: 2026-04-26-002
agent: claude-opus-4-7
status: complete
summary: Operational config — az login alias, MC subscription scope, alert tfvars per environment.
---

# Map: Configuration

## Auth / Connectivity

- `enecotfvppmclogindev` shell alias → MC dev SP login (per project memory). Read-only.
- Skill `eneco-tools-connect-mc-environments` covers dev / acc / prd, IP whitelist, credential cache.
- `current-date` = 2026-04-26.

## Threshold sources

- `configuration/dev-alerts.tfvars`, `acc-alerts.tfvars`, `prd-alerts.tfvars`.
- Per `metric-alert-service-bus.tf` (135 lines, project memory): consumes per-env tfvars for thresholds (DLQ count, throttle errors, etc.).

## Routing destination

- `actiongroup.tf` defines paging targets; Rootly is one of them via webhook.
- `logicapp-azure-monitor-metric-alerts-slack.tf` fans Azure Monitor signals to Slack.

## Probe ground rules

- Read-only az queries only. No `az ... create/update/delete/role assignment`.
- Resource IDs in MC subs follow `/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.<ns>/...`. Once the alert payload yields the resource id, az is point-and-shoot.
- Subscription scope: dev MC; acc/prd scope only if alert payload proves it (Rootly does not always reveal env at fingerprint level).
