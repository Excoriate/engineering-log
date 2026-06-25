---
title: VPP TLS wildcard rotation — determination and resource map
task_id: 2026-06-24-002
agent: claude-opus-4-8
status: partial
summary: Live control-plane determination of MC VPP App Gateway / Key Vault resources for rotating the *.vpp.eneco.com wildcard TLS cert. Real AGW names resolved (vpp-ag-{d,a,p}); cert-object-to-listener map captured; content match pending data-plane read.
timestamp: 2026-06-24T00:00:00Z
---

# VPP TLS Wildcard Rotation — Determination & Resource Map

## 1. Held certificate identity (A1 — openssl on the PFX)

- File: `certificate_to_renovate/26061584690-_-vpp-eneco-com.pfx` (password in sibling `certificate_password.txt`)
- Subject: `CN=*.vpp.eneco.com`
- SAN: `*.vpp.eneco.com`, `vpp.eneco.com`
- Issuer: `Trust Provider B.V. TLS RSA CA G1` (Networking4All)
- Validity: `Jun 15 2026 → Dec 30 2026`
- Serial: `0BBADA7F3539D8F0A6F1E52D7D412C8C`
- SHA-256 FP: `F4:F2:47:8B:35:7F:B9:8D:71:C1:69:3A:57:46:82:67:87:2F:F0:10:89:AE:13:AB:B0:DA:A4:6D:D0:C6:82:1E`
- PFX contains leaf + 2 chain certs; private key present; keypair verified (pubkey md5 of key == cert).
- Wildcard semantics: `*.vpp.eneco.com` matches exactly one label (`X.vpp.eneco.com`). It does **not** match `*.dev-mc.vpp.eneco.com` or `*.acc.vpp.eneco.com` (two labels).

## 2. Resource map (A1 — live `az` control-plane, 2026-06-24)

| Env | Subscription | RG (KV+AGW) | Key Vault | KV firewall | App Gateway (real) |
|-----|--------------|-------------|-----------|-------------|--------------------|
| dev | 839af51e-c8dd-4bd2-944b-a7799eb2e1e4 | mcdta-rg-vpp-d-res | vpp-appsec-d | PNA=Enabled, default=Deny, accessPolicy mode | **vpp-ag-d** |
| acc | b524d084-edf5-449d-8e92-999ebbaf485e | mcdta-rg-vpp-a-res | vpp-appsec-a | same | **vpp-ag-a** |
| prd | f007df01-9295-491c-b0e9-e3981f2df0b0 | mcprd-rg-vpp-p-res | vpp-appsec-p | same | **vpp-ag-p** |

> Runbook said `vpp-agw-*` / `vpp-appgw-*`; both WRONG. Colleague's `vpp-ag-d` was right. Pattern: `vpp-ag-{d,a,p}`.

## 3. Cert-object → listener map (A1 — `az network application-gateway ssl-cert/http-listener list`)

### prd (vpp-ag-p)
| KV cert object | KV secret name | Hosts served |
|---|---|---|
| `wildcard-vpp-frontend-https` | `wildcard-vpp-eneco-com` | agg / gurobi / apollo / flex-trade-optimizer **.vpp.eneco.com** (the `*.vpp.eneco.com` set) |
| `vpp-frontend-https` | `p-vpp-eneco-com` | `vpp.eneco.com` (apex) |
| `vpp-prd-eetpv-com` | `vpp-eetpv-com` | `vpp.prd.eetpv.com` (different domain — NOT ours) |

### dev (vpp-ag-d)
| KV cert object | KV secret name | Hosts served |
|---|---|---|
| `wildcard-dev-mc-vpp-eneco-com` | `wildcard-dev-mc-vpp-eneco-com` | `*.dev-mc.vpp.eneco.com` (apollo/agg/flex-trade-optimizer) — NOT ours (2-label) |
| `vpp-frontend-https` | `d-vpp-eneco-com` | `dev-mc.vpp.eneco.com` (apex — covered by our SAN's `*.vpp.eneco.com`) |

### acc (vpp-ag-a)
| KV cert object | KV secret name | Hosts served |
|---|---|---|
| `wildcard-vpp-frontend-https` | `wildcard-acc-vpp-eneco-com` | `*.acc.vpp.eneco.com` (gurobi/apollo/agg/flex-trade-optimizer) — NOT ours (2-label) |
| `vpp-frontend-https` | `vpp-eneco-com` | `acc.vpp.eneco.com` (apex — covered by our SAN's `*.vpp.eneco.com`) |
| `vpp-acc-eetpv-com` | `vpp-acc-eetpv-com` | `vpp.acc.eetpv.com` (different domain — NOT ours) |

## 4. Determination analysis (A2)

- The held cert (`*.vpp.eneco.com` + `vpp.eneco.com`) natively fits the **production** `*.vpp.eneco.com` subdomain set → prd object **`wildcard-vpp-frontend-https`** (secret `wildcard-vpp-eneco-com`) is the **strongest match** by both name and host coverage.
- The prd apex (`vpp.eneco.com`) object `vpp-frontend-https` (secret `p-vpp-eneco-com`) is **also covered** by our SAN — candidate, pending content check (may be a separate apex-only cert).
- dev/acc apex objects (`dev-mc.vpp.eneco.com`, `acc.vpp.eneco.com`) are *coverable* by `*.vpp.eneco.com` but are named env-specifically; whether they currently hold a `*.vpp.eneco.com` cert is **unknown until data-plane read**.
- dev/acc subdomain wildcards (`*.dev-mc.*`, `*.acc.*`) are different certs → **out of scope** for this PFX.

## 5. Identity / access (A1 + A2)

- Signed-in: `Alex.Torres@eneco.com` (objectId `e476e499-b53f-4ce4-b1bf-769ff853f62b`); all 3 subs cached and control-plane readable.
- No **direct** access-policy entry for this objectId in any KV → access is via AAD group (to be confirmed empirically). Import/create lookup returned empty (likely permission-string casing in legacy policies) — **verify by reading actual policy perms + an empirical cert list after whitelist**.
- Colleague performed import via **portal as a human** → human identity is the correct actor; terraform SP (enecotfvppmclogin*) likely lacks cert data-plane rights. The existing `az` user session is sufficient and avoids 1Password/SP entirely.

## 6. Whitelist mechanics (A1 — aliases-work-eneco-azure.sh)

- `enecoazwhitelist{dev,acc,prd}on/off` runs as the ambient `az` identity, passes `--subscription` explicitly, and whitelists **7–8 storage accounts + the KV (`/32`) + the SQL server** (+ PNA toggles). Broad.
- For cert read/import only the **KV** is needed → prefer surgical `az keyvault network-rule add/remove --name <kv> -g <rg> --subscription <sub> --ip-address <ip>/32` to minimise blast radius.

## 7. Rotation mechanism (A2 — colleague guide + AGW model)

- AGW listeners reference the KV cert by **versionless** secret URI → rotation = **import a NEW VERSION under the existing cert object name** in the KV; AGW auto-pulls latest (propagation up to ~8h, old version stays live until then).
- Force propagation: `az network application-gateway update --name vpp-ag-{x} --resource-group <rg>`.
- Rollback: re-enable previous KV cert version / disable the new one.

## 8. Open items (pre-spec)

1. Data-plane content match: read subject/issuer/expiry of candidate KV objects to confirm the exact object set (needs KV whitelist). **[blocked: firewall]**
2. Confirm import permission for the acting identity (casing-correct policy read + empirical). **[blocked: firewall]**
3. Confirm whether `az keyvault network-rule add` (firewall write) succeeds as the user identity, or needs Contributor. **[blocked: empirical]**
4. Scope decision: prd-only vs prd+dev/acc apex — pending content match + user intent.
