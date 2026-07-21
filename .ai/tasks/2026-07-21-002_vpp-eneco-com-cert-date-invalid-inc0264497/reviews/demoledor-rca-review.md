---
title: "El Demoledor — adversarial demolition of INC0264497 RCA mechanism + fix"
task_id: 2026-07-21-002
agent: el-demoledor
incident: INC0264497
timestamp: 2026-07-21
status: complete
reviewer: el-demoledor
win_condition: break the mechanism and the fix (SAN validity, fix safety, rollback reasoning, wrong identifiers, omitted failure modes)
summary: >-
  Demolition of INC0264497 RCA mechanism + applied fix. 8 findings (1 HIGH, 4 MEDIUM, 3 LOW).
  HIGH D1 is EXPLOIT-VERIFIED: RCA L5/Context-Ledger claim versionless URI resolves to "latest
  enabled version" — contradicted by the team's own June data-plane read (Forbidden SecretDisabled)
  proving versionless = latest version, disabled-latest errors with no fallback; seeds a future apex
  outage via import-disabled poll window. SAN validity for the bare apex is SOUND (exact dNSName SAN
  match, RFC 9525); core diagnosis, force-re-pull, thumbprint gate, and all load-bearing identifiers
  reconcile cleanly. Scope reviewed: output/rca.md, how-to-fix.md, how-to-recreate-this-rca.md,
  kv-cert-inventory-20260721.txt, and the June antecedent (spec, how-it-works, execution-evidence).
---

# DEMOLEDOR REPORT — INC0264497 RCA + fix

**Target:** the causal mechanism and the applied fix (NOT evidence-labels/prose — that is another reviewer's lane).
**Verdict:** 1 HIGH confirmed factual error, 4 MEDIUM completeness/failure-mode gaps, 3 LOW. The *core diagnosis and the applied post-fix served state survive attack* (see "What survived"). But the RCA states a load-bearing certificate-resolution mechanism **wrong**, contradicting the team's own June data-plane evidence, and that error is the seed of the next apex outage.

## Destruction summary

| Metric | Count |
|---|---|
| Findings | 8 (1 HIGH, 4 MEDIUM, 3 LOW) |
| — EXPLOIT-VERIFIED (contradicted by captured evidence) | 1 (D1) |
| — PATTERN-MATCHED / completeness breaks | 4 (D2, D3, D4, D6) |
| — THEORETICAL / unexamined failure modes | 3 (D5, D7, D8) |
| Wrong load-bearing identifier/thumbprint/date/object/sub | 0 confirmed wrong (1 unsupported-precision date, D7) |
| Highest-value break | D1 — "latest **enabled** version" is false; real semantics = latest version, disabled-latest = hard 403, no fallback |

---

## D1 — [HIGH] [EXPLOIT-VERIFIED] "Versionless URI resolves to the latest ENABLED version" is FALSE — it resolves to the latest version, and a disabled latest version ERRORS with no fallback

**Where (3 places, all load-bearing):**
- RCA `L5` line 126: *"A versionless URI resolves to the **latest enabled version** of the object."*
- RCA Context Ledger line 74: *"resolves to the **latest enabled version**."*
- how-to-fix step 5 invariant line 34 frames enable as simply making "versionless URI resolve to the valid cert."

**The break (CONFIRMED by the team's own June A1 data-plane observation):**
`execution-evidence.md` Step 3 FINDING (lines 50–58), captured 2026-06-25 11:41:
```
az keyvault secret show (versionless) -> (Forbidden) SecretDisabled
=> KV versionless resolves to LATEST version; if latest is disabled it ERRORS (no fallback to latest-enabled).
=> RISK WINDOW open until Step 5 (enable): if AGW polls now, fetch fails -> possible listener auto-disable.
```
So the correct semantics is: **versionless = latest version by creation, PERIOD.** If that latest version is disabled, the data-plane GET returns `403 SecretDisabled` — Key Vault does **not** skip back to the newest *enabled* version. The RCA asserts the opposite of what the operators proved five weeks earlier in this very cert object.

**Internal contradiction (the package disagrees with itself):** how-to-fix line 41 (rollback boundary) states the truth — the listener "can auto-disable when the versionless URI resolves to a **disabled/absent version**." That is correct and directly contradicts L5/Context-Ledger's "latest enabled version." The RCA thus carries both the right and the wrong model; a reader who trusts L5 is misled.

**Break scenario / consequence (why this is HIGH, not cosmetic):** The error is benign for the *current* served state (the new version is latest **and** enabled, so versionless → new — apex is fine today). It is dangerous for the **next operator reusing this runbook**: believing "latest enabled wins," they import a new apex version **disabled** (exactly what how-to-fix step 3 tells them to do) and treat the pre-enable window as harmless. During that window the disabled new version is *latest*; if the AGW hits its ~4h poll or any config touch triggers a re-pull, the versionless GET returns `403 SecretDisabled` → **listener auto-disable → full apex outage** (connection failure — strictly worse than the expired-cert interstitial, which at least still completed a handshake). The June evidence names this exact "RISK WINDOW"; the RCA's wording erases it.

**Evidence grade:** EXPLOIT-VERIFIED — not theory; the failing GET (`Forbidden SecretDisabled`) was already observed and logged in `execution-evidence.md`.

**Severity gate:** Exploitability HIGH (the runbook itself instructs import-disabled) × Impact HIGH (full apex outage / listener auto-disable) × Confidence HIGH (observed) → but **capped to HIGH not CRITICAL** because the *currently delivered* state is correct; the danger is latent in reuse. Net: **HIGH**.

**Counter-hypothesis:** *"Maybe Azure changed behavior, or maybe 'latest enabled' is a harmless simplification since the operator always enables promptly."* Rejected: the same package's rollback section (line 41) and the June log both encode the strict "latest version, disabled=error" semantics, and Step 3 explicitly flags the poll-window as a live outage risk. It is not a harmless simplification — it deletes the one caveat that prevents an outage. I would switch only if a current data-plane probe showed versionless now falling back to latest-enabled; the 2026-06-25 capture shows it does not.

---

## D2 — [MEDIUM] [PATTERN-MATCHED] Definition of "done" is too narrow — it proves a valid leaf on the wire but never proves the app is usable (the `/forbidden` secondary symptom is not re-checked post-fix)

**Where:** RCA `L9` and how-to-fix "Verification" line 45 define done as: `notAfter=Dec 30 2026` + thumbprint match + "browser reload … shows the padlock with no `NET::ERR_CERT_DATE_INVALID`." L12 line 232 notes that clicking "Continue (unsafe)" during the outage landed users on `/forbidden` (screenshot 03).

**The break:** The verification confirms *TLS terminates with a valid cert*. It never confirms a normal navigation reaches the actual VPP UI (login/OAuth page) rather than `/forbidden` or another error. `/forbidden` is treated purely as "what you get from proceeding past an untrusted cert" and is never investigated as a possibly-independent layer (WAF rule / OAuth / authz). If `/forbidden` had any cause independent of the expired leaf, the incident is declared fixed (valid cert on wire) while users remain blocked.

**Consequence:** False "resolved." On-call closes INC0264497 on a green handshake; users still hit `/forbidden`; the ticket re-opens. CONFIRMED gap in the verification steps; the independent-`/forbidden` cause is PLAUSIBLE (unexamined).

**Counter-hypothesis:** `/forbidden` is genuinely just the untrusted-cert landing and disappears with a valid cert. Plausible — but the RCA asserts this by omission, not by a post-fix probe that loads real app content. One `curl`/browser check reaching the login page post-fix would settle it; it was not done. I favor flagging because "verify on the wire, never on an exit code" is the RCA's own creed, and a leaf handshake is itself a control-plane-adjacent proxy for "the product works."

---

## D3 — [MEDIUM] [PATTERN-MATCHED] The "fix-forward only, no rollback" framing omits a strictly-safer recovery that existed

**Where:** how-to-fix "Rollback boundary" line 41 + "Certificate source decision" lines 18–21 present exactly two forward options: (i) import the June wildcard PFX as a new version of `p-vpp-eneco-com` (chosen), or (ii) order a dedicated cert. RCA `L8`/Knowledge-Contract item 5 frames the chosen path as *the* safe repair.

**The break:** A third path was available and lower-risk: **repoint the apex ssl-cert `vpp-frontend-https` at the already-valid, already-enabled wildcard Key Vault object's versionless URI** (`…/secrets/wildcard-vpp-eneco-com`, thumb `B8202DE2…`, exp 30 Dec 2026). That reaches the **identical end-state** the RCA settled for — "apex served by the wildcard leaf via SAN" — but as a **pure control-plane AGW `ssl-cert update`**:
- no Key Vault firewall opening (D-plane exposure avoided entirely),
- no `certificate import`,
- **no import-disabled → enable window** (so the D1 outage window never opens),
- no new version added to the already-catalogued naming sprawl.

The reasoning "there is no rollback because the prior apex version is expired" is **logically sound** (nothing valid to roll back *to* inside `p-vpp-eneco-com`). But the leap from "no rollback" to "the chosen import path is the safe recovery" is incomplete: a fewer-mutation, zero-data-plane recovery producing the same served bytes was not enumerated.

**Consequence:** The team opened the prod KV firewall and ran a data-plane import (and, per how-to-fix line 51, briefly exposed the SP secret in plaintext) to achieve something reachable by a single reversible control-plane update. CONFIRMED omission. Trade-off to acknowledge (not a rebuttal): the chosen path keeps "one object per host" and makes a future dedicated-apex swap a same-object import — a real design merit, but orthogonal to *recovery safety*.

**Counter-hypothesis:** Pointing two ssl-certs at one KV object is operationally muddier and the team preferred object-per-host hygiene. Fair — but that is a *design-cleanliness* preference, and the docs sell the chosen path on *safety*, where the repoint dominates. I would withdraw if the apex listener required a distinct ssl-cert object for unrelated config reasons; nothing in the evidence indicates that (both are plain KV-referenced ssl-certs).

---

## D4 — [MEDIUM] [THEORETICAL] Reusing a *different* leaf (new public key/thumbprint) breaks any client that pins the apex certificate or SPKI — never considered

**Where:** RCA assumes the apex has only browser clients (`L1`, `L12`). The fix swaps the apex from its dedicated `CN=vpp.eneco.com` leaf (thumb `8332A22F…`) to the wildcard leaf (`CN=*.vpp.eneco.com`, thumb `B8202DE2…`) — a **different public key and different thumbprint**, not a same-key renewal.

**The break:** Any non-browser consumer that pins the old apex certificate or its public key (mobile app cert-pinning, a service-to-service integration, a synthetic monitor, an HPKP-style pin) will fail the handshake against the new leaf even though it is valid and unexpired — pinning validates *identity*, not *validity window*. A same-key renewal would have preserved SPKI pins; a leaf-reuse does not.

**Consequence:** Silent breakage of pinned clients while browsers are green. PLAUSIBLE (no evidence of pinning exists, but the apex is a production auth front door and pinning was never checked). This risk is *specific to the reuse approach* and would not exist for a dedicated same-key apex renewal — so it belongs in the fix's residual-risk list, which currently only mentions revocation-coupling (how-to-fix line 49).

**Counter-hypothesis:** It's a web UI; nobody pins it. Probably true — but "probably" is exactly the unexamined assumption the RCA's zero-tolerance creed targets. One question to the app team ("does anything pin vpp.eneco.com?") closes it; it was not asked.

---

## D5 — [MEDIUM] [THEORETICAL] HSTS posture unexamined — and the "Continue (unsafe) → /forbidden" narrative implies either no HSTS (a security gap) or a worse blast radius than described

**Where:** RCA `L12` line 232 + screenshot 03 describe users clicking "Continue (unsafe)" past the `ERR_CERT_DATE_INVALID` interstitial. HSTS is never mentioned anywhere in the package.

**The break:** For a `NET::ERR_CERT_DATE_INVALID` error, Chrome/Firefox present a "Proceed anyway" affordance **only when HSTS is not in force** for the host. The fact that a proceed path existed implies `vpp.eneco.com` did **not** enforce HSTS at that moment — a notable security gap for an OAuth-protected production app, and a fact the RCA neither notices nor records. Conversely, **if** HSTS were (or becomes) enabled with a cached policy, a recurrence would **hard-block every prior visitor with no bypass** — a materially larger blast radius than the "interstitial you can click through" the RCA depicts.

**Consequence:** Either an unflagged security posture gap (no HSTS on a login app) or an understated worst-case blast radius. PLAUSIBLE both ways; the RCA analyzes neither.

**Counter-hypothesis:** The proceed screen came from an internal/AVD browser profile without HSTS state, not from production posture. Possible — but that only reinforces that HSTS was never checked; the recurrence blast radius for real users remains uncharacterized.

---

## D6 — [LOW] [PATTERN-MATCHED] Apex "no Terraform drift / objects not Terraform-managed" is extrapolated from the June *wildcard* verification, not proven for the apex

**Where:** RCA `L5` line 126 states as fact, for the apex: *"there is no Terraform drift (the certificate objects are not Terraform-managed; the gateway binding stores the versionless URI)."*

**The break:** The June drift-check (`how-the-vpp-tls-rotation-works.md` step 6, lines 106–115) proved "no `azurerm_key_vault_certificate`" and a versionless binding **for `wildcard-vpp-eneco-com` / `wildcard-vpp-frontend-https`** — not for the apex `p-vpp-eneco-com` / `vpp-frontend-https`. The apex runtime binding *is* versionless (proven by `agw-served-certs-decoded.txt`), and how-to-fix step 0 re-checks that at runtime — but "the apex object is not Terraform-managed" is inherited from the wildcard result, never directly grepped for the apex object. If the apex ssl-cert is IaC-managed with a versioned/pinned value, a manual import could drift or be reverted.

**Consequence:** LOW — mitigated because the prod pipeline is `trigger: none` (June, so no surprise auto-apply) and the runtime binding is versionless. Still, the "not managed" clause for the apex is INFER dressed as FACT.

**Counter-hypothesis:** The whole vault follows one convention, so wildcard-unmanaged implies apex-unmanaged. Likely — but "likely" ≠ the grep that was actually run for the wildcard and never re-run for `p-vpp-eneco-com`.

---

## D7 — [LOW] [THEORETICAL] Fabricated precision: timeline "2026-06-15 : Wildcard leaf issued" has no cited source; the pre-fix apex thumbprint is unverifiable from the saved proofs

**Where:** RCA `L7` timeline line 139: *"2026-06-15 : Wildcard leaf issued (Networking4All)."*

**The break:** No captured evidence gives a 15-June issuance date. The June docs say only "starts mid-June"; the cert's `notBefore` was never recorded. The "15 June" almost certainly derives from the PFX filename prefix `26061584690-…` (a `260615` date code), which is a filename convention, not the certificate's issuance field — presented in the timeline as an observed fact without a label.
Separately, the **pre-fix apex thumbprint `8332A22F…54E098`** (RCA `L4` line 119, Evidence Ledger claim 3, how-to-fix step 2) cannot be reproduced from `kv-cert-inventory-20260721.txt`, because that inventory was captured **post-fix** and shows `p-vpp-eneco-com` already overwritten with `B8202DE2…`. The `8332A22F` value rests entirely on an ephemeral session read; a cold-replay operator following `how-to-recreate-this-rca.md` after the fix cannot re-witness it. Not *wrong* — just not reproducible from the artifacts the package ships.

**Consequence:** LOW / cosmetic-to-evidence-boundary. Minor fake precision + one non-reproducible identifier.

**Counter-hypothesis:** The `260615` filename is a reliable proxy for issuance. Maybe — but then say so and label it, rather than asserting a calendar fact.

---

## D8 — [LOW] [THEORETICAL] Old expired apex version left ENABLED inside `p-vpp-eneco-com` compounds with the D1 mis-model to make future rotations of this object fragile

**Where:** The fix imports + enables the new apex version but never disables the prior expired version (thumb `8332A22F…`, exp 20 Jul). The inventory already shows 8 expired-but-enabled certs; `p-vpp-eneco-com` now holds an enabled-expired version *and* an enabled-valid version.

**The break:** Harmless today (versionless → *latest* = the new valid version). But paired with the true "latest version wins, even if disabled" semantics (D1), the next rotation of this now-multi-enabled object has zero margin: import a new version disabled → it becomes latest → versionless errors → outage. Leaving stale enabled versions removes the "at least an older enabled version is around" mental comfort that the RCA's wrong model implies exists.

**Consequence:** LOW now; a force-multiplier on D1 later.

**Counter-hypothesis:** Cleanup is tracked in the toil-removal proposal. If so, fine — but the *serving-safety* interaction with D1 is not called out where it matters (the fix doc).

---

## Attacks that FAILED — what survived demolition (stated, per zero-tolerance honesty)

- **(a) SAN validity for the bare apex — SOUND.** The reused leaf's SAN is `{*.vpp.eneco.com, vpp.eneco.com}` (June `openssl -ext subjectAltName`, execution-evidence, and inventory all agree). RFC 6125 / RFC 9525 hostname matching: a client matches the reference identity against SAN `dNSName` entries; `vpp.eneco.com` is present as an **exact literal** SAN entry, so the match is unambiguous. Modern browsers (Chrome/Firefox/Safari) ignore CN and validate against SAN, so `CN=*.vpp.eneco.com` is irrelevant to acceptance. The wildcard entry alone would NOT match the apex (a wildcard matches exactly one left label; the apex has none) — the RCA states this correctly at `L4` line 122. The leaf is already CT-logged and serving four public sub-domains without CT/chain errors, so CT is satisfied. **Only** rejection scenario is a legacy client that predates SAN and reads CN only — not a "modern browser," and not this AVD-internal web-UI audience. The SAN reasoning is correct; I could not break it.
- **Core diagnosis — SOUND.** "Apex is a separate KV object (`p-vpp-eneco-com`), deferred in June, expired 20 Jul, browser clock correct" is fully evidenced (screenshots, control-plane binding `agw-served-certs-decoded.txt`, June scope table). The false-explanation rejections ("June rotation broke it", "the 30-Nov cert proves health") are correct.
- **Force-re-pull mechanism — SOUND.** Versioned→versionless toggle to force an immediate re-fetch is MS-doc-verified (Resolution E) and was **wire-verified** on the apex (served `notAfter=Dec 30 2026`, thumb `B8:20:2D:E2:…:BD:E7`).
- **Thumbprint gate — SOUND.** local == vault == `B8202DE2…` is a genuine pre-exposure identity gate.
- **Identifier cross-check — CLEAN.** Subscription `f007df01-9295-491c-b0e9-e3981f2df0b0`, gateway `vpp-ag-p`, KV `vpp-appsec-p`/`mcprd-rg-vpp-p-res`, objects `p-vpp-eneco-com` / `wildcard-vpp-eneco-com` / `vpp-eetpv-com`, ssl-certs `vpp-frontend-https` / `wildcard-vpp-frontend-https` / `vpp-prd-eetpv-com`, new thumb `B8202DE2…BDE7`, dates (apex 20 Jul, old wildcard 1 Jul, new leaf 30 Dec, eetpv 29 Nov), and the "5 expired CN=vpp.eneco.com objects under 5 names" count all reconcile across RCA ↔ inventory ↔ June evidence. **No wrong load-bearing identifier, thumbprint, expiry, object, or subscription found** (the only date blemish is the unsourced 15-Jun issuance, D7).
- **Post-fix served state — SOUND.** Apex currently serves the valid Dec-30 leaf; versionless → latest = new enabled version. Today's apex is genuinely fixed.

## Adversarial self-check

- **Pattern-matching audit:** D1 is not a pattern-match — it is contradicted by the team's own captured `Forbidden SecretDisabled` read; it survives. D4/D5 are explicitly graded THEORETICAL (no evidence of pinning or HSTS state); they are flagged, not asserted as breaks.
- **False-positive conditions named per finding** (counter-hypotheses above).
- **Redundancy / root cause:** D1 and D8 share a root (the versionless-resolution model + stale enabled versions); reported as one HIGH (D1) with D8 as its temporal force-multiplier, not double-counted. D2 and D5 both touch "definition of done / blast radius" but attack different layers (app-content vs. HSTS) — kept separate.
- **Severity-inflation check:** D1 held at HIGH (not CRITICAL) because the delivered state is correct; the danger is reuse-latent. D3 held at MEDIUM (the chosen fix worked; a safer path merely existed). No finding inflated to CRITICAL.

## Recommended tandem (coordinator to execute — I cannot dispatch)

- `verification-engineer` — add a post-fix app-content probe (login page reachable, not `/forbidden`) to close D2 before ticket closure.
- `neo-hacker` / trust-boundary frame — confirm HSTS posture on `vpp.eneco.com` (D5) and any client pinning (D4).

*El Demoledor: proving resilience through destruction. The apex is up today; the RCA's mechanism text is the crack that reopens it.*
