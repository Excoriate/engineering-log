---
task_id: 2026-03-09-001
agent: coordinator
status: complete
summary: Spec for 03_proposal.md — IaC changes to fine-tune the alert
---

# Spec: 03_proposal.md

## Summary
Specific, IaC-level proposal to address the two confirmed issues: (1) description template bug, (2) dev environment paging Rootly unnecessarily.

## Output Path
`log/employer/eneco/00_incident_sre/01_alert_service_bus_topic_size_warning/03_proposal.md`

## Why
Verdict is "Fine-tune" — two issues confirmed by FACT-grade evidence warrant IaC changes.

## Changes to Propose

### Change 1: Fix description template (CRITICAL — misleading)
File: `terraform/metric-alert-service-bus.tf:107`
Before: `description = "Action will be triggered when any topic exceeds size of ${each.value.threshold}Mb"`
After:  `description = "Action will be triggered when any topic (EntityName) exceeds size of ${each.value.threshold} bytes (~${floor(each.value.threshold / 1000000)} MB). Evaluated every 1 min over a 5-min window."`
Rationale: Current description renders "400000000Mb" (unintelligible). Fixed version correctly states bytes unit, adds MB approximation, and explains evaluation parameters.

### Change 2: Exclude dev from Rootly paging (RECOMMENDATION — not critical)
This is a recommendation requiring team decision. The `ag-trade-platform-d` action group with Rootly webhook is managed externally (data source). The VPP team cannot directly remove it from this alert without coordinating with the platform team.
Options:
  a. Remove `data.azurerm_monitor_action_group.team["trade-platform"]` from dev action_group_ids
  b. Add environment condition: only include trade-platform AG when env == "p"
  c. Raise dev warning threshold to reduce noise (e.g., 600MB for dev)
  Recommended: Option b (symmetric with existing OpsGenie pattern)

## Sections Required
1. Executive Summary (Fine-tune verdict, 2 issues)
2. Change 1: Description Fix (before/after, rationale, risk=low)
3. Change 2: Dev Rootly paging (options, recommendation, team coordination needed)
4. Risk Assessment (both changes metadata-only for Change 1; Change 2 touches action_group_ids)
5. Rollback Plan (git revert + terraform apply; no state migration needed)
6. Falsifiable Before/After (specific condition: "after Change 1, alert description reads X")
7. Implementation Steps (terraform plan → review → apply per env)

## Verification
- Contains `metric-alert-service-bus.tf:107` citation
- Contains before/after diff for description
- Contains rollback procedure
- Explicitly addresses all 4 diagnosis options
