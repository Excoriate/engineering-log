---
task_id: 2026-06-22-004
agent: el-demoledor
status: complete
timestamp: 2026-06-22T14:00:00Z
summary: >
  Adversarial demolition of plan §B(4,5,6)+§C tooling fixes. All 4 fixes BROKEN as
  drafted with executed breaking inputs. Hardened replacements verified both directions.
---

# DEMOLEDOR REPORT — Tooling fixes §B(4,5,6) + §C

**Target**: 4 proposed validator-script changes (BUILD=skills-builder, EVAL=skills-evaluator)
**Scope**: Full (control-plane validators) | **Method**: every claim EXPLOIT-VERIFIED via executed grep/python

## DESTRUCTION SUMMARY

| Metric | Count |
|--------|-------|
| Fixes attacked | 4 |
| Fixes BROKEN as drafted | 4 (all) |
| Evidence grade | 4x EXPLOIT-VERIFIED (commands run, output captured) |
| Worst blast radius | Fix 2: 26/27 reference files fail-block; Fix 3: provenance gate fails OPEN |

---

## V1 — validate-specimen.sh L-1 regex — [EXPLOIT-VERIFIED] — BROKEN

`BUILD/scripts/validate-specimen.sh:49`. Proposed: `\{\{|\{placeholder\}|todo:|lorem ipsum`.

**Breaking inputs (executed)** — the proposed regex MISSES every one of these real stub markers a skill author writes:

```
[placeholder]   <placeholder>   PLACEHOLDER   placeholder:   placeholder text here
TODO (no colon)   TBD   FIXME   XXX
```

Narrowing bare `placeholder` → `{placeholder}` drops `[ ]`, `< >`, ALLCAPS, colon, and bare forms.
Confirmed: current regex correctly catches `[placeholder]`,`<placeholder>`,`PLACEHOLDER`,`placeholder:` (the `-i` bare-word match); proposed catches NONE of them.

**False-positive that motivated L-1 (executed)**: current regex FP's on legit prose
`"This skill uses a placeholder substitution strategy"` (4/4 prose lines flagged). Real motivation confirmed.

**Severity Gate**: Exploitability HIGH (authors routinely write `[placeholder]`/`TODO`) x Impact HIGH (stub specimens pass certification) x Confidence HIGH = **CRITICAL**.

**Hardened (verified: 13/14 stubs caught, 0/4 prose FP)** — drop `-i`, match delimited/ALLCAPS/colon forms:
```
\{\{|[<{[]([Pp]laceholder|PLACEHOLDER)[]>}]|placeholder:|\bPLACEHOLDER\b|\b(TODO|TBD|FIXME|XXX)\b|(todo|tbd|fixme|xxx):|[Ll]orem [Ii]psum
```
Irreducible residue: bare-lowercase `placeholder text here` is lexically identical to legit prose
`placeholder substitution` — cannot be regex-classified; the existing ≥40-word / ≥6-distinct-line
substance gate (L51–55) is the correct backstop. Do NOT chase it with regex.

**Counter-hypothesis**: "proposed is fine if authors only ever write `{placeholder}`." Rejected —
executed corpus of author-realistic markers shows 5+ common forms missed.

**Belief-change**: if input `[placeholder]`/`TODO`/`PLACEHOLDER` breaks proposed → use hardened above (no `-i`).

---

## V2 — validate-structure.sh G2 non-empty description — [EXPLOIT-VERIFIED] — BROKEN (worst regression)

`BUILD/scripts/validate-structure.sh:219-243`. Proposed: require non-empty `description:`.

**Breaking reality (executed full corpus scan, NUL-safe)**: of 27 `references/**/*.md` across BUILD+EVAL,
**26 use `summary:` not `description:`** — only 1 (`builder/references/golden-end-state-model.md`) has `description:`.
G2 as run against the BUILD skill root scans `${SKILL_DIR}/references/*.md` (top-level, non-recursive):
13 of those 14 builder refs use `summary:` → **all 13 FAIL** the upgraded G2.

The plan §B(4) says "migrate stubs that lack it" — but the regression is NOT stubs, it is the
**entire field-name split**. G2-upgrade is INVALID unless §B(9)/FORK-1 `summary→description`
migration lands FIRST and atomically. Sequencing the upgrade before migration = self-inflicted NOT-READY.

**bad-meta-skill fixtures** (`EVAL/.../fixtures/bad-meta-skill/references/{orphan,connected}.md`) also use
`summary:` and are INTENTIONAL negatives — they are example-nested, NOT scanned by G2 (SKILL_DIR-scoped),
so they are safe from G2 but MUST NOT be auto-migrated (they are test fixtures).

**Precise parse (verified on 6 edge cases)** — scope to frontmatter fence, then strip quotes/space:
- present `description: text` → PASS
- `description:` (empty) → FAIL (correct)
- `summary:` only (absent) → FAIL (correct)
- `description:` appearing in BODY prose → FAIL (correct — awk `---`…`---` fence excludes body)
- `description: ""` (quoted empty) → FAIL (correct — strip quotes then test empty)
- `description: >` (folded) → false-PASS `val=[>]` (rare; folded scalars need next-line read)

Parse: `awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f'` then
`sed -nE 's/^[[:space:]]*description[[:space:]]*:[[:space:]]*//p'`, strip `["']` + spaces, test `-n`.

**Severity Gate**: Exploitability HIGH x Impact HIGH (blocks own meta-skill cert) x Confidence HIGH = **CRITICAL**.

**Counter-hypothesis**: "only stubs fail." Rejected — executed scan: 26/27 fail, field-name split is the cause.

**Belief-change**: if G2-upgrade runs before migration → 13 builder refs FAIL; gate on §B(9) migration as a HARD predecessor.

---

## V3 — validate-skill-complete.sh provenance grep L-3 — [EXPLOIT-VERIFIED] — BROKEN both ways

`BUILD/scripts/validate-skill-complete.sh` ~:184. Proposed inline `grep -qE '^\s*builder_provenance:\s*(true|"...")'`.
(BSD grep `\s` support CONFIRMED working via probe.)

**False NEGATIVE (executed)**: `builder_provenance : true` (space before colon — valid YAML) → NO-MATCH.
Gate FAILS OPEN: a provenance'd skill escapes the new lints entirely.

**False POSITIVE (executed)**: an indented `  builder_provenance: true` inside a fenced ```yaml doc
code-block in the SKILL BODY → MATCH. `^\s*` does not confine to frontmatter. Since provenance gates
whether NEW lints apply, this wrongly flips a legacy skill (that merely documents the field) into the
penalized cohort.

**Severity Gate**: Exploitability MED x Impact HIGH (gate fails open = silent lint bypass) x Confidence HIGH = **HIGH**.

**Hardened (verified: 7/7 cases correct)** — confine to frontmatter fence, allow space-before-colon, full-line anchor:
```bash
awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$file" \
  | grep -qE '^[[:space:]]*builder_provenance[[:space:]]*:[[:space:]]*(true|"true"|'\''true'\'')[[:space:]]*$'
```
Handles: flat true, nested true, quoted true, spaced-colon true → MATCH; body mention, code-block, false → NO-MATCH.

**Counter-hypothesis**: "no one writes space-before-colon / doc code-blocks." Rejected — both are valid YAML / common doc patterns; executed proof shows the miss/false-match.

**Belief-change**: if `builder_provenance : true` (spaced) or a ```yaml example exists → use awk-fenced hardened check.

---

## V4 — evaluate_golden.py GOLDEN-STATE-DELTA rollback token — [EXPLOIT-VERIFIED] — BROKEN both ways

`EVAL/scripts/evaluate_golden.py:198-213`. Proposed: ALSO require a `rollback|escalat` token.

**False FAIL (executed)**: a genuine state-delta skill with `recorded-fixture: ... -> ...`, an asserted
`observed-effect` post-condition, and a recovery path described as **"compensating transaction / revert / undo"**
→ `FAIL(missing:rollback)`. Real close-path rejected because it never uses the literal word "rollback".
This re-commits the exact L-1 over-narrow-lexical anti-pattern this task fixes elsewhere.

**False PASS (executed)**: a skill that name-drops "GitHub Actions supports a **rollback** strategy" as
background context, with NO asserted post-state → `PASS`. Token present, zero real effect-witness.

**Severity Gate**: Exploitability MED x Impact MED (rejects real / accepts fake; recoverable) x Confidence HIGH = **MEDIUM-HIGH**.

**Hardened (verified: false_fail→PASS, false_pass→FAIL)** — broaden synonyms AND require co-location with a failure/recovery anchor:
```python
RECOVERY_RE = re.compile(r"rollback|roll[- ]back|escalat|revert|undo|compensat|restore|back[- ]?out", re.I)
CLOSE_CTX_RE = re.compile(r"(on[- ]failure|if\s+.{0,40}\bfail|failure[,:]|operator\s+runs|recovery\s+(path|step)|runbook)", re.I)
# require: has_fixture AND has_recovery AND has_close_ctx
```

**Counter-hypothesis (meta-falsified)**: "a state-delta skill SHOULD say 'rollback'." Rejected — recovery
vocabulary (revert/compensate/undo) is standard; mandating one lexeme is the same brittleness the task condemns.

**Belief-change**: if recovery is worded "compensating/revert/undo" → false-FAIL; if "rollback" appears in background → false-PASS; use synonym-set + co-located close-context anchor.

---

## ADVERSARIAL SELF-CHECK

- **Pattern-matching?** No — every finding carries executed grep/python output (the miss/false-match is shown, not asserted).
- **False-positive conditions** named per finding (counter-hypotheses above).
- **Redundancy/root cause**: V3 and V4 share a generator — "lexical token match without frontmatter-scoping
  (V3) or co-location anchor (V4)." Same reasoning class, distinct scripts/languages → reported as 2 fixes, not inflated.
- **Bias scan**: V1/V2 rated CRITICAL — verified by executed corpus impact, not adversarial reflex (V2 = 26/27 files).
- **Meta-falsifier**: strongest defense against V4 false-FAIL ("skills should say rollback") steelmanned and
  rejected on the task's own L-1 principle. All 4 findings CONFIRMED after self-attack; none downgraded.

## VERDICT

**4/4 fixes BROKEN as drafted.** Must-fix hardening:
1. V1: drop `-i`, use delimited/ALLCAPS/colon regex (proposed misses `[placeholder]`,`TODO`,`PLACEHOLDER`).
2. V2: G2-upgrade is a NOT-READY trap unless `summary→description` migration (§B9/FORK-1) lands FIRST — 26/27 refs use `summary:`. Hard sequencing dependency.
3. V3: awk-fence + space-before-colon tolerance (gate currently fails OPEN on spaced colon, fires on doc code-blocks).
4. V4: synonym-set + co-located failure-context anchor (proposed false-FAILs real "compensate/revert", false-PASSes background "rollback").

*El Demoledor: proving resilience through destruction.*
