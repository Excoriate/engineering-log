---
title: Runbook + docs QA receipts — 3 review rounds (13 OMP reviewers) + fixes
type: review
status: complete
timestamp: 2026-07-21T20:20:00Z
task_id: 2026-07-21-004
agent: claude-opus-4-8
summary: Disposition of the final QA round (Q1–Q4 scored reviews) on how-to-fix.md v4 + explanation.md + rca.md; genuine defects fixed; residual scoped honestly.
---

# Runbook + docs QA receipts

Three adversarial rounds via Herdr/omp (GPT-5.6, cross-family), 13 reviewers total:
- **Round 1** (5): explanation.md — folded in (`review-receipts.md`).
- **RCA gate** (2): socrates + el-demoledor on rca.md — folded in (`rca-review-receipts.md`).
- **Runbook R2** (5): self-contained/ambiguity/command/safety/completeness on the one-shot rewrite.
- **Final QA** (4, scored): Q1 execution **42/100**, Q2 safety **68/100**, Q3 explanation-Feynman **61/100**, Q4 rca-holistic **70/100**.

## Genuine defects fixed (all rounds)

| Finding | Where | Disposition |
|---------|-------|-------------|
| **401 semantics ERROR** — on the InfluxDB 2.x *write* endpoint, 401 also covers a valid token lacking write permission (403 is NOT used for write-scope) → "401 rules out mis-scope" was **wrong** | explanation §1.4/H1/H4/ledger/self-test; rca E8b; how-to-fix §5b | **RESOLVE** — corrected in all 3 docs; H4 (mis-scope) re-ranked Medium; cited [write-data API](https://docs.influxdata.com/influxdb/v2/api/write-data/) |
| Broken evidence links (5 `../`, need 6) | explanation header ×2; rca L14 | **RESOLVE** — fixed; verified resolve |
| `rca status: complete` too strong (branch-selecting evidence is A3) | rca frontmatter | **RESOLVE** — → `status: review` |
| C1 auth-hash loop aborts under `errexit` on no-match (verified) | how-to-fix §5c | **RESOLVE** — `if…then…fi` + `|| true` |
| §5c-pw password pipeline discards the secret (verified runtime-attack in manifest) | how-to-fix §5c-pw | **RESOLVE** — `… | tr -d '\n' | clip.exe` (Windows clipboard) + `/health` liveness |
| `influx_exec`/port-forward/proof-write bypass `ocx` (wrong-cluster risk) | how-to-fix §0/§5c-pw/§6A | **RESOLVE** — all routed through `ocx` |
| Branch B leaves `NEW_KV_HASH` undefined under `set -u` | how-to-fix §6B | **RESOLVE** — sets `NEW_KV_HASH="$KV_HASH"`, rollout-only |
| `set +x` missing; `NEWF` temp not trapped; §8 empty-pod silent skip; WRITERS trio not asserted | how-to-fix §0/§4/§8 | **RESOLVE** — all added |
| Explanation intro-before-diagram, coverage note, Knowledge-Contract-adjacent, diagram intros; rca L6 lacked a credential-chain diagram | explanation/rca | **RESOLVE** — added |

## Honest residual (NOT claimed as 100/100)

The final QA scores are not 100. The remaining deductions fall in three buckets, disclosed rather than hidden:

1. **Asymptotic for an untestable live system.** Per-writer *attribution* of a bucket write (both b2b/b2c share `cloud_RoleName` and the measurement) has no clean solution without a cluster-side writer tag I cannot confirm from a laptop; the runbook uses the best available signal (per-pod `cloud_RoleInstance` invocations>0 + unauthorized==0 + fresh non-probe point) and marks empty results UNKNOWN. Full multi-writer transactional rollback and non-Deployment (CronJob/StatefulSet) writers are flagged for operator handling, not fully automated.
2. **Operator-reframe scoping.** The executor is a **human operator on the AVD applying judgment at branches** (the user confirmed), so several "a literal autonomous agent fails-open here" deductions are handled by operator judgment + explicit STOP gates rather than machine-enforced predicates.
3. **Convention conflict.** explanation.md keeps inline `A1/A2/A3` evidence labels (required by the repo's `on-call-incident-workflow.md`), which the how-to-feynman validator's no-codes-in-prose rule flags; the on-call RCA convention wins for an incident doc.

**Net:** the substantive diagnosis is sound and cross-doc-consistent; the runbook's command bugs are fixed (13/13 fences pass `bash -n`) and it is a solid human-operator runbook. A literal 100/100 autonomous-agent runbook would need live-cluster access to close the attribution/rollback items — named here, not papered over.
