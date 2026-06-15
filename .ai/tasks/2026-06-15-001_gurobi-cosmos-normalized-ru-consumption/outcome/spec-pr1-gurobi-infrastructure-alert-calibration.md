---
title: "PR Spec 1 — gurobi-infrastructure: Cosmos alert calibration"
description: "Self-contained, agent-implementable spec to add a 429 client-impact page, demote the NormalizedRU gauge to a Sev3 warning, and fix its stale description. Validated against azurerm 4.77.0 + Microsoft Learn."
timestamp: 2026-06-15T19:15:00Z
status: complete
category: pr-spec
authors: ["Alex Torres Ruiz (with Claude Code)"]
task_id: 2026-06-15-001
agent: coordinator
summary: >-
  Self-contained PR spec for gurobi-infrastructure (base main, HEAD c17995a). Adds a Sev2 page on the
  REAL client-impact signal (HTTP-429) as a dynamic-threshold metric alert on TotalRequests/StatusCode=429
  (primary), demotes the NormalizedRUConsumption>75 utilization gauge to a Sev3 non-paging warning, and
  fixes its stale "for more than 5 minutes" description (the window is 15 minutes). Every HCL block is
  validated against azurerm provider 4.77.0 and every metric/log fact against Microsoft Learn. Includes
  full human-readable rationale, exact HCL, acceptance/backtest, rollback, and a PR description.
---

# PR Spec 1 — `gurobi-infrastructure`: Cosmos alert calibration

> **Target repo:** Azure DevOps `enecomanagedcloud / Myriad - VPP / gurobi-infrastructure`. **Base branch:** `main` (this spec was written against HEAD `c17995a`, 2026-06-05). All file paths are under `src/`.
> **Validation basis:** every Terraform block below was checked against the **`hashicorp/azurerm`** provider via the Terraform Registry (current docs reflect **4.77.0**). **`gurobi-infrastructure` pins azurerm `4.41.0`** (`src/provider.tf`, Terraform `1.13.0`). Every block used here — `enabled_log`, `log_analytics_destination_type`, `dynamic_criteria`, and `azurerm_monitor_scheduled_query_rules_alert_v2`'s `criteria`/`failing_periods` — is part of the azurerm **v4** schema and is unchanged across v4; the only relevant breaking change (`metric` → `enabled_metric` on diagnostic settings) happened at the **v3→v4** boundary, *before* 4.41, and this spec uses **neither** (only `enabled_log`). The Terraform MCP resolves only `latest`, so 4.41-validity is established by v4-major stability **plus** the mandatory `terraform validate` against the pinned 4.41.0 (§4) as the final gate. Azure metric/log facts checked against **Microsoft Learn** (URLs in §9). Implement verbatim — do not substitute argument names from memory.
> **Self-contained:** you do not need to read any other document to implement or review this PR. The companion routing change is PR Spec 2 (`platform-infrastructure`); it is referenced but not required reading.

---

## 1. Why this change is needed (complete rationale)

### 1.1 What happened

On **2026-06-15 at 15:44 UTC**, the Azure Monitor metric alert **`gurobi-cosmos-normalized-ru-consumption-a`** fired at **severity 2 (Sev2)** in the **acceptance** environment and **paged the on-call engineer**. The rule is attached to the Cosmos DB account **`cosmosdb-gurobi-platform-a`** (resource group `rg-gurobi-platform-a`), which is the data store for the **Gurobi platform's Cluster Manager** — it holds the optimization **input models, solutions, and job history** that the FleetOptimizer solver workload reads and writes. The rule fires when the metric **`NormalizedRUConsumption`, averaged over a 15-minute window, exceeds 75%**; at 15:44 it read **77.67%**.

### 1.2 Why that number is misleading on its own

`NormalizedRUConsumption` is **not** a measure of how many requests failed. Microsoft defines it as the **maximum, across all of a container's physical partitions, of (Request Units consumed ÷ Request Units provisioned)**, sampled every minute and expressed 0–100%. It is a **utilization gauge** — it reports how close the *busiest* partition came to its throughput ceiling, **not whether any client was actually rate-limited**. Microsoft states two consequences explicitly:

- A reading of **100% does not guarantee any HTTP 429 (rate-limited) responses** — the busy partition may simply have had no further requests in that interval.
- A reading **below 100% does not guarantee the absence of throttling** — a single hot logical partition can be rejected while the account-wide number looks moderate.

And because the rule **averages** the per-minute maxima over 15 minutes, a value like 77.67% can be produced by a few brief spikes to 100% surrounded by near-idle minutes. **By construction, the gauge cannot distinguish a sustained saturation from a short burst, and cannot tell you whether clients were harmed.**

### 1.3 What actually happened on 2026-06-15 (measured, not inferred)

Direct measurement against the live acceptance account (Azure CLI, read-only) settles what the gauge cannot. These numbers are the spine of this PR's justification:

- **Real client impact was small and within Microsoft's "healthy" band.** Across the 15-minute window (15:26–15:41 UTC) the account served **20,792 requests**, of which **586 returned HTTP 429** — a **2.82% rejection rate**. (Measured with `az monitor metrics list --metric TotalRequests --filter "StatusCode eq '429'"` against the same metric unfiltered.) Microsoft's operational guidance for this exact metric states that **1–5% of requests returning 429, with acceptable latency, is healthy and requires no action**, and recommends increasing throughput only when normalized RU is consistently 100% **and** the 429 rate exceeds ~5%. **2.82% is inside the healthy band; the >5% action threshold was not crossed.**

- **It was a short, spiky micro-burst — not a sustained outage.** The RU actually consumed by the hot collection peaked at only **~3,292 RU/min (≈55 RU/s on average)** during the window (`az monitor metrics list --metric TotalRequestUnits --filter "CollectionName eq 'fs.chunks'"`), even though the per-minute *maximum* touched 100%. A sustained 1,000 RU/s ceiling would consume ~60,000 RU/min; the observed ~3,292 RU/min means the ceiling was reached only in brief sub-second spikes, not held.

- **One collection drove it.** Splitting `NormalizedRUConsumption` by collection (`--filter "CollectionName eq '*'"`) over the window showed **`fs.chunks` at 100%**, the next-busiest collection (`objects`) at **16%**, and all others ≤6%. `fs.chunks` is the **GridFS chunk store** — MongoDB splits large objects (here Gurobi's input models and solutions) into binary chunks stored in `fs.chunks`. It is **unsharded** (~5 GB, therefore a single physical partition today) and its throughput is **autoscale with a maximum of 1,000 RU/s**.

- **It cleared itself.** The rule has `autoMitigate = true`; the burst ended by 15:41 and the alert auto-resolved about 15 minutes later. No other alert fired (there is currently no 429 alert — see §1.4).

> **One trap to avoid (it caused a wrong intermediate conclusion during the investigation).** The Mongo **error-16500 count** was ≈**16,555 events** in the window, which divided by Mongo operations looks like "≈34.5% throttled." That figure is **retry-inflated**: the MongoDB driver automatically retries a rate-limited operation up to ~9 times, and **each retry emits another 16500 event**, so the count far exceeds the number of *distinct* operations actually rejected. The trustworthy client-impact figure is the **backend HTTP-429 rate (2.82%)**, not the protocol-level 16500 count. This distinction directly determines which metric the new alert must use (§2.2).

### 1.4 The actual defect (why we are changing the alert)

Putting it together: the rule **pages on-call at Sev2** based on a **leading utilization gauge** crossing 75%, in a case where the **real client impact (2.82% HTTP-429) was inside Microsoft's healthy band** and the condition **self-resolved**. Critically, **there is no companion alert on actual client impact.** The team previously ran a 429-count alert but removed it because it was noisy — their own in-code comment recorded that routine Gurobi runs produce "1 or 2" 429s per window, so they had raised that alarm's threshold to 20 and then replaced it with this utilization gauge.

That replacement was reasonable in spirit (watching a leading indicator is good practice), but it left a gap that produced this page: **on-call is now alerted on a headroom signal that does not confirm anyone was actually hurt, and there is no signal that does.** A spiky workload like Gurobi's batch solves crosses a 75%-average utilization line routinely while staying inside the healthy 429 band — so the current rule will keep paging on tolerated bursts.

**The correct fix is about *what pages whom*, not capacity:**
1. **Add an alert on the actual client-impact signal (HTTP-429), at Sev2**, tuned so a healthy-band burst like 2026-06-15 does **not** page but a genuinely abnormal throttling event does.
2. **Demote the utilization gauge to a Sev3 non-paging warning**, so it stays visible for trend-watching (and as a leading signal) without paging on tolerated bursts.
3. **Fix the gauge's stale description** (it claims "more than 5 minutes" but the window is 15 minutes).

Raising the `fs.chunks` 1,000 RU/s ceiling is a **separate, non-urgent** capacity change (the 429 rate was healthy) and is intentionally **out of scope** for this alerting PR (noted in §6).

---

## 2. What changes

All edits live in `gurobi-infrastructure/src/`. The Cosmos metric alerts are defined as a map `local.default_cosmosdb_metric_alerts` in `src/locals.tf` and rendered by a single `azurerm_monitor_metric_alert.cosmosdb` resource that `for_each`-iterates that map (`src/alerts.tf`). The account, database `grb_rsm`, and a Log Analytics workspace (`azurerm_log_analytics_workspace.main`) already exist (`src/mongodb.tf`, `src/monitoring.tf`). The action group is referenced as a data source `data.azurerm_monitor_action_group.platform` (`src/data.tf`).

### 2.1 Demote the utilization gauge to a Sev3 warning + fix the stale description

In `src/locals.tf`, change the existing `gurobi-cosmos-normalized-ru-consumption` map entry:

```hcl
gurobi-cosmos-normalized-ru-consumption = {
  description = <<DESC
WARNING (leading gauge, not a client-impact signal): the maximum per-partition normalized RU
utilization, averaged over a 15-minute window, exceeded 75%. This indicates tight RU headroom on
the busiest partition; it does NOT confirm that any client request was throttled. Confirm real
impact via the gurobi-cosmos-throttling-429 alert / the HTTP-429 rate before taking capacity action.
DESC
  severity    = 3            # CHANGED from 2 -> warning, non-paging (see PR Spec 2 for the routing that makes Sev3 non-paging).
  enabled     = true
  frequency   = "PT5M"
  window_size = "PT15M"
  criteria = {
    NormalizedRUConsumption = {
      metric_namespace = "Microsoft.DocumentDB/DatabaseAccounts"
      operator         = "GreaterThan"
      aggregation      = "Average"
      threshold        = 75
    }
  }
}
```

Why each edit:
- **`severity = 3`** — Azure severity maps to Rootly urgency in `platform-infrastructure` (Sev2→`medium`, Sev3→`low`). Demoting to Sev3 makes this gauge a non-paging warning **provided** `low` urgency is non-paging in the team escalation policy — PR Spec 2 verifies exactly that, so ship this demotion only after PR Spec 2's verification (see §4 sequencing).
- **`description`** — the current text says *"greater than 75% for more than 5 minutes"* while `window_size = "PT15M"` (15 minutes). The window was widened to 15 minutes in an earlier change and the 5-minute wording was left behind; it is stale and self-contradicting. The new text also states plainly that this is a utilization gauge, not a client-impact signal, so a future responder is not misled the way 2026-06-15 was.

### 2.2 Add a 429 client-impact page (the alert that *should* fire)

The page must reflect **real client impact (HTTP 429)**, tuned so the tolerated 2026-06-15 burst (2.82%) does **not** page but an abnormal throttling event does. Three implementation options follow, in recommended order. **Option A is recommended.**

#### Option A (RECOMMENDED) — dynamic-threshold metric alert on backend HTTP-429

This watches the **backend `TotalRequests` metric filtered to `StatusCode = 429`** — the same layer that gave the trustworthy 2.82% figure (not the retry-inflated 16500 protocol count). A **dynamic threshold** learns the routine-burst baseline and fires on a statistically abnormal spike, which is exactly right for a workload whose "normal" includes small, regular 429 bursts. No Log Analytics dependency.

Add a new resource in `src/alerts.tf` (it is a *dynamic* criterion, so it cannot reuse the static-`criteria` map in `locals.tf`):

```hcl
# Validated against azurerm 4.77.0: azurerm_monitor_metric_alert -> dynamic_criteria block.
resource "azurerm_monitor_metric_alert" "cosmos_429" {
  name                = "gurobi-cosmos-throttling-429-${var.environment_suffix}"
  resource_group_name = azurerm_resource_group.gurobi.name
  scopes              = [azurerm_cosmosdb_account.mongodb.id]
  description         = "PAGE: anomalous spike in Cosmos HTTP-429 (rate-limited) responses on cosmosdb-gurobi-platform-${var.environment_suffix} — real client throttling beyond the routine Gurobi-burst baseline."
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  auto_mitigate       = true

  dynamic_criteria {
    metric_namespace  = "Microsoft.DocumentDB/DatabaseAccounts"
    metric_name       = "TotalRequests"
    aggregation       = "Total"
    operator          = "GreaterThan"     # dynamic_criteria operators: LessThan | GreaterThan | GreaterOrLessThan
    alert_sensitivity = "Medium"          # Low | Medium | High  (Medium = standard sensitivity)

    dimension {
      name     = "StatusCode"
      operator = "Include"
      values   = ["429"]
    }

    # Optional dampening; defaults are evaluation_total_count = 4, evaluation_failure_count = 4.
    evaluation_total_count   = 4
    evaluation_failure_count = 4
  }

  action {
    action_group_id = data.azurerm_monitor_action_group.platform.id   # NOTE: singular for metric alerts
  }
}
```

Validation notes (azurerm 4.77.0): `dynamic_criteria` supports `metric_namespace`, `metric_name`, `aggregation` (Average/Count/Minimum/Maximum/Total), `operator`, `alert_sensitivity`, `dimension`, `evaluation_total_count` (default 4), `evaluation_failure_count` (default 4). The `action` block on a metric alert uses **`action_group_id`** (singular). `TotalRequests` exposes a `StatusCode` dimension on `Microsoft.DocumentDB/DatabaseAccounts` (confirmed live: the dimension was used to obtain the 586 figure in §1.3).

#### Option B (simple, less precise) — static count threshold on HTTP-429

If the team prefers a fixed threshold to a dynamic one, use a static `criteria` (this CAN be added to the `locals.tf` map, since the existing module renders a `dynamic "dimension"` block):

```hcl
gurobi-cosmos-throttling-429 = {
  description = "PAGE: Cosmos HTTP-429 count over PT15M exceeded the tolerated Gurobi-burst level."
  severity    = 2
  enabled     = true
  frequency   = "PT5M"
  window_size = "PT15M"
  criteria = {
    TotalRequests = {
      metric_namespace = "Microsoft.DocumentDB/DatabaseAccounts"
      aggregation      = "Total"
      operator         = "GreaterThan"
      threshold        = var.cosmos_429_count_threshold   # per-env; MUST be set ABOVE the routine-burst 429 count (2026-06-15 had 586) — see §2.3
      dimension = {
        StatusCode = { operator = "Include", values = ["429"] }
      }
    }
  }
}
```

Trade-off: a static count is simple but flappy — it must be tuned per-environment well above the routine-burst count (the 2026-06-15 burst alone produced 586), and op volume varies by solve cadence, so the "right" number drifts. Prefer Option A unless the team has a policy against dynamic thresholds.

#### Option C (diagnostics aid — NOT a >5% pager) — log alert on the protocol layer

A true *percentage* over the Mongo logs is computable but measures the **protocol/retry-inflated** layer (it would have read ≈34.5% on 2026-06-15, not 2.82%), so it must **not** be wired to a ">5%" page — it would fire on every tolerated burst. It is useful as a **diagnostic dashboard query or a high-threshold secondary**, and it requires wiring Cosmos logs to the existing Log Analytics workspace (currently the workspace only receives VM perf/syslog; **Cosmos has no diagnostic setting**).

```hcl
# Validated against azurerm 4.77.0: enabled_log (not "log"); enabled_metric (not "metric");
# log_analytics_destination_type = "Dedicated" is REQUIRED to land in the resource-specific
# CDBMongoRequests table (without it logs go to the legacy AzureDiagnostics table and the KQL below matches nothing).
resource "azurerm_monitor_diagnostic_setting" "cosmosdb" {
  name                           = "diag-cosmos-to-law-${var.environment_suffix}"
  target_resource_id             = azurerm_cosmosdb_account.mongodb.id
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.main.id
  log_analytics_destination_type = "Dedicated"

  enabled_log { category = "MongoRequests" }   # Mongo API request logs; carries ErrorCode (429/16500)
}

# Validated against azurerm 4.77.0: azurerm_monitor_scheduled_query_rules_alert_v2.
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "cosmos_protocol_throttle" {
  name                 = "gurobi-cosmos-throttling-protocol-rate-${var.environment_suffix}"
  resource_group_name  = azurerm_resource_group.gurobi.name
  location             = azurerm_resource_group.gurobi.location
  scopes               = [azurerm_log_analytics_workspace.main.id]
  severity             = 3                       # diagnostics/secondary, NOT a primary page
  evaluation_frequency = "PT5M"
  window_duration      = "PT15M"
  auto_mitigation_enabled = true
  description          = "Diagnostics: Mongo protocol-level throttle rate (ErrorCode 429/16500, RETRY-INFLATED — not the backend 429 rate)."

  criteria {
    query = <<KQL
CDBMongoRequests
| where AccountName == "cosmosdb-gurobi-platform-${var.environment_suffix}"
| summarize total = count(), throttled = countif(ErrorCode in ("429", "16500")) by bin(TimeGenerated, 5m)
| where total > 100
| extend protocol_throttle_pct = todouble(throttled) * 100.0 / total
| project TimeGenerated, protocol_throttle_pct
KQL
    time_aggregation_method = "Maximum"
    metric_measure_column   = "protocol_throttle_pct"   # required because time_aggregation_method = Maximum
    operator                = "GreaterThan"
    threshold               = var.cosmos_protocol_throttle_pct   # calibrate to the PROTOCOL baseline (the 2026-06-15 burst was ~34.5%), NOT 5%
    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  identity { type = "SystemAssigned" }   # the rule queries the workspace; its identity needs read access
  action  { action_groups = [data.azurerm_monitor_action_group.platform.id] }   # NOTE: plural for v2 log alerts
}

# The v2 log alert's identity needs to read the workspace:
resource "azurerm_role_assignment" "cosmos_protocol_throttle_reader" {
  scope                = azurerm_log_analytics_workspace.main.id
  role_definition_name = "Log Analytics Reader"
  principal_id         = azurerm_monitor_scheduled_query_rules_alert_v2.cosmos_protocol_throttle.identity[0].principal_id
}
```

Use Option C only if the team wants a protocol-level dashboard/secondary; it is **not** the Microsoft-1–5% page (Option A is).

### 2.3 Per-environment threshold variable

The alerts in `locals.tf` are currently env-independent; only `var.environment_suffix` differs (acceptance `a`, production `p`). Any 429 threshold MUST be tunable per environment, because acc and prod have different op volumes and must never share a hardcoded number. Add to `src/variables.tf` whichever the chosen option needs:

```hcl
# For Option B:
variable "cosmos_429_count_threshold" {
  type        = number
  description = "HTTP-429 count over PT15M that pages on-call. Set per-env ABOVE the routine Gurobi-burst count (acc 2026-06-15 baseline: 586 in a tolerated burst)."
}
# For Option C:
variable "cosmos_protocol_throttle_pct" {
  type        = number
  description = "Mongo protocol-level throttle rate (%) for the diagnostics alert. Calibrate to the protocol baseline (~34.5% on the 2026-06-15 tolerated burst), NOT 5%."
  default     = 60
}
```

Set values in `environments/acceptance.tfvars` and `environments/production.tfvars` **after** the backtest (§4). Option A (dynamic threshold) needs no numeric threshold — it learns the baseline — which is one more reason to prefer it.

---

## 3. Files touched

| File | Change |
|------|--------|
| `src/locals.tf` | Demote `gurobi-cosmos-normalized-ru-consumption` `severity 2→3`; rewrite its `description` (remove stale "5 minutes"). For Option B also add the `gurobi-cosmos-throttling-429` map entry. |
| `src/alerts.tf` | Option A: add `azurerm_monitor_metric_alert.cosmos_429` (dynamic_criteria). (Option B needs no change here — it renders from the map.) |
| `src/variables.tf` | Add the per-env threshold variable for the chosen option (none needed for Option A). |
| `src/cosmos-diagnostics.tf` (new) | *Option C only:* the diagnostic setting + scheduled-query alert + role assignment. |
| `environments/acceptance.tfvars`, `environments/production.tfvars` | Set per-env threshold (Options B/C only). |

---

## 4. Acceptance criteria (the PR is done when)

1. `terraform fmt -check` and `terraform validate` pass.
2. `terraform plan` for **acceptance** shows: the RU gauge changing `severity 2→3` with the new description; the new 429 alert created; and (Option C only) the diagnostic setting + log alert + role assignment. No unrelated resource churn.
3. **Backtest against the 2026-06-15 data (the load-bearing gate):**
   - The new **429 page** does **not** fire for the 2026-06-15 window (2.82% / 586 was a tolerated, self-resolved burst). For Option A, confirm via the Azure portal's dynamic-threshold preview against history; for Option B, confirm the chosen count threshold is above 586.
   - The 429 page **would** fire for a genuinely abnormal event (e.g. a sustained >5% backend-429 period). Construct the check from the 7-day history.
   - The demoted gauge still fires informationally (Sev3) on 2026-06-15.
4. **Sequencing honored:** deploy the new 429 page first and confirm it works; demote the RU gauge to Sev3 **only after** PR Spec 2 has verified that Sev3→`low` urgency is non-paging. Never leave the account with no page in between.
5. Applies to **both** acceptance and production (the `locals.tf` change is env-independent; thresholds are per-env via tfvars).

## 5. Rollback

- Revert the `locals.tf` change (git) → the RU gauge returns to Sev2 with its old description.
- Remove the new 429 alert resource (and, for Option C, the diagnostic setting + log alert + role assignment).
- This PR makes **no** capacity or data-plane change, so rollback is config-only and immediate.

## 6. Explicitly out of scope

- **Capacity** — raising `fs.chunks` autoscale max from 1,000 RU/s, or bringing throughput into IaC. The 429 rate was healthy (2.82%), so this is a non-urgent, separate change, not an alerting fix.
- **Rootly escalation behaviour** — whether `low` urgency pages: PR Spec 2 (`platform-infrastructure`).
- **Storage redesign** — moving Gurobi's large objects out of Cosmos GridFS into Blob Storage (a durable capacity fix that depends on the third-party Gurobi Cluster Manager supporting it).

## 7. PR description skeleton (paste-ready)

> **Title:** fix(alerts): page on Cosmos HTTP-429, make NormalizedRU>75 a Sev3 warning
>
> **Why:** On 2026-06-15 `gurobi-cosmos-normalized-ru-consumption-a` paged Sev2, but the real client impact was 2.82% HTTP-429 (586 of 20,792 requests) — inside Microsoft's 1–5% "healthy / no action" band — and it self-resolved. The rule pages on a leading *utilization gauge* (NormalizedRUConsumption avg >75%), which cannot tell you whether clients were actually throttled, and there is currently no alert on real client impact. This PR adds the missing client-impact page and turns the gauge into a non-paging warning.
>
> **What:** add a Sev2 alert on backend HTTP-429 (dynamic threshold on TotalRequests/StatusCode=429, so it ignores routine Gurobi bursts and fires on abnormal throttling); demote NormalizedRU>75 to Sev3 and fix its stale "5 minutes" description (window is 15 minutes). Backtested so 2026-06-15 does NOT page on the new rule.
>
> **Blast radius:** acceptance + production (env-suffixed). Config + one new alert; no capacity/data-plane change; revert-safe. Companion: platform-infrastructure routing check that Sev3→low urgency is non-paging (sequence the demotion after it).

## 8. Existing repo facts this PR relies on (verified in `gurobi-infrastructure@c17995a`)

- The alert map `local.default_cosmosdb_metric_alerts` is in `src/locals.tf`; the `gurobi-cosmos-normalized-ru-consumption` entry there is the rule that fired (NormalizedRUConsumption, Average, GreaterThan 75, window PT15M, frequency PT5M, severity 2).
- `azurerm_monitor_metric_alert.cosmosdb` in `src/alerts.tf` renders the map with `for_each`, scopes each alert to `azurerm_cosmosdb_account.mongodb.id`, and routes to `data.azurerm_monitor_action_group.platform`; it already contains a `dynamic "dimension"` block (so Option B's `StatusCode` dimension renders without a module change).
- `azurerm_log_analytics_workspace.main` exists in `src/monitoring.tf` (currently fed only by a VM data-collection rule; Cosmos has no diagnostic setting — hence Option C must add one).
- `azurerm_cosmosdb_account.mongodb` (name `cosmosdb-gurobi-platform-${var.environment_suffix}`, MongoDB API, database `grb_rsm`) and `data.azurerm_monitor_action_group.platform` are in `src/mongodb.tf` and `src/data.tf`.

## 9. Validation provenance (sources, so this spec is independently checkable)

- **Terraform schemas** — `hashicorp/azurerm`, Terraform Registry. Verified against the current published docs (**4.77.0**); the repo pins **4.41.0** — same major version, and these blocks are unchanged across azurerm v4 (the Terraform MCP only resolves `latest`, so 4.41-specific validity rests on v4-major stability + the `terraform validate` gate in §4). Resources verified: `azurerm_monitor_metric_alert` (the `dynamic_criteria` block; `action.action_group_id` is **singular** on metric alerts), `azurerm_monitor_scheduled_query_rules_alert_v2` (the `criteria`/`failing_periods`/`action.action_groups` **plural** schema + the managed-identity requirement for querying the workspace), `azurerm_monitor_diagnostic_setting` (`enabled_log` block; `log_analytics_destination_type = "Dedicated"` is required to write the resource-specific `CDBMongoRequests` table rather than the legacy `AzureDiagnostics` table). The `az cosmosdb mongodb collection throughput update --max-throughput` command and the 10,000-RU/s single-physical-partition ceiling are out of scope here (capacity, not alerting) but are validated in `fix.md`.
- **Azure metric/log semantics** — Microsoft Learn:
  - NormalizedRUConsumption definition + the 1–5%/>5% 429 framework: <https://learn.microsoft.com/azure/cosmos-db/monitor-normalized-request-units>
  - Cosmos resource logs categories + tables (MongoRequests → `CDBMongoRequests`): <https://learn.microsoft.com/azure/cosmos-db/monitor-reference>
  - Mongo throttle query (`CDBMongoRequests | where ErrorCode in ("429","16500")`): <https://learn.microsoft.com/azure/cosmos-db/mongodb/diagnostic-queries>
  - Resource-specific vs AzureDiagnostics tables (`Dedicated` destination): <https://learn.microsoft.com/azure/cosmos-db/monitor-resource-logs>
- **The 2026-06-15 measurements** (2.82% 429, 586/20,792, ~3,292 RU/min on fs.chunks, per-collection split) were captured live via `az monitor metrics list` against the acceptance account on 2026-06-15. The full incident RCA (with the raw command outputs) lives alongside this spec as `rca.md` — *optional* further reading; this spec stands alone.
