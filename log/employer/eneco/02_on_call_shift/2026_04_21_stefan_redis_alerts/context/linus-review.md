---
task_id: 2026-04-21-001
agent: linus-torvalds
status: complete
summary: Spec is mostly sound but the sparse-merge expression is clever-for-no-reason, the "match repo idiom" path was never considered, and two verification steps have real holes.
---

# Linus review — redis-alerts-per-env-fix

Verdict on the whole: **NEEDS WORK**. Ship-able after the SMELLs are addressed. One REFUSE.

## 1. Merge expression (§2.2) — SMELL, not broken

```hcl
field => lookup(var.redisCache01_alert_overrides, key, {})[field]
if   lookup(lookup(var.redisCache01_alert_overrides, key, {}), field, null) != null
```

- `lookup(obj, key, default)` on a typed `map(object(...))` is fine — the outer collection is a map. [CODE-VERIFIED: variables.tf:104 declares `type = map(object(...))`.]
- The inner `lookup(obj, field, null)` where `obj` is an `object(...)` with `optional()` fields: Terraform 1.x accepts this — `optional()` without a default materializes as `null`, and `lookup` on an object is legal in recent versions. **[UNVERIFIED[assumption]: confirmed only by idiom, not by a 1.13.1 dry-run.]** Falsifier: `terraform console` evaluating the expression with a crafted override. Run it. Do not ship on faith.
- **Real defect**: if a tfvars author typos a key (`cache_latecny = { threshold = 50000 }`), the override is **silently dropped** — the outer `for` only iterates `local.redis_alert_defaults`. No plan diff, no error, Stefan's ticket re-opens in a week. **FIX**: add a validation block or a `precondition` asserting `setsubtract(keys(var.redisCache01_alert_overrides), keys(local.redis_alert_defaults)) == []`. Two lines. Non-negotiable.
- The double-`lookup` is cute. One `try(var.redisCache01_alert_overrides[key][field], null)` reads the same and avoids the nested lookup. Not load-bearing; cosmetic.

## 2. Provider 4.40 update-vs-recreate (§5.2) — ACCEPT the hedge, tighten the falsifier

The spec correctly marks this `[UNVERIFIED[assumption]]`. Good — no bullshit confidence. For `azurerm_monitor_metric_alert` v4.40: `enabled`, `severity`, `frequency`, `window_size`, and `criteria[*].threshold` are all `Optional+Computed` (no `ForceNew`) per the provider schema. In-place is the expected path. **[INFER]** from provider schema conventions, not a 4.40 changelog read.

The falsifier in §5.2 ("read plan.dev; `~` = in-place, `-/+` = recreate") IS the right gate. Keep the hedge, keep V4. Do not promote to FACT without running V4 on dev.

## 3. Repo idiom divergence — REFUSE the steelman, but mention why in the PR

The steelman: "define `metric-alert-rediscache.tf` locally like cosmosdb/servicebus, pass `redis_alert_configuration = {}` to disable module alerts." I considered it. **Reject:**

- The module's alerts use `azurerm_monitor_metric_alert` with keyed `for_each` on `module.redisCache01[0].azurerm_monitor_metric_alert.this["<key>"]`. Moving to consumer-defined alerts means **destroy+recreate of all 9 alerts** on apply across dev/acc/prd (state addresses change). That's a bigger blast radius than the fix warrants. [ARCHITECTURE-INFERRED from module structure noted in V5.]
- The module already does the right thing via `for_each`. Mirroring it locally forks semantics; a later module bump fixing a real bug no longer flows.
- Counter: the cosmosdb/servicebus files use different modules (`monitor_metric_alert` single-alert, not a map). They're not the same pattern being violated — they're a different shape. Divergence is already there by module design.

**Action**: add one sentence to the PR description stating this was considered and rejected on recreate-blast grounds, so the next reviewer doesn't re-litigate.

## 4. 80-line mirror in `rediscache.tf` — SMELL

Putting the mirror inline couples two concerns (resource config + defaults mirror) in one file. Extract to `locals-redis-alert-defaults.tf`. Single concern, one-file-per-review-unit, grep-friendly on module bumps. No functional change; pure readability. Cheap. Do it.

## 5. V6 git diff baseline — REFUSE

```bash
git diff --name-only main...HEAD
```

`main...HEAD` (three dots) compares HEAD against the merge-base with main. If the PR targets `develop` or a release branch — or if `main` is stale locally (`git fetch` not run) — this lies. **FIX**:

```bash
BASE="${BASE_REF:-origin/main}"
git fetch origin "${BASE#origin/}" >/dev/null
git diff --name-only "$BASE"...HEAD | sort > /tmp/changed-files.txt
```

Parameterize the base, force a fresh fetch. Otherwise V6 gives false-OK on a stale local main. [CODE-VERIFIED: spec §3 V6.]

## 6. Empty override stanzas on acc/prd (§2.4, §2.5) — ACCEPT, but the spec is wrong about WHY

Spec says: "Without them, `terraform plan` on acc/prd will fail (undeclared variable)." **False.** The variable has `default = {}` (line 111). Omitting the stanza will NOT error — Terraform uses the default. The stanzas are ceremonial: "force a deliberate choice for new envs."

That's a legitimate reason, but stop telling the reader plan will fail. It won't. **FIX**: change §2.5 trailing paragraph to: "These empty stanzas are a convention, not a requirement — Terraform will default to `{}`. We require them so a new-env bootstrapper must make an explicit Redis-alert decision."

## 7. Out-of-scope but flagged — ACCEPT

§6.4 correctly identifies `enable_non_ssl_port` vs `non_ssl_port_enabled` as a separate bug. Do not let it derail this PR. File it now as a separate ticket so it doesn't get lost.

---

**Priority to fix before PR**: #1 (typo-drop validation) and #5 (V6 baseline). Both are real ship-blockers. #4 and #6 are craftsmanship. #2 and #3 are already handled correctly.

**Self-check**: Would I reject this for over-engineering? No. The sparse-merge is 10 lines for a real problem (per-env tuning of a 9-alert module). Equivalent repo-idiom path costs a state-recreate. Complexity is bounded and justified. Ship it after fixes.
