---
title: "Drafted Slack reply — vpp-agg Kafka certs (dev/test)"
timestamp: 2026-06-02
status: draft
category: on-call
---

# Drafted reply (for #Myriad-platform)

> Looked into this — two things, and the second is the important one.
>
> **1. The format you saw is a red herring.** The secret in `vpp-agg-sb` is a valid PEM; the Portal
> (and `az ... -o json`) just render it JSON-escaped on one line. Read it raw:
> `az keyvault secret show --vault-name vpp-agg-sb --name kafka-cacert --query value -o tsv`.
>
> **2. The actual problem: your dev and test Kafka client certs are EXPIRED.** I pulled them from the
> real runtime vaults:
> - MC **Dev** (`vpp-agg-appsec-d`): client cert `esp-eet-vpp-dt` — **expired 2026-01-10**.
> - MC **Test/Acc** (`vpp-agg-appsec-a`): client cert `esp-eet-vpp-acc` — **expired 2026-01-10**.
> - **Sandbox** (`vpp-agg-sb`): `esp-eet-vpp-dt` — **valid → 2027-01-09** (rotated 2026-05-29).
>
> So a rotation was done on 2026-05-29 but it only landed in the **sandbox** vault — it was never
> propagated to the dev/test runtime vaults, where the certs are still the expired ones. For dev we
> can propagate the valid sandbox cert; for **acc/test there's no valid replacement anywhere — it
> needs to be re-issued.** (The CA itself is fine until 2027; only the client leaves expired.)
>
> Two questions:
> - Which client are you wiring this into? The runtime vaults carry both a **PEM** key and a
>   **PKCS#12 keystore** (`kafka-*-ssl-key-cert-pfx` + `kafkasslkeystorepassword`) — Java wants the
>   keystore (note: it's legacy RC2, open with `openssl pkcs12 -legacy`); librdkafka/Python want PEM.
> - Owner-wise this sits with **Fabrizio** (he runs the `esp-eet-vpp-*` renewals; did `-prd` in Jan)
>   with **Roel** as fallback, and there's a runbook (*Runbook certificate rotation aggregation layer*,
>   ArgoCD `esp-certificate-agg`). A company-wide ESP rotation was already in flight in Dec 2025, so
>   the new dt/acc certs may already exist — worth aligning with Fabrizio before re-requesting via
>   Networking4All/ServiceNow. (Heads-up: the `#expiring-certificates` bot only lists *not-yet-expired*
>   certs, so these dropped off its radar after 2026-01-10 — that's why it went unnoticed.)
> - Are you OK if I raise this as a cert-rotation follow-up? It's the same expiry class we've hit
>   before (incl. the 2025-09 agg-layer expiry) — worth an *already-expired*-aware alarm + automated
>   propagation so dev/test don't silently diverge again.
>
> (Also — `kafka-sslkey` is a private key; let's not pass it around in Slack. Better to get you KV
> read access so you pull it directly, and rotate anything that's been shared.)
