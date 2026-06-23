---
task_id: 2026-06-22-004
agent: claude-code
status: pending_review
summary: Adversarially-vetted change-set (plan v2) for skills-builder + skills-evaluator. All 4 adversarial lanes receipted; forks resolved; awaiting user scope sign-off.
---

# Plan v2 — Adversarially-Vetted Change-Set

Supersedes `plan/plan.md`. Every load-bearing claim below is FACT (source-verified this session) unless tagged INFER.

## 1. Adversarial Receipts (4 lanes, all findings classified)

| # | Finding | Verdict | Evidence / plan change |
|---|---------|---------|------------------------|
| S1 | Merge `H-PARALLEL ⊂ H-PHASE-CONTEXT` (parallel dispatch is *how* the Context phase gathers) | **RESOLVE** | v2 §3: H-PARALLEL becomes a sub-clause of H-PHASE-CONTEXT; not a standalone heuristic |
| S2 | `H-KIND-RECOGNITION` internally complected (cue-rule + golden-completeness) | **RESOLVE** | v2 §3: narrowed to the classifier-cue half; golden-completeness → GOLDEN doctrine |
| S3 | Do NOT merge `H-ACCESS-BOUNDARY` into `H-VERIFY-CLI` (orthogonal: authority axis vs provenance axis) | **RESOLVE** | v2 keeps them distinct (confirms draft) |
| K1 | Size strategy must be SPLIT not REPLACE — `## Operational Surfaces` (SKILL.md:1005-1069) is an enforcement contract w/ BLOCKED-PATH (line 1018: "do NOT cite a subset of gates as validated"); REPLACE deletes it | **RESOLVE** | Source-verified by coordinator (read 1005-1069). v2 §4 = SPLIT: keep primacy `## Reference Map` + critical BLOCKED-PATH lines in L2; move verbose per-surface evidence/fallback detail to a new L3 ref |
| K2 | Reject full-COMPRESS of the 40 heuristics' REASONING — violates the skill's own H-KNOW-1 ("reasoning turns instructions into transferable judgment") | **RESOLVE** | FORK-2 closed: no REASONING compression; the SPLIT reclaims the L2 budget instead |
| K3 | Real cost = heuristic-COUNT attention dilution (40→49) in an unindexed lost-middle block | **PARTIAL/DEFER** | Mitigated by consolidating to 7 (not 9). Optional heuristic index = DEFER (adds lines; revisit if dilution observed) |
| O1 | Ops scoping unenforceable: `classify_skill_type.py:12` = `conceptual/research/configurable/executable` only; drafted ops lints L1-017/018 gate on provenance → regress on golang-cli/doc-validator | **RESOLVE** | Source-verified (no ops class; `declared_substrate()` reads `state-delta` at evaluate_golden.py:105-127). v2 §6: ops lints become **substrate-gated GOLDEN checks** (fire only on declared `state-delta`), NOT provenance-gated L1 |
| O2 | `H-PARALLEL` has no structural witness (runtime parallelism) → unsalvageable as a lint | **RESOLVE** | Doctrine-only heuristic (merged into H-PHASE-CONTEXT per S1); no evaluator lint; residual noted |
| O3 | Universal (4) vs ops-conditional split | **RESOLVE** | Adopted as v2 §3 scoping table |
| O4 | Untested falsifier: build a golang-cli skill, run new lints | **DEFER → P8** | Verification runs new lints against a non-ops example skill as negative-regression proof |
| D1 | V1 specimen regex CRITICAL — proposed `{placeholder}` misses `[placeholder]`,`<placeholder>`,`PLACEHOLDER`,`placeholder:`,`TODO`,`TBD`,`FIXME`,`XXX` | **RESOLVE** | v2 §5.1 uses el-demoledor's verified hardened regex (drop `-i`; delimited/ALLCAPS/colon); substance-gate backstops bare-lowercase residue |
| D2 | V2 G2 CRITICAL — 26/27 refs use `summary:`; G2-upgrade before migration = self-inflicted NOT-READY | **RESOLVE** | v2 §5.2 + §7 sequencing: `summary→description` migration is a HARD predecessor to the G2 upgrade; verified awk-fence parse |
| D3 | V3 provenance grep HIGH — fails OPEN on `builder_provenance : true` (spaced colon); false-fires in body ```yaml block | **RESOLVE** | v2 §5.3 uses awk-fenced hardened check (frontmatter-confined, space-tolerant, full-line anchored) |
| D4 | V4 golden rollback token MEDIUM-HIGH — false-FAILs "compensate/revert/undo"; false-PASSes background "rollback" | **RESOLVE** | v2 §6 uses synonym-set + co-located failure-context anchor (avoids re-committing the L-1 lexical-brittleness anti-pattern) |

Discipline check: 0 systematic Defer (1 DEFER = falsifier→P8; 1 PARTIAL = optional index). 0 Rebut-without-evidence. All accepted findings produce a behavioral v2 change.

## 2. Binding constraints (unchanged + reinforced)
C1 SIZE (net-neutral, SPLIT-funded) · C2 SYMMETRY (heuristic↔lint, substrate enum in 3 copies) · C3 substrate-gated ops lints (NOT provenance) · C4 OWNERSHIP (G2+aggregator are builder) · C5 L2-residency row for Reference Map.

## 3. Final heuristic set — 7 named + 1 GOLDEN strengthening (down from 9)

| Heuristic | Scope | Evaluator pairing (C2) |
|-----------|-------|------------------------|
| `H-REF-ENTRY` (FB-1/7/L-4) — entry = decision-triggering `load WHEN <scenario> → gives <value>`; grouped form allowed | UNIVERSAL | L1-015 terse-value-cell (provenance-gated) |
| `H-REF-LOADER` (FB-2/3/L-5) — ≥4-ref skill ships primacy `## Reference Map` + deterministic loader/emitter | UNIVERSAL | L1 Reference-Map-present (≥4 refs) + l2-residency row |
| `H-NO-HARDCODE` (FB-4/L-6) — category ref = generic pattern + ≥2 examples | UNIVERSAL | L1-016 hardcoded-category (provenance-gated) |
| `H-REF-DESCRIPTION` (FB-5) — reference frontmatter carries non-empty `description` | UNIVERSAL | builder G2 upgrade + L1-019 mirror (provenance-gated) |
| `H-ACCESS-BOUNDARY` (FB-6/L-7) — ops skill ships execution-access-boundary ref; never claim an un-runnable proof | OPS (substrate=state-delta) | GOLDEN substrate-gated check (NOT L1) |
| `H-VERIFY-CLI` (FB-8/L-8) — ops refs carry verified commands + the verification note travels WITH the reference | OPS (substrate=state-delta) | GOLDEN substrate-gated check (NOT L1) |
| `H-PHASE-CONTEXT` (FB-10, absorbs FB-9 H-PARALLEL) — ops/investigation skill: phase model as judgment gates + NON-skippable Context phase (independent lanes dispatched in parallel) + AskUserQuestion clarification escape | OPS doctrine | weak/soft; doctrine-only where no clean witness (residual noted) |
| `H-KIND-RECOGNITION` (FB-11, cue-half only) — routing/classifier skill emits explicit KIND recognition cue for recurring sub-classes | ROUTING doctrine | GOLDEN >1-failure-mode (the completeness half) where classifier present |
| **GOLDEN strengthening** `H-EFFECT-GATE` (L-9) — state-delta close binds observed-effect witness + rollback/escalation | substrate=state-delta | strengthen GOLDEN-STATE-DELTA (evaluate_golden.py:198-213) |

## 4. Builder L2 size strategy (SPLIT — K1/K2)
- Add the 7 heuristics as TIGHT `**H-NAME**` CONDITION/ACTION/REASONING triples under new `### Reference Doctrine` + `### Operational Skills` families; deep detail → L3.
- SPLIT `## Operational Surfaces` (1005-1069): keep a tight primacy `## Reference Map` (linked inventory + load-WHEN groups) AND the critical always-on BLOCKED-PATH lines (master gate blocks complete; size budget; don't cite a subset) in L2; relocate the verbose per-surface EVIDENCE-OF-USE + `*-MISSING` fallback detail to new L3 `references/operational-surfaces-contract.md`.
- Add an `l2-residency-contract.md` row for the Reference Map (≥4-ref conditional) so a future G6 refactor cannot evict it (C5).
- GATE: re-run `check-skill-size.sh`; net L2 delta MUST be ≤ 0. Do NOT pad the §8 justification.

## 5. Builder script fixes (hardened per el-demoledor)
1. **validate-specimen.sh:49 (L-1)** — replace bare `placeholder` with: `\{\{|[<{[]([Pp]laceholder|PLACEHOLDER)[]>}]|placeholder:|\bPLACEHOLDER\b|\b(TODO|TBD|FIXME|XXX)\b|(todo|tbd|fixme|xxx):|[Ll]orem [Ii]psum` (drop `-i`). Add positive test ("no placeholders" PASSes) + negative tests ([placeholder]/TODO still rejected).
2. **validate-structure.sh G2 (L-2/FB-5)** — awk-fence frontmatter, require non-empty `description` (strip quotes/space). **HARD predecessor: the summary→description migration (§7) must land first.**
3. **validate-skill-complete.sh aggregator (L-3)** — awk-fenced provenance detection (frontmatter-confined, space-before-colon tolerant, full-line anchor) before the verdict block (:184); emit one diagnostic line into the stderr footer (:196-210), NOT the JSON gate array.
4. **design-calibration-loop.md (L-10)** — add a "Post-BUILD file-by-file review rounds" section accumulating rules into skill-design.md §8 (template row already exists).

## 6. Evaluator edits (symmetry; substrate-gated where ops)
- **evaluate_l1.py (universal, provenance-gated):** L1-015 terse-value-cell, L1-016 hardcoded-category, L1-019 reference-description (mirror upgraded-G2), Reference-Map-present (≥4 refs). Register in main() extend block + tests.
- **evaluate_golden.py (ops, substrate-gated on state-delta via `declared_substrate`):** access-boundary check, verify-CLI check (verification note co-located), and STRENGTHEN `GOLDEN-STATE-DELTA` (:198-213) with el-demoledor's synonym-set + co-located close-context anchor (recovery RE + close-ctx RE; require fixture AND recovery AND close-ctx).
- **skill-type-matrix.md** — doctrine rows for the new lints.
- Keep evaluator SKILL.md additions to catalog rows only (no inline narration).

## 7. Sequencing (dependency-ordered)
1. Frontmatter migration `summary→description` across the 18 builder/evaluator references (SAFE: nothing consumes `summary` — verified). Do NOT migrate the `bad-meta-skill` negative fixtures.
2. Add `description` to the 6 example-skill references that lack it (reveng-doc-validator ×2, rootly-azure-alert-triage ×2, golang-cli-creator ×2).
3. THEN G2 upgrade (depends on 1+2).
4. Builder heuristics + SPLIT + L3 refs + l2-residency row; re-run check-skill-size.sh.
5. Other builder script fixes (specimen, aggregator, calibration-loop).
6. Evaluator lints (universal + substrate-gated) + tests.
7. Verification (§8).

## 8. Verification strategy (P8)
- `check-skill-size.sh` builder SKILL.md → PASS, net L2 ≤ 0.
- Full builder + evaluator battery (`validate-skill-complete.sh`) self-test on BOTH meta-skills AND exhibit `eneco-sre`.
- New lints: POSITIVE = eneco-sre (PASS all); NEGATIVE = crafted bad case per lint (FAIL). O4 falsifier: run new lints against a non-ops example skill (golang-cli-creator) → must NOT fire ops lints.
- G2 post-migration: all references in both skills PASS.
- Fresh-frame re-read of every edited file (frame ≠ editor).

## 9. Forks now resolved by adversarial pass
- FORK-1 → RENAME `summary→description` (safe + required by G2; recommended).
- FORK-2 → SPLIT, no REASONING compress (kant).
- FORK-3 → 7 heuristics + 1 GOLDEN strengthening (simplicity).

Residual USER decision: scope footprint + sequencing (full vs staged) — this change-set is LARGE (load-bearing Operational Surfaces SPLIT + 24-file frontmatter touch + ~5 lints). Surfaced for sign-off before any edit.
