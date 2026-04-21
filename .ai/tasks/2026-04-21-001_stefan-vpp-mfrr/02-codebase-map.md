---
task_id: 2026-04-21-001
agent: claude-code
status: complete
summary: Codebase scope map — target repos for mFRR investigation
---

# Codebase Map

## Primary scope (not in this repo — external)

From memory (`MEMORY.md`):

- **MC-VPP-Infrastructure (IaC)**: `/Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src/enecomanagedcloud/myriad-vpp/MC-VPP-Infrastructure/main`
  - 16 infrastructure domains per `eneco-platform-mc-vpp-infra` skill: SQL, CosmosDB, Key Vault, Service Bus, Event Hubs, AGW, Redis, Storage, App Config, monitoring, etc.
  - Env tfvars pattern: `configuration/dev-alerts.tfvars`, `sandbox-*.tfvars`, `prd-*.tfvars`, `acc-*.tfvars`.
- **mFRR-Activation service repo**: unknown location — delegate discovery to `eneco-context-repos` skill. Candidate: separate application repo under Myriad VPP project on ADO.

## This repo (engineering-log)

- `log/employer/eneco/02_on_call_shift/2026_04_21_stefan_vpp_infrastructure_mfrr/slack-antecedents.txt` — source ticket (read)
- Adjacent ticket patterns for reference structure only (not inputs):
  - `2026_04_13_argocd_dev_endpoint_unreachable/root-cause-analysis.md`
  - `2026_03_e2e_test_failing_nitin/` (mature $T_DIR-style per-ticket workspace)

## Non-scope

- Stefan's ticket ≠ `2026_04_21_erik_lumbela_argocd_sandbox_access/` ticket opened in IDE. Do not conflate. The Erik ticket is ArgoCD sandbox access; Stefan's is mFRR consumer group.
