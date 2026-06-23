---
title: FBE thor failed-deletion — evidence ledger
task_id: 2026-06-22-008
agent: claude-opus-4-8
status: complete
summary: Probe-backed evidence for the FBE thor delete failures (cert-captured secret + non-idempotent AppConfig stage). Original blocker verified cleared live; remaining blocker is pipeline non-idempotency.
timestamp: 2026-06-22T00:00:00Z
---

# Evidence Ledger — FBE `thor` failed deletion

Slot `thor` · owner Tiago (Santos Rios, TJ, `Alex`-adjacent requester email) · KV `vpp-fbe-thor-vuo` · RG `rg-vpp-app-sb-401` · Sandbox sub `7b1ba02e-bac6-4c45-83a0-7f0d3104922e`.

## Builds (az pipelines build show / timeline / logs)

| Build | Pipeline | Branch | Duration | Failed at | Error |
|-------|----------|--------|----------|-----------|-------|
| 1683298 (run 1) | Feature Branch Environment - Delete | development | 07:05–07:36 UTC (31m) | `DestroyInfra` → Terraform Destroy | `deleting Secret "activationmfrr-eneco-signing-certificate" … 403 … SecretManagedByKeyVault` (A1, raw-requirements.md:21 + screenshots) |
| 1683370 (run 2) | Feature Branch Environment - Delete | development | 07:39–07:43 UTC (3m42s) | `DestroyAppConfiguration` → "Get Feature Flags from Azure AppConfig" | `ERROR: argument --name/-n: expected one argument` → `az appconfig feature list -n <empty>` → exit 1 (A1, build 1683370 log 29) |

## Mechanism

- **F1 (run 1):** A certificate named `activationmfrr-eneco-signing-certificate` was **added manually** to `vpp-fbe-thor-vuo`. In Azure KV a certificate auto-creates a backing **secret** of the same name. That backing secret "captured" the Terraform-managed secret `azurerm_key_vault_secret.copied_secrets["activationmfrr-eneco-signing-certificate"]` (IaC: `key-vault.tf:26-32` for_each over `local.secrets_to_copy` incl. `locals.tf:110`, sourced from shared KV `vpp-aks-d` per `data.tf:42-51`). `terraform destroy` → `DeleteSecret` → Azure 403 `SecretManagedByKeyVault` ("delete the corresponding certificate instead"). A1.
- **F2 (run 2):** User deleted the certificate manually (resolving F1). Re-running the **whole** delete pipeline fails earlier: Preparation (`azure-pipeline-fbe-del.yml:99`) resolves the AppConfig name via `az appconfig list -g rg-vpp-app-sb-401 --query "[?contains(name,'thor')].name"`. Run 1's `DestroyAppConfiguration` stage already destroyed that store, so the lookup returns **empty** → `DestroyAppConfiguration` (`:163-185`) calls template `sandbox.template.yml@pipelines` with `appConfigurationName: ""` → its "Get Feature Flags" task runs `az appconfig feature list -n` with no value → exit 1. The delete pipeline is **non-idempotent** once AppConfig is gone. A1.

## Live state (az, Sandbox sub, read-only — 2026-06-22)

- `az keyvault show --name vpp-fbe-thor-vuo` → exists, RG `rg-vpp-app-sb-401`, softDelete=true, retention 7d, purgeProtection=off. A1.
- `az keyvault certificate show/list/list-deleted` (name `activationmfrr-eneco-signing-certificate`) → `CertificateNotFound` / `[]` / `[]`. **Certificate is gone, not even soft-deleted.** A1.
- `az keyvault secret show` (same name) → `SecretNotFound`. **Backing secret gone → F1 blocker cleared; the 403 cannot recur.** A1.
- `az resource list -g rg-vpp-app-sb-401 --query "[?contains(name,'thor')]"` → only `vpp-fbe-thor-vuo` (KV) + `Failure Anomalies - vpp-insights-fbe-thor` (App Insights smart-detector; explicitly excluded from pipeline cleanup at `azure-pipeline-fbe-del.yml:301` `grep -v smartDetectorAlertRules`). A1.
- `az appconfig list` (thor) → none. **AppConfig store already destroyed** (confirms F2). A1.

## Why "still assigned to me"

Run 1 failed at DestroyInfra and never reached the **"Release environment in the Storage table"** step (`:319-358`), which sets the `featurebranchenvdetails` row `active='unused'` + clears `createdby`. So the env row is still `used` / owned by the requester. A1.
