---
task_id: 2026-05-12-003
agent: claude-code
status: draft
summary: Initial requirements mirror — AADSTS650057 for johnson.lobo@eneco.com; AAD identity-plane investigation; deliver Feynman RCA.
---

# 01 Task Requirements — Initial

## Intake
- User: johnson.lobo@eneco.com
- Subscription context: c7425e5b-a7d4-49f1-a45e-23f230783fa5
- Error code: AADSTS650057 (Invalid resource — client has requested access to a resource not listed in client's app registration permissions)
- Client app: 04b07795-8ddb-461a-bbee-02f9e1bf7b46 (Microsoft Azure CLI — public client; not editable)
- Resource app: 0abb4cf9-70e9-4acf-9ad9-b0a75af7ace3 (api://...; Eneco-managed; defined in `Eneco.Infrastructure/main/terraform/platform/aad`)
- Context: running E2E tests on AVD
- Delta signal: teammates can run; johnson.lobo cannot

## End-state
Identify the discriminating sub-cause of AADSTS650057, cite live probe evidence, recommend the exact fix (target file:line if IaC) and produce a holistic Feynman-style RCA inside the incident dir.

## Constraints
- AAD probes: read-only (`az ad`, `az role assignment list`).
- No mutations to AAD, no Terraform changes (this task is diagnose + recommend).
- RCA must include Context Ledger; evidence labels A1/A2/A3.

## Hypotheses
- H1: Enterprise App requires assignment; user/group not assigned
- H2: User missing from IaC-managed group, OR group-to-app assignment stale
- H3: Stale `~/.azure` token cache or wrong tenant context on user's machine
- H4: Guest/B2B account, cross-tenant token issuance
- H5: Conditional Access policy
