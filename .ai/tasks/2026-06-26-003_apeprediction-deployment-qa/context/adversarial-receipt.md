---
title: Adversarial receipt — ape-prediction ACC/PROD deployment isolation claim
task_id: 2026-06-26-003
agent: sre-maniac
status: complete
timestamp: 2026-06-26
summary: |
  Attacked the central claim that every ape-prediction build writes the same image
  tag into dev/acc/prod folders of VPP-Configuration in one commit, with prod runtime
  rollout gated only by manual ArgoCD sync. Verdict: the claim is SUBSTANTIALLY CORRECT
  and UPHELD on its core mechanism (unconditional values-override step + all three env
  flags true in group 604 + acc/prod having no automated syncPolicy while dev-mc/sandbox
  do). Two corrections required: (a) Lane 4 cluster-separation wording is WRONG as stated
  — all envs use destination https://kubernetes.default.svc, so isolation is per ArgoCD
  instance/cluster, not per destination URL; the prod app-of-apps does NOT prove a
  separate cluster from the gitops repo alone. (b) trigger:none means builds are manual,
  and the var-group key written is `apeprediction` (=$(services)) not `ape-prediction`/
  `ape_prediction` — live group shows apeprediction=1.193 while git overrides lag at
  prod/acc=1.168, dev=1.176, proving the var-group write and the git-commit write are
  decoupled and the git desired-state is currently BEHIND the latest build.
---

# Adversarial Receipt — ape-prediction ACC/PROD Isolation

BRAIN SCAN (my own P1, per [BRAIN_SCAN_REQUIRED]): Dangerous assumption = the
values-override step is unconditional and writes all three folders. Falsifier =
a `condition:`/`${{ if }}` guard on stage/job/step, OR the `${!i}` indirection /
folder mapping not reaching prod, OR an `automated:` block for acc/prod, OR a
parent app-of-apps carrying cascade auto-sync. Frame: sre-maniac (operator /
failure-path), evidence from `git show HEAD:` bytes only. I attacked, did not
rubber-stamp; one sub-claim (Lane 4) is REFUTED-as-worded.

Evidence source = `git -C <checkout> show HEAD:<path>` and live `az pipelines
variable-group show --group-id 604`. File:line references are to the HEAD blob
content shown during this review.

## Lane 1 — Is "Update values-override.yaml" really unconditional? → UPHELD

- `azurepipelines.yml` task `displayName: Update values-override.yaml for $(services)`
  is a `Bash@3` step with NO `condition:` and NO `${{ if }}` template guard. It sits
  inside `stage: build_ape_prediction` → single unnamed `job:` which also carry no
  `condition`. Contrast: the LATER `HelmDeploy@0` step DOES carry
  `condition: eq(variables['Build.SourceBranch'], 'refs/heads/develop')`. So the git
  write is unconditional; only the direct AKS helm-deploy is branch-scoped. UPHELD.
- Caveat to surface (not a refutation): `trigger: none` at the top of the file — this
  pipeline has NO automatic CI trigger. Builds are started manually / by another
  pipeline. "Every build" is accurate, but "every build" requires someone to RUN it;
  it is not auto-fired on every commit. The deliverable should say "every build that
  runs" not imply commit-triggered automation.

## Lane 2 — Are test-env/acc-env/prod-env consumed as described? → UPHELD

- The step body literally sets `dev=$(test-env)`, `acc=$(acc-env)`, `prod=$(prod-env)`
  then `for i in dev acc prod; do if [[ "${!i}" == "true" ]]; then
  foldername="Helm/$(services)/$i" ...`. The `${!i}` indirection resolves to the value
  of the shell var named by `$i` (dev→$dev→test-env value, etc.). Folder mapping is
  `Helm/apeprediction/{dev,acc,prod}`. All three folders exist in the git tree
  (`git ls-tree`: Helm/apeprediction/{dev,acc,prod}/values-override.yaml). UPHELD.
- Live group 604 confirms `test-env=true`, `acc-env=true`, `prod-env=true`. With all
  three "true", the loop writes/overwrites all three override files with the SAME
  `$(imagetag)` and `git add . && git commit && git push origin HEAD:main`. So one
  build = one commit touching dev+acc+prod desired-state. UPHELD.
- Attack that FAILED to break it: the `$(test-env)` etc. are macro-expanded by ADO at
  runtime from the variable group (the preceding "Update variable group" step also
  re-publishes group vars via `setvariable`). For prod to NOT be written, prod-env
  would have to be non-"true" — it is "true". No break found.

## Lane 3 — Is prod ArgoCD truly manual-sync (no automated:)? → UPHELD

- `vpp-core-app-of-apps/templates/application.yaml` resolves per-app syncPolicy as:
  `{{ if $app.syncPolicy }} ... {{- else if $root.Values.global.syncPolicy }} ...`.
  The `apeprediction-eneco-vpp` app entry in BOTH `values.vppcore.acc.yaml` and
  `values.vppcore.prod.yaml` has NO per-app `syncPolicy`, so it inherits
  `global.syncPolicy`.
- `global.syncPolicy` in `values.vppcore.acc.yaml` and `values.vppcore.prod.yaml`
  contains ONLY `syncOptions: [PruneLast=true, Replace=false]` — NO `automated:` block.
- `global.syncPolicy` in `values.vppcore.devmc.yaml:23` and
  `values.vppcore.sandbox.yaml:31` DO contain `automated: {prune:true, selfHeal:true}`.
- Repo-wide `git grep "automated:"` returns ONLY: telemetry app (separate chart),
  vppcore devmc, vppcore sandbox, and default-alerting app-of-apps. acc/prod vppcore
  are absent. So acc + prod = manual sync; dev-mc + sandbox = automated. UPHELD exactly
  as claimed.

## Lane 4 — Does prod app-of-apps deploy to a SEPARATE cluster? → OVERSTATED / partially REFUTED as worded

- The claim's parenthetical "in-cluster kubernetes.default.svc ... separate cluster"
  is internally inconsistent and the gitops repo alone does NOT prove separate clusters.
  ALL env value files (acc, prod, devmc, sandbox) set
  `global.cluster.url: https://kubernetes.default.svc`. `kubernetes.default.svc` means
  "the cluster this ArgoCD instance runs in." So the app-of-apps does NOT encode a
  remote cluster destination for prod; each env's app-of-apps is expected to be applied
  to a DIFFERENT ArgoCD instance / cluster, and the separation lives in WHERE each
  values.vppcore.<env>.yaml is consumed, NOT in the destination URL.
- Therefore the git repo CANNOT, by itself, prove acc and prod are different clusters.
  If two env app-of-apps were ever applied into the same ArgoCD/cluster, the Application
  names (`apeprediction-eneco-vpp`) and namespace (`eneco-vpp`) are IDENTICAL across acc
  and prod — they would COLLIDE. Isolation depends on an out-of-repo invariant: acc and
  prod ArgoCD instances are distinct and each is fed only its own values.vppcore file.
  This is an UNVERIFIED[blocked] assumption from the repo; it must be stated as such, not
  asserted as fact.
- CORRECTION REQUIRED: drop the "separate cluster (in-cluster kubernetes.default.svc)"
  phrasing. Replace with: "each env's app-of-apps targets its own in-cluster ArgoCD
  (destination kubernetes.default.svc); cross-env isolation relies on acc and prod being
  separate ArgoCD instances/clusters fed only their own values.vppcore.<env>.yaml — a
  fact NOT provable from the gitops repo, confirm against the ArgoCD/cluster inventory."

## Lane 5 — Is the recommendation (prod-env=false for non-prod / split group-or-pipeline) safe & sufficient? → OVERSTATED

Failure modes the recommendation must account for:

1. The variable group is a SHARED singleton (group 604), read at runtime by every run.
   `prod-env` is NOT a per-run parameter — it is group state. Flipping `prod-env=false`
   changes it for ALL concurrent and subsequent runs until flipped back. A naive "set
   false before an acc build, true before a prod build" is a RACE: two builds in flight,
   or a forgotten reset, silently mis-target. So "set prod-env=false for non-prod builds"
   is NOT safe as a per-run toggle on the shared group. REFUTED as a standalone fix.
2. Equally, `test-env`/`acc-env`/`prod-env` all being true is almost certainly the
   DESIRED promotion model here: one build → write the same tag to all three folders →
   dev auto-syncs, acc/prod wait for manual sync. Setting prod-env=false would stop the
   prod desired-state in git from ever being updated by this pipeline, breaking prod
   promotion entirely (prod override would freeze at 1.168). So the "safe" fix actually
   BREAKS the intended promotion flow unless paired with a separate prod-promotion path.
3. The genuinely safe options are structural, not a flag flip: (a) split into per-env
   pipelines/stages each with its OWN variable group so the env flag is config-as-code
   not mutable shared state; or (b) make env selection a pipeline runtime PARAMETER
   (queue-time), never a shared mutable group var; or (c) accept the current model and
   make the manual prod ArgoCD sync the deliberate, audited gate (which is what acc/prod
   manual syncPolicy already provides) — i.e. document that git desired-state coupling is
   intentional and runtime isolation is the manual-sync control.
- CORRECTION REQUIRED: the recommendation must NOT present "set prod-env=false" as a
  safe per-build toggle on group 604. It must flag the shared-mutable-state race and the
  prod-promotion-breakage, and pivot to per-env pipeline/parameter separation OR an
  explicit "manual prod sync is the intended gate" framing.

## Additional finding surfaced during attack (not in original 5 lanes)

- The var-group key the pipeline writes is `apeprediction` (`$(services)`), NOT
  `ape-prediction` (empty) nor `ape_prediction` (dev.a5c3a97). Live group 604 shows
  `apeprediction=1.193`. The git overrides show prod/acc tag `1.168` and dev `1.176`.
  The var-group value (1.193) is AHEAD of the git desired-state (≤1.176). This proves the
  two writes are DECOUPLED: the "Update variable group" step and the "Update
  values-override.yaml" git commit do not move in lockstep, and the git desired-state can
  lag the latest built image. The deliverable should not conflate "variable group tag" =
  "git desired-state tag"; the runtime/ArgoCD source of truth is the git override file,
  not group 604.

## Overall verdict: UPHELD with required corrections (claim is substantially correct, NOT wrong)

The central mechanism — unconditional values-override step (Lane 1), all three env flags
true driving a single commit into dev/acc/prod (Lane 2), and acc/prod having no automated
syncPolicy while dev-mc/sandbox do, so prod runtime rollout is gated by manual ArgoCD sync
(Lane 3) — is CONFIRMED from source. The claim is correct that an ACC-intended build also
mutates PROD desired-state in git.

Mandatory corrections the deliverables MUST make:
1. Lane 4: remove the "separate cluster" assertion; all destinations are
   kubernetes.default.svc; cluster/instance isolation is an out-of-repo invariant to be
   verified, state it as UNVERIFIED[blocked] from the gitops repo.
2. Lane 5: do NOT recommend `prod-env=false` as a safe per-build toggle on shared group
   604 (race + breaks prod promotion); recommend per-env pipeline/parameter separation,
   or explicitly frame the manual prod sync as the intended gate.
3. Add the trigger:none caveat ("every build that runs", builds are manual, not
   commit-triggered).
4. Clarify git override file (not var-group 604 value) is the ArgoCD desired-state source
   of truth; note current lag (group 1.193 vs git ≤1.176).
