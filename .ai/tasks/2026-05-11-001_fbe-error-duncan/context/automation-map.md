---
task_id: 2026-05-11-001
agent: claude-opus-4-7
status: complete
summary: Automation/CI map — pipelines, templates, runners
classification: newly-mapped
---

# Automation map — FBE delivery topology

## Pipelines in scope

| Pipeline definition | File | Purpose | Trigger |
|---|---|---|---|
| `Myriad - VPP / VPP - Infrastructure / fbe` (definition ID inferred from build 1638601 link) | `azurepipelines-fbe.yaml` | Manual FBE create for env=kidu et al | Manual (`trigger: none`) |
| `Myriad - VPP / VPP - Infrastructure / sandbox` | `azurepipelines.yaml` | Sandbox baseline plane | `main` push |

## Template references (Eneco.Pipelines repo)

| Caller | Callee | Repo |
|---|---|---|
| azurepipelines-fbe.yaml Plan stage | `terraform/pipelines/tasks/terraform-plan.yml` | `@Eneco.Pipelines` |
| azurepipelines-fbe.yaml Apply stage | `terraform/pipelines/tasks/terraform-apply.yml` | `@Eneco.Pipelines` |
| Both stages | `terraform/pipelines/tasks/terraform-sp-credentials.yml` | `@Eneco.Pipelines` |

## terraform-apply.yml mechanics (line 68-75)

```bash
terraform init \
  -backend-config='resource_group_name=${{ parameters.backendResourceGroup }}' \
  -backend-config='storage_account_name=${{ parameters.backendStorageAccount }}' \
  -backend-config='container_name=${{ parameters.backendContainerName }}' \
  -backend-config='key=${{ parameters.backendKey }}' \
  -force-copy

terraform ${{ parameters.overrideAction }} ${{ parameters.arguments }}
```

`-force-copy` is set: terraform init will silently migrate state from old backend to new without prompting. This is significant — when the buggy state key is used, terraform init creates a NEW blob silently and force-copies whatever local state it has (typically empty if no prior init existed in this job).

## Cross-checkout dependencies (the Plan stage)

The Plan stage checks out THREE repos:
1. `self` → `VPP - Infrastructure` (the IaC)
2. `Eneco.Infrastructure` (the modules referenced via SSH git in main.tf)
3. `Eneco.Vpp.Adx.Management` (KQL scripts for Kusto)

The Apply stage only checks out `Eneco.Infrastructure` (for module credentials during apply).

## Build agent IP whitelisting

Both Plan and Apply add the build agent's public IP to whitelists during their runs (key vault network rule). Apply stage in FBE pipeline does NOT remove the IP afterwards (no cleanup step visible in azurepipelines-fbe.yaml). This is a separate hygiene concern; not the failure cause.
