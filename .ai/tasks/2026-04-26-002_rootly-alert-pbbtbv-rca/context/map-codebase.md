---
task_id: 2026-04-26-002
agent: claude-opus-4-7
status: complete
summary: MC-VPP-Infrastructure alert IaC topology — every Azure metric-alert TF file plus action group and env tfvars.
---

# Map: Codebase (Eneco MC-VPP-Infrastructure / main)

Repository root: `/Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src/enecomanagedcloud/myriad-vpp/MC-VPP-Infrastructure/main`

## Metric alert TF files (terraform/)

- `metric-alert-service-bus.tf` — Service Bus alerts (DLQ, server errors, throttling, etc.)
- `metric-alert-app-gateway.tf` — Application Gateway health/backend.
- `metric-alert-app-insights.tf` — App Insights signals.
- `metric-alert-cosmosdb.tf` — Cosmos DB SQL API alerts.
- `metric-alert-cosmosdbmongo.tf` — Cosmos DB Mongo API alerts.
- `metric-alert-key-vault.tf` — Key Vault throttling/availability.
- `metric-alert-storage-account.tf` — Storage account.
- `metric-alert-sql2.tf` — Azure SQL DB.
- `metric-alert-kusto.tf` — Kusto/ADX.
- `metric-alert-signalr.tf` — SignalR.
- `metric-alerts-eventhhub.tf` — Event Hub (sic, "eventhhub" typo in filename).
- `monitor_metric_query_alert.tf` — Log-query (KQL) based alerts.
- `actiongroup.tf` — Action groups (paging targets).
- `logicapp-azure-monitor-metric-alerts-slack.tf` — Logic App that fans Azure Monitor alerts to Slack.
- `servicebus-mc-lz.tf` — Service Bus namespace + topology (52 lines per memory).

## Configuration / env tfvars

- `configuration/dev-alerts.tfvars` (~18 KB) — dev thresholds.
- `configuration/acc-alerts.tfvars` (~17 KB) — acc thresholds.
- `configuration/prd-alerts.tfvars` (~24 KB) — prd thresholds.
- `configuration/{dev,acc,prd}.tfvars` — env-wide module inputs.
- `configuration/{dev,acc,prd}.backend.config` — TF backend.

## Decision trees

- Phase 4 step 1: read Rootly alert `pbbtBV` payload → identify metric name + resource id → map to which `metric-alert-*.tf` file.
- Step 2: `grep -nE "<metric_name>|<alert_name>" terraform/metric-alert-*.tf` to locate `azurerm_monitor_metric_alert` block.
- Step 3: extract threshold variable name → `grep -nE "<var_name>" configuration/<env>-alerts.tfvars`.
- Step 4: cross-check action group routing in `actiongroup.tf` to confirm Rootly is destination.
