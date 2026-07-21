---
title: "How to fix — operational card (TFLint attestation crash)"
type: how-to-fix
incident_id: 2026_07_18_003_tflint_attestation_pgp_workaround
task_id: 2026-07-19-001
status: complete
timestamp: 2026-07-19T17:30:00Z
note: "Terse operational companion. The teaching / PR-ready deep-dive is fix.md (Feynman); read that to defend the change in review."
---

# How To Fix — operational card

> Terse repair card for on-call. The full teaching guide (why each step is correct, how to defend it in review, first-principles on attestation vs PGP) is **[`fix.md`](./fix.md)**. Deep mechanism is **[`rca.md`](./rca.md)**.

## Mechanism being closed

`tflint --init` panics in `VerifyAttestations` because GitHub's attestation API returned a `null` bundle and TFLint ≤ v0.63.1 dereferenced it. Two levers close it: (a) verify the plugin via PGP instead of attestation; (b) run a TFLint that handles the API correctly (≥ v0.64.0).

## Action 1 — Immediate mitigation (per repo)

- **State plane changed:** the repo's `.tflint.hcl` verification mode.
- **Do:** add `signature = "pgp"` to the `azurerm` plugin block. (Already on `main` for `Eneco.Vpp.Core.Dispatching.Infrastructure` and `Eneco.Infrastructure`.)
- **Rollback boundary:** delete the line to revert; purely a config toggle, no state destroyed.
- **Verify:** `tflint --init` exits 0 (a "legacy PGP signing key" warning is expected).
- **Never:** `signature = "none"` — that disables verification.

## Action 2 — Durable fix / the PR (per repo)

- **State plane changed:** the pipeline's TFLint version input.
- **Do:** in both `.azuredevops/infra-ci.pipeline.yaml` and `.azuredevops/azure-devops-ci-pipeline.yaml`, pass `tflintVersion: "v0.64.0"` to the `pre-commit.yaml@templates` job; then remove `signature = "pgp"` from `.tflint.hcl` (return to `auto`).
- **Rollback boundary:** revert the two YAML edits + restore the `signature` line; no infrastructure touched.
- **Verify:** CI "Install TFLint" log prints `Downloading TFLint v0.64.0`; the `terraform_tflint` step is green. Locally, `tflint --init` with v0.64.0 and no `signature` line exits 0.
- **Residual risk:** a minor TFLint bump *could* surface new lint findings on existing code; review the first run.

## Action 3 — Systemic (owner: CCoE)

- **State plane changed:** the shared `CCoE/azure-devops-templates` default.
- **Do:** change `steps/test/tflint/install.yaml` `tflintVersion` default from `'latest'` to a pinned, scheduled-bump version. See [`sre-toil-removal-proposal.md`](./sre-toil-removal-proposal.md).
- **Residual risk (if skipped):** every other repo still on `'latest'` remains exposed to the next upstream regression.

## Exit criterion

Once CI is guaranteed on TFLint ≥ v0.64.0, remove any remaining `signature = "pgp"` lines to return to attestation verification and drop the legacy-key warning.
