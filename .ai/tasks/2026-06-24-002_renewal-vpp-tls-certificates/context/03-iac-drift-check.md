---
title: OR-1 terraform-drift check — RESOLVED (import-new-version is drift-safe)
task_id: 2026-06-24-002
agent: claude-opus-4-8
status: complete
summary: IaC grep proves the cert object is NOT terraform-managed and the AGW references it via a versionless KV secret URI, so importing a new cert version causes no terraform drift / no CI revert.
timestamp: 2026-06-24T00:00:00Z
---

# OR-1 — Terraform drift check (RESOLVED safe)

## Evidence (A1 — grep over `/Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src`)

1. **No `azurerm_key_vault_certificate` resource** found anywhere in the tree → KV certificate *objects* are NOT created/managed by terraform. The `wildcard-vpp-eneco-com` object is managed out-of-band (manual import — matches the colleague's portal method). There is no terraform resource whose apply would overwrite/revert a manually-imported version.

2. **AGW references the cert via a VERSIONLESS secret URI** (authoritative working copy `MC-VPP-Infrastructure/main/configuration/prd.tfvars:1518`):
   ```
   key_vault_secret_id = "https://vpp-appsec-p.vault.azure.net/secrets/wildcard-vpp-eneco-com"
   ```
   No version GUID → the configured value does not change when a new version is imported. AGW (CCoE module `ccoe/terraform-azure-app-gateway`, `main.tf:129` passes `key_vault_secret_id` through) auto-resolves to the latest enabled version.

## Implications for the spec

- Importing a new **version** of `wildcard-vpp-eneco-com`:
  - changes no terraform-managed object (the cert object isn't one) → **CI will not revert it**;
  - leaves the AGW's configured `key_vault_secret_id` byte-identical → **`terraform plan` shows no diff** → no drift.
- `az network application-gateway update` (force-refresh) is **config-neutral** (no property change) → also no drift.
- Net: the import-new-version model is drift-safe. OR-1 downgraded from risk to confirmed-safe.

## Residual

- Confirm the acc/dev tfvars likewise use versionless URIs (they do, same grep) — not in scope (prod only) but consistent.
- The AGW resource itself is terraform-managed; we must NOT change its config (only refresh) — the spec already only force-refreshes.
