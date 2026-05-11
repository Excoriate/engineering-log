---
task_id: 2026-05-11-002
agent: wiki-harvest-sidecar
status: complete
summary: Eneco ADO wiki context on ArgoCD PAT rotation procedure
phase: 4
---

# Wiki context — ArgoCD PAT / repo-credential rotation

> Status: INFER (wiki-skill scripts succeeded; URLs verbatim from script output; coordinator must source-verify any quote used as FACT in the runbook). All belief-status labels apply to the inherited wiki content; this sidecar only confirms existence and quotes.

## Q1 — Is there a written rotation procedure in any ADO wiki?

**Answer: PARTIAL — no step-by-step procedure for the ArgoCD PAT specifically; one canonical FAQ entry confirms the responsibility lives with the Platform team and PAT renewal is transparent to consumer teams. No `sa_platform_vpp` / `gitops-vpp` rotation runbook found.**

Primary source — `Platform-documentation/Guides/FAQ` (page id 68127, "Last updated: April 2026"):

> Section: **How do I get ArgoCD repository connections for a new service (e.g., Asset Scheduling gitops)?**
>
> "Request it in #myriad-platform. The Platform team creates the repository connection in ArgoCD for each environment (DEV, ACC, PROD) and manages PAT renewal."
>
> "PAT renewal is our responsibility and will be handled transparently." — Roel, Slack thread Jan 8 2026

URL: https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_wiki/wikis/Platform-documentation/68127

Adjacent (FYI, but not the PAT rotation procedure itself):
- `Myriad---VPP.wiki / Myriad - Aggregation Layer / Runbook certificate rotation aggregation layer` (id 50903) — full rollout/rollback runbook, but for the **ESP production certificate** (Axual mTLS), via `esp-certificate-agg` ArgoCD app. Not PAT. Useful as a structural template for the runbook being written.
  - URL: https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_wiki/wikis/Myriad---VPP.wiki/50903
- `Myriad---VPP.wiki / Way of Working / DevOps & Platform / Tutorials-HowTos / ArgoCD` (id 30204) — terse install-time configuration notes; mentions `secretsprovider-eneco-vpp` for docker secret. No rotation steps.
- `Myriad---VPP.wiki / Way of Working / DevOps & Platform / Tutorials-HowTos / Certificates and Secrets / Secret expiry pipeline` (id 36619) — describes an ADO pipeline (definitionId=2735) that "checks for expiring certificates and posts a message to myriad-alerts-devops channel". Expiry **detection**, not rotation steps. Notes appregistration secrets are stored in keyvault `vpp-aks-devops`.
- `Myriad---VPP.wiki / Way of Working / DevOps & Platform / Tutorials-HowTos / appreg secrets` (id 30871) — one-line "These need to be renewed periodically" + two screenshots. Effectively empty.
- `Myriad---VPP.wiki / Myriad - BTM / B2C / Support tasks / Secret Rotation` (id 68382) — concrete step-by-step BTM **app registration** client-secret rotation runbook (locate clientId → create new secret in Entra ID → update keyvault/postman/grafana → restart Function/Web apps → observe App Insights → delete old secret). Pattern-relevant. Not PAT.

Operational corroboration that the team's rotation pattern is "platform refreshes the ArgoCD repository connectivity secret in place" — `Platform-documentation/Guides/Troubleshooting-Guide`, section **ArgoCD application shows "unknown" status**:

> "The Platform team is refreshing the ArgoCD repository connectivity secret. This is a brief operation (~30 seconds) with no impact on running workloads. The status will recover automatically."
> Slack thread: Roel, Jan 23 2026 — "I'm refreshing the secret for repository connectivity in production argocd. If you see applications with 'unknown' status, that's me."
>
> URL: https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_wiki/wikis/Platform-documentation/_pageId/68127 (Troubleshooting-Guide companion to FAQ above)

`[PENDING: ask Fabrizio]` — exact mechanics of the "refresh" (KV update? `kubectl edit secret`? Terraform apply? oc patch?). Wiki documents the OUTCOME and the OWNERSHIP, not the keystrokes.

---

## Q2 — Documented identity of the MC ArgoCD installations

**Answer: FOUND (host names + namespaces) — `Operations & Support / Runbooks / Run Book / PROD-MIGRATION - CMC Dedicated cluster` enumerates the URLs and the cluster apex domains.**

Primary source — `Myriad---VPP.wiki / Operations & Support / Runbooks / Run Book / PROD-MIGRATION - CMC Dedicated cluster`:

| Env | OCP API | ArgoCD (legacy / "eneco-vpp-argocd") | OpenShift GitOps |
|-----|---------|--------------------------------------|------------------|
| dev (MC) | api.eneco-vpp-dev.ceap.nl (10.7.32.148) | eneco-vpp-server-eneco-vpp-argocd.apps.eneco-vpp-dev.ceap.nl (10.7.32.167) | openshift-gitops-server-openshift-gitops.apps.eneco-vpp-dev.ceap.nl (10.7.32.167) |
| acc (MC) | api.eneco-vpp-acc.ceap.nl (10.7.224.148) | eneco-vpp-server-eneco-vpp-argocd.apps.eneco-vpp-acc.ceap.nl (10.7.224.167) | openshift-gitops-server-openshift-gitops.apps.eneco-vpp-acc.ceap.nl (10.7.224.167) |
| prd (MC) | api.eneco-vpp-prd.ceap.nl (10.9.32.148) | eneco-vpp-server-eneco-vpp-argocd.apps.eneco-vpp-prd.ceap.nl (10.9.32.167) | openshift-gitops-server-openshift-gitops.apps.eneco-vpp-prd.ceap.nl (10.9.32.167) |

URL: https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_wiki/wikis/Myriad---VPP.wiki (page "PROD-MIGRATION - CMC Dedicated cluster")

Cross-confirmed in `Way of Working / DevOps & Platform / Tutorials-HowTos / DNS / AVD-DNS-resolution`.

Sandbox (separate cluster, separate ArgoCD): `argocd.dev.vpp.eneco.com` — see `Way of Working / DevOps & Platform / Tutorials-HowTos / ArgoCD / ArgoCD Sandbox` (id 42802). Sandbox ArgoCD is configured via `VPP.GitOps` repo, Kustomize overlays, Entra OIDC, TLS via Azure KeyVault CSI Driver, `sg-vpp-platform` AAD group → `org-admin`. **Two ArgoCD installs co-exist on MC clusters: `eneco-vpp-argocd` (legacy/team-managed) and `openshift-gitops` (Red Hat Operator). The runbook should disambiguate which one holds the gitops-vpp repo credential.** `[PENDING: ask Fabrizio: which ArgoCD instance on MC holds the gitops-vpp repo connection — eneco-vpp-argocd or openshift-gitops?]`

Authoritative quick-links page (current): `Myriad---VPP.wiki / Myriad - VPP: Getting started / Quick Links` (id 8239) — lists ArgoCD PROD / DEV / ACC / SANDBOX (URLs rendered as link text only; raw URLs not in the text dump).

---

## Q3 — What is "cmc-goldilocks"?

**Answer: `[NOT FOUND in 2 searches]` — no hits for "goldilocks" in either wiki and no hits in the `DesignDecisions` repo.**

- `wiki-search.sh --query "goldilocks"` → NO RESULTS (Myriad---VPP.wiki)
- `wiki-search.sh --query "goldilocks" --wiki Platform-documentation` → NO RESULTS (Platform-documentation; also covers Platform-team-internal via cross-wiki search context)
- `repo-search.sh --repo DesignDecisions --query "goldilocks"` → NO RESULTS

`[PENDING: ask Fabrizio: what is the goldilocks repository — name, ADO project, URL, purpose? Is it the ArgoCD repo backing MC clusters?]`

---

## Q4 — Documented credential rotation SLA / RACI

**Answer: `[NOT FOUND]` for a formal SLA. RACI is informal: "Platform team owns it." Two architecture proposals reference rotation as a quality goal but neither defines an SLA nor a renewal cadence.**

Sources:
- `Platform-documentation / Reference / Architecture / Container-registry-interactions` — names rotation as an existing pain ("Rotation of the credentials is almost impossible due to the large blast radius… Credential rotation should be automated."). Forward-looking, not policy.
- `Platform-documentation / Reference / Architecture / Proposal-Container-registry-redesign` — proposes auto-rotated tokens via Terraform and floats Managed Identities as an alternative. Forward-looking proposal, not adopted SLA.
- `Platform-team-internal / How-To-Guides / Gurobi / service-accounts` — generic guidance: "Rotate tokens regularly (at least every 90 days or according to company policy)." Not Eneco-VPP-wide policy; specific to Gurobi service-account API tokens.

R = Platform Team / Trade IT (per FAQ ownership statement). A/C/I = not documented. SLA = `[PENDING: ask Fabrizio]`. Proposal: include "define rotation SLA + RACI for gitops PAT" as a deliverable of the runbook task.

---

## Q5 — Documented KV → cluster sync mechanism for ArgoCD repo secrets

**Answer: PARTIAL — multiple mechanisms documented, each used for a different surface. For the ArgoCD repo connection specifically: no wiki page names the exact mechanism; the Sandbox ArgoCD example uses Azure KeyVault CSI Driver (SecretProviderClass) for its TLS cert, but that is for the **ingress TLS** secret, not the **repo connection** secret.**

Three mechanisms documented in the wikis:

1. **Azure KeyVault CSI Driver via `SecretProviderClass`** — used on Sandbox ArgoCD ingress TLS and Gurobi cluster manager.
   - `Way of Working / DevOps & Platform / Tutorials-HowTos / ArgoCD / ArgoCD Sandbox` (id 42802): defines `secretproviderclass.yaml` + a volume/volumeMount patch on `argocd-server` that triggers the CSI driver to load secrets from Azure KeyVault and materialize a Kubernetes secret. Referenced by `ingress.yaml`.
   - `Platform-team-internal / How-To-Guides / Gurobi / cluster-provisioning`: SecretProviderClass reads CosmosDB connectionstring from Azure KeyVault.
2. **External Secrets Operator (ESO)** — documented as deployable; reads from Azure KeyVault on a polling cycle (example shows 1-hour poll) and materializes a Kubernetes Secret consumable by ArgoCD value files.
   - `Way of Working / DevOps & Platform / Kubernetes / External Secrets Operator` (id 49296): SecretStore vs ClusterSecretStore, ExternalSecret resource, "We can reference these existing secrets in our argocd value file of the application." Service principal `kubectl create secret generic azure-sp-secret` shown.
3. **Manual / in-cluster Secret** — for the ArgoCD repo connection itself, the "refreshing the secret for repository connectivity" Slack quote (Q1) implies a manually-managed Kubernetes Secret in the ArgoCD namespace (the standard ArgoCD pattern: a `Secret` of type `Opaque` with annotation `argocd.argoproj.io/secret-type: repository`). Mechanism for KV → Secret sync is not explicitly named in the wiki for the gitops-vpp PAT.

`[PENDING: which of these three mechanisms feeds the ArgoCD repo connection on MC clusters?]` — most likely "manual `oc patch`/`kubectl apply` from a value the Platform team pulls from `vpp-aks-devops` keyvault", based on the "~30 second refresh" cadence Roel described, but this is an inference, not a wiki claim.

KV name for app-registration secrets is `vpp-aks-devops`, per `Secret-expiry-pipeline` and `ESP-Cert-renewal`.

---

## Q6 — Troubleshooting Guide entry for "FBE pods missing after pipeline succeeds" / "ApplicationGenerationFromParamsError"

**Answer: NO entry for the literal string `ApplicationGenerationFromParamsError` (NO RESULTS). FOUND a related entry: "FBE creation is green but tests fail / frontend is not accessible" which mentions silent service-start failures and CrashLoopBackOff pods, but does not name the ApplicationSet generator error.**

Source — `Platform-documentation / Guides / Troubleshooting Guide`:
> Section: **FBE creation is green but tests fail / frontend is not accessible**
>
> "Possible causes: Configuration drift between the FBE template and the current application code. DNS not yet propagated for the FBE's ingress. A service failed to start silently (check pod logs in ArgoCD)."
> "If the frontend is unreachable, check ArgoCD for the FBE namespace — look for pods in CrashLoopBackOff or Error state."

URL: https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_wiki/wikis/Platform-documentation (Troubleshooting-Guide)

Also relevant: section **ArgoCD sync failing on a specific application after a release** and **One-For-All pipeline: command not found and empty Helm image tags** (definitionId 1811; empty `tag: ""` in `values-override.yaml` → ArgoCD sync/image-pull fails). The empty-tag pattern is a documented silent-fail that resembles "pods missing" but the wiki does not connect it to `ApplicationGenerationFromParamsError`.

Connection to vault's "pods missing after pipeline" pattern doc: `[PENDING]` — wiki does not surface the exact ArgoCD ApplicationSet generator error.

---

## Q7 — Search log

| # | Query | Wiki / Repo | Hits | Top 1-3 paths |
|---|-------|-------------|------|---------------|
| 1 | `ArgoCD PAT rotation` | Myriad---VPP.wiki | 0 | — |
| 2 | `goldilocks` | Myriad---VPP.wiki | 0 | — |
| 3 | `goldilocks` | Platform-documentation | 0 | — |
| 4 | `sa_platform_vpp` | Myriad---VPP.wiki | 0 | — |
| 5 | `ArgoCD repository credentials` | both | 1 | `/platform-documentation/Guides/FAQ` |
| 6 | `ArgoCD secret rotation` | both | 3 | `/Myriad---Aggregation-Layer/Runbook-certificate-rotation-aggregation-layer`; `/Architecture-&-Designs/VPP-Core/Infrastructure/Deployment`; `/Operations-&-Support/Runbooks/Run-Book/Openshift-Troubleshooting/Useful-openshift-commands` |
| 7 | `GitOps PAT` | both | 1 | `/platform-documentation/Guides/FAQ` |
| 8 | `Personal Access Token rotation` | both | 1 | `/internal/How-To-Guides/Gurobi/service-accounts` (Platform-team-internal) |
| 9 | `FBE pods` | both | 5 | On-Demand-Environments-Deployment; Troubleshooting.FeatureBranchEnvironments; Troubleshooting-Guide |
| 10 | `ApplicationGenerationFromParamsError` | both | 0 | — |
| 11 | `ArgoCD repo connection failed` | both | 2 | Troubleshooting-Guide; FAQ |
| 12 | `credential rotation policy` | both | 3 | Proposal-Container-registry-redesign; Container-registry-interactions; Useful-openshift-commands |
| 13 | `MC cluster ArgoCD` | both | 6 | Quick-Links; PROD-MIGRATION; AVD-DNS-resolution |
| 14 | `OpenShift GitOps` | both | 36 | PROD-MIGRATION - CMC Dedicated cluster; AVD-DNS-resolution; many ops pages |
| 15 | `ESO secret store` | both | 0 | — |
| 16 | `SecretProviderClass` | both | 6 | ArgoCD-Sandbox; Gurobi cluster-provisioning; FBE Troubleshooting-steps |
| 17 | `vpp-aks-devops keyvault` | both | 4 | ESP-Cert-renewal; Secret-expiry-pipeline; pfx-file-management |
| 18 | `ArgoCD` | DesignDecisions repo | 0 | — |
| 19 | `goldilocks` | DesignDecisions repo | 0 | — |

Pages fetched in full (verified `test -s` via script output non-empty):
- `Platform-documentation/Guides/FAQ` (page 68127)
- `Platform-documentation/Guides/Troubleshooting-Guide` (filtered to ArgoCD/FBE/PAT sections)
- `Myriad---VPP.wiki/Myriad - Aggregation Layer/Runbook certificate rotation aggregation layer` (50903)
- `Myriad---VPP.wiki/Way of Working/DevOps & Platform/Tutorials-HowTos/ArgoCD` (30204)
- `Myriad---VPP.wiki/Way of Working/DevOps & Platform/Tutorials-HowTos/ArgoCD/ArgoCD Sandbox` (42802)
- `Myriad---VPP.wiki/Way of Working/DevOps & Platform/Kubernetes/External Secrets Operator` (49296)
- `Myriad---VPP.wiki/Way of Working/DevOps & Platform/Tutorials-HowTos/Kubernetes Secrets` (6281)
- `Myriad---VPP.wiki/Way of Working/DevOps & Platform/Tutorials-HowTos/Certificates and Secrets` (34574 — header-only page)
- `Myriad---VPP.wiki/Way of Working/DevOps & Platform/Tutorials-HowTos/Certificates and Secrets/Secret expiry pipeline` (36619)
- `Myriad---VPP.wiki/Way of Working/DevOps & Platform/Tutorials-HowTos/Certificates and Secrets/Certificate Renewal` (12196)
- `Myriad---VPP.wiki/Way of Working/DevOps & Platform/Tutorials-HowTos/appreg secrets` (30871)
- `Myriad---VPP.wiki/Myriad - BTM/B2C/Support tasks/Secret Rotation` (68382)

---

## Q8 — Unexpected finds

1. **Third wiki exists**: `Platform-team-internal` (e.g. `/internal/How-To-Guides/Gurobi/service-accounts`, `/internal/How-To-Guides/Gurobi/cluster-provisioning`). Not in the skill's primary registry. Worth flagging to the coordinator — runbook may want to live there if it is internal.
2. **`VPP.GitOps` repo** is the canonical Kustomize source for the Sandbox ArgoCD configuration (overlays, RBAC ConfigMap, SecretProviderClass). URL pattern: `https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/VPP.GitOps?path=/...`. Strong candidate for "gitops-vpp" referent or its sibling.
3. **Two ArgoCD instances on MC** — both `eneco-vpp-argocd` (custom team install at `eneco-vpp-server-eneco-vpp-argocd.apps.eneco-vpp-<env>.ceap.nl`) and `openshift-gitops` (Red Hat Operator at `openshift-gitops-server-openshift-gitops.apps.eneco-vpp-<env>.ceap.nl`) coexist. Any rotation runbook must name **which one** holds the repo credential under rotation, because they are independent control planes.
4. **`vpp-aks-devops` keyvault** is the central store for appreg secrets and pipeline-facing rotation surface; `Secret-expiry-pipeline` pipeline (definitionId 2735) posts to `#myriad-alerts-devops`. This is the most likely upstream KV for the ArgoCD repo PAT, but the wiki does not explicitly say so.
5. **BTM Secret Rotation runbook (id 68382)** is the closest existing template in the wiki for an Eneco rotation runbook style (Summary of actions → Locate clientId → Update KV → Restart consumers → Observe → Delete old secret). Use as a stylistic template even though the surface differs.
6. **Aggregation Layer cert rotation runbook (id 50903)** is the closest template for an ArgoCD-touching rotation (disable auto-sync → override secret → sync → restart → verify → rollback steps). Use as the structural template for Section B/C of the new runbook.
7. **AAD identity in scope**: Sandbox ArgoCD uses appreg `appreg-vpp-argocd-id-d` with the OIDC client secret named `argocd-configmap-argocd-secret-oidc-azure-clientSecret`. Authorisation via `sg-vpp-platform` → `org-admin`. Tangential to PAT rotation but useful identity context.
8. **No ADRs for ArgoCD / GitOps / repo-credential rotation** exist in the `DesignDecisions` repo (both targeted searches returned zero). The runbook will be authoritative; there is no upstream ADR to cite.

---

## Q9 — Belief change (per Q, what does the runbook plan change to?)

| Q | Belief change for the runbook |
|---|-------------------------------|
| Q1 | The runbook **does not have a pre-existing canonical procedure to defer to**. It must be authored from first principles. The FAQ becomes the **ownership citation** (Platform team owns PAT rotation; transparent to consumers). The "refresh the secret ~30 seconds, status flickers to Unknown" Troubleshooting-Guide entry becomes the **expected user-visible signal**. Aggregation-Layer cert rotation runbook + BTM Secret Rotation runbook become **structural templates**. Coordinator must still ask Fabrizio for the exact keystrokes of the "refresh"; that gap is load-bearing. |
| Q2 | Runbook Section B names concrete URLs: `eneco-vpp-server-eneco-vpp-argocd.apps.eneco-vpp-{dev,acc,prd}.ceap.nl`. Section B MUST disambiguate `eneco-vpp-argocd` vs `openshift-gitops` — both exist on each MC cluster. `[PENDING: which holds the gitops-vpp repo connection]` becomes load-bearing because the wrong target = silent no-op rotation. |
| Q3 | `[PENDING: ask Fabrizio: what is the goldilocks repository]` stays explicit in the runbook. Search exhausted. |
| Q4 | Runbook acknowledges absence of formal SLA, proposes one as a deliverable. RACI placeholder: R = Trade Platform / Platform Team, A/C/I = TBD. Cadence: "no documented SLA; existing alert pipeline detects upcoming expiry — pipeline definitionId 2735." |
| Q5 | Section B enumerates three documented sync mechanisms (CSI Driver via SecretProviderClass; ESO; manual in-cluster Secret) as **candidates** for the ArgoCD repo PAT. `[PENDING: ask Fabrizio which one is in use for the gitops-vpp PAT on MC]`. The KV is most likely `vpp-aks-devops`; flag this as INFER not FACT. |
| Q6 | `ApplicationGenerationFromParamsError` is **not** documented in the Troubleshooting Guide. Runbook's "post-rotation verification" section cannot cite that error from wiki; it must be derived/probed live. Closest wiki match is the empty-Helm-image-tag / sync-fail pattern, which is a different failure mode. |

---

## Self-skepticism (sidecar declaration)

- All wiki content quoted is **INFER from a single retrieval**; coordinator should re-probe before using any quote as load-bearing FACT in the runbook.
- The "PAT renewal is our responsibility" quote is plausibly the strongest single signal in the search, but it is **a Slack quote embedded in a FAQ**, not a procedure. The FAQ tells consumers what NOT to worry about, not the Platform team how to do it.
- "NOT FOUND" answers are bounded by my query phrasing. Goldilocks specifically returns zero across three independent search surfaces; high confidence the term is not wiki-indexed under that spelling. If the spelling is `Goldilocks-MC`, `goldi`, or a code name with different casing handled by the search backend, that's a query-design gap, not a content gap — coordinator may want to try `repo-tree.sh --repo VPP.GitOps` or `--repo Eneco.Infrastructure --path /` greps as a follow-up.
- No adversarial dispatch performed on this sidecar — knowledge harvest with no claim-laundering risk, NOT-FOUND answers are auditable from search log, all URLs and quotes verbatim from script output. `[ROI-NEGATIVE: external adversarial; named falsifier = "did I quote vs paraphrase; did I conflate FAQ ownership statement with a procedure"; auditor evidence = quotes are byte-equal to script output above, paraphrase explicitly labeled]`.

(Word count: ~1480.)
