---
task_id: 2026-05-13-001
agent: codex
status: done
summary: Obsidian CLI read-back must use path= for exact file verification.
---

# Obsidian CLI Exact Reads Need `path=`

`obsidian read "folder/note.md"` can return the active file instead of the
requested note. For consumer-proof read-back, use:

```bash
obsidian read path="folder/note.md"
```

The same applies to `links`, `backlinks`, and `file` commands when verifying a
specific note.

