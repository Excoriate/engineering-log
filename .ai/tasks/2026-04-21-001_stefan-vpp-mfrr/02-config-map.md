---
task_id: 2026-04-21-001
agent: claude-code
status: complete
summary: Expected configuration surfaces touching mFRR consumer groups
---

# Config Map (hypothesized — verify in Phase 4)

| Surface | Location (expected) | Role |
|---|---|---|
| Terraform Event Hubs module | `MC-VPP-Infrastructure/.../terraform/eventhubs-*.tf` | Declares namespaces, event hubs, consumer groups |
| Sandbox tfvars | `configuration/sandbox-*.tfvars` | Env-specific values (consumer group names, throughput units) |
| Env alerts tfvars (ref) | `configuration/dev-alerts.tfvars`, `acc-*`, `prd-*` | Known pattern: per-env tfvars (per MEMORY.md) |
| mFRR service config | app repo — `helm/` values, appsettings, or ConfigMap | Consumer group name consumed by service |
| ADO pipeline | `Myriad - VPP / buildId=1616964` | Stefan's triggered VPP-Infrastructure run |
| ArgoCD Sandbox app | gitops repo (TBD) | Deploys mFRR-Activation workload |

**UNVERIFIED[unknown]**: exact file paths — delegated to `/eneco-context-repos` + `/eneco-platform-mc-vpp-infra`.
