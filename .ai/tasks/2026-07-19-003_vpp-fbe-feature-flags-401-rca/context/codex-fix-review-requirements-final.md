---
task_id: 2026-07-19-003
agent: codex
status: confirmed
summary: Final scope and acceptance contract for the independent fix review.
---

# Final requirements — independent fix review

## Confirmed scope

Review the fix only. Use the RCA as context without taking ownership of its mechanism verdict. Directly inspect the named live-evidence file and local pipeline, Helm, FBE Terraform, and App Configuration module sources. Do not query the live cluster, browse the network, or import other reviewers' conclusions.

## Required verdict contract

The receipt must cover:

1. P1 recreate-case correctness, CSI timing race, recreate route, and deploy-job Kubernetes/ArgoCD credentials.
2. P2 Kubernetes Secret refresh versus mounted-file refresh, plus the correct Deployment annotation surface.
3. P3 value-update versus ForceNew semantics, module output existence, and pinned-ref/tag implications.
4. Duncan's exact first-creation-without-manual-delete outcome, including out-of-band recreate gaps.
5. Every concrete file path, line number, and command in `how-to-fix.md` checked against local source.

Each item gets exactly one top-level verdict from `SURVIVES`, `BROKEN`, or `UNVERIFIABLE`, a one-sentence reason, and a discriminating check. Subclaims may receive separate verdicts when a composite claim mixes proven and unproved parts.

## Sufficiency and clarification decision

No user clarification is needed: the exact source set, review posture, live-access boundary, verdict vocabulary, output path, and stdout ABI are all explicit. The only fact that could promote source-only uncertainty—the installed CSI/Reloader behavior—is intentionally unavailable; it must remain `UNVERIFIABLE` with an exact live discriminating check rather than becoming a question.

## Counterfactual

If this review omits ordering, trigger-route, credential, informer-event, provider-schema, or first-creation checks, the document could prescribe a green but non-causal rollout and fail the developer's exact outcome.
