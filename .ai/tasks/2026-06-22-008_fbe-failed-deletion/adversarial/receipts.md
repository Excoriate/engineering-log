---
title: Adversarial receipts — FBE thor unblock
task_id: 2026-06-22-008
agent: claude-opus-4-8
status: complete
summary: Grading of sre-maniac review of the proposed FBE thor unblock. Lane 1 BREAKS the stage-selection shortcut; recommendation changed to a pipeline idempotency guard + full re-run.
timestamp: 2026-06-22T00:00:00Z
---

# Receipts — sre-maniac review (`sre-quickfix-review.md`)

| Lane | Finding | Verdict | Disposition | Evidence |
|------|---------|---------|-------------|----------|
| 1 | "DestroyInfra only" stage-selection won't run — implicit dependsOn on `DestroyAppConfiguration` + job `condition: succeeded()` → cascade-skip when predecessor deselected | BREAKS | **ACCEPTED** — removed stage-selection from the recommendation; replaced with empty-appconfig guard + full re-run | ADO stage-condition semantics; `azure-pipeline-fbe-del.yml:187-193` (no dependsOn, `condition: succeeded()`) |
| 2 | DestroyInfra consumes no `stageDependencies` (var-self-contained) | HOLDS | Accepted — necessary but insufficient (Lane 1 dominates) | `azure-pipeline-fbe-del.yml:187-358` has no `variables:`/`stageDependencies` |
| 3 | `contains(id,'thor')` deletes any thor-substring resource in the shared RG | RISKY | **ACCEPTED** — added pre-flight `az resource list` check to the procedure | `:297-316`; live list = KV + smart-detector only |
| 4a | `data.azurerm_key_vault_secret` reads 44 secrets from shared KV `vpp-aks-d` on destroy; could fail off-AVD/firewalled | CONDITIONAL | **ACCEPTED** — run via the pipeline SP (whitelisted), not laptop CLI; rules out manual `terraform destroy` from a workstation | `data.tf:42-51`; run 1 reached CosmosDB destroy ⇒ pipeline SP can read the source KV |
| 4b | Another manual cert/secret could re-trigger the 403 | n/a | **REBUTTED** | `az keyvault certificate list` = `[]`; `az keyvault secret list --query "[?managed]"` = `[]` ⇒ no cert-backed secret exists |
| 5 | Green build ≠ done: release step (`condition: succeeded()`) may skip → row stays `used`; KV soft-deletes (7d, no purge protection) → name not reusable; smart-detector orphan | REAL | **ACCEPTED** — witness signal = storage-table row `active='unused'` (NOT green build); added KV-purge + orphan notes | `:319-322` release `condition: succeeded()`; KV `softDelete=true purge=off retention=7` |
| 6 | Safer path: empty-appconfig guard + full re-run (Option A) or manual break-glass (Option B) | — | **ACCEPTED** — Option A is the lead recommendation (durable + unblock) | `:99` appconfig lookup; template `sandbox.template.yml:118-124` |

No findings Deferred. No Rebut-without-evidence. Stage-selection shortcut retired.
