---
task_id: 2026-03-27-001
agent: linus-torvalds
timestamp: 2026-03-27T16:00:00Z
status: complete

summary: |
  Technical accuracy review of the CosmosDB 429 throttling RCA.
  The document is solid work. The alert payload cross-references correctly,
  the CosmosDB mechanics are accurate, and the causal chain is logically
  sound. I found a few issues: one factual error in the timeline diagram,
  one misleading RU/s math presentation, a missing remediation option, and
  some inferences presented without proper epistemic markers. None of these
  invalidate the core analysis.

key_findings:
  - finding_1: "Alert payload cross-reference is accurate — metric, threshold, window, severity, resource all match"
  - finding_2: "CosmosDB throttling mechanics are technically correct with one nuance about partition-level budgets"
  - finding_3: "Timeline diagram has a factual error — alert window vs fire time misalignment"
  - finding_4: "Burst RU/s math is illustrative but the 500+ peak claim is speculative without sub-second data"
  - finding_5: "Gurobi RSM scheduler inference is reasonable but should be labeled as hypothesis, not fact"
  - finding_6: "Missing remediation option: server-side retry policy (CosmosDB native)"
---

# Code Review: CosmosDB 429 Throttling RCA

**Target**: `root-cause-analysis.md` + `rootly-alert-payload.json`
**Verdict**: NEEDS WORK — Mostly solid, a few corrections required.

---

## 1. Data Accuracy: Alert Payload vs RCA Claims

Cross-referencing every claim in the RCA against the JSON payload.

| RCA Claim | Payload Evidence | Verdict |
|-----------|------------------|---------|
| Alert rule: `gurobi-cosmos-throttling-429-a` | `essentials.alertRule`: `"gurobi-cosmos-throttling-429-a"` | MATCH |
| Severity: Sev2 | `essentials.severity`: `"Sev2"` | MATCH |
| Resource: `cosmosdb-gurobi-platform-a` | `essentials.configurationItems[0]`: `"cosmosdb-gurobi-platform-a"` | MATCH |
| Resource group: `rg-gurobi-platform-a` | `essentials.targetResourceGroup`: `"rg-gurobi-platform-a"` | MATCH |
| Fired at: 2026-03-27T13:46:47 UTC | `essentials.firedDateTime`: `"2026-03-27T13:46:47.5480095Z"` | MATCH |
| Metric: TotalRequests filtered StatusCode=429 | `alertContext.condition.allOf[0]`: metricName=`TotalRequests`, dimensions StatusCode=`429` | MATCH |
| Threshold: >= 20 | `alertContext.condition.allOf[0].threshold`: `"20"`, operator: `"GreaterThanOrEqual"` | MATCH |
| Window: 5 min | `alertContext.condition.windowSize`: `"PT5M"` | MATCH |
| Aggregation: Count | `alertContext.condition.allOf[0].timeAggregation`: `"Count"` | MATCH |
| Metric value at trigger: 24 | `alertContext.condition.allOf[0].metricValue`: `24` | MATCH |
| Window: 13:39 - 13:44 UTC | `windowStartTime`: `"2026-03-27T13:39:32.994Z"`, `windowEndTime`: `"2026-03-27T13:44:32.994Z"` | MATCH |
| Description: "Trigger on Request status code of 429" | `essentials.description` | MATCH |
| Action group: `ag-trade-platform-a` | NOT in payload — action group name is an inference | **UNVERIFIABLE** from this payload |
| Subscription: "Eneco MCC - Acceptance - Workload VPP" | Subscription ID present (`b524d084-...`) but friendly name not in payload | **UNVERIFIABLE** from this payload |

**Verdict**: All verifiable fields match exactly. The action group name and subscription friendly name cannot be confirmed from this payload alone — presumably sourced from the Azure portal or Terraform config. Not wrong, just not provable from the artifact provided.

---

## 2. CosmosDB Mechanics: Technical Accuracy

### 2.1 RU/s Model — CORRECT

The RCA's description of Request Units as a per-second budget, the cost examples (1 RU for point read, ~5 RU for write), and the 429 rejection behavior are all technically accurate. Specific points:

- "CosmosDB does NOT queue — it REJECTS immediately." **CORRECT.** CosmosDB returns 429 with `x-ms-retry-after-ms` header. The client SDK handles retries, not the server.
- Cost examples (1 RU point read, 5 RU write, 10-100+ query). **CORRECT.** These are standard ballpark figures from Microsoft documentation.

### 2.2 NormalizedRUConsumption — CORRECT with one nuance

The RCA states: "When NormalizedRU hits 100%, it means at least one physical partition has exhausted its RU budget."

This is **CORRECT**. NormalizedRUConsumption is the max across all physical partitions, not an average. A 100% reading means at least one partition is saturated, which is exactly what triggers 429s for requests hitting that partition.

**Nuance the RCA gets right implicitly but could state more explicitly**: At 100 RU/s provisioned throughput, CosmosDB allocates this across physical partitions. With a single partition (likely at this low throughput), 100% normalized RU = the entire account is saturated. The RCA's explanation is functionally correct for this scenario.

### 2.3 Token Bucket Analogy — MOSTLY CORRECT

The "bucket analogy" in Section 3.3 is a reasonable simplification. CosmosDB does use a token-bucket-like mechanism internally. The one inaccuracy: CosmosDB does not strictly use a 1-second granularity bucket. The actual implementation is more nuanced — it allows micro-bursting within sub-second intervals. But for an RCA, this level of simplification is acceptable and does not mislead the reader about the root cause.

### 2.4 autoMitigate — CORRECT

"autoMitigate: true — Alert auto-resolves when 429s drop below 20/5min." This is correct Azure Monitor behavior for metric alerts with autoMitigate enabled. Note: autoMitigate is NOT in the payload, so this was sourced from the alert rule definition. Reasonable.

---

## 3. Alert Pipeline: Accuracy

The pipeline diagram (Section 2.3) accurately represents:

1. CosmosDB emits TotalRequests metric
2. Azure Monitor evaluates with the filter/window/threshold from the payload
3. Routes to action group, then to Rootly/escalation

**One factual issue in the Timeline (Section 5)**:

The timeline diagram shows:

```
13:39          13:44          13:46
 │              │              │
 5-min window   window end     ALERT FIRED
```

The payload shows:
- `windowStartTime`: 13:39:32.994Z
- `windowEndTime`: 13:44:32.994Z
- `firedDateTime`: 13:46:47.548Z

The RCA's Section 1 table says "Fired At: 2026-03-27T13:46:47 UTC" — CORRECT.

But the timeline diagram in Section 5 labels the burst as "13:41-13:44" with "Burst #2" producing 24 429s. The data table in Section 1 shows the 13:41 row has 24 429s. This is consistent: the 5-minute evaluation window (13:39-13:44) would capture the 13:41 burst.

However, the timeline diagram is slightly misleading. It shows the evaluation window as "13:39 → 13:44" and the burst within it, but visually it implies the alert fired at 13:44 with a lag to 13:46. The actual story: Azure Monitor evaluates on a schedule (typically every 1-5 minutes). The ~2 minute gap between window end (13:44:32) and fire time (13:46:47) is the evaluation + notification latency. The RCA does not explain this gap. Minor, but worth noting for completeness.

---

## 4. Root Cause Logic: Causal Chain

The causal chain presented:

```
Periodic burst (every ~15 min) → exceeds 100 RU/s → 429 → alert fires
```

This is **logically sound** and well-supported by the data table in Section 1.

**Strengths of the analysis**:

- The data shows a clear repeating pattern: spikes at 13:26, 13:41, 13:56, 14:11 — approximately every 15 minutes.
- Between spikes, NormalizedRU% is 3-9% (healthy), confirming the burst nature.
- The 429 counts (16, 24, 24, 24) correlate perfectly with the 100% NormalizedRU spikes.
- The "2.3x to 2.8x normal" RU consumption during spikes is internally consistent.

**One issue with the burst math (Section 3.2)**:

The RCA claims "Peak RU/s: 500+" in the burst diagram. This number is speculative. Here is why:

- Azure Monitor metrics for CosmosDB have minimum 1-minute granularity.
- The `az monitor metrics list` command returns data at 1-minute or 5-minute intervals.
- You CANNOT determine sub-second peak RU/s from 5-minute aggregate data.

The 500+ figure is an inference: "8,500 RUs consumed in 5 minutes, but concentrated in a few seconds, so instantaneous rate must be high." This reasoning is DIRECTIONALLY correct — the burst must exceed 100 RU/s to trigger 429s — but the specific "500+" number is a guess. The RCA should either:

1. Label it explicitly as an estimate, or
2. Remove the specific number and say "significantly exceeds 100 RU/s"

The math "8500/300 = 28 RU/s average" is correct arithmetic but the RCA correctly notes this is misleading. Good.

---

## 5. Remediation Options: Assessment

| Option | RCA Assessment | My Assessment |
|--------|---------------|---------------|
| A. Enable Autoscale | Recommended as immediate fix | **CORRECT.** This is the standard Azure recommendation for bursty workloads. Autoscale on CosmosDB (MongoDB API) allows burst up to 10x the base RU/s. Setting base to 100 with max 1000 handles the burst pattern exactly. Cost impact is minimal — you pay the higher rate only during the seconds of burst. |
| B. Increase Manual RU/s | Listed as alternative | **CORRECT.** 400-500 RU/s would provide headroom. But you pay 24/7 for capacity used only seconds per 15 minutes. Wasteful. |
| C. Exponential backoff + jitter | Long-term improvement | **CORRECT.** But note: the CosmosDB MongoDB driver and most Azure SDKs already implement retry with backoff by default. The 429s in the metric are BEFORE client retries. Worth checking if the application is using raw connections without SDK retry policy. |
| D. Redesign schedule | Eliminates burst pattern | **CORRECT.** Most effective long-term but requires application team involvement. |

**Missing remediation option**:

**E. Server-side retry policy (CosmosDB native)**. Since September 2022, CosmosDB supports server-side retry for 429s (currently for SQL API; MongoDB API support should be verified). This eliminates 429s visible to the client entirely — CosmosDB retries internally. If available for MongoDB API, this is the cheapest fix: zero code change, zero cost change.

**F. Review partition key design.** At 100 RU/s with a single partition, this may not apply. But if the account scales later, a hot partition key on the `metrics` collection would recreate this problem at higher throughput. Worth noting for future-proofing.

**G. Adjust alert threshold.** This is NOT a fix for the throttling, but the alert's threshold of >= 20 in 5 minutes is relatively sensitive. If the burst is known, expected, and handled by SDK retries, the team may want to raise the threshold or add a suppression window to avoid alert fatigue. This is an operational concern, not a root cause fix.

---

## 6. Architecture Inferences: Gurobi RSM Scheduler

The RCA infers a "Gurobi RSM scheduler" running every ~15 minutes as the burst source. Let me assess this inference.

**Evidence supporting the inference**:

1. Database name `grb_rsm` — "grb" = Gurobi, "rsm" = Remote Services Manager. REASONABLE inference.
2. Collection names (`batches`, `jobhistory`, `metrics`, `registry`) are consistent with a job scheduling system.
3. The ~15 minute periodicity in the data is consistent with a scheduled task.
4. GridFS collections (`fs.files`, `fs.chunks`) suggest the application stores large binary objects (Gurobi model files are often large).

**Assessment**: The inference is **REASONABLE** but the RCA presents it with too much confidence.

Specifically, Section 4 draws an architecture diagram showing "Scheduler (periodic)" as a component with "Every ~15 min" labeled, and Section 1 says "likely a scheduled job." The diagram presents this as architectural fact when it is a hypothesis derived from metric patterns.

**What should change**: The architecture diagram should be explicitly labeled as "Inferred Architecture" or "Hypothesis." The ~15 minute cycle is observed in the data; the scheduler component is inferred. The RCA partially does this (says "likely") but the detailed architecture diagram without caveats presents inference as established fact.

To confirm, you would need one of:
- OpenShift CronJob definition showing a 15-minute schedule
- Application logs showing periodic task execution
- Application documentation describing the scheduling pattern

The Section 6 (OpenShift Investigation) correctly lists these as TODO investigations, which is good — but the architecture diagram in Section 4 should carry a caveat.

---

## 7. Other Observations

### 7.1 Internal Consistency of the Data Table

The data table in Section 1 is internally consistent:

- Non-spike windows: 2,692 - 3,567 RUs, 3-9% NormalizedRU, 0 429s
- Spike windows: 7,549 - 8,682 RUs, 100% NormalizedRU, 16-24 429s
- The ratio of spike/normal RUs (2.3x-2.8x) is consistent with a burst adding ~5,000 RUs on top of baseline ~3,000 RUs

The first spike shows only 16 429s vs 24 for subsequent spikes. This could indicate the burst ramps up slightly over iterations (the "2.3x → 2.8x" trend supports this) or that the first observation caught only part of the burst. Either way, it does not undermine the analysis.

### 7.2 The `metrics` Collection as Primary Suspect

The RCA flags `metrics` at 2,814 requests/hr as the "HOT" collection and "primary suspect." This is a reasonable inference from request volume, but request count alone does not determine RU consumption. A collection with fewer requests but expensive queries (scans, aggregations) could consume more RUs. Without per-collection RU breakdown (available via `TotalRequestUnits` metric with `CollectionName` dimension), calling `metrics` the "primary suspect" based solely on request count is an inference, not a fact.

### 7.3 "100 RU/s is almost never enough for production"

Section 8, Takeaway #1 states: "100 RU/s is the CosmosDB minimum — it's almost never enough for production workloads."

This is an OPINION, not a fact. 100 RU/s is fine for genuinely low-traffic collections (config stores, metadata lookups). The statement should be qualified: "100 RU/s is rarely sufficient for collections with bursty or moderate write workloads." Several collections in this account (keys, users, authorization) may be perfectly fine at 100 RU/s.

---

## Summary Verdict

**Grade: NEEDS WORK — Fix specific issues, but the core analysis is sound.**

The RCA demonstrates competent understanding of CosmosDB throttling mechanics, presents a clear causal chain supported by data, and provides reasonable remediation options. The author clearly ran real `az monitor metrics list` queries and built the analysis from actual data. That is good engineering.

**Corrections required (priority order)**:

1. **Label the architecture diagram as inferred/hypothesized**, not established fact. The periodic pattern is observed; the scheduler component is a hypothesis.
2. **Qualify the "500+ RU/s peak" claim** as an estimate or remove the specific number. You cannot derive sub-second peaks from 5-minute aggregate metrics.
3. **Qualify the `metrics` collection as "primary suspect" by request volume**, noting that RU consumption per collection was not measured (or add that data if available).
4. **Add missing remediation options**: server-side retry policy (verify MongoDB API support), alert threshold review.
5. **Qualify Takeaway #1** — 100 RU/s is not universally insufficient.
6. **Add a note about the 2-minute evaluation latency** between window end and alert fire time.

None of these invalidate the root cause conclusion. The throttling IS caused by periodic bursts exceeding the 100 RU/s provision. The analysis IS directionally correct. These are precision improvements, not fundamental errors.

Ship it after the corrections.
