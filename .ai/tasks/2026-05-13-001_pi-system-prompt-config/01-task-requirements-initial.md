---
task_id: 2026-05-13-001
agent: pi
status: initial
summary: Clarify where to configure Pi system prompt versus AGENTS.md.
---
TASK ANALYSIS
- Phase: Acquire | Brain: v5.7.0 | task_id: 2026-05-13-001
- Request: Determine whether Pi system prompt configuration uses SYSTEM.md, AGENTS.md in ~/.pi, or both.
- USER PRE-FRAMING: "if I need" + MY READ: configuration guidance; tone does not waive evidence.
- DOMAIN-CLASS: knowledge
- CONTROL-PLANE-ARTIFACT: y
- CRUBVG: C/R/U/B/V/G = 1/1/1/1/1/1 -> 7 [MID:C config surfaces interact] [MID:R reversible edits but affects future sessions] [MID:U docs needed] [MID:B agent behavior user-facing] [MID:V verify via docs/files] [MID:G partial context before docs] +1 for G
- Phase Compression Mode: Normal (control-plane guidance; no edits requested)
- System view + Frames: Primary process/config-loading; Secondary Kant/Socrates for prompt/rule distinction. unknown-unknown probe: docs may name SYSTEM.md or AGENTS.md precedence.
- Counterfactual: User may edit wrong file and see no behavior change.
- Success Criteria: Answer cites visible Pi docs/files and distinguishes hidden API system prompt from user-configurable instruction files.
- Hypotheses: H1 Pi uses ~/.pi/agent/AGENTS.md for agent instructions; eliminate if docs say SYSTEM.md is loaded. H2 SYSTEM.md is a prompt-template or non-current surface; eliminate if docs say edit it for default system prompt.
- SPECIALTY: none-fits in current runtime; Pi docs are source.
- Triggers: LIBRARIAN:y | FRAME-PRIMARY:Kant | EVALUATOR:n | DOMAIN:n | TOOLS:n
- BRAIN SCAN: dangerous assumption: current visible AGENTS path equals full prompt config; falsifier/probe: read Pi docs for prompts/config; likely failure: confuse hidden API system prompt with configurable user instructions; Roster:[UNVERIFIED[blocked]: companion surface present (probed ~/.pi/agent/subagents)]
