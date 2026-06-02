# SQL DB Health Event Alert — ACC (Preliminary Analysis)

**Date**: 2026-03-26
**Alert**: `mcdta-vpp-SqlDB-healthevent-a`
**Severity**: Sev2
**Rootly URL**: https://rootly.com/account/alerts/Ui3lMF?tab=payload
**Status**: Auto-resolved (total incident duration ~60 seconds)

---

## What Happened

3 databases on `vpp-sqlserver-a` experienced a **platform-initiated downtime** event on 2026-03-25 between 23:17 and 23:18 UTC. All 3 resolved within ~60 seconds.

### Timeline

```
23:17:16  ACTIVATED  Critical  ASSETPLANNING
23:17:16  Updated    Info      ASSETPLANNING
23:17:18  ACTIVATED  Critical  ASSETPLANNING-ELIA
23:17:18  Updated    Info      ASSETPLANNING-ELIA
23:17:18  ACTIVATED  Critical  ASSETPLANNING-TENNETDE
23:17:18  Updated    Info      ASSETPLANNING-TENNETDE
23:18:14  RESOLVED   Info      ASSETPLANNING           (~58s downtime)
23:18:16  RESOLVED   Info      ASSETPLANNING-TENNETDE  (~58s downtime)
23:18:19  RESOLVED   Info      ASSETPLANNING-ELIA      (~61s downtime)
23:31:12  ALERT FIRED (Rootly notified via webhook)
```

### Cause

- **Cause**: `PlatformInitiated`
- **Type**: `Downtime`
- **Meaning**: Azure performed an internal maintenance/failover operation on the underlying infrastructure. This was NOT caused by user activity, configuration change, or load.

---

## Affected Resources

| Database | Server | Elastic Pool | SKU | Status Now |
|----------|--------|-------------|-----|------------|
| `assetplanning` | vpp-sqlserver-a | vpp-sql-epool-a | BC_Gen5 (4 vCores) | Online |
| `assetplanning-elia` | vpp-sqlserver-a | vpp-sql-epool-a | BC_Gen5 (4 vCores) | Online |
| `assetplanning-tennetde` | vpp-sqlserver-a | vpp-sql-epool-a | BC_Gen5 (4 vCores) | Online |

**Not affected**: `assetmonitor`, `asset`, `assetplanning-assets`, `integration` (same server/pool, no health events)

**Separate server not affected**: `vpp-agg-sqlserver-a` / `siteregistry`

---

## Infrastructure Context

```
vpp-sqlserver-a (mcdta-rg-vpp-a-storage)
  └── vpp-sql-epool-a (BusinessCritical, Gen5, 4 vCores, zone-redundant)
       ├── assetplanning          ← AFFECTED
       ├── assetplanning-elia     ← AFFECTED
       ├── assetplanning-tennetde ← AFFECTED
       ├── assetmonitor           (not affected)
       ├── asset                  (not affected)
       ├── assetplanning-assets   (not affected)
       └── integration            (not affected)

vpp-agg-sqlserver-a (mcdta-rg-vpp-agg-a-storage)
  └── siteregistry                (not affected)
```

---

## Alert Rule Analysis

| Property | Value |
|----------|-------|
| Rule name | `mcdta-vpp-SqlDB-healthevent-a` |
| Type | Log Alert (scheduled KQL query) |
| Scope | Entire ACC subscription |
| Evaluation | Every 15 min, 15 min window |
| Threshold | >5 health activation events |
| Action group | `ag-trade-platform-a` → Rootly webhook only |
| Auto-mitigate | Yes |
| Created | 2024-03-25 (Terraform-managed) |

### KQL Query

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

---

## Assessment

### Is this a real incident?

**No** — this was a transient Azure platform maintenance event that self-resolved in ~60 seconds. BusinessCritical tier with zone redundancy means the failover was handled by the secondary replica. The databases are all online now.

### Is this recurring?

**No evidence of recurrence**. Activity log shows 0 SQL health events in the 5 days prior to this incident. All 19 health events in the last 7 days are from this single 2-minute window.

### Should the alert have fired?

**Debatable**. The threshold is >5 events in 15 min. We had 6 activations (3 DBs x 2 events each: Activated + Updated). The alert detected a real health event, but:

- The event self-resolved in 60 seconds
- BusinessCritical tier is designed to handle this transparently
- The threshold of 5 is low enough to trigger on a single platform failover affecting 3 DBs

---

## Recommendations (Morning Action Items)

### 1. No immediate action needed
All databases are online. This was a one-off platform event.

### 2. Consider tuning the alert
**Options**:
- **Raise threshold** from 5 to 10+ to avoid firing on transient failovers
- **Add a delay/suppression** window — fire only if events persist beyond 5 minutes (indicating actual downtime vs failover)
- **Filter out `PlatformInitiated`** with cause `Downtime` + `Resolved` within N minutes — these are expected for BC tier
- **Add `Resolved` check** — modify the KQL to only alert if there are Activated events WITHOUT corresponding Resolved events within the window

### 3. Consider enriching the alert payload
The current KQL projects limited fields. Adding `ResourceId` (the actual DB name) would make triage faster without needing to query the activity log separately.

---

## Verification Commands Used

```bash
# Login
enecotfvppmcloginacc

# SQL servers in ACC
az sql server list --query "[].{name:name, rg:resourceGroup, state:state}" -o table

# Databases on affected server
az sql db list --server vpp-sqlserver-a --resource-group mcdta-rg-vpp-a-storage -o table

# Elastic pool config
az sql elastic-pool show --server vpp-sqlserver-a -g mcdta-rg-vpp-a-storage -n vpp-sql-epool-a -o json

# Alert rule definition
az monitor scheduled-query show --name "mcdta-vpp-SqlDB-healthevent-a" -g mcdta-rg-vpp-a-res -o json

# Health event timeline
az monitor activity-log list --subscription b524d084-edf5-449d-8e92-999ebbaf485e --offset 168h \
  --query "[?contains(operationName.value || '','ealthevent')]" -o json

# Action group (notification routing)
az monitor action-group show --name "ag-trade-platform-a" -g rg-pltfrm-infra-a -o json
```
