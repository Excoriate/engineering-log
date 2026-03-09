---
task_id: 2026-03-09-001
agent: coordinator
status: complete
summary: IaC source code facts for Service Bus alert Terraform module
---

# IaC Code Facts

## module "maxtopicsize_list" — metric-alert-service-bus.tf:100-135
```hcl
module "maxtopicsize_list" {
  for_each = { for c in var.servicebus_topic_size_alerts : c.severity_level => c }
  source   = "...monitor_metric_alert?ref=v1.0.0"

  monitor_metric_alert_name = "${prefix}-${project}-sb-${servicebus_name}-topic-size-${envShort}-${each.value.alert_name_suffix}"
  description = "Action will be triggered when any topic exceeds size of ${each.value.threshold}Mb"  // BUG: unit
  severity    = each.value.severity_level
  criteria = [{
    metric_namespace = "Microsoft.ServiceBus/Namespaces"
    metric_name      = "Size"
    operator         = "GreaterThan"
    aggregation      = "Maximum"
    threshold        = each.value.threshold
  }]
  dimension = [{ name = "EntityName", operator = "Include", values = ["*"] }]
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
}
```

## variable "servicebus_topic_size_alerts" — variables.tf:748-754
```hcl
variable "servicebus_topic_size_alerts" {
  type = list(object({
    alert_name_suffix = string
    severity_level    = number
    threshold         = number
  }))
}
// NO DEFAULT VALUE — must be supplied via tfvars
```

## Threshold Values — dev.tfvars:54-65 (identical in prd.tfvars:51-62)
```hcl
servicebus_topic_size_alerts = [
  { alert_name_suffix = "warning",  severity_level = 2, threshold = 400000000 },  // #400MB
  { alert_name_suffix = "critical", severity_level = 0, threshold = 800000000 },  // #800MB
]
```

## actiongroup_service_bus_topic_size — actiongroup.tf:46-58
```hcl
module "actiongroup_service_bus_topic_size" {
  monitor_action_group_name       = "eneco-${project}-service-bus-topic-size-actiongroup"
  monitor_action_group_short_name = "${project}slack${environmentShort}"
  webhook_receiver = [{ name = "Slack", use_common_alert_schema = true }]
  webhook_receiver_service_uri = azurerm_logic_app_trigger_http_request...callback_url
}
// Sends to Slack via Logic App trigger
```

## Namespace — servicebus-mc-lz.tf:8
```hcl
servicebus_namespace_name = format("%s-sbus-%s", var.project, var.environmentShort)
// dev: vpp-sbus-d | prd: vpp-sbus-p
```

## Key Findings from Code Review
1. Description template BUG: `${each.value.threshold}Mb` where threshold=400000000 (bytes) → "400000000Mb"
2. for_each key is severity_level (0 or 2) — creating 2 alerts per environment
3. OpsGenie only added in production (env == "p")
4. trade-platform action group is a DATA source (external, not managed here):
   `data.azurerm_monitor_action_group.team["trade-platform"]`
   → contains rootly-trade-platform webhook
5. No alerting for windowSize/evaluationFrequency mismatch — these are set in the module
6. No acc-alerts.tfvars entries for this variable — acc uses different file structure
