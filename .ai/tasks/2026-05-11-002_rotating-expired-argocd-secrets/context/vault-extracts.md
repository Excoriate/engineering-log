---
task_id: 2026-05-11-002
agent: claude-opus-4-7
status: complete
summary: Consolidated verbatim quotes from vault notes that ground the runbook authorship
phase: 4
---

# Vault extracts — source-verified quotes for deliverable authorship

> Each block below is a load-bearing quote from a vault note. Citation precedes each quote in the form `<note>:<line>`. These are the source basis for claims in `draft-rotation-secrets.md`, `how-to-rotate.md`, and `proposal-rotation-automation.md`.
>
> **Epistemic guard**: vault notes are MY OWN PRIOR WRITES (Agent Laundering risk). They remain INFER until corroborated by Slack/wiki/IaC sidecars. The deliverables MUST cite vault as the source, not promote vault claims to FACT.

## E1 — The 4 PATs (from intake)

`slack-intake.txt:2-9`:
```
Expiration PAT Tokens Report - Service Account [sa_platform_vpp@eneco.com]

| PAT Token Name                                              | ExpireDate | Status   |
| argo-cd-sandbox                                             | 05/10/2026 | Critical |
| argo-cd-devmc-cmc-goldilocks-repository                     | 06/01/2026 | Warning  |
| argo-cd-accmc-cmc-goldilocks-repository                     | 06/01/2026 | Warning  |
| argo-cd-prdmc-cmc-goldilocks-repository                     | 06/01/2026 | Warning  |
```

`slack-intake.txt:12`:
```
https://eneco-online.slack.com/archives/C063YNAD5QA/p1778495545088229
```

## E2 — Confirmation timestamp (auth-break)

`2026-05-11-pat-expiry-argocd-auth-break.md:41`:
> When: 2026-05-10T12:40:13Z | Where: sandbox AKS `vpp-aks01-d`, namespace `argocd` | Event: `vpp-feature-branch-environments` ApplicationSet's Git generator first fails with `ApplicationGenerationFromParamsError: error retrieving Git files: rpc error: code = Internal desc = unable to resolve git revision : authentication required`. Reconcile cycle ~3 min; the error has been re-emitted continuously for ~22h by the time of investigation. | Evidence: A1 — `kubectl describe applicationset vpp-feature-branch-environments -n argocd` returned the condition with `lastTransitionTime: 2026-05-10T12:40:13Z`

## E3 — Sandbox cluster context (recipe Step 1)

`recipe-rotate-argocd-sandbox-pat.md:45-50`:
```bash
az account set --subscription 7b1ba02e-bac6-4c45-83a0-7f0d3104922e
AKS_RG=$(az aks list --query "[?name=='vpp-aks01-d'].resourceGroup | [0]" -o tsv)
az aks get-credentials --resource-group "$AKS_RG" --name vpp-aks01-d --overwrite-existing
kubectl config current-context
# Expected: vpp-aks01-d
```

## E4 — In-cluster repo Secret identity (recipe Step 2)

`recipe-rotate-argocd-sandbox-pat.md:57-72`:
```bash
for s in $(kubectl get secret -n argocd -l argocd.argoproj.io/secret-type=repository -o name); do
  URL=$(kubectl get $s -n argocd -o jsonpath='{.data.url}' | base64 -d 2>/dev/null)
  USER=$(kubectl get $s -n argocd -o jsonpath='{.data.username}' | base64 -d 2>/dev/null)
  printf "%-40s URL=%s  USER=%s\n" "$s" "$URL" "$USER"
done
```

Find the row whose `URL` contains `VPP.GitOps`. The `USER` field typically reads `sa_platform_vpp@eneco.com` or similar.

`recipe-rotate-argocd-sandbox-pat.md:69-72`:
```bash
ARGOCD_REPO_SECRET="repo-XXXXXXXXXX"   # CHANGE — from the row matching VPP.GitOps
echo "Will rotate PAT inside: $ARGOCD_REPO_SECRET"
```

## E5 — PAT mint (recipe Step 3)

`recipe-rotate-argocd-sandbox-pat.md:80-87`:
> 1. Open https://dev.azure.com/enecomanagedcloud/_usersSettings/tokens
> 2. If you are NOT impersonating `sa_platform_vpp@eneco.com`, sign in as that service account first (or coordinate with the SA owner). PATs are user-scoped; one minted under your personal identity will NOT inherit the SA's repo permissions.
> 3. Click **New Token**.
>    - Name: `argo-cd-sandbox-YYYY-MM-DD` (the date helps reconcile with future expiry reports).
>    - Organization: `enecomanagedcloud`.
>    - Expiration: 1 year (the maximum ADO permits; today + 364 days).
>    - Scopes: **Code → Read** (minimum). DO NOT grant write or admin scopes; the cluster only needs read.
> 4. Click **Create**. **Copy the PAT value immediately** — ADO does not show it again.

## E6 — Pre-patch verification (recipe Step 4)

`recipe-rotate-argocd-sandbox-pat.md:102-111`:
```bash
URL=$(kubectl get secret "$ARGOCD_REPO_SECRET" -n argocd -o jsonpath='{.data.url}' | base64 -d)
echo "URL: $URL"
curl -sI -u ":${NEW_PAT}" "${URL}/info/refs?service=git-upload-pack" | head -3
```

Decision: HTTP 200 → PAT works; HTTP 401/403 → PAT is invalid OR SA lacks Code Read scope.

## E7 — Patch the Secret (recipe Step 5)

`recipe-rotate-argocd-sandbox-pat.md:115-145`:
```bash
case "$ARGOCD_REPO_SECRET" in
  repo-*) echo "Name guard PASS: $ARGOCD_REPO_SECRET" ;;
  *)
    echo "ABORT: secret name does not match repo-* — verify Step 2 selection"
    return 1
    ;;
esac

NEW_PAT_B64=$(printf '%s' "$NEW_PAT" | base64 | tr -d '\n')

kubectl patch secret "$ARGOCD_REPO_SECRET" -n argocd \
  --type=json \
  -p="[{\"op\":\"replace\",\"path\":\"/data/password\",\"value\":\"${NEW_PAT_B64}\"}]"

kubectl get secret "$ARGOCD_REPO_SECRET" -n argocd -o jsonpath='{.data.password}' | base64 -d | wc -c
# Expected: 52 (or whatever your PAT length is) — NOT 0

unset NEW_PAT NEW_PAT_B64
```

## E8 — Force-refresh ApplicationSet (recipe Step 6)

`recipe-rotate-argocd-sandbox-pat.md:148-161`:
```bash
kubectl annotate applicationset vpp-feature-branch-environments -n argocd \
  argocd.argoproj.io/refresh=hard --overwrite

for i in 1 2 3 4 5 6; do
  sleep 15
  STATUS=$(kubectl get applicationset vpp-feature-branch-environments -n argocd -o jsonpath='{.status.conditions[?(@.type=="ErrorOccurred")].status}')
  TIME=$(kubectl get applicationset vpp-feature-branch-environments -n argocd -o jsonpath='{.status.conditions[?(@.type=="ErrorOccurred")].lastTransitionTime}')
  echo "$(date -u +%H:%M:%S) ErrorOccurred=$STATUS (transitioned $TIME)"
  [ "$STATUS" = "False" ] && echo "OK: ApplicationSet auth recovered" && break
done
```

Decision: `ErrorOccurred=False` + fresh `lastTransitionTime` (≤2 min) → auth recovered.

## E9 — Materialize child Applications (recipe Step 7)

`recipe-rotate-argocd-sandbox-pat.md:170-180`:
```bash
SLOT=kidu
for i in 1 2 3 4 5 6; do
  COUNT=$(kubectl get applications.argoproj.io -n argocd 2>/dev/null | grep -c "^${SLOT}-app-of-apps")
  CHILDREN=$(kubectl get applications.argoproj.io -n "$SLOT" --no-headers 2>/dev/null | wc -l | tr -d ' ')
  echo "$(date -u +%H:%M:%S) ${SLOT}-app-of-apps=$COUNT child-apps-in-ns=$CHILDREN"
  [ "$CHILDREN" -ge 10 ] && break
  sleep 30
done
```

Expected progression:
- t=0s: parent app-of-apps appears in argocd namespace
- t=30-60s: child Applications appear in `${SLOT}` namespace (~22 apps per slot)
- t=60-120s: Helm-rendered manifests apply; Deployments/Services/Ingress appear
- t=2-10min: service pods reach Running

## E10 — Verify URL recovery (recipe Step 8)

`recipe-rotate-argocd-sandbox-pat.md:191-201`:
```bash
SLOT=kidu
curl -svk --max-time 15 "https://${SLOT}.dev.vpp.eneco.com/" 2>&1 | grep -iE "HTTP/|Request-Context|x-correlation-id" | head -5
```

Decision:
- HTTP/2 200 + Request-Context + x-correlation-id headers → FBE healthy (full API response)
- HTTP/2 200 only → SPA fallback (different class; see [[eneco-vpp-argocd-healthy-but-unreachable-troubleshooting]])
- HTTP/2 503/502 → pods coming up but not ready
- HTTP/2 404 → no pods backing the ingress yet OR child Applications haven't synced

## E11 — Anti-patterns (recipe + pattern)

`recipe-rotate-argocd-sandbox-pat.md:214-221`:
- Do NOT delete and recreate the affected FBE
- Do NOT restart argocd-application-controller
- Do NOT echo PAT to stdout, paste in chat, commit to repo
- Do NOT widen PAT scopes beyond Code Read
- Do NOT use personal PAT in cluster
- Do NOT skip Step 4 (curl test)

`pattern-argocd-pat-expiry-blocks-new-fbe-apps.md:155-160`:
- "Restart ArgoCD controllers" — argocd-application-controller restart doesn't help; secret still has bad PAT
- "Manually create Application CRDs in {slot} namespace" — symptomatic; copies introduce drift from GitOps source of truth
- "Disable ApplicationSet sync policy" — silences symptom; GitOps contract still broken

## E12 — Empirical signatures (pattern doc)

`pattern-argocd-pat-expiry-blocks-new-fbe-apps.md:134-141` — ALL FIVE must match (first FAIL means different pattern):

1. Pipeline 2412 ended with `partiallySucceeded` (NOT `failed`)
2. Slack notification shows Pester `Total: 4, Success: 1, Failures: 3`
3. `kubectl get applications.argoproj.io -A | grep {slot}` returns nothing AND at least one other slot has child Applications
4. `kubectl get all -n {slot}` shows ONLY `docker-pull-secret` cron/job/pods
5. `kubectl describe applicationset vpp-feature-branch-environments -n argocd | grep -A2 'ErrorOccurred'` returns recent `lastTransitionTime` with `ApplicationGenerationFromParamsError: ... authentication required`

## E13 — KV inventory (vault keyvault-secrets)

`eneco-vpp-keyvault-secrets.md:27-29`:
```
| ArgoCD | argocd-repository-credentials-template-url-acc   | Azure DevOps PAT (ACC)   |
| ArgoCD | argocd-repository-credentials-template-url-devmc | Azure DevOps PAT (DEVMC) |
```

KV name: `vpp-appsec-d` (line 22 — "the deployed KeyVault `vpp-appsec-d` (218 secrets across 11 categories)").

**Coherence flag**: vault lists 2 ArgoCD PAT entries (acc, devmc); intake lists 3 MC PATs (devmc, accmc, prdmc). Discrepancy — likely vault note is incomplete vs reality. P4 IaC sidecar should resolve.

## E14 — F4 adjacency (different rotation surface)

`fbe-failure-modes-catalog.md:171-208`:
> ## F4 — Cross-FBE secret expiry (mass outage)
> Mechanism class: C — Secret/credential management
> Trigger: AAD client secret on shared SP `6db398ec-8cb7-4398-a944-f842aa9a67da` expired.
> Symptom: AssetPlanning API failing across voltex, thor, afi, jupiter — Error: `AADSTS7000215: Invalid client secret provided`
> Cause: Shared SP credential expiry — secret rotation not tracked per-FBE; cross-FBE shared identity is a single point of failure.
> Fix (Dec 29): Fabrizio rotated secret + restarted AssetPlanning, AssetMonitor, Asset, IntegrationTests services per FBE.
> Lesson: Cross-FBE shared identities are a single point of failure.

## E15 — VPPAL cert-rotation runbook (different surface — for proposal context)

`vppal-cert-rotation-runbook.md:14-41` — Steps:
1. Override `keys` secret in ArgoCD application `esp-certificate-agg` to a test name (`esp-cert-new-test`)
2. Override secret mount in ArgoCD for 1-2 test services
3. Confirm test services can consume/produce with new certificate
4. Upload new client certificate on Axual production application
5. Configure production certificate in gitops repository
6. Configure ArgoCD application `esp-certificate-agg` on production cluster (manual sync, leave out-of-sync)
7. Disable auto-sync on apps-of-apps + common application
8. Remove kubernetes secret `keys` from `common` application
9. Sync `esp-certificate-agg` to recreate `keys` secret with new certificate
10. Update PFX password in production KeyVault
11. Restart services

**Insight for proposal**: this runbook shows a different pattern — secret is **gitops-managed via ArgoCD**, password lives in KV. The MC ArgoCD pattern may be similar (gitops-managed, KV-backed).

## E16 — Provenance hypotheses (pattern doc)

`pattern-argocd-pat-expiry-blocks-new-fbe-apps.md:122-128`:
- P1 — Alert was seen but deprioritized
- P2 — Alert noise / alarm fatigue
- P3 — Service-account rotation friction (shared SA, multi-step coordination)

> The fix doctrine is the same for all three: rotate the PAT, update the Kubernetes secret, force-refresh the ApplicationSet.

## E17 — Cross-cluster propagation latent (pattern doc)

`pattern-argocd-pat-expiry-blocks-new-fbe-apps.md:118`:
> Cross-cluster blast radius (dev-MC ArgoCD, prod-MC ArgoCD, other ArgoCD installations): Independent — each ArgoCD installation has its own PAT. Per the 2026-05-08 PAT report: `argo-cd-devmc-cmc-goldilocks-repository`, `argo-cd-accmc-cmc-goldilocks-repository`, `argo-cd-prdmc-cmc-goldilocks-repository` all expire 06/01/2026 (status Warning). The MC clusters will hit the SAME pattern unless rotated proactively.

## E18 — Class-level lessons (pattern doc)

`pattern-argocd-pat-expiry-blocks-new-fbe-apps.md:188-194`:
1. PAT expiry is a silent FBE killer
2. Credential-rotation cadence is a control surface (SLA candidate: rotate within 7 days of Warning, 24 hours of Critical)
3. Pre-existing apps survive an auth break — good UX, bad observability
4. Same pattern latent on dev-MC / acc-MC / prd-MC ArgoCD installations
5. The right alarm is missing — `argocd_appset_status{condition_type="ErrorOccurred"} > 0` Grafana alert would surface this in real-time
