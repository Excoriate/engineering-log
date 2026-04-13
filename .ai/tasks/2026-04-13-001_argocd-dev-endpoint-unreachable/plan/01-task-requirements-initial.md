---
task_id: 2026-04-13-001
agent: coordinator
status: draft
summary: "Initial requirements for ArgoCD dev endpoint unreachable incident"
---

# Task Requirements — Initial

## Problem Statement

VPP developer (Tiago) cannot reach `https://ionix.dev.vpp.eneco.com/api/activationmfrr/swagger/index.html` despite ArgoCD showing the `activationmfrr` application as Synced and Healthy in namespace `ionix` on the dev cluster.

## Key Evidence

1. ArgoCD network view shows **orange dashed lines** between endpoint (50.85.91.121) and ingress — indicates traffic path issue
2. Colleague states: "there is no rewrite rule on dev but there is one in prod/acc"
3. Ingress YAML has NO `nginx.ingress.kubernetes.io/rewrite-target` annotation
4. A branch `feature/opswork/rewrite-rule` exists in MC-VPP-Infrastructure (not yet merged/applied)
5. Working services (e.g., dispatchersimulator) show blue lines in ArgoCD — this one shows orange

## Competing Hypotheses

### H1: Missing NGINX rewrite-target annotation (PRIMARY)
The ingress lacks `nginx.ingress.kubernetes.io/rewrite-target` annotation. Requests to `/api/activationmfrr/...` are forwarded to the backend with the full path, but the app serves at a different base path. Prod/acc have this annotation; dev does not.
- **Elimination**: If ingress in prod/acc has the annotation AND adding it to dev resolves the issue
- **Supporting evidence**: [FACT] Colleague statement about missing rewrite rule on dev; [FACT] Ingress YAML shows no rewrite annotation

### H2: DNS misconfiguration
`ionix.dev.vpp.eneco.com` doesn't resolve to the LB IP `50.85.91.121`
- **Elimination**: `dig ionix.dev.vpp.eneco.com` shows different IP or NXDOMAIN
- **Supporting evidence**: [INFER] Endpoint unreachable could be DNS, but colleague's rewrite comment suggests path-level issue

### H3: Firewall/NSG blocking external traffic
Traffic blocked at Azure NSG/firewall level between client and LB IP
- **Elimination**: TCP connect to 50.85.91.121:443 fails
- **Supporting evidence**: [SPEC] No evidence yet — standard troubleshooting hypothesis

### H4: TLS not configured on ingress
URL uses HTTPS but ingress has no TLS section — could cause connection reset
- **Elimination**: Ingress has no `tls:` block, AND other working services DO have TLS configured differently
- **Supporting evidence**: [FACT] Ingress YAML has no TLS configuration; ArgoCD URL shows `http://` not `https://`

## Counterfactual

If not investigated: developer remains blocked on QA testing of feature branch `feature/fbe-778244_Activation-API-Monitoring`. Feature delivery delayed. Escalation to platform team Monday.

## Requirements

1. Confirm root cause with evidence
2. Produce proposed fix (commands or config changes)
3. Provide only strictly necessary cluster commands for user to execute (no cluster access available)
