---
task_id: 2026-06-22-001
agent: codex
status: initial
summary: Initial requirements for listing recent Rootly ArgoCDSyncAlert alerts.
---

# Task Requirements Initial

## Request

User wants a list of all Rootly alerts from the last two days whose name is
`ArgoCDSyncAlert`, like `https://rootly.com/account/alerts/MECCjA`, so the user
can authorize marking them resolved later.

## Scope

- Read Rootly alert data.
- Filter by alert name containing or equaling `ArgoCDSyncAlert`.
- Limit to alerts created in the last two days relative to 2026-06-22.
- Prefer acknowledged alerts, because the user states the candidates are already acknowledged.
- Do not resolve alerts in this task.

## Success Criteria

- Produce an authorization-ready list with short ID, title/name, status, urgency,
  created time, and Rootly URL when available.
- Evidence comes from a Rootly query or Rootly CLI/API output, not from the screenshot alone.
- Any uncertainty about filtering or access is explicitly labeled.

## Risk

Wrong IDs are the main risk: the subsequent resolve action could affect unrelated
alerts. The discriminating check is to query Rootly using the name/time/status
criteria rather than transcribing only the visible screenshot rows.
