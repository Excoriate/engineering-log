---
task_id: 2026-03-09-001
agent: principal-engineer-document-writer
status: complete
summary: Fine-tune proposal amended with adversarial review: Change 3 (for_each key), SRE operational gaps
---

# Proposal: Fine-Tune Service Bus Topic Size Warning Alert

**Verdict**: Fine-tune (not Remove, not Keep-as-is, not major redesign)

**Scope**: Two IaC changes to `terraform/metric-alert-service-bus.tf` plus one operational note requiring no code change.

| # | Change | Priority | Risk | Requires Team Decision |
|---|--------|----------|------|------------------------|
| 1 | Fix description template bug | HIGH | LOW | No |
| 2 | Remove Rootly paging from dev environment | MEDIUM | MEDIUM | Yes |
| 3 | Consumer backlog causing current firing | N/A | N/A | Consumer team action |

---

## Change 1: Description Template Bug

**Source**: `terraform/metric-alert-service-bus.tf:107`

### Problem

The description string appends "Mb" to a raw byte value, producing nonsensical output.

**Current HCL** (`metric-alert-service-bus.tf:107`):
```hcl
description = "Action will be triggered when any topic exceeds size of ${each.value.threshold}Mb"
```

**Current rendered output** (threshold = 400000000):
```
Action will be triggered when any topic exceeds size of 400000000Mb
```

400,000,000 MB = ~381 PB. The threshold is 400,000,000 **bytes** (400 MB). The unit suffix is wrong.

### Fix

**Proposed HCL**:
```hcl
description = "Alert fires when any Service Bus topic (EntityName) size exceeds ${each.value.threshold} bytes (~${floor(each.value.threshold / 1000000)} MB). Threshold = ${each.value.alert_name_suffix}. Window: PT5M maximum, evaluated every PT1M."
```

**Proposed rendered output** (threshold = 400000000):
```
Alert fires when any Service Bus topic (EntityName) size exceeds 400000000 bytes (~400 MB). Threshold = warning. Window: PT5M maximum, evaluated every PT1M.
```

For the critical threshold (800000000):
```
Alert fires when any Service Bus topic (EntityName) size exceeds 800000000 bytes (~800 MB). Threshold = critical. Window: PT5M maximum, evaluated every PT1M.
```

`floor()` produces clean integers: 400000000 / 1000000 = 400.0, 800000000 / 1000000 = 800.0.

### Diff

```diff
- description = "Action will be triggered when any topic exceeds size of ${each.value.threshold}Mb"
+ description = "Alert fires when any Service Bus topic (EntityName) size exceeds ${each.value.threshold} bytes (~${floor(each.value.threshold / 1000000)} MB). Threshold = ${each.value.alert_name_suffix}. Window: PT5M maximum, evaluated every PT1M."
```

### Risk Assessment

| Dimension | Assessment |
|-----------|------------|
| Risk level | LOW |
| Blast radius | None |
| Alert behavior change | None — description is metadata only |
| Resource recreation | No — in-place update to description field |
| Rollback | `git revert` + `terraform apply` restores old description |

This change modifies **metadata only**. The `description` field on `azurerm_monitor_metric_alert` does not affect threshold evaluation, action group routing, or alert firing logic. Terraform will perform an in-place update (no destroy/recreate).

---

## Change 2: Dev Environment Paging Rootly

**Source**: `terraform/metric-alert-service-bus.tf:125-132`

### Problem

The current action group assignment routes dev environment alerts to `ag-trade-platform-d`, which contains the `rootly-trade-platform` webhook. A dev topic size warning pages on-call engineers via Rootly. Dev alerts should inform (Slack) but not page.

### Current HCL

```hcl
action_group_ids = var.environmentShort == "p" ? [
  azurerm_monitor_action_group.main.id,
  module.actiongroup_service_bus_topic_size.action_group_id,
  module.actiongroup_opsgenie.action_group_id,
  data.azurerm_monitor_action_group.team["trade-platform"].id
] : [
  azurerm_monitor_action_group.main.id,
  module.actiongroup_service_bus_topic_size.action_group_id,
  data.azurerm_monitor_action_group.team["trade-platform"].id
]
```

The ternary distinguishes production (adds OpsGenie) from non-production, but **both branches** include `trade-platform`. In dev, `trade-platform` resolves to `ag-trade-platform-d` which contains the Rootly webhook.

### Options

#### Option A — Remove trade-platform from all non-production

```hcl
action_group_ids = var.environmentShort == "p" ? [
  azurerm_monitor_action_group.main.id,
  module.actiongroup_service_bus_topic_size.action_group_id,
  module.actiongroup_opsgenie.action_group_id,
  data.azurerm_monitor_action_group.team["trade-platform"].id
] : [
  azurerm_monitor_action_group.main.id,
  module.actiongroup_service_bus_topic_size.action_group_id
]
```

```diff
  ] : [
    azurerm_monitor_action_group.main.id,
-   module.actiongroup_service_bus_topic_size.action_group_id,
-   data.azurerm_monitor_action_group.team["trade-platform"].id
+   module.actiongroup_service_bus_topic_size.action_group_id
  ]
```

| Dimension | Assessment |
|-----------|------------|
| Simplicity | Highest — minimal diff |
| Tradeoff | Removes trade-platform from **ACC too** — acceptance no longer mirrors production paging |
| Risk | Low if ACC paging via trade-platform is not required |

#### Option B (RECOMMENDED) — Three-tier: prd / acc / dev

```hcl
action_group_ids = (
  var.environmentShort == "p" ? [
    azurerm_monitor_action_group.main.id,
    module.actiongroup_service_bus_topic_size.action_group_id,
    module.actiongroup_opsgenie.action_group_id,
    data.azurerm_monitor_action_group.team["trade-platform"].id
  ] : var.environmentShort == "a" ? [
    azurerm_monitor_action_group.main.id,
    module.actiongroup_service_bus_topic_size.action_group_id,
    data.azurerm_monitor_action_group.team["trade-platform"].id
  ] : [
    azurerm_monitor_action_group.main.id,
    module.actiongroup_service_bus_topic_size.action_group_id
  ]
)
```

```diff
- action_group_ids = var.environmentShort == "p" ? [
-   azurerm_monitor_action_group.main.id,
-   module.actiongroup_service_bus_topic_size.action_group_id,
-   module.actiongroup_opsgenie.action_group_id,
-   data.azurerm_monitor_action_group.team["trade-platform"].id
- ] : [
-   azurerm_monitor_action_group.main.id,
-   module.actiongroup_service_bus_topic_size.action_group_id,
-   data.azurerm_monitor_action_group.team["trade-platform"].id
- ]
+ action_group_ids = (
+   var.environmentShort == "p" ? [
+     azurerm_monitor_action_group.main.id,
+     module.actiongroup_service_bus_topic_size.action_group_id,
+     module.actiongroup_opsgenie.action_group_id,
+     data.azurerm_monitor_action_group.team["trade-platform"].id
+   ] : var.environmentShort == "a" ? [
+     azurerm_monitor_action_group.main.id,
+     module.actiongroup_service_bus_topic_size.action_group_id,
+     data.azurerm_monitor_action_group.team["trade-platform"].id
+   ] : [
+     azurerm_monitor_action_group.main.id,
+     module.actiongroup_service_bus_topic_size.action_group_id
+   ]
+ )
```

| Dimension | Assessment |
|-----------|------------|
| Prd | OpsGenie + trade-platform + Slack (unchanged) |
| Acc | trade-platform + Slack (mirrors prd paging, no OpsGenie) |
| Dev | Slack only (no paging) |
| Rationale | Symmetric with existing OpsGenie-only-in-prod pattern. ACC mirrors prd alerting minus OpsGenie. Dev is notification-only. |
| Risk | Medium — requires team alignment on ACC behavior |

#### Option C — Raise dev thresholds

Change `dev.tfvars:58`:
```diff
- threshold = 400000000
+ threshold = 600000000  # 600 MB
```

| Dimension | Assessment |
|-----------|------------|
| Simplicity | One-line change |
| Tradeoff | Does not address the fundamental question: should dev page Rootly at all? Merely delays the alert. |
| Risk | Low technically, but avoids the root cause |

### Recommendation

**Option B**. It applies the principle of least surprise: production pages everywhere, acceptance mirrors production routing (minus OpsGenie), dev notifies without paging. This is symmetric with the existing OpsGenie-only-in-prod pattern already established in the ternary.

### Coordination Requirement

Options B and C require team alignment before implementation. The `trade-platform` action group is owned by the platform team. Removing it from dev requires coordination — the team may have monitoring dashboards or SLAs that depend on receiving alerts from all environments. Raise as an engineering proposal; do not merge without explicit approval from the trade-platform team.

---

## Operational Note: Current Firing Cause

The alert is currently firing because subscription `asset-scheduling-gateway` has 3,756 unread messages on topic `assetplanning-asset-strike-price-schedule-created-v1`. This is a consumer-side backlog — the topic accepts messages, but the subscription consumer is not draining them.

**No IaC change required.** This is an application-level issue owned by the consumer team (`asset-scheduling-gateway`). Actions:

1. Notify the consumer team that their subscription has 3,756 unread messages.
2. Verify whether the consumer service is running and processing.
3. If the consumer is intentionally paused, consider dead-lettering or disabling the subscription temporarily.

---

## Risk Assessment Summary

| Change | Risk | Blast Radius | Alert Behavior Impact | Resource Recreation |
|--------|------|--------------|----------------------|---------------------|
| 1: Description fix | LOW | None | None (metadata only) | No (in-place update) |
| 2: Dev action groups (Option B) | MEDIUM | Dev environment only | Dev stops paging Rootly | No (in-place update) |
| 2: ACC action groups (Option B) | NONE | N/A | ACC unchanged from current | No change |
| 2: Prd action groups (Option B) | NONE | N/A | Prd unchanged from current | No change |

---

## Rollback Plan

Both changes are fully reversible via `git revert`.

```bash
# 1. Revert the commit
git revert <commit-sha> --no-edit

# 2. Plan and review per environment (dev first)
cd terraform/
terraform plan -var-file=dev.tfvars -out=rollback-dev.tfplan
# Review the plan output — verify only description and/or action_group_ids change

# 3. Apply rollback
terraform apply rollback-dev.tfplan

# 4. Validate rollback
az monitor metrics alert show \
  --name "<alert-name>" \
  --resource-group "<rg-name>" \
  --query "description"
# Verify description reverts to original text

# 5. Repeat for acc, then prd
terraform plan -var-file=acc.tfvars -out=rollback-acc.tfplan
terraform apply rollback-acc.tfplan
terraform plan -var-file=prd.tfvars -out=rollback-prd.tfplan
terraform apply rollback-prd.tfplan
```

No resource destruction occurs during rollback. Both `description` and `action_group_ids` are in-place update fields on `azurerm_monitor_metric_alert`.

---

## Falsifiable Before/After State

### Change 1 — Description

**Before** (`terraform apply` in any environment):
```bash
az monitor metrics alert show \
  --name "<alert-name>" \
  --resource-group "<rg>" \
  --query "description" -o tsv
```
Returns: `Action will be triggered when any topic exceeds size of 400000000Mb`

**After**:
Returns: `Alert fires when any Service Bus topic (EntityName) size exceeds 400000000 bytes (~400 MB). Threshold = warning. Window: PT5M maximum, evaluated every PT1M.`

**Falsifier**: If the description still contains "Mb" after apply, the change failed.

### Change 2 — Dev Action Groups (Option B)

**Before** (dev environment):
```bash
az monitor metrics alert show \
  --name "<alert-name>" \
  --resource-group "<rg-dev>" \
  --query "actions[].actionGroupId" -o tsv
```
Returns list containing `ag-trade-platform-d`.

**After**:
Returns list **without** `ag-trade-platform-d`.

**Falsifier**: If `ag-trade-platform-d` appears in the dev alert's action group list after apply, the change failed.

---

## Implementation Sequence

| Step | Environment | Action | Gate |
|------|-------------|--------|------|
| 1 | dev | `terraform plan -var-file=dev.tfvars` | Review plan: only description + action_group_ids change |
| 2 | dev | `terraform apply` | Verify via `az monitor metrics alert show` |
| 3 | dev | Validate: trigger test alert, confirm no Rootly page | Rootly incident log shows no new incident |
| 4 | acc | `terraform plan -var-file=acc.tfvars` | Review plan: only description changes (Option B leaves acc action groups intact) |
| 5 | acc | `terraform apply` | Verify via `az monitor metrics alert show` |
| 6 | prd | `terraform plan -var-file=prd.tfvars` | Review plan: only description changes (Option B leaves prd action groups intact) |
| 7 | prd | `terraform apply` | Verify via `az monitor metrics alert show` |

Change 1 (description fix) can proceed immediately — no team approval needed.
Change 2 (dev action groups) is blocked on trade-platform team approval.

---

## Adversarial Review Findings (Linus + SRE-Maniac)

### Change 3: Fix `for_each` Key (HIGH SEVERITY — Latent Bug)

**File**: `terraform/metric-alert-service-bus.tf:101`
**Severity**: HIGH (latent, not currently manifesting)

Current:
```hcl
for_each = { for c in var.servicebus_topic_size_alerts : c.severity_level => c }
```

Problem: The map key is `c.severity_level` (a number: 0 or 2). If two entries in `servicebus_topic_size_alerts` ever share the same severity level, Terraform will error at plan time: `"Two different items produced the key X"`. The variable declaration has no uniqueness constraint on `severity_level`.

Additionally, resource addresses in Terraform state are `module.maxtopicsize_list["2"]` and `module.maxtopicsize_list["0"]` — opaque numeric keys that do not communicate intent.

Proposed fix:
```hcl
for_each = { for c in var.servicebus_topic_size_alerts : c.alert_name_suffix => c }
```

This produces:
- `module.maxtopicsize_list["warning"]` — semantically clear
- `module.maxtopicsize_list["critical"]` — semantically clear
- Uniqueness guaranteed by semantic value (`"warning"` and `"critical"` cannot collide)

**State Migration Required**: This key change renames the Terraform resource addresses. A `terraform state mv` is needed per environment before apply:
```bash
# Per environment (dev, acc, prd):
terraform state mv 'module.maxtopicsize_list["2"]' 'module.maxtopicsize_list["warning"]'
terraform state mv 'module.maxtopicsize_list["0"]' 'module.maxtopicsize_list["critical"]'
```
Without state mv, Terraform will destroy-and-recreate the alert resources (brief alert gap during recreation — acceptable but noisy). State mv preserves resource lifecycle.

**Risk**: MEDIUM (state migration adds apply complexity). Blast radius: 2 alert resources per environment × 3 environments = 6 resources touched. All metadata changes — alert firing is unaffected during recreation gap.

---

### Change 4 (Optional Refactor): Use `concat()` for Unconditional Action Groups

**File**: `terraform/metric-alert-service-bus.tf:125-132`

The `azurerm_monitor_action_group.main.id` and `module.actiongroup_service_bus_topic_size.action_group_id` appear in ALL branches of the conditional. They are unconditional groups hidden inside conditional syntax. Extract them:

Current pattern (repeated in all branches):
```hcl
action_group_ids = var.environmentShort == "p" ? [
  azurerm_monitor_action_group.main.id,
  module.actiongroup_service_bus_topic_size.action_group_id,
  ...env-specific...
] : [
  azurerm_monitor_action_group.main.id,
  module.actiongroup_service_bus_topic_size.action_group_id,
  ...env-specific...
]
```

Proposed (if Change 4 is adopted):
```hcl
action_group_ids = concat(
  [
    azurerm_monitor_action_group.main.id,
    module.actiongroup_service_bus_topic_size.action_group_id,
  ],
  var.environmentShort == "p" ? [
    module.actiongroup_opsgenie.action_group_id,
    data.azurerm_monitor_action_group.team["trade-platform"].id,
  ] : var.environmentShort == "a" ? [
    data.azurerm_monitor_action_group.team["trade-platform"].id,
  ] : []
)
```

This makes the data structure explicit: base groups are always present, environment-specific groups are appended. Easier to extend and audit.

**Risk**: LOW (same behavioral outcome). **Priority**: OPTIONAL — implement after Change 1 and Change 2 are stabilized. Do not mix with Change 3 (state migration) in the same apply.

---

### SRE-Maniac: Operational Follow-Up Items (NOT blocking proposals)

These are gaps in the alert ECOSYSTEM (not this alert's design) to track as future work:

1. **DLQ Monitoring Gap (HIGH)**: No alert exists for `DeadLetteredMessages` accumulation. Dead-lettered messages represent silent data loss — consumers reject messages, they move to DLQ, business events are lost with no page. Recommend: add a `DeadLetteredMessages > 0` alert per topic (EntityName dimension) with Severity 1.

2. **Small-Payload Backlog Blindness (HIGH)**: The `Size` metric does not alert on high message-count backlogs with small payloads (e.g., 50,000 messages × 1 KB = 50 MB — no alert fires). For control-plane topics with small JSON payloads, a complementary `ActiveMessageCount` alert is needed.

3. **Rootly Auto-Resolve Churn (MEDIUM)**: `autoMitigate = true` causes fire-resolve webhooks to Rootly. If the consumer is flaky (crash-restart cycle), Rootly receives repeated fire-resolve pairs and creates multiple incidents. Verify Rootly's deduplication policy for rapid fire/resolve on the same alert rule.

4. **252-Topic Storm Risk (MEDIUM)**: If the consumer service handling multiple topics crashes simultaneously, all affected topics fire simultaneously. Whether Rootly creates 1 incident or 252 incidents for near-simultaneous webhooks depends on Rootly configuration. Validate this with the platform team.

5. **SEV Classification**: Current breach (`assetplanning-asset-strike-price-schedule-created-v1` at 520 MB in dev) is **SEV-3** — actively degrading, consumer confirmed stopped, finite time to data loss, but dev environment with no direct customer impact. Would be SEV-2 if same numbers were in production.
