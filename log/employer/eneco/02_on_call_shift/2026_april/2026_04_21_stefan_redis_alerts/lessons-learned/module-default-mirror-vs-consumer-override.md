---
task_id: 2026-04-21-001
agent: claude-code
status: complete
type: finding
summary: Terraform-module pattern — when a module ships a full-map input default (no deep-merge inside the module), the consumer must pass a complete map to override any single entry. Document the mirror; don't silently inherit.
---

# Lesson — full-map defaults force a consumer-side mirror

Pattern: a Terraform module declares `variable "X" { type = map(...); default = {9 entries} }` and uses it as `for_each = var.X`. The for_each evaluation does NOT deep-merge — whatever the consumer passes (or the default, if nothing is passed) becomes the complete set.

Consequence: to override one entry's threshold, the consumer must pass all 9 entries. Sparse override at the module is structurally impossible.

Resolutions, ranked:

1. **Consumer mirrors the defaults** and merges per-key with a sparse override variable. Pro: no module change. Con: mirror drift risk on module bump. Used in this task.
2. **Module exposes defaults as output** (`output "redis_alert_configuration_defaults" { value = var.redis_alert_configuration }`) so consumers can source-of-truth from the module without copying. Pro: no drift. Con: module change required; doesn't help until bumped.
3. **Module adds a deep-merge override variable** (`variable "overrides" { default = {} }`; internal `locals { merged = merge_deep(defaults, overrides) }`). Pro: cleanest consumer UX. Con: biggest blast radius — all consumers must migrate; deep-merge semantics are bug-prone.

The right choice depends on how many consumers the module has. Small → change the module. Many → have the one needy consumer mirror; later propose the module output.

## Rule for writing new modules

If a module ships an input with a non-trivial default, also ship that default as an output. Tag the output with the module ref it applies to. Cost: one line of HCL. Benefit: every future consumer that needs per-env tuning can use `merge(module.X.defaults, var.my_overrides)` without mirroring.
