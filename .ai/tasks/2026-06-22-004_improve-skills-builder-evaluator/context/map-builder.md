---
task_id: 2026-06-22-004
agent: codebase-analyzer
timestamp: 2026-06-22T00:00:00Z
status: complete
summary: |
  Precise map of the CURRENT skills-builder meta-skill for integrating 6 new
  heuristics + tooling fixes WITHOUT bloat. Heuristic catalog is 40 H-* in ONE
  uniform `**H-NAME: title**` bold form, centralized in SKILL.md (no scattered
  registry, no central index/list of names). Reference doctrine for FB-1/2/3/7
  (Reference Map / load-WHEN lead-line / deterministic loader-emitter) is ABSENT
  — all three are NEW, not duplicates; H-ASSIM-1/2 is the nearest existing
  obligation doctrine. validate-specimen.sh L-1 placeholder bug CONFIRMED (bare
  substring grep). Reference frontmatter uses title/summary/type — `description`
  ABSENT (FB-5 NEW); G2 only checks leading `---`. design-calibration-loop.md is
  PRE-BUILD single-pass only (L-10 NEW). SIZE: SKILL.md L2 is 1075 lines /
  70369 bytes / ~17592 tokens vs budget 500 lines / 28000 bytes — already 2.5x
  OVER the byte ceiling, passing ONLY via the skill-design.md `## 8. L2 Size
  Budget` justification. Headroom is NEGATIVE: -42329 bytes / -575 lines.
---

# skills-builder — CURRENT-STATE MAP (for additive 6-heuristic + tooling integration)

## Key Findings

- **size_budget:** SKILL.md 70369 bytes vs 28000 ceiling — NEGATIVE headroom (-42329 bytes); adding 6 heuristics worsens a 2.5x overage
- **heuristic_catalog:** 40 H-* all in uniform `**H-NAME: title**` + CONDITION/ACTION/REASONING, centralized in SKILL.md, no name-registry
- **reference_map_doctrine:** FB-1/2/3/7 (Reference Map, load-WHEN lead, loader-emitter) ABSENT everywhere except IMPROVEMENT-NOTES — all NEW
- **specimen_bug:** L-1 CONFIRMED — `grep -qiE 'placeholder'` rejects any specimen containing "no placeholders"
- **reference_frontmatter:** title/summary/type only; `description` ABSENT (FB-5 NEW); G2 checks only leading `---`
- **calibration_loop:** PRE-BUILD single-pass only; no POST-BUILD file-by-file accumulating rounds (L-10 NEW)
- **existing_brief_file:** skills-builder root already ships IMPROVEMENT-NOTES-from-eneco-sre-build-2026-06-22.md — the brief's source

**Skill root:** `/Users/alextorresruiz/Dropbox/@GITHUB/@oss/stdlib/std/skills/01_context_engineering/skills-builder/`
All `file:line` below are relative to that root. Evidence labels per repo convention: A1 FACT (witnessed: file:line / command output), A2 INFER (derived), A3 UNVERIFIED[blocked].

**Top-of-map alert (read before any addition):** A handoff brief already lives IN the skill root —
`IMPROVEMENT-NOTES-from-eneco-sre-build-2026-06-22.md` (109 lines). It is the SOURCE the user's brief
(FB-1…FB-8, L-1…L-10) is derived from. `SKILL.md:1` header says "Status: BACKLOG / NOT YET IMPLEMENTED"
[A1 `IMPROVEMENT-NOTES…md:3`]. Every FB/L item below was cross-checked against live code, not just the notes.

---

## Q1. HEURISTIC CATALOG

**A1 FACT — 40 heuristics, ALL defined in `SKILL.md`, ALL in ONE uniform format.**

- **Count:** `grep -cE "^\*\*H-[A-Z]" SKILL.md` → **40** [A1].
- **Format convention (uniform — the template the 6 new ones MUST match):** every heuristic is a
  bold lead line `**H-<FAMILY>-<N>: <imperative title>**` immediately followed by a 3-line block:
  ```
  **H-KNOW-1: Heuristics require reasoning**
  CONDITION: Writing a heuristic
  ACTION: Keep the `CONDITION -> ACTION -> REASONING` chain intact. ...
  REASONING: Reasoning turns instructions into transferable judgment.
  ```
  [A1 `SKILL.md:443-447`]. There are **zero** `#### H-` or `### H-` heading-form heuristics —
  `grep -nE "^#### H-|^### H-" SKILL.md` returns nothing [A1]. So the convention is unambiguous:
  **bold `**H-NAME: title**` + CONDITION/ACTION/REASONING triple**, never a markdown heading.
- **Grouping:** heuristics sit under `## Heuristics` (`SKILL.md:344`) in `### Family` subsections
  (Endgame and Self-Application, Description Engineering, Agent Skills Compatibility, Knowledge
  Quality, Assimilation…, Enforcement Language, Structure, Scope/Style/Placement, Adversarial and
  Cognitive Validation, Pipeline/Framework/Upgrade Discipline) [A1 `SKILL.md:346,368,395,441,466,492,533,566,601,656`].

**Full enumeration (name → SKILL.md line):** [all A1]

| Heuristic | Line | Heuristic | Line |
|---|---|---|---|
| H-ENDGAME-1 | 348 | H-ENFORCE-1 | 494 |
| H-ENDGAME-2 | 354 | H-ENFORCE-2 | 507 |
| H-META-1 | 361 | H-ENFORCE-3 | 521 |
| H-DESC-1 | 370 | H-SCRIPT-1 | 535 |
| H-DESC-2 | 375 | H-SCRIPT-2 | 541 |
| H-DESC-3 | 381 | H-ASSET-1 | 547 |
| H-DESC-4 | 388 | H-EXAMPLE-1 | 553 |
| H-COMPAT-1 | 397 | H-EXAMPLE-2 | 560 |
| H-COMPAT-2 | 405 | H-SCOPE-1 | 568 |
| H-COMPAT-3 | 413 | H-STYLE-1 | 574 |
| H-COMPAT-4 | 422 | H-STYLE-2 | 580 |
| H-KNOW-1 | 443 | H-CONTEXT-1 | 586 |
| H-KNOW-2 | 449 | H-ADVERSARIAL-1 | 603 |
| H-KNOW-3 | 455 | H-ADVERSARIAL-2 | 609 |
| H-KNOW-4 | 460 | H-DEMOLISH-1 | 614 |
| H-ASSIM-1 | 468 | H-SYNTH-1 | 628 |
| H-ASSIM-2 | 476 | H-GATE-1 | 640 |
| H-ASSIM-3 | 484 | H-GATE-2 | 648 |
| | | H-BATCH-1 | 658 |
| | | H-BATCH-2 | 664 |
| | | H-FRAMEWORK-1 | 671 |
| | | H-RETRO-1 | 677 |

**Central list / registry?** — **NO.** [A1] Definitions are centralized in `SKILL.md` only
(`grep -rlnE "^\*\*H-[A-Z]|^#### H-" references/ assets/` returns nothing — no H-* DEFINED outside
SKILL.md). But there is **no index/registry of heuristic NAMES** — no "list of all heuristics" table
anywhere. The closest thing is `skill-design.md:` §8 which name-drops the FAMILIES in prose
("H-ENDGAME/DESC/COMPAT/KNOW/ASSIM/ENFORCE/SCRIPT/ASSET/EXAMPLE/SCOPE/CONTEXT/ADVERSARIAL/GATE/BATCH/
FRAMEWORK/RETRO families") [A1 `skill-design.md` §8 L2 Size Budget block] — NOT a real registry.
`l2-residency-contract.md:31` requires ≥3 full heuristic triples stay in L2 but does not list them.

**Integration implication:** 6 new heuristics (H-REF-ENTRY, H-REF-LOADER, H-NO-HARDCODE,
H-ACCESS-BOUNDARY, H-VERIFY-CLI, H-EFFECT-GATE per `IMPROVEMENT-NOTES…md:83-84`) must be added as
`**H-NAME: title**` + CONDITION/ACTION/REASONING under the appropriate `### Family`. New families
likely needed: a "Reference Doctrine" family (H-REF-ENTRY, H-REF-LOADER, H-NO-HARDCODE) and an
"Operational / Effect" family (H-ACCESS-BOUNDARY, H-VERIFY-CLI, H-EFFECT-GATE). No registry to update,
BUT the `skill-design.md` §8 family list and `l2-residency-contract.md` should be kept coherent.

---

## Q2. REFERENCE DOCTRINE (FB-1/2/3/7 → are H-REF-ENTRY / H-REF-LOADER NEW or DUPLICATE?)

**Verdict: all three sub-items are ABSENT → the brief items are NEW, not duplicates.** [A1 — grep
across the whole skill tree, excluding IMPROVEMENT-NOTES, returns nothing for each token.]

| Sub-item | Status | Evidence |
|---|---|---|
| (a) Primacy `## Reference Map` linked inventory | **ABSENT** | `grep -rln "Reference Map" .` (excl. notes) → nothing [A1]. Current reference inventory is the `## Operational Surfaces` list at `SKILL.md:1005-1069` — a flat bullet list at the BOTTOM (recency, not primacy), with obligation prose but no top-of-file linked map. |
| (b) "Load this reference WHEN `<scenario>` → gives you `<value>`" lead-line per reference | **ABSENT (as a doctrine/convention)** | `grep -rln "Load this reference WHEN\|fetch WHEN"` (excl. notes) → nothing [A1]. No reference file opens with such a lead line. The CLOSEST existing mechanism is the per-surface obligation prose inside `## Operational Surfaces` ("**required** by … TRIGGER … EVIDENCE OF USE … BLOCKED-PATH", e.g. `SKILL.md:1022,1026,1030`) — but that lives in SKILL.md, not as a lead-line ON each reference, and it is not a mandated convention for generated skills. |
| (c) Deterministic reference-LOADER / emitter script | **ABSENT** | `grep -rln "LOAD NOW\|reference-loader\|emitter"` (excl. notes) → nothing [A1]. No script emits a per-task reference set. |

**Nearest existing doctrine (the thing the new heuristics will EXTEND, not duplicate):**
`H-ASSIM-1` (`SKILL.md:468`) "Mandatory means observable" and `H-ASSIM-2` (`SKILL.md:476`)
"References need obligation labels" already require trigger + action + evidence + blocked-path for
mandatory L3 surfaces, and the "Assimilation rule" / "Model-first assimilation [R5]" at
`SKILL.md:228-240`. So FB-1/2/3/7 are a STRENGTHENING of H-ASSIM (per `IMPROVEMENT-NOTES…md:61` "an
H-ASSIM upgrade"), NOT a contradiction. The brief is internally consistent: `IMPROVEMENT-NOTES…md:55-61`
(L-4, L-5) explicitly states the load-WHEN lead-line and loader+Reference-Map pattern are "not in the
builder's playbook" / "absent" [A1]. **Confirmed NEW.**

**Anti-bloat note:** the load-WHEN lead-line is a per-REFERENCE convention (lives in L3 files, costs
no L2 bytes). The `## Reference Map` mandate, however, ADDS to L2 — and FB-3 wants it for "skills with
≥4 references" (`IMPROVEMENT-NOTES…md:33`). For the builder ITSELF (14 references) that is a real new
L2 section on an already-2.5x-over-budget body (see Q7). Recommend the Reference Map mandate target
GENERATED skills and, for the builder's own body, REPLACE the flat `## Operational Surfaces` list
rather than add alongside it (net-neutral, not additive).

---

## Q3. L2-RESIDENCY CONTRACT (`references/l2-residency-contract.md`, 66 lines)

**What it governs** [A1 `l2-residency-contract.md:24-44`]: it is the single source of truth, shared by
skills-builder AND skills-evaluator, for which `SKILL.md` sections MUST stay in the L2 body and may
NEVER be relocated to L3 under G6 byte pressure. The protected set (`:26-32`):

| L2-required section | Evaluator gate | Source |
|---|---|---|
| Structure Declaration table | `L1-012` | this contract |
| Enforcement Contract | `L1-010` | H-ENFORCE-3 |
| Example Reasoning (cites ≥1 heuristic id) | `L1-006` | quality-gates G9 |
| Named heuristics (≥3 full CONDITION/ACTION/REASONING triples) | `L1-004` + validate-knowledge G8 | H-KNOW-1 |
| YAML frontmatter (name+description) | `L0`/`G0` | structure doctrine |

Binding rule (`:40-44`): "NEVER relocate an L2-required section to L3 … that refactor is BLOCKED — it
trades a size PASS for a coherence FAIL." It ships a mechanical residency check (`:54-59`, a `grep -q`
set) and an explicit "What MAY move to L3" allow-list (`:61-66`: non-Structure-Declaration lookup tables,
checklists, verbose protocols, long examples, catalogs, templates, playbooks).

**Where a "Reference Map mandate for skills with ≥4 references" attaches** [A2 INFER from structure]:
add a NEW ROW to the contract table at `l2-residency-contract.md:26-32` — `**Reference Map** (linked
inventory + load-WHEN triggers) | <new evaluator gate id, e.g. L1-0xx> | H-REF-LOADER/H-REF-ENTRY`.
This makes the Reference Map a protected L2-resident section (so a later G6 refactor cannot evict it,
exactly the failure mode this contract was created to prevent — see `:14-18`). It must be paired with:
(1) the new heuristic in SKILL.md, (2) a builder-side mechanical check (mirror `:54-59`), and (3) the
matching evaluator `L1-0xx` finding. Note FB-3's "≥~4 references" threshold — the contract currently has
no count-conditional rows, so the new row needs a threshold clause (e.g. "for skills declaring ≥4
references"). **Stakes (HIGH):** if the Reference Map is mandated in SKILL.md but NOT added to this
contract, a future G6 refactor relocates it → silent coherence regression. Falsifier: a refactor that
moves the Reference Map to L3 and still passes the aggregator.

---

## Q4. REFERENCE TEMPLATE + FRONTMATTER (FB-5 → is `description` required?)

**A1 FACT — reference frontmatter currently does NOT require/carry `description`. FB-5 is NEW.**

- **Doctrine location:** `references/skill-structure.md:11-30` (canonical directory layout) shows
  `references/*.md <- YAML frontmatter: title, summary, type` [A1 `skill-structure.md:14`]. The
  Frontmatter Field Specification table (`skill-structure.md:130-140`) governs the SKILL.md frontmatter,
  NOT reference-file frontmatter — there is no separate "reference frontmatter spec". So the only
  reference-frontmatter convention is the inline `title, summary, type` note.
- **Current actual frontmatter (probe of all 14 references):** every reference uses
  `title / summary / type`, NOT `description`. `description:` field count per file is 0 for 13 of 14;
  the lone exception is `golden-end-state-model.md` (count 1, incidental — its body or summary contains
  the word) [A1 command output, this session]. Representative quote:
  ```yaml
  ---
  title: "L2 Residency Contract"
  summary: "The single source of truth for which SKILL.md sections MUST stay in L2 ..."
  type: reference
  ---
  ```
  [A1 `l2-residency-contract.md:1-5`]. Same shape at `skill-structure.md:1-5`, `anti-patterns.md:1-5`,
  `quality-gates.md:1-5`, `description-engineering.md:1-5`, `design-calibration-loop.md:1-5`.
- **What G2 enforces today** (the gate FB-5 wants upgraded): `validate-structure.sh:219-243` — G2 reads
  ONLY the first line of each `references/*.md` and counts it PASS if `== "---"`. It does **not** parse
  YAML and does **not** check for `title`, `summary`, `description`, or `type` [A1 `validate-structure.sh:224-235`].
  The quality-gates doc mirrors this: G2 = "references/ has >=1 .md file with YAML frontmatter … `head -1
  references/*.md | grep -q '^---'`" [A1 `quality-gates.md:20`].

**Integration implication (FB-5 / L-2):** there is no reference-file template to amend (references are
hand-authored from the `title/summary/type` convention in `skill-structure.md:14`). To implement FB-5,
(1) change that convention line + the layout to require `title + description + type` (or +summary),
(2) add `description` frontmatter to all 14 existing references, (3) upgrade `validate-structure.sh` G2
(`:219-243`) to YAML-parse and require a non-empty `description`. **Naming caution:** the existing
convention key is `summary`, not `description` — the brief (`IMPROVEMENT-NOTES…md:47`, FB-5) demands
`description` specifically. Decide whether to rename `summary`→`description` (touches 14 files + any
evaluator that keys off `summary`) or require BOTH. This is a coherence fork worth surfacing.

---

## Q5. validate-specimen.sh BUG (L-1) — CONFIRMED

**A1 FACT — the bug is real and reproduced.** Function `is_real_specimen()` at
`scripts/validate-specimen.sh:46-57`. The offending line:

```bash
# line 49:
if LC_ALL=C grep -qiE '\{\{|todo:|placeholder|lorem ipsum' "$f" 2>/dev/null; then return 1; fi
```
[A1 `validate-specimen.sh:49`].

**Reproduction (this session):** piping `"This specimen contains the phrase no placeholders…"` into
`LC_ALL=C grep -qiE '\{\{|todo:|placeholder|lorem ipsum'` → **MATCH → return 1 (REJECTED)** [A1 command
output]. Every variant tested rejects: `"no placeholders"`, `"no placeholder content"`, `"uses no
placeholder text"` all match the bare `placeholder` alternation [A1]. **Confirmed:** a legitimate
specimen whose prose contains "no placeholders" (a phrase any high-quality dogfooded specimen might use
to assert its own completeness) is WRONGLY disqualified. The root cause is the unanchored substring
`placeholder` in the alternation; `\{\{`, `todo:`, and `lorem ipsum` are the safe stub markers.

**Everything that depends on this grep (so a scoped-regex fix does not break other logic)** [all A1
`validate-specimen.sh`]:

1. `is_real_specimen()` returns 1 (not-a-specimen) on grep match (`:49`). The function has TWO other
   independent rejection paths that the fix MUST NOT touch: ≥6 distinct non-blank lines (`:51-52`) and
   ≥40 words (`:55`). Only `:49` has the substring bug.
2. `is_real_specimen` is called in exactly TWO places, both inside the `found` discovery loop:
   - root-level specimen scan `:64` (`if is_real_specimen "$f"; then found=1; break; fi`)
   - subdir specimen scan `:77` (same).
3. `found` drives the final verdict: `:85-91` — `found==1` → PASS exit 0; else FAIL exit 1.
4. Upstream/independent of the grep (NOT affected by a regex fix): provenance exemption `:33-36`
   (non-builder-provenance → SKIP exit 0), missing-`examples/` FAIL `:39-42`, `find … -size +800c`
   file-size prefilter `:66,79`, negative-fixture/README/test exclusions `:66,73-74,79`.
5. **Consumers of the script:** the aggregator `validate-skill-complete.sh:157` runs it as the
   `SPECIMEN` gate; `tests/test_validate-specimen.sh` is its 1:1 test [A1 grep output]. SKILL.md cites
   it at `:130` and `:776`. A scoped fix (replace bare `placeholder` with `\{placeholder\}` /
   `{{placeholder}}` patterns per `IMPROVEMENT-NOTES…md:45`) is isolated to line 49 and changes only the
   stub-marker test — the distinct-line and word-count floors, provenance exemption, and discovery loop
   are untouched. **Add a positive test case** to `tests/test_validate-specimen.sh` asserting a specimen
   containing "no placeholders" now PASSes (regression guard).

---

## Q6. design-calibration-loop.md (L-10) — PRE-BUILD single-pass ONLY

**A1 FACT — the loop is a PRE-BUILD specimen pass; it does NOT support POST-BUILD, file-by-file,
rule-accumulating review rounds. L-10 is NEW.**

- **Structure** (`references/design-calibration-loop.md:28-52`, "The loop (run inside DESIGN, after the
  golden end-state is declared)"): 5 steps — PRODUCE specimen → PRESENT → CAPTURE feedback as rules →
  ITERATE → SIGN-OFF binds the contract, then "BUILD encodes them" [A1 `:30-52`]. The header explicitly
  scopes it: "run inside DESIGN" and "BEFORE its decision core is generated" (`:9,28`). The summary
  frontmatter confirms: "calibrating a skill's quality bar … on a REAL specimen BEFORE the decision core
  is generated" [A1 `:3`].
- **It DOES support multi-round iteration — but PRE-BUILD on ONE specimen**, not file-by-file across the
  built skill: step 4 ITERATE says "re-present, and repeat until the user signs off on THE BAR … Expect
  several rounds" (`:45-48`) [A1]. The rounds are over the SAME pre-build specimen, converging the bar
  BEFORE BUILD writes anything.
- **What's ABSENT (L-10):** no notion of reviewing the BUILT skill file-by-file (SKILL.md, each
  reference, each script) AFTER BUILD and accumulating each reaction as a durable rule. The
  "Feedback-to-rule discipline" table (`:62-77`) and "Carrying the specimen's lessons into PROOF"
  (`:79-96`) are all about the pre-build specimen + PROOF lessons, not post-build per-file rounds.
  `IMPROVEMENT-NOTES…md:75-78` (L-10) states this directly: "The design-calibration-loop reference should
  explicitly support post-BUILD, file-by-file review rounds (not only a single pre-BUILD specimen pass)"
  [A1]. The eneco-sre build did 8 file-by-file rounds MANUALLY (`IMPROVEMENT-NOTES…md:15,107`).

**Integration implication:** L-10 is a doctrine ADD to `design-calibration-loop.md` (a new "Post-BUILD
file-by-file review" section that accumulates rules into `skill-design.md` §8 Calibration Record). The
Calibration Record template already supports a ≥1-row captured-rules table
(`assets/templates/skill-design.md:164-175`), so the storage surface exists — only the LOOP doctrine and
its trigger are missing. Low L2 cost (it's all L3 + template), unlike the heuristic adds.

---

## Q7. SIZE BUDGET — CRITICAL ANTI-BLOAT FINDING

**A1 FACT — `scripts/check-skill-size.sh SKILL.md` (this session):**
```
G6    PASS   1075 body lines, 70369 bytes, ~17592 tokens (budgets: 500 lines / 28000 bytes)
            — over budget (lines 1075>500, bytes 70369>28000) but justified in
            skill-design.md '## L2 Size Budget'
EXIT=0
```

| Metric | Current (L2 body, post-frontmatter) | Ceiling (G6) | Headroom |
|---|---|---|---|
| **Bytes** (BINDING metric) | **70369** | 28000 | **−42329 bytes (NEGATIVE — 2.51x over)** |
| **Lines** | 1075 | 500 | **−575 lines (NEGATIVE — 2.15x over)** |
| **Tokens (approx, bytes/4)** | ~17592 | ~7000 | **~−10592 tokens over** |
| File total (incl. frontmatter) | 1091 lines | — | — |

[All A1: command output + `wc -l SKILL.md` = 1091.] The byte budget is the BINDING metric per the script
header (`check-skill-size.sh:` "Byte/token budget is the BINDING context-cost gate") and
`skill-structure.md:99-109`.

**WHY it currently passes (the only thing keeping G6 green):** the skill's own
`skill-design.md` carries `## 8. L2 Size Budget (G6 self-application — H-META-1)` [A1 `skill-design.md`].
The G6 justification-scan regex is `(l2|skill\.md).*size budget` (case-insensitive)
[A1 `check-skill-size.sh` python `heading_re`], which matches the "## 8. L2 Size Budget" heading. The
justification itself flags the overage and even names a deferred COMPRESS pass: "A further reduction
toward budget is possible by collapsing each heuristic's REASONING prose into a denser single-line form
(a COMPRESS pass, not a RELOCATE), recovering an estimated ~80–120 lines" [A1 `skill-design.md` §8].

**Anti-bloat verdict (the #1 risk):** There is **NEGATIVE headroom**. The meta-skill is ALREADY 2.5x over
its own byte ceiling and survives only on its own justification escape — the exact "anti-bloat meta-skill
became bloated" failure the user fears, already partially realized. Adding 6 heuristics (each ~7-line
`**H-NAME**` + CONDITION/ACTION/REASONING triple ≈ ~40-55 lines / ~2.5-3.5KB total raw) pushes it
further over.

**Stakes-class HIGH. Mitigations (mechanically grounded):**
1. **Net-neutral mandate.** Pair every heuristic ADD with a COMPRESS of existing REASONING prose — the
   §8-named ~80-120-line COMPRESS pass exists precisely to fund additions. Target net-zero L2 lines/bytes.
2. **Reference Map = REPLACE, not ADD.** If FB-3's `## Reference Map` lands in the builder's own body,
   it should REPLACE the verbose `## Operational Surfaces` block (`SKILL.md:1005-1069`, ~65 lines of
   per-surface obligation prose) with a tighter linked map — a net REDUCTION, while satisfying FB-3.
3. **Push new doctrine to L3.** H-REF-ENTRY's load-WHEN convention, H-VERIFY-CLI, H-ACCESS-BOUNDARY
   detail belong in references (L3, unbudgeted per `skill-structure.md:109,226`); keep only the
   `**H-NAME**` triple in L2.
4. **Re-run `check-skill-size.sh` after the change as the gate** — it is the mechanical floor; if it
   FAILs, the §8 justification must be re-argued naming the specific new sections (anti-rubber-stamp bar
   at `SKILL.md:1023`), or the additions relocated. Do NOT let it pass by padding the justification.

**Honest scope caveat** [A1 `check-skill-size.sh` header + `skill-structure.md:122-128`]: G6 bounds only
the ACTIVATION-time L2 surface. New MANDATORY references (H-REF-LOADER, access-boundary) defer their cost
to task-time, invisible to G6 — keep those references small too; "G6 PASS" ≠ "not a context bomb".

---

## Cross-cutting: brief items ALREADY implemented vs NEW (the integration ledger)

| Brief item | NEW / DUPLICATE / PARTIAL | Evidence |
|---|---|---|
| FB-1/7 H-REF-ENTRY (load-WHEN + value lead) | **NEW** (extends H-ASSIM) | no `Load…WHEN` convention exists (Q2) |
| FB-2/3 H-REF-LOADER + `## Reference Map` | **NEW** | no Reference Map / LOAD-NOW emitter exists (Q2) |
| FB-4 H-NO-HARDCODE | **NEW** | not probed for a name match; no anti-hardcode heuristic in the 40-catalog (Q1) |
| FB-5 reference `description` frontmatter | **NEW** | refs use title/summary/type; G2 checks only `---` (Q4) |
| FB-6 H-ACCESS-BOUNDARY | **NEW** | no execution-access-boundary reference type (Q2/Q4 doctrine absent) |
| FB-8 H-VERIFY-CLI | **NEW** | no verify-CLI discipline in catalog (Q1) |
| L-1 specimen placeholder bug | **NEW (confirmed bug)** | reproduced (Q5) |
| L-9 H-EFFECT-GATE | **NEW** | not in the 40-catalog (Q1) |
| L-10 post-build file-by-file calibration | **NEW** | loop is pre-build single-pass (Q6) |

**No brief item was found ALREADY IMPLEMENTED in code** — every FB/L maps to a genuine gap. The ONLY
"already done" artifact is the worked exhibit `std/skills/10_employer/eneco/eneco-sre` (the positive
fixture the brief says hand-implements all of these — `IMPROVEMENT-NOTES…md:97-108`), which this map did
NOT inspect (out of the named scope; flag if needed as a follow-up locate).

**A3 UNVERIFIED[blocked]:** I did not open the eneco-sre worked exhibit (not in the named key-file list);
its claimed reference-map/loader/effect-gate exemplars are taken from `IMPROVEMENT-NOTES…md` prose, not
witnessed. Resolving probe: read `std/skills/10_employer/eneco/eneco-sre/SKILL.md` +
`scripts/classify-incident.sh` before copying its patterns as the builder's canonical form.
