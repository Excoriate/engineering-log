---
title: "ADR-001 — Apex vpp.eneco.com TLS certificate lifecycle"
incident: INC0264497
timestamp: 2026-07-21
status: proposed
adversarial_gate: self-reviewed
deciders: VPP Platform Foundations
---

# ADR-001 — Apex `vpp.eneco.com` TLS certificate lifecycle and expiry prevention

## Context and Problem Statement

**Symptom.** On 2026-07-21 production `https://vpp.eneco.com` served an expired leaf; every browser hard-blocked with `NET::ERR_CERT_DATE_INVALID`. Full UI outage (INC0264497).

**Root cause.** The apex listener on Application Gateway `vpp-ag-p` references Key Vault object `p-vpp-eneco-com` through a versionless secret URI and serves its latest enabled version `[per: https://learn.microsoft.com/en-us/azure/application-gateway/key-vault-certs]`. That object's only enabled version expired 2026-07-20. No renewed version had been imported.

**Causal chain.**

```
June rotation renews wildcard-vpp-eneco-com only; apex p-vpp-eneco-com deferred to "separate window" (exp Jul 20)
    ↓ no follow-up scheduled, no expiry alert configured
p-vpp-eneco-com latest enabled version expires 2026-07-20
    ↓ App Gateway keeps serving cached expired leaf (re-pull only on keyVaultSecretId change or ~4h poll) [per: app-gw key-vault-certs]
Browser validates notAfter < now → NET::ERR_CERT_DATE_INVALID → full apex UI outage
```

**Two structural enablers, not one.** (1) The apex is a **separate certificate object** from the wildcard, with an independent expiry that renewing the wildcard does not touch. (2) The apex certificate has been re-created under a **new object name almost every renewal** — `vpp-appsec-p` holds five expired `CN=vpp.eneco.com` objects under five names (`vpp-eneco-com`, `prd-vpp-eneco-com`, `prd1-vpp-eneco-com`, `d-vpp-eneco-com`, `vpp-2023-2024`) — only two distinct certificates by thumbprint, i.e. the same leaf re-imported under new names `[per: proofs/outputs/kv-cert-inventory-20260721.txt]`. This sprawl is why "which object serves the apex and when does it expire" was unclear enough to defer without an owner.

**The gap.**

| Capability | Provided by | Not provided by | Source |
|---|---|---|---|
| Serve a valid apex leaf | Any valid cert whose SAN includes `vpp.eneco.com` | An expired object version | `[per: RFC 6125 §6.4.3 — wildcard matches one label; SAN drives validation]` |
| Notify before expiry | Key Vault near-expiry event/metric (not configured) | The gateway itself | `[per: https://learn.microsoft.com/en-us/azure/key-vault/general/overview-security-worlds]` `[INFERENCE]` |
| Track "which object per host" | A stable object-naming convention (absent) | Ad-hoc per-renewal object names | `[per: kv-cert-inventory-20260721.txt]` |

**Scope.**
- IN: which certificate strategy serves the apex going forward; the controls that prevent silent expiry.
- OUT: the four sub-domains and `vpp.prd.eetpv.com` (separate objects, valid to 30 Dec / 29 Nov 2026); the prod SP credential-handling follow-up (tracked in the RCA residual risk).

## Decision Drivers

| # | Driver | Category | Weight | Measurable criterion | Source |
|---|---|---|---|---|---|
| D1 | No silent expiry recurrence | Non-functional (reliability) | MUST | An alert fires ≥7 days before any apex-bound cert expiry | INC0264497 |
| D2 | Minimize independently-tracked expiry surfaces | Non-functional | SHOULD | Count of distinct apex-relevant expiry dates ≤ the wildcard's | RCA L10 |
| D3 | Time-to-restore under a future expiry | Operational | MUST | Fix reproducible in <15 min with material already in hand | This incident (fixed in ~10 min) |
| D4 | No new vendor-issuance dependency on the hot path | Organizational | SHOULD | Restore does not block on Networking4All issuance | June runbook vendor gate |
| D5 | Configuration legibility | Non-functional (maintainability) | SHOULD | Object name states the host it serves | kv-cert-inventory sprawl |
| D6 | No Terraform drift / auto-rotation preserved | Non-functional | MUST | Gateway binding stays on the versionless URI stored in IaC | `[per: app-gw key-vault-certs]` |

## Options Analysis

### Option A1 — Keep `p-vpp-eneco-com`, import the wildcard leaf each renewal (the applied fix)

**Mechanism.** Import the `*.vpp.eneco.com` leaf (SAN includes `vpp.eneco.com`) as a new version of `p-vpp-eneco-com`; the versionless binding is unchanged; force re-pull `[per: app-gw key-vault-certs]`. The apex thus shares the wildcard's expiry (30 Dec 2026).
**Evaluation.** D1 ✗ (no alert yet — needs the controls below) · D2 ✓ (apex expiry == wildcard expiry, one date to track) · D3 ✓ (material already in vault) · D4 ✓ (no vendor) · D5 ✗ (object named `p-vpp-eneco-com` holds a wildcard leaf — misleading) · D6 ✓.
**Failure mode.** A future wildcard renewal that forgets to also re-import into `p-vpp-eneco-com` leaves the apex on the old wildcard version → silent divergence. Detection: the D1 alert. Recovery: re-import.
**Falsifier.** Wrong if the wildcard leaf ever stops listing `vpp.eneco.com` in its SAN (a future re-issue as a pure `*.vpp.eneco.com` cert) — then it no longer covers the bare apex.
**Reversal cost.** ~0. It is the current state; switching to any other option is additive.

### Option A2 — Repoint the apex listener to the wildcard ssl-cert; retire `p-vpp-eneco-com`

**Mechanism.** Change listener `vpp-frontend-https-private` to use ssl-cert `wildcard-vpp-frontend-https` (→ `wildcard-vpp-eneco-com`); the apex ceases to be a distinct object. One certificate object serves all five VPP hosts. This was also the **lower-risk immediate recovery** for INC0264497 — a single reversible control-plane update, versus the firewall-opening data-plane import that was actually used (see how-to-fix).
**Evaluation.** D1 ✓ (one object to alert on) · D2 ✓✓ (apex is no longer a separate surface at all) · D3 ✓ · D4 ✓ · D5 ✓ (no misleading object) · D6 ✗ **at change time** — the listener→ssl-cert binding is Terraform-managed; repointing is a config change that must go through IaC or it drifts `[INFERENCE: June found the AGW bindings in Terraform via versionless URI]`.
**Failure mode.** A wildcard leaf compromise/revocation now rotates the apex and four sub-domains together (shared fate). Detection: revocation monitoring. Recovery: single rotation covers all.
**Falsifier.** Wrong if policy requires the apex (the primary brand domain) to have an independent certificate for blast-radius isolation.
**Reversal cost.** ~2–4 h: re-create a dedicated apex object and repoint back; blast radius = one listener; no orphaned data.

### Option B — Restore a dedicated apex certificate from Networking4All

**Mechanism.** Order a renewed single-host `vpp.eneco.com` certificate (issued → Zivver → 1Password), import into `p-vpp-eneco-com`, enable, re-pull.
**Evaluation.** D1 ✗ (still needs alerting) · **D2 ✗ — adds a fourth independent expiry surface, the exact condition that caused this incident** · D3 ✗ (restore blocks on vendor issuance) · D4 ✗ (vendor on the hot path) · D5 ✓ · D6 ✓.
**Failure mode.** Its own future expiry, deferred again → identical incident. Detection: D1 alert (if configured). Recovery: vendor re-issue.
**Falsifier.** Wrong unless a concrete policy mandates a dedicated apex certificate; absent that, it multiplies the failure surface for a cosmetic gain.
**Reversal cost.** ~1 h to abandon in favour of A1 (re-import wildcard); vendor cost already sunk.

### Option C — Managed / auto-renewed certificate (eliminate manual renewal)

**Mechanism.** Bind the object to a Key Vault **integrated CA** (DigiCert/GlobalSign) so Key Vault auto-renews before expiry `[per: https://learn.microsoft.com/en-us/azure/key-vault/certificates/how-to-integrate-certificate-authority]`, or run ACME automation. The versionless gateway binding then always resolves to a fresh version.
**Evaluation.** D1 ✓✓ (removes the manual step entirely — attacks the root cause) · D2 ✓ · D3 ✓ (no manual restore) · D4 depends · D5 ✓ · D6 ✓.
**Failure mode.** The integrated CA does not include the current issuer (Trust Provider B.V. / Networking4All reseller), so migration means changing CA — a larger governance change. Detection: pre-flight CA-support check. Recovery: fall back to A1 + alerting.
**Falsifier.** `[SPECULATION]` Wrong if Networking4All / Trust Provider B.V. cannot be used as a Key Vault integrated CA and switching CA is disallowed — then auto-renew is not available without an ACME/vendor change. Falsifier test: confirm whether the current issuer is a supported Key Vault CA integration.
**Reversal cost.** High to adopt (CA governance); low to abandon back to A1.

## Decision Outcome

**Chosen: Option A1 as the standing state (already applied), with the prevention controls below made MANDATORY, and Option C evaluated as the strategic direction. Option B rejected.**

Rationale against the MUST drivers: A1 satisfies D3 (restore in ~10 min with in-vault material — demonstrated this incident), D4 (no vendor on the hot path), and D6 (versionless binding preserved). It does **not** satisfy D1 alone — which is why the controls below are not optional add-ons but part of this decision. A1 also best serves D2 by collapsing the apex expiry into the wildcard's single date.

**Option B is rejected** because it fails D2, D3, and D4: a dedicated apex certificate re-introduces an independent expiry surface — the precise structural condition that produced INC0264497 — in exchange for only cosmetic separation (D5), and it puts vendor issuance back on the restore path. Steelman for B: brand-domain blast-radius isolation. Rejected because that isolation is only valuable if paired with per-object alerting, and the same alerting on A1 gives the reliability benefit without the extra surface.

**Option A2 (retire the apex object) is deferred, not rejected:** it is the cleanest end-state for D2/D5 but requires an IaC change to the gateway binding (D6 at change time) and a policy decision on shared-fate. Adopt A2 if/when the naming-discipline work (P2 below) touches the gateway IaC.

### Mandatory prevention controls (part of this decision)

These address the systemic cause and are required regardless of A1/A2/C. Detail and reversible next actions in [sre-toil-removal-proposal.md](./sre-toil-removal-proposal.md).

1. **Expiry alerting (satisfies D1).** Key Vault near-expiry alert at 30 and 7 days for every AGW-bound object (`p-vpp-eneco-com`, `wildcard-vpp-eneco-com`, `vpp-eetpv-com`) → VPP on-call action group.
2. **One stable object name per host (satisfies D5, enables D2).** Renewals import a new **version** of the bound object; never a new object.
3. **Retire expired residue.** Disable-then-delete the eight expired objects after a no-consumer check.
4. **Deferrals become tracked items.** Any "separate window" in a change spec creates a dated follow-up; not done until the follow-up exists.

### Re-evaluation triggers

- Networking4All/Trust Provider confirmed (or not) as a Key Vault integrated CA → re-open Option C.
- A policy mandating a dedicated apex certificate → re-open Option B with alerting.
- The naming-discipline work reaching the gateway IaC → adopt Option A2.

### Reversal

The decision is low-cost to reverse: A1 is the current state, so moving to B, C, or A2 is additive. The controls (1–4) are independently valuable under any option and carry no reversal cost.

## Devil's advocate (self-reviewed; external gate degraded per skill compatibility clause)

| Question | Answer |
|---|---|
| Pre-mortem: what breaks in 6 months? | A wildcard renewal forgets to re-import into `p-vpp-eneco-com` (Option A1 divergence). Mitigated by control 1 (alert fires ≥7 days out) and, ultimately, by Option A2 (no separate object). |
| Steelman the rejected alternative (B)? | Dedicated apex cert isolates the brand domain's blast radius. Rejected: isolation without per-object alerting is what failed here; A1 + alerting delivers the reliability without the extra expiry surface. |
| Load-bearing assumption? | The wildcard leaf's SAN includes `vpp.eneco.com`. Verified on the wire and by local openssl this incident (thumb `B8202DE2…`, notAfter 30 Dec 2026). Falsifier: a future re-issue that drops the apex SAN entry. |
| What will confuse a new engineer? | An object named `p-vpp-eneco-com` holding a `*.vpp.eneco.com` leaf. Clarified by control 2 (naming) and the RCA L2 host→object table; resolved permanently by Option A2. |

## References

- App Gateway certificates from Key Vault + versionless refresh: <https://learn.microsoft.com/en-us/azure/application-gateway/key-vault-certs>
- App Gateway ↔ Key Vault common errors: <https://learn.microsoft.com/en-us/azure/application-gateway/application-gateway-key-vault-common-errors>
- Key Vault certificate renewal / near-expiry: <https://learn.microsoft.com/en-us/azure/key-vault/certificates/overview-renew-certificate>
- Key Vault integrated certificate authority: <https://learn.microsoft.com/en-us/azure/key-vault/certificates/how-to-integrate-certificate-authority>
- SAN / wildcard matching: [RFC 6125 §6.4.3]
- Incident RCA: [rca.md](./rca.md) · Fix: [how-to-fix.md](./how-to-fix.md) · Prevention: [sre-toil-removal-proposal.md](./sre-toil-removal-proposal.md)
