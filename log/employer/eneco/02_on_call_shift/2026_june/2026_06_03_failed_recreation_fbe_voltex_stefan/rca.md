# RCA — voltex FBE "failed recreation" (Stefan)

> **Status:** complete · **Date:** 2026-06-04 · **Slot:** voltex · **Env:** Sandbox (`vpp-aks01-d`, sub `7b1ba02e-bac6-4c45-83a0-7f0d3104922e`)
> **On-call:** Alex Torres · **Reporter:** Stefan · **Severity:** Medium (single dev FBE blocked; no prod impact)
> **Verification:** triple adversarial review (sherlock-holmes causal re-probe · sre-maniac fix-safety · socrates-contrarian assumptions/goal).

> ## ✅ RESOLVED — 2026-06-04 (fix applied, authorized)
> Track 1 executed: stripped the stuck `hook-finalizer` on `Job/seed-assets-alarmengine-postsync-1779187628` + force-deleted the zombie `frontend`/`monitor` pods. The deadlock cleared **immediately** and the ApplicationSet **auto-recreated** `voltex-app-of-apps` + all 21 children (no pipeline rerun; Step 4 not needed).
> **Outcome (live-witnessed, A1):** app-of-apps Synced/Healthy · 20/21 children Healthy (clientgateway settling) · `frontend` Synced/Healthy with endpoint `10.0.1.157` · **alarmengine seed now returns `204` (was `500`)** · `secret-provider-kv` SecretProviderClass restored.
> **Branch verdict — EXONERATED:** the seed-500 (L4 open item) was the **missing secret mount / deadlock state**, not Stefan's TSO appconfig/image — proven by the clean `204` seed after recreate with secrets present. The `secret-provider-kv` was missing only because the `secretprovider` child wasn't deployed (a deadlock symptom). Stefan's branch deploys cleanly.

## Evidence labels

- **A1 FACT** — externally witnessed (live `kubectl`/`argocd --core`/`az devops` output, or file:line).
- **A2 INFER** — derived from A1 via stated reasoning.
- **A3 UNVERIFIED[blocked: reason]** — could not probe; blocking reason + resolving path named.

## One-paragraph answer (for Stefan)

Your FBE is **not** broken by an ArgoCD/render failure — and your instinct that
"something is off with my branch" is **partly right but for a different reason
than you thought.** Two distinct problems are stacked:

1. **The thing blocking recreation right now is a Kubernetes/ArgoCD finalizer
   deadlock.** Yesterday (2026-06-03 13:14:51Z) the whole voltex FBE was issued a
   delete. 21 of its 22 apps deleted cleanly, but `voltex-app-of-apps` and its
   `alarmengine` child got **stuck in `Terminating`**. ArgoCD refuses to auto-sync
   any app that is mid-deletion, so the ApplicationSet that owns voltex **cannot
   recreate a fresh `voltex-app-of-apps`** — that is why you see only the
   leftover app-of-apps + alarmengine. (A1)
2. **The reason it got stuck — and the reason it will keep getting stuck — is a
   chronically failing seed step on `alarmengine`.** alarmengine's post-deploy
   seeding call (`POST /api/alarmengine/v1/assets/seed`) has returned **HTTP 500
   since 2026-05-18**; that left a hook Job wedged with a finalizer, which is the
   pin in the deadlock. And your branch is in scope here: it deploys alarmengine
   image `0.153.feat.49017e3` plus a new 205-line `app_configuration.yaml` ("new
   TSO"). So clearing the deadlock will let voltex rebuild, but it will **not, by
   itself, guarantee a healthy FBE** — the 500 needs a separate look. (A1/A2)

---

## Context Ledger (zero-context reader first)

| Term | Definition | Code/artifact | Relevance here |
|------|------------|---------------|----------------|
| **FBE** | Feature Branch Environment — one of ~10 named, fixed-slot dev environments running a developer's branch in Sandbox AKS to test the VPP aggregation layer | slots: afi, boltz, ionix, ishtar, jupiter, kidu, operations, thor, veku, **voltex** | "voltex" is Stefan's FBE |
| **app-of-apps** | ArgoCD pattern: one parent `Application` that renders many child `Application`s | `voltex-app-of-apps` (Helm chart `Helm/vpp-core-app-of-apps` in repo `VPP-Configuration`) | The parent that should produce 22 children |
| **ApplicationSet** | ArgoCD controller that generates one app-of-apps per slot from a git file list | `vpp-feature-branch-environments`, generator = `VPP.GitOps/feature-branch-environments/*.yaml` | Owns `voltex-app-of-apps`; will recreate it |
| **child Application** | Per-service ArgoCD `Application` (alarmengine, frontend, monitor, asset, …) living in the slot namespace (`voltex`) | 22 per slot | Only `alarmengine` exists for voltex; 21 missing |
| **`resources-finalizer.argocd.argoproj.io`** | ArgoCD finalizer on an `Application`: "cascade-delete my managed k8s resources before you delete me" | on app-of-apps + alarmengine | The stuck pin of the deadlock |
| **`argocd.argoproj.io/hook-finalizer`** | Finalizer ArgoCD puts on hook resources (PreSync/PostSync Jobs) until the hook resolves | on `Job/seed-assets-alarmengine-postsync-1779187628` | The single object wedging alarmengine's cascade |
| **PostSync seed hook** | A Job that runs after a service syncs, POSTing seed data to the service's API | `seed-assets-alarmengine-postsync-*` (image `opstools:v2.1`) | Returns 500 → never resolves → finalizer never cleared |
| **TSO** | Transmission System Operator (energy grid operator); adding one is config/market work | `app_configuration.yaml`, vpp-domain package | Subject of Stefan's branch `feature/fbe-826335-update-appconfig-with-new-tso` |
| **SecretProviderClass** | CSI object that maps Key Vault secrets into pods | `secret-provider-kv` (per-slot KV, e.g. `vpp-fbe-voltex-tga`) | Missing in voltex (the `secretprovider` child isn't deployed) |

---

## L1 — Business — Why the FBE platform exists

The VPP (Virtual Power Plant) aggregation layer optimises and dispatches
distributed energy assets. Developers need to run **their own branch** end-to-end
against the aggregation layer before merge. FBEs are the fixed-slot Sandbox
environments that make that possible: each slot deploys one developer's branch as
a full mini-VPP (frontend, dispatchers, asset/telemetry services, alarmengine,
etc.). (A2, from intake: *"the sandbox … always the fbe are deployed, to test the
aggregation layer"*)

**Who is blocked:** Stefan — he cannot validate `feature/fbe-826335` ("new TSO")
because his voltex FBE is half-dead. No production or customer impact; this is a
developer-productivity incident. (A2)

## L2 — Repo system

| Repo | Role in this incident |
|------|----------------------|
| `VPP.GitOps` | ApplicationSet generator source — `feature-branch-environments/voltex.yaml` declares the voltex slot. **voltex.yaml present** (A1, local clone + live generator lists voltex). |
| `VPP-Configuration` | Holds `Helm/vpp-core-app-of-apps` (the app-of-apps chart) and per-service `Helm/<svc>/sandbox/values-override.yaml`. app-of-apps tracks Stefan's branch here. (A1) |
| `Myriad - VPP` | Service source + `Configuration/shared/sandbox/app_configuration.yaml` (the appconfig) + Helm charts (`azure-pipeline/Helm/<svc>`). (A1) |
| `Eneco.Vpp.Core.Dispatching` | vpp-domain package updated for the new TSO (PR 177675, active). (A1) |

Stefan's branch `feature/fbe-826335-update-appconfig-with-new-tso` exists in
**all three** of the first set (A1, `az repos ref list`). PRs: **177404** (Myriad
- VPP, *active*), **177674** (VPP-Configuration, **abandoned**), **177675**
(Dispatching, active). Note the VPP-Configuration PR is abandoned, but the
**branch still carries its commits**, and ArgoCD renders from the branch, not the
PR. (A1)

## L3 — Runtime architecture (the dual substrate + the deadlock)

```
ApplicationSet  vpp-feature-branch-environments   (owns one app-of-apps per slot)
        │  generator: VPP.GitOps/feature-branch-environments/voltex.yaml  (A1: present)
        ▼
Application  voltex-app-of-apps   (ns argocd, project vpp-core)
        │  source: VPP-Configuration  Helm/vpp-core-app-of-apps  @ feature/fbe-826335…
        ▼  renders 22 child Applications into ns voltex
 ┌──────────────── 22 children (afi healthy slot has all 20+; voltex has 1) ───────────────┐
 alarmengine  frontend  monitor  asset  dataprep  telemetry  dispatcher{afrr,mfrr,…}  …
        │
        ▼  each child syncs a Deployment/Service/Ingress, then runs a PostSync seed Job
 alarmengine: Service ✔  Deployment ✔  Ingress ✔  →  PostSync seed Job → POST /v1/assets/seed → HTTP 500 ✘
```

**The failure path (A1, controller logs):**

```
2026-06-03 13:14:51Z   ALL 22 voltex Applications get deletionTimestamp
                        (actor = ApplicationSet controller; trigger = A3, see L7)
   ├─ 21 children       → cascade completes → CRDs gone
   └─ alarmengine + app-of-apps → STUCK Terminating:
         alarmengine.finalizer waits on managed objects → Job seed-…-1779187628
             holds argocd.argoproj.io/hook-finalizer (stuck since 2026-05-19)  ◄── the pin
         app-of-apps.finalizer waits on 1 object = the alarmengine Application
   ▼
ArgoCD: "Skipping auto-sync: deletion in progress"  (looping, both apps)   ◄── enabling cause
   ▼
ApplicationSet wants voltex-app-of-apps to EXIST again, repeatedly logs
   "Deleted application voltex-app-of-apps" — cannot create a same-named object
   while the old one is Terminating  →  DEADLOCK  →  FBE half-dead
```

Live confirmation (A1):

```
$ kubectl -n argocd get application voltex-app-of-apps \
    -o jsonpath='{.metadata.deletionTimestamp} {.metadata.finalizers} {ownerRef}'
2026-06-03T13:14:51Z ["resources-finalizer.argocd.argoproj.io"] ApplicationSet/vpp-feature-branch-environments

$ kubectl -n argocd logs argocd-application-controller-0 --since=20m | grep "deletion in progress" | grep voltex
… "voltex/alarmengine"        "Skipping auto-sync: deletion in progress"
… "argocd/voltex-app-of-apps" "Skipping auto-sync: deletion in progress"

$ kubectl get applications -A -o json | jq '[.items[]|select(.metadata.namespace=="voltex").metadata.name]'
["alarmengine"]          # afi slot, by contrast, lists all 20
```

A **second, independent control plane** — `fbe-voltex-monitoring` (separate
ApplicationSet, ns `voltex-monitoring`) — is **Synced/Healthy and unaffected**.
It must stay out of scope of any fix. (A1, sre-maniac)

## L4 — Application code flow (why the seed 500 matters)

After alarmengine's Deployment syncs, ArgoCD runs the PostSync hook
`seed-assets-alarmengine-postsync` (image `opstools:v2.1`). Its script (A1, live
Job spec) does:

```powershell
POST http://alarmengine:8080/api/alarmengine/v1/assets/seed   (header x-apikey: $ENV:seeding_api_key)
# on non-2xx: throw "Status code did not indicate success."
```

Live pod log (A1): `StatusCode: 500` → `BackoffLimitExceeded`. The hook has a
`hook-delete-policy: BeforeHookCreation`, so a failed Job is **left in place**.
When the app is later deleted, ArgoCD must strip each hook Job's
`hook-finalizer`; for a Job that never succeeded during an in-flight delete, that
strip wedged — producing the pin in L3. (A1 for the 500 and the stuck finalizer;
A2 for the wedge mechanism.)

**Why 500, root cause = bounded, not fully pinned (A3[blocked: alarmengine pods
already torn down — no live logs]):**
- voltex runs alarmengine image **`0.153.feat.49017e3`** (Stefan's branch) vs
  main's `0.117.dev.93afed2`. (A1, `az devops` values-override diff)
- His branch also adds a **205-line `app_configuration.yaml`** ("new TSO") that
  **does not exist on `main`** (A1, `TF401174 … not found at main`).
- **Discriminator:** the healthy slot `afi` *also* runs a `0.153.feat` build
  (commit `b968212`) and its seed Job is **Complete** (A1). So the cause is **not
  "feature build vs stable"** — it is something specific to voltex's branch
  content (commit `49017e3` + the new-TSO appconfig) **and/or** a missing secret
  mount (next bullet). (A2)
- voltex is **missing the `secret-provider-kv` SecretProviderClass** that afi has
  — but that is deployed by the per-slot `secretprovider` child Application, which
  is one of the 21 **not materialised** (deadlock symptom). So a fresh voltex
  alarmengine currently `FailedMount`s its Key Vault secrets, which on its own can
  produce a 500. (A1 missing SPC; A2 that it can cause the 500)

**Net:** the 500's root is one of {Stefan's TSO appconfig/build, missing KV
secret mount}, currently entangled. **Resolving probe:** after the deadlock is
cleared and alarmengine redeploys *with* its secrets, capture the alarmengine pod
log at the moment the seed POSTs. 500 with secrets present ⇒ branch content; clean
seed ⇒ the 500 was the missing-secret/deadlock artifact. (named A3 resolver)

## L5 — IaC / state / Azure — the three truths

- **Declared (GitOps):** `VPP.GitOps/feature-branch-environments/voltex.yaml`
  present → ApplicationSet *wants* voltex. (A1)
- **ArgoCD desired:** app-of-apps renders 22 children; ApplicationSet conditions
  `ErrorOccurred=False / ParametersGenerated=True / ResourcesUpToDate=True` — **no
  render or credential error.** (A1) This is why "the branch broke the render" is
  **refuted** (sherlock alt-a/b/c REFUTED).
- **Live cloud/cluster:** ns voltex has 1 child CRD, 0 service Deployments, zombie
  frontend/monitor pods, alarmengine Deployment already gone. (A1) The gap between
  desired (22) and live (≈0) is the deadlock, **not** a spec defect.

## L6 — The pipeline and how it actually runs

The "FBE Creator" run (ADO buildId 1668061) reported success because the FBE
create pipeline tolerates downstream state and its **Pester infra test merely
observed** the broken cluster — it did not cause it. The Pester output in the
intake (alarmengine Running; frontend/monitor `Succeeded`; FrontEnd 404) is a
**faithful snapshot of the deadlocked half-state**, not a pipeline fault. Trusting
"pipeline green ⇒ FBE healthy" is the trap (skill H-STAGE-1). (A2)

## L7 — Timeline

| When (UTC) | Event | Label |
|------------|-------|-------|
| 2025-12-12 | voltex namespace created (long-lived slot) | A1 |
| 2026-05-13 | current app-of-apps + alarmengine objects created | A1 |
| **2026-05-18** | frontend & monitor pods get deletionTimestamp (workloads pruned); **alarmengine seed starts returning 500** | A1 |
| 2026-05-19 10:47 | last *successful* app-of-apps sync (all 22 children "configured") | A1 |
| 2026-05-19 10:52 | `seed-…-1779187628` Job gets deletionTimestamp but keeps its `hook-finalizer` → wedged | A1 |
| **2026-06-03 13:14:51** | **all 22 voltex Applications issued delete**; 21 cascade away, app-of-apps + alarmengine stick | A1 |
| 2026-06-03 ~ | "recreation" / create pipeline 1668061 runs; Pester captures half-state | A1 (Pester) |
| 2026-06-04 | ApplicationSet loops "Deleted application voltex-app-of-apps", cannot recreate (deadlock); investigation | A1 |

**Actor of the 13:14:51 delete = ApplicationSet controller** (A2: ownerRef +
applicationset-controller delete-loop log + managedFields show only argocd
controllers, no human/pipeline manager). **Precise trigger** (a transient
generator drop of voltex.yaml vs a destroy-pipeline `argocd app delete`) is
**A3[blocked: surviving managedFields retain only last-update times; controller
log window doesn't reach 06-03]** — and the fix does not depend on it.

## L8 — Fix

See **`fix.md`** for the executable, gated runbook. Summary — **two tracks**:

- **Track 1 (unblock recreation) — verified safe, voltex-scoped:**
  1. Strip the stuck `hook-finalizer` from `Job/seed-assets-alarmengine-postsync-1779187628`.
  2. Force-delete the zombie `frontend`/`monitor` pods (hygiene; **not** the cascade unblock).
  3. Watch the cascade drain → alarmengine + app-of-apps disappear → **ApplicationSet auto-recreates voltex** (no pipeline rerun; O3 empirically confirmed). (A1, sre-maniac)
  4. *Last resort, gated:* force-remove `resources-finalizer` from alarmengine then app-of-apps if the cascade is still stuck >5 min.
- **Track 2 (make the rebuild actually healthy) — required for "back to live":**
  5. After recreate, capture the alarmengine pod log at seed time to pin the 500
     (branch content vs missing-secret). Fix accordingly (Stefan's TSO
     appconfig/build, or the secret wiring).

**Necessary-but-not-sufficient is the headline:** Track 1 alone gives Stefan a
voltex that *exists and rebuilds*, but the same seed-500 will likely recur (and
can re-wedge the next teardown) until Track 2 is done. (A1/A2, convergent
sre-maniac O5 + socrates Q3.)

**Do NOT** (skill anti-patterns + sre-maniac): run destroy pipeline 2629 as
rollback; `argocd app delete --cascade` (apps already mid-delete; can't reach the
k8s Job finalizer); use label-selectors / `--all` / wrong namespace; touch
`voltex-monitoring` or `kps-voltex-*` cluster objects.

## L9 — Verification (how we'll know it worked)

| Check | Command | Pass condition |
|-------|---------|----------------|
| Deadlock cleared | `kubectl -n argocd get application voltex-app-of-apps` | old object gone, then **new** object with creationTimestamp after the fix |
| Children materialise | `kubectl -n voltex get applications` | ~20+ child Applications appear, syncing |
| alarmengine healthy | `kubectl -n voltex get deploy alarmengine; kubectl get endpoints alarmengine` | Deployment Available, ≥1 endpoint |
| Seed succeeds | `kubectl -n voltex logs <newest seed-assets-alarmengine pod>` | `StatusCode: 2xx` (not 500) |
| Frontend up | Pester `[FrontEnd] should get 200` / `curl` the frontend ingress | HTTP 200 |
| No re-wedge | `kubectl -n voltex get jobs -o custom-columns=NAME:.metadata.name,FIN:.metadata.finalizers` | no Job stuck with `hook-finalizer` |

Frontend 404→200 is **not guaranteed by recreation alone** (A3: frontend child
not materialised, couldn't pre-probe; may carry its own seed dependency).

## L10 — Lessons

1. **"Skipping auto-sync: deletion in progress" is the fingerprint of an ArgoCD
   finalizer deadlock.** A half-deployed slot with only leftover apps + a parent
   stuck `OutOfSync/Progressing` and **no error conditions** is usually a stuck
   *deletion*, not a render/credential failure. Check `deletionTimestamp` +
   finalizers before blaming the branch. (A1)
2. **app-of-apps `.status.resources` shows DESIRED, not LIVE.** It listed 22
   children while only 1 CRD existed. Cross-check with `kubectl get applications
   -A` filtered to the slot namespace. (A1)
3. **A chronically failing PostSync hook is a latent deadlock generator.** With
   `hook-delete-policy: BeforeHookCreation`, a never-succeeding hook Job can wedge
   a future teardown's finalizer. Failing seed hooks should alert, not rot. (A2)
4. **"ApplicationSet generates params" ≠ "the branch's content is deployable."**
   Render success says nothing about runtime health (seed 2xx, secret mounts).
   Don't dismiss a developer's "I think I broke my branch" with a generator check.
   (lesson from the adversarial pass; my first draft over-claimed "branch
   disproven")
5. **The diagnostic window closes during teardown.** alarmengine pods were gone by
   mid-investigation, blocking the 500 root-cause probe. Capture service logs
   *before* or *during* recreate, not after. (A1)

## L11 — End-to-end command playbook (cold reproduce)

```bash
# 0. Context (Sandbox is not VNET-integrated; no whitelist toggle needed)
az account show --query id -o tsv          # 7b1ba02e-bac6-4c45-83a0-7f0d3104922e
kubectl config use-context vpp-aks01-d
export ARGOCD_NAMESPACE=argocd

# 1. The smoking gun: stuck deletion + auto-sync skip
kubectl -n argocd get application voltex-app-of-apps \
  -o jsonpath='{.metadata.deletionTimestamp}{"\n"}{.metadata.finalizers}{"\n"}'
kubectl -n argocd logs argocd-application-controller-0 --since=20m \
  | grep -E 'voltex' | grep -E 'deletion in progress|objects remaining'

# 2. Only 1 child exists vs a healthy slot
kubectl get applications -A -o json \
  | jq -r '.items[]|select(.metadata.namespace=="voltex").metadata.name'   # ["alarmengine"]
kubectl get applications -n afi --no-headers | wc -l                       # ~20

# 3. The pin: the hook Job holding hook-finalizer
kubectl -n voltex get jobs -o custom-columns='NAME:.metadata.name,DEL:.metadata.deletionTimestamp,FIN:.metadata.finalizers' \
  | grep hook-finalizer

# 4. The recurrence generator: seed 500
kubectl -n voltex logs <seed-assets-alarmengine-postsync pod> | grep -E 'base url|StatusCode'

# 5. ApplicationSet still wants voltex (recreation will fire)
kubectl -n argocd get applicationset vpp-feature-branch-environments \
  -o jsonpath='{range .status.resources[*]}{.name}{"\n"}{end}' | grep voltex-app-of-apps

# 6. Branch content (why the 500 may be branch-related)
az repos pr list --org https://dev.azure.com/enecomanagedcloud --project "Myriad - VPP" \
  --source-branch feature/fbe-826335-update-appconfig-with-new-tso --status all -o table
az devops invoke --org https://dev.azure.com/enecomanagedcloud --area git --resource items \
  --route-parameters project="Myriad - VPP" repositoryId="VPP-Configuration" \
  --query-parameters path="/Helm/alarmengine/sandbox/values-override.yaml" \
  versionDescriptor.version="feature/fbe-826335-update-appconfig-with-new-tso" \
  versionDescriptor.versionType=branch includeContent=true --api-version 7.1 --query content -o tsv
```

## L12 — One-page on-call playbook (next shift, 5-minute triage)

> **Symptom:** "FBE recreation succeeded but I only see app-of-apps + one service;
> frontend 404; Pester red."
>
> 1. `kubectl -n argocd logs argocd-application-controller-0 --since=20m | grep -E '<slot>' | grep 'deletion in progress'`
>    → if present, it's a **finalizer deadlock**, not a branch/render bug. Stop blaming the branch.
> 2. `kubectl get application <slot>-app-of-apps -n argocd -o jsonpath='{.metadata.deletionTimestamp}'`
>    → non-empty ⇒ stuck Terminating.
> 3. `kubectl -n <slot> get jobs ... | grep hook-finalizer` → find the wedged hook Job.
> 4. **Unblock:** `kubectl -n <slot> patch job <hook-job> --type=merge -p '{"metadata":{"finalizers":[]}}'`; force-delete zombie pods; watch "objects remaining" drain; ApplicationSet auto-recreates. (gated last resort: strip `resources-finalizer` child-then-parent)
> 5. **Then check health:** seed Job `StatusCode` and frontend 200. If seed 500s, capture the service pod log → it's the branch's image/appconfig or a missing KV secret mount. That is **Track 2**, and it's the part that actually gets the FBE "back to live."
> 6. **Never** run destroy 2629 as rollback; **never** use `--all`/label-selectors; **never** touch `<slot>-monitoring`.
