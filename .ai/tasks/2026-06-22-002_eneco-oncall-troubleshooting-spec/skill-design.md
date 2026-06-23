---
task_id: "2026-06-22-002"
agent: cursor
status: completed
summary: Design record for eneco-oncall-troubleshooting-spec harness skill
---

# Skill design: eneco-oncall-troubleshooting-spec

## Sign-off

- **Status:** CALIBRATION-WAIVED (user requested unilateral skill creation from FBE template work)
- **Golden specimen:** `log/employer/eneco/02_on_call_shift/2026_june/2026_02_22_001_fbe_404_stefan/slack-intake.md`
- **Template:** `log/employer/eneco/02_on_call_shift/_templates/slack-intake.template.md` v1.0.0

## Golden end-state triage

| Field | Value |
|-------|-------|
| PRIMARY substrate | `artifact` |
| CEILING | mechanical-complete (template section parity + manifest keys) |
| Near-miss | Free-form markdown intake without prefetch gate |
| Secondary | `knowledge` (context summaries in optional prefetch file) |

## Make-vs-buy (DF5)

**Verdict:** Dedicated skill — task-specific sequencing (prefetch → manifest → render) is not universal enough for AGENTS.md; overlaps `on-call-log-entry` but ends at spec handoff, not RCA.

## Discrimination evidence (abbreviated)

| Heuristic | Base model without skill | With skill | Observable delta |
|-----------|-------------------------|------------|------------------|
| H-SPEC-2 Prefetch gate | Starts kubectl/az immediately | Blocks probes until Slack/wiki/vault row cited | Context table has A1 citations or A3 blocked rows |
| H-SPEC-3 Manifest | Invents BUILD_ID | A3 or omit | Manifest matches harvest only |

## Claim ledger

| Claim | Class | Source |
|-------|-------|--------|
| Harness skills are centralized in `.ai/harness/skills/*.md` | Known | `.ai/harness/rules/structure/repository-structure.md` |
| Wrappers required at `.claude/.cursor/.gemini/.codex/skills/` | Known | `validate-harness-completeness.sh` §15 |
| Template v1.0.0 defines UAC and context fetch | Known | `slack-intake.template.md` |
| Stefan instance is valid golden shape | Known | `2026_02_22_001_fbe_404_stefan/slack-intake.md` |

## Structure declaration

| Layer | Status | Rationale |
|-------|--------|-----------|
| references/ | OMITTED | Template + golden instance live in log/; harness flat-file skill |
| scripts/ | OMITTED | No deterministic validator in repo harness |
| examples/ | OMITTED | Golden specimen external in log/ |
| assets/ | OMITTED | Template owned by on-call shift templates dir |
