---
task_id: 2026-07-19-002
agent: librarian
status: complete
timestamp: 2026-07-19T00:00:00Z
summary: |
  Adjudicated 5 PromQL semantic claims against authoritative Prometheus docs
  (prometheus.io/docs/prometheus/latest, cross-verified against the canonical
  docs source in prometheus/prometheus main). Claims 2, 3, and 4 are fully
  documented and TRUE (verbatim quotes captured). Claim 1: the reviewer's
  assertion that avg_over_time "returns NaN when there are no samples in the
  window" is FALSE/unsupported — an empty window drops the series (no output),
  which follows from range-vector semantics (A2 INFER; no single explicit doc
  sentence). Claim 5: TRUE in practice but the prose docs are SILENT on keyword
  case-sensitivity — no citable sentence exists (documentation gap, flagged).
source_authority: PRIMARY (official Prometheus documentation)
freshness: CURRENT
---

# Adversarial Fact-Check: PromQL Semantic Claims vs Authoritative Prometheus Docs

## Sources (PRIMARY / Tier 1 — official Prometheus documentation)

- Operators: <https://prometheus.io/docs/prometheus/latest/querying/operators/>
- Functions: <https://prometheus.io/docs/prometheus/latest/querying/functions/>
- Basics: <https://prometheus.io/docs/prometheus/latest/querying/basics/>

Exact quotes were extracted from the canonical docs source (`prometheus/prometheus`
`main` branch, `docs/querying/{operators,functions,basics}.md`) and the load-bearing
passages (comparison-filter behavior, `or` semantics, precedence table) were
cross-verified verbatim against the published `latest` operators page (A1 FACT —
both surfaces agree word-for-word).

## Verdict Table

| # | Claim | Verdict | Documentation basis |
|---|-------|---------|---------------------|
| 1 | Empty `avg_over_time` window drops the series (no result), NOT NaN | **TRUE** (behavior) — reviewer's "returns NaN" is **FALSE** | A2 INFER (no explicit sentence); reviewer claim has zero doc support |
| 2 | `absent_over_time` returns 1 when range empty; labels from selector equality matchers | **TRUE** | A1 FACT — explicit + worked examples |
| 3 | Comparison ops filter without `bool`, return 0/1 with `bool` | **TRUE** | A1 FACT — explicit sentence |
| 4 | `or` union semantics + precedence (`or` lowest; `*` > `==`; `==` > `or`) | **TRUE** | A1 FACT — explicit sentence + precedence list |
| 5 | `and`/`or`/`unless` are case-sensitive lowercase; `OR` is a parse error | **TRUE in practice, but UNDOCUMENTED** | A3 — prose docs are SILENT; no citable sentence |

Only one assertion came back FALSE: the reviewer's "avg_over_time returns NaN when
there are no samples in the window" (Claim 1). Claim 5 cannot be closed on docs alone.

---

## Claim 1 — `avg_over_time(v[2m])` on an empty window

**Reviewer's assertion:** avg_over_time "returns NaN when there are no samples in the window."
**Task's assertion:** the series simply drops (empty), NOT NaN.

**Verdict: reviewer is FALSE / unsupported. Task's assertion is TRUE (behavior), but it is an A2 INFER — the docs contain no single explicit sentence for the empty-window case.**

There is no documented sentence stating avg_over_time returns NaN (or any value) when a
series has no samples in the range. The correct behavior follows from the documented
range-vector model:

- `<aggregation>_over_time()` operates per series of a range vector (functions.md):
  > "The following functions allow aggregating each series of a given range vector over time and return an instant vector with per-series aggregation results:"
  > "`avg_over_time(range-vector)`: the average value of all float or histogram samples in the specified interval (see details below)."
- A range-vector selector only yields series that have samples in the interval (basics.md, Range Vector Selectors):
  > "Range vector literals work like instant vector literals, except that they select a range of samples back from the current instant."
  A series with zero samples in the 2m interval therefore has no range-vector element at that step, so `avg_over_time` produces **no output element** for it — it does not emit a NaN placeholder.
- The docs confirm this "drop, don't placeholder" pattern for the analogous no-eligible-sample case (functions.md, `<aggregation>_over_time()`):
  > "Input ranges containing only histogram samples are silently removed from the output."

**Nuance to hand back to the reviewer:** avg_over_time *can* yield NaN, but only when the
samples that ARE present are themselves NaN (avg of NaN is NaN) — that is a different
condition from "no samples in the window." Conflating "empty window" with "NaN" is the
error. Source: <https://prometheus.io/docs/prometheus/latest/querying/functions/#aggregation_over_time>
and <https://prometheus.io/docs/prometheus/latest/querying/basics/#range-vector-selectors>

---

## Claim 2 — `absent_over_time(v range-vector)`

**Verdict: TRUE (A1 FACT, fully documented).**

Exact quote (functions.md, `absent_over_time()`):

> "`absent_over_time(v range-vector)` returns an empty vector if the range vector passed to it has any elements (float samples or histogram samples) and a 1-element vector with the value 1 if the range vector passed to it has no elements."

Label derivation — exact quote + worked examples:

> "In the first two examples, `absent_over_time()` tries to be smart about deriving labels of the 1-element output vector from the input vector."

```text
absent_over_time(nonexistent{job="myjob"}[1h])
# => {job="myjob"}

absent_over_time(nonexistent{job="myjob",instance=~".*"}[1h])
# => {job="myjob"}

absent_over_time(sum(nonexistent{job="myjob"})[1h:])
# => {}
```

Confirms the claim precisely: the returned 1-element series carries labels derived from
the selector's **equality** matchers (`job="myjob"`). A regex matcher (`instance=~".*"`)
is **not** carried over, and once the selector is wrapped in an aggregation (`sum(...)`)
no labels are derived (`{}`). Returned value is `1`; returned only when the range vector
is empty.
URL: <https://prometheus.io/docs/prometheus/latest/querying/functions/#absent_over_time>

---

## Claim 3 — Comparison operators: filter vs `bool`

**Verdict: TRUE (A1 FACT, fully documented; verbatim on both source and published page).**

Exact quote (operators.md, Comparison binary operators):

> "Comparison operators are defined between scalar/scalar, vector/scalar, and vector/vector value pairs. By default they filter. Their behavior can be modified by providing `bool` after the operator, which will return `0` or `1` for the value rather than filtering."

Reinforcing detail (vector/scalar case):

> "Between an instant vector and a scalar, these operators are applied to the value of every data sample in the vector, and vector elements between which the comparison result is false get dropped from the result vector."

URL: <https://prometheus.io/docs/prometheus/latest/querying/operators/#comparison-binary-operators>

---

## Claim 4 — `or` set semantics and operator precedence

**Verdict: TRUE (A1 FACT, fully documented; precedence list verbatim on both surfaces).**

Exact quote (operators.md, Logical/set binary operators):

> "`vector1 or vector2` results in a vector that contains all original elements (label sets + values) of `vector1` and additionally all elements of `vector2` which do not have matching label sets in `vector1`."

> "These logical/set binary operators are only defined between instant vectors: `and` (intersection), `or` (union), `unless` (complement)."

Note: the reviewer's quoted wording omits the parenthetical "(label sets + values)"
present in the current docs — substantively identical; the claim stands.

Exact precedence list (operators.md, Binary operator precedence — "from highest to lowest"):

```text
1. ^
2. *, /, %, atan2
3. +, -
4. ==, !=, <=, <, >=, >
5. and, unless
6. or
```

> "Operators on the same precedence level are left-associative. ... However `^` is right associative..."

Precedence sub-claims all confirmed:

- `or` is the **lowest** precedence (level 6) — **TRUE**.
- `*` (level 2) binds **tighter** than `==` (level 4) — **TRUE**.
- `==` (level 4) binds **tighter** than `or` (level 6) — **TRUE**.

URL: <https://prometheus.io/docs/prometheus/latest/querying/operators/#binary-operator-precedence>

---

## Claim 5 — Case sensitivity of `and`/`or`/`unless`; is `OR` a parse error?

**Verdict: TRUE in practice, but NOT DOCUMENTED — flagged. No citable doc sentence exists.**

This is a documentation gap (negative information). The official prose docs are **silent**
on keyword case-sensitivity: there is **no** sentence stating the logical operators are
case-sensitive lowercase keywords, and **no** sentence stating that uppercase `OR` is a
parse error. I could not cite a quote because none exists.

What the docs *do* show (circumstantial, not a direct statement):

- Every keyword/operator is written **exclusively in lowercase** throughout operators.md
  and basics.md: `and`, `or`, `unless`, `bool`, `on`, `ignoring`, `group_left`, `group_right`.
- basics.md (Instant vector selectors) states the reserved-keyword restriction using
  lowercase forms only:
  > "The metric name must not be one of the keywords `bool`, `on`, `ignoring`, `group_left` and `group_right`."
  (Note: this list is itself about metric-name collisions and does not even enumerate
  `and`/`or`/`unless`, so it is not a case-sensitivity statement.)

Behavioral truth (A2 INFER, NOT from prose docs): PromQL's lexer recognizes these
keywords only in their lowercase spelling; `OR` (uppercase) is not tokenized as the set
operator — it is lexed as an identifier/metric name, which yields a parse error in an
operator position. This is correct but rests on the parser/lexer implementation, not on
any documented sentence.

**Recommendation for the reviewer:** do not represent Claim 5 as "per the Prometheus
docs." State it as observed/implementation behavior, or verify it with a live
`promtool` / parser probe (e.g. attempt to parse `a OR b`) rather than citing the docs.
Basics reference: <https://prometheus.io/docs/prometheus/latest/querying/basics/>

---

## Handoff Notes

- **Confidence:** CONFIRMED (95%) for Claims 2, 3, 4 (verbatim quotes, dual-surface
  verified). CONFIRMED that the reviewer's Claim-1 NaN assertion is FALSE (contradicts
  documented range-vector model). Claim 1 "series drops" = LIKELY/CONFIRMED behavior but
  A2 INFER (no explicit sentence). Claim 5 = behavior CONFIRMED but UNDOCUMENTED.
- **Negative information (conspicuously absent):** (a) no explicit doc sentence for the
  empty-window behavior of `*_over_time` functions; (b) no explicit doc statement on
  PromQL keyword case-sensitivity. Both are true-in-practice but not doc-citable.
- **Freshness:** CURRENT — published `latest` page matches `main` docs source verbatim
  for all load-bearing quotes as of 2026-07-19.
