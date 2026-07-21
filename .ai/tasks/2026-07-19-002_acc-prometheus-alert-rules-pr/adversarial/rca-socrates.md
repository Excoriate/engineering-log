---
title: Socratic adversarial review — RCA PR 180313 (assumptions + epistemics lane)
type: analysis
status: complete
task_id: 2026-07-19-002
agent: socrates-contrarian
timestamp: 2026-07-19
summary: |
  Adversarial review of rca.md on the assumptions/epistemics lane. The RCA is
  well-evidenced and honestly A1/A2/A3-labelled, but its central "environmental,
  not a PR bug" conclusion rests on ONE unexamined assumption: that
  dispatcher_output_health will carry exported_job="Activation mFRR". The RCA's
  own L4 evidence (all domain gauges on this stack carry "Dispatcher mFRR", and
  the "Activation mFRR" job holds ZERO domain metrics) undercuts that assumption
  and is never reconciled. Same gap contaminates the named resolving probe (E13)
  and both proposed fixes. Verdict: PROCEED-WITH-CHANGES.
verdict: conditional
---

# Socratic adversarial review — RCA for PR 180313

Lane: hidden assumptions + epistemics (E10 gating claim, inherited claims,
reader-decision closure, "not a PR bug" over-confidence, cross-section coherence).
Sibling lanes (logic=russell, ops=sre, docs=librarian) not re-litigated here.

## Steelman (what the RCA gets right, so the critique is fair)

- The `== 0` filter defect is correctly diagnosed and correctly separated from
  Alex's "returns NaN" mis-statement (L9). Solid A1, verified against docs.
- The pipeline-healthy / metric-absent split is real and well-probed (E6): 114
  messaging series present, the domain gauge absent — the transport is provably up.
- A1/A2/A3 discipline is genuine; E12/E13 blocks are named, not hidden.
- The two-repo split (values vs template+emission) is a real reader trap and is
  surfaced clearly (L2).

The findings below are additions/caveats that change the merge decision. They do
not tear down the core analysis — hence PROCEED-WITH-CHANGES, not REJECT.

---

## FINDING 1 — CRITICAL — The `exported_job="Activation mFRR"` selector is an unexamined load-bearing assumption; the RCA's own evidence contradicts it

**What I saw.** Every arm of the RCA — committed rule (E2), Alex's fix (E3), the
"most solid" 8a fix (L8a), and the resolving probe E13 — hard-codes the selector
`dispatcher_output_health{exported_job="Activation mFRR"}`. The RCA treats this
selector as settled/correct and locates the whole problem "upstream" of it
(traffic/FF gating).

But the RCA's own L4 + evidence-ledger line 36-39 says:
- `exported_job="Activation mFRR"` = 114 series, **ALL messaging/plumbing** — zero
  domain metrics.
- Every **domain** gauge on this stack (`activation_amount_mw`,
  `activationresponse_cycle_*`, `activation_mfrr_portfolio_deviation_value`) carries
  `exported_job="Dispatcher mFRR"`, **not** `"Activation mFRR"`.

`dispatcher_output_health` is a domain/business gauge (health of the dispatch
output). The single strongest predictor available in-session — the job label of
every *sibling* domain gauge — points at `"Dispatcher mFRR"`, not `"Activation
mFRR"`. The RCA notes the sibling-job fact in L4 but never draws the inference that
it threatens the selector.

**Why it's a defect.** If the health gauge (once emitted) carries
`exported_job="Dispatcher mFRR"` (or any value ≠ "Activation mFRR"):
- the committed alert never matches → silent in prod even under a real outage;
- the 8a `max by (exported_job)(... {exported_job="Activation mFRR"}) < 1` arm is
  permanently empty → present-arm silent;
- the `absent(... {exported_job="Activation mFRR"})` arm is **permanently true even
  in a healthy, emitting prod** → the exact self-DoS the RCA warns about, now
  caused by a *selector bug*, not deploy order;
- this makes it **a defect in the PR**, directly contradicting Executive-Summary
  point 3 ("none of which is a defect in the PR").

This is the uncomfortable truth the RCA collected the evidence for but did not
state: "Julian can't confirm the metric" may be because the selector is wrong, not
because the environment is idle. That is a simpler, PR-local explanation that the
RCA never competes against E10.

**Belief-status error.** E10 is correctly labelled A2 — good. But the RCA's
confidence paragraph (lines 100-104) names only ONE discriminator ("emits
continuously in a healthy env → emission bug"). It never lists the **selector /
job-label mismatch** as an alternative to traffic-gating. The alternative
hypothesis set is incomplete.

**Discriminating fix (single probe resolves it).** Source-grep
`Eneco.Vpp.Core.Dispatching` at the built commit for the `dispatcher_output_health`
registration and read the meter/service.name (OTLP `service.name` → `exported_job`)
it is emitted under. That one probe answers: (a) does the emission code exist at
all (Finding 2), (b) which `exported_job` it will carry, (c) whether the selector
is right. If source access is blocked, the healthy-env probe MUST drop the job
filter: `count by (exported_job)(dispatcher_output_health)` — see Finding 4.

**If TRUE → action change:** the PR's `baseExpr` selector must be corrected before
any merge, and Executive-Summary point 3 must be softened from "not a defect in the
PR" to "the metric's *absence in idle FBEs* is environmental; the selector
correctness is unverified and may itself be a PR defect."

---

## FINDING 2 — HIGH — "Not a version lag / robust across all build ages" is unsound: no probed build is confirmed to contain the emission code

**What I saw.** Evidence-ledger A2 (line 44) rules out version lag with "Robust
across all build ages → not a version lag." The probed builds are jupiter/boltz
`main.447bd6a`, thor/veku `1.2.feat.*`, ishtar `1.1.feat.*`, kidu `1.2.feat.*`
(evidence line 31). E7: **no probed slot runs Julian's branch**
`feature/820018-…`. The "metrics PR merged, dispatcher gains health-metric code"
row (L7) is sourced only to "thread (prerequisite, separate PR)" — an inherited
Slack claim, **not** probed in-session.

**Why it's a defect.** "Absent across all build ages" only excludes version lag IF
at least one probed build is *known* to contain the emission code. That is exactly
what is unestablished. If none of `main.447bd6a` / `1.x.feat.*` contains the metric
code yet (e.g. the metrics PR is not in `main`, or is in a later `main` than
`447bd6a`), then the simpler explanation — **"the emission code is not in any build
I tested"** — fully explains E6 without any traffic/FF gating. The RCA never
competes E10 against this. This is an inherited claim (metrics-PR-merged) doing
load-bearing work with no in-session probe.

**Discriminating fix.** Same source-grep as Finding 1: confirm
`dispatcher_output_health` is registered in the source at the exact commit a probed
build was cut from. If present → gating hypothesis survives; if absent → the
diagnosis is "code not shipped," not "traffic-gated," and the entire L4 narrative
changes.

**If TRUE → action change:** L4/L7 must add a probe row proving the emission code
exists in a probed build; until then E10 is A2 with a named competing hypothesis,
and the timeline row 1 must be marked A3 (inherited, unprobed).

---

## FINDING 3 — HIGH — A reader still cannot decide whether to approve/merge PR 180313 today (the doc's stated purpose #3 is not closed)

**What I saw.** Stated reader goal: "drive PR 180313 to a safe merge" (lines
14-17, L8b step 6). But:
- The PR *as committed* contains only `== 0` (E2), which the RCA calls defective.
- Alex's `absent` suggestion is **not committed** (E3).
- 8b's 6-step validation is shown to be **currently impossible** (three walls: no
  slot on the branch, no FBE loads the rule, metric not emitting).
- The 8a "most solid" form cannot be tested pre-merge for the same reason.

So the reader is left with: can't merge as-is (defective), can't validate on FBE,
can't test the recommended form. The RCA never states the one decision the reader
actually needs: **"Approve today with the present-arm only (`< 1`), which has no
absence dependency, and defer the `absent()` arm until emission is confirmed in
ACC"** — or whatever the intended verdict is. The ingredients are all present; the
decision is not assembled.

**Compounding gap:** the merge target is **ACC**, but every probe was in **Sandbox
FBE**. The claim "ACC is where the metric emits under real traffic" (L3 matrix) is
A2/assumption — ACC emission was never observed. So even the present-arm's safety
in ACC rests on an unprobed assumption, and (via Finding 1) the `absent` arm could
false-fire in a *healthy* ACC if the selector is wrong. The RCA does not surface
"merging to ACC carries residual risk X" as a distinct reader warning.

**Discriminating fix.** Add an explicit decision block to the Executive Summary or
L8: "Merge X now / hold Y until probe Z returns / do NOT merge any `absent` arm to
ACC until `count by(exported_job)(dispatcher_output_health)` returns data in ACC."
A named yes/no with conditions, not a 6-step procedure that cannot run.

**If TRUE → action change:** reviewer gets an actionable verdict instead of an
implicit one; ACC-specific merge risk is stated rather than buried.

---

## FINDING 4 — MEDIUM-HIGH — The named resolving probe E13 is contaminated by the Finding-1 assumption and cannot discriminate the failure it is meant to resolve

**What I saw.** E13's probe:
`count(dispatcher_output_health{exported_job="Activation mFRR"})` in a healthy env
(also L8b step 3, line 303 blocking precondition).

**Why it's a defect.** If the true job label is "Dispatcher mFRR" (Finding 1), this
probe returns **empty even in a healthy, emitting env**, and the operator would
wrongly conclude "still gated / emission bug" when the real cause is the selector.
The probe embeds the very assumption under test, so it cannot falsify it. A
resolving probe that cannot distinguish its target failure modes is a weak
falsifier (fails the observable + *discriminating* + external standard).

**Discriminating fix.** Drop the job filter in the diagnostic probe:
`count by (exported_job)(dispatcher_output_health)` (or
`group by(__name__,exported_job)({__name__=~".*output_health.*"})`) in a healthy
env. This simultaneously proves emission AND reveals the true `exported_job`, so it
discriminates gating-vs-selector-vs-nonemission in one shot. Update E13 and the
L8b line-303 blocking precondition accordingly.

**If TRUE → action change:** the blocking merge precondition (called "the single
most important line in this RCA") is rewritten to a probe that can actually clear
the block.

---

## FINDING 5 — MEDIUM — "Not a defect in the PR" is over-confident: TSOLivenessCheck (same PR) is never reviewed

**What I saw.** PR 180313 adds `DispatcherOutputHealthZero` **and**
`TSOLivenessCheck` (L7 line 242; E4 area). The RCA analyses only the former.
`TSOLivenessCheck` is named twice and never defined (absent from the Context
Ledger) or reviewed.

**Why it's a defect.** The doc's job is to "drive PR 180313 to a safe merge." A
reviewer approving the PR approves *both* alerts. An unreviewed second alert in the
same PR could carry the same `== 0`-filter or absence pathology (it is a "liveness"
check — a deadman by name, exactly the class the RCA warns about). Declaring the PR
"not defective (environmentally blocked only)" while one of its two alerts is
unexamined is an over-confident scope claim.

**Discriminating fix.** Either review `TSOLivenessCheck`'s rendered expression for
the same absence/filter pathology, or explicitly scope it out: "TSOLivenessCheck is
out of scope for this RCA; it MUST be reviewed separately before merge." Do not let
silence imply it is safe.

**If TRUE → action change:** merge is gated on a second review, or the scope
boundary is stated so the reviewer knows what this RCA did *not* clear.

---

## FINDING 6 — MEDIUM — The `< 1` fix depends on an unverified value-domain assumption (0=unhealthy, healthy ≥ 1)

**What I saw.** 8a replaces `== 0` with `< 1`, justified as "robust to
fractional/negative values" (line 279). Context Ledger states "0 = unhealthy (per
PR annotation)" with status "Known — thread + PR" (inherited). But E13 explicitly
lists the **value domain (binary vs float) as UNVERIFIED**.

**Why it's a defect.** `< 1` encodes "any value below 1 is an alertable outage."
If the gauge is a float that legitimately sits in (0,1) during normal partial
health, `< 1` false-fires; if "healthy" is encoded as some value other than ≥1,
`< 1` is wrong in the other direction. The fix's correctness inherits an unverified
Slack/PR-annotation semantic and states it as "robust" without probing it.

**Discriminating fix.** Same healthy-env probe (Finding 4) also captures the value
domain; gate the `< 1` vs `<= 0` vs `== 0` choice on the observed domain, and label
the current `< 1` recommendation A2-pending-E13 rather than "the most solid form."

**If TRUE → action change:** the recommended threshold is provisional until the
value domain is observed, and the RCA says so.

---

## FINDING 7 — LOW — Cross-section coherence: undefined identifiers for the stated zero-context reader

**What I saw.** The doc claims a zero-context-reader test (line 14, Context Ledger
preamble). Yet these appear un-glossed and are absent from the Context Ledger:
- **`TSOLivenessCheck`** (L7) — part of the PR, undefined + unanalyzed (see F5).
- **"pipeline 2412"** (L8b step 1) — an opaque build-pipeline id used in a fix
  instruction; a zero-context reader cannot act on it.
- **"Roel"** (L6, L8b, L12), **"Stefan"** (L4, E10) — named actors driving process
  rules ("Roel's rule") with no role introduction; only Julian (author) and Hein
  (Core) are contextualised.
- **"AVD"** (E12 probe) — undefined acronym in a resolving-probe instruction.

**Why it's a defect.** Minor, but it violates the doc's own stated comprehension
bar and, for "pipeline 2412" and "AVD", sits inside *actionable fix steps* where an
undefined identifier blocks execution.

**Discriminating fix.** Add Context-Ledger rows (or inline glosses) for
`TSOLivenessCheck`, pipeline 2412, AVD, and one-line role tags for Roel/Stefan.

---

## Superweapon deployment

- **SW4 Silence Audit (never N/A):** missing = TSOLivenessCheck review (F5),
  source-grep proving emission code exists (F2), ACC-specific emission observation
  (F3), job-label verification (F1). These absences are the review's core yield.
- **SW2 Boundary:** the well-covered boundary is app→OTel→Prom. The *uncovered*
  boundary is the label contract between the emitting service's `service.name` and
  the alert's `exported_job` selector (F1) — the highest-value boundary here.
- **SW5 Uncomfortable Truth:** the comfortable headline ("environmental, not a PR
  bug") may protect the PR author from the harder message: the selector is likely
  wrong. Evidence for the hard message was collected (L4) but not connected (F1).
- **SW1 Temporal Decay:** F1's failure mode is a *delayed* one — the alert looks
  fine in idle FBEs and only reveals the permanent-false-CRITICAL (or permanent
  silence) when it reaches an emitting env. N/A-risk: none; flagged via F1.
- **SW3 Compound Fragility:** F1 (selector) + F6 (value domain) + F2 (code
  presence) are correlated — all three resolve on the *same* source-grep +
  unfiltered healthy-env probe. One probe de-risks the cluster (see Dot-Connection).

## Dot-connection

Findings 1, 2, 4, 6 are not independent — they share one root: **the RCA never
observed `dispatcher_output_health` actually emitting, so every property of it
(existence, job label, cardinality, value domain) is assumed from Slack/PR text and
then propagated into the selector, the fix threshold, and the resolving probe.** A
single missing probe (source-grep the emission site + one unfiltered healthy-env
query) collapses all four. The RCA's own confidence note admits the diagnosis rests
on the metric being traffic-gated — but never tests the cheaper, PR-local
explanations (wrong selector / code-not-shipped) that the L4 sibling-job evidence
actively suggests.

## Meta-falsifier (how THIS review could be wrong)

- If the source-grep shows `dispatcher_output_health` is registered under the
  Activation-mFRR service's OTLP `service.name`, then F1/F4 collapse and E10's
  traffic-gating is the right diagnosis — F1 downgrades to "state the assumption
  explicitly," not a defect. I lack repo access this session to settle it, so F1 is
  raised as an unexcluded competing hypothesis, not a proven bug.
- If TSOLivenessCheck was already reviewed in a sibling doc (fix.md / receipts),
  F5 is moot — I did not read fix.md, only rca.md + evidence-ledger.md.
- I did not re-verify the Prometheus `absent()`/filter semantics (russell/librarian
  lanes own that); I assume their receipts stand.

## Verdict

**PROCEED-WITH-CHANGES.** The PromQL defect analysis and the environmental-walls
finding are sound and well-evidenced; ship those. But before this RCA is used to
"drive PR 180313 to a safe merge," it must (1) test the selector job-label
assumption via source-grep / unfiltered healthy-env probe (F1/F2/F4), (2) state an
explicit reader merge-decision with ACC-specific risk (F3), and (3) close or
explicitly scope out TSOLivenessCheck (F5). Findings 6-7 are polish.
