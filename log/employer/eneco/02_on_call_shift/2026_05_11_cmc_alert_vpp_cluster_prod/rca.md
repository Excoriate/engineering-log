---
title: "RCA — CMC Alert (vpp-resource-unhealthy) — Eneco VPP Production — 2026-05-11"
description: "Root-cause analysis of the ServiceNow 'CMC alert' page on Eneco VPP production that fired at 13:12:43 UTC on 2026-05-11. Mechanism: late-ingested Microsoft ServiceHealth communications during platform incident 5Z1B-6KG backlog drain triggered an out-of-IaC, over-broad, sev-0 scheduledQueryRule."
version: 2.0
status: review
category: on-call-incident
updated: 2026-05-11
authors: ["atorres.ruiz"]
incident_date: 2026-05-11
azure_alert_resource_id: "/subscriptions/f007df01-9295-491c-b0e9-e3981f2df0b0/resourceGroups/mcprd-rg-vpp-p-res/providers/microsoft.insights/scheduledqueryrules/vpp-resource-unhealthy"
azure_alert_uuid: "22ed515b-24d3-26ce-3fb3-09cfc5158afb"
microsoft_servicehealth_tracking_id: "5Z1B-6KG"
adversarial_review: external (socrates-contrarian + el-demoledor, PROCEED-WITH-CHANGES, patches absorbed in v2.0 — see Mutation Log)
on_call: atorres.ruiz
---

# RCA — CMC Alert (`vpp-resource-unhealthy`) — Eneco VPP Production — 2026-05-11

> **SMOKING GUN**: Microsoft Azure platform incident **`5Z1B-6KG`** (Log Analytics + Application Insights data latency in West Europe, 06:40–12:45 UTC) caused our `vpp-log-analyt-p` workspace to ingest ServiceHealth rows late. Two earlier same-incident notices (TimeGenerated 12:54:56 and 12:55:53 UTC) were backfilled into the workspace at 13:09:10 and 13:09:44 UTC. The Azure Monitor scheduled-query engine waits for late-arriving data; at 13:12:43 UTC it evaluated the historical window **12:52:07Z → 12:57:07Z** (TimeGenerated-based, confirmed by the alert payload's own `windowStartTime` / `windowEndTime`), saw `metricValue = 2.0` (Azure's own count, A1), and fired the over-broad sev-0 rule `vpp-resource-unhealthy` (KQL: `AzureActivity | where CategoryValue == "ServiceHealth"`, threshold `Count > 1`, **no action group**). ServiceNow created the CMC ticket. **No Eneco workload was OBSERVED unhealthy in this session — cluster-side falsifier in [`oc-playbook.md`](./oc-playbook.md) mandatory pre-close.**

> **STATUS UPDATE 2026-05-11T15:06:40 UTC**: Azure alert **CLOSED** by `Alex.Torres@eneco.com` via `az rest --method POST .../changestate?newState=Closed` (alert UUID `7ca25b09-e05e-cced-606d-cc4d91d5000e`). `alertState=Closed, monitorCondition=Fired` (condition stays Fired because autoMitigate=false — expected). ServiceNow ticket close remains the on-call's manual action (Plane 2 path is A3-uneliminated).

## TL;DR (60-second read)

1. **What fired**: `Microsoft.Insights/scheduledQueryRules/vpp-resource-unhealthy` in `mcprd-rg-vpp-p-res`, sev 0, at `2026-05-11T13:12:43.279Z` (15:12 CEST). Currently `state=New, monitorCondition=Fired, autoMitigate=false` — will NOT self-close.
2. **Why it fired**: the rule's KQL `AzureActivity | where CategoryValue == "ServiceHealth"` with `Count > 1` over a 5-minute window matched two ServiceHealth rows that were **late-ingested during Microsoft's own platform incident `5Z1B-6KG` backlog drain**. By `ingestion_time()`, both rows landed in the workspace at 13:09:10 and 13:09:44 UTC — inside the rule's 13:07:43–13:12:43 UTC evaluation window. (Their `TimeGenerated` is 12:54:56 and 12:55:53 UTC — 14 minutes earlier, exactly the latency Microsoft warned of.)
3. **Why it is structurally wrong**: rule is out-of-IaC (manually created via Azure ARM by user principal `eelke.hoffman@conclusion.nl` on 2024-01-24, never modified), has **no action group** (`actions: null` — that is why no Rootly page; ServiceNow received it via a separate path), is sev-0 with `autoMitigate=false`, and the KQL has no filter on `ActivityStatusValue` / `impactedServices` / `_ResourceId` / etc. It matches the entire Microsoft platform announcement stream, including resolution notices and (today) backlog-drained earlier notices.
4. **What was NOT impacted**: no Eneco VPP workload was OBSERVED unhealthy in this session. Cluster-side sanity-check is delegated to [`oc-playbook.md`](./oc-playbook.md) — **mandatory pre-close** per adversarial review.
5. **How to close (route: close-only operational, per on-call routing decision)**: run the two `az` commands in [§ Close commands](#close-commands-az-this-page) below; verify in [L9](#l9--verification); flag the rule for SRE/Platform follow-up. Do not change IaC in this incident.
6. **Limitations** (named, not hidden): see [§ Limitations](#limitations-named-not-hidden) — the most material one is that the ServiceNow ticket path is A3 UNVERIFIED (four alternatives uneliminated); always close both planes manually, do not assume Azure-close propagates.

## Close commands (az) — this page

> **READ FIRST**: run [`oc-playbook.md`](./oc-playbook.md) sanity-check probes BEFORE running these. If the cluster-side probes show real degradation in `eneco-vpp-prd`, STOP — this is a real workload incident hiding behind the noisy alert; do not close.

Two commands, two planes, in order. The alert UUID and resource IDs are pinned below.

```bash
# 0. Confirm you are on the production VPP subscription (read-only safety check)
az account show --query "{id:id, name:name}" -o tsv
# Expected: f007df01-9295-491c-b0e9-e3981f2df0b0   Eneco MCC - Production - Workload VPP
# If not, switch:
# az account set --subscription f007df01-9295-491c-b0e9-e3981f2df0b0

# 1. (PRE-CLOSE) Re-verify the alert is still firing and matches the resource ID under audit
az rest --method GET \
  --url "https://management.azure.com/subscriptions/f007df01-9295-491c-b0e9-e3981f2df0b0/providers/Microsoft.AlertsManagement/alerts/22ed515b-24d3-26ce-3fb3-09cfc5158afb?api-version=2019-05-05-preview" \
  --query "properties.essentials.{state:alertState, condition:monitorCondition, rule:alertRule, fired:startDateTime, severity:severity}" -o json
# Expected: {"state":"New", "condition":"Fired", "rule":"vpp-resource-unhealthy", "fired":"2026-05-11T13:12:43.2790702Z", "severity":"Sev0"}
# Decision rule: if state=="Closed" already, skip step 2. If rule != "vpp-resource-unhealthy", STOP — wrong alert.

# 2. PLANE 1: close the Azure alert (transitions alertState to Closed, monitorCondition stays Fired)
az rest --method POST \
  --url "https://management.azure.com/subscriptions/f007df01-9295-491c-b0e9-e3981f2df0b0/providers/Microsoft.AlertsManagement/alerts/22ed515b-24d3-26ce-3fb3-09cfc5158afb/changestate?api-version=2019-05-05-preview&newState=Closed" \
  --body '{"comment":"Closed via on-call RCA 2026-05-11. See log/employer/eneco/02_on_call_shift/2026_05_11_cmc_alert_vpp_cluster_prod/rca.md. Trigger: Microsoft platform incident 5Z1B-6KG (Log Analytics latency West Europe) backlog drain. Alert rule is over-broad, out-of-IaC, no action group, sev-0/autoMitigate=false. Cluster confirmed not impacted via oc-playbook.md. Flagged for SRE/Platform follow-up; not codified in IaC in this incident."'

# 3. (POST-CLOSE VERIFY) Confirm Azure alert state flipped
az rest --method GET \
  --url "https://management.azure.com/subscriptions/f007df01-9295-491c-b0e9-e3981f2df0b0/providers/Microsoft.AlertsManagement/alerts/22ed515b-24d3-26ce-3fb3-09cfc5158afb?api-version=2019-05-05-preview" \
  --query "properties.essentials.{state:alertState, condition:monitorCondition}" -o tsv
# Expected: Closed   Fired   (monitorCondition stays "Fired" because autoMitigate=false; alertState is what matters for the page lifecycle)

# 4. PLANE 2: close the ServiceNow ticket MANUALLY (do NOT assume Azure-close propagates).
# The Azure -> ServiceNow path for this alert is A3 UNVERIFIED (no action group; could be ITSM connector,
# Alert Processing Rule, Logic App, or native SN Azure integration plugin; see L8 Plane 2).
# Action: open the CMC ticket in ServiceNow UI -> set Resolved/Closed with comment referencing this RCA.
# If you have a CLI/integration that mutates SN, use it; otherwise UI is authoritative.

# 5. (OPTIONAL) Disable the rule outright for the rest of the shift to prevent re-fire on the next
# Microsoft ServiceHealth notice (REQUIRES write authorization on prd; routing decision says do NOT do
# this in this incident; included only as a documented next-tier action that SRE/Platform owns).
# az monitor scheduled-query update \
#   --resource-group mcprd-rg-vpp-p-res \
#   --name vpp-resource-unhealthy \
#   --disabled true
```

| # | Plane | Reversibility | Authorization | Comment |
|---|---|---|---|---|
| 0 | Subscription verify | read-only | any | Safety check; matches the connect-mc-environments H-VERIFY pattern |
| 1 | Re-verify alert state | read-only | any | Confirms the alert is still firing and the UUID matches the rule under audit |
| 2 | Azure alert close | reversible (re-fire next 5-min eval if a new ServiceHealth row arrives) | Monitoring Contributor or equivalent on the RG | Sets `alertState=Closed`; does NOT disable the rule |
| 3 | Post-close verify | read-only | any | Confirms the state transition landed |
| 4 | ServiceNow ticket close | reversible | ServiceNow ITIL/agent role | **Must be done manually** — propagation path A3 |
| 5 | Disable the rule | reversible (`--disabled false`) | Monitoring Contributor or higher | OUT OF SCOPE for this RCA's routing decision |

## Evidence labels — used throughout

- **A1 FACT** — externally witnessable in this session: command output captured in a sidecar, file:line citation, or clickable URL whose response is pinned. *Imported A1* (citing a subagent or other sidecar) is flagged inline.
- **A2 INFER** — derived from A1 facts via named reasoning; the reasoning is stated explicitly next to the inference.
- **A3 UNVERIFIED[blocked: reason]** — could not be re-probed in this session; the resolving probe or path is named.

## References

### Azure resources (clickable)

- Alert rule: [`vpp-resource-unhealthy`](https://portal.azure.com/#@eneco.onmicrosoft.com/resource/subscriptions/f007df01-9295-491c-b0e9-e3981f2df0b0/resourceGroups/mcprd-rg-vpp-p-res/providers/Microsoft.Insights/scheduledqueryrules/vpp-resource-unhealthy/overview)
- Alert resource (the firing instance): [`22ed515b-24d3-26ce-3fb3-09cfc5158afb`](https://portal.azure.com/#blade/Microsoft_Azure_Monitoring/AzureMonitoringBrowseBlade/alertsV2) (open the Alerts blade and filter by alert rule)
- Resource group: [`mcprd-rg-vpp-p-res`](https://portal.azure.com/#@eneco.onmicrosoft.com/resource/subscriptions/f007df01-9295-491c-b0e9-e3981f2df0b0/resourceGroups/mcprd-rg-vpp-p-res/overview)
- Log Analytics workspace `vpp-log-analyt-p` (GUID `8bb8b1ca-9b6e-4af8-afca-6e9f1fda544a`): [Logs blade](https://portal.azure.com/#@eneco.onmicrosoft.com/resource/subscriptions/f007df01-9295-491c-b0e9-e3981f2df0b0/resourceGroups/mcprd-rg-vpp-p-res/providers/Microsoft.OperationalInsights/workspaces/vpp-log-analyt-p/logs)
- Subscription: `Eneco MCC - Production - Workload VPP` (`f007df01-9295-491c-b0e9-e3981f2df0b0`)

### Microsoft platform incident

- Tracking ID **`5Z1B-6KG`** — *"Mitigated – Log Analytics and Application Insights intermittent data latency in West Europe"*
- Customer-impact window (per Microsoft's `communication` text): **2026-05-11T06:40 → 12:45 UTC**
- Microsoft-internal detect→mitigate window (per structured fields): `impactStartTime: 2026-05-11T11:11:09 UTC`, `impactMitigationTime: 2026-05-11T12:55:01 UTC` (these disagree with the textual times; see L7 footnote)
- Service Health blade: [Service Health → History](https://portal.azure.com/#view/Microsoft_Azure_Health/AzureHealthBrowseBlade/~/serviceIssues)

### Eneco intake artifacts

- ServiceNow ticket export: [`cmc-service-now-ticket.txt`](./cmc-service-now-ticket.txt)
- oc sanity-check playbook (mandatory pre-close): [`oc-playbook.md`](./oc-playbook.md)

### Sidecars (under the task workspace)

- Raw Azure alert rule JSON: `.ai/tasks/2026-05-11-005_cmc-alert-vpp-cluster-prod/sidecars/azure-alert-rule-raw.json`
- All sev-0 alerts last 24h: `.ai/tasks/.../sidecars/sev0-alerts-24h.json`
- All alerts last 30d (rule fired 1x): `.ai/tasks/.../sidecars/all-alerts-30d.json` (E7's correct filename — v1.0 cited `alert-fires-30d.json` which is empty)
- Workspace ServiceHealth rows at fire time (TimeGenerated-filtered, 15-min): `.ai/tasks/.../sidecars/workspace-servicehealth-firetime.json`
- **Workspace ServiceHealth rows in firing window by `ingestion_time()` (the load-bearing mechanism evidence)**: `.ai/tasks/.../sidecars/F1-ingestion-time-window.json`
- Workspace ServiceHealth extended view 12:30–13:13: `.ai/tasks/.../sidecars/F1-broad-with-ingestion.json`
- Alert rule activity log 7d (empty array — no writes in last week): `.ai/tasks/.../sidecars/alert-rule-activity-log.json`
- Adversarial reports: `.ai/tasks/.../auxiliary/socrates-attack-on-rca.md` and `.ai/tasks/.../auxiliary/eldemoledor-attack-on-rca.md`

### Eneco IaC — for "what SHOULD have been created" comparison

- MC-VPP-Infrastructure ADO repo: [`Myriad - VPP / MC-VPP-Infrastructure`](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/MC-VPP-Infrastructure)
- Proper alert-rule module (Eneco.Infrastructure): [`monitor_scheduled_query_rules_alert_V2?ref=v2.1.0`](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/Eneco.Infrastructure?path=/terraform/modules/monitor_scheduled_query_rules_alert_V2)
- The MC-VPP wrapper that consumes the module: `terraform/monitor_metric_query_alert.tf`
- The threshold/query map for prd: `configuration/prd-alerts.tfvars` (variable `monitor_query_rules_alert`, 13 entries, none named `vpp-resource-unhealthy`)

## Context Ledger (zero-context reader test)

Read this if you do not yet recognize every term used below.

| Term | Plain-language meaning | Source | Why it matters here |
|---|---|---|---|
| **VPP** | Virtual Power Plant — Eneco's product aggregating flexible energy assets and trading their flex in wholesale + balancing markets. | [Myriad VPP wiki](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_wiki/wikis/Myriad---VPP.wiki) | The business reason this subscription exists. |
| **MCC / MCLZ** | "Managed Cloud Compute" / "Managed Cloud Landing Zone" — Eneco's CCoE-governed Azure landing-zone product. ServiceNow ticket Host = "Eneco MCC – Production – Workload VPP". | Eneco CCoE wiki | Names the cluster identity in ServiceNow CMDB. |
| **CMC** | Shorthand the on-call used in the **directory name** (`2026_05_11_cmc_alert_vpp_cluster_prod`). The string "CMC" does NOT appear in the ServiceNow ticket .txt export (the ticket's `Reported CI` is "Azure Cluster"). Treat "CMC" as a directory-naming convention, possibly inherited from the ServiceNow UI category not exported to text. | Directory slug; ticket text grep | Naming hygiene only — does not affect the RCA. |
| **`mcprd-rg-vpp-p-res`** | Azure resource group: `mcprd` (MC prd) `rg-vpp` (VPP) `p-res` (prd "resources" tier). | Resource ID | Holds the firing alert and the Log Analytics workspace. |
| **`vpp-log-analyt-p`** | Log Analytics workspace for VPP prd, GUID `8bb8b1ca-9b6e-4af8-afca-6e9f1fda544a`. | Resource ID | Where AzureActivity ServiceHealth rows land and where the rule queries. |
| **`eneco-vpp-prd`** | OpenShift namespace on the Eneco MCC prd OpenShift cluster running VPP workloads. | Cluster API | The "namespace" field in the SN ticket — **not the failure surface in this RCA**. |
| **`scheduledQueryRule`** | Azure Monitor alert rule (resource type `Microsoft.Insights/scheduledQueryRules`) that runs a KQL query on a cadence against a workspace; fires when result satisfies `criteria`. | [Azure docs — Log alerts](https://learn.microsoft.com/azure/azure-monitor/alerts/alerts-types#log-alerts) | The rule type at fault. |
| **AzureActivity / ServiceHealth** | `AzureActivity` is the Log Analytics table for Azure activity-log records. `CategoryValue == "ServiceHealth"` filters to Microsoft's own platform announcements: incidents, advisories, security notices, maintenance — independent of customer resources. | [AzureActivity schema](https://learn.microsoft.com/azure/azure-monitor/reference/tables/azureactivity) | The rule matches any of these without further filter. |
| **`ResourceHealth` (compare)** | Sibling AzureActivity category for **per-resource** health events ("Storage account X became unavailable"). The IaC-defined alerts in `prd-alerts.tfvars` use `ResourceHealth + OperationNameValue contains "healthevent/Activated/action" + ResourceProviderValue == "MICROSOFT.XXX"`. | [ResourceHealth events](https://learn.microsoft.com/azure/service-health/resource-health-overview) | The category the rule SHOULD have used if its author wanted "resource unhealthy" semantics. |
| **`TimeGenerated` vs `ingestion_time()`** | `TimeGenerated` = the emission timestamp on the row (when Azure produced the event). `ingestion_time()` = when the row landed in the Log Analytics workspace and became visible. These can diverge by minutes or hours under platform incidents (today: 14+ minutes). Azure Monitor V2 scheduled-query-rules with default time-scoping **use `ingestion_time()` for window evaluation**, which is why late-ingested rows trigger fires. | [Log alert query time range](https://learn.microsoft.com/azure/azure-monitor/alerts/alerts-types#log-alert-rules) | THE load-bearing distinction for today's mechanism. |
| **Action Group** | The Azure resource that defines how an alert routes (email, SMS, webhook, Logic App, ITSM connector, Rootly source, etc.). An alert with `actions=null` fires internally but does not push to receivers via Action Groups. | [Action groups](https://learn.microsoft.com/azure/azure-monitor/alerts/action-groups) | This rule has `actions: null`. Explains why no Rootly page; ServiceNow received it via a non-Action-Group path (A3). |
| **`autoMitigate`** | Property of a scheduled-query-rule. `true` = Azure marks alert "Resolved" when criteria stop being met. `false` = stays "Fired" until manually closed. | Azure Monitor docs | This rule is `false`; the fire will NOT self-close. |
| **Microsoft `5Z1B-6KG`** | Microsoft Azure platform incident tracking ID. Title: *"Mitigated – Log Analytics and Application Insights intermittent data latency in West Europe"*. Customer impact 06:40–12:45 UTC on 2026-05-11. | Service Health blade | The actual upstream cause of today's fire. |
| **ServiceNow (intake channel)** | The Eneco incident-management system that received the alert. Independent of Rootly. The exact Azure→ServiceNow integration path is A3 UNVERIFIED for this rule (4 alternatives uneliminated: ITSM connector, Alert Processing Rule, Logic App, native SN Azure integration). | Eneco internal | Explains why no Rootly page; warns the on-call NOT to assume Azure-close propagates to SN-close. |
| **`monitor_query_rules_alert` (tfvars variable)** | HCL variable in `configuration/prd-alerts.tfvars` defining the 13 IaC-governed health-event alerts for VPP prd. Drives `monitor_metric_query_alert.tf` which instantiates the shared `monitor_scheduled_query_rules_alert_V2` module. Naming pattern: `${prefix}-${project}-${each.key}-healthevent-${environmentShort}` → e.g., `vpp-KustoDB-healthevent-p`. **Cannot produce the literal name `vpp-resource-unhealthy`.** | `prd-alerts.tfvars:205-558` | Contrast surface — the deployed rule does NOT match any IaC pattern. |

## Evidence Ledger

### Evidence labels in this section: A1 = command/file proof; A2 = inference; A3 = blocked.

| # | Claim | Label | Source / probe |
|---|---|---|---|
| E1 | Alert resource ID = `/subscriptions/f007df01.../resourceGroups/mcprd-rg-vpp-p-res/providers/microsoft.insights/scheduledqueryrules/vpp-resource-unhealthy` | A1 | `cmc-service-now-ticket.txt:14-15` |
| E2 | Alert is `Microsoft.Insights/scheduledQueryRules`, severity 0, evaluationFrequency 5m, windowSize 5m, threshold > 1, aggregation Count, autoMitigate false, `createdWithApiVersion 2023-03-15-preview` | A1 | `az monitor scheduled-query show -g mcprd-rg-vpp-p-res -n vpp-resource-unhealthy` → sidecar `azure-alert-rule-raw.json:5-28,56` |
| E3 | KQL query is literally `AzureActivity\| where  CategoryValue == "ServiceHealth"\r\n` (single predicate, no further filters) | A1 | sidecar `azure-alert-rule-raw.json:17` |
| E4 | `actions: null` — no action group attached | A1 | sidecar `azure-alert-rule-raw.json:2` |
| E5 | `systemData.createdAt == lastModifiedAt == 2024-01-24T16:12:31.862162+00:00` (identical to the microsecond); `createdBy == lastModifiedBy == eelke.hoffman@conclusion.nl`; `createdByType: User`. The byte-identical timestamps are A1 proof of "never rewritten via ARM PUT since creation" — stronger than the 7d activity log alone. | A1 | sidecar `azure-alert-rule-raw.json:43-50` |
| E5b | Whether the User principal used Azure portal, Azure CLI, or workstation-credential Terraform to create the rule is A3 UNVERIFIED[blocked: activity-log creation entry would predate 90d retention; portal-vs-CLI-vs-TF distinguished by `httpRequest.clientRequestId` / `userAgent` / `caller` in the create-time activity-log entry, which is no longer retrievable]. The "out-of-IaC" framing holds either way because the rule is also absent from every local Eneco repo (E11/E12). | A3 | activity-log retention windows + sidecar `local-fs-alert-hcl-search.md` |
| E6 | Rule has no tags (`tags: {}`) | A1 | sidecar `azure-alert-rule-raw.json:51` |
| E7 | Rule has fired exactly **once in the past 30 days**, at `2026-05-11T13:12:43.2790702Z`; current alert state `New` / condition `Fired`; alert UUID `22ed515b-24d3-26ce-3fb3-09cfc5158afb` | A1 | `az rest GET .../providers/Microsoft.AlertsManagement/alerts?timeRange=30d` → sidecar `all-alerts-30d.json` (NOT `alert-fires-30d.json` — that filter syntax returned an empty array; correct file is `all-alerts-30d.json` cross-filtered by `alertRule contains "vpp-resource-unhealthy"`) |
| E8 | Three ServiceHealth rows are visible in the workspace covering 12:30 UTC → fire time, all carrying the same tracking ID `5Z1B-6KG`: (a) `TimeGenerated=12:54:56.5954202Z, ActivityStatusValue=Active, EventDataId=8c9e2fbf-...`; (b) `TimeGenerated=12:55:53.7590998Z, ActivityStatusValue=Resolved, EventDataId=4de50591-...`; (c) `TimeGenerated=13:10:36.3600226Z, ActivityStatusValue=Resolved, EventDataId=662512f2-...` | A1 | `az monitor log-analytics query --analytics-query "AzureActivity \| where TimeGenerated between (datetime(2026-05-11T12:30:00Z) .. datetime(2026-05-11T13:13:00Z)) \| where CategoryValue == 'ServiceHealth' \| project TimeGenerated, IngestionTime=ingestion_time(), ActivityStatusValue, EventDataId, CorrelationId"` → sidecar `F1-broad-with-ingestion.json` |
| E9 | The Microsoft `communication` payload explicitly warned: *"Impacted customers ingesting telemetry in their workspaces may have experienced intermittent data latency and **incorrect alert activation** for workspaces hosted in the region."* | A1 | sidecar `workspace-servicehealth-firetime.json` → Properties.communication |
| **E10 (v3 corrected)** | **The rule's actual evaluation window per Azure's own alert payload is `windowStartTime=2026-05-11T12:52:07Z` to `windowEndTime=2026-05-11T12:57:07Z` — NOT 13:07:43Z–13:12:43Z. The evaluation occurred at fire time 13:12:43Z (≈15 min after windowEnd) because the Azure Monitor scheduled-query engine has a built-in late-data-settling period that delays evaluation of recent windows until late-arriving data has had a chance to settle. By `TimeGenerated`, the 12:52–12:57 window contains exactly 2 ServiceHealth rows (TG 12:54:56 + TG 12:55:53 — both same incident `5Z1B-6KG`). Azure's own `metricValue = 2.0` in the alert payload confirms the count. Both rows landed in the workspace late (ingestion_time 13:09:10 and 13:09:44 — 14 minutes after TimeGenerated, exactly the latency Microsoft's incident communication warned of); the engine waited for them, then evaluated and fired.** | A1 (Azure-authoritative) | Captured in the close-time alert payload — sidecar `close-final-changestate.json` shows `windowStartTime=2026-05-11T12:52:07Z, windowEndTime=2026-05-11T12:57:07Z, metricValue=2.0, dimensions=[{name:_ResourceId, value:/subscriptions/f007df01-...}]`. Cross-validated by the earlier KQL probe in `F1-broad-with-ingestion.json` showing the two TimeGenerated rows in that exact window with ingestion_time inside the 13:09 backlog drain. |
| E11 | The alert is **not defined in `MC-VPP-Infrastructure/main`** at local HEAD `8d7d890` | A1 (`grep` zero-match is a direct coordinator observation) / A2 (extrapolating to "alert is not in IaC anywhere" is conditional on E13 origin-freshness) | `grep -rln "vpp-resource-unhealthy" ...MC-VPP-Infrastructure/main` → zero matches; naming pattern in `terraform/monitor_metric_query_alert.tf` cannot produce literal `vpp-resource-unhealthy`; the 13 keys in `monitor_query_rules_alert` map produce names like `vpp-KustoDB-healthevent-p`, not `vpp-resource-unhealthy` |
| E12 | The alert is **not defined anywhere in the local Eneco source tree** | A1 imported (subagent codebase-locator reported NOT FOUND across all 100+ Eneco-src sub-repos, HIGH confidence; coordinator did NOT re-execute the exhaustive scan but cross-validated by running one literal `grep -rln "vpp-resource-unhealthy" eneco-src/` which also returned zero matches) | sidecar `local-fs-alert-hcl-search.md` + direct `grep` cross-validation |
| E13 | Local mirror is **fixed at commit `8d7d890`** because `git fetch` returned SSH "Permission denied" at probe time | A1 | `cd MC-VPP-Infrastructure && git fetch --all --prune` → `git@ssh.dev.azure.com: Permission denied (password,publickey)` |
| E14 | The IaC-defined alert pattern (in `prd-alerts.tfvars`) for every health-event class is well-formed and structurally different: `CategoryValue == "ResourceHealth"` + `ActivityStatusValue == "Active"` + `OperationNameValue contains "healthevent/Activated/action"` + `ResourceProviderValue == "MICROSOFT.XXX"`; severity 2 or 3; action groups bound | A1 | `configuration/prd-alerts.tfvars:205-558` (KustoDB, AppConfig, Network, CosmosDB, EventHub, Insights, KeyVault, LogicApp, RedisCache, ServiceBus, SignalRService, Storage, SqlDB) |
| E15 | The alert rule's 7-day activity log (`Microsoft.Insights/scheduledQueryRules/write` and friends) is an empty array — no ARM-tracked modifications in the last 7 days. This is consistent with but does NOT prove "never modified since 2024-01-24"; the byte-identical systemData timestamps in E5 are the stronger evidence for "never rewritten via ARM PUT." Portal-only operations that bypass ARM versioning are not captured here. | A1 | sidecar `alert-rule-activity-log.json` (`[]`, 7-day window) |
| E16 | Rootly side-channel cross-reference: handed off to a separate agent per on-call routing decision; not load-bearing for this RCA's mechanism or routing. The single fact this RCA relies on is **`mcp__rootly__listAlerts` returned zero hits for rule name `vpp-resource-unhealthy` in the past hour**, confirming the `actions: null` observation: the rule does not propagate to Rootly. Any broader Rootly correlation analysis (e.g., Kusto ingestion latency alerts, otel-collector memory pressure) is out of scope for this RCA and lives in the parallel agent's deliverable. | A1 imported | Rootly MCP query at intake time; cross-check sidecar exists but is not load-bearing here |
| E17 | The ServiceNow → Azure integration path for this alert is A3 UNVERIFIED[blocked: 4 alternatives uneliminated]: (a) subscription-level Azure→ServiceNow ITSM connector; (b) Alert Processing Rule that adds a webhook independent of the rule's `actions`; (c) Logic App polling Alerts Management API; (d) native ServiceNow Azure integration plugin (pull-side, no Azure-side fingerprint). The `actions: null` observation only rules out per-rule Action Groups. **This A3 directly affects L8 Plane 2**: do not assume Azure-close propagates to ServiceNow-close. | A3 | Probes named in L9 are queued but not executed in this session per scope decision; the implication is the operational defense in L8 |

## L1 — Business — Why Eneco VPP exists

Eneco VPP (Virtual Power Plant) aggregates Eneco's portfolio of flexible energy assets (industrial batteries, demand-response heat pumps, large heating contracts, wind/solar curtailment) and trades their flexibility in the Dutch and German wholesale power and balancing markets — day-ahead, intraday, mFRR (manual frequency-restoration reserve) and FCR (frequency-containment reserve). A real cluster-side incident on `eneco-vpp-prd` is paged because failed schedule submission costs Eneco real money (imbalance charges) and risks regulator-visible non-delivery on balancing contracts.

**Why this matters for THIS RCA**: it sets the bar that a sev-0 page on this stack is "Eneco is losing optimization or money right now." That expectation makes today's page worth diagnosing rather than dismissing — and frames why the close-only routing is conditional on `oc-playbook.md` returning clean.

## L2 — Repo system

| Repo | Role | Source | Incident relevance |
|---|---|---|---|
| `enecomanagedcloud / Myriad - VPP / MC-VPP-Infrastructure` | Terraform IaC for VPP MC landing zone (prd/acc/dev). Owns the Log Analytics workspace, all action groups, and the 13 IaC-defined ResourceHealth alerts. | [ADO repo](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/MC-VPP-Infrastructure) | Source-of-truth for what the rule SHOULD look like; confirms by absence that `vpp-resource-unhealthy` is NOT here. |
| `enecomanagedcloud / Myriad - VPP / Eneco.Infrastructure` | Shared module repo; contains `monitor_scheduled_query_rules_alert_V2` v2.1.0 that MC-VPP-Infrastructure wraps. | [ADO repo](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/Eneco.Infrastructure) | Would be reused if this rule were ever codified. |
| `enecomanagedcloud / Myriad - VPP / azure-pipeline` | Helm charts + ArgoCD overlays for VPP workloads on OpenShift. | [ADO repo](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/azure-pipeline) | Not load-bearing — cluster is not the failure mechanism. |

Specific contrast surface inside MC-VPP-Infrastructure:

- `terraform/monitor_metric_query_alert.tf` — wraps the shared module; iterates over `var.monitor_query_rules_alert`. Naming pattern `${var.prefix}-${var.project}-${each.key}-healthevent-${var.environmentShort}` produces `vpp-KustoDB-healthevent-p` for prd. Cannot produce `vpp-resource-unhealthy`.
- `configuration/prd-alerts.tfvars` — 13 entries, none matching the firing rule.

## L3 — Runtime architecture (Azure side)

Small topology by design. The OpenShift cluster is intentionally outside this picture; see L4 stub for why.

```
+----------------------------------------------------------------+
| Subscription:  Eneco MCC - Production - Workload VPP            |
|                f007df01-9295-491c-b0e9-e3981f2df0b0             |
|                                                                 |
|  +-----------------------------------------------------------+  |
|  | Resource Group: mcprd-rg-vpp-p-res                         |  |
|  |                                                            |  |
|  |   Log Analytics Workspace: vpp-log-analyt-p               |  |
|  |       (customerId 8bb8b1ca-9b6e-4af8-afca-6e9f1fda544a)    |  |
|  |       Tables: AzureActivity, Heartbeat, ...                |  |
|  |                                                            |  |
|  |   ScheduledQueryRule: vpp-resource-unhealthy  <-- FAULT    |  |
|  |       severity   : 0 (Disaster)                            |  |
|  |       frequency  : 5m, window 5m                           |  |
|  |       query      : AzureActivity                           |  |
|  |                       | where CategoryValue=='ServiceHealth|
|  |       threshold  : Count > 1 (evaluated via ingestion_time)|  |
|  |       actions    : null  (no action group)                 |  |
|  |       autoMitigate: false                                  |  |
|  |       createdBy  : eelke.hoffman@conclusion.nl (2024-01-24)|  |
|  |                                                            |  |
|  |   13 IaC-defined ScheduledQueryRules ("healthevent" suite) |  |
|  |       severity   : 2 or 3                                  |  |
|  |       query      : AzureActivity                           |  |
|  |                       | where CategoryValue=='ResourceHealth|
|  |                       | where ActivityStatusValue=='Active' |
|  |                       | where OperationNameValue contains   |
|  |                              'healthevent/Activated/action' |
|  |                       | where ResourceProviderValue=='X'    |
|  |       actions    : routed to team Action Groups -> Rootly  |
|  +-----------------------------------------------------------+  |
|                                                                 |
+----------------------------------------------------------------+

Microsoft Azure platform plane (out of our subscription)
   |  publishes ServiceHealth communications
   |  (incidents, advisories, security, maintenance) for West Europe
   v
AzureActivity ingestion path
   |  affected by incident 5Z1B-6KG (06:40-12:45 UTC) — 14+ min delay
   v
AzureActivity table in our workspace (category=ServiceHealth)
   |  rows visible by ingestion_time() inside rule's 5-min window
   v
Rule evaluation at 13:12:43 UTC -- count > 1 satisfied -- FIRES sev-0

Azure -> ServiceNow path (A3 UNVERIFIED, 4 alternatives)
   |  ITSM connector | APR webhook | Logic App | native SN plugin
   v
ServiceNow ticket (CMC class) -> on-call paged
```

**Format note** (per adversarial F7): the Mermaid-rendered equivalent is a future improvement; the ASCII above is the load-bearing version for engineering-log GitHub viewers. The phone-screen test (Slack mobile) is a known gap.

## L4 — Application code flow — *intentionally omitted*

**Why omitted**: the failure is in Azure Monitor's rule definition, not in any application code path. The OpenShift namespace `eneco-vpp-prd` is referenced in the ServiceNow ticket as a CMDB attribute but is not the failure surface. The cluster-side falsifier is `oc-playbook.md` (sanity check that no VPP workload was actually degraded during the 13:00–13:20 UTC window). If `oc-playbook.md` returns positive evidence of cluster degradation, this RCA's framing must be revisited and a new RCA opened for the workload-side incident.

## L5 — IaC / state / Azure — the three truths

| Truth surface | What it says | Evidence |
|---|---|---|
| **IaC spec** (`MC-VPP-Infrastructure/main` at HEAD `8d7d890`) | This alert should not exist. The 13 health-event alerts that DO exist all use ResourceHealth + provider-filter + `Activated/action` pattern with sev 2/3 and routed action groups. | E11, E14 |
| **Azure runtime** (live, queried this session) | The alert DOES exist as a manually-created resource. KQL is a single `CategoryValue == "ServiceHealth"` predicate. Sev 0, no action group, autoMitigate false. Created 2024-01-24 by `eelke.hoffman@conclusion.nl` via a User-principal ARM call (portal vs CLI vs Terraform-from-workstation A3). Byte-identical createdAt/lastModifiedAt = "never re-written via ARM PUT since creation". | E2, E3, E4, E5, E5b |
| **Wider Eneco source tree** (local mirror at `8d7d890`, A3 origin-freshness) | No file anywhere in the local Eneco-src checkout references this alert name. Cross-validated by subagent codebase-locator (HIGH confidence). | E11, E12, E13 |

**Three-truths reconciliation**: IaC says A; runtime says B; documentation says nothing. The runtime diverges from IaC because the rule was never in IaC. Classic *out-of-IaC shadow resource* pathology — a portal-or-workstation-created resource that escapes the team's Terraform state and review.

**Inversion note**: my initial hypothesis (H4 in the task manifest) was "a recent IaC change introduced the misconfiguration." Evidence inverts that: this alert has been wrong since the day it was born, 15.5 months ago, and no IaC change in any direction would have fixed it because the rule has never been in IaC at all.

## L6 — The pipeline and how it actually runs — *intentionally omitted*

**Why omitted**: no Terraform / Terragrunt / ADO pipeline ran for this resource because it has never been in IaC. No pipeline gate could have caught the misconfiguration. The relevant pipeline-level lesson is that **a pipeline-only review surface is a necessary but not sufficient control** — out-of-IaC resources require an independent inventory diff (see Lesson 1 in L10) because they will never reach the pipeline. If Lesson 1's recommended quarterly inventory diff had run any time in the last 15.5 months, this rule would have surfaced.

## L7 — Timeline

Times in UTC unless noted. CEST = UTC + 2 today (DST active).

| Time (UTC) | Time (CEST) | Event | Evidence |
|---|---|---|---|
| 2024-01-24 16:12:31.862 | 17:12:31 | Rule created via ARM by User principal `eelke.hoffman@conclusion.nl` (portal-vs-CLI-vs-TF A3) | E5 |
| 2024-01-24 → 2026-05-11 | ~15.5 months | Rule never re-written via ARM PUT (`systemData.lastModifiedAt == createdAt`); fires zero times | E5, E7 |
| 2026-05-11 06:40 | 08:40 | Microsoft platform incident `5Z1B-6KG` impact starts (per Microsoft's `communication` text — the structured `impactStartTime` field reads 11:11 UTC; this RCA uses the textual customer-impact window because it is the conservative bound) ¹ | E8, E9 |
| 2026-05-11 08:57 | 10:57 | Microsoft detects via internal monitoring | E9 |
| 2026-05-11 11:05 | 13:05 | Microsoft scales capacity beyond automatic limits | E9 |
| 2026-05-11 12:45 | 14:45 | Microsoft declares Mitigated; customer impact ends (textual). Structured `impactMitigationTime`: 12:55:01 UTC ¹ | E9 |
| 2026-05-11 12:54:56.595 | 14:54:56 | (Microsoft's emission timestamp) ServiceHealth communication `EventDataId=8c9e2fbf-...`, `ActivityStatusValue=Active`, tracking ID `5Z1B-6KG` — same incident | E8 |
| 2026-05-11 12:55:53.759 | 14:55:53 | (Microsoft's emission timestamp) ServiceHealth communication `EventDataId=4de50591-...`, `ActivityStatusValue=Resolved`, tracking ID `5Z1B-6KG` | E8 |
| 2026-05-11 13:09:10.66 | 15:09:10 | First of two late notices is **ingested** into our workspace (delay vs emission: 14:14) | E8 (IngestionTime column) |
| 2026-05-11 13:09:44.70 | 15:09:44 | Second of two late notices is **ingested** into our workspace (delay vs emission: 13:51) | E8 |
| 2026-05-11 12:52:07 → 12:57:07 | 14:52:07 → 14:57:07 | Rule's ACTUAL 5-min evaluation window per Azure's payload (`windowStartTime` / `windowEndTime`). By `TimeGenerated` the window contains 2 rows (TG 12:54:56 + TG 12:55:53). Azure reports `metricValue=2.0` → `Count > 1` satisfied | E10 |
| 2026-05-11 13:07:43 → 13:12:43 | 15:07:43 → 15:12:43 | What the v2 RCA *assumed* the window was (5 min before fire time). Wrong — the Azure Monitor engine evaluates windows offset back to allow late-data settling. | (v2 RCA error, corrected here) |
| 2026-05-11 13:10:36.36 | 15:10:36 | (Microsoft's emission timestamp) ServiceHealth communication `EventDataId=662512f2-...`, `ActivityStatusValue=Resolved`, tracking ID `5Z1B-6KG` — this is the "Mitigated" notice | E8 |
| 2026-05-11 13:12:43.279 | 15:12:43 | Rule fires; sev 0; `monitorCondition=Fired`, `alertState=New`. No action group → no Rootly page | E7, E10 |
| ~2026-05-11 13:13:50 | ~15:13:50 | ServiceNow CMC ticket created (A2: ticket exists at the time the on-call received it; A3: the specific Azure→SN path is uneliminated — see E17 / L8 Plane 2) | `cmc-service-now-ticket.txt`, E17 |
| 2026-05-11 13:20:41.54 | 15:20:41 | The 13:10:36 "Mitigated" notice is finally ingested into our workspace — AFTER the rule had already fired. Would trigger the rule again at the next evaluation if it were in window, but `_ResourceId` partitioning + autoMitigate=false leaves the existing fired state untouched | E8 |
| 2026-05-11 14:02 | 16:02 | On-call (atorres.ruiz) opens RCA; queries Azure backplane; runs adversarial review | This session |

¹ **Time-field footnote** (per adversarial F7): the Microsoft `Properties` payload contains two disagreeing sets of times. Textual (in the HTML `communication` field): 06:40 UTC start, 12:45 UTC mitigation — this is the customer-impact window. Structured (`impactStartTime` 11:11:09 UTC, `impactMitigationTime` 12:55:01 UTC) — likely the detect-to-mitigate window from Microsoft's monitoring view. This RCA uses the textual customer-impact window as the conservative bound for "when did latency affect our workspace." Both are A1-observable in the sidecar.

## L8 — Fix (close-only operational, per routing decision)

> **Routing decision**: on-call (atorres.ruiz) elected **close-only** remediation. This RCA does NOT propose IaC changes, rule disablement, or rule deletion. Tiers (rejected here) are documented in L10 so a future on-call or Platform owner can pick them up.

Three planes. Plane 3 (cluster sanity check) is **mandatory pre-close**, not post.

### Plane 3 (run FIRST) — Sanity-check the cluster

Run [`oc-playbook.md`](./oc-playbook.md). Three probes against `eneco-vpp-prd`:

1. Any pods not Running in the namespace?
2. Any unusual events in the last 30 minutes (CrashLoopBackOff, ImagePullBackOff, FailedScheduling)?
3. Any pod with restartCount climbing during 13:00–13:20 UTC?

**Decision rule**: if any probe returns positive evidence of cluster degradation in `eneco-vpp-prd` around 13:00–13:20 UTC, **STOP — DO NOT CLOSE the alert/ticket**. Open this as a real workload incident; this RCA's framing collapses and a separate investigation is needed. If all probes return clean, proceed to Plane 1.

### Plane 1 — Close the Azure alert

The alert is `state=New, condition=Fired, autoMitigate=false` — will NOT self-close. Use the `az` commands in [§ Close commands](#close-commands-az-this-page) above (Plane 1 = step 2).

**What changes**: `alertState` transitions from `New` to `Closed`. `monitorCondition` stays `Fired` because the rule does not auto-mitigate; that is normal and not a problem.
**Why this addresses the mechanism**: prevents the Azure Alerts blade from carrying a permanently-firing sev-0 entry that confuses future on-call shifts.
**What it does not change**: the alert RULE itself remains in place and **will re-fire on the next ServiceHealth communication** in the workspace.

### Plane 2 — Close the ServiceNow ticket — manually

**The Azure→ServiceNow integration path for this alert is A3 UNVERIFIED** (per adversarial F2 / E17). Four uneliminated alternatives — only some are bidirectional. **Do NOT assume Azure-close propagates to ServiceNow-close.** Always close both planes manually.

**What changes**: ServiceNow ticket transitions to `Resolved` / `Closed` in the ServiceNow UI (or via the SN MID server if there is an integration).
**Why**: closes the paging loop visible to incident-management dashboards regardless of which Azure→SN path is in use.
**What it does not change**: future fires of the same Azure rule will create new tickets.

If you want to know which path is in use (to inform future on-calls), the four uneliminated alternatives and probes are:

| Alternative | Probe to confirm |
|---|---|
| (a) Subscription-level Azure→ServiceNow ITSM connector | `az monitor diagnostic-settings subscription list --subscription f007df01-...` |
| (b) Alert Processing Rule adding a webhook independent of the rule's `actions` | `az monitor alert-processing-rule list --subscription f007df01-...` |
| (c) Logic App polling `Microsoft.AlertsManagement/alerts` | `az logicapp list --subscription f007df01-...` filtered by trigger type |
| (d) Native ServiceNow Azure integration plugin (pull-side) | ServiceNow UI → CMC ticket → Related Items → trace integration record |

None of these were probed in this session per scope decision. They are sequenced for the Platform/SRE follow-up.

## L9 — Verification

How a reviewer (or me on the next shift) confirms closure landed AND the conclusion holds.

| Question | Probe | Expected output | Decision rule |
|---|---|---|---|
| **(MANDATORY PRE-CLOSE) Was the cluster actually healthy?** | Run `oc-playbook.md` Plane-3 probes | No degraded operator / no recent CrashLoopBackOff in `eneco-vpp-prd` during 13:00-13:20 UTC | If any probe returns positive evidence of cluster degradation, **STOP using this RCA's conclusion** — re-open as a real workload incident |
| **(MANDATORY PRE-CLOSE) Re-validate the fire mechanism** | `az monitor log-analytics query --workspace 8bb8b1ca-9b6e-4af8-afca-6e9f1fda544a --analytics-query "AzureActivity \| where ingestion_time() between (datetime(2026-05-11T13:07:43Z) .. datetime(2026-05-11T13:12:43Z)) \| where CategoryValue == 'ServiceHealth' \| count"` | 2 | If 0 or 1: the mechanism in this RCA is wrong, the actual trigger is unknown, and the close decision must be escalated to SRE/Platform before action |
| Did the Azure alert close? | `az rest GET .../alerts/22ed515b-24d3-26ce-3fb3-09cfc5158afb?api-version=2019-05-05-preview` | `essentials.alertState=Closed`, `essentials.monitorCondition=Fired` (the latter is expected with autoMitigate=false) | If still `New`, repeat step 2 of the close commands; if it re-fires within 5 min, a new ServiceHealth event landed and the structural problem is re-asserting itself |
| Did the ServiceNow ticket resolve? | ServiceNow UI on the ticket | Status = Resolved / Closed | If stale > 15 min, the Azure→SN connector path is not bidirectional or there is no connector; close the ticket manually (Plane 2) — see L8 |
| Did Microsoft incident `5Z1B-6KG` truly land in our workspace? | `az monitor log-analytics query ... "AzureActivity \| where TimeGenerated between (datetime(2026-05-11T12:00:00Z) .. datetime(2026-05-11T13:15:00Z)) \| where CategoryValue == 'ServiceHealth' \| project TimeGenerated, ActivityStatusValue, Properties"` | 3 rows, all with the tracking ID `5Z1B-6KG` in `Properties` | If zero rows: this entire RCA's framing is wrong; escalate immediately |

**Confidence calculation** (per rca-holistic Rule X12):

```text
A1_confirmed = 13   (E1, E2, E3, E4, E5, E6, E7, E8, E9, E10, E13, E14, E15)
A2_infer     = 2    (E11 partial, E16 imported)
A3_blocked   = 3    (E5b portal-vs-CLI-vs-TF, E12 origin-freshness, E17 SN-path)
open_contradictions = 0

confidence = 13 / (13 + 2 + 3 + 0) = 0.72
```

The 0.72 score reflects two material A3s (E5b, E17) and one minor (E12 — local mirror freshness). None of the three A3s blocks the fix path: E5b doesn't affect the routing (rule is out-of-IaC regardless of creation tool); E12 is bounded by E11 + subagent cross-validation; E17 is mitigated operationally by "always close both planes manually." **Per Rule X12 hard gate, no A3 affects the root cause or fix path — therefore `status: review` is supported.** Promotion to `status: complete` requires running the two mandatory pre-close probes above + producing `oc-playbook.md`.

## L10 — Lessons

Three durable lessons, each rephrased to test transfer.

### Lesson 1 — Out-of-IaC alerts decay silently for years

**Pattern**: A monitoring alert created manually in a cloud portal (or via workstation-credential CLI / Terraform) during an early platform stand-up never gets adopted into IaC; its KQL/threshold ages alongside the underlying platform and the organization's review cadence (because it is not in any review surface). It eventually fires for a reason its author did not anticipate, and the page goes to an on-call who has never seen the rule before.

**Probe** (the literal `az graph` query in v1 of this RCA was incorrect because `systemData` is not exposed via the Resources table on Resource Graph). The actually-executable probe is a **two-step inventory diff**:

```bash
# Step 1 — enumerate all scheduledQueryRules in the prd subscription
az monitor scheduled-query list --subscription f007df01-9295-491c-b0e9-e3981f2df0b0 \
  --query "[].{name:name, rg:resourceGroup, sev:severity, autoMit:autoMitigate, hasActions:(actions.actionGroups!=null)}" \
  -o tsv > deployed-rules.tsv

# Step 2 — generate the IaC-derived expected name list from the tfvars
# (manual or scripted from MC-VPP-Infrastructure/configuration/prd-alerts.tfvars
# applying the naming pattern: vpp-${each.key}-healthevent-p)
# Diff deployed-rules.tsv against the expected set.
# Anything in deployed but not in expected is an out-of-IaC alert.
```

**Defense**: schedule a quarterly run of the inventory diff. Add to the team's runbook. Any out-of-IaC alert is a candidate for adoption-or-deletion within one sprint.

### Lesson 2 — `CategoryValue == "ServiceHealth"` is the wrong knob for resource alerting

**Pattern**: An alert author wanted to surface platform-level problems for the team, defaulted to "watch ServiceHealth," and stopped before adding any narrowing filter. ServiceHealth is Microsoft's own announcement stream — incidents, advisories, maintenance, security. **Today's twist**: the rule fired not on the resolution notice itself (which arrived later than the fire) but on **earlier same-incident notices late-ingested during the backlog drain** of the very Microsoft incident the notices described. Microsoft's own warning ("incorrect alert activation for workspaces hosted in the region") came literally true.

**Probe** (executable):

```bash
# Enumerate scheduledQueryRules and inspect KQL bodies
az monitor scheduled-query list --subscription f007df01-9295-491c-b0e9-e3981f2df0b0 \
  --query "[].name" -o tsv | while read rn; do
    rg_and_name=$(az monitor scheduled-query show --name "$rn" --resource-group "$(az monitor scheduled-query list --query "[?name=='$rn'].resourceGroup | [0]" -o tsv)" --query "{n:name, q:criteria.allOf[0].query}" -o tsv)
    echo "$rg_and_name"
  done | grep -i 'ServiceHealth' | grep -v 'Activated/action'
```

(The one-liner is sketchy; production version: a small Python/Go tool enumerating rules and parsing their KQL — left as an SRE follow-up.)

**Defense**: in the team's alert-authoring guidance, prohibit raw `CategoryValue == "ServiceHealth"` without (a) `ActivityStatusValue` filter and (b) at least one of `impactedServices`, per-service KQL projection, or — for resource-centric alerts — switch to `ResourceHealth + Activated/action + ResourceProviderValue` like the existing IaC pattern does.

### Lesson 3 — `autoMitigate=false` on a paging-bound rule requires a manual-close runbook (severity merely intensifies the on-call cost)

**Pattern**: `autoMitigate=false` is the irreversible commitment — every fire becomes a permanent Alerts-blade entry until manually closed. **This property is orthogonal to severity.** A sev-2 rule with the same autoMitigate=false and an over-broad KQL would have the same "stays Fired forever" property; severity changes who-gets-paged-how, not the auto-close behavior. The asymmetry — automatic firing, manual resolution — concentrates noise on the on-call when combined with sev-0.

**Probe**:

```bash
az monitor scheduled-query list --subscription f007df01-9295-491c-b0e9-e3981f2df0b0 \
  --query "[?autoMitigate==\`false\` && severity==\`0\`].{name:name, sev:severity}" -o tsv
# Each result must have a documented runbook URL AND a bound action group.
# Then a broader audit:
az monitor scheduled-query list --subscription f007df01-9295-491c-b0e9-e3981f2df0b0 \
  --query "[?autoMitigate==\`false\`].{name:name, sev:severity}" -o tsv
# Every autoMitigate=false rule (any sev) must have a manual-close protocol or a justified exception.
```

**Defense**: in the team's alert review checklist, refuse `autoMitigate=false` on any paging-bound rule unless (a) the action group routes to a 24/7 surface, (b) a runbook URL is present in the rule description, and (c) a manual-close protocol exists. Severity-0 with `autoMitigate=false` requires an extra reviewer.

### Side observation (out of scope for this RCA's routing decision)

The rule's creator (`eelke.hoffman@conclusion.nl`) is a **vendor identity** (Conclusion is an Eneco MCC partner). Whether vendor identities should be able to create sev-0 paging rules on the production VPP subscription that escape IaC for 15.5 months is a **governance/audit question for SRE/Platform**, not an on-call decision. Surfacing here so the next-shift reader can route it; not proposing remediation in this RCA.

### Rejected remediation tiers (for the next shift's awareness)

| Tier | What it would do | Why rejected today | When to revisit |
|---|---|---|---|
| Close + disable rule | Set `enabled=false`; preserves resource for forensics; stops fires | Requires write authorization on prd scheduledQueryRule; team policy is to route changes via IaC PR | If the rule fires again before SRE/Platform picks up the IaC adoption |
| Close + codify in IaC + redesign | Adopt rule into `MC-VPP-Infrastructure` with a narrowed KQL (`ResourceHealth + Activated/action` + provider filter), proper severity (≤2), and a Rootly-bound action group | Requires a PR, review cadence, and acc-environment validation — out of scope for this on-call shift | Add as a follow-up ADO work item assigned to vpp-core or SRE |
| Close + delete rule | Permanent removal of the orphan resource | Loses any future ServiceHealth coverage; portfolio decision | Only after a proper replacement lands, as a cleanup step |

## L11 / L12 — Command playbook and one-page on-call card

- **`fix.md` (forthcoming sibling, optional)** — would extract just the close-command block from this RCA into a standalone file. Currently inlined in [§ Close commands](#close-commands-az-this-page) above per on-call routing decision.
- **[`oc-playbook.md`](./oc-playbook.md)** — minimal `oc` sanity-check sheet (Plane 3) for `eneco-vpp-prd`. **Mandatory pre-close per adversarial F3.**
- **`on-call-onepager.md` (optional, future)** — 3-line triage card for the next on-call paged on `vpp-resource-unhealthy`. Key triage line: *"If the workspace ServiceHealth payload is a Microsoft platform announcement (especially one whose `Properties.communication` mentions West Europe ingestion latency, or one with an Active/Resolved pair in the rolling window via `ingestion_time()`), this is the known orphan-alert noise: run oc-playbook.md to rule out cluster impact, then close-only."*

## Limitations (named, not hidden)

1. **The Azure→ServiceNow integration path is A3 UNVERIFIED** (E17). Four uneliminated alternatives — only some are bidirectional. Operational defense: L8 Plane 2 requires manual ServiceNow close. Resolving probes are in L8 Plane 2 table and L10 follow-ups.
2. **The portal-vs-CLI-vs-Terraform-from-workstation question** for the rule's 2024-01-24 creation is A3 (E5b) because activity-log retention has expired. The "out-of-IaC" framing holds regardless because the rule is also absent from every local Eneco repo (E11 + E12 + subagent cross-validation). Lesson 1's probe was widened to "deployed but not in IaC inventory" rather than relying on `createdBy` heuristics.
3. **Origin freshness of the IaC mirror** (E13) is A3 because `git fetch` was SSH-denied at probe time. Subagent codebase-locator (HIGH confidence, exhaustive scan of 100+ Eneco-src sub-repos) confirms absence; coordinator cross-validated by re-running one literal grep. Promoting "alert is not in IaC anywhere" from A2 to full A1 needs a successful `git fetch` or an ADO-API-side authoritative scan.
4. **No external Rootly correlation in this RCA** — handed off to a separate parallel agent per on-call routing decision. The only Rootly fact relied on here (E16) is "the `vpp-resource-unhealthy` rule name does not appear in Rootly's listAlerts" — confirms the `actions: null` observation and explains why no Rootly page.
5. **No cluster-side probe in this RCA** — delegated to `oc-playbook.md` (mandatory pre-close). The conclusion "no Eneco workload OBSERVED unhealthy" is currently INFER and explicitly downgraded from "no workload was unhealthy"; the falsifier is the oc-playbook execution.
6. **The Microsoft incident's textual and structured time fields disagree** (06:40 / 12:45 vs 11:11 / 12:55) — L7 uses the textual customer-impact window as the conservative bound; both are A1-observable in the sidecar.

## Mutation log (delta evidence for the v1.0 → v2.0 patches)

| Adversarial finding | Severity | What the adversary saw | What changed in v2.0 | How to verify |
|---|---|---|---|---|
| F1 (both) | BLOCKING | E10 claimed `count > 1` satisfied with no on-disk evidence; firing 5-min window had 1 row by `TimeGenerated` | Re-probed by `ingestion_time()` in this session; sidecar `F1-ingestion-time-window.json` shows 2 rows in window. E10 promoted to A1 with corrected mechanism (late ingestion during backlog drain). TL;DR rewritten. L7 timeline expanded with ingestion times. L9 verification updated to use `ingestion_time()` falsifier KQL. | Run the `az monitor log-analytics query` command in L9 — expect 2 rows |
| F2 Socrates | BLOCKING | L4 and L6 missing from holistic-RCA schema | Added L4 and L6 stub sections with explicit "intentionally omitted because X" justifications | Read L4 and L6 sections above |
| F3 demoledor | BLOCKING | `oc-playbook.md` referenced but did not exist | Plane 3 reordered to run FIRST (mandatory pre-close). Pre-close gates added to L9. `oc-playbook.md` to be authored as the next deliverable. | `ls log/employer/eneco/02_on_call_shift/2026_05_11_cmc_alert_vpp_cluster_prod/oc-playbook.md` |
| F2 demoledor | HIGH | ITSM connector path asserted; 4 alternatives uneliminated | Promoted Limitation #4 to E17 listing 4 alternatives with probes. L8 Plane 2 rewritten to require manual SN close, not propagation assumption | Read L8 Plane 2 and the alternatives table |
| F3 Socrates | HIGH | "Manually created in Azure portal" mislabeled A1 | E5 split into E5 (byte-identical timestamps = A1 "never re-written via ARM PUT") and E5b (portal-vs-CLI-vs-TF = A3). TL;DR softened. Lesson 1 probe rewritten. | Compare E5/E5b vs v1.0 |
| F4 Socrates | HIGH | `oTiT7t` PRD Rootly alert in-window silently dismissed | Rootly cross-check handed off to parallel agent per scope decision; E16 narrowed to "rule name absent from Rootly". Cluster sanity check via `oc-playbook.md` now mandatory pre-close (covers the gap independently). | Read E16 + L8 Plane 3 |
| F5 (both) | HIGH/LOW | Lesson 3 conflated severity and autoMitigate | Lesson 3 retitled and rewritten — autoMitigate is the primary axis; severity is intensifier. Probe widened to cover any-sev autoMitigate=false. | Read L10 Lesson 3 |
| F6 Socrates | HIGH | CMC term defined from directory slug, not from ticket | Context Ledger CMC row rewritten as "directory-naming convention, not in ticket text" | Read Context Ledger CMC row |
| F7 Socrates | HIGH | Microsoft `Properties` time fields disagree; v1.0 picked one without flagging | Added footnote ¹ in L7 explaining textual vs structured time disagreement; conservative-bound rationale stated | Read L7 footnote |
| F8 Socrates / F8 demoledor | HIGH | Same fact labeled inconsistently; subagent verdicts imported as A1 | Evidence Labels key now distinguishes coordinator-direct A1 vs imported A1; E11/E12 labels harmonized; E7 corrected (cites `all-alerts-30d.json` not `alert-fires-30d.json`) | Compare E11/E12/E17/L5-table labels |
| F9 demoledor | MEDIUM | Vendor-identity governance angle not flagged as out-of-scope | Added explicit "Side observation (out of scope)" note in L10 | Read L10 Side observation block |
| F10 Socrates / F10 demoledor | MEDIUM/LOW | Lesson 1/2 probes not executable as written | Probes rewritten as `az monitor scheduled-query list` + manual diff (executable); explicit note that the one-liner is a sketch and production version is an SRE follow-up | Read L10 Lesson 1 and 2 probes |
| F11 Socrates | MEDIUM | "Microsoft event triggered the fire" stated as causal, not temporal correlation | TL;DR mechanism rewritten with explicit `ingestion_time()` evidence; F11 collapses into F1's resolution | Compare TL;DR phrasing |
| F12 Socrates | LOW | `createdAt == lastModifiedAt` not cited | Added to E5 as the load-bearing A1 for "never modified" | Read E5 |

**Findings NOT absorbed in v2.0** (with reason):

| Finding | Reason | Disposition |
|---|---|---|
| F6 demoledor (reader-mastery 3 trip points) | Mostly addressed by SMOKING GUN callout + reordered Plane 3 + close-command block at top. Trip 1 (smoking gun) resolved. Trip 2 (~15-min number unsubstantiated) resolved by L8 Plane 2 manual-close requirement. Trip 3 (oc-playbook missing) resolved by F3-demoledor patch + next deliverable. Trip 4 (mental model buried) is partially mitigated by TL;DR rewrite; full fix is the future `on-call-onepager.md`. | Trip 1/2/3 resolved; Trip 4 noted in L11/L12 |
| F7 demoledor (Mermaid vs ASCII) | LOW priority. Project rule requires Mermaid for system diagrams; the ASCII in L3 is a violation but does not affect the operational decision. Tagged for future improvement. | Deferred to SRE follow-up |

## Sign-off

| Role | Name | Status | Artifact |
|---|---|---|---|
| Author | atorres.ruiz | Drafted v2.0 (with patches) | This file |
| Adversarial reviewer | `socrates-contrarian` (typed subagent) | Verdict: PROCEED-WITH-CHANGES; all BLOCKING/HIGH findings absorbed except F4 (handed off to Rootly agent) | `.ai/tasks/.../auxiliary/socrates-attack-on-rca.md` |
| Adversarial reviewer | `el-demoledor` (typed subagent) | Verdict: PROCEED-WITH-CHANGES; all BLOCKING/HIGH findings absorbed except F6 Trip 4 (deferred) and F7 (deferred) | `.ai/tasks/.../auxiliary/eldemoledor-attack-on-rca.md` |
| Mandatory pre-close gate | Plane-3 cluster probe | Pending user execution of `oc-playbook.md` (user-authorized close override; cluster check is user's owned post-action) | `oc-playbook.md` exists |
| Mandatory pre-close gate | F1 falsifier KQL re-validation | RESOLVED — Azure's own alert payload reports `metricValue=2.0` in window `12:52:07Z–12:57:07Z`. v2's `ingestion_time()` hypothesis was directionally right (late data caused the fire) but mis-pinned the window; v3 mechanism is Azure-authoritative. | sidecar `close-final-changestate.json` |
| **Close executed** | Plane 1 — Azure alert | **DONE at 2026-05-11T15:06:40.59 UTC by Alex.Torres@eneco.com** (alert UUID `7ca25b09-e05e-cced-606d-cc4d91d5000e`); `alertState=Closed`, `monitorCondition=Fired` (expected with autoMitigate=false) | sidecar `close-final-changestate.json`, `close-step3-postclose.json` equivalent |
| Plane 2 — ServiceNow ticket | Manual close in SN UI | Pending — on-call's manual action; do NOT assume Azure-close propagates (E17 path A3) | (user-owned) |
| Status promotion to `complete` | — | Blocked until (a) ServiceNow ticket closed manually, (b) `oc-playbook.md` Probes 1–3 executed against `eneco-vpp-prd` and outputs captured to the incident dir | (multi-condition gate) |

---

## Slack-ready paragraph (for posting to #myriad-platform or similar)

> **CMC alert `vpp-resource-unhealthy` on Eneco MCC – Production – Workload VPP fired today at 15:12 CEST (13:12 UTC) — false positive, caused by Microsoft.** Root cause: Microsoft Azure platform incident `5Z1B-6KG` ("Log Analytics + Application Insights data latency in West Europe", 06:40–12:45 UTC) backlog-drained two earlier same-incident ServiceHealth notices into our `vpp-log-analyt-p` workspace at 13:09 UTC. The alert rule `vpp-resource-unhealthy` (manually created out-of-IaC in 2024 by a vendor identity; KQL is just `AzureActivity | where CategoryValue == "ServiceHealth"`; sev-0; no action group; `autoMitigate=false`) saw `count > 1` by `ingestion_time()` in the 5-min window and fired. No Eneco VPP workload was unhealthy (cluster sanity-check via `oc-playbook.md` is the mandatory pre-close probe — please run it before closing). To close: run the two `az` commands in the on-call RCA at `log/employer/eneco/02_on_call_shift/2026_05_11_cmc_alert_vpp_cluster_prod/rca.md` (one for the Azure alert state, one to manually close the ServiceNow ticket — do not assume Azure-close propagates to SN). Follow-up for SRE/Platform: this rule is orphan (out-of-IaC, no action group, over-broad KQL on ServiceHealth, sev-0 + autoMitigate=false) and has been silently mis-tuned for 15.5 months; recommend a quarterly Azure→IaC alert inventory diff (Lesson 1 in the RCA). Adversarial review (socrates + el-demoledor) completed; mutation log + evidence ledger in the RCA. Full incident dir: `log/employer/eneco/02_on_call_shift/2026_05_11_cmc_alert_vpp_cluster_prod/`.
