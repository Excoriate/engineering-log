---
title: SRE adversarial review #2 — reliability & coherence lane (PROD VPP TLS rotation)
task_id: 2026-06-24-002
agent: sre-maniac
status: complete
timestamp: 2026-06-24T00:00:00Z
summary: |
  Reliability & coherence attack on the 4-artifact set (spec + explainer + rotate_tls.go +
  rotate_tls.py). Win condition: outage / false-success / dangling firewall / operator-runtime
  divergence. Dates, host lists, and force-refresh toggle are COHERENT across all three sources
  (VERIFIED). The dominant open defect is a PROBE-SPOOFING pattern shared by both scripts: in
  EXECUTE mode many probes coerce an empty `az` result to the EXPECTED value (`or "true"`,
  `or "Succeeded"`, `or old_sid`, `latest = want`), so a silently-failed read PASSES the gate —
  a false "success" on a production cert change. Second defect: MANUAL mode has no finally and a
  rollback path that does not re-assert an enabled+resolvable version, so a late manual rollback
  can leave AGW pointed at a version it cannot serve = listener auto-disable = outage.
---

# SRE Adversarial Review #2 — Reliability & Coherence

## Key Findings

- probe_spoof: EXECUTE-mode empty-result-to-expected coercion makes several probes pass spuriously (both scripts)
- manual_finally_gap: manual Mode B has no guaranteed whitelist-off; operator is the only finally
- rollback_resolvable: neither rollback path PROBES that the OLD version is still enabled before repointing AGW
- coherence_pass: dates (Dec30/Jul1/Jun27), 4 host lists, force-refresh toggle agree across spec+explainer+go+py
- refresh_no_served_probe: step 6 proves provisioningState+versionless-restore, not that the cert actually re-pulled

Lane: does the artifact SET produce an outage, an unverified "success", a dangling firewall
rule, or a divergence between what the operator reads and what runs?

All conclusions below are INFER until source-verified by the coordinator. Evidence is
file:line + quote. Local probes run: `go vet` (exit 0), `python3 -m py_compile` (exit 0),
cross-file `grep` of dates / hosts / toggle (captured inline).

Scope honored: READ-ONLY. No Azure mutation. No script executed against Azure.

---

## VERDICT: FIX FIRST

Two coherence axes are clean (dates, host lists, force-refresh toggle — see §1). The blocker is
a **probe-determinism class defect** that defeats the entire "every step is probe-gated" safety
claim in EXECUTE mode (§3, R-1), plus a **manual-mode cleanup + rollback gap** (§2/§4, R-2/R-4).
None of these are visible in dry-run, which is exactly why they are dangerous: the dry-run that
the operator reviews before GO looks correct; the execute-mode behavior diverges.

---

## 1. Manual == Scripted == Explainer (coherence)  — VERIFIED (mostly clean)

Cross-checked every host, expiry date, force-refresh mechanism, and the AGW/KV two-name pair.

| Axis | Manual (spec) | Go | Python | Explainer | Verdict |
|------|--------------|----|--------|-----------|---------|
| New cert expiry | `Dec 30 ... 2026` (spec:52,258) | `Dec 30` (go:54) | `Dec 30` (py:66) | `Dec 30 2026` (md:48,164,198) | **MATCH** |
| Old cert expiry | `2026-07-01` (spec:26,34) | `2026-07-01` (go:262) | `2026-07-01` (py:197) | `Jul 1 2026` (md:32,76,163) | **MATCH** |
| Exec deadline | `2026-06-27` (spec:34,57) | `2026-06-27` (go:262) | `2026-06-27` (py:197) | "days of margin" (md:225) | **MATCH** |
| 4 hosts | agg/gurobi/apollo/flex-trade (spec:24,253) | go:58-59 | py:64-65 | md:24-ref,166-169 | **MATCH (exact, all 4, same order)** |
| KV obj vs AGW ssl-cert | `wildcard-vpp-eneco-com` vs `wildcard-vpp-frontend-https` (spec:21-23) | go:41,43 | py:50,52 | md:62,175 | **MATCH** |
| Force = versioned→versionless toggle | spec:231-232 | go:396-402 | py:287-291 | md:121,201,215 | **MATCH** |
| Subscription | `f007df01…` (spec:19,102) | go:38 | py:47 | — | **MATCH** |

**VERIFIED**: no host/date/thumbprint-rule/command divergence across the three executable
sources and the explainer. The two-name trap (KV object ≠ AGW ssl-cert resource) is stated
identically everywhere. This axis is clean.

One residual ESTIMATED note (not a defect, flag for operator): the manual verify-effect probe
(spec:258) expects the SHA1 fingerprint **"upper-case, with colons"** (raw `openssl x509
-fingerprint` format), whereas the scripts normalize to **lower-case, no colons** (go:217,
py:164). The operator doing a manual cross-check between a script's `new_thumb` and the manual
handshake output must normalize by eye. Cosmetic, but it is a place a tired 3 AM operator
declares MISMATCH on a real match (or vice-versa). Conditional fix: state both forms in spec:258.

---

## 2. Cleanup guarantee (dangling firewall)

### Scripted: VERIFIED correct on every failure path.
- Go: `runAll` arms `defer stepWhitelistOff()` (go:505-509) **after** preflight and **before**
  whitelist-on, so any error return from whitelist-on … verify-effect triggers cleanup. The
  defer also folds its own error into the return (go:506-508). Correct.
- Python: `try/finally` wraps the whole body (py:366-376), `step_whitelist_off()` in `finally`.
  Correct.
- `whitelist-off` itself uses an ignore-failure remove (`azAllow` go:453 / `allow_fail=True`
  py:332) **then re-probes** the residual count and **loud-fails** with a manual command if
  still open (go:456-459 / py:335-338). Good — the remove is idempotent and the probe is the
  real guarantee, not the remove's exit code.

### One scripted edge — OPEN (R-5, LOW): single-step execute has no finally.
Running `rotate_tls -step whitelist-on -execute` alone (spec:72 explicitly offers per-step
execution) adds the firewall rule with **no defer/finally** — only `runAll` arms cleanup
(go:505 / py:366). If the operator runs steps individually (the spec sanctions this) and walks
away after a failing `import`, the firewall stays open until they manually run `whitelist-off`.
- **Mechanism**: per-step invocation bypasses the `runAll` defer entirely.
- **Quote**: go:535-540 maps `"whitelist-on": stepWhitelistOn` as a standalone entry; no wrapper.
- **Conditional fix**: spec must state, in Mode A per-step block (spec:70-79), "per-step execute
  has NO automatic cleanup — you are the finally; always end with `-step whitelist-off`." The
  scripts already loud-fail on residual, so detection exists; the gap is operator expectation.

### Manual Mode B — OPEN (R-2, MEDIUM): operator is the ONLY finally.
The spec is explicit and honest about this (spec:40 "in manual mode *you* must run Step 8 even
on failure"; spec:91 "You are the `finally`"). That is a documented manual hazard, not a hidden
one. But it is still the single most likely real-world firewall-left-open path: an operator who
hits a MISMATCH at Step 4 (spec:201 says "go to Step 8 to clean up") under incident stress may
stop at the mismatch and not scroll to Step 8.
- **Conditional fix (cheap, high value)**: tell the manual operator to run the *scripted*
  `whitelist-off` step as their cleanup even in manual mode (`rotate_tls -step whitelist-off
  -execute`) — it is idempotent and self-probing, so it converts the "human remembers" finally
  into a one-liner with a built-in residual check. Strictly an improvement over a raw `az remove`.

---

## 3. Probe determinism — OPEN (R-1, HIGH): the dominant defect

The safety contract is "every mutating step ends with a deterministic PROBE that asserts the
expected value; a failed probe stops" (go:7-8, py:8-11). In **EXECUTE** mode this contract is
**partially defeated** by a recurring pattern: when an `az` read returns empty (transient API
error, throttling, a query that matched nothing), the code **coerces the empty result to the
EXPECTED value**, so `expect()` compares want==want and PASSES. An empty read is the single most
common az failure mode under load/throttling — and here it is laundered into success.

Concrete instances (EXECUTE mode; dry-run is unaffected because dry returns early at go:119 /
py:105):

| # | File:line | Coercion | Spurious-pass scenario |
|---|-----------|----------|------------------------|
| a | go:374-377 / py:274-276 | `en, _ := ...enabled...; if en=="" { en="true" }` then `expect("new version enabled","true")` | enable's read times out → empty → coerced to "true" → PROBE PASSES though we never confirmed enable. Cert may NOT be enabled; AGW later serves OLD / or has nothing to resolve. |
| b | go:384-386 / py:278-279 | `latest, _ := ...thumb...; if latest=="" { latest=want }` (`or st.get('new_thumb')`) | latest-enabled read fails → coerced to the new thumb → "versionless resolves to NEW" PASSES falsely. The vault side is declared done without proof. |
| c | go:406-409 / py:294-295 | `state,_ := ...provisioningState...; if state=="" { state="Succeeded" }` | AGW show fails → coerced to "Succeeded" → "AGW healthy" PASSES though gateway state is unknown (could be Failed → **listener auto-disabled = outage**, the exact failure the explainer md:254 names). |
| d | go:414-417 / py:298-299 | `kvsid,_ := ...; if kvsid=="" { kvsid=VLESS }` | ssl-cert show fails → coerced to versionless → "restored to versionless" PASSES; if the restore actually failed, AGW is left on the **versioned** URI → autorotation off + terraform drift undetected. |
| e | go:483-487 / py:353-354 (rollback) | `kvsid,_ := ...; if kvsid=="" { kvsid=oldSid }` then `expect(==oldSid)` | rollback's confirming read fails → coerced to oldSid → "ssl-cert points at OLD sid" PASSES though the repoint may not have applied. False rollback success during an incident. |
| f | go:294-306 / py:221-226 (baseline) | `sid or "<OLD_SID>"`, `enabled or "true"` | in EXECUTE, if the baseline read fails, `enabled` coerces to `"true"` and the "OLD version is enabled" probe PASSES — recording a rollback target we never confirmed is enabled (feeds R-4 below). |

**Mechanism (why it is HIGH, not cosmetic)**: these are not dry-run placeholders — the
`if x=="" { x=expected }` lines execute in EXECUTE mode (the dry early-return is *above* them at
go:119/py:105; these defaults are reached only when `dry==false` and the read returned empty).
The pattern was almost certainly written to keep dry-run output readable, but it leaks into the
real path. Result: a step that should HALT on an unreadable Azure response instead advances on a
fabricated value. On a production cert rotation, instance (c) is an outage-shaped false-pass
(declares AGW healthy when it may have disabled a listener), and (a)/(b) declare the vault
rotated when it may not be.

**Discriminating test (proves this is real, not theoretical)**: in EXECUTE mode, point `az` at a
throttled/erroring vault (or temporarily break creds after login) so a `show --query` returns
empty; instances a–f will print `PROBE … OK` instead of `PROBE FAILED`. A correct probe must
treat empty-when-a-value-was-required as FAIL.

**Conditional fix**: separate the dry-run placeholder from the execute-mode default. In execute
mode, an empty read on a required probe value must NOT be coerced to the expected value — it must
fail the probe:
```text
// instead of:  if en == "" { en = "true" }      // PASSES on empty
// do:          if !dry && en == "" { return fmt.Errorf("PROBE FAILED: enabled read empty") }
```
Apply to instances a–f (the `enabled`, `provisioningState`, `keyVaultSecretId`, `latest`, and
`sid`/`enabled` baseline reads). The thumbprint gate at verify-import (go:361 / py:263) is the
ONE probe that is correctly hard (it compares two independently-computed values with no empty
coercion of the held side) — that is the model the others should follow.

Note: `expect()` itself is correct (exact `==`, no `contains`, lower-cased on both sides for
thumbprints go:299/383 py:224/279). The defect is the **callers feeding it coerced values**, not
the comparator.

### 3b. verify-effect "best-effort" empty handling — OPEN (R-3, MEDIUM)
verify-effect (go:422-442 / py:304-323) is correctly NON-gating for the AVD handshake (it only
prints commands; the human runs them on AVD). But the inline public-`gurobi` best-effort check
treats an **empty** handshake as "unreachable - MUST verify from AVD" (go:433-434 / py:317) —
correct, it does NOT mask empty as success. Good. However this step `return nil` always
(go:441) / has no probe, so in `runAll` the sequence prints "Sequence OK" (go:517) / "Sequence
finished" (py:377) **regardless of whether any served-cert was confirmed**. The final log line is
a false-success generator: an operator skimming the tail sees "Sequence OK" and may treat the
rotation as proven when verify-effect proved nothing.
- **Quote**: go:516-518 prints "Sequence OK" unconditionally after the step loop; verify-effect
  contributes no gate.
- **Conditional fix**: change the closing line to "Control-plane sequence OK — NOT verified
  until an AVD handshake on all 4 hosts shows Dec 30 2026 + new thumbprint. Rotation is
  UNVERIFIED until then." The spec already says this (spec:259-262); the script's tail line
  contradicts it. This is an operator-reads-vs-runs divergence: spec says "az exit 0 is
  meaningless" (spec:250), script says "Sequence OK."

---

## 4. Rollback correctness & time-bound — OPEN (R-4, MEDIUM/HIGH depending on baseline)

### Time-bound: VERIFIED coherent.
"before Jul 1" / "fix-forward after" stated identically in spec:284-303, go:18/468/517, py:33/342,
md:225,255. The hard scheduling gate (≤Jun 27, post-Jun-29 fix-forward) is in spec:32-34 and
both scripts' preflight reminder (go:262/py:197). Coherent.

### Resolvable-enabled-version guarantee: OPEN (the real risk).
The synthesis (review-synthesis.md:18,31, SRE-R2/DEM-V5) claims rollback was redesigned to
"repoint AGW to the OLD versioned URI … sidesteps reliance on disable/resolution timing" and
that rollback "must always leave a resolvable+enabled version." Examining the actual rollback
code, **the OLD version's enabled-state is never re-probed at rollback time**:

- Rollback repoints AGW to `old_sid` (a **versioned** URI) and disables the new version
  (go:474-481 / py:347-350). Pointing at a versioned URI means AGW resolves THAT specific
  version — which works **only if that version is still enabled**.
- The baseline step recorded `old_enabled` (go:307 / py:227) and probed it ==true (go:314 /
  py:232) — BUT (i) per §3 instance (f) that baseline probe can spuriously pass on an empty
  read, and (ii) more importantly, **rollback never re-checks** that old_sid's version is still
  enabled at the moment of rollback. If, between baseline and rollback, the old version was
  disabled (e.g. a parallel operator, or a botched enable/disable), AGW gets repointed to a
  **versioned URI whose version is disabled** → AGW cannot fetch → **listener auto-disabled →
  outage** (the explainer's own failure mode, md:254; MS-doc-confirmed in synthesis:18).
- **Mechanism**: rollback trusts a baseline snapshot of `old_enabled` taken minutes-to-hours
  earlier and never revalidates the target is resolvable before pointing prod at it.
- **Quote**: go:472-477 reads `old_sid` from saved state and immediately `ssl-cert update
  --key-vault-secret-id oldSid` with no "is this version enabled NOW?" probe between.
- **Conditional fix**: before the AGW repoint in rollback, add a probe:
  `az keyvault certificate show --version <old_ver> --query attributes.enabled` == `true`; if
  not, HALT rollback and escalate (do NOT point AGW at an unresolvable URI). Symmetric to the
  baseline probe but evaluated at rollback time against live state, not saved state.

### Manual rollback (spec): same gap, plus no enabled-recheck at all.
Manual rollback (spec:289-298) repoints to `$OLD_SID` and disables new, then probes ssl-cert ==
OLD_SID and new==false — but **never probes OLD version is still enabled** before or after the
repoint. Manual operator gets no signal that the rollback target is resolvable. Same conditional
fix: add `az keyvault certificate show --version <OLD_VER from OLD_SID> --query
attributes.enabled` == true as a pre-repoint gate in spec:289.

### Versioned-URI drift after rollback: VERIFIED documented (not a defect).
Both scripts (go:495 / py:360) and spec:304 correctly note rollback leaves AGW on a versioned
URI (terraform drift + autorotation off) and instruct restoring versionless after a good cert.
Coherent and honest.

---

## 5. Force-refresh (versioned→versionless toggle, no empty update) — VERIFIED

- Toggle present and correct in all three: repoint to versioned `new_sid`, then restore
  `VLESS` versionless (go:396-405 / py:287-292 / spec:231-232). Order is correct (versioned
  first to force the `keyVaultSecretId` change, versionless second to restore autorotation).
- **No empty `update` anywhere**: grep confirms neither script nor spec ever issues a bare
  `az network application-gateway update` with no `--key-vault-secret-id`. Every AGW mutation in
  all three carries an explicit `--key-vault-secret-id` value (go:396,401,474 / py:287,290,347 /
  spec:231,232,290). The DEM-V4 / MS-docs Resolution-E hazard is correctly avoided.
- The explainer's "dangerous shortcut" ladder (md:207-220) and failure table (md:253) name the
  empty-update trap explicitly and the scripts honor it. Coherent.
- One residual (R-6, LOW): the restore-to-versionless and the force-to-versioned are two separate
  `az` calls (go:396 then go:401). If the **second** (restore) call fails but the first
  succeeded, AGW is left on the versioned URI. In execute mode the first call's error returns
  (go:397) before the second runs — good — but if the FIRST succeeds and the SECOND errors, the
  error returns (go:402) and `runAll`'s defer cleans the firewall, leaving AGW correctly serving
  the NEW cert but on a versioned URI (autorotation off, drift). That is the safe-fail direction
  (NEW cert is served), and the probe at go:418 would catch it if reached — but it is NOT reached
  because the error return at go:402 skips the probe. Net: a failed restore leaves drift with NO
  probe firing. Conditional fix: on restore failure, still run the versionless-confirm probe and
  emit the loud "AGW left on versioned URI — restore manually" warning (mirror the
  whitelist-off loud-fail pattern at go:457).

---

## Summary table (VERIFIED vs OPEN)

| ID | Severity | Finding | Status |
|----|----------|---------|--------|
| C-1 | — | Dates / hosts / two-name pair / sub coherent across all 3 + explainer | **VERIFIED clean** |
| C-2 | — | Force-refresh toggle present+correct; no empty `update` anywhere | **VERIFIED clean** |
| R-1 | **HIGH** | EXECUTE-mode empty-read coerced to expected value → probes pass spuriously (6 instances a–f) | **OPEN** |
| R-2 | MEDIUM | Manual Mode B firewall cleanup depends entirely on operator memory | **OPEN (documented)** |
| R-3 | MEDIUM | `runAll` prints "Sequence OK" though verify-effect proves nothing → false-success tail | **OPEN** |
| R-4 | MED/HIGH | Rollback never re-probes OLD version is still enabled before repointing AGW → possible listener disable | **OPEN** |
| R-5 | LOW | Per-step `whitelist-on -execute` has no defer/finally | **OPEN** |
| R-6 | LOW | Failed versionless-restore returns before its probe → silent drift | **OPEN** |
| FP-1 | INFO | Manual verify-effect expects UPPER:colon thumbprint, scripts use lower-nocolon → eyeball-normalize | **OPEN (cosmetic)** |

## Most-likely 3 AM failure (pre-mortem)
Production cert rotation runs at execute time during a throttled Azure window. A `keyvault
certificate show --query attributes.enabled` returns empty (transient 429). Instance R-1(a)
coerces it to `"true"`, the enable probe PASSES, "Sequence OK" prints (R-3). The new version was
never actually enabled; AGW's next versionless poll resolves to the still-latest OLD version. On
Jul 1 all four hosts serve an expired cert → mass TLS failure. The operator's run log said "OK."
That is the precise outage-with-false-success this lane exists to catch. Fix R-1 + R-3 first.

## Recommendation
FIX FIRST: R-1 (probe coercion) and R-4 (rollback enabled-recheck) are the two that can cause a
production outage masked as success. R-2/R-3/R-5/R-6 are cheap hardening. C-1/C-2 are clean —
the cross-artifact coherence the lane was asked to attack holds.
