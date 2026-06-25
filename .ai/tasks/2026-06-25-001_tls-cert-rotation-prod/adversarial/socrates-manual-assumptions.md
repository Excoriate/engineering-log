---
title: Socrates contrarian review — MANUAL-mode assumptions + probe-discrimination, PROD *.vpp.eneco.com TLS rotation
task_id: 2026-06-25-001
agent: socrates-contrarian
status: complete
timestamp: 2026-06-25T11:03:24+0200
summary: |
  Adversarial assumptions + verifiability review of the MANUAL-mode rotation spec under the
  stated execution model (fresh shell per step; on-disk state persists, shell vars do NOT).
  ONE class-defining CRITICAL: every Step 3-8 and Rollback probe is built on shell variables
  ($NEW_VER/$NEW_SID/$NEW_THUMB/$OLD_SID/$MYIP/$SUB/$RG/$KV/$OBJ/$VLESS) that are EMPTY in a
  fresh shell — multiple of those probes then print a "pass" token on empty input, so they are
  non-discriminating false-confidence gates exactly when it matters most. Plus four inherited
  2026-06-24 assumptions (SP rights, versionless binding intact, single consumer, firewall
  baseline) that the spec does not re-verify at run time. Verdict: NO-GO for the step-by-step
  manual run as written until the var-persistence model and the named probes are tightened.
---

# Socrates Contrarian — MANUAL-mode Assumptions + Verifiability

## Key Findings

- **C1 (CRITICAL, class-defining):** Fresh-shell-per-step voids all carried shell vars; Step 3-8/Rollback probes read empty → several print a PASS token on real failure.
- **H1 (HIGH):** Step 5 / Step 4 / Step 8 / Rollback probes are non-discriminating on empty or wrong-version input.
- **H2/H3/H4 (HIGH/MED):** Four 2026-06-24 assumptions (SP Import rights, versionless binding intact, single consumer, firewall baseline) are INHERITED, not re-verified at run time.
- **M1 (MED, informational):** AVD wire handshake is sufficient + necessary for like-for-like; control-plane proxies are a real but residual-bearing fallback — spec already correct, just don't promote to "done."
- **Deferred audit:** Of the carried-over deferrals, only the shell-var state-persistence gap is run-blocking for MANUAL mode; cross-sub sweep and password-in-ps are non-blocking.

**Target:** `rotation-execution-spec.md` (Mode B, Manual) + `how-the-vpp-tls-rotation-works.md`, read in full.
**Frame:** assumptions whose falsity flips a step or the GO decision; probes that print "pass" on a real failure.
**Epistemic note:** this output is INFER until the coordinator source-verifies. Findings cite the spec by section/line.

---

## STEELMAN (what the spec gets right — survives scrutiny)

- The **import-disabled → thumbprint-gate → enable** ordering is correct and is the strongest design choice: a wrong cert can never go live before the Step-4 crypto gate (spec L163-201). This is genuinely good and should be preserved verbatim.
- It already refuses `az exit 0` as success and mandates a **wire handshake** as the only real proof (L41, L245-263). That is the right truth-surface.
- It already names the **versioned→versionless toggle** as the only working force-refresh, source-verified against MS docs Resolution E (L223-226, companion L117-121). Not FUD; correct.
- It already treats **whitelist-off as a `finally`** and gives an idempotent self-probing cleanup (L89, Step 8).
- Rollback already added **R-4** (re-confirm OLD version is STILL enabled NOW before repointing, L294-297) — that is a run-time re-verify and is exactly the pattern the rest of the spec is missing.

The spec is well-reasoned for a SINGLE continuous shell. The attack below is specifically about the **stated MANUAL execution model**, which the spec body was not written against.

---

## CRITICAL — class-defining

### C1. Fresh-shell-per-step destroys every carried variable → Step 3-8 + Rollback probes read EMPTY and several then print a PASS token

**Assumption (implicit, load-bearing):** "the shell variables set in Session setup / Step 2 / Step 3 are still defined when Step 4-8 and Rollback run their probes."

**Why its falsity matters — and it IS false under the stated model.** The dispatch brief states: *"separate fresh shells; on-disk state persists, shell vars do not."* The spec, however, threads state through **shell variables only**:

- Session setup defines `SUB RG KV OBJ AGW SSL VLESS PFX PW MYIP` (L96-107) and **echoes nothing to disk**.
- Step 2 captures `OLD_SID OLD_THUMB` into vars (L147-149) — the only persistence is "WRITE THESE DOWN" by a human, which the AI agent does not do.
- Step 3 captures `NEW_SID NEW_VER NEW_THUMB` into vars (L170-173).
- Steps 4, 5, 6, 8 and Rollback **all read those vars** in both their action and their Probe.

In a fresh shell every one of `$SUB $RG $KV $OBJ $AGW $SSL $VLESS $MYIP $OLD_SID $NEW_VER $NEW_SID $NEW_THUMB` is the empty string. That converts working commands into silently-wrong ones, and — the verifiability crime — converts several **probes into false-PASS generators**:

- **Step 4 gate (L193-194):** `EXPECT=$(openssl … "$PFX" … )`. With `$PFX` empty, openssl reads nothing, `EXPECT` is empty, the guard `[ -n "$EXPECT" ]` catches THAT case (prints MISMATCH) — OK, this one fails safe. But `$NEW_THUMB` is also empty, so even with a good `$PFX` the compare `[ "$EXPECT" = "$NEW_THUMB" ]` is `non-empty = empty` → MISMATCH. Fails safe but for the WRONG reason (it will block a good import and the operator will chase a phantom cert problem).
- **Step 5 probe (L214-216):** `LATEST=$(az … )` and `[ "$LATEST" = "$NEW_THUMB" ]`. If both the `az` read and `$NEW_THUMB` are empty, the test is `[ "" = "" ]` → **prints `versionless now resolves to NEW`** while NOTHING was verified. **This is a probe that prints PASS on total failure.** Class-defining false confidence.
- **Step 5 enable action (L208):** `--version "$NEW_VER"` with empty `$NEW_VER` → `az` errors or, worse, operates on an unintended default; the probe above masks it.
- **Step 6 action (L229-230):** `--key-vault-secret-id "$NEW_SID"` then `"$VLESS"`, both empty → the first call errors; if only `$VLESS` is empty the gateway could be left pinned to a versioned URI; the probe (L236-237) reads `keyVaultSecretId` literally so it would at least show the wrong value — but only if the operator actually compares it (the spec gives no equality assertion here, just "expect a URI ending …").
- **Step 8 action+probe (L274, L280):** `--ip-address "${MYIP}/32"` with empty `$MYIP` removes/queries `"/32"` — the remove targets the wrong value and the probe `length(... value=='/32')` returns `0` → **prints the expected `0`** → "firewall clean" while **your real IP rule is still open on the prod KV**. False-PASS on the security-cleanup step. This is the worst one: it can leave the prod KV firewall open and report success.
- **Rollback (L296-300):** `OLD_VER="${OLD_SID##*/}"` with empty `$OLD_SID` → `OLD_VER` empty → R-4 check and the repoint operate on garbage during an emergency.

**Severity: CRITICAL.** This single model mismatch makes at least Step 5 and Step 8 probes false-PASS, and corrupts the actions of Steps 4-8 + Rollback.

**Conditional change (pick ONE, enforce for the whole manual run):**

- **Preferred — kill the model mismatch:** run the entire manual sequence in **one persistent shell**, OR have the agent **persist state to disk** and re-`source` it at the top of every step. Concretely, add a **Step 0.5 "state file"**: after Session setup, Step 2, and Step 3, append the captured values to `/tmp/azsp-prd/rotate.env` (e.g. `printf 'export NEW_VER=%q\n' "$NEW_VER" >> …`) and begin every subsequent step with `set -a; source /tmp/azsp-prd/rotate.env; set +a; : "${NEW_VER:?run Step 3 first}"`. The `:?` guards are the discriminator — a missing var HALTS instead of printing PASS.
- **Mandatory regardless:** add a **non-empty guard to every probe** before the equality test, e.g. Step 5: `[ -n "$NEW_THUMB" ] && [ -n "$LATEST" ] && [ "$LATEST" = "$NEW_THUMB" ] && echo MATCH || echo "STOP (empty or mismatch)"`. Same for Step 8: `: "${MYIP:?}"` before the remove, and assert the probe counts the REAL ip, not `/32`.

If the agent will genuinely run fresh shells, this finding alone is **NO-GO** until resolved.

---

## HIGH

### H1. Step 8 probe is non-discriminating even WITH vars — it cannot tell "I removed it" from "it was never there / IP drifted"

**Probe (L280):** counts rules matching `${MYIP}/32` and expects `0`. A `0` is returned in **three different worlds**: (a) the remove worked; (b) the rule was never added because Step 1 failed; (c) your egress IP **changed mid-session** (plausible on corporate NAT/VPN over a multi-step window) so the rule under your OLD IP is **still open** and you're querying the NEW IP → `0`, "clean", but a stale open rule persists. The spec's own "what could go wrong" (L286) acknowledges (c) but the **probe does not detect it** — it's a narrative footnote, not a gate.

**Severity: HIGH** (security exposure on prod KV reported as clean).
**Conditional change:** make the Step 8 probe enumerate **all** IP rules and assert the full list matches the known baseline, not just the absence of one value: `az keyvault show … --query "networkAcls.ipRules[].value" -o tsv` and require it to equal the Step-2-captured baseline set. Capture that baseline in Step 2 (see H4).

### H2. "The prd SP STILL has cert Import + KV-firewall-write rights TODAY" — INHERITED from 2026-06-24, never re-verified in the spec body

The right is proven only in yesterday's context (`02-scope-confirmed.md` section 5; companion Evidence-ledger). The spec **assumes** it (L94) and only discovers loss **reactively** at the point of mutation: Session-setup failure note (L118), Step 1 `AuthorizationFailed` note (L137), Step 3 import error note (L183). That is detection-by-blast, not a pre-flight gate. If an access policy or RBAC assignment was changed in the last day (key rotation, policy cleanup, Conditional Access), the operator finds out **only after** opening the firewall (Step 1 done) but **unable to import** (Step 3) — leaving the prod KV firewall open while troubleshooting permissions.

**Severity: HIGH** (route flips: if the right is gone, the whole manual run is impossible and you've already mutated the firewall).
**Conditional change — add Step 0.6 (read-only, pre-mutation):** after Session setup, before Step 1, re-read the live policy:
`az keyvault show -n "$KV" -g "$RG" --subscription "$SUB" --query "properties.accessPolicies[?objectId=='686d817d-86b9-4d8f-9aa4-8212cf12931a'].permissions.certificates" -o tsv` and assert it contains `Import`. This is control-plane, needs no firewall, and discriminates a since-yesterday revocation **before** any mutation.

### H3. "vpp-ag-p is STILL the only consumer / the AGW ssl-cert is STILL bound to the versionless URI and nobody has rotated it" — INHERITED, drift since 2026-06-24 not re-checked

Two coupled inherited facts: single-consumer (companion section 5; ledger #4) and versionless binding (`03-iac-drift-check.md`). The spec's Step 6 probe (L237) DOES read `keyVaultSecretId` — but only AFTER the toggle, and it asserts the *post*-restore value, so it cannot tell you the binding was **already** versioned/changed by someone else before you started. If a colleague (or a terraform apply you didn't know about) repointed the ssl-cert to a versioned URI yesterday evening, your Step-6 "restore versionless" still looks like a success while you've actually overwritten their pin.

**Severity: HIGH** for the binding-state read (it changes whether Step 6 is "force a pull" or "stomp someone's pin"); MEDIUM for single-consumer (a new consumer added in a day is low-probability but its falsity means a host you don't verify breaks at Jul 1).
**Conditional change — add Step 0.7 (read-only, pre-mutation):** read the **current** `keyVaultSecretId` and assert it is the versionless URI BEFORE Step 1: `az network application-gateway ssl-cert show -g "$RG" --gateway-name "$AGW" -n "$SSL" --query keyVaultSecretId -o tsv` must equal `$VLESS`. If it already ends in a version GUID → STOP and investigate (someone is mid-change). This is the cheapest possible drift discriminator and it is currently absent from the pre-flight.

### H4. "The KV firewall baseline is Deny with my IP absent (residual 0) RIGHT NOW" — assumed, not captured

Preconditions don't capture the firewall's **current** rule set. Step 1 adds your IP; Step 8 removes it; but neither records what was there **before** so you can prove you returned to the exact baseline (not "0 of my IP" — the actual full baseline). If a different operator IP was already whitelisted (legitimately or not), your run neither sees nor preserves it.

**Severity: MEDIUM** (drift/exposure detection gap; pairs with H1).
**Conditional change:** in Step 2 (the "record baseline" step), ALSO capture the firewall baseline to disk: `az keyvault show … --query "networkAcls.ipRules[].value" -o tsv > /tmp/azsp-prd/kv-fw-baseline.txt` and have Step 8's probe assert the post-state equals this file. This makes Step 8 discriminating (resolves H1 too).

---

## MEDIUM

### M1. AVD wire handshake — IS the right user-observable success criterion; control-plane-only proof carries a NAMED residual

The brief asks: is the AVD handshake on 4 hosts both sufficient AND necessary, and is control-plane-only ever acceptable?

- **Necessary:** YES for a true end-to-end claim. The companion's entire thesis (L201, L289) is that `az` exit 0 is not success; only a handshake presenting the new expiry proves the gateway re-pulled. The four listeners share **one** ssl-cert resource (companion L173), so a handshake on any ONE is evidence for all four — but verifying all four is cheap and catches a per-listener disable, so keep all four.
- **Sufficient:** YES for **like-for-like** (same SAN/CA, only expiry+key change). The only things that could differ post-rotation are expiry and thumbprint, both of which the handshake reads. There is no SAN/host-routing change to also verify, so the handshake is complete proof here.
- **Control-plane-only (no AVD) acceptable?** Only as an **interim** with explicit residual, exactly as the spec already states (L266): KV latest-enabled thumbprint == new, AGW `provisioningState=Succeeded`, ssl-cert on versionless URI, Resource Health=Available. These prove "the gateway accepted the change and the vault hands out the new cert" but **NOT** "a client on the wire receives it." The residual is the AGW's ~4h cache/poll and any silent listener disable. **Acceptable to declare "rotation staged, effect pending wire-verify" — NOT "done."** The spec's PC4 already makes "no AVD path → NO-GO" (L56), which is the correct hard gate; keep it.

**Severity: MEDIUM (informational — the spec is already correct here).** Conditional change: none required; just ensure the agent does not silently promote control-plane proxies to "done." Tag any control-plane-only completion as `[UNVERIFIED[blocked]: wire handshake pending AVD]`.

### M2. Step 3 → Step 4 gate compares the PFX to the import-response thumbprint, not an independent vault re-read

Step 3 captures `NEW_THUMB` from the **import response** (`jq .x509ThumbprintHex`, L172). Step 4 compares the **PFX** thumbprint to that captured value (L194). Both sides ultimately trace to "what the import call returned," so if the vault echoed a thumbprint for the bytes it *received* this is fine — but the gate would be strictly stronger if Step 4 re-read the thumbprint from the vault **by version** (`az keyvault certificate show … --version "$NEW_VER" --query x509ThumbprintHex`) rather than trusting the import-response variable. Under C1 (empty var) this matters more; under a fixed-state model it's a minor hardening.

**Severity: MEDIUM.** Conditional change: in Step 4 set `VAULT_THUMB=$(az keyvault certificate show … --version "$NEW_VER" --query x509ThumbprintHex -o tsv | tr A-Z a-z)` and gate on `EXPECT == VAULT_THUMB` (independent of the import response). Discriminates a vault that stored different bytes than it acknowledged.

### M3. Step 6 has no equality assertion — "expect a URI ending …" is eyeball-only

Steps 4 and 5 use `[ … = … ] && echo PASS || echo FAIL`. Step 6's probe (L233-237) just prints `provisioningState` and `keyVaultSecretId` and tells the human to expect a versionless URI — no machine assertion. A human (or agent) skimming "Succeeded" can miss that the second line still shows a version GUID (the spec even warns this is the failure mode, L243). A non-asserting probe is weaker than its neighbors.

**Severity: MEDIUM.** Conditional change: add `[ "$(az … ssl-cert show … --query keyVaultSecretId -o tsv)" = "$VLESS" ] && echo "versionless restored" || echo "STOP — still versioned, re-run restore"`.

---

## DEFERRED-ITEM AUDIT (brief asked: anything still deferred that should block MANUAL run?)

| Deferred item | Source | Block the manual step-by-step run? |
|---|---|---|
| **State persistence for shell vars across steps** | (newly surfaced by C1) | **YES — run-blocking.** This is the one deferral that breaks MANUAL mode. Resolve via Step 0.5 state file or single-shell. |
| Cross-subscription (Sandbox/iactest) sweep | spec Notes L327; companion ledger #7 | NO for executing the prod rotation (prod is self-contained). It only bounds the *org-wide completeness* claim, not the prod change. Keep as post-run residual; do not let it gate GO. |
| Password in `ps` (`--password "$(cat …)"`) | spec L326 | NO on this single-operator laptop. But under C1, the modern-PFX re-encode fallback uses `--passout pass:TMP` / `--password TMP` literals (L325) — those are also `ps`-visible; acceptable per same reasoning. Not run-blocking. |
| No captured firewall baseline / IP-drift handling | (H1/H4) | PARTIAL — should be tightened (H4) but the surgical add/remove is low-risk; not a hard NO-GO if H1/H4 probes are added. |

---

## SUPERWEAPON DEPLOYMENT

- **SW1 Temporal Decay:** HIT — IP drift over a multi-step window makes Step 8 false-clean (H1); inherited 24h-old rights/binding (H2/H3); old-cert rollback decays past Jul 1 (spec already gates this, L312).
- **SW2 Boundary Failure:** HIT — the fresh-shell <-> on-disk-state boundary is exactly where C1 lives; the laptop <-> private-listener boundary is the AVD necessity (M1).
- **SW3 Compound Fragility:** HIT — C1 is a single root cause that simultaneously corrupts Steps 4,5,6,8,Rollback (correlated, not independent). Fix one thing (state model), fix all.
- **SW4 Silence Audit:** HIT — what's MISSING: pre-mutation re-verify of SP rights (H2) and binding state (H3); machine assertion in Step 6 (M3); baseline capture (H4); a `:?` guard on every load-bearing var.
- **SW5 Uncomfortable Truth:** the spec is labeled "all HIGH findings resolved" and `status: review`, but it was written and reviewed against a **single-shell** mental model; the **manual step-by-step-with-fresh-shells** execution model the agent will actually use was never reconciled with it. The prior reviews did not catch this because they tested the commands, not the inter-step state lifecycle.

## DOT-CONNECTION

C1 (empty vars) is the generator; H1 (Step 8 non-discriminating), the Step 5 false-PASS, and the M2/M3 weaknesses are all **symptoms of state living only in volatile shell vars**. Address the state model and the probe-guard pattern ONCE and 5 findings collapse. Do not patch them individually.

## META-FALSIFIER (how this review could be wrong)

- **If** the agent actually runs the whole manual sequence in ONE persistent shell (re-reading "fresh shells" as "fresh per top-level invocation, not per step"), then C1/H1-as-stated downgrade from CRITICAL to "add `:?` guards as defense-in-depth," and the verdict flips to GO-with-minor-hardening. **This is the single fact the coordinator must confirm with the operator before GO.** I assumed the brief's literal "shell vars do not persist."
- **If** Step 0.x re-verifies already exist in `rotate_tls.go` (the canonical source, L84) and the Manual prose is just a lossy mirror, then H2/H3 are partially mitigated for Scripted mode — but the brief is explicitly MANUAL mode, where the prose IS the procedure.
- I did **not** run any live `az` probe (correctly — that's the operator's job on GO); all "drift since yesterday" findings are *possibility* arguments, not confirmed drift. Their value is forcing a cheap read-only re-check, not asserting drift exists.

---

## VERDICT

**NO-GO for the step-by-step MANUAL run as written** — conditional and cheap to clear. The blocker is the execution-model mismatch (C1): under fresh-shell-per-step, Step 5 and Step 8 probes print PASS on real failure, and Steps 4-8 + Rollback operate on empty variables. Resolve by (a) running the manual sequence in one persistent shell **or** persisting captured state to `/tmp/azsp-prd/rotate.env` and `source`-ing it per step with `:?` guards, plus (b) adding the three read-only pre-mutation re-verifies (H2 SP-Import right, H3 versionless-binding-still-bound, H4 firewall baseline capture). With those, GO.

**Single most important run-time re-check:** before Step 1 (any mutation), in the SAME shell that will carry state, re-read **live** that the AGW ssl-cert `keyVaultSecretId` STILL equals the versionless `$VLESS` AND the prd SP cert permissions STILL include `Import` — both are read-only, need no firewall, and each independently flips GO if drift occurred since 2026-06-24.
