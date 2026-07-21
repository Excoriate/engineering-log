---
title: "SRE Toil Removal Proposal — preventing silent apex certificate expiry"
incident: INC0264497
timestamp: 2026-07-21
status: complete
---

# SRE Toil Removal Proposal

Preventing a silent apex certificate expiry. Each proposal names the incident evidence that motivates it, the smallest reversible next action, and the new failure mode it introduces.

## Toil Removal Knowledge Contract

After this doc you can: name the highest-leverage control that removes reliance on a human remembering a deferred renewal; distinguish removing/alerting from blindly automating; and see why each proposal is bound to a specific piece of incident evidence.

## RCA Evidence Base

- The apex object `p-vpp-eneco-com` expired 20 Jul with no signal; the incident surfaced only when users hit the error ([rca.md](./rca.md) L6/L7).
- `vpp-appsec-p` holds seven expired certificates still `enabled=true`; five are apex-name objects under five names, only two distinct leaves by thumbprint (`proofs/outputs/kv-cert-inventory-20260721.txt`).
- The June rotation deferred the apex to a "separate window" that was never scheduled or alarmed ([rca.md](./rca.md) L6).
- The outage's "Continue (unsafe)" affordance implies HSTS was not enforced on the apex (screenshot 03).

## Options Considered

The theme: **remove the reliance on a human remembering a deferred renewal.** Ordered by leverage.

### P1 — Certificate-expiry alerting on every AGW-bound Key Vault object (highest leverage)

- **Proposal:** alert at **30 and 7 days** before expiry for every certificate object bound to `vpp-ag-p` (`p-vpp-eneco-com`, `wildcard-vpp-eneco-com`, `vpp-eetpv-com`). Prefer Key Vault's native near-expiry event/metric over a hand-rolled cron.
- **Smallest reversible next action:** add a Key Vault near-expiry alert rule (Event Grid `Microsoft.KeyVault.CertificateNearExpiry` → the VPP on-call action group) scoped to `vpp-appsec-p`; start alert-only.
- **New failure mode:** noise from the expired residue objects (P3) — mitigate by scoping alerts to AGW-bound objects, or clean up P3 first.

### P2 — One stable object name per host (kill the naming sprawl)

- **Proposal:** renewals import a **new version of the existing bound object**, never a new object. The apex stays `p-vpp-eneco-com`; the wildcard stays `wildcard-vpp-eneco-com`. Document the host→object map next to the gateway config.
- **Smallest reversible next action:** add a one-line "bound object per host" table to the VPP TLS runbook and the June rotation spec.
- **New failure mode:** none material; a discipline change that also makes P1 legible.

### P3 — Retire the expired residue (reduce audit + alert noise)

- **Proposal:** confirm each expired object has no consumer (the June sweep showed `vpp-ag-p` is the only App Gateway and there is no Front Door/APIM/App Service/AKS in the prod sub), then **disable** them (reversible) before any delete. Never delete a certificate object another environment still renders from.
- **Smallest reversible next action:** first disable the just-superseded expired apex version (`8332A22F…`) still enabled inside `p-vpp-eneco-com` — leaving it enabled next to the new version, combined with the latest-by-creation resolution rule, makes the next rotation of this object zero-margin. Then disable (not delete) the five expired apex-name objects (`vpp-eneco-com`, `prd-vpp-eneco-com`, `prd1-vpp-eneco-com`, `d-vpp-eneco-com`, `vpp-2023-2024`) plus the expired `esp-eet-…-streaming` and `tms-eetpv-com` (seven total); watch one AGW poll cycle for listener health; delete only after a soak.
- **New failure mode:** disabling an object still referenced somewhere would break that consumer — hence the consumer check first and disable-before-delete ordering.

### P4 — Make a deferral a tracked, time-boxed item

- **Proposal:** any "deferred / separate window" decision in a change spec must create a dated follow-up (ticket or calendar) **and** rely on P1's alert as the backstop. A deferral is not done until its follow-up exists.
- **Smallest reversible next action:** add a "Deferred items → tracked follow-up" checkbox to the rotation runbook's sign-off.
- **New failure mode:** none; process guard.

### P5 — Enforce HSTS on the apex (security posture)

- **Proposal:** add a `Strict-Transport-Security` response header (gateway/WAF or app). Trade-off: with HSTS a *future* expiry hard-blocks every prior visitor with no click-through — which **raises** the stakes on P1, so gate HSTS behind P1 being live.
- **Smallest reversible next action:** check current posture (`curl -sI https://vpp.eneco.com | grep -i strict-transport`), then add the header with a short `max-age` and ramp up once P1 alerting exists.
- **New failure mode:** HSTS + an uncaught expiry = a harder outage; strictly gated behind P1.

## Recommendation

Adopt **P1–P4 as mandatory** (they directly remove the failure that caused INC0264497) and **P2/P3 together** (naming discipline makes both alerting and cleanup coherent). Adopt **P5 only after P1 is live**. All are alert/discipline/cleanup changes, not new automation of the vendor-gated issuance step.

## Systemic Rationale

The failure was not a bad command; it was a deferred renewal with no watcher. Every proposal above removes a point where the system relied on a human remembering: P1 makes a machine watch the clock, P2/P3 make "which object, expiring when" legible, P4 makes a deferral create its own reminder, P5 hardens the channel once the clock is watched. Favour these systemic guards over giving the next on-call a longer checklist.

## Non-Goals

Certificate **issuance/renewal** stays manual for now (vendor-gated via Networking4All). The goal of P1–P4 is to guarantee the manual step is *triggered in time and against the right object*, not to automate issuance blindly. Moving to managed/auto-renewed certificates is a larger decision recorded in [the ADR](./adr-001-apex-tls-certificate-lifecycle.md).
