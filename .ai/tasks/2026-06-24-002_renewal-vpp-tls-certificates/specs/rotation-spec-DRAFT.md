---
title: PROD *.vpp.eneco.com wildcard TLS rotation — execution spec (DRAFT, pre-adversarial-review)
task_id: 2026-06-24-002
agent: claude-opus-4-8
status: draft
summary: CLI-only execution spec to rotate the *.vpp.eneco.com wildcard cert in prod KV vpp-appsec-p (object wildcard-vpp-eneco-com), import-new-version model, with per-step verification, rollback, surgical whitelist-off finally, and safety gates. DRAFT pending el-demoledor + sre-maniac + socrates review.
timestamp: 2026-06-24T00:00:00Z
---

# PROD `*.vpp.eneco.com` Wildcard TLS Rotation — Execution Spec (DRAFT)

> STATUS: DRAFT — NOT approved. Blocked on (1) el-demoledor + sre-maniac + socrates review, (2) user GO/NO-GO.
> All commands are CLI (no portal click-ops). Identity = prd MC SP (cached). Surgical KV-only whitelist, reverted in a `finally`.

## 0. Scope (confirmed — see context/02-scope-confirmed.md)

| Item | Value |
|---|---|
| Environment | PRODUCTION only (dev/acc excluded by live cert content) |
| Subscription | `f007df01-9295-491c-b0e9-e3981f2df0b0` |
| Key Vault | `vpp-appsec-p` (RG `mcprd-rg-vpp-p-res`) |
| Cert object (import NEW VERSION) | `wildcard-vpp-eneco-com` |
| App Gateway | `vpp-ag-p` (RG `mcprd-rg-vpp-p-res`) |
| Listeners affected | `agg.` / `gurobi.` / `apollo.` / `flex-trade-optimizer.vpp.eneco.com` |
| NOT in scope | apex `vpp.eneco.com` (separate object `p-vpp-eneco-com`, exp Jul 20 2026) |
| Driver | current cert expires **Jul 1 2026** |

## 1. Safety gates (eneco-sre, identity-credential-expiry surface)

- **No one-way door**: importing a cert *version* is a reversible data-plane op — NOT a KV ForceNew/rename, NOT SQL immutability, NOT terraform. (Confirm the cert object is not terraform-managed — see Open Risk OR-1.)
- **Wrong-subscription trap**: every `az` call passes `--subscription` explicitly AND we verify `az account show` is the prod SP before any mutation.
- **Whitelist OFF in `finally`**: the KV firewall rule is removed even on failure; residual verified 0.
- **Close on EFFECT (H-EFFECT-1)**: success = the AGW *serves* the new cert (TLS handshake shows notAfter Dec 30 2026), NOT `az` exit 0.
- **Regression → escalate (H-ROLLBACK-1)**: if a listener serves a broken/old cert after propagation, do the rollback (step 8), do not blindly retry.

## 2. Preconditions (verify; do not mutate)

```bash
# (a) prd SP creds cached
test -s /tmp/mc-production.env && echo "creds present" || echo "MISSING — re-run capture"
# (b) artifacts present
PFX="/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/log/employer/eneco/02_on_call_shift/2026_june/2026_06_24_renewal_vpp_tls_certificates/certificate_to_renovate/26061584690-_-vpp-eneco-com.pfx"
PW="/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/log/employer/eneco/02_on_call_shift/2026_june/2026_06_24_renewal_vpp_tls_certificates/certificate_to_renovate/certificate_password.txt"
test -s "$PFX" && test -s "$PW" && echo "artifacts present"
# (c) held cert identity (expect CN=*.vpp.eneco.com, SAN *.vpp.eneco.com+vpp.eneco.com, exp Dec 30 2026)
openssl pkcs12 -in "$PFX" -nokeys -clcerts -passin "file:$PW" -legacy 2>/dev/null | openssl x509 -noout -subject -enddate -fingerprint -sha1
```

### 2.1 Legacy-PFX pre-check + remediation (Open Risk OR-2)

The PFX is **legacy-encrypted** (openssl required `-legacy`). `az keyvault certificate import` (uses the `cryptography` lib) MAY reject it. Pre-validate, and if needed produce a modern AES PKCS12:

```bash
WORK="/tmp/vpp-rot"; mkdir -p "$WORK"; chmod 700 "$WORK"
# Re-encode to modern PKCS12 (AES-256) — keeps the SAME key+chain, only the bag encryption changes
openssl pkcs12 -in "$PFX" -legacy -nodes -passin "file:$PW" -out "$WORK/chain.pem" 2>/dev/null
NEWPW='<choose-a-throwaway-pw>'
openssl pkcs12 -export -in "$WORK/chain.pem" -keypbe AES-256-CBC -certpbe AES-256-CBC \
  -name wildcard-vpp-eneco-com -out "$WORK/modern.pfx" -passout "pass:$NEWPW"
# verify modern.pfx parses WITHOUT -legacy and has the same leaf
openssl pkcs12 -in "$WORK/modern.pfx" -nokeys -clcerts -passin "pass:$NEWPW" | openssl x509 -noout -subject -fingerprint -sha1
shred -u "$WORK/chain.pem" 2>/dev/null || rm -f "$WORK/chain.pem"
```

Decision: import the original PFX first; if it fails on format, import `$WORK/modern.pfx`. (Reviewers: is re-encode acceptable, or import via PEM?)

## 3. Establish prod SP session (isolated; no disturbance to user session)

```bash
export AZURE_CONFIG_DIR=/tmp/azsp-prd; mkdir -p "$AZURE_CONFIG_DIR"
source /tmp/mc-production.env
az login --service-principal -u "$ARM_CLIENT_ID" -p "$ARM_CLIENT_SECRET" --tenant "$ARM_TENANT_ID" -o none --only-show-errors
az account set -s "$ARM_SUBSCRIPTION_ID"
az account show --query "{sub:id, type:user.type}" -o json   # EXPECT f007df01… + servicePrincipal
```

## 4. Open KV firewall (surgical) + capture rollback baseline

```bash
SUB=f007df01-9295-491c-b0e9-e3981f2df0b0; RG=mcprd-rg-vpp-p-res; KV=vpp-appsec-p; OBJ=wildcard-vpp-eneco-com
MYIP=$(curl -4 -s ifconfig.me)
az keyvault network-rule add --name "$KV" -g "$RG" --subscription "$SUB" --ip-address "${MYIP}/32" -o none
sleep 25
# ROLLBACK BASELINE — record current (OLD) version id + thumbprint BEFORE import
az keyvault certificate show --vault-name "$KV" --name "$OBJ" \
  --query "{current_version:id, thumb:x509ThumbprintHex, expires:attributes.expires, enabled:attributes.enabled}" -o json | tee "$WORK/rollback-baseline.json"
az keyvault certificate list-versions --vault-name "$KV" --name "$OBJ" \
  --query "reverse(sort_by([].{ver:id, enabled:attributes.enabled, created:attributes.created}, &created))" -o table
```

## 5. Import the new version (THE state change)

```bash
az keyvault certificate import --vault-name "$KV" --name "$OBJ" \
  --file "$PFX" --password "$(cat "$PW")" -o json \
  --query "{new_version:id, thumb:x509ThumbprintHex, expires:attributes.expires, enabled:attributes.enabled}"
# If the above fails on format → retry with the modern PFX from step 2.1:
# az keyvault certificate import --vault-name "$KV" --name "$OBJ" --file "$WORK/modern.pfx" --password "$NEWPW" ...
```

## 6. Verify the KV holds the new cert (data-plane)

```bash
# new "latest enabled" version must match the held cert: SHA1 thumbprint + expiry Dec 30 2026
EXPECT_SHA1=$(openssl pkcs12 -in "$PFX" -nokeys -clcerts -passin "file:$PW" -legacy 2>/dev/null | openssl x509 -noout -fingerprint -sha1 | sed 's/.*=//; s/://g')
GOT=$(az keyvault certificate show --vault-name "$KV" --name "$OBJ" --query x509ThumbprintHex -o tsv)
echo "expect=$EXPECT_SHA1 got=$GOT"; [ "$EXPECT_SHA1" = "$GOT" ] && echo "KV MATCH ✅" || echo "KV MISMATCH ❌ — STOP"
```

## 7. Propagate to App Gateway + verify the EFFECT

```bash
# Force refresh (avoids ~8h auto-poll). AGW re-pulls the versionless KV secret. No config change.
az network application-gateway update --name vpp-ag-p -g "$RG" --subscription "$SUB" -o none
```

EFFECT verification (H-EFFECT-1) — listeners are PRIVATE, so this MUST run from **AVD / internal network** (cannot be done from this machine):

```bash
for h in agg.vpp.eneco.com gurobi.vpp.eneco.com apollo.vpp.eneco.com flex-trade-optimizer.vpp.eneco.com; do
  echo "== $h =="; echo | openssl s_client -connect "$h:443" -servername "$h" 2>/dev/null | openssl x509 -noout -enddate -fingerprint -sha1
done
# PASS = notAfter Dec 30 2026 + thumbprint == held cert on all four.
```

## 8. Rollback (if step 6 mismatch or step 7 serves broken/old cert)

```bash
# Disable the just-imported version → KV "latest enabled" reverts to the previous (old) version
NEWVER=<new_version_url_from_step5>
az keyvault certificate set-attributes --vault-name "$KV" --name "$OBJ" --version "${NEWVER##*/}" --enabled false -o none
az network application-gateway update --name vpp-ag-p -g "$RG" --subscription "$SUB" -o none   # force re-pull old
# re-verify from AVD as in step 7 (expect OLD expiry Jul 1 2026 restored)
```

## 9. Cleanup (MANDATORY `finally` — runs even on failure)

```bash
az keyvault network-rule remove --name "$KV" -g "$RG" --subscription "$SUB" --ip-address "${MYIP}/32" -o none
# verify residual 0
az keyvault show -n "$KV" -g "$RG" --subscription "$SUB" --query "length(networkAcls.ipRules[?contains(value,'$MYIP')])" -o tsv   # expect 0
# end session + scrub temp
az logout --only-show-errors 2>/dev/null; rm -rf /tmp/azsp-prd "$WORK"
```

## 10. Post-rotation

- Disable the now-superseded OLD cert version in KV (housekeeping; optional, after confirming new is healthy).
- If apex `p-vpp-eneco-com` (vpp.eneco.com, exp Jul 20 2026) is to be consolidated → separate decision/spec.

## Open Risks for adversarial review

- **OR-1 (terraform drift)**: is `wildcard-vpp-eneco-com` managed by terraform/terragrunt? If so, a manual import may be reverted by the next CI apply, OR cause plan drift. MUST check the MC-VPP IaC repo. [UNVERIFIED]
- **OR-2 (legacy PFX import)**: will `az keyvault certificate import` accept the legacy-encrypted PFX? Mitigation = re-encode (step 2.1). [UNVERIFIED — needs a real import test, e.g. throwaway object on dev]
- **OR-3 (AGW force-update blast)**: does `az network application-gateway update` (no-op PUT) cause any listener flap/downtime? [UNVERIFIED]
- **OR-4 (rollback semantics)**: does AGW, on versionless secret, truly re-pull the latest *enabled* version after disabling the new one + force-update? Confirm. [INFER]
- **OR-5 (verification reach)**: EFFECT check needs AVD/internal — confirm the operator has a path to run step 7's openssl, else success is unverifiable. [constraint]
- **OR-6 (password in process args)**: `--password "$(cat …)"` exposes the PFX password in `ps`. Acceptable? Alternative? 
