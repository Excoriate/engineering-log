---
task_id: 2026-04-13-001
agent: coordinator
status: draft
summary: "Phase 4 investigation findings — root cause evidence chain"
---

# Investigation Findings

## Evidence Chain (all FACT — verified via live probes + source code)

### 1. HTTP Probes (live, 2026-04-13)
| URL | HTTP Code | Meaning |
|-----|-----------|---------|
| `ionix.dev.vpp.eneco.com/api/activationmfrr/swagger/index.html` | **404** | App doesn't serve at this path |
| `ionix.dev.vpp.eneco.com/api/activationmfrr/healthz` | **404** | Confirms: full path mismatch |
| `ionix.dev.vpp.eneco.com/api/activationmfrr/` | **404** | Base path also fails |
| `ionix.dev.vpp.eneco.com/api/activation-mfrr/swagger/index.html` | **200** | **App DOES serve at hyphenated path!** |
| `ionix.dev.vpp.eneco.com/api/dispatchersimulator/` | **200** | Working service comparison |
| `dev.vpp.eneco.com/api/activationmfrr/swagger/index.html` | **404** | Same issue on base host |

### 2. DNS (live)
- `ionix.dev.vpp.eneco.com` → `20.76.210.221` (Azure Application Gateway)
- `dev.vpp.eneco.com` → `20.76.210.221` (same AGW)
- Ingress LB IP in ArgoCD: `50.85.91.121` (NGINX LB inside cluster)
- DNS is NOT the issue — resolution works correctly

### 3. Response Analysis
- 404 response has `Request-Context: appId=cid-v1:af0f50ed-0246-41ed-92f8-6f1dd72f35ae` — same appId as working 200
- 404 has `Content-Length: 0` — empty body, characteristic of ASP.NET Kestrel (not NGINX or AGW error pages)
- The 404 comes from **the application itself**, not infrastructure

### 4. Path Configuration Evidence

**Sandbox values** (VPP-Configuration/Helm/activationmfrr/sandbox/values.yaml:84):
```yaml
ingress:
  enabled: true
  className: nginx
  hosts:
    - host: dev.vpp.eneco.com
      paths:
        - path: /api/activationmfrr/    # <-- NO HYPHEN
          pathType: Prefix
```

**Prod values** (VPP-Configuration/Helm/activationmfrr/prod/values.yaml:83):
```yaml
route:
  path: /api/activation-mfrr   # <-- WITH HYPHEN
```

**Acc values** (VPP-Configuration/Helm/activationmfrr/acc/values.yaml:83):
```yaml
route:
  path: /api/activation-mfrr   # <-- WITH HYPHEN
```

**Dev values** (VPP-Configuration/Helm/activationmfrr/dev/values.yaml:83):
```yaml
route:
  path: /api/activation-mfrr   # <-- WITH HYPHEN
```

### 5. Ingress Template Analysis
- Both activationmfrr and dispatchersimulator use identical ingress templates
- Annotations come from `.Values.ingress.annotations` — both are empty
- Templates are NOT the issue — the VALUES are

### 6. AGW Analysis (dev.tfvars)
- All AGW url_path_maps route to `"ingress-controller"` backend
- NO rewrite_rules_sets exist in dev environment
- NO path rule for `/api/activation-mfrr/*` or `/api/activationmfrr/*`
- AGW is pass-through to NGINX ingress controller

### 7. Working Service Comparison
- dispatchersimulator ALSO has no rewrite annotations — identical setup
- It works because its Blazor app is built with `<base href="/api/dispatchersimulator/">`
- The app inherently serves at the ingress path — no rewrite needed
- activationmfrr is a .NET Web API that serves at `/api/activation-mfrr/` (with hyphen)

## Root Cause

**PATH NAMING INCONSISTENCY**: The sandbox ingress uses `/api/activationmfrr/` (no hyphen) but the application's PathBase is `/api/activation-mfrr/` (with hyphen). All other environments (dev, acc, prod) use the correct hyphenated path.

## Eliminated Hypotheses

[ELIMINATED: H2-DNS, evidence: dig resolves correctly to AGW, phase: 4]
[ELIMINATED: H3-Template-conditional, evidence: templates are identical for both services, phase: 4]
[ELIMINATED: H4-TLS, evidence: curl gets HTTP response (TLS works), phase: 4]
[ELIMINATED: H1-original-NGINX-rewrite, evidence: dispatchersimulator works without rewrite annotations, phase: 4]
