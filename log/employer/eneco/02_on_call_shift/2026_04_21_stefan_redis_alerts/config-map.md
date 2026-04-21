---
task_id: 2026-04-21-001
agent: claude-code
status: complete
summary: Phase-2 config map. Per-env tfvars relevant to the Redis fix.
---

# Config map

| File | Lines | Holds today | Will hold after fix |
|------|-------|-------------|---------------------|
| `MC-VPP-Infrastructure/main/configuration/dev.tfvars` | 660 | `redisCache01 = { sku_name="Standard", capacity=2, ... }` | (unchanged unless we lift alert config into the same object — see Plan) |
| `MC-VPP-Infrastructure/main/configuration/acc.tfvars` | 568 | `redisCache01 = { sku_name="Premium", capacity=1, ... }` | (unchanged) |
| `MC-VPP-Infrastructure/main/configuration/prd.tfvars` | 860 | `redisCache01 = { sku_name="Premium", capacity=1, ... }` | (unchanged) |
| `MC-VPP-Infrastructure/main/configuration/dev-alerts.tfvars` | 444 | Per-env thresholds for OTHER services (servicebus, sql, etc.) | + new `redisCache01_alert_overrides` map for Standard-tier overrides |
| `MC-VPP-Infrastructure/main/configuration/acc-alerts.tfvars` | 444 | Same | + empty/default override map (Premium ⇒ defaults are fine) |
| `MC-VPP-Infrastructure/main/configuration/prd-alerts.tfvars` | 593 | Same | + empty/default override map |
| `MC-VPP-Infrastructure/main/terraform/variables.tf:616-630` | 15 | `redisCache01` object schema with no alert field | + add `alert_overrides` field OR add a sibling `redisCache01_alert_overrides` variable |
| `MC-VPP-Infrastructure/main/terraform/rediscache.tf` | 112 | passes only `alert_actions` to the module | + pass `redis_alert_configuration = local.redis_alerts` (a `merge()` of premium-defaults + per-env overrides) |
| `Eneco.Infrastructure/terraform/modules/rediscache/variables.tf` @ v2.5.3 | ~250 | `redis_alert_configuration` map with 9 hardcoded defaults | (unchanged — module is fine as-is; the fix lives in the consumer) |
