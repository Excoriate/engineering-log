# Draft — Rotation Secrets Harvest (ArgoCD PATs, 2026-05-11)

> **What this doc is**: the evidence base behind [`how-to-rotate.md`](./how-to-rotate.md). Every claim about the 4 expiring ArgoCD PATs is listed here with provenance (vault / Slack / wiki / IaC / runtime) and a belief label (A1 FACT / A2 INFER / A3 UNVERIFIED).
>
> **What this doc is NOT**: a runbook. For step-by-step rotation see `how-to-rotate.md`. For the automation proposal see `proposal-rotation-automation.md`.
>
> **Audience**: Alex (on-call author), Fabrizio (reviewer), future on-call engineers needing the citation chain.
>
> **Source coverage**: Obsidian vault (`2-areas/work-eneco`), Slack via `eneco-context-slack`, ADO wiki via `eneco-context-docs`, IaC repos via `eneco-context-repos`. All conclusions are INFER until source-verified by a witness ≠ producer.

---

## 1. The 4 PATs in scope

Verbatim from the 2026-05-08 PAT expiration report posted to `#myriad-alerts-devops`, captured in `slack-intake.txt:2-9`:

| PAT name | Expiry (MM/DD/YYYY) | Status | Owner |
|---|---|---|---|
| `argo-cd-sandbox` | 05/10/2026 | **Critical (EXPIRED)** | `sa_platform_vpp@eneco.com` |
| `argo-cd-devmc-cmc-goldilocks-repository` | 06/01/2026 | Warning | `sa_platform_vpp@eneco.com` |
| `argo-cd-accmc-cmc-goldilocks-repository` | 06/01/2026 | Warning | `sa_platform_vpp@eneco.com` |
| `argo-cd-prdmc-cmc-goldilocks-repository` | 06/01/2026 | Warning | `sa_platform_vpp@eneco.com` |

Today's surfacing thread permalink: <https://eneco-online.slack.com/archives/C063YNAD5QA/p1778495545088229>

---

## 2. Timeline of the precipitating incident

Reconstructed from `slack-intake.txt:18-49` + vault note `[[2026-05-11-pat-expiry-argocd-auth-break]]` lines 37-52 (the incident page authored earlier today):

| When (UTC) | Where | Event |
|---|---|---|
| 2026-05-08 | `#myriad-alerts-devops` | Automated PAT-expiry report posts; `argo-cd-sandbox` flagged `Critical` |
| 2026-05-10T12:40:13Z | sandbox AKS `vpp-aks01-d`, ns `argocd` | `vpp-feature-branch-environments` ApplicationSet first fails with `ApplicationGenerationFromParamsError: ... authentication required` |
| 2026-05-10T12:40 → 2026-05-11T~10:00 | Sandbox cluster | Silent degradation window — any new slot create/recycle produces empty FBE |
| 2026-05-11T08:00:43Z | ADO build 1638601 | Duncan triggers FBE-create on slot `kidu`; fails at Stage 3 (separate F2 orphan issue, fixed in task `2026-05-11-001_fbe-error-duncan`) |
| 2026-05-11T09:58Z | (Alex's earlier task) | F2 orphan fixed; Stage 3 unblocked |
| 2026-05-11T09:59:53Z | ADO build 1639150 | FBE-create re-runs; reaches Stage 6 |
| 2026-05-11T10:33:15Z | `VPP.GitOps` `feature-branch-environments/kidu.yaml` | Commit `13592fc` succeeds (Stage 6 git push) |
| 2026-05-11T10:37:11Z | Pipeline 1639150 | Ends `partiallySucceeded`; Pester `Total: 4, Success: 1, Failures: 3`; Slack notification posts |
| 2026-05-11T~10:42Z | Duncan in `#myriad-platform` | "It seems it does not load the UI though..." |
| 2026-05-11T~12:23Z | Fabrizio in `#myriad-platform` | "Has anybody renewed the Pat Token used by the Argocd in Sandbox?" |
| 2026-05-11T12:30Z | Alex in `#myriad-platform` | "I will take a look after lunch — is there any documentation, or particular caveat that I need to know in advance?" |
| 2026-05-11T12:47:35Z | Fabrizio (verbatim) | "Nope. There is no documentation for this. It is a good opportunity to create one. You can give me a call and I explain you the process." |
| **NOW** | This document + runbook | Authoring response |

---

## 3. Cross-source convergence matrix

Per the BRAIN's Cognitive Gate 2 (Belief-status). Each load-bearing claim is graded:

- **A1 FACT** = externally-witnessable; cited probe / Slack screenshot / pipeline log / kubectl describe
- **A2 INFER** = derived from A1 facts; derivation labeled inline
- **A3 UNVERIFIED[<class>: <reason>]** = could not be re-probed in this session

| # | Claim | Vault | Slack | Wiki | IaC | Status |
|---|---|---|---|---|---|---|
| C1 | 4 PATs in scope, owner `sa_platform_vpp@eneco.com` | ✓ | ✓ | ✓ | ✓ | **A1 FACT** (4-source) |
| C2 | Sandbox cluster = AKS `vpp-aks01-d`, RG `rg-vpp-app-sb-401`, sub `7b1ba02e-bac6-4c45-83a0-7f0d3104922e` | ✓ | (prior 2026-05-11-001 evidence) | ✓ | ✓ | **A1 FACT** |
| C3 | Auth-break timestamp = `2026-05-10T12:40:13Z` | ✓ | ✓ | — | — | **A1 FACT** (2-source) |
| C4 | NO canonical written rotation procedure exists | ✓ (vault flags absence) | ✓ (Fabrizio verbatim "no doc") | partial (FAQ ownership only) | ✓ (no runbook in repo) | **A1 FACT** (4-source, but bounded — see C16) |
| C5 | MC ArgoCD URLs `eneco-vpp-server-eneco-vpp-argocd.apps.eneco-vpp-{dev,acc,prd}.ceap.nl` | — | — | ✓ | ✓ (CR exists) | **A1 FACT** (2-source) |
| C6 | TWO ArgoCD per MC cluster: `eneco-vpp-argocd` (custom) + `openshift-gitops` (Red Hat Operator) | — | — | ✓ | ✓ (operator CR confirmed) | **A1 FACT** |
| C7 | PAT-expiry generator = ADO pipeline at `myriad-vpp/devops/azure-pipelines.yml` running `scripts/azure-devops-pat-token-monitor.ps1` | — | ✓ (PR 140615 reference) | ✓ (Secret-expiry-pipeline id 36619 + defId 2735) | ✓ (script + yaml on disk) | **A1 FACT** (3-source) |
| C8 | PAT-expiry monitor only watches `sa_platform_vpp@eneco.com`-owned PATs | — | — | ✓ | ✓ (script docstring) | **A1 FACT** |
| C9 | `sa_platform_vpp@eneco.com` LOGIN credentials are in Trade Platform Team password vault (1Password/Bitwarden) | — | ✓ (Roel Jan 23 2026) | — | — | **A2 INFER** (1-source; Slack quote is testimony, not proof of vault content) |
| C10 | Stored credentials are the SA LOGIN, NOT the derived PATs | — | ✓ (Roel "I've put the sa_platform_vpp **account credentials**" — line 73 vault-extracts) | — | — | **A2 INFER** (per Socrates S3 attack: derivative tokens are not the same as login creds) |
| C11 | MC ArgoCD PATs may be operated by CMC-side staff ("Lex from CMC") | — | ✓ (Roel 2026-03-03: "I asked him to update a PAT for me in the CMC ArgoCD instance for the Goldilocks application") | — | — | **A3 UNVERIFIED[reason: single hint, "him" identity not 100% confirmed]** — Group A in gap-list |
| C12 | `goldilocks` is the name of a specific ArgoCD application (NOT the k8s VPA tool of the same name) | — | ✓ (Roel quote calls it "the Goldilocks application") | ✗ (no wiki hit; `goldilocks` returned 0 results across all wiki searches) | ✗ (no IaC reference except unrelated k8s VPA Goldilocks resources) | **A3 UNVERIFIED[unknown]** — Group C in gap-list |
| C13 | No External Secrets Operator (ESO) is deployed | — | — | partial (mentioned as deployable, not as deployed) | ✓ (zero `ExternalSecret`/`SecretStore`/`ClusterSecretStore` matches) | **A1 FACT** |
| C14 | KV `vpp-appsec-d` contains entries `argocd-repository-credentials-template-url-{acc,devmc}` (2 of 4 expected) | ✓ (note `eneco-vpp-keyvault-secrets.md:28-29`) | — | — | ✓ (KV entries exist but NOT Terraform-managed) | **A1 FACT** + **A2 INFER** (the entries exist but are likely vestigial/manual; see C15) |
| C15 | The KV ArgoCD PAT entries are NOT Terraform-managed | — | — | — | ✓ (zero matches for `azurerm_key_vault_secret.*argocd` across all `.tf`) | **A1 FACT** |
| C16 | NO sync mechanism exists for KV → cluster Secret on the ADO Git PAT axis | — | — | partial (no wiki page names the mechanism) | ✓ (no ESO; CSI is OCI-only) | **A1 FACT** (3 orthogonal IaC harvests) |
| C17 | Sandbox ArgoCD is Kustomize-installed `argo-cd/v2.10.5/manifests/install.yaml` | — | — | partial | ✓ (`VPP.GitOps/argocd/base/kustomization.yaml`) | **A1 FACT** |
| C18 | A Helm chart exists for repository Secrets at `myriad-vpp/ArgoCD-Config/Helm/repositories/templates/deployment.yaml` — **renders `argocd.argoproj.io/secret-type: repository` Secrets with name/url/username/password from `.Values`** | — | — | — | ✓ (IaC sidecar lines 36-51) | **A1 FACT** — this is the smoking-gun for the Step 4.5 ownership probe (el-demoledor V5) |
| C19 | The Helm chart targets namespace `eneco-vpp-argocd` (MC), not `argocd` (sandbox) | — | — | — | ✓ | **A1 FACT** — but per Socrates S1, "absence of evidence ≠ evidence of absence": a different Helm release MAY manage the sandbox Secret too |
| C20 | MC ArgoCD = OpenShift GitOps Operator CR (`apiVersion: argoproj.io/v1beta1 kind: ArgoCD`) at `mcc-landing-zone/gitops-vpp/gitops-vpp/main/argocd/{dev,acc,prd}/team-vpp/eneco-vpp-argocd.yaml`, namespace `eneco-vpp-argocd` | — | — | partial | ✓ | **A1 FACT** |
| C21 | ApplicationSet recovers after rotation: `argocd.argoproj.io/refresh=hard` annotation triggers a fresh Git fetch; condition `ErrorOccurred=False` with fresh `lastTransitionTime` signals success | ✓ (vault recipe Step 6) | — | — | (ArgoCD upstream behaviour) | **A2 INFER** (per Socrates S4 two-clock attack: this signal is necessary but NOT sufficient — see C22) |
| C22 | The ApplicationSet condition is a different "clock" from the controller's credential cache; status flip can be a stale-cache flicker, not a true recovery | — | — | — | — | **A2 INFER** (per Socrates S4 attack; mechanism is ArgoCD informer cache TTL); MUST be addressed by Step 6.5 in runbook |
| C23 | The OLD PAT remains valid in ADO until natural expiry unless explicitly revoked; 21-day residual exposure for MC PATs | — | (implicit) | (implicit) | (ADO standard behaviour) | **A2 INFER** (ADO docs); addressed by runbook Step 10 (el-demoledor V9) |
| C24 | F4 class — AAD shared SP `6db398ec-8cb7-4398-a944-f842aa9a67da` — is a DIFFERENT rotation class (per-FBE cascade); rotated Dec 29 2025 by Fabrizio across Thor/Voltex/Jupiter/integrationtest/Kidu | ✓ (catalogue F4) | ✓ (thread `C063SNM8PK5/p1767014621744099`) | — | — | **A1 FACT** (out of scope for this task but referenced in proposal) |
| C25 | PXQ incident 2026-05-07 (4 days before today) was the same class (keyvault client secret expired) — pattern is recurring | — | ✓ (`C0B239D1FRR/p1778164253499109`) | — | — | **A1 FACT** (1-source but verbatim Slack quote) |
| C26 | INC-75 (2024-11-19, Fabrizio): "This manual process is error-prone and must be automated to prevent such issues in the future." | — | ✓ (`C081GTVSZFD/p1732022060724869`) | — | — | **A1 FACT** |
| C27 | Fabrizio DM 2026-04-10: "this is a shit job to be done and can cause outages" — direct backing for automation proposal | — | ✓ (`D09K5LQSW0G/p1775834268694299`) | — | — | **A1 FACT** |

---

## 4. Per-PAT current understanding

### 4.1 `argo-cd-sandbox` (expired 2026-05-10, blocking Duncan now)

| Field | Value | Source |
|---|---|---|
| ADO PAT identity | minted under `sa_platform_vpp@eneco.com` | C1 |
| Cluster | AKS `vpp-aks01-d`, RG `rg-vpp-app-sb-401`, sub `7b1ba02e-...` | C2 |
| ArgoCD install | Kustomize+upstream `argo-cd/v2.10.5` | C17 |
| Namespace | `argocd` | vault recipe |
| Repo Secret naming | `repo-NNNNNNNNNN` (10-digit hash) per ArgoCD convention | C18 + vault recipe |
| Secret ownership | `[UNVERIFIED[ask Fabrizio + probe live cluster]]` — IaC found no Terraform/ESO/CSI, but Helm chart pattern exists at `iac-secret-templates.md:36-51`; live cluster Secret may carry `app.kubernetes.io/managed-by: Helm` label per Socrates S1 + el-demoledor V5 | C16, C18 |
| Source-of-truth (PAT value) | Trade Platform Team password vault (LOGIN); PATs themselves likely transient between mint and cluster-apply | C9, C10 |
| Sync mechanism | Manual `kubectl patch` per vault recipe — assumes Secret is unmanaged; MUST be verified by Step 4.5 ownership probe in runbook | (derived) |
| ApplicationSet consumer | `vpp-feature-branch-environments` in ns `argocd` | vault pattern doc |
| Blast radius (current) | 3 broken slots (kidu, boltz, enel); 8 surviving (afi/ionix/ishtar/jupiter/operations/thor/veku/voltex) | vault incident page |

### 4.2 `argo-cd-devmc-cmc-goldilocks-repository` (expires 2026-06-01)

| Field | Value | Source |
|---|---|---|
| ADO PAT identity | `sa_platform_vpp@eneco.com` per intake report | C1 |
| Cluster | OpenShift, `api.eneco-vpp-dev.ceap.nl`; ArgoCD reachable at `eneco-vpp-server-eneco-vpp-argocd.apps.eneco-vpp-dev.ceap.nl` | C5 |
| ArgoCD install | TWO instances coexist: `eneco-vpp-argocd` (custom Operator CR) at namespace `eneco-vpp-argocd`, AND `openshift-gitops` (Red Hat Operator) at namespace `openshift-gitops` — `[PENDING: which one holds this PAT]` | C6, C20 |
| Repo Secret naming | `[UNVERIFIED[ask Fabrizio]]` — likely `argocd.argoproj.io/secret-type=repository` Opaque, name unknown | (derived) |
| Source-of-truth (PAT value) | `[UNVERIFIED]` — KV `vpp-appsec-d` has an entry `argocd-repository-credentials-template-url-devmc` (C14) but it is NOT Terraform-managed (C15) and has no documented sync mechanism (C16) — likely vestigial | C14, C15, C16 |
| Operator | OpenShift GitOps Operator on MC; may manage / revert Secrets it watches (el-demoledor V13) | C20 |
| Rotation actor | `[UNVERIFIED[Group A: Trade Platform vs CMC]]` — Roel 2026-03-03 hint suggests CMC ("Lex from CMC") | C11 |
| Goldilocks ArgoCD application | exists per Roel quote; purpose/repo unknown | C12 |

### 4.3 `argo-cd-accmc-cmc-goldilocks-repository` (expires 2026-06-01)

Same shape as 4.2, in acc env (`api.eneco-vpp-acc.ceap.nl` / `eneco-vpp-server-eneco-vpp-argocd.apps.eneco-vpp-acc.ceap.nl`). **No KV entry for `accmc`** in `vpp-appsec-d` per vault note C14 — gap.

### 4.4 `argo-cd-prdmc-cmc-goldilocks-repository` (expires 2026-06-01)

Same shape as 4.2, in prd env (`api.eneco-vpp-prd.ceap.nl`). **No KV entry for `prdmc`** in `vpp-appsec-d` — gap. **Production** — highest blast radius if mis-rotated.

---

## 5. Adjacent rotation classes (out of scope, but referenced in proposal)

| Class | Surface | Status | Reference |
|---|---|---|---|
| F4 — AAD shared SP `6db398ec-...` | client secret expiry, per-FBE cascade | rotated Dec 29 2025 by Fabrizio | C24, `[[fbe-failure-modes-catalog#F4]]` |
| ESP / Axual mTLS cert | VPPAL prod cert | runbook in wiki id 50903 + vault `[[vppal-cert-rotation-runbook]]` | (referenced; structural template) |
| TF SP credentials (MC DTA/PRD) | Terraform CI/CD SPs in `mcc-kv-vppdeploy*` KVs | rotated dynamically by 3-stage login flow | `[[eneco-mc-vpp-credentials-ci-cd]]` |
| Per-FBE KV (`vpp-fbe-{slot}-{suffix}`) | per-slot secrets | per-slot mgmt | F4 lesson |
| BTM app-reg client secret | rotation runbook in wiki id 68382 | structural template | (referenced) |
| ADO build-agent PATs | "I have renewed the PAT Tokens used by the private build agents" — Fabrizio 2025-09-29 | manual, post-hoc Slack announce | `slack-rotation-harvest.md:26` |
| PXQ keyvault client secret | expired 2026-05-07 | recent incident; same class | C25 |

**The proposal-rotation-automation.md** argues for unified rotation discipline across these classes — but THIS task's runbook covers ONLY the 4 ArgoCD PATs.

---

## 6. Source artefacts on disk (for the auditor)

```
.ai/tasks/2026-05-11-002_rotating-expired-argocd-secrets/
├── 01-task-requirements-initial.md         # P1 mirror
├── 01-task-requirements-final.md           # P3 final
├── manifest.json                           # task manifest with adversarial dispatch log
├── context/
│   ├── ai-map.md                            # P2 ai-map
│   ├── codebase-map.md                      # P2 rotation surface
│   ├── config-map.md                        # P2 secrets inventory
│   ├── automation-map.md                    # P2 alert→human→propagation
│   ├── docs-map.md                          # P2 vault + wiki + slack docs
│   ├── discovery-map.md                     # P2 known/unknown
│   ├── vault-extracts.md                    # P4 vault verbatim
│   ├── hypotheses.md                        # P4 H1-H7 + decision matrix
│   ├── slack-rotation-harvest.md            # P4 Slack sidecar artefact
│   ├── wiki-rotation-search.md              # P4 wiki sidecar artefact
│   ├── iac-secret-templates.md              # P4 IaC sidecar artefact
│   ├── proposal-options-draft.md            # P4 options pre-draft
│   └── visuals-draft.md                     # P4 mermaid + ASCII drafts
├── auxiliary/
│   ├── socrates-attack-on-procedure.md     # P5 Socrates adversarial
│   ├── eldemoledor-attack.md               # P5 el-demoledor adversarial
│   └── adversarial-receipts.md             # P5 receipts (Accept/Rebut/Defer)
├── plan/plan.md                             # P5 plan with 6Qs
├── specs/
│   ├── draft-rotation-secrets.spec.md      # spec for this doc
│   ├── how-to-rotate.spec.md               # spec for runbook
│   └── proposal-rotation-automation.spec.md # spec for proposal
└── verification/phase-8-results.md         # P8 (pending)
```

Vault notes used (all under `2-areas/work-eneco/`):
- `eneco-vpp-platform/fbe-errors/recipe-rotate-argocd-sandbox-pat.md`
- `eneco-vpp-platform/fbe-errors/pattern-argocd-pat-expiry-blocks-new-fbe-apps.md`
- `eneco-vpp-platform/fbe-errors/2026-05-11-pat-expiry-argocd-auth-break.md`
- `eneco-vpp-platform/eneco-vpp-keyvault-secrets.md`
- `eneco-vpp-platform/eneco-vpp-argocd-healthy-but-unreachable-troubleshooting.md`
- `eneco-vpp-vppal/vppal-cert-rotation-runbook.md`
- `eneco-vpp-platform/fbe/fbe-failure-modes-catalog.md` (F4 section)
- `eneco-vpp-landscape/eneco-mc-vpp-credentials-ci-cd.md`

---

## 7. Open questions to Fabrizio — the questionnaire

This is the **primary user-outcome** of this document (per task SC1). Hand to Fabrizio as a focused list. Each question states: (a) the question, (b) why it's load-bearing for the runbook/proposal, (c) the cheapest probe Fabrizio could give you instead of an answer.

### Group A — MC cluster topology + rotation actor (blocks runbook Section B)

> **A1. Which ArgoCD instance per MC cluster holds the PAT `argo-cd-{env}mc-cmc-goldilocks-repository` — `eneco-vpp-argocd` (your custom Operator CR) or `openshift-gitops` (the Red Hat Operator install)?**
> - Why load-bearing: both instances exist (`eneco-vpp-server-eneco-vpp-argocd.apps.eneco-vpp-{env}.ceap.nl` and `openshift-gitops-server-openshift-gitops.apps.eneco-vpp-{env}.ceap.nl`); patching the wrong one is a silent no-op
> - Cheapest answer: a 1-line message naming the instance + namespace

> **A2. Are the MC PATs minted by Trade Platform OR by CMC-side staff (e.g. "Lex from CMC" per Roel's 2026-03-03 message)?**
> - Why load-bearing: if CMC-operated, my Section B becomes a CMC ticket template, not a procedure I execute
> - Cheapest answer: "we mint and they apply" / "they mint" / "we both can"

> **A3. If Trade Platform mints + CMC applies, what is the SECURE TRANSMISSION CHANNEL for the new PAT?**
> - Why load-bearing: never send a PAT via Slack DM or email; need a specific channel
> - Cheapest answer: "use the 1Password secure share link" / "drop in Azure KV with CMC ACL"

> **A4. Does Trade Platform have `oc` access to the MC OpenShift clusters' `eneco-vpp-argocd` namespace?**
> - Why load-bearing: if not, we cannot probe ownership / verify post-rotation directly
> - Cheapest answer: "yes via this AAD group" / "no, ask CMC"

### Group B — Ownership of the in-cluster Secret (blocks Step 4.5 + Step 5)

> **B1. On sandbox AKS `vpp-aks01-d`, namespace `argocd`: is the `repo-*` Opaque Secret holding the gitops-vpp PAT applied by anything (Helm, sealed-secrets, an ArgoCD Application, manual kubectl)?**
> - Why load-bearing: if anything reconciles it, my `kubectl patch` will be silently reverted within ~minutes-hours
> - Cheapest probe Fabrizio could give you: `kubectl get secret <name> -n argocd -o yaml | head -20` showing labels/annotations

> **B2. On MC, is the `eneco-vpp-argocd` namespace's repo Secret managed by your Helm chart (`myriad-vpp/ArgoCD-Config/Helm/repositories`), by the OpenShift GitOps Operator's CR `spec.repo.repositories`, by `oc apply` manually, or by SealedSecret (Bitnami) controller?**
> - Why load-bearing: same as B1 but for MC. The chart at `iac-secret-templates.md:36-51` targets `eneco-vpp-argocd` ns — strong evidence of Helm management
> - Cheapest probe: `oc -n eneco-vpp-argocd get secret <name> -o yaml | head -20`

### Group C — Repository identity (blocks runbook prose + proposal framing)

> **C1. What is the `cmc-goldilocks` repository? Concrete: ADO project + repo URL + what's in it + what consumes it.**
> - Why load-bearing: my runbook + proposal need to name it; reader can't reason about scope without knowing what the PAT actually unlocks
> - Cheapest answer: a 1-line "it's `dev.azure.com/.../X/_git/Y`, contains Z, consumed by W"

> **C2. What ADO PAT scopes are required for the MC PATs? (Sandbox uses Code Read for `VPP.GitOps`. Is MC the same, or does it need Build Read / Status / Packaging Read for `cmc-goldilocks`?)**
> - Why load-bearing: minimum-scope principle; over-permission is a security cost
> - Cheapest answer: "Code Read only" / "Code Read + Build Read because..."

### Group D — Operational policy (blocks proposal SLA section)

> **D1. Who is authorised to mint a PAT under `sa_platform_vpp@eneco.com` in ADO? You? Anyone in Trade Platform? Specific named individuals?**
> - Why load-bearing: my runbook G1 pre-flight gate; on-call may not have minting authority at 3 AM
> - Cheapest answer: a list or a policy reference

> **D2. Is there an IP-restricted-PAT policy on `sa_platform_vpp` PATs? (Could a PAT minted from Alex's laptop work from his laptop but fail from the cluster's egress IP?)**
> - Why load-bearing: el-demoledor V4 — failing post-mint diagnostic shape
> - Cheapest answer: "no restriction" / "yes, AKS egress IPs are allowlisted via ..."

> **D3. Is there a written rotation SLA, or is it event-driven via the expiry alert?**
> - Why load-bearing: proposal's "define SLA" deliverable scope
> - Cheapest answer: "no SLA; we rotate when alerted" / "Code-Read says 7d/24h"

### Group E — Documentation surface (blocks runbook canonical placement)

> **E1. Is there anything in `Platform-team-internal` ADO wiki, a `#team-platform` Slack canvas, or in the Trade Platform Team password vault NOTES (not just the SA credential) that documents the rotation procedure?**
> - Why load-bearing: per Socrates S2, "no documentation" may be search-scope-bounded; want to extend rather than duplicate
> - Cheapest probe Fabrizio could give you: a wiki URL or "no, nothing"

> **E2. When the rotation is complete, should the runbook live in `Platform-team-internal` wiki, in `Myriad - VPP` wiki, in this engineering log, or somewhere else?**
> - Why load-bearing: canonical placement post-publication
> - Cheapest answer: "drop it in Platform-team-internal/Operations/" or similar

### Group F — Automation (blocks proposal)

> **F1. The PAT-expiry monitor (`myriad-vpp/devops/azure-pipelines.yml` + `azure-devops-pat-token-monitor.ps1`) — can we extend it with: (a) Grafana alert on `argocd_appset_status{condition_type="ErrorOccurred"}`, (b) an SLA-enforcement timer, (c) auto-rotation via Workload Identity Federation?**
> - Why load-bearing: proposal's Phase 1/2 sequencing
> - Cheapest answer: "yes you own it" / "no, that's CCoE territory"

---

## 8. Anti-patterns surfaced (cross-source)

For inclusion in the runbook (`how-to-rotate.md` section 9) — each anti-pattern has a mechanism explanation, not just a "don't":

1. **Delete and recreate the affected FBE** (vault pattern doc + recipe) — would land in the same broken state; ArgoCD still can't fetch the repo
2. **Restart `argocd-application-controller`** (vault) — controller restart doesn't refresh the Secret's cached credential
3. **Manually create the Application CRDs in the {slot} namespace** (vault) — symptomatic; ApplicationSet would prune later; introduces drift
4. **Disable the ApplicationSet sync policy** (vault) — silences symptom; breaks GitOps contract
5. **Echo PAT to stdout / paste in chat / commit to repo** (vault + universal) — bearer credential leak
6. **Widen PAT scopes beyond Code Read** (vault) — increases blast radius if leaked
7. **Use personal PAT in cluster** (vault) — couples cluster auth to your AAD account; rotates when you leave
8. **Skip the curl test before patching** (vault) — silent broken auth for another reconcile cycle before noticing
9. **(NEW per el-demoledor V5) `kubectl patch` on a Helm/Operator-managed Secret** — silent revert on next sync; the patch wins for ~30 min then loses
10. **(NEW per el-demoledor V8) Trust HTTP 200 + headers as proof of FBE health** — NGINX/APIM can inject correlation-id headers; SPA catch-all returns 200; body content + pod readiness are the truth surface
11. **(NEW per el-demoledor V11) Update KV and assume sync** — no KV→cluster sync mechanism exists for MC ADO Git repo PATs; KV update is documentation theater
12. **(NEW per el-demoledor V10 + Socrates S3) Mint MC PAT without confirming CMC-vs-Trade-Platform ownership** — wrong actor = silent no-op; CMC ticket without explicit ArgoCD instance is an ambiguous request
13. **(NEW per Socrates S3) Transmit new PAT to CMC via Slack DM or email** — leak surface + retention
14. **(NEW per el-demoledor V9) Leave OLD PAT alive post-rotation** — old PAT remains valid until natural expiry; 21-day exposure window for MC PATs
15. **(NEW per Socrates S2) Promote "no documentation exists" to FACT without checking `Platform-team-internal` wiki / Slack canvases / 1Password notes** — source-bounded absence

---

## 9. Belief-status summary

| Class | Count | Examples |
|---|---|---|
| A1 FACT (≥2 independent sources or single live probe) | 15 | C1, C2, C3, C4, C5, C6, C7, C8, C13, C15, C16, C17, C18, C20, C24, C25, C26, C27 |
| A2 INFER (derived from A1; named derivation) | 6 | C9, C10, C19, C21, C22, C23 |
| A3 UNVERIFIED[<class>] | 2 + Group A/B/C/D/E/F gaps | C11, C12 + the 13 gap-list items above |

No claim is unflagged. No load-bearing inference is silently promoted to FACT. The runbook + proposal stand on this evidence base.

---

## 10. Self-skepticism (this doc's own audit)

What I'd accept as falsifiers of THIS draft:
- If Fabrizio answers Group E1 with "yes there's a `Platform-team-internal/Operations/RotateArgoCD` page" — half of C4's "no docs" claim is wrong and the runbook should reference that page first
- If Fabrizio answers Group A2 with "we mint AND apply MC PATs ourselves" — C11 collapses, Section B simplifies dramatically
- If Fabrizio answers Group B1 with "Helm-managed via `Eneco.HelmCharts/argocd-platform`" — C18-C19 generalises to sandbox; vault recipe's manual patch is the wrong mechanism for sandbox
- If a live `kubectl get secret -o yaml` on sandbox shows zero ownership annotations — el-demoledor V5's smoking gun is downgraded for sandbox application (still applies to MC)

**These falsifiers are deliberately cheap**. Cost of getting them: one Fabrizio DM + one kubectl call (if Alex chooses to run live probes). Cost of NOT getting them before publishing: a runbook that lies to the operator. The runbook is structured so the answers slot in as section revisions, not rewrites.
