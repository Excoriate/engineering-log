---
title: "Adversarial receipts synthesis — gurobi cosmos RU RCA"
description: "Per-finding disposition (RESOLVE/REBUT/DEFER) for the 4-reviewer adversarial pass"
timestamp: 2026-06-15T17:45:00Z
status: complete
agent: coordinator
summary: >-
  19 findings across sherlock/sre/el-demoledor/socrates. 15 RESOLVE (edits + 4 confirmatory live
  probes E11-E14), 1 REBUT (how-to exists — race-condition false positive), 3 DEFER (solve-success
  -> T0 gate; prod live throughput; HTML -> task #7 in progress). The probes flipped the headline
  from "34.5% severe throttle" to "2.82% HTTP-429, within Microsoft's healthy band."
task_id: 2026-06-15-001
---

# Adversarial Receipts — Disposition

Quality bar: **RESOLVE** = edit/probe cited · **REBUT** = file:line/output/constraint · **DEFER** = risk + revisit condition. No finding overturned the root cause (RU-ceiling saturation of fs.chunks); all were precision/calibration/labeling — exactly what an A1 RCA must pass.

## sherlock-holmes (causal chain)

| # | Finding | Disposition | Evidence |
|---|---------|-------------|----------|
| F1 | fs.chunks-as-saturator was unrecorded (INFER-as-A1) | **RESOLVE** | Captured per-collection PT1M split (E11): fs.chunks 100% vs next `objects` 16% → now A1; rca L3/L8 relabeled. |
| F2 | "not a regression" only ruled out config-writes | **RESOLVE** | rca L8 reworded → "not a *config* regression (A1 E9); *workload-growth* not excluded — Jun 77.67% vs Mar ≈39% (A2)." |
| F3 | 34.5% is retry-inflated | **RESOLVE** | Captured TotalRequests total (E13) → true HTTP-429 rate **2.82%**; 16500 relabeled retry-inflated (A1 MS Learn); rca L7/L10. |
| F4 | Verified vs Hypothesis Set | **RESOLVE** | rca L8 scoped: saturation class Verified (depth 2-3); fs.chunks attribution now A1 via E11 (no longer hypothesis). |

## sre-maniac (operational + fix)

| # | Finding | Disposition | Evidence |
|---|---------|-------------|----------|
| F1 | "degraded not broken" oversold on A3 | **RESOLVE** | rca L8 + fix T0: headline now "minor/degraded, within healthy band; **not closeable until T0** solve-success"; T0 = hard gate. |
| F2 | single-partition makes 4000 unusable = WRONG | **RESOLVE (accept correction)** | fix T1a corrected: single partition serves ≤10k RU/s (instantMax 10000), 4000 needs no shard. |
| F3 | 4000 unsized; demand never measured | **RESOLVE** | Captured TotalRequestUnits (E12, ~3,292 RU/min peak); fix T1a sizes from demand, adds ">8k → T3" branch. |
| F4 | no upstream concurrency cap (backpressure) | **RESOLVE** | fix T2.5 added: RU raise w/o concurrency cap only moves the wall. |
| F5 | 429 threshold 500 ≈ tolerated burst → flapping | **RESOLVE** | fix T2: 429 page = **rate >5%**, per-env backtest, keep RU Sev2 until proven (today's 2.82% would not fire). |
| F6 | cost of 4× | **REBUT (sound as-is)** | Autoscale bills 0.1×max floor + actual; bounded; fix already guards blanket-raise. Noted idle-floor delta. |

## el-demoledor (break claims)

| # | Finding | Disposition | Evidence |
|---|---------|-------------|----------|
| C1 | "fs.chunks is GridFS" | **REBUT (HOLDS)** | `{files_id,n}` index = GridFS signature (E3); inference safe. No edit. |
| C2 | "unsharded ⇒ single partition" stated absolute | **RESOLVE** | rca L3 scoped: "single physical partition **at current ~5 GB size**" (E14 = 5.1 GB < 50 GB split threshold). |
| C3 | "Max≡Avg ⇒ one series" over-stated | **RESOLVE** | Demoted to corroborating; identification rests on per-collection split (A1 E11). |
| C4 | "byte-for-byte" literally false | **RESOLVE** | rca L5 → "semantically identical, no drift" (ARM `evalFreq`/`timeAggregation` ≠ HCL keys). |
| C5.0.1 | stale alert description ("5 min" vs PT15M) | **RESOLVE** | rca L5 flag + fix T2 rewrites the description. |
| C5.0.2 | removed 429 alert would have fired (586 ≈29× thr 20) | **RESOLVE** | rca L7 added — with the count-vs-rate tension (fires by count, healthy by rate). |
| C5.0.3 | fix 429 threshold 500 not derived | **RESOLVE** | fix T2 now rate-based + derivation; 500-count rejected. |
| C5-L6 | "429>5%, both hold" overstated | **RESOLVE** | Corrected: 429 rate 2.82% is **within** 1-5% healthy → >5% trigger NOT met; T1 justified by noise+headroom, demoted to secondary. |
| label leaks L1-L5 | A1/A2 conflations | **RESOLVE** | labels split (single-partition A2, Max≡Avg corroborating, etc.). |

## socrates-contrarian (assumptions + goal fidelity)

| # | Finding | Disposition | Evidence |
|---|---------|-------------|----------|
| G1 | HTML versions missing | **DEFER → IN PROGRESS** | Task #7; `frontend-magician` dispatched this session to render rca.html + how-to.html (dark-mode). Revisit on completion. |
| G2 | how-to-feynman missing | **REBUT** | False positive — `outcome/how-to-feynman.md` exists (socrates' `find` raced the write, which happened in the same dispatch batch). Now present + updated to the 2.82% framing. |
| G3 | fix spec followable | **REBUT (MET)** | fix.md T0-T3 with commands/IaC/acceptance/rollback. |
| G4 | "no unverified claim" — "mis-tuned" overstated | **RESOLVE** | "mis-tuned" → A2 judgment + steelman (rca L6); residual A3s (solve-success, prod throughput) explicitly labeled. |
| G5 | broken-vs-degraded answered? | **RESOLVE + DEFER** | Answered: minor/degraded, 2.82% healthy band (rca L8). Solve-success **DEFER → T0** (job-history read). |
| A1 | "mis-tuned" unfair to a deliberate design | **RESOLVE** | rca L6 steelman + fix T2 recast as "add a 429-rate signal tuned ABOVE the routine micro-burst floor (locals.tf:29-30)", not "undo their change." |
| A2 | acc→prod early-warning | **RESOLVE** | rca L1 + fix "Production caveat": prod live throughput unverified; verify before assuming same ceiling. |
| A3 | T3 Blob feasibility unfounded | **RESOLVE** | fix T3 demoted to "feasibility-BLOCKED (A3) candidate"; third-party Gurobi app; resolving path named. |

## Residual A3 (carried, not closed)

- **Solve-success during the burst** → T0 (Gurobi job history) — gates incident closure.
- **Prod `-p` live throughput / 429 rate** → verify before applying acc conclusions to prod.
- **HTML deliverables** → task #7, frontend-magician in progress.

No systematic Defer (3/19 ≈ 16%), no Rebut-without-evidence. Gate clear to finalize once HTML lands + T0 owner assigned.
