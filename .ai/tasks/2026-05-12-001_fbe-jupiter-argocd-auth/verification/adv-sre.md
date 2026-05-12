---
task_id: 2026-05-12-001
agent: sre-maniac
timestamp: 2026-05-12T13:05:00Z
status: complete

summary: |
  Adversarial SRE review of RCA L8 fix rollout on vpp-aks01-d (Sandbox). 68 stuck
  Applications across 9 namespaces will simultaneously attempt fetch + Helm render +
  diff + sync once one `repo-creds` Secret lands. Three BLOCKING and four HIGH
  operational failure modes identified that require RCA L8 Step 3 sequencing change.
  Headline: (1) argocd-repo-server `--parallelism-limit` default is *unlimited* per
  ArgoCD docs → 68 concurrent helm-template subprocesses on a single repo-server pod
  is a real OOM/CPU-saturation risk on Sandbox node SKUs; (2) ADO 200-TSTU/5-min
  global consumption limit per service-account user is real and Git clone is
  TSTU-billable — 68 parallel clones from one service account at peak business hours
  can trip enforced delays (Retry-After) silently; (3) `selfHeal=true, prune=true`
  cascade across 22 hours of un-synced drift can prune live resources that operators
  manually intervened on (Secrets, ConfigMaps) without warning and without rollback;
  (4) the RCA verification watches `wc -l broken=0` but observes nothing about pod
  health, ingress 4xx→2xx transition, ACR pull throttling, OOMKilled events, or
  PrometheusRule re-creation. Conditional belief-change: L8 Step 3 MUST change from
  "8 annotations in a tight loop" to a throttled, slot-at-a-time rollout with named
  pre-apply probes (repo-server replica + CPU/mem limits, ACR egress capacity, node
  Allocatable headroom, drift-preview per Application).
---

## Key Findings

- **BLOCKING** — Repo-server helm-template parallelism is unbounded by default; 68 concurrent renders on one pod is a single-pod-OOM blast vector; mitigation must precede annotation loop
- **BLOCKING** — ADO 200 TSTU / 5-min consumption limit is per identity (`sa_platform_vpp@eneco.com` is the single identity here); concurrent fetches from this service account across the cluster can trip enforced HTTP 429 + Retry-After delays, manifesting as new `ComparisonError` silently masquerading as the fix not working
- **BLOCKING** — `selfHeal+prune` across 22 hours of operator drift is unbounded destructive scope; any manual cluster-side patch since 2026-05-10 will be pruned without confirmation; rollback after prune is data-loss-shaped, not config-shaped
- **HIGH** — `refresh=hard` semantics under-specified in coordinator notes; if it implies repo-server local clone purge, all 68 syncs are full-clones not incremental fetches, multiplying ADO Git throughput cost by ~10-100x bytes vs. an incremental fetch
- **HIGH** — ACR (`vppacrsb.azurecr.io`) image-pull throttling untested at burst of 64+ Deployments materializing concurrently on Sandbox node SKUs; image pull is per-node and may serialize at the kubelet
- **HIGH** — Bystander Apps (working OCI rabbitmq, working VPP-Configuration Source 2) share the same repo-server pod; if repo-server saturates or OOMs, working Apps regress to `ComparisonError`, widening the incident
- **HIGH** — Rollback of the Secret does NOT abort in-flight syncs deterministically; once repo-server has cached the credential or rendered manifests, sync continues with the cached state; the rollback escape hatch named in RCA L8 is incomplete
- **MEDIUM** — Time-of-day risk: 14:30 CEST is mid-business-hours; a developer push during rollout can race the annotation loop, causing one slot to sync against an in-flight commit
- **MEDIUM** — RCA L9 verification misses pod-health gates, ACR pull errors, kube-apiserver QPS spike from 68 simultaneous reconciles, and per-namespace ResourceQuota events
- **MEDIUM** — No pre-apply drift inventory; operator does not know WHICH resources are about to be pruned in WHICH namespaces before the Secret lands
- **LOW** — Annotation-loop is bash-fragile (no error handling on `kubectl annotate` failures, no exponential backoff, no progress logging)

# Adversarial SRE Review — RCA 2026-05-11 FBE Sandbox ArgoCD Auth Fix Rollout

**Reviewer**: sre-maniac (typed-frame, distinct from RCA author)
**Target**: `log/employer/eneco/02_on_call_shift/2026_05_11_fbe_jupiter_argocd_image_auth_error/rca.md` L8 + L11
**Mission**: enumerate operational failure modes of applying the durable `repo-creds`
Secret + annotation-loop fix to vpp-aks01-d during European business hours, when 68
Applications will simultaneously transition from `ComparisonError` to attempting
fetch + Helm render + diff + sync (with `prune=true`, `selfHeal=true`).

**Verdict**: **FIX FIRST** — three BLOCKING op-modes exist. RCA L8 Step 3 sequencing
must change. Specific changes named at end.

## Murphy Assessment (first-reflex)

```text
MURPHY ASSESSMENT for the rollout (not the fix's correctness):
├─ Network: 68 simultaneous HTTPS fetches to dev.azure.com from one identity
│   → ADO TSTU 200/5min limit (A1 confirmed via Microsoft Learn) can trip;
│     symptom = HTTP 429 + Retry-After, looks identical to a credential miss
├─ Disk: repo-server pod's emptyDir cache may not have headroom for 68
│   concurrent clones of Eneco.Vpp.Core.Dispatching (size unknown; A3 UNVERIFIED)
├─ Database (kube-apiserver): 68 Application status updates + Deployment/Service/
│   Secret/CM/Ingress materializations is a write-burst against etcd
├─ Memory: helm-template subprocesses on one repo-server pod (default replicas=1,
│   A3 UNVERIFIED for vpp-aks01-d); --parallelism-limit default = UNLIMITED
│   (A1 from ArgoCD docs) → 68 parallel helm template processes if uncapped
├─ CPU: same as Memory; helm template is CPU-bound on chart complexity
├─ Concurrent: 68 reconciles fan out to AKS workloads — kubelet image pulls
│   from ACR serialize per-node
└─ VERDICT: FRAGILE — multiple single-pod / single-identity saturation vectors
```

---

## Item-by-item Findings

### 1. Repo-server saturation (helm-template + git fetch concurrency)

**Severity: BLOCKING**

**Concrete failure mode**: ArgoCD `argocd-repo-server` flag `--parallelism-limit`
documents [A1, microsoft-mcp/argo-cd.readthedocs.io server-commands page]: "Any
value less than 1 means no limit." If the Sandbox cluster's `argocd-repo-server`
Deployment leaves this flag at default, 68 simultaneous Application refreshes
spawn up to 68 concurrent `helm template` subprocesses + 68 concurrent git
clones on (likely) one repo-server pod. Each helm-template invocation is
CPU-bound and allocates per-chart MB-scale heap. On a Sandbox-class node
(typically `Standard_D4ds_v5` or smaller per Eneco's MC pattern; A3 UNVERIFIED
for this cluster), repo-server OOMs or CPU-throttles → all 68 reconciles fail
with errors that look like the original `ComparisonError` ("Failed to load
target state") and the operator concludes the fix didn't work.

**Falsifier**: `kubectl -n argocd get deploy argocd-repo-server -o yaml | grep
-E 'parallelism-limit|replicas|resources'`. If a non-default
`--parallelism-limit` ≤ 10 is set AND replicas ≥ 2 AND mem limit ≥ 4Gi,
downgrade to HIGH. Otherwise BLOCKING stands.

**Mitigation**: Cap parallelism before the Secret lands:
```bash
kubectl -n argocd set env deploy/argocd-repo-server ARGOCD_REPO_SERVER_PARALLELISM_LIMIT=8
# or patch args: --parallelism-limit=8
kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=120s
```

**Pre-apply probe (REQUIRED)**:
```bash
kubectl -n argocd get deploy argocd-repo-server -o json | jq '{
  replicas: .spec.replicas,
  args: .spec.template.spec.containers[0].args,
  resources: .spec.template.spec.containers[0].resources,
  env: .spec.template.spec.containers[0].env
}'
# Capture: replicas, --parallelism-limit, memory limit, CPU limit
```

---

### 2. ADO rate limit on burst Git clone

**Severity: BLOCKING**

**Concrete failure mode**: ADO global consumption limit is **200 TSTUs in any
sliding 5-minute window per identity** [A1, microsoft-mcp/learn.microsoft.com
rate-limits page]. All 68 broken Apps authenticate as `sa_platform_vpp@eneco.com`
— a **single identity**. Git clone is TSTU-billable (the doc names "uploading a
large number of files to version control" and "running builds, which download
files from version control" as TSTU sources). 68 simultaneous full clones of
`Eneco.Vpp.Core.Dispatching` (chart-bearing repo; size unknown, A3) from one
identity in one 5-minute window has a non-trivial probability of crossing the
threshold. Response = HTTP 429 + `Retry-After` header [A1, same source]. ArgoCD
repo-server's go-git client may or may not respect Retry-After (A3 UNVERIFIED) —
if it doesn't, ArgoCD reports a generic git error that **looks identical to an
authentication failure** in the Application's `status.conditions.message`. Worst
operational outcome: operator sees `ComparisonError` reappear, concludes the fix
failed, rolls back the Secret, and the cluster is in a worse state (now
PAT-throttled at the ADO level, persistent for ~5 minutes after consumption
drops to zero).

**Falsifier**: load test would be the only way to ground-truth this for THIS
identity. Cannot probe ADO usage directly without `usage-monitoring` page
access; A3 UNVERIFIED. But the bound is a HARD bound — 200 TSTU per 5 min — and
68 concurrent clones from one identity is a deliberate stress on it.

**Mitigation**: throttle the annotation loop. One slot at a time, 30-60s
between slots (gives repo-server time to complete its fetch+render and gives
the TSTU bucket time to bleed off):
```bash
for slot in afi ionix ishtar jupiter operations thor veku voltex; do
  kubectl annotate application dispatchermfrr -n $slot \
    argocd.argoproj.io/refresh=normal --overwrite
  echo "==> $slot annotated at $(date -u +%H:%M:%S); sleeping 60s"
  sleep 60
done
```
(Note: `refresh=normal` rather than `refresh=hard`; see item 6.)

**Pre-apply probe (REQUIRED)**: query ADO usage page if accessible:
- `https://dev.azure.com/enecomanagedcloud/_usersSettings/usage` (signed in as
  `sa_platform_vpp` if possible, or as Alex with org-admin)
- If not accessible, run a CONTROLLED probe FIRST: annotate ONE app, watch
  repo-server logs for any 429 / Retry-After, then proceed.

---

### 3. Helm render thundering herd

**Severity: BLOCKING** (compound with item 1)

**Concrete failure mode**: even if git fetch succeeds, the next step is `helm
template` for each Application's chart. Each render allocates a per-chart Go
heap (typically 50-300 MB for non-trivial charts). 68 concurrent renders on one
repo-server pod at default unlimited parallelism = peak memory burst of ~3-20 GB
in seconds. If pod memory limit is < that (typical Sandbox argocd defaults are
2-4 Gi), OOMKill → pod restart → all 68 reconciles re-queue → repeat → crash
loop. Operator sees `ComparisonError` flapping and zero clarity on root cause.

**Falsifier**: same probe as item 1. If `--parallelism-limit ≤ 8` is set,
downgrade to HIGH. If memory limit ≥ 8 Gi, downgrade to MEDIUM.

**Mitigation**: same as item 1 — cap parallelism in repo-server BEFORE Secret
lands.

**Pre-apply probe (REQUIRED)**: capture current repo-server pod memory + CPU
usage as baseline:
```bash
kubectl -n argocd top pod -l app.kubernetes.io/name=argocd-repo-server
kubectl -n argocd describe pod -l app.kubernetes.io/name=argocd-repo-server | grep -A5 'Limits:'
```

---

### 4. Auto-sync + auto-prune cascade (the destructive op-mode)

**Severity: BLOCKING — this is the data-loss-shaped one**

**Concrete failure mode**: every broken Application has
`syncPolicy.automated.prune=true, selfHeal=true` (per coordinator-provided
context). For 22 hours these Applications have been unable to reconcile. During
that 22h, operators (Alex yesterday, possibly other team members) **may have
manually patched cluster state** — kubectl edit on a Deployment to bump a
replica, a manual `kubectl create secret` to unblock a test, a `kubectl scale`
on a noisy controller. The moment auth resolves, every Application will:
1. Render current desired state from Git (the chart at current branch HEAD)
2. Diff against live state
3. PRUNE any resource in the namespace owned by this Application that is NOT in
   the rendered set
4. APPLY/UPDATE everything else

**Pruned resources may include**: `Secret`, `ConfigMap`, `Deployment`, `Service`,
`Ingress`, `ServiceMonitor`, `PrometheusRule`, `HorizontalPodAutoscaler`,
`NetworkPolicy`, anything labelled with `argocd.argoproj.io/instance=<app>`.

**Critical**: `prune=true` with `selfHeal=true` does NOT prompt the operator.
There is no confirmation gate. The Application discovers drift and erases it
silently within seconds of the sync. **For 22 hours of drift, the operator has
zero visibility into what is about to be deleted.**

Worst real-world example: if anyone in the last 22h kubectl-patched a Secret
(e.g., to override a value to unblock testing), it gets pruned and the
downstream pods crash-loop on the next ConfigMap reload.

**Falsifier**: per-slot drift inventory BEFORE the fix:
```bash
# For each slot, list resources currently in the namespace that are
# argocd-managed by an Application source that's about to come back online
for slot in afi ionix ishtar jupiter operations thor veku voltex; do
  echo "===== $slot ====="
  kubectl get all,secret,cm,ingress,servicemonitor,prometheusrule -n $slot \
    -l argocd.argoproj.io/instance \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.kind}{"\t"}{.metadata.labels.argocd\.argoproj\.io/instance}{"\n"}{end}'
done > /tmp/pre-fix-inventory.txt
```

**Mitigation**: **disable auto-prune temporarily on the broken set before
applying the Secret**, then re-enable per-slot after manual review:
```bash
# DISABLE prune on all 68 Apps
for app in $(cat /tmp/broken-apps.txt | awk '{print $1}'); do
  ns=$(echo $app | cut -d/ -f1); name=$(echo $app | cut -d/ -f2)
  kubectl -n $ns patch application $name --type=merge \
    -p '{"spec":{"syncPolicy":{"automated":{"prune":false,"selfHeal":false}}}}'
done
# Apply the Secret (item 1+2 mitigations active)
# Then manually argocd app sync each slot with --dry-run first
# Re-enable prune slot-by-slot after dry-run inspection
```

Alternative: use `syncPolicy.syncOptions: [ServerSideApply=true]` + `Prune=false`
and require explicit operator approval per slot.

**Pre-apply probe (REQUIRED)**:
```bash
# Inventory cluster-side resources currently labelled with argocd.argoproj.io/instance
# that DO NOT match any current Application's spec — these are prune candidates.
# Can be done via `argocd app diff <app> --refresh` once auth is in place, BUT
# refresh triggers the same fetch+render path we're trying to throttle. Catch-22.
# Workaround: read the GitOps source's chart from a developer machine (out-of-band
# of repo-server) and grep cluster for non-matching argocd-labelled resources.
```

---

### 5. Pod ramp + AKS node CPU/memory + ACR pull throttling

**Severity: HIGH**

**Concrete failure mode**: 68 Applications → ~8 Deployments/slot × 8 FBE slots
+ platform = ~64 Deployments materialize roughly simultaneously. Each Deployment
spawns 1+ Pods. Each Pod triggers an image pull from `vppacrsb.azurecr.io`.
**ACR has per-registry pull-rate limits and per-IP throttling**; on a Standard
SKU registry (A3 UNVERIFIED for vppacrsb), the limit is ~1000 read ops/min and
bandwidth-capped. 64+ simultaneous image pulls from a small node pool (Sandbox
clusters typically 3-6 nodes) saturate node disk I/O for kubelet image-pull,
serializing pulls per node. Pods stuck in `ContainerCreating: pulling image`
for minutes. Kubelet eventually emits `Back-off pulling image` events.
PodReadinessGates miss. Ingress controllers route to NotReady pods → 503.

Cold-start cluster behavior is also untested: the 64+ Deployments may include
init-containers, sidecars (Istio, secrets-store-csi), each of which adds image
pulls.

**Falsifier**: Sandbox cluster has historically run all 8 slots simultaneously
when healthy, so the steady-state load is provably handleable. The risk is the
**cold-start burst**, not steady state.

**Mitigation**: same throttled rollout as item 2 (one slot at a time).

**Pre-apply probe (REQUIRED)**:
```bash
# Node capacity headroom
kubectl get nodes -o json | jq '.items[] | {name: .metadata.name,
  allocatable: .status.allocatable, capacity: .status.capacity}'
# Current pod count vs max
kubectl get nodes -o json | jq '.items[] | {name: .metadata.name,
  pods: (.status.allocatable.pods // "?")}'
# ACR Standard SKU pull-rate budget (or Premium if upgraded)
az acr show -n vppacrsb --query '{sku:sku.name,name:name}'
```

---

### 6. `refresh=hard` semantics

**Severity: HIGH**

**Concrete failure mode**: RCA L8 Step 3 and L11 Step 6 use
`argocd.argoproj.io/refresh=hard`. ArgoCD documentation could not be retrieved
in the time available to confirm exact semantics (A3 UNVERIFIED[blocked: docs
pages I fetched did not describe the annotation; would require source-code read
of `controller/state.go` or `pkg/server` to ground-truth]). Per community
practice and prior incident knowledge, `refresh=hard` is widely understood to
**force a clean re-clone** (purges the repo-server's local working tree for
that repo) rather than incremental `git fetch`. If correct, this multiplies the
ADO Git transfer cost in item 2 by full-clone size vs incremental delta —
typical impact is 10-100x bytes — and compounds the TSTU consumption.

**Mitigation**: use `refresh=normal` for the initial post-Secret rollout.
`refresh=hard` is only needed if there is reason to believe the local clone is
corrupted. After the Secret lands, the local clone state is "couldn't
authenticate" — there is no corrupted state, just no successful state. Normal
refresh forces re-reconcile, which re-attempts credential resolution. That is
what we want.

**Pre-apply probe (REQUIRED)**: source-verify `refresh=hard` semantics before
running L11 Step 6:
- Grep `argo-cd` repo at the cluster's installed version tag for
  `RefreshTypeHard` and `RefreshTypeNormal`; observe what differs in the code
  path.
- If unverifiable, default to `refresh=normal` — strictly safer for this
  rollout, equally effective for the auth-resolution use case.

---

### 7. Bystander Apps (the working set)

**Severity: HIGH**

**Concrete failure mode**: the working Apps (OCI Helm charts from
`vppacra.azurecr.io`/`vppacrsb.azurecr.io`, the working VPP-Configuration Source
2 reads on every Application) **share the same repo-server pod**. Repo-server
is a stateless renderer but it is **a single point of saturation**. If item 1+3
materialize (repo-server OOM, helm-render queue depth saturates), the Apps that
were healthy 5 minutes before the fix flip to `ComparisonError` too. The
incident expands from 68 Apps to potentially all ~80+ Apps on the cluster. Time
to recover: pod restart + cold cache rebuild = 5-10 minutes during which NO App
on the cluster syncs.

Additionally: if the operator restarts repo-server as a recovery step
(forbidden by RCA L8 anti-pattern but tempting under stress), **the in-memory
repo cache for the working Apps is wiped**. Every Application — broken AND
working — must re-fetch on the next reconcile. Compounds with items 1+2+3.

**Falsifier**: list current Apps and confirm working Apps' source URLs do NOT
overlap with broken Apps' source URLs at the repo-server cache key level (which
they don't — different ADO/OCI repos). But the shared CONCURRENCY pool is the
risk, not the shared cache.

**Mitigation**: same as items 1+3 — bound parallelism + bound replicas + monitor
repo-server memory during rollout. Specifically: after each slot's annotation,
verify ALL Apps' status before proceeding to next slot:
```bash
# After each slot, total broken count should DECREASE monotonically
kubectl get applications.argoproj.io -A -o json | jq '
  [.items[] | select(.status.conditions[]?.type=="ComparisonError")] | length'
```
If the count **increases** at any point, HALT — bystander regression detected.

**Pre-apply probe (REQUIRED)**: snapshot the working-Apps count for regression
baseline:
```bash
kubectl get applications.argoproj.io -A -o json | jq '{
  total: (.items | length),
  broken: ([.items[] | select(.status.conditions[]?.type=="ComparisonError")] | length),
  working: ([.items[] | select(.status.conditions[]?.type != "ComparisonError" or (.status.conditions | length) == 0)] | length)
}' > /tmp/pre-fix-baseline.json
cat /tmp/pre-fix-baseline.json
```

---

### 8. Time-of-day risk

**Severity: MEDIUM**

**Concrete failure mode**: 2026-05-12T~12:30 UTC = 14:30 CEST = mid-business
hours in Rotterdam/Eindhoven. Probability that one of 8 FBE-using developers
pushes a commit during the 5-10 minute rollout window is non-zero. Race
scenario: operator annotates `jupiter/dispatchermfrr` → repo-server starts
fetching `feature/fbe-808321_...@HEAD` → developer pushes commit X → repo-server
fetches commit X (not the prior SHA the slot was supposed to be on) → sync
applies commit X → developer's slot deploys an unintended commit. Recovery:
developer must push correct commit again, slot resyncs. Not catastrophic but
muddies observability and lengthens the rollout.

**Mitigation**: announce in `#myriad-platform` and `#fbe-users` (or local
equivalent) **before** starting the annotation loop: "FBE platform credential
fix landing in ~10 minutes; please pause feature-branch pushes to FBE
ApplicationSet repos until ALL CLEAR is posted." OR schedule rollout for
non-business hours (00:00-06:00 UTC).

**Pre-apply probe**: check Slack `#myriad-platform` for any active developer
who recently mentioned a slot, and `git log --since=1.hour` on
`Eneco.Vpp.Core.Dispatching` from a developer machine.

---

### 9. Rollback during cascade

**Severity: HIGH**

**Concrete failure mode**: RCA L8 says "Rollback = `kubectl delete secret
creds-myriad-vpp-project -n argocd` returns the cluster to today's pre-fix
state. No state is destroyed." This is **operationally incorrect** for a
mid-rollout cascade. Once repo-server has resolved the credential, fetched the
repo, rendered manifests, and the application-controller has started an
**Operation** on the Application (sync), deleting the Secret does NOT abort the
operation. ArgoCD does not re-check credentials mid-operation. The sync
proceeds with the rendered manifests, prune happens, Deployments apply, pods
churn. Rollback only prevents FUTURE reconciles from succeeding. **Any prune
that already happened is lost.**

The RCA's "Rollback" wording is true for the CONFIG plane (the Secret CRD goes
away cleanly) but FALSE for the OPERATIONAL plane (the work the Secret unlocked
continues). Treating it as a recoverable rollback gives false confidence.

**Mitigation**: combine with item 4 mitigation — disable auto-prune+selfHeal
BEFORE landing the Secret. Then the Secret arrival unlocks reconciliation
(visibility) but does NOT trigger destructive sync. Operator manually reviews
each slot's `argocd app diff` output and decides per-slot whether to sync. This
is the actual safe abort surface — manual sync gate, not Secret-delete gate.

**Pre-apply probe**: confirm the abort surface exists by testing on ONE app
first:
```bash
# Surgical mode for the first slot only:
kubectl patch application dispatchermfrr -n jupiter --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":{"prune":false,"selfHeal":false}}}}'
# Then proceed with item 1+2 mitigations
# Then argocd app diff dispatchermfrr -n jupiter # inspect prune candidates
# Then argocd app sync dispatchermfrr -n jupiter # if safe
```

---

### 10. Observability during the rollout

**Severity: MEDIUM**

**Concrete failure mode**: RCA L9 verification step 2 watches `wc -l` of broken
Apps going to 0. This is **necessary but radically insufficient**:
- It does NOT observe **pod health** (broken pods, OOMKilled, ImagePullBackOff)
- It does NOT observe **ingress 4xx→2xx transition** (curl is mentioned in step
  5 but only for jupiter, not the other 7 slots)
- It does NOT observe **kube-apiserver request latency / QPS spike** from 68
  reconciles writing status updates simultaneously
- It does NOT observe **repo-server memory/CPU/restart counts**
- It does NOT observe **ACR pull errors** (kubelet `Failed to pull image`)
- It does NOT observe **per-namespace ResourceQuota events** (if any slot has
  CPU/memory quota, sync may fail with `exceeded quota`)
- It does NOT observe **PrometheusRule re-creation** — if prune deletes a
  PrometheusRule the SRE team relies on, alerts go dark silently

**Mitigation**: open a 4-pane dashboard before starting rollout:
1. `watch -n 5 'kubectl get applications.argoproj.io -A -o json | jq ".items[]|{name:.metadata.namespace+\"/\"+.metadata.name, sync:.status.sync.status, health:.status.health.status}" -c'`
2. `kubectl get events -A --watch --field-selector type=Warning`
3. `kubectl top pod -n argocd` every 10s
4. `kubectl get pods -A --watch | grep -vE '1/1|2/2|3/3|Completed'` (anything not Ready)

Plus: after final All-Clear, hit Grafana / Azure Monitor for AKS cluster CPU,
memory, ACR pull-rate, and Prometheus alert rule count baseline.

**Pre-apply probe**: snapshot Prometheus alert rule count BEFORE rollout for
regression detection:
```bash
kubectl get prometheusrules -A --no-headers | wc -l > /tmp/pre-fix-prometheus-rules.txt
```

---

### 11. What the RCA's "verification" misses entirely

**Severity: MEDIUM (cumulative)**

The RCA L9 + L11 verification framework is **credential-plane-complete** but
**operational-plane-incomplete**. Named missing acceptance criteria:

| Missing criterion | Why it matters | Probe |
|---|---|---|
| **Pod readiness count** | Sync success ≠ Pods Ready; CrashLoopBackOff still possible | `kubectl get pods -A -o json \| jq '[.items[] \| select(.status.phase=="Running") \| select(.status.containerStatuses[] \| .ready == false)] \| length'` should be 0 |
| **No prune-side data loss** | The 22h drift inventory; what got pruned and was that OK | Diff `/tmp/pre-fix-inventory.txt` vs post-fix inventory; manual review |
| **ACR pull error count** | Image throttling shows as `ErrImagePull` events | `kubectl get events -A --field-selector reason=Failed,reason=BackOff` should not be elevated |
| **kube-apiserver QPS stability** | 68-Application status churn can spike apiserver, affecting other tenants | AKS Diagnostic Settings → kube-apiserver metrics, or `kubectl get --raw /metrics` |
| **PrometheusRule retention** | Alerts may have been pruned | `kubectl get prometheusrules -A --no-headers \| wc -l` vs pre-fix snapshot |
| **No bystander regression** | Working Apps must remain working | `pre-fix-baseline.json:.working == post:.working` |
| **Slot ingress 200** | Per-slot URL probe, not just jupiter | `for slot in ...; do curl -sk -o /dev/null -w "$slot %{http_code}\n" https://$slot.dev.vpp.eneco.com/; done` |
| **Reporter confirmation** | The original intake reporter sees images updating | Slack reply from the jupiter dev confirming |

---

## Conditional belief-change directive (applied)

**Conditional**: if BLOCKING/HIGH op-modes exist, RCA L8 Step 3 sequencing must
change. **Result: three BLOCKING + four HIGH op-modes exist → L8 Step 3 MUST
change.**

### Required sequence change

Replace L8 Step 3 ("for slot in ...; do kubectl annotate ... refresh=hard
--overwrite; done; sleep 90; check") with the following **gated rollout**:

```text
PHASE A — Pre-apply guard (BEFORE the Secret lands)
  A1. Probe repo-server replicas, --parallelism-limit, memory limit
      → if --parallelism-limit unset or ≥ 20, patch to 8 and rollout-status
  A2. Probe node Allocatable, ACR SKU, current top-pod baseline
  A3. Snapshot working/broken Application counts → /tmp/pre-fix-baseline.json
  A4. Snapshot per-slot argocd-labelled resource inventory → /tmp/pre-fix-inventory.txt
  A5. Snapshot PrometheusRule count → /tmp/pre-fix-prometheus-rules.txt
  A6. Announce in #myriad-platform: "FBE credential fix rolling out ~10 min;
      please pause feature-branch pushes"
  A7. Disable auto-prune+selfHeal on ALL 68 broken Apps (Item 4 mitigation)

PHASE B — Apply the Secret
  B1. kubectl apply -f creds-myriad-vpp-project.yaml
  B2. Observe repo-server pod for 2 minutes — confirm no OOM, no restart,
      CPU stays < 80% of limit

PHASE C — Surgical first-slot validation
  C1. kubectl annotate application dispatchermfrr -n jupiter \
        argocd.argoproj.io/refresh=normal --overwrite      # not hard, see item 6
  C2. Wait 90s. Observe repo-server logs for 401/429/Retry-After.
  C3. argocd app diff dispatchermfrr -n jupiter            # see what WOULD be pruned/applied
  C4. If diff is reasonable → argocd app sync dispatchermfrr -n jupiter
  C5. Confirm pods Ready + ingress 200 + bystander count unchanged
  C6. If anything off → HALT, investigate, this is the safest abort point

PHASE D — Throttled multi-slot rollout (one slot at a time)
  For each remaining slot in afi, ionix, ishtar, operations, thor, veku, voltex,
  + argocd platform Apps:
    D1. annotate refresh=normal on that slot's representative App
    D2. wait 60s
    D3. argocd app diff (per Application in the slot)
    D4. argocd app sync (per Application; can be batched per slot if diff OK)
    D5. snapshot broken count — MUST be monotonically decreasing
    D6. if broken count increases (bystander regression) → HALT

PHASE E — Re-enable auto-prune+selfHeal per slot
  After human approval per slot, re-apply auto-prune+selfHeal:
    kubectl patch application <name> -n <slot> --type=merge \
      -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'

PHASE F — Post-rollout verification (the L9-augmented checklist)
  F1. Broken Apps count = 0 (RCA L9 #2)
  F2. Pod readiness = full set Ready (NEW)
  F3. Per-slot ingress 200 (NEW: all 8 slots, not just jupiter)
  F4. ACR pull error events = baseline (NEW)
  F5. PrometheusRule count >= pre-fix (NEW)
  F6. Reporter confirms in Slack (RCA L9 #6)
  F7. argocd repo-server pod has not restarted (NEW)
```

Estimated rollout time: ~25-40 minutes with throttling, vs. ~3 minutes for
the original tight-loop. **Worth it.**

---

## Mechanism trace for the headline BLOCKING

```text
MECHANISM TRACE — "fix triggers cascade rather than recovery"

SYMPTOM: Operator applies Secret + annotates 8 apps in tight loop.
         Within 30 seconds, dashboard shows broken-app count UNCHANGED or
         INCREASED. Repo-server pod is OOMKilled or in CrashLoopBackOff.

PROXIMATE CAUSE: 68 concurrent helm-template subprocesses + 68 concurrent git
                 clones on one repo-server pod exceeds memory limit OR trips
                 ADO 200 TSTU/5min limit → all 68 reconciles fail with errors
                 that look indistinguishable from the original auth error.

ENABLING CONDITION:
  (a) --parallelism-limit defaults to UNLIMITED (A1, ArgoCD docs)
  (b) Single repo-server pod (default replicas=1 unless HA mode enabled — A3)
  (c) Single service account identity sa_platform_vpp shared across all 68
      Apps → all 68 fetches charge the same TSTU bucket (A1, MS Learn docs)
  (d) `refresh=hard` (if it implies clean re-clone) maximizes per-fetch cost
      (A3 UNVERIFIED on exact semantics)

ROOT CAUSE: RCA L8 Step 3 was written from the perspective of credential-plane
            correctness (PAT + URL prefix → resolves) without modelling the
            operational-plane cost of 68 simultaneous reconciles. The fix
            verb ("apply Secret + annotate 8 apps") is correct in steady state
            but is a stress-test in the rollout transient.

DESIGN FLAW: RCA does not separate "credential correctness" (one-shot,
             low-cost, well-understood) from "reconcile rollout" (cascading,
             cost-bursting, requires throttling). The two are conflated into
             one L8 Step 3.
```

---

## Evidence labels

| Claim | Label | Source |
|---|---|---|
| `argocd-repo-server --parallelism-limit < 1 = no limit (default unlimited)` | A1 | `https://argo-cd.readthedocs.io/en/stable/operator-manual/server-commands/argocd-repo-server/` |
| ADO 200 TSTU / 5-min sliding window per identity; HTTP 429 + Retry-After | A1 | `https://learn.microsoft.com/en-us/azure/devops/integrate/concepts/rate-limits` |
| Git operations are TSTU-billable | A1 | Same source, "running builds, which download files from version control and produce log output" |
| 68 broken Apps share one identity `sa_platform_vpp@eneco.com` | A1 | RCA Context Ledger row "sa_platform_vpp@eneco.com" + Rung 3 |
| Apps have `prune=true, selfHeal=true` | A1 | Coordinator-provided context (coordinator-cited; not independently re-probed in this review) |
| `refresh=hard` purges local clone vs incremental fetch | A3 UNVERIFIED[blocked: docs page fetches did not contain semantics; resolving probe = source-read argo-cd/controller code at deployed version tag] | Failed WebFetch on `user-guide/commands/argocd_app_get` and `user-guide/sync_windows` |
| Sandbox cluster node SKU / repo-server replica count / memory limit | A3 UNVERIFIED[blocked: not probed in this review; coordinator named it "not yet probed"; resolving probe = Phase-A1 pre-apply check] | Coordinator notes |
| ACR `vppacrsb` SKU (Standard vs Premium) and pull-rate budget | A3 UNVERIFIED[blocked: not probed; resolving probe = `az acr show -n vppacrsb`] | — |
| ADO Git client in argocd uses go-git and respects Retry-After | A3 UNVERIFIED[blocked: would require source-read of argo-cd/util/git package] | — |

---

## Discriminator: when to downgrade the verdict

If the pre-apply probe in Phase A1 returns:
- `--parallelism-limit` ≤ 10 AND
- `replicas` ≥ 2 AND
- `memory limit` ≥ 8 Gi AND
- ADO usage page shows `sa_platform_vpp` at < 50 TSTU consumption in last 5 min,

then items 1, 2, 3 downgrade from BLOCKING to MEDIUM and the throttled loop in
Phase D can be tightened from 60s/slot to 15s/slot. Item 4 (prune cascade)
remains BLOCKING regardless of any infrastructure tuning — that is a
behavioral, not capacity, problem.

If the pre-apply probe cannot be performed (e.g., operator does not have
cluster-admin), then the **defaults must be assumed adversarial** and the full
throttled sequence applies.

---

## Self-questioning (mandatory before verdict)

1. **Symptom vs root cause?** Root cause traced: unlimited parallelism +
   single-identity TSTU bucket + unbounded prune cascade. Not just "might OOM".

2. **What if the obvious explanation is wrong?** Alternative: maybe Sandbox
   argocd is already HA-tuned (`replicas=3`, `--parallelism-limit=10`, mem
   limit `8Gi`). In that case items 1+3 downgrade. Item 2 (ADO TSTU) does NOT
   downgrade — the limit is per-identity, not per-pod. Item 4 (prune cascade)
   does NOT downgrade — that's behavioral.

3. **Production-load assumption check?** I'm assuming the broken Apps' chart
   sizes and Helm complexity match typical (50-300 MB/render). If charts are
   small (<10 MB) the memory ceiling is much lower and item 3 downgrades. A3
   on this; probe would be `helm template` on one chart from a dev machine.

4. **Cascade complete to user impact?** Yes: traced to (a) developer sees same
   error after fix, concludes broken, files new intake → MTTR doubled; (b)
   pruned PrometheusRule causes silent alert blind spot; (c) bystander Apps
   regress, widening incident to all FBE slots + platform.

---

## Receipt summary

| RCA gap | Class | Resolved by |
|---|---|---|
| L8 Step 3 tight loop, no throttling | BLOCKING | Phase D throttled rollout |
| L8 rollback claim ("delete Secret = pre-fix state") | HIGH | Phase A7 + Phase E (prune disabled, manual re-enable) |
| L9 verification observes only `wc -l broken=0` | MEDIUM | Phase F augmented checklist |
| L11 Step 6 uses `refresh=hard` without source-verified semantics | HIGH | Use `refresh=normal`; A3 flag on `hard` |
| No pre-apply drift inventory | BLOCKING (with item 4) | Phase A4 inventory snapshot |
| No bystander regression guard | HIGH | Phase A3 + Phase D5 monotonic check |
| Time-of-day pressure | MEDIUM | Phase A6 announcement (or reschedule) |

---

## Final verdict

**FIX FIRST.** RCA L8 Step 3 + L11 Step 6 require restructuring per Phase A→F
above. The credential-plane fix (the Secret yaml) is correct. The rollout
plan is operationally fragile. With the Phase A→F restructure, this is a
safe rollout. Without it, the probability that the cluster ends up in a
worse state than today is non-trivial — and the failure modes are quietly
indistinguishable from "the fix didn't work", which is the worst possible
class of failure for operator confidence.
