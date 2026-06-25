---
title: VPP TLS wildcard rotation — scope CONFIRMED (production only)
task_id: 2026-06-24-002
agent: claude-opus-4-8
status: complete
summary: 100%-confident scope for the *.vpp.eneco.com wildcard renewal — PRODUCTION only, KV vpp-appsec-p, cert object wildcard-vpp-eneco-com. dev/acc excluded by live cert content. SP import + firewall-write capability confirmed. All whitelists reverted (residual 0).
timestamp: 2026-06-24T00:00:00Z
---

# Scope CONFIRMED (100%) — Production `*.vpp.eneco.com` wildcard rotation

## 1. Decisive match (A1 — live KV data-plane reads via prd SP, 2026-06-24)

| Attribute | Held PFX (NEW) | prd `vpp-appsec-p` / `wildcard-vpp-eneco-com` (CURRENT) |
|---|---|---|
| Subject | `CN=*.vpp.eneco.com` | `CN=*.vpp.eneco.com` |
| SAN | `*.vpp.eneco.com, vpp.eneco.com` | `*.vpp.eneco.com, vpp.eneco.com` |
| Issuer | Trust Provider B.V. TLS RSA CA G1 | Trust Provider B.V. TLS RSA CA G1 |
| Validity | Jun 15 2026 → Dec 30 2026 | expires **Jul 1 2026** |
| SHA-256 | F4:F2:47:8B:35:7F:B9:8D… (NEW) | 87:97:34:18:C5:8E:A0:5A… (OLD) |

Same CN+SAN+CA, old expiring imminently (Jul 1 2026), new runs to Dec 30 → **like-for-like renewal**. **TARGET = prd KV `vpp-appsec-p`, object `wildcard-vpp-eneco-com`.**

## 2. Negative confirmations (A1)

- dev `vpp-appsec-d`: `d-vpp-eneco-com` = `CN=dev-mc.vpp.eneco.com` (single host, exp Dec 26 2026); `wildcard-dev-mc-vpp-eneco-com` = `*.dev-mc.vpp.eneco.com` (exp Nov 23 2026). Neither is `*.vpp.eneco.com`. NOT a target.
- acc `vpp-appsec-a`: `vpp-eneco-com` = `CN=acc.vpp.eneco.com` (single host, exp Oct 4 2026); `wildcard-acc-vpp-eneco-com` = `*.acc.vpp.eneco.com` (exp Nov 23 2026). Neither is `*.vpp.eneco.com`. NOT a target.
- Conclusion: the `*.vpp.eneco.com` wildcard is used **only in production**.

## 3. Production scope nuance — apex is SEPARATE

- `wildcard-vpp-eneco-com` (TARGET): serves `*.vpp.eneco.com` subdomain listeners → `agg.`, `gurobi.`, `apollo.`, `flex-trade-optimizer.vpp.eneco.com`.
- `p-vpp-eneco-com` (NOT in scope unless user consolidates): `CN=vpp.eneco.com` single-host, serves apex `vpp.eneco.com`, expires Jul 20 2026 — its own separate renewal.

## 4. Resources to touch (A1)

| Item | Value |
|---|---|
| Subscription | `f007df01-9295-491c-b0e9-e3981f2df0b0` |
| Key Vault | `vpp-appsec-p` (RG `mcprd-rg-vpp-p-res`) |
| Cert object | `wildcard-vpp-eneco-com` (import NEW VERSION) |
| App Gateway | `vpp-ag-p` (RG `mcprd-rg-vpp-p-res`) |
| Identity | prd MC SP (cache `/tmp/mc-production.env`) |

## 5. Capability confirmed (A1)

- prd SP (objectId `686d817d-86b9-4d8f-9aa4-8212cf12931a`) KV cert permissions include: `Get, List, Create, Import, Update, Delete, Recover, Backup, Restore` → **import is permitted**.
- prd SP can write KV firewall (`network-rule add` returned OK).
- acc SP equivalently capable (objectId `4d0692eb-…`) — informational; acc not a target.

## 6. Whitelist hygiene (A1)

- Only surgical `az keyvault network-rule add/remove` used (KV-only); the broad `enecoazwhitelist*` alias (storage+SQL+PNA) was NEVER run.
- Every add was reverted; `residual_for_my_ip = 0` verified on dev, acc, prd. No storage/SQL touched.

## 7. Open scope decision for user

1. Confirm: rotate `wildcard-vpp-eneco-com` only (recommended, like-for-like)? OR also consolidate apex `p-vpp-eneco-com`?
2. Timing: prd `*.vpp.eneco.com` expires **Jul 1 2026** — rotation should happen well before.
