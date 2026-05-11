---
task_id: 2026-05-11-002
agent: claude-opus-4-7
status: complete
summary: AI scaffolding map — skills, prior tasks, agent topology for rotation harvest + runbook authoring
classification: reused (harness unchanged), with new task-specific skill stack (eneco-context-slack/docs/repos + 2ndbrain-obsidian + librarian as needed)
phase: 2
---

# AI map — engineering-log harness + skill stack

## Skills planned for invocation

| Skill | Purpose | Trigger |
|---|---|---|
| `2ndbrain-obsidian` | Foundational vault interaction (read notes in `2-areas/work-eneco`) | Mandatory first fetch per user directive |
| `eneco-context-slack` | Historical Slack threads on PAT rotation (Fabrizio/Roel) — search `#myriad-platform`, `#myriad-alerts-devops`, `#myriad-env-fbe` | H1 hypothesis test |
| `eneco-context-docs` | ADO wiki search for rotation runbooks (Trade Platform Troubleshooting, FAQ, BTM/Platform spaces) | H2 hypothesis test |
| `eneco-context-repos` | IaC search for ArgoCD repo-Secret terraform/yaml templates + KV→cluster sync mechanism (External Secrets Operator? CSI driver? Akeyless?) | Resolve "is the sandbox secret an Opaque type or an ExternalSecret" gap |
| `eneco-tools-connect-mc-environments` | If runtime probe against MC clusters becomes necessary | Optional — to enumerate MC cluster ArgoCD secrets |
| `librarian` (Context7) | ArgoCD repo-credentials docs, AAD PAT lifecycle docs | If wire-level claim needs source verification |

## Prior tasks with reusable evidence

| Prior task | Relevance | Reuse |
|---|---|---|
| `2026-05-11-001_fbe-error-duncan` | Same incident lineage (Duncan's FBE blocked first by F2 orphan, then by this PAT issue). Already has codebase-map of VPP-Infrastructure + automation-map of FBE pipeline. | Reference for FBE pipeline / ApplicationSet context — DO NOT duplicate |
| `2026-04-13-001_argocd-dev-endpoint-unreachable` | Tangential — ArgoCD on dev plane | Skip |

## Agent topology

| Phase | Agent / Skill | Role | Output artifact |
|---|---|---|---|
| P2 (Map) | (coordinator) | Map + delta-vs-prior-task | This map |
| P3 (Confirm) | `AskUserQuestion` | Single route-flipping question (scope of automation proposal: 4 named PATs vs broader credential class) | 01-task-requirements-final.md |
| P4 (Context) | `sherlock-holmes` | Hypothesis discipline + cross-source convergence | context/hypotheses.md |
| P4 (Context) | `eneco-context-slack` (sidecar) | Historical rotation thread harvest | context/slack-rotation-harvest.md |
| P4 (Context) | `eneco-context-docs` (sidecar) | ADO wiki rotation runbook search | context/wiki-rotation-search.md |
| P4 (Context) | `eneco-context-repos` (sidecar) | IaC search — ArgoCD Secret templates, ESO ExternalSecret, KV→cluster | context/iac-secret-templates.md |
| P5 (Plan) | (coordinator) + `socrates-contrarian` | 6Qs + Adversarial Challenge attack on inherited interpretation | plan/plan.md + auxiliary/socrates-attack.md |
| P6 (Specify) | (coordinator) | Spec per deliverable | specs/ |
| P7 (Execute) | (coordinator) | Author 3 deliverables | output/ + external writes |
| P7 (Adversarial) | `neo-hacker` | Trust-boundary attack on rotation procedure (does it leak the PAT? race the cutover?) | auxiliary/neo-hacker-attack.md |
| P7 (Adversarial) | `sre-maniac` | Failure-path attack on runbook | auxiliary/sre-maniac-attack.md |
| P8 (Verify) | `el-demoledor` OR `linus-torvalds` (different agent_type from P7 attackers) | "Am I verifying the right thing?" meta-attack | verification/adversarial-check-the-verification.md |

## Constraint: vault-first ordering

User directive: "you're obliged to check my 2nd brain first." → Phase 4 starts with vault reads (already partially done in P2 for size-checking). Slack/wiki/IaC sidecars dispatch ONLY after vault baseline is on disk in `context/vault-extracts.md`.

## Constraint: no infra mutation in this task

OPS-SHAPE-ATTRIBUTE: read-only. Runtime probes (`az`, `argocd`, `kubectl`) allowed only if the user explicitly asks for live verification of a vault claim. Default: keep this task to documentation harvest only.
