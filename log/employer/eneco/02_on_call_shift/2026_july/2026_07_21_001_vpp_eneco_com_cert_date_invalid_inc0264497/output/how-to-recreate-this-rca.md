---
title: "How To Recreate This RCA from cold"
incident: INC0264497
timestamp: 2026-07-21
status: complete
---

# How To Recreate This RCA

A pass/fail replay contract: another engineer or agent, with no memory of this incident, can rebuild the diagnosis by following these steps in order. If any step needs hidden knowledge not written here, the RCA has failed — report it.

## Recreation Knowledge Contract

After following this doc you can: reproduce the binding-chain diagnosis (listener → ssl-cert → Key Vault object) from cold; confirm the expiry from the authoritative surface; establish why the wildcard reuse is valid; and know which evidence is live-reproducible versus retained-only.

## Preconditions

- Azure CLI logged in with **Reader** on the prod VPP subscription `f007df01-9295-491c-b0e9-e3981f2df0b0` (control-plane reads need only Reader; the vault data-plane read additionally needs the operator IP whitelisted — see Replay step 4).
- `openssl` (3.x, or LibreSSL for the wire handshake only).
- Access to an **AVD / internal-network** session for the wire proof (the apex listener is on a private frontend; public DNS for `vpp.eneco.com` does not resolve).
- The June antecedent folder for the certificate material and prior runbook: `../antecedents/2026_06_24_renewal_vpp_tls_certificates/`.

## Source Inventory

| Source | What it settles | Access |
|---|---|---|
| Screenshots `proofs/screenshots/01,02` | The symptom + correct browser clock | in-repo |
| `az` control-plane on `vpp-ag-p` | Listener → ssl-cert → Key Vault object binding | Reader on prod sub |
| Portal "Listener TLS certificates" blade OR data-plane `az keyvault certificate show` | The bound object's expiry + thumbprint | portal (any Reader) or SP + firewall |
| Local `openssl pkcs12` on the June PFX | The reused cert's SAN + validity | in-repo antecedent |
| AVD `openssl s_client` | The served leaf on the wire | AVD/internal |
| `proofs/outputs/*` | Retained captures of this session's probes (incl. the pre-fix state the fix overwrote) | in-repo |

## Replay Steps

1. **Reproduce the symptom class.** Read `proofs/screenshots/01,02`: `NET::ERR_CERT_DATE_INVALID`, clock 21 Jul 2026 correct ⇒ not a client-clock issue; a genuine expired-leaf failure.
2. **Find the binding.** `az network application-gateway http-listener list … vpp-ag-p` → the `vpp.eneco.com` row binds ssl-cert `vpp-frontend-https`; resolve its `keyVaultSecretId` (`az … ssl-cert show`) → object `p-vpp-eneco-com`. Branch: if it bound `wildcard-vpp-frontend-https`, the cause would be stale cache, not this object.
3. **Confirm the expiry.** Portal Listener-TLS-certificates blade shows `vpp-frontend-https` = Expired, 20 Jul 2026 (no firewall needed). Expected: `Status=Expired`.
4. **(Optional, authoritative) data-plane read.** ⚠️ **Post-fix caveat:** the fix imported a new version *into* `p-vpp-eneco-com`, so `az keyvault certificate show --name p-vpp-eneco-com` **today returns the fixed cert** (`B8202DE2…`, exp 30 Dec 2026), NOT the expired root-cause state. The pre-fix state (`8332A22F…`, exp 20 Jul 2026) survives only in the retained capture `proofs/outputs/apex-cert-prefix-state-20260721.txt` — read it there; you cannot re-witness it live. (Before the fix, whitelisting the operator IP on `vpp-appsec-p` and running this read returned `attributes.expires=2026-07-20…`, thumb `8332A22F…`; remove the whitelist afterward.) If the vault is **blocked** (default-deny, `ForbiddenByFirewall`), use the portal blade in step 3.
5. **Establish the reuse path.** `openssl pkcs12` on `../antecedents/.../certificate_to_renovate/26061584690-_-vpp-eneco-com.pfx` → SAN `{*.vpp.eneco.com, vpp.eneco.com}`, valid 15 Jun → 30 Dec 2026, thumb `B8202DE2…`. This proves the June wildcard covers the apex.
6. **Read the June scope.** `../antecedents/.../rotation-execution-spec.md` scope table: apex `p-vpp-eneco-com` "Out of scope … exp Jul 20 — separate window". This is the deferral evidence.
7. **Wire proof (post-fix).** From AVD: `openssl s_client -connect vpp.eneco.com:443 -servername vpp.eneco.com` → `notAfter Dec 30 2026`, thumb `B8:20:2D:E2:…:BD:E7`.
8. **Cross-check.** Whitelist + `az keyvault certificate list` on `vpp-appsec-p` → inventory (`proofs/outputs/kv-cert-inventory-20260721.txt`): the three AGW-bound certs valid; five expired apex objects under five names (two distinct leaves).

## Evidence Promotion Rules

Steps 1–8 are directly-observable probes (A1 FACT) except: the identification of the ticket's "30-Nov" certificate as `vpp-eetpv-com` (A2 INFER — nearest match by expiry); and the pre-fix apex object state (step 4), which was A1 *this session* but is **no longer live-reproducible** because the fix overwrote the object — rely on the retained proof file. Any claim that cannot be re-run in your session is downgraded to `UNVERIFIED[blocked]` with the blocking reason named.

## Reproduction Failure Conditions

- No Reader on the prod sub → ask the platform team or use the portal with an account that has Reader; do not guess the binding.
- Vault data-plane `ForbiddenByFirewall` → expected (default-deny). Use the portal Listener-TLS-certificates blade for expiry, or whitelist via the SP path in [how-to-fix.md](./how-to-fix.md).
- No AVD session → the wire proof cannot be produced from a normal laptop; mark the wire step `UNVERIFIED[blocked: no internal path]` and hand off to someone on AVD.
- Expecting to re-read the expired root-cause cert live → it is gone (the fix overwrote the object); use the retained capture.
