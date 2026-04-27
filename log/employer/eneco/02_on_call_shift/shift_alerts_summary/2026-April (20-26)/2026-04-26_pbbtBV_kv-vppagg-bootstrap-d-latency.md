---
title: "Rootly pbbtBV — kv-vppagg-bootstrap-d ServiceApiLatency above 1000ms (RCA)"
type: oncall-alert-rca
alert_short_id: pbbtBV
alert_url: https://rootly.com/account/alerts/pbbtBV
alert_source: azure
alert_status: acknowledged_at_write_time
azure_state: Fired_New
environment: development
severity: Sev2
fired_at_utc: 2026-04-26T03:56:24Z
status: complete
created: 2026-04-26
tags: [oncall, rootly, key-vault, ccoe, vppagg, bootstrap, false-positive-class]
---

# Rootly `pbbtBV` — `kv-vppagg-bootstrap-d` Key Vault latency >1000ms

## TL;DR

- **Verdict (FACT)**: benign single-sample false positive. The KV had **one** API call in the 5-min window — `vaultget` (HTTP 200) — and it took 2712 ms, breaching the `Average > 1000` rule.
- **Action now**: resolve **two** places — (1) Rootly: resolve `pbbtBV` with a one-line note; (2) Azure: change the upstream alert to `Closed` via Portal *Investigate → Change alert state → Closed* or `az rest PATCH .../alerts/3d8b33a6-d825-4f49-9708-cadbd34ef000/changestate?api-version=2018-05-05&newState=Closed`. Without (2) the Azure alert sits `Fired` indefinitely (auto-mitigate cannot evaluate against zero further traffic) and any other consumer of the Azure-side alert feed still sees it open.
- **Follow-up (INFER)**: file a defect against the CCoE module `terraform-azure-keyvault` — same hardcoded rule will re-fire across every product/env. Prior firing 2026-04-02 (`Anjhdp`, kv-gurobi-platform-a). Sibling pattern, not a one-off.

## Identity (FACT)

| Field | Value |
|---|---|
| Rootly short_id | `pbbtBV` |
| Rootly status (at write time) | `acknowledged` |
| Rootly source | `azure` |
| Severity / urgency | `Sev2` / Medium |
| Environment field | `development` |
| Fired (UTC) | `2026-04-26T03:56:24.133Z` |
| Window | `03:49:10Z` → `03:54:10Z` (PT5M) |
| Azure rule | `kv-vppagg-bootstrap-d-kv-latency-above-1000ms` |
| Azure alert id | `/subscriptions/839af51e-…/providers/Microsoft.AlertsManagement/alerts/3d8b33a6-d825-4f49-9708-cadbd34ef000` |
| Azure live state | `state=New, monitor=Fired, lastModified=2026-04-26T03:56:24Z` (NOT auto-mitigated yet) |
| Resource | `kv-vppagg-bootstrap-d` (Microsoft.KeyVault/vaults, RG `rg-vppagg-bootstrap-d`, westeurope, sku=standard) |
| Subscription | `839af51e-c8dd-4bd2-944b-a7799eb2e1e4` — *Eneco MCC - Development - Workload VPP* |
| Action group | `ag-trade-platform-d` (RG `rg-pltfrm-infra-d`) → webhook `rootly-trade-platform` |
| Network posture | `publicNetworkAccess=Disabled`, `defaultAction=Deny`, 1 private endpoint, RBAC-authorized |

## Mechanism — why it fired (FACT, with one INFER)

1. The rule (FACT, live + IaC): `criteria.allOf[ServiceApiLatency, Microsoft.KeyVault/vaults, GreaterThan, threshold=1000, timeAggregation=Average]`, `frequency=PT5M`, `windowSize=PT5M`, `auto_mitigate=true`. No `failing_periods` / debouncing — Azure default of 1-of-1 evaluation period applies.
2. The breach window (FACT, payload + `az monitor metrics list`): metric value **2712 ms**, single PT1M sample at `2026-04-26T03:52:00Z`, `count=1`, `max=2712`, `avg=2712`. With aggregation = Average over PT5M, a single 2712 ms request makes the bucket equal 2712 ms. Rule fires.
3. The single call (FACT, `ServiceApiResult` dimensioned by `ActivityName,StatusCode`): one `vaultget` operation, `StatusCode=200`. KV healthy throughout — `Availability` metric = 100.0 in every PT15M bucket from 03:00Z to 06:45Z.
4. Why the KV is so quiet (FACT, 30-day `ServiceApiHit` Total/P1D): baseline traffic is **~1 call per day**, with deploy-day spikes (Apr 20 = 15, Apr 21 = 28 — likely Stefan's `2026-04-21-ootw-enable-authorised-immutability` work). Apr 25 = 0 hits, Apr 26 = the single 2712 ms call. The KV is a *bootstrap* vault (rarely accessed by design).
5. Why the alert is **stuck** in `Fired` (FACT for state, INFER for mechanism): `auto_mitigate` clears the alert only when the criterion evaluates to **FALSE**. With zero ServiceApiHits since 03:50Z (verified via `az monitor metrics list ServiceApiHit` over the last several hours), Azure's default no-data behavior for static metric criteria is to **preserve the prior state** (Fired) rather than flip the criterion to FALSE. So `auto_mitigate` never has a transition to act on. The rule will only auto-resolve once a future evaluation period both contains data **and** aggregates ≤1000 ms — otherwise manual state-change is required (see Recommended Action). Independently confirmed live: `az rest GET .../alerts/3d8b33a6-…` returns `alertState=New, monitorCondition=Fired, lastModified=2026-04-26T03:56:24Z` hours after the breach.
6. Caller of the slow call (UNVERIFIED[blocked: cross-subscription LAW access]): activity log returned empty for the window. The KV **does** have a Diagnostic Setting `diagnosticToMccLaw` forwarding `AuditEvent`, `AzurePolicyEvaluationDetails`, and `AllMetrics` to Log Analytics workspace `mcc-log-workspace-oqqp` in subscription `6c1ab7bd-97b5-4179-8077-ac85acf7bd03` (MCC management). The MC-VPP-dev SP I have access to cannot read that subscription, so I could not run the KQL query that would identify the caller. Operator with cross-sub Reader can run: `AzureDiagnostics | where ResourceProvider == "MICROSOFT.KEYVAULT" and Resource == "KV-VPPAGG-BOOTSTRAP-D" and TimeGenerated between (datetime(2026-04-26T03:48:00Z) .. datetime(2026-04-26T03:54:00Z)) | project TimeGenerated, OperationName, identity_claim_appid_g, CallerIPAddress, requestUri_s, ResultType, DurationMs`. Most plausible callers (consistent with daily 1-hit cadence): Azure Policy compliance scan, Defender-for-Cloud assessment, or a periodic provisioning probe. Caller identity does not change the recommendation.

## Recommended Action

### Now (on-call engineer)

Resolve in **two** systems, in this order:

1. **Rootly**: open `pbbtBV`, mark Resolved with comment:
   ```
   Benign single-sample false positive. Single vaultget request in PT5M window on
   idle bootstrap KV took 2712ms; KV Availability stayed at 100% throughout. Rule
   auto_mitigate=true but no further traffic to drive evaluation; default no-data
   behavior preserves the prior Fired state, so manual close on Azure side is also
   required. RCA in engineering-log shift_alerts_summary/2026-April (20-26).
   ```
2. **Azure** (otherwise the upstream alert sits Fired forever): change `Microsoft.AlertsManagement/alerts/3d8b33a6-d825-4f49-9708-cadbd34ef000` state to `Closed`. Two options:
   - Portal: open the alert (link is in the Rootly payload's `external_url` field) → *Investigate* → *Change alert state* → *Closed*.
   - CLI:
     ```bash
     az rest --method POST \
       --url "https://management.azure.com/subscriptions/839af51e-c8dd-4bd2-944b-a7799eb2e1e4/providers/Microsoft.AlertsManagement/alerts/3d8b33a6-d825-4f49-9708-cadbd34ef000/changestate?api-version=2018-05-05&newState=Closed"
     ```
3. Do **not** create an incident — KV is healthy, no customer-impact path.
4. Do **not** page upstream — module-fix is non-urgent (see Upstream).

### Skip — explicitly do NOT do

- Don't bump the threshold in `MC-VPP-Infrastructure/main` — the rule is **not** defined there. The local `terraform/metric-alert-key-vault.tf` only covers `aks-kv` (a different vault). Editing that file will not silence this alert.
- Don't disable the rule via `az monitor metrics alert update` — IaC drift; next CCoE module apply restores it.
- Don't add an Alert Processing Rule unless a recurrence-suppression decision is made by the platform owner.

## Upstream Recommendation

The rule is hardcoded in CCoE module `terraform-azure-keyvault` and re-applied to **every** product/env via `terraform-bootstrap`:

- File: `enecomanagedcloud/ccoe/terraform-azure-keyvault/locals.tf:22-40`
- Module: `git::https://enecomanagedcloud@dev.azure.com/enecomanagedcloud/CCoE/_git/terraform-azure-keyvault`
- Wrapper: `enecomanagedcloud/ccoe/terraform-bootstrap/keyvault.tf:1-2` at `?ref=v1.2.0`
- Consumer: `enecomanagedcloud/myriad-vpp/platform-bootstrap/src/bootstrap.tf:1-2` at `?ref=v0.4.0`, `for_each = var.products`

Open an issue against `terraform-azure-keyvault` (CCoE owner) suggesting one of:

1. **Switch to a sample-count-aware criterion (scheduled-query rule)**. Replace the static metric alert with `azurerm_monitor_scheduled_query_rules_alert_v2` (the module already exposes `default_scheduled_query_rules_alerts`) and KQL like:
   ```kusto
   AzureMetrics
   | where ResourceProvider == "MICROSOFT.KEYVAULT"
       and MetricName == "ServiceApiLatency"
   | summarize avg=avg(Average), n=sum(Count) by bin(TimeGenerated, 5m)
   | where n >= 5 and avg > 1000
   ```
   This requires multiple samples **and** a sustained breach.
   **Prerequisite**: every consuming KV must have a Diagnostic Setting routing `AllMetrics` to a Log Analytics workspace, otherwise the `AzureMetrics` table is empty and the rule silently never fires (an opposite-polarity defect — worse than the current noise). For the in-scope KV `kv-vppagg-bootstrap-d` this prerequisite is satisfied (`diagnosticToMccLaw` → `mcc-log-workspace-oqqp`); whether every consumer of `terraform-bootstrap` enforces the same is **not verified** here. The module-owner PR should bundle the diag-setting requirement (or template) with the rule change.
2. **Or keep a metric alert but add a `ServiceApiHit` count gate**. Add a second `criteria` block on the same rule: `metric_namespace="Microsoft.KeyVault/vaults", metric_name="ServiceApiHit", aggregation="Total", operator="GreaterThanOrEqual", threshold=N` (N=5 is a reasonable starting point). When both criteria must be true, the latency-AVG breach AND the minimum-sample-count must hold simultaneously, which kills the single-sample failure mode without requiring LAW. This is the cheapest fix that preserves the rule's intent.
3. **Or scope-exempt bootstrap vaults via a module flag**. Expose `var.default_metric_alerts_enabled = true|false` (or per-alert toggles); consumers known to be low-volume opt out. The seam already exists (`for_each = local.default_metric_alerts` at `alerts.tf:127`) — a one-line override. Less ambitious than #1/#2 but unblocks the immediate noise across all consumers.

(An earlier draft proposed switching aggregation from `Average` to `Maximum` plus a count gate. That is **wrong** — `Maximum` is per-bucket-max and is *more* outlier-sensitive than `Average`; it would not fix the single-slow-sample pathology. Keep `Average`.)

Pick #2 for shipping today (no LAW dependency); #1 for correctness if every consumer KV has the diag-setting prerequisite or is willing to gain it; #3 as a stopgap. Recurrence rate (~2 firings in last 1000 azure alerts) suggests this is on-radar-urgent, not on-fire-urgent.

## Evidence (anchored, FACT)

### Rootly payload (excerpt; full at `[T_DIR]/context/01-rootly-alert-pbbtBV.json`)

```json
{
  "short_id": "pbbtBV", "status": "acknowledged", "source": "azure",
  "started_at": "2026-04-25T20:56:24.133-07:00", "ended_at": null,
  "monitorCondition": "Fired", "severity": "Sev2", "signalType": "Metric", "monitoringService": "Platform",
  "alertRule": "kv-vppagg-bootstrap-d-kv-latency-above-1000ms",
  "alertTargetIDs": ["/subscriptions/839af51e-…/providers/microsoft.keyvault/vaults/kv-vppagg-bootstrap-d"],
  "condition": {
    "allOf": [{
      "metricName": "ServiceApiLatency", "metricNamespace": "microsoft.keyvault/vaults",
      "metricValue": 2712, "operator": "GreaterThan", "threshold": "1000",
      "timeAggregation": "Average"
    }],
    "windowStartTime": "2026-04-26T03:49:10.257Z", "windowEndTime": "2026-04-26T03:54:10.257Z", "windowSize": "PT5M"
  }
}
```

### Live Azure rule

```bash
az monitor metrics alert show \
  --name kv-vppagg-bootstrap-d-kv-latency-above-1000ms \
  --resource-group rg-vppagg-bootstrap-d
```
→ `enabled=true, severity=2, autoMitigate=true, evaluationFrequency=PT5M, windowSize=PT5M, criteria.allOf[StaticThresholdCriterion ServiceApiLatency Avg > 1000]`. Matches IaC byte-for-byte.

### Independent metric verification (PT15M aggregation across 31h)

```
2026-04-26T03:45:00Z avg=2712.0 max=2712.0 count=1.0
```
(Every other PT15M bucket from `2026-04-25T00:00:00Z` to `2026-04-26T07:00:00Z` is null/zero.)

### 30-day daily hit count (P1D)

```
2026-03-27..2026-04-04 ........ 1 1 1 1 6 1 1 1 1
2026-04-05..2026-04-13 ........ 0 1 1 1 4 0 1 1 1
2026-04-14..2026-04-22 ........ 1 0 1 1 1 1 15 28 1
2026-04-23..2026-04-26 ........ 1 1 0 1
```
Median = 1 hit/day. Spikes correlate with deploys (Apr 20-21 = `2026-04-21-ootw-enable-authorised-immutability` branch work).

### IaC source (FACT, file:line)

```hcl
# enecomanagedcloud/ccoe/terraform-azure-keyvault/locals.tf:22-40
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

Resource binding: `enecomanagedcloud/ccoe/terraform-azure-keyvault/alerts.tf:126-160` — `azurerm_monitor_metric_alert.default_main` with `for_each = local.default_metric_alerts`, `scopes = [azurerm_key_vault.main.id]`.

### Recurrence (FACT, rootly cli, last ~3.5 weeks of azure-source alerts)

| short_id | started_at | status | summary |
|---|---|---|---|
| `Anjhdp` | 2026-04-02T17:57:25Z | resolved | `kv-gurobi-platform-a-kv-latency-above-1000ms` |
| `pbbtBV` | 2026-04-26T03:56:24Z | acknowledged | `kv-vppagg-bootstrap-d-kv-latency-above-1000ms` (this one) |

## Hypothesis Ledger

| H | Status | Why |
|---|---|---|
| **H1**: Service Bus / messaging metric (parent task framing) | ELIMINATED | `metricNamespace = microsoft.keyvault/vaults`. No Service Bus involvement. |
| **H2**: Other Azure resource — Key Vault `ServiceApiLatency` | **STRONGLY SUPPORTED** | Resource id, metric name, observed value all align (Identity + Mechanism). Pending H4 disconfirmation to be promoted to CONFIRMED. |
| **H3**: Synthetic / heartbeat / non-Azure | ELIMINATED | `source=azure`, `signalType=Metric`, `monitoringService=Platform`. |
| **H4**: Microsoft regional control-plane micro-incident affecting KVs in westeurope | NOT FULLY DISCONFIRMED | `Microsoft.ResourceHealth/events` API returned no events for the window (probed via `az rest`); `Availability` metric stayed 100%; but Service Health does not consistently surface sub-minute control-plane blips, so absence is not proof. H4 and H2 may co-exist (vendor blip materialised on this idle KV's daily call) — neither changes the immediate operator action. |

## Residual Risk (this RCA does NOT prove)

- **Microsoft regional control-plane micro-incident** (UNVERIFIED[partial probe]) — a single 2712 ms `vaultget` is consistent with a brief Azure-side latency blip. Probed via `az rest GET .../Microsoft.ResourceHealth/events?...` for `ServiceIssue` events on 2026-04-26 03:00-05:00Z → 0 events returned for this subscription. Probed `Availability` metric → 100% throughout. **Not** cross-checked against other KVs in westeurope at the same minute, and Service Health does not always surface micro-blips. If the on-call engineer wants paranoid certainty before resolving, check `https://status.azure.com/` and the team Slack for any KV/westeurope chatter around 2026-04-26T03:50Z.
- **Caller identity** (UNVERIFIED[blocked: cross-subscription LAW access]) — diag setting `diagnosticToMccLaw` exists and routes `AuditEvent` + `AllMetrics` to LAW `mcc-log-workspace-oqqp` in subscription `6c1ab7bd-97b5-4179-8077-ac85acf7bd03` (MCC management). The MC-VPP-dev SP cannot read that subscription. KQL probe (caller resolves once an operator with cross-sub Reader runs it) is in §Mechanism step 6. Most likely caller (consistent with daily 1-hit cadence): Azure Policy compliance scan, Defender-for-Cloud assessment, or provisioning probe. Does not change recommendation.
- **Why staticThresholdFailingPeriods.numberOfEvaluationPeriods = 0** in the Rootly payload (INFER) — interpreted as "default 1/1 evaluation behavior". The live `az monitor metrics alert show` shows no `failing_periods` block on `criteria.allOf` (static-criteria don't carry one). Risk: if Azure has changed semantics, my "single sample fires it" claim could be off. Probability: low; the metric value (2712) > threshold (1000) under any failing-periods interpretation, so the firing is logically explained either way.
- **Threshold appropriateness across products** (INFER) — recommendation #1-#4 assume the 1000 ms threshold is the wrong instrument for low-volume vaults. For a *high-volume* product KV (e.g., a hot-path runtime KV), 1000 ms Average over PT5M may be the right gate. The CCoE module mistake is treating all KVs as one class; per-consumer override is the cheap fix.

## References

- Evidence dump (raw payload + cmd outputs): `[engineering-log]/.ai/tasks/2026-04-26-002_rootly-alert-pbbtbv-rca/context/02-evidence-summary.md`
- Plan + adversarial challenge: `[engineering-log]/.ai/tasks/2026-04-26-002_rootly-alert-pbbtbv-rca/plan/plan.md`
- IaC (alert source): `enecomanagedcloud/ccoe/terraform-azure-keyvault/{locals.tf:22-40, alerts.tf:126-160}`
- IaC (consumer): `enecomanagedcloud/myriad-vpp/platform-bootstrap/src/bootstrap.tf:1-2`
- Sibling alert (April 2): Rootly `Anjhdp` — same rule on `kv-gurobi-platform-a`.
