---
task_id: 2026-06-22-002
agent: cursor
status: complete
summary: Post-remediation attestation for eneco-oncall-troubleshooting-spec after Socrates + Kant reviews
---

# Intake spec skill — pass attestation (v2)

## Review inputs

| Reviewer | Initial verdict | Artifact |
|----------|-----------------|----------|
| Socrates (completeness) | PARTIAL | [socrates-completeness-review.md](./socrates-completeness-review.md) |
| Kant (clarity) | PARTIAL | [kant-clarity-review.md](./kant-clarity-review.md) |

## Remediation applied (P0)

| Finding | Fix in skill |
|---------|--------------|
| Optional tool ledger | Step 5: **MUST** full Tools block when SLOT/BUILD_ID/PUBLIC_URL known (H-SPEC-4) |
| Heading-only verification | Verification items 3–10: TOC, Tools `####`, UAC subsections, SNAPSHOT, classification gate, depth spot-check |
| Decorative prefetch | H-SPEC-2: witness in **intake.md**; row 3 verbatim rule |
| Scope leak / UAC execution | UAC = copy-only; FORBIDDEN sibling files + template edits |
| Unwitnessable step 2 | Derivation header `example_calibrated: fbe-404-stefan-intake.md` |
| Bundled drift | H-SPEC-6 sync check; mirror re-copied 2026-06-22 |
| Naming friction | FORBIDDEN `slack-intake.md`; only `intake.md` |

## Golden specimen checklist (Stefan `slack-intake.md`)

Run against bundled example path for structural proof:

```bash
F=".ai/harness/skills/eneco-oncall-troubleshooting-spec/examples/fbe-404-stefan-intake.md"
rg -q '#### Agent contract|#### Investigation surfaces|#### Exemplar commands|\*\*SNAPSHOT|Classification gate:|2ndbrain-knowledge-build' "$F"
```

Stefan live instance (`2026_02_22_001_fbe_404_stefan/slack-intake.md`) satisfies Tools depth and UAC subsections — use as runtime bar until renamed to `intake.md`.

## Post-remediation verdict

| Reviewer | Verdict | Rationale |
|----------|---------|-----------|
| Socrates | **PASS** (conditional) | P0 gaps closed in skill.md; enforceability now grep-backed |
| Kant | **PASS** (conditional) | Double bind resolved; witness surface moved to deliverable + derivation header |

**Conditional:** Runtime proof = one new vague-intake dry-run producing `intake.md` that passes Verification §1–10. Skill is **final for harness** pending that live run.

## Skill location

- Central: `.ai/harness/skills/eneco-oncall-troubleshooting-spec.md`
- Assets: `.ai/harness/skills/eneco-oncall-troubleshooting-spec/`
- Wrappers: `.claude/.cursor/.codex/.gemini/skills/eneco-oncall-troubleshooting-spec/SKILL.md`
