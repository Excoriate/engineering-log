---
task_id: 2026-04-21-001
agent: claude-code
status: partial
summary: Phase 3 — confirmed requirements after Slack intake harvest. Critical reframe: this task is a VERIFICATION of an already-made hypothesis, not a cold diagnosis.
---

# Task — Final Requirements

## What changed after Phase 2/3 Slack harvest

### Chronology reconstructed (FACT, Slack API)

| Time (CEST, 2026-04-21) | Event | Evidence |
|---|---|---|
| 14:48 | Erik (U0AAFHJGHDM) creates PR **173958** to `Eneco.Infrastructure` | `#myriad-platform` announcement at ts=1776775698.766449 |
| 15:14 | Erik files request → `Rec0AU6UB4C4V` (companion ts `1776777286.672039`) | Filing announcement ts=1776777292.268519 |
| 15:42 | Erik files request → **`Rec0AUE5HU5MJ`** (companion ts `1776778921.625239`) — *this is the ticket the user pointed me at*, argocd sandbox access | Filing announcement ts=1776778926.101269 |
| 18:03 | Alex Torres (me) replies inside the 15:14 thread: "Some minutes ago, yourself created a Pull Request, which add you to the necessary security group… I think this will **also** cover the ArgoCD one you created." | `C0ACUPDV7HU` reply at ts=1776787416.767559 |

### Load-bearing claim set (A-label classified)

- **C1 [FACT]**: Erik's PR 173958 in `Eneco.Infrastructure` added `Erik.Lumbela@eneco.com` to AAD security group `sg-vpp-flex-trade-optimizer-developers`. Evidence: my own `az ad group member list` output pasted at 18:03 CEST shows him present after deploy.
- **C2 [FACT]**: PR 173958 is merged AND deployed. Evidence: my own reply "*I've just deployed your Pull Request*" + `az ad group member list` confirmation.
- **C3 [INFER, fragile]**: The same group `sg-vpp-flex-trade-optimizer-developers` is also the group that grants ArgoCD Sandbox access to the `flex-trade-optimizer` project. Evidence: my own PS note ("I think this will also cover the ArgoCD one"). **No probe yet confirms ArgoCD maps this group in sandbox.**
- **C4 [UNVERIFIED[assumption: Erik is still logged out / needs fresh token, boundary: SSO session freshness]]**: Even if C3 holds, ArgoCD OIDC tokens may cache the old group set until Erik re-logs in.
- **C5 [UNVERIFIED[unknown: no probe]]**: Sandbox cluster for FTO may not have an `AppProject` named `flex-trade-optimizer` at all (if FTO isn't deployed to sandbox). `Dev/Acc` working while sandbox missing is consistent with "project doesn't exist yet" AND "group missing" — they're not discriminated yet.
- **C6 [INFER]**: Dev/Acc work for Erik was resolved historically (he stated "I do have it for Dev/acc") — meaning whatever gating mechanism applies at Dev/Acc already accepts him. Evidence: slack-antecedents.txt + historical 2026-04-08 thread (`1775198615.984359`) showing he asked about argo groups in DEV and accessed FTO there by 2026-04-09.

### Hypotheses re-ranked (based on evidence)

- **H1 (leader, was H3)**: PR 173958 fully resolves both DB and ArgoCD sandbox access; Erik just needs to re-login to ArgoCD sandbox for a fresh OIDC token carrying the new group claim. *Test: ask Erik to re-login, or synthesize the OIDC claim set via `argocd account get-user-info` after fresh auth.*
- **H2**: PR 173958 resolves DB access only; ArgoCD Sandbox needs a DIFFERENT group (e.g. `sg-vpp-argocd-sandbox-*` or environment-specific role) that the PR did NOT touch. *Test: inspect `argocd-rbac-cm` on sandbox cluster + AppProject `flex-trade-optimizer` role bindings. Compare with Dev/Acc cluster equivalents.*
- **H3**: The `flex-trade-optimizer` AppProject does not exist in sandbox ArgoCD at all (FTO not yet deployed to sandbox cluster). *Test: `argocd proj list` in sandbox.*
- **H4 (orthogonal)**: Sandbox ArgoCD uses a different AAD tenant / app registration than Dev/Acc. PR only targeted the tenant used by Dev/Acc. *Test: inspect `argocd-cm` OIDC config on sandbox vs Dev.*

## Verification Strategy

### Acceptance criteria (contract with user)

1. Produce ONE of these verified statements, with evidence:
   - (a) "Access already works; Erik only needs to re-login." Evidence = fresh OIDC introspection showing Erik's tokens carry the group AND ArgoCD sandbox RBAC maps that group to FTO project access.
   - (b) "Access is still broken; cause = X; fix = Y." Evidence = the specific mapping that is missing (group, RBAC policy line, AppProject role, or AppProject existence).
2. Explicitly falsify the claim I made at 18:03 CEST if it was wrong. If correct, evidence must show exactly which surface grants the access.
3. Fix steps, if needed, include: repo, file, line, PR outline, expected apply+propagation time, verification command.

### Falsifier list (Phase 8 will execute)

| # | Falsifier | Expected if H1 true | Expected if H1 false |
|---|---|---|---|
| F1 | `argocd proj get flex-trade-optimizer` in sandbox (read) | Project exists, has role binding to group | Project missing → H3 lives; or role binds different group → H2 lives |
| F2 | `kubectl -n argocd get cm argocd-rbac-cm -o yaml` in sandbox | Contains `g, "sg-vpp-flex-trade-optimizer-developers", role:…` that maps to FTO project | Different group mapped → H2/H3 lives |
| F3 | `kubectl -n argocd get cm argocd-cm -o yaml` in sandbox | OIDC tenant/app matches the one whose groups PR 173958 populated | Different tenant/app → H4 lives |
| F4 | PR 173958 file list: do any files touch sandbox-specific AAD objects? | Yes, or the group already existed cross-env | No sandbox-specific change → H2/H4 livens |
| F5 | Diff Dev/Acc vs Sandbox ArgoCD RBAC | Identical policy for FTO project | Divergence exposes the specific gap |
| F6 | Erik's group memberships per `az ad group member list` for every plausible AAD group | Only `sg-vpp-flex-trade-optimizer-developers` needed, and present | A second group missing → name it |

### Verify-how / Who

- **Verify how**: read-only `argocd`, `kubectl` (sandbox), `az ad group member list`, ADO repo file reads for the PR 173958 diff.
- **Who executes**: coordinator via kubectl/argocd/az access the user granted. Evaluator = dispatched sub-agent (not coordinator) grades the Phase 8 report.
- **Who changes code if fix needed**: Erik (if documentation gap) or an Eneco.Infrastructure maintainer for AAD edits; ArgoCD-Config maintainer for RBAC edits. Coordinator produces the PR outline, not the commit.

## Counterfactual re-check (Phase 3)

If not done: I posted an unverified hypothesis in Slack at 18:03 CEST claiming the PR resolves sandbox. If H2/H3/H4 is actually true, Erik follows my advice, re-logs in, still blocked, loses more trust in on-call, and the actual fix is delayed into tomorrow. The on-call value here is precisely the closing-of-the-loop that my Slack reply left open.

## Differences from initial requirements (must not be copy-paste)

- Initial hypothesis set said H1 = group membership missing (leader). After intake, that's demoted to H2, because the PR is already deployed and group membership is FACT-confirmed. Leader now = H1-revised (re-login).
- Initial Verification Strategy didn't exist; now has 6 concrete falsifiers.
- Initial framing treated this as cold diagnosis; reframed as "verify my own prior claim under adversarial scrutiny" — probe-discipline explicitly targets self-generated claim C3.
- Added temporal chronology as load-bearing evidence (PR → request order matters for interpreting Alex's Slack reply).

## Transition statement (P3→P4)

Phase 3 revealed: *I am the author of the hypothesis under test*. Hypothesis C3 ("same group gates ArgoCD sandbox") is now my leading-but-unverified claim. Most dangerous unknown: whether sandbox ArgoCD even has the FTO project — resolving that first (F1) cheaply discriminates H1 vs H3.
