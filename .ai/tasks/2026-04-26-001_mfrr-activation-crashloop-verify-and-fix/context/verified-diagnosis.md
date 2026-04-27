---
task_id: 2026-04-26-001
agent: coordinator
status: complete
summary: Phase 4 verification — diagnosis FAILS at the load-bearing IaC claim; the proposed tfvars fix is already merged on origin/main
---

# Phase 4 — Verified Diagnosis

## TL;DR

The diagnosis at `systemic-diagram-and-verified-diagnosis.md` proposes adding `"activation-mfrr"` to `dispatcher-output-1.consumerGroups` in `sandbox.tfvars`.

**That entry is already present on origin/main at commit `4dbaf72`** — the same commit the diagnosis cites. It was added by **PR 172400 ("Activation.mFRR API - Monitoring", Tiago Santos Rios, 2026-04-16 06:31 UTC)**, five days *before* the diagnosis was authored.

The on-call worktree branch `fix/NOTICKET/mfrr-activation-crashloop` is at the same commit (`4dbaf72`) and `git status` is clean. **There is no IaC change to make.**

## Verified facts (this session, FACT)

| # | Claim | Evidence | Classification |
|---|---|---|---|
| F1 | Worktree HEAD = `4dbaf72e23ae8ebd6d870bd52c950a28d4dc71a4`; origin/main HEAD = `4dbaf72e23ae8ebd6d870bd52c950a28d4dc71a4`; identical. Branch `fix/NOTICKET/mfrr-activation-crashloop`, `git status --porcelain` empty. | `git rev-parse HEAD origin/main`, `git status --porcelain` | A1 FACT |
| F2 | Commit `4dbaf72` author/date/subject: Tiago Santos Rios, 2026-04-16 06:31:41 UTC, "Merged PR 172400: 778244: Activation.mFRR API - Monitoring". | `git show -s --format=...` | A1 FACT |
| F3 | The PR 172400 diff includes `+      "activation-mfrr" = { … }` inside `eventhub_premium_attributes` → `dispatcher-output-1` → `consumerGroups`. | `git show 4dbaf72 -- configuration/terraform/sandbox/sandbox.tfvars` shows exactly that hunk at line 375+. | A1 FACT |
| F4 | At HEAD (4dbaf72), `configuration/terraform/sandbox/sandbox.tfvars` has the `dispatcher-output-1.consumerGroups` block with **6** consumer groups: `cgadxdo`, `monitor`, `assetmonitor`, `tenant-gateway-nl`, `asset-simulator`, `activation-mfrr`. The block spans lines 342–387; `activation-mfrr` entry at lines 379–385. | Direct file read of `configuration/terraform/sandbox/sandbox.tfvars` lines 200–420. | A1 FACT |
| F5 | **Two independent Terraform roots** exist with the same paired-module pattern: `terraform/fbe/event-hub.premium.tf` (FBE root, lines 67–93) and `terraform/sandbox/event-hub.premium.tf` (Sandbox root, lines 70–96). EACH root defines its own `eventhub_namespace_premium_eventhubs_consumer_groups` + `eventhub_namespace_premium_eventhubs_consumer_groups_storage_containers` modules iterating its own `local.eventhub_premium_attributes`, with container `name = "${eventhub_name}-${consumer_group_name}"`. Sandbox runtime resources are produced by `terraform/sandbox/`, NOT by `terraform/fbe/`. The pipeline `terraform-cd-sandbox.pipeline.yaml` line 13 sets `workingDirectory = $(Build.SourcesDirectory)/terraform/sandbox` — Terraform CWD never sees `terraform/fbe/*.tf`. | Direct file reads of both `terraform/fbe/event-hub.premium.tf` and `terraform/sandbox/event-hub.premium.tf`; `grep -rn "fbe\|source\s*=\s*\"\.\." terraform/sandbox/` returns 0 module references; pipeline yaml line 13. | A1 FACT |
| F6 | `terraform/sandbox/locals.tf` flattens `var.eventhub_premium_attributes` (declared in `terraform/sandbox/variables.tf`, populated from `configuration/terraform/sandbox/sandbox.tfvars`) into `local.eventhub_premium_attributes` with `eventhub_name` and `consumer_group_name` keys. The for_each in Sandbox's F5 module pair therefore produces one CG resource and one container resource per (`eh`, `cg`) pair declared in `sandbox.tfvars`. (FBE has its own analogous flatten in `terraform/fbe/locals.tf` for FBE's tfvars — independent state.) | Direct file reads. | A1 FACT |
| F5b | Sandbox DOES depend on a remote-state output from another pipeline: `terraform/sandbox/data.tf:6-15` reads `data "terraform_remote_state" "platform_shared"` from blob `tfstate-platform/sandbox-shared.tfstate`. Producer of that blob is NOT in this repository (no matching backend.config). Outputs are consumed by 6 sandbox `.tf` files (service-bus, redis, kusto, cosmos, sql, …) for VNet/subnet/SQL ids. This is a CROSS-PIPELINE dependency that no path filter on this repo can detect. | `grep -rn "sandbox-shared\|tfstate-platform"`; `find -name "*.backend.config"` returned only the sandbox root's own backend. | A1 FACT |
| F7 | No other Terraform file in the worktree declares `dispatcher-output-1-activation-mfrr` as a literal storage container name. The FBE module pair is the unique IaC owner of that container. | `grep -rn "dispatcher-output-1-activation-mfrr" terraform/ configuration/` → 0 hits. | A1 FACT |
| F8 | `activation-mfrr` appears at exactly TWO lines in `sandbox.tfvars`: line 226 (under `activation-response-output-1.consumerGroups`) and line 379 (under `dispatcher-output-1.consumerGroups`). | `grep -n "activation-mfrr" configuration/terraform/sandbox/sandbox.tfvars`. | A1 FACT |

## Where the prior diagnosis is wrong

The prior `systemic-diagram-and-verified-diagnosis.md` §3 row labelled A1 FACT states:

> "Origin/main `sandbox.tfvars` at commit `4dbaf72`: `dispatcher-output-1` block has 4 consumer groups (`cgadxdo`, `monitor`, `assetmonitor`, `tenant-gateway-nl`), **no `activation-mfrr`** — `git show origin/main:configuration/terraform/sandbox/sandbox.tfvars` lines 335–367"

Three components of that row are demonstrably false at commit `4dbaf72`:

| Component | Diagnosis claim | Reality at 4dbaf72 |
|---|---|---|
| Number of CGs in `dispatcher-output-1` | 4 | 6 |
| Set of CG names | `{cgadxdo, monitor, assetmonitor, tenant-gateway-nl}` | `{cgadxdo, monitor, assetmonitor, tenant-gateway-nl, asset-simulator, activation-mfrr}` |
| Line range of the block | 335–367 | 342–387 |

The most plausible explanation: the diagnosis author's local origin was stale (PR 172400 was merged to main and not pulled before authoring), and the cited `git show origin/main:...` output never saw the post-PR content. The "A1 FACT" classification was applied to an `[INFER from stale local mirror]` reading.

Implication chain:

1. PR 172400 merged to main on **2026-04-16 06:31 UTC**.
2. Pipeline 1413 ("VPP - Infrastructure - Sandbox") is wired off `main` (per the diagnosis itself).
3. **If** the pipeline ran apply on the post-merge commit, the CG + container were created on Azure on or shortly after 2026-04-16.
4. **By 2026-04-21** (Stefan's ticket), the resources should already exist on Azure.
5. Stefan's manual run of the pipeline at `buildId=1616964` reporting "Stage 2 Apply SKIPPED" with "plan-no-change" is **consistent with that already-applied state** — there is no longer anything to add.
6. If runtime probes from 2026-04-21 still showed "CG missing / container missing", the failure is **operational** (apply did not actually run after PR 172400, or it failed silently, or runtime drift since), **not IaC**.

## Hypotheses re-evaluated

- **H1** (one-hunk tfvars fix on `dispatcher-output-1.consumerGroups`): **ELIMINATED.** The hunk already exists at HEAD; `git diff origin/main HEAD -- sandbox.tfvars` is empty.
- **H2** (parameter-error variant): **ELIMINATED on the IaC side.** No different EH or different env tfvars holds an alternative declaration site.
- **H3** (root cause elsewhere — apply not run, RBAC, network, helm mismatch, OR diagnosis runtime probes themselves are incorrect): **REMAINS POSSIBLE.** Cannot be eliminated from IaC alone; needs Azure CLI probes.

## What this Phase 4 cannot conclude

- Whether the consumer group `activation-mfrr` and the blob container `dispatcher-output-1-activation-mfrr` **currently exist on Azure** at sandbox runtime. The diagnosis claimed they did not. Re-running the same probes today is the next step but requires Azure CLI auth, which this session does not load. Marked `[UNVERIFIED[blocked: Azure CLI not authenticated in this Claude session]]`.
- Whether pipeline 1413 successfully applied commit `4dbaf72` after the PR-172400 merge (or whether Stage 2 was skipped on that *first* run too, leaving the tfvars+state mismatch the user is now seeing). Needs ADO pipeline-history probe.
- Whether the activationmfrr pod's crashloop on 2026-04-21 was indeed `ContainerNotFound` from the BlobCheckpointStore vs. a different exception. Needs `kubectl logs`.

## Next-step decision matrix

| Azure runtime state (probe needed) | What the IaC says | Real fix |
|---|---|---|
| CG + container both **EXIST** | Already correct | No IaC change. Rolling-restart `activationmfrr` Deployment to clear stale crashloop; also check that App Config strings match. |
| CG + container both **MISSING** | Already correct | No IaC change. Trigger `terraform apply` against current main (i.e. ensure pipeline 1413 Stage 2 actually runs against `4dbaf72`, not skipped). |
| CG **EXISTS**, container **MISSING** (or vice versa) | Already correct | No IaC change. Investigate why the FBE module pair partially applied; potentially `terraform apply -target=module.eventhub_namespace_premium_eventhubs_consumer_groups_storage_containers`. |
| CG missing on a *different* hub or container under a *different* SA | IaC is wrong on a *different* axis than the diagnosis claimed | New tfvars hunk targeted at the actual missing surface. |

In all cases, **the prepared worktree branch is empty** — there is no commit to push and no PR to open from this session.

## Recommendation

Stop the planned "apply tfvars hunk + open PR" route. Surface this finding to the user, who will decide:
- A. Pivot deliverables to an *audit-and-corrective-action* memo (no PR; replace with operator runbook + after-action note).
- B. Run Azure CLI probes (out of this session's scope without explicit auth).
- C. Discard branch / worktree as no-op work that the prior diagnosis assumed was needed but isn't.

---

# Phase 4 Update — Runtime probes (post-`az login`)

User authenticated `az` interactively (Alex.Torres@eneco.com, tenant eca36054…), `az account set` to Sandbox `7b1ba02e-bac6-4c45-83a0-7f0d3104922e`. Runtime probes executed live.

## R1 — Runtime CG state on `dispatcher-output-1`

Command: `az eventhubs eventhub consumer-group list --namespace-name vpp-evh-premium-sbx --eventhub-name dispatcher-output-1 -g rg-vpp-app-sb-401 --query "[].name" -o tsv`

```
$Default
asset-simulator
assetmonitor
cgadxdo
monitor
tenant-gateway-nl
```

`activation-mfrr` **MISSING**. A1 FACT.

## R2 — Runtime blob container state

`az storage container exists --account-name vppevhpremiumsb --name dispatcher-output-1-activation-mfrr --auth-mode login` → `{"exists": false}`. A1 FACT.

Sibling container `activation-response-output-1-activation-mfrr` DOES exist (parity probe via `container list --query`). A1 FACT.

## R3 — Pipeline 1413 history

`az pipelines runs list --pipeline-ids 1413 --top 15`:

| Run | Branch | SourceVersion | Result | Notes |
|---|---|---|---|---|
| 20260424.1 | feat/remove-dispatching-comosdb | b468e453 | succeeded | Apply blocked by `applyCondition` (not main) |
| 20260421.1 (id 1616964) | refs/heads/main | 4dbaf72 | succeeded | **Apply stage SKIPPED — see R4** |
| 20260403.1 | refs/heads/main | 4dd886b9 | succeeded | Pre-PR-172400 commit; doesn't matter |
| … | … | … | … | … |

A1 FACT: between PR 172400 merge (2026-04-16 06:31 UTC) and Stefan's run on 2026-04-21 14:17 UTC, **no pipeline run occurred against `refs/heads/main`**, because pipeline yaml has `trigger: none` (line 1 of `.azuredevops/pipelines/terraform-cd-sandbox.pipeline.yaml`).

## R4 — Why Apply was skipped on run 1616964

ADO Timeline records under stage `Terraform Apply` (id `448def64…`):

| Record | Type | Result | Start | Finish | Duration |
|---|---|---|---|---|---|
| Terraform Apply | Stage | skipped | — | — | — |
| Checkpoint | Checkpoint | skipped | 14:18:50 | 16:18:50 | **2h 0m exact** |
| Checkpoint.Approval | Checkpoint.Approval | skipped | 14:18:50 | 16:18:50 | 2h 0m exact |

A1 FACT: **the apply stage's environment-approval gate timed out at exactly 2 hours** (Azure DevOps default approval timeout). The diagnosis hypothesis "plan-no-change ⇒ apply auto-skipped" (§5 of `systemic-diagram-and-verified-diagnosis.md`) is **wrong**; the actual cause is "approval-not-granted-within-2h ⇒ stage skipped".

## R5 — Pipeline definition

`.azuredevops/pipelines/terraform-cd-sandbox.pipeline.yaml`:
- Line 1: `trigger: none` — no auto-trigger on merge.
- Line 23: stages templated from `CCoE/azure-devops-templates ref 2.6.9` `stages/infrastructure/terraform/azure-oidc-validate-and-apply.yaml`.
- Line 31: `azureDevOpsEnvironmentName: terraform-sandbox` — environment with approval check.
- Line 41: `applyCondition: eq(variables['Build.SourceBranch'], 'refs/heads/main')` — apply only on main.

## Synthesis — what really happened

1. **2026-04-16 06:31 UTC** — PR 172400 ("Activation.mFRR API - Monitoring", Tiago) merged to main, adding `activation-mfrr` to `dispatcher-output-1.consumerGroups` in sandbox.tfvars. *Author intent: also create CG + blob container via the FBE module pair.*
2. **2026-04-16 → 2026-04-21 (5 days)** — No pipeline run against main. `trigger: none` means no auto-apply on merge. *Latent state drift — IaC says "create resources", state says "nothing to do" because state had not been refreshed since pre-PR.*
3. **2026-04-21 11:12 UTC** — R147 image (`0.147.dev.9334f4a`) deployed via VPP-Configuration → ArgoCD path. New image contains a `DispatcherOutput` consumer that calls `BlobCheckpointStore.ListOwnershipAsync` against container `dispatcher-output-1-activation-mfrr` — which doesn't exist. Pod throws `Azure.RequestFailedException: ContainerNotFound`, exits 139, K8s restarts → CrashLoopBackOff.
4. **2026-04-21 14:17 UTC** — Stefan triggers pipeline 1413 manually against main at 4dbaf72. Plan succeeds (would show `+2 to add`). Apply stage requests approval at 14:18:50.
5. **2026-04-21 16:18:50 UTC** — Approval times out after 2h. Stage marked skipped. Build "succeeds" overall (apply skip is non-failure). State drift uncorrected. Pod still crashlooping.
6. **2026-04-26 (today)** — Probes confirm: IaC at main still has the entry; runtime CG + container still missing; the issue is unchanged since 2026-04-21 (modulo the R145 pod still serving traffic).

## Implication for the user's request

The user prepared a worktree branch `fix/NOTICKET/mfrr-activation-crashloop` expecting to commit a tfvars hunk. **There is no tfvars hunk to commit.** `git diff origin/main HEAD` is empty. The IaC is already correct.

The two real fix paths are:

- **Path P (operational, no IaC commit)** — Trigger pipeline 1413 against main; an authorized approver clicks "Approve" on the apply gate within 2 hours; apply runs, creating the CG + blob container; activationmfrr pod restarts cleanly.
- **Path D (defensive IaC commit)** — Modify `.azuredevops/pipelines/terraform-cd-sandbox.pipeline.yaml` to add a `trigger:` block (auto-run on merge to main with paths watching `configuration/terraform/sandbox/**`, `terraform/sandbox/**`, `terraform/fbe/**`). Optionally extend approval timeout. This *prevents the class* of "merged-but-never-applied" regression.

These are not exclusive — Path D should ride on top of Path P as a follow-up commit, and the user explicitly has a worktree open for an IaC commit.

---

# Phase 8 cross-check — live re-verification (post-Phase-5 dispatch)

User granted kubectl + az broader access. Re-probed every claim I had inherited from the prior diagnosis to ensure coherence between my fix (Path D yaml change) and reality on Azure.

## Live findings (this session, 2026-04-26 ~16:10 UTC)

| # | Claim | Live evidence | Classification |
|---|---|---|---|
| L1 | Sandbox sub `7b1ba02e-bac6-4c45-83a0-7f0d3104922e` resolved to "Eneco Cloud Foundation - Sandbox-Development-Test"; RG `rg-vpp-app-sb-401` healthy, location westeurope | `az account show`, `az group show -n rg-vpp-app-sb-401` | A1 FACT |
| L2 | Pod `activationmfrr-6778566c5f-t2n2w` (R145 image `0.145.dev.fe1f3fa`) — Running 1/1, 17 d, 0 restarts. Still serving. | `kubectl -n vpp get pods` | A1 FACT |
| L3 | Pod `activationmfrr-6dff6b5766-65hc9` (R147 image `0.147.dev.d15a425`) — CrashLoopBackOff, 990 restarts, 3d7h age, exit 139 (Error). NEW ReplicaSet (`6dff6b5766`) compared to the prior diagnosis's `744ddb586c-9rwnd` — the dispatching helm has rolled at least one R147 patch since 2026-04-21 but the failure mode is unchanged. | `kubectl -n vpp get pod ... -o jsonpath='...lastState'` | A1 FACT |
| L4 | Today's pod log shows BOTH co-occurring failures: `Azure.RequestFailedException: ContainerNotFound … x-ms-error-code: ContainerNotFound` (blob side, from `PartitionLoadBalancer.RunLoadBalancingAsync`) AND `EventHubsException: The messaging entity 'vpp-evh-premium-sbx:eventhub:dispatcher-output-1~<partition>\|activation-mfrr' could not be found` (AMQP side, from `AmqpConsumer.ReceiveAsync`). The prior diagnosis cited only the blob side; reality is both fail from the same root cause (missing CG ⇒ AMQP ResourceNotFound; missing container ⇒ blob ContainerNotFound). Either resource being created independently would NOT heal the pod — both must exist. | `kubectl -n vpp logs … --previous` | A1 FACT |
| L5 | Source code in `Eneco.Vpp.Core.Dispatching/src/Activation/mFRR/Activation.mFRR.Api/appsettings.Local.json` defines a single `ActivationResponse` consumer (`EventHub: activation-response-output-1`, `Container: activation-response-output-1-activation-mfrr`). No `DispatcherOutput` consumer in local appsettings. The R147 image's *runtime* configuration of a second consumer (`DispatcherOutput`) must come from environment-specific App Config keys, not from compiled-in defaults. | Direct file read | A1 FACT (about local config); A3 INFER (about runtime App Config — see L6) |
| L6 | Live re-probe of App Config `vpp-appconfig-d` data plane is `[UNVERIFIED[blocked]]` — `az appconfig kv list --endpoint <url> --auth-mode login` failed with a SDK auth-traceback (likely RBAC at the data plane scope; current Entra principal lacks `App Configuration Data Reader`). The prior diagnosis claimed the App Config has `EventHubOptions:ConsumerOptions:DispatcherOutput:{EHName=dispatcher-output-1, CG=activation-mfrr, ContainerName=dispatcher-output-1-activation-mfrr}`. I cannot independently re-confirm this today; downgrade the inherited claim to A2 INFER based on the prior probe. | `az appconfig kv list` data-plane error; reasoning chain as above | A3 UNVERIFIED[blocked] |

## Coherence with the proposed fix

The fix (Path D — add `trigger:` + `pr: none` to `terraform-cd-sandbox.pipeline.yaml`) is unaffected by the L4 / L6 refinements:

- **L4 (two co-occurring SDK errors)**: Both errors disappear only when both Azure resources (CG + blob container) exist. The IaC at HEAD declares both via the FBE-pattern paired modules in `terraform/sandbox/event-hub.premium.tf`. A successful Apply creates both atomically (within one terraform run, sequential resource creation). Path D ensures that Apply runs.
- **L6 (App Config provenance unverified)**: The fix is correct iff the IaC's expected resources are missing on Azure (which L1-L4 confirm: CG missing AND container missing). The provenance of the App Config keys that drive the SDK to look for those resources is upstream context, not an input to the fix. Even if the App Config keys were managed somewhere unexpected, the Sandbox runtime needs the IaC-declared resources to match.

## Updates absorbed into deliverables

The `explanation-of-fix-and-issue-holistic.md` file mentions only `ContainerNotFound`; it should be amended (or RCA can be the canonical place) to record both co-occurring SDK exceptions. PR description and Slack response are unaffected — they describe the *runtime drift* and *fix mechanism*, not the SDK exception trace.
