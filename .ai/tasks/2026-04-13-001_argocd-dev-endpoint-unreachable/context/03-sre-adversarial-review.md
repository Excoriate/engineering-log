---
task_id: 2026-04-13-001
agent: sre-maniac
status: complete
summary: |
  Adversarial review PARTIALLY CONFIRMS root cause but OVERTURNS key evidence
  interpretation. The 200 at /api/activation-mfrr/ is NOT the activationmfrr
  API — it is the VPP frontend SPA catch-all returning index.html for all
  unmatched routes. The fix is still CORRECT but for a different reason than
  stated: the ingress path must match the app's PathBase so the app receives
  correctly-prefixed requests, not because the hyphenated path "works."
---

# SRE Adversarial Review: ArgoCD Dev Endpoint Unreachable

## Key Findings

1. 200 at /api/activation-mfrr/ is the SPA frontend catch-all, not the API
2. 404 at /api/activationmfrr/ proves NGINX ingress IS working and reaching the app
3. Proposed fix is CORRECT but evidence interpretation was wrong
4. AGW dev.tfvars has NO path rule for activation-mfrr — relies on default backend
5. Sandbox uses completely different Helm structure (ingress: vs route:)

## VERDICT: FIX IS CORRECT — EVIDENCE CHAIN IS FLAWED

The proposed fix (changing sandbox ingress path from `/api/activationmfrr/` to
`/api/activation-mfrr/`) is the RIGHT fix, but the evidence chain that led to
it contains a CRITICAL misinterpretation that, if not corrected, will cause
confusion during post-incident review and mask understanding of the actual
request flow.

---

## 1. EVIDENCE VERIFICATION — Independent Curl Results

### Test 1: Non-hyphenated path (the broken path)

```
curl -svk "https://ionix.dev.vpp.eneco.com/api/activationmfrr/swagger/index.html"

HTTP/1.1 404 Not Found
Content-Length: 0
Request-Context: appId=cid-v1:af0f50ed-0246-41ed-92f8-6f1dd72f35ae
x-correlation-id: ab36685e-d086-4f0a-ad03-99dde75d3865
```

**CONFIRMED**: 404, empty body, ASP.NET Kestrel headers (appId, x-correlation-id).
This proves the NGINX ingress at path `/api/activationmfrr/` IS forwarding to the
activationmfrr pod. The pod correctly responds 404 because its PathBase is
`/api/activation-mfrr/` (with hyphen) and it does not recognize `/api/activationmfrr/`.

### Test 2: Hyphenated path (claimed "working" path) — OVERTURNED

```
curl -svk "https://ionix.dev.vpp.eneco.com/api/activation-mfrr/swagger/index.html"

HTTP/1.1 200 OK
Content-Type: text/html
Content-Length: 1893
Last-Modified: Wed, 08 Apr 2026 12:58:46 GMT
ETag: "69d65106-765"
Accept-Ranges: bytes

<title>Eneco Myriad VPP</title>
```

**THIS IS NOT THE ACTIVATIONMFRR API.**

Evidence:
- `Content-Type: text/html` (not `text/html;charset=utf-8` like Swagger)
- NO `Request-Context` header (ASP.NET apps always emit this)
- NO `x-correlation-id` header
- NO `x-swagger-ui-version` header
- `Content-Length: 1893` — static file, not dynamic Swagger UI
- Body contains Vue.js SPA: `<title>Eneco Myriad VPP</title>`, Vuetify, Azure App Insights
- `ETag: "69d65106-765"` — NGINX-style static file ETag
- `Accept-Ranges: bytes` — static file serving

This is the **VPP frontend SPA** serving `index.html` as a catch-all for any
path that does not match a specific NGINX ingress rule. This is standard SPA
behavior: NGINX returns the SPA for all unmatched routes, and the SPA's
client-side router handles them.

### Test 3: Healthz on hyphenated path — OVERTURNED

```
curl -svk "https://ionix.dev.vpp.eneco.com/api/activation-mfrr/healthz"

HTTP/1.1 200 OK
Content-Type: text/html
Content-Length: 1893
ETag: "69d65106-765"
```

**SAME SPA catch-all.** Identical response: same Content-Length, same ETag, same
HTML body. This is NOT a health check response from the activationmfrr pod.

### Test 4: Completely fake path — confirms catch-all

```
curl -svk "https://ionix.dev.vpp.eneco.com/api/activation-mfrr/TOTALLY-FAKE-PATH"

HTTP/1.1 200 OK
Content-Type: text/html
Content-Length: 1893
ETag: "69d65106-765"
```

Any path that does not have a matching NGINX ingress rule returns the SPA.
The "200" at `/api/activation-mfrr/` is meaningless — it proves nothing about
the activationmfrr service.

### Test 5: Working service comparison (dispatchersimulator)

```
curl -svk "https://ionix.dev.vpp.eneco.com/api/dispatchersimulator/swagger/index.html"

HTTP/1.1 200 OK
Content-Type: text/html;charset=utf-8
Transfer-Encoding: chunked
Cache-Control: max-age=0, private
Request-Context: appId=cid-v1:af0f50ed-0246-41ed-92f8-6f1dd72f35ae
x-correlation-id: 5f5e8442-d199-4391-b1a0-d2ffc7977dda
x-swagger-ui-version: 5.32.0
```

**THIS is what a real API Swagger response looks like:**
- `Request-Context` present (ASP.NET)
- `x-correlation-id` present
- `x-swagger-ui-version: 5.32.0` present
- `Transfer-Encoding: chunked` (dynamic, not static file)
- `Cache-Control: max-age=0, private` (dynamic content)

### Test 6: dev.vpp.eneco.com host — same pattern

```
curl -svk "https://dev.vpp.eneco.com/api/activationmfrr/swagger/index.html"

HTTP/1.1 404 Not Found
Content-Length: 0
Request-Context: appId=cid-v1:637e28ad-5d04-413c-adbc-2c523ef6be54

# NOTE: DIFFERENT appId than ionix.dev — these are different
# Application Insights instances (different cluster namespaces)
```

```
curl -svk "https://dev.vpp.eneco.com/api/activation-mfrr/swagger/index.html"

HTTP/1.1 200 OK
Content-Type: text/html
Content-Length: 1893
ETag: "69d8d282-765"  # Different ETag — different deploy of same SPA
```

Same pattern: non-hyphenated reaches the app (404), hyphenated hits SPA catch-all (200).

---

## 2. CORRECTED EVIDENCE CHAIN

### What is actually happening:

```
Request: GET /api/activationmfrr/swagger/index.html
         ↓
DNS:     ionix.dev.vpp.eneco.com → 20.76.210.221 (AGW)
         ↓
AGW:     No explicit path rule for /api/activationmfrr/*
         → falls through to default backend: "ingress-controller" (10.7.32.168)
         ↓
NGINX:   Ingress rule EXISTS for path /api/activationmfrr/ (sandbox values.yaml:84)
         → forwards to activationmfrr ClusterIP service on port 8080
         ↓
App:     PathBase = /api/activation-mfrr/ (with hyphen)
         Request path /api/activationmfrr/ does NOT match PathBase
         → 404 Not Found (Content-Length: 0, appId header present)
```

```
Request: GET /api/activation-mfrr/swagger/index.html
         ↓
DNS:     ionix.dev.vpp.eneco.com → 20.76.210.221 (AGW)
         ↓
AGW:     No explicit path rule for /api/activation-mfrr/*
         → falls through to default backend: "ingress-controller"
         ↓
NGINX:   NO ingress rule for /api/activation-mfrr/ (sandbox defines /api/activationmfrr/)
         → falls to default backend / catch-all server block
         → returns SPA index.html (the VPP frontend)
         ↓
Client:  Receives 200 with Vue.js SPA HTML (NOT the API)
```

### The root cause is confirmed but for the right reason:

The NGINX ingress path `/api/activationmfrr/` successfully routes to the pod,
but the pod rejects the request because its PathBase is `/api/activation-mfrr/`.
The fix must change the ingress path to match the app's PathBase.

---

## 3. CHALLENGE TO THE PROPOSED FIX

### 3a. Will changing ONLY the ingress path be sufficient?

**YES, with high confidence.** The fix changes the NGINX ingress path from
`/api/activationmfrr/` to `/api/activation-mfrr/`. This means:

1. NGINX will match `/api/activation-mfrr/*` and forward to the pod
2. The pod's PathBase `/api/activation-mfrr/` will match
3. The pod will serve the request

The AGW has NO explicit path rule for either path variant — it uses the default
backend (`ingress-controller`) for all unmatched paths. So the AGW configuration
does NOT need to change.

### 3b. Does the ArgoCD app URL need updating?

The ArgoCD UI probably shows the old URL. If the ArgoCD Application resource has
a URL annotation or the team has bookmarks, those need updating. But this is a
UX concern, not a routing concern. The ArgoCD sync itself only cares about the
Helm values, which is what we're changing.

### 3c. Will the AGW route `/api/activation-mfrr/*` to the ingress-controller?

**YES.** The AGW dev.tfvars `url_path_maps` for `vpp-routing-https` has:
```
default_backend_address_pool_name  = "ingress-controller"
default_backend_http_settings_name = "app"
```

Any path not matching an explicit rule goes to `ingress-controller`. Neither
`/api/activationmfrr/*` nor `/api/activation-mfrr/*` has an explicit rule.
Both route to the default backend.

**HOWEVER** — note that acc.tfvars and prd.tfvars DO have explicit AGW path rules
for `/api/activation-mfrr/*`. The dev environment lacks this. This is
inconsistent but not a blocker for the fix: the default backend achieves the
same routing. It is a **configuration hygiene debt** that should be tracked.

### 3d. Could there be ArgoCD sync issues?

ArgoCD watches the Git repo for changes. If the sandbox values.yaml is updated,
ArgoCD will detect the diff and either auto-sync or wait for manual sync
depending on the Application's sync policy. The risk factors:

1. **Sync wave ordering**: If the ingress is created/updated before the deployment
   is ready, there could be a brief window of 502 errors. This is unlikely for a
   path-only change on an existing ingress.
2. **ArgoCD diff detection**: ArgoCD sometimes has issues with certain YAML
   formatting. A simple string change should sync cleanly.
3. **Pruning**: If the old ingress resource name changes, ArgoCD might create a
   new one without deleting the old one (or vice versa). The fix only changes
   the `path` value, not the resource name, so this is not a risk.

**RISK: LOW.** Standard path-change sync.

---

## 4. WHAT COULD SILENTLY FAIL

### 4a. Health probes use relative paths

The sandbox values.yaml defines:
```yaml
startupProbe:
  httpGet:
    path: /healthz       # RELATIVE — no PathBase prefix
    port: http

readinessProbe:
  httpGet:
    path: /readiness      # RELATIVE — no PathBase prefix

livenessProbe:
  httpGet:
    path: /liveness       # RELATIVE — no PathBase prefix
```

These probes are sent DIRECTLY from kubelet to the pod on port 8080, NOT through
the NGINX ingress. The probes hit `/healthz`, `/readiness`, `/liveness` directly.

**Question**: Does the app register these endpoints at the root (`/healthz`) or
under the PathBase (`/api/activation-mfrr/healthz`)?

If the app requires the PathBase prefix for health endpoints, the probes are
currently working ONLY because Kestrel maps both. If the ingress path fix
changes nothing about the pod itself, the probes are unaffected. **LOW RISK.**

### 4b. Other services calling activationmfrr internally

If other services in the cluster call activationmfrr via its ClusterIP service
name (e.g., `http://activationmfrr:8080/api/activation-mfrr/...`), they bypass
NGINX entirely. These internal calls are unaffected by the ingress path change.

### 4c. The SPA catch-all masking future failures

After the fix, if someone curls `/api/activation-mfrr/swagger/index.html` and
the pod is DOWN, NGINX will return 502/503 — NOT the SPA catch-all. If the
NGINX ingress rule is removed or misconfigured, the SPA catch-all will
return 200 with the Vue.js app, silently masking the failure. This is a
**dangerous failure mode**: your monitoring might check for HTTP 200 and
conclude the service is healthy when it's actually returning the wrong content.

**RECOMMENDATION**: Health checks and synthetic monitors for the activationmfrr
endpoint should verify RESPONSE BODY or specific headers (e.g., `x-swagger-ui-version`
or `Request-Context`), not just HTTP status code. A 200 with the SPA HTML is
NOT a healthy response from the API.

---

## 5. BLAST RADIUS ANALYSIS

### What changes:
- One line in `VPP-Configuration/Helm/activationmfrr/sandbox/values.yaml`
- NGINX ingress resource for activationmfrr in the sandbox (ionix) namespace

### What does NOT change:
- AGW configuration (no Terraform change needed)
- DNS records (same wildcard record)
- TLS certificates (wildcard `*.dev.vpp.eneco.com` covers all subdomains)
- Other services' ingress rules
- Pod deployment, service, probes
- dev/acc/prod environments (already correct)

### Blast radius: MINIMAL
- Only affects external HTTP routing to activationmfrr in the sandbox environment
- No other services share this path prefix
- Internal cluster communication unaffected

---

## 6. STRUCTURAL CONCERN — Sandbox vs Other Environments

The sandbox values.yaml uses a COMPLETELY DIFFERENT Helm structure than
dev/acc/prod:

**Sandbox** (broken):
```yaml
ingress:
  enabled: true
  className: nginx
  hosts:
    - host: dev.vpp.eneco.com
      paths:
        - path: /api/activationmfrr/    # Direct NGINX ingress
          pathType: Prefix
```

**Dev/Acc/Prod** (working):
```yaml
route:
  enabled: true
  host: dev-mc.vpp.eneco.com
  path: /api/activation-mfrr
  ingressControllerSelectorLabel: dev-mc
```

This is not just a typo — the sandbox uses a fundamentally different routing
mechanism (`ingress:` with className nginx) versus the MC environments (`route:`
with ingressControllerSelectorLabel). The sandbox also targets a different host
(`dev.vpp.eneco.com` vs `dev-mc.vpp.eneco.com`).

This structural divergence means:
1. The sandbox is not a faithful replica of production routing
2. Path bugs in sandbox may not reproduce in prod and vice versa
3. The Helm chart must support BOTH structures, increasing template complexity
4. Configuration drift between sandbox and other envs is a latent risk

**This is technical debt, not a blocker for the fix, but it should be tracked.**

---

## 7. ADDITIONAL FINDING — AppId Discrepancy

The investigation report states: "404 response has the same appId as the
working 200 response."

This is MISLEADING. The appId `cid-v1:af0f50ed-0246-41ed-92f8-6f1dd72f35ae`
appears in the 404 response (from the activationmfrr pod) but NOT in the
200 response (from the SPA catch-all). The 200 response has NO `Request-Context`
header at all.

On `dev.vpp.eneco.com`, the 404 appId is `cid-v1:637e28ad-5d04-413c-adbc-2c523ef6be54`
— a DIFFERENT Application Insights instance than the `ionix.dev.vpp.eneco.com`
appId. These are different namespaces with different AI instrumentation keys.

The "same appId" claim in the original evidence was comparing apples to oranges.
It remains true that the 404 comes from the application (proven by the
`Request-Context` header), but the comparison with the 200 response is invalid
because the 200 never came from the application.

---

## 8. VERDICT SUMMARY

| Aspect | Assessment |
|--------|------------|
| Root cause correct? | **YES** — path mismatch confirmed |
| Evidence chain correct? | **PARTIALLY** — 200 response misidentified as API |
| Proposed fix correct? | **YES** — change ingress path to match PathBase |
| Fix sufficient? | **YES** — no other changes needed for routing |
| Blast radius | **MINIMAL** — sandbox only, one ingress resource |
| Silent failure risk | **MEDIUM** — SPA catch-all masks routing failures |
| Configuration hygiene | **DEBT** — sandbox uses different Helm structure |

### Recommendation

1. **APPLY THE FIX** — change line 84 of sandbox/values.yaml from
   `/api/activationmfrr/` to `/api/activation-mfrr/`
2. **VERIFY POST-FIX** by checking for ASP.NET-specific headers in the response:
   ```bash
   curl -svk "https://ionix.dev.vpp.eneco.com/api/activation-mfrr/swagger/index.html" 2>&1 \
     | grep -E "Request-Context|x-swagger-ui-version|x-correlation-id"
   ```
   All three headers MUST be present. If only the SPA HTML returns, the fix
   did not take effect.
3. **TRACK DEBT** — sandbox structural divergence from other environments
4. **ADD CONTENT VALIDATION** — health monitoring should check response body,
   not just HTTP status code, to avoid SPA catch-all masking real failures
