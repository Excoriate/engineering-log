---
task_id: 2026-04-21-001
agent: simplicity-maniac
status: complete
summary: Four braids in the spec; the dominant one is the consumer mirroring module-internal default data to recover override capability the module's variable shape denies — accidental, not essential.
---

# Simplicity Audit — redis-alerts-per-env-fix

Doctrine: Hickey "Simple Made Easy", Moseley-Marks "Out of the Tar Pit".

## Braid 1 — The mirror complects "module default" with "consumer tunable surface"

(a) **Complected**: `locals.redis_alert_defaults` (§2.2) fuses three concepts into one blob: (i) the module's *internal* default Value for each alert field, (ii) the consumer's *authoritative* source of truth for those fields at plan time, (iii) the schema of override-eligible knobs. Value + Identity + Authority in one 120-line literal.

(b) **Dissolved counterfactual**: the module exposes a `redis_alert_configuration_defaults` output (spec §6.1.3 names this); consumer reads the output and overrides it. Defaults stay owned by the module; consumer owns only the *delta*. Mirror disappears; so does V5; so does the "concurrent module bump" risk in §5.5. The data lives once, where it is defined.

(c) **Verdict**: ACCIDENTAL. The spec itself names the dissolution path and labels it out of scope. The braid exists because the module's `variable "redis_alert_configuration"` fused *defaults* with *input contract* — the consumer cannot override one field without restating all nine entries. The mirror is the consumer paying interest on the module's original complection. Accepting it for this PR is defensible; calling it essential is not. [DOCTRINE-ANCHORED: Rule 2 — ease purchased by duplication, bill arriving later.]

## Braid 2 — The nested `for` + double `lookup()` merge expression

(a) **Complected**: §2.2's `for key, base in … : key => merge(base, { for field in [...] : field => lookup(…)[field] if lookup(lookup(…), field, null) != null })` fuses four concerns in one expression: (i) per-key iteration, (ii) per-field iteration, (iii) field-presence detection, (iv) sparse-merge policy. Logic + Control + Value-absence semantics braided so tightly that changing any one (e.g. adding a sixth override-able field) requires reading all four.

(b) **Dissolved counterfactual**: Terraform's type system already encodes presence — every field in `var.redisCache01_alert_overrides`'s object is `optional()`, so an unset field is `null`. The whole `if lookup(lookup(...), field, null) != null` machinery exists only because `merge()` would overwrite `base` with explicit `null`s. A plain `merge(base, { for k, v in lookup(var.…, key, {}) : k => v if v != null })` removes one nested lookup and the hard-coded field list. The hard-coded list `["enabled", "threshold", ...]` duplicates information already in the `variable` type signature — a second mirror.

(c) **Verdict**: ACCIDENTAL. This is Anti-Pattern 9.12 (compression hiding fold-count): the double-lookup looks like "one expression" but carries four concepts. Refuse.

## Braid 3 — `redisCache01` vs `redisCache01_alert_overrides` as sibling variables

(a) **Complected**: two top-level inputs describe *one logical thing* (this Redis cache's configuration). Identity of the cache is smeared across two variables that must be kept in name-sync (`redisCache01` ↔ `redisCache01_alert_overrides`). A second cache would require `redisCache02` + `redisCache02_alert_overrides`, doubling the naming contract.

(b) **Dissolved counterfactual**: one variable `redisCache01 = { sku_name=…, capacity=…, alert_overrides={…} }`. Identity lives once; override map is a field of the cache, not a sibling of it.

(c) **Verdict**: ACCIDENTAL but LOW-PRIORITY. Dissolving requires touching `variable "redisCache01"` (§2.1 declines to, explicitly). Orthogonal to Stefan's ticket. Name it; do not act on it here.

## Braid 4 — `acc-alerts.tfvars = {}` / `prd-alerts.tfvars = {}` as "forced deliberate choice"

(a) **Complected**: §2.5 justifies the empty stanzas as "forces anyone creating a new env to make an explicit choice." That fuses *data* (this env has no overrides) with *process enforcement* (new-env authors must think). Terraform's `default = {}` (§2.1) already encodes "no override = module defaults" — the empty stanza restates what the type system says.

(b) **Dissolved counterfactual**: drop the empty stanzas. Process enforcement lives in the PR-review checklist, not the tfvars file. Data stays data.

(c) **Verdict**: ACCIDENTAL. Rule 5: information should be plain data at boundaries, not a pedagogical device.

## Summary

One essential-complexity concession (Braid 1, forced by the module's own design), three accidental complections the spec could shed without touching the module. The spec's §6.1 caveat is honest about Braid 1's cost but papers over Braids 2–4.

Handoff: structural redesign of the override surface → `architect-kernel`. Module-side fix (expose defaults output) → separate ticket.
