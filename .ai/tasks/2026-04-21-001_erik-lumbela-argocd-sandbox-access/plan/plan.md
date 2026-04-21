---
task_id: 2026-04-21-001
agent: claude-code
status: complete
summary: Plan — deliver diagnosis + step-by-step remediation (re-login). Claim C3 verified. Adversarial challenge completed, one residual INFER named, Phase 8 falsifiers defined.
---

# Plan

## Objective

Produce an evidence-backed diagnosis, posted to Erik (or drafted for review), that states:
(a) the PR he opened today resolved the AAD side of the problem;
(b) the ArgoCD sandbox project binding means he IS authorized once his SSO session refreshes;
(c) exactly what he must do (sign out + back in); and
(d) the discriminating command to run if it still doesn't work.

## End state (backward chain)

1. **Terminal state**: Erik has ArgoCD sandbox access to `flex-trade-optimizer` AND a verified record of the diagnostic exists in this task directory for future on-call pattern-matching.
2. **Precondition**: Erik performs a sign-out + sign-in against sandbox ArgoCD → new OIDC ID token carries `groups` claim containing `036bd5f7-…-646d`.
3. **Precondition**: Erik is a member of `sg-vpp-flex-trade-optimizer-developers` in AAD — **done** (F6 confirmed).
4. **Precondition**: Sandbox ArgoCD's FTO AppProject has that group bound to `app-manager` role — **done** (F1 confirmed).
5. **Precondition**: PR 173958 merged + deployed — **done** (F5 confirmed, closed 17:58 CEST).

## Steps

### Step 1 — Verify this task's evidence ledger before acting

- **Objective**: Guarantee no drift between enrichment-report claims and current cluster/AAD state.
- **Acceptance**: `F1`, `F6`, `F5` still hold on re-probe (within the last 30 minutes of action).
- **Falsifier**: Any of the three probes returns a different answer than the enrichment report → HALT and re-diagnose.
- **Route**: Rerun `kubectl -n argocd get appproject flex-trade-optimizer -o yaml` + `az ad group member check` + `az repos pr show --id 173958`.

### Step 2 — Communicate to Erik with prescribed Slack register

- **Objective**: Erik receives a terse, specific reply in the `Rec0AUE5HU5MJ` thread that tells him (a) access is now granted, (b) the one action left, (c) how to verify.
- **Acceptance**: Reply drafted in enrichment-report §"Recommended action". USER posts after review. Matches Eneco Slack reply register: pings filer once, no AI tells, links authoritative URL(s), under 5 sentences.
- **Falsifier**: Message contains any of the banned phrases ("I hope this helps", "feel free to", "happy to", "let me know if", "please don't hesitate"). → Redraft.
- **Route**: User posts manually, not by this coordinator. No write tool invocation against Slack.

### Step 3 — Verify Erik's fresh-login carries the groups claim (Phase 8 falsifier)

- **Objective**: Once Erik signs out+in, he can see the `flex-trade-optimizer` applications AND `argocd account can-i get applications flex-trade-optimizer/*` returns `yes`.
- **Acceptance**: Either (a) Erik confirms the UI view, or (b) `argocd account can-i` returns yes from his CLI session.
- **Falsifier**: Erik reports persistence of the symptom after sign-out+in.
- **Route**: If falsifier fires, run Step 4.

### Step 4 (contingent) — If sign-out+in doesn't fix it, diagnose overage + URL drift

- **Objective**: Rule out the two named residual unknowns from the enrichment report.
- **Commands**:
  - `az ad user get-member-groups --id Erik.Lumbela@eneco.com --security-enabled-only false | wc -l` — expect < 150. If ≥ 150, groups overage is in play; remediation = app-reg Graph API permission grant + `argocd-cm` directory search config (this becomes a separate ticket, not Erik's fault).
  - Ask Erik which URL he's hitting. If not `https://argocd.dev.vpp.eneco.com/`, he's on a different instance and the entire diagnosis needs to be re-done against that instance.
- **Acceptance**: One of the two probes returns the discriminating answer.
- **Falsifier**: Both probes normal and access still broken → escalate: dispatch `investigation-specialist` + inspect his issued JWT directly (requires Erik to share the ID token, which is sensitive — ask first).

## Adversarial Challenge

**Referenced: Phase 4 canonical failures** (probes 1–6 in enrichment-report), **Phase 1 surviving hypotheses** (H1 = re-login is the remaining action), and the Phase 5 consequence contract: each challenge below either changes a step or records explicit residual risk.

### Q1 — Assumption + failure mode

**Assumption under test**: "The AppProject's `spec.roles[].groups` binding is evaluated at runtime against Erik's token groups claim."
**Named failure mode**: ArgoCD `argocd-server` caches project role bindings in its in-memory enforcer; if the ArgoCD server was restarted after a stale config load, the role binding might not match runtime state. **Consequence**: Step 3 falsifier could trip for a non-Erik reason.
**Plan change**: Add to Step 1 — also run `kubectl -n argocd rollout status deployment/argocd-server` to observe last restart time; if restart was > AppProject update time, a pod bounce is safe and recommended (but requires user authorization per skill gates).

### Q2 — Simplest alternative

**Alternative**: Maybe Erik looked at the right URL but the wrong project filter — FTO apps might be visible if he clears the "project" filter in the UI. **Consequence**: If true, there's nothing to "fix" — UX glitch. **Plan change**: Step 2 Slack reply explicitly says "you should see FTO apps after sign-out+in" — if Erik's issue was the UI filter, he'd have said so (experienced dev, uses ArgoCD daily for Dev/Acc). Risk noted, not actioned.

### Q3 — Disproving evidence

**What evidence would disprove H1?** Erik's fresh ID token (post-re-login) does NOT contain group `036bd5f7-…`. **Probe**: `argocd account get-user-info` after Erik's re-login, OR jwt.io decode of his ID token (sensitive). **Plan change**: Step 4 includes this.

### Q4 — Hidden complexity

**Hidden surface**: The URL `argocd.dev.vpp.eneco.com` ingress on the sandbox cluster may serve BOTH the dev ArgoCD and the sandbox ArgoCD depending on DNS resolution context (e.g. split DNS). If Erik hits it via VPN resolving to dev cluster IP while my probes hit the sandbox IP directly, we'd have been diagnosing the wrong instance. **Consequence**: All Probe-1..6 evidence would be sandbox-irrelevant. **Plan change**: Ask Erik for his `curl -v https://argocd.dev.vpp.eneco.com | grep -i server` output or equivalent (inspect response headers to confirm which instance) — this is a named step-4 contingent probe. Residual risk recorded.

### Q5 — Version/existence probes

**Probes already executed** for version/existence: AppProject exists (F1), group exists with GUID matching (probe 2), PR exists/merged (F5), Erik's membership (F6), OIDC config (F3). These cover the version/existence class.

### Q6 — Silent failure (governance/docs lens)

**Silent fail**: The recommendation passes "verification" (Erik reports access works) but my RCA was wrong — e.g. Erik was ALREADY in `sg-vpp-flex-trade-optimizer-developers` before the PR (via another sync mechanism) and the real blocker was something else that happens to also auto-resolve around the same time (coincident fix). **How it fools verification**: Erik clicks "access works" without us ever knowing the PR was the cause. **Methodology flaw**: No pre-PR snapshot of Erik's memberships was taken. **Plan change**: Enrichment report's "Residual unknowns" already records this; acceptable given the PR title is explicit ("add Erik Lumbela to…") and the `az ad group member list` before-and-after in my 18:03 Slack reply contradict the "already-in" alternative. Confidence hit: -0 (claim holds).

### Named downstream consequence

**This adversarial challenge changes the plan concretely**: Step 1 is augmented with an `argocd-server` rollout-status probe (Q1); Step 4 is augmented with a DNS/URL-instance probe (Q4). Residual risks Q2/Q6 are recorded but do not change steps.

## Verification Strategy (Phase 8 falsifiers)

| # | Falsifier | Expected | Failure action |
|---|---|---|---|
| V1 | Erik confirms in the thread that FTO apps are visible after sign-out+in | Yes within < 30 min of reply post | Execute Step 4 |
| V2 | `argocd account can-i get applications flex-trade-optimizer/*` from Erik's CLI post-login | `yes` | Execute Step 4 |
| V3 | `kubectl -n argocd get appproject flex-trade-optimizer -o yaml` unchanged between now and reply | Identical manifest | HALT + investigate drift |
| V4 | `az ad group member check` still returns `{"value": true}` for Erik | `true` | HALT + investigate AAD sync revert |

## Routing / Dispatch commitments

- **Adversarial review**: CONTRARIAN trigger fired (CRUBVG≥5). Will dispatch `socrates-contrarian` on this plan before delivery.
- **Evaluator**: EVALUATOR trigger fired (CRUBVG≥4). Will dispatch separate evaluator (≠ coordinator) to grade the diagnosis at Phase 8 against `01-task-requirements-final.md`.
- **Librarian**: not needed — all authoritative citations gathered (ArgoCD RBAC docs, Azure AD groups overage).
- **Investigation specialist**: on standby for Step 4 fallback if falsifier fires.

## Rollback (N/A because read-only)

No writes. No rollback plan needed beyond Erik retrying his cached session if sign-out+in breaks UX (trivial, 1 min).

## Blast radius of the recommendation

Covered in enrichment-report §"Blast radius (a/b/c)". No scope expansion from this plan.
