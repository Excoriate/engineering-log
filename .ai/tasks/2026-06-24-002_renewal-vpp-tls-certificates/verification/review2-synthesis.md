---
title: Cross-artifact review #2 synthesis + receipts (alignment / reliability / consolidation)
task_id: 2026-06-24-002
agent: claude-opus-4-8
status: complete
summary: simplicity-maniac + linus-torvalds + sre-maniac reviewed the full artifact set. Coherence VERIFIED clean. One systemic HIGH (probe failure-masking) + rollback/false-tail/manual gaps fixed. Consolidated to a SINGLE Go orchestrator (Python deprecated/deleted) per the simplicity finding + user decision. All Go-only deliverables re-validated.
timestamp: 2026-06-24T00:00:00Z
---

# Review #2 Synthesis — Alignment, Reliability, Consolidation

Three typed reviewers attacked the set (spec.md/.html, explainer.md/.html, rotate_tls.go, rotate_tls.py). Output INFER until source-verified by the coordinator (done via gofmt/vet/build/dry-run/grep + MS-doc cross-check from review #1).

## What was VERIFIED clean (the thing the user feared — divergence)

- **Command equivalence** (linus F4): every step's `az` invocation matched Go == Python == spec Manual. After consolidation, Go is the single source; the spec declares "dry-run output wins."
- **Resource-name correctness** (linus F5): sub/RG/KV/OBJ/AGW/SSL/VLESS byte-correct; KV-object vs AGW-ssl-cert never confused.
- **Coherence axes** (sre C-1/C-2): dates (Dec 30 / Jul 1 / Jun 27), 4 host list, force-refresh toggle, no empty `update` — all agree across artifacts.
- **`defer`/`finally` cleanup** (linus F3): runs on every path, preserves the real error.

## Receipts (findings → resolution)

| ID | Sev | Finding | Class | Resolution (evidence) |
|----|-----|---------|-------|-----------------------|
| linus-F1 / sre-R1 | **HIGH** | EXECUTE-mode empty `az` read coerced to the expected value → probes pass spuriously (~7 sites) | **RESOLVE** | Added `azRead` (empty-in-execute = failure) + propagate all `az` errors + deleted every empty→want coercion. `go vet` clean; dry-run still EXEC=0. |
| sre-R4 | MED/HIGH | Rollback never re-checked OLD version is still enabled before repointing AGW → listener auto-disable | **RESOLVE** | Rollback now re-probes `attributes.enabled==true` for the OLD version (live) before repoint, in `rotate_tls.go` and the manual spec; aborts + escalates if not. |
| sre-R3 | MED | `run` printed "Sequence OK" though verify-effect proves nothing | **RESOLVE** | Tail now: "Control-plane sequence OK. NOT YET VERIFIED … UNVERIFIED until all 4 hosts serve Dec 30 2026 + new thumbprint." |
| sre-R6 | LOW | Failed versionless-restore returned before its probe → silent drift | **RESOLVE** | Restore failure now logs a loud "AGW left on versioned URI — restore manually" before propagating. |
| sre-R2 | MED(doc) | Manual mode firewall cleanup depends on operator memory | **RESOLVE** | Manual intro now points to the idempotent self-probing `./rotate_tls -step whitelist-off -execute` as the cleanup. |
| sre-R5 | LOW(doc) | Per-step `-execute` has no auto-cleanup | **RESOLVE** | Spec + Go log both warn: single-step has no defer; finish with `-step whitelist-off`. |
| sre-FP1 | INFO | Manual verify-effect thumbprint format (upper:colon) vs script (lower-nocolon) | **RESOLVE** | Manual Step 7 now shows a normalized comparison (`sed`/`tr`) == `$NEW_THUMB`. |
| simplicity-Q1/Q4 | (arch) | Go + Python + manual prose = 3 hand-maintained command sources → drift hazard | **RESOLVE** | Python **deprecated & deleted** (user decision); Go is canonical; manual commands declared "what the dry-run prints — dry-run wins." Single source of truth. |
| simplicity-Q3 | LOW | `/tmp/vpp-rot-state.json` cross-invocation mutable state | **DEFER** | Bounded: `run` uses in-process state; rollback re-probes live (R-4). Condition to revisit: for multi-day step-by-step, re-run `baseline` before `rollback` so `old_sid` is fresh. |
| linus-F3/F4/F5, simplicity-Q2/Q5 | — | defer correct; equivalence/resource-names correct; step decomposition + versioned-toggle essential | **REBUT/KEEP** | Verified correct; no change. |

## Consolidation outcome

- **Single orchestrator: `rotate_tls.go`** (Go CLI). Python removed.
- Modes: **Scripted** (`rotate_tls.go`, dry-run default, probe-gated, guaranteed cleanup) and **Manual** (operator runs the `az` commands by hand, each with its probe).
- Final validation (Go-only): `gofmt` clean · `go vet` clean · `go build` OK · dry-run EXEC=0, 13 probes · Feynman validator PASS · zero residual Python references · spec HTML regenerated from md.

## Gate status

- All HIGH findings RESOLVED with code/doc changes + re-validation. 1 LOW DEFER (state file) with a named revisit condition. No systematic deferral. Set is aligned, complete, and reliable for GO/NO-GO.
