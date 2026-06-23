---
title: RCA dual-adversarial receipts (socrates + el-demoledor)
task_id: 2026-06-22-008
agent: claude-opus-4-8
status: complete
summary: Grading of the Phase-5 dual adversarial review of rca.md/quick-fix.md. Both PROCEED-WITH-CHANGES; all changes absorbed; el-demoledor's V1 blocker resolved by state-blob evidence.
timestamp: 2026-06-22T00:00:00Z
---

# RCA dual-adversarial receipts

Both reviewers confirmed the **core mechanism** (two independent failures). All findings target fix-hardening and evidence precision. No finding overturned the diagnosis.

## socrates-contrarian (`socrates-rca-review.md`) — PROCEED-WITH-CHANGES

| # | Finding | Disposition | Evidence/diff |
|---|---|---|---|
| C1 | "44 secrets" wrong (actual 49) | **RESOLVE** | Independently re-counted `locals.tf:64-118` = 49; fixed in rca/quick-fix/evidence-ledger |
| C2 | "manually added" stated as fact in prose | **RESOLVE** | Qualified as inference at first use; L10/L12 lessons reframed to certificate-name-collision |
| C3 | E6 conflates live-absence + destroyed-in-run-1 | **RESOLVE** | Split into E6a (A1 live) + E6b (A1 via state-blob) |
| C4 | quick-fix ADO guard uses wrong `dependencies.*.outputs` namespace | **RESOLVE** | Rewrote to job-level `condition: ne(variables['appconfig'],'')` per `:168-171` idiom + bash-guard alternative |
| C5 | cascade-skip cited at job level, actually stage-level default condition | **RESOLVE** | Clarified in L6/L8 + E8 |
| C6 | `featurebranchdeployment` account not in Context Ledger | **RESOLVE** | Added to the table row |
| C7 | Slack paste carries unqualified "manually added" | **RESOLVE** | Softened to "a certificate of the same name appeared in the KV" |

## el-demoledor (`demoledor-rca-review.md`) — PROCEED-WITH-CHANGES

| # | Finding | Severity | Disposition | Evidence |
|---|---|---|---|---|
| V1 | guard strands `thor.appconfig.tfstate` | BLOCKER | **REBUT (resolved by evidence)** | State blob = 184 B (empty), written 07:12 in run 1 ⇒ already destroyed; skipping strands nothing. Documented in L8 + quick-fix |
| V7 | break-glass leaves `terraform.thor` blob | HIGH | **RESOLVE** | Added `az storage blob delete terraform.thor` (+ appconfig blob) to quick-fix break-glass |
| V3 | re-run reads shared `vpp-aks-d` + remote state; SP access unre-verified | HIGH | **RESOLVE** | Added pre-flight note; run-from-pipeline (run 1 proved SP access) |
| V2T | app-config store in infra state; already-deleted on re-run | MED | **RESOLVE** | Noted azurerm 404-on-refresh handling in L8 |
| V4 | "403 cannot recur" is point-in-time | MED | **RESOLVE** | Added immediate-pre-run cert re-check (L8/L9 + quick-fix pre-flight) |
| V5 | L11 needs `az extension add --name azure-devops` | MED | **RESOLVE** | Added prerequisite to L11 |
| V6 | witness probe needs Storage Table Data Reader RBAC | MED | **RESOLVE** | Documented in L9 + quick-fix |

Rebut-without-evidence: 0. Systematic defer: 0. The single REBUT (V1) is backed by a command-output state-blob size, not prose.
