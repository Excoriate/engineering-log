# SECOND BRAIN — SESSION RECALL

## Active Task: 2026-04-27-002-rca-holistic-skill-finalization
---
title: rca-holistic skill finalization
type: task
subtype: active
domain: tech
status: complete
source: codex
created: 2026-04-27
updated: 2026-04-27
tags: [stdlib, skills, rca, skill-upgrade]

## Active Task: 2026-04-28-001-improve-rust-pairing-mentor-skill
---
title: rust-pairing-mentor skill visual contract upgrade
type: task
subtype: active
domain: tech
status: complete
source: codex
created: 2026-04-28
updated: 2026-04-28
tags: [stdlib, skills, rust, validation]

## Active Task: mc-vpp-infrastructure-harness-bootstrap
---
title: MC-VPP-Infrastructure — A-01 phased rollout plan confirmed, A-03 out of scope
type: task
subtype: handoff
domain: tech
status: active
source: agent
created: 2026-04-21
updated: 2026-04-24
review_after: 2026-05-15

## High-Priority Lessons
- [high] When verifying your own prior claim (Slack reply, ADR, assertion), dispatch an adversarial reviewer AND an evaluator in parallel. One lens alone misses either the conceptual or the methodology error class.[scope: log/employer/eneco/**]
- [high] ArgoCD access requires three planes: AAD group membership + Enterprise App assignment (groupMembershipClaims:ApplicationGroup) + AppProject role binding. Any missing plane = silent denial.[scope: log/employer/eneco/**]
- [high] ADO stage with trigger:none + approval gate that times out → stage silently skips. The 2-hour-exact delta in Timeline Checkpoint.Approval records distinguishes timeout (ADO default) from 'plan no change'. Read Timeline records, not just pipeline logs.[scope: log/employer/eneco/**]
- [high] Rootly resolve does NOT close upstream Azure Monitor alerts. RCA action steps must explicitly drive both Rootly and Microsoft.AlertsManagement/alerts/<id> to terminal state. Resolving only one leaves a zombie alert.[scope: log/employer/eneco/**]
