---
task_id: 2026-04-26-001
agent: simplicity-maniac
status: complete
summary: Simple-vs-easy audit of the rca-holistic skill upgrade. Four parallel decompositions (DNA axes, model tests, story beats, level dimensions) braid one underlying concept ("a level installs a transferable model"). "Mental model" is overloaded across four meanings. Story/structure/models are the same concept with three vocabularies. Dogfood predates upgrade so cannot prove the new contracts. Verdict: PROCEED-WITH-CHANGES (consolidate or block delivery).
---

# Verdict
PROCEED-WITH-CHANGES — but the changes are structural, not editorial. Without them the skill teaches easy (copy-pasteable rigor habits) instead of simple (one-fold disciplines).

# What's been complected (concrete patches required)

1. **Collapse the four parallel decompositions into ONE level-construction contract.** DNA's 4 axes, mental-model's 5 tests, storytelling's 5 beats, and the ladder's 6 dimensions are four projections of the same primitive: *what makes a level install a transferable model*. Pick the per-level dimension table (`holistic-ladder.md` §Per-level dimensions) as the canonical surface; demote the other three to *views over* that surface, not independent contracts. Currently a level author must satisfy 4+5+5+6=20 slots that overlap silently (DOCTRINE-ANCHORED: Hickey, complecting = forced co-variation; ARTIFACT-OBSERVED: SKILL.md:39-92 vs mental-model-construction.md:21-40 vs holistic-ladder.md:7-17).

2. **Disambiguate "mental model".** The term names four different things in SKILL.md alone (reader brain-state line 131; named compressed schema line 150; model-graph composition mental-model-construction.md:69-104; artifact-level frame line 116/129). Rename: `inherited-model` (reader endgame), `level-model` (the named schema per level), `model-graph` (composition rule). Drop the "RCA-IS-a-mental-model" framing — it's a slogan, not a construct, and it conflates the artifact with its effect.

3. **Externalize meta-state to the manifest.** Per-level model name, axiom, pattern, prediction, connections, freshness verdict, adversarial finding, narrative arc position — all currently live implicit in prose. A Phase-7 agent in a fresh session re-derives them by re-reading the doc. Add a structured `rca-manifest.json` (or front-matter block) with `levels[].model_name`, `levels[].axiom`, `levels[].evidence_probe`, `evidence_ledger[]`, `adversarial_findings[]`. Otherwise resumability is theater.

4. **Kill story OR structure as a separate discipline.** `storytelling-discipline.md` 5 beats = `holistic-ladder.md` levels grouped by phase. The arc adds *voice* and *explicit inversion* — those are 2 rules, not a 250-line discipline. Fold into the ladder as two cross-level rules; delete the rest.

5. **Demote "patterns" to honest gestures or lift to full pattern shape.** Current "patterns instantiated" entries (`gate-with-timeout`, `opt-in-CI-with-blocking-gate`) are names without GoF problem/solution/consequences structure. Either define each in a pattern catalog with the four GoF slots, or rename the dimension to "**named class label**" and admit it's a tag, not a pattern.

6. **Resolve axioms ≡ first principles.** The skill uses both interchangeably (SKILL.md:64 "Axiom 3 — First principles (axioms, not facts)"). Pick one term. "First principles" is honest; "axiom" implies formal-system status the skill cannot deliver.

7. **Decouple the dogfood from the contracts it predates.** SKILL.md:600 cites `examples/01-mfrr-activation-crashloop/` as exemplar; mental-model-construction.md:122 says "If the dogfood does not survive this measurement, the skill is incomplete." The dogfood was authored before the new 5-tests / 5-beats / 6-dimensions contracts. Either re-author the dogfood against the new contracts before shipping the upgrade, or stop citing it as proof.

# Q1-Q8 attack notes

**Q1.** Single underlying concept: *a level installs one transferable model, evidenced by a probe, named in vocabulary the next level reuses*. The four sets are projections — DNA-axes = what dimensions of the system the model captures; tests = quality gates on the model; beats = where the model lands in the reader's reading order; dimensions = the level template fields. Orthogonality claim fails: "compressed" (test 2) ≡ "compress a model from one angle" (DNA axis 1) ≡ "Mental model installed" (dimension 2) ≡ Beat 3 voice rule. (SKILL.md:39-92 vs mental-model-construction.md:21-40 vs storytelling-discipline.md:30-103 vs holistic-ladder.md:7-17)

**Q2.** Four uses, only two load-bearing. Load-bearing: (b) named compressed schema per level; (c) model-graph composition. Accidental: (a) reader brain-state — a *consequence*, not a construct; (d) "RCA-IS-a-mental-model" — a frame, not an operational rule. The conflation lets the skill claim depth ("we install models!") while delivering only (b).

**Q3.** Redundant. Story = ordering of model installations + voice. Structure = ordered model installations. Models = the schemas. Strip vocabulary: story-arc-beats map 1:1 to L1-L3, L4 onset, L4-L7, L8-L9, L10-L12 (storytelling-discipline.md:13-27 ≡ SKILL.md:166-179). The genuinely additive content in storytelling-discipline.md is *explicit inversion* (lines 104-135) and *voice register* (lines 86-103). Two rules, not a discipline.

**Q4.** Implicit. State carried across phases: input inventory (Phase 0), evidence ledger (Phase 2), level structure with adversarial verdict (Phase 3), narrative draft (Phase 4), L11 + adversarial findings (Phase 5), lessons cross-refs (Phase 6), reproducibility verdict (Phase 7). Most of this lives in prose inside the RCA itself or in adversarial-review-artifact paths *named in front-matter only when status=complete* (SKILL.md:546). A two-session run re-derives: per-level model names (re-parsed from prose), evidence ledger (no canonical location), adversarial-finding ledger (file path stored in front-matter, content not summarized). State+identity+time complect: the RCA document IS the state, AND the deliverable, AND the audit log. Three roles in one artifact.

**Q5.** Axioms ≡ first principles ≡ SKILL.md axis 3 — three names for one thing. "Patterns" fail GoF shape: holistic-ladder.md:43 lists "GitOps + Helm + image registry; separation-of-concerns by repo boundary" — those are tags. No problem/solution/consequences. Dogfood lessons are pattern-shaped (`pattern + probe + defense` SKILL.md:525) which is genuinely close to GoF (problem/solution/consequences) — but only L10 lessons enforce that shape. The per-level "patterns instantiated" dimension is a different, weaker contract.

**Q6.** Simplest version: **(a)** named-reader endgame; **(b)** evidence-ledger of A1/A2/A3 claims with freshness probes; **(c)** ordered levels each producing one named compressed schema with one piece of externally-witnessable evidence; **(d)** one externalized adversarial pass before sign-off. Four primitives. Current SKILL.md = DNA-4 + 12 levels + 6 dimensions + 5 tests + 5 beats + 8 phases + 16 heuristics + 11 validator gates + 4 decision frameworks + 15 anti-patterns. Delta = ~70 surfaces a level author tracks. Most are restatements.

**Q7.** Easy. Mermaid as default for "natural fit" (holistic-ladder.md:60,73,86,99,112,125,138,151,164,177) is a copy-paste habit; ASCII fallback exists but Mermaid is named first in 9 of 12 levels. Hyphenated-named-models (`TenneT-as-pacemaker`, `trigger:none-as-silent-drift`) are easy *labels*; whether they pass test 3 (predictive) and test 4 (transferable) is left to author judgment with no probe. The skill teaches habits that *look* like Hickey-discipline; it does not enforce the discipline.

**Q8.** Slippage. Dogfood was authored before the upgrade, lacks per-level explicit named-model declarations, lacks 5-beat narrative-arc tagging, lacks per-level axioms-list. Mental-model-construction.md:122 says "If the dogfood does not survive this measurement, the skill is incomplete and the example must be upgraded" — this is the skill anticipating its own slippage and deferring it. Shipping the upgrade with this deferral is GATE-FAIL on the user's "no space for mistakes" standard.

# What the simple version of this skill would look like

```
SKILL.md (~150 lines):
  - Named reader + endgame (replicate / explain / defend / predict)
  - 12 levels as a menu with selection rule
  - Per level: anchor question + one named compressed schema + one
    probe-with-evidence + axiom + stop-rule  (ONE table, ONE contract)
  - Two cross-level rules: vocabulary-continuity, explicit-inversion
  - Evidence ledger as structured front-matter (not prose)
  - One externalized adversarial pass, mandatory, before complete
  - Anti-patterns as a closing checklist

References:
  - claim-classification.md (kept — it carries unique content)
  - probe-rationale-pattern.md (kept — unique)
  - anti-patterns.md (kept — unique)
  - DELETE: mental-model-construction.md (fold tests into the level
    contract; tests 1,2,3,5 collapse into "named compressed schema +
    one probe"; test 4 is the rephrase test, already in L10)
  - DELETE: storytelling-discipline.md (keep only the explicit-inversion
    rule and the voice register, fold into SKILL.md as 2 cross-level rules)
  - holistic-ladder.md becomes the level contract surface
```

Net delete: ~600 lines of overlapping doctrine. Net add: structured evidence-ledger schema + dogfood re-authored against the new contract. Result: one fold per concept. Currently: four folds per concept, three of them decorative.
