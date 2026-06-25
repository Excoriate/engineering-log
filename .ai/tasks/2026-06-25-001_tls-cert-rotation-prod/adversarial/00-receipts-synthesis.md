---
title: Adversarial synthesis + receipts — MANUAL-mode PROD TLS rotation (el-demoledor + socrates + kant)
task_id: 2026-06-25-001
agent: claude-opus-4-8 (coordinator)
status: complete
timestamp: 2026-06-25
summary: Three typed reviewers converged on ONE generator — the spec was authored for a single continuous shell but the agent executes one step per fresh Bash call, so cross-step shell vars evaporate, turning several probes into false-PASS gates (worst: Step 8 reports firewall closed while it stays open). All BLOCKING/HIGH RESOLVED in manual-execution-runbook.md (state file + :? guards + pre-mutation re-verifies + enumerate-remove Step 8 + STOP-through-8 invariant + all-four verify). Verdict: GO-ready (manual, hardened).
---

# Adversarial Synthesis — Receipts

Source-verification note: each finding below was checked against the actual spec text (`rotation-execution-spec.md`, read in full) and against locally-probed FACTS (placeholder paths non-resolving; PW=13 bytes w/ trailing `\n`; `/usr/bin/openssl`=LibreSSL lacks `-legacy`; brew openssl fingerprint == `b8202de2…`). Reviewer output was INFER until this check. No reviewer ran `az` against prod (`/tmp/mc-production.env` mtime unchanged).

## The single generator (all three agreed)

**Authoring-model vs execution-model mismatch:** spec assumes one terminal; agent runs one fresh shell per step → every later step that consumes a `$VAR` set earlier reads EMPTY. Symptoms: el-demoledor M-01/M-02/M-04, socrates C1/H1, kant F1/F3/F6. **Fixing the state model + adding `:?` guards collapses ~9 findings at once.**

## Receipts

| ID (reviewer) | Sev | Finding | Class | Resolution (in runbook) |
|---|---|---|---|---|
| M-01 / C1 / F1 | BLOCKING | Shell vars evaporate between steps → wrong-target mutations + false-PASS probes | **RESOLVE** | State file `/tmp/azsp-prd/rotate.env`; every step `source`s it + `:?` guards; new values appended as computed |
| M-02 | BLOCKING | `AZURE_CONFIG_DIR` not re-exported → wrong/personal identity; probe checks only sub id | **RESOLVE** | `AZURE_CONFIG_DIR` is line 1 of state file; Step 0 probe asserts `user.type==servicePrincipal`, not just sub |
| M-03 | BLOCKING | Placeholder `.../` paths; PC2 passes by silence | **RESOLVE** | Absolute PFX/PW paths baked into state file; PC fails loud on missing |
| M-04 / H1 | HIGH | Step 8 removes `"/32"` (empty MYIP) → probe prints `0`=clean while real rule stays open | **RESOLVE** | Step 0 captures fw baseline; Step 8 enumerates real ipRules, removes non-baseline, asserts count==baseline, empty=FAIL |
| H2 | HIGH | "SP still has Import right TODAY" inherited, detected only by blast at Step 3 | **RESOLVE** | Step 0 pre-mutation read-only assert: SP objectId cert perms include `Import` |
| H3 | HIGH | "AGW still on versionless URI / not already rotated" inherited; drift since 06-24 unchecked | **RESOLVE** | Step 0 asserts live `keyVaultSecretId == $VLESS` before any mutation; Step 2 asserts OLD expiry ~Jul 1 and OLD_THUMB != new (catches "already rotated") |
| H4 | MED | Firewall baseline not captured → can't prove return-to-baseline | **RESOLVE** | Step 0 writes `kv-fw-baseline.txt`; Step 8 asserts against it |
| M-05 | HIGH | `ifconfig.me` egress ≠ KV data-plane source IP → 403 stall | **RESOLVE (bounded)** | Run all steps from same network; egress re-check guard on any 403; single-operator home egress = low risk |
| M-06 / F6 | HIGH | bare `openssl -legacy` → LibreSSL "unknown option" → empty EXPECT → gate misfire | **RESOLVE** | Absolute `/opt/homebrew/bin/openssl` everywhere; empty-EXPECT = STOP |
| M-07 | MED | password `file:` vs `$(cat)` newline handling differ | **RESOLVE (minor)** | One mechanism; PW is 12 chars no newline (verified) |
| M-08 / F2 | MED/HIGH | `--disabled` honor; versionless-restore race; control-plane != served | **RESOLVE** | Step 3 self-heals disabled; Step 6 asserts `CUR==VLESS` (loop if not); "done" locked to wire handshake |
| M-09 / F2 | MED/HIGH | `provisioningState=Succeeded` read as "served" | **RESOLVE** | INV-3: completion only on AVD wire handshake; interim proxies labelled `[UNVERIFIED[blocked]]`, never "done" |
| F3 | HIGH | object name vs ssl-cert resource name swap | **RESOLVE** | INV-5 + Step 6 name-binding assertion before mutate |
| F4 | HIGH | single-host / pre-AVD declared done | **RESOLVE** | Step 7 enumerates ALL FOUR hosts with normalize inside the loop |
| F5 / G5 | BLOCKING | `STOP` branch abandons run → KV firewall left open | **RESOLVE** | INV-2: STOP = "STOP-FORWARD-THROUGH-STEP-8"; standing firewall invariant re-asserted each step |
| F7 / G7 | MED | rollback vs retry ambiguity can burn schedule margin | **RESOLVE** | Bounded 2-cycle retry + clock discriminator (today<Jun29 → rollback; else fix-forward) |
| M1 (socrates) | INFO | AVD handshake sufficiency for like-for-like | **REBUT/KEEP** | Spec already correct; AVD = necessary+sufficient; control-plane only = interim w/ named residual |
| M2 (socrates) | MED | Step 4 trusts import-response thumbprint | **RESOLVE** | Step 4 re-reads thumbprint from vault BY VERSION; triple-equality gate (PFX==vault==expected) |
| M3 (socrates) | MED | Step 6 "expect a URI" is eyeball-only | **RESOLVE** | Machine equality assertion `CUR==VLESS` |

## Deferred (bounded, non-blocking — unchanged from 2026-06-24)

| Item | Why not blocking |
|---|---|
| Cross-subscription (Sandbox/iactest) sweep | Prod rotation is self-contained; bounds only org-wide completeness claim. Optional post-run. |
| Password in `ps` argv | Single-operator laptop; accepted per prior review. |

## Gate checks
- Systematic-Defer: 2 DEFER of ~21, both bounded low-risk, none on BLOCKING/HIGH → PASS.
- Rebut-without-evidence: 1 REBUT (M1), backed by spec text + like-for-like reasoning → PASS.
- All BLOCKING (M-01/M-02/M-03, F5/G5, C1, F1, F2/G2) RESOLVED with concrete runbook changes.
- Reviewers preferred the scripted orchestrator `rotate_tls.go`; **user explicitly chose MANUAL** — honored, with hardening that makes the manual path equivalently safe (state file = the orchestrator's in-process state, externalized).

**Verdict: GO-ready for manual step-by-step execution using `manual-execution-runbook.md`, pending Alex's per-step OK.**
