---
task_id: 2026-04-26-002
agent: claude-opus-4-7
status: complete
summary: Discovery sequence — Rootly payload first, MC connect, az metrics, IaC reconciliation.
---

# Map: Discovery Plan

## Highest-info question

What metric, on what Azure resource, in what subscription/RG, breached what threshold, in what time window, and is the breach still active?

## Probe sequence (cheapest discriminating first)

1. **Rootly alert payload** — `mcp__rootly__get_alert_by_short_id` with `pbbtBV` → metric, resource id, fingerprint, source (Azure Monitor vs other), state, fired_at, raw_payload. ELIMINATES H3 (synthetic) if source=Azure Monitor.
2. **Related incidents** — `mcp__rootly__find_related_incidents` against the alert id → recurrence/triage signal.
3. **Connect MC dev** — invoke `eneco-tools-connect-mc-environments` skill (dev) → cache az creds. Subscription only swaps if payload says acc/prd.
4. **Azure metric series** — `az monitor metrics list --resource <id> --metric <metric> --start-time <fired-30m> --end-time <fired+30m> --aggregation Maximum,Total,Average` → CONFIRM same breach.
5. **Resource health** — `az resource show --ids <resource_id>`; `az monitor metrics list-definitions` if metric name needs disambiguation.
6. **IaC reconciliation** — grep `metric-alert-*.tf` for alert/metric → identify TF block → grep `<env>-alerts.tfvars` for threshold variable.
7. **Slack thread** — `mcp__slack__slack_search_public` with alert short_id and metric name in #myriad-platform / #incident-* — operator context.
8. **Cross-incident pattern** — `mcp__rootly__list_incidents` filtered by alert source → recurrence vs novel.

## Falsifier checkpoints

- After step 1: H3 (synthetic) status lockable.
- After step 4: H1 vs H2 lockable on metric name (e.g., `DeadletteredMessages` → H1).
- After step 6: residual misconfiguration vs runtime issue distinguishable (threshold vs actual breach).

## Bounds

- ≤2 reproduction probes during Phase 2 (already used 0; reserve for Phase 4).
- No writes to Azure or Rootly state. No incident creation, no ack. Read-only.
