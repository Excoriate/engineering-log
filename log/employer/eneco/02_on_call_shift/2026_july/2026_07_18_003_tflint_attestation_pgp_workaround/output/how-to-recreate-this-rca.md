---
title: "How to recreate this RCA from cold — TFLint attestation crash"
type: rca-recreation
incident_id: 2026_07_18_003_tflint_attestation_pgp_workaround
task_id: 2026-07-19-001
status: complete
timestamp: 2026-07-19T17:25:00Z
---

# How To Recreate This RCA

A pass/fail replay contract. Another engineer or agent, starting from only the intake, should be able to rebuild every load-bearing claim by following these steps in order. If a step needs hidden author memory, this document has failed — report it.

## Recreation Knowledge Contract

After following this document, a fresh engineer can, without reading the RCA prose: name the real failing repo, quote the exact panic frame and the resolved TFLint version, state the three-file config contract and the `'latest'` trap, name the fix release, and reproduce an exit-0 for the workaround — each backed by a command they ran themselves.

## Preconditions

| Need | How to get it | Blocked path |
|---|---|---|
| ADO read access to `Myriad - VPP` + `CCoE` projects | `az login` (Eneco tenant `eca36054-…`), then `az pipelines` / `az devops invoke` | If `az` can't reach ADO, ask the user to run `az login` and accept the browser prompt |
| Git SSH to ADO | Load the Eneco key into the agent (the user's `sshwork` alias runs `ssh-add ~/.ssh/work/eneco/eneco_personal`) | Without it, ADO clones fail `Permission denied (publickey)`; ask the user to load the key |
| `tflint`, `git`, `curl`, `python3`, `unzip` | Homebrew | — |
| A `GITHUB_TOKEN` (optional) | env | Only needed to avoid GitHub API rate limits; the attestation *trigger* also needs a token in CI |

## Source Inventory

| Source | Access | Answers |
|---|---|---|
| ADO build 1721100 metadata + logs | `az pipelines build show` / `az devops invoke` | which repo failed, resolved TFLint version, the panic |
| `Eneco.Vpp.Core.Dispatching.Infrastructure` | `git clone` (SSH) | `.tflint.hcl`, `.pre-commit-config.yaml`, `.azuredevops/*.pipeline.yaml` |
| `CCoE/azure-devops-templates` @ `2.6.9` | `git clone --branch 2.6.9` (SSH) | `steps/test/tflint/install.yaml` (`'latest'` default) |
| GitHub REST (tflint + ruleset) | `curl api.github.com` | fix release, attestation presence per version |
| tflint source at tag v0.63.1 | raw.githubusercontent.com | the `auto`/unmarshal/verify code path |

## Replay Steps

1. **Identify the real failing repo.** `az pipelines build show --id 1721100 --org https://dev.azure.com/enecomanagedcloud --project "Myriad - VPP"`. Expect `repo=Eneco.Infrastructure`, `definition=Platform - RBAC`, `result=failed`. → RCA L2/L7.
2. **Read the panic from the build log.** `az devops invoke --area build --resource logs --route-parameters project="Myriad - VPP" buildId=1721100 logId=63 --api-version 7.1 --query value -o tsv`. Expect `Downloading TFLint v0.63.1`, then `Installing "azurerm" plugin… Panic … TlogEntries … VerifyAttestations`. → RCA L4/L7.
3. **Clone the target + failing configs.** Clone `Eneco.Vpp.Core.Dispatching.Infrastructure`; read `.tflint.hcl`, `.pre-commit-config.yaml`, `.azuredevops/*.pipeline.yaml`. → RCA L5.
4. **Trace the tool version to its source.** Clone `CCoE/azure-devops-templates` at tag `2.6.9`; read `steps/test/tflint/install.yaml` (`tflintVersion` default `'latest'`). → RCA L5/L6.
5. **Confirm the fix release.** `curl -fsSL api.github.com/repos/terraform-linters/tflint/releases/latest`. Expect `v0.64.0`, 2026-07-17T15:37Z, notes cite #2593/#2600. → RCA L8.
6. **Prove the workaround + end-state.** Download tflint v0.63.1 and v0.64.0; run `tflint --init` for azurerm 0.28.0 with/without `signature = "pgp"` in a temp `TFLINT_PLUGIN_DIR`. Expect exit 0 in all cases (v0.63.1 `pgp` prints a legacy-key warning). → RCA L9.
7. **Query the digest tflint actually uses.** Hash azurerm 0.28.0's **`checksums.txt`** (not the zip) and query `.../attestations/sha256:<digest>` → HTTP 200, 1 attestation, bundle non-null today. Hashing the *zip* gives a misleading 404. → RCA L9/L10.
8. **Confirm the code mechanism.** Fetch `plugin/install.go` + `plugin/signature.go` at tag `v0.63.1`; read `shouldVerifyAttestations` (`len>0`) and the `json.Unmarshal(null)→nil→Verify(nil)` path. → RCA L4.

## Evidence Promotion Rules

- A claim is **FACT** only after you personally ran the command/URL this session and saw the stated output; inherited screenshots or intake prose are **INFER** until re-run.
- The "azurerm 0.28.0 panicked during the window" mechanism is **VERIFIED**: 0.28.0's `checksums.txt` digest is attested (step 7, HTTP 200), so during the window GitHub returned that entry with a null bundle → nil deref; today the bundle is repopulated. Do **not** repeat the earlier mistake of hashing the *zip* (which 404s and falsely reads as "no attestations").
- Any `git show origin/…` read must be preceded by `git fetch` to avoid a stale mirror.

## Reproduction Failure Conditions

- If step 1 returns a repo other than `Eneco.Infrastructure`, the incident moved — re-anchor on that repo's `.tflint.hcl`.
- If step 6's default (no-`pgp`) run **panics**, the GitHub API window is open again — capture the raw attestation response (the `bundle: null` state) for the record.
- If step 5 shows a `latest` newer than v0.64.0, verify the fix commit `9b811b1` is an ancestor of that tag before recommending it as the pin.
- If any clone fails `Permission denied (publickey)`, the ADO SSH key is not loaded — this is an access blocker, not a code finding.
