---
title: "Validation report — RCA + all outcomes re-checked against Terraform MCP + Microsoft Learn"
description: "Per-claim re-validation of every implementable assertion in the RCA, fix spec, how-to, and both PR specs, with source and verdict"
timestamp: 2026-06-15T19:15:00Z
status: complete
category: validation
authors: ["Alex Torres Ruiz (with Claude Code)"]
task_id: 2026-06-15-001
agent: coordinator
summary: >-
  Re-validated every implementable claim across rca.md, fix.md, how-to-feynman.md, and the two PR specs
  against the Terraform Registry MCP (azurerm, rootly) and Microsoft Learn. Caught and corrected 5
  PR-breaking errors in the Spec 1 draft (Mongo log category/table/column, the diagnostic-setting block
  names + Dedicated destination, the metric-vs-log rate layer, and the provider-version provenance) and
  added 2 validated caveats to fix.md (the --max-throughput 4000 minimum; the 10k single-partition
  ceiling source). One item remains unverifiable via the MCP (the optional rootly_escalation_policy
  resource) and is flagged in Spec 2. All HCL now matches azurerm v4 (repo pin 4.41.0); the final gate
  is `terraform validate` against the pinned versions.
---

# Validation Report — RCA + All Outcomes

**Method.** Every implementable claim was checked against an authoritative external source: the **Terraform Registry MCP** (`hashicorp/azurerm`, `rootlyhq/rootly`) for HCL/provider schemas, and **Microsoft Learn** for Azure metric/log/CLI semantics. The live 2026-06-15 measurements were produced by executed `az` commands this session. "CONFIRMED" = source matches the artifact; "CORRECTED" = a draft error was found and fixed; "FLAGGED" = could not verify, surfaced in the artifact.

## A. Spec 1 — `gurobi-infrastructure` (azurerm; repo pins 4.41.0)

| Claim in spec | Source checked | Verdict |
|---|---|---|
| `azurerm_monitor_metric_alert` `dynamic_criteria` block: `alert_sensitivity` (Low/Medium/High), `operator` GreaterThan, `dimension`, `evaluation_total/failure_count`; `action.action_group_id` **singular** | TF MCP, azurerm docs (4.77.0) | **CONFIRMED** — and v4-stable (block present unchanged across azurerm v4; repo's 4.41.0 is same major) |
| `azurerm_monitor_scheduled_query_rules_alert_v2`: `criteria{query,time_aggregation_method,metric_measure_column,operator,threshold,failing_periods}`, `action.action_groups` **plural**, managed-`identity` needed to query the workspace | TF MCP, azurerm docs | **CONFIRMED** |
| `azurerm_monitor_diagnostic_setting` block names | TF MCP, azurerm docs | **CORRECTED** — draft used `metric {}`; current schema is **`enabled_metric {}`** (the v3→v4 rename). Spec now uses only **`enabled_log`** (no enabled_metric needed) |
| Resource-specific table requires `log_analytics_destination_type = "Dedicated"` | TF MCP + MS Learn (monitor-resource-logs) | **CORRECTED** — draft omitted it; without it logs land in legacy `AzureDiagnostics` and the KQL matches nothing |
| Mongo API log **category** = `MongoRequests` (not `DataPlaneRequests`) | MS Learn (monitor-reference) | **CORRECTED** |
| Resource-specific **table** = `CDBMongoRequests` (not `CDBDataPlaneRequests`); throttle **column** = `ErrorCode in ("429","16500")` (not `StatusCode`) | MS Learn (mongodb/diagnostic-queries) | **CORRECTED** |
| The log-based rate measures the **protocol / retry-inflated** layer (~34.5%), not the backend 2.82% → must NOT be a ">5%" pager | MS Learn (driver retry ≤9×) + live metric split | **CORRECTED approach** — primary is now a dynamic-threshold metric alert on backend `TotalRequests`/`StatusCode=429` |
| `TotalRequests` exposes a `StatusCode` dimension on `Microsoft.DocumentDB/databaseAccounts` | Live `az monitor metrics list` (used to obtain 586) | **CONFIRMED (executed)** |
| Provider version provenance | repo `src/provider.tf` | **CORRECTED** — spec said "validated vs 4.77.0"; repo pins **4.41.0**; provenance now states v4-stability + the `terraform validate` gate |

## B. fix.md — `gurobi-infrastructure` capacity (T1)

| Claim | Source | Verdict |
|---|---|---|
| `az cosmosdb mongodb collection throughput update --max-throughput` is the correct command | MS Learn CLI ref | **CONFIRMED** |
| `--max-throughput` minimum accepted value = **4000 RU/s** → raising to 4000 valid; rollback to 1000 may be CLI-rejected | MS Learn CLI ref | **CONFIRMED + caveat added** to fix.md T1a |
| Single physical partition serves up to **10,000 RU/s / 50 GB** (unsharded Mongo collection: single partition, 20 GB cap); splitting a single-hot-key partition does not raise the 10k ceiling | MS Learn (partitioning; autoscale-faq; redistribute-throughput) | **CONFIRMED** — source citation added |
| `>10,000 RU/s` demand forces shard/Blob (T3) | derived from the above | **CONFIRMED** |

## C. Spec 2 — `platform-infrastructure` (rootly; repo pins 5.8.0)

| Claim | Source | Verdict |
|---|---|---|
| Provider pin `rootlyhq/rootly` 5.8.0 | repo `providers.tf` | **CONFIRMED** |
| Azure severity → Rootly urgency mapping (Sev0→critical, Sev1→high, Sev2→medium, Sev3→low) on `$.data.essentials.severity` | repo `modules/rootly-alert-routing/main.tf` | **CONFIRMED** |
| Escalation policy is read-only (`data "rootly_escalation_policy"`), env-based, UI-managed | repo (3 modules) | **CONFIRMED** |
| Optional 3b: a manageable `resource "rootly_escalation_policy"` exists at 5.8.0 | TF MCP returned **404** for `rootlyhq/rootly` | **FLAGGED** — not verifiable via the MCP; Spec 2 §3/§9 instruct the implementer to confirm against the 5.8.0 provider docs before attempting 3b. The core of Spec 2 (UI verification, path 3a) does not depend on it. |

## D. rca.md + how-to-feynman.md (diagnostic / narrative)

| Claim | Source | Verdict |
|---|---|---|
| `NormalizedRUConsumption` = per-partition MAX utilization gauge; 1–5% 429 healthy / >5% act | MS Learn (monitor-normalized-request-units) | **CONFIRMED** (already grounded) |
| Live numbers: 2.82% backend 429 (586/20,792); ~3,292 RU/min on `fs.chunks`; `fs.chunks` 100% vs `objects` 16%; ~5 GB | executed `az monitor metrics list` this session | **CONFIRMED (executed)** |
| Triage `az` commands (TotalRequests/429, CollectionName split, throughput show) | executed this session | **CONFIRMED (executed)** |
| No Terraform HCL in rca.md/how-to → nothing to validate against the provider schema | — | n/a |
| Added an implementation note: the 429 *rate* is a triage figure; the *alert* is a dynamic-threshold (a true metric ratio isn't directly expressible) | derived from §A | **CONFIRMED** — note added to rca.md L8 |

## E. Net result

- **5 PR-breaking errors** corrected in the Spec 1 draft before it could be implemented (Mongo category/table/column; diagnostic-setting block + Dedicated; metric-vs-log rate layer; provider-version provenance). Had the original draft been handed to an agent, the diagnostic setting + KQL would have silently collected nothing and the "true-rate" page would have over-fired on every tolerated burst.
- **2 caveats** added to fix.md (the `--max-throughput` 4000 minimum / rollback constraint; the 10k single-partition ceiling with source).
- **1 item flagged** as unverifiable via the MCP (the optional `rootly_escalation_policy` resource) — surfaced in Spec 2, not asserted.
- **Final implementation gate (unchanged):** `terraform fmt -check` + `terraform validate` against each repo's pinned provider versions (azurerm 4.41.0; rootlyhq/rootly 5.8.0), plus the backtests in each spec's acceptance criteria. Provider-doc validation reduces but does not replace a real `plan` in the target repo.

## F. Sources

- Terraform Registry MCP: `hashicorp/azurerm` (latest 4.77.0; resources `azurerm_monitor_metric_alert`, `azurerm_monitor_scheduled_query_rules_alert_v2`, `azurerm_monitor_diagnostic_setting`). `rootlyhq/rootly` — not resolvable via MCP (404).
- Microsoft Learn: `monitor-normalized-request-units`, `monitor-reference`, `mongodb/diagnostic-queries`, `monitor-resource-logs`, `cli/azure/cosmosdb/mongodb/collection/throughput`, `partitioning`, `autoscale-faq`, `scaling-provisioned-throughput-best-practices`, `how-to-redistribute-throughput-across-partitions`.
- Repo facts: `gurobi-infrastructure@c17995a` (`src/provider.tf`, `src/locals.tf`, `src/alerts.tf`, `src/mongodb.tf`, `src/monitoring.tf`); `platform-infrastructure/main` (`terraform/infrastructure/providers.tf`, `modules/rootly-alert-routing/`).
- Live metrics: `az monitor metrics list` against `cosmosdb-gurobi-platform-a` (acceptance), 2026-06-15.
