---
task_id: 2026-04-26-001
agent: el-demoledor
status: complete
summary: Break-attempt on the proposed trigger yaml change
---

# Break verdict
HOLDS-WITH-PATCH

Three breakage edges: A4 first-merge ordering, A8 `terraform/fbe` path-miss, A9 destroy-cascade. All patchable.

# Required patches to plan

1. **Resolve `terraform/fbe/` BEFORE merge.** Verified-diagnosis F5/F6 cites `terraform/fbe/event-hub.premium.tf:67-93` as unique IaC owner of the missing CG+container module pair. Phase 5 premise 1 denies FBE involvement. `grep -rn "fbe" terraform/sandbox/` = 0 hits (FACT) — proves no in-file ref, NOT state-graph exclusion. Either prove FBE unused by sandbox (then re-read F5/F6 — they may describe FBE stack), OR add `terraform/fbe` to path filter. **Load-bearing internal contradiction.** `[UNVERIFIED[unknown]]`.

2. **Document recursion semantics.** ADO `paths.include` is directory-prefix match, not minimatch — `terraform/sandbox/*` and `terraform/sandbox` and `terraform/sandbox/foo/bar.tf` all match (INFER: MS Learn `pipelines/build/triggers#paths`). Drop the cosmetic `/*` and add comment:

```yaml
paths:
  include:
    # ADO path filters are recursive directory-prefix matches
    - configuration/terraform/sandbox
    - terraform/sandbox
    - .azuredevops/pipelines/terraform-cd-sandbox.pipeline.yaml
    - .azuredevops/pipelines/variables.yaml
```

3. **PR description: run Path P first, THEN merge Path D.** See A4.

# Per-attack-surface findings

**A1 [PATTERN-MATCHED, MEDIUM]** Recursion correct (directory-prefix). Risk = doc debt to future maintainer. Patch 2.

**A2 [PATTERN-MATCHED, LOW]** `batch: true` coalesces queued commits into one build with one approval (FACT: ADO `triggers#batching-ci-runs`). Per-commit rollback granularity lost. Acceptable; document.

**A3 [EXPLOIT-VERIFIED, LOW]** `pr` and `trigger` are sibling root keys; order irrelevant (FACT: YAML). Top-level placement correct. Risk = future hand-indent under `trigger:` silently swallowed as unknown key, ADO defaults `pr: ['main']`. Add blank line + comment.

**A4 [EXPLOIT-VERIFIED, MEDIUM]** The yaml change touches `terraform-cd-sandbox.pipeline.yaml`, which is in its own filter. Merge auto-triggers build at post-merge HEAD. `applyCondition: eq(Build.SourceBranch, 'refs/heads/main')` (line 41) evaluates true regardless of plan-empty. Apply requests approval. If Path P ran first: Path-D auto-build plans 0 changes, wastes approval slot. If Path D merged first: auto-build IS the fix (plans CG+container, Path P redundant). Order = operator clarity, not correctness. Patch 3.

**A5 [EXPLOIT-VERIFIED, LOW]** `pull-request-validation.yaml` is at REPO ROOT (not `.azuredevops/pipelines/` — prompt's path is wrong). FACT: file lines 1-4 = `trigger.branches.include: "*"`, no `pr:`. Adding `pr: none` to terraform-cd-sandbox suppresses the implicit `pr: ['default-branch']` ADO injects when `trigger:` is set without explicit `pr:` (FACT: ADO `yaml-schema/pr`). Confirmed safe.

**A6 [PATTERN-MATCHED, LOW]** `trigger:` is a root-only key in ADO YAML — rejected in templates at parse time (FACT: ADO schema). `CCoE/azure-devops-templates ref 2.6.9` cannot define a trigger. Eliminated.

**A7 [PATTERN-MATCHED, MEDIUM]** `batch: true` serializes same-branch (FACT). Does NOT prevent concurrent main-auto + feature-branch-manual against same backend (`sandbox.backend.config`, line 26). Phase 4 R3 shows feature-branch runs occur. Azure backend uses blob-lease — second run fails fast with state-lock, not corrupts (FACT: azurerm backend docs). Operator burden, not corruption.

**A8 [EXPLOIT-VERIFIED, HIGH]**
- `terraform/fbe/` — see Patch 1. **BLOCKING.**
- `terraform/sandbox-extras/` — directory-prefix `terraform/sandbox` does NOT match `terraform/sandbox-extras/` (boundary). New sibling dir = silent miss. Add comment naming the trap.
- `.terraform-version`/`mise.toml`/`.pre-commit-config.yaml` — pipeline reads `terraformVersion` from `variables.yaml:2` (FACT: `"1.13.1"`), which IS in filter. Local-dev only. Safe.
- Template tag `2.6.9` — pinned; CCoE force-update is out-of-scope abuse. Not a filter concern.

**A9 [THEORETICAL, HIGH]** Conditional on Patch 1. IF FBE is in sandbox state graph: a merge to `terraform/fbe/event-hub.premium.tf` does NOT auto-trigger sandbox-CD; latent drift accumulates; next sandbox-touching merge sweeps both deltas into one unreviewed apply; approver sees combined plan, approves; FBE delta destroys/recreates consumer groups; `BlobCheckpointStore` containers lose owner state; ALL dispatcher consumers crashloop simultaneously. SAME silent-merge-no-apply class as current incident, just delayed. IF FBE unused: collapses to LOW. Resolves on Patch 1.

# Worst realistic outcome
The FBE-cascade. Path-D as written either (a) works as intended if FBE is unused by sandbox state, or (b) introduces a delayed silent-merge-cascade that destroys checkpoint containers across the entire sandbox dispatching stack on the next unrelated merge. Binary on a question the plan does not answer. Verified-diagnosis F5/F6 names FBE as IaC owner; Phase 5 premise 1 denies it. Both cannot be true. Resolve before YAML lands on main.
