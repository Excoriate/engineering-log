---
task_id: 2026-04-26-001
agent: coordinator
status: complete
summary: Phase 5 — execution plan for Path D (defensive IaC commit) plus deliverables; Path P operator command produced as deliverable, not executed
---

# Phase 5 — Plan

## Belief change vs Phase 4

Phase 4 revealed: the IaC at HEAD already contains the `activation-mfrr` entry in `dispatcher-output-1.consumerGroups` of `sandbox.tfvars` (PR 172400, 2026-04-16). Runtime probes confirm the CG and blob container are still missing on Azure today. Pipeline 1413 has `trigger: none` and the only run after the merge (Stefan's `1616964`, 2026-04-21) had its apply stage skipped by a 2 h approval-timeout.

H1 (single tfvars hunk) is **eliminated** — the entry exists. H3 (root cause elsewhere) is **partially confirmed**: the cause is a process gap (no auto-trigger + un-approved apply gate), not a missing tfvars line. Re-framed root cause: **`trigger: none` + non-approved apply checkpoint = silent state drift after every merge.**

What I was most wrong about going in: I assumed the diagnosis's runtime probes were INFER and the IaC claim was FACT. Reality was the inverse — runtime probes were correct, IaC claim was stale-mirror INFER mislabeled FACT.

## Verify Strategy Delta vs Phase 3

UNCHANGED. The Phase 3 falsifiers all ran in Phase 4. The single material change is that the planned tfvars-hunk path is dead; the new path edits the pipeline yaml. The same falsifier (`git diff` is exactly the expected hunk; nothing else touched) still applies, just on a different file.

## Route — Path D (defensive IaC commit) + Path P deliverable

The user accepted: I implement Path D code change; user executes Path P operationally.

### Step D1 — Edit pipeline yaml on the worktree

**File**: `.azuredevops/pipelines/terraform-cd-sandbox.pipeline.yaml` on branch `fix/NOTICKET/mfrr-activation-crashloop` in worktree `VPP%20-%20Infrastructure/2026-04-24-ootw-fix-mfrr-activation-crashloop`.

**Hunk**: replace `trigger: none` (line 1) with a CI trigger scoped to `main` and the paths whose changes can affect Sandbox state:

```yaml
trigger:
  batch: true
  branches:
    include:
      - main
  paths:
    include:
      - configuration/terraform/sandbox/*
      - terraform/sandbox/*
      - .azuredevops/pipelines/terraform-cd-sandbox.pipeline.yaml
      - .azuredevops/pipelines/variables.yaml
```

**Route premises** (each must hold; if falsified, route changes as noted):

1. **Sandbox apply is driven by `terraform/sandbox/**` and consumes `configuration/terraform/sandbox/sandbox.tfvars`.** Confirmed by reading `terraform/sandbox/event-hub.premium.tf` (self-contained, defines its own modules; does not source `terraform/fbe/`) and the pipeline yaml `configFilePath`/`workingDirectory` variables (lines 10–13). *If false → path filter must include `terraform/fbe/**`; route unchanged otherwise.*
2. **`pr:` triggers are out of scope.** PRs are validated by the separate `pull-request-validation.yaml` file. The new `trigger:` block is for CI on push only. *If false → would also need `pr:` block; not adding one.*
3. **Bumping `trigger:` from `none` to branch+path is reversible.** A revert PR restores the prior YAML. *If false → not reversible-cleanly; halt.* Confirmed: pure YAML key change.
4. **The approval gate at the `terraform-sandbox` ADO Environment is unchanged.** I am not lowering security; I am closing a *triggering* gap, not a *gating* gap. *If false (e.g., this implicitly bypasses approval) → halt.* Confirmed: `applyCondition` and `azureDevOpsEnvironmentName` are untouched.

### Step D2 — Stage the change but do NOT commit, push, or open a PR

Per NN-4 Git Mutation Protocol — branch creation already done by user, but commit/push/PR require explicit per-class authorization. The user's directive ("until the code changes only, I'll do the rest") authorizes the file edit only. Leave the change as a working-tree modification on the existing branch.

### Step D3 — Produce three deliverables in the on-call shift folder

`/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/log/employer/eneco/02_on_call_shift/2026_04_21_stefan_vpp_infrastructure_mfrr/`:

- `explanation-of-fix-and-issue-holistic.md` — full repo-by-repo explanation, corrected diagnosis, ASCII diagram, evidence chain, `git show 4dbaf72` excerpt, runtime probe outputs, pipeline timeline, lessons.
- `pr-description.md` — PR description for the trigger-yaml change. Title: `fix(pipeline): add CI trigger to terraform-cd-sandbox so merges to main auto-apply`. Body: problem (silent state drift), root cause (trigger:none + approval timeout), fix (auto-trigger + path filter), blast radius (sandbox-only; approval still required), verification (next merge to main runs plan; runtime CG + container created on approve).
- `slack-response.md` — short, sober update for the parent thread (`#myriad-platform`, `1776781493.090009`). Acknowledges Stefan's report; corrects two parts of the prior diagnosis; states the operational fix (trigger + approve) and the defensive PR; no pings on Stefan (vacation).

### Step D4 — Path P command + explanation as part of `explanation-of-fix-and-issue-holistic.md`

Operator-runnable command, paste-ready, with rich step-by-step explanation, falsifier, rollback, and what to watch for. User executes.

## Adversarial Challenge — 6Qs

**Q1 — What's the most dangerous assumption, and what would falsify it?**
That changing `trigger: none` to a path-filtered branch trigger doesn't break anything else. Falsifier: a `pr:` block defaults to `pr: ['main']` when unspecified, which COULD cause unexpected PR-validation runs of *this* pipeline (separate from `pull-request-validation.yaml`). Mitigation: explicitly add `pr: none` to the yaml to suppress the implicit PR trigger. **Action: include `pr: none`** in the change. *Plan step updated.*

**Q2 — What is the simplest alternative that achieves the same effect?**
Don't change the YAML — just write a runbook saying "after every merge to main, manually trigger the pipeline and approve". Rejected: the recurring human cost is far higher than 4 lines of YAML; the silent-failure mode is the exact problem we're solving.

**Q3 — What evidence would disprove the plan?**
- `terraform/sandbox/` has external Terraform sources (e.g., `git::…` modules pinned by SHA) whose updates wouldn't be detected by path filter → silent staleness on module bumps. *Defense: external modules are pinned to tags (`?ref=v1.0.0`), which only change when an `*.tf` here changes. Verified in `terraform/sandbox/event-hub.premium.tf`.*
- `applyCondition: eq(variables['Build.SourceBranch'], 'refs/heads/main')` evaluates differently for auto-triggered runs vs manual runs → could leave apply still skipped. *Defense: `Build.SourceBranch` is set identically for both trigger types when on main. Verified by ADO docs.*

**Q4 — Hidden complexity?**
- The pipeline template is sourced from `CCoE/azure-devops-templates ref 2.6.9` (line 17–20 of yaml). The template internals could have their own assumptions about manual-only triggering — e.g., the apply Environment may have a check like "manual trigger only". *Mitigation: the only signal we have is build 1616964's timeline, which shows the same template behaviour for a *manual* run with skipped approval — i.e., the template is approval-gated regardless of trigger type. Auto-trigger doesn't change the gate.*

**Q5 — Version probe.**
Pipeline yaml syntax for `trigger.paths.include` is GA in ADO since ~2019 and stable in template `ref 2.6.9` (released long before the worktree commit). Confirmed by reading existing `pull-request-validation.yaml` and `variables.yaml` patterns in the same repo and ADO YAML schema documentation. Low risk.

**Q6 — Silent failure mode.**
The YAML change could silently fail if:
- `pr: none` is misinterpreted by some ADO version → unintended PR runs. Falsifier: open a fresh PR after the merge and confirm the Sandbox pipeline does NOT run on PR.
- A future merge that touches NOT-listed paths but DOES affect Sandbox state (e.g., a new file in `terraform/sandbox-extras/`) wouldn't trigger. Falsifier: weekly visual diff between pipeline-include paths and `terraform/sandbox/` directory structure during PRs.
- Approval timeout still defaults to 2 h. Auto-trigger guarantees a build, but the approver still needs to act within 2 h. **The trigger fix alone does not prevent recurrence if no human approves.** This is *intentional* — Path D is a triggering fix, not an approval fix; lowering approval timeout / removing approval requires team consensus and is out of scope.

**Downstream consequence**: every merge to main touching the path filter will produce a build that requests approval. If approver SLA is poor, this will create a queue of unapproved builds, which is *visibility* rather than silent drift — strictly better than the current state where the queue is invisible.

## Activation Checklist preview

| Gate | Plan | Phase 8 verification |
|---|---|---|
| Phases 1–8 substantive | All written; 4→5 reframing recorded above | Phase 8 will record post-edit state |
| NN-1 TodoWrite | tasks 1–8 created, in_progress for 5 | will mark 5–8 completed sequentially |
| NN-2 file-backed | plan/plan.md, specs/, verification/, outcome/ all under $T_DIR | will check `test -s` |
| NN-3 preflight | done in 01-task-requirements-initial.md | n/a |
| NN-4 safety | NO commit/push/PR — file edit only | will run `git status` to confirm |
| NN-5 context | Read budget: ~1500 lines this session, well under 3000 | will tally |
| Adversarial | 6Qs answered above with named consequence on each | EVALUATOR sub-agent grade in Phase 8 |
| EVALUATOR | y (CRUBVG≥4, actionable deliverable) | dispatched at Phase 8 |

## Subagent dispatch decisions

I am the coordinator. For the YAML edit and the 3 deliverables, the marginal value of dispatching a `terraform-code-hcl-expert` is low — this is ADO YAML, not HCL — and the change is 4 lines. For an `el-demoledor` adversarial pass on Path D, the marginal value is high (it could surface trigger-conflict cases I missed).

Dispatch plan:
- **Phase 8**: `socrates-contrarian` (separate subagent) to attack the trigger-yaml change AND the 3 deliverables. **Belief change conditional**: if it identifies a real failure mode in the trigger or a missing path, route → revise yaml or deliverables. If clean, route → finalize.
- **No fork-based adversarial.** Per CLAUDE.md tandem discipline.

## Path P — operator command (delivered as text in `explanation-of-fix-and-issue-holistic.md`, NOT executed)

```bash
az pipelines run \
  --org "https://dev.azure.com/enecomanagedcloud" \
  --project "Myriad - VPP" \
  --id 1413 \
  --branch refs/heads/main \
  --query "{id:id,buildNumber:buildNumber,status:status,_links:_links.web.href}" \
  -o json
```

Then visit the printed `_links.web.href` in browser → wait for the `Terraform Apply` stage to enter `pending` state → click **Approve** within the 2-hour window. This is the single operational action the user takes; everything else is automated.

Falsifier for Path P: after apply completes, runtime probes must show:

```bash
az eventhubs eventhub consumer-group list --namespace-name vpp-evh-premium-sbx \
  --eventhub-name dispatcher-output-1 -g rg-vpp-app-sb-401 \
  --query "[?name=='activation-mfrr'].name" -o tsv
# expected: activation-mfrr

az storage container exists --account-name vppevhpremiumsb \
  --name dispatcher-output-1-activation-mfrr --auth-mode login -o tsv
# expected: True
```

Both probes returning the expected outputs is the falsifier passing — fix complete.

---

# Phase 5 — Adversarial synthesis (post-dispatch patches)

Two adversaries dispatched in parallel: `el-demoledor` (HOLDS-WITH-PATCH) and `socrates-contrarian` (PROCEED-WITH-CHANGES). Reports at `context/demoledor-attack-on-plan.md` and `context/socrates-attack-on-plan.md`.

## Patches absorbed

**P1 — Path-glob form.** Both adversaries flag `configuration/terraform/sandbox/*` and `terraform/sandbox/*` as risky (`*` is single-segment in ADO; new subdirs would silently miss). Both recommend bare directory paths (treated as recursive prefix-match by ADO). Adopted: drop trailing `/*`.

**P2 — Verified-diagnosis F5/F6 wording bug.** Demoledor: prior wording attributes Sandbox CG/container creation to `terraform/fbe/event-hub.premium.tf`, but Sandbox is a self-contained Terraform root at `terraform/sandbox/event-hub.premium.tf`. Plan path filter is correct (no `terraform/fbe/**`); the doc was misleading. **Fixed F5/F6 in `context/verified-diagnosis.md`** and added F5b to record the genuine cross-pipeline dependency.

**P3 — Cross-pipeline residual: `sandbox-shared.tfstate`.** Socrates surfaced `terraform/sandbox/data.tf:6-15` reading `tfstate-platform/sandbox-shared.tfstate`. Probe confirmed: no producer file exists in this repo (`find -name "*.backend.config"` returns only Sandbox's own). Producer lives in another pipeline/repo. **No path-filter mitigation possible from inside this repo.** PR description records this as a known cross-pipeline residual; not a defect of this PR.

**P4 — First-merge ordering.** When this PR merges, the merge commit itself touches `terraform-cd-sandbox.pipeline.yaml` (in path filter), so the new trigger is read at the post-merge HEAD and an auto-build queues immediately. That build's plan will show **+1 CG + +1 storage container** (the still-unapplied delta from PR 172400 of 2026-04-16). On approval, apply creates the resources — Path D's merge IS Path P's effect. So:
- **Path D as primary**: merge the PR; watch for the auto-triggered build; approve apply within 2 h.
- **Path P remains as a "fix it before approval cycle" alternative**: operator runs `az pipelines run …` against current main now, approves apply within 2 h. Identical outcome on Azure resources; no relationship to the PR being open.

The two are not additive — running both queues two builds; the second one will plan zero changes (apply is no-op because the first one already created the resources). State drift is solved by EITHER, not BOTH.

## Final hunk shape (replaces line 1 `trigger: none` of `.azuredevops/pipelines/terraform-cd-sandbox.pipeline.yaml`)

```yaml
# Auto-trigger on merges to main that touch Sandbox-affecting code.
# Bare directory paths are recursive directory-prefix matches in ADO YAML —
# any file under these directories triggers a build. Sibling directories
# (e.g. terraform/sandbox-extras/) are NOT covered — extend if added.
trigger:
  batch: true
  branches:
    include:
      - main
  paths:
    include:
      - configuration/terraform/sandbox
      - terraform/sandbox
      - .azuredevops/pipelines/terraform-cd-sandbox.pipeline.yaml
      - .azuredevops/pipelines/variables.yaml

# Suppress ADO's implicit pr: ['default-branch'] when trigger: is set.
# This pipeline must NOT run on PRs — pull-request-validation.yaml at repo root
# already covers PR validation via its own trigger.
pr: none
```

## Residual risks recorded in PR description (Phase 7)

1. **Cross-pipeline `sandbox-shared.tfstate` dependency** — producer outside this repo; auto-trigger here cannot react to producer-side drift.
2. **Approval-policy / 2 h timeout** — intentionally untouched; lowering needs team consensus and is out of scope for this PR.
3. **Sibling-directory boundary** — `terraform/sandbox-extras/` (if added later) not covered by `terraform/sandbox` prefix-match.
4. **Template `azure-oidc-validate-and-apply.yaml@2.6.9` opaque on `Build.Reason`** — first auto-triggered run reveals; revert if regression observed.
5. **Sandbox-only blast radius** — no acc/prd impact; varFile + serviceConnection pinned (yaml lines 6-7, 39).
