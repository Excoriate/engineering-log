---
task_id: 2026-06-02-004
agent: claude-opus-4-8
status: partial
summary: Live-probe evidence ledger for the agg.dev telemetryfunctiontestsfn 404. Root cause proven 3 ways; canonical-fix-location lanes pending.
---

# Evidence Ledger — telemetryfunctiontestsfn 404 on agg.dev.vpp.eneco.com

Captured 2026-06-02 from Mr. Alex's laptop (public internet) + live kubectl to AKS `vpp-aks01-d`
(session user `Alex.Torres@eneco.com`). All probes READ-ONLY. Evidence labels per repo convention.

## Symptom (reporter, verbatim)

- `https://agg.dev.vpp.eneco.com/telemetryfunctiontestsfn/healthz` "should be accessible from AVD" but is not.
- `https://agg.dev.vpp.eneco.com/api/siteregistry` IS accessible (reporter's working example).
- Reporter: jhonson lobos. AVD = Azure Virtual Desktop (developers' restricted jump host into CMC/Azure).

## A1 — Edge reproduction (laptop, public DNS → 20.76.210.221 :443)

| Path | HTTP | Body |
|------|------|------|
| `/` | 200 | `{"PackageName":"SiteRegistry.API"}` |
| `/api/siteregistry` | 200 | `{"PackageName":"SiteRegistry.API"}` |
| `/api/siteregistry/healthz` | 200 | `{"status":"Healthy",...}` |
| `/healthz` | 200 | `{"status":"Healthy",...}` |
| `/telemetryfunctiontestsfn/healthz` | **404** | empty |
| `/telemetryfunctiontestsfn/` | **404** | empty |
| `/telemetryfunctiontestsfn` (no slash) | 301 → `/telemetryfunctiontestsfn/` | nginx trailing-slash redirect |
| `/deliveryreportfn/healthz` (CONTROL) | **404** | empty |

Source files: `context/http-probes.txt`, `context/http-probes-2.txt`.
**Inference A2:** clean 404 over a 0.018s TCP connect ⇒ ingress reachable and answering; this is path-routing,
NOT a network/whitelist/private-endpoint block (those yield timeout/403). The "AVD" framing is the reporter's
vantage point, not the cause — the 404 reproduces from the public internet.

## A1 — Routing layer identity

- `301` on bare prefix returns `<center>nginx</center>` ⇒ routing layer is **nginx ingress**, not Front Door/APIM/Azure Functions proxy.
- Front reconciliation: `20.76.210.221` answers only on **:443** (HTTPS); cluster nginx `50.85.91.121` answers on **:80**.
  Hitting public host (443) and hitting cluster nginx directly with `Host: agg.dev.vpp.eneco.com` (80) give
  **identical** results (siteregistry 200 / telemetry 404) ⇒ the front faithfully proxies to this cluster's nginx;
  the 404 originates at nginx→backend, the front is not the cause.

## A1 — Cluster state (AKS vpp-aks01-d, namespace `vpp-agg`)

Ingresses on host `agg.dev.vpp.eneco.com`:

| Ingress | path | pathType | rewrite-target? | backend svc:port |
|---------|------|----------|-----------------|------------------|
| `siteregistry-ingress` | `/` | Prefix | **none** | `siteregistry:8080` |
| `telemetryfunctiontestsfn-ingress` | `/telemetryfunctiontestsfn/` | Prefix | **none** | `telemetryfunctiontestsfn:8080` |
| `deliveryreportfn-ingress` | `/deliveryreportfn/` | Prefix | **none** | `deliveryreportfn:8080` |

Full annotations of telemetry + siteregistry ingress = ONLY `meta.helm.sh/release-*` (NO `nginx.ingress.kubernetes.io/rewrite-target`, no `use-regex`, no `configuration-snippet`).

Telemetry workload ALL HEALTHY:

- svc `telemetryfunctiontestsfn` ClusterIP 10.2.155.205:8080
- deploy `telemetryfunctiontestsfn-telemetryfunctiontestsfn` 1/1 ready, image `vppacra.azurecr.io/eneco-vpp-agg/telemetryfunctiontestsfn:adhoc-0.0.1.1457`
- pod `...-5b74664dtbtpt` 1/1 Running 18h
- endpoints `telemetryfunctiontestsfn` → 10.0.1.167:8080 (present)

nginx ingress controller image: `registry.k8s.io/ingress-nginx/controller:v1.14.0`.

## A1 — Direct-to-backend (port-forward svc:8080, BYPASSING ingress)

`context/backend-portforward-probes.txt`:

telemetryfunctiontestsfn backend:

| Path (at backend root) | HTTP | Body |
|------|------|------|
| `/` | 200 | `<title>Your Azure Function App is up and running.</title>` (Azure Functions host) |
| `/healthz` | **200** | `Healthy` |
| `/telemetryfunctiontestsfn/healthz` | **404** | empty |
| `/api/telemetry`, `/swagger`, `/api/healthz` | 404 | empty |

siteregistry backend: `/` 200 banner, `/healthz` 200 JSON, `/api/siteregistry` 200 banner.

## VERIFIED ROOT CAUSE (depth 3)

The `telemetryfunctiontestsfn` pod is an **Azure Functions host** that serves its routes at **root** (`/healthz` → 200).
Its ingress mounts it under a **path prefix** `/telemetryfunctiontestsfn/` with **no `rewrite-target`**, so nginx forwards
the *unstripped* path. The backend receives `/telemetryfunctiontestsfn/healthz`, has **no `PathBase`/route** for that
prefix, and returns 404.

- **Proximate:** backend 404s the prefixed path (proven: port-forward `/healthz`=200 vs `/telemetryfunctiontestsfn/healthz`=404).
- **Enabling:** ingress path-prefix without `rewrite-target`, and the app has no matching `PathBase`/`routePrefix`.
- **Design/systemic:** the legacy `vpp-agg` `*fn` pattern mounts each function at `/<name>/` but never strips the prefix —
  the `deliveryreportfn` CONTROL 404s identically. `siteregistry` works ONLY because it is mounted at `/` (no prefix to strip).

This is a routing/config defect, fully reproducible from the public internet and cluster-internally. NOT an outage,
NOT a deployment-missing, NOT an AVD network restriction.

## Open (delegated to confirmation lanes)

1. Canonical fix location + whether `rewrite-target` was dropped (regression) or never present (legacy gap):
   Helm chart/GitOps source for these `*fn` ingresses. NOTE drift: running `adhoc-0.0.1.1457` vs GitOps repo's
   `siteregistry 3.18.1.dev.7425677` ⇒ `vpp-agg` may be a legacy/ad-hoc env not actively GitOps-synced. `*fn` workloads
   are NOT visible as ArgoCD apps.
2. Modern convention comparison: named envs (ionix/ishtar/...) expose telemetry via Helm chart `telemetry-0.4.0` at
   path `/api/telemetry` → svc `telemetry`. Is `vpp-agg` deprecated in favour of these?
3. Slack history: jhonson lobos prior AVD reports; was this raised/resolved before?
4. Docs/ADR/runbook for aggregation ingress exposure + the purpose of telemetryfunctiontestsfn.

## Network topology (for AVD probing — user request)

DNS `agg.dev.vpp.eneco.com` → `20.76.210.221` (front, HTTPS:443) → AKS nginx `50.85.91.121` (HTTP:80) →
ClusterIP svc `:8080` → pod. Endpoint is **publicly reachable** (verified from laptop) ⇒ **no AVD IP whitelist
required** to probe `/healthz`. Front identity (A1, resource graph + `az network application-gateway show`):
**Application Gateway `vpp-agw-d`** (WAF_v2, Basic rules, no urlPathMap → pass-through to nginx). See
`network-topology.md`.

## Post-review confirmations & corrections (A1, adversarial)

- **Origin of the 404 — proven, not inferred** (`verification/sherlock-receipt.md`): the **nginx access log**
  shows the failing request routed to upstream **`10.0.1.167:8080`** (the telemetry pod), which returned 404.
  Correction: do NOT use "empty body / absent `Server` header" as an origin discriminator — that header is absent
  even on the 200 responses. Origin rests on the access log + the port-forward repro.
- **Backend HTTP surface scope** (A1, sherlock port-forward): the Functions host serves **only `/healthz` (200)**;
  **`/api/*` → 404**, **`/admin/*` → 401**. ⇒ no HTTP-invocable functions (timer/Kafka-triggered QA test
  functions per ADR AL006). `/healthz` reachability is the complete, intended goal; the rewrite fix is scoped to it.
- **Post-fix 200 is A2** (inference by composition), not executed — fix delivered as a PR; no cluster mutation made.
