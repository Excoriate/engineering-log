---
task_id: 2026-06-02-004
agent: claude-opus-4-8
status: complete
summary: "Fix for telemetryfunctiontestsfn 404 on agg.dev — add nginx rewrite-target to the prefix-mounted ingress (chart values), with verification, rollback, and a consolidation alternative."
---

# Fix — `telemetryfunctiontestsfn/healthz` 404 on `agg.dev.vpp.eneco.com`

## What is wrong (one line)

The nginx ingress mounts the Azure-Functions backend under the path prefix `/telemetryfunctiontestsfn/` with
**no `rewrite-target`**, so the unstripped path reaches an app that serves `/healthz` at root → **404**.

## What is NOT wrong (do not chase these)

- ❌ Network / AVD whitelist / VNET / Private Endpoint — the host is **public** and reachable; a sibling path is 200.
- ❌ WAF / App Gateway — pass-through; returns 404 not 403.
- ❌ The function / pod — healthy (1/1 Running, endpoint present, `/healthz`=200 at backend root).
- ❌ Image version — re-syncing the image tag does not change ingress routing.

---

## Immediate unblock for the reporter (today, no PR)

There is currently **no working edge path** (both `/telemetryfunctiontestsfn/healthz` and the documented bare
prefix 404). Until the PR lands, reach the host directly (needs `kubectl` to AKS `vpp-aks01-d`, which AVD devs have):

```bash
kubectl -n vpp-agg port-forward svc/telemetryfunctiontestsfn 8080:8080
curl http://localhost:8080/healthz        # -> 200 Healthy  (confirms the test-function host is alive)
```

Scope note (verified): this Functions host exposes **only `/healthz`** over HTTP — `/api/*`→404, `/admin/*`→401.
The `*fn` are **timer/Kafka-triggered QA test functions** (ADR AL006), not HTTP-invoked, so `/healthz` reachability
*is* the goal. There is no `/api/<fn>` to call over the edge.

---

## Fix Option A (recommended PERMANENT fix) — add the nginx rewrite

`agg.dev` is actively maintained (live chart `0.1.27`) and is the public endpoint developers use from AVD, so
fixing it directly is the right permanent unblock.

### The change (raise a PR)

Repo: `Eneco.Vpp.Aggregation`
File: `azure-pipeline/Helm/telemetryfunctiontestsfn/values.yaml`
(Apply the **same** change to `azure-pipeline/Helm/deliveryreportfn/values.yaml` and any other prefix-mounted `*fn`.)

```diff
 ingress:
   enabled: true
   className: nginx
   hostname: agg.dev.vpp.eneco.com
-  path: /telemetryfunctiontestsfn/
+  path: /telemetryfunctiontestsfn(/|$)(.*)
   annotations:
+    nginx.ingress.kubernetes.io/use-regex: "true"
+    nginx.ingress.kubernetes.io/rewrite-target: /$2
```

What it does: nginx captures everything after the prefix into `$2` and forwards `/$2` to the backend, so
`/telemetryfunctiontestsfn/healthz` → backend `/healthz` (already returns 200). This **restores `/healthz`
reachability** — the reporter's goal. It does not create function HTTP endpoints (the host exposes none:
`/api/*`→404, `/admin/*`→401); the test functions are triggered by timer/Kafka, not HTTP.

### Pre-merge checks

1. **Confirm the live release values first** (the deployed values are what matter):
   ```bash
   SEC=$(kubectl -n vpp-agg get secret -l owner=helm,name=telemetryfunctiontestsfn --sort-by=.metadata.name -o name | tail -1)
   kubectl -n vpp-agg get "$SEC" -o jsonpath='{.data.release}' | base64 -d | base64 -d | gunzip \
     | jq '{chart: .chart.metadata.version, ingress: .chart.values.ingress, overrides: .config}'
   # expect chart 0.1.27, ingress.className=nginx, annotations:{}
   ```
2. The chart template hard-codes `pathType: Prefix` (`templates/ingress.yaml`). `use-regex: "true"` makes nginx
   honour the regex anyway; for cleanliness optionally set `pathType: ImplementationSpecific` (one-line template change).
3. Render and eyeball the manifest for nginx-ingress **v1.14.0** before merge.
4. Verify the new prefix rule does not shadow the `/` siteregistry catch-all (it will not — longer prefix wins).

### Deploy

Through the normal pipeline (ADO `HelmDeploy@0` for `vpp-agg`). **Do not** `kubectl edit` the live ingress —
it is Helm/pipeline-managed and a manual edit will drift / be overwritten.

---

## Fix Option B (recommended if consolidating environments) — use the canonical OpenShift path

The modern GitOps/ArgoCD deployment on **OpenShift** (`agg.dev-mc.vpp.eneco.com`, ns `eneco-vpp-agg`) already has
a correct prefix-strip:
`Eneco.Vpp.Aggregation.GitOps/Helm/telemetryfunctiontestsfn/dev/values.yaml` →
`route.annotations.haproxy.router.openshift.io/rewrite-target: /`.

Point consumers at `agg.dev-mc`. Cost: it is **internal-only** (resolves NXDOMAIN publicly), so the AVD must be
whitelisted — follow the ServiceNow whitelist runbook (Eneco wiki page **44740**). This removes the two-era
divergence rather than maintaining two ingress definitions.

---

## Verification (acceptance criteria)

```bash
# AFTER fix — must be 200 (this is the acceptance criterion; A2 expectation until deployed+re-probed)
curl -s -o /dev/null -w '%{http_code}\n' https://agg.dev.vpp.eneco.com/telemetryfunctiontestsfn/healthz   # expect 200
# Regression guard — siteregistry must stay 200
curl -s -o /dev/null -w '%{http_code}\n' https://agg.dev.vpp.eneco.com/api/siteregistry                    # expect 200
# NOTE: do NOT expect /telemetryfunctiontestsfn/api/<fn> to work — the host exposes no HTTP functions
# (/api/*=404, /admin/*=401 at the backend). /healthz is the only meaningful HTTP surface.
```

Proof the fix is sound *before* deploying (backend already serves the target path):

```bash
kubectl -n vpp-agg port-forward svc/telemetryfunctiontestsfn 18080:8080 &
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:18080/healthz   # 200  → rewrite to /healthz yields 200
kill %1
```

## Rollback

Revert the values.yaml PR (remove `use-regex`/`rewrite-target`, restore `path: /telemetryfunctiontestsfn/`) and
redeploy. Risk is contained to this one ingress; no data, no shared infra, no other service touched. R = trivial.

## Sign-off checklist for the reporter (Johnson Lobo)

- [ ] PR adds `use-regex` + `rewrite-target` + regex path to `telemetryfunctiontestsfn` (and `deliveryreportfn`).
- [ ] `…/telemetryfunctiontestsfn/healthz` returns 200 from AVD.
- [ ] `…/api/siteregistry` still 200.
- [ ] FAQ updated with the general pattern (prefix-mounted `*fn` need the nginx rewrite).
