---
task_id: 2026-06-22-004
agent: codebase-analyzer
timestamp: 2026-06-22T00:00:00Z
status: complete
summary: |
  Map of the CURRENT state of skills-evaluator (and its coupling to skills-builder)
  for the FB-1..FB-8 / L-2 / L-3 / L-9 improvement brief. Ownership confirmed by grep
  across BOTH skill roots: validate-structure.sh (G2), validate-skill-complete.sh
  (the aggregator), check-skill-size.sh, and quality-gates.md (G0-G6) all live in
  skills-BUILDER, not the evaluator. The evaluator owns the L0/L1/GOLDEN python lints
  + classify_skill_type.py + validate_eval_set.py. builder_provenance is read by BOTH
  skills (evaluator gates discipline lints on it; builder aggregator runs evaluator
  scripts as EVAL-* gates). Several proposed lints are ALREADY PARTIAL (effect-gate =
  GOLDEN-STATE-DELTA; provenance/design-phase = L0-010/L1-011).
---

# Evaluator Map — current state for the FB-1..8 / L-2/L-3/L-9 brief

## Key Findings

- validate-structure.sh G2 + aggregator are BUILDER-owned, not evaluator
- G2 (builder validate-structure.sh:219-243) only asserts ref first line == `---`; no description check
- aggregator = builder validate-skill-complete.sh; missing-provenance line attaches at CLAIM-LEDGER L160-164
- effect-gate lint ALREADY PARTIAL = GOLDEN-STATE-DELTA (evaluate_golden.py:198-213)
- 4 of 5 proposed lints (terse-value, hardcoded-category, unverified-CLI, access-boundary) are ABSENT
- evaluator SKILL.md = 589 lines, no enforced ceiling; 5 new lints land in python scripts not SKILL.md

All claims carry `A1 FACT` (file:line / grep output) or `A2 INFER` (named reasoning).
Skill roots (abbreviated below):

- `EVAL/` = `/Users/alextorresruiz/Dropbox/@GITHUB/@oss/stdlib/std/skills/01_context_engineering/skills-evaluator/`
- `BUILD/` = `/Users/alextorresruiz/Dropbox/@GITHUB/@oss/stdlib/std/skills/01_context_engineering/skills-builder/`

## 0. Ownership verdict (the brief's terms are BUILDER-owned)

`A1 FACT` (grep both roots, BRAIN-SCAN falsifier executed):

| Brief term | Owner | Evidence |
|---|---|---|
| `validate-structure.sh` + gate "G2" | **skills-BUILDER** | `BUILD/scripts/validate-structure.sh:219-243`; NOT present in EVAL (no `EVAL/scripts/validate-structure.sh`) |
| "aggregator" (missing-provenance message) | **skills-BUILDER** | `BUILD/scripts/validate-skill-complete.sh` (whole file; aggregator header L4-47) |
| G0-G6 gate system | **skills-BUILDER** | `BUILD/references/quality-gates.md:20,191-192`; `BUILD/scripts/validate-structure.sh:15,42` |
| `check-skill-size.sh` (size budget G6) | **skills-BUILDER** | `BUILD/scripts/check-skill-size.sh` |
| L0/L1/GOLDEN lints + classify + eval-set | **skills-EVALUATOR** | `EVAL/scripts/{evaluate_l0,evaluate_l1,evaluate_golden,classify_skill_type,validate_eval_set}.py` |
| `builder_provenance` reading | **BOTH** | Evaluator: `EVAL/scripts/evaluate_l0.py:52-75,82-122`. Builder: aggregator runs evaluator scripts as gates (`BUILD/scripts/validate-skill-complete.sh:178-181`) |

`A2 INFER`: the brief's "skills-evaluator change" column for FB-5/L-2 is mis-attributed —
upgrading G2 is a BUILDER edit (`BUILD/scripts/validate-structure.sh`). The L-3 aggregator
fix is also a BUILDER edit (`BUILD/scripts/validate-skill-complete.sh`). Only the NEW python
lints (FB-1/4/7/8, L-9) are evaluator-owned.

---

## 1. CHECK / LINT CATALOG

### 1a. Evaluator-owned lints (python; the real "evaluator catalog")

Three layers, each emits `FINDING|MEASURED|<L0|L1|GOLDEN>|<sev>|<rule>|<evidence>|<msg>`
(`A1` `EVAL/scripts/evaluate_l0.py:25-26`). Rule-id is the dataclass `rule` field; **convention
for adding a new one = append a new `Finding("<LAYER>-NNN", SEV, evidence, msg)` inside the
relevant `*_findings()` helper, register the helper in `main()`'s `findings.extend(...)` block,
and add a matching test in `EVAL/tests/test_<script>.sh`**.

**L0 — mechanical** (`EVAL/scripts/evaluate_l0.py`, ids via `grep -oE 'L0-[0-9]+'`):

| id | file:line | asserts |
|---|---|---|
| L0-001 | `evaluate_l0.py:186-200` | target is a dir & SKILL.md exists |
| L0-002 | `:205` | frontmatter parses (open+close fence) |
| L0-003 | `:210-233` | `name` present, regex-valid, == dir name |
| L0-004 | `:235-253` | `description` non-empty string, <=1024 chars |
| L0-005 | `:255-274` | `compatibility` string, <=500 chars |
| L0-006 | `:276-285` | `allowed-tools` is a string when present |
| L0-007 | `:315-330` | every `scripts/*.{sh,py}` has `tests/test_<stem>.sh` |
| L0-008 | `:332-344` | every `examples/*/` has `tests/test_examples.sh` |
| L0-009 | `:346-362` | INFO: decision-core (fence-excluded) > 500 lines — **EXEMPT for builder-provenance** |
| L0-010 | `:364-392` | provenance-completeness triplet (marker+substrate+design) — **fires only if >=1 signal** |
| L0-011 | `:287-313` | top-level `model:` pin forbidden (universal; exception via `## Model Pinning Exception`) |

**L1 — coherence + reflexivity** (`EVAL/scripts/evaluate_l1.py`, ids L1-000..L1-014):

| id | helper / file:line | asserts |
|---|---|---|
| L1-001 | `extract_missing_path_findings :109-128` | referenced local path exists |
| L1-002 | `extract_orphan_findings :128-160` | bundled surface is reachable, not orphaned |
| L1-003 | `example_readme_findings :184-210` | example dirs have README |
| L1-004 | `heuristic_findings :228-262` | each heuristic has unique id + CONDITION/ACTION/REASONING |
| L1-005 | `heuristic_findings :268-281` | no duplicate/near-dup heuristic CONDITION (SequenceMatcher >=0.92) |
| L1-006 | `example_reasoning_findings :285-324` | `## Example Reasoning` exists when heuristics exist |
| L1-007 | `dependency_findings :534-601` | deps disclosed in compatibility; **provenance:** named adversarial reviewers => receipt artifact proving Verify+Demolish RAN (`:581-600`) |
| L1-008 | `bundled_resource_findings :603-639` | bundled resources resolve |
| L1-009 | `enforcement_language_findings :845-877` | strong-modal enforcement language present |
| L1-010 | `enforcement_language_findings :879-...` | (enforcement sub-check) |
| L1-011 | `design_phase_findings :777-808` | **provenance:** design artifact (skill-design.md sibling OR `## Design`) |
| L1-012 | `structure_declaration_findings :640-776` | **provenance:** Structure Declaration table (INCLUDED/OMITTED per dir) |
| L1-013 | `model_first_findings :809-844` | flag "read reference BEFORE reasoning" assimilation anti-pattern |
| L1-014 | `size_budget_findings :918-955` | MINOR: L2 invocation-context size budget (mirrors builder G6) |

**GOLDEN — per-substrate end-state proof** (`EVAL/scripts/evaluate_golden.py`, **provenance-gated,
`:555-561` returns READY+no-finding when not provenance**):

| id | helper / file:line | asserts |
|---|---|---|
| GOLDEN-DECLARE | `:567-571` | builder-provenance skill MUST declare a golden substrate |
| GOLDEN-ARTIFACT | `check_artifact :157-196` | artifact substrate has emitted-thing proof |
| GOLDEN-STATE-DELTA | `check_state_delta :198-213` | state-delta needs recorded-fixture + observed-effect (exit-0 REJECTED) |
| GOLDEN-FINDINGS / -ADVISORY | `check_findings :420-...,:450-491` | findings substrate recall+precision golden, non-lexical-theater |
| GOLDEN-KNOWLEDGE | `check_knowledge :504-...` | knowledge substrate corpus proof |
| GOLDEN-TRACE | `check_behavioral_trace :522-...` | behavioral-trace graded-on-reader proof |

**Plus two non-finding evaluator scripts:** `classify_skill_type.py` (substrate routing; aggregator
gate `TYPE`) and `validate_eval_set.py` (L2 fixture schema R1-R6, `:130-224` incl. builder_provenance
one-shot rule). `A1` `EVAL/SKILL.md:553-556`.

### 1b. Builder-owned gates (the "G2", aggregator world — NOT the evaluator)

`A1` `BUILD/references/quality-gates.md:20`; `BUILD/scripts/validate-structure.sh:15,42` —
gates **G0-G6**: G0 frontmatter, G0c compatibility, G1 SKILL.md, **G2 references frontmatter**,
G3 examples, G4 script↔test pairing, G5 …, G6 size (delegated to `check-skill-size.sh`).
The aggregator `validate-skill-complete.sh` runs the builder battery (STRUCTURE, SIZE, DESC-LEN,
ENFORCEMENT, KNOWLEDGE, DISCRIMINATION, SPEC, SPECIMEN, CALIBRATION, CLAIM-LEDGER —
`:150-164`) **then the evaluator battery** (TYPE, EVAL-L0, EVAL-L1, EVAL-GOLDEN — `:178-181`).

---

## 2. validate-structure.sh "G2" (FB-5 / L-2) — exact current code

`A1 FACT` `BUILD/scripts/validate-structure.sh:219-243` (verbatim):

```bash
# -- G2: references/ with >=1 frontmatter .md file ---------------------------

ref_dir="${SKILL_DIR}/references"
if [[ -d "$ref_dir" ]]; then
    md_with_frontmatter=0
    for md_file in "$ref_dir"/*.md; do
        [[ -f "$md_file" ]] || continue
        # Check if file starts with ---
        local_first_line=""
        IFS= read -r local_first_line < "$md_file" || true
        if [[ "$local_first_line" == "---" ]]; then
            md_with_frontmatter=$((md_with_frontmatter + 1))
        fi
    done

    if [[ "$md_with_frontmatter" -ge 1 ]]; then
        report "G2" "PASS" "references/ has ${md_with_frontmatter} .md file(s) with frontmatter"
    else
        report "G2" "FAIL" "references/ has no .md files with frontmatter (starts with ---)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    report "G2" "FAIL" "references/ directory not found"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
```

**CONFIRMED**: G2 asserts ONLY that the reference's **first line == `---`** (frontmatter opens).
It does NOT parse the frontmatter, does NOT require `description`, title, or `type`. The brief's
claim (FB-5 / L-2) is ACCURATE. `A1` `BUILD/references/quality-gates.md:20` documents the same:
``head -1 references/*.md | grep -q '^---'``.

**What upgrading G2 to require `description` (+ title+type) would break** (`A2 INFER`):

1. The G2 PASS test only greps for `G2.*PASS` (`A1` `BUILD/tests/test_validate-structure.sh:105-110`)
   against the builder's OWN `references/` (14 files, all with full frontmatter — `A1` dir listing).
   The builder's own references DO carry `description:` (e.g. evaluator references do too), so the
   builder/evaluator self-tests likely still pass — **but this must be verified by running the
   upgraded gate against every `references/*.md` in both skills + all `examples/*/references/`**.
2. **Risk surface = any reference `.md` that opens with `---` but has NO `description:` key.** Some
   `examples/*/references/*.md` are `.rw-------` minimal stubs (e.g.
   `BUILD/examples/golang-cli-creator/references/{goreleaser-setup,project-templates}.md`) — these
   need a probe: do they carry `description:`? If not, the upgraded G2 turns them FAIL and the
   aggregator flips those example skills to NOT-READY.
3. The fixture `EVAL/examples/reflexivity-audit/fixtures/bad-meta-skill/references/{connected,orphan}.md`
   (157B / 166B) are deliberately minimal — an upgraded G2 may (correctly or not) flag them; check
   whether the bad-meta-skill fixture is ever run through validate-structure.sh.

**Symmetry note** (`A2`): if G2 (builder) starts requiring `description`, the evaluator has NO
equivalent reference-frontmatter-completeness lint today — L0/L1 only check SKILL.md frontmatter
and reference *reachability* (L1-001/002/008), never reference frontmatter fields. To stay
symmetric, an evaluator lint mirroring upgraded-G2 (reference description present) would be NEW.

---

## 3. AGGREGATOR missing-provenance (L-3)

`A1 FACT` — the aggregator is `BUILD/scripts/validate-skill-complete.sh`. The missing-`skill-design.md`
+ provenance interaction is NOT in one place today; it's an emergent multi-gate effect:

- **Ledger gate** `:160-164`: if no `skill-design.md` (and no `--ledger`), `CLAIM-LEDGER` is **SKIP**
  with note `"no skill-design.md ledger (non-provenance / no load-bearing claims)"`.
- **CALIBRATION / SPECIMEN** gates SKIP on non-provenance (`:124-138` SKIP-honesty logic).
- **Evaluator gates** EVAL-L0 / EVAL-L1 then **FAIL** because `metadata.builder_provenance: true`
  is still in SKILL.md but `skill-design.md` is gone → L0-010 (`evaluate_l0.py:364-392`) fires
  (triplet incomplete: design member missing) AND L1-011 (`evaluate_l1.py:777-808`) fires
  (no Design artifact). Aggregator verdict flips NOT-READY (`:188-189`).

The brief (L-3) is accurate: the signal is correct but the message is scattered across the gate
table — the user must read 4 rows (CLAIM-LEDGER SKIP, CALIBRATION SKIP, EVAL-L0 FAIL, EVAL-L1 FAIL)
to infer "provenance set but design file gone".

**Best attach point for the single clear line** (`A2 INFER`): in `validate-skill-complete.sh`,
add a pre-flight detection BEFORE the verdict block (`:184`), reading SKILL.md frontmatter for
`metadata.builder_provenance` truthy AND testing `! -f "$SKILL_DIR/skill-design.md"`. Emit the
diagnostic into the human table footer (the `} >&2` block `:196-210`) as a dedicated NOTE line,
e.g. after `:209`:
`"builder_provenance:true but no skill-design.md sibling — restore it or drop provenance"`.
This keeps it OUT of the JSON gate array (it's a diagnostic, not a gate) and adjacent to the verdict.
The frontmatter read can reuse the same parse idiom as `validate-structure.sh` G0 (heredoc python at
`:200-210` of that file) — there is no shared frontmatter-parse helper, so a small inline `grep`
(`grep -qE '^\s*builder_provenance:\s*(true|"[^"]')` within the metadata block) is the minimal,
dependency-free hook.

---

## 4. NEW LINT LANDING SPOTS

| Proposed lint | Status | Best integration point |
|---|---|---|
| **(a) terse-value-cell** (FB-1/7) — reference "when"/trigger cell is a single token or pure vocabulary | **ABSENT** | NEW evaluator L1 helper. No reference-table-cell content lint exists; L1 only checks reference *reachability* (L1-001/002/008) and SKILL.md heuristics (L1-004/005). Add `reference_entry_findings(skill_dir, text)` → `Finding("L1-015", ...)`, registered in `evaluate_l1.py` `main()` `:981-984` block. Parse `references/*.md` lead lines / SKILL.md Reference-Map table cells; flag a trigger cell that is 1 token or matches a pure-vocabulary pattern. **Provenance-gate it** (mirror L1-011/012) so legacy skills are exempt. |
| **(b) hardcoded-category** (FB-4) — category reference whose trigger names ONE concrete instance as the definition | **ABSENT** | NEW evaluator L1 helper alongside (a). Heuristic detection only (semantic) — flag a category/pattern reference whose trigger contains a single proper-noun instance and no "e.g." / `>=2 examples` marker. Same `Finding("L1-016", MINOR/MAJOR)` + register in `main()`. The matrix `EVAL/references/skill-type-matrix.md` is the doctrine home for the rule text. |
| **(c) unverified-CLI in ops references** (FB-8) | **ABSENT** | NEW evaluator GOLDEN/L1 check. Closest existing kin is the receipt-artifact logic `gate_ran_by_receipt` / evidence-citation regex (`evaluate_l1.py:359-379,504-...`) — reuse its `$ cmd` / command-output regex. Add `Finding("L1-017")` requiring ops references (substrate state-delta or named CLI fences) to carry a verification note. Keyed off declared substrate (read via `classify`/`declared_substrate`). |
| **(d) effect-gate for state-delta × observed-effect** (L-9) | **PARTIAL — ALREADY PRESENT** | `GOLDEN-STATE-DELTA` (`evaluate_golden.py:198-213`) ALREADY rejects exit-0/loader-clean and requires `recorded-fixture\|observed-effect\|fixture ->\|post-condition` in ref_text. **Gap vs brief:** L-9 wants a *fix-close binds observed-effect* + *partial-fix/rollback escalation* check; current regex only proves the SUBSTRATE declares an effect surface, not that the SKILL's close-path is effect-witnessed or has a regression-escalation path. Strengthen `check_state_delta` (`:198-213`) to also require a rollback/escalation token. No new file — extend the existing function + its test `EVAL/tests/test_evaluate_golden.sh`. |
| **(e) execution-access-boundary honored** (FB-6) | **ABSENT** | NEW evaluator check. No `access-boundary` / `agent-runnable vs gated` concept exists in any evaluator script (grep negative). Add a GOLDEN or L1 helper: for ops skills (substrate state-delta), if the SKILL claims a probe proof, require an execution-access-boundary reference + no proof claimed for an agent-ungated tool. Doctrine home = a new row in `skill-type-matrix.md`; lint = `Finding("L1-018")`. |

`A2 INFER`: (a)+(b)+(c)+(e) are the 4 genuinely-NEW evaluator lints; (d) is a strengthen-existing.
All NEW lints should be **provenance-gated** to preserve the evaluator's stated discipline boundary
(`A1` `EVAL/scripts/evaluate_l0.py:346-371`; `EVAL/SKILL.md:101-105`): discipline checks fire on
builder-provenance skills; legacy skills are not penalized.

---

## 5. SKILL SIZE / STRUCTURE — anti-bloat budget

`A1 FACT`: `EVAL/SKILL.md` = **589 lines** (`wc -l`). **No size ceiling is enforced on the evaluator's
own SKILL.md.** The size gate (`check-skill-size.sh`, L2 budget G6) is BUILDER-owned and only runs
when the aggregator validates a TARGET skill — the evaluator never runs it against itself in normal
flow. `A2`: the only self-applied size signal would be L0-009 (decision-core > 500 INFO) and L1-014
(L2 budget MINOR) IF the evaluator were evaluated by itself; both are advisory, not blocking.

**Budget for 5 new lints (`A2 INFER`):** the lints land in **python scripts** (`evaluate_l1.py` /
`evaluate_golden.py`), NOT in `EVAL/SKILL.md`. SKILL.md only needs catalog-row updates (the existing
catalog lives at `EVAL/SKILL.md:539-567`). Each new lint = ~1 catalog line + ~1 heuristic mention →
~10-15 SKILL.md lines total for all 5. The grader-must-not-bloat constraint is satisfied because the
detection logic is in scripts; **keep SKILL.md additions to the catalog block + the Heuristics block
(`:225-360`), do not narrate each lint inline.** `evaluate_l1.py` is already 41KB/large — adding 4
helpers is consistent with its existing structure (14 helpers today).

---

## 6. BUILDER ↔ EVALUATOR CONTRACT (symmetry surface)

`A1 FACT` — the coupling that MUST stay symmetric:

1. **Substrate vocabulary** — the 5 SUBSTRATES `(artifact, state-delta, findings, knowledge,
   behavioral-trace)` are defined in the BUILDER reference `BUILD/references/golden-end-state-model.md:46-54`
   and HARDCODED identically in the evaluator: `EVAL/scripts/evaluate_l0.py:78`,
   `evaluate_golden.py:54`. **If the builder changes the substrate enum, both evaluator constants
   must change in lockstep** (no shared source — two copies). `A2`: this is the highest-risk
   asymmetry point for the brief.

2. **builder_provenance triplet** — the SHARED CONTRACT (marker + substrate + design) is encoded in
   `evaluate_l0.py:82-122` (`provenance_triplet`) referencing `fix-spec.md`. Builder writes the
   marker (`metadata.builder_provenance: true`, `metadata.substrate`); evaluator enforces
   completeness. Mirror of `has_builder_provenance` is duplicated across `evaluate_l0.py:52-75`,
   `evaluate_l1.py:82-...`, `evaluate_golden.py:88-...` (THREE copies — `A1` grep).

3. **golden-end-state model** — the evaluator's GOLDEN layer is the runtime enforcement of the
   builder's `golden-end-state-model.md` taxonomy. `A1` `EVAL/SKILL.md:96-104` ("typed on the
   (substrate × ceiling-surface) matrix… Discipline checks that mirror the upgraded builder…fire on
   builder-provenance skills").

4. **MODEL gate parity** — L0-011 (`evaluate_l0.py:287-313`) is documented as mirroring the builder's
   `spec-compliance.sh` MODEL gate (`A1` `:294-297`, `:141-154`); a divergence is itself flagged a
   defect (el-demoledor F1). Same pattern for any NEW lint that mirrors a builder heuristic.

5. **Heuristics** — the evaluator has its OWN heuristics block (`EVAL/SKILL.md:225-360`,
   H-PROVENANCE / H-SPECIMEN-1 / H-CALIBRATION-1 / H-GOLDEN-*). **If the builder adds H-REF-ENTRY,
   H-NO-HARDCODE, H-ACCESS-BOUNDARY, H-VERIFY-CLI, H-EFFECT-GATE (the brief §3), the evaluator's
   matching lints (§4 above) ARE the symmetry obligation** — each builder heuristic that produces a
   structural signal needs an evaluator lint that detects its absence, or the metric is gameable
   (`A1` the evaluator's own thesis `EVAL/SKILL.md:66-71`: "hard-to-game metric → builders must
   improve the real artifact").

**Coupling that must stay symmetric for THIS brief** (`A2`): (1) the substrate enum (3 copies —
2 evaluator + 1 builder doctrine), and (5) the builder-heuristic ↔ evaluator-lint pairing. Adding
builder heuristics WITHOUT the paired evaluator lint breaks the game-theoretic contract the
evaluator is built on.

---

## Verification commands

```bash
ROOT=/Users/alextorresruiz/Dropbox/@GITHUB/@oss/stdlib/std/skills/01_context_engineering
# G2 ownership + code
sed -n '219,243p' "$ROOT/skills-builder/scripts/validate-structure.sh"
# aggregator ledger/verdict
sed -n '160,210p' "$ROOT/skills-builder/scripts/validate-skill-complete.sh"
# effect-gate already partial
sed -n '198,213p' "$ROOT/skills-evaluator/scripts/evaluate_golden.py"
# rule id census
grep -oE 'L0-[0-9]+' "$ROOT/skills-evaluator/scripts/evaluate_l0.py" | sort -u
grep -oE 'L1-[0-9]+' "$ROOT/skills-evaluator/scripts/evaluate_l1.py" | sort -u
grep -oE 'GOLDEN-[A-Z-]+' "$ROOT/skills-evaluator/scripts/evaluate_golden.py" | sort -u
# substrate enum symmetry (3 sites)
grep -rn 'SUBSTRATES = ' "$ROOT/skills-evaluator/scripts/"
grep -n 'state-delta' "$ROOT/skills-builder/references/golden-end-state-model.md"
```

## Open items / probes for the implementer (not blocking this map)

- `A3 UNVERIFIED[blocked: not probed]`: do the minimal `.rw-------` example references
  (`golang-cli-creator/references/*.md`, reveng/rootly references) carry a `description:` key? Probe
  before landing the G2 upgrade — they are the most likely regression.
- `A3`: `classify_skill_type.py` substrate routing — only saw the assets/templates heuristic line
  (`:94`); the full substrate-decision table was not read end-to-end (out of scope for this map).
