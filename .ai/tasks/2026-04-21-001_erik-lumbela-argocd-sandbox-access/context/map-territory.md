---
task_id: 2026-04-21-001
agent: claude-code
status: complete
summary: Phase 2 territory map — AAD platform, ArgoCD config, FTO repos, Slack list intake location.
---

# Territory Map

## Load-bearing repositories (local mirrors, @AZUREDEVOPS/eneco-src)

- **AAD (platform)** — canonical IaC for 161 app regs + 85 security groups
  `enecomanagedcloud/myriad-vpp/Eneco.Infrastructure/terraform/platform/aad/`
  (Skill: `eneco-platform-aad` owns this surface)
- **ArgoCD config** — ArgoCD Application/Project/RBAC definitions
  `enecomanagedcloud/myriad-vpp/ArgoCD-Config/`
  `enecomanagedcloud/myriad-vpp/VPP.GitOps/argocd-configuration/`
- **FTO (Flex Trade Optimizer)**
  - Service: `enecomanagedcloud/vpp-assetoptimisation/flex-trade-optimizer/`
  - Infrastructure: `enecomanagedcloud/vpp-assetoptimisation/flex-trade-optimizer-infrastructure/`
  - GitOps: `enecomanagedcloud/vpp-assetoptimisation/flex-trade-optimizer-gitops/`
  (Skill: `eneco-flex-trade-optimizer` covers the three-repo architecture)

## Intake source

- On-call record: `log/employer/eneco/02_on_call_shift/2026_04_21_erik_lumbela_argocd_sandbox_access/slack-antecedents.txt`
- Slack list record: `https://eneco-online.slack.com/lists/T039G7V20/F0ACUPDV7HU?record_id=Rec0AUE5HU5MJ` (Myriad Platform intake)

## Runtime probe surfaces (read-only)

- `kubectl` sandbox cluster — verifies ArgoCD is deployed and reachable.
- `argocd` CLI — list projects, check AppProject roles/RBAC, introspect user claims.
- `az ad group member list` — verify Erik's group memberships (needs sandbox tenant session; MC dev alias `enecotfvppmclogindev` is read-only for dev).
- Azure DevOps repos (via MCP `mcp__rootly__*` not applicable — AAD/PR lookup uses direct repo access or MCP if available).

## Contract-surface matrix (to reconcile in Phase 4)

| Surface | Canonical | Downstream |
|---|---|---|
| AAD sandbox group for FTO | `Eneco.Infrastructure/terraform/platform/aad/*.tf` (security groups + members) | Azure AD tenant (runtime) |
| ArgoCD project RBAC | `ArgoCD-Config/` or `VPP.GitOps/argocd-configuration/` ConfigMap + AppProject | `argocd-rbac-cm` on sandbox cluster |
| FTO AppProject | `flex-trade-optimizer-gitops/` AppProject manifests | ArgoCD sandbox `flex-trade-optimizer` project |
| SSO claims | Azure AD app registration for ArgoCD sandbox | `argocd-cm` OIDC config |

## Skill pipeline (per user instruction)

1. **eneco-oncall-intake-slack** → harvest Slack context (Phase 3 confirm).
2. **eneco-oncall-intake-enrich** → probe AAD/ArgoCD/k8s read-only (Phase 4 context).
3. **eneco-platform-aad** (if needed for deep AAD module mechanics).
4. **eneco-context-repos** (locate Erik's PR in Eneco.Infrastructure).
5. **2ndbrain-*** — consolidate lessons at end.

## Gate-out

All five sub-maps written inline above (ai/codebase/config/docs/discovery). Ready for Phase 3 confirmation via Slack intake skill.
