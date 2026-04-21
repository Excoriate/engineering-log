---
task_id: 2026-04-21-001
agent: claude-code
status: partial
summary: Initial requirements — diagnose Erik Lumbela's ArgoCD Sandbox access gap for flex-trade-optimizer; cross-check against his landed Eneco.Infrastructure AAD PR.
---

# Task — Erik Lumbela ArgoCD Sandbox access (flex-trade-optimizer)

## Pre-flight mirror

- Phase: 1 | Brain: 67.0.0 | task_id: 2026-04-21-001
- Request: Troubleshoot Erik Lumbela's ArgoCD Sandbox access to `flex-trade-optimizer` project (Dev/Acc work). User suspects PR in `Eneco.Infrastructure` (AAD) resolved it; wants cross-check and a complete, fully verified diagnosis and fix steps.
- DOMAIN-CLASS: investigation
- ROOT-ARTIFACT: n
- CRUBVG: C=1 / R=0 / U=2 / B=1 / V=1 / G=2 = 7 +1 (G≥1) = **8**
  - C=1 [MID because AAD group ↔ ArgoCD SSO OIDC claims ↔ ArgoCD RBAC policy ↔ k8s namespace couple three systems]
  - R=0 [ZERO evidence="diagnosis is read-only; remediation is additive group membership / RBAC edit, reversible"]
  - U=2 [HIGH because MECHANISM='AAD→ArgoCD authorization path' produces FAILURE 'user in wrong/missing group' under CONDITION 'sandbox-only project not covered by PR'; current runtime state of membership and policy unknown]
  - B=1 [MID because one user, one environment, sandbox — not production]
  - V=1 [MID because kubectl+argocd+az CLI available; Slack + MCPs for evidence; some claims require user-session simulation which coordinator can't perform as Erik]
  - G=2 [HIGH because conflicting signals: user says "suspect solved via PR", slack intake says "no access"; PR link not yet known; must reconcile]
- Triggers:
  - LIBRARIAN: n (no external versioned libraries)
  - CONTRARIAN: y (CRUBVG≥5; dispatch socrates-contrarian before delivery)
  - EVALUATOR: y (CRUBVG≥4; dispatched evaluator grades final diagnosis)
  - DOMAIN: y — eneco-oncall-intake-slack, eneco-oncall-intake-enrich, eneco-platform-aad, eneco-context-repos, eneco-context-slack, eneco-tools-rootly (if alert), eneco-context-docs
  - TOOLS: y — kubectl (sandbox), argocd CLI, az CLI (sandbox), gh/az-repos for PR inspection
- BRAIN SCAN:
  - Most dangerous assumption: "the PR landed therefore access works" — PR merge ≠ Terraform apply ≠ AAD group membership propagation ≠ ArgoCD RBAC binding ≠ user session refresh.
  - Most likely failure: user's AAD group for sandbox-specific access was either (a) not created by the PR, (b) created but he's not a member, (c) ArgoCD sandbox `argocd-rbac-cm` policy doesn't map that group to project role, or (d) SSO token cached/stale and a fresh login is required.

## Intake (source: slack-antecedents.txt)

Slack list record: `https://eneco-online.slack.com/lists/T039G7V20/F0ACUPDV7HU?record_id=Rec0AUE5HU5MJ`

> I don't have access to flex-trade-optimizer project in ARGO sandbox environment. I do have it for Dev/acc.

## Acceptance criteria (initial)

1. Verified statement: is Erik's access currently working in Sandbox for `flex-trade-optimizer`? FACT-level (externally witnessable via ArgoCD API or direct kubectl probe).
2. Verified root cause (depth ≥2) if still broken OR verified resolution evidence if already fixed.
3. Reconciled against the Eneco.Infrastructure AAD PR — PR id, changed files, applied state, runtime effect.
4. If broken: step-by-step fix (who changes what, in which repo, with expected apply + propagation time).
5. Falsifier list + evidence in Phase 8 verification.

## Hypotheses (keep ≥2)

- **H1 (leader)**: AAD group `sg-eneco-argocd-sandbox-fto-*` (or equivalent) missing Erik as member — PR may have created the group but not added him.
- **H2**: ArgoCD sandbox `argocd-rbac-cm` ConfigMap lacks a policy mapping the (existing) group to the `flex-trade-optimizer` project role — PR fixed AAD only, not gitops.
- **H3**: PR fully resolved the issue but Erik's SSO session has a cached token without the new group claim — needs re-login.
- **H4**: The flex-trade-optimizer project in ArgoCD sandbox doesn't exist (env not deployed) — different class of bug, treat sandbox access as red herring.
- **H5 (orthogonal/hidden-variable)**: Sandbox uses a different AAD tenant or OIDC app registration than Dev/Acc; PR only touched the Dev/Acc tenant.

## Constraints

- Read-only probes only on shared infra (no `kubectl edit`, no `argocd proj role add`).
- Must use eneco-oncall-intake-slack then eneco-oncall-intake-enrich skills as directed.
- User has kubectl sandbox + argocd access.
- All load-bearing claims classified A1–A4 at decision points.
- Adversarial externalized to Adversary Roster; never self-adversarial.

## Counterfactual (P1)

If not done: Erik remains blocked on sandbox work; FTO iteration cycle slows; nobody has verified the PR actually closes the loop end-to-end (AAD→ArgoCD→namespace); on-call fails to build a reusable runbook for similar "landed PR did it really work?" patterns.
