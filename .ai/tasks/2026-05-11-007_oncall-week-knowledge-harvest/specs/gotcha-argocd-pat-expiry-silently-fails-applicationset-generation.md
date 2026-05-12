---
task_id: 2026-05-11-007
agent: claude-code
status: complete
summary: Spec for new vault gotcha — ArgoCD repository PAT expiry silently fails ApplicationSet generation while existing Application CRDs in etcd survive. Ready to apply to llm-wiki/learnings/gotchas/.
spec_target_path: $SECOND_BRAIN_PATH/llm-wiki/learnings/gotchas/argocd-pat-expiry-silently-fails-applicationset-generation.md
spec_action: create
spec_zone: learnings/gotchas
spec_status: ready_to_apply
---

# Spec — Gotcha: ArgoCD PAT Expiry Silently Fails ApplicationSet Generation

## Target Path

`$SECOND_BRAIN_PATH/llm-wiki/learnings/gotchas/argocd-pat-expiry-silently-fails-applicationset-generation.md`

## Frontmatter

```yaml
---
description: "When the ArgoCD repository PAT (stored in the K8s Secret with label argocd.argoproj.io/secret-type=repository) expires, an ApplicationSet that scans a Git directory for child Application manifests starts reporting ApplicationGenerationFromParamsError: authentication required, but EXISTING Application CRDs in etcd persist and continue reconciling normally. The auth-break only blocks NEW generation. The visible symptoms — FBE pipeline reports partiallySucceeded + Slack 1/4 Success — do NOT point at the credential layer. Diagnostic surface: kubectl describe applicationset <name> -n argocd / -n openshift-gitops. Recovery: rotate the PAT in ADO UI, update the Opaque Secret on the cluster, ApplicationSet retries every minute and re-generates child Applications within 3-5 min."
type: gotcha
domain: work
status: active
source: agent
created: 2026-05-11
last_validated: 2026-05-11
severity: high
confidence: validated
scope: "Eneco VPP ArgoCD installs that use ApplicationSet-driven dynamic child Application generation against an ADO Git repository. Specifically: sandbox ArgoCD (AKS vpp-aks01-d, vpp-feature-branch-environments ApplicationSet → VPP.GitOps); dev-MC, acc-MC, prd-MC ArgoCD installs using cmc-goldilocks repo."
evidence: "log/employer/eneco/02_on_call_shift/2026_05_11_rotating_expired_argocd_secrets/{how-to-rotate.md,proposal-rotation-automation.md,draft-rotation-secrets.md,slack-intake.txt}; Slack #team-platform 2026-05-11 12:32 CEST (Fabrizio surfacing question); Slack #myriad-alerts-devops PAT expiry report 2026-05-08"
tags: [argocd, applicationset, pat, azure-devops, eneco, vpp, sandbox, mc-openshift, credential-expiry, silent-failure, fbe]
---
```

## Body

> **Scope**: This gotcha covers the PAT (auth-to-git) failure class. It is **ORTHOGONAL** to `[[argocd-app-of-apps-product-team-cannot-sync]]` which covers RBAC (Casbin policy denying sync at product-team boundary). Both should cross-link as siblings in the "ArgoCD failure mode family."

## Trigger

When you see (any of):

- An FBE pipeline reports `partiallySucceeded` with Slack notification `1/4 Success` and the failing item is "deployment to ArgoCD" or "wait for sync"
- A new FBE slot is requested (e.g., `kidu`, `boltz`, `enel`), the create pipeline succeeds Stage 1-5, but the cluster has NO `Application` CRDs for that slot after 30+ minutes
- `argocd app list -n <namespace>` is missing slots that "should be" there
- Existing slots are healthy but recently-recycled or newly-requested slots are dead
- A PAT expiration report posts to `#myriad-alerts-devops` flagging `argo-cd-sandbox` or `argo-cd-{devmc,accmc,prdmc}-cmc-goldilocks-repository` as Critical
- `kubectl describe applicationset <name> -n argocd` shows `ApplicationGenerationFromParamsError: authentication required`

## Symptom (what visible signals lie)

The visible signals point AWAY from the credential layer:

- **FBE pipeline status**: `partiallySucceeded` — looks like one stage tripped, not a credential
- **Slack message**: `1/4 Success` — looks like 3 of 4 things tested are healthy
- **`argocd app list`**: existing apps are HEALTHY → suggests system is mostly fine
- **`argocd app get <parent>`**: parent ApplicationSet may still show `Synced` because the generator failed BEFORE Application creation, not at sync time
- **Git push from CI/CD**: SUCCEEDS — the credential failure is read-side (ArgoCD reading from git), not write-side (pipeline writing to git)

The only first-look surface that names the cause:

```bash
kubectl describe applicationset <appset-name> -n <argocd-namespace>
# Look for: status.conditions[].type=ErrorOccurred / message: ApplicationGenerationFromParamsError: authentication required
```

This command is **in NO first-look runbook** at Eneco today (per the canonical `how-to-rotate.md` runbook authored 2026-05-11; flagged for inclusion).

## Root Cause Mechanism

1. ArgoCD stores per-repo credentials as Kubernetes `Secret` resources with label `argocd.argoproj.io/secret-type: repository`. The Secret carries `.data.url`, `.data.username`, `.data.password` (PAT base64-encoded).
2. When the ApplicationSet generator scans a Git directory to discover child Application manifests, it uses these credentials as HTTP Basic auth against Azure DevOps.
3. A PAT in ADO has a maximum lifetime of 12 months (ADO ceiling). When it expires, ADO returns 401 to ArgoCD's Git operations.
4. **The ApplicationSet controller logs the auth error and stops generating children** — but **existing Application CRDs persist in etcd** because they are independent K8s resources, not stateless function outputs of the generator. They were created on a prior successful generation cycle and the cluster has no reason to remove them.
5. **Existing Applications continue to reconcile normally** because ArgoCD's repo-server uses the SAME Secret to fetch their Git sources too — but if the Application's `spec.source.repoURL` is the same and the auth is broken, those reconciles ALSO fail. **However**: ArgoCD caches the last-known Git commit per Application. Reconciles fail soft (last-known state persists, sync stays "Synced" with a stale-revision warning that nobody reads).
6. Net effect: live workloads keep running on their last-deployed image / config (no impact to running services), but the GitOps loop is silently broken for any change submitted after the PAT expired.

## Quantification

- **Time to surface (silent failure window)** at Eneco: ~22 hours for the 2026-05-11 incident (auth break at 2026-05-10T12:40:13Z; Fabrizio asked at 2026-05-11T12:32:25Z)
- **Blast radius**: NEW slot generation only. Existing slots survive (etcd persistence). Stale-revision warnings on existing Applications are ignored by humans.
- **Affected slots (today)**: kidu, boltz, enel had no app-of-apps in ArgoCD; 8 surviving slots (afi, ionix, ishtar, jupiter, operations, thor, veku, voltex) had Applications generated BEFORE the expiry.

## Fix

### Immediate recovery (per-PAT)

```bash
# 1. Mint new PAT in ADO UI (signed in as sa_platform_vpp@eneco.com)
#    Use existing PAT name (e.g., argo-cd-sandbox) and identical scopes (Code Read)
#    Maximum lifetime: 12 months (ADO ceiling)

# 2. Apply to Sandbox cluster (AKS vpp-aks01-d)
NEW_PAT='<paste-from-ADO-UI>'
kubectl patch secret repo-<NNN> -n argocd \
  --type='json' \
  -p="[{\"op\":\"replace\",\"path\":\"/data/password\",\"value\":\"$(echo -n "$NEW_PAT" | base64)\"}]"

# 3. Force ApplicationSet reconcile (optional; it retries every minute on its own)
kubectl annotate applicationset vpp-feature-branch-environments -n argocd \
  argocd.argoproj.io/refresh=true --overwrite

# 4. Verify within 3-5 min: Applications for the previously-broken slots materialize
kubectl get applications -n argocd | grep -E 'kidu|boltz|enel'
# Expected: rows with sync status Synced/OutOfSync (not absent)

# 5. Verify ApplicationSet condition cleared
kubectl describe applicationset vpp-feature-branch-environments -n argocd | grep -A2 'ErrorOccurred'
# Expected: status.conditions[].type=ErrorOccurred / status=False
```

### MC clusters (OpenShift)

The exact path is `[PENDING: confirm with Fabrizio]` — likely either `kubectl patch secret -n eneco-vpp-argocd` (same shape) OR a CMC ticket if access is gated. The Helm chart at `myriad-vpp/ArgoCD-Config/Helm/repositories/templates/deployment.yaml` targets namespace `eneco-vpp-argocd`. See [[2026-05-11-oncall-shift-trade-platform-quad-incident#incident-4]] for the broader operational context.

### Long-term (class-level, see proposal)

The per-PAT rotation is a per-incident workaround. The CLASS problem (credential-expiry-as-recurring-class) needs structural remediation — see [[credential-expiry-is-a-class-problem-not-per-incident-firefight]] for the 3-option roadmap (Workload Identity Federation / KV + ESO / Status quo + SLA).

## Adjacent Mechanisms Worth Knowing

1. **PAT scope matters**: today's rotation must preserve `Code Read` (and any other scopes the previous PAT had). Wrong scope → auth succeeds but ArgoCD can't read the repo → same symptom.
2. **MFA on the SA**: `sa_platform_vpp@eneco.com` has MFA enabled. PAT minting requires sign-in including MFA. The credentials live in the Trade Platform Team vault (per Roel 2026-01-23 #team-platform: *"I've put the sa_platform_vpp account credentials in our Trade Platform Team vault"*). Anyone rotating must have vault access.
3. **The 4 PATs are separate** (per-cluster isolation by ArgoCD design). Compromised sandbox PAT doesn't break prd. Rotation overhead is 4× (mitigation: automation per proposal).
4. **`argo-cd-{devmc,accmc,prdmc}-cmc-goldilocks-repository` targets a DIFFERENT repo** (`cmc-goldilocks`) than sandbox's `argo-cd-sandbox` (which targets `VPP.GitOps`). Mixing them up will leave one cluster broken AND another cluster auth-broken to the wrong repo.
5. **Goldilocks identity**: `[PENDING: confirm with Fabrizio]` — likely CCoE managed-cloud policy / version-pinning ArgoCD app (NOT the k8s VPA tool).

## Defense (proposed Grafana alert)

```promql
argocd_appset_status{condition_type="ErrorOccurred"} > 0
```

Would have caught the 2026-05-10T12:40Z auth-break in real time instead of after 22h of silent failure. Not yet deployed at Eneco.

## Verification Probes (for the next person hitting this)

```bash
# 1. Confirm the ApplicationSet is the failure surface (cluster truth)
kubectl describe applicationset vpp-feature-branch-environments -n argocd | grep -E 'condition_type|Message|Status:' | head -20
# Expected during incident: type=ErrorOccurred, status=True, message contains "authentication required" / "401"

# 2. Confirm the repo Secret is the credential surface
kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=repository -o jsonpath='{.items[*].metadata.name}'
# Expected: one or more "repo-<NNN>" Secrets

# 3. Confirm the PAT expiry on ADO side
# Sign in as sa_platform_vpp@eneco.com (vault credentials) → User Settings → Personal access tokens
# Find argo-cd-sandbox row → check Expires column
```

## Cross-Links

- [[argocd-app-of-apps-product-team-cannot-sync]] — SIBLING failure mode (Casbin RBAC denial, not auth break). Both are "ArgoCD failure mode family."
- [[argocd-helm-oci-plus-appconfig-plus-kv-csi-three-layer-config-stack]] — this PAT failure is a Layer 1 (deploy-time) failure mode in that pattern.
- [[credential-expiry-is-a-class-problem-not-per-incident-firefight]] — class-level lesson; today's PAT is one of 5 recent recurrences.
- [[eneco-credential-expiry-class-incident-history-2024-2026]] — historical incident registry for the class.
- [[2026-05-11-oncall-shift-trade-platform-quad-incident]] — episode of origin.
- [[eneco-vpp-sandbox-is-aks-not-openshift]] — confirms sandbox is AKS (relevant for `kubectl patch` path vs OpenShift `oc patch`).
- [[oncall-rca-must-close-on-every-state-plane]] — operational discipline reinforced.
- Source incident dir: `log/employer/eneco/02_on_call_shift/2026_05_11_rotating_expired_argocd_secrets/`
- Comprehensive runbook: `how-to-rotate.md` (1291 lines, authored 2026-05-11)
- Automation proposal: `proposal-rotation-automation.md` (505 lines, 3 options with phasing recommendation)
