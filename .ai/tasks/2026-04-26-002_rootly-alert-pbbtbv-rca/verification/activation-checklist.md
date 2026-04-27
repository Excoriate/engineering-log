---
task_id: 2026-04-26-002
agent: claude-opus-4-7
status: complete
summary: NN-1..7 + brain activation checklist for the pbbtBV RCA delivery.
---

# Activation Checklist

| Gate | Evidence | Pass? |
|------|----------|-------|
| **Phases 1-8 gate-outs** | $T_DIR has: `01-task-requirements-initial.md`, `01-task-requirements-final.md`, `context/map-{ai,codebase,config,docs,discovery}.md`, `plan/plan.md` (with `## Adversarial Challenge` + downstream consequences), `specs/rca-spec.md`, RCA artifact at user-named external path, `verification/01-adversarial-review.md`, `verification/phase-8-results.md`. 4→5 transition has Verify Strategy Delta + most-wrong; 7→8 has Belief Changes + most-wrong. | PASS |
| **NN-1 TodoWrite** | 8 tasks created, marked in_progress at phase entry, completed at phase gate-out. Final task (Phase 8) is in_progress until this checklist closes. | PASS |
| **NN-2 Files** | All artifacts on disk; manifest.json updated with external_writes; nothing inline >200 tokens that should be a file. | PASS |
| **NN-3 Pre-flight** | Mirrored in `01-task-requirements-initial.md`; DOMAIN-CLASS=investigation, ROOT-ARTIFACT=n, USER PRE-FRAMING captured (autonomy-push, not complexity-minimizing), CRUBVG scored with axis evidence, System view + Counterfactual + Hypotheses + BRAIN SCAN all present. | PASS |
| **NN-4 Safety** | Read-only across the board: no git mutations, no `az ... create/update/delete` against any resource, no Slack send, no incident creation. Cached SP creds scoped to `/tmp/mc-development.env` chmod 600. ROOTLY_API_KEY is pre-existing env var, not exfiltrated. | PASS |
| **NN-5 Context** | Per-phase reads tracked: ~12 files read in total across Phase 4 (Read on rca + alerts.tf + locals.tf + keyvault.tf — all <500 lines). No 10+/3000+ line breach. Bash-based `head -N`, `jq` filtering kept payloads small. | PASS |
| **NN-6 Activation Checklist** | This file. | PASS |
| **NN-7 Subagents Scan** | Single dispatch (socrates-contrarian) with named UNIQUE CAPABILITY ("typed adversarial-reviewer per brain rule, not fork — to avoid confirmation bias from inherited executor conclusions") and SPECIFIC QUESTION ("find new attacks distinct from plan.md 6Q; produce findings with falsifiable observations"). Logged in plan.md S3. | PASS |
| **CRUBVG** | Phase-1 score 6 (C1/R0/U2/B1/V1/G1, +1 G≥1 bonus = 6 total). Re-scored at 4→5 with U2→0 and G1→0 closing the score (mechanism + IaC fully resolved). | PASS |
| **Route + Triggers** | DOMAIN-CLASS=investigation honored (investigation-specialist not strictly needed; coordinator served as investigator since CRUBVG≤7 with A1-A4 holding). Adversarial externalized to socrates-contrarian (typed subagent, NOT fork). EVALUATOR not triggered (CRUBVG<8, no quality-grade). | PASS |
| **Plan Adversarial Challenge** | Q1-Q7 in plan.md; Q5 probed via `git tag` + git log; Q7 (orthogonal) added because CRUBVG≥4 originally; downstream consequence named. | PASS |
| **Claims A1-A4** | Every load-bearing claim in the RCA labelled (FACT)/(INFER)/(UNVERIFIED[…]); 8 explicit labels per `grep -cE`. | PASS |
| **Hypotheses ≥2 with elimination** | H1 ELIMINATED (evidence E8), H2 STRONGLY SUPPORTED, H3 ELIMINATED (E8), H4 NOT FULLY DISCONFIRMED (added via socrates F5). | PASS |
| **Task tracking dynamic** | Task subjects use operation+object+done-when (e.g., "Phase 4: Context — fetch Rootly alert payload, connect MC dev, retrieve Azure metric series"). Lifecycle in_progress → completed verified per phase. | PASS |
| **Contract surfaces** | RCA references both canonical IaC (file:line) and live Azure rule (`az monitor metrics alert show`) — confirmed byte-for-byte match. The user-named external destination path is in `manifest.allowed_external_paths` and recorded in `external_writes`. | PASS |
| **Actionable artifact** | Per-claim classified (8 explicit labels). Adversarial dispatch was content-specific (RCA path + evidence dump path + 5 attack-vector hints). Epistemic debt: RCA top-3 risks named in Residual Risk (regional micro-incident, caller identity, threshold appropriateness across products). | PASS |
| **Verify ≠ Adversarial** | Falsifier ledger above is *verify* (does the RCA pass its own acceptance criteria?). Adversarial review file is *attack* (where can an engineer be hurt by following the RCA?). Two semantically distinct win conditions, separately stamped. | PASS |
| **Memory** | Recall bundle was loaded at session start (handoff `mc-vpp-infrastructure-harness-bootstrap`); not load-bearing for this task. No memory writes during execution. Will write task-local lessons to `lessons-learned/` and propose memory promotion in the user-facing summary. | PASS |
| **Routing keys** | DOMAIN-CLASS=investigation declared at preflight, honored throughout (probe-first, hypothesis-elimination, adversarial-on-RCA). ROOT-ARTIFACT=n correct (the RCA is task-local, not a brain/rule update). | PASS |
| **Visual reasoning** | Concerns are not spatially distributed (single rule, single resource, single subscription, single action group, single Rootly alert). System diagram would be linear and not informative. Declared absent. | PASS |
| **Overconfidence guard** | Top-3 highest-stakes load-bearing claims: (a) "single sample drives the breach" — A1 (FACT), externally-witnessable via `az monitor metrics list ServiceApiLatency` PT1M; (b) "rule is hardcoded in CCoE module" — A1 (FACT), externally-witnessable via `git show terraform-azure-keyvault/locals.tf:22-40` AND `az monitor metrics alert show` byte-for-byte match; (c) "auto_mitigate cannot clear without traffic" — A2 (INFER), externally-witnessable via `az rest GET .../alerts/<id>` returning persistent `monitor=Fired` hours after the breach (probed and confirmed during socrates F1 receipt work). | PASS |
| **Attention topology** | Not a root-brain edit; N/A. | N/A |
