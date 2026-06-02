---
task_id: 2026-04-21-001
agent: claude-code
status: complete
summary: Microsoft Learn citations for Azure Cache for Redis metric semantics and tier memory caps. Anchors the structural argument that absolute-bytes UsedMemory should be retired in favor of UsedMemoryPercentage.
---

# Microsoft Learn — Azure Cache for Redis metrics

## Fact 1 — `cacheLatency` measures **internode** latency, in microseconds

Source: [Azure Cache for Redis monitoring data reference](https://learn.microsoft.com/azure/azure-cache-for-redis/monitor-cache-reference#azure-cache-for-redis-metrics)

> "Cache Latency (preview). The latency of the cache calculated using the internode latency of the cache. This metric is measured in microseconds, and has three dimensions: Avg, Min, and Max."

Implications for this fix:

- The 15 000 µs (15 ms) threshold in the module default is an **internode** latency check, not a client-perceived RTT. It signals replica-sync health.
- The metric is **Preview** — its sampling and stability characteristics are not fully GA-guaranteed. Higher sensitivity to transient spikes is plausible.
- The metric is shown in the supported-metrics table as: `cacheLatency` | Count | Average | dimension `ShardId` | PT1M time grain. Aggregation = Average. Sampling once per minute over a 15-minute lookback (the module's default `frequency = "PT1M", window_size = "PT15M"`) means a single 30-second spike to 30k µs translates roughly to a 1k µs shift in the windowed average — but a sustained 5-minute episode at 20k µs will cross the 15k threshold and fire.

## Fact 2 — Microsoft **recommends** Used Memory Percentage over raw Used Memory

Source: [Memory management for Azure Managed Redis](https://learn.microsoft.com/azure/redis/best-practices-memory-management#monitor-memory-usage)

> "We recommend monitoring the Used Memory Percentage metric rather than raw Used Memory. The percentage metric already accounts for your SKU's total memory limit, including High Availability replication, so it gives you a straightforward view of how close you are to capacity without needing to mentally adjust for replica memory."

> "Add alerting on Used Memory Percentage to ensure that you don't run out of memory and have the chance to scale your cache before seeing issues. If your Used Memory Percentage is consistently over 75%, consider increasing your memory by scaling to a higher tier."

This page is for Azure Managed Redis but the same metric and design rationale apply to the classic Azure Cache for Redis SKUs in scope here. Authoritative endorsement of the structural recommendation: keep `AllUsedMemoryPercentage`, retire `UsedMemory`.

## Fact 3 — Tier memory caps

Source: [What is Azure Cache for Redis? — Service tiers — Memory](https://learn.microsoft.com/azure/azure-cache-for-redis/cache-overview#service-tiers)

> "The Basic and Standard tiers offer 250 MB – 53 GB; the Premium tier 6 GB - 1.2 TB."

Specific capacity values (cross-checked against the [pricing page](https://azure.microsoft.com/pricing/details/cache/) and the standard Azure Cache C-tier / P-tier ladder):

| Capacity setting | Standard SKU | Premium SKU |
|---|---|---|
| `0` | C0 = 250 MB | n/a |
| `1` | C1 = 1 GB | **P1 = 6 GB** ← acc, prd |
| `2` | **C2 = 2.5 GB** ← dev | P2 = 13 GB |
| `3` | C3 = 6 GB | P3 = 26 GB |
| `4` | C4 = 13 GB | P4 = 53 GB |

Threshold-vs-capacity table for the brittle absolute-bytes UsedMemory alert (200 000 000 B ≈ 190.7 MiB):

| Env | SKU + capacity | Cache size | 200 MB threshold = % of capacity | Trips when cache holds … |
|-----|----------------|-----------|----------------------------------|--------------------------|
| dev | Standard C2 | 2.5 GB | **8 %** | > 200 MB |
| acc | Premium P1 | 6 GB | **3.3 %** | > 200 MB |
| prd | Premium P1 | 6 GB | **3.3 %** | > 200 MB |

The threshold trips before the percentage-based alert is anywhere near concerning capacity — confirms the absolute-bytes alert is structurally redundant (and brittle) on every env.

## Fact 4 — `serverLoad` is also tier-relative

Out of immediate scope (Stefan didn't flag it) but worth noting for any follow-up:

> "Server Load. The percentage of cycles in which the Redis server is busy processing and not waiting idle for messages." — same monitor-cache-reference page.

The default `all_server_load` threshold of 75 is fine because it's a percentage, like `all_used_memory_percentage`. Premium has more headroom because it's not single-threaded for I/O on the same vCPU as command processing.

## What I did NOT confirm (residual UNVERIFIED)

- `[UNVERIFIED[unknown: whether MS publishes a recommended *threshold value* for cacheLatency on Standard vs Premium]]`. Searched, no such guidance found. The 15 ms default in the module is the module author's choice, not an MS recommendation. The fix doc proposes a Standard-tier value based on observed behavior (Apr 13–20 band 7k–17k µs in `image (3).png`) plus operator judgment. This is not anchorable to first-party docs.
- `[UNVERIFIED[unknown: whether `cacheLatency` Preview status implies measurement instability]]`. The "(preview)" annotation in MS Learn is a feature-stability annotation, not necessarily a data-quality one. Treated as informational only.
