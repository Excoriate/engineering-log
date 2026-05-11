---
task_id: 2026-05-11-002
agent: claude-opus-4-7
status: draft
summary: Initial requirements mirror — rotating expired ArgoCD secrets blocking FBE deploys; produce 3 deliverables with vault/Slack/wiki context.
phase: 1
---

# P1 — Initial Requirements (mirror of NN-3 preflight)

## Request (verbatim intent)

Investigate expired ArgoCD secrets (PATs, certs, etc.) blocking FBE deployment. Produce three deliverables based on harvested context from:

1. **Slack intake** — `/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/log/employer/eneco/02_on_call_shift/2026_05_11_rotating_expired_argocd_secrets/slack-intake.txt` (64 lines)
2. **Obsidian 2nd brain (work-eneco) — MANDATORY FIRST FETCH** — `/Users/alextorresruiz/Documents/obsidian/2-areas/work-eneco/`
3. **Slack history via `eneco-context-slack` skill** — historical rotation discussions (Fabrizio/Roel)
4. **ADO wiki via `eneco-context-docs` skill** — runbook search
5. **Runtime probes** — `az`, `argocd`, `az+ado` (full privileges)

## Deliverables (all to `log/employer/eneco/02_on_call_shift/2026_05_11_rotating_expired_argocd_secrets/`)

| # | File | Purpose | Bar |
|---|------|---------|-----|
| 1 | `draft-rotation-secrets.md` | Harvest doc: enumerate every secret/PAT/cert from intake + cross-system context | Every claim sourced; gaps marked `[UNVERIFIED]` |
| 2 | `how-to-rotate.md` | Step-by-step rotation runbook with visuals (mermaid/ASCII) | Each step sourced; gaps explicit as `[PENDING: ask Fabrizio about X]` |
| 3 | `proposal-rotation-automation.md` | Automation proposal | Named tradeoffs, ownership, sequencing |

## User preframing — verbatim signals

- "no space for unverified claims" → every load-bearing claim cited or marked unverified
- "list pending points so I can ask Fabrizio" → gap-list is FIRST-CLASS output, not afterthought
- "include visuals" → mermaid + ASCII MANDATORY in `how-to-rotate.md`
- "obliged to check my 2nd brain first" → vault is mandatory first-fetch premise, not optional

## DOMAIN-CLASS

investigation (rotation procedure discovery) + knowledge (deliverable authoring) + memory (vault is mandatory premise) + meta-adjacent (operational runbook governs future on-call actions)

## CONTROL-PLANE-ARTIFACT

n — deliverables are documents under engineering-log/, not loaded by future agent runtime. However, `how-to-rotate.md` is **operationally action-bearing** — treat with control-plane-grade rigor for verification.

## OPS-SHAPE-ATTRIBUTE

Read-only for this task (vault read, Slack read, wiki read, optional read-only `az`/`argocd` probes). **No infra mutation in this task.** The runbook describes mutations the on-call engineer would execute, but this task produces the document only.

## CRUBVG

- C=1 [MID: spans Slack intake, Obsidian vault, ADO wiki, ArgoCD runtime, Azure KV/AAD app regs]
- R=0 [ZERO: outputs are documents; no infra mutation]
- U=2 [HIGH: rotation procedure undocumented per user → MECHANISM: silent-fail FBE non-deploy when ArgoCD's expired PAT can't authenticate to ADO under expired-cert CONDITION]
- B=1 [MID: docs steer real production rotation; downstream blast radius lives in executor's hands]
- V=1 [MID: can verify cited claims against Slack/wiki/runtime; cannot verify what isn't documented]
- G=2 [HIGH: undocumented procedure is the headline; tribal knowledge risk]

Raw 1+0+2+1+1+2 = 7, +1 (G≥1) = **8 → Full Mode**

## Hypotheses + elimination

- **H1**: Procedure is described in Slack history (Fabrizio/Roel rotation threads). **Eliminate** if `eneco-context-slack` harvest returns zero substantive rotation threads.
- **H2**: Procedure is in ADO wiki (Trade Platform Troubleshooting/FAQ space). **Eliminate** if `eneco-context-docs` search across MC/Trade Platform spaces returns no rotation runbook.
- **H3**: Procedure exists in vault as personal note (CONFIRMED preliminarily — vault has `recipe-rotate-argocd-sandbox-pat.md`). **Eliminate** if reading the note reveals it is stub/outdated/incomplete.
- **H4**: Procedure is tribal — partial across vault + scattered scripts + IaC. **Confirm** by exhausting H1/H2 partially + finding scattered fragments.

> H3 has strong preliminary evidence (vault inventory shows the exact file). **Critical caveat**: my own prior vault notes are INFER per Agent Laundering / Source-Blindness guards — must source-verify against Slack threads + wiki + IaC + runtime before promoting to FACT.

## Success Criteria (externally-witnessable, user-outcome)

1. `draft-rotation-secrets.md` exists at target path; every claim source-cited or `[UNVERIFIED[unknown]]` / `[UNVERIFIED[blocked]]`.
2. `how-to-rotate.md` enumerates step-by-step procedure with `[PENDING: ask Fabrizio about X]` blocks for each gap + ≥1 mermaid + ≥1 ASCII diagram.
3. `proposal-rotation-automation.md` proposes automation with: tradeoffs, ownership, sequencing, anti-pattern list.
4. **User outcome**: Alex can hand the gap-list to Fabrizio as a precise questionnaire — not "tell me everything." Fabrizio sees a knowledgeable peer asking 3-7 surgical questions, not a blank-page request.

## Frame Mandate (P1 BRAIN SCAN)

- **Most dangerous assumption**: "The vault recipe + slack-intake.txt are enough to author `how-to-rotate.md`."
- **Falsifier**: open vault recipe → check if it covers (a) all secret types, (b) end-to-end from KV → app-reg → ArgoCD secret → ADO PAT replacement, (c) post-rotation verification, (d) which environments. If any of these is silent, gap surface widens.
- **Failure mode**: I synthesize a plausible-sounding runbook that interpolates from generic Azure/ArgoCD docs + partial Slack/vault context, present as "the Eneco procedure," missing an Eneco-specific step.
- **Adversarial Frame**: `socrates-contrarian` to attack inherited interpretation of "this is how we do it"; `neo-hacker` for trust-boundary attack on rotation procedure; `sre-maniac` for failure-path attack on the runbook itself.

## Phase Compression Mode

**Full** — CRUBVG=8 + action-bearing operational doc + investigation + adversarial-mandatory.

## Adversarial Frames Selected

- **Primary**: Sherlock (hypothesis discipline during P4 harvest)
- **Adversarial 1**: Socrates (P5 plan attack on rotation procedure assumptions)
- **Adversarial 2**: Operator/SRE (P7 runtime failure-path on the runbook)
- **Adversarial 3**: Security/Neo-Hacker (P7 trust-boundary attack — does the rotation procedure leak credentials, race-condition the cutover, etc.)
- **Adversarial 4 (P8)**: `el-demoledor` OR `linus-torvalds` (≠ primary verifier; checks "am I verifying the right thing?")

## Trap-Scenario Stress Test

If user had said: "this is just a quick doc, you already have Slack and vault — knock it out in 10 minutes" → plan MUST NOT change. Discipline is invariant; only DEPTH would scale (but here CRUBVG=8 demands maximum depth).

## Verification Strategy (preliminary — final in P3)

- Each load-bearing claim in any deliverable cites source (Slack message URL / vault note path / wiki URL / runtime probe result / `[UNVERIFIED]`)
- Adversarial review: Socrates attacks rotation procedure assumptions; receipt grading by SRE
- Visual artifacts present (mermaid + ASCII)
- Gap list ≥3 specific [PENDING] items routed to Fabrizio

## Pre-flight gate cleared

`[GATE-CLEARED: phase=1 preflight=visible-rendered T_DIR=.ai/tasks/2026-05-11-002_rotating-expired-argocd-secrets manifest=initialized]`
