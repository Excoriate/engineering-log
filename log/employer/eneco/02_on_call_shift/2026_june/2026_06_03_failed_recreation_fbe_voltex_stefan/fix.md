# Fix — voltex FBE "failed recreation"

> **Decision aid.** This is what I would run. You can apply it yourself, or authorise me.
> Track 1 is the safe unblock; the only destructive step (Step 4) is gated. Track 2 is
> required to actually get the FBE "back to live". All commands are **voltex-scoped** —
> every command carries `-n voltex` (or `-n argocd`) and a **literal object name**; never
> use `-l`/label-selectors/`--all` (that is the only way to escape the blast radius).
>
> **Context preamble (run once):**
> ```bash
> az account show --query id -o tsv          # expect 7b1ba02e-bac6-4c45-83a0-7f0d3104922e (Sandbox)
> kubectl config use-context vpp-aks01-d
> export ARGOCD_NAMESPACE=argocd
> ```
> Sandbox is **not** VNET-integrated, so there is **no whitelisting to turn off** afterwards.

---

## What we are fixing, in one line

`voltex-app-of-apps` + `alarmengine` are stuck `Terminating` on ArgoCD finalizers;
ArgoCD won't auto-sync mid-deletion, so the ApplicationSet can't recreate voltex.
**Clear the pin → the cascade completes → the ApplicationSet rebuilds voltex automatically.**
Then fix the alarmengine seed-500 so the rebuild is actually healthy.

---

## Pre-flight — abort gate (run first; do NOT proceed if it fails)

The recreation only happens automatically if the ApplicationSet still wants voltex.
Confirm that **before** touching any finalizer:

```bash
kubectl -n argocd get applicationset vpp-feature-branch-environments \
  -o jsonpath='{range .status.resources[*]}{.name}{"\n"}{end}' | grep -x voltex-app-of-apps \
  && echo "OK: ApplicationSet still wants voltex — auto-recreate will fire" \
  || echo "ABORT: voltex no longer generated — do NOT clear finalizers; re-run the FBE create pipeline instead"
```

Also snapshot the blocker so you can prove the fix worked:

```bash
kubectl -n argocd get application voltex-app-of-apps \
  -o jsonpath='delTS={.metadata.deletionTimestamp} created={.metadata.creationTimestamp}{"\n"}'
kubectl -n voltex get jobs -o custom-columns='NAME:.metadata.name,DEL:.metadata.deletionTimestamp,FIN:.metadata.finalizers' | grep hook-finalizer
```

---

## TRACK 1 — Unblock recreation (verified safe)

### Step 1 — Strip the stuck hook-finalizer (minimal, scoped, non-destructive)

This is the actual pin. The Job has **no live pods**, so stripping its finalizer just
lets the empty Job object delete; nothing is force-killed. (Verified: only this one Job
carries `hook-finalizer`; the other two seed Jobs delete cleanly.)

```bash
kubectl -n voltex patch job seed-assets-alarmengine-postsync-1779187628 \
  --type=merge -p '{"metadata":{"finalizers":[]}}'
```

**Verify:**
```bash
kubectl -n voltex get job seed-assets-alarmengine-postsync-1779187628   # → NotFound
```
**Stop-condition:** if the Job is still present after ~30s, do NOT jump to Step 4 —
investigate (admission webhook / CRD re-adding the finalizer).

### Step 2 — Clear node-orphaned zombie pods (hygiene; NOT the cascade unblock)

These `frontend`/`monitor` pods have **no finalizers** and their owning ReplicaSets are
gone — they don't block the cascade, but they're stale and should go.

```bash
kubectl -n voltex delete pod frontend-8556c9dffd-7t9w5 monitor-5b45c988c5-sr45x \
  --grace-period=0 --force
```
> Pod names may differ by the time you run this — re-list with
> `kubectl -n voltex get pods | grep -E 'frontend|monitor'` and use the actual names.

### Step 3 — Watch the cascade drain (the real success signal)

```bash
# macOS: `watch` may need `brew install watch`; otherwise loop with sleep
watch -n5 'kubectl -n argocd logs argocd-application-controller-0 --tail=60 \
  | grep -E "voltex/alarmengine|voltex-app-of-apps" | grep "remaining for deletion" | tail -4'
```

**Expect:** alarmengine `"5 objects remaining"` → counts down → alarmengine CR gone;
then app-of-apps `"1 objects remaining"` → app-of-apps CR gone.

**Verify the unblock + auto-recreate:**
```bash
kubectl -n voltex get application alarmengine               # → NotFound (old one)
kubectl -n argocd get application voltex-app-of-apps \
  -o jsonpath='{.metadata.creationTimestamp}{"\n"}'         # → a NEW timestamp (after your fix)
kubectl -n voltex get applications                          # → ~20+ children materialising
```

**Stop-condition:** if `"objects remaining"` does **not** decrease within **5 minutes**
after Steps 1–2, the blocker is not the Job. Enumerate what's left and find the next
finalizer before considering Step 4:
```bash
kubectl -n voltex get application alarmengine -o json | jq '.status.resources'
```

### Step 4 — LAST RESORT ONLY (gated, destructive — no rollback)

Only if Steps 1–3 are done **and** the remaining-object count is stuck **>5 min** **and**
you've found no other k8s finalizer to clear. Force-remove ArgoCD's
`resources-finalizer` — **child first, then parent, never the reverse**:

```bash
kubectl -n voltex  patch application alarmengine        --type=merge -p '{"metadata":{"finalizers":[]}}'
# confirm alarmengine CR gone + app-of-apps "objects remaining" → 0, THEN:
kubectl -n argocd  patch application voltex-app-of-apps --type=merge -p '{"metadata":{"finalizers":[]}}'
```

**Why gated:** this deletes the Application CR immediately and leaves its k8s objects
orphaned (the finalizer existed precisely to clean them up). On recreate, ArgoCD adopts
the orphans **by tracking-id annotation** (not ownerReference) — normally benign, but if
objects are half-deleted you can hit immutable-field conflicts (Service `clusterIP`,
Deployment selector). If that happens: delete the conflicting object and let the fresh
sync recreate it. **There is no undo for finalizer removal.**

### Step 5 — Confirm auto-recreation (expected; no pipeline rerun)

```bash
kubectl -n argocd get application voltex-app-of-apps -o jsonpath='{.metadata.creationTimestamp}{"\n"}'
kubectl -n voltex get applications
```
**Fallback** (only if the pre-flight gate aborted, or no recreate within ~5 min): re-run
the ADO **FBE create pipeline** (the one in the intake). Do **not** `kubectl create` the
app-of-apps by hand, and do **not** run the destroy pipeline 2629 as a rollback.

---

## TRACK 2 — Make the rebuild actually healthy (required for "back to live")

Track 1 gives you a voltex that **exists and rebuilds**. It does **not** guarantee the
seed succeeds or the frontend returns 200 — the alarmengine seed has 500'd since
2026-05-18, and that same failure can re-wedge the next teardown.

### Step 6 — Pin the seed-500 root cause (the decision-flipping probe)

Right after the rebuild, while alarmengine is up, capture its log at seed time:

```bash
kubectl -n voltex get pods | grep -E 'alarmengine|seed-assets-alarmengine'
kubectl -n voltex logs deploy/alarmengine --tail=200        # the API side of the 500
kubectl -n voltex logs <newest seed-assets-alarmengine pod> # the seed side (StatusCode)
# also confirm secrets now mount (the secretprovider child should be back):
kubectl -n voltex get secretproviderclass                   # expect secret-provider-kv present
kubectl -n voltex describe pod <alarmengine pod> | grep -iE 'mount|secret|FailedMount'
```

**Decision rule:**
- **Seed returns 2xx now** → the 500 was the missing-secret / deadlock artifact; FBE is
  healthy; you're done.
- **alarmengine `FailedMount secret-provider-kv`** → the `secretprovider` child hasn't
  synced; let it reconcile or sync it; re-check.
- **Seed still 500 with secrets mounted** → it's **your branch content**. Your branch
  deploys alarmengine `0.153.feat.49017e3` + the new-TSO `app_configuration.yaml`
  (absent on main). Read the alarmengine exception in the log above and check your
  `app_configuration.yaml` / TSO data and the alarmengine build. (afi runs a different
  `0.153.feat` commit and seeds clean — so it is specific to your commit/appconfig, not
  feature-builds in general.)

### Step 7 — Verify the FBE is truly live

```bash
kubectl -n voltex get deploy                                # frontend, monitor, etc. Available
kubectl -n voltex get endpoints frontend                   # ≥1 endpoint
# then re-run the Pester infra test (or curl the frontend ingress) → [FrontEnd] should get 200
```

---

## Authorisation checklist (for you, before you say "go")

| Question | Answer it with | Default if unsure |
|----------|----------------|-------------------|
| Is voltex still wanted by the ApplicationSet? | the pre-flight gate | abort & rerun create pipeline |
| Am I OK force-removing a finalizer (Step 4) with no undo? | only after Steps 1–3 stall | don't; escalate |
| Do I accept Track 1 alone may leave the FBE red? | yes — Track 2 is the real fix | plan Track 2 |
| Is my branch possibly the seed-500 cause? | Step 6 decision rule | assume yes; have the log ready |

**Recommendation:** apply **Track 1 Steps 1–3** (safe, reversible-by-recreate) to unblock,
then run **Step 6** to learn whether your branch needs a fix before declaring victory.
Hold Step 4 unless the cascade genuinely stalls.
