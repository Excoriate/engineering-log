---
task_id: 2026-03-09-002
agent: coordinator
status: complete
summary: Step-by-step PR specification for Service Bus alert fine-tune — executable by human or Claude Code
---

# PR Specification: Service Bus Alert Fine-tune

**Target repository**: `MC-VPP-Infrastructure` (Azure DevOps)
**Target file**: `terraform/metric-alert-service-bus.tf`
**Supporting files**: `configuration/dev.tfvars`, `configuration/acc.tfvars`, `configuration/prd.tfvars` (read-only reference; no changes required)
**Basis**: Analysis `01_analysis-alert.md` + Proposal `03_proposal.md` (incident log `00_incident_sre/01_alert_service_bus_topic_size_warning/`)

---

## Context: Why This PR Exists

The metric alert `mcdta-vpp-sb-vpp-sbus-d-topic-size-d-warning` (and its sibling `*-critical`) are
currently firing in dev and routing pages to Rootly via the `ag-trade-platform-d` action group. Two
confirmed defects were found through source-code inspection and live environment analysis:

1. **Description bug**: The description template at `metric-alert-service-bus.tf:107` renders as
   `"Action will be triggered when any topic exceeds size of 400000000Mb"` — the raw threshold in
   bytes is concatenated with the literal string `"Mb"`, making it appear as 400 million megabytes
   (~381 petabytes). The correct reading is ~400 MB. This misleads every responder who reads the
   alert in Azure Portal, Rootly, or Slack.

2. **Dev environment pages Rootly**: The action group list at lines 125–132 includes
   `data.azurerm_monitor_action_group.team["trade-platform"]` in ALL environments, including dev.
   That action group contains the `rootly-trade-platform` webhook (confirmed via live
   `az monitor action-group show`). This means a dev topic size breach pages on-call engineers
   the same as a production breach — alert fatigue, false urgency, wasted triage time.

A third structural issue was surfaced during adversarial code review (Linus-style):

3. **`for_each` key collision risk**: The `for_each` at line 101 uses `c.severity_level` as the
   map key. If the `servicebus_topic_size_alerts` variable ever contains two entries with the same
   `severity_level`, Terraform errors at plan time. The semantically correct key is
   `c.alert_name_suffix` (values: `"warning"`, `"critical"`), which is inherently unique and
   produces readable resource addresses (`module.maxtopicsize_list["warning"]` instead of
   `module.maxtopicsize_list["2"]`). **This change requires a Terraform state migration.**

---

## PR Metadata

| Field | Value |
|-------|-------|
| **Branch name** | `fix/service-bus-alert-description-and-env-routing` |
| **PR title** | `fix(monitoring): fix SB topic-size alert description unit bug and scope dev routing` |
| **PR type** | Bug fix |
| **Labels** | `monitoring`, `bugfix`, `alerting`, `no-functional-change` |
| **Environments affected** | dev, acc, prd (all; description only) + dev (action group routing) |
| **Blast radius** | Metadata-only for Change 1; notification routing for Change 2; state migration for Change 3 |
| **Suggested reviewers** | IaC team lead + on-call rotation lead (confirm dev Rootly policy) |

---

## Change 1 — Fix description template (REQUIRED, low risk)

### What & Why

`metric-alert-service-bus.tf:107` interpolates the raw threshold value (in bytes) with the literal
suffix `"Mb"`. For `threshold = 400000000` this renders `"400000000Mb"` which reads as 400 million
megabytes. The fix renders the value in both bytes (precise) and approximate MB (human-readable),
and adds evaluation context so responders understand the signal without reading the IaC.

This change is **metadata-only**: it does not affect threshold value, operator, aggregation,
evaluation frequency, or action group routing. `terraform apply` performs an in-place update with
zero risk of re-creating or disabling the alert.

### Exact diff

**File**: `terraform/metric-alert-service-bus.tf`

```diff
- description = "Action will be triggered when any topic exceeds size of ${each.value.threshold}Mb"
+ description = "Alert fires when any Service Bus topic (EntityName) size exceeds ${each.value.threshold} bytes (~${floor(each.value.threshold / 1000000)} MB). Severity: ${each.value.alert_name_suffix}. Window: Maximum over PT5M, evaluated every PT1M."
```

**Line**: 107 (current) → 107 (no line shift)

### Rendered output after change

| Alert | Rendered description |
|-------|----------------------|
| warning (threshold=400000000) | `Alert fires when any Service Bus topic (EntityName) size exceeds 400000000 bytes (~400 MB). Severity: warning. Window: Maximum over PT5M, evaluated every PT1M.` |
| critical (threshold=800000000) | `Alert fires when any Service Bus topic (EntityName) size exceeds 800000000 bytes (~800 MB). Severity: critical. Window: Maximum over PT5M, evaluated every PT1M.` |

### Verification
```bash
# After terraform apply, confirm description in Azure Portal:
az monitor metrics alert show \
  --name mcdta-vpp-sb-vpp-sbus-d-topic-size-d-warning \
  --resource-group mcdta-rg-vpp-d-mon \
  --query 'description' --output tsv

# Expected output contains: "400000000 bytes (~400 MB)"
```

---

## Change 2 — Scope dev out of Rootly paging (REQUIRED, team decision on acc)

### What & Why

The current ternary at lines 125–132 has two branches: `environmentShort == "p"` (production, adds
OpsGenie) and everything-else (dev + acc, same action groups). "Everything-else" currently includes
`data.azurerm_monitor_action_group.team["trade-platform"]`, which carries the Rootly webhook.
This means dev topic size breaches page on-call via Rootly — identical to production.

The fix introduces a three-branch pattern (consistent with the existing OpsGenie/production pattern
already in the file): production gets OpsGenie + Rootly; acc gets Rootly; dev gets Slack only.

**Note on acc**: This PR recommends also removing Rootly from acc, aligning with the principle that
only production environments page on-call engineers. If the team decides acc should retain Rootly
paging, use the two-branch variant (Option B-alt) shown below.

### Exact diff — Option B (recommended: dev + acc Slack-only, prd Rootly+OpsGenie)

**File**: `terraform/metric-alert-service-bus.tf`

```diff
-  action_group_ids = var.environmentShort == "p" ? [
-    azurerm_monitor_action_group.main.id, module.actiongroup_service_bus_topic_size.action_group_id,
-    module.actiongroup_opsgenie.action_group_id,
-    data.azurerm_monitor_action_group.team["trade-platform"].id
-    ] : [
-    azurerm_monitor_action_group.main.id, module.actiongroup_service_bus_topic_size.action_group_id,
-    data.azurerm_monitor_action_group.team["trade-platform"].id
-  ]
+  action_group_ids = (
+    var.environmentShort == "p" ? [
+      azurerm_monitor_action_group.main.id,
+      module.actiongroup_service_bus_topic_size.action_group_id,
+      module.actiongroup_opsgenie.action_group_id,
+      data.azurerm_monitor_action_group.team["trade-platform"].id,
+    ] :
+    var.environmentShort == "a" ? [
+      azurerm_monitor_action_group.main.id,
+      module.actiongroup_service_bus_topic_size.action_group_id,
+      data.azurerm_monitor_action_group.team["trade-platform"].id,
+    ] :
+    [
+      azurerm_monitor_action_group.main.id,
+      module.actiongroup_service_bus_topic_size.action_group_id,
+    ]
+  )
```

**Lines**: 125–132 (current) → 125–140 (after, 8 lines → 18 lines)

### Option B-alt (keep acc paging Rootly — two-branch, no acc change)

If the team decides acc should retain Rootly paging, use this instead:

```diff
-  action_group_ids = var.environmentShort == "p" ? [
-    azurerm_monitor_action_group.main.id, module.actiongroup_service_bus_topic_size.action_group_id,
-    module.actiongroup_opsgenie.action_group_id,
-    data.azurerm_monitor_action_group.team["trade-platform"].id
-    ] : [
-    azurerm_monitor_action_group.main.id, module.actiongroup_service_bus_topic_size.action_group_id,
-    data.azurerm_monitor_action_group.team["trade-platform"].id
-  ]
+  action_group_ids = var.environmentShort == "p" ? [
+    azurerm_monitor_action_group.main.id,
+    module.actiongroup_service_bus_topic_size.action_group_id,
+    module.actiongroup_opsgenie.action_group_id,
+    data.azurerm_monitor_action_group.team["trade-platform"].id,
+  ] : var.environmentShort == "d" ? [
+    azurerm_monitor_action_group.main.id,
+    module.actiongroup_service_bus_topic_size.action_group_id,
+  ] : [
+    azurerm_monitor_action_group.main.id,
+    module.actiongroup_service_bus_topic_size.action_group_id,
+    data.azurerm_monitor_action_group.team["trade-platform"].id,
+  ]
```

### Verification
```bash
# After apply on dev, confirm trade-platform AG is NOT in the alert action groups:
az monitor metrics alert show \
  --name mcdta-vpp-sb-vpp-sbus-d-topic-size-d-warning \
  --resource-group mcdta-rg-vpp-d-mon \
  --query 'actions[].actionGroupId' --output tsv

# Expected: no line containing "ag-trade-platform-d"
# Confirm Slack AG is still present:
# Expected: line containing "eneco-vpp-service-bus-topic-size-actiongroup"
```

---

## Change 3 — Fix `for_each` key (OPTIONAL but STRONGLY RECOMMENDED, requires state migration)

### What & Why

The `for_each` at line 101 maps `c.severity_level => c`, using the numeric severity level
(e.g., `2` for warning, `0` for critical) as the Terraform resource key. This has two problems:

1. **Collision risk**: If two entries in `servicebus_topic_size_alerts` share the same
   `severity_level`, Terraform errors at plan time with a duplicate key error. This is a latent
   defect — the current variable values happen to have unique severity levels, but the data
   structure does not enforce this.

2. **Readability**: Terraform state and plan output shows resource addresses as
   `module.maxtopicsize_list["2"]` and `module.maxtopicsize_list["0"]`, which are opaque without
   knowing the severity scale. Using `alert_name_suffix` yields
   `module.maxtopicsize_list["warning"]` and `module.maxtopicsize_list["critical"]` — self-
   documenting.

**Why this requires state migration**: Changing the `for_each` key changes the Terraform resource
address. Without a state migration, `terraform plan` will show the existing resources as `destroy`
+ `create` (recreate), which momentarily deletes and recreates the Azure metric alerts. This is
safe (no data loss, no metric history loss) but causes a brief gap in alerting.

The state migration (`terraform state mv`) renames the resources in Terraform state without
touching Azure — no Azure API calls, no alert recreation.

### Exact diff

**File**: `terraform/metric-alert-service-bus.tf`

```diff
- for_each = { for c in var.servicebus_topic_size_alerts : c.severity_level => c }
+ for_each = { for c in var.servicebus_topic_size_alerts : c.alert_name_suffix => c }
```

**Line**: 101

### State migration steps (run per environment before `terraform apply`)

```bash
# 1. Init backend for target environment (example: dev)
terraform init -backend-config=configuration/dev.backend.config

# 2. Select dev workspace if applicable
terraform workspace select dev   # or: select default if not using workspaces

# 3. Rename warning alert in state (severity_level=2 → alert_name_suffix=warning)
terraform state mv \
  'module.maxtopicsize_list["2"]' \
  'module.maxtopicsize_list["warning"]'

# 4. Rename critical alert in state (severity_level=0 → alert_name_suffix=critical)
terraform state mv \
  'module.maxtopicsize_list["0"]' \
  'module.maxtopicsize_list["critical"]'

# 5. Verify: terraform plan must show 0 destroy, 0 create for these resources
#    (only in-place updates for description change from Change 1)
terraform plan -var-file=configuration/dev.tfvars -var-file=configuration/dev-alerts.tfvars \
  | grep -A2 "maxtopicsize_list"

# Repeat steps 1-5 for acc and prd environments before applying to each.
```

### Verification after state migration
```bash
# Confirm new state keys exist and old ones are gone:
terraform state list | grep maxtopicsize_list
# Expected:
# module.maxtopicsize_list["warning"]
# module.maxtopicsize_list["critical"]
# (no "0" or "2" entries)
```

---

## Full File State After All 3 Changes

The complete resulting block at `terraform/metric-alert-service-bus.tf:99–135` after applying
Changes 1, 2, and 3:

```hcl
// Servicebus topic size alerts
module "maxtopicsize_list" {
  for_each = { for c in var.servicebus_topic_size_alerts : c.alert_name_suffix => c }
  source   = "git::https://enecomanagedcloud@dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/Eneco.Infrastructure//terraform/modules/monitor_metric_alert?ref=v1.0.0"

  monitor_metric_alert_name = "${var.prefix}-${var.project}-sb-${module.ns.servicebus_name}-topic-size-${var.environmentShort}-${each.value.alert_name_suffix}"
  resource_group_name       = module.rg-monitoring.resource_group_name
  scopes                    = module.ns.servicebus_id
  description               = "Alert fires when any Service Bus topic (EntityName) size exceeds ${each.value.threshold} bytes (~${floor(each.value.threshold / 1000000)} MB). Severity: ${each.value.alert_name_suffix}. Window: Maximum over PT5M, evaluated every PT1M."
  severity                  = each.value.severity_level
  criteria = [{
    metric_namespace = "Microsoft.ServiceBus/Namespaces"
    metric_name      = "Size"
    operator         = "GreaterThan"
    aggregation      = "Maximum"
    threshold        = each.value.threshold
  }]
  dimension = [
    {
      name     = "EntityName"
      operator = "Include"
      values = [
        "*"
      ]
    }
  ]
  action_group_ids = (
    var.environmentShort == "p" ? [
      azurerm_monitor_action_group.main.id,
      module.actiongroup_service_bus_topic_size.action_group_id,
      module.actiongroup_opsgenie.action_group_id,
      data.azurerm_monitor_action_group.team["trade-platform"].id,
    ] :
    var.environmentShort == "a" ? [
      azurerm_monitor_action_group.main.id,
      module.actiongroup_service_bus_topic_size.action_group_id,
      data.azurerm_monitor_action_group.team["trade-platform"].id,
    ] :
    [
      azurerm_monitor_action_group.main.id,
      module.actiongroup_service_bus_topic_size.action_group_id,
    ]
  )

  tags = merge(var.tags_default, var.tags_purpose_vpp_core_shared)
}
```

---

## PR Description Template (paste into Azure DevOps PR body)

```markdown
## Summary

Fine-tunes the Service Bus topic size metric alert to fix a description unit bug and
remove dev-environment Rootly paging. No changes to alert threshold, operator,
aggregation, evaluation frequency, or dimension filter. Alert firing behavior is
unchanged.

## Changes

### Change 1 — Description fix (all environments)
- **File**: `terraform/metric-alert-service-bus.tf:107`
- **Problem**: Template renders `"400000000Mb"` — raw bytes concatenated with "Mb" suffix
  reads as 400 million megabytes (~381 PB). Misleads every incident responder.
- **Fix**: Renders bytes value + approximate MB conversion + evaluation context.
- **Risk**: Metadata-only, in-place update, zero functional impact.

### Change 2 — Dev Rootly routing removed (dev environment)
- **File**: `terraform/metric-alert-service-bus.tf:125–140`
- **Problem**: All non-production environments include `ag-trade-platform-d` (Rootly webhook),
  meaning dev topic size breaches page on-call engineers identically to production.
- **Fix**: Three-branch ternary: prd = OpsGenie+Rootly+Slack, acc = Rootly+Slack, dev = Slack only.
- **Risk**: Routing change — dev alerts no longer create Rootly incidents. Slack notification
  preserved. Requires team confirmation that dev should not page Rootly.

### Change 3 — `for_each` key fix (all environments, state migration required)
- **File**: `terraform/metric-alert-service-bus.tf:101`
- **Problem**: `c.severity_level` as map key is collision-prone and produces opaque resource
  addresses (`["2"]`, `["0"]`).
- **Fix**: `c.alert_name_suffix` as key — semantically unique, human-readable (`["warning"]`,
  `["critical"]`).
- **State migration**: Run `terraform state mv` per environment before apply (see PR spec doc).

## Testing

- [ ] `terraform validate` passes on all three environments
- [ ] `terraform plan` shows 0 destroy/create for alerts (in-place updates only) after state mv
- [ ] After apply on dev: `az monitor metrics alert show` confirms description contains "bytes"
- [ ] After apply on dev: action groups list does NOT include `ag-trade-platform-d`
- [ ] After apply on prd: action groups list STILL includes `ag-trade-platform-d` and OpsGenie

## References
- Incident analysis: `log/employer/eneco/00_incident_sre/01_alert_service_bus_topic_size_warning/`
- Alert JSON: `alert-json-view.json`
- Analysis: `01_analysis-alert.md`
- Proposal: `03_proposal.md`
```

---

## Step-by-Step Execution Guide

Follow these steps in order. Each step has a verification command — do not proceed until it passes.

### Step 0 — Prerequisites

```bash
# Confirm you are in the correct repository
git remote -v | grep MC-VPP-Infrastructure

# Confirm Terraform CLI is available
terraform version

# Confirm Azure CLI is authenticated to the correct subscription
az account show --query '{name:name, id:id}' --output table
# Expected subscription: 839af51e-c8dd-4bd2-944b-a7799eb2e1e4 (dev) or equivalent per env
```

### Step 1 — Create branch

```bash
git checkout main
git pull origin main
git checkout -b fix/service-bus-alert-description-and-env-routing
```

### Step 2 — Apply Change 1 (description fix)

Edit `terraform/metric-alert-service-bus.tf` line 107:

**Before**:
```hcl
  description = "Action will be triggered when any topic exceeds size of ${each.value.threshold}Mb"
```

**After**:
```hcl
  description = "Alert fires when any Service Bus topic (EntityName) size exceeds ${each.value.threshold} bytes (~${floor(each.value.threshold / 1000000)} MB). Severity: ${each.value.alert_name_suffix}. Window: Maximum over PT5M, evaluated every PT1M."
```

Verify the file is syntactically valid:
```bash
terraform validate
# Expected: Success! The configuration is valid.
```

### Step 3 — Apply Change 2 (action group routing)

Edit `terraform/metric-alert-service-bus.tf` lines 125–132. Replace the two-branch ternary with
the three-branch version from the diff above (Option B or Option B-alt depending on team decision).

Verify:
```bash
terraform validate
# Expected: Success!
```

### Step 4 — Apply Change 3 (for_each key — OPTIONAL)

Edit `terraform/metric-alert-service-bus.tf` line 101:

**Before**: `for_each = { for c in var.servicebus_topic_size_alerts : c.severity_level => c }`
**After**:  `for_each = { for c in var.servicebus_topic_size_alerts : c.alert_name_suffix => c }`

If skipping Change 3, proceed to Step 5 directly.

### Step 5 — Terraform plan (dev)

```bash
# Authenticate to dev environment
enecotfvppmclogindev

# Init
terraform init -backend-config=configuration/dev.backend.config

# If applying Change 3: run state migration FIRST (before plan)
terraform state mv 'module.maxtopicsize_list["2"]' 'module.maxtopicsize_list["warning"]'
terraform state mv 'module.maxtopicsize_list["0"]' 'module.maxtopicsize_list["critical"]'

# Plan
terraform plan \
  -var-file=configuration/dev.tfvars \
  -var-file=configuration/dev-alerts.tfvars \
  -out=tfplan-dev

# Review plan output:
# - module.maxtopicsize_list["warning"] and ["critical"] should show ~ (update in-place)
# - No resource should show + (create) or - (destroy)
# - description field change should be visible
# - action_group_ids change should be visible (trade-platform removed for dev)
```

### Step 6 — Apply to dev

```bash
terraform apply tfplan-dev

# Verify description change:
az monitor metrics alert show \
  --name mcdta-vpp-sb-vpp-sbus-d-topic-size-d-warning \
  --resource-group mcdta-rg-vpp-d-mon \
  --query 'description' --output tsv
# Expected: "Alert fires when any Service Bus topic (EntityName) size exceeds 400000000 bytes (~400 MB)..."

# Verify action groups (trade-platform should NOT appear for dev):
az monitor metrics alert show \
  --name mcdta-vpp-sb-vpp-sbus-d-topic-size-d-warning \
  --resource-group mcdta-rg-vpp-d-mon \
  --query 'actions[].actionGroupId' --output tsv
# Expected: NO line containing "ag-trade-platform-d"
```

### Step 7 — Commit and push

```bash
git add terraform/metric-alert-service-bus.tf
git commit -m "fix(monitoring): fix SB topic-size alert description unit bug and scope dev routing

- Fix description template: raw threshold bytes + 'Mb' rendered as '400000000Mb'
  (reads as 381 petabytes). Corrected to show bytes + approximate MB conversion.
- Scope dev out of Rootly paging: add three-branch env ternary so dev alerts
  go to Slack only; acc gets Rootly+Slack; prd retains OpsGenie+Rootly+Slack.
- Fix for_each key: severity_level => alert_name_suffix (collision-proof,
  human-readable resource addresses; requires terraform state mv per env).

Refs: 00_incident_sre/01_alert_service_bus_topic_size_warning/"

git push origin fix/service-bus-alert-description-and-env-routing
```

### Step 8 — Create PR in Azure DevOps

1. Navigate to the MC-VPP-Infrastructure repository in Azure DevOps
2. Create a Pull Request from `fix/service-bus-alert-description-and-env-routing` → `main`
3. Use the PR title and description template from the section above
4. Add reviewers: IaC team lead + on-call rotation lead
5. Add labels: `monitoring`, `bugfix`, `alerting`, `no-functional-change`

### Step 9 — Post-merge: apply to acc and prd

After PR merges, apply to remaining environments using the same state migration + plan + apply
sequence from Steps 5–6, substituting `acc` or `prd` credentials and tfvars.

```bash
# acc
enecotfvppmcloginacc
terraform init -backend-config=configuration/acc.backend.config
terraform state mv 'module.maxtopicsize_list["2"]' 'module.maxtopicsize_list["warning"]'  # if Change 3
terraform state mv 'module.maxtopicsize_list["0"]' 'module.maxtopicsize_list["critical"]' # if Change 3
terraform plan -var-file=configuration/acc.tfvars -var-file=configuration/acc-alerts.tfvars -out=tfplan-acc
terraform apply tfplan-acc

# prd — CONFIRM WITH TEAM BEFORE APPLYING
enecotfvppmcloginprd
terraform init -backend-config=configuration/prd.backend.config
terraform state mv 'module.maxtopicsize_list["2"]' 'module.maxtopicsize_list["warning"]'  # if Change 3
terraform state mv 'module.maxtopicsize_list["0"]' 'module.maxtopicsize_list["critical"]' # if Change 3
terraform plan -var-file=configuration/prd.tfvars -var-file=configuration/prd-alerts.tfvars -out=tfplan-prd
terraform apply tfplan-prd
```

---

## Rollback

If any apply must be reverted:

```bash
# Option A — git revert + re-apply (safest, preferred)
git revert <merge-commit-sha>
# Then re-run terraform init + state mv (reverse direction) + plan + apply per env

# Option B — manual state restoration (if only state migration was run, no apply)
# Reverse the state mv:
terraform state mv 'module.maxtopicsize_list["warning"]' 'module.maxtopicsize_list["2"]'
terraform state mv 'module.maxtopicsize_list["critical"]' 'module.maxtopicsize_list["0"]'
# Then revert the file change and re-apply
```

---

## Acceptance Criteria

This PR is complete when ALL of the following are true:

- [ ] `terraform validate` passes on dev, acc, prd
- [ ] `terraform plan` shows in-place updates only (0 destroy, 0 create) for `maxtopicsize_list` resources in all environments after state migration
- [ ] Dev environment alert description contains `"bytes (~400 MB)"` — verified via `az CLI`
- [ ] Dev environment alert action groups do NOT include `ag-trade-platform-d` — verified via `az CLI`
- [ ] Prd environment alert action groups STILL include `ag-trade-platform-d` and OpsGenie — verified via `az CLI`
- [ ] Terraform state list shows `module.maxtopicsize_list["warning"]` and `["critical"]` (not `["2"]` and `["0"]`) — if Change 3 applied
- [ ] PR reviewed and approved by IaC team lead
- [ ] Team decision documented in PR: does acc retain Rootly? (Option B vs Option B-alt)
