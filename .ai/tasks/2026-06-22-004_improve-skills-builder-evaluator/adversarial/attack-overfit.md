---
task_id: 2026-06-22-004
agent: socrates-contrarian
status: complete
summary: |
  Adversarial attack on plan.md proving n=1 over-generalization from the
  eneco-sre ops build. Decisive finding: the plan's "apply WHEN substrate is
  operational/state-delta/routing" conditioning is UNENFORCEABLE by the named
  classifier. classify_skill_type.py has enum conceptual/research/configurable/
  executable (NO ops/state-delta/routing). The only ops-ish signal is a
  SELF-DECLARED frontmatter `substrate` value read by a DIFFERENT script
  (evaluate_golden.py), and existing L1 lints gate only on `provenance`
  (boolean), never on substrate. So the proposed ops-only lints will fire on
  ALL builder-provenance skills — a regression against CLI/doc/knowledge skills.
---

# Attack: n=1 Over-Generalization in skills-builder/evaluator Change-Set

## Key Findings

- **classifier_has_no_ops_class**: classify_skill_type.py enum lacks state-delta/routing/operational
- **scoping_hand_waved**: ops lints L1-017/018 have no substrate gate in evaluate_l1.py (only provenance boolean)
- **split**: 4 universal / 6 ops-conditional-but-currently-unenforceable / 1 already-correct

Win condition: prove the change-set over-generalizes from ONE ops skill build (eneco-sre, n=1) into UNIVERSAL meta-skill doctrine that will fire on non-ops skills.

## STEELMAN (Rule 9)

The plan's author already SAW this risk. Family "Operational Skills" is explicitly
labeled "apply WHEN substrate is operational/state-delta/routing — conditional, not
universal" (plan.md:27). C3 provenance-gates every new lint (plan.md:15). The
consolidation note flags "the very meta-skills that preach anti-bloat" as the central
risk (context:43). This is NOT a naive author. The attack is therefore NOT "you forgot
to scope" — it is "your scoping mechanism does not exist in the substrate you named."

## DECISIVE FINDING — the conditioning is unenforceable (REPO-GROUNDED)

The plan conditions ops heuristics on substrate `operational/state-delta/routing`
and pairs each with an evaluator lint (C2 symmetry). I traced the classifier the brief
names.

**Mechanism (causal chain to regression):**

1. `classify_skill_type.py:12` — `ORDER = ["conceptual","research","configurable","executable"]`.
   There is NO `state-delta`, `routing`, `operational`, or `ops` class. This is the
   classifier the user named as the gate.
2. A SECOND, non-aligned enum exists: `evaluate_golden.py:54` /
   `evaluate_l0.py:78` — `SUBSTRATES = ("artifact","state-delta","findings","knowledge","behavioral-trace")`.
   So `state-delta` exists ONLY here, and `routing`/`operational`/`access-boundary`
   exist in NEITHER enum.
3. `state-delta` is NOT inferred — it is read from a SELF-DECLARED field
   (`evaluate_golden.py:110` `metadata.substrate`, or a body `Substrate:` marker, :121).
   The author writes it about their own skill.
4. Worse: `check_state_delta` (evaluate_golden.py:198-210) matches `ref_text` against
   `observed[- ]effect|post[- ]condition|fixture` — a regex on REFERENCE PROSE. A
   golang-cli-creator whose docs say "assert the post-condition" trips the state-delta
   surface WITHOUT declaring that substrate.
5. Existing L1 lints (evaluate_l1.py) gate on ONE thing: `provenance` (boolean —
   `has_builder_provenance`, :82, used at :656/:780/etc). NONE gate on substrate or
   type. There is NO precedent code path that scopes an L1 lint to "ops only."

**Therefore:** proposed `L1-018 access-boundary` ("ops skill claiming a probe proof")
and `L1-017 unverified-CLI` ("state-delta substrate / CLI fences") have no available
gate except `provenance:true`. **They will fire on EVERY builder-provenance skill** —
a markdown-doc-validator, a golang-cli-creator, a conceptual mental-model skill —
because the substrate class they claim to condition on is not a thing the classifier
can return. An evaluator lint that fires on skills it shouldn't is a REGRESSION (the
user's own stated bar).

IF TRUE → ACTION CHANGE: every ops heuristic MUST be gated on a substrate the
classifier actually emits. Since none exists, the plan must EITHER (a) first add a
real `operational`/`state-delta` discriminator to `classify_skill_type.py` + wire L1
to read it (a prerequisite task, currently absent from §B/§C), OR (b) drop the ops
family from universal doctrine and ship it as an OPT-IN reference the builder loads
only when the author declares `substrate: state-delta`. Plan as written does neither.

## UNIVERSAL vs OPS-CONDITIONAL vs DROP (corrected scoping table)

| Item (FB/L) | Plan placement | Verdict | Reason / falsifier |
|---|---|---|---|
| H-REF-ENTRY (FB-1/7,L-4) | Reference Doctrine | **UNIVERSAL** | decision-triggering entries help ANY multi-ref skill. Falsifier: a 1-ref conceptual skill — handled, fires only on entries that exist. Keep. |
| H-REF-LOADER (FB-2/3,L-5) | Reference Doctrine | **UNIVERSAL (≥4-ref gated)** | already conditioned on ref-count, not domain. Universal & enforceable (count is countable). Keep. |
| H-NO-HARDCODE (FB-4,L-6) | Reference Doctrine | **UNIVERSAL** | "pattern + ≥2 examples" is domain-free. Keep. L1-016 is sound. |
| L1-019 reference-description (FB-5) | symmetry lint | **UNIVERSAL** | frontmatter completeness; provenance-gate is the CORRECT gate here. Keep. |
| H-ACCESS-BOUNDARY (FB-6,L-7) | Operational | **OPS-CONDITIONAL — UNENFORCEABLE** | "execution-access-boundary" is an eneco AVD/`oc`-gated artifact (memory: mc-avd-execution-boundary). No classifier class. L1-018 fires on all provenance skills. Falsifier: a pure-doc skill has no execution boundary yet gets flagged. CONDITION or DROP. |
| H-VERIFY-CLI (FB-8,L-8) | Operational | **OPS-CONDITIONAL — PARTLY SALVAGEABLE** | "probe before documenting a command" is good for ANY skill with CLI fences — but that is detectable (code-fence presence), NOT "ops substrate." Re-scope L1-017 to "any skill emitting a CLI fence carries a verification note," drop the false "state-delta" gate. Falsifier: a golang skill with a `go build` fence — SHOULD this fire? Arguably yes → then it is UNIVERSAL-on-CLI-presence, not ops. |
| H-EFFECT-GATE (L-9) | Operational | **OPS-CONDITIONAL — enforceable IF declared** | "close by observed effect not return code" is genuinely state-delta-specific. This is the ONE ops item with a real substrate (`state-delta` in golden enum, author-declared). Keep GOLDEN-STATE-DELTA strengthening; it already gates on declared substrate (evaluate_golden.py:583). Do NOT promote to L1 universal. |
| H-PARALLEL (FB-9) | Operational | **DROP from doctrine / advisory only** | "dispatch context lanes in parallel" is a coordinator-runtime behavior, not a skill-structure signal. No structural lint can witness it (the skill is text; parallelism is execution). Symmetry (C2) is unsatisfiable → the metric is gameable by design. n=1 artifact of a time-critical incident. Falsifier: a doc-validator skill — parallelism is meaningless. Drop or demote to non-lint prose. |
| H-PHASE-CONTEXT (FB-10) | Operational | **OPS-CONDITIONAL** | "non-skippable Context phase" suits investigation/ops; for a 1-shot CLI-creator a phase model is ceremony — the exact anti-pattern the plan elsewhere warns against. Condition on investigation/ops or DROP. |
| H-KIND-RECOGNITION (FB-11) | Operational | **NARROW — routing/classifier only** | genuinely useful but ONLY for classifier-substrate skills (findings). "golden >1 failure mode" generalizes; "KIND cue" does not. Split: keep ">1 real failure mode" as findings-substrate lint (enforceable via golden), drop "KIND cue" as eneco-FBE-shaped. |

Net: **4 universal, 1 enforceable-ops (effect-gate via declared substrate), 5 unenforceable-or-drop.**

## SINGLE MOST DANGEROUS OVER-GENERALIZATION

`L1-018 access-boundary` (+ the H-ACCESS-BOUNDARY doctrine). It encodes a pure
eneco-ops artifact (AVD-gated `oc`/argocd execution boundary) as a builder-universal
lint, but the only gate available in `evaluate_l1.py` is `provenance:true`. Result: it
fires "you must ship an execution-access-boundary reference + claim no proof for a
gated tool" on a golang-cli-creator or markdown-doc-validator that has no execution
boundary at all. A symmetry lint (C2) that the substrate cannot scope is not a
strengthening — it is a guaranteed false-positive generator against every future
non-ops skill. This is n=1 doctrine masquerading as universal law.

## META-FALSIFIER (Rule 11)

This attack is WRONG if: (a) `classify_skill_type.py` is NOT the gate the new lints
use, and a substrate-aware gate is added in §C that I missed — but §C:57-58 names no
classifier wiring, only "ops reference (state-delta substrate / CLI fences)" as prose;
(b) the plan intends ops lints to be authored-substrate-declared (opt-in) and I
mis-read C3 provenance-gating as the sole gate — possible, but the plan never says
"gate L1-017/018 on declared substrate==state-delta," it says "provenance-gated"
(plan.md:54). If the author adds explicit `if declared_substrate != 'state-delta':
return []` to each ops lint AND a real ops/routing discriminator, the enforceability
objection collapses for effect-gate/verify-CLI; access-boundary and parallel still
have no substrate to bind to.

Evidence basis: REPO-GROUNDED (classify_skill_type.py:12; evaluate_golden.py:54,110,
198-210,583; evaluate_l1.py:82,656; evaluate_l0.py:78). Domain gap: I did not run the
lints against a non-ops fixture — that empirical test (build a golang-cli skill, run
the proposed lints) is the definitive falsifier and is currently UNTESTED.
