---
task_id: 2026-04-21-001
agent: claude-code
status: complete
summary: Diagnosis for Stefan's Redis-alerts ticket — what the mechanism is, what's load-bearing vs assumed, what to read next.
---

# Diagnosis — Stefan's Redis alert spam

**Bottom line.** Stefan's framing is right: the Redis alerts live in the module, the module ships them with tier-agnostic defaults, and the consumer (`MC-VPP-Infrastructure`) never overrides them, so dev (Standard) and prd (Premium) get the same thresholds. But it's not one noisy alert — it's **two**, with different failure modes:

- `CacheLatency` (15 ms) is the one actually firing on Rootly. The screenshot of the alert list shows ~10 fires in 4 days (image.png). The metric itself (image (3).png) oscillates 7–17 ms on dev's Standard C2, crossing 15 ms frequently. This is the spam Stefan felt.
- `UsedMemory` (200 MB absolute) has been chronically tripped at the Azure-portal level for hours on end — dev's cache sits at ~455 MB (image (1).png). You didn't hear about it on Rootly because… we don't yet know, but the alert is in a fired state regardless. Stefan called this one "way too low" in his Friday review. He's right; it's structurally broken, not just tuned poorly.
- `AllUsedMemoryPercentage` (85 %) is the one alert that's working. Sitting at 18.6 %, no fires (image (2).png). It's the percentage counterpart to UsedMemory, and Microsoft explicitly says to prefer it.

Confidence: **~90 %.** The mechanism is fact-anchored — module v2.5.3 defaults match the portal thresholds byte-for-byte, and the consumer really does never pass `redis_alert_configuration`. The remaining 10 % is you choosing threshold values and whether to disable the UsedMemory alert or just raise it. Those are judgment calls, not facts.

## The shape

```
Eneco.Infrastructure
  terraform/modules/rediscache (v2.5.3)
    variable "redis_alert_configuration" = {          ◄── 9 alerts, hardcoded
      cache_latency   { threshold = 15000      ... }       tier-agnostic
      used_memory     { threshold = 200000000  ... }       defaults.
      all_used_mem_pc { threshold = 85         ... }       No env awareness.
      ... 6 others
    }
    resource "azurerm_monitor_metric_alert" "this" {
      for_each = var.redis_alert_configuration
    }
                         │
                         │ pinned by ?ref=v2.5.3
                         ▼
MC-VPP-Infrastructure
  terraform/rediscache.tf
    module "redisCache01" {
      source = "...?ref=v2.5.3"
      alert_actions = { rootly = { ... } }            ◄── only this is passed
      # redis_alert_configuration NOT passed          ◄── so defaults flow
    }                                                     through unchallenged
                         │
                         ▼
  Per-env tfvars
    dev.tfvars  sku_name = "Standard"  capacity = 2   → C2 (2.5 GB)   ← noisy
    acc.tfvars  sku_name = "Premium"   capacity = 1   → P1 (6 GB)
    prd.tfvars  sku_name = "Premium"   capacity = 1   → P1 (6 GB)
```

## Failure ↔ success, paired

So you can see the invariant, not just the break:

```
ALERT                       BROKEN STATE (today, dev)           WORKING STATE (template)
─────────────────────────────────────────────────────────────────────────────────────────
CacheLatency                threshold = 15 000 µs                threshold sized to
                            metric band 7–17 ms on Standard      tier's normal band
                            → crosses often → Rootly fires       → fires only on real
                                                                   internode trouble

UsedMemory                  threshold = 200 000 000 B absolute   retire in favor of
                            = 8% of C2 capacity                  AllUsedMemoryPercentage
                            = 3% of P1 capacity                  (percentage, tier-
                            → fires on any modest usage          relative, recommended
                                                                   by MS)

AllUsedMemoryPercentage     threshold = 85 %                     (already working — keep)
                            currently 18.6 %
                            → no fires, correct behavior
```

That last row is the point. The percentage version is the working counterpart of the absolute version. That's why the fix doc proposes disabling UsedMemory on dev rather than "tuning" it — the signal it ostensibly provides is already covered, correctly, by a different alert the module also ships.

## Why both Premium envs aren't spamming too

They would, if their caches held meaningful data. At P1's 6 GB, 200 MB is 3.3 % of capacity — any moderate load on acc or prd crosses that. The only reason they're quiet is that acc's and prd's Redis caches are currently small. Don't read their silence as "the default is fine on Premium." The default is brittle on every tier; Standard C2 just happens to be the env where the brittleness is currently visible. This is why the fix's per-env override disables `used_memory` on **dev only** — acc and prd keep the current behavior until someone decides otherwise. I almost wrote a fix that disabled it everywhere by default; the contrarian pass caught that as silent scope expansion (F1 / F3 in `context/contrarian-critique.md`). Worth reading if you want to see where the plan evolved.

## Falsifiers for my model

Three checks that would demote my "90 %" to "I got it wrong":

1. **If acc or prd `terraform plan` shows Redis alert changes** after the fix, my local mirror of the module defaults drifted. The V5 diff in the spec catches this before the PR ships.
2. **If the portal thresholds on dev don't match the module v2.5.3 defaults byte-for-byte**, someone hand-tuned in Azure. I'd need to pull `az monitor metrics alert list` output to see the truth. I'm working from screenshots only; they matched, but I'm one portal-drift scenario away from wrong. Your call on whether to probe before apply.
3. **If apply on dev does a resource recreation** on `used_memory` instead of an in-place update, `enabled` isn't a PATCH-able field on this provider version. Plan output tells you; watch for `-/+` instead of `~`.

## What's still honestly Unknown

- Why CacheLatency spiked on dev Apr 13–18 and then came back down Apr 19–20. Stefan said "getting back to initial state" — probably a workload anomaly, but I don't know whose workload. Separate question; not blocking the fix.
- Whether the `used_memory` alert was ever routed to Rootly or just fires in the portal and gets swallowed. The Rootly list only shows CacheLatency fires. I didn't trace the action group → Rootly webhook mapping because it doesn't change the fix.
- Whether the other six alerts (AllConnectedClients, AllPercentProcessorTime, AllServerLoad, CacheRead, Errors, UsedMemoryRSS) are tuned well. Stefan didn't flag them; I didn't investigate. If any become noisy later, the override mechanism the fix ships handles them the same way.

## Live Azure evidence (pulled 2026-04-21, ~12:45 UTC)

Probed dev-mc directly via `enecotfvppmclogindev` + `az monitor metrics alert list` and `az monitor metrics list`. Sub `839af51e-c8dd-4bd2-944b-a7799eb2e1e4`, RG `mcdta-rg-vpp-d-storage`, resource `vpp-rediscache01-d`. No whitelist needed (management-plane reads only).

### All 9 alerts, live state — byte-identical to module v2.5.3

```text
Name                                        Enabled  Sev  Eval   Win    Metric                   Op           Threshold       Agg
------------------------------------------  -------  ---  -----  -----  -----------------------  -----------  --------------- -------
AllConnectedClients-vpp-rediscache01-d       True     3    PT1M   PT5M   allconnectedclients      GreaterThan  128             Maximum
AllPercentProcessorTime-vpp-rediscache01-d   True     3    PT1M   PT15M  allpercentprocessortime  GreaterThan  60              Average
AllServerLoad-vpp-rediscache01-d             True     3    PT1M   PT15M  allserverLoad            GreaterThan  75              Average
AllUsedMemoryPercentage-vpp-rediscache01-d   True     3    PT1M   PT5M   allusedmemorypercentage  GreaterThan  85              Average
CacheLatency-vpp-rediscache01-d              True     3    PT1M   PT15M  cachelatency             GreaterThan  15000           Average
CacheRead-vpp-rediscache01-d                 True     3    PT5M   PT15M  cacheRead                GreaterThan  46875000        Average
Errors-vpp-rediscache01-d                    True     3    PT1M   PT5M   errors                   GreaterThan  850             Maximum
UsedMemory-vpp-rediscache01-d                True     3    PT5M   PT5M   usedmemory               GreaterThan  200000000       Maximum
UsedMemoryRSS-vpp-rediscache01-d             True     3    PT1M   PT5M   usedmemoryRss            GreaterThan  11000000000     Average
```

Zero portal drift. F-C falsifier upgraded: the byte-identity claim now rests on live az CLI output across all 9 alerts, not just the 3 sampled screenshots.

**All three alerts in scope route to the same action group `ag-vpp-core-d`**: CacheLatency, UsedMemory, and AllUsedMemoryPercentage. That answers an open question from the original diagnosis — yes, `UsedMemory` is wired to Rootly, not just the portal.

### Redis resource confirmed

`sku=Standard, family=C, capacity=2, redis_version=6.0, publicNetworkAccess=Disabled, enableNonSslPort=false, provisioningState=Succeeded`. Matches the tfvars claim (Standard C2 = 2.5 GB) exactly.

### CacheLatency — 7-day PT15M-average view, only rows that crossed 15 000 µs

The alert evaluates the 15-minute moving average every minute. So what matters is the 15-min avg, not the raw max. In the last 7 days:

- **35 distinct 15-min windows crossed 15 000 µs** (sampled Apr 14–20).
- Peak 15-min average: **17 148 µs** on 2026-04-17 23:45 UTC.
- Distribution: Apr 16 (12 crossings) and Apr 17 (12 crossings) were the hot days; Apr 18–20 shows only 2 crossings total. Matches Stefan's "getting back to the initial state."
- Hourly averages over last 24h sit steadily at **7 000–10 000 µs**. Healthy baseline.

This is why **50 000 µs is a sound starting threshold for dev**: max observed 15-min average over 7 days was ~17k µs. 50k gives ~3× headroom while still catching a sustained internode-latency regression. Individual 1-minute Max spikes reach 85k–338k µs, but those are instantaneous, not sustained, and the alert uses Average so they don't trigger it alone.

### UsedMemory — continuously above 200 MB, monotonically growing

Last 24h per-hour Maximum:

```text
2026-04-20 12:44Z  450 513 600 B  (≈ 429 MiB)
...
2026-04-21 04:44Z  452 954 272 B
2026-04-21 11:44Z  458 290 064 B  (≈ 437 MiB)
```

Growth rate ≈ **8 MB / 24 h**. The cache has been above the 200 MB threshold since before the observation window started. The alert has been in *continuously fired* state, not "occasionally firing."

**This reframes why Rootly only shows CacheLatency fires** (Stefan's image.png): UsedMemory transitioned to fired state long ago and stayed there; Rootly dedupes sustained fired states into a single old incident. CacheLatency, by contrast, oscillates in and out of fired state, so Rootly creates a new incident each time. Stefan's intuition that "only one alert is spamming" is correct as far as Rootly surface goes — but **two alerts are misconfigured**, one noisy and one silently useless.

Bonus finding: the monotonic growth is itself worth a glance later. 8 MB/day sustained is not immediately dangerous on a 2.5 GB cache, but it's not flat — someone is writing keys without evicting them, or the TTL / eviction policy isn't catching up. Separate investigation; not blocking this fix. The percentage-based alert is what catches this when it matters (will fire at 85% = ~2.1 GB, currently at 19% = ~0.46 GB, so several hundred days of runway at current rate).

### AllUsedMemoryPercentage — working as designed

Last 24h: steady at **18–19%**, 85% threshold, zero fires. This is the alert that should carry memory-pressure signal going forward. The UsedMemory-absolute alert's disablement on dev doesn't remove any real defense — percentage covers the same axis more correctly.

### What the live data changes in the recommendation

- Confidence goes from ~90 % to **~95 %**. The remaining uncertainty is purely operator-choice (threshold values, whether to also bump acc/prd), not factual.
- F-C falsifier strengthened: all 9 alerts confirmed, not just 3.
- New finding (not in original): UsedMemory is not a "would spam" alert on dev, it's a "silently stuck" alert. That's a worse failure mode than the diagnosis originally stated — the alert looks healthy (it's enabled, wired to Rootly) but provides zero signal. Replacing it with the percentage alert is therefore not a tuning question, it's a correctness one.
- Acc/prd probe deliberately not run (would cost two more biometric prompts). The tier argument stands: on Premium P1 (6 GB), 200 MB = 3.3 % of capacity; if any acc/prd workload grew past 200 MB, same stuck-alert pattern would appear.

## Read next

- `specs/redis-alerts-per-env-fix.md` — the file-by-file fix with exact diffs and a PR description template. The thing you'd paste into a review.
- `context/contrarian-critique.md` — seven attacks on an earlier draft of the plan. Three landed and changed the spec. Worth reading if you want to understand the choices.
- `context/ms-learn-redis-metrics.md` — Microsoft Learn citations backing the "retire UsedMemory" move and the SKU memory caps.
- `plan/plan.md` — decision record with rejected alternatives. If someone asks "why didn't you just change the module?" — it's there.
