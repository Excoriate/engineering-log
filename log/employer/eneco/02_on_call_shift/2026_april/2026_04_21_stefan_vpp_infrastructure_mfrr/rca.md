---
task_id: 2026-04-26-001
agent: claude-code
status: complete
summary: Final cross-checked Root Cause Analysis for the mFRR Activation Sandbox crashloop, with multi-level diagrams connecting business intent to IaC contract to pipeline behavior to runtime exception trace; fix is coherent with the verified diagnosis.
---

# RCA — mFRR Activation Sandbox CrashLoopBackOff

This is the canonical, evidence-backed RCA for the on-call ticket of 2026-04-21 (Stefan's report) as understood after a full re-verification on 2026-04-26 with `az` + `kubectl` access. It supersedes the earlier `systemic-diagram-and-verified-diagnosis.md` on two specific claims (called out below) and confirms everything else.

Every load-bearing claim is classified `A1 FACT | A2 INFER | A3 UNVERIFIED[reason]`. No claim is presented at higher confidence than its evidence supports.

## Levels at a glance

| Level | Question it answers |
|---|---|
| L1. Business | What does mFRR Activation do, why does it matter? |
| L2. Repo system | Which four repos are in play, what do they own? |
| L3. Azure runtime | Which Azure resources are involved, what is the topology? |
| L4. Application startup | What does the activationmfrr container do at boot? |
| L5. IaC contract | How does tfvars produce the missing resources? |
| L6. Pipeline behavior | How does a tfvars change reach Azure (or fail to)? |
| L7. Timeline | What happened, on what dates? |
| L8. Fix | What changes, why, and what doesn't change. |
| L9. Verification | How do we know the fix works? |
| L10. Lessons | What patterns to keep around. |

---

## L1 — Business / Functional

```
   TenneT (Dutch TSO)                         Eneco BSP (us)
        │                                         ▲
        │ Energy bid activation request           │
        │ (mFRR — Manual Frequency Restoration    │
        │  Reserve, full activation 12.5 min)     │
        ▼                                         │
   ┌────────────────┐    ┌──────────────────┐    │
   │ Activation.mFRR│ →  │ Dispatcher.mFRR  │ → asset setpoints
   │ (L4 ingress,   │    │ (L3 OT, airgapped)│
   │  public REST)  │    └──────────────────┘
   └────────────────┘
        │
        │ also CONSUMES dispatcher-output-1
        │ (since R147 — for availability monitoring
        │  of the mFRR dispatcher itself, per
        │  TenneT BSP-availability requirement,
        │  PR 172400 commit message)
```

mFRR is a balancing service the Dutch TSO uses to restore grid frequency after a deviation. Eneco participates as a Balancing Service Provider (BSP). The `Activation.mFRR` service is the **public ingress** to the BSP; it accepts activation/deactivation commands from TenneT, publishes them onto an internal Event Hub, and (since R147) also **subscribes** to the dispatcher's output topic so it can monitor whether the dispatching pipeline is alive — TenneT requires the BSP to expose monitoring endpoints proving readiness.

The R147 image (rolled to Sandbox starting 2026-04-21) was the first version of the service that actually consumed `dispatcher-output-1`. R145 (still running healthy) does not. This is why the failure surfaced now and not on 2026-04-16 when the IaC change merged.

Source for the *why R147 consumes dispatcher-output-1*: `git show 4dbaf72` PR-172400 commit body says verbatim: *"For mFRR energy bids, TenneT wants to monitor the availability of the BSP. … Therefore, the Activation.mFRR service needs to start consuming the output from that topic. In this pull request, I made activation-mfrr as a consumer of the dispatcher-output-1 topic - more specifically in the Sandbox and FBE environments."* — A1 FACT.

---

## L2 — Repo system

```
                ┌────────────────────────────────────────────────────────────────┐
                │ Azure DevOps org: enecomanagedcloud   project: Myriad - VPP    │
                └────────────────────────────────────────────────────────────────┘

  (A) Eneco.Vpp.Core.Dispatching       (B) VPP - Infrastructure          (C) VPP.GitOps
  ─────────────────────────────────    ────────────────────────────      ──────────────────────
  C# code + Helm chart for             Terraform for Sandbox + FBE.      ArgoCD configuration:
   activationmfrr (and other            Pipeline 1413 = "VPP -            Application + AppProject
   dispatching services).               Infrastructure - Sandbox"         manifests; sandbox
  Builds:                               (file: terraform-cd-sandbox.      overlay points ArgoCD
   vppacra.azurecr.io/eneco-vpp/         pipeline.yaml).                   at repo (D).
   activationmfrr:0.<rel>.dev.<sha>     Two Terraform roots:
                                          - terraform/sandbox/   ← THIS
                                          - terraform/fbe/        runs in
                                                                  separate
                                                                  pipeline
                                       env-specific values:
                                        configuration/terraform/sandbox/
                                          sandbox.tfvars

                                       (D) VPP-Configuration
                                       ────────────────────────
                                       Helm app-of-apps; values.
                                       vppcore.sandbox.yaml pins
                                       image tags + chart versions.

  Outputs container image  ──→      ──→   ArgoCD reads (D), pulls helm
  to ACR.                                  chart from ACR, deploys to AKS.

                                       Pipeline 1413  ──→ apply terraform → CG, blob container,
                                                                              all other Sandbox res.
```

Only **(B) `VPP - Infrastructure`** is touched by the fix. The pipeline yaml change at `(B)/.azuredevops/pipelines/terraform-cd-sandbox.pipeline.yaml`. (A), (C), (D) are unchanged.

Crucial property of (B) — A1 FACT, verified by reading the relevant `.tf` files:

- `terraform/sandbox/event-hub.premium.tf` is **self-contained** for the Sandbox Terraform root. It declares its own `module "eventhub_namespace_premium_eventhubs_consumer_groups"` AND `module "eventhub_namespace_premium_eventhubs_consumer_groups_storage_containers"` (lines 70–96), each `for_each` over `local.eventhub_premium_attributes`. The blob container's `name` is computed as `"${eventhub_name}-${consumer_group_name}"` (line 91).
- `terraform/fbe/event-hub.premium.tf` declares the same pair of modules for the FBE root. It runs in a separate pipeline against separate state.
- `terraform/sandbox/locals.tf` flattens `var.eventhub_premium_attributes` (declared in `variables.tf`, populated from `configuration/terraform/sandbox/sandbox.tfvars`) into `local.eventhub_premium_attributes`.

So one entry under `eventhub_premium_attributes."<EH>".consumerGroups."<CG>"` in `sandbox.tfvars` produces, on Apply, **two Azure resources**: one consumer group on the Event Hub and one blob container on the storage account. The naming convention `"${EH}-${CG}"` is enforced by the Terraform module — not by the SDK. (The SDK only takes whatever container name the application config passes in, and asks blob storage for it.)

Cross-pipeline residual not closeable from (B): `terraform/sandbox/data.tf:6-15` reads `data.terraform_remote_state.platform_shared` from `tfstate-platform/sandbox-shared.tfstate`. The producer of that state lives outside (B). Not related to the current incident, but recorded so a future RCA reading this isn't surprised. — A1 FACT.

---

## L3 — Azure runtime

```
 ┌─────────────────────────────────────────────────────────────────────────────────┐
 │  Subscription 7b1ba02e-bac6-4c45-83a0-7f0d3104922e  (Sandbox-Development-Test)  │
 │  Resource Group rg-vpp-app-sb-401                                               │
 └─────────────────────────────────────────────────────────────────────────────────┘
                                  │
                       ┌──────────┴───────────┬───────────────────────┐
                       ▼                      ▼                       ▼
   AKS  vpp-aks01-d         Event Hub Premium NS         Storage account
   (Sandbox compute)        vpp-evh-premium-sbx          vppevhpremiumsb
                                                          (BlobCheckpointStore)
   ns "vpp"                 ┌─ activation-response-       ├─ activation-response-
   Deployment                │    output-1                │    output-1-
   activationmfrr             │   CGs: $Default,          │    activation-mfrr  ✓
   replicas: 1                │        activation-mfrr ✓, ├─ … other containers
                              │        tenant-gateway-nl  │
                              ├─ dispatcher-output-1      ╳ dispatcher-output-1-
                              │   CGs: $Default,          │    activation-mfrr  MISSING
                              │        asset-simulator,   │    ↑
                              │        assetmonitor,      │    The container the R147 SDK
                              │        cgadxdo, monitor,  │    asks for at startup.
                              │        tenant-gateway-nl  │
                              │  ╳    activation-mfrr  MISSING
                              │
                              └─ … other event hubs
```

**Live runtime probes (this session, A1 FACT):**

```
$ az eventhubs eventhub consumer-group list \
    --namespace-name vpp-evh-premium-sbx --eventhub-name dispatcher-output-1 \
    -g rg-vpp-app-sb-401 --query "[].name" -o tsv
$Default · asset-simulator · assetmonitor · cgadxdo · monitor · tenant-gateway-nl
# activation-mfrr NOT in list

$ az storage container exists --account-name vppevhpremiumsb \
    --name dispatcher-output-1-activation-mfrr --auth-mode login
{ "exists": false }

$ az storage container list --account-name vppevhpremiumsb --auth-mode login \
    --query "[?contains(name,'activation-mfrr')].name" -o tsv
activation-response-output-1-activation-mfrr
# the response-1 sibling DOES exist; the dispatcher-output-1 one does not
```

**Pod state today (live, A1 FACT):**

```
$ kubectl -n vpp get pods -l app.kubernetes.io/name=activationmfrr
NAME                              READY   STATUS             RESTARTS   AGE
activationmfrr-6778566c5f-t2n2w   1/1     Running            0          17d   ← R145, healthy, still serving
activationmfrr-6dff6b5766-65hc9   0/1     CrashLoopBackOff   990 (4m)   3d7h  ← R147 (image 0.147.dev.d15a425),
                                                                              exit 139 every ~14s
```

R145 has been carrying load for 17 days; that's the only reason this is a P3/P4 sandbox issue rather than a production outage. (Note the *new* ReplicaSet `6dff6b5766` — a different one than the prior diagnosis cited; the R147 helm chart has rolled at least one patch since 2026-04-21, but the failure mode is unchanged because the underlying IaC is still un-applied.)

---

## L4 — Application startup behavior

```
Pod activationmfrr boots
        │
        ▼
 1. Read env ConnectionStrings__AppConfiguration  (CSI from Key Vault)
 2. Construct Azure App Configuration provider, auth via UAMI 419ef759-…
 3. Filter by App Config label "Activation-mFRR"
 4. Read EventHubOptions:ConsumerOptions:* keys → for R147, two consumers:
       ActivationResponse  → {EH=activation-response-output-1,
                              CG=activation-mfrr,
                              Container=activation-response-output-1-activation-mfrr}  ← SDK probes this:  OK
       DispatcherOutput    → {EH=dispatcher-output-1,
                              CG=activation-mfrr,
                              Container=dispatcher-output-1-activation-mfrr}            ← SDK probes this:  FAIL
 5. For each consumer, construct an EventProcessorClient
 6. EventProcessorClient runs two concurrent partition-load-balancing tasks; each
    can independently throw if its precondition is unmet:
       (a) BlobCheckpointStore path (PartitionLoadBalancer.RunLoadBalancingAsync →
           BlobCheckpointStoreInternal.GetCheckpointAsync / ListOwnershipAsync)
            → BlobCheckpointStoreInternal.GetCheckpointAsync / ListOwnershipAsync
            → blob REST GET on container <Container>
            → 404 ContainerNotFound  (today, live log)
       (b) ValidateEventHubsConnectionAsync
            → AmqpConnectionScope.OpenConsumerLinkAsync(<CG>)
            → AMQP open against EH <EH>, CG <CG>
            → ResourceNotFound: 'vpp-evh-premium-sbx:eventhub:dispatcher-output-1~<part>|activation-mfrr'
              could not be found (today, live log)
 7. Either failure rethrows up to PartitionLoadBalancer.RunLoadBalancingAsync
    → EventProcessor.StartProcessingAsync
    → Eneco.Vpp.Messaging.EventHub.Consumers.EventHubConsumer.StartAsync
    → IHostedService throws → Host.StartAsync → process exit 139
 8. K8s sees exit 139 (Error, not OOMKilled) → restarts pod → goto step 1
                                                              (CrashLoopBackOff)
```

**Live exception evidence** (`kubectl -n vpp logs activationmfrr-6dff6b5766-65hc9 --previous`, 2026-04-26):

```
Azure.RequestFailedException: The specified container does not exist.
ErrorCode: ContainerNotFound
   at Azure.Storage.Blobs.Specialized.BlobBaseClient.GetPropertiesInternal(...)
   at Azure.Messaging.EventHubs.Primitives.BlobCheckpointStoreInternal.GetCheckpointAsync(...)
   at Azure.Messaging.EventHubs.EventProcessorClient.GetCheckpointAsync(...)
   at Azure.Messaging.EventHubs.Primitives.PartitionLoadBalancer.RunLoadBalancingAsync(...)

…and concurrently:

Azure.Messaging.EventHubs.EventHubsException(ResourceNotFound): The messaging entity
'vpp-evh-premium-sbx:eventhub:dispatcher-output-1~21844|activation-mfrr' could not be found.
   at Azure.Messaging.EventHubs.Amqp.AmqpConsumer.ReceiveAsync(...)
```

Both errors are present. The prior diagnosis only cited `ContainerNotFound`; reality is **both errors fire, from the same root cause** (CG missing ⇒ AMQP `ResourceNotFound`; container missing ⇒ blob `ContainerNotFound`). Importantly, **either resource being created in isolation would not heal the pod** — both must exist. The Terraform paired modules in `terraform/sandbox/event-hub.premium.tf` create both as one logical unit per declared CG, so a single Apply against the current IaC heals the pod once.

**Refinement vs prior diagnosis:** the prior `systemic-diagram-and-verified-diagnosis.md` §1 ASCII diagram step 8 says *"Second one (Dispatcher-Output) → 404"* and step 9 *"EventHubsException bubbles to host"* — the wording conflates the blob and AMQP errors. The corrected mental model is **two parallel preconditions, both currently failing**, not a single sequential failure. — A1 FACT.

---

## L5 — IaC contract: how tfvars becomes Azure resources

```
configuration/terraform/sandbox/sandbox.tfvars
─────────────────────────────────────────────────────────────────
eventhub_premium_attributes = {
  "dispatcher-output-1" = {
    "consumerGroups" = {
      "cgadxdo"           = { … },
      "monitor"           = { … },
      "assetmonitor"      = { … },
      "tenant-gateway-nl" = { … },
      "asset-simulator"   = { … },
      "activation-mfrr"   = { kusto_evh_connection_enabled = "false", … }   ← line 379-385
                                                                              added by PR 172400
                                                                              on 2026-04-16
    }
  },
  "activation-response-output-1" = { "consumerGroups" = { "activation-mfrr" = { … }, … } },
  …
}

           │   var.eventhub_premium_attributes
           ▼
terraform/sandbox/locals.tf  (flatten)
─────────────────────────────────────────
local.eventhub_premium_attributes = [
  { eventhub_name = "dispatcher-output-1", consumer_group_name = "activation-mfrr",
    kusto_evh_connection_enabled = "false", kusto_db_name = "Monitor", … },
  …
]

           │   for_each over local.eventhub_premium_attributes
           ▼
terraform/sandbox/event-hub.premium.tf
──────────────────────────────────────────
module "eventhub_namespace_premium_eventhubs_consumer_groups"
  → azurerm_eventhub_consumer_group "activation-mfrr"
    on EH dispatcher-output-1                                          ← TARGET ① (currently MISSING on Azure)

module "eventhub_namespace_premium_eventhubs_consumer_groups_storage_containers"
  → azurerm_storage_container "dispatcher-output-1-activation-mfrr"
    on SA vppevhpremiumsb                                              ← TARGET ② (currently MISSING on Azure)
```

Crucial: Terraform produces both targets atomically per declared `(EH, CG)` pair. There's no IaC change needed — the contract already says "create both". The gap is between the contract and Azure runtime, and that gap exists because no Apply has run that includes this contract.

---

## L6 — Pipeline behavior: how (or how not) IaC reaches Azure

### Before this PR (current state of `.azuredevops/pipelines/terraform-cd-sandbox.pipeline.yaml`)

```
Line 1:  trigger: none                ← no auto-CI on merge
Line 41: applyCondition: eq(Build.SourceBranch, 'refs/heads/main')   ← apply only on main
Line 31: azureDevOpsEnvironmentName: terraform-sandbox                 ← Environment with Approval gate

Behavior on merge to main:
   merge → 0 builds queued (trigger:none) → no plan, no apply
   ⇒ silent state drift accumulates until someone manually triggers.

Behavior on manual trigger to main:
   az pipelines run … → Plan succeeds → Apply stage requests Approval
   → Approver has 2h (ADO default Environment approval timeout)
       → approves within 2h:   Apply runs, creates resources.   ✓
       → does NOT approve:     Checkpoint.Approval skipped after 2h,
                               Apply stage marked "skipped",
                               build "succeeds" overall.        ✗  ← exactly what happened
                                                                    on 2026-04-21 build 1616964.
```

**Live evidence — pipeline run history and timeline (A1 FACT):**

```
$ az pipelines runs list --project "Myriad - VPP" --pipeline-ids 1413 --top 15
20260421.1 (id 1616964)  refs/heads/main @ 4dbaf72  manual  succeeded
                          (the FIRST run on main since PR 172400 merged on 2026-04-16)

$ az devops invoke … buildId=1616964
Stage "Terraform Apply" : skipped
  ├─ Checkpoint           : skipped  start=14:18:50  finish=16:18:50  delta = 2h00m exact
  └─ Checkpoint.Approval  : skipped  start=14:18:50  finish=16:18:50  delta = 2h00m exact
```

Two-hour delta is the smoking gun. `Checkpoint.Approval` is the Environment approval; it expires at the ADO default 2 hours. Build "succeeded" because a skipped Apply is non-failure.

### After this PR

```
Line 1-19:  trigger:                   ← auto-CI on merge to main, path-filtered
              batch: true
              branches: include: [main]
              paths:    include:
                          - configuration/terraform/sandbox
                          - terraform/sandbox
                          - .azuredevops/pipelines/terraform-cd-sandbox.pipeline.yaml
                          - .azuredevops/pipelines/variables.yaml
            pr: none                   ← suppress ADO's implicit pr: ['default-branch']
Line 41 unchanged: applyCondition still pinned to main.
Line 31 unchanged: same Environment + same approval gate (2h timeout still in force).

Behavior on merge to main touching any path-filtered file:
   merge → ADO reads new trigger → build queued automatically at post-merge HEAD
   → Plan runs → Apply requests Approval → … (approval mechanics unchanged)

The fix CLOSES the trigger gap. It does NOT change the approval gap.
   - Pre-fix:  silent drift (no build, nothing to approve, nothing to see).
   - Post-fix: visible queue of pending approvals (every relevant merge produces a build).
```

This is strictly better but is **not by itself sufficient** if approvers are unavailable. Lowering the approval requirement or extending the timeout requires team consensus and is intentionally out of scope. — Acknowledged in PR description.

---

## L7 — Timeline (UTC)

```
2026-04-16 06:31  PR 172400 merged to main (commit 4dbaf72).
                   sandbox.tfvars now declares "activation-mfrr" under
                   dispatcher-output-1.consumerGroups (lines 379-385).
                   But pipeline 1413 has trigger:none → NO build queued.

2026-04-16 → 2026-04-21    No manual trigger of pipeline 1413.
(5 days latency)            IaC says "create the resources"; Azure state has
                            not changed since pre-PR. No visibility into the gap.

2026-04-21 11:12  ArgoCD rolls R147 image (0.147.dev.9334f4a, then later .d15a425)
                   into vpp/activationmfrr-*. The image now has a DispatcherOutput
                   consumer that asks for the missing CG + container.
                   Pod throws ContainerNotFound + EventHubsException.
                   K8s restarts. CrashLoopBackOff.

2026-04-21 14:17  Stefan opens ticket #myriad-platform/p1776781493090009.
                   Manually triggers pipeline 1413 against main at 4dbaf72.
                   Build 1616964 starts.

2026-04-21 14:18  Plan stage succeeds (would print "Plan: 2 to add, 0 to change, 0 to destroy").
                   Apply stage requests Environment approval. Checkpoint.Approval starts.

2026-04-21 16:18  Checkpoint.Approval times out (exactly 2h after request).
                   Apply marked "skipped". Build "succeeds" overall.
                   Resources still missing on Azure.

2026-04-21 → 2026-04-26    No further pipeline runs against main. R145 carries traffic.
(5 more days latency)       R147 ReplicaSet rolls at least once (6dff6b5766 today vs
                            744ddb586c on 2026-04-21) but failure mode unchanged.

2026-04-26 (today, this session)
                   Live re-verification: IaC at HEAD has the entry; runtime CG and
                   container still missing; pod still crashlooping at 990 restarts.
                   Two adversarial passes on the proposed fix; YAML edit applied to
                   the worktree branch fix/NOTICKET/mfrr-activation-crashloop.
                   Awaiting operator action (commit/push/PR or run Path P).
```

---

## L8 — Fix

### What the fix changes

`.azuredevops/pipelines/terraform-cd-sandbox.pipeline.yaml`, replace line 1 (`trigger: none`) with:

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

`git diff --stat` after the edit: `1 file changed, 20 insertions(+), 1 deletion(-)`. Lines 2–41 of the original file are byte-identical (verified). — A1 FACT.

### Why this fix is coherent with the verified diagnosis

| Verified-diagnosis claim (live evidence) | How the fix addresses it |
|---|---|
| L3: CG `activation-mfrr` missing on `dispatcher-output-1`; container `dispatcher-output-1-activation-mfrr` missing on `vppevhpremiumsb` | The fix makes the next merge to main auto-trigger Pipeline 1413, whose plan against current IaC will show `+1 azurerm_eventhub_consumer_group + +1 azurerm_storage_container`. On Approve, Apply creates both. |
| L4: pod throws `ContainerNotFound` AND `EventHubsException(ResourceNotFound)` from missing CG + container | Fixed by the same Apply (both resources created atomically per (EH, CG) pair via the paired modules in `terraform/sandbox/event-hub.premium.tf`). |
| L5: IaC at HEAD already declares the (EH, CG) pair → corresponding (CG, container) pair is the implicit output | Fix does not modify IaC contract. It modifies *delivery* of the contract to Azure. |
| L6: pipeline `trigger: none` + 2h approval timeout caused 5+5 days of latent drift | Fix replaces `trigger: none` with path-filtered branch trigger; the gap closes. Approval timeout intentionally untouched (visibility wins). |

### What the fix DOES NOT change

- **Approval gate / 2 h timeout** — out of scope. Visible-queue > silent-drift, but a non-approving operator still defeats the system.
- **Cross-pipeline `sandbox-shared.tfstate`** dependency (`terraform/sandbox/data.tf:6-15`) — producer outside this repo; no path filter from inside this repo can react.
- **`terraform/fbe/**`** — Sandbox is self-contained; including fbe paths would create false-positive triggers.
- **R145 / R147 helm chart selection** — outside (B); ArgoCD reading from (D).
- **Any other Sandbox CD configuration** — `applyCondition`, `azureDevOpsEnvironmentName`, `serviceConnection`, `terraformVersion` — all unchanged.

### Path P — operator command (alternative path; identical end state)

If the operator wants the runtime healed *before* this PR is approved-and-merged:

```bash
az pipelines run \
  --org "https://dev.azure.com/enecomanagedcloud" \
  --project "Myriad - VPP" \
  --id 1413 \
  --branch refs/heads/main \
  --query "{id,buildNumber,status,_links:_links.web.href}" \
  -o json
```

Open the printed URL → wait for "Terraform Apply" → click **Approve within 2 h**.

After Apply succeeds, re-run the L3 probes:

```bash
az eventhubs eventhub consumer-group list \
  --namespace-name vpp-evh-premium-sbx --eventhub-name dispatcher-output-1 \
  -g rg-vpp-app-sb-401 --query "[?name=='activation-mfrr'].name" -o tsv
# expected: activation-mfrr

az storage container exists --account-name vppevhpremiumsb \
  --name dispatcher-output-1-activation-mfrr --auth-mode login -o tsv
# expected: True
```

Then bump the pod:

```bash
kubectl -n vpp rollout restart deployment/activationmfrr
kubectl -n vpp logs -l app.kubernetes.io/name=activationmfrr --tail=80 \
  | grep -E "PartitionInitializingAsync|ContainerNotFound|ResourceNotFound"
# positive signal: PartitionInitializingAsync line appears, no ContainerNotFound / ResourceNotFound.
```

Path P and Path D are alternatives. Once one heals the runtime, the other becomes a no-op (plan shows zero changes). They are **not** additive.

---

## L9 — Verification

Two independent kinds of verification are in play; only the first has fired by the end of this session:

| Verification | Status | Evidence |
|---|---|---|
| IaC diff matches plan (only line 1 of yaml replaced; everything else byte-identical) | DONE — A1 FACT | `git diff --stat` = `1 file changed, 20 insertions(+), 1 deletion(-)` on the worktree |
| Adversarial review of fix coherence (process + technical) | DONE — both subagents PROCEED-WITH-CHANGES; six findings absorbed into the final hunk + PR description | `socrates-attack-on-plan.md`, `demoledor-attack-on-plan.md` in `$T_DIR/context/` |
| Live runtime state matches verified-diagnosis claims (pod crashlooping; CG missing; container missing) | DONE — A1 FACT | `kubectl get pods` + `az eventhubs eventhub consumer-group list` + `az storage container exists` (this session, 2026-04-26) |
| Apply runs and creates both resources | PENDING | Operator action (Path P or merge of Path D's PR) |
| Pod recovers after rollout-restart | PENDING | Same as above |
| Slack reply posted to the parent thread | PENDING | Operator decision; draft at `slack-response.md` |

The fix's correctness is *complete* in IaC + adversarial-review terms; what remains is the operator-side execution (which the user explicitly said they would handle).

---

## L10 — Lessons (keep three; each with a probe)

1. **`git show origin/main:…` is only as fresh as your last `git fetch`.** A FACT label on a `git show origin/main` claim is *INFER until you fetched within the same probe window*. Defense: probe with `git fetch --all && git show <full-sha>:<path>` or `az repos diff` against the live remote — never trust a local mirror without timestamping the fetch.

2. **`trigger: none` + non-zero approval timeout is a silent-state-drift trap.** When CI is opt-in *and* apply is approval-gated, every merge is one human action away from latent drift. Defense: any pipeline whose Apply gates on Environment approval should also have a `trigger:` + path filter, so unapproved runs become a visible queue rather than invisible drift. This PR is the defense for pipeline 1413 specifically; the same pattern likely applies to other Sandbox CD pipelines in the org.

3. **"Stage skipped" in ADO ≠ "stage decided not to run".** `Skipped` collapses three different causes: (a) `applyCondition` evaluated false; (b) `dependsOn` failed; (c) `Checkpoint.Approval` timed out. Reading the **Timeline records** (`az devops invoke --area build --resource Timeline`) for `Checkpoint` / `Checkpoint.Approval` distinguishes the cases. The original diagnosis collapsed (c) into "plan-no-change" — the most charitable interpretation but wrong. Defense: when an Apply is "skipped", **always inspect the Timeline records** before forming a hypothesis about why.

---

## Residual / unverified items

| Item | Classification | What's blocked |
|---|---|---|
| App Config `vpp-appconfig-d` data-plane keys for label `Activation-mFRR` (specifically the `DispatcherOutput` consumer entry that drives the SDK to ask for the missing resources) | A3 UNVERIFIED[blocked: Entra principal lacks `App Configuration Data Reader` on this store; data-plane probe failed with SDK auth traceback] | Cannot directly re-probe this session. Logical chain still holds: source code does NOT define `DispatcherOutput` in local appsettings, R147 image asks for it at runtime, therefore App Config provides it. Independent verification needs RBAC grant. |
| Whether the auto-trigger's first run will encounter a template-internal `Build.Reason`-based gate inside `azure-oidc-validate-and-apply.yaml@2.6.9` | A3 UNVERIFIED[unknown] | Template is opaque to this repo. ADO docs say `Build.SourceBranch` is identical for IndividualCI / BatchedCI / Manual triggers on main, and the visible `applyCondition` only checks branch. First post-merge run reveals; revert if regression. |
| Whether `terraform/sandbox-extras/` (sibling directory not covered by `terraform/sandbox` prefix) will exist in the future | A3 UNVERIFIED[unknown] | Comment in the YAML calls this out so a future maintainer extends the path filter. |

These do NOT block the fix. They are recorded so they're not silently dropped.

---

## L11 — End-to-end command sequence and rationale (recreate this RCA from scratch)

This section is the literal "playbook" — every probe I ran, in the order I ran it, with the question each one answers. Anyone with the same access (interactive `az` session on the Sandbox subscription, kubectl on `vpp-aks01-d`, and the four repos cloned locally) can re-derive the same conclusions by walking this list top to bottom.

The hypothesis I started with: **the user's prepared worktree branch implies a tfvars hunk needs to be added; the prior diagnosis at `systemic-diagram-and-verified-diagnosis.md` says exactly which hunk.** The *job* of this sequence is to falsify that hypothesis if it's wrong, before committing anything.

### Step 0 — Identify the worktree and confirm clean state

**Question**: Is the prepared worktree where the user said it would be? Is it clean? On what commit?

```bash
ls "/Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src/enecomanagedcloud/myriad-vpp/" \
  | grep -i 'infrastructure\|gitops\|configuration\|dispatching'
# expect: VPP - Infrastructure, VPP%20-%20Infrastructure, VPP.GitOps,
#         VPP-Configuration, Eneco.Vpp.Core.Dispatching

WT="/Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src/enecomanagedcloud/myriad-vpp/VPP%20-%20Infrastructure/2026-04-24-ootw-fix-mfrr-activation-crashloop"
cd "$WT" && git fetch --all --prune  # CRITICAL — without this, origin/main is whatever your last
                                     # fetch saw, and a stale local mirror can invert FACT-vs-INFER
                                     # classification (this is exactly the trap that broke the prior
                                     # diagnosis; see L10 Lesson #1).
cd "$WT" && git worktree list && git branch --show-current && \
  git rev-parse HEAD origin/main && git status --porcelain
# expect: branch fix/NOTICKET/mfrr-activation-crashloop, HEAD == origin/main == 4dbaf72, status empty
```

**Why**: the user typed `VPP - Infrastructure/2026-04-24-...` but the literal worktree dir uses `%20` chars (looks URL-encoded but is the actual path). Confirming this avoids editing the *plain clone* by mistake. The branch + HEAD + clean status confirms there's no prior in-flight change to reconcile.

### Step 1 — Read the prior diagnosis to inventory load-bearing claims

**Question**: which exact claims will I have to verify or falsify?

```bash
SHIFT="…/02_on_call_shift/2026_04_21_stefan_vpp_infrastructure_mfrr"
wc -l "$SHIFT"/{diagnosis.md,diagnosis-and-fix-spec.md,systemic-diagram-and-verified-diagnosis.md,systemic-diagram-mermaid.md,slack-reply-draft.md,slack-antecedents.txt}
# read systemic-diagram-and-verified-diagnosis.md (top-priority — author's "verified" version)
# then diagnosis-and-fix-spec.md and slack-antecedents.txt
```

**Why**: the prior diagnosis is the *input under verification*. Its tables of FACTs and INFERs are the propositions to attack. The "verified" version (one in the IDE) is canonical; older `diagnosis.md` is a draft and is read only if cross-checking is needed.

### Step 2 — Verify the load-bearing IaC claim ("`activation-mfrr` is missing from `dispatcher-output-1` in `sandbox.tfvars` at `4dbaf72`")

**Question**: does the file actually lack the entry at the cited commit?

```bash
cd "$WT"
grep -n "activation-mfrr" configuration/terraform/sandbox/sandbox.tfvars
# 226:      "activation-mfrr" = {        ← under activation-response-output-1
# 379:      "activation-mfrr" = {        ← under dispatcher-output-1   ← surprise!
# count = 2, NOT 0 as the prior diagnosis claimed.

git log --oneline -3 -- configuration/terraform/sandbox/sandbox.tfvars
# 4dbaf72 Merged PR 172400: 778244: Activation.mFRR API - Monitoring   ← !

git show 4dbaf72 -- configuration/terraform/sandbox/sandbox.tfvars | head -80
# diff @@ -375,6 +375,13 @@ shows the EXACT hunk the prior diagnosis proposed — already merged.
```

**Why**: this is the cheapest discriminating probe. If the entry is missing at HEAD, the diagnosis route is right and proceed to commit. If it's present at HEAD, the route is dead and everything downstream needs reframing. **Outcome: present at HEAD; diagnosis stale.**

### Step 3 — Verify the IaC produces both CG + container from a single (EH, CG) tfvars entry

**Question**: even if the tfvars entry is there, will Apply actually create both the consumer group AND the matching blob container?

```bash
sed -n '57,96p' "$WT/terraform/sandbox/event-hub.premium.tf"
# module "eventhub_namespace_premium_eventhubs_consumer_groups"
#   for_each = { for entry in local.eventhub_premium_attributes:
#                "${entry.eventhub_name}.${entry.consumer_group_name}" => entry }
# module "eventhub_namespace_premium_eventhubs_consumer_groups_storage_containers"
#   storage_container_name = "${eventhub_name}-${consumer_group_name}"

sed -n '28,40p' "$WT/terraform/fbe/locals.tf"  # (sandbox/locals.tf has a parallel flatten)
# eventhub_premium_attributes = flatten([ ... eventhub_name = …, consumer_group_name = …, … ])
```

**Why**: protects against the "tfvars entry exists but module doesn't iterate it" failure mode. **Outcome: confirmed — paired modules iterate the same flattened local.**

### Step 4 — Sanity check that Sandbox is self-contained (does NOT source `terraform/fbe/`)

**Question**: when Pipeline 1413 runs Apply, does it consume `terraform/fbe/` at all?

```bash
grep -rn "fbe\|source\s*=\s*\"\.\." "$WT/terraform/sandbox/" | grep -v "logic-app-.*\.json"
# zero hits — sandbox does not source fbe
sed -n '12,14p' "$WT/.azuredevops/pipelines/terraform-cd-sandbox.pipeline.yaml"
#   - name: workingDirectory
#     value: $(Build.SourcesDirectory)/terraform/sandbox
# Terraform CWD is terraform/sandbox; cannot see terraform/fbe.
```

**Why**: this drives the path-filter design in Step 12. **Outcome: confirmed — sandbox is self-contained; path filter must NOT include `terraform/fbe/`.**

### Step 5 — Authenticate to Azure (Sandbox subscription)

**Question**: am I in the right context to probe Azure?

```bash
az login --use-device-code   # or interactive browser
# accept device code at https://login.microsoft.com/device with code <printed>

az account set --subscription 7b1ba02e-bac6-4c45-83a0-7f0d3104922e
az account show -o json | head -10
# id  = 7b1ba02e-…  name = Eneco Cloud Foundation - Sandbox-Development-Test  ✓
```

**Why**: the user's default sub may be `iactest` or another. Sandbox is the only one that has the resources. — `az account list` then `az account set`.

### Step 6 — Live runtime probes for the missing CG and container

**Question**: are the CG and the blob container actually missing on Azure right now?

```bash
az eventhubs eventhub consumer-group list \
  --namespace-name vpp-evh-premium-sbx --eventhub-name dispatcher-output-1 \
  -g rg-vpp-app-sb-401 --query "[].name" -o tsv
# $Default · asset-simulator · assetmonitor · cgadxdo · monitor · tenant-gateway-nl
# activation-mfrr NOT present — confirms missing CG.

az storage container exists --account-name vppevhpremiumsb \
  --name dispatcher-output-1-activation-mfrr --auth-mode login
# { "exists": false }   — confirms missing container.

# Parity check on the sibling EH that already works:
az storage container list --account-name vppevhpremiumsb --auth-mode login \
  --query "[?contains(name,'activation-mfrr')].name" -o tsv
# activation-response-output-1-activation-mfrr   — present.
```

**Why**: if the IaC at HEAD declares the resources but Azure runtime lacks them, the gap must be operational (Apply hasn't run or failed). Comparing to the sibling container (which exists) rules out global storage-account RBAC issues — only the dispatcher-output-1 pair is missing.

### Step 7 — Pipeline 1413 history: did Apply ever run after the merge?

**Question**: was an Apply ever attempted on `main` at `4dbaf72`?

```bash
az pipelines runs list --org "https://dev.azure.com/enecomanagedcloud" \
  --project "Myriad - VPP" --pipeline-ids 1413 --top 15 \
  --query "[].{id,buildNumber,result,reason,sourceBranch,sourceVersion,startTime,finishTime}" \
  -o table
# 20260421.1 (id 1616964)  refs/heads/main  4dbaf72  manual  succeeded
# 20260403.1               refs/heads/main  4dd886b9 manual  succeeded   ← pre-PR-172400 commit
# … all runs are reason=manual; no automatic CI runs anywhere in the table.
```

**Why**: confirms `trigger: none` — pipeline never auto-runs on merge. The first run at the post-PR commit was Stefan's manual trigger 5 days later.

### Step 8 — Why was Apply skipped on the only relevant run?

**Question**: distinguish between "applyCondition false", "depends-on failed", and "approval timeout".

```bash
az devops invoke --org "https://dev.azure.com/enecomanagedcloud" \
  --area build --resource Timeline \
  --route-parameters project="Myriad - VPP" buildId=1616964 --api-version 7.0 \
  --query "records[?type=='Stage' || type=='Job']" -o table
# Run Terraform Plan         succeeded  completed
# Snyk IaC Test - Plan File  succeeded  completed
# Terraform Validation       succeeded  completed
# Terraform Apply            skipped    completed   ← but WHY?
# Finalize build             succeeded  completed

az devops invoke --area build --resource Timeline \
  --route-parameters project="Myriad - VPP" buildId=1616964 --api-version 7.0 \
  --query "records[?contains(name,'Approve') || contains(name,'Approval') || contains(name,'Checkpoint')]" \
  -o json
# Checkpoint           start=2026-04-21T14:18:50  finish=2026-04-21T16:18:50  result=skipped
# Checkpoint.Approval  start=2026-04-21T14:18:50  finish=2026-04-21T16:18:50  result=skipped
# Δ = 2h00m exact ⇒ ADO default approval timeout
```

**Why**: a "skipped" stage in ADO can mean three things; reading the Timeline distinguishes them. The exact 2h delta between start and finish of `Checkpoint.Approval` is the smoking gun for "approval timed out". The prior diagnosis read this as "plan-no-change" — wrong. **Outcome: confirmed approval-timeout, not plan-empty.**

### Step 9 — Read the pipeline yaml to confirm the trigger gap

**Question**: is the no-auto-trigger really the cause, or am I missing some other trigger surface?

```bash
sed -n '1,45p' "$WT/.azuredevops/pipelines/terraform-cd-sandbox.pipeline.yaml"
# line 1:  trigger: none                                                 ← this is the gap
# line 13: workingDirectory = $(Build.SourcesDirectory)/terraform/sandbox
# line 31: azureDevOpsEnvironmentName: terraform-sandbox                  ← approval gate
# line 41: applyCondition: eq(Build.SourceBranch, 'refs/heads/main')

# Check whether ANY other yaml defines a trigger pointing at this pipeline:
grep -rn "trigger\|terraform-cd-sandbox" "$WT/.azuredevops/" "$WT/pull-request-validation.yaml"
# only terraform-cd-sandbox.pipeline.yaml line 1 + pull-request-validation.yaml's own trigger.
# no resource-based pipeline trigger from elsewhere.
```

**Why**: confirms the *only* way to start a build is `az pipelines run` (manual). There is no overlapping trigger from another yaml that could compensate.

### Step 10 — Live pod state and exception trace

**Question**: what does the pod actually fail on, today, in real time?

```bash
az aks get-credentials --resource-group rg-vpp-app-sb-401 --name vpp-aks01-d --overwrite-existing

kubectl -n vpp get pods -l app.kubernetes.io/name=activationmfrr -o wide
# activationmfrr-6778566c5f-t2n2w   1/1   Running             0          17d   ← R145, healthy
# activationmfrr-6dff6b5766-65hc9   0/1   CrashLoopBackOff    990 (4m)  3d7h   ← R147, dying every ~14s

POD=activationmfrr-6dff6b5766-65hc9
kubectl -n vpp get pod $POD -o jsonpath='{.spec.containers[0].image}'
# vppacra.azurecr.io/eneco-vpp/activationmfrr:0.147.dev.d15a425

kubectl -n vpp get pod $POD -o jsonpath='{.status.containerStatuses[0].lastState}' | jq
# terminated.exitCode: 139, reason: Error

kubectl -n vpp logs $POD --previous --tail=120 \
  | grep -E "ContainerNotFound|ResourceNotFound|partition|Exception" | head -15
# Azure.RequestFailedException: ContainerNotFound (blob, from PartitionLoadBalancer)
# Azure.Messaging.EventHubs.EventHubsException(ResourceNotFound):
#   'vpp-evh-premium-sbx:eventhub:dispatcher-output-1~<part>|activation-mfrr' could not be found
```

**Why**: the prior diagnosis cited only `ContainerNotFound`. Live evidence shows BOTH co-occurring exceptions. This refines the mental model: two parallel preconditions (storage check + AMQP open) both fail; healing requires both Azure resources to exist. The Terraform paired modules create both atomically, so a single Apply still fixes it — the fix itself is unchanged, but the explanation is more accurate.

### Step 11 — Dispatching repo source-code probe (where does the DispatcherOutput consumer come from?)

**Question**: does the source code define the `DispatcherOutput` consumer string anywhere, or is it injected purely from runtime config?

```bash
DISPATCH="…/Eneco.Vpp.Core.Dispatching"
grep -rn "DispatcherOutput\|dispatcher-output\|activation-mfrr" "$DISPATCH/helm/activationmfrr/"
grep -rn "ConsumerOptions\|EventHubOptions" "$DISPATCH/" | grep -v Test
sed -n '140,160p' "$DISPATCH/src/Activation/mFRR/Activation.mFRR.Api/appsettings.Local.json"
# Local config only has ActivationResponse consumer — no DispatcherOutput.
# DispatcherOutput must be injected via App Config at runtime (label "Activation-mFRR").

cd "$DISPATCH" && git log --all --oneline -S "DispatcherOutput" -- 'src/Activation/**'
# zero results — string not introduced via code; comes from App Config keys
# (the C# code reads ConsumerOptions:* generically and builds a consumer per child key).
```

**Why**: rules out "the helm chart hardcodes the wrong container name" as a cause. The image just enumerates the App Config consumers; the names come entirely from App Config.

### Step 12 — App Config data-plane probe (blocked)

**Question**: does App Config really define the `DispatcherOutput` consumer entry as the prior diagnosis claimed?

```bash
ENDPOINT=$(az appconfig show --name vpp-appconfig-d --resource-group rg-vpp-app-sb-401 \
            --query endpoint -o tsv)
az appconfig kv list --endpoint "$ENDPOINT" --label "Activation-mFRR" --auth-mode login \
  --fields key value --top 500
# ERROR: SDK auth traceback (expecting JSON but got error response).
# Likely cause: my Entra principal lacks App Configuration Data Reader on this store.
```

**Why**: the auth-blocked status downgrades the inherited claim about App Config to A2 INFER. **The fix is unaffected** — even if the App Config claim were wrong, the fact that Azure runtime LACKS the IaC-declared resources is the operative condition. The fix targets that gap.

### Step 13 — Adversarial dispatch (ON the plan, BEFORE committing the YAML edit)

**Question**: what fails if I commit the proposed `trigger:` block as written? What did I miss?

```
# Two parallel typed subagents — never the coordinator's own self-review:
Agent (subagent_type: socrates-contrarian)  → context/socrates-attack-on-plan.md
Agent (subagent_type: el-demoledor)         → context/demoledor-attack-on-plan.md

# Both received: verified-diagnosis.md + plan/plan.md + the actual yaml file.
# Each was given 8-9 specific attack questions about glob semantics, pr suppression,
# template internals, race conditions, path-filter completeness, blast radius, etc.
```

**Why**: per the brain's tandem rule, externalize attack to typed reviewers. Coordinator self-review is forbidden as a substitute. Both returned (PROCEED-WITH-CHANGES, HOLDS-WITH-PATCH) with six concrete findings. Six absorbed, zero rebutted, zero deferred.

### Step 14 — Refine path filter (post-adversarial)

**Question**: the original plan used `terraform/sandbox/*`; both adversaries flagged this as risky. What's the correct form?

```bash
# Per ADO docs https://learn.microsoft.com/en-us/azure/devops/pipelines/build/triggers#paths
# `*` = single-segment minimatch; `**` = recursive minimatch; bare directory = recursive prefix.
# Both adversaries converged on bare directory paths as the safest form.
```

**Why**: avoids the silent-miss class where a future subdir under `terraform/sandbox/` would not match. **Outcome: switch to bare directory paths in the final hunk.**

### Step 15 — Apply the YAML edit on the worktree

**Question**: did the edit land cleanly with no collateral damage?

```bash
# (Edit performed via tool; the resulting on-disk diff:)
cd "$WT" && git diff --stat .azuredevops/pipelines/terraform-cd-sandbox.pipeline.yaml
# 1 file changed, 20 insertions(+), 1 deletion(-)
git diff .azuredevops/pipelines/terraform-cd-sandbox.pipeline.yaml | head -40
# expected: replaces only "trigger: none" with the new trigger+pr block; lines 2..41 unchanged.

git status --porcelain   # exactly: " M .azuredevops/pipelines/terraform-cd-sandbox.pipeline.yaml"
git branch --show-current && git rev-parse HEAD
# fix/NOTICKET/mfrr-activation-crashloop, HEAD still 4dbaf72 (no commit, no push)
```

**Why**: Phase-8 falsifier #1 — if anything other than line 1 changed, halt and re-verify. **Outcome: clean.**

### Step 16 — Final coherence check (this RCA)

**Question**: does every load-bearing claim in the deliverables (`explanation-of-fix-and-issue-holistic.md`, `pr-description.md`, `slack-response.md`, this `rca.md`) match what we just verified live?

```
Cross-walk:
  L3 (CG missing, container missing)         ↔  Step 6  ✓
  L4 (two co-occurring SDK exceptions)       ↔  Step 10 ✓ (refines prior diagnosis)
  L5 (paired modules in sandbox/ root)       ↔  Step 3, 4 ✓
  L6 (trigger:none + 2h approval timeout)    ↔  Step 7, 8, 9 ✓
  L7 (5+5 days timeline)                     ↔  git log + ADO API timestamps ✓
  L8 fix hunk                                ↔  Step 15 (1 file, +20 / -1) ✓
```

**Why**: the user's direction was *no space for mistakes*. Walking the cross-reference end-to-end is the last check before handing the work back. — All rows pass.

---

## L12 — One-page playbook for the next on-call who sees this class of failure

```
Symptom:    a service pod in vpp namespace is in CrashLoopBackOff with one of:
            - Azure.RequestFailedException: ContainerNotFound (blob)
            - Azure.Messaging.EventHubs.EventHubsException(ResourceNotFound) (AMQP)

Step 1.    az login → az account set --subscription <sandbox>
Step 2.    Identify the (EH, CG, Container) triple the pod is asking for.
              kubectl logs --previous, look for the resource name in the exception.
              Cross-check against App Config (label = service name):
                az appconfig kv list --endpoint https://<store>.azconfig.io \
                  --label <ServiceName> --auth-mode login --fields key value
Step 3.    Probe Azure runtime for that triple:
              az eventhubs eventhub consumer-group list  --namespace-name <ns> --eventhub-name <eh> -g <rg>
              az storage container exists --account-name <sa> --name <container> --auth-mode login
Step 4.    If runtime is missing the resources, read the IaC at origin/main:
              git fetch --all
              git show origin/main:configuration/terraform/<env>/<env>.tfvars | grep -A 20 '"<eh>"'
            (a) IaC has the entry → operational fix needed:
                  az pipelines runs list --pipeline-ids <id>  → find last run on main
                  az devops invoke … Timeline                 → was Apply skipped? what was the Checkpoint.Approval delta?
                  If approval-timeout: az pipelines run + approve within 2h.
                  If applyCondition false: investigate the branch the run was triggered from.
            (b) IaC LACKS the entry → tfvars PR needed (the original diagnosis route).
Step 5.    Verify post-fix with the same probes. Then `kubectl rollout restart deployment/<svc>`.
            Look for `PartitionInitializingAsync` in the logs (positive signal).

Lesson 1: Always `git fetch` before `git show origin/main:…`. A stale local origin makes
          a "FACT" out of an INFER.
Lesson 2: A skipped Apply stage means three different things; read the Timeline records
          to distinguish.
Lesson 3: If a pipeline has an approval-gated Apply and `trigger: none`, every merge is
          one human action away from latent state drift. Add a `trigger:` + path filter so
          the unapproved queue is at least visible.
```
