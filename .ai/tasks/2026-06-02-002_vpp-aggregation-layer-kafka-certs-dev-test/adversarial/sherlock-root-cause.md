---
task_id: 2026-06-02-002
agent: sherlock-holmes
status: complete
summary: >
  Adversarial root-cause receipt attacking the "read-method-only" diagnosis for vpp-agg-sb
  Kafka certs. Crypto/format claims hold for all THREE secrets (independently re-verified:
  byte-clean PEM, no BOM/CRLF/literal-\n in storage, JSON-escape symptom reproduces for all
  three, key<->leaf SPKI MATCH, chain OK, all in-date, no future notBefore). Two material
  gaps survive: (G1) "dev and test = one vpp-agg-sb set" CONTRADICTS the intake's own Context
  line ("get this from MC Dev AND MC Test environments") — the requester named TWO environments,
  the diagnosis collapsed them to one; flagged as "open item" but stated in the verdict as A2
  FACT-shaped. (G2) sibling secret kafkasslkeystorepassword (17B password) plus a stale 2023
  DER/PKCS12 secret named `test` imply a JKS/PKCS12 keystore consumer may exist — raw PEM may
  not be the artifact the consumer loads. Also: each Kafka secret has 3 NEWER but DISABLED
  versions from the 2026-05-29 rotation burst (delivered value = oldest/enabled = correct now,
  but rotation is unsettled). Verdict on the CLAIM: NOT fully resolved — technically sound on
  format, but root-cause-COMPLETENESS fails on requester-intent (env scope + artifact type).
timestamp: 2026-06-02
---

# Adversarial Root-Cause Receipt — vpp-agg-sb Kafka certs (dev/test)

## Claim under attack

> "The stored secrets are valid; the ONLY problem is the read method (JSON escaping / portal
> single-line view). Delivering the `-o tsv` PEM and telling the requester to use `-o tsv` fully
> resolves the request, and the single vpp-agg-sb cert set satisfies 'dev and test'."

**Win condition:** falsify. **Result:** the format/crypto half survives every attack; the
**root-cause-completeness half does NOT** — two uneliminated alternative needs remain (env scope,
artifact type), one of which is directly contradicted by the intake's own words.

All probes run on this machine, Sandbox sub `7b1ba02e-...` only (no MC env touched, no whitelist
drift). No private-key bytes printed anywhere.

---

## Lane 1 — Is "read-method JSON escaping" the real cause, or assumed? Re-checked all THREE.

The diagnosis demonstrated the symptom on `kafka-cacert` only and generalized to three. I
re-probed each secret independently at the byte level and re-ran the `-o json` symptom per key.

| Check (per secret) | kafka-cacert | kafka-clientcert | kafka-sslkey | Label |
|---|---|---|---|---|
| First bytes | `2d2d2d2d2d 4245 47 49 4e` = `-----BEGIN` (no `EF BB BF` BOM) | same | `-----BEGIN PRIVA` | A1 FACT |
| CRLF (`0d0a`) in storage | 0 | 0 | 0 | A1 FACT |
| literal `\n` in stored bytes (tsv) | 0 | 0 | 0 | A1 FACT |
| `-o json` literal `\n` on ONE line (the "broken" symptom) | 50 | 87 | 27 | A1 FACT |
| contentType | `<null>` (plain secret) | `<null>` | `<null>` | A1 FACT |

**Evidence:** `xxd` head/tail of `/tmp/vppagg-sb-2026-06-02/{kafka-cacert,kafka-clientcert,kafka-sslkey}.raw`;
`az keyvault secret show --query value -o json | grep -o '\n' | wc -l` per key (50/87/27 on 0 newlines);
`az keyvault secret show --query contentType -o tsv` = null for all.

**Sub-hypotheses tested and killed:**

- **base64 / double-encoding on the key only** — REBUTTED. `kafka-sslkey.raw` begins `-----BEGIN PRIVATE KEY-----`, parses as PKCS#8 directly; no base64 layer.
- **BOM** — REBUTTED. No `EF BB BF` prefix on any of the three (first 16 bytes captured).
- **CRLF / trailing-byte mangling** — REBUTTED. Zero CR bytes; tails end clean (`-----\n` / `-----\n\n`).
- **literal `\n` written into storage for one key** — REBUTTED. Zero literal `\n` in the `-o tsv` bytes of all three.
- **H-FMT-3 (secret is a KV certificate object → reading returns PKCS12/DER not PEM)** — REBUTTED. contentType null on all three; raw bytes are ASCII PEM, not DER.

**Lane 1 verdict: REBUTTED (claim holds).** The "not in good format" symptom is a read-method
artifact and it reproduces identically for all three secrets, not just the cacert. The diagnosis's
generalization is now backed by per-secret evidence rather than one sample.

Independent crypto re-verification (did not trust the diagnosis's single run):

- `kafka-cacert` parses; `CN=Trust Provider B.V. TLS RSA CA G1`, issuer DigiCert Global Root G2, valid 2017-11-02 → 2027-11-02. A1 FACT.
- `kafka-clientcert` = exactly 3 `BEGIN CERTIFICATE` blocks; leaf `CN=esp-eet-vpp-dt.streaming.eneco.com` (2025-12-09 → 2027-01-09), intermediate Trust Provider G1, root DigiCert G2. A1 FACT.
- key ↔ leaf SPKI sha256 **independently re-derived = `47ca90cbf4c09427135e80289b86b4cba55f15f5f8a626e5ba65a77e529bab30` on BOTH** → MATCH. A1 FACT.
- `openssl verify -CAfile cacert -untrusted intermediate leaf` → `OK`. A1 FACT.

---

## Lane 4 — Expiry / rotation / cached-value subtlety. **One real finding (DEFER).**

- **notBefore-in-future:** REBUTTED for all 4 certs (leaf notBefore 2025-12-09 < now 2026-06-02; none future-dated). A1 FACT.
- **Expiry:** REBUTTED — all in-date as of 2026-06-02. A1 FACT.
- **Rotation / cached or wrong version — NEW FINDING:** each of the three Kafka secrets has **4
  versions**, ALL stamped 2026-05-29, and the **enabled (current) version is the OLDEST of the
  four**; the three NEWER versions are **disabled**:

  | secret | enabled version (updated) | newer DISABLED versions |
  |---|---|---|
  | kafka-cacert | 08:10:02 | 08:56:19, 08:56:24, 08:56:29 |
  | kafka-clientcert | 08:55:40 | 08:55:52, 08:56:00, 08:56:07 |
  | kafka-sslkey | 08:57:48 | 08:58:20, 08:58:26, 08:58:31 |

  **Evidence:** `az keyvault secret list-versions --vault-name vpp-agg-sb --name <k> --query "...attributes.{updated,enabled}"`.

  Impact on the CLAIM: NONE for correctness *right now* — `az keyvault secret show` returns the
  latest **enabled** version, which is exactly what was delivered into `certs/`. So the delivered
  bytes are the active ones. BUT a 2026-05-29 rotation produced **3 newer disabled versions per
  secret** (a burst of writes immediately rolled back to the older enabled value). This is an
  **unsettled rotation**, not a closed one. Two live risks: (a) if anyone re-enables the newest
  version, the active cert silently changes and the delivered PEM goes stale; (b) the requester
  may have read a now-disabled version during the 08:55–08:58 window and seen a value that no
  longer resolves.

  **Classification: DEFER.** *Revisit condition:* confirm with the secret owner whether the
  2026-05-29 disabled versions are intentional (rotation rolled back) and whether the requester
  read before/after 08:10:02; if a re-enable is planned, the delivered PEM must be re-pulled.

---

## Lane 2 — Could the real need be a DIFFERENT artifact (JKS/PKCS12 keystore / truststore)? **Uneliminated (DEFER, leaning ACCEPTED-RISK).**

The diagnosis treats the request as "three PEM secrets" and ignores the sibling secrets. Attack:

- `kafkasslkeystorepassword` exists (17 bytes, password-shaped, updated 2026-05-29 — same rotation
  batch as the certs). A keystore **password** secret strongly implies a consuming application that
  loads a **JKS or PKCS12 keystore**, not raw PEM. A2 INFER (mechanism: Spring-Kafka / Java Kafka
  client typically wants `ssl.keystore.location` + `ssl.keystore.password` + `ssl.truststore.*`,
  not three loose PEM files).
- Vault secret list contains **no `.jks` / `.p12` / `keystore` / `truststore` binary secret** — only
  the password. So either the keystore is **assembled at deploy time from these PEMs** (in which
  case PEM delivery IS correct), or it lives in a firewall-restricted per-env vault we cannot see.
  A1 FACT (full `az keyvault secret list` enumerated; no keystore object present).
- Additional signal: a stale secret literally named **`test`** (9837 bytes, updated **2023-06-01**,
  enabled) whose first bytes `30 82 71 30 82 37 09 2A 86 48 86 F7…` are a **DER ASN.1 SEQUENCE with
  a PKCS OID** — i.e. a binary **PKCS12/PFX keystore**, NOT PEM. A1 FACT (first-60-byte structure
  probe; value not printed). It is stale and almost certainly not "the test cert," but it proves
  **PKCS12 keystores are a real artifact shape in this vault's history** — so the requester asking
  for "the Kafka certificate" could plausibly mean a keystore the PEMs feed into.

**Why this attacks the claim:** the claim asserts delivering PEM + `-o tsv` instruction *fully
resolves* the request. If the requester's consumer ingests a JKS/PKCS12 (the keystore-password
secret is the tell), then PEM-only delivery is necessary-but-not-sufficient; they would also need
the keystore (or the build-time assembly step + the password). The diagnosis did not mention
`kafkasslkeystorepassword` at all, so this need was never eliminated.

**Classification: DEFER.** *Revisit condition:* ask the requester what their Kafka client is
(Java/Spring → keystore likely; librdkafka/Python/Go → PEM is correct) and whether they need
`kafkasslkeystorepassword`. If Java, deliver/point to the keystore + password, not only PEM.

---

## Lane 3 — Is "dev and test = one vpp-agg-sb set" sound? **FALSIFIED by the intake's own text.**

This is the strongest break. The diagnosis verdict (diagnosis.md:29) states as A2:

> "Therefore 'dev and test' = this one cert set in vpp-agg-sb; it is the dev-test Kafka client identity."

But the **intake's own Context section** (`slack-intake.md:16`, mirrored in
`context/01-topology-and-auth-findings.md:16`) says, verbatim:

> "Dev and Test, means you have to get this information from the **MC Dev, and MC Test environments**."

**Two independent environments are named by the requester.** The diagnosis leans on the leaf CN
`esp-eet-vpp-dt` = "vpp **D**ev-**T**est" to argue one combined identity — a reasonable INFER, but
it **directly conflicts with the requester's explicit instruction to pull from MC Dev AND MC Test
environments** (two distinct MC envs, behind firewall-restricted vaults `vpp-agg-appsec-d` /
`-a` / `-p` which were returned 403 and NOT inspected — diagnosis.md:30).

The diagnosis itself concedes this in "Open item" (diagnosis.md:86–90) — but then the **TL;DR
verdict and A2 present the single-set answer as the resolved conclusion**. An open item that, if
true, changes the deliverable from "one sandbox set" to "two per-env runtime certs" is not a
footnote — it is an **uneliminated route-flip**. The claim "the single vpp-agg-sb cert set
satisfies 'dev and test'" is therefore **NOT established**; it rests on CN semantics over the
requester's literal words.

**Mechanism of failure if the claim is wrong:** the leaf `esp-eet-vpp-dt` is the Sandbox/dev-test
client identity. The MC Dev runtime (and a real MC Test, if one exists for this component) may use a
**different client cert** (CN `…vpp-d…` etc.) stored in the firewall-restricted `vpp-agg-appsec-d`,
which requires MC SP login + IP whitelist (the very `eneco-tools-connect-mc-environments` skill the
intake mandated and which was NOT executed). Delivering only the Sandbox cert would hand the
requester the wrong identity for the MC Dev broker → TLS handshake auth failure at connect time.

**Classification: ACCEPTED-RISK / route-flip OPEN.** This is the one finding that prevents the
claim from being marked resolved. *Revisit condition:* either (a) requester confirms the Sandbox
`vpp-agg-sb` set is what they want for both, OR (b) execute the mandated MC-connect skill against
`vpp-agg-appsec-d` (and locate/confirm an MC Test vault) and compare the leaf CN/SPKI; if it
differs from `esp-eet-vpp-dt`, deliver the per-env certs.

---

## Verdict on the CLAIM

| Half of the claim | Status |
|---|---|
| "Stored secrets valid; only problem is read method (JSON escaping)" | **REBUTTED (claim holds)** — independently confirmed for all three secrets, not just cacert. |
| "Delivering `-o tsv` PEM + use-`-o tsv` instruction **fully** resolves the request" | **NOT established** — assumes PEM is the consumed artifact; `kafkasslkeystorepassword` + a 2023 PKCS12 `test` secret leave a keystore need uneliminated (Lane 2 DEFER). |
| "The single vpp-agg-sb set satisfies 'dev and test'" | **FALSIFIED by intake text** — requester explicitly said MC Dev AND MC Test environments; firewall-restricted per-env vaults never inspected (Lane 3). |

**Bottom line:** the format diagnosis is technically correct and well-evidenced — the read-method
root cause is real and now confirmed across all three secrets. But the *request* is not fully
resolved: root-cause completeness fails on **requester intent** (two-environment scope) and
possibly **artifact type** (keystore vs PEM). The word "fully" in the claim is the load-bearing
overreach. Recommend the diagnosis demote its single-set / fully-resolved language to
**PARTIAL** pending: (1) requester confirmation of Kafka client type (PEM vs keystore +
keystore-password), and (2) confirmation of whether the MC Dev / MC Test runtime certs (firewall-
restricted vaults) are needed — the mandated `eneco-tools-connect-mc-environments` step was not run.

## Probe hygiene

- All reads on Sandbox sub `7b1ba02e-...`; `az account show` re-confirmed Sandbox at end — no MC
  environment accessed, no whitelist enabled, no drift to revert.
- No private-key bytes emitted: key validation used SPKI sha256 of the **public** key only;
  `test` secret characterized by first-60-byte structure marker, value never dumped.
- Temp split files cleaned.
