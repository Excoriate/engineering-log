---
task_id: 2026-04-21-001
agent: socrates-contrarian
status: complete
summary: Seven-finding adversarial attack on the per-env Redis alert override plan — scope creep, mirror drift, silent acc/prd behavior change, post-hoc threshold rationalization, rollback fiction, operator UX debt, and a silent-production-break path.
---

# Contrarian Critique — Redis alerts per-env plan

Coordinator owns synthesis. Holes only; no fixes.

## F1. Scope creep: Stefan asked for spam to stop, plan ships a config refactor

(a) Claim: ticket requires both (i) env-tunable overrides AND (ii) retiring absolute-bytes UsedMemory across all envs (D5, consequence #3).
(b) Failure: Stefan asked why Rootly is spamming; he did not ask to change acc/prd behavior. The plan promotes a "cleanup" into a prod change under cover of a dev fix. When acc/prd later misses a real absolute-bytes event the module shipped as defense-in-depth, the post-mortem lands on this PR.
(c) Probe: re-read Stefan's message verbatim. Did he ask for acc/prd behavior to change? If no, plan exceeds mandate.

## F2. The "mirror module defaults in a consumer local" move is load-bearing and under-justified

(a) Claim: D3 — copy v2.5.3 defaults verbatim into `locals.redis_alert_defaults`. Mitigation is an inline comment and a PR-review checklist.
(b) Failure: module bumps to v2.5.4 with a 10th key or tweaked threshold. Consumer never learns. Acc/prd silently drift from module intent while the pin claims `?ref=v2.5.4`. Checklist-as-mitigation is theater; in six months nobody remembers it. `git blame` hides inline comments. Every future bump requires a two-repo manual diff. D3 dismisses "expose defaults as a module output" in one sentence without weighing permanent mirror maintenance cost.
(c) Probe: search the org for other consumers of `?ref=v2.5.3`. If all mirror, cargo-cult; if none do, this plan invents a novel pattern.

## F3. `used_memory.enabled = false` consumer default contradicts the plan's own falsifiers

(a) Claim: consequence #3 says all three envs drop UsedMemory by default. S4/S5 falsifiers say "plan no-op for acc/prd Redis alerts."
(b) Failure: cannot both be true. If consumer default disables `used_memory` and acc/prd pass `{}`, acc/prd plans show `~ enabled: true -> false` on `UsedMemory-*`. Either (i) S4/S5 falsifiers will fail and reviewer trusts a check that can't hold, or (ii) the real design routes re-enable via env override and D5 is misdescribed. The plan contradicts itself — this is the silent-fail Q6 claims to catch.
(c) Probe: mentally execute S2+S4 with acc's empty override. If plan shows `~ enabled` on `azurerm_monitor_metric_alert.this["used_memory"]`, invariant is violated by design.

## F4. 50 000 µs is post-hoc rationalization, not a threshold

(a) Claim: D4 — "3× observed max is a reasonable signal." R4 concedes it is "not proven."
(b) Failure: Stefan said "metrics is getting back to the initial state" — the 7–17k band is recovery from anomaly, not steady state. If baseline returns to 3–5k, 50k is 10–15× headroom and the alert becomes decorative. "3× observed max over 7 days during a known anomaly" is numerology — no SLO reference, no percentile reasoning, no severity correlation. Disable-in-disguise framed as a threshold.
(c) Probe: pull 30 days of CacheLatency on dev-mc via `az monitor metrics list`. Compute p50/p95/p99. If p99 < 10k in a normal week, 50k is admitting "make it quiet."

## F5. Rollback story is `terraform apply` of the previous commit — not a real rollback

(a) Claim: consequence #5 — "rollback step per commit (`terraform apply` the previous commit)."
(b) Failure: S2 applies partially. Five of nine alerts update in-place, one hits ARM throttling, state is mixed. Re-applying the prior commit does not deterministically restore pre-S2 Azure state — provider drift + `for_each` key churn can leave orphans or force recreates where updates were intended. R1 covers `enabled` as PATCH in the happy case but never partial-apply failure mid-map. "Bisectable" describes git history, not Azure state.
(c) Probe: if apply errors on alert #4 of 9, what is the observable end state and which commit's apply restores it? If the answer requires manual `terraform state rm` / import, the rollback claim is fiction.

## F6. Operator UX in six months: `redisCache01_alert_overrides` is undiscoverable

(a) Claim: D2 — overrides live in `configuration/*-alerts.tfvars` per repo convention.
(b) Failure: an operator editing `dev-alerts.tfvars` six months out sees `redisCache01_alert_overrides = { cache_latency = { threshold = 50000 } }`. To know valid keys they must read `rediscache.tf` locals (hidden mirror), cross-ref `Eneco.Infrastructure@v2.5.3`, and grok `merge()` semantics. No schema discoverability; no validation on typo (`cachelatency` silently no-ops). Every other `metric-alert-*.tf` here uses direct tfvars-to-resource wiring — this is the only one wedging a mirror in between.
(c) Probe: show the tfvars line to a teammate and ask "what keys are valid, what fields, what happens on typo?" If >60 seconds from the repo alone, UX is debt.

## F7. Silent production break: plan passes its own falsifiers yet leaves acc/prd subtly worse

(a) Claim: S4/S5 are "plan no-op"; Q6 mitigation requires all 9 keys present in the mirror.
(b) Failure: mirror is keys-complete and thresholds-byte-exact, so acc/prd plans look clean — EXCEPT the `enabled: true -> false` flip on UsedMemory (see F3). Reviewer approves "one tiny enabled flip, matches end-state." Two months later acc's cache crosses 200 MB during an unrelated workload; absolute-bytes signal is off, percentage version (85% of 6 GB ≈ 5.1 GB) stays silent because the workload is nowhere near 5 GB. Early-warning layer disappears while every falsifier says PASS. Q6's "all 9 keys present" doesn't catch this — `enabled=false` is "present." The falsifier suite validates structure, not semantics.
(c) Probe: for acc and prd, name one failure mode `UsedMemory@200MB` catches that `AllUsedMemoryPercentage@85%` does not. "None, redundant" → D5 holds. "Leak detection / early-warning at low absolute values" → disabling by default costs a real signal on envs never in scope.

---

Seven holes. Coordinator decides which land.
