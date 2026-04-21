---
task_id: 2026-04-21-001
agent: claude-code
status: complete
summary: Mermaid diagrams — data flow, repo topology, and resource parity for the mFRR-Activation fix
---

# Systemic Diagrams (Mermaid)

Renders natively in Obsidian / VS Code / GitHub. Complements the ASCII diagram in `systemic-diagram-and-verified-diagnosis.md` §1.

## Diagram 1 — Build + deploy pipeline (how code gets to a pod)

```mermaid
flowchart LR
  subgraph ADO["Azure DevOps — enecomanagedcloud"]
    A["<b>Eneco.Vpp.Core.Dispatching</b><br/>C# source + helm chart<br/>(activation service)"]
    B["<b>VPP - Infrastructure</b><br/>Terraform for Sandbox<br/>+ FBEs"]
    C["<b>VPP.GitOps</b><br/>ArgoCD config +<br/>sandbox overlays"]
    D["<b>VPP-Configuration</b><br/>Helm app-of-apps<br/>values.vppcore.sandbox.yaml"]
    P["<b>Pipeline 1413</b><br/>VPP-Infrastructure-<br/>Sandbox<br/>Stage 1: tf plan<br/>Stage 2: tf apply<br/>(skipped on no-change)"]
    B --> P
  end

  subgraph ACR["Azure Container Registry<br/>vppacra.azurecr.io"]
    IMG["eneco-vpp/activationmfrr<br/>tags: 0.145.dev.*, 0.147.dev.*"]
    HELM["helm OCI chart<br/>activationmfrr-0.2.0"]
  end

  subgraph AZ["Sandbox Azure Subscription<br/>7b1ba02e-... / rg-vpp-app-sb-401"]
    APPCFG["<b>App Configuration</b><br/>vpp-appconfig-d<br/>label: Activation-mFRR"]
    KV["<b>Key Vault</b><br/>vpp-aks-d"]
    EHNS["<b>EH namespace</b><br/>vpp-evh-premium-sbx"]
    EH1["hub: activation-<br/>response-output-1"]
    EH2["hub: dispatcher-<br/>output-1"]
    SA["<b>Storage</b><br/>vppevhpremiumsb"]
    EHNS --> EH1
    EHNS --> EH2
  end

  subgraph K8S["AKS cluster vpp-aks01-d • namespace vpp"]
    RS145["ReplicaSet 6778566c5f<br/>R145 pod (Running 12d)<br/>⚠ Kafka brokers down since<br/>11:12 UTC (separate issue)"]
    RS147["ReplicaSet 744ddb586c<br/>R147 pod<br/>❌ CrashLoopBackOff<br/>exit 139"]
    DEP["Deployment activationmfrr<br/>(same env vars both RSes)"]
    MI["User-assigned MI<br/>419ef759-..."]
    DEP --> RS145
    DEP --> RS147
  end

  A -->|build + push| IMG
  A -->|helm package| HELM
  B -->|terraform apply| APPCFG
  B -->|terraform apply| KV
  B -->|terraform apply| EHNS
  B -->|terraform apply| SA
  C -->|ArgoCD watches| D
  D -->|references OCI chart| HELM
  D -->|ArgoCD syncs| DEP
  RS147 -->|image pull| IMG
  RS147 -->|KV CSI mount| KV
  RS147 -->|MI auth| MI
  MI -->|reads| APPCFG
  RS147 -->|EventProcessorClient AMQP| EH2
  RS147 -->|BlobCheckpointStore REST| SA
```

## Diagram 2 — Runtime sequence (why the R147 pod crashes)

```mermaid
sequenceDiagram
  participant K8s as Kubernetes (AKS)
  participant Pod as R147 pod
  participant KV as Key Vault vpp-aks-d
  participant AC as App Config<br/>vpp-appconfig-d
  participant EH as EventHub<br/>dispatcher-output-1
  participant Blob as Storage<br/>vppevhpremiumsb

  K8s->>Pod: Start container<br/>(image 0.147.dev.9334f4a)
  Pod->>KV: CSI-mount application-secret<br/>(user-assigned MI 419ef759...)
  KV-->>Pod: connectionstrings_appconfig
  Pod->>AC: Bind AppConfig provider<br/>filter label "Activation-mFRR"
  AC-->>Pod: EventHubOptions:ConsumerOptions:<br/>DispatcherOutput:{CG, ContainerName, EHName}
  Pod->>Pod: Construct 2× EventProcessorClient<br/>(ActivationResponse + DispatcherOutput)
  Note over Pod: DispatcherOutput load-balance cycle begins
  Pod->>Blob: ListBlobFlatSegmentAsync<br/>(container=dispatcher-output-1-activation-mfrr)
  Blob-->>Pod: 404 ContainerNotFound
  Note over Pod: SDK wraps:<br/>RequestFailedException →<br/>EventHubsException(GeneralError)
  Pod->>Pod: Unhandled exception<br/>CLR abnormal termination (exit 139)
  Pod-->>K8s: Process exits
  K8s->>K8s: Restart (exponential back-off)
  Note over K8s: Loop. restartCount = 40+
```

## Diagram 3 — Resource parity (where Sandbox differs from FBE-kidu)

```mermaid
graph TB
  subgraph SBX["Sandbox (broken)"]
    SBX_CG1["CG activation-mfrr<br/>on activation-response-output-1<br/>✅ exists"]
    SBX_CG2["CG activation-mfrr<br/>on dispatcher-output-1<br/>❌ MISSING"]
    SBX_C1["blob activation-response-<br/>output-1-activation-mfrr<br/>in vppevhpremiumsb<br/>✅ exists"]
    SBX_C2["blob dispatcher-output-1-<br/>activation-mfrr<br/>in vppevhpremiumsb<br/>❌ MISSING"]
  end

  subgraph KIDU["FBE kidu (healthy — reference)"]
    K_CG1["CG activation-mfrr<br/>on activation-response-output-1<br/>✅ exists"]
    K_CG2["CG activation-mfrr<br/>on dispatcher-output-1<br/>✅ exists"]
    K_C1["blob activation-response-<br/>output-1-activation-mfrr<br/>in vppevhpremiumkidu<br/>✅ exists"]
    K_C2["blob dispatcher-output-1-<br/>activation-mfrr<br/>in vppevhpremiumkidu<br/>✅ exists"]
  end

  FIX["Fix: one tfvars hunk in<br/>configuration/terraform/sandbox/<br/>sandbox.tfvars<br/>adds activation-mfrr CG to<br/>dispatcher-output-1.consumerGroups.<br/>Terraform module creates<br/>BOTH CG AND blob container."]

  SBX_CG2 -.->|PR merge + apply| K_CG2
  SBX_C2 -.->|PR merge + apply| K_C2
  FIX --> SBX_CG2
  FIX --> SBX_C2
```

## Diagram 4 — Five-repo dependency graph

```mermaid
graph LR
  A["Eneco.Vpp.Core.Dispatching<br/>(app code + helm)"]
  B["VPP - Infrastructure<br/>(terraform sandbox+fbe)"]
  C["VPP.GitOps<br/>(argocd config)"]
  D["VPP-Configuration<br/>(helm app-of-apps values)"]
  E["MC-VPP-Infrastructure<br/>(terraform for MC envs)"]

  A -->|OCI helm chart + image| D
  D -->|ArgoCD syncs| AKS["AKS Sandbox"]
  C -->|ArgoCD installation| AKS
  B -->|tf apply| AZURE["Azure Sandbox"]
  E -.->|tf apply| MC["OpenShift<br/>dev-mc/acc/prd<br/>(out of scope)"]
  AKS -.->|consumes| AZURE

  style E stroke-dasharray: 5 5
  style MC stroke-dasharray: 5 5
```

## How to read these

- Start with **Diagram 4** to see the five repos that compose the VPP Sandbox picture.
- **Diagram 1** shows how code from each repo flows into runtime resources.
- **Diagram 2** shows exactly where and why the R147 pod dies (left-to-right in time).
- **Diagram 3** shows the one-shot diff between Sandbox (broken) and FBE-kidu (healthy reference) — which is what the PR closes.
