---
task_id: 2026-05-11-007
agent: claude-code
status: complete
summary: Spec for new vault lesson — alerts created manually outside IaC during early platform stand-ups age silently because no review surface owns them; defense is a quarterly inventory diff (Azure-deployed rules vs IaC-declared rules). Ready to apply to llm-wiki/learnings/lessons/.
spec_target_path: $SECOND_BRAIN_PATH/llm-wiki/learnings/lessons/out-of-iac-alerts-decay-silently-quarterly-inventory-diff.md
spec_action: create
spec_zone: learnings/lessons
spec_status: ready_to_apply
---

# Spec — Lesson: Out-of-IaC Alerts Decay Silently — Defend With a Quarterly Inventory Diff

## Frontmatter (apply verbatim)

```yaml
---
description: "Alerts (scheduledQueryRules, metric alerts, log alerts) created manually in Azure portal/CLI/workstation-credential Terraform during platform stand-up never get adopted into IaC; their KQL/thresholds age alongside the underlying platform and the organization's review cadence (because they are not in any review surface). They eventually fire for a reason their author did not anticipate, and the page goes to an on-call who has never seen the rule before. Today's CMC incident is one such case: the rule was created 2024-01-24, never modified, never in IaC, escaped review for 15.5 months. Defense: schedule a quarterly inventory diff of Azure-deployed alert rules vs IaC-declared rules; any unmatched rule is a candidate for adoption-or-deletion within one sprint."
type: lesson
domain: tech
status: active
source: agent
created: 2026-05-11
last_validated: 2026-05-11
severity: high
confidence: validated
tags: [eneco, vpp, azure-monitor, alerts, out-of-iac, governance, quarterly-cadence, sre, platform-team]
---
```

## The Rule

If an alert is not in IaC, it has no review surface. If it has no review surface, its KQL and thresholds age silently — and one day it pages someone who has never seen it.

## Why (mechanism)

The Eneco-deployed proof case: rule `vpp-resource-unhealthy` in `mcprd-rg-vpp-p-res` was created by `eneco.hoffman@conclusion.nl` (Conclusion vendor identity) on 2024-01-24 via an ARM PUT (`systemData.createdAt == lastModifiedAt`, byte-identical → never re-written since). It is absent from every searched Eneco repo (`MC-VPP-Infrastructure`, `Eneco.Infrastructure`, others — confirmed by `codebase-locator` HIGH-confidence + coordinator cross-validation grep). KQL is single-predicate `AzureActivity | where CategoryValue == "ServiceHealth"`, sev-0, `autoMitigate=false`, `actions: null`. For 15.5 months no team owned its quality.

The fire mechanism today is documented in [[azure-monitor-late-ingestion-fires-alerts-from-stale-data]]; the structural defect is that nobody owned the rule.

## How to apply

### Quarterly Inventory Diff (proposed defense)

Per Trade Platform SRE rotation, every quarter:

```bash
# Step 1 — enumerate all scheduledQueryRules in each prd/acc/dev subscription
for SUB in <PRD_SUB_ID> <ACC_SUB_ID> <DEV_SUB_ID>; do
  az monitor scheduled-query list --subscription "$SUB" \
    --query "[].{name:name, rg:resourceGroup, sev:severity, autoMit:autoMitigate, hasActions:(actions.actionGroups!=null)}" \
    -o tsv > "deployed-rules-${SUB}.tsv"
done

# Step 2 — generate the IaC-derived expected name list from MC-VPP-Infrastructure tfvars
# Naming pattern: vpp-${each.key}-healthevent-${envShort}
# From configuration/{prd,acc,dev}-alerts.tfvars, extract var.monitor_query_rules_alert keys

# Step 3 — diff
# Anything in deployed-rules-*.tsv but not in expected = out-of-IaC orphan
# Action per orphan within ONE sprint: adopt-into-IaC OR delete (with sign-off)
```

### Real-time defense (for new rules)

Add to the team's alert-authoring checklist:
1. PR-only rule creation (no portal-only authoring on prd; require Terraform PR + review)
2. Mandatory action group binding (`actions: null` = HALT)
3. Mandatory KQL narrowing (no `CategoryValue == "ServiceHealth"` without `ActivityStatusValue` AND one of `impactedServices` / per-service projection / `_ResourceId` predicate)
4. Mandatory severity + autoMitigate combo review (sev-0 + autoMitigate=false requires extra reviewer)
5. Mandatory runbook URL in rule description

## What to avoid

- **Treating today's close-only as "done"** — the rule stayed in Azure; it can fire again on the next Microsoft 5Z1B-6KG-class event. Until adopted into IaC or deleted, this is a latent recurrence.
- **Letting governance/audit questions distract from the structural defect** — yes, a vendor identity created a sev-0 paging rule that escaped IaC for 15.5 months; that's an SRE governance question. The lesson here is operational: regardless of WHO created the rule, the absence of a quarterly inventory diff means anyone (vendor or employee) can leave one behind.

## Cross-Links

- [[2026-05-11-oncall-shift-trade-platform-quad-incident]] — episode of origin (Incident 1)
- [[azure-monitor-late-ingestion-fires-alerts-from-stale-data]] — sibling gotcha (today's fire mechanism)
- [[automitigate-false-orthogonal-to-severity-needs-manual-close-runbook]] — sibling lesson
- [[openshift-sanity-check-rule-out-not-diagnose]] — sibling pattern
- Source RCA: `log/employer/eneco/02_on_call_shift/2026_05_11_cmc_alert_vpp_cluster_prod/rca.md` L10 Lesson 1
