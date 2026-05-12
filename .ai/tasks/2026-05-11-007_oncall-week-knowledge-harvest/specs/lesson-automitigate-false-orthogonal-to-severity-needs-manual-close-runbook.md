---
task_id: 2026-05-11-007
agent: claude-code
status: complete
summary: Spec for new vault lesson — autoMitigate=false on any paging-bound Azure alert (regardless of severity) requires a manual-close runbook; the property is ORTHOGONAL to severity, severity merely intensifies on-call cost. Ready to apply to llm-wiki/learnings/lessons/.
spec_target_path: $SECOND_BRAIN_PATH/llm-wiki/learnings/lessons/automitigate-false-orthogonal-to-severity-needs-manual-close-runbook.md
spec_action: create
spec_zone: learnings/lessons
spec_status: ready_to_apply
---

# Spec — Lesson: `autoMitigate=false` Is Orthogonal to Severity (Both Need a Manual-Close Runbook)

## Frontmatter (apply verbatim)

```yaml
---
description: "Azure scheduled-query-rule property autoMitigate=false is the irreversible commitment that every fire becomes a permanent Alerts-blade entry until manually closed. This property is ORTHOGONAL to severity — a sev-2 rule with autoMitigate=false has the same 'stays Fired forever' property; severity changes who-gets-paged-how, not the auto-close behavior. The asymmetry (automatic firing, manual resolution) concentrates noise on the on-call. Any paging-bound rule with autoMitigate=false MUST have (a) a documented manual-close runbook, (b) an action group routing to a 24/7 surface, (c) a runbook URL in the rule description. Sev-0 with autoMitigate=false requires an extra reviewer."
type: lesson
domain: tech
status: active
source: agent
created: 2026-05-11
last_validated: 2026-05-11
severity: high
confidence: validated
tags: [eneco, vpp, azure-monitor, automitigate, severity, alert-design, runbook, on-call-toil]
---
```

## The Rule

`autoMitigate=false` is the primary axis of "stays Fired until human acts." Severity is merely an intensifier of the cost when humans must act. Treat them as independent design decisions.

## Why (mechanism)

When an Azure scheduled-query-rule fires, the resulting alert has two state fields:
- `alertState` — `New | Acknowledged | Closed` (transitionable by human action)
- `monitorCondition` — `Fired | Resolved` (transitionable by the rule's criteria re-evaluation)

`autoMitigate=true` means: when criteria stop being met, the engine sets `monitorCondition=Resolved` and (optionally) auto-closes the alert. `autoMitigate=false` means: the engine NEVER auto-resolves — `monitorCondition` stays `Fired` until a human runs `changestate?newState=Closed` (or the rule itself is disabled).

Severity (sev-0..sev-4) controls routing/escalation, NOT auto-close. A sev-2 rule with `autoMitigate=false` has the SAME "stays Fired forever" property as a sev-0 rule with `autoMitigate=false`. The on-call toil cost differs by severity, but the structural defect is identical.

Today's CMC incident: rule `vpp-resource-unhealthy` is sev-0 + `autoMitigate=false`. The alert closed at 15:06 UTC after a human (Alex) issued `az rest POST .../changestate?newState=Closed`; `monitorCondition` stayed `Fired` (expected). Without manual action, the alert would persist forever in the Alerts blade, even though the triggering ServiceHealth incident was already resolved.

## How to apply

### Audit existing rules

```bash
# Find sev-0 autoMitigate=false rules (highest-toll combination)
az monitor scheduled-query list --subscription <SUB_ID> \
  --query "[?autoMitigate==\`false\` && severity==\`0\`].{name:name, sev:severity}" -o tsv
# Each result MUST have: documented runbook URL + bound action group + manual-close protocol

# Broader audit: ALL autoMitigate=false rules (any severity)
az monitor scheduled-query list --subscription <SUB_ID> \
  --query "[?autoMitigate==\`false\`].{name:name, sev:severity}" -o tsv
# Each must have a manual-close protocol or a justified exception
```

### Alert-authoring checklist

For ANY paging-bound rule with `autoMitigate=false`:

| Requirement | Why | Verify in PR |
|-------------|-----|--------------|
| Action group bound to a 24/7 surface (Rootly, PagerDuty, ServiceNow ITSM connector) | The "fired forever" property is only operationally tolerable if a human is paged immediately | `actions.actionGroups != null` |
| Manual-close runbook URL in rule description | The on-call must know HOW to close, not just THAT they need to | `description` field contains runbook URL |
| Documented close-command (PR-reviewed) | `az rest POST .../changestate?newState=Closed` with the exact resource/api-version pinned | Runbook contains exact command |
| Severity-vs-autoMitigate review gate | sev-0 + autoMitigate=false should require an additional reviewer beyond a single platform engineer | Branch-protection rule on alert IaC repo |

### Disable as last resort

If a rule fires repeatedly with `autoMitigate=false` and no clean criteria reset exists, consider `--disabled true` as a tactical pause while a proper redesign lands. This is reversible (`--disabled false`) and stops the noise without losing the rule's existence for future review.

## What to avoid

- **Conflating severity and autoMitigate in design** — the original v1 of today's CMC RCA Lesson 3 made this mistake; Socrates F5 forced the rewrite. Severity = routing tier; autoMitigate = state-machine policy.
- **Letting `autoMitigate=false` ship without a manual-close runbook** — operational gap; reactive every time it fires.
- **Treating "autoMitigate=false on sev-0" as the only problem** — sev-2 with autoMitigate=false on a noisy rule generates the same residue, just routed differently.

## Cross-Links

- [[2026-05-11-oncall-shift-trade-platform-quad-incident]] — episode of origin (Incident 1)
- [[azure-alert-close-two-plane-azure-plus-servicenow]] — sibling pattern (the manual-close command)
- [[out-of-iac-alerts-decay-silently-quarterly-inventory-diff]] — sibling lesson
- [[azure-monitor-late-ingestion-fires-alerts-from-stale-data]] — sibling gotcha (today's specific fire mechanism)
- Source RCA: `log/employer/eneco/02_on_call_shift/2026_05_11_cmc_alert_vpp_cluster_prod/rca.md` L10 Lesson 3
