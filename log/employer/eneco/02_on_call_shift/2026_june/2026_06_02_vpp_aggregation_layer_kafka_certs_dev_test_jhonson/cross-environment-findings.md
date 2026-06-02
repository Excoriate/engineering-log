---
title: "VPP Aggregation Layer Kafka certs — cross-environment findings (dev / test / sandbox)"
timestamp: 2026-06-02
status: complete
category: on-call
---

# Cross-Environment Findings — vpp-agg Kafka certs

**Headline:** the request was "provide the Kafka cert for dev and test." Retrieving from the
**actual MC runtime vaults** (not just the sandbox the requester named) shows the **dev and test
(acc) runtime client certs are EXPIRED**. The only valid cert anywhere is the freshly-rotated one in
the **sandbox** vault. This is a **rotation/deployment gap**, layered on top of several PEM **format**
gotchas. The format issue was real but secondary; **expiry is the load-bearing problem.**

## The three vaults (all evidence A1 unless noted — openssl on values pulled live)

| Env | Vault (sub) | Client leaf CN | Leaf notAfter | State | Stored format |
|-----|-------------|----------------|---------------|-------|---------------|
| **Sandbox / Dev-Test** | `vpp-agg-sb` (`7b1ba02e`) | `esp-eet-vpp-dt` | **2027-01-09** | ✅ **VALID** (rotated 2026-05-29) | clean PEM (read with `-o tsv`) |
| **MC Dev** | `vpp-agg-appsec-d` (`839af51e`) | `esp-eet-vpp-dt` | **2026-01-10** | ❌ **EXPIRED** | `kafka-dev-*` = base64(PEM)+base64(PKCS12); legacy `kafka-cacert` (2023) = mangled (spaces-for-newlines) |
| **MC Acc / "test"** | `vpp-agg-appsec-a` (`b524d084`) | `esp-eet-vpp-acc` | **2026-01-10** | ❌ **EXPIRED** | `kafka-test-*` = clean PEM + base64 PKCS12 |

CA cert (`Trust Provider B.V. TLS RSA CA G1`, DigiCert-rooted) is valid → **2027-11-02** in every
vault; only the **client leaves** expired.

## What this means

1. **Dev and test (acc) Kafka mTLS client certs both expired on 2026-01-10** (~5 months ago). Any
   service still presenting them to the broker fails the TLS handshake. This is very likely *why* the
   request was raised.
2. **A rotation happened on 2026-05-29** and produced a valid `esp-eet-vpp-dt` cert — but it landed
   **only in the sandbox vault** (`vpp-agg-sb`), and was **not propagated** to the MC Dev runtime
   vault. (A2 INFER from the 2026-05-29 timestamps + the sandbox being the only valid copy.)
3. **For acc (`esp-eet-vpp-acc`) there is no valid replacement** in any vault I could reach — it
   needs re-issuance, not just propagation. (A1: enumerated `vpp-agg-appsec-a`; newest is the expired
   2025-01-07 set.)
4. **"Not in good format" had different causes per vault** — so the requester likely hit more than one:
   - Sandbox: valid PEM shown JSON-escaped by `-o json`/Portal → read with `-o tsv`.
   - MC Dev legacy `kafka-cacert` (2023): **mangled in storage** (newlines replaced by spaces) → won't parse even with `-o tsv`.
   - MC Dev/Acc current sets: **base64-wrapped** → must `base64 -d` before openssl.
   - Keystores: `*.pfx` use **legacy RC2-40-CBC** → open with `openssl pkcs12 -legacy`.

## Connection to LL-006 (credential-expiry class)

This is another instance of the Trade Platform credential-expiry class problem: a calendar-expiring
cert (Jan 2026) with a manual, incomplete rotation. Per LL-006, per-incident retrieval does not fix
the class — the fix is automated rotation + propagation (KV + ESO/scheduler) with an expiry alarm.

## Recommended actions (for the requester / cert owner)

1. **Dev:** propagate the valid `esp-eet-vpp-dt` cert (the rotated 2026-05-29 set now in `vpp-agg-sb`)
   into `vpp-agg-appsec-d` — replacing the expired `kafka-dev-*`/legacy secrets — and redeploy the
   consumer. Confirm the consumer reads from `vpp-agg-appsec-d`, not the sandbox vault.
2. **Acc/"test":** **re-issue** an `esp-eet-vpp-acc` client cert (no valid copy exists), publish to
   `vpp-agg-appsec-a`, redeploy.
3. **Hygiene:** clean up the mangled legacy `kafka-cacert/clientcert/sslkey` (2023) in `vpp-agg-appsec-d`;
   resolve the sandbox `vpp-agg-sb` unsettled rotation (3 newer *disabled* versions from 2026-05-29).
4. **Class fix (LL-006):** add an expiry alarm on these certs and automate rotation+propagation so the
   sandbox-vs-runtime divergence cannot recur silently.

## What to do — documented procedure, owner & precedent (wiki + Slack, fetched live 2026-06-02)

### The certificate lifecycle (so the steps make sense)

ESP delivers a **password-protected PFX** (CA + client cert + private key) per environment. Eneco
splits it with openssl into the `kafka-cacert` / `kafka-clientcert` / `kafka-sslkey` secrets +
keystore password. (A1: wiki *ESP certificate setup*, Page 6791; the documented filenames are
literally `…esp-eet-vpp-dt-streaming-eneco-com.pfx` / `…-acc-…` / `…-prd-…` — exact match.)

### Owner / who to talk to (A1: Slack)

- **Fabrizio Zavalloni** (`fabrizio.zavalloni@eneco.com`) — the operator who runs `esp-eet-vpp-*`
  ESP cert renewals (did `esp-eet-vpp-prd` on 2026-01-07; led the 2025-09 agg-layer expiry fix).
- **Roel van de Grint** — historical owner: creates Axual apps, plugs certs, owns the
  **Networking4All** relationship. (He's said this "should be self-service for your team.")
- **Issuer:** Networking4All (Jenke van Gerven, `j.vangerven@networking4all.com`) → Trust Provider
  B.V. / DigiCert PKI, requested via a **ServiceNow** ticket. 1-year validity, manual (no ACME).

### The documented runbook (A1: wiki Page 50903)

`/Myriad - Aggregation Layer/Runbook certificate rotation aggregation layer` — rotate via the
ArgoCD app **`esp-certificate-agg`**: validate on 1 service first → upload new cert to Axual →
configure in gitops → sync `esp-certificate-agg` to recreate the `keys` k8s secret → update the
**PFX password in keyvault** → restart services. (Has a rollback plan.) Also see how-to
`platform-documentation` repo → `How-To-Guides/Certificates/esp-certificates-renewal.md` (PR 118713).

### Concrete next steps for THIS incident

1. **Align with Fabrizio first** — a company-wide ESP/VPP cert rotation was already in progress in
   Dec 2025 ("Fabrizio is already rotating all certificates right now"; VPP+Agg historically *shared*
   certs, with "separate certs to be discussed in January"). The 2026-05-29 `vpp-agg-sb` rotation is
   very likely part of that effort that **stalled before reaching the runtime vaults**. He may
   already have the new `esp-eet-vpp-dt` / `-acc` PFXs. (A1 Slack + A2.)
2. **Dev:** if the sandbox `esp-eet-vpp-dt` is the intended new cert, run runbook 50903 to deploy it
   to the dev cluster + publish to `vpp-agg-appsec-d`.
3. **Acc/"test":** **no valid `esp-eet-vpp-acc` exists** → request re-issue (Networking4All /
   ServiceNow), then runbook 50903 for acc.
4. **Prod:** verify `esp-eet-vpp-prd` (renewed 2026-01-07) is healthy — it's the sibling cert.

### Why nobody caught the expiry (the real systemic gap)

- A **`#expiring-certificates`** Slack bot posts a weekly expiry digest by CN — but it only lists
  *not-yet-expired* certs. `esp-eet-vpp-dt`/`-acc` expired 2026-01-10 and **fell off the digest**, so
  they were invisible after expiry. (A1/A2 Slack.) The ESP expiry pipeline (`definitionId=2735` →
  `myriad-alerts-devops`) is likewise notification-only.
- **No documented procedure covers sandbox→runtime propagation or dev/acc** — the runbook is
  prod-centric. This incident *is* that undocumented gap. (A3 wiki.)
- **Recurrence:** a near-identical agg-layer expiry hit sandbox+acc on **2025-09-08** (same KVs, same
  owner, reactive fix). This is the LL-006 credential-expiry class — the durable fix is an
  *already-expired*-aware alarm + automated rotation **and propagation**, not another manual pull.

> Full evidence with permalinks/quotes: `.ai/tasks/2026-06-02-002_*/context/05-docs-kafka-cert-rotation.md`
> (wiki) and `06-slack-kafka-cert.md` (Slack).

## Delivered cert material (all gitignored; private keys do not leave git)

| Folder | Env | Usable? |
|--------|-----|---------|
| `certs/` | Sandbox `vpp-agg-sb` (`esp-eet-vpp-dt`) | ✅ VALID → 2027 |
| `certs-mc-dev/` | MC Dev `vpp-agg-appsec-d` (`esp-eet-vpp-dt`) | ❌ EXPIRED 2026-01-10 (reference only) |
| `certs-mc-test-acc/` | MC Acc/"test" `vpp-agg-appsec-a` (`esp-eet-vpp-acc`) | ❌ EXPIRED 2026-01-10 (reference only) |

## Access hygiene (this investigation)

- MC Dev + MC Acc reached via isolated `AZURE_CONFIG_DIR` SP sessions (shared `az`/Alex session never
  clobbered → concurrent agents unaffected).
- My IP was added to `vpp-agg-appsec-d` and `-a` network rules to read, then **removed** (both
  confirmed gone) → **zero Terraform drift**. Both SPs logged out; all `/tmp` secret copies shredded.
