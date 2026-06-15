---
task_id: 2026-06-15-001
agent: docs-librarian
status: complete
timestamp: 2026-06-15T16:26:17Z
summary: |
  External authoritative docs for the Gurobi-Cosmos NormalizedRUConsumption alert investigation.
  Microsoft Learn CONFIRMS NormalizedRUConsumption is the MAX of per-physical-partition (per
  partition-key-range) RU/s utilization in the interval, 0-100%, emitted at 1-min granularity —
  NOT an account-wide average. The route-flip is therefore RESOLVED: an account-level alert
  reading ~77% can fully hide a single hot partition that hit 100% and threw 429s, AND a value
  below 100% never guarantees no throttling. Microsoft publishes NO "75%" threshold; their
  guidance is the 100%/1-5%-429 framework — so 75% is a user-chosen advisory buffer (noise-leaning
  unless paired with a 429 check). Throttling is DIRECTLY evidenced only by TotalRequests filtered
  to StatusCode=429 (and TotalRequestUnits), not by NormalizedRUConsumption. Gurobi platform =
  bursty/scheduled batch-solve workload whose Cluster Manager database persists input models +
  output solutions + 30-day job history (write-heavy, hot-partition-prone). Eneco ADO wiki (C) is
  BLOCKED — librarian has no ADO authentication.
---

# External Authoritative Docs — Gurobi / Cosmos DB NormalizedRUConsumption

> Lane: external authoritative documentation only (Microsoft Learn for Azure; gurobi.com /
> docs.gurobi.com for Gurobi). All load-bearing claims carry an evidence label. `A1 FACT` =
> quoted from a live, clickable primary-source URL fetched this session.

## TL;DR for the RCA consumer

| Question | Answer | Label |
|----------|--------|-------|
| Is NormalizedRUConsumption a per-partition MAX (not an account average)? | **YES** — MAX of per-partition-key-range RU/s utilization across all partition key ranges in the interval. | A1 FACT |
| Can account-reported ~77% hide a 100% hot partition that threw 429s? | **YES** — the metric is already a max; a 5-min Average of per-minute maxes around 77% is consistent with one partition periodically hitting 100%. | A2 INFER (from A1) |
| Does NormalizedRUConsumption < 100% guarantee no throttling? | **NO** — Microsoft explicitly states a hot logical partition can throttle (429) while total/normalized consumption is below the provisioned ceiling. | A1 FACT |
| Is 75% a Microsoft number? | **NO** — Microsoft's published guidance is the 100% + 1-5%-429 framework; no 75% threshold appears. 75% is a user-chosen advisory buffer. | A1 FACT (absence in primary source) |
| Which metric DIRECTLY evidences throttling? | `TotalRequests` filtered to `StatusCode = 429` (a.k.a. "Throttled Requests"); supported by `TotalRequestUnits`. NormalizedRUConsumption is an indirect/utilization signal. | A1 FACT |

**Route impact (as posed in the dispatch):** Both branches of the conditional fire.
NormalizedRUConsumption IS per-partition-max → an account-level reading can hide a throttling
partition → the RCA MUST check 429s directly. AND a sub-100% (let alone 77%) value is advisory-only
for "no throttle" → leans the 75% alert toward **noise** unless corroborated by a real 429 rate.

---

## A) Azure Cosmos DB `NormalizedRUConsumption`

Namespace: `Microsoft.DocumentDB/databaseAccounts`. Metric display name "Normalized RU Consumption",
REST/`az` name `NormalizedRUConsumption`.

### A.1 — Exact definition: per-partition MAX, 0-100% [A1 FACT]

> "**Normalized RU Consumption** is a metric between 0% to 100% that's used to help measure the
> utilization of provisioned throughput on a database or container. The metric is emitted at
> **1-minute intervals** and is defined as the **maximum Request Units per second (RU/s) utilization
> across all partition key ranges in the time interval**. Each partition key range maps to one
> physical partition…"
>
> Worked example: container with autoscale max 20,000 RU/s, two partition key ranges P1 and P2 each
> scaling 1,000-10,000 RU/s. In a given second P1 consumes 6,000 RU (60%), P2 consumes 8,000 RU
> (80%). "**The overall normalized RU consumption of the entire container is MAX(60%, 80%) = 80%.**"

Source (A1): <https://learn.microsoft.com/azure/cosmos-db/monitor-normalized-request-units> (section "Metric definition").
Corroborated by the autoscale FAQ: "Normalized utilization is defined as the **maximum** of the RU/s
utilization across all physical partitions" — <https://learn.microsoft.com/azure/cosmos-db/autoscale-faq#what-happens-if-incoming-requests-exceed-the-maximum-ru-s-of-the-database-or-container>.

**Per-partition or per-account aggregated?** Mechanically it is **per-partition-key-range computed,
then reduced by MAX to a single value** that is reported at database/container scope. It is NOT a sum
or average across partitions. The metric is also filterable/splittable by the `PartitionKeyRangeID`
dimension to see each physical partition individually (Insights > Throughput >
"Normalized RU Consumption (%) By PartitionKeyRangeID"). [A1 FACT — same page, "View / Filters" and
"How to identify a hot partition" sections.]

### A.2 — What `timeAggregation = Average` over `PT15M` actually averages [A2 INFER, grounded in A1]

The raw metric stream is one value **per 1-minute interval** (`PT1M` time grain), and **each
1-minute datapoint is already a MAX across partition key ranges** (and within the minute, the max
over the per-second utilizations). [A1 FACT: 1-minute emission + max definition, page above.]

Therefore an account-level alert with `timeAggregation = Average` over a 15-minute window is
**averaging the already-maxed-per-minute partition ratios** — i.e., the mean of fifteen
"worst-partition-this-minute" numbers. [A2 INFER from the A1 definition.] Consequence: the Average
smooths over short single-minute spikes, so a 15-min Average of ~77% is fully consistent with one
partition briefly hitting 100% inside the window. Microsoft's own autoscale example shows exactly
this smoothing dynamic — a 1-second P1 spike drives Normalized RU to 100% for that interval while the
broader (5-second) scaling logic does not react. [A1 FACT:
<https://learn.microsoft.com/azure/cosmos-db/monitor-normalized-request-units#normalized-ru-consumption-and-autoscale>]

> Caveat (UNKNOWN, not blocking): how Azure Monitor rolls the PT1M max-stream into a PT15M Average
> (arithmetic mean of the 15 one-minute maxes) is the standard Azure Monitor aggregation behavior;
> the Cosmos page documents the PT1M max but does not restate the PT15M roll-up arithmetic. Treat the
> "mean of 15 per-minute maxes" reading as A2 INFER, not A1.

### A.3 — Relationship to HTTP 429: sub-100% does NOT guarantee no throttling [A1 FACT]

Two directions, both stated explicitly by Microsoft:

1. **100% does not necessarily mean 429s** (false-positive direction):
   > "It isn't always the case that you see a 429 rate-limiting error just because the normalized RU
   > reached 100%. That's because the **normalized RU is a single value that represents the maximum
   > usage over all partition key ranges. One partition key range might be busy but the other
   > partition key ranges can serve requests without issues.**"
   Source (A1): <https://learn.microsoft.com/azure/cosmos-db/monitor-normalized-request-units#what-to-expect-and-do-when-normalized-ru-s-is-higher>

2. **Below-ceiling consumption CAN still throttle a hot partition** (the route-flip / false-negative
   direction):
   > "When there's a hot partition, one or more logical partition keys on a physical partition are
   > consuming all the physical partition's Request Units per second (RU/s)… As a symptom, **the total
   > RU/s consumed are less than the overall provisioned RU/s** at the database or container. **You
   > could still see throttling (429 errors) on the requests against the hot logical partition key.**"
   Source (A1): <https://learn.microsoft.com/azure/cosmos-db/troubleshoot-request-time-out> (section "Hot partition key").

**Can one hot partition hit 100% (throttle) while the account average is ~77%? YES.** [A2 INFER from
the two A1 quotes above + the per-partition-max definition.] Mechanism: the per-minute metric is the
max of one busy partition. If that partition oscillates (e.g., 100% for some minutes, lower for
others, or the busy partition's per-second peak crosses 100% but the within-minute average is lower),
the 15-min Average lands below 100% (e.g., ~77%) even though that one partition was rate-limited in
specific seconds. The only authoritative confirmation of *actual* throttling is the 429 count
(see A.5), not NormalizedRUConsumption.

### A.4 — Microsoft's recommended threshold (is 75% Microsoft's number?) [A1 FACT]

**Microsoft does not publish a 75% threshold.** Across the primary metric guidance, the FAQ, and the
Well-Architected service guide, the stated framework is:

- "When the normalized RU consumption reaches **100%** for a given partition key range, and if a
  client still makes requests in that 1-second window to that partition key range, it receives a
  rate-limited error (429)." [A1]
- "for a production workload, if you see **between 1-5% of requests with 429s**, and your end-to-end
  latency is acceptable, this is a healthy sign… No further action is required." [A1]
- "If the normalized RU consumption metric is **consistently 100% across multiple partition key
  ranges and the rate of 429s is greater than 5%, it's recommended to increase the throughput.**" [A1]
  Source: <https://learn.microsoft.com/azure/cosmos-db/monitor-normalized-request-units#what-to-expect-and-do-when-normalized-ru-s-is-higher>
- Well-Architected guidance is only directional: "Create alerts for throughput throttling… Use
  alerts to track when this metric **exceeds expected thresholds**. Over time, review and adjust
  alerts as you learn more about your workload." (No numeric value given.) [A1]
  Source: <https://learn.microsoft.com/azure/well-architected/service-guides/cosmos-db#operational-excellence>

**Conclusion:** A 75% alert threshold is a **user-chosen advisory buffer**, not a Microsoft-prescribed
number. By Microsoft's own framework, 75% (well below 100%) on its own indicates headroom, not
throttling — it is a "getting warm" signal, noise-leaning unless joined to a 429 rate. [A2 INFER.]

**Autoscale vs manual — how computed / what it means:**
- The metric is "a metric between 0% to 100% that is used to help measure the utilization of the
  **autoscale max RU/s or manual provisioned throughput**" — same metric, both modes. [A1:
  <https://learn.microsoft.com/azure/cosmos-db/autoscale-faq#what-metric-should-be-used-to-determine-whether-the-autoscale-max-ru-s-or-manual-provisioned-ru-s-can-be-scaled-up-or-down-programatically>]
- Under **autoscale**, NormalizedRUConsumption is computed against the autoscale **max** RU/s, and
  Cosmos only scales to max when the metric is 100% sustained over a 5-second interval — so brief
  100% blips on the metric do NOT mean autoscale failed; conversely if you are autoscale and the
  metric sits at 100% while scaled to max with >1-5% 429s, manual may be more cost-effective. [A1:
  <https://learn.microsoft.com/azure/cosmos-db/monitor-normalized-request-units#normalized-ru-consumption-and-autoscale>]
- Under **manual**, the value is utilization vs the fixed provisioned RU/s; exceeding it throttles.
- Legacy-metric mapping confirms NormalizedRUConsumption ≡ legacy "Max RUMP (RUs Per Minute)". [A1:
  <https://learn.microsoft.com/azure/cosmos-db/legacy-migrate-az-monitor#what-is-the-azure-monitor-rest-api>]

### A.5 — Metrics that DIRECTLY evidence throttling (`az monitor metrics list`-usable) [A1 FACT]

From the supported-metrics reference for `Microsoft.DocumentDB/databaseAccounts`
(<https://learn.microsoft.com/azure/azure-monitor/reference/supported-metrics/microsoft-documentdb-databaseaccounts-metrics>)
and the Cosmos monitoring-data reference (<https://learn.microsoft.com/azure/cosmos-db/monitor-reference#metrics>):

| Metric (REST/`az` name) | Unit | Aggregations | Key dimensions | Use for throttling |
|--------------------------|------|--------------|----------------|--------------------|
| `TotalRequests` | Count | Count | `DatabaseName`, `CollectionName`, `Region`, **`StatusCode`**, `OperationType`, `Status`, `CapacityType` | **PRIMARY.** Filter `StatusCode == 429` = throttled-request count. Legacy "Throttled Requests" maps here. |
| `TotalRequestUnits` | Count | Total(Sum), Average, Maximum | `DatabaseName`, `CollectionName`, `Region`, **`StatusCode`**, `OperationType`, `Status`, `CapacityType` | RU consumed; can split by `StatusCode` to isolate RU spent on 429 attempts. |
| `PhysicalPartitionThroughputInfo` | Count | Maximum | `CollectionName`, `DatabaseName`, **`PhysicalPartitionId`**, `Region` | RU/s assigned per physical partition — pair with per-partition NormalizedRU to find the hot one. |
| `AutoscaledRU` | Count | Maximum | `DatabaseName`, `CollectionName`, **`PhysicalPartitionId`**, `Region` | Per-partition autoscaled RU (dynamic autoscale accounts). |

- "Total Requests" legacy mapping: "Throttled Requests → `TotalRequests` (Filter by status code)". [A1:
  legacy-migrate page above.]
- The NormalizedRU page itself directs you to filter Total Requests by 429 and split by Operation
  Type for throttling visibility. [A1: monitor-normalized-request-units, "Metric definition" tail.]

**Exact `az` shape (constructed from the A1 metric/dimension names — verify on the live account):**

```bash
# Direct throttling evidence: count of 429s in the window
az monitor metrics list \
  --resource "<cosmos-account-resource-id>" \
  --metric TotalRequests \
  --filter "StatusCode eq '429'" \
  --aggregation Count \
  --interval PT1M \
  --start-time <ISO8601> --end-time <ISO8601>

# Per-physical-partition utilization to find the hot partition (split, not filter)
az monitor metrics list \
  --resource "<cosmos-account-resource-id>" \
  --metric NormalizedRUConsumption \
  --aggregation Maximum \
  --interval PT1M \
  --filter "PartitionKeyRangeID eq '*'"
```

> Label note: metric/dimension/aggregation NAMES are A1 (quoted from the supported-metrics tables).
> The exact `az` invocation syntax (flag spelling, `--filter` dimension support for these specific
> dimensions on this account) is A2 INFER — the live `az monitor metrics list --help` and a probe
> against the actual account are the resolving check. Note `PartitionKeyRangeID` filtering is
> documented in the portal Insights split; whether `az --filter` accepts it for this metric should
> be probed before relying on it.

---

## B) Gurobi — what it is and why a "Gurobi platform" needs a Cosmos DB

### B.1 — What Gurobi is [A1 FACT]

Gurobi is a commercial **mathematical-programming (optimization) solver** — you express a business
problem as a math model (LP/MIP/QP etc.) and Gurobi returns the provably optimal solution. It follows
a "model-and-solve" paradigm. Source: <https://www.gurobi.com/solutions/gurobi-optimizer/>.

### B.2 — Platform topology (license/token server, compute servers, cluster manager) [A1 FACT]

A Gurobi *platform* (Remote Services / Compute Server) is a client-server system with three layers:

- **License / token server** — floating-license token issuance (`grb_ts`); a long-running user
  process that hands out and reclaims tokens as solver environments are created/disposed.
  Source: <https://www.gurobi.com/documentation/current/quickstart_mac/sta_a_token_server.html>
- **Compute Server nodes** — where solves actually execute. Built-in **job queue + load balancing**;
  each node has a simultaneous-job limit, excess jobs are queued (FIFO with configurable -100..100
  priorities), and node groups route jobs to suitable hardware. Fault-tolerant: if a node fails, new
  jobs dispatch elsewhere. Source: <https://docs.gurobi.com/projects/remoteservices/en/current/content/overview/architecture.html>
- **Cluster Manager (optional control plane) + its Database** — security/auth (accounts, API keys),
  monitoring, REST API, Web UI, and **Batch Management**. Source:
  <https://docs.gurobi.com/projects/remoteservices/en/current/content/cluster-manager.html>

### B.3 — Why it needs a database / Cosmos-DB-shaped persistence + workload shape [A1 FACT]

> "The database supports the Cluster Manager. It stores… data with long lifespans, like user
> accounts, API keys, **history information for jobs and batches**, and data with **shorter
> lifespans, like input models and their solutions for batch optimization**."
> Source: <https://docs.gurobi.com/projects/remoteservices/en/current/content/overview/architecture.html>

Batch lifecycle (the persistence-heavy path):
> "The client uploads a batch specification… containing the input data… When the job later runs, it
> retrieves the relevant data from the Cluster Manager, performs the optimization, and **stores
> optimization results back to the Cluster Manager.** A client can then retrieve the results."
> Solutions are exported as JSON documents. Completed jobs are retained for a **configurable period,
> default 30 days**; batch data can be explicitly discarded to reclaim storage.
> Source: <https://docs.gurobi.com/projects/remoteservices/en/current/content/overview/architecture.html>

**Workload shape inference for the RCA [A2 INFER, grounded in B.3 A1 facts]:**

- The DB is **write-heavy on the batch path**: every batch solve writes an input model in, then
  writes a solution document back out, then retains job/batch metadata. Reads come on result
  retrieval and history/monitoring queries.
- The workload is **bursty / scheduled**, not steady: optimization platforms (and a VPP
  FleetOptimizer specifically — see C) typically fire solves on a cadence (e.g., per market interval
  / per planning cycle) or on demand, producing spikes of concurrent batch submissions rather than a
  flat request rate. The queue+priority design exists precisely because submission bursts exceed
  instantaneous solve capacity.
- **Hot-partition risk is plausible**: if the backing Cosmos container partitions job/batch records
  by something low-cardinality or time-clustered (e.g., a date, a single tenant/cluster id, or a
  monotonic batch id), a burst of writes can concentrate on one physical partition → that partition
  hits 100% NormalizedRU and throws 429s while the account-level average stays moderate. This is the
  exact mechanism Microsoft's "hot partition" docs describe (A.3) and is consistent with the
  reported ~77% account-average alert. **(This is A2 INFER about partitioning; the actual Cosmos
  partition-key design for the Eneco Gurobi/FleetOptimizer container is UNVERIFIED — see C and the
  internal IaC/code lanes.)**

---

## C) Eneco ADO wiki (Myriad - VPP) on Gurobi / FleetOptimizer — BLOCKED

**Status: A3 UNVERIFIED[blocked: librarian lane has no Azure DevOps authentication].**

Probe result: `https://dev.azure.com/enecomanagedcloud/_search?text=Gurobi%20FleetOptimizer`
returned **HTTP 302 → `spsprodweu2.vssps.visualstudio.com/_signin`** (Microsoft Entra sign-in).
WebFetch cannot authenticate against private ADO; the redirect goes to an interactive login realm.
Confirmed this session (the redirect target is an MSAL/VSSPS `_signin` URL).

**Resolving path (for a tooled agent / authenticated session):** dispatch the `eneco-context-docs`
skill (Myriad VPP ADO wiki + ADRs) and/or `eneco-context-repos` (FleetOptimizer source + the Cosmos
IaC for the Gurobi platform) under an authenticated Azure CLI session. Specifically wanted:
(1) the FleetOptimizer/Gurobi platform's Cosmos container **partition key** design, (2) the solve
**cadence/schedule** (market interval vs on-demand), and (3) whether the alerting threshold (75%) was
deliberately chosen or inherited from a CCoE/golden-path default. Those three resolve the
noise-vs-real determination internally; this external-docs lane cannot reach them.

---

## Evidence ledger (primary-source URLs, all A1 fetched 2026-06-15)

| # | Claim supported | URL |
|---|-----------------|-----|
| 1 | NormalizedRU = MAX per partition-key-range, 0-100%, 1-min, worked example | <https://learn.microsoft.com/azure/cosmos-db/monitor-normalized-request-units> |
| 2 | 100% on metric ≠ guaranteed 429; max-over-partitions framing; 1-5% 429 healthy; >5% act | <https://learn.microsoft.com/azure/cosmos-db/monitor-normalized-request-units#what-to-expect-and-do-when-normalized-ru-s-is-higher> |
| 3 | Autoscale: brief 100% blips don't force scale-to-max; 5-sec sustained logic | <https://learn.microsoft.com/azure/cosmos-db/monitor-normalized-request-units#normalized-ru-consumption-and-autoscale> |
| 4 | Normalized utilization = MAX across physical partitions (FAQ restatement) | <https://learn.microsoft.com/azure/cosmos-db/autoscale-faq#what-happens-if-incoming-requests-exceed-the-maximum-ru-s-of-the-database-or-container> |
| 5 | Hot partition throttles (429) while total RU/s < provisioned | <https://learn.microsoft.com/azure/cosmos-db/troubleshoot-request-time-out> |
| 6 | Well-Architected: alert on "exceeds expected thresholds" (no numeric value) | <https://learn.microsoft.com/azure/well-architected/service-guides/cosmos-db#operational-excellence> |
| 7 | Supported metrics: TotalRequests/TotalRequestUnits names, StatusCode dimension | <https://learn.microsoft.com/azure/azure-monitor/reference/supported-metrics/microsoft-documentdb-databaseaccounts-metrics> |
| 8 | Cosmos monitoring data reference (metric tables, PhysicalPartitionThroughput, PartitionKeyRangeID) | <https://learn.microsoft.com/azure/cosmos-db/monitor-reference#metrics> |
| 9 | Legacy mapping: Throttled Requests → TotalRequests filter; Max RUMP → NormalizedRUConsumption | <https://learn.microsoft.com/azure/cosmos-db/legacy-migrate-az-monitor#what-is-the-azure-monitor-rest-api> |
| 10 | What Gurobi is (math programming solver) | <https://www.gurobi.com/solutions/gurobi-optimizer/> |
| 11 | Token / license server (grb_ts) | <https://www.gurobi.com/documentation/current/quickstart_mac/sta_a_token_server.html> |
| 12 | Remote Services architecture: compute nodes, queue, cluster manager, DB, batch persistence, 30-day retention | <https://docs.gurobi.com/projects/remoteservices/en/current/content/overview/architecture.html> |
| 13 | Cluster Manager responsibilities (batch mgmt, storage of input models + solutions) | <https://docs.gurobi.com/projects/remoteservices/en/current/content/cluster-manager.html> |

## Negative information / what is conspicuously absent

- **No Microsoft "75%" or "80%" recommended alert value exists** in primary docs — only the 100% +
  1-5%/>5% 429 framework. Any fixed sub-100% threshold is operator-chosen. (Already load-bearing in A.4.)
- **Microsoft does not document the PT15M Average roll-up arithmetic on the Cosmos page** — the
  "mean of 15 per-minute maxes" reading is INFER from standard Azure Monitor behavior, not stated.
- **The Eneco Cosmos partition-key design and solve cadence are not externally documented** — they
  are the decisive internal facts and live behind ADO auth (C, blocked).
