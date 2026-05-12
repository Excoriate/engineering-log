---
title: "Fix runbook — Sandbox FBE platform-wide ArgoCD auth break (68 Apps, 8 slots + argocd ns)"
type: how-to
domain: tech
status: draft
created: 2026-05-12
updated: 2026-05-12
authors: [alex-torres]
estimated_wall_time: "25-40 minutes (gated rollout — see Phase A→F)"
reviewed_by: [el-demoledor, socrates-contrarian, sre-maniac]
related:
  - rca.md
  - context.md
  - slack-intake.txt
---

# Fix runbook — gated rollout

> **What is the fix in one sentence?** Add **ONE Kubernetes Secret** (a `repo-creds`
> credential template) to the `argocd` namespace on the Sandbox AKS cluster, so ArgoCD
> can authenticate against the two ADO Git repos (`Eneco.Vpp.Core.Dispatching`,
> `platform-gitops`) that currently have no credential. The Secret bytes are reused from
> the existing working PAT in `repo-3703084109`. No new PAT mint required.
>
> **Why a gated rollout instead of one `kubectl apply` and done?** The Secret is correct.
> But applying it causes 68 stuck Applications to simultaneously fetch from ADO + render
> Helm + diff + sync with `prune=true`. Three operational blockers (repo-server
> parallelism, ADO 200-TSTU rate limit, 22h-drift prune cascade) mean naive application
> can leave the cluster in a worse state than today. The Phase A→F plan throttles the
> reconcile fan-out and adds a manual sync gate.

## Action-surface legend (used on every step below)

Every step is labelled with WHERE the action happens:

| Symbol | Meaning |
|---|---|
| 🔵 **kubectl** | Run on operator workstation against `kubectl config current-context=vpp-aks01-d` |
| 🟢 **argocd CLI** | Run with `argocd` CLI logged in to `argocd.dev.vpp.eneco.com` |
| 🟣 **az CLI** | Run with `az` logged in to subscription `7b1ba02e-bac6-4c45-83a0-7f0d3104922e` (Sandbox) |
| 🟡 **git** (workstation) | Run with `git` from operator workstation; **NOT** inside the cluster |
| 🟠 **ArgoCD UI** | Click in the web UI at `https://argocd.dev.vpp.eneco.com` |
| ⚪ **Slack** | Post message in `#myriad-platform` |
| 🟤 **Inspect** | Read-only, no mutation |

## Pre-conditions (must all hold before Phase A)

1. 🟣 `az account show` returns subscription `7b1ba02e-bac6-4c45-83a0-7f0d3104922e`
2. 🔵 `kubectl config current-context` returns `vpp-aks01-d`
3. 🟢 `argocd context` shows `argocd.dev.vpp.eneco.com` AND `argocd account get-user-info` succeeds (re-login if AADSTS700082)
4. 🟤 You have read this `fix.md` end-to-end at least once
5. 🟤 The associated `rca.md` Knowledge Contract and L8 fix are accepted

If any pre-condition fails → STOP and resolve before continuing.

---

## Phase A — Pre-apply guard (read-only probes + announce; 5-10 min)

### A0 — 🟡 git: Verify PAT scope from workstation (the most important probe)

This is the single most important step. It rules out the scenario where the fix lands,
the prefix-match works, but ADO still 401s because `sa_platform_vpp@eneco.com` lacks
`Code Read` permission on the two uncovered repos.

```bash
# Extract the PAT bytes from the working Repository CR (do NOT echo to stdout)
PAT=$(kubectl get secret repo-3703084109 -n argocd -o jsonpath='{.data.password}' | base64 -d)
ADO_USER="sa_platform_vpp@eneco.com"
ADO_USER_ENC=$(printf '%s' "$ADO_USER" | python3 -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.stdin.read(), safe=""))')

# Probe 1 — KNOWN WORKING (control case; must return a SHA)
git ls-remote "https://${ADO_USER_ENC}:${PAT}@dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/VPP.GitOps" HEAD 2>&1 | head -2

# Probe 2 — UNCOVERED-1 (the failing repo; must return a SHA after fix)
git ls-remote "https://${ADO_USER_ENC}:${PAT}@dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/Eneco.Vpp.Core.Dispatching" HEAD 2>&1 | head -2

# Probe 3 — UNCOVERED-2 (the other failing repo; must return a SHA after fix)
git ls-remote "https://${ADO_USER_ENC}:${PAT}@dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/platform-gitops" HEAD 2>&1 | head -2

# Clean up
unset PAT ADO_USER_ENC
```

**Decision rule (READ CAREFULLY):**

- Probe 1 returns a SHA → control case passes. Continue.
- Probe 1 fails (401) → **STOP**. The PAT bytes are not even working for the known-good repo. Re-check PAT extraction. Possibly yesterday's rotation has issues.
- Probes 2 and 3 return SHAs → **proceed to Phase A1**. The PAT has read access to the uncovered repos; the only thing missing is the ArgoCD `repo-creds` template.
- Probe 2 OR Probe 3 returns 401 → **STOP. Do NOT apply the fix.** Escalate to **Fabrizio** in `#myriad-platform`: "Service account `sa_platform_vpp@eneco.com` lacks `Code Read` on `<repo>`. Need ADO repo-permission grant before the credential template will work."

### A1 — 🔵 kubectl: Probe argocd-repo-server resource posture

```bash
kubectl -n argocd get deploy argocd-repo-server -o json | jq '{
  replicas: .spec.replicas,
  parallelism_limit: ([.spec.template.spec.containers[0].args[]?,
                       .spec.template.spec.containers[0].env[]?.value]
                       | join(" ")
                       | match("parallelism[-_]limit[ =]*([0-9]+)";"")
                       .captures[0].string // "DEFAULT (=unlimited)"),
  memory_limit: .spec.template.spec.containers[0].resources.limits.memory,
  cpu_limit: .spec.template.spec.containers[0].resources.limits.cpu
}'

# Also: current memory + CPU usage as baseline
kubectl -n argocd top pod -l app.kubernetes.io/name=argocd-repo-server
```

**Decision rule:**

- `parallelism_limit: "DEFAULT (=unlimited)"` AND `replicas: 1` AND `memory_limit < 4Gi` → **MUST CAP before Phase B.** Run A1.b below.
- `parallelism_limit` is a number ≤ 10 OR `replicas ≥ 2` AND `memory_limit ≥ 4Gi` → safe to proceed without capping.

### A1.b — 🔵 kubectl: (Only if A1 decision rule triggered) Cap repo-server parallelism

```bash
# Set the parallelism limit to 8 (conservative; matches typical SRE practice for repo-server)
kubectl -n argocd set env deploy/argocd-repo-server \
  ARGOCD_REPO_SERVER_PARALLELISM_LIMIT=8

# Wait for the new pod to be ready before continuing
kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=180s
```

**Note**: This restarts `argocd-repo-server`. The restart will momentarily affect ALL Applications (including the working ones), but recovery is automatic on the next reconcile (~3 min). This is the right time to do it because everything is already broken.

### A2 — 🔵 kubectl: Snapshot baseline state (so you can detect regression mid-fix)

```bash
# 1. Broken vs working Applications baseline
kubectl get applications.argoproj.io -A -o json | jq '{
  total: (.items | length),
  broken: ([.items[] | select((.status.conditions // []) | map(select(.type=="ComparisonError" and (.message|test("auth"; "i")))) | length > 0)] | length),
  healthy_synced: ([.items[] | select(.status.sync.status=="Synced" and .status.health.status=="Healthy")] | length)
}' > /tmp/pre-fix-baseline.json
cat /tmp/pre-fix-baseline.json
# Expected: broken≈68, healthy_synced≈30+ (the working OCI + VPP-Configuration-only apps)

# 2. PrometheusRule count baseline (to detect silent pruning)
kubectl get prometheusrules -A --no-headers | wc -l > /tmp/pre-fix-prom-rules.txt
echo "Prom rules: $(cat /tmp/pre-fix-prom-rules.txt)"

# 3. Per-slot argocd-managed resource inventory (to detect prune surprises)
for slot in afi ionix ishtar jupiter operations thor veku voltex; do
  echo "===== $slot ====="
  kubectl get all,secret,cm,ingress,servicemonitor,prometheusrule -n $slot \
    -l argocd.argoproj.io/instance --no-headers 2>/dev/null | wc -l
done > /tmp/pre-fix-inventory.txt
cat /tmp/pre-fix-inventory.txt
```

### A3 — ⚪ Slack: Announce the rollout in `#myriad-platform`

Post (verbatim):

> 🛠 FBE platform credential fix rolling out in ~10 minutes. Resolves the 2026-05-10
> ArgoCD source-auth break affecting 8 slots + platform Apps. Please **pause feature-branch
> pushes** to `Eneco.Vpp.Core.Dispatching` / `platform-gitops` until I post ALL CLEAR.
> Expected wall-time: 25-40 min. Reference: `log/employer/eneco/02_on_call_shift/2026_05_11_fbe_jupiter_argocd_image_auth_error/`.

### A4 — 🔵 kubectl: Disable auto-prune + auto-selfHeal on all 68 broken Apps

This is the **destructive-cascade safety gate**. Once the Secret lands, every broken
Application is going to discover 22 hours of drift between Git desired-state and live
state. With `prune=true` they will SILENTLY delete any resource not in the rendered set —
including any manual `kubectl edit` made over the last day.

```bash
# Build the list of currently-broken apps
kubectl get applications.argoproj.io -A -o json | jq -r '
  .items[] | . as $a |
  ($a.status.conditions // []) | map(select(.type=="ComparisonError" and (.message|test("auth"; "i")))) |
  if length>0 then "\($a.metadata.namespace)/\($a.metadata.name)" else empty end
' > /tmp/broken-apps.txt
wc -l /tmp/broken-apps.txt   # expect ~64-68

# Disable prune + selfHeal on each
while IFS=/ read -r ns name; do
  kubectl -n "$ns" patch application "$name" --type=merge \
    -p '{"spec":{"syncPolicy":{"automated":{"prune":false,"selfHeal":false}}}}'
done < /tmp/broken-apps.txt
```

**Decision rule:** after this step, **the Secret can land safely.** Applications will
reconcile, render manifests, and *detect drift* but will NOT auto-prune.
Sync becomes a manual gate per slot (Phase D).

---

## Phase B — Apply the fix (the actual change; <1 min)

### B1 — 🟤 Compose the Secret YAML

The change is **ONE Kubernetes Secret** in the `argocd` namespace. Type:
`argocd.argoproj.io/secret-type=repo-creds` (credential template). URL: the ADO project-
level prefix `https://enecomanagedcloud@dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/`.
Note the **trailing slash** — required so prefix-match has a path boundary.

The credential bytes (username + password) are **reused** from the existing working
secret `repo-3703084109`. No new PAT is minted.

> **NOTE**: This is NOT a change in the ArgoCD UI. The Secret is created via `kubectl`.
> The ArgoCD UI will reflect it after creation under `Settings → Repositories →
> Credential templates`.

### B2 — 🔵 kubectl: Apply the Secret

```bash
# Extract bytes from the working secret (these are base64 already; do not re-encode)
PAT_B64=$(kubectl get secret repo-3703084109 -n argocd -o jsonpath='{.data.password}')
USER_B64=$(kubectl get secret repo-3703084109 -n argocd -o jsonpath='{.data.username}')
# Encode the project-level URL (NOTE: trailing slash present)
URL_B64=$(printf 'https://enecomanagedcloud@dev.azure.com/enecomanagedcloud/Myriad%%20-%%20VPP/' | base64 | tr -d '\n')

# Apply
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

# Clean up
unset PAT_B64 USER_B64 URL_B64
```

**Decision rule (verify the Secret landed correctly):**

```bash
kubectl get secret creds-myriad-vpp-project -n argocd -o yaml | head -20
kubectl get secret creds-myriad-vpp-project -n argocd -o jsonpath='{.data.url}' | base64 -d
# Expected URL: https://enecomanagedcloud@dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/
# (trailing slash present)
```

### B3 — 🟠 ArgoCD UI: Confirm the credential template appears

1. Open `https://argocd.dev.vpp.eneco.com`
2. Settings → Repositories
3. Scroll to **CREDENTIALS TEMPLATE URL** section at the bottom
4. **Expected**: a new row appears with URL `https://enecomanagedcloud@dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/` and **CREDS** column showing a populated indicator (not `-`)

This is a UI verification only — no mutation.

### B4 — 🔵 kubectl: Watch repo-server stability for 2 minutes

```bash
# In one terminal:
watch -n 10 'kubectl -n argocd top pod -l app.kubernetes.io/name=argocd-repo-server'
# In another:
kubectl -n argocd get pod -l app.kubernetes.io/name=argocd-repo-server -w
```

**Decision rule:** observe for 2 minutes. If repo-server pod does NOT restart and stays
< 80% memory limit → safe to proceed to Phase C. If pod OOMKill / Restart → STOP, address
parallelism cap (A1.b), wait for stability, then continue.

---

## Phase C — Surgical first-slot validation (the canary; 3-5 min)

Validate the fix mechanism on ONE slot before touching the other 7. This is the safest
abort point.

### C1 — 🟢 argocd CLI: Trigger normal refresh on jupiter (canary)

```bash
# Use refresh=normal NOT hard — refresh=hard would purge the local clone and multiply
# ADO Git bytes 10-100x; refresh=normal is sufficient to force re-resolution.
argocd app refresh dispatchermfrr -n jupiter
# (or equivalent kubectl annotation:)
# kubectl annotate application dispatchermfrr -n jupiter \
#   argocd.argoproj.io/refresh=normal --overwrite
```

**Side note**: during the investigation, the `jupiter/dispatchermfrr` Application was
observed to have been deleted. The `vpp-feature-branch-environments` ApplicationSet
should regenerate it on next reconcile. If `argocd app refresh` returns `not found`,
substitute any other Application in `jupiter` namespace (e.g. `dispatcherafrr`).

### C2 — 🟤 Wait 90 seconds + 🔵 kubectl: Observe repo-server logs for credential resolution

```bash
sleep 90
kubectl -n argocd logs deploy/argocd-repo-server --since=2m \
  | grep -iE 'Eneco.Vpp.Core.Dispatching|authentication|401|429|Retry-After|jupiter/dispatchermfrr' \
  | tail -30
```

**Decision rule (the discriminator):**

- Log shows successful `git fetch` / `LsRemote OK` for `Eneco.Vpp.Core.Dispatching` → **GOOD**, proceed to C3.
- Log still shows `authentication required` → **STOP**. Either the credential template is misformed or there's a deeper issue. Re-run Phase A0 PAT probe.
- Log shows `HTTP 429` / `Retry-After` → ADO rate-limited. Wait 5 min and retry C1 once.
- Log shows `couldn't find remote ref` → branch missing on remote OR stale repo-server clone. Run `kubectl rollout restart deploy/argocd-repo-server -n argocd`, wait 60s, retry C1.

### C3 — 🟢 argocd CLI: Inspect diff (what WOULD be applied/pruned if synced)

```bash
argocd app diff dispatchermfrr -n jupiter 2>&1 | head -100
# (or in UI: open the Application → "App Diff" tab)
```

**Decision rule:** read the diff. If it shows the expected changes (chart values updated
to the new branch, Deployments updated to new image tags) AND no surprise prune of
resources you care about (Secrets, ConfigMaps containing manual overrides) → safe to C4.
If the diff shows pruning of resources that should be preserved → STOP, escalate to
Fabrizio for manual reconciliation strategy.

### C4 — 🟢 argocd CLI: Sync the canary (jupiter only)

```bash
argocd app sync dispatchermfrr -n jupiter --timeout 600
```

Watch progress. Expected wall-time: 1-5 min depending on pod ramp.

### C5 — 🔵 kubectl + 🟤 Inspect: Verify canary recovered

```bash
# Application is Synced + Healthy
argocd app get dispatchermfrr -n jupiter | head -15

# Pods are Ready (the on-the-ground proof)
kubectl get pods -n jupiter -l app.kubernetes.io/instance=dispatchermfrr

# Bystander check — total broken count is now decreasing OR all 67 still broken
kubectl get applications.argoproj.io -A -o json | jq '
  [.items[] | select((.status.conditions // []) | map(select(.type=="ComparisonError" and (.message|test("auth"; "i")))) | length > 0)] | length'
# Expected: ~67 (down by ~1-7 depending on how many jupiter apps got auto-refreshed in cascade)

# Working apps baseline unchanged
kubectl get applications.argoproj.io -A -o json | jq '
  [.items[] | select(.status.sync.status=="Synced" and .status.health.status=="Healthy")] | length'
# Expected: ≥ pre-fix baseline; if LOWER, bystander regression — STOP
```

**Decision rule:** if canary recovers AND bystander count unchanged → proceed to Phase D.
If canary stuck OR bystanders regressed → STOP, investigate, do NOT proceed to multi-slot.

---

## Phase D — Throttled multi-slot rollout (the bulk; 15-25 min)

One slot at a time, 60-second pause between slots. This is the throttle that respects
both ADO TSTU (200/5min per identity) and repo-server parallelism.

### D — 🟢 argocd CLI + 🔵 kubectl: Rolling sync

```bash
# Slots (excluding jupiter which is done in Phase C, and ionix which was created today
# at 12:19 and may need separate handling depending on its current state)
for slot in afi ishtar operations thor veku voltex ionix; do
  echo "==================================================="
  echo "==> Slot: $slot at $(date -u +%H:%M:%S)"
  echo "==================================================="

  # 1. Refresh all apps in the slot (find them dynamically)
  for app in $(kubectl get applications -n $slot --no-headers -o custom-columns=':metadata.name' 2>/dev/null); do
    echo "  refresh $slot/$app"
    argocd app refresh $app -n $slot 2>&1 | tail -2
  done

  # 2. Wait for repo-server to render
  sleep 30

  # 3. Inspect one diff per slot (canary the diff)
  REP_APP=$(kubectl get applications -n $slot --no-headers -o custom-columns=':metadata.name' | head -1)
  if [ -n "$REP_APP" ]; then
    echo "==> Diff for $slot/$REP_APP:"
    argocd app diff $REP_APP -n $slot 2>&1 | head -30
    echo "==> If diff looks safe, syncing all apps in $slot..."
  fi

  # 4. Sync all apps in the slot
  for app in $(kubectl get applications -n $slot --no-headers -o custom-columns=':metadata.name' 2>/dev/null); do
    argocd app sync $app -n $slot --timeout 600 &
  done
  wait

  # 5. Verify monotonic improvement
  BROKEN_NOW=$(kubectl get applications.argoproj.io -A -o json | jq '
    [.items[] | select((.status.conditions // []) | map(select(.type=="ComparisonError" and (.message|test("auth"; "i")))) | length > 0)] | length')
  echo "==> After $slot: broken count = $BROKEN_NOW"

  # 6. Throttle gate — sleep before next slot
  echo "==> Sleeping 60s before next slot..."
  sleep 60
done
```

**Decision rule (per slot):**

- broken count decreases monotonically → continue.
- broken count INCREASES → **STOP** — bystander regression. Investigate before continuing.
- ADO 429 in repo-server logs → **STOP** for 5 minutes, then resume from the next slot.

### Platform `argocd/` namespace apps (separate batch)

```bash
for app in product-asset-scheduling product-flex-trade-optimizer product-vpp-core product-vpp-dispatching \
           rabbitmq-target-state-service-accounts rabbitmq-target-state-topology-playground rabbitmq-target-state-users; do
  argocd app refresh $app -n argocd
  sleep 5
  argocd app diff $app -n argocd 2>&1 | head -20
  argocd app sync $app -n argocd --timeout 600
  sleep 30
done

# Note: argocd/loki uses an OCI Helm chart (grafana.github.io/helm-charts) — its source 1
# may have a different auth path. Inspect first:
argocd app get loki -n argocd | head -20
# If it shows OCI 401 instead of git auth, that's a separate problem (out of this RCA's scope).
```

---

## Phase E — Re-enable auto-prune + selfHeal per slot (after human review; 5-10 min)

For each slot that came up healthy in Phase D, re-enable the auto-sync policy that was
disabled in Phase A4.

### E — 🔵 kubectl: Re-enable syncPolicy

```bash
# Re-enable on the broken-apps list, but ONLY for apps that are now Synced + Healthy.
# Iterate the list, check each, patch if healthy.
while IFS=/ read -r ns name; do
  STATUS=$(kubectl get application $name -n $ns -o jsonpath='{.status.sync.status}/{.status.health.status}' 2>/dev/null)
  if [ "$STATUS" = "Synced/Healthy" ]; then
    echo "  re-enable prune+selfHeal: $ns/$name (status=$STATUS)"
    kubectl -n $ns patch application $name --type=merge \
      -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'
  else
    echo "  SKIP (not healthy): $ns/$name (status=$STATUS)"
  fi
done < /tmp/broken-apps.txt
```

**Decision rule:** any app NOT re-enabled is one that didn't recover in Phase D. Open a
follow-up ticket per app, not a blocker for this rollout.

---

## Phase F — Post-rollout verification (the augmented acceptance checklist; 5 min)

Run each. ALL must pass. Any failure = STOP and triage.

### F1 — 🔵 kubectl: Broken-app count = 0

```bash
kubectl get applications.argoproj.io -A -o json | jq '
  [.items[] | select((.status.conditions // []) | map(select(.type=="ComparisonError" and (.message|test("auth"; "i")))) | length > 0)] | length'
# Expected: 0 (or 1-3 with documented reasons in Phase D notes)
```

### F2 — 🔵 kubectl: Pod readiness

```bash
# Pods in Running state but with NotReady containers (the silent failure)
kubectl get pods -A -o json | jq '
  [.items[] | select(.status.phase=="Running") | select((.status.containerStatuses // []) | map(.ready) | any(. == false))] | length'
# Expected: 0 (or low; document any persistent NotReady)
```

### F3 — 🔵 kubectl: No image-pull errors

```bash
kubectl get events -A --field-selector type=Warning -o json | jq '
  [.items[] | select(.reason | test("Failed|BackOff|ErrImagePull"))] | length'
# Expected: at or below pre-fix baseline (use /tmp/pre-fix-baseline.json if captured)
```

### F4 — 🔵 kubectl: PrometheusRule count not regressed

```bash
NOW=$(kubectl get prometheusrules -A --no-headers | wc -l)
PRE=$(cat /tmp/pre-fix-prom-rules.txt)
echo "Prom rules: pre=$PRE now=$NOW"
# Expected: NOW >= PRE
```

### F5 — 🟢 argocd CLI: Working count not regressed

```bash
kubectl get applications.argoproj.io -A -o json | jq '
  [.items[] | select(.status.sync.status=="Synced" and .status.health.status=="Healthy")] | length'
# Expected: >> pre-fix healthy_synced (the 68 broken apps should now mostly be in this set)
```

### F6 — 🌐 HTTP: Per-slot ingress responds non-404

```bash
for slot in afi ionix ishtar jupiter operations thor veku voltex; do
  CODE=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 10 https://$slot.dev.vpp.eneco.com/ 2>/dev/null || echo "TIMEOUT")
  echo "$slot → HTTP $CODE"
done
# Expected: 200 (or 503 while pods come up — wait 2 min and retry)
# NOT expected: 404 (means ingress has no backing pods — sync incomplete)
```

### F7 — 🔵 kubectl: argocd-repo-server has not restarted

```bash
kubectl -n argocd get pod -l app.kubernetes.io/name=argocd-repo-server \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].restartCount}{"\n"}{end}'
# Expected: restartCount unchanged from pre-fix observation; if it incremented during rollout, document
```

### F8 — ⚪ Slack: Confirm with the original reporter

Post in the thread the original intake was filed in:

> ✅ ALL CLEAR. Sandbox FBE auth fix applied. Jupiter (and 7 other slots) should now sync
> images normally. Please confirm your FBE images update — let me know if anything
> remains stuck and I'll re-investigate. Full RCA: `<path to log dir>`.

Wait for the reporter to confirm before closing the incident.

---

## Rollback (if Phase B-D goes sideways)

The fix is **additive but rollback is NOT atomic during in-flight syncs**. Be aware:

| Stage | Rollback action | What it cleans up | What it does NOT clean up |
|---|---|---|---|
| Before any sync (Phase B only) | 🔵 `kubectl delete secret creds-myriad-vpp-project -n argocd` | Removes credential template; future reconciles fall back to anonymous; cluster returns to pre-fix state | Nothing else has changed |
| After a slot's `argocd app sync` started but before pods Ready (Phase D mid-slot) | 🟢 `argocd app terminate-op <name> -n <slot>` for each in-flight, then delete Secret | Aborts the in-flight operation | **Already-applied resources are not rolled back. Already-pruned resources are gone.** |
| After full rollout completed | (No reason to roll back; investigate and roll forward instead) | — | — |

**Critical**: If you must roll back after a sync started, also revert the prune+selfHeal
disable from Phase A4 (or the next reconcile after the Secret is re-added will trigger
the same cascade you just rolled back from):

```bash
# Re-disable prune on the broken set (defensive)
while IFS=/ read -r ns name; do
  kubectl -n $ns patch application $name --type=merge \
    -p '{"spec":{"syncPolicy":{"automated":{"prune":false,"selfHeal":false}}}}'
done < /tmp/broken-apps.txt
```

---

## Anti-patterns (DO NOT DO)

| ❌ Action | Why not |
|---|---|
| Apply Secret + run the original RCA L8 Step 3 tight loop | Triggers 68 concurrent reconciles; risks repo-server OOM, ADO 429, and 22h-drift silent prune cascade |
| Use `refresh=hard` instead of `refresh=normal` | Forces full re-clone instead of incremental fetch; multiplies ADO Git bytes 10-100x; not needed when the failure mode is no-credential, not corrupted-clone |
| Register two separate `Repository` CRs for `Eneco.Vpp.Core.Dispatching` and `platform-gitops` | Works but is not durable — any future ADO repo under `Myriad - VPP` would need another Repository CR. The project-level credential template covers all future repos automatically. |
| Rotate the PAT again | Yesterday's PAT works (proven by A0 ls-remote probes). The defect is coverage, not credential validity. Rotating creates a new gap on the new bytes. |
| Restart `argocd-application-controller` | It doesn't read the Secret directly; repo-server does. Restarting application-controller is a no-op for this fix. |
| Restart `argocd-repo-server` UNCONDITIONALLY | Only restart if Phase C2 shows `couldn't find remote ref` (stale local clone state). Otherwise the restart wipes the working Applications' caches too and widens the incident. |
| Delete + recreate broken Applications | The ApplicationSet regenerates them in the same broken state because the credential gap is upstream of the Application CR. Wasted effort. |
| Skip Phase A0 PAT-scope probe | If `sa_platform_vpp@eneco.com` lacks Code Read on `Eneco.Vpp.Core.Dispatching`, applying the template lands the Secret but every subsequent reconcile still 401s. Silent no-op. 5-min probe avoids 90-min wrong-direction investigation. |

---

## Escalation

If anything outside the decision rules above happens, escalate to:

- **Fabrizio Zavalloni** in `#myriad-platform` (FBE / platform owner; coordinated yesterday's PAT rotation)
- **Trade Platform on-call** for any cross-cluster MC implications

Authority gradient:

| What | Who can sign off |
|---|---|
| Apply the credential template (B2) | On-call SRE (you) |
| Disable auto-prune temporarily (A4) | On-call SRE (you), but document |
| Re-enable auto-prune per slot (E) | On-call SRE (you), with diff inspection |
| Re-rotate PAT or change ADO permissions | Fabrizio + ADO admin |
| Restart `argocd-repo-server` outside Phase A1.b | Fabrizio (widens blast radius) |
| Roll back mid-sync | Fabrizio (potentially data-loss-shaped) |

## See also

- `rca.md` — full root cause analysis (L1-L12 holistic, feynman-framed)
- `context.md` — investigation evidence trail
- `slack-intake.txt` — original user intake
- Vault: `$SECOND_BRAIN_PATH/2-areas/work-eneco/eneco-vpp-platform/fbe-errors/`
- Yesterday's incident: `2026-05-11-pat-expiry-argocd-auth-break.md` (the recipe whose Step 7 verification was incomplete)
