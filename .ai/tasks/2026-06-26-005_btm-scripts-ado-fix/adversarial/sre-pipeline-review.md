---
task_id: 2026-06-26-005
agent: sre-maniac
status: complete
summary: |
  Adversarial runtime review of the BTM tag-step relocation fix. The identity fix
  (mechanism 1) and stage gating (mechanism 3), deploy regression (4), agent capability
  (5), and no-az-login isolation (6) all SURVIVE on decisive evidence. One BROKEN finding
  blocks: the script's `git log --format=%B` has NO commit-range limit, so on the new
  standalone job's fresh shallow checkout it walks the ENTIRE shallow history
  (fetchDepth 10 for DEV, 100 for ACC/PRD) and harvests work items from UNRELATED PRs.
  Measured blast radius: 7 distinct work items on a depth-10 DEV checkout (only 1 belongs
  to the triggering PR); 57 on a depth-100 ACC/PRD checkout — every prior PR's work items
  get the env tag on every deploy. This is a pre-existing latent bug the original also had,
  but the new comment block explicitly claims to fix the script's "latent bugs" while
  leaving this one, and the relocation does not change the over-tagging behavior.
---

# SRE Adversarial Review — BTM Tag-Step Relocation Fix

## Key Findings

- **mechanism_1_identity: SURVIVES** — env-mapped System.AccessToken resolves to Project Build Service identity in a standalone job, same mapping the old inline step used
- **mechanism_2_git_history: BROKEN** — unbounded `git log --format=%B` tags work items from unrelated PRs within the shallow checkout depth (7 on DEV depth-10, 57 on ACC/PRD depth-100)
- **mechanism_3_dependson_condition: SURVIVES** — dependsOn names match deployment jobs; stage conditions gate ACC/PRD to main; trigger is main-only
- **mechanism_4_deploy_regression: SURVIVES** — tag step had no side effects the deploy depended on; removal is inert to deploy/environment/approval
- **mechanism_5_agent_capability: RESIDUAL** — relies on az + azure-devops ext being preinstalled on ubuntu-24.04; same assumption as the old step, but unpinned
- **mechanism_6_no_az_login: SURVIVES** — checkout:self performs git credential auth only, leaves no `az login` session; the bug is not reintroduced

**Target:** `Eneco.Vpp.BehindTheMeter` branch `fix/NOTICKET/fix-tagging-script-pipeline`
**Files:** `azure-pipelines/deploy-terraform.pipeline.yml`, `azure-pipelines/steps/azure-boards-add-tag.sh`
**Win condition:** prove the fix fails at runtime / does not run as the Build Service identity / breaks the deploy.
**Overall verdict:** **FIX-FIRST** — the identity relocation is correct and the deploy is safe, but a BROKEN over-tagging mechanism in the script ships work-item tag pollution on every run.

All evidence is from read-only `git`/`Read`/`WebFetch` probes against the repo on 2026-06-26. My output is INFER until the lead source-verifies.

---

## Mechanism 1 — System.AccessToken in a standalone (non-deployment) job

**VERDICT: SURVIVES**

Decisive evidence:

- The new jobs map the token exactly as the old inline step did:
  `pipeline.yml:78-80` (DEV), `:125-127` (ACC), `:172-174` (PRD):
  `env: AZURE_DEVOPS_EXT_PAT: $(System.AccessToken)`.
- The OLD step (`git show HEAD:...pipeline.yml`, captured) used the identical
  `env: AZURE_DEVOPS_EXT_PAT: $(System.AccessToken)` mapping inside the deployment job.
  Nothing about the credential mapping changed — only the surrounding job changed.
- Microsoft docs (learn.microsoft.com/azure/devops/pipelines/build/variables, fetched):
  `System.AccessToken` is NOT auto-injected; it must be **explicitly mapped via `env:`**
  at step/task level — which this fix does. Once mapped, it is "available for use in
  regular build jobs, deployment jobs, any job type where you can configure environment
  variables." It "carries the security token used by the running build … typically the
  Project Build Service account."

So the attack ("token absent/empty in a standalone job") is FALSIFIED: a regular `job`
is not a weaker context than a `deployment` job for `System.AccessToken` — both require the
same explicit `env:` mapping, and both get the same Project Build Service identity.

`enforceJobAuthScope=true` does not break this: it constrains the token to the **current
project** ("Myriad - VPP"), which is exactly where area 6393 / Team BtM work items live.
The brief's already-verified diagnosis established the Build Service CAN read+tag (the SP
could not). Scope-limiting to the project does not remove that capability.

Residual (not blocking): IF the org/collection-level "Limit job authorization scope to
current project for non-release pipelines" were combined with an explicit ACL **deny** of
"Edit work items in this node" for the Build Service on Team BtM, tagging would fail. That
is an org-config state I cannot probe read-only, and the verified diagnosis says the Build
Service can tag. Confidence bounded: A2 INFER on capability, falsifier = a TF401019 from the
Build Service identity in the new job's log.

---

## Mechanism 2 — git history availability / over-harvest

**VERDICT: BROKEN (BLOCKING)**

This is the failure mode that makes the PR wrong as written.

The script (`azure-boards-add-tag.sh`, hardened diff) harvests IDs with:

```bash
work_items=$(git log --format=%B | grep -F 'Related work items:' | grep -Po '\d+' \
  | sort -u | paste -sd, - || true)
```

`git log` here has **NO `-n` / no revision range**. It walks every commit reachable from
HEAD in the job's checkout. The new standalone tag job does a **fresh** `checkout: self`
with `fetchDepth: 10` (DEV, `pipeline.yml:75-76`) or `fetchDepth: 100` (ACC/PRD,
`:122-123`, `:169-170`). So the harvest set = **all work-item references in the last
10 / 100 commits**, not the triggering PR's.

Measured blast radius (probed on this checkout, which mirrors a post-merge `main`):

- The PR merge commit is at HEAD and DOES carry its marker
  (`git log origin/main -n 1 --format=%B` → `Related work items: #854674`), so the happy
  path "the marker is reachable" holds — the attack's *shallow-too-thin* angle is FALSIFIED.
- But unbounded `git log` over a depth-10 view yields **7 distinct work items**:
  `824536,836210,837664,842803,845171,853190,854674` — six of which belong to OTHER PRs.
- Over a depth-100 view (ACC/PRD): **57 distinct work items**
  (`git log -n 100 --format=%B | grep -F 'Related work items:' | grep -Po '\d+' | sort -u | wc -l` → 57).

Every ACC deploy would attempt to write the `ACC` tag to 57 work items; every PRD deploy
the `PRD` tag to 57. The WIQL `[System.Tags] NOT CONTAINS '$TAG'` filter only suppresses
re-tagging items that already carry the tag — it does not scope to the current PR. After
the first run, steady-state churn is smaller, but the **first** ACC/PRD run after this PR
mass-tags historical work items with environment tags they never reached through this
deploy. That is silent, hard-to-reverse work-item metadata pollution across Team BtM.

Why this is a fix-quality finding, not just inherited debt: the original step ran in the
deployment job, which reused the **deploy checkout** — but that checkout used the SAME
`fetchDepth` (10/100), so the original had the SAME over-harvest. HOWEVER, the original
never actually tagged anything (it ran as the SP and got TF401019 / empty). This fix is the
**first time the script will successfully tag at scale** — so the latent over-harvest bug
goes from dormant to active **because of this fix**. And the new comment block
(`azure-boards-add-tag.sh` header) explicitly advertises "ROOT-CAUSE HARDENING also fixes
two latent bugs," establishing intent to fix script bugs while leaving the highest-blast
one in place.

Route Y (conditional belief-change): scope the harvest to the triggering PR's commits, e.g.
`git log -1 --format=%B` if the merge commit body carries the full work-item list (it does,
per the HEAD probe above — the squash/merge message aggregates `Related work items:`), OR
range to the previous deploy's commit. Verify the merge message is the single source before
narrowing. If a single-commit harvest is adopted, fetchDepth could even shrink to 1.

---

## Mechanism 3 — dependsOn + stage condition (runs when it should, not spuriously)

**VERDICT: SURVIVES**

- `dependsOn` references resolve to the deployment job names:
  `ApplyTagDevelopment.dependsOn: ApplyDevelopment` (`:73` → deployment at `:47`),
  `ApplyTagAcceptance.dependsOn: ApplyAcceptance` (`:120` → `:98`),
  `ApplyTagProduction.dependsOn: ApplyProduction` (`:167` → `:145`). Names match exactly.
  A failed deploy → dependent tag job is skipped (default `succeeded()` dependency
  semantics). Attack "tags apply after a failed deploy" FALSIFIED.
- ACC/PRD tag jobs inherit their stage's gate:
  `Acceptance` and `Production` stages carry
  `condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))`
  (`:96`, `:143`). Jobs do not run if the stage is skipped.
- `Development` stage has no condition, but the CI `trigger` is `branches: include: [main]`
  only (`:1-9`) and there is no `pr:` block, so the pipeline does not run as PR validation
  unless wired as branch-policy build validation (not visible in YAML). On a `main` CI run,
  `Build.SourceBranch == refs/heads/main`, so even the ACC/PRD branch checks pass legitimately.

Residual (LOW): IF this pipeline is additionally configured as PR build validation in branch
policy (org state, not in YAML), the Development stage (no condition) WOULD run on PR builds
and — combined with mechanism 2 — would DEV-tag the PR's reachable history. The over-harvest
in mechanism 2 is the real damage amplifier here; fixing mechanism 2 also bounds this.

---

## Mechanism 4 — deploy regression from removing the inline step

**VERDICT: SURVIVES**

The removed inline step (`git show HEAD:...`, captured) was a terminal `script:` that only
called `az boards`. It produced no files, no Terraform state, no environment/approval side
effects, and nothing downstream in the deployment job consumed its output (it was the last
step). Removing it is inert to the deploy. Terraform apply (`steps/terraform.yml`) is
untouched. The `environment:` targets and approval gates are stage/deployment-scoped and
unaffected by adding a sibling `job`. Attack FALSIFIED.

One ordering note (not a regression): the tag job now runs as a **separate job** after the
deploy job completes, on a **different agent**, so tagging no longer shares the deploy
agent's state. That is the intended isolation and is fine — the script only needs git +
az boards, both re-established by the fresh checkout (see mechanism 6).

---

## Mechanism 5 — agent capability (az + azure-devops extension on ubuntu-24.04)

**VERDICT: RESIDUAL (LOW)**

The new jobs inherit the top-level `pool: vmImage: ubuntu-24.04` (`:17-18`); no `pool:`
override on the tag jobs (confirmed by Read — only `checkout` + `script`). Microsoft-hosted
`ubuntu-24.04` ships the Azure CLI preinstalled, and `az boards` is part of the
`azure-devops` extension, which on Microsoft-hosted images is generally preinstalled.

This SURVIVES on parity grounds: the OLD inline step relied on the identical assumption
(same image, same `az boards`, no install step) and the brief's diagnosis confirms it got
far enough to hit TF401019 — i.e. `az boards` WAS present and executed. So the capability is
empirically there.

Residual: neither the old nor the new step pins the extension or runs
`az extension add --name azure-devops`. If Microsoft drops the preinstalled extension from a
future ubuntu-24.04 image, both old and new break identically. Not introduced by this fix;
worth a one-line hardening (`az extension add -n azure-devops || true`) but non-blocking.

---

## Mechanism 6 — does checkout:self reintroduce an az login session?

**VERDICT: SURVIVES**

`checkout: self` performs **git** authentication only (the agent's git credential/extraheader
using the job access token) to clone the repo. It does not invoke `az login` and leaves no
Azure CLI account context on the agent. The bug under repair is specifically that
`azure-login.yml` runs `az login --service-principal` (`azure-login.yml:6-9`), which is the
ONLY thing that creates the SP `az` session the azure-devops CLI then prefers. The new tag
jobs do not include `azure-login.yml` (confirmed by Read — the templates are absent from
`ApplyTag*`). Therefore `az boards` in the new job has no `az login` session to inherit and
falls back to `AZURE_DEVOPS_EXT_PAT` = `System.AccessToken` = Build Service. Attack
("checkout reintroduces the login") FALSIFIED — git credential auth ≠ `az` CLI auth.

---

## Findings

| Sev | Mechanism | Finding | Route |
|-----|-----------|---------|-------|
| **BLOCKING** | 2 | `git log --format=%B` is unbounded; on the new job's fresh shallow checkout it harvests work items from unrelated PRs (7 on DEV depth-10, 57 on ACC/PRD depth-100). This fix makes the tagging *succeed* for the first time, activating a dormant over-tagging bug. The header comment claims to fix the script's "latent bugs" but leaves this one. | Scope harvest to the triggering PR's merge commit (`git log -1 --format=%B`, after verifying the merge body aggregates all `Related work items:` lines) or to the range since the last deploy; then fetchDepth can shrink. |
| LOW | 3 | If the pipeline is also wired as PR build-validation in branch policy (not in YAML), the unconditioned Development stage runs on PR builds and DEV-tags PR history. Damage is amplified by mechanism 2. | Fixing mechanism 2 bounds this; optionally add a SourceBranch condition to the Development stage if PR validation is configured. |
| LOW | 5 | `azure-devops` CLI extension is assumed preinstalled on ubuntu-24.04; unpinned (same as the old step). | Add `az extension add -n azure-devops || true` before the boards calls. |
| LOW | 1 | Build Service work-item edit capability on Team BtM is taken from the verified diagnosis, not re-probed under the new job. | Falsifier = TF401019 from the Build Service identity in the first real run; watch the first DEV tag job log. |

## What would have broken it, that did NOT

- IF `System.AccessToken` required a deployment-job context → would break mechanism 1. It does
  not; explicit `env:` mapping is the only requirement and it is present.
- IF the PR's `Related work items:` marker lived only in unmerged feature commits below the
  fetch depth → would break mechanism 2's happy path. It does not; the marker is in the merge
  commit at HEAD. The break is the OPPOSITE — too MANY commits are reachable, not too few.
- IF `dependsOn` named the stage instead of the job, or misspelled the job → tag job would
  error or run out of order. Names match exactly.

**Overall: FIX-FIRST.** The identity relocation — the actual purpose of the PR — is correct
and the deploy is unharmed. But shipping it as-is will mass-tag historical work items across
Team BtM on the first ACC/PRD deploy. Bound the harvest to the triggering PR before merge.
