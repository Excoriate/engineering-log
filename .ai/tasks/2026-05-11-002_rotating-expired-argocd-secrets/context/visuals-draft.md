---
task_id: 2026-05-11-002
agent: claude-opus-4-7
status: complete
summary: Pre-drafted mermaid + ASCII visuals for the runbook (Section A confirmed; Section B placeholders)
phase: 4
---

# Visuals draft for `how-to-rotate.md`

## V1 — Mermaid: 4-PAT topology (Section overview)

```mermaid
flowchart TB
    subgraph ADO["Azure DevOps — sa_platform_vpp@eneco.com"]
        P1["argo-cd-sandbox<br/>Exp: 2026-05-10 (Critical)"]
        P2["argo-cd-devmc-cmc-goldilocks-repository<br/>Exp: 2026-06-01 (Warning)"]
        P3["argo-cd-accmc-cmc-goldilocks-repository<br/>Exp: 2026-06-01 (Warning)"]
        P4["argo-cd-prdmc-cmc-goldilocks-repository<br/>Exp: 2026-06-01 (Warning)"]
    end

    subgraph SBX["Sandbox AKS — vpp-aks01-d (sub 7b1ba02e-...)"]
        SBXSEC["Secret repo-NNNNNNNNNN<br/>(Opaque, argocd ns)<br/>→ VPP.GitOps"]
        SBXAPPSET["ApplicationSet<br/>vpp-feature-branch-environments"]
        SBXAPPSET --> SBXSEC
    end

    subgraph MCDEV["dev-MC ArgoCD [PENDING: cluster name]"]
        MCDEVSEC["Repo secret [PENDING: name]<br/>→ cmc-goldilocks repo"]
    end

    subgraph MCACC["acc-MC ArgoCD [PENDING: cluster name]"]
        MCACCSEC["Repo secret [PENDING: name]<br/>→ cmc-goldilocks repo"]
    end

    subgraph MCPRD["prd-MC ArgoCD [PENDING: cluster name]"]
        MCPRDSEC["Repo secret [PENDING: name]<br/>→ cmc-goldilocks repo"]
    end

    P1 -->|direct kubectl patch| SBXSEC
    P2 -->|"[PENDING: ESO? CSI? IaC?]"| MCDEVSEC
    P3 -->|"[PENDING: ESO? CSI? IaC?]"| MCACCSEC
    P4 -->|"[PENDING: ESO? CSI? IaC?]"| MCPRDSEC

    classDef expired fill:#ff6b6b,stroke:#c92a2a,color:#fff
    classDef warning fill:#ffd43b,stroke:#f08c00,color:#000
    classDef pending fill:#e9ecef,stroke:#868e96,color:#000

    class P1 expired
    class P2,P3,P4 warning
    class MCDEV,MCACC,MCPRD,MCDEVSEC,MCACCSEC,MCPRDSEC pending
```

## V2 — Mermaid: Section A rotation flow (sandbox PAT)

```mermaid
sequenceDiagram
    autonumber
    participant Op as On-call (Alex)
    participant ADO as Azure DevOps
    participant Cluster as Sandbox AKS<br/>(vpp-aks01-d)
    participant AppSet as ApplicationSet<br/>vpp-feature-branch-environments
    participant Repo as VPP.GitOps repo

    Op->>Cluster: Step 1: az aks get-credentials<br/>kubectl config use-context vpp-aks01-d
    Op->>Cluster: Step 2: list secrets, find repo-NNNNNNNNNN<br/>(URL contains VPP.GitOps)
    Op->>ADO: Step 3: Mint PAT for sa_platform_vpp<br/>scope=Code Read, expiry=+1y
    ADO-->>Op: New PAT (52 chars)
    Op->>Repo: Step 4: curl -u :PAT URL/info/refs<br/>expect HTTP 200
    Repo-->>Op: HTTP 200 (PAT valid)
    Op->>Cluster: Step 5: kubectl patch secret<br/>(replace /data/password)
    Op->>AppSet: Step 6: kubectl annotate<br/>argocd.argoproj.io/refresh=hard
    AppSet->>Repo: Re-fetch feature-branch-environments/*.yaml<br/>(with new PAT)
    Repo-->>AppSet: 200 OK
    AppSet->>Cluster: ErrorOccurred=False (≤90s)
    Cluster->>Cluster: Step 7: child Application CRDs<br/>materialize in {slot} ns
    Op->>Op: Step 8: curl https://{slot}.dev.vpp.eneco.com/<br/>expect HTTP/2 200 + Request-Context header
    Op->>Op: Step 9: document rotation in vault
```

## V3 — Mermaid: Section B propagation candidates (MC PATs)

```mermaid
flowchart LR
    subgraph SoT["Source of Truth"]
        ADO["Azure DevOps PAT<br/>(minted in UI)"]
        KV["KeyVault vpp-appsec-d<br/>argocd-repository-credentials-<br/>template-url-{env}"]
    end

    subgraph SyncMech["KV → Cluster Sync Mechanism — [PENDING: which?]"]
        ESO["External Secrets Operator<br/>(ExternalSecret CRD)"]
        CSI["Azure KV CSI Driver<br/>(SecretProviderClass)"]
        IaC["Terraform IaC<br/>(kubernetes_secret + data.azurerm_key_vault_secret)"]
        Manual["Manual kubectl patch<br/>(like sandbox)"]
    end

    subgraph Target["Target Cluster (per MC env)"]
        ClusterSec["Repo Secret in argocd ns<br/>(name [PENDING])"]
    end

    ADO -->|"Op: Mint PAT"| KV
    KV -->|"Op: az keyvault secret set"| ESO
    KV --> CSI
    KV --> IaC
    ADO -.->|"if Manual"| Manual
    ESO --> ClusterSec
    CSI --> ClusterSec
    IaC --> ClusterSec
    Manual --> ClusterSec

    classDef pending fill:#e9ecef,stroke:#868e96,color:#000
    class SyncMech,ESO,CSI,IaC,Manual,ClusterSec pending
```

## V4 — ASCII: Step-by-step decision tree (sandbox)

```
[Start]
   │
   ▼
[CONFIRM PRE-CONDITIONS]
   │  • You have ADO impersonation rights for sa_platform_vpp@eneco.com
   │  • You can kubectl edit secrets in argocd ns of vpp-aks01-d
   │  • The 5 empirical signatures from the pattern doc all match
   │
   ├── NO ────► STOP. Escalate in #myriad-platform.
   │
   ▼ YES
[STEP 1: kubectl context = vpp-aks01-d?]
   ├── NO ────► STOP. Fix context first.
   │
   ▼ YES
[STEP 2: locate repo-NNNNNNNNNN (URL contains VPP.GitOps)]
   ├── 0 matches ────► No legacy repo-* Opaque. Check argocd-cm declarative repos.
   │
   ▼ exactly 1 match
[STEP 3: mint PAT in ADO]
   │  • Name: argo-cd-sandbox-YYYY-MM-DD
   │  • Org:  enecomanagedcloud
   │  • Exp:  +1 year
   │  • Scope: Code Read only
   │  • COPY at mint time
   │
   ▼
[STEP 4: curl test ⇒ HTTP 200?]
   ├── 401/403 ────► PAT invalid or scope wrong. Re-mint. DO NOT proceed.
   │
   ▼ HTTP 200
[STEP 5: kubectl patch secret /data/password ⇒ wc -c shows 52]
   │  (AskUserQuestion BEFORE; defense-in-depth name guard on repo-*)
   │
   ▼
[STEP 6: annotate refresh=hard; watch ErrorOccurred for ≤90s]
   ├── still True after 90s ────► Re-check Step 4. Possibly second secret with stale cred.
   │
   ▼ ErrorOccurred=False with fresh lastTransitionTime
[STEP 7: child Applications materialize in slot ns (≥10 in 2 min)]
   │
   ▼
[STEP 8: curl https://{slot}.dev.vpp.eneco.com/ ⇒ HTTP/2 200 + correlation headers]
   ├── 404/503 ────► Wait 5 min. If still bad, re-check Step 7.
   │
   ▼ healthy
[STEP 9: document rotation in vault incident page]
   │  • Timestamp
   │  • New expiry date
   │  • Anything unexpected during recovery
   │
   ▼
[DONE]
```

## V5 — ASCII: Mental model (the silent-failure chain)

```
   ┌──────────────────────────────────────────────────────────┐
   │ 1. PAT lifetime: 12 months (ADO max). Expiry is silent.  │
   └──────────────────────────────────────────────────────────┘
                              │
                              ▼
   ┌──────────────────────────────────────────────────────────┐
   │ 2. PAT-expiry report posts in #myriad-alerts-devops      │
   │    (alert exists, SLA does not).                         │
   └──────────────────────────────────────────────────────────┘
                              │
                              ▼  if not actioned in time
   ┌──────────────────────────────────────────────────────────┐
   │ 3. ApplicationSet Git generator → ADO 401 every 3 min.   │
   │    Status condition records ErrorOccurred=True.          │
   │    No alert fires (this condition is INFORMATIONAL).     │
   └──────────────────────────────────────────────────────────┘
                              │
                              ▼  developer triggers FBE-create
   ┌──────────────────────────────────────────────────────────┐
   │ 4. Pipeline 2412 succeeds Stages 1-6.                    │
   │    Stage 6 commits to VPP.GitOps cleanly.                │
   │    ArgoCD CAN'T read the commit (auth dead).             │
   │    Stage 7 Pester: namespace=PASS, pods=FAIL, URL=FAIL.  │
   │    Pipeline result: partiallySucceeded.                  │
   │    Slack post: "Infra Tests: 1/4 Success".               │
   └──────────────────────────────────────────────────────────┘
                              │
                              ▼  developer thinks "FBE broken"
   ┌──────────────────────────────────────────────────────────┐
   │ 5. Surface signal points at downstream services.         │
   │    True root cause: ApplicationSet condition (NOT in     │
   │    any first-look runbook). 30-60 min to diagnose        │
   │    without the pattern; 5 min with this doc.             │
   └──────────────────────────────────────────────────────────┘
```

## V6 — Mermaid: Automation proposal options decision tree

```mermaid
flowchart TD
    Start[Where are we?] --> Q1{Is KV+ESO already<br/>deployed in MC?}
    Q1 -->|YES| OptB[Option B: KV+ESO+scheduled rotation<br/>~7-10 days eng cost<br/>Familiar pattern]
    Q1 -->|NO| Q2{Is ADO Workload<br/>Identity Federation<br/>GA in our tenant?}
    Q2 -->|YES| OptA[Option A: WIF replaces PATs<br/>~10-15 days eng cost<br/>Eliminates PAT class]
    Q2 -->|NO| OptC[Option C: Status quo + SLA + Grafana alert<br/>~1-3 days eng cost<br/>Buys time]
    Q1 -->|UNKNOWN| Sidecar[Resolve via IaC sidecar<br/>before deciding]
    Q2 -->|UNKNOWN| Sidecar
    Sidecar --> Q1

    OptA -.->|"as Phase 1: do Option C anyway<br/>(takes 1-3 days; high MTTD impact)"| OptC
    OptB -.->|"as Phase 1: do Option C anyway"| OptC
```

## V7 — ASCII: gap-list-to-questions extractor

```
┌───────────────────────────────────────────────────────────┐
│ The PENDING list (extracted from how-to-rotate.md         │
│ Section B + automation proposal):                         │
├───────────────────────────────────────────────────────────┤
│ Group A: MC cluster topology                              │
│   Q1. Cluster names + AKS/OpenShift + RG + subscription   │
│   Q2. ArgoCD namespace per env                            │
│   Q3. Repo Secret naming pattern                          │
├───────────────────────────────────────────────────────────┤
│ Group B: KV → cluster sync                                │
│   Q4. Mechanism (ESO / CSI / IaC / manual)?               │
│   Q5. Sandbox PAT in vpp-appsec-d KV too, or only cluster?│
│   Q6. Per-env KVs for acc/prd, or single dev KV?          │
├───────────────────────────────────────────────────────────┤
│ Group C: Repository identity                              │
│   Q7. What is cmc-goldilocks? URL? Content?               │
│   Q8. Required PAT scopes (only Code Read?)?              │
├───────────────────────────────────────────────────────────┤
│ Group D: Operational policy                               │
│   Q9. Who has authority to mint sa_platform_vpp PATs?     │
│   Q10. Is there a written rotation SLA?                   │
├───────────────────────────────────────────────────────────┤
│ Group E: Automation                                       │
│   Q11. Who/what generates the PAT-expiry report?          │
└───────────────────────────────────────────────────────────┘

Hand to Fabrizio as one focused message in #myriad-platform.
```
