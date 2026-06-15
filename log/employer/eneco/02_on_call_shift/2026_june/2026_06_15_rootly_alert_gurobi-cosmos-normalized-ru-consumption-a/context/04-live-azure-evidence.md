---
title: "Live Azure evidence capture — gurobi cosmos RU (2026-06-15)"
description: "Raw az/ARM outputs captured during the investigation, for citation and adversarial review"
timestamp: 2026-06-15T17:05:00Z
status: complete
agent: coordinator
summary: >-
  Verbatim captured outputs of the live az probes (control-plane, acc SP): NormalizedRU per-minute,
  429 + Mongo-16500 counts, fs.chunks throughput, alert rule def, fired instances, 7-day recurrence,
  account config, IaC git log. All A1.
task_id: 2026-06-15-001
---

# Live Azure Evidence Capture (A1)

All captured 2026-06-15 via `az` against sub `b524d084-edf5-449d-8e92-999ebbaf485e` (acc SP, control-plane reads). Account logged out afterward (`enecotflogout`). `RID = /subscriptions/b524d084-.../resourceGroups/rg-gurobi-platform-a/providers/Microsoft.DocumentDB/databaseAccounts/cosmosdb-gurobi-platform-a`.

## E1 — NormalizedRUConsumption per minute (Max == Avg; single series)

```text
15:17 17 | 15:18 17 | 15:24 7 | 15:26 3
15:27 100 | 15:28 100 | 15:29 76 | 15:30 9 | 15:31 10
15:32 100 | 15:33 100 | 15:34 100 | 15:35 100 | 15:36 100 | 15:37 100 | 15:38 100
15:39 76 | 15:40 75 | 15:41 19 | 15:42 10 | 15:44 23 | ...baseline ~5-9
```

Window 15:26:47–15:41:47 → **PT15M average = 77.67%** (matches alert `metricValue`). Max≡Avg per minute ⇒ effectively one series (consistent with the unsharded single-partition `fs.chunks`).

## E2 — Direct throttling (the load-bearing check)

`TotalRequests` `StatusCode=429`, Total, PT1M: **586 total** → 15:31=85, 15:32=181, 15:34=57, 15:35=145, 15:37=118.

`MongoRequests` `ErrorCode=16500`, Total, PT1M: **~16,555 total** → 15:28=1505, 15:32=4515, 15:34=3010, 15:35=3010, 15:36=1505, 15:37=1505, 15:38=1505.

`MongoRequests` total in PT15M window = **47,953**; throttled (16500) = **16,555** ⇒ **34.5%** of Mongo ops throttled.

## E3 — fs.chunks throughput (the ceiling)

```json
{ "throughput": 100, "autoscaleMaxRU": 1000, "minimumRU": "1000", "instantMax": "10000" }
```

⇒ **autoscale, max 1000 RU/s.** `collection show` → `shardKey: null` (unsharded), indexes `_id` + `(files_id,n)` (standard GridFS).

All 12 collections (`registry, batches, settings, trash, metrics, fs.files, objects, fs.chunks, keys, users, authorization, jobhistory`) reported the same `autoscaleMax 1000`.

## E4 — Alert rule (live, matches IaC)

```json
{ "name":"gurobi-cosmos-normalized-ru-consumption-a", "enabled":true, "severity":2,
  "autoMitigate":true, "windowSize":"PT15M", "evalFreq":"PT5M",
  "criteria":{ "metricName":"NormalizedRUConsumption","operator":"GreaterThan",
               "threshold":75.0,"timeAggregation":"Average" }, "tags":{} }
```

## E5 — Fired instances on the resource, last 1 day

Only `gurobi-cosmos-normalized-ru-consumption-a` (Sev2, fired 15:44:03Z, now **Resolved**). No 429/latency alert fired (no 429 alert rule exists — see E8).

## E6 — All metric-alert rules in rg-gurobi-platform-a

`gurobi-cosmos-latency-a` (ServerSideLatency>99, PT5M) · `gurobi-cosmos-normalized-ru-consumption-a` (NormalizedRU>75, PT15M) · `kv-gurobi-platform-a-kv-latency-above-1000ms` · `kv-...-availability-below-100` · 7× token-server VM alerts. **No `*throttling*` / 429 rule present.**

## E7 — 7-day recurrence (NormalizedRU PT1H Max ≥ 90%)

```text
Jun08 07,11 | Jun09 09,10,14 | Jun10 10,(14=93),15,16 | Jun11 09,10 | Jun12 08 | Jun15 09,13,14,15  (all 100%)
```

⇒ 100% bursts are a multiple-times-daily routine. Only today's was sustained enough to push the PT15M average > 75%.

## E8 — Account config

```json
{ "kind":"MongoDB","mongoVersion":"7.0","capabilities":["EnableMongo"],
  "consistency":"Eventual","publicNetworkAccess":"Disabled","ipRules":[],"vnetFilter":false,
  "automaticFailover":false,"multiWrite":false,"backup":"Periodic","freeTier":false,
  "locations":["West Europe"],"provisioningState":"Succeeded" }
```

## E9 — Activity log (config changes since 2026-05-15)

**Empty.** No throughput/account write operations ⇒ no capacity regression; the change was the alert sensor, not the DB.

## E10 — IaC git log `gurobi-infrastructure` 3b2530b(2026-01-27) .. c17995a(2026-06-05)

```text
f956e9b fix: Update Cosmos DB alert for normalized RU consumption and remove throttling alert
d7fc972 Merged PR 176135: fix: Adjust window size for normalized RU consumption alert to 15 minutes
0bd2787 fix: Correct metric name for Cosmos DB normalized RU consumption alert
6fa7eec fix: Correct formatting in the description of the normalized RU consumption alert
e056227 fix: Improve readability of the Cosmos DB normalized RU consumption alert description
```

⇒ the team **removed the 429 alert** and **added** the NormalizedRU>75%/PT15M alert.

## E11 — Per-collection NormalizedRU PT1M Max (15:26–15:41) — names the saturator (A1)

```text
fs.chunks   100.0     <-- THE saturator
objects      16.0
Metrics       6.0
trash         5.0   keys 4.0   jobhistory 4.0   fs.files 4.0
registry      3.0   users 2.0  batches 2.0
```

⇒ `fs.chunks` is the sole hot collection (next is `objects` at 16%). No co-saturator. fs.chunks attribution is **A1** (per-collection split), not inference.

## E12 — TotalRequestUnits (RU served/min) on fs.chunks — burst shape (A1)

```text
15:28 1005 | 15:31 3220 | 15:32 3277 | 15:34 1718 | 15:35 3292 | 15:38 1000 | 15:39 1000
(all other minutes < 150 RU)
```

Peak minute ≈ **3,292 RU/min ≈ 55 RU/s average**. A sustained 1000 RU/s would be ~60,000 RU/min — actual is ~5% of that. ⇒ **brief sub-minute spikes to the 1000 RU/s ceiling, not sustained saturation** (micro-burst pattern). The per-minute NormalizedRU Max = 100% reflects 1-second peaks, not a full-minute wall.

## E13 — True HTTP-429 rate (the metric Microsoft's framework uses) (A1)

```text
TotalRequests ALL status (15:26–15:41) = 20,792
TotalRequests StatusCode=429           =    586   ->  586/20792 = 2.82%
```

⇒ **HTTP-429 rate = 2.82%** — INSIDE Microsoft's 1–5% "healthy / no action required" band. The earlier 34.5% (16,555 Mongo-16500 ÷ 47,953 MongoRequests) is the **Mongo-protocol-layer** count, inflated by driver retries (≤9× per logical op, A1 MS Learn) — NOT the action metric.

## E14 — fs.chunks storage size (A1)

```text
DataUsage max ≈ 5,345,509,376 bytes ≈ 5.1 GB
```

⇒ well under the ~50 GB physical-partition split threshold → **single physical partition at current size** (the qualifier matters: it can split if it grows).
