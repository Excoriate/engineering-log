---
task_id: 2026-04-21-001
agent: claude-code
status: complete
summary: Phase 8 — all falsifiers run, reviewer-raised probes executed, belief changes recorded, epistemic debt tallied. Verdict deployable with the edits now integrated in outcome/.
---

# Phase 8 — Verification Results

## Falsifier execution

| # | Falsifier | Command / Source | Result | Pass/Fail |
|---|---|---|---|---|
| F1 | Sandbox AppProject `flex-trade-optimizer` binds a group affected by PR 173958 | `kubectl -n argocd get appproject flex-trade-optimizer -o yaml` | `spec.roles[0].groups = [036bd5f7-…-646d, 2aef53bb-…-fa7f]`; 036bd5f7 resolves to `sg-vpp-flex-trade-optimizer-developers` | **PASS** |
| F2 | Global `argocd-rbac-cm` does not veto project grants | `kubectl get cm argocd-rbac-cm` | Only `g, "2aef53…", role:admin` + `p, role:authenticated, *, *, *, deny` + `policy.default: role:authenticated`. `role:authenticated` is a Go `defaultRole` fallback, not transitive; project grants are independent | **PASS** |
| F3 | OIDC tenant/app matches Erik's tenant, groups flow | `kubectl get cm argocd-cm` + `az ad app show --id 504b5d75-…` | Same tenant `eca36054-…`; `groups.essential: true`; `groupMembershipClaims: ApplicationGroup` | **PASS** |
| F4 | PR is narrow (AAD-only) | `az repos pr show` + `curl .../iterations/1/changes` | Single commit, single file `terraform/platform/aad/groups-flex-trade-optimizer-teams.tf` edit | **PASS** |
| F5 | Dev/Acc vs Sandbox RBAC consistency | Not directly probed (ROI low after F1) | N/A — redundant with F1 | SKIP (documented) |
| F6 | Erik's live membership | `az ad group member check --group sg-vpp-flex-trade-optimizer-developers --member-id f118e00d-…-7403` | `{"value": true}` | **PASS** |
| V3 | Ledger unchanged between Phase 4 and Phase 8 | Re-run of `appproject -o jsonpath='{.spec.roles[0].groups}'` | `[036bd5f7-…, 2aef53bb-…]` — identical | **PASS** |
| V4 | Erik still in group at Phase 8 | Re-run `az ad group member check` | `true` | **PASS** |
| Q1 | argocd-server not mid-restart (adversarial challenge) | `kubectl -n argocd rollout status deployment/argocd-server` | `successfully rolled out` | **PASS** |

## Reviewer-raised probes (Phase 8 additions)

| # | Probe | Source of challenge | Result | Net effect |
|---|---|---|---|---|
| R1 | `enableUserInfoGroups` in argocd-cm | socrates-contrarian attack #3 | NOT configured; no key present | Strengthens diagnosis — sign-out+in sufficient |
| R2 | Erik's AAD group count (overage threshold) | socrates-contrarian attack #5; apollo evaluator U3 | **169 groups** < 200 JWT threshold | Strengthens diagnosis — groups claim will not be replaced by `groups:src1` overage |
| R3 | DNS for alternative ArgoCD hostnames | socrates-contrarian attack #2 | `sandbox/sb/iactest/acc/prd` all **NXDOMAIN** — only `argocd.dev.vpp.eneco.com` resolves | Introduces a named residual risk — diagnosis adds §4 URL-ambiguity block to outcome |
| R4 | Public DNS for `argocd.dev.vpp.eneco.com` | socrates-contrarian attack #2 | Resolves to `20.76.210.221` (different from sandbox cluster's `50.85.91.121`) | Same as R3 — outcome includes contingent Step D |
| R5 | App reg `groupMembershipClaims` + optional-claims | socrates-contrarian attack #5 | `groupMembershipClaims: ApplicationGroup`; `idToken.groups optional (essential:false)`, overridden by argocd-cm `essential:true` | Raises a new hypothesis: group must be assigned to Enterprise App |
| R6 | Is `sg-vpp-flex-trade-optimizer-developers` assigned to `appreg-vpp-argocd-id-d`? | Follow-up to R5 | `appRoleAssignedTo` Graph API confirms `036bd5f7-…` IS a Group-type assignee on SP `571430ce-…` | **PASS** — groups claim will flow; diagnosis holds |

## Belief changes

- **Unchanged**: PR 173958 resolves the AAD side of the gap; Erik is in the group; AppProject binding grants him `app-manager`.
- **Strengthened**: No UserInfo cache (R1), no overage risk (R2), group assigned to Enterprise App (R5–R6). Confidence moved from 95% toward ~97%.
- **Added residual**: DNS ambiguity around which ArgoCD Erik hits (R3–R4). Named in outcome §4. Resolvable by Erik's `curl` output in contingent Step D.
- **Corrected doctrine**: Casbin rule evaluation (`some(allow) && !some(deny)`, not OR). Fix landed in outcome §7.
- **Methodology flaw** (apollo finding): success-path verification asymmetry. FIXED by making `argocd account can-i` mandatory regardless of UI outcome (outcome §2 Step C + §5 Slack reply).
- **I was most wrong about**: treating ArgoCD RBAC as permissive-first when it's deny-wins. The diagnosis survived because of a separate Go-code mechanism (`defaultRole` fallback) that I did not know existed at the start. Socrates's attack #1 caught this. Net lesson: *probe the engine's actual semantics, don't infer them from the config that happens to work*.

## Epistemic debt

- **FACT**: 11 (E1–E6 + R1, R2, R4, R6, and the reviewer-verified Casbin semantics)
- **INFER**: 3 (re-login necessity U1; argocd-server session TTL U2; URL ambiguity interpretation in §4)
- **UNVERIFIED[assumption]**: 0 that are load-bearing
- **UNVERIFIED[unknown]**: 0 that are load-bearing (URL routing unknown is named + has a probe in contingent Step D)
- **UNVERIFIED[blocked]**: 0

FACT (11) > INFER (3) + UNVERIFIED (0 LB). Ledger healthy.

## Highest-risk claims (skeptical re-read, as-if another agent)

1. **"Erik's next ID token will carry the `036bd5f7-…` group."** — Rests on R5+R6 chain. If R6 drifts (group un-assigned from the Enterprise App) between now and Erik's re-login, claim fails. Mitigation: Step C's `can-i` catches this.
2. **"Erik is hitting the ArgoCD instance whose AppProject I probed."** — Rests on the user's statement "you have kubectl access for sandbox, and also argocd" plus the naming conventions. If Erik is on a split-DNS VPN, this may hold; if on public DNS, he hits 20.76.210.221 (different instance). Mitigation: Step D URL check.
3. **"Sign-out + sign-in forces a fresh ID token with fresh groups."** — Standard Azure AD / OIDC behavior. Not yet confirmed by Erik's retry. Mitigation: V1/V2 falsifiers from the plan, which are the `can-i` command itself.

## Domain-fit retrospective

- **Shape of the case**: "Engineer opens own self-service IaC PR; before the PR deploys, files a help ticket; on-call answers with unverified cross-environment hypothesis; diagnosis required to verify own prior claim."
- **Fit to skill pipeline**: Excellent. `eneco-oncall-intake-slack` extracted the filing context; `eneco-oncall-intake-enrich` drove the probes; adversarial + evaluator caught the Casbin doctrine error and the success-path verification asymmetry. Both of those would have shipped to Erik as wrong-flavor advice without the reviewer stage.
- **What I would keep**: The TWO reviewer dispatch (contrarian + assurance marshal) in parallel. Catching BOTH the conceptual error (Casbin) and the methodology error (success-path asymmetry) required both lenses; neither alone would have produced both.
- **What I would change**: Run R5 (app reg manifest) BEFORE writing the enrichment report. `groupMembershipClaims: ApplicationGroup` could have invalidated the whole diagnosis; I got lucky that the group was already assigned. Next time: probe the app-reg manifest as F0.
- **Pattern for the runbook**: the three-plane alignment check (§8 of outcome) — codify that sequence so the next on-call engineer runs it in order instead of reinventing.

## Evaluator / adversarial incorporation

- `socrates-contrarian` verdict: (b) yes with named edits. All 5 attacks integrated:
  - Attack 1 (Casbin): FIXED in outcome §7
  - Attack 2 (URL): named residual in §4, contingent Step D
  - Attack 3 (UserInfo cache): probed — refuted, noted in E6
  - Attack 4 (self-reference laundering): V3/V4 re-runs with Phase 8 timestamp anchor this file
  - Attack 5 (H5-H8 alt hypotheses): groupMembershipClaims+app-reg probed (R5-R6); overage re-threshold (R2 used correct 200 limit for JWT)
- `apollo-assurance-marshal` verdict: DEPLOY WITH EDITS. Both edits integrated:
  - Mandatory success-path verification: outcome §2 Step C + §5 Slack reply
  - Deploy timestamp in reply: §5 Slack reply ("as of 17:58 CEST today")

## Final verdict

**DEPLOY.** The outcome `diagnosis-and-fix.md` is ready for Alex to review and post the Slack reply draft (§5) verbatim or with minor tweaks. All reviewer-raised concerns addressed; residual INFER named with falsifier probes queued for Erik's end.
