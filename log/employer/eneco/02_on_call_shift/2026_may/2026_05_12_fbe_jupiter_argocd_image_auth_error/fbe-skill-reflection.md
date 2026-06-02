---
title: "Reflection — what `eneco-fbe-troubleshoot` skill must contain for 100% confident handling of the source-1 credential-coverage class"
type: research
domain: tech
status: complete
created: 2026-05-12
authors: [alex-torres]
purpose: |
  This file is NOT a skill edit. It is an enrichment specification: the gaps a
  future agent (or future-me) would hit if they tried to tackle this same
  incident class using only the current skill at
  `std/skills/10_employer/eneco/eneco-fbe-troubleshoot`. Each gap is named, the
  inefficiency or mistake it caused in this session is cited, and the specific
  enrichment that would prevent the inefficiency is proposed.
target_skill: /Users/alextorresruiz/Dropbox/@GITHUB/@oss/stdlib/std/skills/10_employer/eneco/eneco-fbe-troubleshoot
related:
  - rca.md
  - context.md
  - fix.md
  - .ai/tasks/2026-05-12-001_fbe-jupiter-argocd-auth/verification/adv-*.md
---

# Skill enrichment reflection — eneco-fbe-troubleshoot

This document audits **every false start, wrong default, missed efficiency, and
correction during 2026-05-12 incident handling** and maps each to a specific
enrichment in the skill. The acceptance criterion for the enriched skill: a
future agent landing on jupiter's "FBE not updating images, authentication
error" intake at 2026-05-12T12:20 UTC should be able to:

1. Identify the class (Application source-1 credential coverage gap) within **3 probes**, not 12
2. Apply the fix via the **idiomatic surface** (argocd CLI or UI) without defaulting to kubectl
3. Skip the broad-prune-disable mutation and rely on `selfHeal` natural cascade with **confidence**, not as a discovered shortcut
4. Recover the platform in **<10 minutes total** wall-time (from intake to ALL CLEAR), not 60+
5. Make **zero false-confidence claims** to user (no "PAT expiry" misdiagnosis, no "1 simple Secret" framing while overlooking 67-app blast)

---

## Section 1 — Audit of inefficiencies and corrections in this session

### 1.1 — Misdiagnosed class on first impression (cost: ~10 min)

**What happened**: User reported "jupiter FBE not updating images, authentication error". The catalogued pattern `pattern-argocd-pat-expiry-blocks-new-fbe-apps` from yesterday's incident had the same `authentication required` symptom. **Initial mental model defaulted to that class.**

**The actual class is distinct**: the catalogued pattern fires at the `ApplicationSet generator` level (one symptom is `ApplicationGenerationFromParamsError` on the ApplicationSet status). Today's class fires at the `Application source-1 manifest generation` level (`ComparisonError` on the Application, with `source 1 of N`). Same error string, different surface, different fix.

**What I missed**: a discriminator probe BEFORE assuming class. The discriminator is:

```bash
# A. Does the ApplicationSet generator currently fail?
kubectl get applicationset vpp-feature-branch-environments -n argocd \
  -o jsonpath='{.status.conditions}' | jq '.[] | select(.type=="ErrorOccurred")'
# If status=True → catalogued PAT-expiry class (ApplicationSet level)
# If status=False → THIS class (Application source level)

# B. Counter-probe: how many Applications are in ComparisonError WITH source-N substring?
kubectl get applications.argoproj.io -A -o json | jq -r '
  .items[] | . as $a | ($a.status.conditions // []) |
  map(select(.type=="ComparisonError" and (.message|test("source [0-9]+ of [0-9]+"))))
  | if length>0 then $a.metadata.namespace+"/"+$a.metadata.name else empty end
' | wc -l
# If >>0 → THIS class
```

**Enrichment proposed for skill — Decision Framework 1** (Classify The Incident, currently in skill): add a discriminator row:

| Signature | Class | Recipe |
|---|---|---|
| **ApplicationSet** `vpp-feature-branch-environments` status `ErrorOccurred=True` with `authentication required` | catalogued PAT-expiry class | `recipe-rotate-argocd-sandbox-pat` |
| **ApplicationSet** status `ErrorOccurred=False` AND ≥1 Application has `ComparisonError: ... source N of M: ... authentication required` | **NEW** — Application source-N credential-coverage gap | **NEW recipe needed** — see Section 3.1 |
| Both above are true simultaneously | Cascading credential failure | Fix both planes (rotate PAT for ApplicationSet AND register credential template for source-N coverage) |

### 1.2 — Defaulted to kubectl over argocd CLI / UI (cost: user correction round-trip, ~5 min)

**What happened**: My `fix.md` Phase B used `kubectl apply -f -` for the Secret YAML. User had to ask "why not via the UI or argocd CLI?" — both equivalent, both idiomatic.

**Why I defaulted to kubectl**: yesterday's recipe (`recipe-rotate-argocd-sandbox-pat`) uses `kubectl patch secret` for the analogous step. I pattern-matched.

**Why kubectl is the wrong default for THIS class**: yesterday's recipe was patching an EXISTING Secret's password — kubectl is natural. This class CREATES a NEW credential template — argocd CLI's `argocd repocreds add` has the field shape built in and is validated by ArgoCD's own logic.

**Enrichment proposed for skill — new "Apply Surface Decision" section**:

```text
WHEN you need to add a NEW credential template:
  PREFER argocd CLI: `argocd repocreds add <URL> --username U --password P` (or --password-stdin)
  EQUIVALENT: ArgoCD UI → Settings → Repositories → + CONNECT REPO → toggle "Credentials Template"
  LAST RESORT: kubectl apply Secret YAML (use only if argocd CLI auth is dead AND --core mode unavailable)

WHEN you need to PATCH an existing credential Secret's password (e.g., PAT rotation):
  PREFER kubectl: `kubectl patch secret <name> -n argocd --type=json -p='[{"op":"replace",...}]'`
  REASON: argocd CLI does not support editing an existing repocreds; it can only add or remove.
```

### 1.3 — Didn't know about `argocd --core` mode (cost: ~3 min + user prompt)

**What happened**: When `argocd account get-user-info` returned `AADSTS700082: refresh token expired`, my first response was "you (user) need to re-auth via `argocd login --sso`". The user pushed back: "try to connect to argocd CLI yourself."

**The workaround**: argocd CLI has a `--core` flag that bypasses the argocd-server gRPC entirely and uses kubectl context's cluster-admin to talk directly to the Kubernetes API. This means:

```bash
# Step 1: clear the expired AAD token from argocd CLI's config cache
mv ~/.config/argocd/config ~/.config/argocd/config.bak.$(date +%s)

# Step 2: ensure kubectl default namespace is argocd (so argocd-cm ConfigMap resolves)
kubectl config set-context --current --namespace=argocd
# OR: export ARGOCD_NAMESPACE=argocd

# Step 3: use --core mode
argocd repocreds list --core
argocd repo list --core
argocd app list --core
argocd repocreds add --core <URL> --username U --password P
```

**Caveats discovered**:
- `argocd --core` still honors AppProject RBAC — e.g., `argocd app get --core dispatchermfrr -N afi` may return `PermissionDenied: namespace 'afi' is not permitted` because the embedded server runs with no user identity. Read-only LIST operations work fine; per-Application access may not.
- For per-Application reads, fall back to `kubectl get application <name> -n <ns> -o yaml` (which uses cluster-admin cert — always works).

**Enrichment proposed for skill — new "Tool Auth Ladder" reference table**:

| Op | Preferred | If primary fails | Fallback |
|---|---|---|---|
| Read Application status | `argocd app get --core` | RBAC denied → use kubectl | `kubectl get application -n <ns> -o yaml` |
| List Applications cluster-wide | `kubectl get applications.argoproj.io -A` | — | (always works) |
| List Repositories / credential templates | `argocd repo list --core` / `argocd repocreds list --core` | argocd config cached AAD token → move config aside | `kubectl get secret -n argocd -l argocd.argoproj.io/secret-type=repository/repo-creds -o ...` |
| Add new credential template | `argocd repocreds add --core` | (requires kubectl admin) | `kubectl apply` raw Secret YAML |
| Patch existing repo Secret | `kubectl patch secret` | — | (only option) |
| Trigger Application refresh | `argocd app get --core <app> --refresh` | RBAC denied → annotation | `kubectl annotate application <name> -n <ns> argocd.argoproj.io/refresh=normal --overwrite` |
| ArgoCD UI access | requires fresh AAD session | — | log in via browser; SSO redirect |

Add the **expired-token unblock procedure** (`mv ~/.config/argocd/config aside` + set kubectl default ns to argocd) as an explicit numbered subprocedure under "Tool Reality Probe Set".

### 1.4 — Didn't proactively inspect existing template URL form before designing fix (cost: ~5 min on adversarial round-trip)

**What happened**: My initial fix proposal had URL `https://enecomanagedcloud@dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/` (WITH trailing slash, per el-demoledor V2's suggestion). The existing working template `creds-870830599` has URL `.../VPP%20-%20Asset%20Optimisation` (NO trailing slash). Team convention: no trailing slash, no `_git/`, userinfo present.

**Why I missed this**: I designed the URL from first principles (longest-prefix-match logic) instead of pattern-matching the existing working template.

**Enrichment proposed for skill — new heuristic H-PATTERN-MATCH-FIRST**:

> When proposing a new ArgoCD configuration of any class that has an existing
> working sibling in the same cluster, **first inspect the sibling's exact form
> via `argocd repo list` / `argocd repocreds list` / `kubectl get secret -o yaml`
> and replicate the byte-for-byte shape.** Differences from convention are
> evidence-requiring; convention should be the default. This saves an adversarial
> round trip on URL forms, base64 encoding choices, label/annotation patterns,
> and naming.

### 1.5 — Proposed too-broad mutation (disable prune on 68 apps) when narrower was correct (cost: user correction; would have been ~20 min unnecessary mutation)

**What happened**: Adversarial review (sre-maniac) flagged BLOCKING risk: "22 hours of drift + `prune=true selfHeal=true` cascade across 60 Applications could silently destroy any manual cluster intervention." I incorporated this into fix.md Phase A4 as "patch syncPolicy.automated.prune=false on all 60 broken Apps before the credential lands."

**User correction**: "skip the first mutation, it's too broad — just argo and read-only checks."

**Why the user was right**: in Sandbox FBE specifically, the deployment contract IS "GitOps source-of-truth wins; manual cluster drift is fair game to be pruned." That's the operating contract of an FBE platform. The conservative adversarial framing was correct for production, not for Sandbox FBE.

**Enrichment proposed for skill — new principle "Mutation scope = deployment contract"**:

```text
PRINCIPLE — Match mutation scope to the deployment's own contract.

Sandbox FBE:
  - Contract: GitOps source-of-truth, ephemeral, designed for high churn
  - Manual cluster drift in slot namespaces is NOT expected to be preserved
  - selfHeal natural cascade is the DESIGNED recovery mechanism
  - → mutation scope: ONE credential template add. Do NOT batch-patch syncPolicy.

dev-MC / acc-MC / prd-MC:
  - Contract: stable, operator interventions may be deliberate
  - Manual cluster drift should be reviewed before pruning
  - → mutation scope: disable prune+selfHeal on affected apps, manual diff review,
    re-enable per-app after human approval. (i.e., the fix.md Phase A→F plan IS
    correct for these clusters.)

WHEN to use Phase A→F throttled rollout:
  - The cluster has heterogeneous prune-safety requirements
  - There's a real chance of recent manual intervention worth preserving
  - You don't have a clean baseline of what GitOps would render

WHEN to skip Phase A→F (use minimal mutation):
  - Sandbox FBE (the contract above)
  - Empty namespaces with no service workload (nothing to prune)
  - All affected apps are ephemeral / branch-scoped
```

Add to skill: an explicit **"Deployment Contract" classification table** mapping cluster → mutation-scope policy.

### 1.6 — Didn't proactively probe blast radius from the first kubectl call (cost: ~2 min)

**What happened**: User reported ONE Application (`jupiter/dispatchermfrr`). My first investigation focused on jupiter only. The cluster-wide pattern (60+ apps across 9 namespaces) was discovered piecemeal over 5 probes.

**Single one-shot probe that would have revealed scale immediately**:

```bash
kubectl get applications.argoproj.io -A -o json | jq '
  [.items[] | select((.status.conditions // []) | map(select(.type=="ComparisonError")) | length > 0)] |
  group_by(.spec.sources[0].repoURL // .spec.source.repoURL) |
  map({repoURL: .[0].spec.sources[0].repoURL // .[0].spec.source.repoURL, count: length, sample: .[0].metadata.namespace + "/" + .[0].metadata.name})
'
```

**Enrichment proposed for skill — new "First-look one-shot probe set"** (run within 60 seconds of intake):

```bash
# 0. Cluster identity + ArgoCD reachability
kubectl config current-context; kubectl get ns argocd -o jsonpath='{.metadata.name}{"\n"}'

# 1. Blast radius — same error across multiple Apps?
kubectl get applications.argoproj.io -A -o json | jq '[.items[]
  | select((.status.conditions // []) | map(select(.type=="ComparisonError")) | length > 0)] | length'

# 2. Symptom-source clustering — group by Source 1 URL
kubectl get applications.argoproj.io -A -o json | jq '
  [.items[] | select((.status.conditions // []) | map(select(.type=="ComparisonError")) | length > 0)
    | {ns: .metadata.namespace, name: .metadata.name, src1: (.spec.sources[0].repoURL // .spec.source.repoURL),
       err: (.status.conditions[0].message[0:80]), since: (.status.conditions[0].lastTransitionTime)}]
  | group_by(.src1) | map({src1: .[0].src1, count: length, since_window: [.[].since] | min + " ... " + max})'

# 3. ApplicationSet generator level health
kubectl get applicationset -A -o json | jq '
  .items[] | {name: .metadata.name, conditions: (.status.conditions // [] | map({type, status, lastTransitionTime, message: (.message[0:80])}))}'

# 4. Credential coverage — what's registered?
kubectl get secret -n argocd -l 'argocd.argoproj.io/secret-type in (repository,repo-creds)' -o json | jq '
  .items[] | {name: .metadata.name, type: .metadata.labels."argocd.argoproj.io/secret-type",
              user: (.data.username | @base64d), url: (.data.url | @base64d)}'

# 5. Time-of-first-failure clustering (identifies common trigger)
kubectl get applications.argoproj.io -A -o json | jq -r '
  .items[] | (.status.conditions // []) | .[] | select(.type=="ComparisonError") | .lastTransitionTime' | sort | uniq -c | sort -rn | head -10
```

Each probe is ONE line and produces an actionable output. Together they identify class + blast radius + trigger window in **<60 seconds**. Add this as the literal first-look section of the skill.

### 1.7 — Followed yesterday's recipe verification depth (cost: a load-bearing inference in the RCA)

**What happened**: Yesterday's recipe `recipe-rotate-argocd-sandbox-pat` Step 7 verifies "child Applications materialize for the slot" via `kubectl get applications.argoproj.io -n <slot> | wc -l`. This passed for kidu yesterday → "fix complete" was declared. But the child Applications, once materialized, still couldn't fetch their own Source 1 repos. The credential gap was at a DIFFERENT layer.

**Enrichment proposed for skill — new heuristic H-VERIFY-CAUSE-CLAIM-DEPTH**:

```text
HEURISTIC — Verification depth must equal the depth of the cause-claim.

CAUSE-CLAIM: "PAT-expiry blocked NEW FBE app generation"
WRONG verification: app-of-apps count appears in the slot namespace
RIGHT verification: per-Application source fetch succeeds AND each Application
                    has status.sync.revision advancing to a fresh SHA AND
                    no ComparisonError persists in any layer.

CAUSE-CLAIM: "Application source-1 credential resolution fails"
WRONG verification: credential template Secret exists in argocd namespace
RIGHT verification: at least one previously-broken Application's
                    status.conditions[] no longer contains ComparisonError AND
                    status.sync.revision is fresh AND repo-server log shows
                    successful git fetch for the URL.

GENERIC RULE: trace the cause chain from the observed symptom to the proposed
              fix; verify at the deepest CONSUMER surface, not at the SOURCE
              surface. Source-surface verification ("the Secret exists") proves
              process, not outcome. Consumer-surface verification proves outcome.
```

Add explicit verification-depth examples per class in the skill's Recipes section.

### 1.8 — Pattern doc and recipe in vault don't cover this class at all

**What happened**: The catalogued `pattern-argocd-pat-expiry-blocks-new-fbe-apps` doc and `recipe-rotate-argocd-sandbox-pat` recipe cover ONLY the ApplicationSet-generator-level failure. The per-Application source-credential-coverage class has no vault entry.

**Enrichment proposed for skill — new vault artifacts to author**:

| Artifact | Path | Status |
|---|---|---|
| Pattern | `$SECOND_BRAIN_PATH/2-areas/work-eneco/eneco-vpp-platform/fbe-errors/pattern-argocd-per-application-source-credential-gap.md` | **TO AUTHOR** (this incident's class) |
| Recipe | `$SECOND_BRAIN_PATH/.../fbe-errors/recipe-register-missing-credential-template.md` | **TO AUTHOR** (the executable for this class) |
| Incident page | `$SECOND_BRAIN_PATH/.../fbe-errors/2026-05-12-jupiter-source1-credential-gap.md` | **TO AUTHOR** (today's incident; references rca.md) |
| Index amendment | `$SECOND_BRAIN_PATH/.../fbe-errors/_index.md` symptom-→entry matrix | **TO AMEND** (new symptom row: "ApplicationSet healthy + Apps in ComparisonError with `source N of M: ... authentication required`") |
| Recipe amendment | `$SECOND_BRAIN_PATH/.../fbe-errors/recipe-rotate-argocd-sandbox-pat.md` Step 7 | **TO AMEND** (add per-Application verification depth) |

The skill should reference these directly. Until they exist, the skill is incomplete for this incident class.

### 1.9 — `.env.tmp` convention not anticipated by skill

**What happened**: User staged credentials in a `.env.tmp` file inside the log dir for me to read. The file was 21 bytes (much smaller than a PAT) — turned out it was either empty or in an unexpected format. I switched to extracting PAT from the in-cluster Secret instead.

**The convention IS useful** for cases where the credential isn't already in-cluster. Worth documenting.

**Enrichment proposed for skill — new "Credential intake conventions" section**:

```text
CREDENTIAL INTAKE — operator may provide credentials via:

1. IN-CLUSTER (preferred): extract from an existing working Secret
   PAT=$(kubectl get secret <existing-secret> -n argocd -o jsonpath='{.data.password}' | base64 -d)
   - Zero credential transit beyond the kubectl shell

2. 1Password CLI: `op read "op://Los Shaflas Torres/Job Eneco/Platform Service Account VPP/password"`
   - Requires user's `op` CLI session active
   - Vault: Los Shaflas Torres / Job Eneco
   - Item names observed: "Platform Service Account VPP",
     "Eneco Service Account sa-platform-vpp (Azure DevOps)",
     "ArgoCD Sandbox CD PAT Token Service Account"

3. Operator-staged `.env.tmp` in log dir (transient): if user mentions ".env" or
   "I've stored them in <path>", read the file with structure-first probe
   (`grep -E '^[A-Z_]+=' file | sed 's/=.*/=/'` shows key names without values).
   - File MUST be gitignored or untracked; verify via `git check-ignore` BEFORE reading
   - DELETE after use: `rm <path>`

4. Manual paste in chat (LAST RESORT): operator pastes PAT directly
   - Risk: chat transcript captures the bytes
   - Use only if 1-3 are unavailable

NEVER:
- Echo PAT bytes to stdout, log files, or chat
- Commit a .env file to git (even temporarily)
- Pass PAT as a positional CLI arg unless tool supports --password-stdin
```

### 1.10 — Hook conflicts cost time and trust early in the session

**What happened**: First 3 Bash calls were blocked by `task-workspace-guard.sh` because my manifest schema was incomplete (`created_files`, `modified_files` arrays missing; `preflight_complete: true` missing in sentinel). Took 3 hook failures before I read the hook source and discovered the required schema.

**Enrichment proposed for skill — link to harness invariants**:

```text
HARNESS INVARIANT — Before any non-trivial work, ensure preflight artifacts are
in the schema the project's hooks expect. For this repo (engineering-log):

  $T_DIR/manifest.json MUST contain:
    {
      "task_id": "YYYY-MM-DD-NNN",
      "slug": "kebab-case",
      "task_root": ".ai/tasks/{task_id}_{slug}",
      "allowed_external_paths": [<absolute paths>],
      "created_files": [],
      "modified_files": [],
      "external_writes": [],
      "git_mutations": [],
      "pending_adversarial_dispatches": [],
      "runtime_attacks": [],
      "gate_witnesses": []
    }

  .ai/runtime/current-task.json MUST contain:
    {
      "task_id": "<same>",
      "slug": "<same>",
      "task_root": "<same>",
      "phase": "1..8",
      "preflight_complete": true
    }

  See /Users/alextorresruiz/.claude/hooks/task-workspace-guard.sh for the
  validator function `has_current_task()`.
```

(This is a project-specific invariant; the skill should reference the project's harness contract rather than re-derive it.)

### 1.11 — Frontmatter validator hook blocked first context file

**What happened**: First write to `.ai/tasks/.../context/probe-set.md` was rejected by `frontmatter-validator.sh` for missing fields and invalid `type: probe-plan` (valid types are `plan|analysis|review|finding|research|log|report`).

**Enrichment proposed for skill — link to project's frontmatter contract**:

```text
PROJECT FRONTMATTER CONTRACT (engineering-log):
  Required fields for `.ai/**/*.md`: task_id, agent, status, summary
  Valid `type` values: plan, analysis, review, finding, research, log, report
  Valid `status` values: complete, partial, blocked, pending_review, draft
  Validator: /Users/alextorresruiz/.claude/hooks/frontmatter-validator.sh
```

### 1.12 — Initial recipe-shape over-engineering (cost: 1.5 hours wall-time on adversarial review)

**What happened**: I produced an exhaustive Phase A→F runbook (~600 lines) covering parallelism caps, throttled rollout, drift inventory, manual sync gates, augmented verification — based on adversarial review's BLOCKING op-modes. User chose to skip 80% of it and rely on natural reconcile cascade. The actual apply was **~2 minutes**.

**This is not strictly an inefficiency** — adversarial review's findings WERE valid for production, and the skill should retain Phase A→F as a fallback. BUT the skill should also encode "minimal viable rollout" as the FIRST path, with throttled rollout as the escalation path if minimal fails.

**Enrichment proposed for skill — two-tier rollout doctrine**:

```text
ROLLOUT TIER 1 — Minimal (preferred for Sandbox FBE):
  1. Pre-apply: read-only baselines (broken count, healthy count, PrometheusRule count)
  2. Apply: ONE credential template add via argocd CLI / UI
  3. Wait: 60s for natural reconcile cycle (selfHeal does the work)
  4. Verify: broken count → 0, PrometheusRule count unchanged, no repo-server restart
  Wall-time: ~3-5 minutes total

ROLLOUT TIER 2 — Throttled (fallback if Tier 1 fails or environment requires drift preservation):
  Phase A→F per fix.md template (~25-40 min)
  Triggered by:
  - Tier 1 broken count is not decreasing within 5 min
  - Repo-server CPU exceeds 80% of node Allocatable
  - PrometheusRule count drops (prune destruction detected)
  - Bystander apps regress (healthy count drops)
  - Environment is dev-MC / acc-MC / prd-MC (production contract)
```

---

## Section 2 — What the skill MUST contain (specific edits)

Translating the audit above into concrete additions to the skill file. Order is roughly skim-priority for a future agent.

### 2.1 — Add at top of skill (after "Skill Selection Gate"): the 60-second first-look probe set (from §1.6)

A future agent reading the skill should see the 5 one-shot kubectl probes as the FIRST operational content. Currently the skill's Ten-Minute Triage assumes pre-loaded vault context.

### 2.2 — Add new Decision Framework: "ArgoCD failure-surface discrimination" (from §1.1)

A table mapping (error string + surface) → class → recipe. The current Decision Framework 1 catalogues PAT expiry but not the per-Application source-credential class. Add the new row + the discriminator probe.

### 2.3 — Add new Decision Framework: "Apply Surface Decision" (from §1.2)

Mapping (change kind) → (preferred tool). Currently the skill's tooling references default to kubectl/argocd CLI implicitly; explicit doctrine is missing.

### 2.4 — Add new Reference: "Tool Auth Ladder" with `--core` mode unblock (from §1.3)

Table of (operation) → (preferred tool) → (fallback) → (last resort), with the `mv ~/.config/argocd/config aside + ARGOCD_NAMESPACE=argocd + --core` unblock named explicitly.

### 2.5 — Add new Heuristic H-PATTERN-MATCH-FIRST (from §1.4)

"Before designing any new ArgoCD configuration, inspect the existing working sibling and replicate its exact byte-form."

### 2.6 — Add new Principle "Mutation scope = deployment contract" with two-tier rollout (from §1.5, §1.12)

Map (cluster identity) → (mutation-scope doctrine). Tier 1 minimal vs Tier 2 throttled. Sandbox FBE → Tier 1 default; MC clusters → Tier 2 default.

### 2.7 — Add new Heuristic H-VERIFY-CAUSE-CLAIM-DEPTH (from §1.7)

"Verification depth must equal the depth of the cause-claim. Source-surface verification proves process, not outcome."

### 2.8 — Add "Credential Intake Conventions" section (from §1.9)

The 4-way operator credential intake protocol (in-cluster Secret > 1Password CLI > .env.tmp > manual paste) + the NEVER list.

### 2.9 — Reference the project's harness contract (from §1.10, §1.11)

Link to the `engineering-log` repo's `task-workspace-guard.sh` and `frontmatter-validator.sh` schemas. Avoid re-deriving these at incident time.

### 2.10 — Author and link the missing vault artifacts (from §1.8)

Pattern + recipe + incident page for the per-Application source-credential-coverage class. Until these exist, the skill's "M4: The Vault Owns Canonical Knowledge" mental model is broken for this class.

---

## Section 3 — Authored artifacts (deliverables for vault writeback)

These are the documents that must land in the vault to close the loop. Naming follows the catalogue's Knowledge DNA contract (`pattern-{class-noun}.md`, `recipe-{action}.md`, `YYYY-MM-DD-{slot}-{shortname}.md`).

### 3.1 — `pattern-argocd-per-application-source-credential-gap.md`

Mental model:

> When an ArgoCD Application has `spec.sources[]` with ≥1 Git source, the
> credential resolution path is: exact-match `Repository` CR → longest-prefix
> `repo-creds` template → anonymous. If the source URL is private (ADO Git,
> private GitHub, etc.) and NO Repository CR or covering template exists,
> ArgoCD's repo-server falls to anonymous, ADO returns HTTP 401, and the
> Application records `ComparisonError: ... failed to generate manifest for
> source N of M: ... authentication required`. The fix is to register a
> `repo-creds` template covering the ADO project prefix, OR an explicit
> Repository CR for the exact repo. Adjacent to but DISTINCT from
> `pattern-argocd-pat-expiry-blocks-new-fbe-apps` (which fires at the
> ApplicationSet generator level, not the Application source level).

Symptoms (all simultaneously present):
- `kubectl get applicationset vpp-feature-branch-environments -n argocd` reports `ErrorOccurred=False, ResourcesUpToDate=True`
- ≥1 `Application` reports `ComparisonError` with `source N of M` substring in the message
- `kubectl get secret -n argocd -l argocd.argoproj.io/secret-type=repository` does NOT include the failing Application's `.spec.sources[0].repoURL`
- `kubectl get secret -n argocd -l argocd.argoproj.io/secret-type=repo-creds` has no entry whose `data.url` is a prefix of the failing URL
- Other Applications using DIFFERENT source-1 URLs that ARE registered work fine

### 3.2 — `recipe-register-missing-credential-template.md`

Paste-able recipe, three steps:

1. **Probe coverage**: enumerate Application source URLs and registered credentials; identify the gap.
2. **Apply template**: `argocd repocreds add --core <project-prefix-URL> --username <service-account> --password <PAT>`. PAT bytes can be reused from any existing working Repository CR Secret in the same cluster if same identity is acceptable, OR mint a dedicated PAT per team convention (`argo-cd-<env>-<purpose>` naming).
3. **Verify**: broken count → 0 within 5 min via natural reconcile cycle (no forced refresh needed if `selfHeal=true`); no repo-server restart, no PrometheusRule regression.

Anti-patterns:
- Do not register one Repository CR per failing repo — over time the explicit list drifts. The project-level template covers all current and future repos under that ADO project.
- Do not add trailing slash to the template URL (breaks team convention; check existing templates first).
- Do not mint a new PAT if reuse is acceptable — the working PAT in the existing Repository CR is already cluster-deployed and proven; copying its bytes avoids a fresh secret rotation cycle.

### 3.3 — `2026-05-12-jupiter-source1-credential-gap.md`

Incident page referencing this engineering-log RCA. Mirror structure of `2026-05-11-pat-expiry-argocd-auth-break.md` for catalogue consistency.

### 3.4 — Amend `fbe-errors/_index.md` Symptom→Entry matrix

Add row:

| Observed signal | Likely class | Where to land |
|---|---|---|
| `kubectl get application` shows `ComparisonError: ... source N of M: ... authentication required` AND `kubectl get applicationset ... -o jsonpath='{.status.conditions}'` shows `ErrorOccurred=False` | Application source-N credential-coverage gap | `pattern-argocd-per-application-source-credential-gap` → `recipe-register-missing-credential-template` |

### 3.5 — Amend `recipe-rotate-argocd-sandbox-pat` Step 7

Replace:

```text
Step 7 — Verify slot Applications materialize
  for i in 1 2 3 4 5 6; do
    COUNT=$(kubectl get applications.argoproj.io -n argocd 2>/dev/null | grep -c "^${SLOT}-app-of-apps")
    CHILDREN=$(kubectl get applications.argoproj.io -n "$SLOT" --no-headers 2>/dev/null | wc -l | tr -d ' ')
    echo "$(date -u +%H:%M:%S) ${SLOT}-app-of-apps=$COUNT child-apps-in-ns=$CHILDREN"
    [ "$CHILDREN" -ge 10 ] && break
    sleep 30
  done
```

With:

```text
Step 7 — Verify slot Applications materialize AND can sync
  # 7a — count-level (was already here)
  ...same as above...

  # 7b (NEW) — sync-level: per-Application source-fetch succeeds
  BROKEN_AT_SOURCE=$(kubectl get applications.argoproj.io -n "$SLOT" -o json | jq '
    [.items[] | select((.status.conditions // []) | map(select(.type=="ComparisonError")) | length > 0)] | length')
  echo "Apps with ComparisonError in $SLOT: $BROKEN_AT_SOURCE"

  # 7c (NEW) — cluster-wide: no per-Application credential gap remaining
  CLUSTER_BROKEN=$(kubectl get applications.argoproj.io -A -o json | jq '
    [.items[] | select((.status.conditions // []) | map(select(.type=="ComparisonError" and (.message|test("source [0-9]+ of [0-9]+"; "i")))) | length > 0)] | length')
  echo "Cluster-wide apps still in source-N ComparisonError: $CLUSTER_BROKEN"

  # 7b and 7c MUST be 0 to declare success.
  # If 7c > 0 → you have an adjacent credential-coverage gap; route to
  # pattern-argocd-per-application-source-credential-gap before declaring fix complete.
```

---

## Section 4 — Skill-level reflective lesson (the most generalizable takeaway)

Beyond the operational specifics, the meta-pattern from this incident:

**Yesterday's fix was "correct at cause-claim depth N" but the user-observable
recovery requires fix-correctness AT EVERY DEPTH ≤ N**. Yesterday's
ApplicationSet-generator-PAT rotation passed its own verification depth (Step 7
counted child apps) but stopped one layer above the actual user-observable
outcome (slot pods running, URL 200). Today's incident IS that one-layer-deeper
verification firing 22 hours late.

The skill should encode this as a principle:

```text
PRINCIPLE — Recursive verification.

For any fix at cause-claim depth N, verify success at:
  depth N (the fix's own assertion: "the credential is registered")
  depth N+1 (the immediate consumer: "ArgoCD repo-server can fetch")
  depth N+2 (the downstream consumer: "Applications enter Synced state")
  ... up to ...
  depth USER (the user-observable outcome: "the FBE URL returns 200 with
              real service response, not SPA fallback")

A fix that passes depth N but is silent about depths N+1..USER is INCOMPLETE.
Every catalogued recipe should explicitly name its verification depth range.
```

---

## Section 5 — Confidence assessment

If a future agent landed on this exact incident class with the skill enriched
per Sections 2-4 above, the agent would:

| Step | Time saved vs this session |
|---|---|
| Class identification (source-N gap vs PAT-expiry vs F-class) | ~10 min (one-shot discriminator probe) |
| Tool surface choice (argocd CLI > UI > kubectl) | ~5 min (no kubectl default round-trip) |
| `--core` mode unblock | ~3 min (named procedure, not discovered) |
| URL form (no trailing slash, with userinfo, no `_git/`) | ~5 min (pattern-match heuristic) |
| Mutation scope (skip prune-disable for Sandbox FBE) | ~10 min (deployment-contract doctrine) |
| Blast radius enumeration in 60 seconds | ~5 min (first-look probe set) |
| Verification depth = cause-claim depth | (would prevent yesterday's incomplete-fix recurrence) |
| **Total time savings** | **~38 minutes** |

Plus the meta-savings: no adversarial round-trip needed for facts that the
skill should have surfaced upfront; no user corrections needed for false
defaults; no false-confidence claims that the user would need to challenge.

This is the bar the enriched skill should meet.
