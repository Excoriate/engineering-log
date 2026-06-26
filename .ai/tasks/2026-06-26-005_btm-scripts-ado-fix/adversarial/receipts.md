---
title: "Adversarial receipts — BTM tag-fix code changes"
status: complete
timestamp: 2026-06-26T00:00:00Z
task_id: 2026-06-26-005
agent: claude-opus-4-8
summary: "Receipts for sre-maniac (pipeline) + el-demoledor (script) findings on the BTM tag-fix diff. 4 RESOLVED (incl. 1 BLOCKING, 1 HIGH, 1 MEDIUM), 3 REBUTTED, 2 DEFERRED with conditions. No DEFER on BLOCKING/HIGH."
---

# Adversarial receipts

Reviewers: `sre-maniac` (pipeline runtime), `el-demoledor` (hardened script). Both verdicts: FIX-FIRST.
The identity relocation (the PR's purpose) SURVIVED both; the findings were latent script bugs the
identity fix *activated* by making tagging succeed for the first time.

| # | Finding (sev) | Disposition | Evidence |
|---|---------------|-------------|----------|
| SRE-M2 | Unbounded `git log` harvests work items from all shallow-checkout commits (7@d10, 57@d100) → mass-tags unrelated PRs once tagging works (**BLOCKING**) | **RESOLVE** | Scoped to `git log -1` (triggering merge/squash commit). Verified each merge commit at HEAD carries exactly its own `Related work items:` line. test-harness T1. |
| DEM-M4 | `az ... show` (`2>/dev/null`, unguarded) failure → `current=""` → `update` REPLACES whole tag set (**HIGH**, exploit-verified) | **RESOLVE** | Guarded read: on `show` failure → `warn` + `continue` (skip item, never clobber); stopped redirecting stderr to /dev/null. test-harness T3 (tags preserved, no update emitted). |
| DEM-M6 | Unset `TAG` (`:?`) exits 1 → blocks deploy, violates never-block contract (**MEDIUM**) | **RESOLVE** | Replaced with `warn` + `SucceededWithIssues` + `exit 0`. test-harness T5 (exit 0). |
| DEM-M1 | `grep -Po '\d+'` grabs any digit run on marker line (dates/versions/PR-id) → stray candidate ids (**RESIDUAL/LOW**) | **RESOLVE** | Changed to `grep -Po '(?<=#)\d+'` (only `#NNN` ids). test-harness T2 (only 123 from `#123 fixed on 2026-06-26 v1.2`). |
| SRE-M1 | Build Service work-item edit on area 6393 taken from prior diagnosis, not re-probed in the new job (**LOW**) | **DEFER** | This is the structural residual E14 — closes via the post-merge realized-tag check. Falsifier: TF401019 from Build Service in first DEV tag-job log. |
| DEM-M3 | `tr -d ' '` over-collapses internal spaces → false-skip on tag literally named e.g. `D EV` (**RESIDUAL/LOW**) | **DEFER** | Condition to revisit: only if Team BtM uses tag names whose non-space chars spell DEV/ACC/PRD (none observed; ADO env tags have no spaces). Element-wise compare is the fix if it ever bites. |
| DEM-M5 | `read` does not strip CRLF (**RESIDUAL/LOW**) | **REBUT** | `az ... -o tsv` emits LF only on the ubuntu-24.04 target (reviewer's own note); not reachable in the runtime env. |
| SRE-M5 | `azure-devops` CLI extension assumed preinstalled, unpinned (**LOW**) | **REBUT** | Parity with the original step, which empirically ran `az boards` (reached TF401019) on the same image → extension present. Not introduced by this change. |
| SRE-M3 | If wired as PR build-validation (org state, not in YAML), unconditioned Development stage runs on PR builds (**LOW**) | **REBUT** | Trigger is `branches: include: [main]` only, no `pr:` block (pipeline.yml:1-9). Further bounded by SRE-M2 fix: only HEAD's (the PR's own) items would be tagged. |

## Note on SRE-M2 (the one behavior change beyond the RCA)

The RCA's prescribed fix was identity + the listed hardening; it did NOT address harvest scope (because
in the RCA's world the script never tagged anything, so over-harvest was invisible). The identity fix
activates successful tagging, which would activate the over-harvest. Scoping to `git log -1` is the
correct per-PR behavior (matches the tag's documented intent: "how far has THIS story shipped") and is
verified safe for this repo's merge-commit strategy. This is the single place the delivered change goes
beyond the RCA — flagged to the user for veto. If the team uses rebase/fast-forward merges (no single
aggregating commit), the harvest source must be revisited.
