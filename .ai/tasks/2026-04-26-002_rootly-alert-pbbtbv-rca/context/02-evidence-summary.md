---
task_id: 2026-04-26-002
agent: claude-opus-4-7
status: complete
summary: Evidence dump for Rootly alert pbbtBV — payload, az metrics, IaC source, recurrence pattern, action group routing.
---

# Evidence — Rootly Alert pbbtBV

## E1 — Identity (FACT)

| Field | Value | Source |
|------|-------|--------|
| short_id | `pbbtBV` | rootly cli payload |
| Rootly alert id | `4b420c7c-b549-49cb-bec1-06dae666e1e0` | payload |
| Rootly status | `acknowledged` | payload `data.attributes.status` |
| source | `azure` | payload |
| started_at | `2026-04-26T03:56:24.133Z` | payload |
| ended_at | `null` | payload (alert not resolved) |
| severity | `Sev2` (Medium) | payload `essentials.severity` + `alert_urgency.urgency=medium` |
| environment | `development` | payload alert_field_values |
| signalType | `Metric` | payload |
| monitoringService | `Platform` | payload |
| alertRule name | `kv-vppagg-bootstrap-d-kv-latency-above-1000ms` | payload |
| Azure alertId | `/subscriptions/839af51e.../providers/Microsoft.AlertsManagement/alerts/3d8b33a6-d825-4f49-9708-cadbd34ef000` | payload |
| Azure rule id | `/subscriptions/839af51e.../resourceGroups/rg-vppagg-bootstrap-d/providers/Microsoft.Insights/metricAlerts/kv-vppagg-bootstrap-d-kv-latency-above-1000ms` | payload |
| Target resource | `/subscriptions/839af51e.../providers/microsoft.keyvault/vaults/kv-vppagg-bootstrap-d` | payload `alertTargetIDs` |
| Subscription | `839af51e-c8dd-4bd2-944b-a7799eb2e1e4` (Eneco MCC - Development - Workload VPP) | `az account show` |
| Live Azure state | `state=New, monitor=Fired, lastModified=2026-04-26T03:56:24Z` (NOT yet auto-mitigated) | `az rest GET .../alerts/3d8b33a6...` |
| Action group | `ag-trade-platform-d` → webhook `rootly-trade-platform` → `https://webhooks.rootly.com/webhooks/incoming/azure_webhooks...` | `az monitor action-group show` |

## E2 — Breach window (FACT)

| Field | Value |
|-------|-------|
| windowStartTime | `2026-04-26T03:49:10.257Z` |
| windowEndTime | `2026-04-26T03:54:10.257Z` |
| windowSize | `PT5M` |
| metricName | `ServiceApiLatency` |
| metricNamespace | `microsoft.keyvault/vaults` |
| operator | `GreaterThan` |
| threshold | `1000` ms |
| timeAggregation | `Average` |
| metricValue | **`2712`** ms |

## E3 — Independent metric verification (FACT, az cli)

`az monitor metrics list --resource <kv> --metric ServiceApiLatency --aggregation Average Maximum Count --interval PT15M --start 2026-04-25T00Z --end 2026-04-26T07Z`

Single non-null sample across 31 hours:

```
2026-04-26T03:45:00Z avg=2712.0 max=2712.0 count=1.0
```

`az monitor metrics list --metric ServiceApiHit --interval PT15M` over the same 31h window: **count=0 in every PT15M bucket except 03:45-04:00Z (count=1)**.

`az monitor metrics list --metric ServiceApiResult --filter "ActivityName eq '*' and StatusCode eq '*'"` over 03:30-04:30Z: a single record dimensioned `activityname=vaultget, statuscode=200, count=1.0` at `2026-04-26T03:50:00Z`. Every other dimension/bucket is zero.

`Availability` metric: **100.0** in every PT15M bucket from 03:00-07:00Z. The KV is healthy; the alert reflects latency only.

## E4 — Resource posture (FACT, az cli)

`az resource show --ids <kv>`:
- `name=kv-vppagg-bootstrap-d`, `type=Microsoft.KeyVault/vaults`, `location=westeurope`, `sku=standard`.
- `publicNetworkAccess=Disabled`, `networkAcls.defaultAction=Deny`, `networkAcls.bypass=None`, `networkAcls.ipRules=[]`, `virtualNetworkRules=[]`.
- `privateEndpointConnections.length = 1`.
- RBAC-authorized.

This KV is private, locked-down, low-volume by design.

## E5 — IaC source (FACT, file:line)

Alert is **not** instanced in `MC-VPP-Infrastructure/main` — the file `terraform/metric-alert-key-vault.tf` only covers the `aks-kv` (different KV).

True source chain:

1. `enecomanagedcloud/myriad-vpp/platform-bootstrap/src/bootstrap.tf:1-2` — instantiates `terraform-bootstrap` (CCoE) via `for_each = var.products`, sourced as `git::.../CCoE/_git/terraform-bootstrap?ref=v0.4.0`.
2. `enecomanagedcloud/ccoe/terraform-bootstrap/keyvault.tf:1-2` — wraps `terraform-azure-keyvault` (CCoE) at `?ref=v1.2.0`.
3. **`enecomanagedcloud/ccoe/terraform-azure-keyvault/alerts.tf:126-160`** — `azurerm_monitor_metric_alert.default_main` with `for_each = local.default_metric_alerts`.
4. **`enecomanagedcloud/ccoe/terraform-azure-keyvault/locals.tf:22-40`** — definition (verbatim):

```hcl
kv-latency-above-1000ms = {
  name          = "kv-latency-above-1000ms"
  description   = "Alert when Key Vault latency is above 1000ms"
  enabled       = true
  auto_mitigate = true
  severity      = 2
  frequency     = "PT5M"
  window_size   = "PT5M"
  criteria = [{
    metric_namespace = "Microsoft.KeyVault/vaults"
    metric_name      = "ServiceApiLatency"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 1000
  }]
}
```

Threshold and aggregation are **hardcoded** in the CCoE module — applied identically across every product (vppagg, vppfo, vppidd, gurobi, astsch, …) and every environment (dev/acc/prd) consuming `terraform-bootstrap`.

`az monitor metrics alert show` confirms the live rule matches the IaC byte-for-byte: `enabled=true`, `severity=2`, `autoMitigate=true`, `evaluationFrequency=PT5M`, `windowSize=PT5M`, criteria allOf StaticThresholdCriterion `ServiceApiLatency Avg > 1000`.

## E6 — Recurrence pattern (FACT, rootly cli)

Across the 1000 most-recent Azure-source Rootly alerts (~3.5 weeks of data):

| short_id | started_at | status | summary |
|----------|------------|--------|---------|
| `Anjhdp` | 2026-04-02T17:57:25Z | resolved | `kv-gurobi-platform-a-kv-latency-above-1000ms` (acc env, gurobi product) |
| `pbbtBV` | 2026-04-25T20:56:24-07:00 (= 2026-04-26T03:56:24Z) | acknowledged | `kv-vppagg-bootstrap-d-kv-latency-above-1000ms` (dev env, vppagg product) |

Two firings → low-frequency but **recurring** pattern across products and environments. Not a one-off.

## E7 — Why the alert is stuck firing (INFER from FACTs)

Rule has `auto_mitigate=true` (verified live), so Azure should auto-resolve when the breach clears. **However**, ServiceApiHit count has been **0 in every PT15M bucket from 03:45Z to 06:45Z** (the latest data observed). Azure metric alerts evaluate aggregations only over collected samples; a metric with no data emits nothing for the rule to evaluate. With zero hits since the breach, the rule has nothing below threshold to trigger mitigation, so it sits in `Fired/New` indefinitely until either (a) traffic resumes and aggregates ≤1000ms, or (b) operator manually resolves. This is a structural pathology of "single-sample average GreaterThan threshold" rules on near-idle resources.

## E8 — Hypothesis ledger

| H | Status | Evidence |
|---|--------|----------|
| H1: Service Bus / messaging metric | **ELIMINATED** | `metricNamespace=microsoft.keyvault/vaults`; no Service Bus involvement (E1, E2). |
| H2: Other Azure resource (Key Vault `ServiceApiLatency`) | **CONFIRMED** | E1, E2, E3, E4 (resource id, metric name, breach value all align). |
| H3: Synthetic / heartbeat / non-Azure | **ELIMINATED** | `source=azure`, `signalType=Metric`, `monitoringService=Platform` (E1). |

## E9 — Caller identification (UNVERIFIED[unknown: no probe])

`az monitor activity-log list --resource-id <kv> --start 03:30Z --end 04:30Z` returned an empty list. KV control-plane reads (`vaultget`) frequently do not emit Administrative-category activity log entries; would need `AzureDiagnostics` (KV `AuditEvent` log via Diagnostic Setting) to identify the caller principal. No Diagnostic Setting was queried. Caller is therefore **unknown** but the operation type (`vaultget`, statuscode=200) and the timing (single hit after 31h idle) are highly consistent with a periodic provisioning probe (deploy pipeline, terraform refresh, Azure Policy compliance scan, or DSC/configuration drift check). Not a meaningful blocker for the RCA — the caller does not change the recommendation.
