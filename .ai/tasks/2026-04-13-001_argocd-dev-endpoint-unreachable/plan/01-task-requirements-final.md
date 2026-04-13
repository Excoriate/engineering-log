---
task_id: 2026-04-13-001
agent: coordinator
status: draft
summary: "Final requirements — ArgoCD dev endpoint unreachable (activationmfrr)"
---

# Task Requirements — Final

## Problem Statement

VPP developer cannot reach `https://ionix.dev.vpp.eneco.com/api/activationmfrr/swagger/index.html`. ArgoCD shows Synced+Healthy but orange network lines indicate traffic path failure.

## Key Changes from Initial

1. **NEW**: `route.yaml` exists alongside `ingress.yaml` in helm templates — OpenShift Route might be the primary traffic path, not NGINX Ingress alone
2. **NEW**: 4 local repos provide full comparison data (activationmfrr vs dispatchersimulator, sandbox vs prod values)
3. **REFINED H1**: "Missing rewrite rule" may be on Route object, not just NGINX annotation
4. **ADDED**: Branch `feature/opswork/rewrite-rule` in MC-VPP-Infrastructure is a named pointer — must be probed

## Competing Hypotheses (refined)

### H1: Missing rewrite/path-rewrite annotation on Ingress or Route (PRIMARY)
- The ingress or route for activationmfrr in sandbox/dev lacks a path rewrite that exists in prod/acc
- Without rewrite, requests to `/api/activationmfrr/swagger/index.html` arrive at the pod with that full path, but the .NET app serves Swagger at `/swagger/index.html` (stripped prefix)
- **Elimination**: Compare ingress/route templates and values across envs; if rewrite exists in prod but not sandbox, confirmed
- **Supporting evidence**: [FACT] Colleague: "no rewrite rule on dev, there is one in prod/acc"

### H2: DNS misconfiguration
- `ionix.dev.vpp.eneco.com` doesn't resolve to 50.85.91.121
- **Elimination**: `dig` query; if resolves correctly, eliminated
- **Supporting evidence**: [INFER] Less likely given colleague identified rewrite as the issue

### H3: Ingress template conditional excludes annotations for feature branch envs
- The template might use `if` conditions that skip rewrite annotations for sandbox/feature-branch environments
- **Elimination**: Read the template; if conditionals exist, confirmed
- **Supporting evidence**: [INFER] Feature branch envs often have different value sets

### H4: TLS termination mismatch
- URL uses HTTPS but ingress may lack TLS config for this host
- **Elimination**: Check if TLS is configured at ingress controller level (wildcard cert) or per-ingress
- **Supporting evidence**: [FACT] Ingress YAML has no TLS block; ArgoCD URL shows http://

## Verification Strategy

### Acceptance Criteria
1. Root cause identified with FACT-level evidence from at least 2 sources (code + comparison)
2. Proposed fix with specific file/line changes
3. Explain WHY the mechanism causes the failure (not just WHAT is wrong)

### Verify-How
1. Compare ingress.yaml template for activationmfrr vs dispatchersimulator (working)
2. Compare values files: sandbox vs prod/acc for rewrite-related keys
3. DNS probe: `dig ionix.dev.vpp.eneco.com`
4. HTTP probe: `curl -v https://ionix.dev.vpp.eneco.com/api/activationmfrr/swagger/index.html`
5. If cluster commands needed: provide compiled kubectl commands for user

### Who-Verifies
- Coordinator + parallel sherlock-holmes investigation
- el-demoledor + sre-maniac for adversarial verification of root cause
