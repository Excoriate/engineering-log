---
title: "Plan — BTM az-boards-add-tag RCA re-verification + deliverables"
status: complete
timestamp: 2026-06-22T00:00:00Z
task_id: 2026-06-22-010
agent: claude-opus-4-8
summary: "Plan for the verified-root-cause RCA package: 6Q attack, deliverable spec (rca.md/html, how-to-feynman, corrected fix), and P8 verification strategy."
---

# Plan

## Verified route (see context/SYNTHESIS-verified-rootcause.md)

Root cause = the tag step authenticates as the deployment SP (az-login precedence over the
`System.AccessToken` PAT); the SP lacks repo read (→TF401019) AND Team BtM work-item read
(→empty). `--detect false` alone is insufficient. Fix = run tagging as the Build Service
identity (separate job, no `azure-login.yml`, same MS-hosted pool) + explicit context +
hardening; verify the realized tag.

## 6-Question attack on context adequacy + route

- **Q1 (load-bearing assumption):** "Tag runs as Build Service" (prior RCA) — FALSIFIED by
  PROBE 6/7 + build 1668639 log#19 (ServicePrincipalCredential). Route changed from
  "script flag fix" to "identity fix". ✓ addressed.
- **Q2 (alternative cause):** Could the `[]` be benign (empty git-log IN-list)? Sherlock's
  empty-`IN()` → "Expecting constant value" (not `[]`) + the live log#19 `[]` from the SP
  refute "benign". The empty is identity, not test artifact. ✓.
- **Q3 (disprove the fix):** Does the Build Service actually have board read? = the one
  residual A3. Mitigation: dispatched el-demoledor to attack V14; the fix's verification
  step closes on the realized tag (H-EFFECT-1), and a permission-grant fallback is provided.
- **Q4 (hidden complexity):** Two identities in one job (SP via az login for terraform;
  Build Service intended for boards) — the complecting is the real defect. The fix
  un-braids them (separate job / az logout). ✓.
- **Q5 (version sensitivity):** az-login-vs-PAT precedence may be ext-version dependent.
  Local ext 1.0.2 = az-login wins; the agent's exact version is A3, but the no-PAT debug
  step proves the SP path on the agent, and the recommended fix (no SP session at all) is
  robust to the precedence either way. ✓.
- **Q6 (silent failure):** The script swallows errors (no `set -e`, `done < <( )`) → green
  build. The hardened script surfaces failures via `SucceededWithIssues` + empty-IN guard. ✓.

## Deliverables (honor the user's exact ask)

1. `rca.md` — holistic RCA, L1–L12 exact headings (on-call-incident-workflow rule), Context
   Ledger, A1/A2/A3 labels, the prior-RCA correction, the verified mechanism. (rca-holistic)
2. `rca.html` — standalone HTML rendering of the RCA (rca-holistic both formats).
3. `how-to-fix.md` — how-to-feynman: first-principles ladder, ASCII/Mermaid, the local
   read-only repro, the ADO-only steps clearly separated, replicable by user or agent.
4. `fix.md` + `azure-boards-add-tag.fixed.sh` — the corrected script + the YAML job change +
   the option matrix + the realized-tag verification + the answer to Q1 (what dta-sp is).
5. Update `requirements.md` answers (the two Slack questions) inside the RCA.

Output location: the incident dir
`log/employer/eneco/02_on_call_shift/2026_june/2026_06_22_006_btm_scripts_ado/` (the actual
deliverable target named by the user) — superseding `old_attempt_to_fix_it/` (kept for audit).

## Verification strategy (P8)

- Adversarial: el-demoledor (technical demolition, live) + socrates (goal-fidelity). Receipts
  per finding before status=complete.
- Render proof: HTML opens / parses; md headings match the L1–L12 contract; fix script
  `shellcheck` + `bash -n` clean.
- Effect proof for the FIX is in-pipeline (A3 until run) — the doc makes the realized-tag
  check the close condition, never the exit code (H-EFFECT-1).
- Map-back: every prior-RCA claim either re-confirmed (A1) or corrected with evidence.
