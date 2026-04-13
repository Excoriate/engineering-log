---
task_id: 2026-04-13-001
agent: coordinator
status: draft
summary: "Confirmed root cause analysis: activationmfrr 404 due to path naming inconsistency (missing hyphen)"
---

# Root Cause Analysis: ArgoCD Dev Endpoint Unreachable — activationmfrr

**Date**: 2026-04-13
**Severity**: Blocking (VPP developer cannot QA-test feature branch)
**Status**: Root cause confirmed with FACT-level evidence

---

## 1. Incident Summary

The `activationmfrr` service deployed in ArgoCD's `ionix` namespace (feature branch environment for `feature/fbe-778244_Activation-API-Monitoring`) shows as **Synced + Healthy** but returns **HTTP 404** when accessed at `https://ionix.dev.vpp.eneco.com/api/activationmfrr/swagger/index.html`.

**Root Cause**: A single-character typo — a missing hyphen in the ingress path configuration. The sandbox Helm values configure the NGINX ingress with path `/api/activationmfrr/` (no hyphen), but the .NET application serves at PathBase `/api/activation-mfrr/` (with hyphen between "activation" and "mfrr"). NGINX forwards the non-hyphenated path to the pod; the app's routing middleware doesn't match it; the app returns 404.

---

## 2. Request Flow — How Traffic Reaches Your Pod

### Architecture Overview

```
                              ┌─────────────────────────────────────┐
                              │       Azure Application Gateway      │
    Developer's Browser       │       IP: 20.76.210.221             │
    ─────────────────────►    │       TLS termination + WAF          │
    ionix.dev.vpp.eneco.com   │       Pass-through to backend       │
                              └───────────────┬─────────────────────┘
                                              │
                         ┌────────────────────▼──────────────────────┐
                         │     NGINX Ingress Controller (in-cluster)  │
                         │     LoadBalancer IP: 50.85.91.121          │
                         │                                            │
                         │  Matches request by:                       │
                         │    1. Host header (ionix.dev.vpp.eneco.com)│
                         │    2. URL path (/api/activationmfrr/*)    │
                         │                                            │
                         │  Forwards to: Service activationmfrr:8080  │
                         │  PATH FORWARDED AS-IS (no rewrite!)        │
                         └────────────────────┬──────────────────────┘
                                              │
                         ┌────────────────────▼──────────────────────┐
                         │     Pod: activationmfrr (.NET Web API)     │
                         │     Port: 8080                             │
                         │                                            │
                         │  App PathBase: /api/activation-mfrr/       │
                         │  (note the HYPHEN ─────────────^)          │
                         │                                            │
                         │  Serves:                                   │
                         │    /api/activation-mfrr/swagger/index.html │
                         │    /api/activation-mfrr/healthz            │
                         │    /api/activation-mfrr/readiness          │
                         │    /api/activation-mfrr/v1/...             │
                         │                                            │
                         │  Does NOT serve:                           │
                         │    /api/activationmfrr/swagger/index.html  │
                         │    /api/activationmfrr/healthz             │
                         │    (no hyphen = no match = 404)            │
                         └───────────────────────────────────────────┘
```

### The Broken Request Flow (what happens today)

```
Browser: GET /api/activationmfrr/swagger/index.html
         Host: ionix.dev.vpp.eneco.com
                          │
                          ▼
┌─── DNS ─────────────────────────────────────────────┐
│ ionix.dev.vpp.eneco.com → 20.76.210.221 (AGW)      │
│ ✅ DNS resolves correctly                            │
└─────────────────────────┬───────────────────────────┘
                          ▼
┌─── Azure Application Gateway ───────────────────────┐
│ Listener: *.dev.vpp.eneco.com:443                    │
│ TLS termination: ✅                                  │
│ WAF check: ✅                                        │
│ URL path map: no specific match for /api/activation* │
│ → forwards to default backend: ingress-controller    │
│ ✅ AGW forwards correctly                            │
└─────────────────────────┬───────────────────────────┘
                          ▼
┌─── NGINX Ingress Controller ────────────────────────┐
│ Ingress rule found:                                  │
│   host: ionix.dev.vpp.eneco.com                      │
│   path: /api/activationmfrr/  (NO HYPHEN)           │
│   pathType: Prefix                                   │
│   backend: activationmfrr:8080                       │
│                                                      │
│ MATCH! Path starts with /api/activationmfrr/         │
│                                                      │
│ Forwards to pod WITH FULL PATH (no rewrite):         │
│   → /api/activationmfrr/swagger/index.html           │
│ ✅ NGINX routes correctly (per its config)           │
└─────────────────────────┬───────────────────────────┘
                          ▼
┌─── Pod: activationmfrr ─────────────────────────────┐
│ Receives: GET /api/activationmfrr/swagger/index.html │
│                                                      │
│ ASP.NET routing middleware checks:                   │
│   PathBase = "/api/activation-mfrr/"  (WITH HYPHEN)  │
│                                                      │
│   Does "/api/activationmfrr/..." start with          │
│        "/api/activation-mfrr/"?                      │
│                                                      │
│   "activationmfrr" ≠ "activation-mfrr"               │
│                                                      │
│   ❌ NO MATCH → 404 Not Found                        │
│   (Content-Length: 0, empty ASP.NET Kestrel response)│
└──────────────────────────────────────────────────────┘
```

### The Working Request Flow (AFTER THE FIX — predicted, not yet verified)

> **Note**: This flow is NOT exercised today because no NGINX ingress rule matches `/api/activation-mfrr/`. Currently, requests to this path fall through to the VPP frontend SPA catch-all. After the fix, NGINX will have an ingress rule for `/api/activation-mfrr/` and this flow will become active.

```
Browser: GET /api/activation-mfrr/swagger/index.html     ← note the HYPHEN
         Host: ionix.dev.vpp.eneco.com
                          │
                          ▼
┌─── NGINX Ingress Controller ────────────────────────┐
│ Ingress rule (AFTER FIX):                            │
│   host: ionix.dev.vpp.eneco.com                      │
│   path: /api/activation-mfrr/  (WITH HYPHEN)        │
│   backend: activationmfrr:8080                       │
│                                                      │
│ MATCH! Forwards to pod WITH FULL PATH:               │
│   → /api/activation-mfrr/swagger/index.html          │
└─────────────────────────┬───────────────────────────┘
                          ▼
┌─── Pod: activationmfrr ─────────────────────────────┐
│ Receives: GET /api/activation-mfrr/swagger/index.html│
│                                                      │
│ ASP.NET routing middleware checks:                   │
│   PathBase = "/api/activation-mfrr/"                 │
│                                                      │
│   Does "/api/activation-mfrr/..." start with         │
│        "/api/activation-mfrr/"?                      │
│                                                      │
│   ✅ MATCH → strips PathBase → serves /swagger/...   │
│   → 200 OK with Swagger UI HTML                     │
│   (Response will have: Request-Context header,       │
│    x-swagger-ui-version, Content-Type with charset)  │
└──────────────────────────────────────────────────────┘
```

---

## 3. Root Cause — The Path Naming Inconsistency

### The Typo

| Environment | Routing Mechanism | Path | Has Hyphen? | Works? |
|-------------|------------------|------|-------------|--------|
| **Sandbox** (ionix FBE) | NGINX Ingress | `/api/activationmfrr/` | **NO** | **NO (404)** |
| Dev (main) | OpenShift Route | `/api/activation-mfrr` | YES | YES |
| Acc | OpenShift Route | `/api/activation-mfrr` | YES | YES |
| Prod | OpenShift Route | `/api/activation-mfrr` | YES | YES |

**Source**: `VPP-Configuration/Helm/activationmfrr/sandbox/values.yaml` line 84:
```yaml
        - path: /api/activationmfrr/    # ← WRONG: missing hyphen
```

### Live Proof (curl probes, 2026-04-13)

**404 responses — PROVES the request reaches the activationmfrr pod:**

| URL Path | HTTP Code | Headers | Proves |
|----------|-----------|---------|--------|
| `/api/activationmfrr/swagger/index.html` | **404** | `Request-Context: appId=...`, `x-correlation-id`, `Content-Length: 0` | Request reached the pod; app rejects non-hyphenated path |
| `/api/activationmfrr/healthz` | **404** | Same ASP.NET headers | Even health check fails at wrong path |
| `/api/activationmfrr/` | **404** | Same ASP.NET headers | Base path also rejected by app |

**200 responses — WARNING: These are the VPP frontend SPA catch-all, NOT the activationmfrr API:**

| URL Path | HTTP Code | Headers | What This Actually Is |
|----------|-----------|---------|----------------------|
| `/api/activation-mfrr/swagger/index.html` | **200** | `Content-Type: text/html`, `ETag`, `Accept-Ranges: bytes`, **NO** `Request-Context` | **SPA catch-all** — NGINX returns the Vue.js frontend for unmatched paths |
| `/api/activation-mfrr/healthz` | **200** | Same static file headers | **SPA catch-all** — NOT a health check response |
| `/api/activation-mfrr/readiness` | **200** | Same static file headers | **SPA catch-all** — NOT a readiness response |

> **Important**: The 200 at `/api/activation-mfrr/` does NOT prove the activationmfrr app serves at that path. It proves that NGINX has NO ingress rule for that path, so the request falls through to the default backend (VPP frontend SPA) which returns `index.html` for ALL unmatched routes. The SPA response has: `<title>Eneco Myriad VPP</title>`, Vue.js/Vuetify content, no `Request-Context` header, no `x-correlation-id`.

**Working service comparison — REAL API response:**

| URL Path | HTTP Code | Headers | Proves |
|----------|-----------|---------|--------|
| `/api/dispatchersimulator/` | **200** | `Request-Context`, `x-correlation-id`, `x-swagger-ui-version: 5.32.0`, `Transfer-Encoding: chunked` | This IS a real API response (note: dynamic content, ASP.NET headers present) |

**How we know the app's PathBase is `/api/activation-mfrr/`:**
The prod, acc, and dev values ALL configure the Route path as `/api/activation-mfrr` (with hyphen). These environments work correctly. The app's PathBase is set in the .NET application code to match this path.

### Why the 404 Comes from the App (Not NGINX or AGW)

The 404 response headers are:
```
HTTP/1.1 404 Not Found
Content-Length: 0
Request-Context: appId=cid-v1:af0f50ed-0246-41ed-92f8-6f1dd72f35ae
x-correlation-id: 6c952504-d6eb-4dfe-ac21-59dcda70ea96
```

- **No `Server` header**: NGINX always adds `Server: nginx/x.x.x`. AGW adds `Server: Microsoft-Azure-Application-Gateway/v2`. Neither is present.
- **`Content-Length: 0`**: Empty body. NGINX returns HTML error pages for its own 404s. ASP.NET Kestrel returns empty 404s by default.
- **`Request-Context` + `x-correlation-id`**: These are Application Insights SDK headers injected by the ASP.NET middleware — proving the request reached the .NET application.
- **Contrast with SPA**: The SPA catch-all 200 response has NONE of these ASP.NET headers — it's a static file served by NGINX directly.

---

## 4. Why It Matters — Understanding NGINX Path Forwarding

### Key Concept: NGINX Ingress Does NOT Rewrite Paths by Default

When an NGINX Ingress resource has:
```yaml
spec:
  rules:
    - host: ionix.dev.vpp.eneco.com
      http:
        paths:
          - path: /api/activationmfrr/
            pathType: Prefix
            backend:
              service:
                name: activationmfrr
                port:
                  name: http
```

NGINX uses the path for **matching** (deciding which backend to forward to), but it **forwards the FULL original path** to the backend. There is no path stripping or rewriting.

```
Request:  GET /api/activationmfrr/swagger/index.html
NGINX:    Matches /api/activationmfrr/ prefix? YES
          Forward to backend: GET /api/activationmfrr/swagger/index.html  ← FULL PATH
```

To rewrite paths, you need the annotation `nginx.ingress.kubernetes.io/rewrite-target`. But in this case, a rewrite isn't needed — we just need the path to match what the app expects.

---

## 5. Why Prod/Acc Work — OpenShift Routes vs NGINX Ingress

Prod and acc environments use a completely different routing mechanism:

```
Prod/Acc:  OpenShift Route → HAProxy → Pod
           path: /api/activation-mfrr  (WITH HYPHEN)
           
Sandbox:   NGINX Ingress → NGINX → Pod
           path: /api/activationmfrr/  (NO HYPHEN — the bug)
```

The prod/acc Route path (`/api/activation-mfrr`) matches the app's PathBase. That's why they work. The sandbox ingress path was created with a typo (missing hyphen) and was never caught because:
1. Sandbox and prod use different routing mechanisms
2. No automated test validates the ingress path matches the app's PathBase
3. The service appeared "Healthy" in ArgoCD (health probes use internal pod networking, bypassing the ingress entirely)

---

## 6. Why dispatchersimulator Works — Blazor PathBase vs Web API

The developer noticed that `dispatchersimulator` works while `activationmfrr` doesn't, despite both having the same NGINX ingress setup (no rewrite annotations, same template).

The difference is in the **application architecture**:

- **dispatchersimulator** is a **Blazor Server app** that's built with `<base href="/api/dispatchersimulator/">`. The entire app is designed to serve at this path prefix. All routes are relative to it.

- **activationmfrr** is a **.NET Web API** with PathBase `/api/activation-mfrr/`. It uses ASP.NET routing middleware that expects the EXACT PathBase string.

The dispatchersimulator's ingress path (`/api/dispatchersimulator`) matches its `<base href>`. The activationmfrr's ingress path (`/api/activationmfrr/`) does NOT match its PathBase (`/api/activation-mfrr/`).

---

## 7. Proposed Fix

### Change: `VPP-Configuration/Helm/activationmfrr/sandbox/values.yaml`

**Line 84**, change:
```yaml
        - path: /api/activationmfrr/
```
to:
```yaml
        - path: /api/activation-mfrr/
```

### Where to Make the Change
- **Repository**: `VPP-Configuration`
- **Branch**: `feature/fbe-778244_Activation-API-Monitoring` (the same branch the ArgoCD app tracks for `$values`)
- **File**: `Helm/activationmfrr/sandbox/values.yaml`
- **Line**: 84

### What Happens After the Fix
1. ArgoCD detects the change in VPP-Configuration branch
2. Auto-sync triggers (selfHeal: true, prune: true)
3. ArgoCD re-renders the Helm template with the corrected path
4. NGINX Ingress Controller picks up the updated Ingress resource
5. New requests to `/api/activation-mfrr/swagger/index.html` → NGINX matches → pod matches PathBase → 200

### New URL After Fix
```
https://ionix.dev.vpp.eneco.com/api/activation-mfrr/swagger/index.html
```
Note: The URL changes from `activationmfrr` to `activation-mfrr` (hyphen added).

---

## 8. Verification Commands

After applying the fix, run:

```bash
# 1. Verify the ingress path updated (via ArgoCD or kubectl if available)
# The ArgoCD UI should show the new path in the Ingress resource

# 2. Test the new URL — MUST check for ASP.NET headers, not just HTTP 200!
#    (A 200 without these headers means you're getting the SPA catch-all, not the API)
curl -svk "https://ionix.dev.vpp.eneco.com/api/activation-mfrr/swagger/index.html" 2>&1 \
  | grep -E "HTTP/|Request-Context|x-swagger-ui-version|x-correlation-id|Content-Type"
# Expected:
#   HTTP/1.1 200 OK
#   Content-Type: text/html;charset=utf-8    ← note charset (not just text/html)
#   Request-Context: appId=cid-v1:...        ← MUST be present (proves it's the API)
#   x-correlation-id: ...                     ← MUST be present
#   x-swagger-ui-version: 5.32.0            ← MUST be present (proves it's Swagger)

# 3. Test health endpoint — same header check
curl -svk "https://ionix.dev.vpp.eneco.com/api/activation-mfrr/healthz" 2>&1 \
  | grep -E "HTTP/|Request-Context|Content-Type"
# Expected: HTTP 200 WITH Request-Context header

# 4. DANGER CHECK — if you get this, the fix did NOT work:
#    200 with Content-Type: text/html (no charset), ETag, Accept-Ranges: bytes,
#    and NO Request-Context header = you're hitting the SPA catch-all
```

> **Warning**: Do NOT rely on HTTP 200 alone to confirm the fix works. The VPP frontend SPA returns 200 for ALL unmatched paths. You MUST verify the response contains ASP.NET headers (`Request-Context`, `x-correlation-id`, `x-swagger-ui-version`) to confirm the request actually reached the activationmfrr pod.

---

## 9. Mental Model — How to Debug "ArgoCD Healthy but Endpoint Unreachable"

When ArgoCD shows Healthy+Synced but the endpoint doesn't work, follow this decision tree:

```
1. Is DNS resolving correctly?
   └─ dig <hostname> → should point to LB/AGW IP
   
2. Is the connection establishing?
   └─ curl -sv <url> → check for TLS errors or connection refused
   
3. What HTTP status do you get?
   ├─ Connection refused → Service/LB not listening
   ├─ 502/503 → Backend unhealthy (check pods)
   ├─ 404 → Path routing issue (THIS CASE)
   └─ 200 → Working
   
4. WHERE does the 404 come from?
   ├─ Check response headers:
   │   ├─ Server: nginx/x.x.x → NGINX can't find backend
   │   ├─ Server: Microsoft-Azure-Application-Gateway → AGW routing issue
   │   └─ Request-Context + Content-Length: 0 → App received request but no route match
   │
   └─ If it's the APP returning 404:
      
5. Does the ingress path match the app's PathBase?
   ├─ Check ingress: kubectl get ingress -n <ns> -o yaml → spec.rules[].http.paths[].path
   ├─ Check app PathBase: compare with prod/acc Route path
   ├─ Test: curl with different path variations (hyphens, slashes, casing)
   └─ MISMATCH? → Fix the ingress path to match the app
   
6. Why didn't ArgoCD catch it?
   └─ Health probes (liveness/readiness) use POD-INTERNAL networking
      (port-forward to localhost:8080/healthz), NOT the ingress path.
      The pod is healthy but the ingress path is wrong.
```

### Key Takeaway
**ArgoCD "Healthy" only means the pod's health probes pass. It does NOT validate the end-to-end network path through DNS → AGW → Ingress → Service → Pod.** A path typo in the ingress configuration can make the endpoint unreachable while ArgoCD shows everything green.

---

## 10. The SPA Catch-All Trap

A dangerous pattern exists in this cluster: the VPP frontend SPA is configured as a catch-all that returns `index.html` (HTTP 200) for ANY path that doesn't match a specific NGINX ingress rule. This means:

```
GET /literally/any/path/that/doesnt/match → 200 OK (SPA HTML)
```

**Why this is dangerous:**
1. **Masks routing failures**: If an ingress rule is deleted or misconfigured, the SPA catch-all silently absorbs the traffic and returns 200. Monitoring that checks HTTP status codes will report "healthy" when the API is actually unreachable.
2. **Confuses debugging**: During this investigation, the 200 response at `/api/activation-mfrr/` was initially interpreted as "the API works at this path." It took adversarial analysis to discover it was the SPA catch-all.
3. **False positive verification**: After applying fixes, a naive `curl` check for HTTP 200 might confirm "success" when the fix actually didn't work.

**Mitigation**: Always verify API responses by checking for ASP.NET-specific headers (`Request-Context`, `x-correlation-id`, `x-swagger-ui-version`) rather than relying on HTTP status codes alone.

---

## 11. Configuration Debt — Sandbox vs Production Routing

The sandbox environment uses a fundamentally different routing mechanism than production:

| Aspect | Sandbox | Dev/Acc/Prod |
|--------|---------|-------------|
| Routing mechanism | NGINX Ingress | OpenShift Route |
| Path | `/api/activationmfrr/` (typo) | `/api/activation-mfrr` |
| Host | `dev.vpp.eneco.com` + prefix | `dev-mc.vpp.eneco.com` / `acc.vpp.eneco.com` / `vpp.eneco.com` |
| TLS | Handled by AGW | Handled by Route |

This structural divergence means the sandbox is not a faithful replica of production routing. Path bugs in sandbox may not reproduce in prod and vice versa. Consider tracking this as technical debt.
