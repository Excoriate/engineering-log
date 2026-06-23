# Fix `telemetryfunctiontestsfn/healthz` 404 on `agg.dev` — add the nginx prefix rewrite

**Repo:** `Eneco.Vpp.Aggregation`  ·  **Branch:** `fix/NOTICKET/add-nginx-rewrite-telemetry-fn` → `development`
**Chart:** `azure-pipeline/Helm/telemetryfunctiontestsfn` (`0.1.28` → `0.1.29`)

## Why

`https://agg.dev.vpp.eneco.com/telemetryfunctiontestsfn/healthz` returns **404** from AVD, blocking e2e/release validation, while the sibling `…/api/siteregistry` returns 200. This recurred from the 2026‑06‑02 on‑call incident — the fix below was diagnosed then but never merged, so ~15 redeploys since have re‑rendered the broken ingress.

## Root cause

The nginx `Ingress` mounts the Azure‑Functions backend under the **path prefix** `/telemetryfunctiontestsfn/` with **no `rewrite-target`**. The backend serves its health endpoint at the **root** (`/healthz`), so nginx forwards the *unstripped* path `/telemetryfunctiontestsfn/healthz` to an app that only knows `/healthz` → **404**. `siteregistry` works only because it is mounted at `/` (no prefix to strip). Origin: the AGIC → nginx ingress migration dropped the `appgw` prefix‑strip annotation and the nginx equivalent (`rewrite-target`) was never added.

## What this PR changes

**`values.yaml`** — make the path a regex and add the nginx rewrite:

```diff
-  path: /telemetryfunctiontestsfn/
-  annotations: {}
+  path: /telemetryfunctiontestsfn(/|$)(.*)
+  annotations:
+    nginx.ingress.kubernetes.io/use-regex: "true"
+    nginx.ingress.kubernetes.io/rewrite-target: /$2
```

**`templates/ingress.yaml`** — `pathType` must change for a regex path:

```diff
           - path: {{ .Values.ingress.path }}
-            pathType: Prefix
+            pathType: ImplementationSpecific
```

**`Chart.yaml`** — `version: 0.1.28` → `0.1.29`.

nginx now captures everything after the prefix into `$2` and forwards `/$2` to the backend, so `/telemetryfunctiontestsfn/healthz` → backend `/healthz` → **200**.

## Why `pathType: ImplementationSpecific` (not `Prefix`)

A regex path under `pathType: Prefix` is **rejected by the nginx ingress admission webhook** (`path … cannot be used with pathType Prefix`). `use-regex` does not rescue it — the webhook denies the object before nginx evaluates the path. `ImplementationSpecific` is the correct (and required) path type for regex matches.

## Verification

- **Proven live before merge:** a throwaway ingress with these exact annotations and `pathType: ImplementationSpecific` returned **200** through the public edge; the backend already serves `/healthz`=200 at root (verified by port‑forward).
- **Rendered manifest accepted:** server‑side dry‑run of the chart's output passes the nginx admission webhook.
- **Post‑deploy acceptance (dev):**

```bash
curl -s -o /dev/null -w '%{http_code}\n' https://agg.dev.vpp.eneco.com/telemetryfunctiontestsfn/healthz   # expect 200
curl -s -o /dev/null -w '%{http_code}\n' https://agg.dev.vpp.eneco.com/api/siteregistry                    # still 200 (regression guard)
```

(Confirm the deploy carried the change: decode the live Helm release and check `ingress.annotations` is no longer `{}`.)

## Scope

- **Only `telemetryfunctiontestsfn`** (the release blocker). The same two‑file change applies to other prefix‑mounted `*fn` (e.g. `deliveryreportfn`) and can follow in a separate PR. Note: `deliveryreportfn`'s backend serves `/`=200 but `/healthz`=404, so its liveness check is `/deliveryreportfn/`, not `/healthz`.
- **No** app/image/network/whitelist/VNET changes — none are the cause.
- Incidental: for this service the bare‑prefix `/telemetryfunctiontestsfn` request (today a `301`→`http://` redirect) becomes a `200` root banner — an improvement.

## Rollback

Revert this PR and redeploy; the ingress returns to the prior state. Blast radius is one dev ingress — no data, no shared infrastructure, no other service touched.

## Reference

Full holistic RCA + how‑to‑fix + live evidence: engineering‑log `log/employer/eneco/02_on_call_shift/2026_june/2026_06_22_005_azfunctions_avd_not_visible/`.
