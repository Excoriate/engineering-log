---
task_id: 2026-04-21-001
agent: claude-code
status: complete
summary: Fully-verified multi-repo diagnosis + systemic diagram for Stefan's mFRR-Activation Sandbox crashloop — every load-bearing claim is now A1 FACT sourced from a live probe
---

# Systemic Diagram + Verified Diagnosis — mFRR-Activation Crashloop

All A3 UNVERIFIED assumptions from the prior diagnosis have been closed with live read-only probes. This document carries the FACT-classified evidence chain and the exact one-hunk Terraform fix.

## 1. The whole picture — all components and repos

```
 ┌─────────────────────────────────────────────────────────────────────────────────────────┐
 │                            SOURCE  REPOS  (Azure DevOps)                                 │
 ├──────────────────────────────────┬──────────────────────────────────┬────────────────────┤
 │ (A) Eneco.Vpp.Core.Dispatching   │ (B) VPP - Infrastructure         │ (C) VPP.GitOps     │
 │     C# service code +            │     Terraform for Sandbox +      │     ArgoCD config  │
 │     Helm chart source            │     FBEs (shared `terraform/`)   │     (overlays/     │
 │                                  │     env-specific tfvars in       │      sandbox)      │
 │     Builds to:                   │     configuration/terraform/     │     references:    │
 │     vppacra.azurecr.io/          │     <env>/<env>.tfvars           │                    │
 │       eneco-vpp/activationmfrr   │                                  │                    │
 │     (both the container image    │  Pipeline "VPP-Infrastructure-   │  repoURL points to │
 │      AND the helm OCI chart)     │   Sandbox" (def id 1413):        │  (D) VPP-Configur- │
 │                                  │  Stage 1 Terraform Validation    │      ation, path   │
 │     Image tag examples:          │    → plan only                   │      Helm/vpp-core-│
 │     - 0.145.dev.fe1f3fa (R145)   │  Stage 2 Terraform Apply         │      app-of-apps   │
 │     - 0.147.dev.9334f4a (R147)   │    → SKIPPED on plan-no-change   │                    │
 └──────────────┬───────────────────┴──────────────┬───────────────────┴─────────┬──────────┘
                │                                  │                             │
                │ image push on                    │ az cli: terraform apply     │ ArgoCD controller
                │ merge/release                    │ (when enabled)              │ watches (D)
                ▼                                  ▼                             ▼
 ┌─────────────────────────┐   ┌───────────────────────────────────┐   ┌─────────────────────┐
 │  Azure Container        │   │  AZURE  RESOURCES  ON  SANDBOX    │   │ ArgoCD "vpp-core"   │
 │  Registry:              │   │  (sub 7b1ba02e-..., RG            │   │ Application reads   │
 │  vppacra.azurecr.io     │   │   rg-vpp-app-sb-401)              │   │ (D) Helm values for │
 │  - eneco-vpp/           │   │                                   │   │ the vpp-core app-   │
 │    activationmfrr image │   │ AKS cluster  vpp-aks01-d          │   │ of-apps → which     │
 │  - helm OCI chart       │   │ Event Hub namespace               │   │ in turn references  │
 │    (premium)            │   │   vpp-evh-premium-sbx  ─── hubs ──┼───┤ (A)'s OCI helm      │
 │                         │   │   ├─ activation-response-output-1 │   │ chart in ACR        │
 │                         │   │   │   CG: activation-mfrr  ✓      │   │                     │
 │                         │   │   └─ dispatcher-output-1          │   │                     │
 │                         │   │       CG: activation-mfrr  ✗ MISS │   │                     │
 │                         │   │ Storage account  vppevhpremiumsb  │   │                     │
 │                         │   │   ├─ container activation-        │   │                     │
 │                         │   │   │   response-output-1-          │   │                     │
 │                         │   │   │   activation-mfrr  ✓          │   │                     │
 │                         │   │   └─ container dispatcher-        │   │                     │
 │                         │   │       output-1-activation-        │   │                     │
 │                         │   │       mfrr  ✗  MISSING            │   │                     │
 │                         │   │ Azure App Config  vpp-appconfig-d │   │                     │
 │                         │   │   label "Activation-mFRR":        │   │                     │
 │                         │   │   EventHubOptions:ConsumerOptions:│   │                     │
 │                         │   │     ActivationResponse:{EHName,   │   │                     │
 │                         │   │       CG=activation-mfrr,         │   │                     │
 │                         │   │       ContainerName=...response.. │   │                     │
 │                         │   │       ..-activation-mfrr}         │   │                     │
 │                         │   │     DispatcherOutput: {EHName,    │   │                     │
 │                         │   │       CG=activation-mfrr,         │   │                     │
 │                         │   │       ContainerName=...output-1-  │   │                     │
 │                         │   │       activation-mfrr}            │   │                     │
 │                         │   │ Key Vault  vpp-aks-d              │   │                     │
 │                         │   │   secret  connectionstrings-      │   │                     │
 │                         │   │     app-config                    │   │                     │
 │                         │   │   secret  appreg-vpp-keyvault-    │   │                     │
 │                         │   │     id/id-secret                  │   │                     │
 │                         │   │ User-assigned MI                  │   │                     │
 │                         │   │   419ef759-bafa-49c2-b26b-        │   │                     │
 │                         │   │   33ae7b073435                    │   │                     │
 │                         │   └───────────────┬───────────────────┘   │                     │
 │                         │                   │                       │                     │
 │                         │                   │  K8s ns "vpp"         │                     │
 │                         │                   ▼                       │                     │
 └──────────────┬──────────┘     ┌────────────────────────────────────┐│                     │
                │                 │ K8s Deployment  activationmfrr    ││                     │
                │                 │   replicas=1                      ││                     │
                │                 │                                   ││                     │
                │                 │ ReplicaSet  6778566c5f  (R145)    ││                     │
                │                 │   pod: activationmfrr-...-t2n2w   ││                     │
                │                 │   status: Running 1/1 (12 d)      ││                     │
                │                 │   BUT logs show: ESP Kafka        ││                     │
                │                 │   brokers unreachable since       ││                     │
                │                 │   11:12 UTC today  (separate      ││                     │
                │                 │   concern — SEE §5)               ││                     │
                │                 │                                   ││                     │
                │                 │ ReplicaSet  744ddb586c  (R147)    ││                     │
                │                 │   pod: activationmfrr-...-9rwnd   ││                     │
                │                 │   status: CrashLoopBackOff        ││                     │
                │                 │   restartCount: 40+               ││                     │
                │                 │   exit: 139 (abnormal CLR term)   ││                     │
                │                 │   stack: BlobCheckpointStore →    ││                     │
                │                 │   ContainerNotFound on            ││                     │
                │                 │   dispatcher-output-1-            ││                     │
                │                 │   activation-mfrr                 ││                     │
                │◄────────────────┤ Image pulls from ACR (vppacra)    │┘                     │
                │   image pull    │ Mounts: secrets-store-inline      │                      │
                                  │   (KV CSI) → application-secret   │                      │
                                  │                                   │                      │
                                  │ Startup:                          │                      │
                                  │   1. Read env                     │                      │
                                  │      ConnectionStrings__App-      │                      │
                                  │      Configuration  (injected     │                      │
                                  │      from KV via CSI)             │                      │
                                  │   2. .NET host binds              │                      │
                                  │      Azure AppConfig provider     │                      │
                                  │   3. Provider authenticates via   │                      │
                                  │      user-assigned MI             │                      │
                                  │   4. Filter by label              │                      │
                                  │      "Activation-mFRR"            │                      │
                                  │   5. Read keys:                   │                      │
                                  │      EventHubOptions:             │                      │
                                  │        ConsumerOptions:*          │                      │
                                  │   6. Construct 2×                 │                      │
                                  │      EventProcessorClient         │                      │
                                  │   7. Each calls BlobCheckpoint-   │                      │
                                  │      Store.ListOwnershipAsync     │                      │
                                  │      (REST GET on container)      │                      │
                                  │   8. Second one (Dispatcher-      │                      │
                                  │      Output) → 404               │                      │
                                  │   9. EventHubsException bubbles   │                      │
                                  │      to host → process dies       │                      │
                                  │  10. K8s restarts pod             │                      │
                                  │  11. Goto step 1 (CrashLoop)      │                      │
                                  └───────────────────────────────────┘
```

## 2. Repos enumerated (what was probed, what was found)

| # | Repo path (local) | Role | Load-bearing finding |
|---|---|---|---|
| A | `Eneco.Vpp.Core.Dispatching` (clone present at `.../myriad-vpp/Eneco.Vpp.Core.Dispatching`) | C# source for activationmfrr service + helm chart source. Builds images to `vppacra.azurecr.io/eneco-vpp/activationmfrr:<version>` (tags `0.145.dev.*`, `0.147.dev.*`, etc.) | A new `DispatcherOutput` consumer added somewhere between R145 → R147 reads `dispatcher-output-1` EH via CG `activation-mfrr` and a blob checkpoint container. |
| B | `VPP - Infrastructure` (clone at `.../myriad-vpp/VPP - Infrastructure`) | Terraform that provisions Sandbox + FBE Azure resources. `terraform/fbe/` is shared code; env-specific tfvars in `configuration/terraform/<env>/<env>.tfvars`. Pipeline definition 1413 "VPP - Infrastructure - Sandbox" runs against branch `main`. | The `dispatcher-output-1` consumer-groups map in `sandbox.tfvars` does NOT declare `activation-mfrr`. **This is the fix site.** |
| C | `VPP.GitOps` (clone at `.../myriad-vpp/VPP.GitOps`) | ArgoCD configuration: argocd installation + Sandbox overlays + argocd `Application` manifests that define what ArgoCD syncs. `argocd-configuration/applications/vpp-core-app-of-apps-sandbox.yaml` points ArgoCD at repo (D) to source the Helm app-of-apps. | Not load-bearing for this fix — the deployment path already works; the failing pod comes through this pipeline healthily, the issue is downstream at IaC. |
| D | `VPP-Configuration` (exists in ADO; local clone not confirmed in this session) | Helm chart `vpp-core-app-of-apps-migration` + env-specific values files `values.vppcore.sandbox.yaml` that reference image tags + (indirectly) which OCI helm charts ArgoCD pulls from ACR. | Not load-bearing for this fix — values flowed correctly to K8s Deployment (same env vars R145 vs R147 confirmed via `diff`). |
| — | `MC-VPP-Infrastructure` (clone at `.../myriad-vpp/MC-VPP-Infrastructure`) | Terraform for MC environments (dev-mc, acc, prd) — **different repo** from (B) `VPP - Infrastructure`. Not in Sandbox scope. | Out of scope for this ticket. Sandbox fix is in (B) only. |

## 3. Evidence chain — every load-bearing claim verified

| Claim | Evidence | Classification |
|---|---|---|
| Crash-loop pod = `vpp/activationmfrr-744ddb586c-9rwnd`, image `0.147.dev.9334f4a`, exit 139 (Error, not OOMKilled), restartCount growing past 40 | `kubectl -n vpp describe pod`, `kubectl get pod -o jsonpath='{.status.containerStatuses[0].lastState}'` | **A1 FACT** |
| Verbatim exception: `Azure.RequestFailedException: ContainerNotFound (Status 404)` inside `BlobCheckpointStoreInternal.ListOwnershipAsync(fullyQualifiedNamespace, eventHubName, consumerGroup, cancellationToken)` wrapped as `EventHubsException(GeneralError)` | `kubectl -n vpp logs activationmfrr-744ddb586c-9rwnd --tail=300` | **A1 FACT** |
| R147 vs R145 env vars are IDENTICAL (regression is inside the image only) | `diff <(kubectl get pod <R145> -o jsonpath='{.spec.containers[0].env}') <(kubectl get pod <R147> -o jsonpath='{.spec.containers[0].env}')` → empty | **A1 FACT** |
| Sandbox subscription = `7b1ba02e-bac6-4c45-83a0-7f0d3104922e` (Eneco Cloud Foundation - Sandbox-Development-Test), RG `rg-vpp-app-sb-401` | `az account list -o table` | **A1 FACT** |
| Activation-mFRR App Config label exists and defines two consumers (`ActivationResponse`, `DispatcherOutput`), each with explicit `ConsumerGroup`, `ContainerName`, `EventHubName` values | `az appconfig kv list --name vpp-appconfig-d --label "Activation-mFRR" --fields key value --top 500` | **A1 FACT** |
| ActivationResponse consumer: EH=`activation-response-output-1`, CG=`activation-mfrr`, Container=`activation-response-output-1-activation-mfrr` | App Config read (see row above) | **A1 FACT** |
| DispatcherOutput consumer: EH=`dispatcher-output-1`, CG=`activation-mfrr`, Container=`dispatcher-output-1-activation-mfrr` | App Config read (see row above) | **A1 FACT** |
| Both Event Hubs live on `vpp-evh-premium-sbx` (NOT `vpp-evh-sbx` as the prior diagnosis initially assumed) | For-loop over all 14 EH namespaces in RG: `az eventhubs eventhub list --namespace-name <ns> -g rg-vpp-app-sb-401 --query "[?name=='activation-response-output-1' \|\| name=='dispatcher-output-1']"` — matched only on `vpp-evh-premium-sbx/kidu/ionix/ishtar/veku` | **A1 FACT** |
| CG state on `vpp-evh-premium-sbx/activation-response-output-1`: `$Default`, **`activation-mfrr` ✓**, `tenant-gateway-nl` | `az eventhubs eventhub consumer-group list --namespace-name vpp-evh-premium-sbx --eventhub-name activation-response-output-1` | **A1 FACT** |
| CG state on `vpp-evh-premium-sbx/dispatcher-output-1`: `$Default`, `asset-simulator`, `assetmonitor`, `cgadxdo`, `monitor`, `tenant-gateway-nl` — **`activation-mfrr` MISSING ✗** | `az eventhubs eventhub consumer-group list --namespace-name vpp-evh-premium-sbx --eventhub-name dispatcher-output-1` | **A1 FACT** |
| Blob container state on `vppevhpremiumsb`: `activation-response-output-1-activation-mfrr ✓`, **`dispatcher-output-1-activation-mfrr` MISSING ✗** | Enumeration across all SAs in RG: `az storage container exists --account-name <sa> --name <container>` + container listing | **A1 FACT** |
| Parity check: `vpp-evh-premium-kidu` + `vppevhpremiumkidu` SA have BOTH consumer groups AND containers — Sandbox is the lone deficit | `az eventhubs ... list` + `az storage container list` on kidu | **A1 FACT** |
| Pipeline `buildId=1616964` = "VPP - Infrastructure - Sandbox" (def id 1413), build number `20260421.1`, manual trigger by Stefan, source `refs/heads/main` commit `4dbaf72e`, result `succeeded`, **Stage 1 Terraform Validation succeeded, Stage 2 Terraform Apply SKIPPED** | `az pipelines runs show --id 1616964` + ADO REST timeline API | **A1 FACT** |
| Origin/main `sandbox.tfvars` at commit `4dbaf72e`: `dispatcher-output-1` block has 4 consumer groups (`cgadxdo`, `monitor`, `assetmonitor`, `tenant-gateway-nl`), **no `activation-mfrr`** | `git show origin/main:configuration/terraform/sandbox/sandbox.tfvars` lines 335–367 | **A1 FACT** |
| Terraform shared code `terraform/fbe/event-hub.premium.tf` defines TWO modules — `eventhub_namespace_premium_eventhubs_consumer_groups` AND `eventhub_namespace_premium_eventhubs_consumer_groups_storage_containers` — both iterate `local.eventhub_premium_attributes`. Adding ONE consumer-group entry in tfvars automatically creates BOTH the CG resource AND the blob container. | Source file read (lines 57–94) | **A1 FACT** |
| Container name pattern = `"${eventhub_name}-${consumer_group_name}"` (explicit in `event-hub.premium.tf` line 88) — confirms "container = CG name" was convention only, NOT SDK guarantee (lesson LL-012 already promoted) | Source file read | **A1 FACT** |
| Managed identity `419ef759-bafa-49c2-b26b-33ae7b073435` mounted via KV CSI → `application-secret` → App Config connection-string; reads `ConnectionStrings__AppConfiguration` from env | `kubectl get secretproviderclass secret-provider-kv -o yaml` | **A1 FACT** |
| R145 "healthy" pod is logging `4/4 brokers are down` against `ssl://*.dtaaz.esp.eneco.com:9094/` every 5 min since 2026-04-21 11:12 UTC — **separate concern** from Stefan's ticket (different upstream: Eneco ESP / Axual Kafka, not Azure EventHubs) | `kubectl -n vpp logs activationmfrr-6778566c5f-t2n2w --tail=80` | **A1 FACT** |

## 4. The fix — one hunk, one PR

File: `VPP - Infrastructure/configuration/terraform/sandbox/sandbox.tfvars`
Location: inside the `eventhub_premium_attributes."dispatcher-output-1"."consumerGroups"` map, around line 337
Patch:

```hcl
  "dispatcher-output-1" = {
    "consumerGroups" = {
      "cgadxdo" = {
        "kusto_db_name"                = "Monitor"
        "kusto_evh_connection_enabled" = "true",
        "table_name"                   = "RawDispatcherOutputPremium",
        "mapping_rule_name"            = "RawDispatcherOutput_mapping_v1",
        "data_format"                  = "MULTIJSON",
      },
+     "activation-mfrr" = {
+       "kusto_db_name"                = "Monitor"
+       "kusto_evh_connection_enabled" = "false",
+       "table_name"                   = "",
+       "mapping_rule_name"            = "",
+       "data_format"                  = "",
+     },
      "monitor" = {
        # ...unchanged...
      },
      "assetmonitor" = { /* unchanged */ },
      "tenant-gateway-nl" = { /* unchanged */ },
    }
  },
```

This one tfvars change automatically produces TWO Terraform resource creations via the shared `terraform/fbe/event-hub.premium.tf` module iteration:

1. `module.eventhub_namespace_premium_eventhubs_consumer_groups["dispatcher-output-1.activation-mfrr"]`
   → creates consumer group `activation-mfrr` on `vpp-evh-premium-sbx/dispatcher-output-1`.
2. `module.eventhub_namespace_premium_eventhubs_consumer_groups_storage_containers["dispatcher-output-1.activation-mfrr"]`
   → creates blob container `dispatcher-output-1-activation-mfrr` on storage account `vppevhpremiumsb`.

Zero other resources are changed. Plan should show exactly `+2` additions.

## 5. Pipeline behaviour explained (why Stefan's trigger did not fix it)

The pipeline `buildId=1616964` succeeded as reported, but its behaviour is:

- **Stage 1 "Terraform Validation"**: always runs — `terraform init`, `terraform plan`, Snyk IaC Test on plan. This succeeded.
- **Stage 2 "Terraform Apply"**: **was SKIPPED** in Stefan's run. Reason is one of:
  - Plan detected zero changes → apply has nothing to do → stage auto-skipped (most likely, consistent with the unchanged tfvars).
  - Pipeline YAML gates apply on non-manual triggers or branch filters.

Either way: **Stefan triggering the pipeline against main, without a prior tfvars PR, is a no-op that cannot fix the missing resources.** The fix path is the PR above, merged to main; on merge, the pipeline will detect the two added resources in plan, apply will run, and the CG + container will appear on Azure. Then a `kubectl rollout restart deployment/activationmfrr` in `vpp` namespace (or ArgoCD auto-sync + selfHeal, which is enabled on the app-of-apps) will restart the pod, which will then successfully list ownership on the now-existing blob container and progress to the AMQP open against the now-existing CG.

## 6. The *separate* concern — R145 Kafka broker failure

This is NOT part of Stefan's ticket but was surfaced by the adversarial probe on the R145 pod. Evidence: continuous `4/4 brokers are down` against `ssl://*.dtaaz.esp.eneco.com:9094/` in R145's pod log from 2026-04-21 11:12 UTC onward. `dtaaz` is the Eneco ESP (Axual) Kafka cluster used for outbound publishing (activation response → ESP → TenneT). Likely causes:

- Network / NSG regression on Sandbox `vpp` namespace outbound route to `dtaaz.esp.eneco.com`.
- ESP-side broker maintenance.
- DNS resolution failure (`vpp-aks01-d` pod DNS → ESP broker IP).

**Impact**: Even if the R147 fix above applies and the new pod starts healthy, activation responses may not publish to ESP until this Kafka-side issue is resolved. Combined impact: Sandbox mFRR activation is **effectively offline end-to-end** until both issues are fixed. This warrants a **separate ticket** directed to Core team / Platform networking.

## 7. Residual UNVERIFIED items (what remains beyond read-only reach)

- [A3 UNVERIFIED[unknown]] **Root cause of the ESP Kafka broker failure** — requires either ESP-side investigation (not my scope) or network-level probes (NSG rules, DNS resolution, route tables) which may need SP-based auth.
- [A3 UNVERIFIED[blocked: MC OpenShift context not loaded]] — did the R147 image propagate to dev-mc/acc/prd on MC? Different auth flow per `/eneco-tool-tradeit-mc-environments` — not exercised in this session. Precedent suggests no (MC envs deploy via separate pipelines off release branches, not Sandbox's mainline auto-sync).
- [A3 UNVERIFIED[unknown]] **When the R147 DispatcherOutput consumer was added to the service code** — requires reading Eneco.Vpp.Core.Dispatching git log in detail (out of scope for this session).

These do not block the Sandbox fix. They are named here so they remain visible, not silently dropped.

## 8. How a reader becomes an expert on this class of problem

Read in this order:

1. **This document §1** — the ASCII diagram maps every component.
2. **This document §3** — the evidence chain shows which claims are FACT-sourced from which probe.
3. **Lesson [[reporter-self-diagnoses-are-infer-not-fact]]** — why "missing consumer group" was inverted to "missing blob container first, then CG".
4. **Lesson [[kubernetes-running-ready-does-not-imply-functional]]** — why R145 "healthy" was a framing trap (adversary §5).
5. **Lesson [[read-azure-appconfig-values-before-authoring-terraform-pr]]** — why App Config read is the highest-impact probe for this class.
6. **Gotcha [[azure-eventhubs-checkpoint-container-name-is-convention-not-sdk-guarantee]]** — why "container = CG name" is convention, not SDK contract (verified in §3 against `event-hub.premium.tf` line 88).
7. **Gotcha [[eneco-vpp-sandbox-is-aks-not-openshift]]** — why tooling differs from MC envs (Sandbox = AKS, MC = OpenShift).
8. **Pattern [[argocd-helm-oci-plus-appconfig-plus-kv-csi-three-layer-config-stack]]** — the config architecture that allows "same env vars, different image → different behaviour".

Internalizing those eight artifacts plus this diagram converts this incident from "a mystery crashloop" into "a recognizable class of missing-CG+missing-container rollout regression, with a known Terraform-tfvars fix site and a known pipeline gating behavior."
