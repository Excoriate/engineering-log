---
task_id: 2026-06-22-009
agent: claude-opus-4-8
status: complete
summary: "Fix for telemetryfunctiontestsfn 404 on agg.dev — add nginx use-regex + rewrite-target to the chart ingress values. Fix proven live this session (test ingress -> public 200). Immediate port-forward unblock + permanent chart PR, each with a witnessable effect check, rollback, and sign-off."
---

# How to fix — `telemetryfunctiontestsfn/healthz` 404 on `agg.dev.vpp.eneco.com`

> **Every step below is closed by an observed EFFECT (an HTTP status or a decoded value), never by "the command exited 0."**
> The permanent fix was **proven live** this session: a throwaway test ingress with the exact annotations returned `200` through the public edge ([`evidence/08-live-rewrite-proof.txt`](./evidence/08-live-rewrite-proof.txt)), then was deleted.

---

## The one line

The nginx ingress mounts the Azure-Functions backend under the path prefix `/telemetryfunctiontestsfn/` with **no `rewrite-target`**, so the unstripped path reaches an app that serves `/healthz` at root → **404**. Add the nginx rewrite to the chart values.

## What is NOT the problem — do not chase these

- ❌ **Network / AVD whitelist / VNET / Private Endpoint** — the host is public and reachable; a sibling path (`/api/siteregistry`) returns `200`. (Verified: `evidence/01`.)
- ❌ **WAF / App Gateway** — pass-through, `urlPathMaps: []`; it returns `404`, not `403`. (Verified: `evidence/07`.)
- ❌ **The function / pod** — healthy: `1/1 Running`, endpoint present, `/healthz`=`200` at the backend root. (Verified: `evidence/03`, `evidence/06`.)
- ❌ **Image version** — re-syncing or rebuilding the image does not change ingress routing. (The image was already rebuilt `1457`→`1479`; still 404.)

---

## Pre-flight (run once — confirm you are on the right cluster)

```bash
kubectl config current-context        # MUST print: vpp-aks01-d
az account show --query name -o tsv   # MUST print the Sandbox-Development-Test subscription
```

**Effect check:** if either line is wrong, STOP — you are pointed at the wrong cluster/subscription. Do not proceed. (No whitelist toggle is needed for the public `agg.dev` or for read-only Sandbox access.)

---

## Tier 1 — Immediate unblock TODAY (no PR, ~2 minutes)

Use this to unblock Anasthasia's e2e run while the chart PR is in review. It needs `kubectl` access to AKS `vpp-aks01-d`, which AVD developers have.

```bash
kubectl -n vpp-agg port-forward svc/telemetryfunctiontestsfn 8080:8080
# in another shell / browser:
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/healthz
```

**Effect check (the success signal):** the curl prints **`200`**, and `curl http://localhost:8080/healthz` shows the body **`Healthy`**. That proves the test-function host is alive.

**Does this unblock the e2e test?**
- If the e2e harness lets you set a base URL → point it at `http://localhost:8080` and it will pass its `/healthz` liveness gate.
- If the harness is hard-wired to `https://agg.dev.vpp.eneco.com/telemetryfunctiontestsfn/healthz` → Tier 1 cannot satisfy it; you need Tier 2 deployed. (Telemetry's host exposes only `/healthz` over HTTP among the paths probed — `/api/*`=404, `/admin/*`=401 — so there is nothing else to call.)

---

## Tier 2 — Permanent fix (the real fix) — add the nginx rewrite to the chart values

This is the durable fix. It is a purely **additive** 3-line change to one file (the chart already uses `className: nginx` with empty annotations).

### Mechanism it changes

It tells nginx to **strip the path prefix before forwarding**: capture everything after `/telemetryfunctiontestsfn/` into `$2`, forward `/$2` to the backend. So `/telemetryfunctiontestsfn/healthz` → backend `/healthz` → `200`. (State plane closed: the **edge routing rule**. It does not touch the app, the image, or the network. One incidental effect: the bare-prefix request `…/telemetryfunctiontestsfn` — today a `301`→`http://` plaintext-downgrade redirect — becomes a `200` root banner, which is an improvement; see RCA L10.)

### The change (raise a PR) — TWO files

> **This is a two-file change, not values-only.** The chart template **hard-codes `pathType: Prefix`** (confirmed on the `development` branch, `evidence/11`), and nginx-ingress **rejects a regex path under `pathType: Prefix`** at admission time — I proved this live this session: `kubectl apply` of the exact `Prefix`+regex shape was denied with `path /tf-prefix-proof(/|$)(.*) cannot be used with pathType Prefix` (`evidence/09`). The standalone config that DID return a public `200` used `pathType: ImplementationSpecific` (`evidence/08`). So `pathType` **must** change, and only the template sets it.

**Repo:** `Eneco.Vpp.Aggregation`

**File 1 — `azure-pipeline/Helm/telemetryfunctiontestsfn/values.yaml`** (add the annotations + make the path a regex):

```diff
 ingress:
   enabled: true
   className: nginx
   hostname: agg.dev.vpp.eneco.com
-  path: /telemetryfunctiontestsfn/
-  annotations: {}
+  path: /telemetryfunctiontestsfn(/|$)(.*)
+  annotations:
+    nginx.ingress.kubernetes.io/use-regex: "true"
+    nginx.ingress.kubernetes.io/rewrite-target: /$2
```

**File 2 — `azure-pipeline/Helm/telemetryfunctiontestsfn/templates/ingress.yaml`** (the template emits `pathType: Prefix` literally — change it):

```diff
               - path: {{ .Values.ingress.path }}
-                pathType: Prefix
+                pathType: ImplementationSpecific
```

**For `deliveryreportfn` and other prefix-mounted `*fn`:** apply the **same two-file rewrite**, but mind the health path — `deliveryreportfn`'s backend returns `200` at `/` but **`404` at `/healthz`** (proven, `evidence/10`); it has no `/healthz` route. So after the rewrite, `…/deliveryreportfn/` returns `200` (the host banner = liveness), while `…/deliveryreportfn/healthz` will still `404` from the backend itself. Use `/deliveryreportfn/` for its liveness check, not `/healthz`.

### Pre-merge checks

1. **Confirm the live deployed values first** (the deployed render is what matters, not the clone):
   ```bash
   SEC=$(kubectl -n vpp-agg get secret -l owner=helm,name=telemetryfunctiontestsfn --sort-by=.metadata.name -o name | tail -1)
   kubectl -n vpp-agg get "$SEC" -o jsonpath='{.data.release}' | base64 -d | base64 -d | gunzip \
     | jq '{chart: .chart.metadata.version, ingress: .chart.values.ingress, overrides: .config}'
   ```
   **Effect check:** you should see `chart 0.1.28`, `ingress.className: nginx`, `ingress.annotations: {}`. That confirms the change is additive (no existing annotation to clobber).
2. **The `pathType` template change is MANDATORY** — `use-regex: "true"` does NOT rescue `pathType: Prefix`; the admission webhook rejects the regex path before nginx ever evaluates it (`evidence/09`). It must be `ImplementationSpecific`.
3. It will **not** shadow the `/` siteregistry catch-all — confirmed live: the `ImplementationSpecific`+`use-regex` ingress coexisted with the `/` catch-all and siteregistry stayed `200` (`evidence/08`). Keep the post-deploy regression guard as a hard gate.
4. Render the manifest against nginx-ingress **v1.14.0** before merge.

### Deploy

Through the normal ADO pipeline (`HelmDeploy@0` for `vpp-agg`). **Do NOT `kubectl edit` the live ingress** — it is Helm/pipeline-managed and a manual edit drifts and is overwritten by the next deploy (this is exactly how the bug survived ~15 redeploys).

---

## Verification (acceptance criteria)

### Already witnessed this session (the fix is proven sound BEFORE you merge)

```bash
# backend already serves the target at root:
kubectl -n vpp-agg port-forward svc/telemetryfunctiontestsfn 18080:8080 &
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:18080/healthz   # 200
kill %1
```
And the live rewrite proof: a test ingress with `use-regex`+`rewrite-target:/$2` made `https://agg.dev.vpp.eneco.com/tf-rewrite-proof/healthz` return **`200`** ([`evidence/08`](./evidence/08-live-rewrite-proof.txt)). That proof used `pathType: ImplementationSpecific` — **exactly the shape File 2 ships** — and the `Prefix` shape was separately proven to be rejected by the admission webhook ([`evidence/09`](./evidence/09-prefix-regex-proof.txt)). So the deployed two-file change produces the identical `200`.

### After the PR is merged AND deployed (the owner runs this)

```bash
# 1. PRIMARY effect — the reporter's URL must now be 200:
curl -s -o /dev/null -w 'telemetry=%{http_code}\n' https://agg.dev.vpp.eneco.com/telemetryfunctiontestsfn/healthz   # expect 200
# 2. REGRESSION guard — siteregistry must stay 200:
curl -s -o /dev/null -w 'siteregistry=%{http_code}\n' https://agg.dev.vpp.eneco.com/api/siteregistry                # expect 200
# 3. CONFIRM the deploy actually carried the fix (not just merged):
SEC=$(kubectl -n vpp-agg get secret -l owner=helm,name=telemetryfunctiontestsfn --sort-by=.metadata.name -o name | tail -1)
kubectl -n vpp-agg get "$SEC" -o jsonpath='{.data.release}' | base64 -d | base64 -d | gunzip \
  | jq '.chart.values.ingress.annotations'   # expect the two nginx annotations, NOT {}
```

**Done-when (all three must hold):** edge `telemetry=200`, `siteregistry=200`, and the decoded release `annotations` contains `use-regex` + `rewrite-target`. If edge is 200 but step 3 still shows `{}`, you edited the live object instead of the chart — it will regress on the next deploy.

**Falsifier (if step 1 still 404s after deploy):** check `use-regex` applied, the `/$2` capture group matches the regex path, and the deployed release actually picked up the new values (step 3).

---

## Rollback

Revert the `values.yaml` PR (remove `use-regex`/`rewrite-target`, restore `path: /telemetryfunctiontestsfn/`) and redeploy. Blast radius is one ingress: no data, no shared infra, no other service touched. Reversibility: trivial. **Effect check after rollback:** `…/telemetryfunctiontestsfn/healthz` returns to `404` and `…/api/siteregistry` stays `200`.

## Residual risk / out of scope

- **The `agg.dev-mc` (OpenShift/GitOps) path already has the correct Route rewrite** but is internal-only (NXDOMAIN publicly). Consolidating onto it is a strategic follow-up, not this fix.
- **Latent:** the bare-prefix `301`→`http://` plaintext-downgrade redirect on the legacy nginx ingress (see RCA L10 #6) is not addressed here.
- **Process risk (the real recurrence cause):** without an owner for the chart PR and a per-`*fn` `/healthz` CI smoke probe, this class can silently regress again. Add the CI probe (see `sre-toil-removal` note in RCA L10/L12).

## Sign-off checklist

- [ ] PR changes BOTH files for `telemetryfunctiontestsfn`: `values.yaml` (add `use-regex` + `rewrite-target:/$2` + regex path) AND `templates/ingress.yaml` (`pathType: Prefix` → `ImplementationSpecific`). Same for `deliveryreportfn` (liveness via `/deliveryreportfn/`, not `/healthz`).
- [ ] PR **merged** (not just opened) and **deployed** through the ADO pipeline.
- [ ] `…/telemetryfunctiontestsfn/healthz` returns `200` from AVD / public.
- [ ] `…/api/siteregistry` still `200`.
- [ ] Decoded live release `ingress.annotations` is no longer `{}`.
- [ ] FAQ updated: prefix-mounted `*fn` need the nginx rewrite; reach health at the backend root via port-forward in the meantime.
- [ ] (Recommended) CI smoke probe added: assert each `*fn` `/healthz` returns 200 through the edge after deploy.
