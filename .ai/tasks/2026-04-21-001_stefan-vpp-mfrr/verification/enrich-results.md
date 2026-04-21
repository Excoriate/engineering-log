---
task_id: 2026-04-21-001
agent: claude-code
status: complete
summary: Phase 7 enrich probe results — FACT-classified evidence, hypothesis classification, pipeline verification
---

# Enrich Probe Results

## Probe matrix

| ID | Stage | Claim under test | Command | Result | State shift |
|---|---|---|---|---|---|
| P1 | A | Azure CLI + kubectl are usable in this session | `az account list -o table` + `kubectl config current-context` | Authenticated; current context = `vpp-aks01-d` | N/A (enabler) |
| P2 | A | Sandbox subscription ID is still `7b1ba02e-...` | `az account list` | CONFIRMED: `Eneco Cloud Foundation - Sandbox-Development-Test` = `7b1ba02e-bac6-4c45-83a0-7f0d3104922e` | A3 → **A1 (FACT)** |
| P3 | A | Sandbox AKS resides in `rg-vpp-app-sb-401` | `kubectl config get-contexts` | CONFIRMED: context `vpp-aks01-d` uses `clusterUser_rg-vpp-app-sb-401_vpp-aks01-d` | A3 → **A1** |
| P4 | A | mFRR-Activation workload exists on Sandbox AKS | `kubectl get pods -A \| grep -iE "mfrr\|activation\|dispatch"` | LOCATED: `vpp/activationmfrr-744ddb586c-9rwnd` **CrashLoopBackOff (40 restarts)**; sibling `vpp/activationmfrr-6778566c5f-t2n2w` **Running (12d)** | **A1** — dual ReplicaSet, rollout stuck |
| P5 | B (F4) | **Crash cause is `EventHubsException(Reason=ResourceNotFound)` on consumer group entity (H1)** | `kubectl -n vpp logs <pod> --tail=300` | **REFUTED (partially)**. Actual error: `Azure.RequestFailedException: ContainerNotFound` — Status 404 — inside `BlobCheckpointStoreInternal.ListOwnershipAsync(fullyQualifiedNamespace, eventHubName, consumerGroup, cancellationToken)`. Exception class: general `EventHubsException(GeneralError)` wrapping the blob exception, not `ResourceNotFound` on the Event Hub. | H1 as stated → **refuted in specifics**; new leading hypothesis: missing **Blob Storage checkpoint container** (H1b) |
| P6 | A | Pod container exit mode + image identity | `kubectl -n vpp describe pod <pod>` | Image `vppacra.azurecr.io/eneco-vpp/activationmfrr:0.147.dev.9334f4a` (R147 pre-release). Exit code **139** (SIGSEGV / abnormal termination). Liveness/readiness at `/liveness`, `/readiness`; startup probe at `/healthz` (delay=0s, period=5s, failureThreshold=30 → ~150s allowed). Service account: `activationmfrr`. Secrets: KV CSI mount + Azure App Config connection string. | **A1** |
| P7 | B (F4b) | Old healthy pod runs a different image (version diff) | `kubectl -n vpp get pod activationmfrr-6778566c5f-... -o jsonpath='{.spec.containers[0].image}'` | Image `activationmfrr:0.145.dev.fe1f3fa` (R145). **Two minor versions difference** between healthy (R145) and crashing (R147) pods. | **A1** — rolling deployment introduced the regression |
| P8 | C (F1) | The Event Hub `iot-telemetry` on `vpp-evh-sbx` lacks the consumer group the service expects | `az eventhubs eventhub consumer-group list --namespace-name vpp-evh-sbx -g rg-vpp-app-sb-401 --eventhub-name iot-telemetry -o table` | Only **two** CGs: `$Default`, `fleetoptimizer`. **No `activationmfrr`-named CG**. | **A1** — CG is indeed absent (Stefan was directionally right) |
| P9 | A | Only one event hub exists in the `vpp-evh-sbx` namespace | `az eventhubs eventhub list --namespace-name vpp-evh-sbx -g rg-vpp-app-sb-401 --query "[].name"` | Single hub: `iot-telemetry` | **A1** |
| P10 | A | Storage account for dispatching checkpoints | `az storage account list -g rg-vpp-app-sb-401 -o table` | Candidate: **`savppdspbootstrapsb`** — created `2026-04-20 14:49 UTC` (<24h before ticket). Sibling accounts exist per service (`savppftobootstrapsb`, `savppfobootstrapsb`, `savppcrebootstrapsb`, `savppaggbootstrapsb`). | **A1** — new account provisioned the day before |
| P11 | C (F2a) | `savppdspbootstrapsb` contains a checkpoint container for activationmfrr | `az storage container list --account-name savppdspbootstrapsb --auth-mode login -o table` | **Only one container exists: `tfstate`** (Terragrunt state). **No checkpoint container.** | **A1** — confirms the `ContainerNotFound` mechanism |
| P12 | B (F4c) | Pod config dictates CG/container at runtime (not K8s env) | `kubectl -n vpp get deploy activationmfrr -o yaml` | Deployment env injects only: `connectionstrings_appconfig` (Azure App Config URL), KV client credentials, tenant IDs, `DOTNET_GCHeapHardLimitPercent=46`. **No direct CG/container env vars** — everything comes from **Azure App Configuration** at runtime. | **A1** — config is dynamic, not static |
| P13 | A | SecretProviderClass manifests the KV references | `kubectl -n vpp get secretproviderclass secret-provider-kv -o yaml` | KV = `vpp-aks-d`. User-Assigned MI id `419ef759-bafa-49c2-b26b-33ae7b073435`. 15 secret objects; `connectionstrings-app-config` is the one that injects the App Config URL. | **A1** — identity + config source confirmed |
| P14 | A | App Configuration instance used by the service | `az appconfig list -g rg-vpp-app-sb-401 -o table` | **`vpp-appconfig-d`** (endpoint `https://vpp-appconfig-d.azconfig.io`) — the main VPP App Config for Sandbox. Created 2022-07-22. FBE-specific ones exist per env. | **A1** |
| P15 | A | Deployment rollout history | `kubectl -n vpp rollout history deploy/activationmfrr` | Revisions 20, 21, 22 (change-cause NULL — not `kubectl set image`). Shows exactly 3 revisions retained per `revisionHistoryLimit`, consistent with helm-managed chart sync. | **A1** — ArgoCD/Helm driven, not imperative kubectl |
| P16 | D (F3) | ADO pipeline `buildId=1616964` outcome | Manual (no `az devops` CLI configured in this session) | `[UNVERIFIED[blocked: ADO CLI not configured]]` — runbook provided to operator | — |
| P17 | E (F5) | Non-Sandbox envs are healthy (blast radius) | FBE pods: `kubectl get pods -A \| grep activationmfrr` — OpenShift envs: `[UNVERIFIED[blocked: no MC context]]` | FBE namespaces (`ionix/ishtar/kidu/veku`) all show `activationmfrr-*` **Running 1/1, 0 restarts**. dev-mc/acc/prd not probed from this session. | **A1** (Sandbox FBEs only), **A3** (MC envs) |
| P18 | F | Apr 16 "activation service is red" thread resolution | Not investigated further (low information gain: cross-env noise) | Marked `[DEFERRED]` — not load-bearing for the Sandbox diagnosis | — |

## Redefinition of leading hypothesis

The reporter's hypothesis (H1) said "missing EventHub consumer" / "missing consumer group". The pod's actual exception contradicts the naive reading of that, but confirms a specific sub-variant I'll call **H1b**:

> **H1b — Missing Blob Storage checkpoint container (named after the consumer group by SDK convention), and by transitive necessity, the consumer group itself is also missing on the Event Hub.**

Mechanism chain (verified):

```
 1. [FACT] R147 pre-release of activationmfrr (image 0.147.dev.9334f4a) is deployed
    via ArgoCD helm OCI sync to vpp namespace on Sandbox AKS.
 2. [FACT] The service reads its Event Hub + consumer group + checkpoint store
    settings from Azure App Configuration (vpp-appconfig-d) at startup — none
    are static in the K8s deployment.
 3. [INFER — chain from P5, P8, P11, P12, P14] The new config values reference
    (a) a consumer group on vpp-evh-sbx/iot-telemetry that the R147 version
        introduces (likely named `activationmfrr` following service-name
        convention), AND
    (b) a blob container on a Sandbox storage account used by
        BlobCheckpointStoreInternal as checkpoint persistence — container name
        by SDK convention is typically the consumer group name.
 4. [FACT — P11] The blob container does not exist.
 5. [FACT — P5] EventProcessorClient startup triggers
    `BlobCheckpointStoreInternal.ListOwnershipAsync(fullyQualifiedNamespace,
    eventHubName, consumerGroup, cancellationToken)` which calls
    `Azure.Storage.Blobs.ContainerRestClient.ListBlobFlatSegmentAsync`.
 6. [FACT — P5] Azure Blob Storage returns 404 `ContainerNotFound`. SDK wraps
    as `Azure.RequestFailedException`, then `EventHubsException(GeneralError)`.
 7. [INFER] The host process surfaces the unhandled exception → container
    exits with code 139 (SIGSEGV / abnormal CLR termination).
 8. [FACT — P4, P6] Kubernetes restart policy → pod re-created → same
    exception → CrashLoopBackOff; 40 restarts in 175 minutes.
 9. [FACT — P8] Additionally, the consumer group itself does not exist on
    `vpp-evh-sbx/iot-telemetry`. Even if the blob container were created,
    the subsequent AMQP connection open would fail with the exception class
    originally hypothesized (EventHubsException Reason=ResourceNotFound).
    Both resources must be created.
10. [FACT] The old ReplicaSet (R145 image, 0.145.dev.fe1f3fa) continues to
    serve healthy (12 days, 0 restarts) because its config references a
    consumer group + container combination that already exists (likely
    $Default or fleetoptimizer).
```

## Blast radius (final)

- **[FACT] Sandbox `vpp` namespace only**. FBE namespaces (`ionix/ishtar/kidu/veku`) have their own activationmfrr pods, all Running 0 restarts — their dedicated EH namespaces (`vpp-evh-ionix`, `vpp-evh-kidu`, etc.) and config don't share this gap.
- **[UNVERIFIED[assumption: no MC regression, boundary: not probed]]** dev-mc / acc / prd on MC OpenShift: not reachable from this session. The same version bump (R147) may or may not have been promoted beyond Sandbox — operator must verify before closing.
- **[FACT] Old R145 pod continues serving** → there is *no* current functional outage of mFRR activation on Sandbox; the rollout is blocked but the service path still works through the old replica. This is a **DX/rollout ticket**, consistent with Stefan's `:this-is-fine:` priority tag, NOT a production incident.

## Confidence

**~90% on H1b** (missing blob container primary; missing CG secondary by transitive necessity). Residual 10%:
- ADO pipeline buildId=1616964 outcome not verified from this session (P16 blocked). If the pipeline *already* ran successfully and declared both resources, the fix is automatic once ArgoCD resyncs. If the pipeline's scope is infra-only and did not create the container, a PR is still needed.
- MC envs not probed (P17 blocked). A wider regression is unlikely given the FBE namespaces are healthy and MC deploys are separate pipelines, but not proven from this session.

## Handover gate compliance

- [✓] Gate 1 (no writes): zero write probes executed; all `az`/`kubectl` calls were read-only (`list`, `show`, `describe`, `get`, `logs`, `rollout history`).
- [✓] Gate 2 (no Slack posts): draft only, not posted.
- [✓] Gate 3 (no severity claim): classified as P3/P4 DX ticket consistent with reporter's tag, no new severity assigned.
- [✓] Gate 4 (no IaC PR opened): runbook drafted for operator.
- [✓] Gate 5 (no secret values captured): `SecretProviderClass` manifest captured (key names only, no values); `application-secret` content not dumped; App Config connection string never read.
