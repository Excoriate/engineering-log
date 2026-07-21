---
task_id: 2026-07-21-002
agent: socrates-contrarian
timestamp: 2026-07-21
status: complete
review_lane: EPISTEMIC (label integrity, load-bearing assumptions, cross-section coherence, overclaim, ledger-backs-narrative)
scope_excluded: technical correctness of the fix (owned by a different reviewer)
target: log/employer/eneco/02_on_call_shift/2026_july/2026_07_21_001_vpp_eneco_com_cert_date_invalid_inc0264497/output/
verdict: conditional
summary: |
  Verdict PROBLEMATIC / revise-before-finalize (enum: conditional). Root cause and fix logic are
  sound and well-grounded, but two A1 labels on the most load-bearing claims (the wire-serve proof
  and the pre-fix apex-object state) are not backed by any retained artifact, and the "Confidence:
  high / no uncleared assumption" statement overclaims relative to the evidence actually persisted.
  The binding-chain diagnosis (listener -> ssl-cert -> KV object) is genuinely well-evidenced and
  cross-checks cleanly against the retained JSON/txt proofs. The epistemic weakness is concentrated
  at the two ends of the causal story: (1) the fix-effect claim ("the apex now serves B8202DE2 on
  the wire") is the RCA's self-declared only definition of done, yet its cited artifact (an AVD
  openssl screenshot) is NOT in the retained proof set, and the RCA's own KV != served logic forbids
  substituting any control-plane proof; (2) the pre-fix apex object state (thumb 8332A22F, expiry
  20-Jul, SAN vpp.eneco.com) is labelled A1 but the only persisted data-plane capture (the inventory)
  shows the POST-fix state, and the fix overwrote that same object, so the root-cause evidence is now
  unreproducible and the "recreate from cold" contract silently breaks at steps 3-4. Several
  lower-impact overclaims (blast radius, "eight expired", "re-created every renewal", "6-IP baseline",
  private-frontend inference) follow the same pattern: narrative slightly ahead of the artifact.
---

## Key Findings

- F1 HIGH: wire-serve proof (Claim 7, the only "done") artifact absent from proofs; A1 overclaimed.
- F2 HIGH: pre-fix apex object state (Claim 3) A1 but unpersisted; fix overwrote object -> recreate steps 3-4 unreproducible.
- F3 MED: blast-radius incoherence — L1 "every user"/"customers" vs L3 "private frontend, public DNS doesn't resolve".
- F4 MED: "naming sprawl = new object every renewal" contradicted by duplicate thumbprints (5 objects = 2 distinct leaves).
- F5 LOW-MED: "eight expired certs" miscount (data shows seven); P3 disable-list double-counts vpp-2023-2024.
- F6 LOW-MED: apex "private frontend" + "public DNS doesn't resolve" inferred from listener name / June antecedent, not probed this session.
- F7 LOW: "6-IP baseline" firewall + gate/enable/firewall-restore step outputs (Claim 6) unpersisted, fake precision.
- F8 LOW: Context Ledger status column marks eetpv "Directly observed" — conflates object-exists (A1) with is-the-ticket's-cert (A2).

# Socrates Contrarian — Epistemic Review of INC0264497 RCA

**Lane:** epistemic defects only (label integrity, load-bearing assumptions, cross-section coherence, overclaim, ledger↔narrative fit). I did **not** evaluate whether the fix technically works — that is another reviewer's win condition.

**Steelman (Rule 9).** This is a strong RCA. The central diagnosis — one Application Gateway carries several independent certificate objects with independent expiries; the apex object `p-vpp-eneco-com` had only an expired enabled version; the June rotation deliberately and correctly deferred it — is coherent, matches the antecedent June work, and is backed by real, reproducible control-plane artifacts. The author clearly understands the KV-object/versionless-URI mechanism and repeatedly insists on wire-proof over exit-code. My findings are about where the *labels and confidence language run ahead of the retained evidence*, not about whether the story is true. On the balance of evidence the story is probably true; the defect is that the RCA claims more certainty than its persisted artifacts carry.

**Belief revision during review:** I initially flagged the repeated `adr-001-apex-tls-certificate-lifecycle.md` cross-reference as dangling (a first `find` missed it). A direct `ls` of `output/` confirmed the ADR (and `postmortem.md`) exist. **Finding withdrawn** — the ADR references are valid.

---

## F1 — HIGH — The fix's "only definition of done" (wire handshake) has no retained artifact, yet is labelled A1

**Exact text.** Evidence Ledger Claim 7: *"Post-fix wire: `vpp.eneco.com` serves `notAfter Dec 30 2026`, thumb `B8:20:2D:E2:…:BD:E7` | A1 | AVD `openssl s_client` handshake (operator screenshot)."* L9 renders the handshake as a text blob. how-to-fix.md L43: *"Verification (the only definition of done)… A TLS handshake… Control-plane `Succeeded` is necessary but not sufficient."*

**Defect class.** A1-that-is-really-A2/UNVERIFIED[blocked] + overclaim. The cited artifact ("operator screenshot") is **not** in `proofs/screenshots/` — that directory holds only `01`/`02` (browser error), `03` (forbidden), `04` (ServiceNow). The L9 block is transcribed text, not a captured file. Critically, the RCA's own evidence file `proofs/outputs/agw-served-certs-decoded.txt` records *"(no publicCertData on AGW)"* — i.e. the served bytes **cannot** be recovered from the control plane. So by the RCA's own repeatedly-stated logic (KV object state ≠ what the gateway serves; the ~4h poll / re-pull quirk), the inventory proving the KV object now holds `B8202DE2` does **not** prove the gateway serves it. The one proof that closes that gap is the wire handshake — and it is the single load-bearing claim with no re-inspectable artifact in the retained set.

**Why load-bearing.** "The apex is fixed" flips to "unverified" if the gateway is still serving a cached old leaf. This is the assumption whose falsity most cheaply invalidates the RCA's central conclusion, and it is the worst-persisted.

**If true → the RCA must change:** downgrade Claim 7 from A1 to A2 (or UNVERIFIED[blocked: wire artifact not retained]); persist the AVD handshake output as `proofs/outputs/agw-wire-verify-20260721.txt` (and/or a screenshot) and cite it; and correct the Evidence Ledger "Confidence: high / **no uncleared assumption on … the fix path**" line, which is false while the fix-effect rests on an unpersisted witness.

## F2 — HIGH — Pre-fix apex object state (thumb 8332A22F, exp 20-Jul, SAN vpp.eneco.com) is A1 but unpersisted; the fix overwrote the object, so it is now unreproducible

**Exact text.** Evidence Ledger Claim 3: *"`p-vpp-eneco-com` current cert expired 2026-07-20, thumb `8332A22F…54E098`, CN/SAN `vpp.eneco.com` | A1 | Portal Listener-TLS-certificates blade; data-plane `az keyvault certificate show`."* L4: *"The expired apex leaf (`p-vpp-eneco-com`, thumbprint `8332A22F…54E098`): Subject `CN=vpp.eneco.com`, SAN `vpp.eneco.com`… A single-host certificate."*

**Defect class.** A1 without retained artifact + a broken reproducibility contract. The only persisted data-plane capture, `kv-cert-inventory-20260721.txt`, was taken **post-fix** and shows `p-vpp-eneco-com = B8202DE2…, exp 2026-12-30, CN=*.vpp.eneco.com` (line 9, "APEX (FIXED)"). Nothing in the retained proofs shows `8332A22F`, the 20-Jul expiry, or the single-host `SAN vpp.eneco.com`. The "portal blade" is not screenshotted; the pre-fix data-plane read output is not saved. Because the fix imported a new version **into the same object**, a cold-replay reader following `how-to-recreate-this-rca.md` step 4 (`az keyvault certificate show --name p-vpp-eneco-com`) will today read the **valid** fixed cert — the exact opposite of the "expired" finding — yet the recreate doc's Evidence-labels section asserts *"Steps 1–8 are all directly-observable probes (A1 FACT) except the ticket's 30-Nov identification."* That is false for steps 3–4 post-fix.

**Why load-bearing.** The identity of the *expired object that was served* is the root cause. The "expired" conclusion is independently corroborated by the browser `ERR_CERT_DATE_INVALID` + the proven binding chain, so the **root cause survives**; but the *specific* A1 assertions (thumb 8332A22F, single-host SAN) are not independently observable from retained evidence, and the recreate contract silently fails on them.

**If true → the RCA must change:** persist the pre-fix portal-blade screenshot / data-plane read as a proof artifact, or downgrade the thumbprint+SAN specifics in Claim 3 / L4 to A2; and add a warning to `how-to-recreate-this-rca.md` steps 3–4 that the object was overwritten by the fix and now returns the post-fix state — the expired-state evidence is ephemeral and must be read from a retained capture, not re-run.

## F3 — MEDIUM — Blast-radius incoherence: "every user"/"customers" (L1) vs "private frontend, public DNS doesn't resolve, only AVD/internal" (L3)

**Exact text.** L1: *"every modern browser hard-blocks the page… the entire UI is unreachable… the blast radius is 'the whole product's web entry point'… operators and customers use [it]."* L3: *"the apex path terminates on a private-frontend listener — which is why the reporter could only see it from an AVD session and why public DNS for the host does not resolve."*

**Defect class.** Cross-section incoherence / severity overclaim. If the apex listener is private-frontend-only and `vpp.eneco.com` does not resolve in public DNS, then the affected population is internal/AVD/VPN users, not arbitrary internet "customers." The two sections cannot both be literally true. This changes the *audience* and *severity framing* of a P1.

**If true → the RCA must change:** reconcile who was actually affected. Either (a) L1's "every user / customers" is loose and the real impact is internal/operator/AVD users (soften the blast-radius language), or (b) external customers reach the apex through a private/VPN path and L3's "public DNS doesn't resolve" needs the qualifier that it is still customer-facing via that path. State which, with a probe (a `dig vpp.eneco.com` result would settle it — see F6).

## F4 — MEDIUM — "Re-created under a new object name almost every renewal" is contradicted by duplicate thumbprints

**Exact text.** Exec summary: *"the apex certificate has been re-created under a new object name almost every renewal. The Key Vault holds five expired `vpp.eneco.com` certificates under five different names."* Inventory FINDINGS line 28: *"re-created under a NEW name almost every renewal = naming sprawl."*

**Defect class.** Narrative not backed by the ledger it cites. The inventory shows the five expired `CN=vpp.eneco.com` objects collapse to **two distinct leaves** by SHA1: `23884DBCC697…` is shared by `d-vpp-eneco-com`, `vpp-2023-2024`, and `vpp-eneco-com` (three names, one cert); `AC86C454…` is shared by `prd-vpp-eneco-com` and `prd1-vpp-eneco-com` (two names, one cert). Same bytes under multiple names is **duplication**, not "re-created (issued afresh) every renewal." "Five expired certificates" is really "five objects / two distinct certificates."

**Why it matters (bounded).** The remediation (P2: one stable object per host) is unaffected — five objects is still sprawl. But the causal *characterization* is wrong and would mislead a future reader about whether renewals were re-issued or merely re-imported/copied.

**If true → the RCA must change:** L10 lesson 4, the exec summary, and inventory FINDINGS should say "five objects, two distinct leaves (duplicate thumbprints)" and drop/soften "re-created every renewal" in favour of "the same leaf was re-imported under new names."

## F5 — LOW-MEDIUM — "Eight expired certificates" miscount; the data shows seven

**Exact text.** sre-toil-removal-proposal.md P3: *"eight expired certificates remain `enabled=true` in `vpp-appsec-p`."* Inventory FINDINGS line 26: *"8 expired certs still enabled=true."* P3 action: *"disable the five expired apex-name objects and the expired `esp-eet-…-streaming` / `tms-eetpv` / `vpp-2023-2024`."*

**Defect class.** Fake/incorrect precision (arithmetic). Counting expired rows (EXPIRES < 2026-07-21) in the inventory: `d-vpp-eneco-com`, `esp-eet-vpp-prd-streaming`, `prd-vpp-eneco-com`, `prd1-vpp-eneco-com`, `tms-eetpv-com`, `vpp-2023-2024`, `vpp-eneco-com` = **seven**. P3's own disable-list reaches "eight" only by double-counting `vpp-2023-2024` (it is already one of the "five apex-name objects" *and* is listed again after `tms-eetpv`).

**If true → the RCA must change:** correct "eight" → "seven" in both the proposal and the inventory FINDINGS, and de-duplicate `vpp-2023-2024` in the P3 disable-list.

## F6 — LOW-MEDIUM — Apex "private frontend" and "public DNS does not resolve" are inferred, not probed this session

**Exact text.** L3: *"terminates on a private-frontend listener… public DNS for the host does not resolve."* Context Ledger row for `vpp-frontend-https-private`: Status *"Directly observed."*

**Defect class.** INFER dressed as directly-observed. What is directly observed in `agw-listeners.json` is the listener **name** (`vpp-frontend-https-private`) and its ssl-cert binding — **not** its frontend-IP-configuration, and not a DNS resolution result. The June antecedent verified private frontend `10.9.32.4` for the **wildcard** listeners (PC4), not the apex listener. "Public DNS does not resolve for `vpp.eneco.com`" has no `dig`/`nslookup` artifact in this session's proofs. The private-frontend conclusion underpins F3's severity question, so it is not cosmetic.

**If true → the RCA must change:** either add a `dig vpp.eneco.com` + apex-listener frontend-IP-config probe to the proofs and keep the claim A1, or relabel "private frontend / public DNS doesn't resolve" as A2 INFER (from the listener name + June antecedent).

## F7 — LOW — "6-IP baseline" and the gate/enable/firewall-restore step outputs are unpersisted

**Exact text.** L8: *"firewall back to 6-IP baseline."* Evidence Ledger Claim 6 evidence: *"This session's step outputs (import/gate/enable/re-pull/whitelist-off)."*

**Defect class.** Fake precision + unpersisted A1. The number "6" for the firewall baseline appears nowhere else in the RCA or the proofs; no `az keyvault show … networkAcls.ipRules` capture is retained. The thumbprint-gate match, the enable, and the firewall-restored-to-baseline outcomes are asserted as A1 but rest on session outputs not saved as artifacts. The outcome is partly corroborated by the inventory (object now `B8202DE2`), but the security-relevant "firewall restored" claim is not.

**If true → the RCA must change:** persist the pre/post firewall rule-count captures (this is a security assertion — vault back to default-deny), or drop the specific "6-IP" figure and soften Claim 6's A1 to "outcome corroborated by inventory; intermediate step outputs not retained."

## F8 — LOW — Context Ledger status column conflates "object exists" (A1) with "is the ticket's cert" (A2)

**Exact text.** Context Ledger row `vpp-eetpv-com`: *"The '30-Nov' cert the ticket confused with the apex | Directly observed."* Evidence Ledger correctly labels the *identification* Claim 9 as **A2** (*"nearest match to the ticket claim"*), and notes the 1-day discrepancy (ticket "30-Nov" vs cert 29-Nov) only implicitly.

**Defect class.** Minor label smear. The eetpv object existing is A1; that it is *the cert the ticket meant* is A2. The ledger row marks the whole assertion "Directly observed," which imports the A2 inference under an A1 status. The unexplained 30-Nov vs 29-Nov off-by-one is the exact reason Claim 9 is (correctly) A2 — the Context Ledger should carry the same hedge.

**If true → the RCA must change:** mark the eetpv Context Ledger row status as "Object directly observed; ticket-identification A2 (nearest match, off-by-one date unexplained)."

---

## Sections that are epistemically sound (credited, not padded)

- **Binding chain (Claims 2, 4, 8, 10; L2/L3 tables).** Listener→ssl-cert→KV-object is fully backed and cross-checks cleanly across `agw-listeners.json`, `agw-sslcerts.json`, `agw-served-certs-decoded.txt`, and `kv-cert-inventory-20260721.txt`. `p-vpp-eneco-com` now = `B8202DE2` = `wildcard-vpp-eneco-com` thumbprint: consistent everywhere. The "five expired CN=vpp.eneco.com objects" count (5) is correct.
- **The fix-validity fact (SAN covers apex).** "The wildcard leaf's SAN explicitly lists `vpp.eneco.com`" (L4) is solidly evidenced by `openssl` on the antecedent PFX and corroborated by the June `how-the-vpp-tls-rotation-works.md` live read and the inventory. This is the load-bearing fact for *why the reuse is valid*, and it is well-grounded — no defect.
- **Claim 9 (ticket's cert) honestly labelled A2.** The one inference on the causal periphery is correctly hedged; it does not touch root cause or fix. Good discipline.
- **The RCA correctly separates control-plane success from wire success** in its prose doctrine (L9, how-to-fix). The irony captured in F1 is that it doesn't *retain* the wire artifact it rightly insists on — the doctrine is sound; the evidence retention isn't.

---

## Meta-falsifier (Rule 11)

- **What would prove this review wrong.** (a) The AVD wire-handshake screenshot / a saved handshake output actually exists in the package (a directory I was not pointed at) → F1 collapses to "cite the existing artifact." (b) A retained pre-fix data-plane capture or portal screenshot of `p-vpp-eneco-com` showing `8332A22F`/20-Jul exists → F2 collapses. (c) `dig vpp.eneco.com` genuinely returns NXDOMAIN and the apex listener's frontend IP is the private `10.9.32.4` → F3/F6 soften to "reconcile L1 wording only."
- **My assumptions.** I treated the provided proof set (`proofs/outputs/*`, `proofs/screenshots/01-04`) as the complete retained evidence. If more artifacts exist, F1/F2/F7 weaken proportionally. My "seven vs eight" count (F5) assumes today = 2026-07-21 (per the RCA's own timestamp) as the expiry cutoff.
- **Where I could be pattern-matching.** F4's "duplication vs re-issuance" reads intent from thumbprint equality; it is possible (though the evidence doesn't show it) that identical thumbprints arose from re-importing an unchanged long-lived cert — which is still "not re-issued every renewal," so the finding holds either way.

**Overall verdict: PROBLEMATIC (revise before finalizing).** Root cause and fix reasoning are sound; the required changes are label downgrades (F1, F2), artifact persistence (F1, F2, F7), two coherence reconciliations (F3, F6), and three precision corrections (F4, F5, F8). None of these say the fix is wrong — they say the RCA currently claims more certainty than the retained evidence carries, most acutely on the two claims that matter most.
