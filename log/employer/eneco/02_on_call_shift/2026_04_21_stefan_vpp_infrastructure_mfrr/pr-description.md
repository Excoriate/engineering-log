---
task_id: 2026-04-26-001
agent: claude-code
status: complete
summary: PR description for the defensive trigger fix on terraform-cd-sandbox.pipeline.yaml
---

# PR Description

**Title**: `fix(pipeline): auto-trigger terraform-cd-sandbox on merges to main`

**Branch**: `fix/NOTICKET/mfrr-activation-crashloop` → `main`
**File changed**: `.azuredevops/pipelines/terraform-cd-sandbox.pipeline.yaml` (1 file, +20 / -1)

## Problem

Pipeline `VPP - Infrastructure - Sandbox` (def id 1413) had `trigger: none`, so merges to `main` did not automatically run the pipeline. Combined with the 2 h Environment-approval timeout on the Apply stage, this lets a single missed manual trigger leave Sandbox in silent state drift indefinitely.

That is exactly what happened with PR 172400 ("778244: Activation.mFRR API - Monitoring", merged 2026-04-16 06:31 UTC). The PR added `"activation-mfrr"` to `dispatcher-output-1.consumerGroups` in `sandbox.tfvars`. Apply never ran:

- 2026-04-16 → 2026-04-21: no manual trigger; nothing on `main` ran the pipeline.
- 2026-04-21 11:12 UTC: ArgoCD rolled the R147 image (`0.147.dev.9334f4a`) which expects a blob container named `dispatcher-output-1-activation-mfrr` to exist; it doesn't, because the Apply that would create it never ran. Pod throws `Azure.RequestFailedException: ContainerNotFound` from `BlobCheckpointStoreInternal.ListOwnershipAsync`, exits 139, K8s restarts → `CrashLoopBackOff`.
- 2026-04-21 14:17 UTC: manual trigger of pipeline 1413 (build `1616964`) against `main` at `4dbaf72`. Plan stage succeeded. Apply stage requested approval at 14:18:50.
- 2026-04-21 16:18:50 UTC: `Checkpoint.Approval` skipped — exactly 2 h after request, the ADO default approval timeout. Build "succeeded" overall, Apply silently skipped, resources still missing.

## Root cause

`trigger: none` makes auto-CI opt-out and forces a manual workflow that, combined with the existing Environment approval gate (2 h timeout), can absorb missed apply requests without surfacing them. Any merge to `main` that does not get followed up by an in-time manual trigger plus approval is silently latent drift.

## Fix

```yaml
# Auto-trigger on merges to main that touch Sandbox-affecting code.
# Bare directory paths are recursive directory-prefix matches in ADO YAML —
# any file under these directories triggers a build. Sibling directories
# (e.g. terraform/sandbox-extras/) are NOT covered — extend if added.
trigger:
  batch: true
  branches:
    include:
      - main
  paths:
    include:
      - configuration/terraform/sandbox
      - terraform/sandbox
      - .azuredevops/pipelines/terraform-cd-sandbox.pipeline.yaml
      - .azuredevops/pipelines/variables.yaml

# Suppress ADO's implicit pr: ['default-branch'] when trigger: is set.
# This pipeline must NOT run on PRs — pull-request-validation.yaml at repo root
# already covers PR validation via its own trigger.
pr: none
```

`batch: true` coalesces same-branch queued commits into one build (one approval per batch).

## Why these path filters

| Path | What it gates | Why it triggers Sandbox apply |
|---|---|---|
| `configuration/terraform/sandbox` | `sandbox.tfvars`, `sandbox.backend.config` | Env-specific values consumed by the Sandbox Terraform root. |
| `terraform/sandbox` | All Sandbox-root `.tf` files | Sandbox is a self-contained Terraform root (does NOT source `terraform/fbe/`). |
| `.azuredevops/pipelines/terraform-cd-sandbox.pipeline.yaml` | This pipeline | A change to the pipeline definition itself must re-evaluate the trigger. |
| `.azuredevops/pipelines/variables.yaml` | `terraformVersion`, etc. | Templated by this pipeline (line 4 of the yaml). |

## Why `pr: none`

ADO injects an implicit `pr: ['default-branch']` whenever `trigger:` is set without an explicit `pr:`. This pipeline must not run on PRs — `pull-request-validation.yaml` at the repo root already validates PRs via its own trigger.

## Blast radius

Sandbox only.

- `armServiceConnection: "rg-vpp-app-sb-401"` (line 7) is pinned to the Sandbox resource group's OIDC service connection.
- `terraformVarFilePaths: [sandbox.tfvars]` (lines 38–39) confines variable inputs to Sandbox.
- `applyCondition: eq(variables['Build.SourceBranch'], 'refs/heads/main')` (line 41) is unchanged — non-main branches still cannot apply.
- Acc / prd / FBE pipelines are independent and unaffected.

## What this PR does NOT change

- **Approval gate / 2 h timeout** — intentionally untouched. Lowering the approval requirement or extending the timeout requires team consensus and is out of scope for this PR. This change closes the *triggering* gap, not the *gating* gap. After this PR, missed approvals become a visible queue of pending builds rather than silent state drift — which is strictly better but does not by itself prevent a recurrence if no human approves.
- **Cross-pipeline `sandbox-shared.tfstate` dependency** — `terraform/sandbox/data.tf:6-15` reads `data.terraform_remote_state.platform_shared` from `tfstate-platform/sandbox-shared.tfstate`. The producer of that blob lives outside this repo. No path filter from inside this repo can detect changes there. This is a known cross-pipeline residual.
- **`terraform/fbe/**` path coverage** — Sandbox is self-contained (`terraform/sandbox/event-hub.premium.tf` defines its own paired CG + container modules; `grep -rn "fbe\|source\s*=\s*\"\.\." terraform/sandbox/` returns 0 module references). The FBE Terraform root has its own pipeline; including its paths here would create false-positive triggers.
- **Sibling directories** (`terraform/sandbox-extras/` etc., if added later) — the bare-directory prefix match does not cover sibling dirs sharing a common stem. Comment in the YAML calls this out.

## Verification plan

On merge:

1. ADO reads the new `trigger:` from the merge commit (which itself touches `terraform-cd-sandbox.pipeline.yaml` — in the new path filter), queues a build at post-merge HEAD.
2. `Run Terraform Plan` succeeds and shows:
   - `# module.eventhub_namespace_premium_eventhubs_consumer_groups["dispatcher-output-1.activation-mfrr"]` will be created.
   - `# module.eventhub_namespace_premium_eventhubs_consumer_groups_storage_containers["dispatcher-output-1.activation-mfrr"]` will be created.
   - `Plan: 2 to add, 0 to change, 0 to destroy.`
3. Apply stage requests approval. Approver clicks Approve within 2 h.
4. Apply creates the consumer group + blob container.
5. Verification probes (run by reviewer / on-call):

   ```bash
   az eventhubs eventhub consumer-group list \
     --namespace-name vpp-evh-premium-sbx \
     --eventhub-name dispatcher-output-1 \
     -g rg-vpp-app-sb-401 \
     --query "[?name=='activation-mfrr'].name" -o tsv
   # expected: activation-mfrr

   az storage container exists \
     --account-name vppevhpremiumsb \
     --name dispatcher-output-1-activation-mfrr \
     --auth-mode login -o tsv
   # expected: True
   ```

6. `kubectl -n vpp rollout restart deployment/activationmfrr` — pod recovers; expect `PartitionInitializingAsync` log lines (positive signal), no further `ContainerNotFound`.

If the operator wants the runtime healed *before* this PR merges, the same outcome is achievable today by manually running pipeline 1413 against `main` and approving the apply stage within 2 h:

```bash
az pipelines run \
  --org "https://dev.azure.com/enecomanagedcloud" \
  --project "Myriad - VPP" \
  --id 1413 \
  --branch refs/heads/main \
  --query "{id,buildNumber,status,_links:_links.web.href}" \
  -o json
```

That command is interchangeable with this PR's auto-trigger; running both creates two builds where the second plans zero changes.

## Rollback

Single revert PR. Reverting restores `trigger: none`. State changes from any apply that ran in the meantime are preserved. There is no operational downside to reverting beyond reverting to the prior silent-drift posture.

## Related

- Original ticket: Slack thread `#myriad-platform` ts `1776781493.090009`.
- Prior diagnosis (corrected by this work): `engineering-log/log/employer/eneco/02_on_call_shift/2026_04_21_stefan_vpp_infrastructure_mfrr/systemic-diagram-and-verified-diagnosis.md`.
- Verified diagnosis (this work): `…/.ai/tasks/2026-04-26-001_…/context/verified-diagnosis.md`.
- Adversarial reviews: `socrates-attack-on-plan.md`, `demoledor-attack-on-plan.md` in the same context dir.
- The IaC change that introduced the `activation-mfrr` requirement: PR 172400 (`Activation.mFRR API - Monitoring`, Tiago Santos Rios, 2026-04-16).
- The pipeline run that timed out: `buildId=1616964` (2026-04-21).
