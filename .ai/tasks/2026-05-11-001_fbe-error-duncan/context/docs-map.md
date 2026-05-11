---
task_id: 2026-05-11-001
agent: claude-opus-4-7
status: complete
summary: Docs map — what documentation exists for FBE creation/destroy and its gaps
classification: newly-mapped (will be enriched by eneco-context-docs probe in P4)
---

# Docs map — FBE documentation

## In-repo documentation

| File | Coverage | Gap |
|---|---|---|
| `VPP - Infrastructure/README.md` | Generic Terraform workflow primer (init/plan/apply/destroy + pre-commit setup) | Does NOT mention FBE lifecycle, state model, recovery procedures, or env naming conventions |
| `VPP - Infrastructure/aks-log-analytics/` | Helm chart | Out of scope for FBE |
| `MC-VPP-Infrastructure/docs/00-mssql-immutability.md` | MSSQL immutability note | Out of scope |

## Out-of-repo documentation to query (P4)

Per eneco-context-docs skill: ADO wikis under `Myriad - VPP` project may contain:
- FBE creation runbook
- "What is an FBE" platform doc
- Orphan-resource recovery procedure
- State backend conventions

These will be queried during Phase 4 with specific search terms: `FBE create`, `FBE Feature Branch Environment`, `terraform.kidu state`, `evh-premium`, `orphan resource import`.

## Discovery map (knowledge gaps to fill in P4)

1. **What is FBE mechanically** — does the platform doc describe the 10-env slot model? Or is `kidu`/`afi`/etc. a per-team allocation?
2. **Documented destroy procedure** — is there a "destroy FBE" pipeline that should be run before re-creating? Does it have the same `$` typo?
3. **Orphan-resource recovery doctrine** — does the team have a documented `terraform import` runbook for this case?
4. **State backend ownership** — who owns `tfstatevpp/tfstate/terraform.{env}`? Is there a documented cleanup procedure for stale state blobs?
