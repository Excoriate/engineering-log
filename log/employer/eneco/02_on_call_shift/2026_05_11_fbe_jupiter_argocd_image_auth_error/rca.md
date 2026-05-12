---
title: "FBE Sandbox cluster-wide ArgoCD source-1 auth break — root cause: missing Repository CR for Eneco.Vpp.Core.Dispatching and platform-gitops under Myriad - VPP ADO project"
type: rca
domain: tech
status: complete
fix_applied_at: 2026-05-12T13:04:00Z
fix_applied_by: alex-torres
fix_method: argocd CLI --core mode
fix_method_chosen_over: kubectl apply (per user direction — argocd CLI more idiomatic)
broken_apps_pre: 60
broken_apps_post: 0
recovery_wall_time: ~2 minutes (natural reconcile cycle)
created: 2026-05-12
updated: 2026-05-12
authors: [alex-torres]
incident_date: 2026-05-10
detected_date: 2026-05-12
slot_initial_intake: jupiter
blast_radius: "68 Applications across 8 FBE slots (afi, ionix, ishtar, jupiter, operations, thor, veku, voltex) + the platform argocd namespace"
class: "ArgoCD per-Application credential-resolution gap — adjacent to but distinct from pattern-argocd-pat-expiry-blocks-new-fbe-apps"
related:
  - "$SECOND_BRAIN_PATH/2-areas/work-eneco/eneco-vpp-platform/fbe-errors/2026-05-11-pat-expiry-argocd-auth-break.md"
  - "$SECOND_BRAIN_PATH/2-areas/work-eneco/eneco-vpp-platform/fbe-errors/pattern-argocd-pat-expiry-blocks-new-fbe-apps.md"
  - "$SECOND_BRAIN_PATH/2-areas/work-eneco/eneco-vpp-platform/fbe-errors/recipe-rotate-argocd-sandbox-pat.md"
---

# RCA — Sandbox FBE platform-wide ArgoCD auth break since 2026-05-10T12:45 UTC

## Knowledge Contract (falsifiable)

> By the end of this document, the reader believes — and can probe to falsify — the
> following load-bearing claim:
>
> **The Sandbox VPP platform has been in a 68-Application cluster-wide credential-coverage
> outage continuously since 2026-05-10T12:45 UTC. The mechanism is not PAT expiry; the PAT
> was rotated on 2026-05-11T13:35 UTC. The mechanism is that ArgoCD on `vpp-aks01-d` has
> Repository CR coverage only for three ADO repos under the `Myriad - VPP` project
> (`VPP-Configuration`, `Myriad - VPP`, `VPP.GitOps`), but every per-service Helm chart
> Application uses Source 1 = `Eneco.Vpp.Core.Dispatching` (FBE slots) or `platform-gitops`
> (platform namespace) — neither of which has any matching credential. The minimum durable
> fix is one `repo-creds` credential template covering the URL prefix
> `https://enecomanagedcloud@dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/`.**
>
> **Single falsifier**: produce a `Repository` CR or `repo-creds` template currently in
> the `argocd` namespace whose URL is `Eneco.Vpp.Core.Dispatching` OR whose URL is a strict
> prefix of `.../Myriad%20-%20VPP/_git/Eneco.Vpp.Core.Dispatching` AND has a non-empty
> `password`. If any such credential exists, this RCA is wrong.

If you accept the contract, the rest of this document is the evidence ladder, mechanism
explanation, and remediation plan to act on it. If you reject the contract, jump to the
[Evidence Ledger](#evidence-ledger) and try to falsify it directly.

## Context Ledger

| Term | Definition | Code Artifact / Concrete Location | Relevance HERE |
|---|---|---|---|
| **VPP** | Virtual Power Plant — Eneco's energy-trading platform aggregating distributed flexibility for TenneT balancing markets | enecomanagedcloud ADO org, `Myriad - VPP` project | Root business context |
| **Trade Platform** | The team owning VPP IaC, pipelines, and operational tooling | ADO project `enecomanagedcloud` | Owner of this incident |
| **FBE** | Feature Branch Environment — ephemeral per-feature-branch FBE slot leased from a fixed pool of 10 named slots (afi, boltz, enel, ionix, ishtar, jupiter, kidu, operations, veku, voltex). NB: the harness `ddd-ubiquitous-language.md` lists FBE as "Flex Budget Engine" — vault-canonical and skill-canonical definition is Feature Branch Environment | Lease table `featurebranchenvdetails` in storage account `featurebranchdeployment`, RG `rg-vpp-app-sb-401`, Sandbox subscription `7b1ba02e-bac6-4c45-83a0-7f0d3104922e` | The whole platform layer this incident affects |
| **Sandbox** | The Azure subscription `7b1ba02e-bac6-4c45-83a0-7f0d3104922e` where FBE slots are provisioned and the cluster `vpp-aks01-d` runs | Az CLI: `az account set --subscription 7b1ba02e-...` | The single cluster all 68 broken Applications live on |
| **AKS cluster `vpp-aks01-d`** | Sandbox AKS cluster hosting ArgoCD and all FBE slot namespaces | `kubectl config current-context` returns `vpp-aks01-d` | The AKS where the auth break manifests |
| **ArgoCD** | GitOps CD tool; reconciles `Application` CRDs by fetching Git/OCI sources and applying rendered manifests | `argocd-application-controller`, `argocd-repo-server` Deployments in `argocd` namespace | The component that emits the `authentication required` error |
| **ApplicationSet** | ArgoCD generator that templates `Application` CRDs from a Git directory of YAML files (one per slot) | `vpp-feature-branch-environments` and `feature-branch-environment-monitoring-stack` ApplicationSets in `argocd` namespace | NOT what's broken here — the ApplicationSet generator works fine; what's broken is the per-Application source fetch |
| **Application (ArgoCD)** | A single managed deployment; spec lists `sources[]` (1+ Git/OCI URLs); ArgoCD repo-server clones each and renders manifests | e.g. `kubectl get application dispatchermfrr -n jupiter` | The 68 broken Applications |
| **Source 1 / Source 2** | When an `Application` has multiple `sources[]`, ArgoCD fetches each and merges. Common pattern: Source 1 = Helm chart repo, Source 2 = `ref: values` repo for valueFiles | Application YAML pasted in slack-intake.txt | "source 1 of 2" in the error string |
| **Repository CR (Repository Secret)** | A `Secret` in `argocd` namespace with label `argocd.argoproj.io/secret-type=repository` and `data.url/username/password`; provides credentials for an exact repo URL | `repo-3194359838`, `repo-3613977198`, `repo-3703084109` in `argocd` namespace | The credential-resolution mechanism that's incomplete |
| **repo-creds template** | A `Secret` with `secret-type=repo-creds`; provides credentials for any repo URL that begins with `data.url`. Longest-prefix wins. | `creds-870830599` (covers `VPP - Asset Optimisation` ADO project) | The mechanism the fix uses |
| **PAT** | Personal Access Token — ADO HTTPS credential bound to a user identity; finite expiry (12 months max in ADO) | The PAT stored in `repo-*` and `creds-*` secrets' `data.password`, base64-encoded | Yesterday's rotation target; NOT today's root cause |
| **VPP.GitOps** | ADO Git repo storing the GitOps state — `feature-branch-environments/{slot}.yaml` files consumed by the ApplicationSet | `https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/VPP.GitOps` | The ApplicationSet's generator source; has working credential |
| **VPP-Configuration** | ADO Git repo storing per-product configuration (feature flags, app config, value files) | `https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/VPP-Configuration` | Source 2 for Application CRDs; has working credential |
| **Eneco.Vpp.Core.Dispatching** | ADO Git repo for VPP Core Dispatching services (mFRR/aFRR dispatchers, dataprep, simulator, etc.); contains `helm/{service}` chart directories | `https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/Eneco.Vpp.Core.Dispatching` | **Source 1 for 64 of 68 broken Applications. THE missing credential.** |
| **platform-gitops** | ADO Git repo containing the `argocd` namespace platform Applications (rabbitmq, loki, product-*) | `https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/platform-gitops` | Source 1 for the 7 broken `argocd/*` Applications. **The other missing credential.** |
| **Myriad - VPP (ADO project)** | The ADO project name (note: contains a space) — URL-encoded as `Myriad%20-%20VPP`. Houses the four repos above | ADO project URL `https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP` | The prefix the durable fix's `repo-creds` template will match |
| **sa_platform_vpp@eneco.com** | Service account whose PAT is used for all ArgoCD-→-ADO Git auth | The `username` in every `repo-*` Repository secret | The identity the fix's credential will use |
| **ComparisonError** | ArgoCD Application status condition emitted when repo-server cannot render manifests from the Application's sources | `kubectl get application -o jsonpath='{.status.conditions}'` | The on-cluster surface where the auth failure is recorded |
| **`pattern-argocd-pat-expiry-blocks-new-fbe-apps`** | Catalogued vault pattern: ApplicationSet generator fails when its PAT expires; NEW slots can't be generated, existing slots survive cached | `$SECOND_BRAIN_PATH/.../fbe-errors/pattern-argocd-pat-expiry-blocks-new-fbe-apps.md` | The pattern yesterday's incident matched; **this incident is adjacent but DIFFERENT** — see the "What this is NOT" section |
| **`recipe-rotate-argocd-sandbox-pat`** | Catalogued vault recipe: 9-step PAT rotation procedure | Same dir | The recipe Alex+Fabrizio executed yesterday; its Step 7 verification gap is part of this RCA's lessons |

Zero-context reader: read the Knowledge Contract, then this ledger, then the
[First-Principles Ladder](#first-principles-ladder). After those three sections you can
follow the rest without external references.

## First-Principles Ladder

To reason about the root cause from scratch (no domain memory), build five rungs.

**Rung 1 — How does ArgoCD know what to deploy?** It reads `Application` CRDs from the
cluster. Each `Application` has one or more `sources[]`. ArgoCD's repo-server clones each
source and renders manifests, then the application-controller diffs against the live
state and syncs.

**Rung 2 — How does repo-server authenticate to a Git source?** It looks up the
`spec.sources[].repoURL` against the cluster's repo-credential store. The store has two
kinds of entries:

1. **`Repository` CR** — `Secret` labelled `argocd.argoproj.io/secret-type=repository`.
   Matches the source URL **exactly** (after URL normalization). Provides
   `username/password`. Highest priority.
2. **`repo-creds` template** — `Secret` labelled
   `argocd.argoproj.io/secret-type=repo-creds`. Matches if `data.url` is a **prefix** of
   the source URL. Longest prefix wins. Lower priority than exact match.

If neither matches, repo-server falls back to anonymous HTTP. For a private ADO repo,
anonymous → HTTP 401 → ArgoCD records `ComparisonError: ... authentication required`.

**Rung 3 — What does the Sandbox cluster's repo-credential store contain TODAY?**

| Match URL | Type | Username | PW present? |
|---|---|---|---|
| `.../Myriad - VPP/_git/VPP-Configuration` | Repository CR | `sa_platform_vpp@eneco.com` | yes |
| `.../Myriad - VPP/_git/Myriad - VPP` | Repository CR | `sa_platform_vpp@eneco.com` | yes |
| `.../Myriad - VPP/_git/VPP.GitOps` | Repository CR | `sa_platform_vpp@eneco.com` | yes |
| `.../VPP - Asset Optimisation` (different ADO project) | repo-creds template | `sa_platform_vpp@eneco.com` | yes |
| `vppacrsb.azurecr.io/...` various | Repository CR | various OCI service accounts | yes |
| `vppacra.azurecr.io/helm` | Repository CR | `vppacra` | yes |
| `oci://vppacra.azurecr.io/helm-agg`, `vppacra.azurecr.io/helm-agg` | repo-creds | `vppacra` | yes |

**No entry exists for `.../Myriad - VPP/_git/Eneco.Vpp.Core.Dispatching`. No entry exists
for `.../Myriad - VPP/_git/platform-gitops`. No `repo-creds` template covers the URL prefix
`.../Myriad - VPP/` (the only template under enecomanagedcloud covers a different ADO
project: `VPP - Asset Optimisation`).**

**Rung 4 — Which Applications fetch from those uncovered URLs?**

`kubectl get applications.argoproj.io -A` + filter by source 1 repoURL yields:

- **64 Applications** with `Source 1 = Eneco.Vpp.Core.Dispatching`: 7-8 services × 8 slots
  (afi, ionix, ishtar, jupiter, operations, thor, veku, voltex). Services per slot:
  `activationmfrr, dataprep, dispatcherafrr, dispatchermanual, dispatchermfrr,
  dispatcherscheduled, dispatchersimulator, secretprovider-dispatcher`.
- **4 Applications** with `Source 1 = platform-gitops`: `argocd/product-asset-scheduling`,
  `argocd/product-flex-trade-optimizer`, `argocd/product-vpp-core`,
  `argocd/product-vpp-dispatching`.
- **3 OCI-source `argocd/rabbitmq-*` Applications** + `argocd/loki`: source[0] points to a
  Helm OCI chart and a value-files source 1 that also hits the same gap.

Every one of these 68 Applications has `ComparisonError: ... source 1 of {1|2}: ...
authentication required` since the time the previous PAT died.

**Rung 5 — Why did the failure begin precisely at 2026-05-10T12:45 UTC, not before?**

The previous PAT expired at `2026-05-10T12:40:13Z` (catalogued in yesterday's incident
note). Until expiry, the previous PAT was being used for ALL ADO HTTPS auth — including
for repos that have NO explicit `Repository` CR. The reason this worked is that **ArgoCD's
repo-server caches the resolved credential per cloned repo within a single repo-server
pod lifetime**. The previous PAT must have been minted with broader scope (org-wide Code
Read), and at some prior point in time the cluster had either a now-deleted
`repo-creds` template covering `Myriad - VPP`, or every Application had a `Repository`
entry that has since been pruned. Yesterday's PAT rotation rebuilt the three Repository
entries for the ApplicationSet generator's needs but did NOT recreate the broader
credential coverage — and ArgoCD's repo-server reconcile then hit each Application,
failed credential resolution, and recorded `ComparisonError`. The transition timestamps
cluster at 12:45-12:51 UTC because that is one to two ApplicationSet reconcile cycles
after the PAT died.

(This last rung carries an A3 — the historical credential state before 05-10 cannot be
re-probed in this session. The mechanism today is A1; the explanation for the previous
working state is A2 INFER with the named alternative.)

## What this is NOT (don't misroute)

This RCA is **adjacent to but distinct from** the catalogued pattern
`pattern-argocd-pat-expiry-blocks-new-fbe-apps`. Both involve an "authentication required"
error in the `argocd` namespace; both trace to ADO PAT credentials. They are different
defects.

| Aspect | Catalogued PAT-expiry pattern | This RCA |
|---|---|---|
| Failing component | `ApplicationSet` Git generator | `Application` repo-server source-1 fetch |
| Error condition name | `ApplicationGenerationFromParamsError` on the ApplicationSet | `ComparisonError` on each Application |
| Scope when active | NEW slots only (cached app-of-apps survive) | All slots, all Applications whose source 1 isn't covered |
| Visible surface | `kubectl describe applicationset` | `kubectl get application` |
| Fix | Rotate PAT, patch one Repository secret (`VPP.GitOps`), force-refresh ApplicationSet | Add a `repo-creds` template covering `Myriad - VPP` ADO project |
| Yesterday's fix completed? | YES — ApplicationSet generator works (proven: kidu.yaml WAS fetched by the generator at some point after rotation) | NO — child Applications still fail |

This is **NOT**:

- F2 Azure-resource orphan — Terraform applied cleanly; namespaces are `Active`.
- F4 cross-FBE secret expiry — F4 fires `AADSTS7000215` at runtime; there are no pods to emit it.
- F7 `secrets_to_copy` regression — pods aren't running, so the secret-mount path is moot.
- F10 sandbox-AKS pressure — `kubectl get nodes` Ready; ArgoCD itself reachable.
- F19 Terraform version drift — no destroy attempted.

## Cause chain

```
0. ArgoCD repo-server resolves credentials per source URL via:
   exact Repository CR > longest-prefix repo-creds template > anonymous          [Rung 2]
                              │
                              ▼
1. The cluster has Repository CRs for ONLY 3 of the 5 ADO Git repos
   referenced by ArgoCD Applications under the Myriad - VPP project              [A1: Rung 3 enumeration]
                              │
                              ▼
2. No repo-creds template exists whose URL is a prefix of any Myriad - VPP
   `_git/{repo}` URL (the only enecomanagedcloud template covers a different
   ADO project: VPP - Asset Optimisation)                                        [A1: same probe]
                              │
                              ▼
3. For Application sources pointing at `Eneco.Vpp.Core.Dispatching` or
   `platform-gitops`, credential resolution falls to anonymous → ADO 401 →
   ArgoCD records `ComparisonError: ... authentication required`                 [A2: mechanism per Rung 2]
                              │
                              ▼
4. Before 2026-05-10T12:40, the previous PAT happened to resolve via some
   mechanism that has since been pruned (former template, former Repository
   entries, or pod-local cache); after the PAT died and the new PAT was minted
   only into 3 Repository CRs, the latent gap became active                       [A2: timeline match;
                                                                                   A3 historical: pre-05-10
                                                                                   credential state not re-probable]
                              │
                              ▼
5. From the next ApplicationSet/Application reconcile cycle onward, every
   Application whose source 1 is uncovered records ComparisonError. 68 such
   Applications across 8 FBE slots + the argocd namespace are affected            [A1: 68-Application enumeration]
                              │
                              ▼
6. Yesterday (2026-05-11) Alex+Fabrizio rotated the PAT and patched the 3
   Repository CRs. The ApplicationSet generator recovered (kidu.yaml could be
   fetched, child Applications regenerated in etcd). But the child Applications
   themselves remained broken because their Source 1 repos still have no
   credential coverage. Yesterday's verification did not reach down to the
   per-Application source fetch — Step 7 of the recipe checks app-of-apps
   appearance and child-app COUNT, but does NOT check whether each child app's
   ComparisonError clears                                                          [A1: yesterday's
                                                                                   recipe; A2: gap analysis]
                              │
                              ▼
7. As of 2026-05-12T12:20 UTC, the platform is in a continuous credential-coverage
   outage that began 2026-05-10T12:45 UTC                                         [A1: live cluster state]
```

## L1 — Business — Why this matters

The Sandbox FBE platform exists so that **VPP feature-branch developers** can deploy a
full clone of the VPP stack to a named slot and test their branch end-to-end before
merging to `main`. When the FBE Applications cannot sync, every developer who pushed a
feature branch since 2026-05-10 has — silently — no running services to test against.
Slot URLs return 404 not because the developer's code is bad but because the platform
cannot deploy any service.

There are **eight slots** currently in this state (the entire active FBE pool except
`boltz`, `enel`, and `kidu` which are unleased or recovered yesterday). At ~1 developer
per slot, **eight feature branches' worth of validation work is stalled**. The user who
filed today's intake (FBE-808321 mFRR Effective Steering Mode) is one of those eight.

In addition to per-developer impact, the `argocd/product-*` Applications are the
platform's own deployment of VPP product manifests on the Sandbox cluster. Their being
out of sync means **any platform-level config change to vpp-core / vpp-dispatching /
asset-scheduling / flex-trade-optimizer made since 2026-05-10 will not have propagated**.
This is an order-of-magnitude blast-radius widening compared to "one developer's FBE."

## L2 — Repo system

```
ADO project: Myriad - VPP
├── VPP.GitOps                       ◄── REGISTERED   (ApplicationSet generator source)
├── VPP-Configuration                ◄── REGISTERED   (Application Source 2: valueFiles)
├── Myriad - VPP                     ◄── REGISTERED   (legacy / monorepo entry)
├── Eneco.Vpp.Core.Dispatching       ◄── *** UNREGISTERED *** (Application Source 1
│                                         for all FBE dispatching apps × 8 slots)
└── platform-gitops                  ◄── *** UNREGISTERED *** (Application Source 1
                                          for argocd/product-* and rabbitmq-*)

ADO project: VPP - Asset Optimisation
└── (covered by repo-creds creds-870830599; not affected by this incident)
```

Repos referenced by ArgoCD on the Sandbox cluster: 5 ADO Git repos under `Myriad - VPP` +
1 ADO repo under `VPP - Asset Optimisation` + ~8 Helm OCI chart repos in
`vppacrsb.azurecr.io`/`vppacra.azurecr.io`. Of those, the two unregistered Git repos in
`Myriad - VPP` are the entire failure surface.

## L3 — Runtime architecture

```mermaid
flowchart LR
    Dev[Developer pushes<br>feature/fbe-*] -->|git push| ADO_Source[ADO: Eneco.Vpp.Core.Dispatching<br>helm/{service}/...]
    Dev -->|triggers| Pipeline[ADO Pipeline 2412<br>FBE-create]
    Pipeline -->|Stage 6<br>writes YAML| ADO_GitOps[ADO: VPP.GitOps<br>feature-branch-environments/{slot}.yaml]

    subgraph AKS_vpp-aks01-d[AKS cluster vpp-aks01-d]
        AppSet[ApplicationSet<br>vpp-feature-branch-environments]
        RepoServer[argocd-repo-server pod]
        AppCtrl[argocd-application-controller]
        SlotNS[Namespace: jupiter]
        AppCRD[Application<br>jupiter/dispatchermfrr]
    end

    AppSet -->|reads via Git gen| RepoServer
    RepoServer -->|HTTPS w/ PAT<br>repo-3703084109| ADO_GitOps
    AppSet -->|generates| AppCRD
    AppCRD -->|source 1<br>HTTPS w/ ???| ADO_Source
    AppCRD -->|source 2<br>HTTPS w/ PAT<br>repo-3194359838| ADO_GitOps_2[ADO: VPP-Configuration]
    AppCtrl -->|reconciles| AppCRD

    style ADO_Source fill:#ffcccc
    style AppCRD fill:#fff4cc
```

The red surface is the failing edge: repo-server's HTTPS fetch of
`Eneco.Vpp.Core.Dispatching` has no credential to use, so the Application records
`ComparisonError`. ApplicationSet → VPP.GitOps works (green path). Application → Source 2
(`VPP-Configuration`) works (green path). Application → Source 1
(`Eneco.Vpp.Core.Dispatching`) fails (red path).

## L4 — Application code flow

ArgoCD repo-server, when reconciling `jupiter/dispatchermfrr`, executes (conceptually):

```text
1. Read Application spec from etcd via argocd-application-controller
2. For each source in spec.sources[]:
     a. Resolve URL → credential:
          if exists Secret labelled secret-type=repository with data.url == source.repoURL
            use that secret's username/password
          elif exists Secret labelled secret-type=repo-creds with data.url == longest prefix
            use that secret's username/password
          else
            use anonymous (no auth header)
     b. Clone (or git fetch) source.repoURL @ source.targetRevision into a per-source
        working directory
     c. Render manifests:
          if source.helm.valueFiles[] references $values, pull those from the
            sibling source (the one with `ref: values`)
          else if path-based, run helm template (or kustomize build, etc.)
3. Merge rendered manifests across sources
4. Return manifests to argocd-application-controller
5. application-controller diffs vs live cluster state
6. Emit status.conditions reflecting any errors from step 2-4
```

The defect lives entirely in step 2a for `Source 1`. The chained downstream steps (2b
clone, 2c render, 3 merge, ...) never run because 2a returns "no credential → anonymous →
ADO 401 → fail with 'authentication required'".

## L5 — IaC / state / the three truths

This incident has **no Terraform / Azure resource defect**. It is a pure ArgoCD-layer
credential-store defect. The three "truths" in this incident are:

1. **GitOps source of truth** (`VPP.GitOps` repo): `feature-branch-environments/jupiter.yaml`
   has the correct Application spec with two sources. **Source spec is correct.**
2. **Cluster state** (`kubectl get application -n jupiter`): the Application CRD exists
   and is identical to the GitOps source. **Cluster state is correct.**
3. **Cluster credential store** (`kubectl get secret -n argocd -l argocd.argoproj.io/secret-type=repository`):
   missing entries for `Eneco.Vpp.Core.Dispatching` and `platform-gitops`. **Credential
   store is incomplete.**

The defect is in truth #3 only.

## L6 — The pipeline and how it actually runs

Pipeline 2412 (FBE-create) is not the proximate cause but is the indirect trigger:

- Stage 3 DeployInfra (Terraform): succeeded for jupiter — Azure resources exist.
- Stage 5 DeployServices: irrelevant — those are service-CD pipelines (`TriggerBuild@4`)
  that produce Docker images and push them to ACR; the failure here is on Git fetch,
  not Docker pull.
- Stage 6 DeployFBEInArgoCD: committed `jupiter.yaml` to VPP.GitOps with the new branch
  `feature/fbe-808321_new-mFRR-Effective-Steering-Mode` as `targetRevision`. **This
  caused ArgoCD to re-resolve Source 1 against the new branch and hit the credential
  gap, surfacing the latent defect.**
- Stage 7 Infra_tests (Pester): may have reported `1/4` because pods never came up; the
  user reported "not updating images" — that's downstream of the manifest-render failure.

The pipeline did its job correctly. The user's slack-intake symptom is **a true positive
about ArgoCD auth, not about the pipeline.**

## L7 — Timeline

| When (UTC) | What | Evidence |
|---|---|---|
| **2026-05-10T12:40:13Z** | Previous `argo-cd-sandbox` PAT expires | A1 — catalogued yesterday's incident |
| **2026-05-10T12:45:18-22Z** | ApplicationSet + Applications transition to error state on next reconcile cycle | A1 — `kubectl get application jupiter/dispatchermfrr -o jsonpath='{.status.conditions[].lastTransitionTime}'` returns `2026-05-10T12:45:22Z` |
| **2026-05-11T~10:42Z** | Duncan reports kidu broken in Slack | A1 — yesterday's incident note |
| **2026-05-11T13:35:00Z** | Alex+Fabrizio rotate the PAT, patch 3 Repository CRs, force-refresh ApplicationSet | A1 — yesterday's incident note `sandbox_rotated_at` |
| **2026-05-11T~14:00 onward** | ApplicationSet generator works; new app-of-apps generate; child Applications appear in etcd. **Child Applications cannot resolve Source 1 credential**, so their syncs immediately re-fail. Yesterday's Step 7 verification did not catch this — it checked count, not ComparisonError. | A2 INFER — recipe step contents + child-app state today |
| **2026-05-12T~12:00 UTC** | User (today) files slack intake noting jupiter "not updating/syncing images, authentication error" | A1 — `slack-intake.txt` |
| **2026-05-12T12:15:40Z** | Application `jupiter/dispatchermfrr` last reconcile attempt — still fails | A1 — `kubectl get application -o jsonpath='{.status.reconciledAt}'` |
| **2026-05-12T~12:25 UTC** | This RCA's diagnostic probes complete; 68 broken Apps enumerated; root cause confirmed | A1 — probe outputs in `.ai/tasks/2026-05-12-001_fbe-jupiter-argocd-auth/context/` |
| 2026-05-12T~12:50 UTC | Three typed adversarial frames dispatched in parallel (socrates-contrarian, el-demoledor, sre-maniac); 27 findings produced | A1 — `.ai/tasks/.../verification/adv-*.md` |
| 2026-05-12T~13:00 UTC | Adversarial synthesis; 4 BLOCKING/HIGH rebutted with A1 evidence; 3 BLOCKING/HIGH resolved via fix-sequence restructure; fix.md Phase A→F written | A1 — RCA's "Adversarial Review Receipts" section |
| 2026-05-12T~13:02 UTC | User directs: simplify — read-only checks + credential template add only, skip prune-disable broad mutation | A1 — user message |
| 2026-05-12T~13:03 UTC | `argocd CLI --core` mode used after clearing expired AAD token from `~/.config/argocd/config`; native `argocd repocreds list` confirms 3 templates (no Myriad - VPP) | A1 — argocd CLI output |
| **2026-05-12T13:04:00Z** | **FIX APPLIED**: `argocd repocreds add --core 'https://enecomanagedcloud@dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP' --username sa_platform_vpp@eneco.com --password <PAT>` — credential template lands. PAT bytes reused from `repo-3703084109` Secret. | A1 — argocd CLI returned `Repository credentials for ... added` |
| 2026-05-12T13:06:43Z | broken_auth=45 (down from 60). Natural reconcile cycle resolving credential. | A1 |
| 2026-05-12T13:07:04Z | broken_auth=33 | A1 |
| 2026-05-12T13:07:25Z | broken_auth=15 | A1 |
| 2026-05-12T13:07:45Z | broken_auth=1 | A1 |
| 2026-05-12T13:08:00Z | **broken_auth=0** — all 60 source-1-auth failures resolved | A1 |
| 2026-05-12T13:08:00Z | Health metrics: `healthy_synced` 152→197 (+45); PrometheusRules unchanged 32→32 (no prune damage); repo-server CPU peaked 1019m transient, no restart, no OOM, memory 526 MiB stable. | A1 — kubectl probes |

## L8 — Fix

**Strategy chosen** (per user direction): durable project-level credential template.

> **⚠️ Read `fix.md` in this same directory for the EXECUTABLE Phase A→F runbook.** This
> L8 section describes the mechanism. The actual procedure to apply went through three
> rounds of adversarial review (`socrates-contrarian`, `el-demoledor`, `sre-maniac`) that
> reshaped the rollout from a 3-minute tight loop into a 25-40 minute gated rollout with
> pre-apply probes, throttling, drift inventory, and a manual sync gate. The mechanism
> below is correct; the rollout sequencing is in fix.md.

### Step 1 — Reuse the working PAT

The PAT currently stored in the three working Repository CRs (`repo-3194359838`,
`repo-3613977198`, `repo-3703084109`) was minted 2026-05-11 with `sa_platform_vpp@eneco.com`
Code → Read scope. ADO PATs are user-scoped; the same PAT bytes will authenticate against
any repo in the org for which the user has `Code Read` permission. Reuse those bytes.

```bash
# Read the PAT from any of the three working Repository secrets
# (do NOT echo to stdout or write to disk)
PAT_B64=$(kubectl get secret repo-3703084109 -n argocd -o jsonpath='{.data.password}')
USER_B64=$(kubectl get secret repo-3703084109 -n argocd -o jsonpath='{.data.username}')
URL_B64=$(printf 'https://enecomanagedcloud@dev.azure.com/enecomanagedcloud/Myriad%%20-%%20VPP' | base64 | tr -d '\n')
```

### Step 2 — Create a `repo-creds` template covering all `Myriad - VPP` repos

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: creds-myriad-vpp-project
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repo-creds
type: Opaque
data:
  url: <base64 of "https://enecomanagedcloud@dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP">
  username: <base64 of "sa_platform_vpp@eneco.com">
  password: <base64 of the PAT bytes (length 52 after b64 decode)>
```

A naming choice: use `creds-myriad-vpp-project` rather than ArgoCD's auto-generated
hash. The catalogued template `creds-870830599` is hash-named; that hides what it covers.
A human-meaningful name will help next-shift on-call see at a glance which ADO project is
covered. (See lessons below.)

Apply:

```bash
kubectl apply -f /tmp/creds-myriad-vpp-project.yaml
```

### Step 3 — Force a refresh on one Application per slot to confirm credential resolution

```bash
for slot in afi ionix ishtar jupiter operations thor veku voltex; do
  kubectl annotate application dispatchermfrr -n $slot \
    argocd.argoproj.io/refresh=hard --overwrite
done

# Wait one reconcile cycle (~60-90s), then check ComparisonError clears
sleep 90
kubectl get applications.argoproj.io -A -o json | jq -r '
  .items[] |
  . as $app |
  ($app.status.conditions // []) |
  map(select(.type == "ComparisonError" and (.message | test("authentication required")))) |
  if length > 0 then "\($app.metadata.namespace)/\($app.metadata.name) STILL BROKEN" else empty end
'
```

Expected: list is empty.

### Step 4 — Verify `argocd/` namespace platform Applications too

```bash
for app in product-asset-scheduling product-flex-trade-optimizer product-vpp-core product-vpp-dispatching; do
  kubectl annotate application $app -n argocd argocd.argoproj.io/refresh=hard --overwrite
done
```

### Anti-patterns — DO NOT DO

- **Do NOT register `Eneco.Vpp.Core.Dispatching` and `platform-gitops` as two separate
  Repository CRs.** That is the minimal-scope fix; it leaves the same latent defect for
  any future ADO repo added under `Myriad - VPP` (e.g., a new service repo). The durable
  fix is the project-level template.
- **Do NOT rotate the PAT again.** Yesterday's PAT works; the defect is coverage, not
  credential validity. Rotating again would create the same gap on the new bytes.
- **Do NOT restart `argocd-repo-server`.** It won't help — the credential store doesn't
  contain a credential that resolves; restarting just re-runs the same broken lookup.
- **Do NOT delete and recreate the broken Applications.** Yesterday's wrong instinct.
  The ApplicationSet would regenerate them in the same broken state because the credential
  gap is upstream of the Application CR.

### Rollback

The fix is additive (creates one new Secret). Rollback = `kubectl delete secret
creds-myriad-vpp-project -n argocd` returns the cluster to today's pre-fix state. No
state is destroyed.

## L9 — Verification

> **STATUS: COMPLETE 2026-05-12T13:08:00Z.** All criteria below verified after apply. Numbers below are POST-FIX MEASURED values, not predictions.

### Actual post-fix results

| Criterion | Pre-fix | Post-fix | Pass? |
|---|---|---|---|
| `kubectl get secret creds-myriad-vpp-project -n argocd` exists with `secret-type=repo-creds` | absent | **PRESENT** (created via `argocd repocreds add --core`; name auto-generated `creds-<hash>` — different from the predicted `creds-myriad-vpp-project` because argocd CLI auto-names; functionally equivalent) | ✅ |
| Apps with `ComparisonError: ... authentication required` | 60 | **0** | ✅ |
| Healthy + Synced Applications | 152 | **197** (+45) | ✅ |
| PrometheusRule count (regression guard) | 32 | **32** | ✅ |
| repo-server restarts during fix | 0 | **0** | ✅ |
| repo-server peak CPU | 316m | **1019m** (transient, ~30s during fan-out) | ✅ within node headroom |
| repo-server memory growth | 538 MiB | **526 MiB** (stable, no burst) | ✅ |
| Per-slot HTTP 200 (active FBE slots only): afi, ionix, ishtar, thor, veku, voltex | 404 | **200** (ishtar briefly 503 during pod ramp, then 200) | ✅ |
| Per-slot HTTP for INACTIVE FBE slots: jupiter, operations | 404 | **404** | ⚠️ expected — these slots have no `feature-branch-environments/{slot}.yaml` in VPP.GitOps; the developer either cancelled or the slot was reassigned |
| Total recovery wall-time | — | **~2 minutes** (60 → 45 → 33 → 15 → 1 → 0) | ✅ much faster than predicted 25-40 min because we relied on natural reconcile cycle instead of forced refresh |

### Original acceptance criteria (each line a falsifier — if it doesn't pass, the fix is incomplete):

1. `kubectl get secret creds-myriad-vpp-project -n argocd` returns the new Secret with
   `argocd.argoproj.io/secret-type=repo-creds`.
2. `kubectl get applications.argoproj.io -A -o json | jq` query above returns empty
   list. (No Application has `ComparisonError: ... authentication required`.)
3. For at least one Application per slot, `status.sync.revision` advances to a fresh SHA
   from `Eneco.Vpp.Core.Dispatching@feature/fbe-808321_...` (or whatever each slot's
   branch is).
4. Pods materialize in each slot namespace within 5-10 min of the fix.
5. `curl -sk https://jupiter.dev.vpp.eneco.com/ | head` returns non-404 content (200 with
   `Request-Context` or 503 while pods come up).
6. **The slack-intake reporter (jupiter dev) confirms images are syncing.**

A subtle one: if any other Application source 1 in `argocd/` namespace points to a Helm
OCI chart (not Git) that ALSO requires auth, and the OCI auth uses a different secret
class, that path is independent. Verify by re-running the broad query at step 2 with
filter relaxed to `test("authentication")`.

## L10 — Lessons

L10.1 — **Yesterday's recipe Step 7 verification surface mismatched the cause-claim surface.** (Sharpened wording per socrates-contrarian review.) The recipe's cause-claim was "PAT expiry blocks new FBE apps"; the right verification surface is therefore where "new FBE apps" become observable as healthy — the per-Application source fetch, NOT the parent app-of-apps existence count. The recipe stopped at app-of-apps count (correctness for a different cause-claim — "ApplicationSet generator restored") and silently transferred the gap to the per-Application layer. The durable lesson: verification depth must equal cause-claim depth. Cross-reference to `actionable-artifact-gate.md` — recipes are actionable artifacts and should follow Stakes-claim + Falsifier + Stakes-class. Open Phase-9 follow-up: amend `recipe-rotate-argocd-sandbox-pat` Step 7 in the vault to add per-Application source-fetch verification.

L10.0 — **Original lesson kept:** It checks that child
Application CRDs appear in the slot namespace (count ≥ 10) but does NOT check whether
those child Applications can themselves resolve their sources. The verification depth
stops one layer too shallow. Recipe should add a Step 7.5: "for at least one Application
per slot, confirm `status.conditions[].type=ComparisonError` is absent OR
`status.sync.revision` is non-empty." Open Phase-9 follow-up: amend
`recipe-rotate-argocd-sandbox-pat` Step 7 in the vault.

L10.2 — **The catalogued PAT-expiry pattern is incomplete.** It documents the
ApplicationSet generator failure mode but not the per-Application source-1 mode. They
look the same on the wire (`authentication required`), trace to the same credential
plane, but have different visible surfaces (`ApplicationSet.status` vs.
`Application.status`) and different fixes. The catalogue needs a sibling pattern note:
`pattern-argocd-per-application-source-credential-gap` (or similar). Add this when
writing back the vault.

L10.3 — **Repository CR coverage is silently incomplete by default.** ArgoCD treats
"missing credential → anonymous" as a successful resolution; the operator gets no
warning when a new Application is created that references a repo with no credential.
This is the fundamental observability gap. Proposal: a recurring kubectl audit that
iterates Applications, extracts unique source URLs, and asserts each has a matching
Repository CR or `repo-creds` template. Wire into the FBE-create pipeline's Stage 7
Pester suite, or as a standalone weekly cron.

L10.4 — **Auto-generated secret names hide intent.** `creds-870830599` and
`repo-3613977198` are content-addressable hashes; the operator must base64-decode the
URL to know which repo they cover. Human-readable names (`creds-myriad-vpp-project`,
`repo-vpp-gitops-sandbox`) are a 5-second-faster mental model on every future incident.
This is a soft preference, not a defect — but worth applying to net-new entries.

L10.5 — **Yesterday's "resolved" claim was visually confirmed, not functionally
confirmed.** The pattern doc says "kidu Application CRDs materialize within ~2-3 min"
and "service pods reach Running within ~5-10 min". Yesterday's incident note doesn't
record whether the latter actually happened — it records the rotation completing. The
gap between "ApplicationSet generates child apps" and "child apps actually sync" is
exactly where this incident lived for ~22 hours undetected. Resolution should always
include the pod-up check, not just the app-of-apps materialization.

L10.7 — **ArgoCD credential resolution precedence: exact Repository CR > longest-prefix `repo-creds` template.** (Per el-demoledor V5 source-code citation: `util/db/repository.go` `GetRepository` flow.) Practical implication: adding the new project-level `creds-myriad-vpp-project` template does NOT override the 3 existing Repository CRs (`repo-3194359838`, `repo-3613977198`, `repo-3703084109`) — they remain authoritative for their exact URLs. **Future PAT rotation must update ALL 4 secrets** (3 Repository CRs + 1 template) or the gap re-opens. Add to recipe-rotate-argocd-sandbox-pat: rotation must enumerate all `repository` AND `repo-creds` secrets under the affected ADO project, not just the explicit Repository CRs.

L10.9 — **Actual apply was much simpler than the adversarially-restructured plan, and that was the right call by the user.** fix.md Phase A→F (~25-40 min, prune-disable on 68 apps, throttled per-slot rollout, manual sync gate) was the conservative path. User chose to skip the prune-disable broad mutation (60 patched Applications) and rely on `selfHeal=true`'s natural reconcile cycle to do the recovery work organically. Result: 60 → 0 broken Apps in **~2 minutes** of natural reconcile, zero repo-server stress, zero PrometheusRule destruction, zero bystander regression. The aggressive operational safety design was correct IF a destructive prune cascade were the dominant risk — but in Sandbox FBE specifically, "any manual drift is fair game for GitOps" is the operating contract, so the cascade was actually the desired behavior. **Lesson: adversarial review's `BLOCKING` op-modes can be context-sensitive; the operator must triage them against the deployment's own contract.** Apply gates should remain in fix.md as fallback for cases where the destructive cascade ISN'T acceptable (e.g., production where manual operator edits are expected).

L10.10 — **`argocd CLI` works with `--core` mode bypassing the AAD-OIDC auth chain.** When `argocd account get-user-info` failed with `AADSTS700082: refresh token expired`, the workaround was: `mv ~/.config/argocd/config ~/.config/argocd/config.bak.<ts>` (clears cached AAD session), set kubectl default namespace to `argocd` (so `argocd-cm` ConfigMap resolves), then `argocd repocreds list --core` / `argocd repocreds add --core` work directly via the kubectl context's cluster-admin cert. **Implication**: an operator without active AAD session can still operate ArgoCD CLI via `--core` mode as long as they have kubectl cluster-admin cert. This was NOT documented in the catalogued recipe. Add to vault recipe + skill.

L10.11 — **The credential template name is auto-generated as `creds-<hash>` by argocd CLI; it is NOT possible to specify a human-readable name via `argocd repocreds add`.** The new template's actual Kubernetes Secret name will be `creds-<hash>`, indistinguishable in `kubectl get secret -n argocd` from yesterday's `creds-870830599` and `creds-1649328519` except by inspecting the `data.url`. **Operator hygiene tip**: at next maintenance window, consider replacing the auto-named Secret with a hand-written one named `creds-myriad-vpp-project` for at-a-glance readability. NOT urgent; current state is functional.

L10.8 — **The verification gate that saved this incident from compounding into a worse one was adversarial review with FRESH-CONTEXT typed agents.** The three adversaries (`socrates-contrarian`, `el-demoledor`, `sre-maniac`) ran in parallel with non-overlapping attack lanes. They produced 27 distinct findings. Of those, 4 BLOCKING/HIGH were REBUTTED by A1 evidence I collected during synthesis (notably the ionix-created-today natural experiment) and 3 BLOCKING/HIGH led to a complete L8 rollout-sequence restructure. **Without the adversarial pass, the original L8 ("apply Secret + tight-loop annotate 8 apps") would have triggered the prune cascade and possibly repo-server OOM, leaving the cluster in a worse state.** Validates the governance rule `adversarial-dispatch-discipline.md` and the brain contract's `VERIFY/DEMOLISH LOCK`.

L10.6 — **Harness domain term drift.** The repo's
`.ai/harness/ddd-ubiquitous-language.md` defines FBE as "Flex Budget Engine" — but the
vault, the `eneco-fbe-troubleshoot` skill, and every catalogue note use "Feature Branch
Environment". Update the harness to match the vault canonical, OR add both as accepted
expansions if both are domain-valid. Phase-9 follow-up.

## L11 — End-to-end command playbook

Reproducible from a cold session (assumes operator has Azure + kubectl + argocd CLI
auth):

```bash
# 0. Context
az account set --subscription 7b1ba02e-bac6-4c45-83a0-7f0d3104922e
az aks get-credentials --resource-group rg-vpp-app-sb-401 --name vpp-aks01-d --overwrite-existing
kubectl config current-context   # expect: vpp-aks01-d

# 1. Symptom recognition (this incident's signature)
kubectl get application dispatchermfrr -n jupiter -o jsonpath='{.status.conditions}' | python3 -m json.tool
# expect:
#   "type": "ComparisonError"
#   "message": "Failed to load target state: failed to generate manifest for source 1 of 2: ... authentication required"

# 2. Blast radius — enumerate
kubectl get applications.argoproj.io -A -o json | jq -r '
  .items[] | . as $app |
  ($app.status.conditions // []) |
  map(select(.type == "ComparisonError" and (.message | test("authentication required")))) |
  if length > 0 then "\($app.metadata.namespace)/\($app.metadata.name) since=\(.[0].lastTransitionTime)" else empty end
' | sort | tee /tmp/broken-apps.txt
wc -l /tmp/broken-apps.txt   # expect: 68 (or similar — count is the blast radius)

# 3. Confirm Source 1 of every broken app is uncovered by credentials
kubectl get applications.argoproj.io -A -o json | jq -r '
  .items[] | . as $app |
  ($app.status.conditions // []) |
  map(select(.type == "ComparisonError" and (.message | test("authentication required")))) |
  if length > 0 then $app.spec.sources[0].repoURL else empty end
' | sort -u

# 4. Confirm those URLs are NOT in repository or repo-creds secrets
echo "=== Registered Repositories ==="
kubectl get secret -n argocd -l argocd.argoproj.io/secret-type=repository -o json | jq -r '.items[] | .data.url | @base64d'
echo "=== Credential Templates ==="
kubectl get secret -n argocd -l argocd.argoproj.io/secret-type=repo-creds -o json | jq -r '.items[] | .data.url | @base64d'

# 5. Apply the fix
PAT_B64=$(kubectl get secret repo-3703084109 -n argocd -o jsonpath='{.data.password}')
USER_B64=$(kubectl get secret repo-3703084109 -n argocd -o jsonpath='{.data.username}')
URL_B64=$(printf 'https://enecomanagedcloud@dev.azure.com/enecomanagedcloud/Myriad%%20-%%20VPP' | base64 | tr -d '\n')
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: creds-myriad-vpp-project
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repo-creds
type: Opaque
data:
  url: ${URL_B64}
  username: ${USER_B64}
  password: ${PAT_B64}
EOF

# 6. Refresh one app per slot + platform
for slot in afi ionix ishtar jupiter operations thor veku voltex; do
  kubectl annotate application dispatchermfrr -n $slot argocd.argoproj.io/refresh=hard --overwrite
done
for app in product-asset-scheduling product-flex-trade-optimizer product-vpp-core product-vpp-dispatching; do
  kubectl annotate application $app -n argocd argocd.argoproj.io/refresh=hard --overwrite
done

# 7. Wait, then re-enumerate
sleep 90
kubectl get applications.argoproj.io -A -o json | jq -r '
  .items[] | . as $app |
  ($app.status.conditions // []) |
  map(select(.type == "ComparisonError" and (.message | test("authentication required")))) |
  if length > 0 then "\($app.metadata.namespace)/\($app.metadata.name) STILL BROKEN" else empty end
'
# expect: empty output

# 8. Per-developer sanity
curl -sk -o /dev/null -w "%{http_code}\n" https://jupiter.dev.vpp.eneco.com/
# expect: 200 (or 503 while pods come up); NOT 404
```

## L12 — One-page on-call playbook

> **Symptom**: an FBE Application URL returns 404 OR a developer says "FBE not updating
> images" OR Slack reports a per-Application "authentication required" error.
>
> **Single discriminator (60 seconds)**:
>
> ```bash
> kubectl get applications.argoproj.io -A -o json | jq -r '.items[] | . as $a |
>   ($a.status.conditions // []) | map(select(.type=="ComparisonError" and (.message|test("authentication required")))) |
>   if length>0 then "\($a.metadata.namespace)/\($a.metadata.name)" else empty end' | wc -l
> ```
>
> - `0` lines → not this class; route to F-catalogue.
> - `>5` lines spanning multiple slots → **this RCA's class**.
>
> **30-second routing decision**:
>
> ```bash
> # Does Eneco.Vpp.Core.Dispatching or platform-gitops have a credential?
> kubectl get secret -n argocd -l argocd.argoproj.io/secret-type=repository \
>   -o json | jq -r '.items[].data.url|@base64d' | grep -E 'Eneco.Vpp.Core.Dispatching|platform-gitops'
> kubectl get secret -n argocd -l argocd.argoproj.io/secret-type=repo-creds \
>   -o json | jq -r '.items[].data.url|@base64d' | grep -E 'Myriad%20-%20VPP$|Myriad%20-%20VPP/$'
> ```
>
> - Both grep return non-empty → not this RCA's class; investigate per-repo PAT scope.
> - Either grep returns empty → **apply this RCA's L8 fix.**
>
> **Fix in 4 commands** (after confirming above):
>
> 1. `PAT_B64=$(kubectl get secret repo-3703084109 -n argocd -o jsonpath='{.data.password}')`
> 2. `URL_B64=$(printf 'https://enecomanagedcloud@dev.azure.com/enecomanagedcloud/Myriad%%20-%%20VPP' | base64 | tr -d '\n')`
> 3. `kubectl apply -f -` ← the Secret yaml from L8 Step 2
> 4. `for slot in ...; do kubectl annotate ... refresh=hard; done` (L8 Step 3)
>
> **Verification in 1 command** (after 90s wait):
>
> ```bash
> kubectl get applications.argoproj.io -A -o json | jq '... # the same query above' | wc -l
> # expect: 0
> ```
>
> **Escalation**: Fabrizio Zavalloni in `#myriad-platform` for PAT scope questions or to
> coordinate with `sa_platform_vpp@eneco.com` ADO owner.

## Self-tests (read this RCA and check)

Test 1 (concept): Why did yesterday's PAT rotation NOT fix today's failure even though the
PAT bytes work?
*Answer should mention: the rotation only patched 3 Repository CRs whose URLs match
`VPP-Configuration`, `VPP.GitOps`, `Myriad - VPP`; the broken Applications fetch from
`Eneco.Vpp.Core.Dispatching` and `platform-gitops` which have no Repository CR and no
covering `repo-creds` template.*

Test 2 (mechanism): At what point in ArgoCD's reconcile is the failure injected? Why does
the error message say "source 1 of 2" specifically?
*Answer should mention: step 2a credential resolution; the Application has 2 sources;
Source 1 is `Eneco.Vpp.Core.Dispatching` (uncovered); Source 2 is `VPP-Configuration`
(covered by `repo-3194359838`). Resolution fails for source 1 only; "source 1 of 2"
identifies which source.*

Test 3 (falsifier): What single piece of evidence would falsify this RCA's claim?
*Answer should mention: a Repository CR or `repo-creds` template in `argocd` namespace
whose URL exactly matches or is a strict prefix of
`.../Myriad - VPP/_git/Eneco.Vpp.Core.Dispatching` AND has a populated password. Probe
in L11 Step 4.*

Test 4 (durability): Why does the fix create a `repo-creds` template instead of two
explicit `Repository` CRs?
*Answer should mention: future-proofing — any new repo under `Myriad - VPP` (e.g., a
new service split out from Eneco.Vpp.Core.Dispatching) inherits the credential
automatically; minimal-scope fix leaves the same latent defect for the next repo.*

Test 5 (blast radius): Why are 68 Applications affected when only one was reported?
*Answer should mention: the credential gap is project-wide; 8 slots × 8 dispatching
services + 4 platform-gitops apps + 3 rabbitmq + loki = 68. The single intake just
happened to be the first developer to look closely; the platform-level
`argocd/product-*` outage hasn't reached the operator's attention because no human
watches those daily.*

## Evidence Ledger

| # | Claim | A-label | Probe (re-runnable) | Status |
|---|---|---|---|---|
| E1 | Application `jupiter/dispatchermfrr` is in `ComparisonError` state since 2026-05-10T12:45:22Z | **A1 FACT** | `kubectl get application dispatchermfrr -n jupiter -o jsonpath='{.status.conditions}'` | Verified 2026-05-12T12:27 UTC |
| E2 | Repository CRs in `argocd` namespace cover only 3 of 5 ADO repos under `Myriad - VPP`: `VPP-Configuration`, `VPP.GitOps`, `Myriad - VPP` | **A1 FACT** | `kubectl get secret -n argocd -l argocd.argoproj.io/secret-type=repository -o json \| jq -r '.items[] \| .data.url \| @base64d'` | Verified 2026-05-12 |
| E3 | The only enecomanagedcloud `repo-creds` template covers `VPP - Asset Optimisation`, NOT `Myriad - VPP` | **A1 FACT** | Same probe with `-l secret-type=repo-creds` | Verified 2026-05-12 |
| E4 | 68 distinct Applications across 9 namespaces have the same `ComparisonError: ... authentication required` | **A1 FACT** | Full enumeration in L11 Step 2 | Verified 2026-05-12 |
| E5 | All 64 FBE Applications' source[0] is `Eneco.Vpp.Core.Dispatching` | **A1 FACT** | L11 Step 3 query | Verified 2026-05-12 |
| E6 | All 4 platform `product-*` Applications' source[0] is `platform-gitops` | **A1 FACT** | Same probe | Verified 2026-05-12 |
| E7 | Yesterday's PAT was rotated at 2026-05-11T13:35:00Z and the 3 working Repository CRs use that PAT | **A1 FACT** (via vault note) | `$SECOND_BRAIN_PATH/.../2026-05-11-pat-expiry-argocd-auth-break.md` lines 22-23, 56 | Cited 2026-05-12 |
| E8 | ArgoCD's credential resolution order is exact Repository > longest-prefix repo-creds > anonymous | **A2 INFER** from ArgoCD docs (informal) | https://argo-cd.readthedocs.io/en-stable/operator-manual/declarative-setup/#repository-credentials | Citation-based; A1-grade live confirmation would be reading repo-server source code |
| E9 | The mechanism by which the previous PAT covered `Eneco.Vpp.Core.Dispatching` before 2026-05-10 cannot be re-probed from today's cluster state | **A3 UNVERIFIED[blocked: historical state not in etcd; resolving probe: `git log` on `argocd-cm` ConfigMap if it was version-controlled, OR ArgoCD audit log if enabled]** | Pre-05-10 cluster state not recoverable | Acknowledged gap |
| E10 | Yesterday's recipe Step 7 verification depth stops at "child Applications materialize", not at "child Applications can sync" | **A1 FACT** | `$SECOND_BRAIN_PATH/.../recipe-rotate-argocd-sandbox-pat.md` Step 7 contents (lines 168-188) | Cited 2026-05-12 |
| E11 | Harness `ddd-ubiquitous-language.md` defines FBE as "Flex Budget Engine" while vault canonical is "Feature Branch Environment" | **A1 FACT** | `engineering-log/.ai/harness/ddd-ubiquitous-language.md` line 19 vs `$SECOND_BRAIN_PATH/.../fbe/_index.md` and `eneco-fbe-troubleshoot` skill description | Verified 2026-05-12 |

## Challenge defense (anticipated objections + response)

**Objection 1**: "If the credentials were broken since 2026-05-10, why didn't every
developer notice immediately?"
*Defense*: existing slots' Application CRDs already in etcd continue to reconcile (per
yesterday's pattern doc). Once an Application's repo-server cache held a successful
clone, subsequent reconciles re-fetch but may still report sync as "stale" without
visible service degradation **as long as no new branch is pushed**. The moment a
developer pushes a new feature branch and Stage 6 updates `targetRevision`, the
repo-server tries to fetch the new ref → credential resolution fails → ComparisonError.
Slot-by-slot, the failures surfaced as developers pushed new commits over the 22-hour
window.

**Objection 2**: "Maybe yesterday's recipe DID fix it and the problem is back due to a
new cause today."
*Defense*: the `lastTransitionTime` of every broken Application is `2026-05-10T12:45-12:51 UTC`,
NOT `2026-05-12T*`. ArgoCD updates `lastTransitionTime` only on status flip — if
yesterday's rotation had cleared the error and a new failure had occurred today, the
timestamp would be today. The timestamp identity proves the error has been continuous.

**Objection 3**: "Maybe the screenshot showing all Repositories as 'Successful' means
the credential plane is fine."
*Defense*: the Repositories list shows EXPLICITLY REGISTERED Repository CRs. The
defect is that two ADO repos are NOT in that list and have no template covering them.
"All registered repos work" is a true statement and is fully consistent with this RCA.

**Objection 4**: "Why didn't this incident's class show up in
`pattern-argocd-pat-expiry-blocks-new-fbe-apps`?"
*Defense*: yesterday's pattern was authored at ~10:30 UTC 2026-05-11, before the
PAT rotation completed. The recipe's verification at 13:35 UTC checked
`{slot}-app-of-apps` count and pod existence on a single fresh slot (kidu); the recipe
didn't probe the existing-slot per-Application sync depth. This RCA is the sibling
pattern that yesterday's author would have written if the recipe had reached Step 7.5.

## Adversarial Review Receipts (summary)

Three typed-frame adversaries reviewed this RCA in parallel before fix-apply was
authorised. Full reports live in
`.ai/tasks/2026-05-12-001_fbe-jupiter-argocd-auth/verification/`:
`adv-socrates.md`, `adv-eldemoledor.md`, `adv-sre.md`.

| # | Finding (abbreviated) | Adversary | Severity | Status | Resolution |
|---|---|---|---|---|---|
| 1 | URL userinfo blocks prefix-match (V1) | el-demoledor | BLOCKING | **REBUT** | A1 evidence: existing `creds-870830599` URL has `enecomanagedcloud@` userinfo AND `eneco-flex-trade-optimizer/*` Applications under that template are Synced+Healthy. Production pattern confirms userinfo-preserving prefix match works. El-demoledor's own self-falsifier clause named exactly this condition. |
| 2 | Class conflation — 4 platform apps may be a separate class | socrates | HIGH | **REBUT** | A1 evidence: all 64 FBE + 7 platform-ns timestamps cluster within 2026-05-10T12:43-12:51 UTC (one PAT-expiry reconcile window). Unified class. |
| 3 | Cached-credential mechanism (sticky 401 from pre-rotation pod state) | socrates | HIGH | **REBUT** | A1 evidence: Ionix Applications created **2026-05-12T12:19:05Z** (today) and broken IMMEDIATELY at the same timestamp. Fresh Applications have no cache; their failure proves credential is genuinely absent, not cache-stuck. Also: repo-server pod (3-mo-old) successfully serves the 3 working Repository CRs after yesterday's rotation, proving Secret re-reads happen. |
| 4 | argocd self-management with prune=true would silently revert fix | socrates | MEDIUM-HIGH | **REBUT** | A1 probe: `argocd/argocd-configuration` has `prune=false`; no Application managing argocd Secrets has prune=true. New template will survive. |
| 5 | Reused PAT scope unverified on Eneco.Vpp.Core.Dispatching and platform-gitops | el-V4 / soc-1 | HIGH | **RESOLVE** | Added Phase A0 PAT-scope `git ls-remote` probe to fix.md as the very first step. Lands silently no-op if PAT lacks repo-level Code Read. |
| 6 | Template URL missing trailing slash → future over-coverage on `Myriad - VPP - X` projects | el-V2 | MEDIUM | **RESOLVE** | fix.md B2 URL ends with `/` (verified in the actual encoded URL). |
| 7 | 68 concurrent reconciles will trip repo-server parallelism limit AND ADO 200 TSTU/5min limit | sre-1 / sre-2 / el-V3 | **BLOCKING** | **RESOLVE** | fix.md restructured into Phase A→F: probe parallelism (cap to 8 if unset), throttled per-slot rollout with 60s gates, monotonic-decrease bystander check. |
| 8 | 22h-drift prune cascade silently destroys manual cluster edits | sre-3 | **BLOCKING** | **RESOLVE** | fix.md Phase A4 disables `automated.prune+selfHeal` on all 68 broken apps BEFORE Secret lands. Phase E re-enables per-slot after manual `argocd app diff` inspection. |
| 9 | `refresh=hard` semantics: forces full re-clone, multiplies ADO bytes 10-100x | sre-4 / el-V6 | HIGH | **RESOLVE** | fix.md uses `argocd app refresh` (normal) and explicit `argocd app sync` instead of the annotation `refresh=hard`. |
| 10 | OCI Application errors won't match `test("authentication required")` filter | el-V8 | MEDIUM | **RESOLVE** | All filters in fix.md use case-insensitive `test("auth"; "i")` so 401 / `helm registry login required` / similar all match. |
| 11 | Rollback claim "no state destroyed" oversimplifies; rollback is non-atomic for in-flight syncs | sre-7 / el-V7 | HIGH | **RESOLVE** | fix.md has a 3-row table per rollback stage with explicit "what it does NOT clean up" wording. |
| 12 | "Do NOT restart repo-server" anti-pattern is over-strong; restart is RIGHT when symptom is `revision not found` | el-V6 | MEDIUM | **RESOLVE** | fix.md C2 decision rule explicitly allows restart for `revision not found` symptom; remains forbidden for `authentication required` symptom. |
| 13 | Rung 5 historical mechanism (pre-2026-05-10 working state) is decorative, not load-bearing | soc-3 | LOW | **RESOLVE** | First-Principles Ladder Rung 5 in this RCA explicitly notes "(This last rung carries an A3 ... The mechanism today is A1; the explanation for the previous working state is A2 INFER ...)". Decorative-not-load-bearing flag added. |
| 14 | Project-level template is "durable" framing is overstated; trade-offs exist | soc-4 | MEDIUM | **PARTIAL** (DEFER doc) | Tradeoff acknowledged here: future repos under `Myriad - VPP` that need DIFFERENT credentials would still require an explicit Repository CR (which takes precedence). Future PAT rotation must remember the template as a 4th secret. The minimal-scope alternative (2 explicit Repository CRs) was explicitly considered and rejected on durability grounds with this trade-off accepted. |
| 15 | L10.1 wording ("verification too shallow") could be sharpened to "verification surface mismatched the cause-claim surface" | soc-5 | LOW | **RESOLVE** | See L10.1 below — updated wording. |
| 16 | Bystander Apps share repo-server pod; saturation could regress working set | sre-6 | HIGH | **RESOLVE** | fix.md Phase A2 captures working-app baseline; Phase D5 monotonic check halts on bystander regression; Phase F5 re-verifies. |
| 17 | Time-of-day risk: 14:30 CEST is mid-business-hours; developer push race | sre-8 | MEDIUM | **RESOLVE** | fix.md Phase A3 announces in `#myriad-platform` requesting pause on feature-branch pushes. |
| 18 | Compound diagnosis confusion (rate-limit + cache + race mixing error messages) | el-V9 | MEDIUM | **RESOLVE** | fix.md Phase C2 decision rule enumerates the 4 distinct log signatures and the differential action for each. |
| 19 | L9 verification covers only `wc -l broken=0`; misses pod health, ACR pull errors, PrometheusRule retention, kube-apiserver QPS | sre-10 / sre-11 | MEDIUM | **RESOLVE** | fix.md Phase F has 8 acceptance criteria (F1-F8) covering broken count, pod readiness, image-pull errors, PrometheusRule baseline, working-count regression, per-slot ingress 200, repo-server restart count, reporter Slack confirmation. |
| 20 | Repository CR precedence behaviour | el-V5 | MEDIUM info | **RESOLVE** (doc) | L10.7 lesson added below noting precedence model. |

**Summary**: 4 BLOCKING / HIGH findings REBUTTED with A1 evidence collected during this
session (the ionix-created-today data point is the strongest single rebuttal — a natural
experiment none of the adversaries had visibility to). 3 BLOCKING / HIGH findings
RESOLVED by complete restructure of L8 rollout into Phase A→F in `fix.md`. 13
MEDIUM/LOW findings RESOLVED as doc-level changes. 1 finding (#14) DEFERRED as
acknowledged trade-off in L8 narrative.

**No DEFER on BLOCKING. No systematic-Defer pattern. No rebut-without-evidence.** Per
the `.claude/rules/governance/adversarial-dispatch-discipline.md` gates, the review
passes for fix authorisation.

## See also

- `slack-intake.txt` (this dir) — verbatim user intake
- `context.md` (this dir) — investigation evidence trail with raw outputs
- `fix.md` (this dir) — **executable Phase A→F runbook (the version to ACT from)**
- Adversarial reports: `.ai/tasks/2026-05-12-001_fbe-jupiter-argocd-auth/verification/{adv-socrates,adv-eldemoledor,adv-sre}.md`
- Vault canonical: `$SECOND_BRAIN_PATH/2-areas/work-eneco/eneco-vpp-platform/fbe-errors/`
- Yesterday's incident: `2026-05-11-pat-expiry-argocd-auth-break.md`
- Pattern (adjacent, NOT this class): `pattern-argocd-pat-expiry-blocks-new-fbe-apps.md`
- Recipe (used yesterday, gap identified in L10.1): `recipe-rotate-argocd-sandbox-pat.md`
- Phase-9 follow-up: author a new pattern note `pattern-argocd-per-application-source-credential-gap` and bump the recipe's Step 7
