---
title: "On-call: vpp-agg Kafka certs (dev/test) — index"
timestamp: 2026-06-02
status: complete
category: on-call
---

# vpp-agg Kafka certs (dev/test) — on-call package

**Request:** provide the Kafka certificate for dev/test from Key Vault `vpp-agg-sb`; the PEM read
from KV "looked not in good format."

**What it actually turned out to be (two layers):**
1. **Format (the surface ask):** the sandbox secret is valid PEM — `az ... -o json`/Portal show it
   JSON-escaped; read with `--query value -o tsv`.
2. **Expiry (the real problem):** the **MC Dev** (`esp-eet-vpp-dt`) and **MC Acc/"test"**
   (`esp-eet-vpp-acc`) runtime client certs both **EXPIRED 2026-01-10**. The only valid cert is the
   sandbox one (rotated 2026-05-29, → 2027). It was never propagated to the runtime vaults. → see
   **`cross-environment-findings.md`**.

## Read order
1. `cross-environment-findings.md` — **the incident view** (expiry + rotation gap across 3 vaults)
2. `rca-feynman.md` — **the teaching RCA** (first-principles, diagrams, self-test)
3. `cert-inspection-cookbook.md` — copy-paste local commands to inspect/verify any of the certs
4. `diagnosis.md` — concise evidence record (format root cause)
5. `slack-reply.md` — drafted reply for the requester

## Files

| Path | What | Usable? |
|------|------|---------|
| `certs/` | **Sandbox** `vpp-agg-sb` set (`esp-eet-vpp-dt`) | ✅ VALID → 2027-01-09 |
| `certs-mc-dev/` | **MC Dev** `vpp-agg-appsec-d` set (`esp-eet-vpp-dt`) | ❌ EXPIRED 2026-01-10 |
| `certs-mc-test-acc/` | **MC Acc/"test"** `vpp-agg-appsec-a` set (`esp-eet-vpp-acc`) | ❌ EXPIRED 2026-01-10 |
| `slack-intake.md` | original request (verbatim) | — |

(All `certs*/` private keys are gitignored — do not commit.)

## Status

- ✅ Retrieved + validated all three environments (sandbox + MC Dev + MC Acc) with live openssl.
- ✅ Format root cause confirmed (read-method JSON escaping on sandbox; base64-wrap + mangling on runtime).
- ✅ **Expiry incident identified:** dev + acc runtime certs expired 2026-01-10; rotation landed only in sandbox.
- ✅ Adversarially reviewed (sherlock-holmes + el-demoledor) — receipts in `.ai/tasks/2026-06-02-002_*/adversarial/`.
- ✅ Access hygiene: isolated SP sessions (shared `az` untouched); IP whitelist added then **removed** on both runtime vaults (zero drift); SPs logged out; `/tmp` shredded.

## Open / recommended (for cert owner)
- Propagate the valid `esp-eet-vpp-dt` (sandbox) cert into MC Dev runtime vault; redeploy.
- **Re-issue** `esp-eet-vpp-acc` (no valid copy exists anywhere); publish to MC Acc; redeploy.
- Confirm consumer type (librdkafka PEM vs Java PKCS#12 keystore — both present in runtime vaults).
- LL-006 class fix: expiry alarm + automated rotation/propagation.
