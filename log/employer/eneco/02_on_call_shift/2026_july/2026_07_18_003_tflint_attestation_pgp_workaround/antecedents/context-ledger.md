---
title: "Antecedents & context ledger — TFLint attestation crash"
type: antecedents
incident_id: 2026_07_18_003_tflint_attestation_pgp_workaround
task_id: 2026-07-19-001
status: complete
timestamp: 2026-07-19T17:35:00Z
---

# Antecedents

The prior artifacts this RCA is built on, and every context dimension resolved or blocked.

## Inherited input (ENRICH mode)

| Antecedent | Location | Status after re-probe |
|---|---|---|
| Slack intake | `../slack-intake.md` | Consumed; **corrected** — it conflated the failure site (`Eneco.Infrastructure`, build 1721100) with the mitigation repo (`Dispatching.Infrastructure`). Re-verified via `az pipelines build show`. |
| Upstream fact verification | `../../../../../.ai/tasks/2026-07-19-001_tflint-attestation-pgp-rca-fix/context/upstream-tflint-facts.md` | Independently re-probed; the "azurerm 0.28.0 has no attestations" nuance was confirmed and reconciled against the build log. |
| Reproduction outputs & scripts | `../proofs/` | Generated this session against real TFLint binaries. |

## Context dimensions

| Dimension | Resolved? | Source / blocked reason |
|---|---|---|
| Failing repo & pipeline | Yes | `az pipelines build show --id 1721100` → `Eneco.Infrastructure` / "Platform - RBAC" |
| TFLint & ruleset versions | Yes | build log (`v0.63.1`) + `.tflint.hcl` (`azurerm 0.28.0`) |
| How TFLint is installed | Yes | CCoE template `steps/test/tflint/install.yaml` (`tflintVersion: 'latest'`) |
| Fix release | Yes | GitHub releases API (`v0.64.0`) |
| Why azurerm 0.28.0 crashed (its attestation status) | **Resolved** | 0.28.0's `checksums.txt` digest is attested (HTTP 200, signed 2025-03-21); the window returned that entry with a `null` bundle → nil deref; bundle is repopulated now. An earlier draft hashed the *zip* (404) and wrongly read it as "no attestations" — corrected after adversarial review. |
| Full org-wide inventory of exposed repos | **Blocked** | Out of scope; resolving probe = org-wide `.tflint.hcl` + pipeline grep (RCA L11). |
