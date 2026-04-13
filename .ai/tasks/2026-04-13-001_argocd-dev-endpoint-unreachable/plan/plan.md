---
task_id: 2026-04-13-001
agent: coordinator
status: draft
summary: "Plan for root cause analysis deliverable and proposed fix for activationmfrr endpoint 404"
---

# Plan — ArgoCD Dev Endpoint Unreachable

## Objective
Deliver a confirmed root cause analysis with holistic explanation (what/why/how with visual aids) and a proposed fix for the activationmfrr 404 issue.

## Acceptance Criteria
1. Root cause explanation with >=3 FACT-level evidence sources
2. Visual diagram showing the request flow (working vs broken)
3. Explanation deep enough to teach the mental model for future debugging
4. Proposed fix with specific file + line changes
5. Adversarial review passed (sre-maniac + el-demoledor)

## Verified Root Cause (FACT)
**PATH NAMING INCONSISTENCY**: The sandbox NGINX ingress uses path `/api/activationmfrr/` (no hyphen) but the .NET app serves at PathBase `/api/activation-mfrr/` (with hyphen). NGINX forwards the non-hyphenated path to the pod; the app doesn't match and returns 404.

### Evidence Summary
| Probe | Path | Result | Interpretation |
|-------|------|--------|---------------|
| curl | `/api/activationmfrr/swagger/index.html` | 404 | App doesn't serve at non-hyphenated path |
| curl | `/api/activation-mfrr/swagger/index.html` | **200** | App DOES serve at hyphenated path |
| curl | `/api/activation-mfrr/healthz` | **200** | Health endpoint confirms PathBase |
| curl | `/api/activation-mfrr/readiness` | **200** | Readiness also confirms PathBase |
| curl | `/api/activationmfrr/healthz` | 404 | Health fails at wrong path too |
| curl | `/api/dispatchersimulator/` | **200** | Working service for comparison |

## verify-strategy
Reconciled with Phase 3 blind strategy:
1. ✅ Compare ingress templates — DONE (identical, not the issue)
2. ✅ Compare values across envs — DONE (path mismatch found)
3. ✅ DNS probe — DONE (works correctly, eliminated H2)
4. ✅ HTTP probe — DONE (404 vs 200, confirmed root cause)
5. ✅ Cluster commands — NOT NEEDED (root cause identified without cluster access)
Phase 3 criterion "explain WHY": preserved — full mechanism explanation required in deliverable.

## Steps

### Step 1: Write Root Cause Analysis
- Full what/why/how explanation with ASCII diagrams
- Request flow visualization (working vs broken)
- Mental model for future debugging
- Acceptance: document covers all 7 evidence sources
- Falsifier: if any FACT-level evidence contradicts the explanation, the analysis is wrong

### Step 2: Write Proposed Fix
- Specific file/line change in VPP-Configuration
- Commit description
- Verification instructions
- Acceptance: fix addresses the specific path mismatch
- Falsifier: if applying the fix wouldn't change the 404 to 200, the fix is wrong

### Step 3: Adversarial Review
- Synthesize sre-maniac and sherlock-holmes findings
- Deploy el-demoledor for final destruction attempt
- Accept/rebut/defer each finding
- Acceptance: all critical findings addressed
- Falsifier: if any unaddressed finding invalidates the root cause

### Step 4: Verify and Deliver
- Phase 8 verification of all claims
- Activation checklist
- Acceptance: all FACT claims re-verified

## Adversarial Challenge

### Phase 4 Canonical Failures Addressed
1. "No rewrite rule on dev" — ADDRESSED: the colleague was right about a path issue, but the specific mechanism is a typo (missing hyphen), not a missing NGINX annotation or AGW rewrite rule
2. "Feature branch environment different from main" — ADDRESSED: sandbox values have the typo; prod/acc/dev values are correct

### Phase 1 Surviving Hypotheses
- H1 (path-level): CONFIRMED (refined — it's a naming inconsistency, not a missing rewrite)
- H2 (DNS): ELIMINATED (DNS works correctly)
- H3 (conditional template): ELIMINATED (templates are identical)
- H4 (TLS): ELIMINATED (TLS works, curl gets responses)

### Adversarial Questions
1. **Assumption**: The 200 at `/api/activation-mfrr/` comes from the activationmfrr pod
   - **Failure mode**: Could be from a different pod/service
   - **Evidence**: Swagger HTML content matches an activation API service; would need kubectl to 100% confirm
   
2. **Simplest alternative**: Could the app be configured to serve at BOTH paths?
   - **Disproof**: If it served at both, the non-hyphenated path would also return 200. It returns 404.

3. **Disproving evidence**: If the hypothesis is wrong, we'd observe the hyphenated path also returning 404, or the non-hyphenated path returning 200. Neither is the case.

4. **Hidden complexity**: Changing the ingress path means the ArgoCD-generated URL will also change. The developer needs to know the new URL uses the hyphen.

5. **Version/existence probe**: The sandbox values file EXISTS and CONTAINS the non-hyphenated path (READ-5 confirmed). EXECUTED.

6. **Silent failure (Q6)**: How could the fix pass all verification but be wrong?
   - If the VPP-Configuration repo is on a different branch than what ArgoCD reads
   - If ArgoCD's valuesObject override takes precedence and somehow forces the non-hyphenated path
   - If the NGINX ingress controller treats paths with hyphens differently
   - Mitigation: verify by checking ArgoCD sync after fix; curl the new path
