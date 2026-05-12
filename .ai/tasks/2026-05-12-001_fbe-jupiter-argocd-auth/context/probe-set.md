---
title: Targeted probe set — jupiter/dispatchermfrr "authentication required"
type: research
domain: tech
status: draft
task_id: 2026-05-12-001
agent: claude-code
summary: Three-surface probe set discriminating H_A (stale Application state from yesterday's PAT-expiry window) vs H_B (per-repo permission gap on new PAT) vs H_C (multi-source race) vs H_D (stale repo-server clone). Probe order, decision rules, and quick-fix path for jupiter/dispatchermfrr.
created: 2026-05-12
prereqs:
  - "az login + az account set --subscription 7b1ba02e-bac6-4c45-83a0-7f0d3104922e"
  - "kubectl context vpp-aks01-d (already set, verified A1 2026-05-12)"
  - "argocd login argocd.dev.vpp.eneco.com (current session expired AADSTS700082)"
---

# Probe set — jupiter/dispatchermfrr auth break

Run in order. Stop and capture output after each. Decision rules embedded.

## Surface 1 — The failing Application's own status (HIGHEST priority)

**Question:** Is the failure live or stale? What does the Application itself report?

**Why this is authoritative:** `argocd app get -o yaml` reads the Application CR
directly from the cluster's etcd. The status block contains the actual error
emitted by repo-server on the most recent reconcile, the last successful
reconcile timestamp, and the source revisions ArgoCD believes it has resolved.
This is the source of truth for "did the auth fail TODAY or is the error
sticky from yesterday."

```bash
# Capture the full status — do not truncate; we want timestamps
kubectl get application dispatchermfrr -n jupiter -o yaml > /tmp/dispatchermfrr-app.yaml
echo "---"
# Key fields:
yq '.status.conditions' /tmp/dispatchermfrr-app.yaml
echo "---"
yq '.status.operationState | {phase, message, startedAt, finishedAt, syncResult}' /tmp/dispatchermfrr-app.yaml
echo "---"
yq '.status.reconciledAt, .status.observedAt, .status.sync.revision, .status.sync.revisions' /tmp/dispatchermfrr-app.yaml
echo "---"
yq '.status.sourceTypes, .status.history[-1]' /tmp/dispatchermfrr-app.yaml 2>/dev/null
```

(If `yq` not installed: `kubectl get application dispatchermfrr -n jupiter -o jsonpath='{.status.conditions}' | jq .`)

**Decision rules:**

- `status.conditions[].lastTransitionTime` predates 2026-05-11T13:35:00Z UTC
  (yesterday's PAT rotation) → **H_A confirmed (stale state from PAT outage
  window). Quick fix: hard-refresh.**
- `lastTransitionTime` is recent (today, within hours) → live auth failure,
  rule out H_A and move to Surface 2.
- `status.sync.revision` is a SHA from a prior branch, not the current
  `feature/fbe-808321_...` branch → repo-server hasn't successfully re-fetched
  since the branch change; H_A or H_D.
- `operationState.phase: Failed` with a timestamp from yesterday's outage
  window → **H_A confirmed**.

## Surface 2 — repo-server's view of credentials and clone state

**Question:** Does the credential pool resolve the same way for all three ADO
git repos, or is `Eneco.Vpp.Core.Dispatching` resolving against a different
(or empty) credential?

**Why this is authoritative:** ArgoCD's repo-server resolves repo URLs to
credentials in this order: explicit Repository CR > Credential Template
(longest prefix match) > anonymous. The Repository page shows "Successful"
for the LAST connection test; today's manifest generation runs through the
same path but may be hitting a different credential record.

```bash
# Enumerate all repo credentials and credential templates for ADO
for s in $(kubectl get secret -n argocd -l argocd.argoproj.io/secret-type=repository -o name 2>/dev/null) \
         $(kubectl get secret -n argocd -l argocd.argoproj.io/secret-type=repo-creds -o name 2>/dev/null); do
  URL=$(kubectl get $s -n argocd -o jsonpath='{.data.url}' 2>/dev/null | base64 -d 2>/dev/null)
  USER=$(kubectl get $s -n argocd -o jsonpath='{.data.username}' 2>/dev/null | base64 -d 2>/dev/null)
  PROJ=$(kubectl get $s -n argocd -o jsonpath='{.data.project}' 2>/dev/null | base64 -d 2>/dev/null)
  TYPE=$(kubectl get $s -n argocd -o jsonpath='{.metadata.labels.argocd\.argoproj\.io/secret-type}')
  printf "%-50s | %-12s | %-30s | %s\n" "$s" "$TYPE" "$USER" "$URL"
done | sort
```

**Decision rules:**

- Three rows whose URL matches `dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/{Eneco.Vpp.Core.Dispatching,VPP-Configuration,VPP.GitOps}` exist with the same `username` → credential plane uniform; rules out H_B.
- A `repo-creds` (credential template) row exists whose URL is a PARENT prefix of `Eneco.Vpp.Core.Dispatching` with empty/different `username` → H_B candidate; credential template precedence may steal the auth from the explicit Repository.
- No row for `Eneco.Vpp.Core.Dispatching` and only a template prefix-matches → **H_B confirmed**.

## Surface 3 — ArgoCD-side error message (the actual git error, not the UI string)

**Question:** What does ArgoCD's repo-server log when it tries to fetch the
failing branch right now?

**Why this is authoritative:** The Application's `status.conditions` is the
post-processed error. The repo-server pod logs are the raw git error from
the moment of fetch. Difference between "401 from ADO" and "git: revision not
found" eliminates H_D vs. H_B.

```bash
# Hard-refresh and watch the repo-server log
argocd app get jupiter/dispatchermfrr --hard-refresh > /tmp/app-refresh.txt 2>&1 &
REFRESH_PID=$!

# Tail repo-server logs for ~30s; grep for the failing repo URL
kubectl logs -n argocd deploy/argocd-repo-server --tail=200 -f --since=30s 2>&1 \
  | grep -iE 'dispatching|authentication|401|403|error|fatal' \
  | head -40 &
LOG_PID=$!

sleep 30
kill $LOG_PID 2>/dev/null
wait $REFRESH_PID
cat /tmp/app-refresh.txt
```

**Decision rules:**

- After `--hard-refresh` the error CLEARS and `status.sync.revision` advances → **H_A confirmed AND remediated**. Document and stop.
- Repo-server log shows `HTTP 401` from `dev.azure.com` for `Eneco.Vpp.Core.Dispatching` only → H_B candidate (per-repo permission); inspect Step 2's credential table again.
- Repo-server log shows `revision not found` / `couldn't find remote ref` → H_D candidate (branch missing on remote OR stale local clone); next probe is Surface 4.
- Repo-server log shows the exact UI error and nothing else → H_A; the error is sticky.

## Surface 4 — (only if Surface 3 shows "revision not found") — Branch existence on ADO

```bash
# Read the repo URL the Application is using
yq '.spec.sources[0].repoURL, .spec.sources[0].targetRevision' /tmp/dispatchermfrr-app.yaml
# Verify the branch exists on ADO using your dev session
az repos ref list \
  --organization https://dev.azure.com/enecomanagedcloud \
  --project "Myriad - VPP" \
  --repository "Eneco.Vpp.Core.Dispatching" \
  --filter "heads/feature/fbe-808321_new-mFRR-Effective-Steering-Mode" \
  -o table 2>&1 | head -5
```

**Decision rule:** if branch exists on ADO but ArgoCD reports "not found" → repo-server local clone is stale; restart `argocd-repo-server` Deployment to clear cache.

## Surface 5 — (only if H_A confirmed) — Quick-fix path

If H_A is confirmed, the fix sequence is:

```bash
# 1. Hard-refresh the Application (re-pulls all sources, ignores cache)
argocd app get jupiter/dispatchermfrr --hard-refresh

# 2. If hard-refresh insufficient, terminate any stuck operation
argocd app terminate-op jupiter/dispatchermfrr 2>/dev/null || true

# 3. Trigger a fresh sync
argocd app sync jupiter/dispatchermfrr

# 4. Verify
argocd app get jupiter/dispatchermfrr | head -30
```

**Anti-patterns (DO NOT DO):**

- Restart `argocd-application-controller` — does not clear repo-server cache.
- Delete + recreate the Application — risks losing FBE state; the
  ApplicationSet would recreate it eventually but with the same cache issue.
- Patch the repo-creds secret — yesterday's PAT rotation already did this;
  the Repository page shows Successful.

## Stop conditions

Stop probing and write the RCA when:

1. Surface 1 returned the timestamp evidence to confirm or rule out H_A.
2. (If H_A not confirmed) Surface 2 returned the credential table to confirm or rule out H_B.
3. (If neither) Surface 3 returned the repo-server log for live error class.

Three surfaces minimum; H_A confirmation can short-circuit Surfaces 2-3 if
hard-refresh fixes the Application (Surface 5).
