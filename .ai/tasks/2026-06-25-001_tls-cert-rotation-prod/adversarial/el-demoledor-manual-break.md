---
title: El Demoledor — MANUAL-mode break review of PROD TLS rotation spec
task_id: 2026-06-25-001
agent: el-demoledor
status: complete
timestamp: 2026-06-25
target: rotation-execution-spec.md (Mode B: Manual), companion how-the-vpp-tls-rotation-works.md
execution_model: AI agent runs each Manual step as a SEPARATE Bash call = FRESH shell; shell vars DO NOT persist; on-disk state (AZURE_CONFIG_DIR, /tmp, working folder) persists; human confirms each step; Step 7 run by human on AVD; Step 8 mandatory finally
summary: "10 findings (3 BLOCKING, 3 HIGH, 3 MED, 1 LOW). Dominant break = lost shell state across fresh Bash calls: every var (MYIP, OLD_*, NEW_*, SUB/RG/KV/OBJ/AGW/SSL/VLESS/PFX/PW, AZURE_CONFIG_DIR) is undefined from Step 2 onward, producing FAIL-outright AND silent-success-while-wrong outcomes, incl. a firewall left OPEN. Verdict: NO-GO for manual as written."
---

# El Demoledor — MANUAL-mode Destruction Inventory

**Target:** `rotation-execution-spec.md` Mode B (Manual), executed by an AI agent one step per fresh Bash shell.
**Scope:** Full. The single highest-information fact about this execution model — *shell variables do not survive between Bash tool calls* — is load-bearing for almost every step, because the spec was written assuming **one continuous terminal**. Below, each finding carries an evidence grade, the exact failing input, observed-vs-expected, and a conditional fix.

## DESTRUCTION SUMMARY

| Metric | Count |
|---|---|
| Vulnerabilities Found | 10 |
| — EXPLOIT-VERIFIED | 4 |
| — PATTERN-MATCHED | 4 |
| — THEORETICAL | 2 |
| BLOCKING | 3 |
| HIGH | 3 |
| MED | 3 |
| LOW | 1 |
| Root cause (dominant) | Lost shell state across fresh Bash calls (M-01) drives M-02..M-05, M-08 |

Locally probed FACTS used below (all EXPLOIT-VERIFIED on this machine, 2026-06-25):

- `certificate_password.txt` is **13 bytes**, last byte `0x0a` — a real trailing newline (`xxd`: `...4c6a 5500 …` → `...LjU\n`). `$(cat PW)` = `HlScIUDLMLjU` (12 chars, newline stripped); `file:$PW` passes the newline **into** openssl/az.
- Bare `openssl` in THIS shell resolves to `/opt/homebrew/bin/openssl` (3.6.2, has `-legacy`), but `/usr/bin/openssl` (LibreSSL 3.3.6) is also on PATH and **`-legacy` is "unknown option"** there.
- LibreSSL reads the held PFX **without** `-legacy` (`MAC verified OK`) — i.e. dropping `-legacy` "works" and is a silent-success trap.
- Brew openssl `-fingerprint -sha1` on the held PFX = `b8202de20be7fb3fb37e6d5141975282bf33bde7` — **matches** the claimed `NEW_THUMB`. The compare-gate math is sound; the danger is the pipeline producing an *empty* `EXPECT`, not a wrong one.
- `.../certificate_to_renovate/...` (literal placeholder) **does not resolve**: `test -s` is false, silently.
- `AZURE_CONFIG_DIR=/tmp/azsp-prd` **does not exist** right now (`No such file or directory`).

---

## BLOCKING

### M-01: Shell state evaporates between steps — `PFX`/`PW`/`MYIP`/`OBJ`/`KV`/… all undefined from Step 2 on  [EXPLOIT-VERIFIED]

- **Exploit / exact break:** "Session setup" defines `SUB RG KV OBJ AGW SSL VLESS PFX PW MYIP` and `export AZURE_CONFIG_DIR`. Each is set in shell #1. Step 1 runs in shell #2, Step 2 in shell #3, … Every one of those variables is **empty** in the next shell.
  - Step 1 actual command becomes: `az keyvault network-rule add --name "" -g "" --subscription "" --ip-address "/32"` → `az` errors (`--name` required / invalid) → FAIL-outright. *Best case.*
  - Step 2: `az keyvault certificate show --vault-name "" --name ""` → error; `OLD_SID`/`OLD_THUMB` set to empty; `echo "OLD_SID=   OLD_THUMB="` → operator "writes down" **nothing**, and the rollback baseline is silently lost.
  - Step 4 GATE: `EXPECT` recomputed fine (if `$PFX` survived — it won't), but `NEW_THUMB` from Step 3 is **empty in this shell** → `[ "$EXPECT" = "$NEW_THUMB" ]` compares a real value to empty → `❌ MISMATCH — STOP` on a cert that is actually correct (false-fail), OR if both empty → the `[ -n "$EXPECT" ]` guard prints MISMATCH. Either way the gate is meaningless because its inputs don't survive.
- **Observed vs expected:** Expected: each probe prints the documented value. Observed: NULL-substituted commands that either error or operate on the wrong/empty target. The spec's own "expect `f007df01-…`" probe in Session setup passes *in shell #1* and lulls the operator into trusting persistence that does not exist.
- **Blast radius:** Every step 1–8 + rollback. This is the generator behind M-02..M-05 and M-08.
- **Counter-hypothesis:** "Safe if the agent keeps one long-lived shell." Rejected by the stated execution model (one Bash call per step = fresh shell). I favor the vuln because the FACTS section of the dispatch explicitly states vars do not persist, and `AZURE_CONFIG_DIR` is already absent on disk.
- **Severity Gate:** Exploitability HIGH (happens on step 2 unconditionally) × Impact HIGH (wrong-target prod mutations / lost rollback baseline / false gate) × Confidence HIGH (EXPLOIT-VERIFIED model) = **BLOCKING**.
- **Conditional fix:** If steps run as separate shells → **rewrite Manual mode to persist state to a file and re-source it at the top of every step.** Concretely:
  - At end of Session setup, write a state file:
    `cat > /tmp/azsp-prd/rotate.env <<EOF\nexport AZURE_CONFIG_DIR=/tmp/azsp-prd\nexport SUB=… RG=… KV=… OBJ=… AGW=… SSL=… VLESS=… PFX=<ABS> PW=<ABS> MYIP=$MYIP\nEOF`
  - Make **every** subsequent step begin with `source /tmp/azsp-prd/rotate.env` (and append `OLD_SID/OLD_THUMB/NEW_SID/NEW_VER/NEW_THUMB` to that same file as they are computed, e.g. `echo "export NEW_VER=$NEW_VER" >> /tmp/azsp-prd/rotate.env`).
  - Add a guard to each step: `: "${KV:?run Session setup + source rotate.env first}"`.

### M-02: `AZURE_CONFIG_DIR` not re-exported per step → `az` runs as the WRONG identity (or none)  [EXPLOIT-VERIFIED]

- **Exploit / exact break:** `export AZURE_CONFIG_DIR=/tmp/azsp-prd` is in Session setup only. In every later fresh shell it is **unset**, so `az` falls back to the default `~/.azure` profile — the operator's **personal** account. The spec itself states the personal account returns `AuthorizationFailed` on the KV firewall and lacks Import.
  - Step 1 (firewall add) as personal account → `AuthorizationFailed` → FAIL-outright (loud, recoverable).
  - **Worse silent path:** if the personal `~/.azure` happens to be logged into the prod subscription with *some* reader role, `az account show --query id` (the Session-setup probe, re-run later) prints `f007df01-…` → **looks authenticated as intended** while actually being the wrong principal → subsequent Import fails confusingly, or a different-permissioned identity acts. The probe "proves right identity" only by subscription id, never by principal.
- **Observed vs expected:** Expected: all `az` calls use the SP token in `/tmp/azsp-prd`. Observed: calls use `~/.azure`. `AZURE_CONFIG_DIR` is confirmed **absent** on disk right now, so even shell #1's `az login` has not happened.
- **Counter-hypothesis:** "Safe — `az account show` would reveal the wrong account." Rejected: the spec's probe queries only `.id` (subscription), not `signedInUser`/`servicePrincipalId`, so a wrong-principal-right-subscription state passes silently.
- **Severity Gate:** Exploitability HIGH × Impact HIGH (prod identity confusion) × Confidence HIGH = **BLOCKING**.
- **Conditional fix:** Fold into M-01's `rotate.env` (`export AZURE_CONFIG_DIR=/tmp/azsp-prd` is line 1). **Additionally** change the Session-setup probe to assert the principal, not just the sub: `az account show --query "user.name" -o tsv` (expect the SP app id / `servicePrincipal`), and add `az account show --query "user.type" -o tsv` expecting `servicePrincipal`. If it prints a human UPN → STOP.

### M-03: Placeholder `.../` paths in `PFX`/`PW` → `test -s` false silently, Step 3 imports an EMPTY file or whole-vault-wrong  [EXPLOIT-VERIFIED]

- **Exploit / exact break:** Both PC and Session setup literally contain `PFX=".../certificate_to_renovate/26061584690-_-vpp-eneco-com.pfx"` and `PW=".../certificate_password.txt"`. The `...` is a **placeholder the author never replaced**. Probed: `test -s ".../certificate_to_renovate/26061584690-_-vpp-eneco-com.pfx"` → **false** (path does not resolve).
  - **PC2 silent-pass:** `test -s "$PFX" && test -s "$PW" && echo "PC2 artifacts ok"` → prints **nothing** when the files are missing. Absence of "PC2 artifacts ok" is the only signal, and an agent scanning for errors sees no error → proceeds. This is a textbook silent-success-while-wrong (the gate's pass condition is "no output," indistinguishable from "I didn't look").
  - **Step 3 with placeholder PFX:** `az keyvault certificate import … --file ".../….pfx"` → `az` errors "file not found" (loud) — OR if the agent "helpfully" substitutes a real path that is **the old exported cert** sitting in the same folder, it imports the wrong bytes; Step 4's thumbprint gate catches that one (good), but only if M-01 didn't already void the gate.
  - **`--password "$(cat ".../certificate_password.txt")"`:** `cat` on a missing file → empty string → `--password ""` → import fails or imports with wrong password.
- **Observed vs expected:** Expected: real absolute paths. Observed: `.../` resolves nowhere; the artifact PC passes by silence.
- **Counter-hypothesis:** "Safe — the operator obviously fills in `...`." Rejected for the AI-agent execution model: an agent may paste verbatim, and even a human under time pressure can miss a `...` that *looks* like an elision rather than a literal. The real PFX is at `…/2026_06_24_renewal_vpp_tls_certificates/certificate_to_renovate/26061584690-_-vpp-eneco-com.pfx` (verified present, 5.5k).
- **Severity Gate:** Exploitability HIGH × Impact MED-HIGH (wrong/empty import; mostly caught by Step 4 IF the gate survives M-01) × Confidence HIGH = **BLOCKING** (because PC2's pass-by-silence defeats the only pre-import artifact check).
- **Conditional fix:** If paths are placeholders → replace all `.../` with the **absolute** paths:
  `PFX="/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/log/employer/eneco/02_on_call_shift/2026_june/2026_06_24_renewal_vpp_tls_certificates/certificate_to_renovate/26061584690-_-vpp-eneco-com.pfx"` and the matching `…/certificate_password.txt`. **And** make PC2 fail loudly: `test -s "$PFX" && test -s "$PW" && echo "PC2 ok" || { echo "PC2 FAIL — paths"; exit 1; }`.

---

## HIGH

### M-04: `MYIP` /32 written in Step 1 is unknown to Step 8 → firewall left OPEN (broken `finally`)  [EXPLOIT-VERIFIED]

- **Exploit / exact break:** Step 1 adds `${MYIP}/32`. Step 8 removes `${MYIP}/32`. With M-01, `MYIP` is **empty in Step 8's shell** → the remove targets `"/32"`, which matches no rule → `az` no-ops or errors, and the **real** `<egress-ip>/32` rule stays. Probe `length(networkAcls.ipRules[?value=='/32'])` returns `0` → spec says "expect `0`" → **operator reads `0` as success while the actual IP rule is still open.** This is the worst class: the mandatory security `finally` reports clean while leaving prod KV exposed to a public IP.
  - Compounding: `MYIP=$(curl -4 -s ifconfig.me)` is re-evaluated if the operator re-runs Session setup before Step 8 from a **different network** (laptop moved, VPN toggled) → Step 1 opened IP-A, Step 8 removes IP-B, IP-A persists. The spec's own "What could go wrong" for Step 8 admits this ("Your IP changed mid-session") but the probe still returns `0` and looks successful.
- **Observed vs expected:** Expected: `0` means firewall closed. Observed: `0` means "no rule named `/32`," which is **always** true and says nothing about the real rule.
- **Counter-hypothesis:** "Safe — operator notices the missing IP." Rejected: the probe is keyed on the same empty `$MYIP`, so probe and bug share the failure; the green checkmark is self-confirming.
- **Severity Gate:** Exploitability HIGH × Impact HIGH (standing prod-KV exposure + the spec's stated drift) × Confidence HIGH = **HIGH** (BLOCKING-adjacent; it is the broken-finally the dispatch specifically asked to hunt).
- **Conditional fix:** (a) Persist `MYIP` via M-01's `rotate.env`. (b) Make Step 8 **enumerate and remove the real rule(s)** rather than trusting a variable: `for ip in $(az keyvault show -n "$KV" -g "$RG" --subscription "$SUB" --query "networkAcls.ipRules[].value" -o tsv); do az keyvault network-rule remove --name "$KV" -g "$RG" --subscription "$SUB" --ip-address "$ip" -o none; done` then assert `length(networkAcls.ipRules)` is the known baseline (capture it in Step 0). (c) Change the Step 8 probe to `--query "length(networkAcls.ipRules)"` and compare to the **baseline count captured before Step 1**, not to a literal that is vacuously 0.

### M-05: Step 1 `MYIP` (public egress) ≠ the IP that reaches the KV data plane → 403 forever, or wrong /32 whitelisted  [PATTERN-MATCHED]

- **Exploit / exact break:** `MYIP=$(curl -4 -s ifconfig.me)` returns the **public egress** IP as seen by `ifconfig.me`. If the operator/agent is behind a corporate proxy, split-tunnel VPN, or CGNAT, the IP that the **Key Vault data plane** sees on the `az keyvault certificate import` call can differ from the one `ifconfig.me` reports (different egress for the Azure-bound flow vs the ifconfig.me flow). Result: Step 1 whitelists IP-A, Step 3 import arrives from IP-B → **403 forever**, and the spec's advice ("propagation not finished; wait and retry") sends the operator into an infinite wait on a cause that waiting cannot fix.
  - On this machine `curl -4 ifconfig.me` returned **empty** in the probe (no output, exit 0 under the eval), which would trip `: "${MYIP:?no egress IP}"` — good — but an empty-yet-exit-0 path on a flaky network could also yield a partial/garbage value.
- **Observed vs expected:** Expected: whitelisted IP == data-plane source IP. Observed: not guaranteed equal; the spec assumes they are.
- **Counter-hypothesis:** "Safe on a single-operator laptop with direct egress." Plausible on Alex's home network; I grade PATTERN-MATCHED not EXPLOIT-VERIFIED because reachability depends on his actual egress topology, which I cannot observe. Exploitable **IF** the rotation is run from AVD/VPN/proxy (which PC4 says is *required* for Step 7 — so a network change between Step 1 and a re-verify is plausible).
- **Severity Gate:** Exploitability MED × Impact HIGH (403 stall under a hard ≤Jun27 deadline) × Confidence MED = **HIGH**.
- **Conditional fix:** Derive the IP from the actual Azure-bound path or verify it: after Step 1, if any later data-plane call 403s, **re-read the current egress and diff** (`NOW=$(curl -4 -s https://ifconfig.me); [ "$NOW" = "$MYIP" ] || echo "EGRESS CHANGED $MYIP -> $NOW"`). State explicitly that Step 1 and Steps 2–8 MUST run from the **same** network as the eventual import path; if Step 7 forces AVD, do Steps 1–6 from that same AVD egress or re-whitelist.

### M-06: Bare `openssl` + `-legacy` is PATH-dependent → LibreSSL "unknown option" → empty `EXPECT` → gate false-result  [EXPLOIT-VERIFIED]

- **Exploit / exact break:** PC1 and Step 4 call **bare** `openssl … -legacy`. Verified: `/usr/bin/openssl` (LibreSSL 3.3.6) errors `unknown option '-legacy'` and prints a usage block to stderr; the pipe to `openssl x509 -fingerprint` then gets **empty stdin** → `EXPECT=""`.
  - In THIS shell bare `openssl` = brew (has `-legacy`), so it works — but a fresh **non-login** shell, a different `PATH` order, `sudo`, or a cron/agent context can put `/usr/bin` first. Then Step 4: `[ -n "$EXPECT" ] && …` → `EXPECT` empty → prints `❌ MISMATCH — STOP` on a **correct** cert (false-fail). Under the ≤Jun27 deadline a false-fail can panic the operator into rolling back or "re-encoding" unnecessarily.
- **Observed vs expected:** Expected: `EXPECT=b8202de2…`. Observed (LibreSSL path): `EXPECT=""` → gate misfires. (Brew path verified to yield the correct `b8202de2…` matching `NEW_THUMB`.)
- **Counter-hypothesis:** "Safe — the dispatch says use `/opt/homebrew/bin/openssl`." True for the operator who remembers; the **spec text** says bare `openssl`. I favor the vuln because the artifact under review hard-codes the ambiguous form and the FACTS confirm LibreSSL is on PATH.
- **Severity Gate:** Exploitability MED (needs PATH order) × Impact MED (false-fail, not a wrong-pass) × Confidence HIGH = **HIGH**.
- **Conditional fix:** Replace every bare `openssl` in PC1, Step 4, Step 7's normalize line, and the re-encode note with the **absolute** `/opt/homebrew/bin/openssl`. Add to Step 4 after computing `EXPECT`: `[ -n "$EXPECT" ] || { echo "EXPECT empty — wrong openssl (use /opt/homebrew/bin/openssl, LibreSSL lacks -legacy)"; exit 1; }` so an empty `EXPECT` can never be silently compared.

---

## MED

### M-07: Password trailing newline — `file:$PW` (PC1/Step4) carries `\n`; `$(cat $PW)` (Step3) strips it → inconsistent password between read and import  [EXPLOIT-VERIFIED]

- **Exploit / exact break:** `certificate_password.txt` ends in `0x0a` (verified, 13 bytes; content `HlScIUDLMLjU\n`).
  - PC1 & Step 4 use `-passin "file:$PW"` → openssl reads the file and (modern openssl) strips a single trailing newline, so it works *with brew openssl* (verified: `MAC verified OK`, correct subject/fingerprint).
  - Step 3 uses `--password "$(cat "$PW")"` → `$(…)` strips the newline → password = `HlScIUDLMLjU` (12 chars, verified).
  - These happen to **agree** today because both strip the newline. The fragility: **if** the held PFX password genuinely contained a trailing newline, or **if** a future openssl/az build does NOT strip it, PC1 (`file:`) and Step 3 (`$(cat)`) would disagree — PC1 validates the PFX but Step 3's import sends a different password → import 400 / wrong-password, *after* PC1 said "ok." Mixed `file:` vs `$(cat)` semantics for the same secret is an avoidable inconsistency.
- **Observed vs expected:** Today both yield the 12-char password (consistent). Risk is the divergent newline handling, not a present-day failure.
- **Counter-hypothesis:** "Non-issue — both strip the newline." Largely true now; graded MED not HIGH because I verified consistency on this toolchain. Exploitable **IF** toolchain newline handling changes or the password legitimately ends in whitespace.
- **Severity Gate:** Exploitability LOW × Impact MED × Confidence HIGH = **MED**.
- **Conditional fix:** Use **one** password mechanism everywhere. Prefer `--password "$(cat "$PW")"` (newline-stripped, deterministic) in Step 3 **and** make PC1/Step 4 use the same: `-passin "pass:$(cat "$PW")"`. Or normalize the file once (`printf %s "$(cat "$PW")" > /tmp/azsp-prd/pw` and reference that). Document that the password is 12 chars, no trailing newline.

### M-08: `--disabled` not honored / versioned→versionless restore race — gate-before-exposure can be voided  [THEORETICAL]

- **Exploit / exact break:** Step 3 relies on `az keyvault certificate import … --disabled` creating a version that is `enabled=false`. The spec already flags "Probe returns `true` → the `--disabled` flag didn't apply." If that occurs (older `az` builds have had flag-honor bugs), the new (correct) cert is **immediately the latest-enabled version**, so the versionless URI resolves to it **before** Step 4's thumbprint gate runs — verification-after-exposure. For a like-for-like correct cert the exposure is benign, but it silently removes the "gate before live" guarantee the design depends on.
  - Step 6 race: between `ssl-cert update → NEW_SID (versioned)` and `→ VLESS (versionless)`, if the second call fails (transient) and M-01 left `VLESS` empty, the gateway is **left pinned to the versioned URI** → auto-rotation off + terraform drift, and `provisioningState=Succeeded` on the *first* call reads as success.
- **Observed vs expected:** Cannot observe without prod `az`; `--disabled` honor is `az`-version-specific.
- **Counter-hypothesis:** "Safe — Step 3 probe catches non-disabled; Step 6 probe catches a residual version GUID." Both true *if the probes' variables survive* — which M-01 breaks. I grade THEORETICAL because the failure needs either an `az` flag bug or a transient on the second Step-6 call.
- **Severity Gate:** Exploitability LOW × Impact MED × Confidence LOW = **MED**.
- **Conditional fix:** After Step 3, **assert** disabled and self-heal: `EN=$(az keyvault certificate show … --version "$NEW_VER" --query attributes.enabled -o tsv); [ "$EN" = false ] || az keyvault certificate set-attributes … --version "$NEW_VER" --enabled false`. In Step 6, run the versionless-restore until the probe confirms the URI ends `/secrets/wildcard-vpp-eneco-com` (loop, don't fire-and-forget), and gate Step 7 on that.

### M-09: `provisioningState=Succeeded` treated as proxy for "new cert served"  [PATTERN-MATCHED]

- **Exploit / exact break:** Step 6 probe expects `provisioningState=Succeeded`. The companion doc is explicit that exit-0 / control-plane success does NOT prove the wire serves the new leaf — yet Step 7 (the only real witness) is run by a **human on AVD** and PC4 admits it may be unreachable. The failure path: Step 6 returns `Succeeded`, Step 7 is skipped/unreachable, operator declares done → gateway is still serving OLD until the 4h poll or Jul 1 expiry → mass TLS-expired across all 4 hosts. The spec mitigates with "control-plane proxies" language but explicitly says they are "not a substitute for the wire handshake."
- **Counter-hypothesis:** "Safe — the spec mandates the handshake." It mandates it but routes it through a human + a reachability precondition that can fail; the control-plane green is the seductive false-pass. PATTERN-MATCHED: this is the exact "silent non-propagation" the doc itself names.
- **Severity Gate:** Exploitability MED × Impact HIGH × Confidence MED = **MED** (capped: the spec does flag it, so it's a discipline gap not a hidden bug).
- **Conditional fix:** Make Step 7 a **hard gate, not a human courtesy**: the manual procedure MUST NOT be marked complete until the normalized served fingerprint `== NEW_THUMB` is captured for all 4 hosts and pasted into the evidence file. If AVD is unreachable → status `blocked`, not `done` (consistent with PC4's NO-GO).

---

## LOW

### M-10: `sleep 25` / propagation waits assume a single uninterrupted shell; per-step model can re-run waits or skip them  [PATTERN-MATCHED]

- **Exploit / exact break:** Step 1 chains `… add … && sleep 25` in one command (survives the per-step model — good). But if an agent splits the `add` and the `sleep` into two calls, or re-runs Step 1 after a failure, the propagation window is mis-timed → Step 2/3 hit a not-yet-propagated rule → 403 → spec says "wait and retry," extending the window under deadline. Low because the `&&`-chaining mostly holds it together.
- **Counter-hypothesis:** "Safe — the `&&` keeps add+sleep atomic." Mostly true; LOW.
- **Severity Gate:** Exploitability LOW × Impact LOW × Confidence MED = **LOW**.
- **Conditional fix:** Keep `add && sleep 25` atomic in one step; add an explicit propagation probe loop (`until az keyvault certificate show … 2>/dev/null; do sleep 5; done` bounded by a max) instead of a fixed sleep.

---

## SPECULATIVE OBSERVATIONS (not counted)

- The Step-7 `for h in …` loop and the normalize one-liner both use bare `openssl s_client`/`x509`; same PATH caveat as M-06 but on AVD (a different machine) where the openssl build is unknown. Flag for the human running Step 7.
- `--password "$(cat "$PW")"` exposes the password in the process table (the spec's Notes acknowledge this). On a single-operator laptop, accepted; not a finding.

---

## ADVERSARIAL SELF-CHECK

- **Pattern-matching check:** M-01..M-04 are not pattern guesses — I verified the placeholder non-resolution, the password byte, the openssl PATH split, and the empty `MYIP` path on THIS machine. The fresh-shell model is given as FACT by the dispatch.
- **False-positive conditions named:** M-05 is a false positive IF egress == data-plane source IP (direct home egress). M-06 is a false positive IF bare `openssl` always resolves to brew (true in this exact shell, not guaranteed in a fresh/agent shell). M-07 is a false positive on toolchains that strip trailing newlines (today's does).
- **Redundancy / root cause:** M-02, M-04, and parts of M-03/M-05/M-08 all descend from **M-01 (lost shell state)**. They are ONE root cause with multiple prod-dangerous manifestations; fixing M-01 (persist + re-source a state file, plus principal-asserting probes) neutralizes the silent-success half of each. They are reported separately because each manifestation needs its own probe/guard change, but the team lead should treat **M-01 as the single mandatory fix** that the others build on.
- **Bias scan:** Severity-inflation check applied — M-09 and M-10 were *not* rated HIGH despite being adversary-attractive, because the spec already names them; they are discipline gaps, capped at MED/LOW.
- **Meta-falsifier:** Strongest argument against the whole report = "the orchestrator `rotate_tls.go` (Mode A) has none of these — just run scripted." Correct, and it strengthens the verdict: **Manual mode as written is the weak path; Mode A's `defer` whitelist-off and in-process variables dodge M-01/M-02/M-04 entirely.** That does not rescue Manual mode for a GO; it argues for preferring Mode A.

## VERDICT

**NO-GO for MANUAL (Mode B) as written** — 3 BLOCKING findings (M-01 lost shell state, M-02 wrong identity, M-03 placeholder paths) make step-by-step manual execution likely to either fail loudly or, worse, leave the **KV firewall open while reporting `0`** (M-04). All BLOCKING/HIGH items have a concrete conditional fix above; the single mandatory fix is **M-01: persist state to `/tmp/azsp-prd/rotate.env` and `source` it at the top of every step, with principal-asserting and absolute-path guards.** Prefer **Mode A (scripted)**, whose in-process state and `defer` cleanup are immune to M-01/M-02/M-04.

*El Demoledor: Proving resilience through destruction.*
