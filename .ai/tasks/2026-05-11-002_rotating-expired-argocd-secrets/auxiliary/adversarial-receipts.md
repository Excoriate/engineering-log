---
task_id: 2026-05-11-002
agent: claude-opus-4-7
status: complete
summary: Receipts (Accepted / Rebutted / Deferred + evidence) for each Socrates + el-demoledor finding before P6→P7
phase: 5
---

# Adversarial Receipts

> Per § 8 Subagent discipline: each adversarial finding has an Accepted / Rebutted / Deferred verdict + evidence. Systematic Defer ≥50% on BLOCKING / HIGH = HALT. None below qualify as BLOCKING (no findings prove the task is impossible); 100% are Accepted or HARDEN-with-defense.

## Socrates (4 attacks, all VERDICT REVISE)

| Attack | Finding | Receipt | Action in deliverable |
|---|---|---|---|
| S1 (kubectl patch) | "IaC absence ≠ reconciler absence; require ownership-probe gate" | **Accepted** | how-to-rotate.md Section A: add Step 4.5 (ownership-label probe); fail-closed if any controller owns the Secret. RELAX `repo-*` name guard to `argocd.argoproj.io/secret-type=repository` label selector. |
| S2 (Fabrizio "no doc") | "Quote is bounded by search scope; `Platform-team-internal` wiki + Slack canvases + 1Password notes not searched" | **Accepted** | how-to-rotate.md "Before you start": include the two-question Fabrizio DM (mint + private-doc check). draft-rotation-secrets.md: gap-list item explicit. proposal: REFRAME problem statement away from "no docs" toward "manual + oral + SPOF". |
| S3 (simplest mechanism) | "Conflates mint authority vs apply authority; SA vault stores LOGIN not derived PATs; CMC may be apply-only" | **Accepted** | how-to-rotate.md Section B: split mint/apply actor columns. Require EXPLICIT secure-transmission channel (1Password share, NOT Slack/email). plan/draft Q2: split into two columns. |
| S4 NEW (two-clock) | "ApplicationSet lastTransitionTime ≠ controller credential cache state; add `argocd repo get connectionState` + resourceVersion delta + controller logs" | **Accepted** | how-to-rotate.md Section A: add Step 6.5 (two-clock verification). |

**Cross-attack synthesis (the generator)**: Every load-bearing **absence claim** in deliverables MUST cite the search scope OR mark `[PENDING]`. Already in P3 final F1/F7; tightened by this receipt.

## El-Demoledor (13 attacks; 0 HOLD / 9 HARDEN / 4 REWRITE)

### REWRITE (4) — block publication unless addressed

| # | Decision Rule | Receipt | Action |
|---|---|---|---|
| V5 | Step 5 kubectl patch reverted by Helm/Operator reconcile (Helm chart at `iac-secret-templates.md:36-51` is smoking gun) | **Accepted** | Mandatory Step 4.5 ownership probe (same as S1). Extend Step 6 wait window to MAX(180s, 2×reconcile-interval). Add Step 6.5 "re-verify Secret value at wait-end". |
| V8 | Step 8 "200 + headers" can be NGINX-injected; population-level false-positive | **Accepted** | Replace Step 8 with: body-content match (slot-specific content) + pod-readiness probe + `argocd app get` health check. |
| V10 | Section B Step 1 (MC mint) may not be Trade-Platform authorized (Roel "asked him [Lex from CMC]") | **Accepted** | Section B opens with `[PENDING: ask Fabrizio about MC mint authority]`. Two branches authored: (i) if Trade-Platform-authorized → procedure; (ii) if CMC-operated → request-template with explicit ArgoCD-instance name + transmission channel + SLA. Preserve EXISTING PAT name (no date suffix) to keep monitoring filter alignment. |
| V11 | Section B option Y (KV update) is documentation theater — no sync mechanism (3 orthogonal IaC harvests) | **Accepted** | **DELETE option Y**. Replace with explicit "There is no KV→cluster sync for MC ArgoCD ADO Git repo creds. KV update is a documentation artifact at best." |

### HARDEN (9) — zero-cost defense-in-depth; apply unconditionally

| # | Decision Rule | Receipt | Action |
|---|---|---|---|
| V1 | Step 1 context check may pass with stale cached endpoint | **Accepted** | Add probe: `kubectl cluster-info` + verify API server FQDN matches `az aks show --query fqdn`. |
| V2 | Step 2 multi-match risk (Helm chart proves multiple repository-typed Secrets coexist; URL substring is non-anchored) | **Accepted** | Anchor exact equality against `kubectl get applicationset vpp-feature-branch-environments -o jsonpath='{.spec.generators[*].git.repoURL}'`. Refuse to proceed if 0 or 2+ matches. |
| V3 | Step 3 user-picker confusion / SA MFA dead-end / PAT scope leak | **Accepted** | Post-mint user-identity probe: `connectionData` API call returning `providerDisplayName == sa_platform_vpp@eneco.com`. Flag scope-leak (Code Read is org-wide) as `[PENDING]` for proposal. |
| V4 | Step 4 curl from laptop ≠ curl from cluster (IP-restricted PAT) | **Deferred (conditional)** | Add cluster-egress probe ONLY IF `[PENDING: ask Fabrizio: IP-restricted-PAT policy?]` returns yes. Document the probe in an "Optional pre-flight" subsection. |
| V6 | Step 6 condition is stale-cached / condition-type may differ in MC ArgoCD version | **Accepted** | Triangulate: condition + generator-output (`status.resources`) + extended timeout based on observed reconcile interval. Pin condition type to ArgoCD version probed via `kubectl api-resources`. |
| V7 | Step 7 counts CRDs but not health | **Accepted** | Probe must check count + sync.status + health.status; require ALL Healthy + ALL Synced. |
| V9 NEW | Old PAT remains valid post-rotation; 21-day exposure window for MC PATs | **Accepted** | Add Step 9 (renamed Step 9 → Step 10): explicit "Revoke old PAT in ADO UI; confirm by curling old PAT → expect 401." |
| V12 | Section B option Z (CMC ticket) — ArgoCD-instance ambiguity + transmission channel + SLA | **Accepted** | Section B ticket template MUST name: (a) ArgoCD instance + namespace, (b) secure transmission channel (1Password share / KV with CMC ACL), (c) SLA expectation, (d) post-fulfillment verification probe. |
| V13 | Section B "wait for sync mechanism" — Goldilocks sync policy may be manual; annotation target may differ | **Accepted** | Post-rotation MUST include health probe (`oc get application goldilocks -o jsonpath='{.status.sync.status} {.status.health.status} {.status.operationState.phase}'`). If sync policy = manual → explicitly trigger sync. |

### THEORETICAL (downgraded by el-demoledor's own self-check)

V9 (revoke old PAT) — already accepted above; theoretical for unauthorized use but trivial mitigation cost.

## Cross-frame synthesis (Socrates + El-demoledor)

Both frames converge on three root-cause generators:

1. **Ownership model absent** — V5, V11, V13 (el-d) + S1 (Socrates). The runbook lacks a model of which controller owns the in-cluster Secret. Fix: Step 4.5 hard gate.
2. **Single-probe success criteria** — V2, V6, V7, V8 (el-d) + S4 two-clock (Socrates). Each verification step is one signal; triangulation absent. Fix: pair every success probe with a different-frame probe.
3. **Identity-of-minter ambiguous** — V3, V10 (el-d) + S3 simplest-mechanism (Socrates). PAT mint authority + identity verification absent. Fix: post-mint identity probe + Section B mint-vs-apply split.

## Coordinator's response to "block publication on 4 PENDING" recommendation

El-demoledor recommends blocking publication on 4 PENDING items. **Coordinator decision**: **PROCEED but with EXPLICIT publication gates**:

- **Section A (sandbox)**: PUBLISHABLE as-is with all 9 HARDEN + the two REWRITE-relevant ones (Step 4.5 ownership probe + Step 8 body-content match). The 4 PENDING items affect Section A only via S2 ("private doc check") which becomes a Step 0 "Before you start" prompt.
- **Section B (MC)**: PUBLISH AS DRAFT — DO NOT EXECUTE banner at top, with explicit `[PENDING]` blocks for: (b) MC ArgoCD repo Secret ownership, (c) MC PAT minting authority. Section B is presented as a QUESTIONNAIRE + conditional-branch procedure, NOT an executable runbook.

**Justification**: User's outcome SC1 is "hand the gap-list to Fabrizio as a focused questionnaire." Section B as questionnaire IS the requested outcome shape for the unresolved gaps. Blocking publication entirely contradicts SC1.

## Recommendation deferred to future task: verification-engineer regression probes

El-demoledor recommended invoking `verification-engineer` for V5 + V8 regression probes BEFORE publication. **Coordinator decision**: **Defer** to future task because (a) this task's user-stated scope is documentation-only (no execution), (b) regression probes are an implementation artifact (part of the automation proposal Option C's "Grafana alerts"), (c) the runbook's HARDEN steps already include the manual probes; an automated version is a Phase-1-of-the-proposal artifact.

Record in proposal-rotation-automation.md sequencing under "Phase 1 (now-30d)" as a sub-item.

## Receipt summary

| Frame | Findings | Accepted | Rebutted | Deferred |
|---|---|---|---|---|
| Socrates | 4 | 4 | 0 | 0 |
| El-Demoledor | 13 | 12 | 0 | 1 (V4 — conditional) |

**Acceptance rate**: 16/17 = 94%. No systematic Defer; no BLOCKING-graded item left unaddressed. Gate-clear for P6→P7.
