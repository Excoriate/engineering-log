---
task_id: 2026-06-22-002
agent: socrates-contrarian
timestamp: 2026-06-22T00:00:00Z
status: complete

summary: |
  Adversarial completeness review of eneco-oncall-troubleshooting-spec L2 skill against
  Stefan FBE 404 bar and canonical slack-intake.template.md. Verdict PARTIAL: intent and
  template wiring are sound, but verification and Step 5 weaken enforceability—agents can
  pass checklist with heading-only, ledger-empty, self-attested prefetch intake worse than Stefan.

key_findings:
  - finding_1: Step 5 marks tool ledger optional; Verification never requires Tools subsections or SNAPSHOT
  - finding_2: Prefetch gate accepts A3 self-attestation without harvest evidence in intake body
  - finding_3: H-SPEC-4 heading diff allows stripped UAC/Tools content; classification gate unverified
---

# Contrarian completeness review: eneco-oncall-troubleshooting-spec

## STEELMAN

- **Best interpretation:** Skill renders one contract-faithful `intake.md` from canonical/bundled template, prefetches context via three skills, stops before investigation—Stefan example is the depth bar.
- **Author intent:** Separate intake spec authoring from RCA/fix workflows; template/instance split with bundled offline mirror.
- **Works when:** Agent reads template + example, copies generic sections verbatim (H-SPEC-5), runs verification checklist honestly.

## VERDICT: **PARTIAL**

Skill architecture is directionally correct but **not rigorously enforceable** at Stefan bar. Heading-only compliance passes; optional ledger and decorative prefetch undermine the user bar.

---

## Attack vector responses

### 1. Sub-Stefan output despite following skill?

**YES — mechanistically allowed.**

| Claim attacked | Evidence |
|----------------|----------|
| H-SPEC-4 "same TOC hierarchy required" | Verification L153: headings only—no minimum row counts in Tools/UAC tables |
| Step 5 "Optional non-destructive tool ledger" | L134 `.ai/harness/skills/eneco-oncall-troubleshooting-spec.md` — contradicts Stefan example L180–206 with filled ledger + SNAPSHOT |
| H-SPEC-5 "copy verbatim" vs Step 5 optional | Agents can skip ledger/snapshot and still PASS verification |

**Mechanism:** Agent copies TOC + section titles → empty `Tool availability ledger` → omits `#### Investigation surfaces` body → PASS because file exists + headings grep-match example.

**Falsifier:** On skill output: `rg -q '#### Agent contract|#### Investigation surfaces|#### Exemplar commands|^\*\*SNAPSHOT' {folder}/intake.md && rg -q 'Tool availability ledger' {folder}/intake.md && ! rg -q '\{\{KUBECTL_VERSION\}\}|{{.*}}' {folder}/intake.md` → must exit 0.

### 2. Scope leaks (rca/fix/context)?

**PARTIAL containment.**

| Strength | Gap |
|----------|-----|
| L17–18, L154 BLOCKED + verification for `rca.md`, `fix.md`, `context.md`, `output/` | Template UAC L225–257 embeds deliverable paths; Skills table names `rca-holistic`, `on-call-log-entry` — no skill-level "copy only, do not execute" on UAC |
| L89 H-SPEC-1 forbids sibling RCA files | Step 1 L116 allows folder creation; template mentions `context-prefetch.md` — skill silent on BLOCKED |

**Mechanism:** Agent finishes `intake.md`, reads UAC Deliverables, continues to `context.md` in same session—verification runs after, not gated mid-run.

**Falsifier:** Dry-run prompt "create intake only" → `find {folder} -maxdepth 1 -type f ! -name intake.md ! -name 'image.*'` → must be empty.

### 3. Missing mandatory template behaviors in skill enforcement

**Skill silent on verifying these template surfaces in output:**

- `#### Agent contract` (template L150–157)
- `#### Investigation surfaces` (L186–194)
- `#### Exemplar commands` + fenced block (L192–204)
- `**SNAPSHOT ({{LEDGER_DATE}}):**` row (L206)
- `**Classification gate:**` paragraph under Skills (L140–144)
- Full UAC subsections including `Post-completion: vault and memory` with `2ndbrain-*` (L234–243)

H-SPEC-5 implies verbatim copy but Verification never lists them. Stefan example summarizes some UAC prose but **retains all subsections and Tools depth**.

**Falsifier:** `rg -c '^#### ' {folder}/intake.md` ≥ 9 (Evidence and honesty, Learning bar, Deliverables, Post-completion, RCA acceptance, How-to-fix, Out of scope, Agent contract, Investigation surfaces, Exemplar commands — adjust count) AND `rg '2ndbrain-knowledge-build' {folder}/intake.md`.

### 4. Prefetch gate — enforceable or decorative?

**Mostly decorative.**

| Surface | Issue |
|---------|-------|
| H-SPEC-2 L94 | "or mark each context row A3" — no proof of skill invocation |
| Step 4 L128–130 | Done-when defers to template body, not skill verification |
| Verification L152 | "citation or A3 per row" — agent can paste A3 without running `eneco-context-slack` |

**Mechanism:** Blocked MCP → agent stamps five `A3 UNVERIFIED[blocked: …]` rows → PASS without enrichment → intake not "rich."

**Falsifier:** Require row 3 (intake thread) contain verbatim quote **or** link to `slack-intake.txt` in folder; rows 1–2 cite channel message excerpt or `A3` + task artifact path under `.ai/tasks/`.

### 5. Template/bundled mirror drift

**Sync is documentary, not enforced.**

- Asset readme L3: "sync when canonical changes" — no skill step
- Skill L55 points to readme as "Sync contract" — no pre-render diff
- Runtime: `diff -q` canonical vs bundled differs only in header comments/title (8-line diff today)—low drift now, **zero guarantee later**

**Falsifier:** Add Verification step: `diff -q` canonical vs bundled OR `template_version` equality assertion before write.

### 6. Epistemic labels A1/A2/A3

**Required in template output sections; only partially required by skill.**

| Location | Skill |
|----------|-------|
| H-SPEC-3 | Manifest keys only |
| Verification L152 | Context fetch rows only |
| Template L112, L206, Skills | Labels in body — **not in Verification** |

**Mechanism:** Manifest values unlabeled; Context table rows without A1/A2/A3 prefixes → downstream agent treats paraphrase as FACT.

**Falsifier:** `rg 'A[123]' {folder}/intake.md | wc -l` ≥ 5 AND each Context-to-fetch row starts with or contains label.

---

## SUPERWEAPON DEPLOYMENT

| SW | Result |
|----|--------|
| Temporal Decay | Template version 1.0.0 fixed; bundled drift accumulates without sync gate |
| Boundary | Skill ↔ template UAC deliverables boundary ambiguous for scope |
| Compound | Optional ledger + decorative prefetch + heading-only verify = hollow Stefan |
| Silence Audit | Missing verification for classification gate, SNAPSHOT, Tools subsections |
| Uncomfortable Truth | "Example-shaped" is weaker than "Stefan-shaped" despite marketing copy L26, L54 |

---

## Required fixes (skill.md only)

### P0

1. **Step 5:** Replace "Optional non-destructive tool ledger" with **MUST** populate `Tool availability ledger`, `Investigation surfaces`, `Exemplar commands`, `SNAPSHOT` when any manifest identifier is set; omit ledger only when **all** of SLOT/BUILD_ID/PUBLIC_URL unknown (document A3).
2. **Verification:** Add checklist items (grep-able):
   - TOC block present (mirror example L19–38)
   - `#### Agent contract`, `#### Investigation surfaces`, `#### Exemplar commands`, `**SNAPSHOT` present
   - `Classification gate:` under Skills
   - All seven UAC `####` subsections present (not summarized away)
   - No unresolved `{{PLACEHOLDER}}` in output
3. **Prefetch:** Change H-SPEC-2 / Verification — each of 5 context rows MUST show harvest summary with `A1`/`A2`/`A3` **in intake.md**; row 3 MUST NOT remain paraphrase-only if Slack accessible.

### P1

4. **Scope:** Add BLOCKED line: do not create `context.md`, `rca.md`, `fix.md`, `output/`, `context-prefetch.md` in this skill run; UAC deliverables are **downstream contract text only**.
5. **Sync:** Add Step 2.5 or Verification: confirm bundled `intake.template.md` matches canonical (diff or version); fail with "re-sync bundled mirror" instruction.
6. **Epistemics:** Extend Verification — manifest table values cite evidence class; Context-to-fetch rows labeled.

---

## META-FALSIFIER

This review assumes Stefan example + template are the authority bar. If user accepts "heading parity only," verdict upgrades to ACCEPTABLE. Re-read skill after P0 edits; if Step 5 still says "optional," review stands.

## RECOMMENDATION

**Revise before treating skill as production-ready.** Conditions: implement P0 verification gates; re-run Stefan folder dry-run and diff output against `examples/fbe-404-stefan-intake.md` structure + Tools depth.
