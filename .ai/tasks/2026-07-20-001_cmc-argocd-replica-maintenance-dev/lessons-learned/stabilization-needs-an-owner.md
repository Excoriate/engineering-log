---
task_id: 2026-07-20-001
agent: codex
status: complete
summary: A locally invented observation duration is not an acceptance contract.
---

# Stabilization needs an owner

Repeated healthy samples prove only the interval actually observed. They do not create an authoritative maintenance-completion duration.

The first draft used convenient numeric defaults such as five minutes and two fresh samples. Those numbers were useful as observer heuristics but unsafe as closure gates because no Eneco or CMC contract supplied them.

Reusable rule: the signed maintenance intent must name the observation duration or handoff condition. If it does not, record `STABLE AS OBSERVED — DURATION CONTRACT NOT SUPPLIED`, preserve the exact first/last timestamps, and hand the unresolved duration decision to an identified human owner.
