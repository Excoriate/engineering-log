---
task_id: 2026-03-27-001
agent: sre-maniac
timestamp: 2026-03-27T16:00:00Z
status: complete

summary: |
  SRE reliability review of the automated runbook (Sections 8.1-8.4) and proposed
  remediation changes (Section 7.1) for the Gurobi CosmosDB 429 throttling alert.
  Identifies 3 critical and 5 high-severity production hazards including: runbook
  script fails silently on empty metric data, burst capacity is NOT guaranteed and
  will not solve this pattern, alert dampening IaC is incorrect (dynamic_threshold
  block mixed with static criteria), autoscale migration via Terraform requires
  destroy-apply, and the runbook has no fallback for Azure Monitor metric delays.

key_findings:
  - burst_capacity_not_guaranteed: "Burst capacity is explicitly 'not guaranteed' per Microsoft docs -- it is best-effort and Azure may use it for background maintenance. Relying on it as a fix is hope-as-strategy."
  - runbook_empty_data_crash: "The Python classification script will crash with json.JSONDecodeError or produce wrong classification if az monitor metrics list returns null/empty timeseries (metric delay, maintenance window, CosmosDB failover)."
  - iac_dampening_wrong_block: "Section 7.1 Change 2 uses dynamic_threshold_failing_periods but the alert uses static criteria (SingleResourceMultipleMetricCriteria). This block does not apply to static alerts. The IaC will either error or be silently ignored."
  - terraform_autoscale_destroy_apply: "azurerm_cosmosdb_mongo_collection docs state: autoscale_settings 'must be set upon database creation otherwise it cannot be updated without a manual terraform destroy-apply' and 'Switching between autoscale and manual throughput is not supported via Terraform'."
  - runbook_no_timeout_no_retry: "The runbook script has no timeout on az CLI calls, no retry on transient failures, and no error handling for az auth expiry. set -e will exit silently on first az failure."
---

# SRE Maniac Review: Runbook Design & Remediation Proposals

```text
SRE MANIAC ANALYSIS
============================
Target: root-cause-analysis.md Sections 7.1 (Remediation) and 8.1-8.4 (Automated Runbook)
Verdict: FIX FIRST
```

---

## 1. Burst Capacity (Change 1): Hope Is Not a Strategy

**Verdict: CRITICAL -- This is not a fix. It is a prayer.**

The RCA proposes enabling `burst_capacity_enabled = true` as a "zero-cost, immediate" fix.
Here is what Microsoft actually says about burst capacity:

> "Usage of burst capacity is subject to system resource availability and is **not guaranteed**.
> Azure Cosmos DB may also use burst capacity for background maintenance tasks. If your
> workload requires consistent throughput beyond what you have provisioned, it's recommended
> to provision your RU/s accordingly without relying on burst capacity."
>
> -- [Microsoft Learn: Burst Capacity](https://learn.microsoft.com/en-us/azure/cosmos-db/burst-capacity)

### Burst Capacity Math (Best Case)

```text
BURST CAPACITY CALCULATION (100 RU/s partition, best case):
  Accumulation: 100 RU/s x 300 seconds idle = 30,000 RU maximum credits
  Max burst rate: 3,000 RU/s
  Max burst duration: 30,000 / 3,000 = 10 seconds at full burst

ACTUAL BURST PATTERN (from RCA data):
  Burst total RU in 5min window: ~8,500 RU
  Peak RU/s (proven >100 by 429 occurrence): Unknown exact, but 429s = >100 RU/s
  Burst duration: Seconds (sub-minute, from RCA Section 3.2)

VERDICT: Burst capacity COULD absorb this IF:
  1. Azure has not consumed the credits for background maintenance
  2. The credits have fully accumulated (requires ~5 min idle -- matches pattern)
  3. Peak burst does not exceed 3,000 RU/s (unknown -- no sub-second data)
  4. The burst does not cross multiple physical partitions differently

RISK: This is best-effort. Microsoft explicitly says "not guaranteed."
      A single instance where burst credits are unavailable = 429s return = alert fires.
      You have traded a deterministic problem for a probabilistic one.
```

### Burst Capacity -- What Is Actually True

| Claim in RCA | Reality | Source |
|---|---|---|
| "zero-cost, immediate" | Correct -- no extra charge | [MS Docs](https://learn.microsoft.com/en-us/azure/cosmos-db/burst-capacity-faq) |
| "absorb short spikes" | **Best-effort, not guaranteed** | [MS Docs](https://learn.microsoft.com/en-us/azure/cosmos-db/burst-capacity) |
| Works for MongoDB API | Yes, supported for MongoDB API | [MS Docs](https://learn.microsoft.com/en-us/azure/cosmos-db/burst-capacity) |
| Will stop 429s | **No guarantee**. Azure may use credits for maintenance | [MS Docs](https://learn.microsoft.com/en-us/azure/cosmos-db/burst-capacity) |

### CASCADE

```text
Initial: Burst capacity enabled but not available when burst hits
  -> 429s occur anyway -> alert fires -> on-call paged
  -> "But we enabled burst capacity!" -> debugging time wasted investigating
     why burst capacity did not help
  -> Actual fix delayed because team believed problem was solved
```

### RECOMMENDATION

Enable burst capacity (it is free, it helps sometimes), but **do NOT treat it as
a remediation**. It is a best-effort cushion. The actual fix is autoscale or increased
manual RU/s. Document this clearly: "Burst capacity is a mitigation, not a solution."

---

## 2. Alert Dampening IaC (Change 2): Wrong Terraform Block

**Verdict: CRITICAL -- This IaC change will not work as written.**

Section 7.1 Change 2 proposes:

```hcl
dynamic_threshold_failing_periods {
  min_failing_periods_to_alert    = 3
  number_of_evaluation_periods    = 3
}
```

This is **incorrect** for this alert. The alert uses `criteria` (static threshold),
not `dynamic_criteria`. The `staticThresholdFailingPeriods` values of `0/0` in the
alert payload are not a configurable field -- they are default/placeholder values
for static threshold criteria which **do not support failing periods**.

### Evidence

From the alert payload:

```json
"conditionType": "SingleResourceMultipleMetricCriteria"
"staticThresholdFailingPeriods": {
  "minFailingPeriodsToAlert": 0,
  "numberOfEvaluationPeriods": 0
}
```

From the `azurerm_monitor_metric_alert` Terraform provider docs:

- `criteria` block (static): Has `metric_name`, `operator`, `threshold`, `aggregation`,
  `dimension`. **No `failing_periods` sub-block.**
- `dynamic_criteria` block: Has `evaluation_total_count` and `evaluation_failure_count`
  (which map to `numberOfEvaluationPeriods` and `minFailingPeriodsToAlert`).

You cannot add `dynamic_threshold_failing_periods` to a `criteria` (static) block.
The provider will either reject it at plan time or silently ignore it.

### The RCA's Own Note Acknowledges This

> "Note: `azurerm_monitor_metric_alert` does not natively expose
> `staticThresholdFailingPeriods` for static criteria."

The RCA then suggests increasing `window_size` from `PT5M` to `PT15M` as a workaround.
This is the **correct approach** for static threshold dampening.

### RECOMMENDATION: Two Valid Approaches

**Approach A: Increase window_size (static alert, simplest)**

```hcl
resource "azurerm_monitor_metric_alert" "cosmosdb" {
  # ... existing config ...
  window_size = "PT15M"   # Was PT5M -- aggregates 3 burst cycles
  frequency   = "PT5M"    # Keep evaluation frequency at 5min
  # threshold remains 20

  # With PT15M window: a single burst of 24 gets counted alongside
  # two clean 5-min periods. Total 429s in 15min = ~24 (one burst)
  # which exceeds 20, so this ALONE may not be enough.
  # Consider raising threshold to 40-60 for PT15M window.
}
```

**WAIT** -- there is a subtlety. With `window_size = PT15M` and `aggregation = Count`,
Azure sums ALL 429s in the 15-minute window. A single burst of 24 in 15 minutes still
exceeds threshold=20. You would need to **also raise the threshold** to account for the
wider window. With one burst per 15 min producing ~24 429s, threshold of 40 would require
two bursts in the same 15-min window to fire.

**Approach B: Switch to dynamic_criteria (more sophisticated)**

```hcl
resource "azurerm_monitor_metric_alert" "cosmosdb" {
  # ... existing config ...

  dynamic_criteria {
    metric_namespace = "microsoft.documentdb/databaseaccounts"
    metric_name      = "TotalRequests"
    aggregation      = "Count"
    operator         = "GreaterThan"
    alert_sensitivity = "Medium"

    dimension {
      name     = "StatusCode"
      operator = "Include"
      values   = ["429"]
    }

    evaluation_total_count   = 3   # Look at 3 periods
    evaluation_failure_count = 3   # All 3 must exceed dynamic threshold
  }

  # Remove the existing static 'criteria' block
}
```

Dynamic thresholds would learn the periodic pattern and only alert on anomalous spikes
above the learned baseline. However, this changes the alert semantics significantly and
should be tested in ACC before PRD.

---

## 3. Autoscale Migration (Change 3): Terraform Cannot Do This

**Verdict: HIGH -- The IaC path has a trap.**

The RCA correctly identifies two options: CLI migration or Terraform import. However,
the Terraform path has a documented landmine.

From the `azurerm_cosmosdb_mongo_collection` provider documentation:

> `autoscale_settings` - (Optional) An `autoscale_settings` block as defined below.
> **This must be set upon database creation otherwise it cannot be updated without a
> manual terraform destroy-apply.**
>
> **Note:** Switching between autoscale and manual throughput is not supported via
> Terraform and must be completed via the Azure Portal and refreshed.

### CASCADE

```text
If someone tries the "Import into Terraform + manage going forward" path:
  1. Import existing collection into state (manual throughput = 100 RU/s)
  2. Add autoscale_settings block to .tf file
  3. terraform plan -> shows change from manual to autoscale
  4. terraform apply -> FAILS or REQUIRES DESTROY + RECREATE
  5. Destroy = DELETE THE COLLECTION AND ALL DATA
  6. Recreate = empty collection, all data lost
  7. At 3 AM, this is a career-ending event
```

### Autoscale Migration -- What Is Safe

| Method | Safe? | Downtime | Data Loss | Notes |
|---|---|---|---|---|
| Azure CLI `az cosmosdb mongodb collection throughput migrate` | **Yes** | Zero | Zero | [MS Docs](https://learn.microsoft.com/en-us/azure/cosmos-db/provision-throughput-autoscale) |
| Azure Portal toggle | **Yes** | Zero | Zero | Online operation |
| Terraform import + change `autoscale_settings` | **DANGEROUS** | Destroy-recreate | **ALL DATA LOST** | Provider limitation |
| Terraform fresh resource with autoscale | Safe | N/A | N/A | Only for new collections |

### RECOMMENDATION

1. Migrate via Azure CLI (`az cosmosdb mongodb collection throughput migrate`) -- zero
   downtime, zero data loss, confirmed by Microsoft.
2. After migration, import the collection into Terraform state with autoscale config to
   maintain IaC alignment.
3. **Add a giant warning comment** in the Terraform code:

```hcl
# WARNING: DO NOT change throughput_type via Terraform.
# The azurerm provider does NOT support switching between manual and autoscale.
# Attempting this will DESTROY AND RECREATE the collection, losing ALL data.
# Use Azure CLI: az cosmosdb mongodb collection throughput migrate
# See: RCA 2026-03-27 and provider docs for azurerm_cosmosdb_mongo_collection
```

### Autoscale Cost Impact

The RCA mentions "Cost increase during bursts (~10x for seconds)" but does not quantify.

```text
AUTOSCALE COST CALCULATION:
  Minimum autoscale RU/s: 1000 (Azure minimum for autoscale max)
  -> Scales between 100 RU/s (10% of max) and 1000 RU/s
  -> Autoscale billing rate: 1.5x manual rate per RU/s
  -> At idle (100 RU/s): 100 x 1.5 = equivalent to 150 RU/s manual cost
  -> Current manual: 100 RU/s = 100 RU/s cost
  -> Cost increase at idle: +50%
  -> During burst (up to 1000 RU/s): 1000 x 1.5 = 1500 RU/s equivalent
  -> Burst duration: ~10-15 seconds every 15 minutes

  NET IMPACT: ~50% cost increase per collection at idle, brief higher cost during bursts.
  For 12 collections at 100 RU/s each, this is negligible in absolute terms
  (CosmosDB minimum provisioned throughput costs are very low).
```

---

## 4. Runbook Script Failure Modes

**Verdict: CRITICAL (empty data crash) + HIGH (multiple failure modes)**

### 4.1 Empty Metric Data -- The Script Will Crash

**CRITICAL**: The `az monitor metrics list` command can return `null` or empty
timeseries data in several scenarios:

- Azure Monitor metric pipeline delay (documented: up to 2-3 minutes for CosmosDB)
- CosmosDB maintenance window (metrics may be unavailable)
- CosmosDB failover event
- Azure Monitor regional outage
- Metric not yet emitted (cold start after account recreation)

When this happens, the `--query "value[0].timeseries[0].data[].maximum"` JMESPath
returns `null` or `[]`.

```text
FAILURE TRACE:
  1. az monitor metrics list returns: null (no timeseries data)
  2. RU_DATA="null" or RU_DATA=""
  3. Python receives: null or empty string
  4. json.load(sys.stdin) -> json.JSONDecodeError (if empty) or loads null
  5. data = None -> iteration fails: "TypeError: 'NoneType' is not iterable"
  6. Script exits with non-zero (set -e)
  7. Non-zero exit = ESCALATE classification
  8. On-call engineer gets paged for a metric collection failure, not a real incident
```

This is worse than a crash -- if `set -e` catches the Python error, exit code 1
means ESCALATE. The on-call gets paged with garbage diagnostics.

### FIX: Add null/empty guards

```bash
# After metric collection, before classification:
if [ -z "$RU_DATA" ] || [ "$RU_DATA" = "null" ] || [ "$RU_DATA" = "[]" ]; then
  echo "[RUNBOOK] WARNING: No metric data returned. Possible metric delay or outage."
  echo "[RUNBOOK] CLASSIFICATION: INCONCLUSIVE -- metric data unavailable"
  echo "[RUNBOOK] ACTION: Retry in 5 minutes. If persistent, escalate as monitoring gap."
  exit 2  # Distinct exit code: 0=auto-ack, 1=escalate, 2=inconclusive/retry
fi
```

### 4.2 No Timeout on az CLI Calls

**HIGH**: The `az monitor metrics list` calls have no timeout. If Azure Monitor API
is slow (degraded, regional issue), the script hangs indefinitely.

```text
CASCADE:
  1. Azure Monitor API responding slowly (30s+ per request)
  2. Script blocks on first az call
  3. OpsGenie automation action has its own timeout (default: 10 minutes)
  4. If OpsGenie times out: alert remains unprocessed, on-call not notified
  5. If OpsGenie does not timeout: script hangs for minutes, delaying classification
  6. During this time, more alerts fire (every 5 min) -- each spawning a new script instance
  7. Multiple concurrent scripts = race condition on OpsGenie alert state
```

### FIX: Add timeout wrapper

```bash
# Use timeout command (GNU coreutils / macOS built-in)
RU_DATA=$(timeout 30 az monitor metrics list \
  --resource "$RESOURCE_ID" \
  --metric "NormalizedRUConsumption" \
  ... ) || {
  echo "[RUNBOOK] ERROR: Metric query timed out after 30s"
  exit 2
}
```

### 4.3 No Azure Authentication Check

**HIGH**: The script assumes `az` is authenticated. On an OpsGenie worker, Azure
Function, or CronJob, authentication may have expired (managed identity token refresh
failure, service principal secret rotation, etc.).

```text
CASCADE:
  1. az CLI not authenticated or token expired
  2. az monitor metrics list fails with auth error
  3. set -e exits script with code 1
  4. Exit 1 = ESCALATE classification
  5. On-call paged with "ESCALATE" but actual issue is runbook auth failure
  6. On-call spends 30 minutes debugging a non-incident
```

### FIX: Auth pre-check

```bash
# Pre-flight: verify az CLI is authenticated
if ! az account show --query "id" -o tsv >/dev/null 2>&1; then
  echo "[RUNBOOK] FATAL: Azure CLI not authenticated. Cannot query metrics."
  echo "[RUNBOOK] This is a RUNBOOK INFRASTRUCTURE FAILURE, not a CosmosDB issue."
  exit 3  # Distinct code for infra failure
fi
```

### 4.4 Race Between Alert and Metric Availability

**HIGH**: The alert payload shows `windowEndTime: 2026-03-27T13:44:32.994Z` and
`firedDateTime: 2026-03-27T13:46:47Z` -- a ~2 minute pipeline delay. When the
runbook fires immediately after the alert, it queries "last 30 minutes" which includes
the CURRENT window that may not have complete metric data yet.

```text
TIMING ISSUE:
  Alert fires at: 13:46:47 (for window ending 13:44:32)
  Runbook queries: 13:16:47 to 13:46:47
  Azure Monitor metric pipeline delay: 1-3 minutes
  Most recent 5-min window (13:41-13:46): May show INCOMPLETE data
  -> The window that triggered the alert may appear as a partial spike
  -> Classification logic may miscount spikes
```

### FIX: Offset query window

```bash
# Account for Azure Monitor pipeline delay: query up to 5 minutes ago, not "now"
PIPELINE_DELAY_MINUTES=5
END_TIME=$(date -u -v-${PIPELINE_DELAY_MINUTES}M '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null \
  || date -u -d "${PIPELINE_DELAY_MINUTES} minutes ago" '+%Y-%m-%dT%H:%M:%SZ')
```

### 4.5 Classification Logic Edge Cases

**MEDIUM**: The classification logic has gaps:

```text
EDGE CASE 1: Exactly 3 spikes, non-consecutive
  Spikes at windows 1, 3, 5 (with gaps at 2, 4, 6)
  SPIKE_COUNT=3 > PERIODIC_MAX_SPIKES(2) -> ESCALATING
  CONSECUTIVE=1 < SUSTAINED_CONSECUTIVE_LIMIT(3) -> Not SUSTAINED
  Result: ESCALATING -- but this is still a periodic pattern (just 3 bursts in 30 min)
  This is correct if the pattern is worsening, but false positive if the lookback
  window simply caught an extra burst cycle.

EDGE CASE 2: Deployment or restart causing one-time burst
  Application restart -> connection storm -> brief 100% RU -> single spike
  SPIKE_COUNT=1 <= PERIODIC_MAX_SPIKES(2) -> PERIODIC -> auto-ack
  But this was NOT the known periodic pattern -- it was a deployment artifact.
  Auto-ack is wrong here because the deployment may have introduced a regression.

EDGE CASE 3: CosmosDB maintenance window
  During planned maintenance, NormalizedRU may spike due to partition migration.
  Pattern looks like SUSTAINED -> ESCALATE -> on-call paged
  But this is expected CosmosDB behavior during maintenance.
```

### 4.6 No Idempotency Guard

**MEDIUM**: If the alert fires every 5 minutes (as documented: ~4/hour), and each
alert triggers the runbook, multiple concurrent runbook executions will:

1. All query the same metrics
2. All reach the same classification
3. All attempt to close/escalate the same OpsGenie alert
4. Race condition on OpsGenie alert state transitions

### FIX: Add lock/dedup

```bash
# Use a lock file or OpsGenie alert tag to prevent concurrent execution
LOCK_FILE="/tmp/gurobi-cosmos-429-runbook.lock"
if [ -f "$LOCK_FILE" ]; then
  LOCK_AGE=$(( $(date +%s) - $(stat -f %m "$LOCK_FILE" 2>/dev/null || stat -c %Y "$LOCK_FILE") ))
  if [ "$LOCK_AGE" -lt 300 ]; then
    echo "[RUNBOOK] Another instance ran ${LOCK_AGE}s ago. Skipping."
    exit 0
  fi
fi
touch "$LOCK_FILE"
trap "rm -f $LOCK_FILE" EXIT
```

---

## 5. Missing Monitoring: Observability Gaps

**Verdict: HIGH -- The current monitoring is a single-dimension view.**

### 5.1 What Exists

| Alert | Metric | Threshold | Purpose |
|---|---|---|---|
| `gurobi-cosmos-throttling-429-a` | TotalRequests(429) | >= 20/5min | Throttling detection |
| `gurobi-cosmos-latency-a` | ServerLatency | > 99ms | Latency degradation |
| `gurobi-cosmos-health-a` | ResourceHealth | Unhealthy | Availability |

### 5.2 What Is Missing

```text
OBSERVABILITY GAPS:
  |  Missing Metric                        | Why It Matters                                          | Severity |
  |----------------------------------------|---------------------------------------------------------|----------|
  | NormalizedRUConsumption sustained >80%  | Detects approaching throttling BEFORE 429s occur.       | CRITICAL |
  |                                        | Current alert only fires AFTER damage is done.          |          |
  |----------------------------------------|---------------------------------------------------------|----------|
  | TotalRequestUnits trend (daily/weekly) | Detects gradual workload growth that will eventually     | HIGH     |
  |                                        | exceed provisioned capacity. The threshold was already   |          |
  |                                        | raised once (1->20). Next time it will be 20->?.        |          |
  |----------------------------------------|---------------------------------------------------------|----------|
  | ServerLatency correlated with 429s     | 429s cause client-side retries which increase latency    | HIGH     |
  |                                        | for non-throttled requests. Detect cascading degradation.|          |
  |----------------------------------------|---------------------------------------------------------|----------|
  | Per-collection request count anomaly   | Identifies which collection is the hotspot. Currently    | MEDIUM   |
  |                                        | must be debugged manually during incidents.              |          |
  |----------------------------------------|---------------------------------------------------------|----------|
  | Autoscale RU/s current (if migrated)   | After autoscale migration, track actual scaling behavior | MEDIUM   |
  |                                        | to validate cost assumptions and detect scaling ceiling. |          |
```

### 5.3 Recommended Additional Alert

**NormalizedRU Sustained Saturation Alert** (pre-throttling warning):

```hcl
resource "azurerm_monitor_metric_alert" "cosmosdb_ru_saturation" {
  name                = "gurobi-cosmos-ru-saturation-a"
  resource_group_name = "rg-gurobi-platform-a"
  scopes              = [azurerm_cosmosdb_account.mongodb.id]
  description         = "NormalizedRU sustained above 80% -- approaching throttling"
  severity            = 3  # Sev3 = warning, not page
  frequency           = "PT5M"
  window_size         = "PT15M"  # 15-min window to filter transient spikes

  criteria {
    metric_namespace = "microsoft.documentdb/databaseaccounts"
    metric_name      = "NormalizedRUConsumption"
    aggregation      = "Average"  # Average over 15min -- sustained, not spike
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.gurobi.id
  }
}
```

This fires when the **average** NormalizedRU is above 80% for 15 minutes -- meaning
sustained pressure, not the periodic burst pattern (which averages ~15% over 15 min).

---

## 6. On-Call Experience Assessment

**The core question: "Does this solve the 'don't wake me up at night' problem?"**

### Current State

```text
ALERT FATIGUE CALCULATION:
  Pattern: ~24 429s every 15 minutes
  Alert threshold: 20 429s / 5min window
  Evaluation frequency: every 5 minutes
  failingPeriods: 0/0 (fires on first breach)
  autoMitigate: true (auto-resolves when < 20)

  Result: Alert fires -> resolves -> fires -> resolves
  Frequency: ~4 alerts/hour during active period
  Each alert: OpsGenie -> Rootly -> Escalation Policy -> Phone call

  At 3 AM: Phone buzzes every 15 minutes. Engineer wakes up, checks,
  sees known pattern, acknowledges, goes back to sleep. Repeat 4x/hour.
  This is a denial-of-service attack on your own on-call.
```

### After Proposed Changes (As Written)

| Change | Effect on On-Call | Problems |
|---|---|---|
| Burst capacity | **Maybe** stops 429s, **maybe** not | Not guaranteed; false confidence |
| Alert dampening (as written) | **Does not work** -- wrong Terraform block | Zero improvement |
| Autoscale migration | **Actually solves root cause** | Not immediate; needs CLI execution |
| Automated runbook | **Correct approach** but script has failure modes | Crashes on empty data, no timeout |

### What Actually Solves This

```text
PRIORITY ORDER (fastest to slowest impact on on-call):

1. IMMEDIATE (today): Increase window_size to PT15M AND raise threshold to 50
   -> Single periodic burst (24 429s) in 15-min window < 50 -> no alert
   -> Two bursts in same window (48 429s) < 50 -> still no alert (acceptable)
   -> Three bursts or sustained (72+) > 50 -> ALERT (genuine degradation)
   -> Implementation: One Terraform variable change, zero risk
   -> On-call impact: IMMEDIATE silence for known pattern

2. THIS WEEK: Migrate hot collections to autoscale via Azure CLI
   -> Eliminates 429s at source (burst absorbed by autoscale)
   -> On-call impact: Root cause eliminated

3. THIS WEEK: Enable burst capacity
   -> Free, helps sometimes, not guaranteed
   -> On-call impact: Reduces 429 frequency probabilistically

4. NEXT SPRINT: Deploy automated runbook (after fixing failure modes)
   -> Classifies future alerts automatically
   -> On-call impact: Auto-ack for known patterns, smart escalation for new ones

5. NEXT SPRINT: Add NormalizedRU saturation alert (Sev3, no page)
   -> Early warning before throttling occurs
   -> On-call impact: Proactive capacity planning, not reactive firefighting
```

---

## 7. CosmosDB Failover and Maintenance Window Behavior

### What Happens During CosmosDB Maintenance

```text
MAINTENANCE WINDOW ANALYSIS:
  This account: Single region (West Europe), no automatic failover
  During platform maintenance:
    - CosmosDB may perform partition moves
    - Brief latency spikes and possible 429s during partition migration
    - NormalizedRU may spike to 100% temporarily
    - Metrics may be delayed or temporarily unavailable

  RUNBOOK IMPACT:
    - Metric query returns incomplete/delayed data -> misclassification
    - Maintenance-induced 429s look like SUSTAINED pattern -> false escalation
    - Single-region account: no failover, maintenance affects ALL traffic

  RECOMMENDATION: The runbook should check Azure Service Health for active
  maintenance events before classifying. Or at minimum, document this as a
  known false-positive scenario in the escalation notes.
```

### What Happens During CosmosDB Failover

```text
This account has automatic_failover = false and single region.
There IS no failover. If West Europe has an issue:
  - All traffic fails
  - This is a different incident entirely
  - The throttling alert is the least of your problems
```

---

## 8. Summary of Findings

```text
FINDING TABLE
=============================================================================
| # | Severity | Finding                                    | Section |
|---|----------|--------------------------------------------|---------|
| 1 | CRITICAL | Burst capacity not guaranteed -- not a fix  | 2       |
| 2 | CRITICAL | Alert dampening IaC uses wrong TF block     | 2       |
| 3 | CRITICAL | Runbook crashes on empty metric data        | 4.1     |
| 4 | HIGH     | TF autoscale migration = destroy-apply      | 3       |
| 5 | HIGH     | Runbook has no timeout on az CLI calls      | 4.2     |
| 6 | HIGH     | Runbook has no auth pre-check               | 4.3     |
| 7 | HIGH     | Metric pipeline delay causes miscount       | 4.4     |
| 8 | HIGH     | Missing NormalizedRU saturation alert       | 5       |
| 9 | MEDIUM   | Classification edge cases (deploy, maint)  | 4.5     |
| 10| MEDIUM   | No idempotency guard for concurrent runs   | 4.6     |
| 11| MEDIUM   | Autoscale cost not quantified for team      | 3       |
=============================================================================
```

---

## 9. Required Fixes Before Ship

### Must Fix (Blocking)

1. **Fix alert dampening IaC**: Use `window_size = "PT15M"` + `threshold = 50`
   instead of `dynamic_threshold_failing_periods`. Or switch entirely to
   `dynamic_criteria` block.

2. **Add empty data guard to runbook**: Check for null/empty `RU_DATA` and
   `THROTTLE_DATA` before classification. Use distinct exit code (2) for
   inconclusive results.

3. **Add timeout to runbook az calls**: Wrap `az monitor metrics list` in
   `timeout 30` to prevent indefinite hangs.

4. **Document burst capacity limitation**: Change RCA language from "fix" to
   "best-effort mitigation". Add the Microsoft disclaimer quote.

5. **Document Terraform autoscale trap**: Add warning that `azurerm` provider
   cannot switch throughput mode. CLI migration is the only safe path.

### Should Fix (Before Production)

6. **Add auth pre-check** to runbook script.

7. **Offset metric query window** by 5 minutes to account for pipeline delay.

8. **Add lock/dedup mechanism** to prevent concurrent runbook executions.

9. **Create NormalizedRU saturation alert** (Sev3, no page, 15-min window).

10. **Add per-collection request count dashboard** for faster incident triage.

---

## 10. Verdict

```text
SRE MANIAC VERDICT:
  Overall Status: FIX FIRST
  Confidence: HIGH
  Critical Issues: 3 (burst capacity framing, IaC dampening block, runbook crash)
  High Issues: 5 (TF autoscale trap, timeouts, auth, metric delay, missing alerts)

  The RCA analysis is thorough and the root cause identification is excellent.
  The remediation proposals have the right intent but wrong implementation details.
  The runbook design is architecturally sound but operationally fragile.

  Fix the 5 blocking items. Then this is ready to ship.

  The fastest path to on-call relief is NOT the runbook -- it is a single IaC change:
  window_size = PT15M + threshold = 50. Deploy that TODAY. Everything else is Week 2.
```

---

**Sources:**
- [Azure CosmosDB Burst Capacity](https://learn.microsoft.com/en-us/azure/cosmos-db/burst-capacity)
- [Burst Capacity FAQ](https://learn.microsoft.com/en-us/azure/cosmos-db/burst-capacity-faq)
- [CosmosDB Autoscale Provisioning](https://learn.microsoft.com/en-us/azure/cosmos-db/provision-throughput-autoscale)
- [Autoscale FAQ](https://learn.microsoft.com/en-us/azure/cosmos-db/autoscale-faq)
- [az cosmosdb mongodb collection throughput CLI](https://learn.microsoft.com/en-us/cli/azure/cosmosdb/mongodb/collection/throughput)
- [azurerm_cosmosdb_account Terraform Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cosmosdb_account)
- [azurerm_cosmosdb_mongo_collection Terraform Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cosmosdb_mongo_collection)
- [azurerm_monitor_metric_alert Terraform Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_metric_alert)
- [Monitor Normalized Request Units](https://learn.microsoft.com/en-us/azure/cosmos-db/monitor-normalized-request-units)
