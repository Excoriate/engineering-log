---
task_id: 2026-05-11-002
agent: claude-opus-4-7
status: complete
summary: Discovery map — known knowns / known unknowns / mapped surface holes
classification: newly-mapped
phase: 2
---

# Discovery map — what we know vs. don't know

## Known knowns (FACT — source-verified in this P2)

| Fact | Source | Citation |
|---|---|---|
| 4 PATs in scope, all under `sa_platform_vpp@eneco.com` | Slack intake | `slack-intake.txt:2,4-9` |
| `argo-cd-sandbox` expired 2026-05-10T12:40:13Z (Critical) | Slack intake + vault incident | `slack-intake.txt:18-22` + `2026-05-11-pat-expiry-argocd-auth-break.md:41` |
| 3 MC PATs expire 2026-06-01 (Warning) | Slack intake | `slack-intake.txt:7-9` |
| Sandbox cluster: `vpp-aks01-d`, RG `rg-vpp-app-sb-401`, sub `7b1ba02e-…` | Vault recipe Step 1 + prior task codebase-map | recipe lines 45-50 + 2026-05-11-001 codebase-map:87-93 |
| Sandbox repo Secret: `repo-NNNNNNNNNN` Opaque under label `argocd.argoproj.io/secret-type=repository` | Vault recipe Step 2 | recipe lines 57-72 |
| Source repo: `VPP.GitOps` on `dev.azure.com/enecomanagedcloud/...` | Vault pattern + recipe | pattern line 25, recipe line 234 |
| ApplicationSet: `vpp-feature-branch-environments`, Git generator, ~3-min reconcile | Vault pattern | pattern lines 70-78 |
| Auth-break manifests as `ApplicationGenerationFromParamsError: ... authentication required` condition | Vault pattern + incident A1 | pattern line 39, incident line 41 |
| Symptom on FBE: pipeline 2412 `partiallySucceeded`, Pester 1/4, URL HTTP 404, namespace empty | Vault pattern + incident | pattern lines 29-39, incident lines 47-48 |
| 8 sandbox slots survived (afi/ionix/ishtar/jupiter/operations/thor/veku/voltex) because etcd-cached CRDs persist | Vault pattern blast radius | pattern lines 110-121 |
| F4 class is the AAD shared SP `6db398ec-…` (different surface) | Vault catalogue | catalogue F4 lines 171-208 |
| `vpp-appsec-d` KV contains ACC + DEVMC PAT secrets | Vault keyvault-secrets | keyvault-secrets:28-29 |
| 218 secrets total across 11 categories in `vpp-appsec-d` (canonical) | Cross-ref to 06-azure-deep-state §6.2.1 | keyvault-secrets:22 |

## Known unknowns (UNVERIFIED — must probe in P4 or escalate to Fabrizio)

### Group A — MC cluster topology (BLOCKS the MC half of the runbook)

| Question | Probe candidate | Severity |
|---|---|---|
| What are the MC cluster names (dev/acc/prd)? AKS or OpenShift? | `kubectl config get-contexts` after MC SP login; or ask Fabrizio | HIGH — runbook can't name the cluster without this |
| Which namespace hosts MC ArgoCD? `argocd` (sandbox-parity) or `openshift-gitops`? | `kubectl get namespaces \| grep -E "argo\|gitops"` after MC connect | HIGH |
| What is the secret naming for MC ArgoCD repo creds? `repo-*` (sandbox-parity)? Or declarative `argocd-cm` entries? | `kubectl get secret -n <ns> -l argocd.argoproj.io/secret-type=repository` | HIGH |
| Does each MC env have its own ArgoCD installation, or one MC-wide installation? | Topology probe | MEDIUM — affects whether 3 PATs map to 3 secrets in 3 clusters or 3 secrets in 1 cluster |

### Group B — KV-to-cluster sync (BLOCKS understanding source-of-truth)

| Question | Probe candidate | Severity |
|---|---|---|
| Is the MC PAT propagated from KV → cluster Secret via ESO, CSI driver, IaC, or manual patch? | `kubectl get externalsecret -n <ns>` + `kubectl get secretproviderclass -n <ns>` + grep IaC repo for `kubernetes_secret` | HIGH — wrong assumption breaks the rotation |
| Where is the sandbox PAT stored as source of truth? (KV? Or only in cluster Secret?) | `az keyvault secret list --vault-name vpp-appsec-d --query "[?contains(name, 'sandbox')]"` | MEDIUM |
| Are the 3 MC PATs stored in `vpp-appsec-d` or in env-specific KVs (`vpp-appsec-a`, `vpp-appsec-p`)? | `az keyvault list \| grep vpp-appsec` + `secret list` for each | HIGH — must rotate the correct KV |

### Group C — Repository semantics

| Question | Probe candidate | Severity |
|---|---|---|
| What is the "cmc-goldilocks" repository? URL, content, owner | Ask Fabrizio; or read MC ArgoCD repo Secret `.data.url` | MEDIUM |
| What scopes does the MC PAT need (Code Read only, or also Code Status / Build Read for CI integration)? | Ask Fabrizio; or check ArgoCD docs for repo-creds scopes | MEDIUM |

### Group D — Operational policy

| Question | Probe candidate | Severity |
|---|---|---|
| Who has authority to mint a PAT for `sa_platform_vpp@eneco.com`? | Ask Fabrizio / Trade Platform lead | HIGH — Alex must NOT proceed if not authorized |
| Is there a written rotation SLA (e.g., 7 days for Warning, 24h for Critical)? | Wiki search via eneco-context-docs | LOW — observed-only is acceptable |
| What is the post-rotation verification cadence? (Beyond the 90s ApplicationSet recovery — is there a longer check?) | Wiki search; or ask Fabrizio | LOW |

### Group E — Adjacent automation

| Question | Probe candidate | Severity |
|---|---|---|
| Who/what generates the PAT-expiry report posted to `#myriad-alerts-devops`? | eneco-context-slack search; or ask Fabrizio | MEDIUM — needed for automation proposal |
| Is the report based on ADO REST API, or on a manual maintained list? | Same | MEDIUM |
| Are there other related PATs (build pipelines, snyk, etc.) not in this list but also approaching expiry? | Read full alert; cross-ref with broader audit | LOW — out of this task's scope |

## Map class summary

| Map | Class | Reason |
|---|---|---|
| ai-map.md | reused (harness) + newly-mapped (skill stack for THIS task) | Same harness as prior task but different skill stack |
| codebase-map.md | newly-mapped (rotation surface) + reused (FBE/Argo context from 001) | Cross-references prior task; rotation surface is novel |
| docs-map.md | newly-mapped (gap list) + reused (vault structure already enumerated) | First time mapping rotation-doc-surface explicitly |
| config-map.md | newly-mapped | First time mapping the 4-PAT inventory + naming pattern |
| automation-map.md | newly-mapped | First time mapping the alert→human→propagation→reconcile chain |
| discovery-map.md (this) | newly-mapped | Gap list output |

## System-coherence cross-checks done in P2

| Cross-check | Result |
|---|---|
| Vault recipe Step 1 cluster name `vpp-aks01-d` vs prior task 2026-05-11-001 codebase-map RG `rg-vpp-app-sb-401` | ✓ Coherent (same sandbox cluster) |
| Vault keyvault-secrets line 28-29 (ACC + DEVMC PATs) vs slack-intake line 7-9 (3 MC PATs flagged) | ✗ INCOHERENT — vault note shows only 2 (acc, devmc), intake shows 3 (devmc, accmc, prdmc). **`vpp-appsec-d` may be missing `accmc` and `prdmc` entries**, OR vault note is incomplete. Resolve in P4. |
| Vault recipe expects ADO repo URL contains `VPP.GitOps` (sandbox) vs MC PATs contain `cmc-goldilocks-repository` in name | ✓ Coherent (different repos = different PATs by ArgoCD convention) |
| Vault incident timeline (2026-05-08 alert, 2026-05-10T12:40 expiry, 2026-05-11 ~12:23 surfaced) vs intake | ✓ Coherent |
| Prior task 2026-05-11-001 wrote nothing about PAT rotation; this task is non-overlapping | ✓ Coherent — separate surfaces, no conflict |
