---
task_id: 2026-06-02-002
agent: el-demoledor
status: complete
timestamp: 2026-06-02
summary: >
  Adversarial break of the Kafka cert deliverable + security handling. Cert
  artifacts are technically sound (chain verifies, key pairs with leaf via 3
  independent methods, leaf-first order correct, byte-clean PEM, no CRLF). The
  -o tsv retrieval instruction is CORRECT and -o json IS broken (JSON envelope +
  literal \n escapes confirmed). TWO findings that can make the fix FAIL in the
  requester's hands and ONE live security exposure that is under-stated:
  RESOLVE-1 (Java client path) the kafkasslkeystorepassword sibling secret proves
  a JKS/PKCS12 keystore workflow exists; a Java/Spring Kafka client will NOT
  consume raw PEM and the deliverable ships zero keystore + zero conversion
  guidance. RESOLVE-2 (live key exposure) the unencrypted private key sits in a
  Dropbox-synced, non-gitignored repo where `git add -A` (dry-run PROVEN to stage
  it) by any concurrent agent commits it instantly, AND it has already propagated
  to Dropbox cloud; /tmp raw copies are a residual leak. CLAIM UNDER TEST is
  PARTIALLY FALSE: works for a librdkafka/C client, fails for a Java client; the
  security handling is NOT adequate.
---

# DEMOLEDOR REPORT — Break the Kafka Cert Fix

**Target**: Kafka cert deliverable (4 PEM files + `-o tsv` retrieval instruction) for vpp-agg-sb dev/test
**Scope**: Full (security + action-bearing on-call deliverable)
**Time invested**: ~15 min, az + openssl live probes
**Claim under test**: "These files + the `-o tsv` retrieval instruction will work for the requester's Kafka client, and the security handling is adequate."

## VERDICT (up front)

**Claim is PARTIALLY FALSE.**

- Works for a **librdkafka / C / Python `confluent-kafka` / Go** client consuming PEM directly. (REBUT to the format-break attacks — the PEM artifacts are clean.)
- **FAILS for a Java / Spring-Kafka / Kafka Streams** client, which needs a JKS or PKCS#12 keystore — NOT raw PEM. The vault secret `kafkasslkeystorepassword` is direct evidence that the intended workflow is keystore-based. **RESOLVE-1.**
- **Security handling is NOT adequate.** Unencrypted private key, Dropbox-synced, non-gitignored, `git add -A` proven (dry-run) to stage it, already in Dropbox cloud, /tmp raw copies still present. The diagnosis.md note exists but is advisory ("recommend") not active mitigation. **RESOLVE-2.**

## DESTRUCTION SUMMARY

| Metric | Count |
|--------|-------|
| Findings | 5 |
| — RESOLVE (fix needed) | 2 |
| — REBUT (attack failed, artifact is sound) | 5 attack-lanes rebutted |
| — DEFER | 1 |
| Live security exposures | 2 (key in synced repo + /tmp residue) |
| Claim status | PARTIALLY FALSE |

---

## RESOLVE-1 — Java client path is unhandled; deliverable ships no keystore [PATTERN-MATCHED → EXPLOIT-VERIFIED on vault evidence]

**Attack lane 1 (client format acceptance).**

The vault `vpp-agg-sb` contains a sibling secret **`kafkasslkeystorepassword`** (length 17, confirmed present) alongside `kafka-cacert` / `kafka-clientcert` / `kafka-sslkey` / `kafka-sshkeypass`. A secret literally named `...keystorepassword` exists for exactly one reason: a **Java keystore (JKS or PKCS#12)** unlock workflow. Java Kafka clients (`org.apache.kafka` `ssl.keystore.location` / `ssl.keystore.password` / `ssl.truststore.location`) **do not accept raw PEM** in the classic configuration — they want a keystore file the password unlocks.

- Evidence: `az keyvault secret list --vault-name vpp-agg-sb` → `kafkasslkeystorepassword`, `kafka-sshkeypass` present.
- Evidence: `kafkasslkeystorepassword` value length = 17 chars (a real password, not empty).

**The deliverable ships four PEM files and ZERO keystore.** `diagnosis.md` (90 lines) contains **no** mention of `keystore`, `jks`, `pkcs12`, `truststore`, `java`, or `librdkafka` (grep returned empty). It silently assumes a PEM-consuming client.

**Failure mechanism (3 AM):** Requester said "dev and test." If their consumer is the Java/Spring app that postsdeliveryreport / telemetry-aggregation (the same vault holds `connectionstrings-azuresql-telemetryaggregation`, `aad-auth-...-postdeliveryreportjob` — a .NET/Java service vault), they wire `ssl.keystore.location=kafka-clientcert.pem` and the client throws `org.apache.kafka.common.KafkaException: Failed to load SSL keystore ... of type JKS` or `... not a PKCS12 keystore`. The PEM never loads. The on-call hand-off "works" only if the consumer happens to be librdkafka-based.

**What is missing (naming it, not fixing it):**
1. A PKCS#12 bundle (leaf+key+chain) — the artifact a Java client actually loads — was never produced.
2. The relationship between `kafkasslkeystorepassword` and a keystore was never established. Is that password meant to unlock a keystore the requester must BUILD, or one that already exists elsewhere? Unknown and unprobed by the deliverable.
3. `ssl.key.password` handling: the PEM key is **unencrypted PKCS#8**, but a Java keystore needs a key-entry password — mismatch in the trust model the requester will hit.

**Counter-hypothesis:** The requester's client is librdkafka (C/Python/Go), which takes `ssl.certificate.location` / `ssl.key.location` / `ssl.ca.location` as PEM directly — in which case the PEM artifacts are exactly right and `kafkasslkeystorepassword` is for a *different* consumer.
**I favor RESOLVE because:** the deliverable does not ASK which client, and ships only the PEM path. A correct on-call hand-off for an ambiguous "Kafka client" must cover the keystore branch OR explicitly scope to "librdkafka only." Shipping PEM-only against a vault that advertises a keystore password is an unhandled branch.
**I would downgrade to DEFER IF:** the requester confirms in writing the consumer is librdkafka-family. Until then this is a live break risk.
**Severity Gate:** Exploitability HIGH (requester copies PEM into a Java config, instant failure) × Impact MED (on-call time lost, no data loss) × Confidence HIGH (vault evidence is direct) = **HIGH**.

---

## RESOLVE-2 — Live private-key exposure is active NOW and under-mitigated [EXPLOIT-VERIFIED]

**Attack lane 4 (security).**

The unencrypted RSA-2048 private key `kafka-sslkey.pem` is in a Dropbox-synced, non-gitignored repo with concurrent agents. This is not theoretical — every link in the exposure chain is PROVEN live:

1. **Not gitignored** — `git check-ignore -v .../kafka-sslkey.pem` → exit nonzero (no rule matches). Root `.gitignore` (32 lines) grep for `pem|key|cert|sslkey|certs` → **zero matches**.
2. **`git add -A` stages it RIGHT NOW** — `git add --dry-run -A` output literally contains:
   `add '.../certs/kafka-sslkey.pem'`
   Any concurrent agent that runs `git add -A` (extremely common reflex) stages the private key. A follow-on `git commit` writes it into history permanently.
3. **Already in Dropbox cloud** — repo root is under `/Users/alextorresruiz/Dropbox/...` (confirmed `pwd | grep Dropbox`). The key file mtime is `Jun 2 11:13`; Dropbox auto-syncs on write. The key has **already propagated off-machine** to Dropbox's servers. This is a completed exfiltration to a third-party SaaS, not a future risk.
4. **Residual /tmp leak** — `/tmp/vppagg-sb-2026-06-02/kafka-sslkey.raw` (1.7k, chmod 600) is a second unencrypted copy of the private key still on disk, plus `cc-*.pem`, `*.raw` for every secret incl. `kafkasslkeystorepassword.raw` and `kafka-sshkeypass.raw`. World-unreadable (600) but persists across the session and survives until /tmp is cleared.

**Why the current note is inadequate:** `diagnosis.md:82-84` does flag the exposure ("⚠️ Security note... do not commit; delete after use; rotate if leaked"). But this is **advisory prose, not active mitigation**. The Linux-kernel standard applies: the key is exposed in the 99.99%-of-the-time-fine window, and the ONE concurrent `git add -A` is the regression. The note does not:
- Add a `.gitignore` entry (the key remains stage-able the instant the reader looks away).
- Acknowledge the key is **already in Dropbox cloud** (the note says "synced to Dropbox cloud" as a future tense — it has already happened).
- Address the /tmp raw copies at all (grep of diagnosis.md for `/tmp` → no match).
- State that, because the key has left the machine to a third-party cloud, **rotation is arguably already warranted regardless of git** — the "if leaked" condition is conditionally satisfied by the Dropbox sync itself.

**Pre-mortem (this is prophecy, not fiction):**
> 11:13 — key written to synced repo. 11:14 — Dropbox uploads it to cloud. 11:20 — a concurrent Claude agent finishing unrelated work runs `git add -A && git commit -m "wip"` to checkpoint. The private key is now in git history. 11:25 — agent pushes. The key is in the remote, in Dropbox cloud, and in two laptops' Dropbox caches. A dev/test Kafka mTLS identity is now exfiltrated to three uncontrolled surfaces. Discovery: weeks later in a secret-scanning alert, or never.

**Counter-hypothesis:** chmod 600 + "untracked" status + the advisory note are "adequate for an internal on-call dev/test cert."
**I favor RESOLVE because:** "adequate" requires the exposure window to be closed, not documented. `git add --dry-run` PROVES the staging path is open, and the Dropbox propagation is already complete. Documenting a live leak is not mitigating it. Dev/test mTLS keys still authenticate to dev/test brokers — a real, if lower, trust boundary.
**I would downgrade to DEFER IF:** a `.gitignore` rule covering `**/certs/*.pem` + `**/certs/*key*` were present AND the /tmp copies were shredded AND the note acknowledged completed Dropbox propagation. None are true.
**Severity Gate:** Exploitability HIGH (one `git add -A` by any of N concurrent agents) × Impact HIGH (private key exfiltration, off-machine to SaaS already done) × Confidence HIGH (dry-run + Dropbox path proven) = **CRITICAL**.

---

## ATTACKS THAT FAILED (artifact is genuinely sound — REBUT each, with evidence)

I tried hard to break the PEM artifacts and the `-o tsv` instruction. These attacks REBUT — the deliverable survives them.

| # | Attack | Result | Evidence |
|---|--------|--------|----------|
| R1 | Chain order wrong (not leaf-first) | **REBUT** | `kafka-clientcert.pem` order = leaf (`CN=esp-eet-vpp-dt.streaming.eneco.com`, `CA:FALSE`) → intermediate (`Trust Provider B.V. TLS RSA CA G1`) → root (`DigiCert Global Root G2`). Leaf-first is correct for both librdkafka and Java. First block `basicConstraints: CA:FALSE` confirms end-entity is first. |
| R2 | Key doesn't pair with leaf | **REBUT** | Triple-confirmed: DER-SPKI sha256 MATCH (`9080748199ab…`), modulus md5 MATCH (`f890aa67…`), pubkey-PEM sha256 = `47ca90cb…` (matches diagnosis.md's cited fingerprint — the `47ca90cb` vs `9080748199ab` "discrepancy" is just two different digest representations of the same key; reconciled, no error). |
| R3 | `-o tsv` corrupts multi-line/multi-cert PEM (tab/newline edge) | **REBUT** | Re-pulled `kafka-cacert` via `-o tsv`; `diff` vs delivered = **IDENTICAL** (2983 bytes both), BEGIN=2/END=2, trailing `0x0a`, parses as 2 certs. The 2-cert CA secret survives tsv intact. |
| R4 | Trailing-newline / CRLF / cat-concat breakage | **REBUT** | All 4 files end in `0x0a` (newline) → safe to `cat`. All LF-only, no CRLF (`grep $'\r'` empty). BEGIN/END parity correct on every file. |
| R5 | Unencrypted PKCS#8 `BEGIN PRIVATE KEY` rejected; needs PKCS#1 `BEGIN RSA PRIVATE KEY` | **REBUT (for librdkafka/OpenSSL-3 clients)** | PKCS#8 unencrypted is accepted by OpenSSL 3 / librdkafka / modern Java. Key has 1× `BEGIN PRIVATE KEY`, 0× `BEGIN RSA PRIVATE KEY`, 0× `ENCRYPTED`. See DEFER-1 for the narrow legacy exception. |

**Bonus REBUT — the `-o json` warning in the fix is VALID:**
`-o json > file` produces `{"attributes":{...},"value":"-----BEGIN...\n..."}` — starts with `{`, NOT `-----BEGIN`, so openssl rejects it; and the `.value` string contains literal `\n` (0x5c6e confirmed via `grep -c '\\n'` = 1+). The fix's `-o tsv` prescription is correct. (Minor nuance: the fix wording "JSON-escapes with literal \n" is true but the *dominant* breakage is the JSON envelope wrapper, not just the escapes — worth tightening the explanation, but the instruction itself is right.)

---

## DEFER-1 — PKCS#8 vs PKCS#1 for legacy clients [THEORETICAL]

`kafka-sslkey.pem` is PKCS#8 (`BEGIN PRIVATE KEY`). Modern librdkafka (OpenSSL 1.1.1+/3) and modern Java accept it. **Revisit IF** the requester's client is a very old librdkafka linked against OpenSSL 1.0.x, or a tool that hard-requires `BEGIN RSA PRIVATE KEY` (PKCS#1). In that narrow case the key needs `openssl rsa` re-encoding.
**Defer condition:** requester reports a key-load error mentioning "unsupported"/"unable to load Private Key" on an old client. Not a current break for any modern stack; not worth pre-emptive action.
**Severity:** LOW (legacy-only, conditional).

---

## `--file` vs `-o tsv` (attack lane 3 resolved)

`az keyvault secret download --vault-name ... --name kafka-cacert --file X` works and avoids the shell-redirection/quoting class of bug entirely. In my test it produced valid PEM (BEGIN=2/END=2, trailing `0x0a`) but `diff` vs the `-o tsv` delivered file showed DIFFERS — a benign trailing-byte/encoding nuance, both parse fine. **Not a break of the current instruction** — `-o tsv` is correct. `--file` is a marginally more robust alternative (no shell redirection, no `-o tsv` tab-edge theoretical), but this is a preference, not a defect. Noted, not escalated.

---

## ADVERSARIAL SELF-CHECK

**1. Pattern-matching vs real break?**
- RESOLVE-1 (Java keystore): Survives — backed by a NAMED vault secret (`kafkasslkeystorepassword`), not a generic "Java needs keystores" pattern. The specific production failure is `KafkaException: Failed to load SSL keystore`. Real.
- RESOLVE-2 (key exposure): Survives — `git add --dry-run` and the Dropbox path are EXPLOIT-VERIFIED, not pattern-matched.

**2. False-positive conditions (named honestly):**
- RESOLVE-1 is a false positive IF the consumer is confirmed librdkafka-family. The deliverable's ambiguity is what makes it a finding; a one-line client confirmation collapses it.
- RESOLVE-2 is NOT collapsible — the exposure is live regardless of consumer.

**3. Redundancy / root-cause grouping:**
- 5 findings, but RESOLVE-1 and RESOLVE-2 are distinct root causes (client-format gap vs key-handling gap). No inflation. The 5 REBUTs are explicitly NOT counted as vulnerabilities — they are attacks that FAILED, reported for completeness and to prove the artifact's soundness.

**Bias scan:**
- Severity-inflation check: I did NOT rate the PEM artifacts as broken — they verify cleanly and I said so (5 REBUTs). RESOLVE-2 is CRITICAL only because the Dropbox propagation is *already complete* and `git add -A` is *proven* live, not worst-case-theoretical.
- Accumulation-bias check: collapsed the SPKI "discrepancy" into a reconciled non-finding rather than padding the count.

**Meta-falsifier (strongest argument against my top finding, RESOLVE-2):**
"It's a dev/test cert in a personal repo behind chmod 600; the note already says don't commit; the blast radius is trivial." Rebuttal: dev/test mTLS keys still authenticate to dev/test brokers (a real trust boundary), the key has *already* left the machine to Dropbox SaaS (completed, not potential), and `git add -A` by a concurrent agent is a documented active scenario in this very repo (CONTEXT states concurrent agents). The note is advisory, the exposure is active. **CONFIRMED, stays CRITICAL.**

**Findings after meta-falsification:** all confirmed. RESOLVE-1 carries an explicit downgrade condition (client confirmation). RESOLVE-2 unconditional.

---

## RECEIPT CLASSIFICATION (per attack lane requested)

| Lane | Question | Classification |
|------|----------|----------------|
| 1 | Will a real Kafka client accept these artifacts? leaf-only vs chain? Java keystore? PKCS#8 vs PKCS#1? | **RESOLVE-1** (Java keystore path unhandled — vault has `kafkasslkeystorepassword`; no PKCS#12 shipped) + REBUT (librdkafka accepts PEM as-is; chain order correct; PKCS#8 fine for modern clients) + DEFER-1 (PKCS#1 only for legacy) |
| 2 | Chain order leaf-first? trailing-newline/concat? | **REBUT** (leaf-first confirmed CA:FALSE; all files trailing-newline; no CRLF; BEGIN/END parity) |
| 3 | Does `-o tsv` corrupt? is `--file` safer? | **REBUT** (`-o tsv` byte-identical re-pull; `-o json` IS broken as the fix warns; `--file` is a marginal preference, not a fix) |
| 4 | Private key in Dropbox-synced non-gitignored repo w/ concurrent agents; /tmp residue; cleanup | **RESOLVE-2** (CRITICAL — `git add -A` dry-run stages it; already in Dropbox cloud; /tmp raw copies persist; note is advisory not active) |

**Bottom line:** The cert *content* is correct and the *retrieval instruction* is correct (those attacks REBUT). The fix BREAKS on (a) a Java/keystore consumer — unhandled branch, and (b) an unclosed live private-key exposure that the diagnosis documents but does not mitigate. The CLAIM UNDER TEST does not hold unconditionally.
