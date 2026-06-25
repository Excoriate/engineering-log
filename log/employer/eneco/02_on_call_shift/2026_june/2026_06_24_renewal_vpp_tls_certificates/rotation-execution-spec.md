---
title: PROD *.vpp.eneco.com Wildcard TLS Rotation — Validated Execution Spec (manual + scripted, explained)
status: review
author: Alex Torres (paired with Claude)
timestamp: 2026-06-24
review: socrates-contrarian + el-demoledor + sre-maniac (all HIGH findings resolved); MS-docs source-verified
companion: how-the-vpp-tls-rotation-works.md (the "why"); rotate_tls.go (the orchestrator)
---

# PROD `*.vpp.eneco.com` Wildcard TLS Rotation — Execution Spec

> **GATE: DO NOT RUN until Alex gives GO.** Every step below is written so an operator or agent with **no prior context** can run it: *what it does · why · the command · a probe that proves it worked · what could go wrong · what to do*. Two modes — **Scripted** (`rotate_tls.go`, recommended) and **Manual** (you run the `az` commands by hand). Read `how-the-vpp-tls-rotation-works.md` first for the mental model.

## Scope (100% confirmed)

| Item | Value |
|---|---|
| Environment | **PRODUCTION only** (dev/acc use different certs) |
| Subscription | `f007df01-9295-491c-b0e9-e3981f2df0b0` |
| Key Vault | `vpp-appsec-p` (RG `mcprd-rg-vpp-p-res`) |
| KV cert **object** (import a new version here) | `wildcard-vpp-eneco-com` |
| App Gateway | `vpp-ag-p` |
| AGW **ssl-cert resource** (≠ KV object name) | `wildcard-vpp-frontend-https` |
| Listeners served | `agg.` / `gurobi.` / `apollo.` / `flex-trade-optimizer.vpp.eneco.com` |
| Out of scope | apex `vpp.eneco.com` (`p-vpp-eneco-com`, exp Jul 20 — separate window) |
| Old cert expiry (the driver) | **2026-07-01** |

## The mechanism in one paragraph (so the steps make sense)

The App Gateway does not hold the certificate; it **references** the Key Vault object through a *versionless* link and serves whatever the latest **enabled** version is. So rotating = **import a new version under the same object name**, prove it's the right cert, enable it, then **force the gateway to re-pull** (a no-op `update` does *not* refresh — only changing the link does). Every step is gated by a probe so you advance only on proven success.

## ⏱️ Scheduling gate (HARD)

Execute **no later than 2026-06-27**. The rollback restores the *old* cert, which is only valid until **Jul 1**. After ~Jun 29, a bad-cert rollback would restore an already-expired cert (a second outage) → treat any late attempt as **fix-forward-only**. Earlier is strictly safer.

## Safety gates (apply throughout)

- **No one-way door** — importing a cert *version* is reversible data-plane (not a KV ForceNew/rename, not SQL immutability, not terraform).
- **Right identity, right subscription** — every `az` call passes `--subscription`; the SP session is verified before any mutation.
- **Whitelist-off is a `finally`** — the scripted mode guarantees it; in manual mode *you* must run Step 8 even on failure.
- **Success = EFFECT** — a TLS handshake serving the new cert, not `az` exit 0.
- **Regression → escalate** — if a listener serves a broken/old cert, roll back (before Jul 1); do not blind-retry.

## Preconditions (verify; nothing is mutated here)

```bash
test -s /tmp/mc-production.env && echo "PC1 creds ok"
PFX=".../certificate_to_renovate/26061584690-_-vpp-eneco-com.pfx"
PW=".../certificate_to_renovate/certificate_password.txt"
test -s "$PFX" && test -s "$PW" && echo "PC2 artifacts ok"
openssl pkcs12 -in "$PFX" -nokeys -clcerts -passin "file:$PW" -legacy 2>/dev/null | openssl x509 -noout -subject -enddate
# expect: subject=CN=*.vpp.eneco.com ; notAfter=Dec 30 ... 2026
```

- **PC3** (manual): confirm no in-flight prd `terraform apply` / open prd PR touching the AGW — an AGW apply mid-change re-pulls Key Vault and could race your rollback.
- **PC4** (manual): confirm you have an **AVD / internal-network path** that can reach the AGW **private** frontend `10.9.32.4:443` for the verify-effect handshake. (Verified 2026-06-24: every wildcard listener except `gurobi`'s public one is **private-frontend only**, and the AGW public IP `132.220.123.93` is **source-restricted** — a direct-IP TLS handshake from a normal laptop is blocked, so do **not** rely on it. The hostnames also don't resolve in public DNS.) **No AVD/internal path → NO-GO** (the change would be unverifiable).
- **PC5** (manual): today is before **2026-06-27**.

---

# Execution — Mode A: Scripted (recommended)

The orchestrator is **`rotate_tls.go`** — a single Go CLI that runs the Steps below as small, composable, **probe-gated** functions. It is **dry-run by default** (pass `-execute` to act) and removes the firewall rule on every exit path (`defer`). Each scripted step performs the same *action + probe* explained in the matching Manual step — read those for the full rationale.

```bash
# build once, then run the static binary
go build -o rotate_tls rotate_tls.go          # or: go run rotate_tls.go -step run
./rotate_tls -step run                         # SEE the whole plan + every probe (no mutation)
./rotate_tls -step run -execute                # execute end-to-end, probe-gated, cleanup guaranteed
# one verified step at a time (same names as Manual Steps 1-8 + rollback):
./rotate_tls -step whitelist-on   -execute     # Step 1
./rotate_tls -step baseline       -execute     # Step 2
./rotate_tls -step import         -execute     # Step 3
./rotate_tls -step verify-import  -execute     # Step 4 (aborts on mismatch; new version stays disabled)
./rotate_tls -step enable         -execute     # Step 5
./rotate_tls -step refresh        -execute     # Step 6
./rotate_tls -step verify-effect               # Step 7 (prints handshake commands for AVD)
./rotate_tls -step whitelist-off  -execute     # Step 8
./rotate_tls -step rollback       -execute     # Rollback
```

---

> **Canonical source of truth:** `rotate_tls.go` is the single source of truth for the commands. The Manual-mode commands below are the *same* commands the orchestrator's dry-run prints — if they ever differ, the **dry-run output wins** (`./rotate_tls -step <step>` shows the exact command).
> **Per-step cleanup:** a single step run with `-execute` does **NOT** auto-remove the firewall (only `run` defers whitelist-off). If you step manually, always finish with `./rotate_tls -step whitelist-off -execute`.

# Execution — Mode B: Manual (each step explained + probe-gated)

> You are the `finally`: if anything fails after Step 1, still run **Step 8**. Never advance until a step's **Probe** returns the expected value. The simplest cleanup is the orchestrator's own idempotent, self-probing step — `./rotate_tls -step whitelist-off -execute` — which works even if you ran everything else by hand and tells you loudly if the firewall is still open.

### Session setup (run once)

**What it does:** logs in as the production *service principal* in an isolated `az` config directory, selects the production subscription, and defines the variables the later steps reuse.
**Why:** certificate operations need an identity with both Key-Vault-firewall-write and certificate-**Import** rights. Your personal account has neither on prod (it returned `AuthorizationFailed`); the MC service principal has both. The isolated config (`AZURE_CONFIG_DIR`) keeps your normal `az` session untouched.

```bash
export AZURE_CONFIG_DIR=/tmp/azsp-prd
source /tmp/mc-production.env
az login --service-principal -u "$ARM_CLIENT_ID" -p "$ARM_CLIENT_SECRET" --tenant "$ARM_TENANT_ID" -o none --only-show-errors
az account set -s f007df01-9295-491c-b0e9-e3981f2df0b0
SUB=f007df01-9295-491c-b0e9-e3981f2df0b0; RG=mcprd-rg-vpp-p-res; KV=vpp-appsec-p
OBJ=wildcard-vpp-eneco-com; AGW=vpp-ag-p; SSL=wildcard-vpp-frontend-https
VLESS="https://vpp-appsec-p.vault.azure.net/secrets/wildcard-vpp-eneco-com"
PFX=".../certificate_to_renovate/26061584690-_-vpp-eneco-com.pfx"
PW=".../certificate_to_renovate/certificate_password.txt"
MYIP=$(curl -4 -s ifconfig.me); : "${MYIP:?no egress IP}"
```

**Probe (expect `f007df01-…`):**

```bash
az account show --query id -o tsv
```

**This proves:** you are authenticated as the right identity against the **production** subscription, so subsequent commands act where you intend.
**What could go wrong / what to do:**
- Output is **not** the prod sub → **STOP** (you'd mutate the wrong environment). Re-run `az account set -s …`.
- `az login` fails / `MYIP` empty → check `/tmp/mc-production.env` exists (re-cache from 1Password) and your network; do not proceed.

### Step 1 — open the KV firewall (surgical)

**What it does:** adds your current public IP to the Key Vault's firewall allow-list, then waits ~25 s for the rule to propagate.
**Why:** the vault's network default is **Deny**; without your IP, reading or importing a certificate fails with `403`. We add only the KV (not the broad storage/SQL alias) to keep the blast radius minimal.

```bash
az keyvault network-rule add --name "$KV" -g "$RG" --subscription "$SUB" --ip-address "${MYIP}/32" -o none && sleep 25
```

**Probe (expect `1`):**

```bash
az keyvault show -n "$KV" -g "$RG" --subscription "$SUB" --query "length(networkAcls.ipRules[?value=='${MYIP}/32'])" -o tsv
```

**This proves:** the firewall now allows your IP, so the data-plane steps (read/import) can reach the vault.
**What could go wrong / what to do:**
- `AuthorizationFailed` → the identity lacks KV write (you're not the SP — redo Session setup).
- Probe returns `0` → the rule didn't apply or your egress IP changed; re-check `MYIP` and re-run.
- Data-plane still 403 in later steps → propagation not finished; wait and retry (don't widen the rule).

### Step 2 — record the OLD version (rollback baseline)

**What it does:** captures the current (old) certificate version's secret identifier and thumbprint into shell variables.
**Why:** rollback works by repointing the gateway at *this exact old version*. You must capture it **before** importing the new one. If your shell dies you lose these — so echo and write them down.

```bash
OLD_SID=$(az keyvault certificate show --vault-name "$KV" --name "$OBJ" --query sid -o tsv)
OLD_THUMB=$(az keyvault certificate show --vault-name "$KV" --name "$OBJ" --query x509ThumbprintHex -o tsv | tr 'A-Z' 'a-z')
echo "OLD_SID=$OLD_SID   OLD_THUMB=$OLD_THUMB"   # WRITE THESE DOWN
```

**Probe (expect `OK enabled=true`):**

```bash
case "$OLD_SID" in */secrets/"$OBJ"/*) E=$(az keyvault certificate show --vault-name "$KV" --name "$OBJ" --query attributes.enabled -o tsv); echo "OK enabled=$E";; *) echo "BAD OLD_SID — STOP";; esac
```

**This proves:** you have a valid, *enabled*, versioned rollback target for this exact object.
**What could go wrong / what to do:**
- `BAD OLD_SID` → wrong object/KV name in Session setup → **STOP** and fix.
- `enabled=false` → the old version isn't enabled, so a disable-based fallback couldn't resolve to it. Don't rely on rollback; make sure an enabled prior version exists before continuing.

### Step 3 — import the new version, DISABLED (not live yet)

**What it does:** imports the new PFX as a **new version** of the existing object, created in the **disabled** state.
**Why:** importing under the *same object name* (not a new object) is what the versionless gateway link will pick up. Creating it **disabled** means a wrong cert can never go live before the Step-4 thumbprint gate passes — verification happens *before* exposure.

```bash
IMP=$(az keyvault certificate import --vault-name "$KV" --name "$OBJ" --file "$PFX" --password "$(cat "$PW")" --disabled -o json)
NEW_SID=$(echo "$IMP" | jq -r .sid)
NEW_VER=$(echo "$IMP" | jq -r .id | awk -F/ '{print $NF}')
NEW_THUMB=$(echo "$IMP" | jq -r .x509ThumbprintHex | tr 'A-Z' 'a-z')
echo "NEW_SID=$NEW_SID   NEW_VER=$NEW_VER   NEW_THUMB=$NEW_THUMB"
```

**Probe (expect `false`):**

```bash
az keyvault certificate show --vault-name "$KV" --name "$OBJ" --version "$NEW_VER" --query attributes.enabled -o tsv
```

**This proves:** the new certificate bytes are in the vault but **not serving anything yet** — safe to inspect.
**What could go wrong / what to do:**
- Import errors with HTTP `400` / "invalid PKCS12 / unsupported algorithm" → the **service** rejected the legacy-encrypted PFX. Re-encode to a modern PKCS12 (see Notes) and import that instead. (The local `-legacy` need does **not** by itself cause this — `az` ships raw bytes.)
- Probe returns `true` → the `--disabled` flag didn't apply; immediately disable that version before continuing, or you've lost the gate-before-exposure guarantee.

### Step 4 — GATE: imported thumbprint must equal the held PFX

**What it does:** computes the SHA1 thumbprint of the held PFX and compares it (case-normalized) to the thumbprint the vault recorded for the imported version.
**Why:** this proves the bytes now in the vault are **exactly** the certificate you intended — not a stale, truncated, or wrong import. It is the safety gate before anything goes live.

```bash
EXPECT=$(openssl pkcs12 -in "$PFX" -nokeys -clcerts -passin "file:$PW" -legacy 2>/dev/null | openssl x509 -noout -fingerprint -sha1 | sed 's/.*=//; s/://g' | tr 'A-Z' 'a-z')
[ -n "$EXPECT" ] && [ "$EXPECT" = "$NEW_THUMB" ] && echo "✅ MATCH" || echo "❌ MISMATCH — STOP"
```

**This proves:** the vault holds your exact new certificate (identity confirmed by cryptographic fingerprint).
**What could go wrong / what to do:**
- `❌ MISMATCH` → do **NOT** enable. The new version stays disabled (harmless). Investigate (wrong file? truncated upload?), then go to **Step 8** to clean up the firewall.
- `EXPECT` empty → openssl couldn't read the PFX (wrong password file) → fix and re-run; do not proceed.

### Step 5 — enable the new version (only if Step 4 matched)

**What it does:** enables the imported version, making it the **latest enabled** version of the object.
**Why:** the gateway's versionless link resolves to the *latest enabled* version. Enabling is what makes the new certificate the one the vault will hand out.

```bash
az keyvault certificate set-attributes --vault-name "$KV" --name "$OBJ" --version "$NEW_VER" --enabled true -o none
```

**Probe (expect `true`, then a thumbprint equal to `$NEW_THUMB`):**

```bash
az keyvault certificate show --vault-name "$KV" --name "$OBJ" --version "$NEW_VER" --query attributes.enabled -o tsv
LATEST=$(az keyvault certificate show --vault-name "$KV" --name "$OBJ" --query x509ThumbprintHex -o tsv | tr 'A-Z' 'a-z'); echo "latest=$LATEST new=$NEW_THUMB"
[ "$LATEST" = "$NEW_THUMB" ] && echo "✅ versionless now resolves to NEW" || echo "❌ STOP"
```

**This proves:** a versionless read of the object now returns your new certificate — i.e. the vault side of the rotation is complete.
**What could go wrong / what to do:**
- `latest != new` → a different/newer version exists or was imported in parallel. List versions, sort out which should be latest-enabled, and do **not** refresh the gateway until this resolves to `new`.

### Step 6 — force the App Gateway to re-pull (empty `update` does NOT work)

**What it does:** briefly points the gateway's ssl-cert at the **versioned** new URI (a real config change), then restores the **versionless** URI.
**Why:** Microsoft documents that the gateway re-fetches **only when its configured `keyVaultSecretId` changes** — an empty `az network application-gateway update` finishes successfully but does **not** refresh. The versioned→versionless toggle forces an immediate pull; restoring versionless keeps auto-rotation working and matches what terraform stores (so no drift).

```bash
az network application-gateway ssl-cert update -g "$RG" --gateway-name "$AGW" -n "$SSL" --key-vault-secret-id "$NEW_SID" -o none
az network application-gateway ssl-cert update -g "$RG" --gateway-name "$AGW" -n "$SSL" --key-vault-secret-id "$VLESS" -o none
```

**Probe (expect `Succeeded`, then a URI ending `/secrets/wildcard-vpp-eneco-com`):**

```bash
az network application-gateway show -g "$RG" -n "$AGW" --query provisioningState -o tsv
az network application-gateway ssl-cert show -g "$RG" --gateway-name "$AGW" -n "$SSL" --query keyVaultSecretId -o tsv
```

**This proves:** the gateway accepted the change (healthy) and is back on the versionless link (auto-rotation preserved, no terraform drift).
**What could go wrong / what to do:**
- `provisioningState=Failed` → the gateway couldn't access the vault/cert (permission, network, or cert state). Check the gateway's Resource Health; the listener may be auto-disabled — fix the vault access before anything else.
- The second probe still shows a **version GUID** → the restore didn't apply; re-run the restore line, or auto-rotation stays off and terraform will show drift.

### Step 7 — verify the EFFECT (run from AVD / internal — listeners are private)

**What it does:** opens a real TLS handshake to each of the four hosts and reads the served certificate's expiry and thumbprint.
**Why:** this is the **only** proof the rotation actually took effect end-to-end. `az` exit 0 only proves a control-plane write; it does **not** prove the gateway is serving the new leaf. The listeners are private, so this must run from AVD or the internal network.

```bash
for h in agg.vpp.eneco.com gurobi.vpp.eneco.com apollo.vpp.eneco.com flex-trade-optimizer.vpp.eneco.com; do
  echo "== $h =="; echo | openssl s_client -connect "$h:443" -servername "$h" 2>/dev/null | openssl x509 -noout -enddate -fingerprint -sha1
done
```

**Probe (expect on ALL four):** `notAfter=Dec 30 23:59:59 2026 GMT`, **and** the served fingerprint equals the new cert. The handshake prints `SHA1 Fingerprint=AA:BB:…` (upper-case, colons) while `$NEW_THUMB` is lower-case no-colons — normalize before comparing:

```bash
# served fingerprint, normalized to match $NEW_THUMB (lower-case, no colons)
echo | openssl s_client -connect agg.vpp.eneco.com:443 -servername agg.vpp.eneco.com 2>/dev/null \
  | openssl x509 -noout -fingerprint -sha1 | sed 's/.*=//; s/://g' | tr 'A-Z' 'a-z'   # == $NEW_THUMB
```
**This proves:** real clients now receive the new certificate — the rotation is genuinely done.
**What could go wrong / what to do:**
- Still the **old** expiry → the re-pull didn't propagate. Re-run Step 6, wait a minute, re-check; inspect the gateway's Resource Health.
- Hosts **unreachable** → you are not on AVD/internal (the listeners are on the private frontend `10.9.32.4`; the public frontend is source-restricted) → success is **unverifiable** → do **not** declare done; get on AVD/internal and re-check. As an interim from-this-machine signal you still have the control-plane proxies (KV latest-enabled thumbprint == new, AGW `provisioningState=Succeeded`, ssl-cert on the versionless URI, Resource Health = Available) — strong for a like-for-like renewal, but not a substitute for the wire handshake.

### Step 8 — remove the whitelist (MANDATORY — your `finally`)

**What it does:** removes your IP from the Key Vault firewall.
**Why:** leaving it open is a standing security exposure and a terraform drift. Run this **even if an earlier step failed**.

```bash
az keyvault network-rule remove --name "$KV" -g "$RG" --subscription "$SUB" --ip-address "${MYIP}/32" -o none
```

**Probe (expect `0`):**

```bash
az keyvault show -n "$KV" -g "$RG" --subscription "$SUB" --query "length(networkAcls.ipRules[?value=='${MYIP}/32'])" -o tsv
```

**This proves:** the vault firewall is back to its locked baseline; no residual exposure or drift.
**What could go wrong / what to do:**
- Non-zero → the remove didn't apply; re-run until it returns `0`.
- Your IP changed mid-session → the remove targeted the wrong value; list all rules (`… --query "networkAcls.ipRules[].value"`) and remove the stale one.

### Rollback (emergency — only useful while the OLD cert is unexpired, before Jul 1)

**What it does:** repoints the gateway directly at the OLD version's URI and disables the new version.
**Why:** if the new cert serves wrong/broken, this restores the previous working cert immediately. It is only safe while the old cert is still valid (before **Jul 1**).

```bash
# R-4: confirm the OLD version is STILL enabled NOW before pointing prod at it.
# (Pointing AGW at a disabled/unresolvable version => listener auto-disable => outage.)
OLD_VER="${OLD_SID##*/}"
az keyvault certificate show --vault-name "$KV" --name "$OBJ" --version "$OLD_VER" --query attributes.enabled -o tsv   # MUST be 'true'; if not → STOP, fix forward (do NOT repoint)
# then repoint + park the new version:
az network application-gateway ssl-cert update -g "$RG" --gateway-name "$AGW" -n "$SSL" --key-vault-secret-id "$OLD_SID" -o none
az keyvault certificate set-attributes --vault-name "$KV" --name "$OBJ" --version "$NEW_VER" --enabled false -o none
```

**Probe (expect ssl-cert == `$OLD_SID`, new version `false`):**

```bash
az network application-gateway ssl-cert show -g "$RG" --gateway-name "$AGW" -n "$SSL" --query keyVaultSecretId -o tsv   # == $OLD_SID
az keyvault certificate show --vault-name "$KV" --name "$OBJ" --version "$NEW_VER" --query attributes.enabled -o tsv     # == false
```

**This proves:** the gateway is back on the old (working) certificate and the new one is parked.
**What could go wrong / what to do:**
- After **Jul 1** the old cert is expired → rollback would restore an expired cert (a second outage) → **fix forward** with a re-issued PFX instead.
- The gateway is now pinned to a versioned URI (temporary terraform drift) → once a good cert is staged, restore the **versionless** URI (Step 6's restore line) and re-verify (Step 7).

---

## Monitoring (watch live during the window)

- `vpp-ag-p` `provisioningState` = `Succeeded`; Resource Health = `Available`.
- The gateway **disables a listener** if it cannot fetch the cert → watch Resource Health + the repo alert `terraform/metric-alert-app-gateway.tf` / Rootly for ~1 poll cycle after the change.

## Notes / residual

- **Legacy PFX**: `az ... import` sends the raw PFX bytes to the Key Vault *service* (it does not parse them client-side), so the local `-legacy` requirement does not affect import. Re-encode to a modern PKCS12 **only if** the service returns an HTTP 400 PKCS12/algorithm error:
  `openssl pkcs12 -in "$PFX" -legacy -nodes -passin "file:$PW" -out /tmp/c.pem && openssl pkcs12 -export -in /tmp/c.pem -keypbe AES-256-CBC -certpbe AES-256-CBC -out /tmp/modern.pfx -passout pass:TMP && shred -u /tmp/c.pem` then import `/tmp/modern.pfx` with `--password TMP`.
- **Password in `ps`**: `--password "$(cat …)"` is briefly visible in the process table — acceptable on this single-operator laptop; not on a shared host.
- **Cross-subscription completeness (bounded residual)**: proven complete for the prod subscription; a Sandbox/iactest sweep needs your multi-sub identity (`az login` as yourself + a Resource-Graph query) — low risk, optional, before claiming org-wide completeness.
