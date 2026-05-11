---
task_id: 2026-05-11-001
agent: claude-opus-4-7
status: complete
summary: Config map — env, tfvars, pipeline parameters relevant to FBE deploy
classification: newly-mapped (no prior FBE-specific config map)
---

# Config map — FBE deployment knobs

## Pipeline parameters (manual trigger)

- `environment` (string): one of `afi, boltz, enel, ionix, ishtar, jupiter, kidu, operations, veku, voltex` (azurepipelines-fbe.yaml:11-21)

## Pipeline variables

- Variable group `eneco-vpp-sandbox` (ADO library)
- `terraformVersion`: 1.13.1 (azurepipelines-fbe.yaml:26 — **note pipeline declares 1.13.1, but the failing build shows installed Terraform v1.14.3, indicating the runtime installer step used 1.14.3; this is a separate diagnostic question**)
- `serviceConnectionName`: `rg-vpp-app-sb-401` — ADO service connection (uses Sandbox subscription `7b1ba02e-bac6-4c45-83a0-7f0d3104922e`)

## Apply-stage arguments injected by pipeline

`-var environment=${{ parameters.environment }} -var agent-ip=$(build_agent_public_ip) -var sqlserver_azurelogin_client_id=$(AZURE_CLIENT_ID) -var sqlserver_azurelogin_client_secret=$(AZURE_CLIENT_SECRET)` (azurepipelines-fbe.yaml:141-145, only in Plan; Apply uses `terraform.tfplan` artifact)

## Duncan's run-time inputs (from build 1638601 log)

- `-var environment=kidu`
- `-var kusto_cluster_name=vppkustocluster01sb`
- `-var kafka_queue_name=com-eneco-eet-vpp-streamcopy-dev10`

These three are inferred from the apply command line shown in the build log. The `kusto_cluster_name` and `kafka_queue_name` reference SANDBOX-shared resources (cluster `vppkustocluster01sb`), indicating the FBE binds to shared Sandbox infra for some externals while owning per-env resources for the rest.

## FBE state-key formula (with the bug)

| Stage | Key parameter value | After ADO template compile | Effective state blob |
|---|---|---|---|
| Plan | `terraform.${{ parameters.environment }}` | `terraform.kidu` | `tfstate/terraform.kidu` |
| Apply | `terraform.{{ parameters.environment }}` | `terraform.{{ parameters.environment }}` (LITERAL — `$` missing) | `tfstate/terraform.{{ parameters.environment }}` |

This typo on `azurepipelines-fbe.yaml:207` is **the load-bearing hypothesis** for state divergence — to be confirmed via live storage probe in Phase 2 freshness audit.
