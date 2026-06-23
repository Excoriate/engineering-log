---
task_id: 2026-06-22-004
agent: claude-code
status: draft
summary: Consolidated scope (FB-1..11 + L-1..10) for the skills-builder/evaluator improvement, with overlap map and consolidation hypothesis.
---

# Full Scope + Consolidation Map

## Sources (A1 FACT — read this session)

- Brief: `skills-builder/IMPROVEMENT-NOTES-from-eneco-sre-build-2026-06-22.md` (108 lines) — carries FB-1..8 + L-1..10, proposals in §3.
- Register: `stdlib/.ai/tasks/2026-06-22-001_eneco-sre-skill-build/feedback-register.md` (37 lines) — carries **FB-1..11**.
- **Finding F0 (brief incompleteness):** the brief's §3 proposals propagate only FB-1..8 + L-1..10. **FB-9, FB-10, FB-11 exist in the register but were NOT carried into the brief's proposed changes.** The user's "FB-1…FB-11" was correct. These three must be added to scope.

## Complete actionable set

### Reference-quality cluster (references must be decision-triggering, discoverable, generic, complete)
- **FB-1 / FB-7 / L-4** — reference ENTRY = "load WHEN `<scenario>` → gives `<value>`"; value clause must be decision-TRIGGERING, not a label/vocab dump. (FB-7 is explicitly "deeper FB-1".)
- **FB-3 / L-5(part)** — primacy `## Reference Map` (linked inventory at top) for skills with ≥~4 references.
- **FB-2 / L-5(part)** — deterministic reference LOADER/emitter (`LOAD NOW:` per-task set) so refs are un-overlookable.
- **FB-4 / L-6** — category reference = generic PATTERN + ≥2 examples; never one instance (CosmosDB) as the definition.
- **FB-5 / L-2** — reference frontmatter requires non-empty `description` (+ ideally title+type); evaluator `validate-structure.sh` G2 upgrade.

### Ops-reference cluster (skills that span execution-access boundaries)
- **FB-6 / L-7** — execution-access-boundary reference TYPE (agent-runnable vs gated probes); wired to loader + write gate; never claim a proof the agent can't run.
- **FB-8 / L-8** — ops references carry VERIFIED commands (probe before documenting); DIRECT vs GATED posture can differ within one surface.

### Operational-behavior cluster (how operational/fix/routing skills must behave)
- **FB-9** — H-PARALLEL-1: time-critical / multi-source skill MUST dispatch independent context lanes as ONE parallel batch (not serial).
- **FB-10** — structured phase-model pattern: phases as judgment gates (not ceremony) + a NON-skippable Context phase + an explicit AskUserQuestion clarification escape.
- **FB-11** — routing/classifier skill emits explicit KIND recognition cue for recurring sub-classes; golden/knowledge enumerate >1 REAL failure mode (dogfood against the actual incident).
- **L-9** — H-EFFECT-GATE: a skill whose substrate is `state-delta × observed-effect` must bind a post-action effect-witness gate ("closed by observed effect, never the command's return code") + partial-fix/rollback ("regressed → escalate, don't re-fire").

### Tooling fixes (machinery bugs/gaps)
- **L-1** — `validate-specimen.sh` false-positive: `is_real_specimen()` greps bare word "placeholder"; a specimen saying "no placeholders" is wrongly rejected. Scope regex to `{{`, `{placeholder}`, `lorem ipsum`, `todo:`.
- **L-2** — `validate-structure.sh` G2 description requirement (= FB-5 evaluator side).
- **L-3** — aggregator: one clear line when `builder_provenance:true` but no `skill-design.md` sibling.
- **L-10** — design-calibration-loop supports POST-BUILD, file-by-file review rounds → captured rules in `skill-design.md` §8 (not only a single pre-BUILD specimen pass).

## Consolidation hypothesis (to be ruled on by simplicity-maniac + kant adversarials)

The brief proposes ~6 new `H-*` heuristics + ~5 new evaluator lints. Raw count risks bloating the very meta-skills that preach anti-bloat (the central irony/risk). Hypothesis: encode as **3 doctrine clusters + 4 tooling fixes**, not 11 scattered atoms:

1. **Reference Doctrine** (one consolidated section/reference covering entry-format, Reference Map, loader, no-hardcode, frontmatter) — FB-1/2/3/4/5/7 + L-2/4/5/6.
2. **Ops-Access Doctrine** (execution-access-boundary reference type + verified-CLI discipline) — FB-6/8 + L-7/8.
3. **Operational-Behavior Doctrine** (parallel context, phase model + Context gate + clarification escape, effect-gate close, KIND recognition + multi-failure golden) — FB-9/10/11 + L-9.
4. **Tooling fixes** — L-1, L-2(script), L-3, L-10.

OPEN QUESTION for adversary + user: consolidate (fewer, denser doctrine units) vs. the brief's literal atom-per-item naming (H-REF-ENTRY, H-REF-LOADER, …). Trade-off = discoverability/enforceability of named heuristics vs. attention/size budget of the meta-skill. Decide AFTER size-budget headroom is known (map-builder lane).

## Hard constraints (from brief + governance)
- Changes must be ADDITIVE and tested against the worked exhibit `eneco-sre`.
- builder ↔ evaluator must stay symmetric (every builder heuristic that is checkable gets an evaluator check, and vice versa).
- Do NOT bloat past the size ceiling enforced by `check-skill-size.sh`.
- The exhibit's claimed implementations are the TEMPLATES — but verify them first (some, e.g. L-9 effect-gate, may be absent per brief's own hedge).
