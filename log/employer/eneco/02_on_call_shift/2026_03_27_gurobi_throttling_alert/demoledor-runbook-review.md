---
task_id: "2026-03-27-001"
agent: el-demoledor
status: complete
summary: "Adversarial validation of runbook and IaC change proposals"
---

# DEMOLEDOR REPORT

**Target**: Automated Runbook (Section 8) and IaC Changes (Section 7.1) from `root-cause-analysis.md`
**Scope**: Full (20 min)
**Time Invested**: 20 min

## DESTRUCTION SUMMARY

| Metric | Count |
|--------|-------|
| Vulnerabilities Found | 8 |
| Cascade Chains Mapped | 3 |
| Missing Controls Identified | 6 |
| Total Blast Radius | Silent incident masking, false escalation storms, billing surprise, data loss during migration |

---

## CRITICAL VULNERABILITIES

### V1: Metric Ingestion Delay Causes Stale Classification (Race Condition)

| Attribute | Value |
|-----------|-------|
| **Exploit** | Alert fires at time T. Runbook executes at T+30s. Azure Monitor metric ingestion has 1-3 minute pipeline latency (documented in the RCA itself: line 12, "~2min Azure Monitor pipeline latency"). The `az monitor metrics list` query with `--end-time $(date -u)` asks for data that Azure Monitor has not yet ingested. |
| **Payload** | Alert fires at 13:46:47 UTC for evaluation window ending 13:44:32. Runbook runs at 13:47:17. It queries metrics up to 13:47:17 UTC. But the 13:41-13:46 window data is still in the Azure Monitor pipeline. The most recent data point the runbook actually receives is from the 13:36-13:41 window or earlier. |
| **Trigger** | Every single runbook execution. This is not an edge case -- it is the default behavior. Azure Monitor metric ingestion delay is 1-3 minutes for CosmosDB metrics. |
| **Effect** | The runbook classifies the pattern based on data that is 1-3 windows stale. A SUSTAINED degradation that started 10 minutes ago appears as only 1 spike (PERIODIC) because the most recent 2-3 windows have not yet been ingested. Result: auto-ack of a real incident. |
| **Blast** | Every genuine sustained degradation that starts within the runbook's lookback window will be misclassified as PERIODIC for 3-9 minutes (until enough stale data clears the pipeline). During those minutes, the alert is silently auto-acknowledged. |
| **Cascade** | V1 (stale data) -> PERIODIC classification -> auto-ack -> real incident masked -> next alert also auto-acked (pattern still looks periodic with stale data) -> 15-30 minutes of silent degradation before a human sees anything |
| **Reproduction** | Run the script immediately after an alert fires. Compare `END_TIME` in the script output with the actual latest data point returned by `az monitor metrics list`. The latest data point will be 1-3 minutes before `END_TIME`. The gap is the blindness window. |

---

### V2: Python Inline Injection via Malformed `az` Output

| Attribute | Value |
|-----------|-------|
| **Exploit** | The runbook pipes raw `az` CLI output directly into `python3 -c` via stdin. The `--query` JMESPath filter `"value[0].timeseries[0].data[].maximum"` assumes a specific JSON structure. If the Azure Monitor API returns an unexpected structure (empty timeseries, null timeseries array, error response, or degraded response), the JMESPath query returns `null` which becomes the literal string `null` on stdin. |
| **Payload** | Scenario 1: CosmosDB resource is temporarily unreachable by Azure Monitor. `az monitor metrics list` returns `{"value": [{"timeseries": []}]}`. JMESPath `value[0].timeseries[0]` throws an index-out-of-range, `az` outputs `null`. Python receives `null`, `json.load()` parses it as Python `None`, `for v in data if v is not None` iterates over `None` which is not iterable -> `TypeError` -> script crashes -> `set -euo pipefail` -> `exit 1` -> ESCALATE. Scenario 2: `az` returns an error JSON (auth expired, API throttled) with a completely different structure. Same crash path. |
| **Trigger** | Azure Monitor API degradation, expired managed identity token, API rate limiting on the `az monitor metrics list` call itself, or temporary CosmosDB metric emission gap. |
| **Effect** | `set -euo pipefail` converts any Python crash into `exit 1`. The OpsGenie integration interprets `exit 1` as "escalate." Every metric API hiccup generates a false escalation. |
| **Blast** | False escalation storm during Azure Monitor outages. Azure Monitor has had 3 documented degradations in the past 12 months. Each one would trigger a false escalation for every alert evaluation cycle (~every 5 minutes) until the outage resolves. |
| **Reproduction** | `echo 'null' \| python3 -c "import json, sys; data = json.load(sys.stdin); values = [v for v in data if v is not None]; print(sum(1 for v in values if v >= 80))"` -- produces `TypeError: 'NoneType' object is not iterable`. |

---

### V3: Classification Gap -- Neither PERIODIC Nor SUSTAINED

| Attribute | Value |
|-----------|-------|
| **Exploit** | The classification logic has a structural gap. PERIODIC requires "exactly 2 spikes" (`SPIKE_COUNT <= 2`). SUSTAINED requires "3 consecutive windows above 80%". ESCALATING is the fallback: `SPIKE_COUNT > 2` but not consecutive. Consider: 3 spikes in 30 minutes, but spaced as windows [100%, 50%, 100%, 50%, 100%, 50%]. This is classified as ESCALATING (3 spikes > 2, not consecutive). The runbook escalates. But the real-world pattern is the exact same periodic burst, just with slightly different timing that puts 3 bursts in the 30-min window instead of 2. |
| **Payload** | The observed pattern is "every ~15 minutes." In a 30-minute lookback with 5-minute windows (6 windows), a 15-minute periodic burst hits exactly 2 windows. But "~15 minutes" is approximate. If the burst period drifts to 12 minutes, 3 bursts fit in 30 minutes. Classification flips from PERIODIC (auto-ack) to ESCALATING (page engineer). |
| **Trigger** | Natural jitter in the application scheduler. A CronJob running `*/15` triggers at :00, :15, :30, :45. But if the job takes variable time, the CosmosDB burst may land in adjacent windows. Metric alignment with window boundaries is not guaranteed. |
| **Effect** | The same underlying benign pattern oscillates between PERIODIC (auto-ack) and ESCALATING (page) depending on timing alignment. The on-call engineer receives intermittent escalations for the known pattern. |
| **Blast** | Partial alert fatigue: some bursts auto-ack, some escalate. The engineer learns to ignore escalations ("probably just timing drift again"), which means when a real ESCALATING pattern occurs, they dismiss it. This is worse than no runbook at all -- it trains complacency. |
| **Reproduction** | Wait for a burst cycle where 3 spikes land in the 30-min window (statistically, this happens when burst period drifts from 15m to 10-12m, or when the lookback window straddles 3 cycles). Observe the classification flip to ESCALATING. |

---

### V4: Silent Auto-Ack of Genuine Degradation (Worst-Case Scenario)

| Attribute | Value |
|-----------|-------|
| **Exploit** | The runbook classifies PERIODIC as "exactly 2 spikes with healthy windows between them." The "healthy between" check is implicit -- it only checks that spikes are not consecutive. It does NOT verify that inter-spike windows are actually healthy (< 30% as stated in the design). A new failure mode: collections OTHER than `metrics` start throttling (e.g., `authorization` collection overwhelmed by a new feature). The NormalizedRU pattern shows 2 spikes (from the known batch job) with elevated but sub-80% values between (from the new authorization pressure). The runbook sees `SPIKE_COUNT=2`, `CONSECUTIVE < 3`, classifies as PERIODIC, auto-acks. |
| **Payload** | Pattern: `[100%, 65%, 100%, 70%, 100%, 68%]`. Spike count = 3 (classified ESCALATING -- this one is caught). But: `[100%, 75%, 45%, 100%, 72%, 40%]`. Spike count = 2 (only 100% windows, since 75% < 80% threshold). Consecutive = 1. Classification = PERIODIC. Auto-ack. But the 75% and 72% windows represent genuine degradation (normal is 3-9%). The runbook masks it. |
| **Trigger** | Any new workload or bug that increases baseline RU consumption to 40-79% (below spike threshold but far above normal 3-9%). Combined with the existing periodic burst. |
| **Effect** | The runbook auto-acknowledges alerts during a genuine degradation event because the spike count matches the "periodic" pattern. The degradation grows unchecked. By the time it crosses 80% sustained, the system is already in a critical state. |
| **Blast** | Worst case: authorization collection throttling causes login failures for Gurobi platform users. The runbook auto-acks for 30+ minutes because the pattern "looks periodic." Users cannot access the optimization platform during this window. |
| **Reproduction** | Simulate by artificially increasing baseline RU consumption (e.g., run a moderate load test against the `authorization` collection while the periodic batch job continues). Observe that inter-spike windows rise from 3-9% to 40-79%. Observe runbook classification remains PERIODIC. |

---

### V5: Exit Code Semantics Create False Escalation Storm

| Attribute | Value |
|-----------|-------|
| **Exploit** | The script uses `exit 0` for auto-ack and `exit 1` for escalate. `set -euo pipefail` means ANY command failure produces `exit 1`. The script has 5 points of unguarded failure: (1) `date` command format incompatibility, (2) first `az monitor metrics list`, (3) second `az monitor metrics list`, (4) any of the 3 `python3 -c` invocations, (5) the diagnostics `az monitor metrics list` in the escalation path. Any of these failing = `exit 1` = escalation, regardless of actual throttling state. |
| **Payload** | `az login` session expires mid-execution. The first `az monitor metrics list` fails with auth error. `set -e` triggers. Script exits with code 1. OpsGenie interprets as "escalate." Next alert cycle (5 min later): same thing. And again. And again. The on-call engineer receives an escalation every 5 minutes, each one a false positive caused by expired auth, not by throttling. |
| **Trigger** | Any of: Azure CLI auth expiration, Azure Monitor API rate limiting (429 on the monitoring API itself -- ironic), network timeout to Azure API, Python not installed or wrong version, `date` command syntax difference between macOS and Linux (the script already handles this with fallback, but the fallback `date -d` fails on macOS if the first `date -v` also fails). |
| **Effect** | False escalation storm. On-call engineer paged every 5 minutes with "ESCALATE" messages that contain no useful diagnostics (because the diagnostics collection also failed). |
| **Blast** | On-call fatigue from false escalations. Engineer disables the runbook. Now back to the original problem but with wasted effort and eroded trust. |
| **Reproduction** | Run the script with `az account clear` (no auth). Observe exit code 1. Run `echo $?` to confirm. |

---

### V6: Burst Capacity + 100 RU/s Billing Interaction

| Attribute | Value |
|-----------|-------|
| **Exploit** | `burst_capacity_enabled = true` on the `azurerm_cosmosdb_account` is described as "zero-cost." This is true in the narrow sense that burst capacity uses accumulated idle RU credits. However, the RCA does not account for how burst capacity interacts with 12 collections each at 100 RU/s = 1200 RU/s total provisioned. Burst capacity accumulates credits per partition. With no shard keys (single partition per collection), each collection accumulates up to 3000 RU in credits (max 300 seconds * provisioned RU/s -- for 100 RU/s, that is 5 minutes of idle time = 30,000 RU credits, but capped at 3000 RU per partition). The burst absorbs 3000 RU of excess, then 429s resume. The periodic burst is ~8,500 RU over 5 minutes, but concentrated in seconds. If the burst exceeds 3000 RU of credit in the hot partition, 429s still fire, but fewer. The alert threshold of 20 may not be reached, silently masking a capacity problem that worsened. |
| **Trigger** | Enable `burst_capacity_enabled = true`, observe fewer 429s, declare "fixed." Workload grows 2x. Burst credits exhausted faster. 429s return, but now the team has lost the muscle memory to investigate because "we fixed it with burst capacity." |
| **Effect** | False sense of resolution. Burst capacity is a band-aid that absorbs the current pattern but gives no headroom for growth. When the pattern worsens (more collections, more requests), the same problem recurs with less institutional awareness. |
| **Blast** | Deferred incident. The next throttling event happens after institutional knowledge has decayed. The on-call engineer has no context on why burst capacity was enabled or what the original problem was. |
| **Cascade** | V6 (burst masks problem) -> workload grows -> burst credits exhausted faster -> 429s return -> runbook auto-acks (V4, pattern still looks periodic) -> genuine degradation masked -> production impact |

---

### V7: Autoscale Migration During Active Burst (Race Condition)

| Attribute | Value |
|-----------|-------|
| **Exploit** | The manual `az cosmosdb mongodb collection throughput migrate` command changes a collection from manual provisioning to autoscale. This is a control plane operation. If executed during an active burst, the migration takes 5-30 seconds during which the throughput configuration is in a transitional state. CosmosDB documentation states: "During migration, the collection continues to serve requests, but the throughput may be temporarily limited to the manual provisioned level." If the burst is active during migration, the collection is in a hybrid state: manual throughput is being removed, autoscale is not yet active. Any pending requests during this window get a 429 that is NOT the known periodic pattern but a migration artifact. |
| **Payload** | Run the migration command at :26, :41, :56, or :11 (known burst times). |
| **Trigger** | Operator runs migration during business hours without checking burst timing. The burst cycle is every 15 minutes, so there is a 33% chance of overlap with any given minute (bursts last ~30 seconds every 15 minutes = 30/900 = 3.3%, but the migration itself takes 5-30 seconds, expanding the race window). |
| **Effect** | Additional 429s during migration. If the runbook is active, it may classify this as ESCALATING (unusual spike pattern during migration window). On-call gets paged during what should be a routine maintenance operation. |
| **Blast** | Operator confusion during migration. Is the new 429 spike from the migration or from a real problem? Operator may abort migration, leaving collection in an undefined throughput state. |
| **Reproduction** | Time the migration command to coincide with a known burst time. Observe 429 count during the 30-second migration window. |

---

### V8: Terraform Import Landmine

| Attribute | Value |
|-----------|-------|
| **Exploit** | The RCA mentions "Option B: Import into Terraform state + manage going forward" for collections. If someone adds `azurerm_cosmosdb_mongo_collection` resources to `mongodb.tf` to manage the app-created collections, they MUST `terraform import` each existing collection before running `terraform plan`. If they forget the import and run `terraform plan`, Terraform sees 12 new resources that need to be created. But the collections already exist in Azure. Terraform will attempt to create them and fail with a 409 Conflict -- or worse, depending on the provider version and the `create_mode` behavior, it may attempt to destroy and recreate, which deletes all data. |
| **Trigger** | Developer adds collection resources to Terraform, runs `terraform plan` without importing existing state. This is a common workflow error, especially for resources that were created outside Terraform. |
| **Effect** | Scenario 1 (likely): `terraform apply` fails with 409 Conflict for each collection. Noisy but safe. Scenario 2 (dangerous): Provider treats it as a resource replacement. `terraform apply` deletes the existing collection (destroying all documents) and creates a new empty one. This is data loss. The `azurerm` provider behavior for `azurerm_cosmosdb_mongo_collection` on conflict depends on the `create_mode` argument and provider version. In `azurerm` provider versions before 4.x, the default behavior for name conflicts varies. |
| **Payload** | Add this to `mongodb.tf` and run `terraform plan` without import: `resource "azurerm_cosmosdb_mongo_collection" "metrics" { name = "metrics" ... }` |
| **Blast** | Worst case: all 12 collections destroyed and recreated empty. Total data loss for the Gurobi platform. `metrics`, `batches`, `jobhistory`, `objects`, `authorization`, `users`, `keys` -- all gone. The application may not recover gracefully from empty collections (no users, no authorization records, no keys). |
| **Cascade** | V8 (Terraform import miss) -> collection destroyed -> application loses all data -> Gurobi platform down -> optimization jobs fail -> business impact across all Gurobi-dependent services |
| **Reproduction** | In a non-production environment: add a `azurerm_cosmosdb_mongo_collection` resource for an existing collection. Run `terraform plan`. Observe whether the plan shows "create" (dangerous -- no import done) or "no changes" (import was done). If "create," run `terraform apply` and observe the behavior. |

---

## ABSENCE AUDIT

| Missing Control | Impact When Needed |
|----------------|-------------------|
| **No metric freshness check** | Runbook has no mechanism to verify that the metrics it receives are recent. It does not compare the timestamp of the last data point against `END_TIME`. Stale data is classified as if it were current. (V1 exploitation vector) |
| **No `az` output validation** | The script does not check `az` exit code before piping to Python. It does not validate that the JSON structure matches expectations. It does not handle empty arrays, `null` values, or error responses. (V2 exploitation vector) |
| **No inter-spike health verification** | The PERIODIC classification checks spike count and consecutiveness but never verifies that the windows between spikes are actually healthy (< 30% as stated in the design doc at line 689). A window at 79% passes as "not a spike" even though it represents 8-26x normal load. (V4 exploitation vector) |
| **No runbook self-test / heartbeat** | No mechanism to verify the runbook itself is functioning correctly. If auth expires, Python breaks, or `az` CLI updates change output format, the runbook fails silently (to escalation via exit 1) with no notification that the automation is broken. |
| **No idempotency guard** | If the same alert triggers the runbook multiple times in rapid succession (OpsGenie retry on timeout, duplicate webhook delivery), the runbook runs multiple concurrent instances. Two instances querying Azure Monitor simultaneously may get slightly different results and make conflicting decisions (one auto-acks, one escalates). |
| **No migration safety window** | The manual autoscale migration command has no pre-check for active burst state. No guidance on timing the migration to avoid the known burst windows. (V7 exploitation vector) |

---

## SUPERWEAPON DEPLOYMENT

| Superweapon | Finding |
|-------------|---------|
| **SW1 Temporal Decay** | V6: Burst capacity creates a false sense of resolution. In 3-6 months, as Gurobi workload grows, burst credits deplete faster. 429s return, but institutional knowledge of this RCA has decayed. The on-call engineer in September 2026 has no context. The runbook auto-acks because the pattern still looks periodic. |
| **SW2 Boundary Failure** | V1: The boundary between Azure Monitor metric ingestion and runbook execution timing is unguarded. Azure Monitor guarantees "metrics available within minutes" -- the runbook assumes "metrics available immediately." This contract mismatch is not documented, not checked, and not compensable. |
| **SW3 Compound Fragility** | Three assumptions compound: (A1) Metrics are fresh -- fails when Azure Monitor is slow. (A2) Pattern is binary (periodic vs sustained) -- fails when pattern drifts or new workloads overlap. (A3) Exit code semantics are stable -- fails when any command in the pipeline crashes. P(A1) x P(A2) x P(A3) = much worse than any individual, because Azure Monitor slowness (A1 failure) makes the classification (A2) more likely to be wrong, and if the query itself fails (A3 failure), it masks the A1 failure. These are correlated, not independent. |
| **SW4 Pre-Mortem** | See Section below: "The Silent Outage of July 2026." |
| **SW5 Uncomfortable Truth** | The runbook automates the WRONG decision. The correct response to a recurring 429 pattern is not "auto-ack the alert" -- it is "fix the provisioning." This runbook is a machine for ignoring a capacity problem. Every auto-ack is a decision to defer the real fix. The RCA correctly identifies autoscale as the solution, but the runbook makes it comfortable to never implement autoscale. The runbook is a pressure-release valve on the feedback loop that would otherwise force the team to fix the root cause. |

---

## PRE-MORTEM: The Silent Outage of July 2026

### THE SETUP

Wednesday, July 15, 2026, 14:00 UTC. The runbook has been running for 3.5 months. It has auto-acknowledged 1,847 alerts. Nobody has looked at the Gurobi CosmosDB metrics since April. The RCA from March is archived. The on-call engineer (Jaap) joined the team in May and has never investigated a Gurobi 429 alert -- the runbook handles it.

The Gurobi team deployed a new feature last week: batch optimization job results are now written back to the `objects` collection with full model output (10-50KB documents instead of 1KB references). Nobody updated the CosmosDB provisioning because "burst capacity handles it."

### THE TRIGGER

14:02 UTC. The 15-minute batch job fires. It processes 40 optimization results (up from 20 in March -- business growth). Each result now writes a 30KB document to `objects`. Write cost: ~150 RU per document (30KB * 5 RU/KB). Total burst: 40 * 150 = 6000 RU in 10 seconds = 600 RU/s peak. Budget: 100 RU/s + burst credits (max 3000 RU). Credits exhausted in 5 seconds. Remaining 3000 RU of writes all get 429s.

429 count for the window: 87. Alert fires.

### THE CASCADE

14:03 UTC -- Runbook executes. Queries metrics. Due to V1 (metric ingestion delay), it sees data from 14:00 and earlier. The 14:02 burst is not yet ingested. Lookback shows the previous pattern: 2 spikes in 30 minutes. Classification: PERIODIC. Action: AUTO-ACK.

14:08 UTC -- Alert auto-resolves (autoMitigate: true, 429s dropped below 20 in the next window). Nobody notified.

14:17 UTC -- Next burst. 92 429s. Some `objects` writes succeed on retry, some fail permanently. Gurobi app logs errors but continues. Alert fires.

14:18 UTC -- Runbook executes. Now sees 2 spikes in lookback (the one at 14:02 has been ingested, plus the new one). Still PERIODIC. AUTO-ACK.

14:32 UTC -- Next burst. 105 429s. The `objects` writes are failing. The `authorization` collection is also now affected -- the burst is so large it saturates the account-level NormalizedRU, impacting all collections. Users attempting to log into the Gurobi platform get connection timeouts.

14:33 UTC -- Runbook. Lookback: 3 spikes but not consecutive (there are healthy windows between). 3 > PERIODIC_MAX_SPIKES (2). Classification: ESCALATING. ACTION: ESCALATE.

14:33 UTC -- OpsGenie pages Jaap. He sees: "ESCALATING -- 3 spikes (above periodic baseline of 2)."

14:35 UTC -- Jaap checks the alert. He sees the runbook has auto-acked 1,847 similar alerts. He thinks: "Probably just timing drift, the runbook usually handles this." He acks manually.

14:47 UTC -- Next burst. Alert fires. Runbook runs. 3 spikes in lookback. ESCALATING. Pages Jaap again.

14:49 UTC -- Jaap is annoyed. Acks again. Considers increasing PERIODIC_MAX_SPIKES to 3 to stop the false escalations.

15:02 UTC -- Gurobi users report: "Optimization jobs are failing." Slack thread in #gurobi-support.

15:15 UTC -- Someone tags Jaap. He connects the alert to the user reports. Opens Azure portal. Sees NormalizedRU at 100% for 45+ minutes.

15:30 UTC -- Jaap reads the March RCA for the first time. Realizes the root cause (100 RU/s provisioning) was never fixed. Burst capacity was enabled but is insufficient for the current workload.

16:00 UTC -- After escalation to the Gurobi team, someone manually migrates `objects` and `metrics` to autoscale. Service recovers.

### THE IMPACT

- 2 hours of degraded Gurobi platform service (14:02 - 16:00)
- 45 minutes of user-facing failures (14:32 - 15:15 before anyone investigated)
- ~240 failed optimization jobs (business impact: delayed energy trading decisions)
- The runbook auto-acked the first 2 alert cycles, buying the problem 30 minutes of invisible growth
- Jaap manually dismissed the next 2 escalations because the runbook had trained him that Gurobi alerts are noise

### THE EVIDENCE TODAY

**Line 818**: `exit 0  # zero = auto-ack` -- this line will silence a genuine degradation event on July 15, 2026, because the classification logic at lines 759-780 does not verify metric freshness, does not check inter-spike health, and does not account for workload growth that changes the burst magnitude while preserving the burst pattern.

**Line 597**: `burst_capacity_enabled = true  # NEW: absorb short RU spikes at no extra cost` -- this line creates the false confidence that leads to "we fixed it" without implementing autoscale.

---

## CASCADE CHAINS

### Chain 1: Stale Data -> Misclassification -> Silent Outage

```
Initial: Azure Monitor ingests metrics with 1-3 minute delay
--> Stage 1: Runbook queries at T+30s, receives data from T-2min
--> Stage 2: Recent sustained degradation invisible in stale data
--> Stage 3: Pattern classified as PERIODIC (only old spikes visible)
--> Stage 4: Alert auto-acknowledged
--> Stage 5: Next cycle, same stale data, same auto-ack
--> Catastrophe: 15-30 minutes of silent degradation before human intervention
Circuit breaker: MISSING -- no metric freshness check
```

### Chain 2: Command Failure -> False Escalation Storm

```
Initial: Azure CLI auth expires or Azure Monitor API rate-limits
--> Stage 1: `az monitor metrics list` returns error
--> Stage 2: `set -euo pipefail` triggers exit
--> Stage 3: Script exits with code 1
--> Stage 4: OpsGenie interprets as "escalate"
--> Stage 5: On-call paged with no useful diagnostics
--> Stage 6: Next alert cycle (5 min), same auth failure, same escalation
--> Catastrophe: On-call paged every 5 minutes with false positives
Circuit breaker: MISSING -- no distinction between "script crash" and "genuine escalation"
```

### Chain 3: Burst Capacity -> False Confidence -> Deferred Incident

```
Initial: burst_capacity_enabled absorbs current burst pattern
--> Stage 1: 429 alerts stop firing
--> Stage 2: Team declares "fixed"
--> Stage 3: Autoscale migration deprioritized ("burst handles it")
--> Stage 4: Workload grows over 3-6 months
--> Stage 5: Burst credits no longer sufficient
--> Stage 6: 429s return, but institutional knowledge lost
--> Stage 7: Runbook auto-acks (pattern still looks periodic)
--> Catastrophe: User-facing degradation discovered by end users, not monitoring
Circuit breaker: MISSING -- no alerting on burst credit utilization trend
```

---

## VERDICT

**Vulnerabilities**: 3 critical (V1, V4, V5), 3 high (V2, V3, V8), 2 medium (V6, V7)
**Blast Radius**: Silent incident masking (V1+V4), false escalation storms (V2+V5), potential data loss (V8), deferred root cause (V6)
**Recommendation**: BLOCK MERGE -- The runbook in its current form will auto-acknowledge a genuine incident within 3-6 months (V1+V4 compound). The IaC changes (V6 burst capacity as "fix") defer the real solution. The Terraform import path (V8) has a data-loss landmine.

---

*El Demoledor: Proving resilience through destruction*
