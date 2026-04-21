---
task_id: 2026-04-21-001
agent: claude-code
status: complete
summary: Phase-2 codebase map. Surfaces touched by Stefan's Redis-alerts ticket across Eneco.Infrastructure (module owner) and MC-VPP-Infrastructure (consumer).
---

# Codebase map — Redis alerts

## Eneco.Infrastructure (module owner)

Local checkout: `/Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src/eneco-temp/Eneco.Infrastructure`
Working tree HEAD: pre-v2.5.0 (older than the alert-bearing tags). Tag-pinned reads via `git show v2.5.3:...`.

| Path | Lines | Role |
|------|-------|------|
| `terraform/modules/rediscache/main.tf` @ v2.5.3 | ~85 | Defines `azurerm_redis_cache.redis_cache` AND `azurerm_monitor_metric_alert.this` (for_each over `var.redis_alert_configuration`). Action injection via `dynamic "action"` over `var.alert_actions`. |
| `terraform/modules/rediscache/variables.tf` @ v2.5.3 | ~250 | Declares `redis_alert_configuration` (map of object, **default contains 9 alerts** — see ledger below) and `alert_actions`. Validations: severity ∈ {0..4}, operator/aggregation enums, ISO-8601 frequency/window, unique `name` field. |
| `terraform/modules/rediscache/outputs.tf` | 17 | redis_cache_id, redis_cache_primary_connection_string, etc. No alert-related outputs. |

Tag history relevant to alerts (`git log --all -- terraform/modules/rediscache/`):

| Commit | Tag | Purpose |
|--------|-----|---------|
| `e0c7200` | v2.5.0+ | feat: add set of standard alerts for redis (the original Stefan refers to) |
| `c191c70` | v2.5.1+ | chore: tweak redis alert for cache latency |
| `a23b83e` | v2.5.2+ | fix: fix broken alert config for redis cache |
| `5d302b6` | v2.5.3 | fix(rediscache): Ensure unique alert names (authored by Alex Torres himself, Feb 11) |

## MC-VPP-Infrastructure (consumer)

Local checkout: `/Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src/enecomanagedcloud/myriad-vpp/MC-VPP-Infrastructure/main`

| Path | Lines | Role |
|------|-------|------|
| `terraform/rediscache.tf` | 112 | `module "redisCache01"` pinned at `?ref=v2.5.3`. Sets `alert_actions = { "rootly" = { action_group_id = data.azurerm_monitor_action_group.team["vpp-core"].id, webhook_properties = { "Runbook" = "LinkToRedisRunbooksHere" } } }`. **Does NOT pass `redis_alert_configuration`.** Result: all 9 module defaults apply uniformly to dev/acc/prd. |
| `terraform/variables.tf:616-630` | 15 | Declares `var.redisCache01` object — **no field for alert config or alert overrides**. Only deployment + capacity + SKU + RDB knobs. |
| `terraform/actiongroup.tf` | — | Defines the action groups (incl. `vpp-core`) referenced by `alert_actions`. Out of scope for fix. |
| `configuration/dev.tfvars:649-660` | 12 | `sku_name = "Standard"`, capacity = 2 (= C2 = 2.5 GB). |
| `configuration/acc.tfvars:557-568` | 12 | `sku_name = "Premium"`, capacity = 1 (= P1 = 6 GB). |
| `configuration/prd.tfvars:849-860` | 12 | `sku_name = "Premium"`, capacity = 1 (= P1 = 6 GB). |
| `configuration/dev-alerts.tfvars` | 444 | Existing per-env alert thresholds for OTHER services (servicebus, sql, etc.). Natural home for new Redis alert overrides. |
| `configuration/acc-alerts.tfvars` | 444 | Same as above (acc). |
| `configuration/prd-alerts.tfvars` | 593 | Same as above (prd; bigger because more services in scope). |
| `terraform/metric-alert-*.tf` (cosmosdb, sql, key-vault, app-gateway, service-bus, kusto, signalr, storage-account, eventhub) | — | Pattern: dedicated `metric-alert-<service>.tf` files using `azurerm_monitor_metric_alert` directly with thresholds wired from per-env tfvars. **Redis breaks this pattern** — it has no `metric-alert-rediscache.tf`; alerts come from inside the module instead. |

## Default alerts shipped by the module (v2.5.3)

| Map key | Alert name | Metric | Threshold | Aggregation | Window | Tier-relative? |
|---------|------------|--------|-----------|-------------|--------|----------------|
| all_connected_clients | AllConnectedClients | allconnectedclients | > 128 | Maximum | PT5M | No (absolute) |
| all_percent_processor_time | AllPercentProcessorTime | allpercentprocessortime | > 60 % | Average | PT15M | Yes (percentage) |
| all_server_load | AllServerLoad | allserverLoad | > 75 | Average | PT15M | Yes (percentage-like) |
| all_used_memory_percentage | AllUsedMemoryPercentage | allusedmemorypercentage | > 85 % | Average | PT5M | **Yes (Stefan: "more useful")** |
| cache_latency | CacheLatency | cachelatency | > 15 000 µs | Average | PT15M | **No (absolute) — THE SPAMMER** |
| cache_read | CacheRead | cacheRead | > 46 875 000 | Average | PT15M | No (absolute) |
| errors | Errors | errors | > 850 | Maximum | PT5M | No (absolute) |
| used_memory | UsedMemory | usedmemory | > 200 000 000 B (≈190 MiB) | Maximum | PT5M | **No (absolute) — Stefan: "way too low"** |
| used_memory_rss | UsedMemoryRSS | usedmemoryRss | > 11 000 000 000 B (≈10.2 GiB) | Average | PT5M | No (absolute) |

## Cross-validation against screenshots

| Screenshot | Alert | Threshold in Azure | Default in module v2.5.3 | Match |
|------------|-------|--------------------|--------------------------|-------|
| `image (1).png` | UsedMemory-vpp-rediscache01-d | 200 000 000 B | 200 000 000 | ✓ |
| `image (2).png` | AllUsedMemoryPercentage-vpp-rediscache01-d | 85 % | 85 | ✓ |
| `image (3).png` | CacheLatency-vpp-rediscache01-d | 15 000 µs | 15 000 | ✓ |

**All three Azure alerts are byte-identical to the module defaults.** No portal drift; the consumer is shipping defaults verbatim.
