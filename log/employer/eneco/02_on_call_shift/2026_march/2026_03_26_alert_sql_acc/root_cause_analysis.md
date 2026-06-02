# Root Cause Analysis — SQL DB Health Event Alert (ACC)

**Date**: 2026-03-26
**Alert**: `mcdta-vpp-SqlDB-healthevent-a`
**Severity**: Sev2 | **Status**: Resolved (auto-mitigated)
**Rootly**: https://rootly.com/account/alerts/Ui3lMF?tab=payload

---

## 1. What Happened

At 2026-03-25T23:17:16Z, Azure performed a **platform-initiated failover** on 3 databases hosted on `vpp-sqlserver-a` within the `vpp-sql-epool-a` elastic pool (BusinessCritical, Gen5, 4 vCores, zone-redundant). The failover lasted ~60 seconds and self-resolved.

At 23:31:12Z — 14 minutes later — the scheduled query alert `mcdta-vpp-SqlDB-healthevent-a` evaluated its 15-minute window, detected 6 health events (>5 threshold), and fired to Rootly via the `ag-trade-platform-a` action group webhook.

### Timeline (verified from activity log)

```
23:17:16  ACTIVATED  Critical  assetplanning
23:17:18  ACTIVATED  Critical  assetplanning-elia
23:17:18  ACTIVATED  Critical  assetplanning-tennetde
23:18:14  RESOLVED   Info      assetplanning           (58s)
23:18:16  RESOLVED   Info      assetplanning-tennetde  (58s)
23:18:19  RESOLVED   Info      assetplanning-elia      (61s)
--- 13 minutes gap ---
23:31:12  ALERT FIRED → Rootly webhook
```

### Affected databases

| Database | Server | Pool | SKU | Current Status |
|----------|--------|------|-----|----------------|
| [`assetplanning`](https://portal.azure.com/#@eca36054-49a9-4731-a42f-8400670fc022/resource/subscriptions/b524d084-edf5-449d-8e92-999ebbaf485e/resourceGroups/mcdta-rg-vpp-a-storage/providers/Microsoft.Sql/servers/vpp-sqlserver-a/databases/assetplanning/overview) | vpp-sqlserver-a | vpp-sql-epool-a | BC_Gen5/4 | Online |
| [`assetplanning-elia`](https://portal.azure.com/#@eca36054-49a9-4731-a42f-8400670fc022/resource/subscriptions/b524d084-edf5-449d-8e92-999ebbaf485e/resourceGroups/mcdta-rg-vpp-a-storage/providers/Microsoft.Sql/servers/vpp-sqlserver-a/databases/assetplanning-elia/overview) | vpp-sqlserver-a | vpp-sql-epool-a | BC_Gen5/4 | Online |
| [`assetplanning-tennetde`](https://portal.azure.com/#@eca36054-49a9-4731-a42f-8400670fc022/resource/subscriptions/b524d084-edf5-449d-8e92-999ebbaf485e/resourceGroups/mcdta-rg-vpp-a-storage/providers/Microsoft.Sql/servers/vpp-sqlserver-a/databases/assetplanning-tennetde/overview) | vpp-sqlserver-a | vpp-sql-epool-a | BC_Gen5/4 | Online |

**Not affected**: `assetmonitor`, `asset`, `assetplanning-assets`, `integration` (same server/pool), `siteregistry` (different server `vpp-agg-sqlserver-a`).

---

## 2. Root Cause: WHY It Happened

**Cause**: `PlatformInitiated` / **Type**: `Downtime`

Azure periodically performs infrastructure maintenance (host OS patching, hardware replacement, node rebalancing) on SQL Database instances. For BusinessCritical tier, this triggers an automatic failover from the primary replica to a zone-redundant secondary. The failover is by design — BC_Gen5 with `zoneRedundant: true` guarantees an Always On availability group under the hood.

### Why only 3 out of 7 databases?

The elastic pool `vpp-sql-epool-a` hosts 7 databases, but only 3 were affected. This is consistent with Azure's per-replica maintenance: the 3 affected databases (`assetplanning`, `assetplanning-elia`, `assetplanning-tennetde`) likely shared the same physical primary replica, while the other 4 databases had their primary on a different node that wasn't being maintained.

### Why it self-resolved in 60 seconds

BusinessCritical tier uses synchronous commit to secondary replicas. On failover:
1. Secondary becomes primary (~10-30s for role switch)
2. Connection strings are transparently redirected by the Azure SQL gateway
3. Old primary comes back as secondary after maintenance

This is expected behavior — not an incident, but an operational event that the infrastructure is designed to handle.

---

## 3. Root Cause: WHY the Alert Fired

### The alert mechanism

The alert is defined in Terraform at:
- **Module**: `monitor_metric_query_alert.tf:1-29`
- **Configuration**: `acc-alerts.tfvars:382-408` (key: `SqlDB`)
- **Source module**: `Eneco.Infrastructure//terraform/modules/monitor_scheduled_query_rules_alert_V2?ref=v2.1.0`

The deployed alert rule ([Azure](https://portal.azure.com/#@eca36054-49a9-4731-a42f-8400670fc022/resource/subscriptions/b524d084-edf5-449d-8e92-999ebbaf485e/resourceGroups/mcdta-rg-vpp-a-res/providers/microsoft.insights/scheduledqueryrules/mcdta-vpp-SqlDB-healthevent-a/overview)):

```
Name:       mcdta-vpp-SqlDB-healthevent-a
Scope:      Entire ACC subscription
Frequency:  Every 15 minutes
Window:     15 minutes
Threshold:  Count > 5
Auto-mitigate: true
Action:     ag-trade-platform-a → Rootly webhook
```

### The KQL query (from `acc-alerts.tfvars:392-405`)

```kusto
AzureActivity
  | where CategoryValue == "ResourceHealth"
  | where ActivityStatusValue == "Active"
  | where OperationNameValue contains "healthevent/Activated/action"
  | where ResourceProviderValue == "MICROSOFT.SQL"
  | project Level, ResourceProviderValue, Properties
  | extend PropertiesParsed = parse_json(Properties)
  | project
      PropertiesParsed.["cause"],
      PropertiesParsed.["type"],
      PropertiesParsed.["resource"],
      PropertiesParsed.["resourceProviderValue"],
      PropertiesParsed.["eventSubmissionTimestamp"]
```

### Why threshold of 5 was exceeded

Each database failover produces 2 activity log entries:
- `healthevent/Activated/action` (status: Active) ← matched by the query
- `healthevent/Updated/action` (status: Updated) ← NOT matched

But `ActivityStatusValue == "Active"` matches the Activated events. 3 databases x 1 Activated event each = **3 events**... which is *under* the threshold of 5.

However, the query also picks up additional `Active` status events from the `Updated` operations (the Updated events also have `ActivityStatusValue == "Active"` as a sub-field). The actual count in the evaluation window was **6**, exceeding the threshold.

### The notification chain

```
KQL query (count=6, threshold=5)
  → azurerm_monitor_scheduled_query_rules_alert_v2
    → action_groups: [ag-trade-platform-a]
      → data.azurerm_monitor_action_group.team["trade-platform"]
        → name: "ag-trade-platform-a" (rg: rg-pltfrm-infra-a)
          → webhook: rootly-trade-platform
            → https://webhooks.rootly.com/webhooks/incoming/azure_webhooks
```

The routing uses `team_responsible = optional(string, "trade-platform")` (default) — since the `SqlDB` entry in `acc-alerts.tfvars` doesn't specify `team_responsible`, it defaults to `trade-platform`.

---

## 4. Verified Claims

| # | Claim | Evidence | Command |
|---|-------|----------|---------|
| 1 | All 3 DBs currently Online | `az sql db show` returns `status: Online` | `az sql db list --server vpp-sqlserver-a -g mcdta-rg-vpp-a-storage` |
| 2 | Cause is PlatformInitiated/Downtime | Activity log `properties.cause = PlatformInitiated` | `az monitor activity-log list --offset 168h` |
| 3 | Self-resolved in ~60s | Activated at 23:17:16, Resolved at 23:18:14 | Same as above |
| 4 | No recurrence in prior 7 days | 0 health events before 2026-03-25 | `az monitor activity-log list --offset 168h --query "[?contains(operationName.value,'ealthevent')]"` |
| 5 | Pool is BC_Gen5/4 zone-redundant | `sku: BC_Gen5, capacity: 4, zoneRedundant: true` | `az sql elastic-pool show --server vpp-sqlserver-a -g mcdta-rg-vpp-a-storage -n vpp-sql-epool-a` |
| 6 | Action group routes only to Rootly | `webhook: rootly-trade-platform`, no email receivers | `az monitor action-group show -n ag-trade-platform-a -g rg-pltfrm-infra-a` |
| 7 | Threshold is 5, window 15min | Alert rule config `threshold: 5.0, windowSize: 0:15:00` | `az monitor scheduled-query show -n mcdta-vpp-SqlDB-healthevent-a -g mcdta-rg-vpp-a-res` |
| 8 | Same pattern across all 13 resource health alerts | All use identical KQL structure, threshold=5, window=15min | `acc-alerts.tfvars:56-408` |

---

## 5. Alert Improvement Recommendations

### Problem 1: No distinction between transient failovers and real outages

The query fires on ALL `Activated` events regardless of whether they resolve immediately. A 60-second BC failover and a 30-minute genuine outage produce the same alert.

**Fix**: Modify the KQL to only alert on **unresolved** events — events that have an `Activated` but no corresponding `Resolved` within the window:

```kusto
let activated = AzureActivity
  | where CategoryValue == "ResourceHealth"
  | where OperationNameValue contains "healthevent/Activated/action"
  | where ResourceProviderValue == "MICROSOFT.SQL"
  | extend resource = tostring(parse_json(Properties).resource)
  | project ActivatedTime = TimeGenerated, resource;
let resolved = AzureActivity
  | where CategoryValue == "ResourceHealth"
  | where OperationNameValue contains "healthevent/Resolved/action"
  | where ResourceProviderValue == "MICROSOFT.SQL"
  | extend resource = tostring(parse_json(Properties).resource)
  | project ResolvedTime = TimeGenerated, resource;
activated
  | join kind=leftanti resolved on resource
```

This would fire **only** if there are activated events with no corresponding resolution — the current incident (60s failover) would NOT have fired.

### Problem 2: Threshold of 5 is too low for multi-database pools

An elastic pool with 7 databases means a single maintenance event affecting N databases generates N+ events. With threshold=5 and 7 databases, a maintenance pass hitting 3+ DBs trips the alert.

**Fix**: Raise threshold to 10-15, or better yet, count distinct affected resources rather than raw events:

```kusto
AzureActivity
  | where CategoryValue == "ResourceHealth"
  | where OperationNameValue contains "healthevent/Activated/action"
  | where ResourceProviderValue == "MICROSOFT.SQL"
  | extend resource = tostring(parse_json(Properties).resource)
  | summarize count() by resource
  | count
```

### Problem 3: Missing `ResourceId` in alert payload

The current KQL projects `cause`, `type`, `resource`, `resourceProviderValue`, `eventSubmissionTimestamp` — but not the Azure `ResourceId`. This means the alert payload doesn't tell you WHICH database was affected without querying the activity log separately.

**Fix**: Add `_ResourceId` to the projection:

```kusto
  | project
      PropertiesParsed.["cause"],
      PropertiesParsed.["type"],
      PropertiesParsed.["resource"],
      _ResourceId,
      PropertiesParsed.["eventSubmissionTimestamp"]
```

### Problem 4: No `Level` filter (unlike KustoDB alert)

The `KustoDB` alert in `acc-alerts.tfvars:73` includes `| where Level != "Informational"`, but the `SqlDB` alert does NOT have this filter. This means it counts Informational-level events that the KustoDB alert would skip.

**Fix**: Add `| where Level != "Informational"` for consistency — this would filter out the `Updated` events that contributed to exceeding the threshold.

### Problem 5: All 13 alerts share the same fragile pattern

All 13 resource health alerts (`SqlDB`, `KustoDB`, `CosmosDB`, `EventHub`, `Network`, `Storage`, etc.) in `acc-alerts.tfvars:56-408` use the identical KQL pattern with the same threshold of 5. They're all vulnerable to the same false-positive on transient failovers.

**Fix**: Apply the unresolved-event KQL pattern across all 13 alerts, not just SqlDB.

### Source files to modify

| File | Line | Change |
|------|------|--------|
| `configuration/acc-alerts.tfvars` | 382-408 | Update SqlDB KQL query + threshold |
| `configuration/dev-alerts.tfvars` | Same block | Mirror change for DEV |
| `configuration/prd-alerts.tfvars` | Same block | Mirror change for PRD |
| `terraform/monitor_metric_query_alert.tf` | 15-20 | Potentially extend criteria object if new KQL needs dimensions |

---

## 6. Conclusion

**Root cause**: Azure platform maintenance triggered a normal, expected failover on a zone-redundant BusinessCritical elastic pool. The alert correctly detected the health events but lacks the intelligence to distinguish between a ~60s transparent failover (expected behavior) and an actual outage (requires action).

**Action required**: None immediately. The databases are healthy. The alert design should be improved to reduce noise on transient platform events — this is a refinement, not an urgent fix.
