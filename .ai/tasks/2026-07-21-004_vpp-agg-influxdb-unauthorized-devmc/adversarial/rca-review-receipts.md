---
title: RCA + fix adversarial receipts — socrates-contrarian + el-demoledor
type: review
status: complete
timestamp: 2026-07-21T16:40:00Z
task_id: 2026-07-21-004
agent: claude-opus-4-8
summary: Disposition of the Phase-5 dual adversarial gate (socrates + el-demoledor) on rca.md + the fix shape. Both verdicts PROCEED-WITH-CHANGES; all findings RESOLVED (fix package's BLOCKING closed by writing how-to-fix.md).
---

# RCA + fix adversarial receipts

Gate: `socrates-contrarian` (undefended-assumption lane) + `el-demoledor` (break-the-fix lane), typed subagents, parallel, on the full `rca.md` + `explanation.md` Part 4. Receipts: `socrates-rca-review.md`, `eldemoledor-rca-review.md`. Both **PROCEED-WITH-CHANGES**, no BLOCKING on the *diagnosis*; el-demoledor's one BLOCKING was on the *fix package* (missing runbook), now closed.

## Socrates (assumptions & defensibility)

| # | Sev | Finding | Disposition | Change |
|---|-----|---------|-------------|--------|
| S-F1 | HIGH | b2b/b2c labeled A1 but cited evidence (one `dev/values.yaml`) doesn't show two variants | **RESOLVE** | Added ledger E5b citing `strikepricefn/{dev,acc,prod}/values.b2b.yaml`+`values.b2c.yaml` (A1 existence, A3 per-variant status); L8 step 4 now "enumerate every workload resolving the secret" |
| S-F2 | MED-HIGH | "401≠under-scope" + "tokens don't expire" labeled A1 but training-derived | **RESOLVE** | Split E8 → E8a (401 observed, A1) + E8b (interpretation, A2/vendor-doc with InfluxData URL); same in explanation ledger #10 |
| S-F3 | MED | Ledger E9 says "Root cause" but carries A2 | **RESOLVE** | Renamed E9 → "Leading hypothesis (root-cause candidate)" |
| S-F4 | MED | Confidence names only the org/bucket flip | **RESOLVE** | Confidence now enumerates 4 flips (byte-mismatch, never-succeeded, proxy, org/bucket-gone) |
| S-F5 | MED | Ground-truth evidence ledger less hedged than RCA; fix-shape skips byte-check | **RESOLVE** | Added superseded-by note atop `01-live-evidence.md` Diagnosis pointing to rca L8 + byte-check-first |
| S-F6 | LOW-MED | Kafka in diagrams but not in context ledger/glossary | **RESOLVE** | Added Kafka row to rca Context Ledger + explanation glossary |
| S-F7 | LOW | Three different line-number citations for the catch block | **RESOLVE** | Normalized to `InfluxDbClientHelper.cs:23–33 (throw at :27)` |
| S-F8 | LOW | E3 bundles A1 observation + A2 conclusion under A1 | **RESOLVE** | Split E3 → A1 (no `Microsoft.Web/sites`) + A2 (therefore OpenShift) |

## El-Demoledor (break the diagnosis + fix)

| # | Sev | Finding | Disposition | Change |
|---|-----|---------|-------------|--------|
| E-F1 | **BLOCKING** | `how-to-fix.md` (all deferred dangerous steps) did not exist | **RESOLVE** | Wrote `how-to-fix.md` with byte-check, proxy discriminator, admin-branch, enumerate-all-writers, per-pod verify, ID-only token inspection, verified firewall cleanup |
| E-F2 | HIGH | Verification variant-blind (b2b/b2c share `cloud_RoleName`) → false-close | **RESOLVE** | rca L9 + explanation §4 + how-to-fix Step 5 now verify **per pod** (`cloud_RoleInstance`) + require an observed write |
| E-F3 | HIGH | No branch for "admin token also orphaned" (the leading hypothesis implies it) | **RESOLVE** | rca L8 step 1 + how-to-fix Step 1 add the admin-**password** fallback + treat admin-401 as re-init confirmation → HALT path |
| E-F4 | MED | 401 could be a proxy/service-mesh, not InfluxDB | **RESOLVE** | rca L3 + confidence + E9b + how-to-fix Step 0b add the origin discriminator |
| E-F5 | MED | "no exception" false-passes on an empty-data write window | **RESOLVE** | Verification requires an **observed write** (fresh point in bucket), not just absence of error |
| E-F6 | MED | `influx auth list` prints token strings to scrollback | **RESOLVE** | how-to-fix Step 1 uses ID/scope + `jq`, never the token column |
| E-F7 | MED | Firewall-cleanup step easily skipped → security drift | **RESOLVE** | how-to-fix Step 6 makes IP removal a **verified** step (re-query ipRules) |
| E-F8 | MED | Roll-list hardcoded b2b+b2c; revoke could break an un-enumerated writer | **RESOLVE** | L8 + how-to-fix Step 2 enumerate ALL consumers of `influxdb-api-token` before roll/revoke |
| E-F9 | LOW | "tokens don't expire" A1 overstates for this instance | **RESOLVE** | E8b now A2 (this instance) / vendor-doc |
| E-F10 | LOW | L11 repro query differs from the working E1 query → could false-zero | **RESOLVE** | L11 note: `outerMessage has 'InfluxDb'` is the matching clause; zero rows ⇒ recheck filter before concluding recovery |
| E-F11 | LOW | "monitoring-only, low severity" assumes no automated consumer | **RESOLVE** | L1 caveat + how-to-fix boundary: confirm nothing non-human reads the bucket |
| E-note | — | "reviewed by 4 reviewers" overstated fix coverage (they reviewed explanation.md, fix runbook didn't exist) | **RESOLVE** | Fix package is now reviewed by el-demoledor (shape) + the runbook exists; explanation header already scopes the 4 reviewers to "an earlier draft"; how-to-fix carries `review_status: awaiting-independent-challenge` |

## Gate compliance
- Rebut count: 0. Systematic-defer: not triggered (all RESOLVE; the earlier explanation.md DEFER-to-runbook items are now closed by the runbook existing).
- Diagnosis survived both frames; fix package's BLOCKING closed. rca.md → `status: complete, adversarial_review: external`. how-to-fix.md → `review_status: awaiting-independent-challenge` (fix SHAPE reviewed; runbook TEXT awaits a fresh-frame pass).
