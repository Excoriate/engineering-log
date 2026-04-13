---
task_id: 2026-04-13-001
agent: coordinator
status: draft
summary: Configuration map for ACC ClientGateway investigation
---

# Config Map
- Azure environments accessible via eneco-tool-tradeit-mc-environments skill
- ACC environment: MC acceptance (mc_acc)
- Alert configs: `configuration/acc-alerts.tfvars` in MC-VPP-Infrastructure
- Service Bus IaC: `terraform/servicebus-mc-lz.tf`
- Action groups: `terraform/actiongroup.tf`
