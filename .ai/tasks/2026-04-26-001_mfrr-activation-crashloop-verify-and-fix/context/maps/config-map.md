---
task_id: 2026-04-26-001
agent: coordinator
status: complete
summary: Config-surface map — where strings like "activation-mfrr" can live across the four repos
---

# Config-surface map

| Surface | Path | Purpose | Holds CG/container name? |
|---|---|---|---|
| Sandbox env tfvars | `VPP-Infrastructure/configuration/terraform/sandbox/sandbox.tfvars` | Inputs to `terraform/sandbox/*` | YES — `eventhub_premium_attributes."<eh>".consumerGroups."<cg>" = {…}` (per Phase-1 diagnosis review) |
| Shared FBE tfvars | `VPP-Infrastructure/terraform/fbe/terraform.tfvars` | Defaults / FBE common | TBD Phase-4 read |
| FBE module body | `VPP-Infrastructure/terraform/fbe/event-hub.premium.tf` | Defines two paired Terraform modules: CG + storage-container | NO — pattern only; container name = `"${eh}-${cg}"` (per diagnosis line 88 claim) |
| FBE locals | `VPP-Infrastructure/terraform/fbe/locals.tf` | `local.eventhub_premium_attributes` flattening of tfvars input | NO — flattening only |
| Sandbox premium wiring | `VPP-Infrastructure/terraform/sandbox/event-hub.premium.tf` | Sandbox-side instantiation of FBE EH premium module | NO — wires var → module |
| Azure App Config | runtime resource `vpp-appconfig-d`, label `Activation-mFRR` | Consumed by C# service at startup | YES — has explicit `ConsumerGroup`, `ContainerName`, `EventHubName` per consumer (per diagnosis evidence row App-Config) |
| Helm values | `VPP-Configuration/Helm/activationmfrr/…/values.vppcore.sandbox.yaml` | Helm overrides at deploy time | TBD Phase-4 read; likely env vars only, not CG strings |
| Helm chart source | `Eneco.Vpp.Core.Dispatching/helm/activationmfrr/` | Chart templates | TBD Phase-4 read; CG strings expected to be read from App Config, not hardcoded |

## Cross-surface consistency rule (claimed by diagnosis, must reconcile)

Three places must agree on the string `activation-mfrr` and the implicit container name `dispatcher-output-1-activation-mfrr`:

1. **App Config** (`vpp-appconfig-d` label `Activation-mFRR` → `EventHubOptions:ConsumerOptions:DispatcherOutput`) — *claimed* to already declare CG=`activation-mfrr`, Container=`dispatcher-output-1-activation-mfrr`.
2. **Azure runtime** (Event Hub CG list + storage container list on `vpp-evh-premium-sbx` / `vppevhpremiumsb`) — *claimed* to be MISSING both.
3. **Terraform tfvars** — *claimed* to be missing the entry that would create both via the FBE module pair.

Phase 4 verifies (3) by file read; (1) and (2) are runtime assertions in the diagnosis under live-probe FACT — they remain INFER for me until I either probe directly (would require Azure CLI auth) or accept them on the diagnosis author's chain-of-custody.

## What is NOT a config surface for this fix

- ArgoCD configs in `VPP.GitOps/` — orchestrate which Helm chart deploys; do not hold CG strings.
- VPP-Configuration `vpp-core-app-of-apps-migration` — pins image tags / chart versions; not consumer-group ownership.
