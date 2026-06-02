---
task_id: 2026-05-13-001
agent: pi
status: complete
summary: Evidence for Pi system prompt and AGENTS.md configuration surfaces.
---
Highest-info fact: Pi docs distinguish context files from system prompt replacement.

Evidence:
- README lines 296-304 (read offset 274): Pi loads `~/.pi/agent/AGENTS.md`, parent dirs, current dir as context files; all matching files concatenated.
- README line 307 (read offset 274): default system prompt can be replaced by `.pi/SYSTEM.md` or `~/.pi/agent/SYSTEM.md`; append via `APPEND_SYSTEM.md`.
- README lines 573-576 (read offset 558): `--system-prompt` replaces default prompt while context files and skills still append; `--append-system-prompt` appends.
- quickstart lines 66-80 (read offset 60): AGENTS.md is for project instructions and requires restart or `/reload` after changes.

Lane ledger:
- selected: official README, quickstart, settings docs.
- skipped: source code loader internals; not necessary for user-level configuration answer.
- blocked: external adversarial companion absent/probed for current runtime.

Missing-angle question: precedence between global/project SYSTEM.md if both exist is not explicit in the cited README excerpt beyond project/global locations.
Omitted-lane risk: edge-case ordering may require source-code inspection if user needs exact merge precedence.
Route-flip falsifier: if source code says AGENTS.md is ignored when SYSTEM.md exists, answer would change; docs instead say CLI replacement still appends context files/skills.
