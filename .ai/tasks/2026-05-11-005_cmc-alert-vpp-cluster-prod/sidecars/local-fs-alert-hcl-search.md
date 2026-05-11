---
task_id: 2026-05-11-005
agent: codebase-locator
timestamp: 2026-05-11T16:05:00+00:00
status: complete

summary: |
  VERDICT: NOT FOUND. Exhaustive literal + case-insensitive search across the entire
  /Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src/ tree (4 root areas, 100+ sub-repos,
  all requested file types) finds ZERO references to the Azure alert `vpp-resource-unhealthy`
  or any of its naming variants (snake_case, substring `resource-unhealthy`/`resource_unhealthy`/
  `ResourceUnhealthy`). The Log Analytics workspace `vpp-log-analyt-p` is also not referenced
  anywhere in the local IaC. The resource group `mcprd-rg-vpp-p-res` is heavily referenced —
  but always as scope for OTHER resources (KeyVault, AppInsights, AppConfig, App Gateway),
  never co-located with `*unhealthy*`. The dedicated scheduled-query module is `Eneco.Infrastructure/
  terraform/modules/monitor_scheduled_query_rules_alert_V2`, and the only consumer in
  `MC-VPP-Infrastructure/main/terraform/monitor_metric_query_alert.tf` builds alert names with the
  pattern `<prefix>-<project>-<key>-healthevent-<env>` — NOT `vpp-resource-unhealthy`. Conclusion:
  this alert is created out-of-band (Azure portal, deleted commit, remote-only repo, or non-local tooling).
---

# Local FS Search: `vpp-resource-unhealthy` Across Eneco Source Tree

## Verdict

**NOT FOUND** (HIGH confidence)

## Key Findings

- pattern_1_vpp_resource_unhealthy_hyphen: ZERO matches across all *.tf *.tfvars *.hcl *.yaml *.yml *.json *.md *.tpl *.tmpl *.bicep
- pattern_2_vpp_resource_unhealthy_snake: ZERO matches
- pattern_3_resource_dash_unhealthy_substring: ZERO matches
- pattern_4_resource_underscore_unhealthy_substring: ZERO matches
- pattern_5_vpp_log_analyt_p_workspace_name: ZERO matches (no IaC for this workspace in local tree)
- pattern_6_resource_group_mcprd_rg_vpp_p_res: many matches but ALL for OTHER azure resources, never co-located with *unhealthy*
- pattern_7_microsoft_insights_scheduledqueryrules_resource_type: only 1 file, a generated `tfplan-dev.json` (not source IaC defining this alert)
- pattern_8_9_scheduled_query_rules_alert_resource: many files; canonical module is `Eneco.Infrastructure/terraform/modules/monitor_scheduled_query_rules_alert_V2`; consumer `MC-VPP-Infrastructure/main/terraform/monitor_metric_query_alert.tf` builds alert names as `<prefix>-<project>-<key>-healthevent-<env>`, which does NOT match `vpp-resource-unhealthy`
- final_exhaustive_case_insensitive_full_tree: ZERO matches for ResourceUnhealthy / resource-unhealthy / resource_unhealthy anywhere in eneco-src (no file-type filter)
- servicenow_integration_scripts_renaming_alerts: no Eneco-internal ServiceNow integration scripts found that could rename Azure alerts to `vpp-resource-unhealthy` at intake time
- bicep_arm_templates: no .bicep files found in tree; no ARM templates other than tfplan outputs match the alert resource type
- helm_argocd_path_user_called_out: `eneco-temp/Myriad - VPP/azure-pipeline/Helm/` URL-encoded as `Myriad%20-%20VPP` exists; probed for `unhealthy`, no matches relevant to alert name
- prometheus_alertmanager_observability_trees: probed VPP-Configuration/alertmanager, eneco-vpp-alerting, ocp-prometheus-alerting, Eneco.Vpp.Observability.OpenTelemetry, VPP.GitOps/vpp-agg-monitoring — ZERO matches for any variant
- rg_gitignore_parser_warning: one non-fatal warning on `github-org-eneco/sre-tf-github-teams/.gitignore` line 37 (dangling backslash). Ripgrep falls back to default ignore rules for that one file; scanning continues. Not a search failure.

## Verdict Detail

The Azure scheduled-query alert `vpp-resource-unhealthy` (resource type `Microsoft.Insights/scheduledQueryRules`, RG `mcprd-rg-vpp-p-res`, workspace `vpp-log-analyt-p`) **does not exist** in any form in the local Eneco source tree at `/Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src/`.

Probable explanations (in order of likelihood, NOT verified by this sidecar):

1. Alert was created out-of-band directly in Azure Portal (no IaC source of record).
2. Alert lives in a remote Azure DevOps / GitHub repo not present in this local clone set.
3. Alert was defined in a branch / commit that is not currently checked out or has been deleted.
4. Alert is managed by a Microsoft-managed automation (Defender, Resource Health auto-rules) outside Eneco IaC.

## Search Methodology — Exhaustion Gate Passed

| Strategy | Probe | Result |
|---|---|---|
| 1. Name-based literal | `rg 'vpp-resource-unhealthy'` across 10 file types | 0 matches |
| 2. Snake-case literal | `rg 'vpp_resource_unhealthy'` | 0 matches |
| 3. Hyphen substring | `rg -l 'resource-unhealthy'` | 0 matches |
| 4. Underscore substring | `rg -l 'resource_unhealthy'` | 0 matches |
| 5. Workspace literal | `rg 'vpp-log-analyt-p'` | 0 matches |
| 6. Resource group literal | `rg 'mcprd-rg-vpp-p-res'` | many matches, all for OTHER resources |
| 7. Resource type literal | `rg 'Microsoft.Insights/scheduledQueryRules'` | 1 file (generated tfplan-dev.json, not source) |
| 8. Terraform resource | `rg 'scheduled_query_rules_alert'` | module + consumers found; naming convention `*-healthevent-*` not `*-resource-unhealthy` |
| 9. Generic `unhealthy` | `rg 'unhealthy'` myriad-vpp tree | all matches are App Gateway `unhealthy_threshold` / `UnhealthyHostCount` |
| 10. Permissive regex | `rg -i 'resource[-_ ]?unhealthy'` whole tree, no file-type filter | 0 matches |
| 11. Exact name attribute | `rg -i 'name\s*=\s*"[^"]*unhealthy[^"]*"'` | 0 matches in tf files |
| 12. ServiceNow renaming | `rg -i -e 'servicenow' -e 'service[-_]?now'` | found rootly integration only; no SNow renamer scripts |

**Coverage**: HIGH. Searched 4 top-level roots (`eneco-temp/`, `enecomanagedcloud/`, `eneco-engineering-docs/`, `github-org-eneco/`) covering 100+ sub-repos. Both URL-encoded (`Myriad%20-%20VPP`) and decoded (`Myriad - VPP`) path variants probed.

**Naming variations**: HIGH. Tried hyphen, underscore, mixed case, with-prefix `vpp-`, without prefix, plus permissive regex with optional separator.

**Negative confidence**: HIGH. Three independent strategies (literal, regex, attribute-scoped) all returned zero. The naming convention discovered in canonical alert tf (`*-healthevent-*`) is structurally different from `vpp-resource-unhealthy`.

## Key Architectural Finding — Naming Convention Mismatch

`enecomanagedcloud/myriad-vpp/MC-VPP-Infrastructure/main/terraform/monitor_metric_query_alert.tf` (29 lines, A1 FACT):

```hcl
module "monitor_query_rules_alert" {
  source = "git::https://enecomanagedcloud@dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/Eneco.Infrastructure//terraform/modules/monitor_scheduled_query_rules_alert_V2?ref=v2.1.0"
  for_each             = var.monitor_query_rules_alert
  name                 = "${var.prefix}-${var.project}-${each.key}-healthevent-${var.environmentShort}"
  ...
  display_name         = "${var.prefix}-${var.project}-${each.key}-healthevent-${var.environmentShort}"
  ...
}
```

Every alert produced by this canonical module ends in `-healthevent-<env>` (e.g. `vpp-core-<key>-healthevent-p`). The fired alert name `vpp-resource-unhealthy` violates this pattern. **A2 INFER**: either the alert comes from a DIFFERENT terraform module than this one, or it was created without IaC.

## Match Table — Patterns Returning Hits (None Match the Target Alert)

### Pattern 6: `mcprd-rg-vpp-p-res` (resource group) — used by OTHER resources

| File | Lines | Used For | Match Type |
|---|---|---|---|
| `eneco-temp/Myriad%20-%20VPP/azure-pipeline/pipelines/appconfiguration/production.pipeline.yml` | 21-22 | AppConfiguration | A1 reference (unrelated) |
| `eneco-temp/FleetOptimizer/azure-pipeline/appconfiguration/production.pipeline.yaml` | 21-22 | AppConfiguration | A1 reference (unrelated) |
| `enecomanagedcloud/myriad-vpp/Eneco.Vpp.Aggregation.Infrastructure.Mc/terraform/env/mcc-prd/mcc-prd-alerts.tfvars` | 770, 774 | KeyVault ResourceHealth alert (`kvHealth`) | A1 reference (different alert) |
| `enecomanagedcloud/myriad-vpp/MC-VPP-Infrastructure/ootw-rootly-alert-sqlserver-a/terraform/dashboard-*.tpl` | multiple | App Insights dashboards | A1 reference (unrelated) |
| `eneco-temp/platform-documentation/internal/How-To-Guides/Certificates/tls-certificates-renewal.md` | 30-31 | KeyVault + App Gateway URLs | A1 documentation (unrelated) |

### Pattern 8/9: `scheduled_query_rules_alert` resource — canonical module locations

| File | Role | Confidence |
|---|---|---|
| `eneco-temp/Eneco.Infrastructure/terraform/modules/monitor_scheduled_query_rules_alert/main.tf` | Module v1 definition | A1 FACT |
| `eneco-temp/Eneco.Infrastructure/terraform/modules/monitor_scheduled_query_rules_alert_V2/main.tf` | Module v2 definition | A1 FACT |
| `enecomanagedcloud/myriad-vpp/Eneco.Infrastructure/{branches}/terraform/modules/monitor_scheduled_query_rules_alert_V2/main.tf` | Module v2 in subtree branches | A1 FACT |
| `enecomanagedcloud/myriad-vpp/MC-VPP-Infrastructure/{branches}/terraform/monitor_metric_query_alert.tf` | Module CONSUMER; produces `*-healthevent-*` names | A1 FACT — name pattern does NOT match target |
| `enecomanagedcloud/mcc-landing-zone/cmc-azure-landingzone/479_esp-p-workload/template/alerts.tf` | ESP Kafka consumer of `azurerm_monitor_scheduled_query_rules_alert_v2`; names are `Failed_ESP_Connector_*` | A1 FACT — naming unrelated |

### Pattern: `unhealthy` (case-insensitive) anywhere in myriad-vpp

All matches are one of:

- App Gateway `unhealthy_threshold = 3` (backend probe config)
- App Gateway `metric_name = "UnhealthyHostCount"` (metric alert criterion)
- App Gateway alert key `unhealthy-backend-endpoint-app-gateway`

None match the alert name `vpp-resource-unhealthy`. A2 INFER: the fired alert is not the App Gateway unhealthy-backend metric alert either (different name shape, different resource type).

## Negative Findings — Conspicuous Absences

- **No `.bicep` files** found anywhere in eneco-src tree.
- **No ARM templates** matching `Microsoft.Insights/scheduledQueryRules` other than one generated terraform plan output.
- **No ServiceNow integration scripts** that would rename Azure alert names at intake time.
- **No Container Insights** YAML or `azure-monitor-agent` config referencing this alert.
- **No Helm `PrometheusRule`** CRD with this alert name (probed `ocp-prometheus-alerting`, `eneco-vpp-alerting`, `alertmanager`, `eneco-vpp-telemetry`).
- **No ArgoCD Application manifest** referencing this alert.

## Tool Notes

- ripgrep 15.1.0 at `/opt/homebrew/bin/rg`
- Cosmetic warning on `github-org-eneco/sre-tf-github-teams/.gitignore` line 37 (`'terraform.rc\'` dangling backslash). Ripgrep skips that one `.gitignore` and uses default ignore rules; scanning of all other files proceeds normally. Verified by running probes both with and without the affected sub-repo — results identical.

## Recommended Next Steps for Parent Coordinator

1. **Pivot to remote Azure surface**: query Azure directly via `az monitor scheduled-query show` to fetch the raw alert rule definition (resource id already known from intake).
2. **Search Azure DevOps repos via API**: literal `vpp-resource-unhealthy` against ALL repos in `enecomanagedcloud/Myriad - VPP` project, not just locally cloned ones.
3. **Check Azure activity log** for the `Microsoft.Insights/scheduledQueryRules/write` operation against this resource id — that surfaces the principal that created/last-edited it (out-of-band human change vs CI pipeline service principal).
4. **Check the alert resource's tags** — most Eneco IaC injects a `managed-by`/`source-repo` tag.

## Confidence Classification

- **A1 FACT**: every `ZERO matches` claim is backed by a `rg` exit code + empty stdout output observed in this session.
- **A1 FACT**: naming-convention citation is from direct Read of `monitor_metric_query_alert.tf` lines 5 and 13.
- **A2 INFER**: "alert created out-of-band" inferences are derived from absence of literal matches across exhaustive strategies — falsifier = a remote repo or branch not in local clone set contains the definition; this sidecar cannot probe remote-only surfaces.
- **A3 UNVERIFIED[blocked: remote-repo-scope]**: cannot rule out the alert living in a non-locally-cloned Azure DevOps / GitHub repo. Parent coordinator should pursue remote-side probes.
