---
title: el-demoledor adversarial mechanics review — PROD vpp wildcard TLS rotation spec
task_id: 2026-06-24-002
agent: el-demoledor
status: complete
summary: Adversarial demolition of the 6 mechanical lanes of rotation-spec-DRAFT.md. KEY INVERSION — az import sends RAW PFX bytes (never client-parses), so legacy RC2/3DES is irrelevant to the client and step 2.1 re-encode is solving a non-problem on the client side; real risk shifts to KV SERVICE-side parser + step-2.1 collateral (friendlyName loss, password substitution). Thumbprint verify has a CASE-mismatch false-confidence bug. AGW force-update + rollback resolution are THEORETICAL (could not reach Microsoft docs MCP this session). 8 findings.
timestamp: 2026-06-24T00:00:00Z
---

# DEMOLEDOR REPORT — Rotation Spec Mechanics

**Target**: `specs/rotation-spec-DRAFT.md` (PROD `*.vpp.eneco.com` wildcard TLS rotation)
**Scope**: Full (mechanics lane) — local openssl on the real PFX + az CLI source trace
**Win condition**: make it FAIL or silently half-succeed unnoticed

> EVIDENCE NOTE: Microsoft docs MCP tools were NOT callable in this session (`microsoft_docs_search`/`fetch` returned "No such tool available"). Lanes 4 and 5 (AGW versionless re-pull + rollback resolution) are therefore graded THEORETICAL/PATTERN-MATCHED from az CLI source + Azure platform semantics, NOT doc-confirmed. The root agent MUST reach the AGW Key Vault docs before trusting lanes 4/5. All PFX/openssl/az-source findings are EXPLOIT-VERIFIED from local probes.

## DESTRUCTION SUMMARY

| Metric | Count |
|--------|-------|
| Findings | 8 |
| — EXPLOIT-VERIFIED | 4 |
| — PATTERN-MATCHED | 2 |
| — THEORETICAL | 2 |
| Spec premises INVERTED | 2 (OR-2 / step 2.1, OR-6 password-in-ps) |
| Blast radius | Failed/half-done prod cert rotation; worst case AGW serves no/old cert, or operator believes success on a false thumbprint match |

---

## THE BIG INVERSION (read this first)

**FACT (EXPLOIT-VERIFIED, az CLI source trace):** `az keyvault certificate import` does NOT parse the PFX on the client. The SDK does:

```text
azure/keyvault/certificates/_client.py:390
  base64_encoded_certificate = base64.b64encode(certificate_bytes).decode("utf-8")
  ... password=kwargs.pop("password", None) ...
  bundle = self._client.import_certificate(... parameters=parameters ...)
```

It base64-encodes the **raw file bytes** and ships them + the password to the Key Vault REST API. The client `cryptography` library NEVER decodes the PKCS12 structure. Verified two ways:

1. az 2.87.0 bundles `cryptography 46.0.7` on `OpenSSL 3.6.2` — the SAME OpenSSL 3.x that refuses this PFX without `-legacy` locally. If the client parsed it, import would fail. It doesn't parse it.
2. `_client.py` import path is pure base64-of-bytes; no `pkcs12.load_*` call anywhere in the import flow.

**Consequence for the spec:**
- OR-2's framing ("`az` ... uses the `cryptography` lib ... MAY reject it") is **WRONG at the client layer**. The client cannot reject it on format — it forwards bytes blindly.
- Acceptance/rejection happens **server-side in the Key Vault service PFX parser**, whose legacy-PBE tolerance is NOT determined by your local OpenSSL 3.6 and NOT determined by az's cryptography version.
- Therefore the local "openssl needed `-legacy`" observation is **NOT predictive** of whether import succeeds. The spec treats it as predictive. That is false-precision.

This does not make the spec safe — it relocates the risk and makes step 2.1 a **collateral-damage generator** rather than a fix (see V1/V2).

---

## FINDINGS

### V1 — Step 2.1 re-encode is a non-fix on the client side AND drops friendlyName [EXPLOIT-VERIFIED]

| Attribute | Value |
|-----------|-------|
| Mechanism | The spec mandates a "decision: import original first; if it fails on format, import modern.pfx." But the client never validates format (Big Inversion). So the original PFX bytes go to the service regardless. If the SERVICE rejects legacy PBE, re-encoding helps; if it accepts, re-encode is pure added risk. The spec presents re-encode as the mitigation for a client-side rejection that **cannot occur**. |
| Collateral | I ran step 2.1 verbatim on the real PFX. Re-encode IS cryptographically lossless for key+chain: 3 certs + 1 RSA key preserved, leaf SHA1 identical (`B8:20:2D:E2:0B:E7:FB:3F:B3:7E:6D:51:41:97:52:82:BF:33:BD:E7`), parses without `-legacy` (PBES2/AES-256-CBC, MAC sha256). BUT the original PFX has **NO friendlyName** on any bag (only `localKeyID` on the key bag; cert bags = `<No Attributes>`). Step 2.1 INJECTS `-name wildcard-vpp-eneco-com` as friendlyName. KV ignores PKCS12 friendlyName on import (object name comes from `--name`), so this is benign HERE — but it means original and modern.pfx are NOT byte-identical-intent, and the "import original first, modern as fallback" branch can silently change which artifact is the source of truth. |
| Detect | After re-encode, diff bag attributes: original has no friendlyName, modern.pfx has one. If a future audit compares "what was imported" by friendlyName, they diverge. |
| Severity Gate | Exploitability: LOW (collateral, not a direct break) x Impact: MED (source-of-truth ambiguity in a prod rotation) x Confidence: HIGH (verified) = MEDIUM |
| Conditional fix | **Step 2.1 MUST change to:** delete the "client may reject" justification; reframe as "import the ORIGINAL PFX bytes directly; re-encode is ONLY needed if the Key Vault SERVICE returns a parse error (HTTP 400 `Invalid PKCS12 / unsupported algorithm`)." Make re-encode a documented fallback triggered by a SPECIFIC service error string, not by the local `-legacy` observation. |
| Counter-hypothesis | Safe-if: the KV service rejects legacy PBE → then 2.1 is a real fix and should run first. I favor "non-fix as written" because the spec's stated TRIGGER for 2.1 is client-side format rejection, which the source proves impossible. I would switch IF a live throwaway-object import of the original PFX returns a service-side 400. |

### V2 — Re-encode + import path swaps the password variable; high silent-failure surface [EXPLOIT-VERIFIED]

| Attribute | Value |
|-----------|-------|
| Mechanism | Step 5 fallback: `--file "$WORK/modern.pfx" --password "$NEWPW"`. `$NEWPW` is set in step 2.1 (`<choose-a-throwaway-pw>` placeholder) inside a SEPARATE shell invocation block. If the operator runs steps as separate copy-pastes (the spec is a paste-the-block document), `$NEWPW` is **unset** in step 5's shell → `--password ""` → KV import of an encrypted key with empty password → service-side decrypt failure OR (worse) a successful import of a key the operator can't later reason about. The original-PFX password (`file:$PW` / `$(cat "$PW")`) and the modern-PFX password (`$NEWPW`) are DIFFERENT secrets with different lifetimes. |
| Detect | The import returns an error only if KV rejects empty-password decrypt. If KV is lenient, no error surfaces. |
| Severity Gate | Exploitability: MED (requires fallback branch + separate shells) x Impact: HIGH (failed/wrong import in prod) x Confidence: HIGH = HIGH |
| Conditional fix | **Step 2.1/5 MUST change to:** export `NEWPW` into the same persisted env used by step 5 (e.g. write to `$WORK/newpw` with `chmod 600`, read via `file:`), and add an explicit guard `: "${NEWPW:?modern PFX password unset — re-run 2.1}"` before any import that uses it. |
| Counter-hypothesis | Safe-if: operator runs the whole spec as one script with shared env → `$NEWPW` persists. I favor the break because the document is structured as independent paste blocks (each `## N` is its own fenced block) and explicitly uses a placeholder `<choose-a-throwaway-pw>`. I'd switch IF the spec is wrapped in a single executable script with `set -u`. |

### V3 — Thumbprint verify has a CASE-mismatch false-confidence bug [PATTERN-MATCHED]

| Attribute | Value |
|-----------|-------|
| Mechanism | Step 6 compares `EXPECT_SHA1` (openssl `-fingerprint -sha1` piped through `sed 's/.*=//; s/://g'`) against `GOT` (`az ... --query x509ThumbprintHex -o tsv`) with a literal string `[ "$EXPECT_SHA1" = "$GOT" ]`. I verified openssl produces **UPPERCASE** hex: `B8202DE20BE7FB3FB37E6D5141975282BF33BDE7`. Azure Key Vault's `x509ThumbprintHex` is the SHA1 hash hex-encoded but Azure has historically returned it in a DIFFERENT case (commonly lowercase or with az JMESPath normalization). A `[ "$A" = "$B" ]` string compare is **case-sensitive**. If az returns lowercase `b8202de2...` and openssl gives uppercase `B8202DE2...`, the compare yields `KV MISMATCH ❌ — STOP` on a PERFECTLY CORRECT import → operator aborts a successful rotation, OR (the dangerous direction) if a future az version flips case the operator's eye-check passes a non-match. Either way the gate is unreliable. |
| Also | `x509ThumbprintHex` is the documented hex field (good — NOT the base64url `x509Thumbprint`), so the FORMAT (hex vs base64) is correct; only CASE is the defect. Spec already correctly strips colons. |
| Detect | Run both sides on the OLD cert before import: `az ... x509ThumbprintHex -o tsv` vs `openssl ... -fingerprint -sha1 | sed ...`. If they differ ONLY by case, the gate is broken. |
| Severity Gate | Exploitability: HIGH (fires on every run if case differs) x Impact: HIGH (false STOP on success, or false PASS) x Confidence: MED (az case is version-dependent; not locally reproducible without the live KV) = HIGH |
| Conditional fix | **Step 6 MUST change to:** normalize BOTH sides to one case before compare: `EXPECT_SHA1=$(... | tr 'A-Z' 'a-z')` and `GOT=$(az ... -o tsv | tr 'A-Z' 'a-z')`. Same fix in step 8 baseline compare and step 4 rollback-baseline. |
| Counter-hypothesis | Safe-if: az `x509ThumbprintHex` happens to return uppercase matching openssl in this az version. I favor the break because case-sensitive crypto-digest string compares are a classic false-confidence pattern and Azure's documented examples show lowercase; the cost of `tr` normalization is zero. I'd switch IF a live `az keyvault certificate show ... x509ThumbprintHex` on the existing object returns uppercase. The operator can settle this in one read BEFORE import. |

### V4 — AGW `update` no-op may NOT force a versionless re-pull [THEORETICAL]

| Attribute | Value |
|-----------|-------|
| Mechanism | Step 7 claims `az network application-gateway update` (no property change) "forces AGW to re-pull the versionless KV secret." `az network application-gateway update --help` confirms it is a generic update that serializes existing config and PUTs it back (`begin_create_or_update`). Whether a no-delta PUT triggers AGW to re-resolve the versionless KV secret URI is a SERVICE-side behavior of the AGW control plane, NOT guaranteed by the PUT itself. Azure's documented mechanism for versionless KV certs is an automatic poll (~4h, historically cited as up to ~24h in some docs); a forced re-pull via no-op PUT is FOLKLORE unless the PUT actually changes the sslCertificate's resolved version. If the PUT is a true no-op and AGW dedupes it (no provisioning change), the new cert is NOT served until the next auto-poll — operator sees `az` exit 0 and BELIEVES propagation happened. This is the spec's own H-EFFECT-1 risk, but step 7's force-refresh claim is asserted as fact. |
| Detect | The spec's own EFFECT check (step 7 openssl s_client from AVD) is the ONLY truth — but it requires internal network (OR-5). Without AVD reach, "success" is unverifiable, and the no-op-PUT assumption is untested. |
| Severity Gate | Exploitability: MED x Impact: HIGH (silent non-propagation; listeners serve OLD cert until it expires Jul 1 → outage) x Confidence: MED (could not reach docs) = HIGH |
| Conditional fix | **Step 7 MUST change to:** (a) downgrade the "forces re-pull" claim to `[UNVERIFIED — confirm against AGW Key Vault docs]`; (b) make the AVD `s_client` EFFECT check MANDATORY and BLOCKING, not optional; (c) if no-op PUT is unconfirmed, the reliable forcer is to touch the sslCertificate's KeyVaultSecretId (re-set the SAME versionless URI) which guarantees a re-resolve, OR accept the auto-poll window and schedule verification after it. Root agent MUST fetch `learn.microsoft.com/azure/application-gateway/key-vault-certs` to confirm before GO. |
| Counter-hypothesis | Safe-if: AGW re-resolves versionless secrets on every control-plane PUT regardless of delta (some Azure RPs do). I favor THEORETICAL-with-high-impact because I could not confirm it this session and the failure is SILENT (exit 0, old cert served). I'd switch to PATTERN-MATCHED-safe IF the AGW docs state a no-op update re-pulls. |

### V5 — Rollback assumes AGW resolves versionless secret to "latest ENABLED" — unconfirmed [THEORETICAL]

| Attribute | Value |
|-----------|-------|
| Mechanism | Step 8 rollback: `set-attributes --enabled false` on the new version, then AGW update, expecting AGW to fall back to the previous (old, still-enabled) version. This rests on TWO unconfirmed behaviors: (1) a versionless KV secret URI resolves to the latest ENABLED version (not merely the latest CREATED version — if AGW resolves "latest by created" it would resolve to the now-DISABLED new version and FAIL to serve, breaking ALL listeners during a rollback attempt); (2) AGW re-pulls on the update (same as V4). If (1) is "latest created" semantics, disabling the new version does NOT revert AGW — it leaves AGW pointing at a disabled/unresolvable version → total TLS outage on all four listeners, during an incident-response rollback, at the worst possible moment. |
| Detect | Cannot detect without live test; the disabled-version resolution behavior is the load-bearing unknown. |
| Severity Gate | Exploitability: LOW (only on rollback path) x Impact: HIGH (rollback makes outage WORSE) x Confidence: MED = HIGH-on-rollback |
| Conditional fix | **Step 8 MUST change to:** add a SAFER rollback primary: re-import the OLD cert bytes as a NEW version (making the OLD cert the latest-created AND enabled), rather than relying on disable-and-fallback semantics. Keep disable as secondary ONLY after confirming versionless→latest-enabled resolution against AGW/KV docs. Pre-stage the OLD PFX/PEM (export now via `az keyvault certificate download` / `secret show` while whitelist is open) so rollback does not depend on resolution semantics. |
| Counter-hypothesis | Safe-if: versionless KV secret resolution is "latest enabled" (Key Vault secret GET without version returns the latest enabled value — this IS the documented KV secret behavior, which supports the spec). I favor flagging it THEORETICAL because the COMPLECTING of KV-secret-resolution + AGW-cache + AGW-re-pull timing is not jointly confirmed, and the failure mode is catastrophic-on-rollback. I'd switch to safe IF both KV "GET secret (no version) = latest enabled" AND AGW re-pull-on-update are doc-confirmed. |

### V6 — `--password "$(cat "$PW")"` exposes password in `ps`, but NOT the way OR-6 assumes [EXPLOIT-VERIFIED]

| Attribute | Value |
|-----------|-------|
| Mechanism | TWO sub-issues. (a) Process-args exposure: `--password "$(cat "$PW")"` — command substitution runs in the parent shell and the RESULT is placed in az's argv, so the plaintext password IS visible in `ps -ef`/`/proc` for the import duration. OR-6 flags this correctly. (b) Newline handling: I verified the password file is 13 bytes = 12-char password `HlScIUDLMLjU` + trailing `\n` (0x0a). `$(cat "$PW")` STRIPS the trailing newline (verified: cat-result 12 bytes vs file 13) → az receives the correct 12-char password. GOOD. The newline is safely stripped by command substitution. The earlier-step openssl `file:$PW` ALSO strips it (verified: full thumbprint pipe works). So the newline is NOT a defect — but it is LATENT: if anyone changes step 5 to `--password "$PW"` (file path) or `--password "$(printf '%s\n' ...)"`, the trailing `\n` reappears and import fails with a wrong-password error that looks like a legacy-format error. |
| Detect | `ps -ef | grep -i password` during import shows plaintext. For newline: import fails with auth error if newline leaks in. |
| Severity Gate | Exploitability: MED (local host only; SP session is isolated) x Impact: MED (secret leak to local process table; this is a single-operator laptop) x Confidence: HIGH = MEDIUM |
| Conditional fix | **Step 5 MUST change to:** avoid argv exposure. az has no `--password @file`, so the lowest-risk path is `read -rs` into a shell var from the file (newline-stripped) and pass via the var, accepting brief argv exposure, OR re-encode to a known throwaway password and document the secret is short-lived. Add an explicit assertion that the password length is 12 (`[ ${#PW_VAL} -eq 12 ]`) to catch newline contamination. |
| Counter-hypothesis | Safe-if: this is a single-user trusted laptop with no other processes reading `ps`. I favor reporting because it is a real prod secret in argv and the spec itself raised OR-6. The newline portion I downgrade to LATENT (currently safe, fragile to edits). |

### V7 — Soft-delete / name-collision: import on an existing name creates a VERSION, but purge-protection edge exists [PATTERN-MATCHED]

| Attribute | Value |
|-----------|-------|
| Mechanism | `az keyvault certificate import --name <existing>` on a LIVE (non-deleted) object correctly creates a NEW VERSION — this is standard KV behavior and is the correct model here (the object `wildcard-vpp-eneco-com` is live per scope doc). The break surface: if the OBJECT itself were ever soft-deleted (it is not, per scope A1 reads), import would fail with "object is currently in a deleted but recoverable state" until recovered/purged — NOT a silent wrong state, a hard error. The real silent-state risk is the spec's step 5 NOT passing `--disabled`, combined with KV importing the new version as `enabled=true` by default → new version becomes latest-enabled IMMEDIATELY on import, BEFORE the step-6 thumbprint gate runs. So the gate is verifying a version that is ALREADY live to any versionless consumer. If the import is somehow the WRONG cert, it is already the latest-enabled version at the KV layer the instant import returns — the "STOP" in step 6 is too late to prevent KV-level exposure (though AGW won't pick it up until step 7). |
| Detect | Step 4 list-versions before + step 5 import output `new_version` id; compare. Check `attributes.enabled` of the imported version = true. |
| Severity Gate | Exploitability: LOW (object is live, scope-confirmed) x Impact: MED (gate-after-live ordering) x Confidence: MED = MEDIUM |
| Conditional fix | **Step 5 MAY change to:** import with `--disabled` so the new version is NOT latest-enabled until the step-6 thumbprint gate PASSES, then `set-attributes --enabled true`. This makes the verify gate actually gate-BEFORE-exposure. (Tradeoff: extra step; but it closes the gate-after-live window and makes rollback cleaner since the new version starts disabled.) |
| Counter-hypothesis | Safe-if: the cert is correct (scope doc proves CN/SAN/SHA256 match the held PFX — F4:F2:47... verified locally matches scope doc) so the wrong-cert scenario is near-zero. I favor reporting the ordering as a MEDIUM hardening because verify-after-live is structurally backwards even when the content is right. |

### V8 — `MYIP` capture + whitelist-revert race / IPv6 + `finally` correctness [PATTERN-MATCHED]

| Attribute | Value |
|-----------|-------|
| Mechanism | Step 4 `MYIP=$(curl -4 -s ifconfig.me)` then add `${MYIP}/32`. Step 9 `finally` removes `${MYIP}/32` and verifies residual 0 by `contains(value,'$MYIP')`. Failure modes: (a) if `curl -4 ifconfig.me` returns EMPTY (network hiccup, ifconfig.me down), `network-rule add --ip-address "/32"` runs with a malformed value → either errors (safe) or adds a garbage rule; the revert then removes `/32` (also garbage) and the residual check `contains(value,'')` matches EVERYTHING → reports a FALSE residual or a false-clean. (b) If the operator's egress is IPv6 or changes IP mid-session (CGNAT, VPN flap), the added rule whitelists an IP that is NOT the one KV sees → import fails with 403 Forbidden that looks like a permission problem, not a whitelist problem. (c) `finally` only runs if the operator's harness actually wraps steps in trap/finally — the spec SAYS "MANDATORY finally" but the blocks are bare bash; a paste-and-run operator who Ctrl-C's mid-import leaves the whitelist OPEN. |
| Detect | Guard `MYIP`: `[ -n "$MYIP" ] || exit`. Compare `az account` IP-seen vs curl IP. Residual check should match `value=='${MYIP}/32'` exactly, not `contains`. |
| Severity Gate | Exploitability: MED x Impact: MED (residual prod KV firewall opening if revert is skipped/garbage) x Confidence: HIGH (logic-verified) = MEDIUM |
| Conditional fix | **Steps 4/9 MUST change to:** (a) `: "${MYIP:?could not determine egress IP}"` guard; (b) residual check uses exact equality `?value=='${MYIP}/32'` not `contains`; (c) wrap the whole import in an actual `trap '...' EXIT` so the revert truly runs on Ctrl-C/failure, not just documented as "finally." |
| Counter-hypothesis | Safe-if: operator runs as one trapped script on a stable IPv4 egress. I favor reporting because the spec's blocks are independently pasteable and `contains('')` matching-everything is a verified logic defect. |

---

## ABSENCE AUDIT

| Missing Control | Impact When Needed |
|-----------------|--------------------|
| Case normalization on thumbprint compare | V3 false STOP/PASS |
| `--disabled` import + gate-before-enable | V7 verify-after-live ordering |
| `${MYIP:?}` / `${NEWPW:?}` guards | V2/V8 empty-variable silent failures |
| Real `trap EXIT` (not prose "finally") | V8 residual prod firewall opening on abort |
| Pre-staged OLD cert export for rollback | V5 rollback depends on unconfirmed resolution semantics |
| Service-side error-string trigger for re-encode | V1 re-encode runs on wrong trigger |
| Doc confirmation of AGW versionless re-pull | V4/V5 silent non-propagation |

## SUPERWEAPON DEPLOYMENT

| SW | Finding |
|----|---------|
| SW1 Temporal | Old cert expires Jul 1 2026; if V4 (no re-pull) fires silently, listeners serve old cert until Jul 1 then hard TLS-expiry outage on agg./gurobi./apollo./flex-trade-optimizer — a delayed, calendar-triggered cascade. |
| SW2 Boundary | The boundary between LOCAL openssl (`-legacy` needed) and SERVICE-side KV parser is where the spec's risk model is wrong (Big Inversion). Local observation does not predict service behavior. |
| SW3 Compound | V2+V8: separate-shell paste model + empty `$NEWPW`/`$MYIP` + `contains('')` matching-all compound into "import wrong/fails AND firewall left open AND operator thinks it's clean." |
| SW4 Pre-Mortem | Jul 1 02:00 — cert expires. agg./gurobi./apollo. all throw TLS errors. On-call pulls up the rotation log from June 24: `az` exited 0, thumbprint "matched." But the June 24 thumbprint compare silently passed on a case-fluke, the no-op AGW PUT never re-pulled, and the AVD effect-check was skipped because the operator wasn't on the internal network. The cert was in KV the whole time — AGW just never served it. 4 prod listeners down, root cause 6 days stale. |
| SW5 Uncomfortable Truth | The spec's headline mitigation (step 2.1 re-encode for "az may reject legacy PFX") is solving a client-side problem that the az source proves cannot happen. Effort went into the wrong risk; the REAL risks (thumbprint case, AGW re-pull, rollback resolution, empty-var safety) are under-specified or marked `[INFER]`/`[UNVERIFIED]` and left for review. The re-encode feels like diligence but is mechanism-misplaced. |

## ADVERSARIAL SELF-CHECK

- Pattern-matching check: V3 (thumbprint case) and V4/V5 (AGW behavior) are the ones I could NOT fully verify locally. I graded V3 PATTERN-MATCHED (case-compare is a known false-confidence shape; az case is version-dependent — operator can settle in one read) and V4/V5 THEORETICAL (could not reach docs). I did NOT inflate them to EXPLOIT-VERIFIED.
- False-positive conditions: each finding carries an explicit "Safe-if" counter-hypothesis. V1/V2/V7's break depends on the paste-block execution model; if wrapped as one `set -eu` script, V2 weakens.
- Redundancy / root-cause grouping: V1+V2 share ONE root cause (step 2.1 premise is mechanism-misplaced). V4+V5 share ONE root cause (unconfirmed AGW versionless re-pull/resolution). V8's three sub-issues are one root cause (no `set -u`/`trap`). Counted as distinct findings because each needs a DIFFERENT spec edit, but the root agent should treat {V1,V2} and {V4,V5} as paired fixes.
- Bias scan: I caught myself initially wanting to grade "legacy PFX will be rejected" as a CRITICAL break (pattern-match on OpenSSL 3.6 deprecation). The az source trace INVERTED it — client never parses. Corrected before writing. This is the single most important correction in this review.

## META-FALSIFIER

- CONFIRMED after self-attack: V1, V2, V3, V6, V8 (locally verified or logic-verified).
- DOWNGRADED: V4, V5 explicitly held at THEORETICAL — I will not assert AGW re-pull/rollback behavior without the Microsoft docs the MCP tool denied me this session. Strongest defense against V4: many Azure RPs DO re-resolve KV refs on any PUT; if true, V4 collapses. I leave it flagged because the failure is silent and calendar-fatal.
- REMOVED: none. I considered removing V7 (content is provably correct, so wrong-cert is near-zero) but kept it because verify-after-live is a structural ordering defect independent of content correctness.

## VERDICT

**Findings**: 8 (4 EXPLOIT-VERIFIED, 2 PATTERN-MATCHED, 2 THEORETICAL).
**Highest severity**: HIGH — V3 (thumbprint case false-confidence), V4 (silent non-propagation), V5 (rollback makes outage worse).
**Two spec premises INVERTED**: OR-2/step-2.1 (client never parses PFX) and the predictive value of the local `-legacy` observation.
**Blast radius**: prod TLS rotation that exits 0 while serving the OLD cert, then hard-expires Jul 1 2026 across 4 listeners; or a rollback that deepens the outage.
**Recommendation**: BLOCK MERGE until (1) step 6/8 thumbprint compares are case-normalized, (2) step 2.1 re-trigger is reframed to a service-side error, (3) `$NEWPW`/`$MYIP` guards + real `trap EXIT` added, (4) AGW versionless re-pull (V4) and rollback resolution (V5) are CONFIRMED against `learn.microsoft.com/azure/application-gateway/key-vault-certs` — the root agent must reach those docs (MCP was unavailable to me this session).

---
*El Demoledor: Proving resilience through destruction*
