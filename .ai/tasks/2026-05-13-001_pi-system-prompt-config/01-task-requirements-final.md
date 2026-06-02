---
task_id: 2026-05-13-001
agent: pi
status: final
summary: Final requirements for Pi prompt configuration guidance.
---
Need answer: whether to edit SYSTEM.md, AGENTS.md, or both.
Key falsifier changed from initial: docs explicitly say `--system-prompt` replaces default prompt while context files and skills still append; so SYSTEM.md does not make AGENTS.md categorically irrelevant.

## Verification Strategy
Truth surface: official installed Pi documentation and visible runtime paths.
Acceptance: answer distinguishes default system prompt replacement from appended context instructions, with paths and practical recommendation.
Witness != producer: command/read outputs from installed docs under pi package path.
