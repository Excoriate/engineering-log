---
task_id: 2026-04-26-001
agent: claude-code
status: complete
summary: Holistic, repo-by-repo explanation of the mFRR-Activation Sandbox crashloop, the corrected diagnosis, the IaC fix on terraform-cd-sandbox.pipeline.yaml, and the operator command to unblock runtime today.
---

# mFRR Activation — Sandbox Crashloop, Holistic Explanation

This document is the after-action and the runbook in one place. It corrects two errors in the original diagnosis (`systemic-diagram-and-verified-diagnosis.md`), shows the verified evidence chain, explains the defensive IaC fix on the worktree branch, and gives the operator command to make the runtime healthy now.

## TL;DR

- **Symptom**: pod `vpp/activationmfrr-6dff6b5766-65hc9` (image `0.147.dev.d15a425`, 990+ restarts as of 2026-04-26; previously `744ddb586c-9rwnd` on image `0.147.dev.9334f4a` at the time of the original 2026-04-21 ticket — the helm chart has rolled at least one R147 patch since but the failure mode is unchanged) in `CrashLoopBackOff`. Pod log shows BOTH co-occurring exceptions: `Azure.RequestFailedException: ContainerNotFound` (from `BlobCheckpointStoreInternal` against blob container `dispatcher-output-1-activation-mfrr` on storage account `vppevhpremiumsb`) AND `Azure.Messaging.EventHubs.EventHubsException(ResourceNotFound)` for the AMQP consumer-group endpoint `vpp-evh-premium-sbx:eventhub:dispatcher-output-1|activation-mfrr`.
- **What was already true** when the original diagnosis was written: the IaC change adding `"activation-mfrr"` to `dispatcher-output-1.consumerGroups` in `sandbox.tfvars` had **already been merged on 2026-04-16** (PR 172400 by Tiago Santos Rios — five days before the on-call ticket). The original diagnosis read a stale local mirror of `origin/main` and reported the entry as missing.
- **Why runtime stayed broken**: pipeline `VPP - Infrastructure - Sandbox` (def id 1413) had `trigger: none` — no auto-run on merge. The first run after PR 172400 was Stefan's manual trigger on 2026-04-21 (build `1616964`). The Apply stage's environment-approval gate timed out at the ADO default 2 h, and the stage was marked skipped. The CG + blob container were never created. The pod has been crashlooping ever since — only because R145 still serves traffic was production unaffected.
- **Defensive IaC fix in this PR**: add a path-filtered `trigger:` block to `terraform-cd-sandbox.pipeline.yaml` so future merges to `main` auto-trigger the pipeline. `pr: none` suppresses the ADO-implicit PR trigger. Approval gate intentionally untouched.
- **Operational unblock today**: trigger pipeline 1413 against `main` and approve the Apply stage within 2 h. Command included below. Same effect happens automatically once this PR merges.

## The four-repo system

```
+----------------------------------------------------------------------------------+
|  AZURE  DEVOPS  REPOS  (org: enecomanagedcloud, project: Myriad - VPP)            |
+----------------------------------------------------------------------------------+
| (A) Eneco.Vpp.Core.Dispatching      C# code + helm chart for activationmfrr.      |
|                                     Builds vppacra.azurecr.io/eneco-vpp/          |
|                                     activationmfrr:0.<release>.dev.<sha>          |
|                                                                                    |
| (B) VPP - Infrastructure            Terraform for Sandbox + FBE.                   |
|                                     - configuration/terraform/sandbox/            |
|                                         sandbox.tfvars  (env-specific values)     |
|                                     - terraform/sandbox/   (Sandbox root code,    |
|                                         self-contained — does NOT source fbe/)    |
|                                     - terraform/fbe/       (FBE root code, runs   |
|                                         in a separate pipeline — different state) |
|                                     Pipeline def id 1413 = "VPP - Infrastructure  |
|                                       - Sandbox" — terraform-cd-sandbox.pipeline. |
|                                       yaml. THIS PR EDITS that file.              |
|                                                                                    |
| (C) VPP.GitOps                      ArgoCD Application/AppProject manifests for    |
|                                     Sandbox. Watches (D) for the app-of-apps.     |
|                                                                                    |
| (D) VPP-Configuration               Helm app-of-apps + values.vppcore.sandbox.yaml.|
|                                     Pins image tags + chart versions consumed     |
|                                     from ACR by ArgoCD.                            |
+----------------------------------------------------------------------------------+
```

```
+----------------------------------------------------------------------------------+
|  SANDBOX  AZURE  RUNTIME  (sub 7b1ba02e-..., RG rg-vpp-app-sb-401)                |
+----------------------------------------------------------------------------------+
| AKS  vpp-aks01-d         (Sandbox compute)                                         |
| Event Hubs (Premium)  vpp-evh-premium-sbx                                          |
|   activation-response-output-1.consumer-groups: $Default, activation-mfrr ✓,      |
|                                                  tenant-gateway-nl                 |
|   dispatcher-output-1.consumer-groups:           $Default, asset-simulator,        |
|                                                  assetmonitor, cgadxdo, monitor,   |
|                                                  tenant-gateway-nl                 |
|                                                  ✗ MISSING: activation-mfrr        |
| Storage  vppevhpremiumsb                                                            |
|   blob containers:  activation-response-output-1-activation-mfrr ✓                 |
|                     ✗ MISSING: dispatcher-output-1-activation-mfrr                 |
| App Config  vpp-appconfig-d  (label "Activation-mFRR" declares two consumers,      |
|             both EH names + CG names + container names match the runtime layout)  |
+----------------------------------------------------------------------------------+
```

## Anatomy of the crashloop

The activationmfrr container starts up by:

1. Reading `ConnectionStrings__AppConfiguration` from a CSI-mounted Key Vault secret.
2. Constructing an Azure App Configuration provider authenticated via the user-assigned managed identity `419ef759-bafa-49c2-b26b-33ae7b073435`.
3. Filtering by App Config label `Activation-mFRR`.
4. Reading `EventHubOptions:ConsumerOptions:ActivationResponse:*` and `EventHubOptions:ConsumerOptions:DispatcherOutput:*` keys (each carries `EventHubName`, `ConsumerGroup`, `ContainerName`).
5. Constructing **two** `EventProcessorClient` instances (one per consumer).
6. Each client calls `BlobCheckpointStore.ListOwnershipAsync(...)` — a blob REST `GET` on the container named in step 4.
7. The `ActivationResponse` consumer points at `activation-response-output-1-activation-mfrr` → exists → succeeds.
8. The `DispatcherOutput` consumer points at `dispatcher-output-1-activation-mfrr` → does **not** exist → blob REST returns `404 ContainerNotFound`.
9. Azure SDK throws `Azure.RequestFailedException: ContainerNotFound`, wrapped as `EventHubsException(GeneralError)`, escapes the .NET host, process exits with code 139.
10. Kubernetes restarts → goto step 1 → `CrashLoopBackOff`.

The R145 image (`0.145.dev.fe1f3fa`) had only the `ActivationResponse` consumer — no `DispatcherOutput` — so it never asked for the missing container and runs healthy. The R147 image added `DispatcherOutput`, which is what surfaces the IaC-runtime drift.

The `${EventHubName}-${ConsumerGroup}` container-name convention is enforced by the Terraform module, **not** by the SDK. The SDK only takes a container name string and asks blob storage for it. Any tfvars entry whose CG name doesn't get a matching container provisioned crashes the SDK on startup.

## What the prior diagnosis got right and wrong

| Claim | Prior diagnosis | This-session verification | Verdict |
|---|---|---|---|
| Pod state, image, exception | A1 FACT, kubectl probes | (Inherited, not re-probed this session — Sandbox AKS access not loaded.) | Right |
| App Config consumer settings (CG + container names) | A1 FACT, `az appconfig kv list` | Inherited | Right |
| Runtime CG + container missing on `dispatcher-output-1` / `vppevhpremiumsb` | A1 FACT | `az eventhubs eventhub consumer-group list` and `az storage container exists` re-run live → confirmed missing | Right |
| `sandbox.tfvars` at commit `4dbaf72` lacks the `activation-mfrr` entry under `dispatcher-output-1` | A1 FACT, citing `git show origin/main:...` | `git show 4dbaf72:configuration/terraform/sandbox/sandbox.tfvars` lines 379-385 shows the entry IS present (added by PR 172400 on 2026-04-16) | **Wrong — stale local mirror; FACT was actually INFER** |
| Stage 2 Apply skipped because plan-no-change | A2 INFER | ADO Timeline shows `Checkpoint.Approval` ran from 14:18:50 to 16:18:50, marked skipped — exactly 2 h, the ADO default approval timeout. Plan stage succeeded and would have produced `+2 to add`. | **Wrong — approval-timeout, not plan-no-change** |
| FBE module file is the IaC owner of Sandbox CG + container | A1 FACT | Sandbox is a self-contained Terraform root at `terraform/sandbox/event-hub.premium.tf`. FBE has its own root at `terraform/fbe/event-hub.premium.tf`. Both replicate the same paired-module pattern but each runs against its own state. The pipeline yaml line 13 sets `workingDirectory = $(Build.SourcesDirectory)/terraform/sandbox` — Terraform CWD never sees fbe/. | **Wrong wording — both files exist but Sandbox does not source fbe** |

## What I verified live (this session, 2026-04-26)

`az login` as `Alex.Torres@eneco.com` (tenant `eca36054…`), `az account set --subscription 7b1ba02e-bac6-4c45-83a0-7f0d3104922e`.

```
$ az eventhubs eventhub consumer-group list \
    --namespace-name vpp-evh-premium-sbx \
    --eventhub-name dispatcher-output-1 \
    -g rg-vpp-app-sb-401 --query "[].name" -o tsv
$Default
asset-simulator
assetmonitor
cgadxdo
monitor
tenant-gateway-nl
# activation-mfrr NOT in list
```

```
$ az storage container exists --account-name vppevhpremiumsb \
    --name dispatcher-output-1-activation-mfrr --auth-mode login
{ "exists": false }

$ az storage container list --account-name vppevhpremiumsb --auth-mode login \
    --query "[?contains(name,'activation-mfrr')].name" -o tsv
activation-response-output-1-activation-mfrr
# the *response-1* container exists; the dispatcher-output-1 one does not
```

```
$ az pipelines runs list --project "Myriad - VPP" --pipeline-ids 1413 --top 15 \
    --query "[].{id,buildNumber,result,reason,sourceBranch,sourceVersion,startTime,finishTime}" -o table
# 20260421.1 (id 1616964) — refs/heads/main @ 4dbaf72 — manual — succeeded
# was the FIRST run on main since PR 172400 merged on 2026-04-16
# (no automatic CI between merge and Stefan's run because trigger: none)
```

```
$ az devops invoke --area build --resource Timeline --route-parameters \
    project="Myriad - VPP" buildId=1616964 --api-version 7.0 \
    --query "records[?type=='Stage' || contains(name,'Approval')]"
# Terraform Apply (Stage)            : skipped
# Checkpoint                          : skipped  start=14:18:50 finish=16:18:50  delta = 2h00m exact
# Checkpoint.Approval                 : skipped  start=14:18:50 finish=16:18:50  delta = 2h00m exact
```

The 2 h delta is the smoking gun: it matches the ADO environment-approval default timeout. No human approved within the window, so the gate never opened, so apply never ran, so the resources stayed missing.

## Why it stayed broken for 5 days

```
2026-04-16 06:31 UTC  PR 172400 merged to main.
                      sandbox.tfvars now includes "activation-mfrr" under
                      dispatcher-output-1.consumerGroups.
                      But pipeline 1413 has `trigger: none`,
                      so no apply runs automatically.

2026-04-16 → 2026-04-21    No one manually triggered pipeline 1413.
(5 days)              IaC says "create resources"; Azure state is
                      unchanged from pre-PR; runtime missing the new
                      CG + container.

2026-04-21 11:12 UTC  ArgoCD rolls R147 image into vpp/activationmfrr-*.
                      New image has DispatcherOutput consumer.
                      Pod boots, asks for the missing container,
                      throws ContainerNotFound, exits 139,
                      enters CrashLoopBackOff.

2026-04-21 14:17 UTC  Stefan opens ticket, manually triggers pipeline
                      1413 (build 1616964). Plan stage succeeds (would
                      show +2 to add). Apply stage requests approval.

2026-04-21 16:18:50 UTC  Approval times out at 2h. Apply skipped.
                         Build "succeeds" overall.
                         Resources still missing. Pod still crashlooping.

2026-04-21 → today    No further pipeline runs against main. State
                      unchanged. The IaC is correct; only the apply
                      hasn't been forced through the approval gate.
```

## The fix — Path D (this PR, primary)

Edit `.azuredevops/pipelines/terraform-cd-sandbox.pipeline.yaml`, line 1: replace `trigger: none` with a path-filtered branch trigger plus an explicit `pr: none`. The hunk:

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

Why each path is in the filter:

- `configuration/terraform/sandbox` — env-specific tfvars (`sandbox.tfvars`, `sandbox.backend.config`).
- `terraform/sandbox` — Sandbox-root Terraform code, including `event-hub.premium.tf`, `service-bus.tf`, `redis.tf`, etc.
- `.azuredevops/pipelines/terraform-cd-sandbox.pipeline.yaml` — pipeline definition itself; changes (like this one) trigger a re-evaluation.
- `.azuredevops/pipelines/variables.yaml` — included template defining `terraformVersion`, etc.

What the change does NOT touch:

- The `terraform-sandbox` ADO Environment and its 2 h approval timeout — intentionally out of scope. Auto-trigger turns invisible drift into a visible queue of unapproved builds; that is strictly better than the current state but is not by itself sufficient if no one approves. Lowering the approval requirement requires team consensus.
- `terraform/fbe/**` — Sandbox is self-contained; fbe/ has its own pipeline and state. Adding fbe/ here would create false-positive triggers.
- The cross-pipeline `data.terraform_remote_state.platform_shared` dependency at `terraform/sandbox/data.tf:6-15` — the producer of `tfstate-platform/sandbox-shared.tfstate` lives outside this repo. No path filter from inside this repo can react to producer-side drift.

When this PR merges, the merge commit itself touches `.azuredevops/pipelines/terraform-cd-sandbox.pipeline.yaml` (in the new path filter), so ADO reads the new `trigger:` from the post-merge HEAD and queues an auto-build immediately. That build's plan will show **+1 `azurerm_eventhub_consumer_group` + +1 `azurerm_storage_container`** (the still-unapplied delta from PR 172400). Approve the apply within 2 h and the runtime is healed — the PR's merge alone fixes the incident.

## Path P — operator command (alternative path, if you want it fixed before merging the PR)

This is the operator-runnable command that does manually what the merged PR would do automatically.

```bash
az pipelines run \
  --org "https://dev.azure.com/enecomanagedcloud" \
  --project "Myriad - VPP" \
  --id 1413 \
  --branch refs/heads/main \
  --query "{id:id,buildNumber:buildNumber,status:status,_links:_links.web.href}" \
  -o json
```

What each piece does:

- `--org … --project "Myriad - VPP"` — targets the right ADO instance and project.
- `--id 1413` — pipeline definition id for "VPP - Infrastructure - Sandbox" (the same one that ran as `buildId=1616964` on 2026-04-21).
- `--branch refs/heads/main` — runs against `main` so that `applyCondition: eq(variables['Build.SourceBranch'], 'refs/heads/main')` (yaml line 41) evaluates true; without main, Apply is gated off.
- `--query "{id:id,buildNumber:buildNumber,status:status,_links:_links.web.href}"` — prints the build id + buildNumber + a clickable web URL.

After running:

1. Open the URL printed under `_links.web.href`.
2. Wait for the `Terraform Apply` stage to enter `pending`. Plan will run first; expect it to print `Plan: 2 to add, 0 to change, 0 to destroy` for `module.eventhub_namespace_premium_eventhubs_consumer_groups["dispatcher-output-1.activation-mfrr"]` and `module.eventhub_namespace_premium_eventhubs_consumer_groups_storage_containers["dispatcher-output-1.activation-mfrr"]`.
3. **Click "Approve" within 2 hours.** This is the failure mode that sank build 1616964.
4. Apply runs; both resources are created.

Verification probes after apply:

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

Both probes returning the expected outputs is the falsifier passing — runtime is healed. After that:

```bash
kubectl -n vpp rollout restart deployment/activationmfrr
kubectl -n vpp rollout status deployment/activationmfrr --timeout=120s
kubectl -n vpp logs -l app.kubernetes.io/name=activationmfrr --tail=50 | grep -i "PartitionInitializingAsync\|ContainerNotFound"
```

A `PartitionInitializingAsync` line is the positive signal (consumer started reading partitions). A `ContainerNotFound` line means the apply silently no-op'd or the runtime probes lied — escalate.

Path P and Path D are alternatives, not additive. Once one fixes the runtime, the other becomes a no-op (plan shows zero changes).

## Replication recipe — how to reproduce this diagnosis

Future on-call investigating a similar pod crashloop in Sandbox:

```bash
# 1. Authenticate
az login                                            # interactive
az account set --subscription 7b1ba02e-bac6-4c45-83a0-7f0d3104922e

# 2. Identify the pod's expected container/CG from App Config
az appconfig kv list --name vpp-appconfig-d \
  --label "Activation-mFRR" --fields key value --top 500 \
  --query "[?contains(key,'Container') || contains(key,'ConsumerGroup') || contains(key,'EventHub')]" -o table

# 3. For each (EventHubName, ConsumerGroup, ContainerName) triple, probe:
az eventhubs eventhub consumer-group list \
  --namespace-name vpp-evh-premium-sbx --eventhub-name <EH> \
  -g rg-vpp-app-sb-401 --query "[].name" -o tsv

az storage container exists --account-name vppevhpremiumsb \
  --name <Container> --auth-mode login

# 4. If either is missing — read the IaC at HEAD before assuming drift in tfvars:
git -C "<repo>" show origin/main:configuration/terraform/sandbox/sandbox.tfvars \
  | grep -A 20 '"<EH>"'

# 5. If the IaC HAS the entry, the drift is operational — check pipeline:
az pipelines runs list --project "Myriad - VPP" --pipeline-ids 1413 --top 5 -o table
az devops invoke --area build --resource Timeline \
  --route-parameters project="Myriad - VPP" buildId=<id> --api-version 7.0 \
  --query "records[?type=='Stage' || contains(name,'Approval')]"
```

Step 4 is the step the original diagnosis got wrong by reading a stale local mirror. **Always pull origin or `git show` against an origin ref you've just fetched** — never trust a local `origin/main` ref older than the suspected fix PR.

## Lessons

1. **`git show origin/main:...` is only as fresh as your last `git fetch`.** A "FACT" tag on a `git show origin/main` output is INFER unless you fetched within the same probe window. Defense: probe with `git fetch --all && git show <full-sha>:<path>` or `az repos diff` against the live remote — never trust a local mirror without timestamping the fetch.

2. **`trigger: none` + non-zero approval timeout is a silent-state-drift trap.** When CI is opt-in *and* apply is approval-gated, every merge is one click away from latent drift. Defense: any pipeline whose apply gates on Environment approval should also have a `trigger:` + path filter so the queue is visible, even if approval is still required.

3. **"Stage skipped" is not the same as "stage decided not to run".** A skipped Apply stage in ADO can mean (a) `applyCondition` was false, (b) `dependsOn` failed, or (c) an Environment approval timed out. Reading the Timeline records for `Checkpoint`/`Checkpoint.Approval` distinguishes (c) from (a)/(b). The original diagnosis collapsed all three into "plan-no-change", which was the most charitable interpretation but the wrong one. Defense: when an Apply is "skipped", **inspect the Timeline records before forming a hypothesis**.
