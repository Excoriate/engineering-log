---
task_id: 2026-05-11-001
agent: claude-opus-4-7
status: complete
summary: AI scaffolding map — skills, prior tasks, agent topology relevant to this RCA
classification: reused (engineering-log .ai/harness unchanged between Apr 26 and May 11)
---

# AI map — engineering-log harness and prior task context

## Skills invoked / relevant

| Skill | Purpose this task |
|---|---|
| `rca-holistic` | Primary skill — produces the RCA output package |
| `eneco-context-repos` | Locate FBE pipeline + IaC repo (resolved: `VPP - Infrastructure`) |
| `eneco-context-docs` | Find FBE runbooks/ADRs (TBD — to be queried in P4) |
| `eneco-tools-connect-mc-environments` | NOT applicable — Duncan's FBE targets Sandbox (`mc-connect-sandbox.sh`) per skill description |
| `2ndbrain-knowledge-build` | Optional — capture lesson if recurrence pattern emerges |

## Prior tasks with reusable evidence

| Prior task | Relevance |
|---|---|
| `2026-04-26-001_mfrr-activation-crashloop-verify-and-fix` | Phase-2 codebase-map.md covered `terraform/fbe/` (PATH DRIFTED — was previously `terraform/fbe/`, now `codebase/fbe/`); name formula confirmed |
| `2026-04-21-001_stefan-vpp-mfrr` | Earlier Phase-2 maps of the VPP eco |
| `2026-03-09-001_service-bus-alert-runbook` | Service Bus alerting; unrelated |
| `2026-04-13-001_acc-clientgateway-issue` | ACC plane; unrelated |
| `2026-04-13-001_argocd-dev-endpoint-unreachable` | ArgoCD on dev; unrelated |

## Agent topology this task will use

| Phase | Agent / Skill | Role |
|---|---|---|
| P2-P3 | `Explore`/Bash | Map + freshness audit (coordinator) |
| P4 | `sherlock-holmes` + `linus-torvalds` | Root-cause investigation tandem |
| P4 | `librarian` (if needed) | Azure docs on Premium EventHub deletion semantics |
| P5 | (coordinator) | Plan with 6Qs |
| P7 (RCA author) | `principal-engineer-document-writer` | Compose holistic RCA |
| P7 (Adversarial) | `socrates-contrarian` + `el-demoledor` (parallel) | Attack full RCA |
| P8 | (coordinator) | NN-6 + verify SC1-SC8 |
