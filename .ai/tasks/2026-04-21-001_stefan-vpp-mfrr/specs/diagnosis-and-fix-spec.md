---
task_id: 2026-04-21-001
agent: claude-code
status: complete
summary: Acceptance criteria for the final diagnosis and step-by-step fix deliverable
---

# Spec — Final Diagnosis + Step-by-Step Fix

## What to produce

One file: `$T_DIR/outcome/diagnosis.md` — authoritative, self-contained. One companion: `$T_DIR/outcome/slack-reply-draft.md` (not posted automatically).

## Required structure

1. **Bottom line** (one paragraph). State root cause class (H1 / H2 / H3 / H4) with confidence and a one-line justification. If any probe was blocked, say so — do not paper over.
2. **Evidence** — FACT-classified list, each with source (file:line, command output, Slack permalink, MS Learn URL). Every load-bearing claim carries one of A1-A4 labels.
3. **Mechanism diagram** — the 10-step chain from IaC gap to `CrashLoopBackOff`, with the MS Learn citation anchoring the non-retryable SDK behavior.
4. **Failure ↔ Success pairing table** — invariant made visible (from first-principles-knowledge.md §3).
5. **Blast radius** — Sandbox-only vs. wider; Rootly check state; non-prod business impact; DX vs incident classification.
6. **Step-by-step fix** — operator-executable, one command per line, each step has:
   - Objective
   - Command (exact)
   - Acceptance (how to know it worked)
   - Falsifier (how to know it didn't)
   - Rollback
7. **Adversarial challenge summary** — the six Q&A pairs from the plan, shortened.
8. **Residual risk / UNVERIFIED** — explicit list of anything the session could not verify, with the missing capability named.
9. **Authority required** — who owns the write steps.
10. **Slack reply stub** (in the companion file) — sober, no AI tells, no ping while reporter is on vacation.

## Acceptance criteria

- A1-A4 labels present at every decision point.
- Every FACT has a cited source; every INFER has a named chain; every UNVERIFIED has a named probe and its blocker.
- Step-by-step fix is executable without further interpretation.
- Adversarial pass is summarized (full pass in plan.md).
- Independent adversarial reviewer has examined the deliverable (Phase 8).
- Sandbox-only blast radius is either confirmed by F5 output OR listed in residual risk as UNVERIFIED with the probe the operator can still run.

## Explicit non-deliverables

- No Terraform apply executed from this session.
- No Slack message posted from this session.
- No PR opened from this session.
- No severity claim beyond P3/P4 without explicit probe evidence.
