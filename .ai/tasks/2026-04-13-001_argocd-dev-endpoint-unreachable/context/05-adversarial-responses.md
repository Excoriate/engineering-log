---
task_id: 2026-04-13-001
agent: coordinator
status: draft
summary: "Coordinator responses to adversarial findings from sre-maniac"
---

# Adversarial Finding Responses

## SRE-Maniac Findings

### Finding 1: 200 at /api/activation-mfrr/ is SPA catch-all, not the API
**ACCEPTED** — Critical correction. The SRE proved the 200 response is the VPP frontend SPA returning index.html for unmatched routes (evidence: no Request-Context header, static ETag, Vue.js HTML body). RCA updated to correct the evidence table and add explicit SPA catch-all warning.

### Finding 2: Fix is correct but evidence interpretation was wrong
**ACCEPTED** — The root cause (path mismatch) is confirmed. The evidence that the 404 comes from the app is solid (Request-Context + x-correlation-id headers). The evidence that the app's PathBase is `/api/activation-mfrr/` comes from prod/acc/dev values files, not from the (incorrectly interpreted) 200 response. RCA updated.

### Finding 3: AGW has no explicit path rule for activation-mfrr in dev
**ACCEPTED** — The AGW uses default backend for unmatched paths, which is the NGINX ingress controller. This means the fix (changing the NGINX ingress path) is sufficient without AGW changes. Noted as configuration hygiene debt.

### Finding 4: SPA catch-all is dangerous silent failure mode
**ACCEPTED** — Added section 10 to RCA about the SPA catch-all trap. Updated verification commands to require ASP.NET header checks, not just HTTP 200.

### Finding 5: Sandbox uses different routing mechanism (ingress vs route)
**ACCEPTED** — Added section 11 to RCA about configuration debt. This structural divergence is the root cause of why the typo exists — the sandbox path was configured separately from prod/acc/dev and didn't go through the same review process.

### Finding 6: AppId comparison was invalid
**ACCEPTED** — The 200 response has no Request-Context header at all (SPA), so comparing appIds between the 404 and 200 was comparing different things. RCA updated to remove misleading appId comparison.

### Finding 7: Health monitoring should check response body
**ACCEPTED** — Added to recommendations. A 200 from the SPA is indistinguishable from a healthy API response by HTTP status code alone.

## Sherlock-Holmes Findings

### Finding 1: Reproduced 100% failure rate — path mismatch confirmed
**ACCEPTED** — Independent reproduction with test matrix confirms deterministic failure.

### Finding 2: False positive identified — SPA catch-all
**ACCEPTED** — Converges with SRE-maniac finding. Real Swagger is 735 bytes; SPA is 1893 bytes.

### Finding 3: AGW uses Basic routing (no rewrites)
**ACCEPTED** — Confirms AGW is pure pass-through, no infrastructure changes needed.

### Finding 4: Frontend ingress at path `/` catches unmatched
**ACCEPTED** — Identified the specific ingress resource causing the catch-all behavior.

## El-Demoledor Findings

### V1: 200 at hyphenated path is SPA catch-all — EVIDENCE WRONG
**ACCEPTED** — Same finding as SRE-maniac and Sherlock. Six paths return identical response (same ETag, same Content-Length). RCA evidence table already corrected.

### V2: Verification commands will report false success
**ACCEPTED** — RCA Section 8 already updated with header-check verification commands. Post-fix verification MUST check for Request-Context, x-swagger-ui-version headers, not just HTTP 200.

### SW4 Pre-Mortem: Fix that looked like it worked
**ACCEPTED** — This is the most dangerous scenario. Added explicit warning in Section 8 of the RCA.

## Summary
All findings from all 3 agents ACCEPTED. RCA document updated with all corrections. Zero findings deferred.

## Agent Convergence
All three independent agents (SRE-maniac, Sherlock-Holmes, El-Demoledor) independently identified:
1. Root cause: path typo (confirmed)
2. SPA catch-all masking (confirmed)
3. Verification commands need content checks (confirmed)
This triple-convergence provides high confidence in the analysis.
