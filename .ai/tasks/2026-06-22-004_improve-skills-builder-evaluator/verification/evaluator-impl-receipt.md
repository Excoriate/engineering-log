---
task_id: 2026-06-22-004
agent: verification-engineer
timestamp: 2026-06-22T00:00:00Z
status: complete
summary: |
  Implemented evaluator-side symmetry for the builder change-set: L1-019
  (reference-description, MAJOR, mirrors builder G2), L1-020 (reference-map,
  MINOR, mirrors H-REF-LOADER), and strengthened GOLDEN-STATE-DELTA to require
  a recovery/escalation path co-located with a failure context on top of the
  existing fixture+observed-effect requirement. Added catalog rows to SKILL.md,
  a doctrine row to skill-type-matrix.md, a self-skill Reference Map, and
  positive+negative tests. All 5 evaluator test suites pass; both meta-skills
  and the eneco-sre exhibit run without crash and behave sanely.
---

# Evaluator Implementation Receipt — L1-019, L1-020, GOLDEN-STATE-DELTA

## Key Findings

- all_tests_pass: L1, GOLDEN, L0, classify, validate_eval_set all exit 0
- no_regressions: self-skill stays L1 band=READY findings=0 and GOLDEN READY
- exhibit_sane: eneco-sre (artifact) + builder (state-delta) + evaluator all READY, no crash
- lint_caught_own_slop: existing L1-001 flagged a backtick glob in a draft catalog row; fixed

EVAL ROOT: `/Users/alextorresruiz/Dropbox/@GITHUB/@oss/stdlib/std/skills/01_context_engineering/skills-evaluator`

All paths below are relative to EVAL ROOT unless absolute.

## Changes (file:line)

### 1. L1-019 reference-description (MAJOR, provenance-gated)

- `scripts/evaluate_l1.py` — new `_ref_frontmatter_description()` and
  `reference_description_findings()` helpers inserted at evaluate_l1.py:830-916
  (immediately before `SOFT_MODAL_PATTERNS`). Mirrors builder gate G2
  (`skills-builder/scripts/validate-structure.sh:219-264`): parses ONLY the
  first `---`…`---` fence, strips surrounding single/double quotes + trailing
  whitespace, a folded scalar (`>`/`|`) counts as present (non-empty indicator),
  no-frontmatter file → `(no-frontmatter)` offender, empty/absent description →
  offender. Provenance-gated (early-return when not `provenance`), mirroring
  `design_phase_findings`/`structure_declaration_findings`. Severity MAJOR
  (structural L1 class). Message names offending file(s).
- Registered in `main()` at evaluate_l1.py:1080
  (`findings.extend(reference_description_findings(skill_dir, skill_md, provenance))`).

### 2. L1-020 reference-map-present (MINOR, provenance-gated)

- `scripts/evaluate_l1.py` — new `reference_map_findings()` helper at
  evaluate_l1.py:918-947. Counts top-level `references/*.md` (non-recursive,
  matching the "top-level" spec); when `provenance` and count >= 4 and SKILL.md
  body has no `^## Reference Map` section → MINOR finding. Docstring cites
  `references/l2-residency-contract.md` row L1-020 and builder `H-REF-LOADER`.
  MINOR does NOT block the band (band logic: `blocked = severity in
  {CRITICAL,MAJOR}`), so it never false-FRAGILEs a skill over a missing index.
- Registered in `main()` at evaluate_l1.py:1081
  (`findings.extend(reference_map_findings(skill_dir, skill_md, text, provenance))`).

### 3. GOLDEN-STATE-DELTA strengthen (MAJOR)

- `scripts/evaluate_golden.py` — added `STATE_DELTA_RECOVERY_RE` and
  `STATE_DELTA_CLOSE_CTX_RE` at evaluate_golden.py:56-72 (the EXACT
  adversarially-verified regexes from the spec). Rewrote `check_state_delta`
  at evaluate_golden.py:213-251: split the original combined regex into
  `has_fixture` (`recorded-fixture|fixture ->|post-condition`) AND
  `has_observed_effect` (`observed-effect`); KEEP the original fixture/effect
  requirement (either missing → original message, early return); ADD a second
  requirement `has_recovery AND has_close_ctx` (new message). Net predicate:
  `has_fixture AND has_observed_effect AND RECOVERY.search AND CLOSE_CTX.search`.
  A background "rollback strategy" with no fixture/effect still FAILS on the
  fixture half (proven by test sd-bg-rollback). A recovery worded "compensating
  revert on failure" PASSES (proven by test sd-recovery; also by the real
  builder skill, state-delta, which is READY).

### 4. Catalog + doctrine rows (no inline narration)

- `SKILL.md` — extended the `scripts/evaluate_l1.py` Operational-Surfaces bullet
  (SKILL.md:555-564) with L1-019 (MAJOR) and L1-020 (MINOR) catalog rows.
  NOTE: an initial draft wrote `` `references/*.md` `` (a backtick glob); the
  existing L1-001 lint correctly flagged it as a non-existent local path and
  flipped the self-skill to FRAGILE. Reworded to prose ("top-level reference
  markdown file") — self-skill back to READY. (The evaluator caught my own slop.)
- `SKILL.md` — added a `## Reference Map` section (SKILL.md:478-486) so the
  self-skill (5 references, builder_provenance) satisfies its own new L1-020
  lint (H-REFLEX-1 reflexivity).
- `references/skill-type-matrix.md` — added a "Reference-Loader Discipline"
  doctrine section (skill-type-matrix.md:119-137) documenting L1-019/L1-020 and
  the state-delta recovery requirement, mirroring builder G2 / H-REF-LOADER.

### 5. Tests

- `tests/test_evaluate_l1.sh:760-958` — L1-019 negative (ref missing description
  FAILS, sibling with-desc not flagged), L1-019 positive (all refs incl. folded
  scalar PASS), L1-020 negative (>=4 refs, no Reference Map FAILS), L1-020
  positive (Reference Map clears it), L1-020 exempt (<4 refs).
- `tests/test_evaluate_golden.sh:530-606` — state-delta with
  fixture+effect+"compensating revert on failure" PASSES (READY); fixture+effect
  but NO recovery FAILS (recovery-half message); background "rollback strategy"
  with NO fixture/effect FAILS (fixture-half message — recovery word does not
  rescue a missing fixture).

## Test results (raw tails)

### Full evaluator suite — all 5 PASS (exit 0)

```text
test_evaluate_l1.sh         EXIT=0 -> ALL L1 TESTS PASSED
test_evaluate_golden.sh     EXIT=0 -> ALL GOLDEN TESTS PASSED
test_evaluate_l0.sh         EXIT=0 -> ALL L0 TESTS PASSED
test_classify_skill_type.sh EXIT=0 -> SUMMARY|type=conceptual|comparability=COMPARABLE
test_validate_eval_set.sh   EXIT=0 -> SUMMARY|layer=L2-FIXTURE|band=READY|findings=0
```

### L1 suite tail

```text
--- L1-020 exempt: a <4-reference provenance skill does NOT fire L1-020 ---
ALL L1 TESTS PASSED
```

### GOLDEN suite tail (new state-delta cases)

```text
--- GOLDEN: state-delta with fixture+effect+'compensating revert on failure' => READY ---
SUMMARY|layer=GOLDEN|band=READY|...|substrate=state-delta
--- GOLDEN: state-delta with fixture+effect but NO recovery path fires GOLDEN-STATE-DELTA ---
SUMMARY|layer=GOLDEN|band=FRAGILE|findings=1|substrate=state-delta
--- GOLDEN: background 'rollback strategy' with no fixture/effect still fires GOLDEN-STATE-DELTA ---
FINDING|...|GOLDEN-STATE-DELTA|...|state-delta substrate requires a recorded fixture + observed-effect proof ...; no fixture/observed-effect surface declared
SUMMARY|layer=GOLDEN|band=FRAGILE|findings=1|substrate=state-delta
ALL GOLDEN TESTS PASSED
```

### Meta-skills + exhibit (no crash, sane behavior)

```text
TARGET evaluator (self):  L1 band=READY findings=0 ; GOLDEN READY substrate=findings
TARGET skills-builder:    L1 band=READY findings=0 ; GOLDEN READY substrate=state-delta
TARGET eneco-sre exhibit: L1 band=READY findings=0 ; GOLDEN READY substrate=artifact
explicit exit codes: exhibit L1=0 GOLDEN=0 ; self L1=0 GOLDEN=0 ; builder GOLDEN(state-delta)=0
py_compile evaluate_l1.py evaluate_golden.py -> OK
```

Sanity notes:
- builder (real state-delta skill) stays READY → strengthened recovery check is
  NOT over-strict on a genuine state-delta golden (real-world positive control).
- exhibit eneco-sre has 7 top-level references AND a `## Reference Map` → L1-020
  correctly does NOT fire; all 7 refs have descriptions → L1-019 does NOT fire.
- L1-019/L1-020 are non-recursive on top-level `references/*.md`; the exhibit's
  `references/troubleshooting/*.md` subdir is correctly out of scope (matches the
  "top-level" spec).

## Tooling compliance

- `shellcheck tests/test_evaluate_l1.sh` → exit 0, no output.
- `shellcheck tests/test_evaluate_golden.sh` → exit 0, no output.
- `python3 -m py_compile` on both scripts → OK. (ruff not installed on this host.)

## Blockers / regressions

- NONE. No functional regression; no tooling failure.
- One in-session defect found and fixed: a draft SKILL.md catalog row used a
  backtick glob `references/*.md` which the existing L1-001 lint flagged as a
  missing local path (self-skill → FRAGILE). Reworded; resolved.
- Out-of-scope observation (NOT introduced by this work): `git status` shows 4
  other `references/*.md` (behavioral-validity, forge-and-comparison,
  reflexivity-audit, scoring-and-reporting) as Modified with 1-line diffs each.
  Their mtimes (22 Jun 13:38) predate this session and they were NOT edited here;
  they are pre-existing uncommitted edits from the prior builder change-set. Only
  `skill-type-matrix.md` among references was edited by this task.
- task-workspace-guard: no exit-2 warnings were surfaced during this run; the
  receipt was written to the task verification dir and re-read successfully.
