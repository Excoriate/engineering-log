---
task_id: 2026-05-13-001
agent: pi
status: final
summary: Live read-only Azure Sandbox investigation of FBE Logic Apps to identify Slack keep-enabled prompt workflow.
---
# Final Requirements

## Confirmed scope
Use Azure CLI read-only commands in Sandbox subscription `7b1ba02e-bac6-4c45-83a0-7f0d3104922e` to inspect three Logic Apps:

- `vpp-fbe-autodelete-trigger`
- `vpp-fbe-delete-handler`
- `vpp-fbe-deletion-trigger`

Return the JSON description of the one whose workflow asks the Slack user whether they want to keep their FBE enabled.

## Map evidence
- `az` is installed: `.ai/tasks/2026-05-13-001_logic-app-slack-fbe-query/context/01-map.txt`.
- Sandbox subscription ID source: eneco-tools-connect-mc-environments skill.
- Prior task maps exist; this task is live Azure resource inspection, not codebase context recreation.

## Verification Strategy
1. Set/verify active subscription is Sandbox.
2. Locate the three named Logic App resources/resource groups.
3. Export each resource/workflow JSON under task `context/`.
4. Search workflow definitions for Slack and keep/enable prompt terms.
5. Save selected JSON under `outcome/` and report path + exact basis.

## Route-flip assumption
If none of the three definitions contains Slack keep/enabled wording, do not guess; report no matching workflow and include evidence paths.
