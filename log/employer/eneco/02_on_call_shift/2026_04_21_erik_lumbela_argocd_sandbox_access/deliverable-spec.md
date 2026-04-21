---
task_id: 2026-04-21-001
agent: claude-code
status: complete
summary: Spec — one markdown outcome file for Alex to post/hand Erik; contents match the enrichment report's recommended-action section + plan's Phase 8 falsifiers re-run live.
---

# Deliverable Spec

## What-why

Alex needs a single compact artifact he can read on-call, decide to send to Erik (or paste adapted), and keep as runbook for future "I don't have access to X in ArgoCD sandbox" tickets. The artifact must be *evidence-anchored* (not memory-based), *terse* (Slack register), and *educational enough* that the team can self-serve next time.

## Inputs

- `context/enrichment-report.md` — full diagnostic body (probes, ledger, adversarial pass).
- `plan/plan.md` — step-by-step + verification strategy.
- Live probe re-runs (Phase 8 below) — to prove the state hasn't drifted since Phase 4.

## Output

Single file at `outcome/diagnosis-and-fix.md`:

1. One-paragraph verdict (is it fixed? what's left?).
2. Numbered step-by-step for Erik (sign out + sign in + verify command).
3. The evidence block (small table, 6 rows).
4. The ready-to-paste Slack reply draft.
5. Contingent branch if verification fails (what to probe next, not what to commit).

## Verification

- Each step: one concrete command with expected output.
- Claims classified A1-A4 at decision points.
- No AI tells in the Slack draft.
- Links: PR URL, Microsoft Docs groups-overage, ArgoCD RBAC doc.
