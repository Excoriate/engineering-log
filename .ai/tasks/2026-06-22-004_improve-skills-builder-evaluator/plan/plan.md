---
task_id: 2026-06-22-004
agent: claude-code
status: draft
summary: DRAFT change-set for skills-builder + skills-evaluator (FB-1..11 + L-1..10). Pre-adversarial. Target for kant/simplicity/el-demoledor/socrates attack.
---

# Change-Set Plan (DRAFT — pre-adversarial)

Ground truth from `context/{map-builder,map-evaluator,verify-exhibit,full-scope-and-consolidation}.md`.

## Binding constraints (non-negotiable)
- **C1 SIZE:** builder L2 = 70369 B / 1075 lines vs 28000 B / 500-line ceiling (2.51× over, passes only via §8 justification). **Every L2 add MUST be net-neutral or net-negative.** Re-run `check-skill-size.sh` as the gate; do NOT pad the §8 justification to pass.
- **C2 SYMMETRY:** every builder heuristic that yields a structural signal needs a paired evaluator lint, else the metric is gameable. Substrate enum lives in 3 copies (builder doctrine + 2 evaluator constants) — change in lockstep.
- **C3 ADDITIVE + provenance-gated:** new evaluator lints fire only on `builder_provenance:true` skills (legacy skills not penalized).
- **C4 OWNERSHIP (brief correction):** G2 + aggregator are BUILDER-owned. FB-5/L-2/L-3 are builder edits.
- **C5 L2-RESIDENCY:** if a Reference Map becomes L2-mandatory, add a row to `l2-residency-contract.md` or a future G6 refactor silently evicts it.

## A. Consolidation decision (granularity)
Brief lists 6 heuristics; +FB-9/10/11 ⇒ up to 9. To respect C1, group into **2 new families + strengthen 1**, each L2 stub TIGHT (CONDITION/ACTION/REASONING, detail pushed to L3):

**Family: Reference Doctrine**
- `H-REF-ENTRY` (FB-1/7, L-4) — every reference ENTRY = decision-triggering `load WHEN <scenario> → gives <value>`; grouped form allowed (group header = coarse trigger, per exhibit). Detail → L3.
- `H-REF-LOADER` (FB-2/3, L-5) — multi-reference (≥4) skill ships a primacy `## Reference Map` (linked inventory) + a deterministic loader/emitter that prints the per-task reference set. Detail → L3.
- `H-NO-HARDCODE` (FB-4, L-6) — a CATEGORY reference states the generic PATTERN + ≥2 examples; never one instance as the definition.

**Family: Operational Skills** (apply WHEN substrate is operational/state-delta/routing — conditional, not universal)
- `H-ACCESS-BOUNDARY` (FB-6, L-7) — ops skill ships an execution-access-boundary reference (agent-runnable vs gated probes) wired to loader + write gate; never claim a proof the agent cannot run.
- `H-VERIFY-CLI` (FB-8, L-8) — ops references carry VERIFIED commands (probe before documenting) AND the verification note/provenance travels WITH the reference (not only in skill-design ledger — per exhibit correction). DIRECT vs GATED posture can differ within one surface.
- `H-EFFECT-GATE` (L-9) — a `state-delta × observed-effect` skill binds a post-action effect-witness close ("closed by observed effect, never the command's return code") + a partial-fix/rollback escalation ("regressed → escalate, don't re-fire").
- `H-PARALLEL` (FB-9) — a time-critical / multi-source skill dispatches independent context lanes as ONE parallel batch.
- `H-PHASE-CONTEXT` (FB-10) — operational/investigation skill uses a structured phase model (judgment gates, not ceremony) with a NON-skippable Context phase + an explicit AskUserQuestion clarification escape.
- `H-KIND-RECOGNITION` (FB-11) — a routing/classifier skill emits an explicit KIND recognition cue for recurring sub-classes; golden/knowledge enumerate >1 REAL failure mode.

> Open question for adversary: is 9 heuristics the right granularity, or do Reference-Doctrine items collapse to 1–2? Decide by complecting test, not preference.

## B. Builder edits (`skills-builder/`)
1. **SKILL.md heuristics** — add the families above as TIGHT `**H-NAME: title**` + CONDITION/ACTION/REASONING triples under new `### Reference Doctrine` / `### Operational Skills` subsections in `## Heuristics`. Net-neutral funding:
   - REPLACE the verbose `## Operational Surfaces` block (SKILL.md:1005-1069, ~65 lines) with a tight builder `## Reference Map` (dogfood FB-3 on the builder itself) — net reduction.
   - Keep each new heuristic's deep detail in L3; L2 carries only the triple + an L3 pointer.
   - Re-run `check-skill-size.sh`; net L2 delta target ≤ 0.
2. **New L3 references** (unbudgeted, but keep small):
   - `references/reference-doctrine.md` — the load-WHEN entry format (grouped allowed), Reference Map shape, loader/emitter pattern, no-hardcode rule. Exhibit template: eneco-sre `## Reference Map` + `classify-incident.sh` LOAD NOW.
   - `references/operational-skill-doctrine.md` — access-boundary reference type, verify-CLI discipline (with in-reference provenance), effect-gate + rollback, parallel context, phase+context-gate, KIND recognition. Exhibit templates cited (eneco-sre H-EFFECT-1/H-ROLLBACK-1, mc-avd-execution-boundary.md).
3. **`references/skill-structure.md`** — change reference frontmatter convention `title, summary, type` → `title, description, type` (FB-5). [FORK: see §E.]
4. **`scripts/validate-structure.sh` G2 (L-2/FB-5)** — parse frontmatter; require non-empty `description`. Probe all `references/**` + `examples/*/references/**` first; migrate stubs that lack it.
5. **`scripts/validate-specimen.sh` L-1** — line 49: replace bare `placeholder` alternative with scoped `\{\{|\{placeholder\}|todo:|lorem ipsum`. Add positive test (specimen with "no placeholders" PASSes).
6. **`scripts/validate-skill-complete.sh` L-3** — before verdict block (:184), detect `builder_provenance` truthy + missing `skill-design.md`; emit one diagnostic line into the stderr footer (:196-210), NOT the JSON gate array.
7. **`references/design-calibration-loop.md` L-10** — add a "Post-BUILD file-by-file review rounds" section accumulating rules into `skill-design.md` §8 Calibration Record (template row support already exists).
8. **`references/l2-residency-contract.md`** — add a Reference-Map residency row (conditional ≥4 refs) paired to the new evaluator lint id (C5).
9. **Frontmatter migration** — rename `summary:`→`description:` in builder's 14 + evaluator's 5 references [FORK §E]; verify nothing keys off `summary:` first.

## C. Evaluator edits (`skills-evaluator/`)
New lints (python; provenance-gated; SKILL.md gets only catalog rows):
- `L1-015 terse-value-cell` (FB-1/7) — flag reference trigger/when cell that is a single token / pure vocabulary.
- `L1-016 hardcoded-category` (FB-4) — flag a category reference whose trigger names one concrete instance with no ≥2-examples / "e.g." marker.
- `L1-017 unverified-CLI` (FB-8) — ops reference (state-delta substrate / CLI fences) must carry a verification note.
- `L1-018 access-boundary` (FB-6) — ops skill claiming a probe proof must ship an execution-access-boundary reference + claim no proof for an agent-gated tool.
- `L1-019 reference-description` (FB-5 symmetry) — mirror upgraded-G2: reference frontmatter has non-empty `description` (provenance-gated).
- Strengthen `GOLDEN-STATE-DELTA` (`evaluate_golden.py:198-213`, L-9) — also require a rollback/escalation token + effect-witness close-path, not just an effect-surface declaration.
- FB-9/10/11 evaluator checks: parallel-context (≥2 independent sources dispatched concurrently), non-skippable Context phase + clarification escape, classifier KIND-recognition + golden >1 failure mode. (Land as L1 helpers or GOLDEN extensions; provenance-gated.)
- Register each in `evaluate_l1.py` main() extend block + add test in `tests/`.
- Update `references/skill-type-matrix.md` doctrine rows for the new lints.

## D. Verification strategy (P8)
- Run `check-skill-size.sh skills-builder/SKILL.md` → must stay PASS with net L2 delta ≤ 0.
- Run the full builder battery (`validate-skill-complete.sh`) + evaluator battery against BOTH meta-skills (self-test) AND the exhibit `eneco-sre`.
- New lints: POSITIVE fixture = eneco-sre (must PASS all new lints); NEGATIVE fixture = a crafted bad case per lint (must FAIL). Add to `tests/`.
- Frontmatter migration: re-run G2 against all references in both skills + examples → all PASS.
- Fresh-frame re-read of every edited file (different frame than the editor).

## E. FORKS for the user (decide before/after adversarial)
- **FORK-1 (frontmatter):** rename `summary`→`description` across 19 meta-skill references (clean, matches exhibit + SKILL.md field name) vs G2 accepts either (no migration, perpetuates split). Recommend RENAME.
- **FORK-2 (size scope):** net-neutral-via-replace only (safe, this plan) vs ALSO do the deferred §8 full COMPRESS pass of existing 40 heuristics' REASONING (more "optimal", larger/riskier, arguably its own task). Recommend net-neutral now; COMPRESS as a separate follow-up.
- **FORK-3 (granularity):** 9 named heuristics vs fewer consolidated doctrine units — pending simplicity-maniac verdict.

## F. Out of scope / explicitly NOT doing
- No rewrite of the 40 existing heuristics' wording (FORK-2 deferred).
- No behavior change to evaluator scoring weights.
- eneco-sre itself is NOT edited (it is the fixture/exhibit).
