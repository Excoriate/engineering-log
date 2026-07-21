---
title: "How To Fix — apex vpp.eneco.com expired TLS certificate"
incident: INC0264497
timestamp: 2026-07-21
status: complete
---

# How To Fix — apex `vpp.eneco.com` expired TLS certificate

This is the repair companion to [rca.md](./rca.md). It explains *why* each action closes the failure, not just what to type. The exact commands live in the June antecedent runbook ([manual-execution-runbook.md](../antecedents/2026_06_24_renewal_vpp_tls_certificates/manual-execution-runbook.md)); this doc adapts them to the apex object and names the invariant each step restores.

## Fix Knowledge Contract

After this doc you can: choose the safest recovery path for an expired App-Gateway-bound apex certificate; run the import-based repair with a thumbprint gate; explain why steps 3→5 must be fast; verify on the wire rather than on an exit code; and name the residual risks the leaf-reuse approach carries.

## Mechanism Recap

The apex listener serves whatever the versionless Key Vault reference `…/secrets/p-vpp-eneco-com` resolves to — the **latest version by creation**, not the latest *enabled* (a disabled latest version errors `403 SecretDisabled` with no fallback). Its only enabled version expired 20 July 2026, so the gateway keeps serving expired bytes. The repair stages a **valid new version** of that object and forces the gateway to fetch it.

## Certificate source / recovery decision (make this first)

Three paths reach the same served end-state (apex served by the valid wildcard leaf). This incident used the second; the **first is the lowest-risk recovery** and is what a future on-call should prefer for a pure restore.

- **(Safest recovery) Repoint the apex ssl-cert at the wildcard object.** Change ssl-cert `vpp-frontend-https` to reference `…/secrets/wildcard-vpp-eneco-com` (already valid, already enabled). A single reversible control-plane `az network application-gateway ssl-cert update` — **no Key Vault firewall opening, no import, no import-disabled window** (so the resolution risk below never opens). Caveats: verify the apex listener→ssl-cert binding is not IaC-pinned first (or repoint in Terraform to avoid drift); it points two ssl-certs at one object (less "one object per host").
- **(Used here) Reuse the June wildcard leaf by importing it into `p-vpp-eneco-com`.** Valid to 30 Dec 2026, SAN already contains `vpp.eneco.com`. No vendor order. Chosen to keep object-per-host continuity and mirror the proven June runbook — but it required opening the KV firewall and a data-plane import to reach a state the repoint reaches with one control-plane call. Trade-off: the object then holds a `*.vpp.eneco.com` leaf (functionally valid, cosmetically odd).
- **(Clean, slow) Order a dedicated apex cert from Networking4All.** Preserves a dedicated `vpp.eneco.com` certificate. Slower (vendor issuance via Zivver → 1Password). See [the ADR](./adr-001-apex-tls-certificate-lifecycle.md).

## Fix Plan

Identity: production SP on subscription `f007df01-…` (a personal account has Reader only and cannot import to the prod vault). Vault `vpp-appsec-p` (RG `mcprd-rg-vpp-p-res`), gateway `vpp-ag-p`.

| # | Action | Plane it closes | Invariant restored | Proof to demand |
|---|---|---|---|---|
| 0 | Log in as prod SP (isolated `AZURE_CONFIG_DIR`); verify `servicePrincipal` + sub `f007df01-…`; confirm `Import` perm; confirm apex ssl-cert on the versionless URI; capture the KV firewall baseline | identity/context | acting as the right principal on the right subscription | `az account show` type=servicePrincipal; certperms include `Import` |
| 1 | Add operator IP `/32` to the KV firewall; wait ~25 s | network (data-plane access) | operator can read/import into the default-deny vault | rule count for the IP = 1 |
| 2 | Baseline the current apex version (SID, thumb, expiry) | record | rollback target captured (here it is expired ⇒ **no rollback**; fix-forward only) | thumb `8332A22F…`, expiry `2026-07-20` |
| 3 | Import the chosen PFX into `p-vpp-eneco-com` **disabled** | vault (staging) | a valid version exists but cannot serve until gated | imported version `enabled=false` |
| 4 | **Thumbprint gate**: local PFX SHA1 == vault version SHA1 == expected | verification-before-exposure | the vault holds exactly the intended cert | `B8202DE2…` on all three |
| 5 | Enable the new version | vault (activation) | versionless URI resolves to the valid cert | versionless latest == `B8202DE2…` |
| 6 | Force gateway re-pull: set ssl-cert to the **versioned** URI, then back to **versionless** | gateway (serving) | gateway serves the new bytes now, not on its ~4 h poll; auto-rotation + Terraform parity preserved | `provisioningState=Succeeded`, binding back on versionless |
| 7 | **(AVD/internal) wire verify** | proof | real clients receive the new leaf | `notAfter=Dec 30 2026`, thumb `B8:20:2D:E2:…:BD:E7` |
| 8 | Remove operator IP from the KV firewall (**mandatory finally**) | network | vault back to default-deny; no residual exposure or drift | firewall count back to baseline |

> **Why steps 3→5 must be quick (the resolution rule).** The versionless URI resolves to the **latest version by creation**, not the latest *enabled*. Between step 3 (import disabled) and step 5 (enable), the new version is the latest and is disabled, so any gateway re-fetch in that window returns `403 SecretDisabled` and can auto-disable the listener (Key Vault does not fall back to an older enabled version — the team observed this on this object in June). Move briskly import → gate → enable. The repoint recovery avoids this window entirely.

## Rollback boundary

There is **no rollback** for this incident: the prior apex version is already expired, so repointing to it restores another expired cert. This is **fix-forward only**. If step 6 leaves the listener unable to fetch (it can auto-disable when the versionless URI resolves to a disabled/absent version), recover by ensuring the new version is enabled and re-running step 6 — do not repoint to the old version.

## What This Fix Does Not Change

- It does not order a dedicated apex certificate — the apex is now served by the wildcard leaf (valid via SAN).
- It does not touch the four sub-domains or the `eetpv` host.
- It does not add any expiry monitoring — that is left to the follow-up actions.
- It does not disable the old expired apex version inside `p-vpp-eneco-com` (see Residual risk).

## Verification (the only definition of done)

A TLS handshake from AVD/internal to `vpp.eneco.com:443` returns `notAfter=Dec 30 2026` and thumbprint `B8:20:2D:E2:…:BD:E7`. Control-plane `Succeeded` is necessary but not sufficient. A browser reload in a fresh Incognito tab shows the padlock with no `NET::ERR_CERT_DATE_INVALID`. **One more check the handshake does not cover:** load the actual VPP login/OAuth page (not `/forbidden`) over the now-trusted channel — a valid cert proves TLS terminates, not that the app is reachable. `/forbidden` during the outage was almost certainly the untrusted-channel landing, but confirm a real navigation succeeds before closing the ticket.

## Residual risk

- The apex now depends on the wildcard leaf; a future compromise/revocation of that leaf rotates apex and the four sub-domains together. Accept or address via the ADR.
- **Certificate pinning.** The fix swapped the apex to a *different* leaf (new public key/thumbprint), not a same-key renewal. Any client that pins the apex certificate or its public key (mobile app, service integration, synthetic monitor) breaks against the new leaf even though it is valid. Confirm with the app team whether anything pins `vpp.eneco.com`.
- **HSTS.** The outage's "Continue (unsafe)" affordance implies HSTS was not enforced on this login host — worth fixing on its own, and note a future recurrence *with* HSTS would hard-block every prior visitor with no bypass.
- **Stale enabled version.** The old expired apex version (`8332A22F…`) is still enabled inside `p-vpp-eneco-com`. Disable it — leaving stale enabled versions plus the latest-by-creation resolution rule makes the next rotation of this object fragile.
- No expiry alert exists yet on `p-vpp-eneco-com` — the recurrence guard is in [sre-toil-removal-proposal.md](./sre-toil-removal-proposal.md).
- The prod SP secret was briefly supplied via a plaintext file this session; **rotate that SP secret** as a security follow-up.
