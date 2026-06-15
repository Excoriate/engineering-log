## Input

- Rootly alert: [E89PYM](https://rootly.com/account/alerts/E89PYM) — `gurobi-cosmos-normalized-ru-consumption-a`
- Azure investigate: [Portal](https://portal.azure.com/#view/Microsoft_Azure_Monitoring_Alerts/Investigate.ReactView/alertId/%2fsubscriptions%2fb524d084-edf5-449d-8e92-999ebbaf485e%2fresourceGroups%2frg-gurobi-platform-a%2fproviders%2fMicrosoft.AlertsManagement%2falerts%2f1c74b00e-7e6a-4dd1-9589-de15cb87f000)

## Alert

| Field | Value |
|-------|-------|
| Rootly | [E89PYM](https://rootly.com/account/alerts/E89PYM) |
| Rootly status | `triggered` |
| Rule | `gurobi-cosmos-normalized-ru-consumption-a` |
| Severity | Sev2 |
| Source | Azure Monitor (Metric) |
| Environment | acceptance |
| Fired (UTC) | `2026-06-15T15:44:03.4368457Z` |
| Azure resource | `cosmosdb-gurobi-platform-a` (`rg-gurobi-platform-a`) |
| Subscription | `b524d084-edf5-449d-8e92-999ebbaf485e` |
| Metric | `NormalizedRUConsumption` — **77.67%** avg (threshold **> 75%**) |
| Window | PT15M (`2026-06-15T15:26:47.898Z` → `2026-06-15T15:41:47.898Z`) |
| Monitor condition | Fired |

### Description

Trigger when normalized RU consumption is greater than 75% for more than 5 minutes,
which may indicate that the provisioned throughput is not sufficient for the workload.
This alert can help identify performance issues and the need to scale up the Cosmos DB account.

### Rootly payload

```json
{
  "ID": "3a71361e-f8c6-4c4e-8a89-ae5a5d892c5c",
  "data": {
    "essentials": {
      "alertId": "/subscriptions/b524d084-edf5-449d-8e92-999ebbaf485e/providers/Microsoft.AlertsManagement/alerts/1c74b00e-7e6a-4dd1-9589-de15cb87f000",
      "severity": "Sev2",
      "alertRule": "gurobi-cosmos-normalized-ru-consumption-a",
      "signalType": "Metric",
      "alertRuleID": "/subscriptions/b524d084-edf5-449d-8e92-999ebbaf485e/resourcegroups/rg-gurobi-platform-a/providers/microsoft.insights/metricalerts/gurobi-cosmos-normalized-ru-consumption-a",
      "description": "Trigger when normalized RU consumption is greater than 75% for more than 5 minutes,\nwhich may indicate that the provisioned throughput is not sufficient for the workload.\nThis alert can help identify performance issues and the need to scale up the Cosmos DB account.\n",
      "firedDateTime": "2026-06-15T15:44:03.4368457Z",
      "originAlertId": "b524d084-edf5-449d-8e92-999ebbaf485e_rg-gurobi-platform-a_microsoft.insights_metricalerts_gurobi-cosmos-normalized-ru-consumption-a_-1754837546",
      "alertTargetIDs": [
        "/subscriptions/b524d084-edf5-449d-8e92-999ebbaf485e/resourcegroups/rg-gurobi-platform-a/providers/microsoft.documentdb/databaseaccounts/cosmosdb-gurobi-platform-a"
      ],
      "monitorCondition": "Fired",
      "essentialsVersion": "1.0",
      "investigationLink": "https://portal.azure.com/#view/Microsoft_Azure_Monitoring_Alerts/Investigate.ReactView/alertId/%2fsubscriptions%2fb524d084-edf5-449d-8e92-999ebbaf485e%2fresourceGroups%2frg-gurobi-platform-a%2fproviders%2fMicrosoft.AlertsManagement%2falerts%2f1c74b00e-7e6a-4dd1-9589-de15cb87f000",
      "monitoringService": "Platform",
      "configurationItems": [
        "cosmosdb-gurobi-platform-a"
      ],
      "targetResourceType": "microsoft.documentdb/databaseaccounts",
      "alertContextVersion": "1.0",
      "targetResourceGroup": "rg-gurobi-platform-a"
    },
    "alertContext": {
      "condition": {
        "allOf": [
          {
            "operator": "GreaterThan",
            "threshold": "75",
            "dimensions": [],
            "metricName": "NormalizedRUConsumption",
            "metricValue": 77.6666666666667,
            "webTestName": null,
            "metricNamespace": "microsoft.documentdb/databaseaccounts",
            "timeAggregation": "Average"
          }
        ],
        "windowSize": "PT15M",
        "windowEndTime": "2026-06-15T15:41:47.898Z",
        "windowStartTime": "2026-06-15T15:26:47.898Z",
        "staticThresholdFailingPeriods": {
          "minFailingPeriodsToAlert": 0,
          "numberOfEvaluationPeriods": 0
        }
      },
      "properties": null,
      "conditionType": "SingleResourceMultipleMetricCriteria"
    },
    "customProperties": null
  },
  "rootly": {
    "title": "gurobi-cosmos-normalized-ru-consumption-a",
    "description": "Trigger when normalized RU consumption is greater than 75% for more than 5 minutes,\nwhich may indicate that the provisioned throughput is not sufficient for the workload.\nThis alert can help identify performance issues and the need to scale up the Cosmos DB account.",
    "alert_source_url": "https://portal.azure.com/#view/Microsoft_Azure_Monitoring_Alerts/Investigate.ReactView/alertId/%2fsubscriptions%2fb524d084-edf5-449d-8e92-999ebbaf485e%2fresourceGroups%2frg-gurobi-platform-a%2fproviders%2fMicrosoft.AlertsManagement%2falerts%2f1c74b00e-7e6a-4dd1-9589-de15cb87f000",
    "alerting_targets": [
      {
        "id": "1b6ee744-4aca-45ed-9d00-2d1d2b5edbfa",
        "type": "EscalationPolicy"
      }
    ]
  },
  "schemaId": "azureMonitorCommonAlertSchema",
  "routing_rules": [
    {
      "id": "ec1b8ab3-cc70-4d41-9016-bfa6384b0d1f",
      "targets": [
        {
          "id": "1b6ee744-4aca-45ed-9d00-2d1d2b5edbfa",
          "type": "EscalationPolicy"
        }
      ]
    }
  ],
  "alert_urgency_id": "0ef2c622-8ccb-468d-8bfe-1d2401b6374d",
  "rootly_alert_status": "triggered"
}
```

## Context provided

**ADO project:** [Myriad - VPP](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP) (`enecomanagedcloud`)

**Environment (this alert):** acceptance — `cosmosdb-gurobi-platform-a` in `rg-gurobi-platform-a` (subscription `b524d084-edf5-449d-8e92-999ebbaf485e`). Gurobi platform resources and metric alerts are **not** in `MC-VPP-Infrastructure`; they live in the Gurobi IaC repo below.

**Gurobi repos** (from `eneco-context-repos` territory map):

| Repo | Role | Branch | ADO |
|------|------|--------|-----|
| [gurobi-infrastructure](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/gurobi-infrastructure) | IaC — Cosmos DB, compute servers, metric alerts (`gurobi-cosmos-*`), env configs under `src/` | `main` | Myriad - VPP |
| [gurobi-azuredevops](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/gurobi-azuredevops) | Application / DevOps — pipelines, deployment automation for Gurobi Compute | `main` | Myriad - VPP |
| [gurobi-gitops](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/gurobi-gitops) | GitOps — ArgoCD / cluster deployment config for Gurobi workloads | `main` | Myriad - VPP |

**Related (alert routing, not Gurobi-specific IaC):**

| Repo | Role | ADO |
|------|------|-----|
| [platform-infrastructure](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/platform-infrastructure) | Rootly live-call routing (`/terraform/infrastructure/rootly.tf`) | Myriad - VPP |

**Prior incident on same resource:** [2026-03-27 Gurobi Cosmos throttling RCA](../../../2026_march/2026_03_27_gurobi_throttling_alert/root-cause-analysis.md) — same `cosmosdb-gurobi-platform-a`, IaC source `gurobi-infrastructure/src/`.

### Skills to use

**Load first:** `eneco-oncall-intake-rootly` — Rootly alert intake for `E89PYM` / `gurobi-cosmos-normalized-ru-consumption-a` (quick-triage or deep-enrich; IaC traceback targets `gurobi-infrastructure`, not `MC-VPP-Infrastructure`).

**Rootly (mechanics):**

- `eneco-tools-rootly` — decode Azure Monitor payload, query alert history/patterns, ack/resolve, on-call schedule

**Eneco territory & runtime:**

- `eneco-tools-connect-mc-environments` — MC acceptance subscription access (`b524d084-…`); turn OFF IP whitelist after probes

> **Note (`eneco-tools-connect-mc-environments`):** When you access MC environments, turn OFF whitelisting after completing your task to prevent configuration drift.

**Obsidian / 2ndbrain** — vault already holds Gurobi canon; use transport + recall before re-deriving from scratch:

| Skill | When here |
|-------|-----------|
| `2ndbrain-obsidian` | **Always first for vault** — search/read existing Gurobi notes under `$SECOND_BRAIN_PATH/2-areas/work-eneco/` |
| `2ndbrain-knowledge-build` | After diagnosis if a **new** pattern, recipe, or incident page is warranted (not for initial triage) |
| `2ndbrain-knowledge-update` | After vault writes — relink neighborhood, fix backlinks, reconcile with existing Gurobi canon |
| `2ndbrain-memory-consolidate` | Session end — promote durable lessons to `llm-wiki/` + `.ai/memory/lessons-learned.json` |

**Vault anchors** (read via `2ndbrain-obsidian` before deep investigation):

- `2-areas/work-eneco/eneco-vpp-fto/eneco-vpp-gurobi-cosmosdb-throttling-pattern.md` — RU / 429 burst pattern on `cosmosdb-gurobi-platform-a` (same resource class as this alert)
- `2-areas/work-eneco/eneco-vpp-architecture/eneco-vpp-gurobi-cluster-architecture.md` — Gurobi platform topology
- `2-areas/work-eneco/eneco-vpp-platform/eneco-oncall-recognition-week-2026-06-08.md` — known-vs-novel Gurobi alert routing (self-resolve vs persistent RU exhaustion)

**Not for this incident:** `eneco-fbe-troubleshoot` (FBE/Sandbox only).

**Session artifacts:** `on-call-log-entry` (log directory structure) · `how-to-feynman` (final learning doc per UAC below)

### UAC

- You have to use, at the end when there's full confidence of the result obtained, the `how-to-feynman`skill, so it's explained in a .md document what you did, how, why, etc. So, I learn. I must be able to understand deeply your rationale, and replicate it by myself. If not, it's a failure.
- Want a clear hot-to-fix or improve, with a creat spec that I can follow or an agent can follow to implement this fix, either in the alert,gurobi, etc.

