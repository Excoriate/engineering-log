---
task_id: 2026-04-21-001
agent: apollo-assurance-marshal
status: complete
summary: Grade of the Redis-alerts fix artifact set. Overall CONDITIONALLY_ASSURED — spec is implementable, resolves the F3 contradiction, but leaves three load-bearing claims externally unverified and carries plan-vs-spec drift the reader will notice.
---

# Evaluator Report — Redis alerts fix artifact set

Verdict key: PASS = meets grading criterion; PARTIAL = meets with named gap; FAIL = does not meet.

## Axis 1 — Did the spec solve the user's actual question?

**PARTIAL.** Alex can execute §0–§4 without further Claude help: preconditions are shell-runnable, §2 diffs are concrete file:line level, §3 has per-env expected outputs, PR template included. He will get stuck in exactly three spots:

- **§3 V5 path drift**: the command `cd /Users/.../eneco-src/eneco-temp/Eneco.Infrastructure` points to a repo root that was never confirmed in maps — `codebase-map.md` and the preconditions only name `enecomanagedcloud/myriad-vpp/MC-VPP-Infrastructure`. If `eneco-temp/Eneco.Infrastructure` doesn't exist on his disk, V5 fails before running.
- **§3 V2/V3 grep regex**: `'azurerm_monitor_metric_alert\.this\["(all_|cache_|errors|used_|)'` — the trailing empty alternation `|)` matches any character, so `|| echo "OK"` fires even on real changes. Alex will catch it (principal engineer), but the check as written is not a real falsifier.
- **§2.1 line number guidance**: "around line 616" is advisory but the consumer's `variables.tf` structure was never fully mapped; he'll skim to confirm. Low friction, but still a manual resolve.

Missing piece: no pointer to which branch to cut the PR from, and no reference to the repo's pre-commit chain beyond naming `tflint` abstractly.

## Axis 2 — Evidence chain integrity

**PARTIAL.** Load-bearing claims and anchors:

| Claim | Anchor | Status |
|---|---|---|
| Module v2.5.3 ships 9 alerts with listed defaults | `git show v2.5.3:...variables.tf` (F-A) | VERIFIED-ARTIFACT (CLAIMED until F-A actually re-run in Phase 8) |
| Consumer doesn't pass `redis_alert_configuration` | grep command in P0.1 | VERIFIED-ARTIFACT |
| SKU per env (dev Standard, acc/prd Premium) | tfvars grep P0.2 | VERIFIED-ARTIFACT |
| Portal threshold = module default byte-for-byte | "visual inspection of supplied screenshots" | CLAIMED — no screenshot path cited in spec; unverifiable from spec alone |
| MS recommends percentage over absolute UsedMemory | URL in `ms-learn-redis-metrics.md` Fact 2 | VERIFIED-ARTIFACT |
| `enabled` is an in-place PATCH | R1 narrative, no provider-version cite | EXTERNAL_UNVERIFIED — "should be" language, no azurerm changelog |
| 50 000 µs "3× headroom over observed max" | `image (3).png` band 7k–17k | CLAIMED — image not rendered in spec; reader can't audit |

Rests on nothing: the PATCH-vs-recreate claim for `enabled` toggle (R1), and the dev CacheLatency observed band (no exported metric series, only screenshot reference).

## Axis 3 — Requirement-to-evidence traceability (A1–A7 vs §3 V1–V5)

**PARTIAL.**

| AC | Covered by | Verdict |
|---|---|---|
| A1 (per-env tfvars flow; dev changes, prd doesn't) | V2, V3, V4 | PASS |
| A2 (UsedMemory disabled in consumer, not deleted) | V4 expects `enabled: true -> false` on dev | **GAP** — A2 says "disabled **by default in the consumer**"; spec disables only in dev-alerts.tfvars. See Axis 6. |
| A3 (CacheLatency raised in dev only) | V4 | PASS |
| A4 (module unchanged, `?ref=v2.5.3` stable) | P0.1 | PASS |
| A5 (`terraform fmt/validate/tflint` pass) | V1 covers fmt+validate, **tflint absent** | PARTIAL |
| A6 (diffs touch only one variables.tf, one rediscache.tf, three *-alerts.tfvars) | not verified by any V-step | **GAP** — no falsifier asserts file scope |
| A7 (diagnosis in conversational register, ≥1 ASCII diagram, falsifier block) | diagnosis.md self-evidences | PASS for diagnosis; spec's V-steps don't test it |

Two untested acceptance criteria: A5 (tflint) and A6 (file-scope invariant).

## Axis 4 — Residual risk the spec doesn't address

**FAIL** on coverage of operational risks:

1. **Live state vs IaC drift** — spec never runs `az monitor metrics alert list` or `terraform plan -refresh-only` to confirm Azure state matches v2.5.3 defaults *today*. Diagnosis §Falsifier 2 acknowledges this; spec does not carry it forward. If a prior operator hand-tuned a threshold in the portal, `terraform apply` will silently revert it.
2. **Concurrent PR to the module** — P0.3 checks for an in-flight `redisCache01_alert_overrides` variable but not for an in-flight module bump PR. If someone merges `?ref=v2.5.4` between Alex's branch-cut and merge, the mirror goes stale on merge.
3. **Rootly routing rules for the disabled alert** — spec §4.1 says "verify portal shows Disabled." Doesn't address whether Rootly has a saved routing rule for `UsedMemory-vpp-rediscache01-d` that will orphan on the Rootly side. Stefan's original complaint was Rootly-side spam; spec doesn't close the Rootly-side loop.
4. **Action-group blast radius** — `alert_actions = { "rootly" = ... }` continues to route other alerts through the same action group; no check that disabling `used_memory` doesn't cascade to other consumers of that action group.
5. **Redis connection string rotation** — out of this spec's domain, but if the cache is recreated (R1 pathological path), connection strings rotate and dependents break. §5.2 dismisses recreation as "won't happen"; no explicit guard.

Spec acknowledges only risks R1–R5 in the plan (mirror drift, threshold guess, key rename). Operational surface above is not addressed.

## Axis 5 — Diagnosis register

**PASS.** `outcome/diagnosis.md` opens with "Stefan's framing is right," carries an ASCII diagram at §"The shape", a paired-invariant table at §"Failure ↔ success, paired", a named-falsifier block with three checks, and an honest "What's still Unknown" section. Confidence `~90%` is stated with what the 10% actually is. Register matches user's stated preference.

Minor noise: line 77 has meta-narration ("I almost wrote a fix that disabled it everywhere by default; the contrarian pass caught that") — conversational, but a ruthless editor would cut the self-reference.

## Axis 6 — Contradiction check

**PARTIAL.**

- **F3 resolution**: the spec's `local.redis_alert_defaults` at line 214 keeps `used_memory.enabled = true` (module default), and only dev-alerts.tfvars line 328 flips it to `enabled = false`. So acc/prd plans ARE no-op. F3 contradiction RESOLVED in the spec.
- **New plan-vs-spec contradiction introduced**: `plan/plan.md` §D5 says "**Disable by default**, not raise" and §"Downstream consequence" #3 says "Pre-populate `used_memory.enabled = false` as a **consumer-level default** … so all three envs drop that alert by default." The spec does NOT do this — it's an env-level override only. The plan's own acceptance language contradicts the spec. A principal reviewer reading both will flag this.
- **Diagnosis-vs-spec**: diagnosis line 77 says "this is why the fix's per-env override disables `used_memory` on **dev only**" — matches spec. Diagnosis and spec are consistent; plan is the stale one.

Spec is correct; plan body was not updated post-contrarian.

## Axis 7 — Honest uncertainty

**PASS with one lapse.** Spec §6.2 explicitly labels 50 000 µs as "a guess … clearly a starting bid, not a design claim." Diagnosis reserves 10% for operator-judgment space. `ms-learn-redis-metrics.md` names two explicit `[UNVERIFIED[unknown]]` items (no MS-published threshold for cacheLatency; preview stability). §6.1 flags mirror drift honestly.

Lapse: R1's "No resource recreation. Falsifier: plan shows `~` not `-/+`." is presented as mechanism-known when it's provider-version-dependent. Should be `[UNVERIFIED[assumption: azurerm toggles `enabled` as PATCH on this provider version]]`. No changelog cited.

---

## Top-3 residual risks (pre-ship)

1. **Plan/spec contradiction on `used_memory` default** (Axis 6) — reviewer reads plan D5 + consequence #3, expects consumer-level disable, sees env-level override in spec. Either refresh the plan to match spec, or add a one-line note at plan §D5 saying "superseded by spec §2.3 after contrarian pass F3."
2. **Portal drift unverified before apply** (Axis 4.1) — `terraform apply` will silently revert any hand-tuning. One `az monitor metrics alert list -g <rg>` call before PR merges closes this.
3. **A2/A5/A6 untested by the spec's own falsifiers** (Axis 3) — tflint not run, file-scope not asserted, A2's "consumer default disabled" contradicted by A6's interpretation in Axis 6.

## Recommendation before shipping the PR

Run the live-state probe: `az monitor metrics alert list --resource-group <redis-rg-dev> --query "[?contains(name, 'rediscache01-d')].{name:name, enabled:enabled, threshold:criteria.allOf[0].threshold}" -o table`, paste output into the PR description as the "portal state at PR cut" anchor. Closes Axis 2's "portal = module default" CLAIMED claim, neutralizes Axis 4.1's silent-revert risk, and costs 30 seconds. Everything else in the spec is good enough to ship.

**Verdict: CONDITIONALLY_ASSURED.** Ship after (a) plan/spec reconciliation on F3 aftermath and (b) the live-state probe above.
