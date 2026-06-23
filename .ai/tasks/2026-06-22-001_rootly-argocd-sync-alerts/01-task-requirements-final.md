---
task_id: 2026-06-22-001
agent: codex
status: final
summary: Final requirements for Rootly ArgoCDSyncAlert candidate listing.
---

# Task Requirements Final

List the Rootly alert short IDs suitable for later user authorization to resolve,
with no status mutation performed in this turn.

Selection criteria:

- `status = acknowledged`
- `summary = ArgoCDSyncAlert`
- primary window: `created_at >= 2026-06-18T22:00:00Z`, to include the visible
  screenshot rows that Rootly shows as roughly two days old
- strict rolling 48-hour cross-check: `created_at >= 2026-06-20T07:24:53Z`

Verification criteria:

- Rootly MCP query must cover all returned pages.
- Exclude any acknowledged alerts in the window whose summary is not
  `ArgoCDSyncAlert`.
- Preserve Rootly URLs so the user can inspect exact alerts before approving
  resolve.
