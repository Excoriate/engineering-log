---
title: "Initial requirements — BTM scripts / ADO RCA re-verification"
status: draft
timestamp: 2026-06-22T00:00:00Z
task_id: 2026-06-22-010
agent: claude-opus-4-8
summary: "Re-verify the BTM az-boards-add-tag incident with zero unverified claims; deliver rca-holistic (.md+HTML) + how-to-feynman + an actionable fix that achieves the real effect (tags applied)."
---

# Initial Requirements (P1 mirror of NN-3 preflight)

## User-verbatim goal corpus (for goal-fidelity adversarial)

> "This was troubleshooted before, but your job is to **verify 100% everything, no space
> for unverified claims**, and provide an **actionable fix**. use /rca-holistic (both .md
> and HTML), and a /how-to-feynman **that will actually work** with an actionable how to
> fix it. So I can implement it, or an agent."

Original intake UAC (from slack-intake.md):
> "use ... the `how-to-feynman` skill, so it's explained in a .md document ... I must be
> able to understand deeply your rationale, and replicate it by myself. If not, it's a
> failure."
> "Ensure the script can be tested locally, so I can inspect it. If the solution requires
> ADO, it must be specified in the .md document."

## The decisive reframing (why the prior attempt is INSUFFICIENT)

The prior package (`old_attempt_to_fix_it/`) is internally rigorous but solves **Thread A**
only:

- **Thread A — TF401019 (the loud symptom).** `az boards query` omits `--org/--project` →
  CLI auto-detects repo via `GET /_git/<repo>/vsts/info` → project-scoped job token denied
  → `TF401019` → error swallowed (no `set -e`, inside `done < <( )`) → green build, no tag.
  Prior fix: `--organization/--project/--detect false`. **This is provably correct for the
  error message.**

- **Thread B — empty workItems (the REAL blocker, in requirements.md).** AFTER applying
  `--detect false`, Anton reports the error is gone but `az boards query` returns
  `{"workItems":[]}` → **tags still never apply**. A NEW Slack request states the pipeline
  identity `mcc-btm-deployment-dta-sp` "lost access to our ADO Boards — it cannot see and
  update the workitems", broke "around the time someone/something added
  `mcc-btm-deployment-dta-sp` to devops users on 22nd of April" (matches the prior RCA's
  own bisected onset window 2026-04-15..04-25). Production `mcc-btm-deployment-prd-sp` still
  works.

**Conclusion:** the prior fix closed on "error gone" (return-code thinking), not on the
observed effect (tags realized) — exactly H-EFFECT-1. The user's "verify 100% / fix that
actually works" mandate = diagnose and fix **Thread B**, while re-verifying Thread A.

## Load-bearing open questions (must be resolved or marked A3[blocked])

1. WHICH identity does the `az boards` call actually authenticate as — `System.AccessToken`
   (Build Service) or one of the `mcc-btm-deployment-*-sp` SPs? (Niels: "system.access
   token was not using the SP credentials but rather the pipeline pool credentials.")
2. Why does the WIQL return empty after `--detect false`? Competing hypotheses:
   - H-B1: identity lost **area-path read** ("View work items in this node") on `Team BtM`
     AreaId 6393 around Apr 22.
   - H-B2: benign — manual/test trigger means `git log` has no "Related work items:" lines →
     `System.Id IN ()` → empty/erroring query (NOT a permission loss).
   - H-B3: project-scope / org policy change altered Boards visibility for the job token.
3. What is `mcc-btm-deployment-dta-sp`, why was it created in ADO on Apr 22, and is deleting
   it safe? (User explicitly asks — DESTRUCTIVE, requires authorization; H-SAFETY-1.)

## Deliverables (fixed)

- `rca-holistic` package — `.md` AND `.html`.
- `how-to-feynman` — actionable, locally testable, replicable by user or agent.
- An actionable fix that achieves the **effect** (tags applied), with witnessable success
  signal, not just "error gone".

## Success criteria (externally witnessable)

Every load-bearing claim A1/A2/A3 with inspectable source; Thread B root cause confirmed by
independent disconfirmation (not narrative recap); fix step-executable with named effect
witness; deliverables render/parse-verified; typed adversarial passed before status=complete.
