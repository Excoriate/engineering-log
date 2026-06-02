# SECOND BRAIN — SESSION RECALL

## Active Handoff: mc-vpp-infrastructure-harness-bootstrap
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
tags: [mc-vpp-infrastructure, harness, immutability, handoff, phase-plan]
---

## What Was Done

## High-Priority Lessons
- [high] Always read _index.md before writing to any vault folder[scope: **/*]
- [high] Keep root docs and generated wrappers thin; mutable llm-wiki topology belongs only in centralized harness surfaces.[scope: .ai/harness/**]
- [high] Completed import batches must reconcile __import_data_tmp or future runs will misread finished source material as pending residue.[scope: __import_data_tmp/**]
- [high] Replace generic fallback scaffolds before adding domain-native reasoning machinery to specialist prompts[scope: std/subagents/software_engineering/**]
- [high] Regenerating Codex agent TOMLs from cc markdown with the canonical converter preserves the markdown name and will drop the repository's codex-* naming envelope unless it is preserved explicitly[scope: std/subagents/**]

## Available Context Notes
- repos/mc-vpp-infrastructure
- tools/second-brain-hooks
