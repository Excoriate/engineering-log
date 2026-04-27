---
task_id: 2026-04-26-001
agent: coordinator
status: complete
summary: Phase 6 — combined spec for the YAML edit and the three explanatory deliverables
---

# Spec — IaC edit + 3 deliverables

## Spec 1 — YAML edit

**File**: `/Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src/enecomanagedcloud/myriad-vpp/VPP%20-%20Infrastructure/2026-04-24-ootw-fix-mfrr-activation-crashloop/.azuredevops/pipelines/terraform-cd-sandbox.pipeline.yaml`

**Operation**: replace exactly line 1 (`trigger: none`) with the post-adversarial hunk in `plan/plan.md` "Final hunk shape". Lines 2–41 untouched.

**Acceptance**:
- `git diff origin/main HEAD -- .azuredevops/pipelines/terraform-cd-sandbox.pipeline.yaml` shows additions on lines 1–N (the new `trigger:` block + comments + `pr: none`) and removal of the single `trigger: none` line. No other lines touched.
- `wc -l` on the file increases by approximately 12–15 lines (1 removed + 13–16 added).
- File still parses as valid YAML (visual check; ADO will fail loudly if syntax breaks on next push).
- No commit, no push, no PR creation. Working tree only.

**Falsifier**: any other line of the file changes; whitespace touched outside the hunk; file ends without the original stages content (lines 22–41).

## Spec 2 — `explanation-of-fix-and-issue-holistic.md`

**Path**: `/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/log/employer/eneco/02_on_call_shift/2026_04_21_stefan_vpp_infrastructure_mfrr/explanation-of-fix-and-issue-holistic.md`

**Voice**: principal-engineer prose, no jargon hedging. Reader is the operator (Alex) who needs to (a) understand what happened, (b) replicate the diagnosis, (c) explain to a colleague.

**Required sections**:
1. **TL;DR** — 4 bullet points: what failed, root cause, who fixed what (PR 172400), why it didn't apply, what the new PR does.
2. **The four-repo system** — ASCII diagram (reuse from `systemic-diagram-and-verified-diagnosis.md` §1, with corrections noted).
3. **Anatomy of the crashloop** — SDK invariant, container/CG naming convention, why R147 image needed something R145 didn't.
4. **What the prior diagnosis got right and wrong** — the stale-mirror correction (IaC was already merged) and the approval-timeout correction (not "plan-no-change").
5. **What I verified live (this session)** — table of 4 az probes with command + output + classification.
6. **Why it stayed broken for 5 days** — `trigger: none` + approval timeout chain.
7. **The fix — Path D (IaC commit, primary)** — the YAML hunk, what it does, why bare paths, why `pr: none`, what NOT changing (approval gate).
8. **Path P — operator command (alternative path)** — the `az pipelines run` command with rich explanation, then the verification probes.
9. **Replication recipe** — exact commands a future on-call can run to reproduce this diagnosis from scratch.
10. **Lessons** — three at most, each with a concrete probe to prevent recurrence.

**Acceptance**:
- Self-contained: someone reading ONLY this file can diagnose the same class of incident next time.
- Every load-bearing claim cites file:line OR command output.
- Path P command paste-ready and copy-correct.
- Mermaid or ASCII diagram present.

## Spec 3 — `pr-description.md`

**Path**: `/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/log/employer/eneco/02_on_call_shift/2026_04_21_stefan_vpp_infrastructure_mfrr/pr-description.md`

**Title**: `fix(pipeline): auto-trigger terraform-cd-sandbox on merges to main`

**Required sections**:
1. **Problem** — three sentences. Pipeline 1413 had `trigger: none`. PR 172400 (2026-04-16) added `activation-mfrr` to `dispatcher-output-1.consumerGroups` for Sandbox. Apply never ran (no auto-trigger + 2h approval timeout on Stefan's manual run 2026-04-21) → silent state drift → activationmfrr pod CrashLoopBackOff because the matching blob container was never created.
2. **Root cause** — `trigger: none` + reliance on manual triggering + approval timeout under operator load.
3. **Fix** — the diff, in code-block.
4. **Why these path filters** — bullet list mapping each path to the resource it gates.
5. **Why `pr: none`** — one sentence; suppresses ADO's implicit `pr: ['default-branch']`.
6. **Blast radius** — Sandbox only; varFile + serviceConnection pinned (yaml lines 6-7, 39); acc/prd CDs untouched; no cross-env.
7. **What this PR does NOT change** — explicit list:
   - Approval gate / 2h timeout (intentionally out of scope; lowering needs team consensus).
   - Cross-pipeline `sandbox-shared.tfstate` dependency (producer outside this repo).
   - `terraform/fbe/**` path coverage (Sandbox is self-contained; fbe/ has its own pipeline).
8. **Verification plan**:
   - On merge: ADO will read the new `trigger:` from the merge commit and queue an auto-build against post-merge HEAD.
   - That build's plan will show **+1 `azurerm_eventhub_consumer_group` + +1 `azurerm_storage_container`** (the still-unapplied delta from PR 172400).
   - Approver (anyone in `terraform-sandbox` Environment) clicks Approve within 2 h.
   - Apply completes. Verification commands (provided) confirm runtime CG + container exist.
   - `kubectl rollout restart deployment/activationmfrr -n vpp` (or wait for ArgoCD self-heal) restores the R147 pod.
9. **Rollback** — single revert PR. Reverting restores `trigger: none`; current Apply state remains.

**Acceptance**: a teammate reading this PR description without prior context can review and approve the change.

## Spec 4 — `slack-response.md`

**Path**: `/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/log/employer/eneco/02_on_call_shift/2026_04_21_stefan_vpp_infrastructure_mfrr/slack-response.md`

**Channel**: `#myriad-platform` (C063SNM8PK5), parent thread ts `1776781493.090009`.

**Constraints**:
- Stefan on vacation since 2026-04-22 — do NOT @mention.
- No `<!channel>`, no `<!here>`, no pleasantries ("happy to help", "let me know"), no AI-tells.
- Sober colleague-to-colleague register.
- Length: ~120 words.
- Single message.

**Required content**:
- Acknowledge the report.
- Two corrections to prior public framing: (a) IaC fix was already merged on 2026-04-16 (PR 172400), (b) Apply was skipped on the 2026-04-21 run because the approval gate timed out at 2 h, not because plan saw zero changes.
- One-line description of the new defensive PR.
- One-line description of the operational unblock path (manual pipeline run + approve, OR merge the PR and approve the auto-trigger).
- No ping on Stefan; tag the Core team stand-in only if explicitly required.

**Acceptance**: under 150 words; passes the style check from prior `slack-reply-draft.md` (no banned phrases, no pings); cites the buildId, PR number, and branch name verbatim so the reader can verify.
