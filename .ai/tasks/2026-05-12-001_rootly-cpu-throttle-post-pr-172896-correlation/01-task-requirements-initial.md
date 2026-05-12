---
task_id: 2026-05-12-001
slug: rootly-cpu-throttle-post-pr-172896-correlation
status: draft
phase: 1
created: 2026-05-12
agent: claude-code-coordinator
summary: Initial requirements (P1 mirror) for correlating last-2h Rootly CPU-throttle alerts with merged ADO PR 172896 to verdict {PR-insufficient | PR-not-yet-deployed | other-cause} and produce holistic RCA + oc-probes.md.
---

# Task Requirements (Initial — P1 mirror of NN-3 BRAIN SCAN)

## Request

Correlate Rootly alerts from the **last 2 hours** with **ADO PR 172896** (recently merged, claimed prod-capacity remediation, originally undersized prod resources confirmed).

Decide whether:
- (A) PR 172896 needs improvement (resources still undersized after merge), OR
- (B) PR merged but not yet deployed/propagated to prd, OR
- (C) Alerts are about something else entirely (different metric/resource).

Produce:
1. Holistic RCA at `log/employer/eneco/02_on_call_shift/2026_05_11_rootly_alert_cpu_throtling/rca.md` (or update if exists)
2. `oc-probes.md` in the same dir with concrete commands to run, conditional on the verdict and current alert reality.

## Success Criteria (USER outcome)

- On-call user receives RCA with verdict {A | B | C} + named falsifier for the verdict
- `oc-probes.md` lists copy-pastable commands matched to current alert state, NOT speculative

## Truth Surface

- Rootly alert API (last 2h) — externally witnessable via `mcp__rootly__listAlerts`
- ADO PR 172896 — externally witnessable via PR URL fetch and/or eneco-context-repos
- IaC alert threshold definition — file:line in MC-VPP-Infrastructure
- Deployment pipeline state for PR 172896 — ADO build/release timeline

## Load-Bearing Assumption (most likely to flip route)

**"PR 172896 was deployed to prd at time T < first post-PR alert."**
Falsifier: ADO pipeline timeline for the build triggered by PR 172896 merge — if no successful prd deploy after merge, route flips from H1 (resize again) to H2 (chase the deploy).

## Frames Triggered

- **Sherlock** (Hypotheses H1/H2/H3): typed
- **SRE-maniac** (Failure path — pipeline + scale-out propagation timing): typed
- **Socrates** (Assumption: "PR merged ⇒ fix shipped"): typed
- **Evaluator** (action-bearing RCA): yes

## CRUBVG

C=1 R=0 U=2 B=1 V=1 G=2 → **7** (Full mode)

## Counterfactual

If I skip the deployment-state probe and assume PR-merged = PR-effective, I'll recommend a second resize PR while the first one hasn't even shipped — wasted cycles, user keeps paging.
