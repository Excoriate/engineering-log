---
task_id: 2026-05-13-001
agent: pi
status: complete
summary: Verification results for Pi prompt configuration answer.
---
- PASS: README states AGENTS.md/CLAUDE.md context files load from global/parents/current and are concatenated.
- PASS: README states `.pi/SYSTEM.md` or `~/.pi/agent/SYSTEM.md` replaces default system prompt; `APPEND_SYSTEM.md` appends.
- PASS: README CLI section states `--system-prompt` replaces default prompt but context files and skills still append.

## Belief Changes
Initial uncertainty: whether SYSTEM.md replaces all instructions. Result: it replaces Pi default system prompt, not context files/skills per README CLI note.

Residual risk: exact precedence when both global and project SYSTEM.md exist not fully resolved from cited slices.
