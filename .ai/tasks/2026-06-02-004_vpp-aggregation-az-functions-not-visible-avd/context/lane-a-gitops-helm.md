---
task_id: 2026-06-02-004
agent: claude-opus-4-8
status: complete
summary: Lane A source/IaC sidecar. Canonical fix located. telemetryfunctiontestsfn 404 = legacy chart authored for Azure Application Gateway (appgw backend-path-prefix), deployed onto nginx-ingress where that annotation is a no-op; nginx rewrite-target was NEVER present (legacy gap, not regression). vpp-agg on AKS is the ABANDONED direct-HelmDeploy era; canonical path is GitOps+ArgoCD OpenShift Routes on agg.dev-mc.
---

# Lane A — GitOps / Helm source for the telemetryfunctiontestsfn 404

Read-only investigation. Local clones at
`/Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src/enecomanagedcloud/myriad-vpp/`.
Clones are ~6.5 months stale; `git pull` over SSH is broken. Internal consistency with all
live-probed facts (host, namespace, image tags, missing ingress annotations) is high, so the
verdict below holds; staleness is flagged A3 where it could matter for a PR.

Evidence labels: A1 = file:line / command output; A2 = inference; A3 = UNVERIFIED[blocked: reason].

## TL;DR verdict

There are **TWO deployment eras** for these `*fn`/siteregistry workloads, and the live 404 lives in
the **legacy** one:

| | LEGACY (what is LIVE & broken) | CANONICAL (modern) |
|---|---|---|
| Cluster | AKS `vpp-aks01-d` | OpenShift / OCP |
| Namespace | `vpp-agg` | `eneco-vpp-agg` |
| Host | `agg.dev.vpp.eneco.com` | `agg.dev-mc.vpp.eneco.com` |
| Routing object | nginx `Ingress` (path prefix, NO rewrite) | OpenShift `Route` (`haproxy.../rewrite-target: /`) |
| Source of routing | `Eneco.Vpp.Aggregation/azure-pipeline/Helm/<svc>/templates/ingress.yaml` | OCI chart `oci://vppacra.azurecr.io/helm-agg`, values in `Eneco.Vpp.Aggregation.GitOps/Helm/<svc>/{dev,acc,prod}/values.yaml` |
| Deploy mechanism | ADO `HelmDeploy@0 upgrade` direct to AKS | ADO CD → git-push image tag into GitOps repo → ArgoCD sync |
| Image tags | `adhoc-0.0.1.1457` (ad-hoc) | `3.18.1.dev.*` |

The OpenShift Route path **already strips the prefix correctly** (`haproxy.router.openshift.io/rewrite-target: /`).
Only the legacy nginx-Ingress path is broken — and it is broken because its prefix-strip annotation is the
**Application Gateway** variant, which nginx ignores.

## 1. The chart that generates the live ingress (file:line)

The live nginx ingresses are rendered by the **app repo's** azure-pipeline Helm dir, NOT the GitOps repo.

A1 — `Eneco.Vpp.Aggregation/azure-pipeline/Helm/telemetryfunctiontestsfn/templates/ingress.yaml:1-26`
renders `kind: Ingress` only `{{- if eq .Values.openshift.enabled false }}`, name `{{ .Release.Name }}-ingress`,
`path: {{ .Values.ingress.path }}` with `pathType: Prefix`, annotations purely passed through from
`.Values.ingress.annotations`. **The template adds NO rewrite logic of its own.**

A1 — `Eneco.Vpp.Aggregation/azure-pipeline/Helm/telemetryfunctiontestsfn/values.yaml:21-32`:
```yaml
openshift:
  enabled: false
ingress:
  enabled: true
  hostname: agg.dev.vpp.eneco.com
  path: /telemetryfunctiontestsfn/
  annotations:
    appgw.ingress.kubernetes.io/backend-path-prefix: /
    kubernetes.io/ingress.class: azure/application-gateway
```

A1 — same pattern for `deliveryreportfn` (`.../deliveryreportfn/values.yaml:29-37`,
`path: /deliveryreportfn/` + identical `appgw.*` annotation). siteregistry differs: `path: /` with
no strip needed (`.../siteregistry/values.yaml:38-46`, nginx annotation only commented out).

### Why this 404s on nginx

A2 — The path-strip annotation present is `appgw.ingress.kubernetes.io/backend-path-prefix: /`, the
**Azure Application Gateway Ingress Controller (AGIC)** equivalent of nginx's `rewrite-target`. The live
controller is **nginx-ingress v1.14.0** (A1, evidence-ledger). nginx **ignores `appgw.*` annotations**, so
the `/telemetryfunctiontestsfn/` prefix is forwarded unstripped to the Azure-Functions backend, which serves
its routes at root and 404s the prefixed path. This is the exact mechanism proven by the port-forward probes
(`/healthz`=200 vs `/telemetryfunctiontestsfn/healthz`=404). The chart was authored for App Gateway and is
mis-deployed onto nginx. (Consistent with the evidence-ledger observation that the LIVE ingress carries ONLY
`meta.helm.sh/release-*` annotations — see drift note in §4.)

## 2. rewrite-target: absent (legacy gap) — NOT removed

A1 — `git -C Eneco.Vpp.Aggregation log --all --oneline -S "nginx.ingress.kubernetes.io/rewrite-target" -- azure-pipeline/Helm/`
returns **zero commits**. nginx `rewrite-target` was never in any of these charts.

A1 — `git log -S "appgw.ingress.kubernetes.io/backend-path-prefix" -- .../telemetryfunctiontestsfn/values.yaml`
→ introduced `ca7399fb 2023-12-13` ("PR 66664: HTTPS access for siteregistry and telemetryfunctiontestsfn").
The appgw annotation is the only path-strip mechanism this chart has ever had.

A1 — `11f955e3 2024-07-10` ("PR 87440: Update networking configuration for service with ingress") changed
`path: /telemetryfunctiontestsfn` → `/telemetryfunctiontestsfn/` and `service.type: LoadBalancer` → `ClusterIP`,
but **kept** the appgw annotation. So the trailing-slash prefix was added without ever switching to an
nginx-compatible rewrite.

A2 — Verdict: **legacy gap (H1 confirmed)**, not a regression. The chart predates / never adopted the
nginx-ingress idiom. The siteregistry sibling only works because it is mounted at `/` (no prefix to strip).

## 3. How vpp-agg is deployed + legacy/canonical verdict

### Legacy (LIVE): direct ADO HelmDeploy to AKS

A1 — `Eneco.Vpp.Aggregation/azure-pipeline/templates/deploy.yaml:30-50`:
`${{ if eq(parameters.environment, 'vpp-agg') }}` → `HelmDeploy@0 command: upgrade`, `useClusterAdmin: true`,
`namespace: vpp-agg`, `chartType: FilePath`, `chartPath: azure-pipeline/Helm/<svc>/`,
`overrideValues: ingress.hostname=agg.dev.vpp.eneco.com`. Caller chain:
`deploy-stage.yaml:245 → deploy.yaml` (A1).

A2 — This is what produced the live nginx ingresses in `vpp-agg` on `agg.dev.vpp.eneco.com`. The running
`adhoc-0.0.1.1457` tags map to the `Agg-Adhoc-Versions` variable group (A1,
`deploy.job.template.yaml:35`) — an ad-hoc/manual HelmDeploy, not the standard release flow.

### Canonical (modern): CD → GitOps → ArgoCD → OpenShift Routes

A1 — `Eneco.Vpp.Aggregation/azure-pipeline/pipelines/templates/deploy.job.template.yaml:64-121`: the modern
CD job does NOT helm-deploy. It `checkout: gitops`, `yq -i` the image tag into
`Helm/<svc>/<env>/values.yaml`, and `git push origin HEAD:main` into the GitOps repo. This matches the
GitOps repo's last commit `fb45273 2025-11-12 "Updated image tag for siteregistry to 3.18.1.dev.7425677"` (A1).

A1 — `Eneco.Vpp.Aggregation.GitOps/Helm/telemetryfunctiontestsfn/dev/Chart.yaml:25-29`: values-only wrapper,
`dependencies: telemetryfunctiontestsfn 0.1.26 repository oci://vppacra.azurecr.io/helm-agg` (the route/ingress
template lives in that OCI chart — A3 [blocked: OCI registry not pulled this session]).

A1 — `.../GitOps/Helm/telemetryfunctiontestsfn/dev/values.yaml:18-25`: `openshift.enabled: true`,
`route.annotations.haproxy.router.openshift.io/rewrite-target: /`, `internalHostName: agg.dev-mc.vpp.eneco.com`,
`routePath: /telemetryfunctiontestsfn`. → OpenShift **Route** with correct prefix strip.

A1 — `.../GitOps/Helm/agg-argocd-application/values.dev.yaml`: ArgoCD app set, `namespace: eneco-vpp-agg`,
monitors the GitOps repo; registers `telemetryfunctiontestsfn` (`path: Helm/telemetryfunctiontestsfn/dev`),
`siteregistry`, `deliveryreportfn`, etc.

A2 — **Verdict: `agg.dev.vpp.eneco.com` / namespace `vpp-agg` on AKS is the LEGACY, effectively abandoned
deployment.** The canonical aggregation dev surface is the GitOps+ArgoCD OpenShift deployment in namespace
`eneco-vpp-agg` at `agg.dev-mc.vpp.eneco.com`, where the prefix-strip is already correct. The `adhoc` images,
497d age, absence from the ArgoCD app set on this cluster, and host mismatch (`agg.dev` vs `agg.dev-mc`) all
point the same way.

A3 [blocked: cannot pull current ADO] — Whether the legacy `vpp-agg`/AKS endpoint is still officially the
shared dev aggregation endpoint, or formally deprecated in favour of `agg.dev-mc`, is an org/ownership
question not answerable from stale clones. Resolving path: ask Trade Platform / Aggregation owners, or check
the aggregation wiki/ADR (eneco-context-docs) for the current canonical dev host. The reporter's expectation
that `agg.dev` should serve telemetry suggests `agg.dev` is still treated as live by consumers.

Note on the "telemetry-0.4.0 / `/api/telemetry`" modern pattern (ionix/ishtar/jupiter): that chart is NOT
present in any of the four aggregation repos (A1 — grep for `telemetry-0.4.0` / `/api/telemetry` in
`Eneco.HelmCharts`, `platform-gitops`, `VPP.GitOps` returned nothing relevant; only `opentelemetry-collector`
exists). A2 — it is a separate telemetry-collector product layer, not the aggregation `*fn` family; treat it
as a different system, not a drop-in replacement for `telemetryfunctiontestsfn`.

## 4. Drift note (live ingress annotations)

A3 [blocked: cannot re-pull / cannot re-inspect Helm release values] — Source values define the `appgw.*`
annotations, but the LIVE ingress (evidence-ledger) carries ONLY `meta.helm.sh/release-*`. So the live release
was rendered from values that lacked even the appgw annotation (e.g. an older chart revision or an
override). This does NOT change the fix — whatever the live values were, they contained no nginx
rewrite-target — but it means the deployed values are not byte-identical to the current source values.yaml.
Confirm by reading the live Helm release values (`helm -n vpp-agg get values telemetryfunctiontestsfn`) before
raising a PR, so the PR targets the values actually in effect.

## 5. Recommended fix — location + minimal change

Two options. Pick by answering "is `agg.dev`/AKS the endpoint we keep?" (the §3 A3 ownership question).

### Option A (RECOMMENDED if `agg.dev`/AKS stays the dev endpoint) — add nginx rewrite to the LEGACY chart

Platform-idiomatic for nginx-ingress v1.14.0: regex capture + rewrite-target.

File: `Eneco.Vpp.Aggregation/azure-pipeline/Helm/telemetryfunctiontestsfn/values.yaml`
(and mirror in `deliveryreportfn/values.yaml`). Minimal diff:

```yaml
ingress:
  enabled: true
  hostname: agg.dev.vpp.eneco.com
  path: /telemetryfunctiontestsfn(/|$)(.*)        # was: /telemetryfunctiontestsfn/
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
    nginx.ingress.kubernetes.io/use-regex: "true"
    kubernetes.io/ingress.class: nginx            # was: azure/application-gateway
    # drop: appgw.ingress.kubernetes.io/backend-path-prefix (no-op on nginx)
```

A3 [blocked] — the template hard-codes `pathType: Prefix`
(`templates/ingress.yaml:20`). With `use-regex: "true"` nginx honours the regex regardless of pathType, but
for cleanliness consider `pathType: ImplementationSpecific`. Validate the rendered manifest against
nginx-ingress v1.14.0 before apply. NOTE: confirm the live release values first (§4) so the override actually
lands.

### Option B (RECOMMENDED if the org intent is consolidation) — re-sync to the canonical GitOps/ArgoCD path

Do not patch the legacy chart. Onboard `telemetryfunctiontestsfn` to the GitOps+ArgoCD OpenShift deployment
(namespace `eneco-vpp-agg`, host `agg.dev-mc.vpp.eneco.com`), where the Route already strips the prefix
correctly (`.../GitOps/Helm/telemetryfunctiontestsfn/dev/values.yaml:20-25`), and point/redirect consumers at
`agg.dev-mc`. This eliminates the divergence rather than perpetuating two eras. Requires platform-owner
decision on the canonical host.

### NOT recommended
Re-syncing the legacy AKS deploy to the GitOps `3.18.1.dev` image alone does NOT fix the 404 — the bug is the
ingress prefix/annotation, not the image tag. A newer image on the same broken nginx ingress still 404s.

## Confidence

- Root-cause mechanism (appgw annotation no-op on nginx; rewrite-target never present): **HIGH** (git + source).
- Two-era legacy/canonical split + deploy mechanisms: **HIGH** (deploy.yaml, deploy.job.template.yaml,
  argocd app set, image-tag drift all converge).
- Exact fix snippet for nginx v1.14.0: **HIGH** for the annotation/regex idiom; **MEDIUM** on pathType detail
  and on live-values byte-parity (§4 A3) — verify rendered manifest + live release values before PR.
- "Is agg.dev officially deprecated": **UNVERIFIED[blocked]** — ownership/wiki question.
