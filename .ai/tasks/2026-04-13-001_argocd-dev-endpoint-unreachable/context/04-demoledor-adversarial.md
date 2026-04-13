---
task_id: "2026-04-13-001"
agent: el-demoledor
status: complete
summary: "Root cause CONFIRMED with corrections: the path typo is real but the RCA's key evidence is wrong -- the 200 at /api/activation-mfrr/ is a default-backend SPA catch-all, NOT the activationmfrr service responding. Fix direction is correct. One CRITICAL correction to the RCA and one secondary finding."
---

# DEMOLEDOR REPORT

**Target**: Root Cause Analysis for activationmfrr 404 (file: `outcome/root-cause-analysis.md`)
**Scope**: Full (20 min)
**Time Invested**: 20 minutes

## DESTRUCTION SUMMARY

| Metric | Count |
|--------|-------|
| Vulnerabilities in the RCA | 2 |
| -- EXPLOIT-VERIFIED | 2 |
| -- PATTERN-MATCHED | 0 |
| -- THEORETICAL | 0 |
| Root Cause Correct? | YES -- but with WRONG evidence |
| Fix Direction Correct? | YES -- with caveat (see V1) |
| Total Blast Radius | RCA credibility; post-fix verification will give WRONG results |

---

## CRITICAL VULNERABILITIES IN THE ROOT CAUSE ANALYSIS

### V1: The "200 at hyphenated path" is NOT from the activationmfrr service -- EVIDENCE IS WRONG [EXPLOIT-VERIFIED]

| Attribute | Value |
|-----------|-------|
| **Exploit** | The RCA claims `/api/activation-mfrr/swagger/index.html` returns 200 from the activationmfrr pod, proving the app serves at the hyphenated path. This is FALSE. The 200 comes from a **default-backend Vue.js SPA catch-all**, not from the activationmfrr .NET service. |
| **Payload** | Every path that does NOT match any NGINX ingress rule returns the same response. |
| **Trigger** | Requesting any unmatched path on `ionix.dev.vpp.eneco.com` |
| **Effect** | The RCA's primary evidence table (Section 3, "Live Proof") is built on false positives. The "200" entries do not prove the app serves at the hyphenated path -- they prove the SPA catches everything that doesn't match a specific ingress rule. |
| **Blast Radius** | Post-fix verification commands in Section 8 will report success prematurely. After the fix, you MUST verify using response CONTENT and HEADERS, not just HTTP status codes. |
| **Reproduction** | See proof chain below |
| **Severity Gate** | Exploitability: HIGH (trivially demonstrated) x Impact: HIGH (entire evidence chain is compromised) x Confidence: HIGH (EXPLOIT-VERIFIED) = **CRITICAL** |

**PROOF CHAIN (all probes executed 2026-04-13T05:14Z)**:

The following requests ALL return the IDENTICAL response:

| Request Path | HTTP Code | Content-Type | Size | ETag |
|---|---|---|---|---|
| `/api/activation-mfrr/swagger/index.html` | 200 | `text/html` | 1893 | `"69d65106-765"` |
| `/api/activation-mfrr/healthz` | 200 | `text/html` | 1893 | `"69d65106-765"` |
| `/api/activation-mfrr/readiness` | 200 | `text/html` | 1893 | `"69d65106-765"` |
| `/api/activation-mfrr/` | 200 | `text/html` | 1893 | `"69d65106-765"` |
| `/nonexistent/path/` | 200 | `text/html` | 1893 | `"69d65106-765"` |
| `/totally/random/garbage/path/xyz123` | 200 | `text/html` | 1893 | `"69d65106-765"` |
| `/` | 200 | `text/html` | 1893 | `"69d65106-765"` |

All return the same Vue.js SPA shell:
```html
<title>Eneco Myriad VPP</title>
<script type="module" crossorigin src="/static-assets/index-Bezc7498.js"></script>
```

**Contrast with a REAL service (dispatchersimulator)**:

| Request Path | HTTP Code | Content-Type | Size | ETag |
|---|---|---|---|---|
| `/api/dispatchersimulator/` | 200 | `text/html; charset=utf-8` | chunked | none |
| `/api/dispatchersimulator/healthz` | 200 | `application/json` | 256 | none |

The dispatchersimulator returns `application/json` for healthz with actual health data:
```json
{"status":"Healthy","totalDuration":"00:00:00.0077624","entries":{"self":{...},"azure-storage-check":{...}}}
```

The `/api/activation-mfrr/healthz` returns the same `text/html` 1893-byte Vue SPA. This is NOT a health check response from a .NET service. This is the NGINX default backend serving its catch-all SPA for any unmatched path.

**Why this matters**: The RCA states "App DOES serve at hyphenated path" in Section 3. It does not. No NGINX ingress rule matches `/api/activation-mfrr/` because the only ingress rule for this service uses `/api/activationmfrr/` (no hyphen). Requests to the hyphenated path fall through to the default backend. The fix (changing the ingress path to `/api/activation-mfrr/`) will route traffic to the pod, which SHOULD then serve correctly -- but this has NOT been proven by the current evidence.

**Counter-hypothesis**: "The 200 at the hyphenated path genuinely comes from the activationmfrr pod, proving the app serves at that PathBase." REFUTED. The response body is a Vue.js SPA (title: "Eneco Myriad VPP"), not a .NET Swagger page or health endpoint. The Content-Type is `text/html` without charset (NGINX static file), not `text/html; charset=utf-8` (.NET Kestrel) or `application/json` (health endpoint). The ETag is identical across ALL unmatched paths. The `Content-Length: 1893` with `Last-Modified: Wed, 08 Apr 2026` is consistent with a static `index.html` from the frontend service, not a dynamically-generated .NET response.

---

### V2: Verification Commands Will Report False Success [EXPLOIT-VERIFIED]

| Attribute | Value |
|-----------|-------|
| **Exploit** | Section 8 "Verification Commands" uses `curl ... -w "HTTP_CODE:%{http_code}"` to check the fix. After the fix, if NGINX routes to the pod and the pod serves correctly, this works. But if the fix DOESN'T work (e.g., different issue), the default backend will STILL return 200, and the verification will pass anyway, masking a continued failure. |
| **Payload** | Run the verification commands against ANY path (even `/api/does-not-exist/swagger/index.html`) and they return `HTTP_CODE:200`. |
| **Trigger** | Running the verification commands from Section 8 |
| **Effect** | False confidence that the fix worked |
| **Blast Radius** | Fix could be incomplete and verification would not catch it |
| **Reproduction** | `curl -skL -o /dev/null -w "HTTP_CODE:%{http_code}\n" "https://ionix.dev.vpp.eneco.com/api/activation-mfrr/swagger/index.html"` returns `HTTP_CODE:200` RIGHT NOW, before any fix is applied. |
| **Severity Gate** | Exploitability: HIGH x Impact: MED (verification gap, not direct failure) x Confidence: HIGH = **HIGH** |

**Counter-hypothesis**: "The verification commands are sufficient because the old URL check (step 4) would distinguish." Partially valid -- after the fix, step 4 checks the old non-hyphenated URL and expects a 404 "from NGINX, not the app." But that distinction requires examining headers, which the `-o /dev/null` flag discards. The non-hyphenated path currently returns a Kestrel 404 (with `Request-Context` + `x-correlation-id`). After the fix removes the `/api/activationmfrr/` ingress path, the non-hyphenated path would indeed get the SPA catch-all 200 -- which would make step 4 FAIL (it expects 404 but gets 200). So step 4 would actually detect a WRONG state. I favor my finding because the POSITIVE checks (steps 2-3) are unreliable.

**Corrected verification commands**:
```bash
# After fix: verify CONTENT, not just status code
# Step 1: Check swagger returns JSON (not SPA HTML)
curl -sk "https://ionix.dev.vpp.eneco.com/api/activation-mfrr/swagger/v1/swagger.json" \
  -w "\nHTTP_CODE:%{http_code} CONTENT_TYPE:%{content_type}\n" | head -5
# Expected: HTTP_CODE:200 CONTENT_TYPE:application/json with swagger JSON body

# Step 2: Check healthz returns JSON health response
curl -sk "https://ionix.dev.vpp.eneco.com/api/activation-mfrr/healthz" \
  -w "\nHTTP_CODE:%{http_code} CONTENT_TYPE:%{content_type}\n"
# Expected: HTTP_CODE:200 CONTENT_TYPE:application/json with {"status":"Healthy",...}

# Step 3: Check response headers for .NET markers
curl -svk "https://ionix.dev.vpp.eneco.com/api/activation-mfrr/swagger/index.html" 2>&1 | grep -E "Request-Context|x-correlation-id|Content-Type"
# Expected: Request-Context header present (proves .NET app responded)
# Expected: Content-Type includes charset=utf-8 (Kestrel, not NGINX static)
```

---

## SPECULATIVE OBSERVATIONS (not counted in findings total)

### SO1: The health probes bypass the ingress entirely

The sandbox values.yaml health probes are configured as:
```yaml
startupProbe:
  httpGet:
    path: /healthz
    port: http
```

These probe `/healthz` directly on the pod's port (8080), NOT through the ingress path `/api/activation-mfrr/healthz`. The probes hit the pod via cluster-internal networking, so the path mismatch in the ingress is invisible to Kubernetes health checks. This is correctly identified in the RCA (Section 9) and is NOT a bug -- it's by design. But it means ArgoCD "Healthy" is genuinely meaningless for ingress validation, as stated.

### SO2: Host mismatch in values.yaml vs actual URL

All sandbox values.yaml files configure `host: dev.vpp.eneco.com` but the actual accessed URL uses `ionix.dev.vpp.eneco.com` (namespace prefix). The Helm chart template likely prepends the ArgoCD Application's namespace or uses a Helm values injection to construct the full hostname. This is NOT a finding -- it's how the sandbox isolation works. But it means the `host` in values.yaml is a template input, not the literal ingress host.

---

## ABSENCE AUDIT

| Missing Control | Impact When Needed |
|----------------|-------------------|
| Verification commands that check response CONTENT, not just HTTP status | False positive verification after fix (V2) |
| No automated test validating ingress path matches app PathBase | This exact bug class will recur for any new sandbox service |

---

## SUPERWEAPON DEPLOYMENT

| Superweapon | Finding |
|-------------|---------|
| SW1 Temporal Decay | N/A -- this is a static misconfiguration, not a time-dependent failure |
| SW2 Boundary Failure | FIRED -- V1. The boundary between "NGINX routes to pod" and "NGINX default backend catches unmatched" is invisible when checking only HTTP status codes. The RCA crossed this boundary without noticing. |
| SW3 Compound Fragility | FIRED -- the combination of (a) SPA catch-all returning 200 for everything + (b) status-code-only verification + (c) missing ingress rule for the hyphenated path compounds into a false evidence chain. |
| SW4 Pre-Mortem | See below |
| SW5 Uncomfortable Truth | The RCA's evidence table in Section 3 is wrong. Every "200" entry attributed to "App DOES serve at hyphenated path" is actually "Default backend SPA served for unmatched path." The conclusion (fix the hyphen) is still correct, but the reasoning path used to get there contains a critical false step. |

### SW4: Pre-Mortem -- The Fix That Looked Like It Worked

**THE SETUP**: Tuesday morning. The developer applies the one-line fix: change `/api/activationmfrr/` to `/api/activation-mfrr/` in `sandbox/values.yaml`. ArgoCD syncs. They run the verification commands from Section 8 of the RCA.

**THE TRIGGER**: The verification commands return `HTTP_CODE:200`. Developer declares success. But they don't check what's actually being served. There's a second issue -- maybe the Helm chart template doesn't process the sandbox differently from dev/acc, or the OCI chart version doesn't support ingress. The 200 they're seeing is still the SPA catch-all.

**THE DISCOVERY**: Two days later, a QA engineer tries to actually USE the API through the swagger UI. The swagger page loads the VPP SPA instead of the swagger interface. "I thought this was fixed?"

**THE ROOT CAUSE TODAY**: Section 8 verification commands use `-o /dev/null` which discards the response body, and check only the HTTP status code, which is 200 regardless of whether the fix worked because the SPA catch-all always returns 200 for unmatched paths.

---

## CASCADE CHAINS

```
V1 (wrong evidence) -> V2 (verification based on wrong evidence)
-> Developer applies fix, runs verification
-> Verification returns 200 (from SPA catch-all OR from actual fix)
-> CANNOT DISTINGUISH between "fix worked" and "fix had no effect"
-> Possible false confidence in fix
Circuit breaker: Check response CONTENT and HEADERS, not just status code
```

---

## ADVERSARIAL SELF-CHECK

### Self-Questioning Results

1. **Pattern-matching check**: V1 is NOT pattern-matching -- it is proven by comparing six identical responses (same ETag, same Content-Length, same body) across wildly different paths. A real .NET service would return different responses for `/healthz` (JSON) vs `/swagger/index.html` (HTML) vs `/nonexistent` (404). The identical response across all paths proves catch-all behavior.

2. **False positive check**: V1 is a false positive IF the activationmfrr .NET service happens to serve a Vue.js SPA with the exact title "Eneco Myriad VPP" at every endpoint including `/healthz`. This is not plausible -- the RCA itself describes the service as a ".NET Web API" returning empty 404s, not a Vue.js application.

3. **Redundancy check**: V1 and V2 share the root cause "SPA catch-all masks the true routing state." These are 1 root cause with 2 manifestations (wrong evidence + unreliable verification). I report them separately because they require separate remediation actions.

### Bias Scan

**Pattern-matching bias**: I initially considered whether the prod/dev `path: /api/activation-mfrr` (without trailing slash) vs sandbox `path: /api/activationmfrr/` (with trailing slash and without hyphen) constituted a second path-format issue. On examination, the trailing slash difference is between OpenShift Route (no trailing slash) and NGINX Ingress (trailing slash) syntax and is not independently meaningful. Kept focus on the core findings.

**Severity inflation check**: V1 rated CRITICAL because the entire evidence chain in the RCA is compromised. If the evidence table is wrong, the logical chain from "app serves at hyphenated path" to "therefore fix the ingress path" is unsupported. The conclusion happens to still be correct (the prod/acc values files confirm `/api/activation-mfrr` is the canonical path), but the argument in the RCA doesn't support it through the claimed evidence.

### Meta-Falsifier Results

- **V1 CONFIRMED**: The evidence is irrefutable. Six paths return identical responses. The response is a Vue.js SPA, not a .NET service. The ETag/Content-Length/Last-Modified are identical across all paths.
- **V2 CONFIRMED**: The verification commands demonstrably return 200 right now, before any fix. They cannot distinguish "fixed" from "still broken."

**Strongest argument against V1**: "The root cause conclusion is still correct, so does the evidence quality matter?" YES -- because (a) wrong evidence undermines credibility, (b) wrong evidence leads to wrong verification (V2), and (c) the ACTUAL evidence that the fix will work is the prod/acc values files showing `path: /api/activation-mfrr` at line 83, not the curl probes.

---

## ASSESSMENT OF THE ROOT CAUSE

### What the RCA gets RIGHT

1. **Root cause identification**: The path typo IS the root cause. Sandbox line 84 has `/api/activationmfrr/` while prod/acc/dev all have `/api/activation-mfrr`. This is confirmed by file evidence:
   - `prod/values.yaml:83: path: /api/activation-mfrr`
   - `acc/values.yaml:83: path: /api/activation-mfrr`
   - `dev/values.yaml:83: path: /api/activation-mfrr`
   - `sandbox/values.yaml:84: path: /api/activationmfrr/` (WRONG)

2. **Fix direction**: Changing line 84 to `/api/activation-mfrr/` is correct.

3. **404 source identification**: The 404 at `/api/activationmfrr/` does come from the .NET app (confirmed by `Request-Context` + `x-correlation-id` headers + `Content-Length: 0`). NGINX does route `/api/activationmfrr/*` to the pod. The pod rejects the path because its PathBase doesn't match.

4. **Architecture explanation**: Sections 4-6 (NGINX forwarding, OpenShift vs NGINX, dispatchersimulator comparison) are sound.

### What the RCA gets WRONG

1. **Section 3 "Live Proof" table**: The 200 entries are false positives from the SPA catch-all, not evidence that the app serves at the hyphenated path. The ACTUAL proof that the hyphenated path is correct comes from the prod/acc/dev values files, not from curl probes.

2. **Section 2 "Working Request Flow"**: States "Browser: GET /api/activation-mfrr/swagger/index.html ... Pod matches PathBase -> 200". This flow is NOT currently exercised because no NGINX ingress rule matches `/api/activation-mfrr/`. The request never reaches the pod -- it hits the default backend. This flow diagram is a PREDICTION of post-fix behavior, not a verified current state.

3. **Section 8 "Verification Commands"**: Will produce false positives due to SPA catch-all (see V2).

---

## VERDICT

**Vulnerabilities in the RCA**: 2 (2 EXPLOIT-VERIFIED, 0 PATTERN-MATCHED, 0 THEORETICAL)
**Root Cause**: CONFIRMED CORRECT (path typo is real, fix direction is sound)
**Evidence Quality**: COMPROMISED -- key "proof" entries are false positives from SPA catch-all
**Fix Assessment**: Will work, but verification commands need correction
**Recommendation**: CONDITIONAL ACCEPT -- apply fix, but use corrected verification commands that check response CONTENT (Content-Type, body) not just HTTP status code. Update Section 3 evidence table and Section 8 verification commands.

---

*El Demoledor: Proving resilience through destruction*
