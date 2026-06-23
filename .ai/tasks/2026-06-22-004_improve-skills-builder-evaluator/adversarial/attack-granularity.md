---
task_id: 2026-06-22-004
agent: simplicity-maniac
timestamp: 2026-06-22T00:00:00Z
status: complete
summary: |
  Adversarial complecting audit of plan §A's 9 named heuristics. Win condition was
  DESTRUCTION of "9 distinct concepts." Result: the brief is MOSTLY correct — 6 of 9
  survive as genuinely orthogonal (each maps a distinct Hickey axis + distinct evaluator
  lint with independent witness). But TWO complecting defects survive: (1) H-PARALLEL is
  a sub-clause of H-PHASE-CONTEXT's Context gate (one concept, two granularities — the
  exact FB-1/FB-7 split the plan already collapsed elsewhere); (2) H-KIND-RECOGNITION is
  itself two concepts complected — a novel classifier-cue authoring rule braided with a
  golden-completeness rule that already belongs to existing GOLDEN doctrine. Minimal
  distinct set = 7 named heuristics + 1 GOLDEN strengthening (not 9 new heuristics).
---

# Attack: Heuristic Granularity in plan §A

## Key Findings

- finding_1: H-PARALLEL folds into H-PHASE-CONTEXT — Context-phase-quality is one concept at two granularities
- finding_2: H-KIND-RECOGNITION complects classifier-cue (novel) with golden->1-failure (existing GOLDEN doctrine)
- finding_3: H-ACCESS-BOUNDARY vs H-VERIFY-CLI are ORTHOGONAL (Authority axis vs Value/provenance axis) — split is correct, do NOT merge
- finding_4: Reference-Doctrine trio (ENTRY/LOADER/NO-HARDCODE) are orthogonal — different cardinality trigger + independent lints

## Win condition

DESTROY the claim "these 9 are distinct concepts each deserving its own named heuristic."
Method: Braid Detector — for each pair, ask whether changing/understanding one FORCES
loading the other (complecting) or merely places them near each other (adjacency). A
genuine merge is justified only by naming the SINGLE concept the items share.

## Framing correction (what the target actually is)

Plan §A has ALREADY collapsed the brief's raw atoms in two places before adversarial review:
- FB-1 + FB-7 are merged into the single `H-REF-ENTRY` (FB-7 = "deeper FB-1" — the
  one-concept-split-in-two the coordinator flagged is ALREADY healed). [plan §A:23, full-scope:19]
- The 9 are grouped into 2 families + 1 strengthen. But §A STILL NAMES 9 individual `H-*`.

So the live target is the **9 named heuristics**, not the brief's looser proposal count.

---

## Scorecard per merge candidate

### MERGE-CANDIDATE 1 — Reference Doctrine trio: H-REF-ENTRY / H-REF-LOADER / H-NO-HARDCODE

| | H-REF-ENTRY | H-REF-LOADER | H-NO-HARDCODE |
|---|---|---|---|
| Concept | content-shape of ONE entry (trigger is decision-triggering) | collection-level discoverability mechanism (Map + emitter) | generality of reference BODY (pattern vs instance) |
| Trigger cardinality | per-reference | per-skill, ≥4 refs | per-category-reference |
| Evaluator lint | L1-015 terse-value-cell | Map/loader presence | L1-016 hardcoded-category |
| Hickey axis | Value (entry semantics) | Identity/Time (discoverability at task time) | Value (generic vs concrete) |

**Falsifier run (the test the merge must survive):**
- Skill with 2 refs: needs H-REF-ENTRY, does NOT trigger H-REF-LOADER (≥4 gate). → independent.
- Reference Map present but entries are vocab dumps: H-REF-LOADER PASS, H-REF-ENTRY FAIL. → independent.
- Perfect `load WHEN` line on a reference that defines the category by one CosmosDB instance:
  H-REF-ENTRY PASS, H-NO-HARDCODE FAIL. → independent.

All three cells of each 2×2 populate. **VERDICT: orthogonal. Merge REJECTED. Keep all three.**
(DOCTRINE-ANCHORED: distinct axes per *Simple Made Easy*; ARTIFACT-OBSERVED: three independent
evaluator lints fire on different witnesses.)

### MERGE-CANDIDATE 2 — H-ACCESS-BOUNDARY vs H-VERIFY-CLI (the brief's strongest-looking merge)

The coordinator's hypothesis: "H-ACCESS-BOUNDARY is just H-VERIFY-CLI applied to execution."
**This is the trap. It is wrong.** They braid two DIFFERENT Hickey axes:

- H-VERIFY-CLI = **Value/provenance** axis: *was this command actually run?* (epistemic status).
- H-ACCESS-BOUNDARY = **Authority/capability** axis: *can THE AGENT run it?* (DIRECT vs GATED).

**2×2 (verified × agent-accessible) — all four cells real:**

| | agent-runnable (DIRECT) | agent-gated (GATED) |
|---|---|---|
| verified | ideal | run by a privileged human, agent cannot reproduce — H-VERIFY-CLI PASS, H-ACCESS-BOUNDARY must forbid "agent proves X" |
| unverified | runnable but never run — H-VERIFY-CLI FAIL, access fine | worst case — both fire |

The off-diagonal cells are exactly what makes them orthogonal. The brief's own line "DIRECT vs
GATED posture can differ within one surface" [plan §A:29] is the proof: access-posture varies
*independently* of verification-status. **Merging them would COMPLECT provenance with authority** —
the precise anti-move this doctrine exists to catch. **VERDICT: orthogonal. Merge REJECTED. Split is correct.**
(Highest-confidence finding — but it CONFIRMS the brief, does not break it.)

### MERGE-CANDIDATE 3 — H-PARALLEL ⊂ H-PHASE-CONTEXT  ★ BREAK FOUND

- H-PHASE-CONTEXT [FB-10]: operational skill ships a phase model with a **non-skippable Context phase**
  + AskUserQuestion escape.
- H-PARALLEL [FB-9]: a time-critical / multi-source skill **dispatches independent context lanes as
  ONE parallel batch.**

**The single shared concept: "the Context phase must be a real, well-formed context-gathering gate."**
H-PHASE-CONTEXT asserts THAT the Context gate exists and is non-skippable. H-PARALLEL asserts HOW that
gate gathers (concurrently, not serially). Parallel context-lane dispatch is *a tactic that lives
inside the Context phase* — it has no meaning outside a context-gathering step.

**Complecting test:** to author or change "dispatch context in parallel," you must already be inside
the Context-phase model. You cannot reason about H-PARALLEL without loading H-PHASE-CONTEXT's Context
gate. That is the definition of complecting (changing/understanding one forces the other). The
apparent orthogonality ("a skill could have a serial Context phase") is the SAME relationship FB-1↔FB-7
had — coarse rule + refinement of the *same* concept — which the plan ALREADY ruled is ONE heuristic
(H-REF-ENTRY). By the plan's own consistency standard, H-PARALLEL is a sub-bullet of H-PHASE-CONTEXT,
not a peer heuristic. The evaluator check "≥2 independent sources dispatched concurrently" is a
property OF the Context phase and rides the same phase-presence witness.

**VERDICT: MERGE ACCEPTED. H-PARALLEL → sub-clause inside H-PHASE-CONTEXT (the "Context phase gathers
in parallel" rule).** Zero enforceable signal lost — the parallel lint becomes a refinement of the
Context-phase lint.

### MERGE-CANDIDATE 4 — H-KIND-RECOGNITION is internally complected  ★ SPLIT-THEN-ABSORB

H-KIND-RECOGNITION [FB-11] bundles TWO concepts:
- (a) **classifier/routing skill emits an explicit KIND recognition cue** for recurring sub-classes —
  novel, authoring-structural, classifier-specific. Legitimately new.
- (b) **golden/knowledge enumerate >1 REAL failure mode** — this is a **golden-completeness** property.
  It is NOT classifier-specific; it is the existing golden/example doctrine surface. The plan's own §C
  lands this half as a **GOLDEN extension** ("golden >1 failure mode … land as GOLDEN extensions")
  [plan §C:61], not as a new lint family.

So H-KIND-RECOGNITION complects a classifier-authoring rule (a) with a golden-quality rule (b) that
belongs to pre-existing GOLDEN doctrine. **Complecting test:** changing the golden-completeness bar
should NOT drag classifier-cue authoring with it, and vice versa — they vary independently and the plan
already routes (b) to a different enforcement surface.

**VERDICT: keep H-KIND-RECOGNITION for half (a) only (classifier KIND cue). Route half (b) into the
existing GOLDEN strengthening, NOT a new heuristic.** This matches plan §C's own split — §A's single
named heuristic is more-fused than §C's enforcement. Align §A to §C.

### H-EFFECT-GATE [L-9] — checked, NOT merged

Binds post-action effect-witness close ("closed by observed effect, never return code") + rollback
escalation. Test vs H-VERIFY-CLI: verify-CLI is *pre-documentation* (command provenance); effect-gate
is *post-action runtime closure* (Time axis — when is the work done). Different axis, different lint
(GOLDEN-STATE-DELTA strengthening). **Orthogonal. Keep.** (The rollback + effect-witness are two facets
of ONE concept "close on observed effect," correctly already one heuristic.)

---

## Minimal distinct set (loses zero enforceable signal)

**7 named builder heuristics + 1 GOLDEN-doctrine strengthening** (down from 9 named):

| # | Heuristic | Status | Axis it owns |
|---|---|---|---|
| 1 | H-REF-ENTRY | keep | entry semantics (decision-triggering value) |
| 2 | H-REF-LOADER | keep | collection discoverability (Map + emitter, ≥4) |
| 3 | H-NO-HARDCODE | keep | reference body generality (pattern + ≥2 ex) |
| 4 | H-ACCESS-BOUNDARY | keep | execution Authority (DIRECT vs GATED) |
| 5 | H-VERIFY-CLI | keep | command provenance (run before documenting) |
| 6 | H-EFFECT-GATE | keep | post-action closure on observed effect (Time) |
| 7 | H-PHASE-CONTEXT | keep, ABSORBS H-PARALLEL | phase model + non-skippable Context gate (incl. parallel-dispatch sub-clause) |
| — | H-KIND-RECOGNITION | keep ONLY the classifier-cue half | classifier KIND recognition cue |
| — | golden >1-failure-mode | move to GOLDEN strengthening, NOT a heuristic | golden completeness (existing doctrine) |

Net: **9 named → 7 heuristics** (H-PARALLEL absorbed; the golden-completeness half of
H-KIND-RECOGNITION demoted to a GOLDEN extension). H-KIND-RECOGNITION survives as a (narrowed) 7th.

## Conditional belief-changes (route impact)

- **IF H-PARALLEL absorbed into H-PHASE-CONTEXT →** plan §A drops one `**H-*: title**` triple from L2
  (≈7 lines / ~0.4KB recovered against the 2.51× negative-headroom body — real attention+byte win on a
  body that is ALREADY over ceiling). §C's "parallel-context (≥2 independent sources)" lint becomes a
  sub-assertion of the non-skippable-Context-phase lint sharing ONE provenance-gated witness, not two
  separate evaluator entries → one fewer L1 catalog row to symmetry-pair (C2).
- **IF H-KIND-RECOGNITION narrowed to classifier-cue only →** §A keeps the heuristic but §C's
  "golden >1 failure mode" requirement attaches to the existing `GOLDEN` strengthening (already planned
  at §C:60-61), NOT a new lint — eliminating a double-count where §A implied a fused heuristic and §C
  implied a GOLDEN extension. Removes a latent symmetry ambiguity (C2): the golden bar is owned by
  GOLDEN doctrine, the cue bar by the heuristic.
- **IF the 6 orthogonal heuristics confirmed (1-6) →** NO change to §A/§C for those; the brief's
  atom-per-item granularity is VINDICATED for them and matches the skill's existing 40-fine-heuristic
  idiom. Do not over-merge: collapsing H-ACCESS-BOUNDARY into H-VERIFY-CLI would itself be a complecting
  regression (provenance × authority) — an anti-pattern §9.1-style "looks cleaner, fuses two axes."

## Where the brief was RIGHT (could not break it)

The dominant outcome is that the brief's granularity is *mostly correct* — 6 of 9 map cleanly distinct
Hickey axes with independent witnesses, matching the builder's established 40-fine-heuristic idiom.
Over-consolidating them (the full-scope.md "3 doctrine clusters" hypothesis) would COMPLECT orthogonal
concerns into mega-heuristics whose evaluator lints could no longer fire independently — gameable
metrics (violates C2 symmetry). The correct move is surgical: 2 merges, not wholesale clustering.

## Evidence labels

- A1 (ARTIFACT-OBSERVED): plan §A:20-33, §C:54-63; full-scope:19-33; map-builder Q1 (40 uniform
  `**H-NAME**` heuristics), Q7 (2.51× negative headroom).
- A2 (AXIS-INFERRED): H-PARALLEL ⊂ H-PHASE-CONTEXT (shared concept = Context-phase quality; reasoning
  chain: parallel dispatch is meaningless outside a context-gathering gate). H-KIND-RECOGNITION internal
  complecting (classifier-cue vs golden-completeness vary independently; plan §C already routes them to
  two surfaces).
- A3 (UNVERIFIED): the exact line-cost recovered by absorbing H-PARALLEL is estimated, not measured —
  resolving probe: draft both forms and run `check-skill-size.sh`. Does not change the merge verdict
  (the complecting argument stands regardless of byte count).
