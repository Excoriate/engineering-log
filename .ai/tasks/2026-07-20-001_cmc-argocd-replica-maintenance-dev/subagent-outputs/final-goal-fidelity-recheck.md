---
task_id: 2026-07-20-001
agent: codex
role: isolated-goal-fidelity-adversary
status: complete
summary: |
  The repaired six-document package materially improves folder routing, timestamped truth,
  ACC fleet-gap disclosure, proof ceilings, and DEV-incident transfer. It still cannot receive
  PASS: stale DEV finding/claim states remain, unsourced two-sample closure gates remain,
  draft/review frontmatter remains unresolved, and a new human-paste ACC block fails open under
  Bash after a failed guard. Overall verdict: FAIL pending document repair; the declared AVD live
  activation ceiling may remain PARTIAL after those textual defects are fixed.
---

# Final goal-fidelity recheck

## Verdict

**FAIL — the package is substantially better, but not yet safe to call finished or Wednesday-ready.**

Evidence basis:

- **REPO-GROUNDED:** all six repaired files were read in full; claims below cite exact file/line evidence.
- **RUNTIME-VERIFIED:** all relative Markdown file links resolve; all runbook Bash fences parse with `bash -n`; secret scans found zero JWT-like values and zero bearer/password assignments; the failed-guard negative control reproduced a fail-open command path.
- **Explicit ceiling:** no live ACC command was executed in this recheck. Structural/source proof does not promote the AVD wrapper, structured fleet query, structured EndpointSlice join, or Wednesday state to live proof.

The steelman survives: this is now a strong teaching and operational package. It has a canonical route, an exact first-principles syllabus, meaningful architecture diagrams, excellent `solver`/sync/health treatment, bounded attribution, an explicit ACC fleet-baseline gap, and a useful DEV incident-to-ACC preflight transfer. The remaining failures are narrow but load-bearing because they affect the operator's stop/close behavior and the package's claimed completion state.

## Prior-finding recheck

### GF2-01 — Folder route and wrong-ledger risk: PASS

- **Attack:** start from every file as a zero-context reader and look for a competing Wednesday route or a DEV instruction that can capture ACC evidence.
- **Evidence:** every file routes to `argocd_replica_increase_explained.md` → `argocd-replica-increase-acceptance-runbook.md` → `maintenance-july-22-records-findings.md`; examples include `argocd-openshift-command-probes.md:11-15`, `probes-explanation.md:10-18`, `maintenance-july-20-records-findings.md:11`, `maintenance-july-22-records-findings.md:11`, and `argocd-replica-increase-acceptance-runbook.md:13-15`. The DEV command guide is now `reference-only-for-acceptance` and its hard gate explicitly redirects ACC to the July 22 ledger at `argocd-openshift-command-probes.md:286-290`.
- **Falsifier:** any top-level operational instruction that names the July 20 ledger for Wednesday or presents the DEV guide as the ACC execution surface.
- **Result:** no such route survived. Relative `.md` link existence check passed.

### GF2-02 — Historical versus current truth: PASS

- **Attack:** search all `current`/`now` language and try to carry a preparation value into DEV-after or Wednesday ACC truth.
- **Evidence:** the syllabus names three environment+timestamp snapshots and expiry rules at `argocd_replica_increase_explained.md:26-34`; the DEV bridge labels its table historical at `probes-explanation.md:58-87`; DEV preparation findings are timestamped at `maintenance-july-20-records-findings.md:128-153`; ACC headings and tables are capture-qualified at `maintenance-july-22-records-findings.md:53-80,94-106,133-143`; and Wednesday T0 expiry is explicit at `argocd-replica-increase-acceptance-runbook.md:150-152,494-499`.
- **Falsifier:** a present-tense replica/configuration claim whose environment and observation time cannot be derived from the same local section.
- **Result:** remaining uses of `current` are Kubernetes status-field terminology, generic object semantics, or locally timestamp-bound evidence—not an unqualified environment snapshot.

### GF2-03 — DEV final closure versus item-level states: FAIL

- **User criterion:** “You can finish the dev live watch, maintenance is over.”
- **Attack:** compare the final DEV verdict with every preparation/live finding status and the concise bridge's challenge table.
- **Evidence:** the final closure is clear at `maintenance-july-20-records-findings.md:203-224,370-379`, and prior F-001/F-007/F-012 defects were repaired at `:128-135,253-263,311-321`. However, F-002 still says `target component pending` at `:137-144` after the live record identifies the changed components; F-003 still says `monitor at T0/start` at `:146-153`; F-004 still says `preserve and diff at T0` at `:155-162` even though the live ledger records unchanged pre-existing exceptions. `probes-explanation.md:197-203` simultaneously presents the completed DEV outcome at the top but says “The maintenance succeeds — not yet evidenced.”
- **Mechanism/consequence:** a new joiner receives both a closed record and active-looking tasks. The package cannot distinguish accepted historical residuals from unfinished monitoring.
- **Falsifier:** every stale action is replaced by a final observed state or bounded residual; the challenge table says success is evidenced only across the stated proof layers and names the remaining ceiling.
- **Required repair:** close F-002/F-003/F-004 using the final captures and convert the bridge's “not yet evidenced” row to the bounded DEV verdict. Do not erase historical facts; append/restate the resolution.

### GF2-04 — Unsourced numeric acceptance gates: FAIL (partially repaired)

- **User criterion:** “do not invent evidence or thresholds.”
- **Attack:** trace every fixed number into warning, evidence-floor, or closure decisions rather than merely searching for the removed `80%`, `+10pp`, and five-minute text.
- **Evidence:** the percentage/delta gates and local five-minute authorization were correctly removed or converted to observations at `argocd-openshift-command-probes.md:231,286-290`, `probes-explanation.md:172-185`, and `maintenance-july-20-records-findings.md:73-76,109-122,203-224`. But the ACC serving invariant still **requires** “at least two post-readiness samples” at `argocd-replica-increase-acceptance-runbook.md:343-354`, and the closure evidence floor still **requires** “at least two advancing, complete metrics samples” at `:420-429`. No CMC/Eneco contract or source supplies those minimum counts.
- **Mechanism/consequence:** the locally chosen number still controls `STABLE AS OBSERVED`; the unsourced threshold moved from minutes/percentages into sample cardinality rather than disappearing.
- **Falsifier:** authoritative maintenance intent or policy supplies the exact two-sample minimum; none is cited.
- **Required repair:** express both gates over the signed observation interval: membership must remain consistent throughout all completed post-readiness samples, and metrics evidence must be fresh/complete whenever used. If a change/trend claim logically requires two observations, explain that as the comparison's evidence precondition—not as a fixed closure minimum.

### GF2-05 — ACC Application-fleet completeness: PASS as explicitly bounded

- **Attack:** try to promote the July 20 visible screenful into a complete/fresh ACC fleet baseline.
- **Evidence:** `maintenance-july-22-records-findings.md:108-125` now says `APPLICATION FLEET BASELINE INCOMPLETE` and enumerates missing count, distribution, exceptions, and freshness. The DEV guide carries the same ceiling at `argocd-openshift-command-probes.md:245-255`. The runbook provides a deterministic JSON aggregation and explicit proof tier at `argocd-replica-increase-acceptance-runbook.md:202-248`, then makes incomplete output fail closed at `:380-397`.
- **Falsifier:** any fleet-level “all green/fresh” claim based only on the preparation screenful.
- **Result:** no such promotion remains. The missing live T0 data is now an honest non-document live residual, not a hidden documentation defect.

### GF2-06 — Publication/review state: FAIL

- **Attack:** compare the requested finished handoff with frontmatter visible to the new joiner.
- **Evidence:** `argocd_replica_increase_explained.md:4-5` still says `draft-awaiting-independent-learning-review` / `awaiting-independent-challenge`; `argocd-replica-increase-acceptance-runbook.md:5-6` and `maintenance-july-22-records-findings.md:5-6` still say `awaiting-independent-challenge`.
- **Mechanism/consequence:** readers cannot tell whether the package is approved, stale scaffolding, or intentionally non-consumable. This recheck is the independent challenge, but the current user-facing files have not yet recorded its disposition.
- **Falsifier:** post-recheck frontmatter names the achieved state without promoting blocked live proof—for example, documentation review complete while AVD activation remains explicitly blocked.
- **Required repair:** after accepting/rebutting this receipt, update the three frontmatter states. Do not change the ACC runbook to `monitor-ready` until the live AVD activation succeeds.

### GF2-07 — Honest AVD wrapper/proof ceiling: PASS as a live residual; see new regression below

- **Attack:** look for structural parsing, wide EndpointSlice output, or repository evidence being promoted to pinned-wrapper, structured-join, structured-fleet, or Wednesday runtime proof.
- **Evidence:** `argocd-replica-increase-acceptance-runbook.md:83-130,214-248,490-499` distinguishes live unpinned ACC facts from blocked wrapper/structured forms. `maintenance-july-22-records-findings.md:127-149,163-182,204` separately bounds repository/pipeline evidence, ACC preparation execution, and future Wednesday truth. `argocd-openshift-command-probes.md:245-275` applies the same ceiling.
- **Falsifier:** language saying the pinned/structured forms executed successfully in the AVD or that ACC consumed the incident revision.
- **Result:** no such false promotion remains. Human paste or isolated-kubeconfig activation is an honest external residual. This does not excuse the fail-open block defect below.

## New regression NR-01 — FAIL: the new human-paste structured block does not fail closed under Bash

- **Affected user criterion:** a zero-context SRE must be able to use the Wednesday runbook safely; tested commands and proof ceilings must discriminate real behavior from parse-only success.
- **Artifact evidence:** `argocd-replica-increase-acceptance-runbook.md:214-246` tells the operator to human-paste a top-level block whose first line is `acc_guard || return 1`, followed by unconditionally separate `acc_oc` commands.
- **Runtime falsifier executed:**

  ```text
  bash -c 'acc_guard(){ return 1; }; acc_guard || return 1; echo COMMAND_AFTER_FAILED_GUARD_EXECUTED'
  ```

  Observed:

  ```text
  COMMAND_AFTER_FAILED_GUARD_EXECUTED
  bash: return: can only `return' from a function or sourced script
  BASH_BLOCK_EXIT=0
  ```

  All source Bash fences still pass `bash -n`, proving that parse-only verification cannot catch this behavior.
- **Mechanism/consequence:** at Bash top level, `return` is invalid, but the shell continues to the next command and finishes green. If the guard fails during a pasted block, subsequent queries can still run, violating the runbook's identity-first contract and producing an apparently accepted capture after the guard failure.
- **Counter-hypothesis:** perhaps the operator always pastes into a function or a shell where top-level `return` exits. The runbook says “human-paste the following structured forms” and does not provide that wrapper; Ubuntu/WSL Bash is the documented environment, so the counter-hypothesis is not the published contract.
- **Required repair:** place the entire structured block inside a named function where `return 1` is valid, then invoke it; or guard every command with an execution structure that demonstrably prevents later commands after failure. Re-run the negative control and require: no sentinel command output and nonzero block status when `acc_guard` returns 1.

## Newly added DEV incident transfer: PASS for documentation, live ACC state still unverified

- **Attack:** try to blame the replica maintenance, conflate green pipeline/`Synced` with health, or promote repository evidence into ACC runtime truth.
- **Evidence:** F-014 traces missing release variables → empty tag → Helm `latest` fallback → absent registry manifest → `ImagePullBackOff` at `maintenance-july-20-records-findings.md:333-351`, while preserving the healthy Argo CD control-plane evidence and the unverified recovery/end-user ceiling. The syllabus teaches why `Synced Degraded` is coherent and why the upstream generator—not Argo CD capacity—is causal at `argocd_replica_increase_explained.md:452-499`. ACC transfer is explicitly repository/pipeline evidence rather than runtime evidence at `maintenance-july-22-records-findings.md:127-131`. The runbook turns it into a pre-start differential probe at `argocd-replica-increase-acceptance-runbook.md:154-171`.
- **Falsifier:** ACC T0 shows no consumption of the bad revision/tag and no degraded/pull-failure state; the runbook already says that observation replaces the risk hypothesis.
- **Result:** the transfer is accurate, actionable, and attribution-safe. Its ACC command execution remains covered by the declared AVD live ceiling.

## Original-criteria attack ledger

| Criterion | Verdict | Named attack and evidence |
|---|---|---|
| Exact six files and exact `argocd_replica_increase_explained.md` name | **PASS** | Inventory found exactly the six expected Markdown files; exact requested filename exists. |
| Zero-context canonical start | **PASS** | Followed every top-level route; all converge on syllabus → ACC runbook → July 22 ledger. |
| Feynman treatment in new and existing docs | **PASS** | Concept bridges, analogies, mechanisms, diagrams, false greens, worked diagnoses, and self-tests remain across all six files. |
| Self-contained Argo CD/Kubernetes first principles and architecture | **PASS** | Syllabus covers control-plane components, two loops, CR/operator/workload/Pod/node/Service/EndpointSlice/Application/time boundaries, plus connected DEV after-state architecture at `argocd_replica_increase_explained.md:36-142,177-450`. |
| DEV proof and findings | **PARTIAL** | Command proof/attribution/incident are strong; stale item/bridge states block a coherent closed record (GF2-03). |
| `solver`, sync, health, Progressing | **PASS** | The two axes, chronology, and non-causation ceiling remain explicit in the syllabus, DEV record, and ACC runbook. |
| ACC baseline/readiness/runbook | **FAIL until document repair** | Fleet gap and live ceiling are honest, but unsourced sample gates and the fail-open pasted block remain. |
| No invented evidence/threshold | **FAIL** | Repository evidence is properly bounded, but fixed two-sample closure gates remain (GF2-04). |
| No hidden CMC blame | **PASS** | DEV and incident findings separate state, timing, actor evidence, and application-delivery causation. |
| Lens/Freelens last | **PASS** | Deferred after CLI proof at `probes-explanation.md:24-29` and recorded in final handoff at `maintenance-july-20-records-findings.md:370-379`. |
| Secret hygiene | **PASS** | Zero JWT-like and bearer/password-assignment matches; human-only/token non-retention rules remain explicit. |
| Tested commands/proof ceilings | **FAIL for one block; PASS elsewhere** | Source blocks parse and live ceilings are honest, but NR-01 demonstrates why the new structured block's behavior is unsafe despite `bash -n`. |

## Required repairs before another PASS attempt

1. Fix NR-01 and run the failed-guard negative control against the exact published block.
2. Resolve stale DEV F-002/F-003/F-004 and `probes-explanation.md`'s “not yet evidenced” success row.
3. Remove or source the fixed two-sample serving/metrics closure minima; keep freshness/completeness as evidence requirements over the signed observation interval.
4. After disposing this receipt, update draft/awaiting-review frontmatter without promoting the honest AVD live residual.
5. Re-run: exact file/link check, current/timestamp scan, stale-state scan, unsourced-number scan, secret scan, full Bash parse, and the dynamic failed-guard test.

## Meta-falsifier

This review would be wrong if the published Wednesday workflow runs the structured block only inside an omitted enclosing function; if an authoritative CMC/Eneco procedure supplies the two-sample minima; if the stale DEV statuses intentionally point to a separate visible resolution ledger; or if repository convention requires `awaiting-independent-challenge` to remain after the challenge is accepted. None of those conditions appears in the six documents. The dynamic Bash output directly falsifies the strongest safety claim for NR-01.

**Promotion rule:** textual PASS requires all four document defects above to be repaired. After that, the package may be documentation-complete while still honestly reporting `AVD BEHAVIORAL PROOF BLOCKED`; live ACC maintenance success remains future evidence.
