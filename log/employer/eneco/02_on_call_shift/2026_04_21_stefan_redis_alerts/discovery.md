---
task_id: 2026-04-21-001
agent: claude-code
status: complete
summary: Phase-2 discovery — what changed since Stefan first noticed the spam, and what we already know vs still need to verify.
---

# Discovery

## Topology insight

Two repos, two control surfaces, one missing seam:

```
Eneco.Infrastructure                    MC-VPP-Infrastructure
─────────────────────                    ─────────────────────
modules/rediscache/      pinned by       terraform/rediscache.tf
  variables.tf  ────────────────────►    module "redisCache01" {
    redis_alert_configuration             source = "...?ref=v2.5.3"
    (default: 9 alerts,                    alert_actions = {...}     ← passed
     hardcoded thresholds                 # redis_alert_configuration ← NOT passed
     tier-agnostic)                      }
  main.tf
    azurerm_monitor_metric_alert.this           configuration/{dev,acc,prd}.tfvars
      for_each = var.redis_alert_configuration   redisCache01 = { sku_name = "..." }
                                                                                ▲
                                                                                │
                                                                no `alert_overrides` field
                                                                no `alert_configuration` field
                                                                seam absent — defaults
                                                                propagate uniformly to
                                                                Standard (dev) and Premium
                                                                (acc, prd) alike
```

The break is structural: the module exposes `redis_alert_configuration` as an input (correct, well-typed, validated), but the consumer doesn't expose the same surface to its tfvars layer. Defaults flow through unchallenged.

## What's known (FACT, anchored)

- F1. dev-mc Redis = Standard C2 (2.5 GB). Source: `MC-VPP-Infrastructure/main/configuration/dev.tfvars:659`.
- F2. acc-mc and prd-mc Redis = Premium P1 (6 GB). Source: `acc.tfvars:567`, `prd.tfvars:859`.
- F3. The consumer pins `?ref=v2.5.3`. Source: `MC-VPP-Infrastructure/main/terraform/rediscache.tf:2`.
- F4. v2.5.3 of the module ships 9 default alerts with hardcoded tier-agnostic thresholds. Source: `git show v2.5.3:terraform/modules/rediscache/variables.tf` (Eneco.Infrastructure).
- F5. The consumer never passes `redis_alert_configuration` and never overrides any threshold. Source: `MC-VPP-Infrastructure/main/terraform/rediscache.tf` (only `alert_actions` is passed).
- F6. Three of those nine defaults are observable in dev-mc Azure with byte-identical thresholds (15000, 200000000, 85). Source: screenshots `image.png`, `image (1).png`, `image (2).png`, `image (3).png`.
- F7. The CacheLatency-vpp-rediscache01-d alert has fired ≥10 times over Apr 17–21 on Rootly (Low severity, vpp-core team), with durations 1–13 minutes. Source: `image.png`.
- F8. Cache Latency on dev oscillated 7k–17k µs across the past week, frequently crossing the 15k µs threshold. Source: `image (3).png` preview chart.
- F9. The "well-behaved" percentage-based alert sat at 18.6% with an 85% threshold (no fires). Source: `image (2).png`.
- F10. The author of the most recent module fix (`v2.5.3`, "Ensure unique alert names") is the user himself (Alex Torres, Feb 11 2026). The user has prior context on this module.
- F11. The MC-VPP repo has a recurring **pattern** of `terraform/metric-alert-<service>.tf` files (cosmosdb, sql, key-vault, app-gateway, service-bus, kusto, signalr, storage-account, eventhub) consuming per-env tfvars for thresholds. Redis is the **only** service where alerts come from inside the upstream module. Source: `terraform/` file inventory.

## What's inferred (INFER, depends on F* above)

- I1. The UsedMemory absolute-bytes alert (200MB) is brittle on **every** environment, not only dev. On dev's C2 (2.5 GB) it trips at ~8% capacity; on acc/prd's P1 (6 GB) it trips at ~3%. dev only happens to be the env where the cache currently exceeds 200 MB; if acc/prd ever hold meaningful data, they will spam too. Chain: F1+F2+F4 + Microsoft pricing pages on Standard/Premium SKU memory caps.
- I2. The CacheLatency alert is brittle on Standard SKU specifically because Standard runs on shared compute and exhibits higher tail-latency than Premium. Chain: F4+F8 + Microsoft Learn on Azure Cache for Redis service tiers.
- I3. The percentage-based AllUsedMemoryPercentage alert is structurally correct because it scales with SKU capacity; this is the model the absolute-bytes UsedMemory alert should follow. Chain: F4+F9.
- I4. Stefan's verbal claim that the alerts are "introduced in the Redis module in the Eneco.Infrastructure repository" is FACT (F4 + git log on the module). His claim that "in the MC-Infrastructure we are using the same default alerts for all envs equally" is also FACT (F5).

## What's still UNVERIFIED (assumption + named probe)

- U1. `[UNVERIFIED[assumption: the deployed Azure alerts on acc and prd carry the exact same v2.5.3 defaults as dev does, boundary: only dev was screenshotted]]`. Probe: `az monitor metrics alert list --resource-group <rg> --query "[?starts_with(name,'UsedMemory') || starts_with(name,'CacheLatency')].{name:name,threshold:criteria.allOf[0].threshold,enabled:enabled}" -o table` against the acc/prd subs. If thresholds differ, someone hand-tuned in the portal and the IaC plan would revert it. Not blocking the recommendation — the IaC fix governs the long-term shape regardless.
- U2. `[UNVERIFIED[assumption: the consumer's `enable_non_ssl_port` key (in tfvars + consumer call) silently drops because the module variable is `non_ssl_port_enabled`, boundary: not the ticket scope]]`. This is an unrelated bug surfaced by reading the consumer call site. Not part of the fix; flag in lessons-learned only.
- U3. `[UNVERIFIED[unknown: whether the team has additional informal preferences (e.g., disable absolute-byte alerts entirely vs. raise their thresholds) beyond what Stefan said in the thread]]`. No known probe other than asking Stefan or the vpp-core team. The fix design must accommodate either choice (per-key enable/disable + per-key threshold override).

## Surprises (Phase 1 → Phase 2 transition)

- The folder name "stefan_redis_alerts" implied a single alert. Reality: **two** alerts misbehave in different ways (CacheLatency actually fires, UsedMemory is chronically firing per the portal but Stefan only highlighted it qualitatively). The recommendation must address both.
- The local `Eneco.Infrastructure` working tree is at a pre-v2.5.0 state and shows no alerts. Reading `git show v2.5.3:...` was necessary; relying on the working tree alone would have created the false impression that "the alerts don't exist in this repo at all." Lesson: when a consumer pins `?ref=...`, read the tagged version, not the working tree.
- The user (Alex Torres) authored the most recent module fix — domain familiarity is high; the spec can assume he knows the module idioms.
- Most dangerous pre-Phase-2 assumption ("the spam comes from one alert") is now downgraded. Two alerts are involved; one is the fire generator (CacheLatency), one is the chronic-firing-but-perhaps-not-routed-to-Rootly question (UsedMemory). The Rootly screenshot (`image.png`) shows only `CacheLatency` fires. The UsedMemory alert may have a Sev or routing that suppresses Rootly delivery — to be verified, but **not load-bearing** because the IaC fix tackles both regardless.

## Adversarial-needed surfaces (carry into Phase 5)

- "Disabling alerts in dev hides real signal." Counter: not disable; raise to a sensible Standard-tier threshold OR disable only the absolute-bytes UsedMemory which is redundant with the working percentage version.
- "Per-env override mechanism still ships defaults that don't fit Standard." Mitigation: provide Standard-aware defaults at the consumer, not just an override capability.
- "The next module bump pulls in new defaults that override the consumer's choices." Counter: the module merges via `for_each` over the input variable, so as long as the consumer passes a complete map, defaults are inert. But if the consumer passes a sparse override and the module deep-merges, a future module change could surprise. Resolve in plan.
