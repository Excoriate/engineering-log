---
task_id: 2026-06-22-002
agent: kant-cognitive-scientist
timestamp: 2026-06-22T10:20:00Z
status: complete

summary: |
  Adversarial clarity review of eneco-oncall-troubleshooting-spec against Stefan golden
  example and slack-intake template. Verdict PARTIAL: structural contracts are strong but
  verification is heading-aligned not depth-calibrated; prefetch and example-bar obligations
  are partly unwitnessable; optional-vs-exemplar ledger creates a double bind agents resolve
  toward shallow PASS.

key_findings:
  - finding_1: Step-2 acknowledgement lives in task notes only — compliance not observable in intake.md
  - finding_2: Optional tool ledger vs Stefan full ledger — Law 6 contradiction; H-SPEC-4 checks TOC only
  - finding_3: Verification checklist allows self-grade PASS via all-A3 context rows + heading clone
---

# Kant clarity review — eneco-oncall-troubleshooting-spec

**User bar:** Vague error + folder path → `intake.md` matching Stefan rigor, no scope creep.

**Artifacts read:** skill.md, fbe-404-stefan-intake.md, slack-intake.template.md, on-call-log-entry cross-ref.

## VERDICT: PARTIAL

Skill can produce structurally valid `intake.md` without Stefan-quality prefetch depth. Binding language exists (BLOCKING step 4, H-SPEC-2) but **witness surface is weak** — agents optimize for verification checklist (Law 4: training prior toward “complete the checklist”).

---

## Attack vector findings

### 1. Attention / lost-middle — prefetch skip after heuristics

**Mechanism:** H-SPEC-2 (line 92–95) and step 4 (128–130) both mandate prefetch, but heuristics sit in **lost-middle zone** (~40% of skill body) between router table and steps. Step 5 immediately offers **optional tool ledger** — recency pulls agents toward concrete CLI work (Law 3: “ledger” primes probe behavior).

**Empathic read:** After reading Stefan example’s rich Tools section, agent feels bar = fill ledger; skill step 5 says optional → agent fills ledger **before** context fetch rows, inverting H-SPEC-2 order.

**Falsifier:** `intake.md` has populated Tool availability ledger + empty `SEARCH_TERMS` / all context rows `A3` with generic reason → prefetch skipped.

### 2. Competing instructions — optional ledger vs Stefan exemplar

**Double bind (Law 6):** Step 5: “Optional non-destructive tool ledger.” H-SPEC-4 + Stefan example: full ledger, snapshot, exemplar commands. Template placeholders (`{{KUBECTL_VERSION}}`) imply optional fill; example is **fully populated**.

**Falsifier:** Diff Stefan vs new intake — headings match, Tool ledger is template placeholders only; verification still PASS.

### 3. Acknowledgement obligations — observable compliance?

**Gap:** Mandatory surfaces table (47–57) requires derivation header evidence; step 2 done-when = “acknowledged in **task notes**” — **not** in deliverable. No verification item for “read bundled example.”

**Falsifier:** No task notes artifact required; agent writes intake.md without ever opening example file — cannot be disproven from output alone.

### 4. Trigger vs NOT-for — on-call-log-entry false positives

**Overlap:** on-call-log-entry step 2b delegates vague intake to this skill; triggers include “enrich vague FBE error.” User says “log this on-call incident” → on-call-log-entry wins; may skip `intake.md` entirely (step 2b optional phrasing “when vague”).

**Inverse false positive:** “build troubleshooting spec” triggers this skill even if user wanted full RCA pipeline.

**NOT-for** lists RCA/fix but **not** “full incident log workflow.”

**Falsifier:** Prompt “create on-call log for FBE 404 in {folder}” → agent runs on-call-log-entry only, no intake.md.

### 5. Verification cost vs falsifiability — self-grade PASS

**Checklist (147–154)** is structural: exists, header path, manifest present, headings align, no sibling RCA files. **No depth probes:** verbatim harvest status, min A1 count, ledger tier, attachment analysis, `ROUTER_SYMPTOM` gate.

**Falsifier:** Script checks headings + file existence only → shallow intake PASSes; blind human rejects depth.

### 6. Naming friction — intake.md vs slack-intake.*

**Triangulation:** Output `intake.md`; template `slack-intake.template.md`; legacy `slack-intake.md`; raw `slack-intake.txt`. Line 43–44 acknowledges rename debt without **FORBIDDEN** list.

**Falsifier:** Agent writes `slack-intake.md` or edits template in `_templates/` — skill verification silent.

---

## Top 3 clarity/cognition findings (ranked)

| # | Finding | Root law | Falsifier |
|---|---------|----------|-----------|
| 1 | **Unwitnessable prefetch/read obligations** — step 2 task-notes ack; verification doesn’t require intake-embedded prefetch evidence beyond per-row A3 escape hatch | Law 2 + Law 7 | intake.md PASS with zero A1 context citations and no harvest in Original request |
| 2 | **Optional ledger vs exemplar bar** — agents satisfy H-SPEC-4 (headings) while omitting Stefan-depth Tools block | Law 6 | Heading-aligned intake without version rows when BUILD_ID known |
| 3 | **Verification = structure theater** — self-grade PASS without depth calibration | Law 4 | Automated checklist green; Stefan diff fails on manifest completeness + attachment Known state |

---

## Minimal fix recommendations (skill.md only)

1. **Witness prefetch in deliverable:** Add verification item: each context-fetch row has A1 citation **or** A3 with named blocker + fallback query documented **in intake.md** (not task notes). Move step 2 done-when to: “derivation header includes `example_calibrated: fbe-404-stefan-intake.md`.”

2. **Resolve ledger double bind:** Replace “Optional tool ledger” with: **If manifest has BUILD_ID or SLOT → tool ledger + SNAPSHOT required (match example tier); else omit subsection.** Align H-SPEC-4: “section depth ≥ example for populated manifest keys.”

3. **Depth verification (3 binary checks):** (a) `Original request` not still paraphrase-only when Slack URL present; (b) `Known state from attachments` non-empty when ATTACHMENT_REFS set; (c) `PRIMARY_SKILL` + `ROUTER_SYMPTOM` both set.

4. **NOT-for row:** “Full incident log (context + RCA + fix)” → `on-call-log-entry`; this skill **only** when user wants agent-ready spec or step 2b vague handoff.

5. **Naming lock:** Under Scope: `FORBIDDEN outputs: slack-intake.md, editing _templates/*`; only `{folder}/intake.md`.

---

## Confidence

| Dimension | Level | Basis |
|-----------|-------|-------|
| Diagnosis | Medium–High | Textual double binds + unwitnessable done-when in skill.md |
| Intervention | Medium | Symmetric fixes at Law 2/6/4 layers; needs runtime A/B on one vague intake |
| User bar met today | Low | PARTIAL — structure yes, Stefan rigor not enforced |

---

## Escalation

None. Review complete; implement fixes in harness skill + mirrored `.cursor/skills/` copy via parent agent.
