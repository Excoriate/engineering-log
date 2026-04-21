---
task_id: 2026-04-21-002
agent: claude-code
status: complete
summary: Two-repo implementation plan for Redis alert override fix — module v2.5.4 adds native override support, consumer bumps ref and supplies sparse per-env overrides.
---

# Plan — Redis alert overrides (two-repo implementation)

## Scope divergence from spec

The referenced spec (`redis-alerts-per-env-fix.md`) chose a **consumer-only** approach with a local mirror of module defaults (spec §2.2a) because changing the module was deemed out-of-scope. The user has now chosen the **proper** two-repo fix: the module gains native override support in v2.5.4, the consumer references v2.5.4 and supplies sparse overrides. This eliminates the mirror drift risk (spec §6.1) entirely.

## Module side — Eneco.Infrastructure v2.5.4

Worktree: `.../Eneco.Infrastructure/2026-04-21-ootw-redist-alert-override`

Existing state (FACT):
- `terraform/modules/rediscache/variables.tf:85-288` — `redis_alert_configuration` has 9-alert default baked in.
- `terraform/modules/rediscache/main.tf:52-53` — `for_each = var.redis_alert_configuration`.

Changes:
1. `variables.tf` — append new variable `redis_alert_configuration_overrides` with sparse schema (5 optional fields: enabled, threshold, severity, frequency, window_size) + 4 validations (severity range, frequency ISO 8601, window_size ISO 8601, unknown-key guard).
2. `main.tf` — add `locals` block that strips null fields from overrides and merges onto `var.redis_alert_configuration`. Change `for_each` from `var.redis_alert_configuration` to `local.redis_alert_configuration_final`. Add `lifecycle.precondition` to enforce unknown-key guard (belt-and-braces with the validation block).

Backward compatibility: any caller passing their own `redis_alert_configuration` continues to work exactly as before; if they also pass `redis_alert_configuration_overrides`, the overrides merge on top of their map. Empty `redis_alert_configuration_overrides` (the default) = current behavior preserved.

## Consumer side — MC-VPP-Infrastructure

Worktree: `.../MC-VPP-Infrastructure/2026-04-21-ootw-redist-alert-override`

Note: this worktree's paths are `terraform/…` and `configuration/…` (no `main/` prefix the spec uses — the spec was written against a different layout convention).

Changes:
1. `terraform/rediscache.tf:2` — bump ref `v2.5.3` → `v2.5.4`.
2. `terraform/rediscache.tf` — add one line to the `module "redisCache01"` block: `redis_alert_configuration_overrides = var.redisCache01_alert_overrides`.
3. `terraform/variables.tf` — insert new variable `redisCache01_alert_overrides` right after the existing `redisCache01` block (line 630) for locality. Sparse schema + validation guarding typos against the 9 known keys.
4. `configuration/dev-alerts.tfvars` — append override stanza (cache_latency=50000, used_memory.enabled=false).
5. `configuration/acc-alerts.tfvars` — append explicit empty override stanza.
6. `configuration/prd-alerts.tfvars` — append explicit empty override stanza.

No mirror file is created (removes spec §2.2a drift risk).

## Adversarial Challenge

- **Q1 (assumption, failure mode):** "Adding a new variable with `default = {}` is backward-compatible." FAILURE MODE: any caller currently passing `redis_alert_configuration_overrides` with a different schema would break. Probe: module is internal to Eneco; only MC-VPP-Infrastructure is known to consume. No existing `_overrides` pattern in this module. RESIDUAL: undiscovered external consumer. Acceptable — new variable name is unique enough that collision is implausible.
- **Q2 (simplest alternative):** Inline the merge in the consumer (spec's original approach). REJECTED: drift risk, duplication across any future consumer.
- **Q3 (disproving evidence):** If the module were already planning a different override scheme. Probed: git log on rediscache module shows no in-flight override work.
- **Q4 (hidden complexity):** Validation cross-variable reference for "unknown key guard". Terraform 1.9+ supports cross-var validation; to avoid version-dependency, implemented as a `lifecycle.precondition` on the resource (TF ≥ 1.2 supports this), which also happens at plan time.
- **Q5 (version/existence probe, executed):** `git tag --sort=-v:refname` on Eneco.Infrastructure returned v2.6.1 as latest. User's target tag v2.5.4 does not exist yet; will be cut at merge. This is a user-side concern, not a coordination risk for the code.
- **Q6 (silent failure — pass verification yet wrong):** Override validation on the new variable is silent unless caller misuses it. Mitigation: `contains(keys(var.redis_alert_configuration), k)` validation on the override variable fails at plan with a descriptive message listing valid keys.

**Downstream consequence:** Q4 changed the implementation — cross-variable validation moved to `lifecycle.precondition` for broad TF compatibility. Q6 added the unknown-key validation to the override variable AND a precondition on the resource (belt-and-braces).

## Verification (delegated to user)

User runs `terraform plan` per env after merge of Eneco.Infrastructure PR + cutting v2.5.4 tag. Expected plans match spec §3 V2/V3/V4 (no-op on acc/prd; two in-place updates on dev: cache_latency threshold and used_memory enabled).
