---
task_id: 2026-06-22-001
agent: codex
status: complete
summary: Specification for the authorization candidate list.
---

# Spec

The output table must include:

- short ID
- Rootly URL
- status
- alert name
- source
- created time in Europe/Amsterdam

The table must distinguish the full screenshot-compatible candidate set from the
strict rolling 48-hour subset, because those are different sets.

Looks-correct-while-wrong failure: listing only screenshot-visible rows or only
page 1 would omit matching alerts. The Rootly query reported two pages, and both
were fetched.
