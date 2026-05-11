---
task_id: 2026-05-11-005
slug: cmc-alert-vpp-cluster-prod
phase: 2
status: complete
agent: claude-opus-4-7
summary: Rootly past-hour alert cross-check against vpp-resource-unhealthy fire and Microsoft platform incident 5Z1B-6KG.
---

# Rootly Cross-Check — Past Hour

## Query window

`filter_started_at_gte = 2026-05-11T12:30:00Z` (≈90 min ago at check time).
Pulled at: `2026-05-11T14:02:20Z` (16:02 CEST).
Total alerts in window: **26** (Rootly API meta.total_count).

## Timeline of relevant external events

| Time (UTC) | Time (CEST) | Event | Source |
|---|---|---|---|
| 06:40 | 08:40 | Microsoft platform incident **5Z1B-6KG** begins — Log Analytics + AppInsights data latency in West Europe | Azure Activity ServiceHealth |
| 08:57 | 10:57 | Microsoft detects via automated monitoring | Azure Activity ServiceHealth |
| 11:05 | 13:05 | Microsoft increases capacity to recover | Azure Activity ServiceHealth |
| 12:45 | 14:45 | Microsoft declares **Mitigated** (impact end) | Azure Activity ServiceHealth |
| 13:10:36 | 15:10:36 | Microsoft "Mitigated" communication ingested into `vpp-log-analyt-p` workspace AzureActivity table | workspace KQL query |
| 13:12:43 | 15:12:43 | **`vpp-resource-unhealthy`** sev-0 alert fires (KQL matches the Mitigation notice) | Azure Alerts Management |
| ~15:13:50 | 15:13:50 | ServiceNow ticket created (3-min ServiceNow→connector lag) | ServiceNow intake |

## Rootly alerts in window — likely-related-to-incident

A2-INFER classification: all "likely related" claims are correlated by timing + path through Azure West Europe ingestion. Definitive causal proof needs Azure backplane internals (not available to me).

| Rootly short ID | Time (UTC) | Source | Alert | Status | Env | Relation hypothesis |
|---|---|---|---|---|---|---|
| `lJabX0` | 13:42:41 | azure | mcdta-vpp-IngestionLatency-KustoDynamic-d | acknowledged | DEV | A2: Kusto/ADX cluster `mcdta-...` ingestion delayed; Kusto and Log Analytics share underlying storage engine. Most likely related. |
| `4wgOPw` | 13:12:24 | azure | mcdta-vpp-IngestionLatency-KustoDynamic-d (earlier fire) | resolved (15m) | DEV | A2: same alert rule, second instance during the incident window |
| `KIXyMJ` | 13:55:14 | alertmanager | ContainerMemoryUsageHigh `otc-container` (otel-collector, eneco-vpp namespace) 94% | resolved | DEV | A2: OpenTelemetry collector memory pressure consistent with downstream Azure Monitor ingestion backpressure |
| `ZujltD` | 13:21:14 | alertmanager | ContainerMemoryUsageHigh `otc-container` 96% | resolved | DEV | A2: same collector pod, earlier in window |
| `tLcfNl` | 13:01:14 | alertmanager | ContainerMemoryUsageHigh `otc-container` 92% | resolved | DEV | A2: same collector pod, even earlier — consistent with extended ingestion delay |

## Rootly alerts in window — likely-unrelated

| Rootly short ID | Time (UTC) | Source | Alert | Env | Why unrelated |
|---|---|---|---|---|---|
| `oTiT7t` | 13:58:18 | alertmanager | KubernetesDeploymentReplicasMismatch `eneco-vpp-gurobi/gurobi-compute` | **PRD** | Fired 73 min after Microsoft mitigation; 31-second duration; transient cluster scheduling event |
| `INgINO`/`JRrsL1`/`Z8X7KI`/`nYs2EG` | 13:49 / 13:31 / 13:06 / 12:54 (UTC) | alertmanager | KubePodCrashLooping `eneco-vpp-asset-scheduling/inbox-ingestion` | DEV | Recurring throughout day; pattern predates Azure incident |
| `1K8JAM`/`l6AnCx` | 13:25 / 13:10 | dynatrace | "Problematic node condition" AKS node `aks-general-purpose-6ks8s` | — | A3 UNVERIFIED: cannot rule out without checking Dynatrace OneAgent ingestion path — but AKS node-level conditions are typically Dynatrace's own metrics, not Azure Monitor |
| `8kfyAT`/`wSmSJf`/`jEeWcQ`/`kLXFw9`/`kyGGno`/`n2iH3w`/`ydZ74B` | 12:50-13:22 | dynatrace | Job failure events | — | Dynatrace's own job pipeline — unlikely path-related |
| `6c21RZ` | 13:22:33 | live_call_routing | Phone call to vpp-core | — | Inbound phone call to on-call rotation, manual signal |

## Critical fact about `vpp-resource-unhealthy` and Rootly

The Azure rule `vpp-resource-unhealthy` has `actionGroups: null`. Therefore:

- It does NOT fire to any Rootly alert source.
- It does NOT appear in Rootly listAlerts output. **Confirmed**: no Rootly alert in the past hour references this rule name.
- The ServiceNow ticket exists via a parallel **Azure → ServiceNow connector** path (not Action Group → Rootly).

This explains why the user got a ServiceNow page but no Rootly page for the same event. They are two independent signal streams.

## Implications for on-call

Three open paging surfaces, three different lifecycles:

| Surface | State | Auto-close? | Required action |
|---|---|---|---|
| ServiceNow ticket for `vpp-resource-unhealthy` | Open, not acknowledged | NO (Azure rule has `autoMitigate=false`) | Manually close the Azure alert in portal AND close the ServiceNow ticket |
| Rootly `inbox-ingestion CrashLoopBackOff` (DEV) | Still triggered (`INgINO`) | Yes when pod stabilizes | Separate investigation; not related to today's RCA |
| Rootly `mcdta-vpp-IngestionLatency-KustoDynamic-d` (DEV) | Acknowledged | Yes when Azure backlog drains | Likely self-resolves as Microsoft platform recovers; verify in ~30 min |

## Evidence key for this section

- **A1 FACT**: Rootly listAlerts API response (cited filter window), Microsoft `eventSubmissionTimestamp` value, Azure CLI `az monitor scheduled-query show` output (sidecar `azure-alert-rule-raw.json`).
- **A2 INFER**: causal attribution of Rootly alerts to Microsoft incident — based on time correlation + path-through-shared-infra reasoning; not proven by backplane traces.
- **A3 UNVERIFIED**: Dynatrace alert relation — would need to confirm whether Dynatrace OneAgent's ingestion route passes through the affected West Europe Log Analytics path.
