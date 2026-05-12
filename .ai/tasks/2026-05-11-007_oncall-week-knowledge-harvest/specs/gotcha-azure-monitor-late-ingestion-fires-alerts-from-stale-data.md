---
task_id: 2026-05-11-007
agent: claude-code
status: complete
summary: Spec for new vault gotcha — Azure Monitor scheduled-query alerts can fire on data ingested into the workspace minutes-to-hours after the data's TimeGenerated (during Microsoft platform latency incidents like 5Z1B-6KG); Azure's engine waits for late-arriving data and evaluates by ingestion_time. Ready to apply to llm-wiki/learnings/gotchas/.
spec_target_path: $SECOND_BRAIN_PATH/llm-wiki/learnings/gotchas/azure-monitor-late-ingestion-fires-alerts-from-stale-data.md
spec_action: create
spec_zone: learnings/gotchas
spec_status: ready_to_apply
---

# Spec — Gotcha: Azure Monitor Late-Ingestion Fires Alerts From Stale Data

## Target Path

`$SECOND_BRAIN_PATH/llm-wiki/learnings/gotchas/azure-monitor-late-ingestion-fires-alerts-from-stale-data.md`

## Frontmatter (apply verbatim)

```yaml
---
description: "Azure Monitor V2 scheduled-query-rules with default time-scoping evaluate windows by ingestion_time(), NOT TimeGenerated. During Microsoft platform latency incidents (e.g., 5Z1B-6KG: Log Analytics + Application Insights intermittent data latency in West Europe, 2026-05-11), workspace rows can land minutes-to-hours after their emission timestamp. The Azure scheduled-query engine has a built-in late-data-settling period that delays evaluation of recent windows until late-arriving data has had a chance to settle. Net effect: an alert can fire ~20+ minutes AFTER the underlying event's TimeGenerated, on data whose nominal timestamp is BEFORE the rule's window evaluation. Authors of alert rules MUST add narrowing filters (ResourceProvider, ActivityStatusValue, impactedServices, _ResourceId) and SHOULD prefer CategoryValue='ResourceHealth' + OperationNameValue contains 'healthevent/Activated/action' over raw 'ServiceHealth' to avoid matching Microsoft's full announcement stream."
type: gotcha
domain: tech
status: active
source: agent
created: 2026-05-11
last_validated: 2026-05-11
severity: high
confidence: validated
scope: "Azure Monitor scheduled-query alerts evaluating AzureActivity / Log Analytics tables in workspaces that may experience ingestion latency; applies to all Eneco prd/acc/dev workspaces during Microsoft incidents that affect West Europe ingestion."
tags: [azure-monitor, log-analytics, ingestion-latency, scheduled-query-rules, microsoft-incident-5z1b-6kg, alert-noise, kql, eneco-vpp, west-europe]
---
```

## Body

### Trigger

- An Azure scheduled-query-rule fires with `windowStartTime` earlier than NOW by an unexpected margin (15+ minutes for a 5-min window rule)
- The alert payload's `metricValue` is correct relative to its window, but no recent Eneco-side action explains the fire
- Microsoft Service Health blade shows an active or recently-mitigated incident affecting Log Analytics / Application Insights data latency in the workspace's region
- `ingestion_time()` of the underlying rows is significantly later than their `TimeGenerated`

### Symptom signature

```text
Rule: <rule-name>
Fired at: T (now)
windowStartTime: T-15min, windowEndTime: T-10min (5-min window evaluated ~10 min AFTER its nominal end)
metricValue: 2.0 (or N matching the threshold)
Triggering rows (by TimeGenerated): T-17min, T-16min  (predate windowStart? confusing)
Triggering rows (by ingestion_time()): T-3min, T-2min (inside the window's evaluation, makes sense)
```

### Root cause mechanism

Azure Monitor V2 scheduled-query-rules with default time-scoping **evaluate windows using `ingestion_time()`**, NOT `TimeGenerated`. The engine has a built-in late-data-settling period to wait for late-arriving rows before evaluating a window. When Microsoft's platform has a backlog (e.g., 5Z1B-6KG: Log Analytics + Application Insights intermittent data latency in West Europe), rows ingest minutes-to-hours after their emission time. The settling period delays evaluation; the now-late-arrived rows fall into the rule's window; the rule fires on data whose nominal `TimeGenerated` is much earlier.

### Falsifier KQL (to prove the mechanism on a live alert)

```kusto
AzureActivity
| where TimeGenerated between (datetime(<WINDOW_START>) .. datetime(<WINDOW_END>))
| where CategoryValue == "<rule's category>"
| project TimeGenerated, IngestionTime=ingestion_time(), ActivityStatusValue, EventDataId, CorrelationId
```

If `IngestionTime - TimeGenerated > 10 minutes` and an active Microsoft Service Health incident affects the workspace region, the late-ingestion mechanism is confirmed.

### Defense (rule authoring)

1. **Always narrow `CategoryValue` predicates** — `AzureActivity | where CategoryValue == "ServiceHealth"` is wrong on its own; add `ActivityStatusValue`, `impactedServices`, `Properties.communication contains "<region>"`, etc.
2. **For per-resource health, use `ResourceHealth`** with `OperationNameValue contains "healthevent/Activated/action"` and `ResourceProviderValue == "MICROSOFT.XXX"` (the IaC pattern in `prd-alerts.tfvars`)
3. **Set `autoMitigate=true`** when criteria can be naturally re-evaluated cleanly (sibling lesson: [[automitigate-false-orthogonal-to-severity-needs-manual-close-runbook]])
4. **Verify the rule against the next Microsoft platform incident** — run a backtest KQL against a known prior backlog event before approving a sev-0 rule

### Verification probes

```bash
# 1. Get the rule's actual evaluation window from the alert payload
az rest --method GET \
  --url "https://management.azure.com/subscriptions/<SUB>/providers/Microsoft.AlertsManagement/alerts/<UUID>?api-version=2019-05-05-preview" \
  --query "properties.essentials.{state:alertState, condition:monitorCondition, fired:startDateTime, windowStart:windowStartDateTime, windowEnd:windowEndDateTime, value:metricValue}" -o json

# 2. Confirm late ingestion in the workspace
az monitor log-analytics query --workspace <WORKSPACE_GUID> \
  --analytics-query "AzureActivity | where ingestion_time() between (datetime(<FIRE_TIME-5m>) .. datetime(<FIRE_TIME>)) | where TimeGenerated < (ingestion_time() - 10m) | project TimeGenerated, ingestion_time(), Latency=(ingestion_time() - TimeGenerated)" -o table

# 3. Cross-check Microsoft Service Health blade for active incidents affecting the workspace region
```

## Cross-Links

- [[2026-05-11-oncall-shift-trade-platform-quad-incident]] — episode of origin (Incident 1, mechanism)
- [[out-of-iac-alerts-decay-silently-quarterly-inventory-diff]] — sibling lesson about WHY the rule existed in the first place
- [[automitigate-false-orthogonal-to-severity-needs-manual-close-runbook]] — sibling lesson
- [[openshift-sanity-check-rule-out-not-diagnose]] — pattern to rule out cluster impact when this mechanism fires
- [[azure-alert-close-two-plane-azure-plus-servicenow]] — close pattern after rule out
- Source RCA: `log/employer/eneco/02_on_call_shift/2026_05_11_cmc_alert_vpp_cluster_prod/rca.md` (504 lines, v2.0 with adversarial mutation log)
- Microsoft incident: tracking ID `5Z1B-6KG`, customer-impact window 2026-05-11 06:40–12:45 UTC
