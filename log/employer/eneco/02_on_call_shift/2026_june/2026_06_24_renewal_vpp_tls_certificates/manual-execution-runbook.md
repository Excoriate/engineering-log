---
title: PROD *.vpp.eneco.com TLS rotation — HARDENED manual execution runbook (agent step-by-step)
status: partial
author: Alex Torres (paired with Claude)
timestamp: 2026-06-25
source_spec: rotation-execution-spec.md
hardening: applies el-demoledor + socrates + kant receipts (see .ai/tasks/2026-06-25-001_tls-cert-rotation-prod/adversarial/00-receipts-synthesis.md)
execution_model: AI agent runs ONE step per fresh Bash call; cross-step state persisted to /tmp/azsp-prd/rotate.env and re-sourced each step
---

# HARDENED Manual Runbook — PROD `*.vpp.eneco.com` wildcard TLS rotation

> **GATE: each step runs ONLY on Alex's explicit "go" for THAT step.** Nothing here is destructive until **Step 1**.
> Today **2026-06-25** · hard schedule gate **≤2026-06-27** · rollback-to-old valid until **Jul 1** (so rollback OK before ~Jun 29).

## Scope (frozen)

| Item | Value |
|---|---|
| Subscription | `f007df01-9295-491c-b0e9-e3981f2df0b0` (PRODUCTION) |
| Key Vault | `vpp-appsec-p` (RG `mcprd-rg-vpp-p-res`) |
| KV cert **object** | `wildcard-vpp-eneco-com` (import a new version here) |
| AGW | `vpp-ag-p` |
| AGW **ssl-cert resource** (≠ object) | `wildcard-vpp-frontend-https` |
| Hosts served | agg / gurobi / apollo / flex-trade-optimizer `.vpp.eneco.com` |
| New cert (held PFX) | exp **Dec 30 2026**, SHA-1 `b8202de20be7fb3fb37e6d5141975282bf33bde7` |
| Old cert | exp **Jul 1 2026** |

## Standing invariants (re-asserted every step)

- **INV-1 — state is on disk, not in the shell.** Each step begins by `source`-ing `/tmp/azsp-prd/rotate.env` and runs `:?` guards; a missing var **HALTS** (never proceed/retry-blind).
- **INV-2 — STOP = STOP-FORWARD-THROUGH-STEP-8.** From Step 1 on, the KV firewall is OPEN. The run may NOT end — success **or** failure — until Step 8's probe shows the firewall back to baseline. Any `STOP`/`❌` means: stop the rotation, **then run Step 8 and confirm baseline**, then escalate.
- **INV-3 — "done" only on the wire.** Completion requires the AVD handshake showing `notAfter Dec 30 2026` **and** the new thumbprint on **all four** hosts. `provisioningState=Succeeded`/`enabled=true`/`latest==new`/Resource-Health are **interim** signals, tagged `[UNVERIFIED[blocked]]`, never "done".
- **INV-4 — absolute openssl.** Always `/opt/homebrew/bin/openssl` (LibreSSL at `/usr/bin` lacks `-legacy`); an empty `EXPECT` is a STOP.
- **INV-5 — two-name discipline.** KV **object** = `wildcard-vpp-eneco-com` (holds versions). AGW **ssl-cert** = `wildcard-vpp-frontend-https` (references it). Never pass one where the other belongs.
- **INV-6 — exact-match probes, empty = FAIL.** Every probe asserts the expected literal and prints `[$v]` so a blank result is visible and treated as failure, never as "absence of the bad value".

Per-step preamble (prepended to every step Bash block):
```bash
export AZURE_CONFIG_DIR=/tmp/azsp-prd
. /tmp/azsp-prd/rotate.env 2>/dev/null
OSSL=/opt/homebrew/bin/openssl
LOG=/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/log/employer/eneco/02_on_call_shift/2026_june/2026_06_24_renewal_vpp_tls_certificates/execution-evidence.md
```

---

## Step 0 — Session setup + PRE-MUTATION re-verifies (NON-destructive)

Logs in as the prod SP in an isolated config dir, writes the state file, and re-checks the four things that could have drifted since 2026-06-24 — all read-only, no firewall change.

```bash
mkdir -p /tmp/azsp-prd
export AZURE_CONFIG_DIR=/tmp/azsp-prd
. /tmp/mc-production.env                      # ARM_* (secret stays out of rotate.env)
az login --service-principal -u "$ARM_CLIENT_ID" -p "$ARM_CLIENT_SECRET" --tenant "$ARM_TENANT_ID" -o none --only-show-errors
az account set -s f007df01-9295-491c-b0e9-e3981f2df0b0

cat > /tmp/azsp-prd/rotate.env <<'EOF'
export AZURE_CONFIG_DIR=/tmp/azsp-prd
export SUB=f007df01-9295-491c-b0e9-e3981f2df0b0
export RG=mcprd-rg-vpp-p-res
export KV=vpp-appsec-p
export OBJ=wildcard-vpp-eneco-com
export AGW=vpp-ag-p
export SSL=wildcard-vpp-frontend-https
export VLESS=https://vpp-appsec-p.vault.azure.net/secrets/wildcard-vpp-eneco-com
export PFX=/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/log/employer/eneco/02_on_call_shift/2026_june/2026_06_24_renewal_vpp_tls_certificates/certificate_to_renovate/26061584690-_-vpp-eneco-com.pfx
export PW=/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/log/employer/eneco/02_on_call_shift/2026_june/2026_06_24_renewal_vpp_tls_certificates/certificate_to_renovate/certificate_password.txt
export EXPECT_THUMB=b8202de20be7fb3fb37e6d5141975282bf33bde7
export SP_OBJID=686d817d-86b9-4d8f-9aa4-8212cf12931a
EOF
echo "export MYIP=$(curl -4 -s ifconfig.me)" >> /tmp/azsp-prd/rotate.env
. /tmp/azsp-prd/rotate.env
: "${MYIP:?no egress IP}"; : "${PFX:?}"; test -s "$PFX" || echo "FAIL PFX missing [$PFX]"

# P0a identity = SP on prod (assert PRINCIPAL, not just sub)
echo "acct.id   = $(az account show --query id -o tsv)          (expect f007df01-…)"
echo "acct.type = $(az account show --query user.type -o tsv)   (expect servicePrincipal)"
# P0b SP STILL has cert Import right  [H2]
echo "sp.certperms = $(az keyvault show -n "$KV" -g "$RG" --subscription "$SUB" --query "properties.accessPolicies[?objectId=='$SP_OBJID'].permissions.certificates" -o tsv)  (expect …Import…)"
# P0c AGW ssl-cert STILL on versionless URI (drift)  [H3]
CUR=$(az network application-gateway ssl-cert show -g "$RG" --gateway-name "$AGW" -n "$SSL" --query keyVaultSecretId -o tsv)
[ "$CUR" = "$VLESS" ] && echo "P0c PASS versionless intact" || echo "P0c FAIL ssl-cert=[$CUR] (someone mid-change?) — STOP"
# P0d AGW healthy
echo "agw.state = $(az network application-gateway show -g "$RG" -n "$AGW" --query provisioningState -o tsv)  (expect Succeeded)"
# P0e firewall BASELINE captured  [H4]
az keyvault network-rule list --name "$KV" -g "$RG" --subscription "$SUB" --query "ipRules[].value" -o tsv | sort > /tmp/azsp-prd/kv-fw-baseline.txt
echo "fw.baseline_count = $(grep -c . /tmp/azsp-prd/kv-fw-baseline.txt 2>/dev/null || echo 0)  (expect 0 — my IP absent)"
```
**Advance only if:** acct.type=`servicePrincipal`, certperms include `Import`, P0c PASS, agw=`Succeeded`, baseline as expected. Any FAIL → STOP (no firewall opened yet, so nothing to clean).

---

## Step 1 — open the KV firewall (FIRST mutation)

```bash
export AZURE_CONFIG_DIR=/tmp/azsp-prd; . /tmp/azsp-prd/rotate.env
: "${KV:?}"; : "${RG:?}"; : "${SUB:?}"; : "${MYIP:?}"
az keyvault network-rule add --name "$KV" -g "$RG" --subscription "$SUB" --ip-address "${MYIP}/32" -o none && sleep 25
v=$(az keyvault network-rule list --name "$KV" -g "$RG" --subscription "$SUB" --query "length(ipRules[?value=='${MYIP}/32'])" -o tsv)
[ "$v" = "1" ] && echo "PASS firewall now allows ${MYIP}/32" || echo "FAIL got=[$v] — STOP→Step8"
```
**From here INV-2 is live: the firewall is OPEN until Step 8 confirms baseline.**

## Step 2 — baseline OLD version + drift check (persist)

```bash
export AZURE_CONFIG_DIR=/tmp/azsp-prd; . /tmp/azsp-prd/rotate.env
: "${KV:?}"; : "${OBJ:?}"
OLD_SID=$(az keyvault certificate show --vault-name "$KV" --name "$OBJ" --query sid -o tsv)
OLD_THUMB=$(az keyvault certificate show --vault-name "$KV" --name "$OBJ" --query x509ThumbprintHex -o tsv | tr 'A-Z' 'a-z')
OLD_EXP=$(az keyvault certificate show --vault-name "$KV" --name "$OBJ" --query attributes.expires -o tsv)
: "${OLD_SID:?empty OLD_SID — STOP→Step8}"
printf 'export OLD_SID=%s\nexport OLD_THUMB=%s\n' "$OLD_SID" "$OLD_THUMB" >> /tmp/azsp-prd/rotate.env
echo "OLD_SID=$OLD_SID"; echo "OLD_THUMB=$OLD_THUMB"; echo "OLD_EXP=$OLD_EXP  (expect ~2026-07-01)"
# drift: object must NOT already be the new cert
[ "$OLD_THUMB" = "$EXPECT_THUMB" ] && echo "STOP — object already holds the NEW cert (already rotated?)"
# enabled + sid shape
case "$OLD_SID" in */secrets/"$OBJ"/*) E=$(az keyvault certificate show --vault-name "$KV" --name "$OBJ" --query attributes.enabled -o tsv); [ "$E" = "true" ] && echo "PASS OLD enabled (rollback target valid)" || echo "FAIL OLD enabled=[$E]";; *) echo "FAIL BAD OLD_SID=[$OLD_SID] — STOP→Step8";; esac
```

## Step 3 — import new version, DISABLED (+ self-heal)

```bash
export AZURE_CONFIG_DIR=/tmp/azsp-prd; . /tmp/azsp-prd/rotate.env
: "${KV:?}"; : "${OBJ:?}"; : "${PFX:?}"; : "${PW:?}"; test -s "$PFX" || { echo "FAIL PFX [$PFX] — STOP→Step8"; exit 1; }
IMP=$(az keyvault certificate import --vault-name "$KV" --name "$OBJ" --file "$PFX" --password "$(cat "$PW")" --disabled -o json)
NEW_SID=$(echo "$IMP" | jq -r .sid); NEW_VER=$(echo "$IMP" | jq -r .id | awk -F/ '{print $NF}'); NEW_THUMB=$(echo "$IMP" | jq -r .x509ThumbprintHex | tr 'A-Z' 'a-z')
: "${NEW_VER:?import failed — STOP→Step8}"
printf 'export NEW_SID=%s\nexport NEW_VER=%s\nexport NEW_THUMB=%s\n' "$NEW_SID" "$NEW_VER" "$NEW_THUMB" >> /tmp/azsp-prd/rotate.env
echo "NEW_SID=$NEW_SID"; echo "NEW_VER=$NEW_VER"; echo "NEW_THUMB=$NEW_THUMB"
EN=$(az keyvault certificate show --vault-name "$KV" --name "$OBJ" --version "$NEW_VER" --query attributes.enabled -o tsv)
[ "$EN" = "false" ] || { echo "WARN not disabled — re-disabling"; az keyvault certificate set-attributes --vault-name "$KV" --name "$OBJ" --version "$NEW_VER" --enabled false -o none; EN=$(az keyvault certificate show --vault-name "$KV" --name "$OBJ" --version "$NEW_VER" --query attributes.enabled -o tsv); }
[ "$EN" = "false" ] && echo "PASS imported DISABLED (not live)" || echo "FAIL enabled=[$EN] — STOP→Step8"
```
- If import errors HTTP 400 (PKCS12/algorithm) → re-encode per spec Notes, then re-import. Otherwise do not re-encode.

## Step 4 — GATE: vault bytes == held PFX == expected (independent re-read)

```bash
export AZURE_CONFIG_DIR=/tmp/azsp-prd; . /tmp/azsp-prd/rotate.env
: "${PFX:?}"; : "${NEW_VER:?}"; : "${EXPECT_THUMB:?}"
EXPECT=$("$OSSL" pkcs12 -in "$PFX" -nokeys -clcerts -passin "file:$PW" -legacy 2>/dev/null | "$OSSL" x509 -noout -fingerprint -sha1 | sed 's/.*=//; s/://g' | tr 'A-Z' 'a-z')
[ -n "$EXPECT" ] || { echo "FAIL EXPECT empty — wrong openssl — STOP→Step8"; exit 1; }
VAULT_THUMB=$(az keyvault certificate show --vault-name "$KV" --name "$OBJ" --version "$NEW_VER" --query x509ThumbprintHex -o tsv | tr 'A-Z' 'a-z')
echo "EXPECT=$EXPECT"; echo "VAULT=$VAULT_THUMB"; echo "EXPECT_THUMB=$EXPECT_THUMB"
[ "$EXPECT" = "$VAULT_THUMB" ] && [ "$VAULT_THUMB" = "$EXPECT_THUMB" ] && echo "✅ MATCH (vault holds exactly our cert)" || echo "❌ MISMATCH — STOP→Step8 (new version stays disabled, harmless)"
```

## Step 5 — enable the new version (only if Step 4 ✅)

```bash
export AZURE_CONFIG_DIR=/tmp/azsp-prd; . /tmp/azsp-prd/rotate.env
: "${OBJ:?}"; : "${NEW_VER:?}"; : "${NEW_THUMB:?}"; : "${EXPECT_THUMB:?}"
az keyvault certificate set-attributes --vault-name "$KV" --name "$OBJ" --version "$NEW_VER" --enabled true -o none
EN=$(az keyvault certificate show --vault-name "$KV" --name "$OBJ" --version "$NEW_VER" --query attributes.enabled -o tsv)
LATEST=$(az keyvault certificate show --vault-name "$KV" --name "$OBJ" --query x509ThumbprintHex -o tsv | tr 'A-Z' 'a-z')
echo "enabled=[$EN] latest=[$LATEST] new=[$NEW_THUMB]"
[ "$EN" = "true" ] && [ -n "$LATEST" ] && [ "$LATEST" = "$NEW_THUMB" ] && [ "$LATEST" = "$EXPECT_THUMB" ] && echo "✅ versionless resolves to NEW" || echo "❌ STOP→Step8"
```

## Step 6 — force AGW re-pull, then restore versionless

```bash
export AZURE_CONFIG_DIR=/tmp/azsp-prd; . /tmp/azsp-prd/rotate.env
: "${RG:?}"; : "${AGW:?}"; : "${SSL:?}"; : "${NEW_SID:?}"; : "${VLESS:?}"
[ "$(az network application-gateway ssl-cert show -g "$RG" --gateway-name "$AGW" -n "$SSL" --query name -o tsv)" = "$SSL" ] || { echo "FAIL ssl-cert name mismatch — STOP→Step8"; exit 1; }
az network application-gateway ssl-cert update -g "$RG" --gateway-name "$AGW" -n "$SSL" --key-vault-secret-id "$NEW_SID" -o none   # versioned (force)
az network application-gateway ssl-cert update -g "$RG" --gateway-name "$AGW" -n "$SSL" --key-vault-secret-id "$VLESS" -o none     # restore versionless
PS=$(az network application-gateway show -g "$RG" -n "$AGW" --query provisioningState -o tsv)
CUR=$(az network application-gateway ssl-cert show -g "$RG" --gateway-name "$AGW" -n "$SSL" --query keyVaultSecretId -o tsv)
echo "provisioningState=[$PS] sslcert=[$CUR]"
[ "$PS" = "Succeeded" ] && [ "$CUR" = "$VLESS" ] && echo "PASS re-pulled + versionless restored" || echo "FAIL — if CUR≠VLESS re-run the restore line until equal; then re-probe"
```
> NOTE: control-plane only. **NOT done** — Step 7 is the proof.

## Step 7 — VERIFY THE EFFECT (Alex runs on AVD / internal — HARD GATE, all four)

```bash
EXPECT_THUMB=b8202de20be7fb3fb37e6d5141975282bf33bde7
for h in agg.vpp.eneco.com gurobi.vpp.eneco.com apollo.vpp.eneco.com flex-trade-optimizer.vpp.eneco.com; do
  echo "== $h =="
  served=$(echo | openssl s_client -connect "$h:443" -servername "$h" 2>/dev/null | openssl x509 -noout -enddate -fingerprint -sha1)
  echo "$served"
  norm=$(printf '%s\n' "$served" | sed -n 's/.*SHA1 Fingerprint=//p' | tr -d ':' | tr 'A-Z' 'a-z')
  [ "$norm" = "$EXPECT_THUMB" ] && echo "  OK serves NEW" || echo "  MISMATCH got=[$norm]"
done
```
**PASS = all four show `notAfter=Dec 30 23:59:59 2026 GMT` AND "OK serves NEW".** Paste the output back; I record it as the completion witness.
- Any host still OLD expiry → bounded retry (see Rollback box): re-run Step 6, wait ~1 min, re-handshake; **max 2 cycles**, then decide by the clock.
- AVD unreachable → status `partial` / `[UNVERIFIED[blocked]]`, **not done**.

> **LIVE CORRECTION (2026-06-25, Step 1):** `az keyvault show --query "networkAcls.ipRules"` returns EMPTY — the correct path is `az keyvault network-rule list … --query "ipRules…"` (or `properties.networkAcls.ipRules`). The prod KV firewall is **NOT empty**: baseline = **6 pre-existing rules to PRESERVE** (`132.220.123.93`, `20.8.40.144`, `40.118.58.239`, `40.67.207.92`, `62.145.36.17`, `82.174.84.43` — all `/32`) + the appgw vnet rule. `kv-fw-baseline.txt` holds these 6. **Step 8 removes ONLY `84.86.32.39/32` and must leave the 6 intact.**

## Step 8 — remove the whitelist (MANDATORY finally — enumerate + baseline assert)

```bash
export AZURE_CONFIG_DIR=/tmp/azsp-prd; . /tmp/azsp-prd/rotate.env
: "${KV:?}"; : "${RG:?}"; : "${SUB:?}"
base=/tmp/azsp-prd/kv-fw-baseline.txt
for ip in $(az keyvault network-rule list --name "$KV" -g "$RG" --subscription "$SUB" --query "ipRules[].value" -o tsv); do
  grep -qxF "$ip" "$base" 2>/dev/null || { echo "removing operator-added $ip"; az keyvault network-rule remove --name "$KV" -g "$RG" --subscription "$SUB" --ip-address "$ip" -o none; }
done
now=$(az keyvault network-rule list --name "$KV" -g "$RG" --subscription "$SUB" --query "ipRules[].value" -o tsv | sort)
ncount=$(printf '%s\n' "$now" | sed '/^$/d' | wc -l | tr -d ' '); bcount=$(sed '/^$/d' "$base" | wc -l | tr -d ' ')
echo "now_count=[$ncount] baseline_count=[$bcount] now=[$now]"
[ "$ncount" = "$bcount" ] && echo "PASS firewall back to baseline (no residual exposure)" || echo "FAIL — firewall NOT at baseline; re-run until equal"
```

## Rollback (emergency — only before ~Jun 29, while OLD cert unexpired)

```bash
export AZURE_CONFIG_DIR=/tmp/azsp-prd; . /tmp/azsp-prd/rotate.env
: "${OLD_SID:?}"; : "${NEW_VER:?}"; : "${RG:?}"; : "${AGW:?}"; : "${SSL:?}"; : "${KV:?}"; : "${OBJ:?}"
OLD_VER="${OLD_SID##*/}"; : "${OLD_VER:?}"
EN=$(az keyvault certificate show --vault-name "$KV" --name "$OBJ" --version "$OLD_VER" --query attributes.enabled -o tsv)
[ "$EN" = "true" ] || { echo "STOP OLD enabled=[$EN] — do NOT repoint; FIX FORWARD"; exit 1; }
az network application-gateway ssl-cert update -g "$RG" --gateway-name "$AGW" -n "$SSL" --key-vault-secret-id "$OLD_SID" -o none
az keyvault certificate set-attributes --vault-name "$KV" --name "$OBJ" --version "$NEW_VER" --enabled false -o none
echo "sslcert=[$(az network application-gateway ssl-cert show -g "$RG" --gateway-name "$AGW" -n "$SSL" --query keyVaultSecretId -o tsv)]  (== OLD_SID)"
echo "new_enabled=[$(az keyvault certificate show --vault-name "$KV" --name "$OBJ" --version "$NEW_VER" --query attributes.enabled -o tsv)]  (== false)"
```
**Retry/rollback decision (G7):** Step-7 OLD expiry → re-run Step 6 + re-handshake, **max 2 cycles**. Still OLD after cycle 2, or `provisioningState=Failed`, or a listener auto-disabled → STOP retrying. If **today < 2026-06-29** → Rollback (above). If **≥ 2026-06-29** → fix-forward only (a rollback would restore a soon/expired cert). Then run **Step 8**.

## Monitoring (during the window)
- `vpp-ag-p` `provisioningState=Succeeded`; Resource Health = `Available`.
- AGW disables a listener if it can't fetch the cert → watch Resource Health + repo alert `terraform/metric-alert-app-gateway.tf` / Rootly ~1 poll cycle after Step 6.

## Cleanup at task end (after success confirmed)
```bash
export AZURE_CONFIG_DIR=/tmp/azsp-prd
az logout --only-show-errors 2>/dev/null
rm -rf /tmp/azsp-prd          # state file + isolated az session
# (keep /tmp/mc-production.env until the whole task is closed)
```
