---
title: vpp-agg-sb Kafka certs (dev/test) — retrieval & format diagnosis
timestamp: 2026-06-02
status: complete
category: on-call
---

# Kafka Certificate Retrieval & "Bad Format" Diagnosis — vpp-agg-sb (dev/test)

**Requester ask (Slack #Myriad-platform):** provide the Kafka certificate for dev and test;
reading the PEM from Key Vault `vpp-agg-sb` shows it "is not in good format."
Keys: `kafka-cacert`, `kafka-clientcert`, `kafka-sslkey`.

> This is the concise evidence record. The full teaching write-up (with first-principles
> reasoning and reproduction) is `rca-feynman.md` in this folder.

## TL;DR (verdict)

> ⚠️ **Bigger finding — see `cross-environment-findings.md`:** the MC **Dev** and MC **Acc/"test"**
> runtime Kafka client certs are **EXPIRED (2026-01-10)**. The only valid cert is the sandbox one
> below. This doc covers the **format** root cause (the surface symptom); the **expiry** is the
> load-bearing problem. Both are real.

1. **The stored secrets in `vpp-agg-sb` (sandbox) are correct, valid, in-date, well-formed PEM.**
   Nothing is wrong with the sandbox Key Vault content.
2. **"Not in good format" is a read-method artifact.** Reading the secret as JSON (Azure CLI
   default / `-o json`, or the Portal's single-line value field) returns the value wrapped in a
   **JSON envelope** (`{"value":"..."}` or a bare quoted string) with **literal `\n`** escapes on
   one line. Reading with `--query value -o tsv` returns byte-clean multi-line PEM.
3. **Delivered the dev-test cert set** the requester named (`vpp-agg-sb`, leaf CN
   `esp-eet-vpp-dt` = VPP **D**ev-**T**est).
4. **Open scope item (confirm):** the intake also said "MC Dev *and* MC Test environments." The
   per-environment **runtime** vaults `vpp-agg-appsec-{d,a,p}` are firewall-restricted; if a
   *distinct* MC-Dev runtime client cert is required, that needs the MC SP login + IP whitelist
   (`eneco-tools-connect-mc-environments`). See "Scope" below.

## ⚠️ Process observation — should these be requested over Slack at all?

The requested material includes `kafka-sslkey`, a **private key** (and `kafka-clientcert`, a client
identity). These are **secrets**, so the request itself carries a process/security smell worth raising:

1. **Handing a private key over Slack is a secret-handling anti-pattern.** Pasting or forwarding it
   into Slack writes the key into Slack's servers, channel history, search index, and notifications —
   a durable, off-platform exposure that is hard to revoke. Same for email or any chat.
2. **Key Vault exists precisely so this manual transfer does not happen.** The intended pattern is:
   the consuming application reads the secret **at runtime via its managed identity / RBAC**; humans
   do not extract and pass private keys around. A human needing the raw key by hand usually means
   (a) local dev/test against the dev-test broker, (b) a consumer not wired to KV, or (c) the person
   lacks direct KV access — each has a better fix than a Slack hand-off.
3. **The correct help is self-serve, not extraction.** Since the stored PEM is fine and the only
   problem was the read method, the right resolution is to (a) ensure the requester has KV read
   access (RBAC on `vpp-agg-sb`), and (b) give them the correct command
   (`az keyvault secret show … --query value -o tsv`) so **they** pull it directly — the key never
   traverses Slack.
4. **If the key has already been shared (Slack / files / handed over), consider rotating it.**
   Combined with the unsettled 2026-05-29 rotation, a clean re-rotation + re-publish to KV may be
   warranted. Dev/test keys still authenticate to dev/test brokers — a real (if lower) trust boundary.
5. **Minimum-exposure handoff** if a transfer is genuinely unavoidable: use a secret manager / 1Password
   share or an ephemeral secure channel — never plain Slack/email — and delete after use.

**For the requester conversation:** *"Happy to help — but note `kafka-sslkey` is a private key.
Rather than pasting it into Slack, let's get you KV read access + the correct `-o tsv` command so you
retrieve it directly. The stored value is valid; the format you saw was just the JSON/portal view.
And if this key has been shared around, we should rotate it."*

## Environment resolution (evidence)

| Label | Claim | Evidence |
|-------|-------|----------|
| A1 | `vpp-agg` is a VPP workload with envs dev/acc/prd/sandbox; **no "test"** env. | Resource Graph: `vpp-agg-appsec-{d,a,p}`, `vpp-agg-sb`, `kv-vppagg-bootstrap-{d,a,p,sb}` |
| A1 | `vpp-agg-sb` is in sub `Eneco Cloud Foundation - Sandbox-Development-Test` (`7b1ba02e-…`). | `az graph query` + `az account list` |
| A1 | Client-cert leaf CN = **`esp-eet-vpp-dt.streaming.eneco.com`** — `vpp-dt` = VPP Dev-Test. | `openssl x509 -subject` |
| A2 | The `vpp-agg-sb` set is the dev-test Kafka client identity (sandbox sub literally = "Development-Test"; CN = dev-test). | CN semantics + the vault the requester named |
| A1 | `vpp-agg-appsec-d` (dev) and `-a` (acc) are **firewall-restricted** (`ForbiddenByFirewall`; IP 84.86.32.39 blocked). | `az keyvault secret list` 403 |

## Cryptographic validation (externally witnessed via openssl; independently re-verified by reviewer)

| Item | Finding | Label |
|------|---------|-------|
| `kafka-cacert` | PEM cert. `CN=Trust Provider B.V. TLS RSA CA G1`, issued by DigiCert Global Root G2. Valid **2017-11-02 → 2027-11-02**. | A1 |
| `kafka-clientcert` | **3-cert chain**, leaf-first: leaf `CN=esp-eet-vpp-dt.streaming.eneco.com` (`CA:FALSE`, valid **2025-12-09 → 2027-01-09**) → intermediate → DigiCert root. | A1 |
| `kafka-sslkey` | `-----BEGIN PRIVATE KEY-----` = unencrypted PKCS#8, RSA-2048. Parses. | A1 |
| key ↔ leaf | Public-key SPKI sha256 **MATCH** (`47ca90cb…`); modulus md5 match (independent method). | A1 |
| chain | `openssl verify -CAfile cacert (-untrusted intermediate) leaf` → **OK**. | A1 |
| dates | All in-date as of 2026-06-02. | A1 |

## Root cause of "not in good format" (confirmed for all three secrets)

```bash
# LOOKS BROKEN (default / -o json): JSON envelope + literal \n, one line:
az keyvault secret show --vault-name vpp-agg-sb --name kafka-cacert --query value -o json
#   "-----BEGIN CERTIFICATE-----\nMIIEsjCCA5q…\n…"

# CORRECT (-o tsv): real newlines = valid PEM:
az keyvault secret show --vault-name vpp-agg-sb --name kafka-cacert --query value -o tsv
```

Reviewer independently reproduced the symptom on **all three** secrets (50 / 87 / 27 literal `\n`
on the `-o json` read; **0** in the `-o tsv` bytes). The Azure Portal "Secret value" field shows
the value on a single line, producing the same visual symptom on copy.

## Rotation note (unsettled)

Each of the three kafka secrets has **4 versions, all stamped 2026-05-29**; the **enabled
(current)** version is the **oldest**, and **3 newer versions are disabled**. `az keyvault secret
show` returns the enabled version — exactly what was delivered — so the delivered bytes are
correct now. But this is a rotation that was written then rolled back. Two risks: (a) if someone
re-enables a newer version the active cert changes silently and the delivered PEM goes stale;
(b) the requester may have read a now-disabled version during the 08:55–08:58 window. *Action:*
confirm with the secret owner whether the 2026-05-29 disabled versions are intentional.

## Client-type branch (which artifact does the consumer load?)

- **librdkafka / C / Python `confluent-kafka` / Go** → consume PEM directly
  (`ssl.ca.location` / `ssl.certificate.location` / `ssl.key.location`). The delivered PEMs are
  exactly right.
- **Java / Spring-Kafka / Kafka Streams** → load a **JKS/PKCS#12 keystore + truststore**, not raw
  PEM. The sibling secret `kafkasslkeystorepassword` (and a stale 2023 PKCS12 secret named `test`)
  signal a keystore workflow may exist. If the consumer is Java, build a keystore from the PEMs:

```bash
# Truststore (CA):
keytool -importcert -alias kafka-ca -file kafka-cacert.pem -keystore truststore.p12 -storetype PKCS12
# Keystore (leaf + key) as PKCS#12:
openssl pkcs12 -export -in kafka-clientcert.pem -inkey kafka-sslkey.pem \
  -certfile kafka-cacert.pem -name kafka-client -out keystore.p12   # password: use kafkasslkeystorepassword
```

## Delivered files (`./certs/`)

| File | Contents |
|------|----------|
| `kafka-cacert.pem` | CA cert (broker trust anchor / truststore source) |
| `kafka-clientcert.pem` | full client chain (leaf+intermediate+root) |
| `kafka-clientcert-leaf.pem` | leaf only (convenience) |
| `kafka-sslkey.pem` | **PRIVATE KEY** (RSA-2048, unencrypted PKCS#8) — chmod 600 |
| `.gitignore` | `*` — excludes the key material from git so a concurrent agent's `git add -A` can't commit it |

## Security posture (corrected)

- The repo path is named `…/Dropbox/…` but Dropbox sync is **NOT active** (confirmed by owner) —
  so there is **no cloud propagation**. Earlier "exfiltrated to cloud" concern is **retracted**.
- Residual risk = accidental **git commit**. Mitigated: `certs/.gitignore` (`git add -A --dry-run`
  proven to no longer stage the keys). Owner will not commit; recommend deleting after review.
- `/tmp` raw copies of the secret values were **shredded** (`rm -fP`).
- No MC SP login and no IP whitelist were performed → **zero Terraform drift** to revert.

## Scope: what was delivered vs the literal ask

Delivered = the `vpp-agg-sb` (Sandbox / Dev-Test) cert set, which is the vault + keys the requester
named, with leaf CN `vpp-dt` (dev-test). **If** the requester specifically needs the per-environment
**runtime** cert from MC Dev (`vpp-agg-appsec-d`, likely a different CN), that vault is
firewall-restricted and requires the MC SP login (1Password biometric) + IP whitelist via
`eneco-tools-connect-mc-environments`, then whitelist-OFF. Because other agents are concurrently
using the shared `az` session, that step should be timed to avoid clobbering them (an isolated
`AZURE_CONFIG_DIR` is the safe method). Flagged for confirmation.
