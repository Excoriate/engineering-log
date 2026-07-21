---
title: Adversarial review receipts — explanation.md (x4 omp/Herdr)
type: review
status: complete
timestamp: 2026-07-21T14:20:00Z
task_id: 2026-07-21-004
agent: claude-opus-4-8
summary: Disposition of the 4 cross-family (GPT-5.6/omp) adversarial reviews of explanation.md; RESOLVE applied to explanation.md, DEFER routed to the how-to-fix runbook.
---

# Adversarial review receipts — `explanation.md`

**Fleet:** 4× `omp` (default model GPT-5.6, cross-family from Opus author) via Herdr, one tab each, `--no-pty --auto-approve --max-time 10m`, prompts + outputs as files under this task workspace. All 4 reached `done`; outputs in `../subagent-outputs/`.

Disposition bar: **RESOLVE** = fix applied (cite change) · **REBUT** = evidence it's wrong · **DEFER** = valid but routed elsewhere (with condition).

| # | Reviewer | Finding (sev) | Disposition | Action |
|---|----------|---------------|-------------|--------|
| 1 | R1/R2/R3 | 401 over-read as "token unknown"; A2 mechanism stated as fact in summary/Part4/self-test (HIGH/BLOCKING) | **RESOLVE** | Reworded Part 0, 1.4, 3.4, Part 4 opening, self-test to "rejected authentication → leading A2 hypothesis"; added malformed/wrong-injection/inactivated alternatives |
| 2 | R3/R4 | No credential byte-parity discriminator before rotation; KV non-empty ≠ byte-correct at pod (BLOCKING) | **RESOLVE** + **DEFER** | Added §3.4 "check the credential chain first (length+hash, no value)"; full procedure → how-to-fix doc |
| 3 | R4 | "update KV + restart" assumes KV→k8s propagated; restart can reload old token (BLOCKING) | **RESOLVE** + **DEFER** | Part 4 now gates restart on proven k8s-Secret change; mechanism steps → how-to-fix doc |
| 4 | R4 | "repair org/bucket if lost" collapses token-mint (reversible) with stateful recovery (BLOCKING) | **RESOLVE** | Part 4 step 2 → org/bucket absent = HALT + escalate; do not recreate |
| 5 | R3/R4 | Blast radius not operationalized (b2b/b2c, other writers of the shared secret) (HIGH) | **RESOLVE** | Added §3.6 blast-radius matrix; corrected "step 1 resolves all three" |
| 6 | R3/R2 | Onset ">1 month" filer-only; "static cred → server-side change" too deductive (HIGH) | **RESOLVE** | Added timeline-confidence note + "last successful write" as the resolving probe; softened wording |
| 7 | R3 | No ranked competing-hypothesis table (HIGH/MEDIUM) | **RESOLVE** | Added §3.5 hypothesis table with rank + discriminating probe |
| 8 | R1 | Line-protocol example has spaces around commas → invalid wire payload (MEDIUM) | **RESOLVE** | Fixed to valid line protocol; labeled the aligned form "conceptual" |
| 9 | R1/R2 | "Grafana unaffected" too strong; dashboards ARE affected by missing writes (MEDIUM) | **RESOLVE** | Softened; added Grafana read-path to blast-radius checks |
| 10 | R1 | "Every API call must carry a token" false (health/readiness) (LOW) | **RESOLVE** | Reworded to "every protected call, incl. /api/v2/write" |
| 11 | R2 | Kafka topic `asset-strikeprices-1` in diagram not in evidence ledger (MEDIUM) | **RESOLVE** | Added the topic to evidence ledger E8 (it IS in the real values.yaml); kept |
| 12 | R2 | Rec0BGG7SPERE "datatype mismatch" detail beyond ledger (MEDIUM) | **RESOLVE (partial)** | It IS sourced from the intake requirements.md; tightened hedge + cited source; kept as A2 link |
| 13 | R3/R4 | No credential-role/least-privilege table (writer/admin/grafana) (MEDIUM) | **RESOLVE** | Added credential-role table + create-before-revoke rule |
| 14 | R3 | No glossary of VPPAL/MC/AVD/CMC/oc/KV/RG/b2b-b2c (LOW) | **RESOLVE** | Added glossary after Part 0 |
| 15 | R3 | No "first-10-min" handover / "you still need" / link to runbook (HIGH) | **DEFER** | The runbook IS the how-to-fix deliverable (task 6); added forward link + "you still need" list in Part 4 |
| 16 | R4/R3 | Verification can false-pass (timer didn't run / manual 204 / Grafana from another writer) (HIGH) | **RESOLVE** + **DEFER** | Tightened Part 4 step 5 (per-variant post-rollout scheduled write); full gate → how-to-fix doc |

**Coordinator note (H-OM-8):** worker outputs were not laundered as fact — each finding was checked against the verified evidence ledger before acceptance. No finding was REBUTTED; findings #2,#3,#16 are split RESOLVE-in-explanation / DEFER-to-runbook because the operational depth belongs in the how-to-fix doc. Systematic-defer and rebut-without-evidence gates: not triggered (0 rebuts, 1 pure defer).
