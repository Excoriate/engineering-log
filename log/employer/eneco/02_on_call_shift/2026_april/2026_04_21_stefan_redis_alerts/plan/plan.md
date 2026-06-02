---
task_id: 2026-04-21-001
agent: claude-code
status: complete
summary: Phase-5 fix plan — per-env alert override via consumer-side sparse merge; retire absolute-bytes UsedMemory in favor of percentage; dev-specific CacheLatency bump. No module change. Includes Adversarial Challenge (6Qs) and named downstream consequence.
---

# Plan — Redis alerts per-env overrides

## Objective

Make the Redis alerts defined by `Eneco.Infrastructure/modules/rediscache` v2.5.3 overridable per environment in `MC-VPP-Infrastructure`, and retire the structurally redundant absolute-bytes `UsedMemory` alert. Do this without changing the module or the `?ref=v2.5.3` pin.

## End state (success counterpart for each break)

| Break (today) | Success (after fix) |
|---------------|---------------------|
| All envs inherit the 9 module defaults; dev-mc spams CacheLatency on Rootly. | All envs still get the 9 alerts, but per-env tfvars can override any subset of `{enabled, threshold, severity, frequency, window_size}`. |
| `UsedMemory` (absolute bytes, 200 MB) fires whenever cache holds > 200 MB. Brittle on every env. | `UsedMemory` disabled in the consumer (`enabled = false`) by default. `AllUsedMemoryPercentage` (85 %) is the sole memory-pressure alert and has been idling at 18.6 %. Any env can re-enable `UsedMemory` explicitly. |
| `CacheLatency` at 15 000 µs on Standard C2 dev-mc trips 10+ times in 4 days. | dev override raises the threshold to a value above the observed Standard-tier band (proposed: 50 000 µs = 50 ms), or disables the alert in dev if the team prefers. acc and prd keep the default 15 000 µs. |
| Consumer's `redisCache01` input object has no alert surface. | Consumer has a sibling `redisCache01_alert_overrides` input variable wired into the call site via `merge()`. |

## Decision record

### D1 — Where does the fix live? **Consumer only. No module change.**

The module already exposes `redis_alert_configuration` as a fully typed, validated input with a complete default map. Adding a module-side "deep merge" overrides variable would be over-engineering. The consumer passing a complete map (either the defaults it wants, or a `merge(local.defaults, var.overrides)` expression) satisfies the ticket without a module version bump.

Rejected alternative: add `redis_alert_overrides` to the module and have the module do the merge. Blast radius: bumps the module version, forces every other consumer (there are other `?ref=v2.5.3` pins in the org) to learn a new input. Doesn't improve the outcome for MC-VPP.

### D2 — Where do the per-env values live? **In `configuration/*-alerts.tfvars`.**

The repo already has the convention: `dev-alerts.tfvars`, `acc-alerts.tfvars`, `prd-alerts.tfvars` for env-specific alert thresholds (see `metric-alert-cosmosdb.tf`, `metric-alert-servicebus.tf`, etc.). A new `redisCache01_alert_overrides` variable should sit in the same files. Keeps the repo idiom.

Rejected alternative: put the overrides inside the existing `redisCache01` object in `{dev,acc,prd}.tfvars`. Mixing "what to deploy" (SKU, capacity) with "how to alert" violates the existing file-role separation.

### D3 — Sparse override vs full replacement. **Sparse override with key-level merge.**

Since the module uses `for_each = var.redis_alert_configuration` (not a merge inside the module), the consumer must pass a **complete** map to the module. So the consumer builds it at the call site:

```hcl
locals {
  redis_alert_defaults = {
    # Replica of the module v2.5.3 defaults, minus any we explicitly disable by default.
    # Duplicated here deliberately — see "known cost" below.
    all_connected_clients      = { name = "AllConnectedClients", ... }
    all_percent_processor_time = { name = "AllPercentProcessorTime", ... }
    all_server_load            = { name = "AllServerLoad", ... }
    all_used_memory_percentage = { name = "AllUsedMemoryPercentage", ... }
    cache_latency              = { name = "CacheLatency", ... }
    cache_read                 = { name = "CacheRead", ... }
    errors                     = { name = "Errors", ... }
    used_memory                = { name = "UsedMemory", enabled = false, ... }  # retired; percentage version takes its place
    used_memory_rss            = { name = "UsedMemoryRSS", ... }
  }
  redis_alerts = {
    for k, base in local.redis_alert_defaults :
    k => merge(base, lookup(var.redisCache01_alert_overrides, k, {}))
  }
}
```

The per-env tfvars only specify the fields that differ from the default for that env.

**Known cost**: the consumer now carries a copy of the module's defaults. If the module is ever bumped and the defaults change meaningfully, the consumer's copy diverges. Mitigation:

1. Inline comment in `locals.tf` block naming the module ref being mirrored (`# Mirrors Eneco.Infrastructure//terraform/modules/rediscache?ref=v2.5.3`).
2. The mirror is **deliberate** — it makes the per-env override behavior explicit and reviewable in PRs. A later refactor can extract this to a separate `locals-redis-alerts.tf` if the file becomes unwieldy.

Rejected alternative: reference `module.redisCache01.default_alert_configuration` as a data source. The module doesn't expose defaults as outputs, and adding that is a module change (see D1).

### D4 — Per-env override shape.

Proposed overrides (open to team feedback):

```hcl
# dev-alerts.tfvars
redisCache01_alert_overrides = {
  cache_latency = {
    threshold = 50000   # 50 ms — Standard C2 tolerance. Raise/lower after observation.
  }
  # used_memory is already disabled in the consumer default; no override needed here.
}

# acc-alerts.tfvars and prd-alerts.tfvars
redisCache01_alert_overrides = {}   # Premium defaults are acceptable.
```

The 50 000 µs for dev is a starting number, not a claim about "the right Standard-tier value." Rationale: observed band in `image (3).png` was 7k–17k µs across Apr 13–20 with Apr 19–20 dropping to 7–10k. A threshold of 50k leaves ~3× headroom over the observed maximum while still catching a genuine internode-latency problem (3× baseline is a reasonable signal). The team should revisit after one week of observation. If still noisy, disable via `enabled = false` and reopen the conversation about whether Standard is the right tier for dev at all.

### D5 — Disable vs raise for `UsedMemory`.

> **SUPERSEDED by spec §2.3 after contrarian pass F1/F3/F7.** Original D5 said "disable as a consumer-level default for all envs." That contradicted S4/S5's "no-op for acc/prd" falsifiers — a silent scope expansion. **The shipped spec (`specs/redis-alerts-per-env-fix.md`) disables `used_memory` only via `dev-alerts.tfvars`; acc and prd keep the module default `enabled = true`.** Reasoning preserved below for the record.

Original reasoning: `AllUsedMemoryPercentage` is the structurally correct version of the same signal, Microsoft explicitly recommends the percentage variant ([memory-management best practices](https://learn.microsoft.com/azure/redis/best-practices-memory-management#monitor-memory-usage)), and the module happens to ship both. Keeping two alerts on the same capacity axis with two different threshold conventions is noise, not defense-in-depth.

The structural argument still applies on every env, but the disablement is now opt-in per env rather than opt-out — surface the trade-off to acc/prd owners explicitly when they hit the same noise.

## Step-by-step implementation

Each step is a single commit on a single branch. Commits are bisectable — reverting any one commit leaves the system in a coherent state.

| # | File | Action | Falsifier |
|---|------|--------|-----------|
| S1 | `MC-VPP-Infrastructure/main/terraform/variables.tf` | Add `variable "redisCache01_alert_overrides"` with the right type signature (map of object with all fields optional). | `terraform validate` passes with the new variable; `terraform plan` on current tfvars (without overrides) is no-op. |
| S2 | `MC-VPP-Infrastructure/main/terraform/rediscache.tf` | Add a `locals { redis_alert_defaults = {...}; redis_alerts = {...merge...} }` block. Modify the `module "redisCache01"` call site to pass `redis_alert_configuration = local.redis_alerts`. | `terraform plan -var-file=configuration/{dev,acc,prd}.tfvars -var-file=configuration/{dev,acc,prd}-alerts.tfvars` shows **no changes** for acc and prd (because defaults match module defaults byte-for-byte) and **only** `enabled: true -> false` on `azurerm_monitor_metric_alert.this["used_memory"]` plus name-driven re-creation caveats (see risk below) for dev. |
| S3 | `MC-VPP-Infrastructure/main/configuration/dev-alerts.tfvars` | Append `redisCache01_alert_overrides = { cache_latency = { threshold = 50000 } }`. | `terraform plan -var-file=dev.tfvars -var-file=dev-alerts.tfvars` shows CacheLatency threshold: 15000 -> 50000 and nothing else redis-related. |
| S4 | `MC-VPP-Infrastructure/main/configuration/acc-alerts.tfvars` | Append `redisCache01_alert_overrides = {}`. | Plan no-op for acc Redis alerts. |
| S5 | `MC-VPP-Infrastructure/main/configuration/prd-alerts.tfvars` | Append `redisCache01_alert_overrides = {}`. | Plan no-op for prd Redis alerts. |
| S6 | Per-env apply | dev first, observe 1 week, then acc + prd. | Rootly channel for CacheLatency fires drops to zero on dev within 15 min of apply; acc/prd show no delta in Rootly traffic. |

## Risks

- **R1 — `used_memory` alert recreation vs update.** The Terraform resource name is `azurerm_monitor_metric_alert.this["used_memory"]`, and the Azure resource name is `"UsedMemory-${azurerm_redis_cache.redis_cache.name}"`. Toggling `enabled` should be an **in-place update** (provider handles `enabled` as a PATCH). No resource recreation. Falsifier: `terraform plan` on dev should show `~ resource` (update) not `-/+ resource` (recreate). If recreate appears, something else is drifting; investigate before apply.
- **R2 — Plan shows defaults drift for acc/prd.** If plan on acc/prd shows threshold updates despite overrides being empty, the consumer's local `redis_alert_defaults` mirror has drifted from module v2.5.3 defaults. Falsifier: diff the mirror against `git show v2.5.3:terraform/modules/rediscache/variables.tf`. If so, fix the mirror before apply.
- **R3 — Override schema drift.** Future module version (v2.6+) adds a new alert key or removes one. The consumer's mirror wouldn't know. Mitigation: the inline comment + a PR review checklist item ("did the module bump change default keys?"). Not a runtime risk; only a maintenance one.
- **R4 — Operator picks the wrong dev CacheLatency value.** 50 000 µs is a starting point, not proven. If the underlying workload spikes above 50k for other reasons, the alert will still fire but at a lower rate. Falsifier: one week of Rootly data post-apply. If still ≥1 fire/day, raise further or disable.
- **R5 — Acc/prd also need the CacheLatency bump.** Currently untested. Stefan only complained about dev. If acc/prd have been quiet on CacheLatency, default 15 000 µs is fine. Falsifier: `az monitor metrics alert list` on acc/prd subscriptions filtered by name prefix `CacheLatency` and check the firing history. Can be done pre- or post-apply; doesn't block dev fix.

## Adversarial Challenge (6Qs)

### Q1. What assumption in this plan, if false, breaks the fix?

The load-bearing assumption is: **the consumer's mirror of the module's default map stays byte-exact with v2.5.3**. If it drifts, acc/prd plans will show unexpected threshold changes even with empty overrides. Mitigation: Phase-8 falsifier will diff the mirror against the tag-shipped defaults. Mode: copy-paste from `git show v2.5.3:terraform/modules/rediscache/variables.tf` defaults block and paste verbatim into the `locals.tf` block.

### Q2. What is the simplest alternative we're rejecting, and why?

**Simplest alternative**: "Set `enabled = false` on all noisy alerts in dev via Azure portal; don't touch Terraform." Rejected because (a) it's out-of-band drift that the next `terraform apply` would revert, (b) it doesn't solve the structural ticket (Stefan asked for env-configurable alerts, not a portal hotfix), (c) it doesn't help acc/prd if they ever hit the same issue. The plan above is the **minimum Terraform change** that does solve the structural problem. Anything simpler trades structure for speed and costs re-work.

### Q3. What evidence would disprove the plan?

- If `terraform plan` on acc or prd shows alert changes despite `redisCache01_alert_overrides = {}`, the mirror is broken.
- If apply on dev shows alert **recreation** (not in-place update) on `UsedMemory`, the provider semantics are different from what D5 assumed, and the toggle would briefly leave the alert un-deployed.
- If post-apply Rootly data on dev shows CacheLatency continuing to fire, the 50 000 µs threshold is wrong or there's an underlying workload anomaly.

### Q4. What hidden complexity could bite us?

- **`alert_actions` is still passed per-call.** If a future env-specific override wants to suppress routing (e.g. dev doesn't route to Rootly at all), that's a separate change not covered here. Flag as a follow-up, don't scope-expand now.
- **The module's `name` field is used to construct the Azure resource name**. If someone ever renames a map key in the consumer's defaults mirror (say `used_memory` → `used_memory_abs`) the Azure alert resource won't change its name, but the Terraform state key will. Risk of "resource renamed" → Terraform wants to recreate. Avoid key renames in the mirror.
- **`enable_non_ssl_port` vs `non_ssl_port_enabled` mismatch** between consumer and module `redis_cache_config` schema — noticed during mapping, out of scope for this fix. File a separate ticket.
- **The consumer passes `redis_version = 6`** inline at the module call site, but the module's `redis_cache_config` object also declares `redis_version` as an optional field. Potential double-set. Out of scope; noted for archaeology.

### Q5. What version / existence probes do we need? (≥ 1 executed)

- [EXECUTED] `git tag --contains <alert-commit>` confirmed alert code is present in v2.5.3.
- [EXECUTED] `grep -r 'azurerm_monitor_metric_alert' MC-VPP-Infrastructure/main/terraform/` confirmed no duplicate Redis alert resource already exists outside the module.
- [EXECUTED] Microsoft Learn search confirmed `cachelatency` metric name, unit, aggregation, and `usedmemorypercentage` as the recommended variant.
- [TO EXECUTE at Phase 8] Diff the `locals.redis_alert_defaults` mirror (once written in the spec) against `git show v2.5.3:...`. Done as part of Phase 8 falsifier check.

### Q6. What silent-failure mode passes verification yet wrong?

**The big one**: `terraform plan -var-file=configuration/dev.tfvars` looks clean (only the expected CacheLatency threshold change and the UsedMemory enabled toggle), but because the consumer's `redis_alert_defaults` mirror accidentally omitted a key (say `used_memory_rss`), the deployed state silently drops that alert entirely. Plan output **does** flag it (`- resource destroyed`), but a rushed reviewer could miss it in a long plan.

**Mitigation**: the spec includes a mandatory `diff` command as part of step S2 acceptance: produce `terraform plan -detailed-exitcode` and **manually** compare the list of `azurerm_monitor_metric_alert.this[<key>]` resources pre and post. All 9 keys must be present (even `used_memory`, which should be `enabled = false` not destroyed). This is step S2's falsifier, not a vibes check.

## Downstream consequence (Phase 5 contract)

This plan **directly causes** the Phase 6 spec to:

1. Embed the full v2.5.3 default map verbatim inside a `locals.redis_alert_defaults` block, with the `# Mirrors ...ref=v2.5.3` comment.
2. Include a `diff` command in S2's acceptance criteria (not just "plan is clean").
3. **[REVISED post-F3]** Disable `used_memory` only via `dev-alerts.tfvars`. Original consequence #3 ("consumer-level default disable for all envs") was a scope-expansion silently introduced by D5; corrected after contrarian critique. Spec §2.3 implements the dev-only version.
4. Propose `cache_latency.threshold = 50000` as dev's **only** override in this first iteration, not a larger "tune everything at once" blast.
5. Include a rollback step per commit. **[REVISED post-F5]** Be explicit that the rollback is `terraform apply` of the prior commit, not a magic state restoration; partial-apply failures must be repaired by re-running apply on the target commit.
