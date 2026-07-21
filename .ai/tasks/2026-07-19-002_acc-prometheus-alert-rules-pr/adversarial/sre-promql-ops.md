---
task_id: 2026-07-19-002
agent: sre-maniac
timestamp: 2026-07-19T00:00:00Z
status: complete
summary: |
  Adversarial operational review of proposed DispatcherOutputHealthZero alert.
  VERDICT: DO-NOT-SHIP as written. The absent arm fires immediately and
  permanently (24/7 CRITICAL self-DoS) because dispatcher_output_health is
  currently emitted by ZERO series in the target Prometheus. Secondary: the
  two `or` arms emit DIFFERENT label sets, so a flap between present-0 and
  absent changes the alert series identity and RESETS the for:2m timer ->
  missed page during a crash-loop, plus broken silences/dedup. Also: double
  dwell (avg_over_time[2m] + for:2m ~= 4m latency) and float-brittle `== 0`.
  Merge precondition: metric must be confirmed live-emitting before the absent
  arm ships. Safe form provided (unified label sets, instant gauge, <= 0).
---

# Adversarial SRE Review — `DispatcherOutputHealthZero` (Activation mFRR)

## Key Findings

- FM1: absent arm fires now/permanently because metric never instrumented (DO-NOT-SHIP)
- FM2: label-set mismatch between or arms resets for:2m timer on flap -> missed page + broken silences
- FM3: avg_over_time[2m] + for:2m double dwell -> ~4m detection latency on time-critical mFRR
- FM4: exact == 0 on a gauge is float-brittle -> missed page
- FM5: partial replica loss (1 of N) invisible to both arms

Lane: operational failure modes (false-page / missed-page / for-timer / routing).
Not code style. Not other reviewers' lanes.

## Verdict

**DO-NOT-SHIP as written.** Ship only after (a) the merge precondition below is
met and (b) the expression is replaced with the unified-label form. With those
two changes: SHIP-WITH-GUARDS.

## Targets under attack

- CURRENT (committed): `avg_over_time(dispatcher_output_health{exported_job="Activation mFRR"}[2m]) == 0`
- PROPOSED: `... == 0 or absent_over_time(dispatcher_output_health{exported_job="Activation mFRR"}[2m]) == 1`
- LIVE FACT (given): selector matches **0 series today**; metric emitted by no
  dispatcher build. `exported_job="Activation mFRR"` carries 114 *other* series.

## PromQL semantics this review rests on (A1 — Prometheus spec)

- `absent_over_time(sel[2m])` returns a **single series labelled only with the
  equality matchers** in the selector -> `{exported_job="Activation mFRR"}`, and
  only when the selector matched **zero** samples in the window. Given the live
  fact, it returns **1 right now** and will keep returning 1 until the metric flows.
- `avg_over_time(sel[2m])` **preserves the full source label set**
  (`instance`, `pod`, `exported_instance`, ...).
- `or` returns all LHS series plus RHS series whose label signature does not
  appear on the LHS. Different label signatures = **distinct output series**.
- `for:` tracks pending->firing **per output series identity** (full label set).
- Alertmanager grouping / silences / dedup key off the alert's output labels.

## Ranked failure modes

### FM1 — [DO-NOT-SHIP] Absent arm fires immediately and permanently (self-DoS)

- Trigger: merge the PROPOSED rule while `dispatcher_output_health` is not yet
  emitted. `absent_over_time(...)==1` is TRUE now (A1: 0 series today) -> after
  `for: 2m` the CRITICAL alert fires and **stays firing 24/7**.
- Cascade: continuous critical page on the on-call rotation -> alert fatigue ->
  the rotation silences the alertname wholesale -> the alert is **dead on
  arrival** even after the metric later starts flowing (silence outlives the
  fix). This is a denial-of-service on your own pager.
- Root cause (mechanism, not symptom): `absent()` cannot distinguish
  "instrumentation never shipped" from "dispatcher crashed". Both look identical.
  The alert asserts a metric contract that production does not yet satisfy.
- Blast radius: 100% of pages from this alert are false for the entire window
  between merge and instrumentation landing (open-ended).

### FM2 — [HIGH] `or`-arm label mismatch resets `for:` timer + breaks silences

- Trigger: dispatcher crash-looping / flapping faster than 2m between
  "present-but-0" (LHS active, identity `{exported_job, instance, pod, ...}`)
  and "absent" (RHS active, identity `{exported_job}` only).
- Effect A — MISSED PAGE: each flip is a **new series identity**, so the pending
  alert is discarded and `for: 2m` restarts from zero. A dispatcher that never
  stays in one state for a full 2m **never satisfies `for:`** -> no page during
  exactly the worst outage (crash-loop).
- Effect B — routing/silence breakage: a silence or Alertmanager group keyed on
  `{exported_job="Activation mFRR", pod="x"}` (LHS) does **not** match the bare
  `{exported_job="Activation mFRR"}` absent arm, and vice versa. Silences leak;
  the same logical failure can double-notify or escape suppression.
- Root cause: LHS preserves full labels, RHS collapses to equality matchers.
  The two arms are not label-compatible, so `or` yields an unstable identity.

### FM3 — [MED-HIGH] Double dwell -> ~4m detection latency on a time-critical path

- `avg_over_time(...[2m])` requires the trailing 2m window to fill with all-0
  samples, THEN `for: 2m` requires that condition to hold another 2m.
  Worst-case detection ~= 2m + 2m ~= **4m**.
- mFRR activation is minute-critical (frequency regulation / imbalance
  settlement). 4m of silent dispatcher-dead before a CRITICAL page is almost
  certainly unintended and too slow. The `avg_over_time` adds latency and buys
  nothing that a raw gauge + single `for:` does not.

### FM4 — [MED] Exact `== 0` on a gauge is float-brittle

- If the OTel pipeline ever delivers the gauge as a float (delta->cumulative
  conversion, rescaling, or `avg_over_time` of a flapping 0/1 producing
  fractional values like 0.5), exact `== 0` is only true when **every** sample
  is precisely 0. A single healthy scrape -> avg > 0 -> **no page**. Use `<= 0`.

### FM5 — [MED] Partial-cardinality blind spot (1-of-N replica loss)

- If multiple `dispatcher_output_health` series exist (per pod/replica) and ONE
  disappears while others still report:
  - LHS `avg_over_time==0`: evaluated per-series; the dead series simply stops
    existing -> no LHS result for it (nothing fires for the dead replica).
  - RHS `absent_over_time`: returns 1 only if the **entire** selector matches
    zero series. Any surviving replica -> absent=0 -> RHS silent.
  - Net: partial disappearance is **invisible to both arms**. Only *total*
    disappearance or *all-series-0* is caught. State this limitation explicitly;
    add a count-based alert if per-replica coverage matters.

## FM6 — Missed-page vs false-page: proposed vs current

| Scenario | CURRENT `== 0` | PROPOSED (`or absent`) |
|---|---|---|
| Metric present, sustained 0 | pages (good) | pages (good) |
| Dispatcher fully down / not scraped | **SILENT (missed page)** — empty vector | pages (intended improvement) |
| Metric not yet instrumented (today) | inert, 0 coverage | **false-pages 24/7 (FM1)** |
| Crash-loop flap present-0<->absent | n/a (no absent arm) | **missed page via for-reset (FM2)** |

Current = safe-but-blind (its single most important case, total-down, is
silent, and today it gives zero coverage). Proposed fixes the blindness in
intent but is unsafe to ship as written and unsafe to ship before the metric
exists.

## Safest production-ready expression

Unify the label sets so both `or` arms emit the **same** identity
(`{exported_job="Activation mFRR"}`), drop the double dwell, and use `<= 0`:

```yaml
# Recommended single-alert form
expr: |
  max by (exported_job) (dispatcher_output_health{exported_job="Activation mFRR"}) <= 0
  or
  absent(dispatcher_output_health{exported_job="Activation mFRR"})
for: 2m
labels:
  severity: critical
```

Why this is safe:
- `max by (exported_job)(...) <= 0` -> label set `{exported_job="Activation mFRR"}`,
  fires only when the **best** replica is unhealthy (all replicas <= 0). `<=`
  removes float brittleness (FM4). Instant gauge + single `for:` removes the
  double dwell (FM3).
- `absent(...)` (not `absent_over_time(...)==1`) -> also `{exported_job="Activation mFRR"}`.
  **Identical label set to the LHS** -> stable series identity across a
  present-0 <-> absent flap -> `for: 2m` no longer resets (fixes FM2), silences
  and grouping stay coherent.

Given the Helm template renders `<baseExpr> <exprOperator> <thresholdValue>`,
this needs the `or`-with-`absent()` in `baseExpr`; if the template cannot host a
compound expression, **split into two alertnames** (this is the operationally
cleanest option anyway — different failure modes, different tolerances, different
runbooks):

```yaml
# Preferred: two alerts, independent for: tolerances
- alert: DispatcherOutputHealthZero      # sustained-unhealthy
  expr: max by (exported_job) (dispatcher_output_health{exported_job="Activation mFRR"}) <= 0
  for: 2m
  labels: { severity: critical }

- alert: DispatcherOutputHealthAbsent    # not reporting / down
  expr: absent(dispatcher_output_health{exported_job="Activation mFRR"})
  for: 5m   # longer, to tolerate rolling deploys / scrape gaps
  labels: { severity: critical }
```

The longer `for:` on the absent alert prevents false pages during normal
rolling restarts / OTel pipeline hiccups (a residual false-page risk the 2m
absent arm would otherwise carry even after the metric is live).

Optional per-replica coverage (only if replicas are expected > 1):

```yaml
- alert: DispatcherOutputHealthReplicaLoss
  expr: count(dispatcher_output_health{exported_job="Activation mFRR"}) < <expected_replicas>
  for: 5m
  labels: { severity: warning }
```

## MERGE PRECONDITION (blocking)

Do **NOT** merge any `absent()`/`absent_over_time()` arm until
`dispatcher_output_health{exported_job="Activation mFRR"}` is **confirmed
emitting >= 1 series in the target Prometheus** (query it live; it must return
data). Concretely, one of:

1. Ship the metric instrumentation first, confirm it flows in the FBE/target
   Prometheus (`count(dispatcher_output_health{exported_job="Activation mFRR"}) > 0`
   returns a value), THEN merge the alert; or
2. Ship metric + alert in the same rollout, gated on the confirmation query.

Until then the absent arm is a guaranteed 24/7 false CRITICAL (FM1). Shipping
the sustained-`<= 0` arm alone is harmless (inert while metric absent) but
provides zero coverage, so it is not a substitute for the precondition — it just
defers the real work.

## Evidence labels

- A1 — Prometheus `absent`/`absent_over_time` label + zero-match semantics; `or`
  set-op identity rules; `for:` per-series tracking (Prometheus docs / query
  engine spec).
- A1 — LIVE FACT supplied by requester: selector matches 0 series in target
  Prometheus today.
- A2 — FM1..FM5 derived by applying A1 semantics to the proposed expression and
  the live 0-series state.
- A3 UNVERIFIED[blocked: no cluster access in this sidecar] — exact replica
  count of `dispatcher_output_health` once it emits (drives FM5 relevance) and
  whether OTel delivers the gauge as int or float (sharpens FM4). Resolve by
  querying the target Prometheus after instrumentation lands.
