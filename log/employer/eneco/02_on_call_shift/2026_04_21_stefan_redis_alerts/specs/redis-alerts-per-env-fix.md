---
task_id: 2026-04-21-001
agent: claude-code
status: complete
summary: Step-by-step Terraform fix for the Redis alert spam on dev-mc. Consumer-only change; no module bump. Per-env override of specific thresholds via a new sparse-override variable; acc/prd behavior preserved.
---

# Fix — Redis alerts per-env overrides

> **Scope.** This document is the implementable fix for Stefan's ticket (record `Rec0ATVMGS4J1`).
> You (Alex) inspect, then implement. Claude does not touch either repo.
>
> **Repos touched.** Only `MC-VPP-Infrastructure` (consumer). `Eneco.Infrastructure` is untouched; the `?ref=v2.5.3` pin stays.
>
> **What changes semantically.** Only dev-mc sees alert behavior change: `CacheLatency` threshold raised, and `UsedMemory` disabled in dev. acc and prd are unchanged (plan should be no-op for them on the Redis alert resources).

---

## 0. Preconditions (verify before starting)

Repo paths used throughout this spec (adjust if your local layout differs):

- Consumer: `/Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src/enecomanagedcloud/myriad-vpp/MC-VPP-Infrastructure`
- Module:   `/Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src/eneco-temp/Eneco.Infrastructure`

Run these before writing any code. Each must match the expected output.

```bash
CONSUMER=/Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src/enecomanagedcloud/myriad-vpp/MC-VPP-Infrastructure
MODULE=/Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src/eneco-temp/Eneco.Infrastructure
test -d "$CONSUMER" -a -d "$MODULE" || { echo "FAIL: paths not found"; exit 1; }
cd "$CONSUMER"

# P0.1 — confirm module ref and that the consumer does NOT already pass redis_alert_configuration
grep -n 'ref=v2.5.3' main/terraform/rediscache.tf          # expect: line 2
grep -n 'redis_alert_configuration' main/terraform/rediscache.tf  # expect: no output

# P0.2 — confirm SKU per env
grep -n 'sku_name' main/configuration/dev.tfvars main/configuration/acc.tfvars main/configuration/prd.tfvars
# expect: dev="Standard", acc="Premium", prd="Premium"
# (Other "sku_name" hits in the same files belong to other resources and are fine.)

# P0.3 — confirm no previous alert override variable exists
grep -n 'redisCache01_alert_overrides' main/terraform/variables.tf  # expect: no output

# P0.4 — confirm live Azure state matches module defaults BEFORE you commit anything.
# This catches portal drift; without it `terraform apply` may silently revert
# someone's hand-tuning. Paste the output into the PR description.
# Requires: az login + the dev-mc subscription set as default (use the
#   `enecotfvppmclogindev` alias from your shell profile).
az monitor metrics alert list \
  --resource-group <REPLACE-WITH-DEV-REDIS-RG> \
  --query "[?contains(name, 'rediscache01-d')].{name:name, enabled:enabled, threshold:criteria.allOf[0].threshold, severity:severity}" \
  -o table
# Expect 9 rows. Thresholds for the three named ones MUST match:
#   CacheLatency-vpp-rediscache01-d            15000
#   UsedMemory-vpp-rediscache01-d              200000000
#   AllUsedMemoryPercentage-vpp-rediscache01-d 85
# If any threshold differs, someone hand-tuned in the portal. Investigate
# before applying — `terraform apply` will revert the hand-tune.
```

If P0.1/P0.2/P0.3 fails, stop and re-read `codebase-map.md`. Somebody may have already started this fix on a branch.

If P0.4 fails (or you cannot run it because the subscription isn't to hand right now), record `[UNVERIFIED[assumption: portal state matches module defaults]]` in your PR description and treat it as a known risk — the V5 manual diff in §3 still gates the mirror, but the live-state check is what would catch portal drift specifically.

---

## 1. The change in one paragraph

Add a new input variable `redisCache01_alert_overrides` to the consumer (`MC-VPP-Infrastructure`). In `terraform/rediscache.tf`, build a local map by **merging** the module's v2.5.3 default alerts (mirrored into a `locals` block) with the per-env overrides. Pass the merged map to `module "redisCache01"` as `redis_alert_configuration`. Populate per-env overrides in `dev-alerts.tfvars` only; leave `acc-alerts.tfvars` and `prd-alerts.tfvars` override maps empty so their plan is a no-op.

---

## 2. File-by-file diffs

### 2.1 `main/terraform/variables.tf` — add the override variable

Append at the end of the file (or near the existing `redisCache01` variable declaration around line 616, operator's choice — keep the file's existing grouping style):

```hcl
variable "redisCache01_alert_overrides" {
  description = <<-EOT
    Per-environment sparse overrides for the Redis Cache alert configuration.
    
    The module Eneco.Infrastructure//terraform/modules/rediscache (pinned via
    ?ref=v2.5.3 in rediscache.tf) ships nine alerts with tier-agnostic defaults.
    This map lets each env override any subset of {enabled, threshold, severity,
    frequency, window_size} per alert key, without repeating the full alert
    configuration.
    
    Defaults are mirrored in locals-redis-alert-defaults.tf
    (local.redis_alert_defaults). Valid keys correspond to the nine
    module-default alert keys; a typo in a key would silently drop the
    override, which the validation block below guards against.
    
    Example (dev-alerts.tfvars):
      redisCache01_alert_overrides = {
        cache_latency = { threshold = 50000 }
        used_memory   = { enabled   = false }
      }
  EOT
  type = map(object({
    enabled     = optional(bool)
    threshold   = optional(number)
    severity    = optional(number)
    frequency   = optional(string)
    window_size = optional(string)
  }))
  default = {}
  
  # Guard against typos in override keys (Linus review #1). A mistyped
  # key (e.g. "cache_latancy") would silently be dropped by the merge in
  # rediscache.tf because we iterate over default keys, not override keys.
  # Keep this list in sync with locals-redis-alert-defaults.tf on every
  # module ref bump.
  validation {
    condition = alltrue([
      for k in keys(var.redisCache01_alert_overrides) : contains([
        "all_connected_clients", "all_percent_processor_time", "all_server_load",
        "all_used_memory_percentage", "cache_latency", "cache_read", "errors",
        "used_memory", "used_memory_rss",
      ], k)
    ])
    error_message = "redisCache01_alert_overrides contains an unknown key. Valid keys are the nine module v2.5.3 alert keys; check for a typo."
  }
}
```

Design notes:

- All fields are `optional()`, so any override can be sparse. `{}` means "use the default."
- Top-level type is `map(object(...))`, so only the 5 override-able knobs are exposed — **not** `name`, `metric_name`, `aggregation`, `operator`, `dimension`. Those are semantically bound to the module's alert definition; overriding them would fork the alert, not tune it. If that need ever arises, it's a module change (a separate PR).
- `default = {}` means existing callers (only this repo) don't break. Plan will be no-op for acc/prd after step 2.3.

### 2.2a `main/terraform/locals-redis-alert-defaults.tf` — new file, single-concern mirror

Extract the 80-line default map to its own file (Linus review #4). Keeps `rediscache.tf` short; makes the mirror reviewable as one self-contained artifact at module-bump time.

```hcl
# ------------------------------------------------------------------
# Redis Cache alert default configuration — CONSUMER-SIDE MIRROR
#
# The module Eneco.Infrastructure//terraform/modules/rediscache (pinned
# via ?ref=v2.5.3 in rediscache.tf) ships its `redis_alert_configuration`
# input with a default map of nine alert entries. The module uses
# `for_each = var.redis_alert_configuration`, so the consumer must pass
# a complete map — there is no deep-merge at the module boundary.
#
# This file is that complete map, copied verbatim from
#   git show v2.5.3:terraform/modules/rediscache/variables.tf
#
# Per-env overrides in var.redisCache01_alert_overrides (see
# variables.tf) are merged on top in rediscache.tf.
#
# !! On every module ref bump, diff this file against the upstream
# !! default block and re-sync. See spec §3 V5.
# ------------------------------------------------------------------
locals {
  redis_alert_defaults = {
    all_connected_clients = {
      name        = "AllConnectedClients"
      description = "Alert when the number of connected clients exceeds the threshold"
      severity    = 3
      frequency   = "PT1M"
      window_size = "PT5M"
      enabled     = true
      metric_name = "allconnectedclients"
      aggregation = "Maximum"
      operator    = "GreaterThan"
      threshold   = 128
      dimension   = []
    }
    all_percent_processor_time = {
      name        = "AllPercentProcessorTime"
      description = "Alert when the CPU usage exceeds the threshold"
      severity    = 3
      frequency   = "PT1M"
      window_size = "PT15M"
      enabled     = true
      metric_name = "allpercentprocessortime"
      aggregation = "Average"
      operator    = "GreaterThan"
      threshold   = 60
      dimension = [
        { name = "ShardId", operator = "Include", values = ["*"] },
        { name = "primary", operator = "Include", values = ["true"] },
      ]
    }
    all_server_load = {
      name        = "AllServerLoad"
      description = "Alert when the server load exceeds the threshold"
      severity    = 3
      frequency   = "PT1M"
      window_size = "PT15M"
      enabled     = true
      metric_name = "allserverLoad"
      aggregation = "Average"
      operator    = "GreaterThan"
      threshold   = 75
      dimension = [
        { name = "ShardId", operator = "Include", values = ["*"] },
        { name = "primary", operator = "Include", values = ["true"] },
      ]
    }
    all_used_memory_percentage = {
      name        = "AllUsedMemoryPercentage"
      description = "Alert when the used memory percentage exceeds the threshold"
      severity    = 3
      frequency   = "PT1M"
      window_size = "PT5M"
      enabled     = true
      metric_name = "allusedmemorypercentage"
      aggregation = "Average"
      operator    = "GreaterThan"
      threshold   = 85
      dimension   = []
    }
    cache_latency = {
      name        = "CacheLatency"
      description = "Alert when the cache latency exceeds the threshold"
      severity    = 3
      frequency   = "PT1M"
      window_size = "PT15M"
      enabled     = true
      metric_name = "cachelatency"
      aggregation = "Average"
      operator    = "GreaterThan"
      threshold   = 15000
      dimension   = []
    }
    cache_read = {
      name        = "CacheRead"
      description = "Alert when the data read from the cache exceeds the threshold"
      severity    = 3
      frequency   = "PT5M"
      window_size = "PT15M"
      enabled     = true
      metric_name = "cacheRead"
      aggregation = "Average"
      operator    = "GreaterThan"
      threshold   = 46875000
      dimension   = []
    }
    errors = {
      name        = "Errors"
      description = "Alert when the number of errors on the cache exceeds the threshold"
      severity    = 3
      frequency   = "PT1M"
      window_size = "PT5M"
      enabled     = true
      metric_name = "errors"
      aggregation = "Maximum"
      operator    = "GreaterThan"
      threshold   = 850
      dimension   = []
    }
    used_memory = {
      name        = "UsedMemory"
      description = "Alert when the used memory for k-v pairs exceeds the threshold"
      severity    = 3
      frequency   = "PT5M"
      window_size = "PT5M"
      enabled     = true
      metric_name = "usedmemory"
      aggregation = "Maximum"
      operator    = "GreaterThan"
      threshold   = 200000000
      dimension   = []
    }
    used_memory_rss = {
      name        = "UsedMemoryRSS"
      description = "Alert when the used memory including fragmentation and metadata exceeds the threshold"
      severity    = 3
      frequency   = "PT1M"
      window_size = "PT5M"
      enabled     = true
      metric_name = "usedmemoryRss"
      aggregation = "Average"
      operator    = "GreaterThan"
      threshold   = 11000000000
      dimension   = []
    }
  }
}
```

### 2.2b `main/terraform/rediscache.tf` — merge and pass

At the top of `rediscache.tf`, add a `locals` block that strips null fields from each override and merges onto the defaults. Then add one line to the module call.

```hcl
locals {
  # Strip null fields from each override entry — map(object(...)) with
  # optional() fields yields nulls for unset keys, and merge() treats
  # nulls as overwrites. This normalisation keeps the merge readable
  # and one concern (default + sparse override) per expression.
  _redis_alert_overrides_clean = {
    for key, ov in var.redisCache01_alert_overrides :
    key => { for field, value in ov : field => value if value != null }
  }
  
  redis_alert_configuration = {
    for key, base in local.redis_alert_defaults :
    key => merge(base, lookup(local._redis_alert_overrides_clean, key, {}))
  }
}
```

Then modify the `module "redisCache01"` block (currently at `rediscache.tf:1-45`) to pass the merged map:

```diff
 module "redisCache01" {
   source = "git::https://enecomanagedcloud@dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/Eneco.Infrastructure//terraform/modules/rediscache?ref=v2.5.3"

   resource_group_name = module.rg-storage.resource_group_name
   location            = module.rg-storage.resource_group_location

   count            = var.redisCache01.deploymentRequired ? 1 : 0
   redis_cache_name = format("%s-rediscache01-%s", var.project, var.environmentShort)
   redis_cache_config = {
     capacity                      = var.redisCache01.capacity
     enable_non_ssl_port           = var.redisCache01.enable_non_ssl_port
     sku_name                      = var.redisCache01.sku_name
     public_network_access_enabled = var.redisCache01.public_network_access_enabled
     redis_version                 = 6
     identity = {
       type = "SystemAssigned"
     }
     zones = contains(["acc", "prd"], var.environment) ? [1, 2, 3] : null
   }
   patch_schedule = [{
     day_of_week    = "Sunday"
     start_hour_utc = 22
   }]
   redis_configuration = [{
     authentication_enabled                 = var.redisCache01.authentication_enabled
     maxmemory_policy                       = "volatile-lru"
     data_persistence_authentication_method = var.redisCache01.data_persistence_authentication_method
     notify_keyspace_events                 = "KEA"
   }]
   family                              = var.redisCache01.sku_name == "Basic" || var.redisCache01.sku_name == "Standard" ? "C" : "P"
   rdb_backup_enabled                  = var.redisCache01.rdb_backup_enabled && var.redisCache01.sku_name == "Premium" ? true : null
   rdb_backup_frequency                = var.redisCache01.sku_name == "Premium" ? var.redisCache01.rdb_backup_frequency : null
   rdb_backup_max_snapshot_count       = var.redisCache01.sku_name == "Premium" ? var.redisCache01.rdb_backup_max_snapshot_count : null
   rdb_storage_connection_string       = var.redisCache01.rdb_backup_enabled && var.redisCache01.sku_name == "Premium" ? module.redisCache01StorageAccount[0].primary_blob_connection_string : null
   rdb_storage_account_subscription_id = var.redisCache01.sku_name == "Premium" ? var.subscriptionId : null
   tags                                = merge(var.tags_default, var.tags_purpose_vpp_core_monitoring)
+  redis_alert_configuration           = local.redis_alert_configuration
   alert_actions = {
     "rootly" = {
       action_group_id = data.azurerm_monitor_action_group.team["vpp-core"].id
       webhook_properties = {
         "Runbook" = "LinkToRedisRunbooksHere"
       }
     }
   }
 }
```

Only one line added: `redis_alert_configuration = local.redis_alert_configuration`. Everything else is the mirror + merge above.

### 2.3 `main/configuration/dev-alerts.tfvars` — the only per-env override in this first iteration

Append at the end of the file:

```hcl
# ---- Redis (dev: Standard C2 = 2.5 GB) ----
# Stefan's ticket Rec0ATVMGS4J1: CacheLatency was firing ~10x over 4 days on Rootly
# because the module default (15 000 µs) is tuned for Premium and dev runs Standard.
# UsedMemory (absolute 200 MB) is structurally redundant with AllUsedMemoryPercentage
# (85 %) per Microsoft guidance — retire it on dev.
#
# Starting values; observe one week then revisit.
redisCache01_alert_overrides = {
  cache_latency = {
    threshold = 50000   # 50 ms; Standard C2 baseline observed at 7–17 ms; 3x headroom
  }
  used_memory = {
    enabled = false     # Percentage-based AllUsedMemoryPercentage covers the same axis
  }
}
```

### 2.4 `main/configuration/acc-alerts.tfvars` — explicit empty override

Append at the end of the file:

```hcl
# ---- Redis (acc: Premium P1 = 6 GB) ----
# Module defaults apply. If CacheLatency or UsedMemory become noisy on acc,
# copy dev's pattern here.
redisCache01_alert_overrides = {}
```

### 2.5 `main/configuration/prd-alerts.tfvars` — explicit empty override

Append at the end of the file:

```hcl
# ---- Redis (prd: Premium P1 = 6 GB) ----
# Module defaults apply. Any change here should pass through the
# vpp-core team's review + one observation week in acc first.
redisCache01_alert_overrides = {}
```

The empty overrides in §2.4 and §2.5 are **convention**, not technical requirement. The variable declaration (§2.1) sets `default = {}`, so omitting the stanza would not break plan — it would silently inherit an empty override. The explicit stanza exists so that **anyone creating a new env is forced to make a deliberate choice** about Redis alert behavior (copy dev's pattern, keep defaults, or something else) rather than inheriting an invisible default. If you prefer to rely on `default = {}` and keep the tfvars terser, that's a local style call; mention it in the PR.

---

## 3. Pre-apply verification

Run these commands **per env** after writing the code. Each has an expected-output check. If any fails, fix before continuing.

```bash
cd /Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src/enecomanagedcloud/myriad-vpp/MC-VPP-Infrastructure/main

# V1 — syntax + schema
terraform fmt -check -recursive terraform/
terraform validate                     # expect: Success

# V2 — acc no-op on Redis alerts
# (regex matches the 9 module-default keys; trailing `|` removed — earlier
#  draft had an empty alternation that would match anything)
ALERT_KEYS='all_connected_clients|all_percent_processor_time|all_server_load|all_used_memory_percentage|cache_latency|cache_read|errors|used_memory|used_memory_rss'
terraform plan \
  -var-file=configuration/acc.tfvars \
  -var-file=configuration/acc-alerts.tfvars \
  -out=plan.acc
terraform show plan.acc | grep -E "azurerm_monitor_metric_alert\.this\[\"($ALERT_KEYS)\"\]" \
  && { echo "FAIL: acc shows Redis alert changes — investigate"; exit 1; } \
  || echo "OK: no Redis alert changes on acc"

# V3 — prd no-op on Redis alerts
terraform plan \
  -var-file=configuration/prd.tfvars \
  -var-file=configuration/prd-alerts.tfvars \
  -out=plan.prd
terraform show plan.prd | grep -E "azurerm_monitor_metric_alert\.this\[\"($ALERT_KEYS)\"\]" \
  && { echo "FAIL: prd shows Redis alert changes — investigate"; exit 1; } \
  || echo "OK: no Redis alert changes on prd"

# V4 — dev shows *exactly two* Redis alert changes: cache_latency threshold + used_memory enabled
terraform plan \
  -var-file=configuration/dev.tfvars \
  -var-file=configuration/dev-alerts.tfvars \
  -out=plan.dev
# Inspect plan.dev manually. Expect:
#   module.redisCache01[0].azurerm_monitor_metric_alert.this["cache_latency"] will be updated in-place
#     ~ criteria.allOf[0].threshold: 15000 -> 50000
#   module.redisCache01[0].azurerm_monitor_metric_alert.this["used_memory"] will be updated in-place
#     ~ enabled: true -> false
# And nothing else redis-related. If a (-/+) recreate appears on used_memory, STOP — see risk R1.

# V5 — mirror-vs-module-default bytecheck (ONE-TIME, before first PR)
cd "$MODULE"  # set in §0 preconditions
git show v2.5.3:terraform/modules/rediscache/variables.tf | sed -n '/variable "redis_alert_configuration"/,/^variable /p'
# Compare the default block line-for-line with local.redis_alert_defaults in rediscache.tf.
# Every key and every field value must match exactly. This is the one manual review gate.

# V6 — file-scope assertion (Acceptance A6)
# Baseline is the branch this PR targets (usually main, but override BASE if not).
# Always fetch first — stale local main breaks the diff.
cd "$CONSUMER"
BASE="${BASE:-origin/main}"
git fetch origin --quiet
git diff --name-only "$BASE"...HEAD | sort > /tmp/changed-files.txt
cat <<EOF | sort > /tmp/expected-files.txt
main/configuration/acc-alerts.tfvars
main/configuration/dev-alerts.tfvars
main/configuration/prd-alerts.tfvars
main/terraform/locals-redis-alert-defaults.tf
main/terraform/rediscache.tf
main/terraform/variables.tf
EOF
diff /tmp/changed-files.txt /tmp/expected-files.txt \
  && echo "OK: only the expected 6 files changed (vs $BASE)" \
  || { echo "FAIL: branch touches files outside the spec (vs $BASE)"; exit 1; }

# V7 — tflint (Acceptance A5; runs the repo's tflint config if present)
test -f .tflint.hcl && tflint --recursive || echo "WARN: no .tflint.hcl, skipping"
```

V5 is the Phase-8 structural falsifier for mirror drift. It must be re-run on every module ref bump.
V6 enforces file-scope. V7 catches anything `terraform validate` doesn't.

---

## 4. Apply plan

Order is important: dev first, observe, then acc + prd together or sequentially.

### 4.1 Apply to dev

```bash
# (your normal pipeline — pseudo-commands below)
terraform apply plan.dev
```

**Post-apply within 15 minutes**:

- Watch the Rootly `#vpp-core` channel. `CacheLatency-vpp-rediscache01-d` fires should drop to zero.
- Verify in the Azure portal that `UsedMemory-vpp-rediscache01-d` shows "Disabled" in the Alert Rules list.
- Verify in the Azure portal that `CacheLatency-vpp-rediscache01-d` shows threshold `50000`.

**Observation window**: 7 days. After 7 days:

- Zero CacheLatency fires → keep 50 000 µs; propagate to acc/prd if they show similar noise.
- Still some fires → either raise further (e.g. 100 000 µs) or `enabled = false` for dev. Update `dev-alerts.tfvars` and re-apply.

### 4.2 Apply to acc and prd

Only after dev is stable for ≥ 7 days. `terraform plan` must still show no Redis alert changes (re-run V2 and V3 against the dev-merged branch). Apply them in any order — they don't affect each other.

---

## 5. Rollback

Rollback is not a git-revert-and-reapply. Azure state doesn't bend to Terraform's time arrow; it bends to what Terraform tells it at apply time.

### 5.1 If apply succeeds but behavior is worse (e.g. CacheLatency misses real issues)

Change `dev-alerts.tfvars` to raise the threshold further or set `enabled = true` and `threshold = 15000` to restore module defaults. Re-apply. Nothing exotic — this is the intended "tune by observation" loop.

### 5.2 If apply partially fails mid-way across the two dev alert updates

`[UNVERIFIED[assumption: azurerm provider applies `enabled` and `threshold` toggles as in-place PATCH, not resource recreation, on the provider version pinned in this repo]]`. Falsifier: read `terraform plan plan.dev` carefully. If you see `~ resource` (in-place update), the assumption holds. If you see `-/+ resource` (recreate), it does not — and the alert resource will be briefly absent during apply. The provider's CHANGELOG for `azurerm_monitor_metric_alert` is the authoritative source; this spec doesn't cite a specific version.

If the assumption holds: a partial failure means one alert is in the new state and one is in the old. Re-run `terraform apply plan.dev` (idempotent). Verify both alerts reach the target state in the portal.

If the assumption does not hold and recreate appears: stop. Either revert the spec change for `used_memory` (toggle alone via portal first, then `terraform refresh`) or schedule a maintenance window so the brief disappearance of the alert resource is acceptable.

### 5.3 If you need to undo the entire change (structural rollback)

The change in `rediscache.tf` is: added a `locals` block + added one line to the module call. Reverting the commit brings the file back to its current shape. After revert:

- `terraform plan` on each env will show every alert going back to module defaults (on acc/prd: no-op; on dev: CacheLatency 50 000 → 15 000 and UsedMemory disabled → enabled).
- This means dev-mc will resume receiving CacheLatency spam immediately.
- Applies must happen in the same order as forward: apply dev first, then acc + prd.

If the override variable was populated in tfvars that are still on disk, the plan will error (undeclared variable). Remove the `redisCache01_alert_overrides` stanza from all three `*-alerts.tfvars` files as part of the revert commit.

### 5.4 If something truly catastrophic happens

Alerts are observability infrastructure; they don't carry data. Worst case you're flying blind for a few hours, not losing state. Escalate to vpp-core in `#team-platform` and open the Azure portal to manually disable all three affected alert rules while the IaC is sorted out.

---

## 5.5 Operational risks the spec does NOT close (caller's responsibility)

These came out of the evaluator pass and are real but out-of-band:

- **Live-state drift after P0.4** — if you applied this fix and someone hand-tunes a threshold in the portal afterwards, the next `terraform apply` will revert it. There is no continuous reconciliation alarm in this repo. Mitigation: re-run P0.4 before any subsequent IaC change in this area.
- **Concurrent module bump PR** — if a teammate merges `?ref=v2.5.4+` into the consumer between your branch-cut and merge, the mirror in §2.2 goes stale on merge. Re-run V5 immediately before merging the PR.
- **Rootly-side routing rules** — disabling `UsedMemory` on dev removes the Azure-side alert resource from the firing set, but Rootly may have a saved deduplication or routing rule keyed off the alert name. If the rule auto-archives orphaned alert names, fine; otherwise file a separate Rootly cleanup ticket.
- **Action-group blast** — the consumer continues to pass `alert_actions = { "rootly" = ... }` to the module; this fix does not affect routing of the *other* alerts (AllConnectedClients, etc.) through the same action group. If the team ever wants per-alert routing, that's a module-side change.

## 6. Known caveats

### 6.1 The mirror is drift-sensitive

The 9 alert defaults are copied into `rediscache.tf`'s `locals`. If the module is bumped (e.g. `?ref=v2.5.4` or later adds a tenth alert or changes a threshold), **that change doesn't automatically flow through**. Mitigations:

1. V5 in §3 must be re-run on every module ref bump.
2. A PR review checklist item: "did this PR change the module ref? If so, re-run V5."
3. (Future) When the module gains a `redis_alert_configuration_defaults` output, drop the mirror and source defaults from the output. That's out of scope for this ticket.

### 6.2 The 50 000 µs threshold is a guess

It's anchored to `image (3).png`'s observed band (7k–17k µs across Apr 13–20, trending down), not to an SLO or a Microsoft-published target. If the team has an SLO for Redis latency, set the threshold to SLO + σ instead. The ticket didn't name one, so we're proposing 50 000 as "3× observed max" — clearly a starting bid, not a design claim. Revisit after one observation week.

### 6.3 Disabling UsedMemory on dev is a deliberate narrowing

This fix removes one of two memory-pressure signals on dev. `AllUsedMemoryPercentage` (85 %) remains and is the structurally correct variant per [Microsoft Learn](https://learn.microsoft.com/azure/redis/best-practices-memory-management#monitor-memory-usage). If the team wants defense-in-depth on dev (e.g. low-water mark alert at 30 %), add a second override setting `used_memory.enabled = true` with a threshold that makes sense for C2 (e.g. 70 % of 2.5 GB = 1 750 000 000 B). Out of scope for this iteration.

### 6.4 Out-of-scope bugs noticed during mapping

Not part of this fix, not part of the ticket, but file separately:

- **consumer↔module key rename**: consumer sets `enable_non_ssl_port`, module reads `non_ssl_port_enabled`. Live probe (Apr 21) confirms Azure state `enableNonSslPort = false`, so the effective behaviour is correct — but the consumer's key is silently ignored by the module's typed object, and the default (false) happens to match what the consumer intends. If the consumer ever sets this to `true`, the module will ignore it and the key stays false. Fix the consumer or the module key to align.
- **double `redis_version`**: consumer sets `redis_version = 6` inline in `redis_cache_config`; module's `redis_cache_config` type object also declares `redis_version` as optional. Live probe shows `redisVersion = "6.0"`. Potential double-set. Low risk, but worth tidying.

---

## 7. PR description template

```
Fix: make Redis Cache alerts env-tunable; retire redundant absolute-bytes UsedMemory on dev

Ref: Stefan Klopf ticket Rec0ATVMGS4J1 (Slack Lists in #myriad-platform).

Context:
The Redis module Eneco.Infrastructure//terraform/modules/rediscache?ref=v2.5.3
ships 9 alerts with tier-agnostic defaults. The consumer never overrides them,
so dev (Standard C2, 2.5 GB) and acc/prd (Premium P1, 6 GB) get identical
thresholds. Two defaults are noisy on dev:
- CacheLatency > 15 000 µs fires ~10x over 4 days on Rootly (image.png).
- UsedMemory > 200 MB trips chronically at portal level because dev cache
  sits at ~455 MB (image (1).png). Microsoft recommends the percentage
  variant (AllUsedMemoryPercentage, 85 %) over the absolute variant
  (memory-management best-practices).

Change:
- New input `redisCache01_alert_overrides` on the consumer (sparse
  per-alert-key, per-field override map).
- Mirror the module's v2.5.3 default alert map into a `locals` block in
  rediscache.tf, merge with the override at the call site, pass the
  result as `redis_alert_configuration`.
- dev-alerts.tfvars: raise CacheLatency threshold to 50 000 µs; disable
  UsedMemory in favor of AllUsedMemoryPercentage.
- acc-alerts.tfvars and prd-alerts.tfvars: explicit empty overrides
  (forces deliberate choice for new envs).

Blast radius:
- dev: CacheLatency threshold 15 000 → 50 000 µs; UsedMemory enabled → disabled.
- acc, prd: no-op. Verified with terraform plan.

Rollback: documented in specs/redis-alerts-per-env-fix.md §5.

Module version unchanged (still ?ref=v2.5.3). Mirror drift risk acknowledged
in comment at rediscache.tf and mitigated by V5 checklist in the spec.
```
