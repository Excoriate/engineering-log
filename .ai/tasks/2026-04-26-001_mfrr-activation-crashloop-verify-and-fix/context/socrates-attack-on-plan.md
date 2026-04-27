---
task_id: 2026-04-26-001
agent: socrates-contrarian
status: complete
summary: Adversarial review of trigger-yaml change for terraform-cd-sandbox.pipeline.yaml. Two findings change the plan; one residual risk; otherwise PROCEED with amendments.
---

# Verdict
PROCEED-WITH-CHANGES

# Top-3 changes the plan must absorb

1. **Use recursive globs (`**`), not `*`.** Per Microsoft Learn `learn.microsoft.com/en-us/azure/devops/pipelines/build/triggers#paths`: `*` matches a single segment; `**` is recursive. `configuration/terraform/sandbox/*` and `terraform/sandbox/*` work today (no subdirs exist) but if anyone ever adds `terraform/sandbox/modules/x.tf` or `configuration/terraform/sandbox/overrides/y.tfvars`, the trigger silently misses — exact recurrence shape of today's bug. Replace both with `**`, OR use bare directory paths (`terraform/sandbox`, `configuration/terraform/sandbox`) which ADO docs treat as recursive.

2. **Path filter is incomplete: `terraform_remote_state.platform_shared`.** `terraform/sandbox/data.tf:6-15` reads `tfstate-platform/sandbox-shared.tfstate`. Outputs feed `service-bus.tf`, `redis.tf`, `kusto-cluster.tf`, `cosmos-db.tf`, `cosmosdbmongo.tf`, `sql-database.tf` (vnet/subnet/sql ids). If the producer of `sandbox-shared.tfstate` lives in this repo at a path NOT in the filter (likely `terraform/platform-shared/**` or a separate pipeline), changes there mutate sandbox-consumed values without triggering this pipeline. Plan §Q3 missed this. **Action**: user confirms producer; if in-repo → add path; if separate pipeline → document as cross-pipeline residual in PR.

3. **PR description must state sufficiency limit.** Approval gate (`applyCondition` line 41 + `azureDevOpsEnvironmentName: terraform-sandbox` line 31, untouched) keeps the 2h timeout that caused build 1616964's skip. Auto-trigger turns invisible drift into a visible queue of pending approvals — strictly better, but does NOT prevent end-to-end recurrence if no approver acts. State explicitly in PR: "trigger fix only; approval-policy intentionally out of scope."

# Q1-Q8 attack notes

**Q1 — Glob.** `*` = single segment, `**` = recursive (MS Learn `triggers#paths`). Today both globs match the actual files (`ls` confirmed: 2 files in `configuration/terraform/sandbox/`, 24 top-level in `terraform/sandbox/`, no subdirs). Future-proof with `**` per Top-3 #1.

**Q2 — `pr: none`.** ADO schema treats `pr` and `trigger` as sibling root keys; order irrelevant. Without `pr: none` ADO defaults to running on every PR to main (applyCondition blocks apply, but plan runs and shows red). Current placement correct. PROCEED.

**Q3 — Chicken-and-egg.** No. ADO evaluates triggers from the YAML AT the commit being tested. Merge commit touches `.azuredevops/pipelines/terraform-cd-sandbox.pipeline.yaml` (in filter) → new YAML read → build queued on the merge commit itself. Standard documented behavior. PROCEED.

**Q4 — Sandbox/fbe coupling.** (a) `grep` for `../fbe` / `/fbe"` in `terraform/sandbox/*.tf` → 0. (b) **YES** remote-state coupling at `data.tf:6-15` (see Top-3 #2). (c) Shared resources owned by sandbox modules. (d) `workingDirectory = $(Build.SourcesDirectory)/terraform/sandbox` (pipeline line 13) — terraform CWD cannot see `terraform/fbe/*.tf`. "fbe" strings in three logic-app JSON files are default-name references to prod logic apps, not module sources. **Direct: clean. Remote-state: REAL.**

**Q5 — Approval gate.** Trigger fix is INCOMPLETE for end-to-end prevention; 2h timeout still bites with no approver. Plan §Q6 defers approval-policy. Visible queue > invisible drift. Surface in PR per Top-3 #3.

**Q6 — Template sensitivity.** Cannot fully falsify — template `CCoE/azure-devops-templates@2.6.9` opaque this session. Counter-evidence: `Build.SourceBranch` identical for IndividualCI/BatchedCI/Manual on main; visible gate is `applyCondition: eq(...,'refs/heads/main')`. Residual: template could check `Build.Reason == 'Manual'` (low probability — hostile design). First auto-triggered run reveals.

**Q7 — Other yamls.** Repo-wide `find`: only two yamls have triggers — the one we edit + `pull-request-validation.yaml` at repo root (`trigger: include: "*"`, runs `code-quality` template; no apply, no approval). PR-val is at repo root (not in our path filter) but self-triggers on `*`. After our change a qualifying merge produces two builds (code-quality + terraform-cd-sandbox). **No conflict.**

**Q8 — Worst realistic outcome.** Plausible: future merge with destructive `sandbox.tfvars` change; approver rubber-stamps; apply destroys sandbox resources. Risk exists TODAY via manual-run + approve; auto-trigger doesn't enlarge it, just makes it more frequent. Defense is approval-gate culture, not trigger. Implausible (trigger bypasses approval): `applyCondition`/Environment untouched, Environment checks server-side, not bypassable by trigger type. Cross-env blast: zero — varFile + serviceConnection pinned to sandbox; acc/prd CDs untouched. **Net: rubber-stamped destructive sandbox change. Sandbox-only, recoverable. Not amplified by this PR.**

# Residual risks I cannot falsify

1. **`sandbox-shared.tfstate` producer location.** If in this repo at unfiltered path, drift recurs via different vector. User to confirm.
2. **Template `azure-oidc-validate-and-apply.yaml@2.6.9` internals** w.r.t. `Build.Reason`. First post-merge run reveals.
3. **Implicit `pr` default across ADO versions.** Documented `pr: ['*']` when unset; suppressed by `pr: none`. Low edge-case risk.
4. **First auto-trigger timing.** Off-hours merge → no approver → 2h timeout → skip; same outcome as today but with visible build artifact. Operational, not technical.
