---
task_id: 2026-05-11-001
agent: claude-opus-4-7
status: complete
summary: Codebase map of VPP-Infrastructure repo (FBE + Sandbox planes) + Eneco.Pipelines templates relevant to Duncan's failure
classification: changed (prior 2026-04-26 map had path drift; codebase tree refactored from terraform/fbe → codebase/fbe)
---

# Codebase map — VPP-Infrastructure (FBE plane)

## Top-level layout

The ADO repo `VPP - Infrastructure` (org `enecomanagedcloud`, project `Myriad - VPP`) is at:

```
/Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src/enecomanagedcloud/VPP%20-%20Infrastructure/
├── azurepipelines-fbe.yaml      (208 lines) FBE pipeline definition (manual trigger, 10-env dropdown)
├── azurepipelines.yaml          (247 lines) Sandbox pipeline definition (main trigger)
├── pull-request-validation.yaml (PR validation)
├── aks-log-analytics/           Helm chart for log analytics
├── codebase/
│   ├── fbe/                     FBE Terraform module instance (THIS is the failing surface)
│   └── sandbox/                 Sandbox Terraform module instance
└── README.md
```

## FBE Terraform tree (codebase/fbe/)

```
codebase/fbe/
├── aks.tf
├── app-config.tf
├── app-insights.tf
├── app-users.tf
├── common.tf
├── cosmos-db.tf
├── data.tf
├── event-hub.premium.tf          ← the failing module instantiation (line 1-19 declares vpp-evh-premium-{env})
├── event-hub.tf                  Standard SKU event hub
├── key-vault.tf
├── kusto-cluster.tf
├── locals.tf                     consumer-group flattening (eventhub_premium_attributes:31-43)
├── modules/                      vendored sub-modules
├── provider.tf
├── redis.tf
├── service-bus.tf
├── signalr.tf
├── sql-database.tf
├── storage-account.tf
├── terraform.tfvars              FBE shared tfvars (not env-specific; env is supplied via -var)
└── variables.tf                  declares var.environment (free-form string, no validation)
```

## Sandbox Terraform tree (codebase/sandbox/)

```
codebase/sandbox/
├── action-group.tf
├── app-config.tf  app-insights.tf
├── cosmos-db.tf  cosmosdbmongo.tf
├── event-hub.premium.tf          Sandbox-specific premium evh (namespace name: vpp-evh-premium-sbx)
├── event.hub.tf
├── function-apps.tf
├── key-vault.tf  kusto-cluster.tf
├── locals.tf  provider.tf
├── logic-app-*.{tf,json}         autodelete/delete/slack-alerting logic apps
├── logicapp_sandbox.tf
├── redis.tf  service-bus.tf  signalr.tf
├── sql-database.tf  storage-account.tf
├── terraform.tfvars
└── variables.tf
```

## Eneco.Pipelines templates (referenced via @Eneco.Pipelines)

```
/Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src/enecomanagedcloud/myriad-vpp/Eneco.Pipelines/terraform/pipelines/tasks/
├── terraform-plan.yml             template invoked by Plan stage
├── terraform-apply.yml            template invoked by Apply stage
└── terraform-sp-credentials.yml   Service Principal credential injection
```

## Backend (state) layout

Both Sandbox and FBE share ONE backend storage:

| Field | Value | Source |
|---|---|---|
| Resource group | `rg-vpp-app-sb-401` | azurepipelines-fbe.yaml:137, azurepipelines.yaml:17 |
| Storage account | `tfstatevpp` | azurepipelines-fbe.yaml:138, azurepipelines.yaml:101 |
| Container | `tfstate` | azurepipelines-fbe.yaml:139, azurepipelines.yaml:102 |
| Key — Sandbox plane | `terraform.tfstate` (single blob) | azurepipelines.yaml:103,160 |
| Key — FBE plane (Plan stage) | `terraform.${{ parameters.environment }}` → e.g. `terraform.kidu` | azurepipelines-fbe.yaml:140 |
| Key — FBE plane (Apply stage) | `terraform.{{ parameters.environment }}` ← **TYPO: missing `$`** | azurepipelines-fbe.yaml:207 |

## Failing module sources (referenced via SSH git)

| Module | Source | Ref |
|---|---|---|
| `eventhub_namespace_premium` | `git::ssh://...Eneco.Infrastructure//terraform/modules/event_hub_namespace` | `?ref=v1.0.0` |
| `eventhub_namespace_premium_storageaccount` | `terraform/modules/storageaccount` | `?ref=v1.0.0` |
| `eventhub_namespace_premium_eventhubs` | `terraform/modules/event_hub` | `?ref=v1.0.0` |
| `eventhub_namespace_premium_eventhubs_consumer_groups` | `terraform/modules/event_hub_consumer_group` | `?ref=v1.0.0` |
| `kusto_eventhub_premium_data_connection` | `terraform/modules/kusto_eventhub_data_connection` | `?ref=v0.1.9` |
| `keyvault_secret_*` | `terraform/modules/keyvaultsecret` | `?ref=v0.1.0` |

## Naming formula for the failing resource

```hcl
# event-hub.premium.tf:6
eventhub_namespace_name = format("%s-evh-premium-%s", var.project-prefix, var.environment)
```

So for `var.environment="kidu"` and `var.project-prefix="vpp"` → namespace name `vpp-evh-premium-kidu` (matches Duncan's error verbatim).

## FBE pipeline parameter — fixed env allowlist

`azurepipelines-fbe.yaml:11-21`:
```
afi, boltz, enel, ionix, ishtar, jupiter, kidu, operations, veku, voltex
```

`kidu` is one of 10 fixed FBE slots. Trigger is `trigger: none` — pipeline is manually started, env picked from dropdown. Multiple users can target the same env across time.

## Worktree note

Repo lives on the filesystem with **literal `%20`** in the directory name (`VPP%20-%20Infrastructure` — URL-encoded space encoded as literal characters). All shell `cd`/path operations must keep those `%`s verbatim.
