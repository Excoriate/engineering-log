---
task_id: 2026-07-19-002
agent: bertrand-russell
timestamp: 2026-07-19T00:00:00Z
status: complete
verdict: conditional
russell_verdict: SOUND-WITH-CAVEATS
summary: |
  Audited whether the proposed PromQL expression is a faithful TOTAL function
  over the case space {present+healthy, present+sustained-0, present+briefly-0,
  fully-absent-2m, partial-absence}. Precedence, `or` union semantics, and the
  mutual exclusivity of the two arms are PROVABLY correct — the two arms can
  never both be non-empty, so the `or` never resolves a label collision. The
  `== 1` on the absent arm is REDUNDANT (harmless). Three load-bearing hidden
  assumptions carry the verdict: (1) the selector matches EXACTLY ONE series in
  a healthy env — if >1, partial-absence is silent-when-it-should-fire; (2) the
  gauge is non-negative — required for `avg==0` to mean "sustained 0"; (3) the
  selector is CORRECT and the metric is genuinely expected present — `absent`
  cannot distinguish "went away" from "never existed", and the LIVE FACT (0
  matching series now) makes this a real false-critical risk. Expression is
  internally valid; merge is gated on resolving cardinality and selector-truth.
weapons_fired:
  - Theory of Descriptions: "the metric dispatcher_output_health" fails existence NOW (0 series) and uniqueness is unproven (1 vs N series)
  - Type-Theory check: absent-of-emission (runtime) conflated with dispatcher-unhealthy (object) — level mix
  - Acquaintance audit: "absence == dispatcher down" chain does not terminate in an observed atom; absent() cannot witness the difference from misconfig
  - Vagueness taxonomy: "sustained 0" is sorites-vague (one 0 sample in 2m counts)
  - Logical Atomism: intent decomposed into 5 per-case atomic obligations
---

# Russell Audit — `DispatcherOutputHealthZero` proposed PromQL

## Verdict: SOUND-WITH-CAVEATS (frontmatter enum: conditional)

The expression is a **logically valid** implementation of the *stated* intent
("fire iff sustained-0 over 2m OR whole-selector absent for 2m"). It is NOT a
faithful total function of the *true operational* intent ("this dispatcher is
unhealthy") because two of the five cases depend on unproven premises, and the
absence arm conflates absence-of-emission with unhealthiness. Whether this
blocks the PR reduces to three checkable facts (§ Falsifiers).

## Key Findings

- Operator precedence correct: `(A==0) or (B==1)`; `==` binds tighter than `or`.
- The two arms are **PROVABLY mutually exclusive**; the `or` union is collision-free.
- `absent_over_time(...) == 1` is **redundant**, not load-bearing (harmless).
- Multi-series partial absence is a **SILENT-WHEN-SHOULD-FIRE** hole if the selector matches >1 series.
- The absent arm **cannot distinguish** "metric disappeared" from "metric never emitted / wrong selector" — false-critical risk given the live 0-series fact.
- Label-set differs between arms (rich labels vs `exported_job`-only) → `for:` timer resets on `present+0 → absent` transition.

## Claim under audit

> PROPOSED:
> `avg_over_time(dispatcher_output_health{exported_job="Activation mFRR"}[2m]) == 0`
> `or absent_over_time(dispatcher_output_health{exported_job="Activation mFRR"}[2m]) == 1`
>
> Intent: fire iff (health sustained 0 over 2m) OR (metric absent for 2m).

Claim type: **partition + universal** (a total function from window-state to
fire/no-fire; the partition must be mutually exclusive AND collectively
exhaustive over the case space).

## Weapons fired (§5.4 receipt — all seven probed)

| Weapon | Trigger row | Fired | Condition observed (or rationale for N) |
|---|---|---|---|
| Theory of Descriptions | definite description | **Y** | "the metric `dispatcher_output_health`" is a definite description. EXISTENCE conjunct **fails now** (LIVE FACT: 0 matching series). UNIQUENESS conjunct **unproven** (1 series or N per-instance?). PREDICATION (=health) assumed. |
| Vicious-Circle detection | self-referential verification | **N** | No "we verify X by X" structure. The alert does not define its own oracle; health is an external gauge. No impredicative totality present. |
| Type-Theory check | category-ambiguous term | **Y** | `absent_over_time` treats **absence of a runtime series** (scrape/emit level, type n+1) as equivalent to **dispatcher unhealthy** (object level, type n). Level-mix: "metric not scraped" ≠ "dispatcher output unhealthy". |
| Acquaintance audit | inference chain w/o direct observation | **Y** | The chain "selector empty → dispatcher down → fire critical" has no acquaintance atom witnessing that emptiness *means* unhealthy. `absent()` cannot observe the discriminating difference between "was emitting, now gone" and "never emitted / wrong name". |
| Vagueness taxonomy | sorites/many-dim predicate | **Y** | "sustained 0" is sorites-vague: `avg==0` fires on a SINGLE 0-valued sample in the window (scrape gap → one sample). "Sustained" implies duration/density that the expression does not enforce (the `for: 2m` partially compensates). |
| Logical Atomism | compound claim not evaluable as-is | **Y** | "fire iff sustained-0 OR absent" atomized into 5 per-case checkable propositions (§ case table). |
| Dissolution over refutation | subject term E/U/P all failed | **N** | Existence fails *now* but uniqueness/predication are not both dead, and the expression's *behavior* remains evaluable per case. Not dissolved — evaluated, with existence-failure surfaced as a merge-blocking caveat (§ Falsifiers). |

## PromQL semantics established (primary source)

All verified against prometheus.io/docs (operators, functions):

1. **Precedence**: `==` is level-4; `or` is level-6 (lowest). So the parse is
   unambiguously `(A == 0) or (B == 1)`, NOT `A == (0 or B) == 1`. Matches
   intent. **[A1 FACT]**
2. **`vector == scalar` without `bool`** is a **filter**: series where the
   comparison is false are dropped; survivors keep their **original value and
   full label set**. It does NOT yield a 0/1. **[A1 FACT]**
3. **`vector1 or vector2`** = all of `vector1`, plus elements of `vector2`
   whose label set is unmatched in `vector1` (LHS-wins union). **[A1 FACT]**
4. **`absent_over_time(sel[2m])`** = empty if the window has ≥1 sample; else a
   single series `{exported_job="Activation mFRR"} => 1` (labels lifted from
   the equality matchers). **[A1 FACT]**
5. **`avg_over_time(sel[2m])`** over an empty window produces **no output
   series** (range-vector aggregations emit nothing when there are no input
   samples). **[A2 INFER from range-vector aggregation semantics; standard
   Prometheus behavior]**

Let `A := avg_over_time(...[2m]) == 0` and `B := absent_over_time(...[2m]) == 1`.

## Mutual exclusivity proof (the load-bearing structural fact)

- `A` non-empty ⟹ ≥1 matching series had samples in the window (to be averaged)
  ⟹ `absent_over_time` sees samples ⟹ returns empty ⟹ `B` empty.
- `B` non-empty ⟹ 0 samples in the whole window ⟹ `avg_over_time` emits nothing
  ⟹ `A` empty.

Therefore **A and B are never simultaneously non-empty**, for ANY series
cardinality. Consequence: the `or` union's "drop RHS on label collision" rule
**never activates** — there is nothing to collide. The `or` is collision-safe
here. This is the one thing that makes an otherwise label-set-inconsistent
expression behave cleanly.

## Case-space enumeration (the total-function audit)

| # | Case | `avg_over_time` | Arm A | `absent_over_time` | Arm B | Result | Intent | Match? |
|---|------|-----------------|-------|--------------------|-------|--------|--------|--------|
| 1 | present + healthy (all ≥1) | ≥1 | ∅ (≥1≠0) | ∅ (samples exist) | ∅ | **no-fire** | no-fire | yes |
| 2 | present + sustained-0 (all 0) | 0 | {series}=0 | ∅ | ∅ | **fire** | fire | yes |
| 3 | present + briefly-0 (mixed 0/≥1) | (0,1)+ | ∅ (avg≠0) | ∅ | ∅ | **no-fire** | no-fire* | yes* |
| 4 | fully-absent 2m (**LIVE**) | ∅ | ∅ | {exported_job}=1 | {exported_job}=1 | **fire** | fire | yes |
| 5 | partial absence (N series, some vanish) | per present series | present-0 series only | ∅ (some present) | ∅ | **fire only for present-0; vanished series SILENT** | fire per vanished instance? | NO if N>1 |

### Case notes

- **Case 3 (`*`)**: correct *given a strictly binary gauge {0, ≥1} and
  non-negativity*. If health can take values in (0,1) or negatives, `avg==0` is
  the WRONG encoding of "never healthy in the window". A dispatcher that
  flapped 0,0,0.5,0 was never healthy (never ≥1) yet `avg>0` → no fire. The
  operator that *directly* encodes "never healthy in 2m" is
  `max_over_time(...[2m]) < 1`, which is robust to intermediate values. `avg==0`
  is only equivalent to `max<1` under the binary + non-negative assumption.
  **Hidden assumption: gauge ∈ {0} ∪ [1,∞).**

- **Case 4**: this is the load-bearing improvement over the CURRENT expression.
  Current expr is arm-A only; on full absence `avg_over_time` emits nothing and
  `∅ == 0` is `∅` → current expr is **silent-when-it-should-fire on absence**.
  The proposed arm B correctly closes that. Confirmed load-bearing.

- **Case 5 — the real hole**: `absent_over_time` is **all-or-nothing over the
  entire selector**. If even ONE `dispatcher_output_health{exported_job=...}`
  series still emits, arm B is empty. A specific instance/pod that goes fully
  absent while siblings stay healthy is caught by NEITHER arm (arm A needs the
  vanished series to still emit a 0; it emits nothing). **Silent-when-it-should-
  fire, IF the selector matches >1 series.** Whether this case is even reachable
  is exactly the unresolved UNIQUENESS conjunct from Theory of Descriptions.

## Redundancy finding: `== 1` on the absent arm

`absent_over_time` only ever yields value `1` (or nothing). `{...}=1 == 1`
keeps it; `∅ == 1` is `∅`. So `absent_over_time(...) == 1` ≡
`absent_over_time(...)`. The `== 1` is **redundant, not load-bearing**. Harmless,
but it is cosmetic noise that implies a value test that does nothing. Drop it.

## Label-set inconsistency between arms (secondary defect)

- Arm A fires with the **full label set** of the offending series
  (`exported_job`, plus any `instance`/`pod`/… present on the gauge).
- Arm B fires with **only** `{exported_job="Activation mFRR"}` (matcher labels).

Because the arms are mutually exclusive the `or` tolerates this, BUT across
*time* a single unhealthy series that transitions `present+0 → absent` changes
its alert label set → Prometheus treats it as a **new** alert series → the
`for: 2m` clock **resets**, delaying the critical by up to 2m at the worst
moment (dispatcher crashing after being unhealthy). Also degrades dedup/routing
consistency. Minor but real; only matters if the gauge carries per-instance
labels (again the uniqueness question).

## Hidden assumptions (must be true for the claim to hold)

1. **[UNIQUENESS]** `dispatcher_output_health{exported_job="Activation mFRR"}`
   matches **exactly one** series in a healthy env. If N>1: Case 5 silent hole +
   label-flap `for`-reset become live. **Probe: count the series in a healthy
   env.**
2. **[NON-NEGATIVITY]** the gauge is in `{0} ∪ [1,∞)` with no negative or
   intermediate values. Required for `avg==0 ⇔ sustained-0` and for Case 3.
3. **[SELECTOR-TRUTH / EXISTENCE]** the selector is correct and the metric is
   *genuinely expected to be present* when healthy. `absent_over_time` **cannot
   distinguish** "was emitting, now gone (real outage)" from "never emitted /
   wrong metric name / wrong label (misconfiguration)". Both produce an
   identical critical.

## The LIVE FACT makes assumption 3 acute

Right now `exported_job="Activation mFRR"` emits **114 series** but
`dispatcher_output_health` matches **0**. Under the proposed expression this is
**Case 4 → the alert FIRES A CRITICAL immediately** (after `for: 2m`). Two
readings are observationally identical:

- (a) the dispatcher's health metric is genuinely down → correct critical; or
- (b) the metric is not wired up / renamed / the selector is wrong (note
  `exported_job`, a relabel-collision prefix — the metric may be exposed under a
  different job/name) → **false critical, permanently firing**.

`absent()` provides no acquaintance atom to tell these apart. **Deploying the
absence arm before confirming the metric exists in a healthy env risks shipping
a self-justifying permanent critical.** This is the strongest countermodel: a
world where every stated premise holds, the expression does exactly what it
says, and the alert is nonetheless *wrong* because "absent" did not mean
"unhealthy".

## Corrected expression

If uniqueness holds (single series) — minimal cleanup, logically equivalent,
drops redundant `==1` and matches "never healthy" more directly:

```promql
max_over_time(dispatcher_output_health{exported_job="Activation mFRR"}[2m]) < 1
  or
absent_over_time(dispatcher_output_health{exported_job="Activation mFRR"}[2m])
```

- `max_over_time(...) < 1` encodes "never reached healthy in 2m", robust to
  intermediate/negative values (supersedes `avg==0`). If you must preserve exact
  "all samples 0" semantics and trust non-negativity, `avg_over_time(...) == 0`
  is acceptable — but then state the non-negativity premise in the rule comment.

If the selector matches >1 series and per-instance absence must fire, the bare
`absent_over_time` is insufficient (all-or-nothing). Use a per-series liveness
against an expected set, e.g. a `count`-based deadman or `absent()` per known
instance; this requires an expected-instances reference and is a design change,
not a one-liner.

Regardless of arm form, **mitigate assumption 3 before merge**: confirm the
metric is emitted in a healthy env, or gate the absence arm on a known
ever-present sibling so a *typo/never-existed* selector cannot fire, e.g.:

```promql
absent_over_time(dispatcher_output_health{exported_job="Activation mFRR"}[2m])
  and on() (count(up{...dispatcher target...} == 1) > 0)
```

(only if such an always-present sibling exists — otherwise you cannot
distinguish the two absence causes and must accept the false-positive risk
consciously.)

## Does the proposed fix "must change"?

- On **pure logic vs stated intent** (single series, non-negative, selector
  correct): NO forced change — arms are exclusive, precedence correct, Cases
  1-4 match. Verdict body = SOUND.
- The proposed fix **must change IF** the selector matches >1 series (Case 5
  silent hole) **OR IF** the metric is not genuinely present in a healthy env
  (Case 4 becomes a false critical). Given the LIVE FACT that 0 series match
  right now, **assumption 3 is currently unproven and pointing the wrong way**,
  so at minimum the merge must not proceed until Falsifier 3 is confirmed.

## Falsifiers / next discriminating checks

1. **Uniqueness**: run `count(dispatcher_output_health{exported_job="Activation mFRR"})`
   in a **healthy** env. Result 1 → Case 5 moot. Result >1 → adopt per-series
   design or accept the documented hole.
2. **Non-negativity**: confirm the gauge's value domain (metric definition /
   emitter source). Any value in (0,1) or negative → switch to
   `max_over_time(...) < 1`.
3. **Selector-truth**: confirm `dispatcher_output_health` is emitted under this
   exact selector in a healthy env. If it never was, fix the selector — do NOT
   let the absence arm ship a permanent false critical.

## Handoff

Remaining questions 1-3 are **evidence acquisition about the live metric**, not
logic — hand to Sherlock/SRE for the healthy-env cardinality + emission probe.
Once those three facts are in hand, this expression's verdict resolves to SOUND
(single-series, non-negative, selector-true) or requires the per-series
redesign (multi-series).
