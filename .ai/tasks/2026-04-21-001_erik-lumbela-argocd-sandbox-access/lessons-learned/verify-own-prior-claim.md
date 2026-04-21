---
task_id: 2026-04-21-001
agent: claude-code
status: complete
summary: Process lesson — when validating coordinator's own prior claim, parallel dispatch of adversarial + evaluator catches orthogonal error classes that a single reviewer misses.
---

# Lesson — verifying coordinator's own prior Slack reply

When the task is *"verify whether my own earlier Slack reply was correct"*, the failure mode is **self-reference laundering**: the coordinator grades their own prior claim by looking at evidence they themselves cited. The review stage is where the actual verification happens — skip or combine it at your peril.

## What worked in this task

Parallel dispatch of **two distinct reviewer lenses**:

- `socrates-contrarian` → caught the **conceptual error** (Casbin doctrine: "ANY allow wins" vs actual `some(allow) && !some(deny)`). No amount of evidence-adding would have caught this because it was a prose framing bug.
- `apollo-assurance-marshal` → caught the **methodology error** (success-path verification asymmetry: "looks good" reply would have entered institutional memory as proven RCA even if the cause was coincident). This was a process/gate bug, not a conceptual one.

**Neither reviewer alone would have caught both.** Parallel dispatch of orthogonal lenses is the minimum viable quality gate when the coordinator is verifying their own prior claim.

## When to trigger this pattern

- Coordinator made a Slack/ADO/comment-level claim that is now being verified in the same session
- The claim is load-bearing for a user's next action
- The claim was made without running the falsifier probes that the current task will run
- Risk class: reputational (Eneco Trade Platform) or operational (user follows the claim)

## Required gates

1. The adversarial reviewer **must not be the coordinator**.
2. The evaluator **must not be the coordinator**.
3. Both review artifacts must be on disk (`test -s`) before the final outcome is emitted.
4. All reviewer findings tagged one of: Accepted / Rebutted / Deferred. Systematic Defer ≥50% = the coordinator is stonewalling and the whole pipeline should HALT.

## Timing cost

This task cost ~2 minutes of parallel reviewer dispatch against the diagnosis. Both reviewers returned actionable findings that changed the deliverable. ROI is overwhelming when the alternative is an unverified Slack reply shipping to an engineer who then follows it for a day before the error surfaces.
