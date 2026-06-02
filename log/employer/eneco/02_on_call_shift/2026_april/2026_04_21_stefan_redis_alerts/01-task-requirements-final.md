---
task_id: 2026-04-21-001
agent: claude-code
status: complete
summary: Phase-3 final requirements with falsifiers and Verification Strategy. Materially differs from initial — moves from one-alert framing to two-alerts + a retire/replace decision; locates the fix entirely on the consumer side; introduces success-counterpart pairing for each break.
---

# 01 — Task Requirements (final)

## Material changes vs the initial requirements

| Initial framing | Final framing | Reason for change |
|-----------------|---------------|-------------------|
| "Spam comes from one alert" | Two alerts misbehave in different ways: **CacheLatency** is the actual Rootly fire generator (10+ fires Apr 17–21); **UsedMemory** is chronically firing at the portal level (455 MB > 200 MB) — Stefan flagged it qualitatively. Both must be addressed. | `image.png` (Rootly fires only show CacheLatency), `image (1).png` (UsedMemory portal state), Stefan's Friday review notes in the thread. |
| "Module needs env-aware defaults" | **Module is fine as-is.** It already exposes `redis_alert_configuration` as a typed, validated input. The fix is purely on the consumer side — wire env-tunable overrides into the consumer call. | `git show v2.5.3:terraform/modules/rediscache/variables.tf` shows the input variable + 9 defaults; module-side change would be over-engineering. |
| "Only dev is affected" | Absolute-bytes UsedMemory threshold (200 MB) is brittle on **every** env (dev C2 = 8% capacity, acc/prd P1 = 3%). dev only happens to be currently above 200 MB. acc/prd will spam too once their caches hold meaningful data. | Microsoft Learn pricing page on Standard/Premium memory caps + capacity setting in tfvars (F1, F2). |
| "Add an `alert_overrides` map" | Two-part fix: (a) make the alerts env-overridable via the consumer; (b) retire the redundant absolute-bytes UsedMemory alert in favor of the working percentage-based AllUsedMemoryPercentage. The "tunable" capability is necessary but not sufficient — without (b) the next operator inherits the same brittleness. | Pairing failure with success counterpart: percentage version sits at 18.6% with 85% threshold and never fires (`image (2).png`); absolute version fires whenever the cache holds modest data. The fix that respects "X is broken because Y" must specify what working-Y looks like. |

## What the user explicitly asked for

> "I want a clear diagnosis, and a proposed document with the fix, step by step,
>  so I can inspect it, understand it, and implement it by me."

Two artifacts:

1. **Diagnosis** (`outcome/diagnosis.md`) — conversational, with diagrams. Explains the mechanism end-to-end, surfaces all assumptions, names falsifiers, and gives Stefan's question a calibrated answer.
2. **Fix spec** (`specs/redis-alerts-per-env-fix.md`) — concrete, file-by-file, with exact diffs and per-env tfvars values. Alex implements himself; we don't edit either repo this session.

Bonus (not asked but standard practice in this skill): a sober Slack reply stub (`outcome/slack-reply.md`) that Alex can copy into the thread — confidence is high enough (≥ 70%) that artifact (c) is appropriate.

## Out of scope — explicit

- Editing `Eneco.Infrastructure` or `MC-VPP-Infrastructure` source.
- Touching the Azure portal directly. The fix flows through Terraform.
- Designing a new alert (e.g., a Standard-tier cache warming policy). The ticket is "make existing alerts behave"; we tune what exists.
- Tuning the *other* six alerts that aren't currently misbehaving (AllConnectedClients, AllPercentProcessorTime, AllServerLoad, CacheRead, Errors, UsedMemoryRSS). They're either tier-relative (percentage) or weren't flagged by Stefan. They should pass through with module defaults until evidence says otherwise.
- Posting to Slack. We draft; the user posts.
- Investigating *why* CacheLatency briefly spiked Apr 13–18. Stefan said "the metrics is getting back to the initial state" — that's a separate capacity/workload question, not an IaC question.

## Acceptance — what "the fix is correct" means

Numbered for Phase 8 falsifier execution.

A1. The Redis-alert thresholds in `MC-VPP-Infrastructure` flow through per-env tfvars; changing dev's `cache_latency.threshold` value (e.g. from 15000 to 50000) appears in `terraform plan -var-file=configuration/dev.tfvars` and **does not** appear in `terraform plan -var-file=configuration/prd.tfvars`.

A2. The `UsedMemory` alert is **disabled by default in the consumer** in favor of `AllUsedMemoryPercentage`. (Disabled, not deleted, so the per-env override layer can re-enable it for any env that needs it.)

A3. The `CacheLatency` threshold in dev is raised to a value that does not fire under normal Standard-tier load. Acc/prd remain at the module default (15 000 µs). dev value to be set by the operator informed by `image (3).png`'s observed band — the fix doc proposes a starting value but the user owns the final number.

A4. Module v2.5.3 is **not** changed. The `?ref=v2.5.3` pin in the consumer is **not** changed. The fix is module-version-stable.

A5. `terraform fmt`, `terraform validate`, and `tflint` (or whatever the repo's pre-commit chain runs) all pass on the proposed diffs.

A6. The proposed diffs touch only: one `variables.tf`, one `rediscache.tf`, three `*-alerts.tfvars`. No other files.

A7. The diagnosis document is written in conversational register (the ruthless-systems-thinker voice the user prefers), not compliance-document register. It includes at least one ASCII diagram, the success-counterpart pairing, and a named falsifier block.

## Falsifiers (Phase 8 will execute these)

Each falsifier names: action → expected if our model holds → meaningfully different observation if our model is wrong.

- **F-A**: Read `git show v2.5.3:terraform/modules/rediscache/variables.tf` again and confirm `redis_alert_configuration` is a `map(object(...))` with the 9 keys and thresholds we listed in `codebase-map.md`. → expected: byte-identical; → if a 10th key exists or thresholds differ, our default-value table is stale and the fix doc must be amended.
- **F-B**: Read `MC-VPP-Infrastructure/main/terraform/rediscache.tf` again and confirm the consumer does **not** pass `redis_alert_configuration` to the module. → expected: only `alert_actions` is passed; → if `redis_alert_configuration` is already passed, then someone partially fixed this and our spec must rebase on top of their work.
- **F-C**: For each of the three Azure portal screenshots, the threshold visible in the portal must equal the default in v2.5.3. → expected: matches (already cross-validated in `codebase-map.md`); → if a portal value diverges, there is portal drift and the fix doc must add an explicit step to acknowledge/import that drift.
- **F-D**: SKU per env. `dev.tfvars:659 sku_name = "Standard"`, `acc.tfvars:567 sku_name = "Premium"`, `prd.tfvars:859 sku_name = "Premium"`. → expected: matches; → if any has changed (e.g. dev was bumped to Premium between ticket filing and now), the "Standard is the brittle case" framing requires reframing.
- **F-E**: The `azurerm_monitor_metric_alert.this` block in v2.5.3 main.tf uses `for_each = var.redis_alert_configuration`. → expected: yes (sparse override merging is impossible at the module — every alert key must appear in the map for the alert to exist). → if instead the module merges defaults internally, the consumer fix can use sparse overrides without rebuilding the full map.

## Verification Strategy

Per-claim verifier, named owner, named tool.

| Claim | Verifier | Tool / command | Owner |
|-------|----------|----------------|-------|
| The 9 default alerts are exactly as documented | re-read tagged variables.tf | `git show v2.5.3:terraform/modules/rediscache/variables.tf` | Phase 8 (claude) |
| Consumer doesn't pass `redis_alert_configuration` today | re-read consumer call site | `grep -n redis_alert_configuration MC-VPP-Infrastructure/main/terraform/rediscache.tf` (must return nothing) | Phase 8 |
| SKU matches per env | re-read tfvars at named line | `sed -n '..p' configuration/{dev,acc,prd}.tfvars` | Phase 8 |
| Portal thresholds match module defaults | visual inspection of supplied screenshots | by hand | already done |
| Proposed Terraform parses + plans cleanly | dry run | `terraform fmt -check && terraform validate && terraform plan -var-file=configuration/dev.tfvars` (per env) | **operator (Alex)** at apply time — out of this session's scope |
| Proposed plan touches only the targeted alerts | inspect plan output | as above | operator |
| dev plan changes; prd plan does not (for the alerts we override) | per-env diff | `diff` of plan summary lines | operator |

The first four verifiers are deterministic and run in this session (Phase 8). The last three are the operator's checks at implementation time and are baked into the fix spec.

## Confidence (refined; will be re-stated in the diagnosis)

**~90 %.** Mechanism is fact-anchored (module defaults match portal byte-for-byte; consumer skips overrides; SKU disparity confirmed). The remaining 10 % is operator-choice space (what threshold values to set for dev, whether to disable UsedMemory entirely vs. re-tune it, whether to apply via a PR or a hot-fix), not factual gaps. Spec proposes defaults; user decides.
