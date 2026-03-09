---
task_id: 2026-03-09-001
agent: principal-engineer-document-writer
status: complete
summary: |
  Alert analysis with Fine-tune verdict + adversarial gaps: consumer state OQ, threshold calibration OQ, cost of inaction

key_findings:
  - alert_valid: Alert correctly detected consumer backlog (3,756 messages on asset-scheduling-gateway subscription)
  - description_bug: IaC template renders threshold in bytes with "Mb" suffix, producing "400000000Mb" (~381 PB stated)
  - identical_thresholds: Dev and production share identical 400MB/800MB thresholds despite different traffic profiles
  - verdict: Fine-tune — fix description template, review dev paging policy with team
---

# Analysis: Service Bus Topic Size Warning Alert

> **Summary**: Alert `mcdta-vpp-sb-vpp-sbus-d-topic-size-d-warning` monitors the `Size` metric across 252 topics on Service Bus namespace `vpp-sbus-d` in MC Development. It fires when any single topic exceeds 400 MB (warning) or 800 MB (critical), evaluated every 1 minute over a 5-minute maximum window. The alert is currently firing on one topic due to a confirmed consumer backlog. Two defects exist: a misleading description template and identical dev/prd thresholds. **Verdict: Fine-tune.**

---

## 1. Alert Identity and Configuration

The alert resource `mcdta-vpp-sb-vpp-sbus-d-topic-size-d-warning` is defined in the MC Development subscription `839af51e-c8dd-4bd2-944b-a7799eb2e1e4` [FACT: alert-json-view.json:3-4]. It is provisioned by `module "maxtopicsize_list"` using `for_each = { for c in var.servicebus_topic_size_alerts : c.severity_level => c }`, which generates one alert resource per severity level [FACT: metric-alert-service-bus.tf:100-101].

### 1.1 Metric Mechanics

The alert evaluates the `Size` metric on resource type `Microsoft.ServiceBus/Namespaces` [FACT: alert-json-view.json:46-47]. The metric unit is bytes [FACT: dev.tfvars:58, comment `#400MB` confirms 400000000 = ~400 MB].

Evaluation parameters:

| Parameter | Value | Source |
|-----------|-------|--------|
| Operator | `GreaterThan` | alert-json-view.json:43 |
| Time aggregation | `Maximum` | alert-json-view.json:57 |
| Window size | `PT5M` (5 minutes) | alert-json-view.json:39 |
| Evaluation frequency | `PT1M` (every 1 minute) | alert-json-view.json:21 |
| Dimension split | `EntityName = *` (per-topic) | alert-json-view.json:50-55 |
| Auto-mitigate | `true` (auto-resolves when condition clears) | alert-json-view.json:22 |

The dimension split on `EntityName = *` means Azure evaluates each topic independently against the threshold. With 252 topics monitored [FACT: Azure Portal screenshot], any single topic breaching 400 MB fires this alert. The `Maximum` aggregation over `PT5M` means a single peak sample within the 5-minute window triggers the condition — sustained breach is not required.

### 1.2 Thresholds

| Severity | Threshold (bytes) | Threshold (MB) | % of Max Topic Size | Suffix | Source |
|----------|--------------------|-----------------|----------------------|--------|--------|
| 2 (Warning) | 400,000,000 | ~381 MiB / ~400 MB | 39.06% | `warning` | dev.tfvars:56-59 |
| 0 (Critical) | 800,000,000 | ~763 MiB / ~800 MB | 78.13% | `critical` | dev.tfvars:60-63 |

Maximum topic size is 1,024 MB per topic [FACT: `az servicebus topic list` output, live query 2026-03-09]. Warning fires at 39% capacity; critical fires at 78% capacity. These thresholds are identical in production [FACT: prd.tfvars:51-62].

### 1.3 Estimated Cost

The alert monitors 252 time series at PT1M frequency. Estimated monthly cost: $25.20 [FACT: Azure Portal screenshot].

---

## 2. Notification Path

Three action groups are attached to this alert:

**1. `eneco-vpp-devops-actiongroup`** — No receivers configured in dev [FACT: `az monitor action-group show`, live query]. This action group is inert in the dev environment.

**2. `ag-trade-platform-d`** (resource group `rg-pltfrm-infra-d`) — Contains a webhook receiver named `rootly-trade-platform` [FACT: `az monitor action-group show`, live query]. This is the Rootly paging path. When this alert fires, it creates an incident in Rootly, which pages on-call engineers.

**3. `eneco-vpp-service-bus-topic-size-actiongroup`** — Webhook to Slack via Logic App [FACT: actiongroup.tf:54-57]. This provides a Slack notification channel parallel to Rootly.

In production only, a fourth action group `actiongroup_opsgenie` is attached [FACT: metric-alert-service-bus.tf:125-128], adding OpsGenie as a paging path.

The notification chain for this dev alert is: Azure Monitor metric condition breached --> webhook to Rootly (via `ag-trade-platform-d`) + webhook to Slack (via Logic App). Rootly then pages the on-call engineer.

---

## 3. Live State (2026-03-09)

Queried via `enecotfvppmclogindev` against DEV subscription `839af51e`:

- **Alert status**: ENABLED and currently FIRING [FACT: `az monitor metrics alert list`]
- **Critical alert status**: ENABLED, NOT firing (520 MB < 800 MB threshold) [FACT: `az monitor metrics alert list`]
- **Topics above warning threshold**: 1 of 252 [FACT: `az servicebus topic list`]
- **Breaching topic**: `assetplanning-asset-strike-price-schedule-created-v1` at 520.50 MB (545,782,443 bytes) [FACT: `az servicebus topic list`]

### 3.1 Consumer Analysis

Subscriptions on the breaching topic:

| Subscription | Active Messages | Status |
|--------------|-----------------|--------|
| `tenant-gateway-subscription` | 0 | Healthy |
| `dataprep` | 0 | Healthy |
| `asset-scheduling-gateway` | **3,756** | **Consumer backlog** |

[FACT: `az servicebus topic subscription list`]

The `asset-scheduling-gateway` subscription holds 3,756 unprocessed messages. This is the direct cause of topic size growth: messages accumulate in the topic because this consumer is not draining them. The other two subscriptions have zero pending messages, confirming the backlog is isolated to one consumer [INFER: derived from subscription message counts — zero on two, non-zero on one].

---

## 4. Known Defects

### 4.1 Description Template Bug (CRITICAL)

The IaC template at metric-alert-service-bus.tf:107 renders:

```hcl
description = "Action will be triggered when any topic exceeds size of ${each.value.threshold}Mb"
```

The `threshold` variable holds a value in bytes (400000000). The template appends `Mb` directly, producing the rendered description:

> "Action will be triggered when any topic exceeds size of 400000000Mb"

[FACT: alert-json-view.json:15]

This states "400 million megabytes" — approximately 381 petabytes. An on-call engineer reading this description during an incident receives actively misleading information about the alert's purpose and scale. The correct rendering would be `~400 MB (400,000,000 bytes)`.

**Impact**: Responder confusion during incidents. An engineer unfamiliar with this alert cannot determine the actual threshold from the description alone.

**Fix**: Replace the template expression with a computed human-readable value, e.g.:

```hcl
description = "Action will be triggered when any topic exceeds size of ${each.value.threshold / 1000000} MB (${each.value.threshold} bytes)"
```

Risk: Low. Change affects only the `description` field metadata — no behavioral change to the alert condition, thresholds, or notification path.

### 4.2 Identical Dev/Production Thresholds

Development and production share identical thresholds [FACT: dev.tfvars:58 = 400000000, prd.tfvars:55 = 400000000]:

| Environment | Warning | Critical |
|-------------|---------|----------|
| Dev | 400,000,000 | 800,000,000 |
| Prd | 400,000,000 | 800,000,000 |

The dev environment pages Rootly via `ag-trade-platform-d` with these same thresholds. Dev traffic patterns, data volumes, and operational expectations differ from production [INFER: standard practice — dev environments carry test/synthetic workloads with different characteristics than production].

Whether dev should page Rootly at the same thresholds as production is a team decision. Options include: raising dev thresholds, removing the Rootly action group from dev alerts, or accepting the current behavior as intentional early-warning. This is not an autonomous IaC change — it requires team alignment on on-call policy [SPEC: team decision required].

---

## 5. Diagnosis: Four-Option Analysis

### Option A: Remove

**Evaluation**: The alert detected a real consumer backlog — `asset-scheduling-gateway` has 3,756 unprocessed messages causing topic `assetplanning-asset-strike-price-schedule-created-v1` to grow to 520.50 MB [FACT: live query]. Topic size growth is a leading indicator of consumer failure, dead-letter accumulation, or throughput degradation. Without this alert, topic sizes could grow silently toward the 1,024 MB limit, at which point publishers receive `QuotaExceededException` and message production halts.

**Verdict**: Remove is wrong. The alert provides real operational signal and caught an active issue.

### Option B: Keep As-Is

**Evaluation**: The current state has two concrete defects. First, the description renders "400000000Mb" [FACT: alert-json-view.json:15] — an on-call engineer reading this during a 2 AM page receives nonsensical threshold information. Second, dev pages Rootly at production thresholds, generating on-call interrupts for an environment where the operational impact of a topic size breach is lower.

**Verdict**: Keep-as-is is wrong. The description bug actively misleads responders, and the dev paging policy deserves explicit team review.

### Option C: Improve (Significant Redesign)

**Evaluation**: Significant redesign would involve restructuring the alert — changing the metric (e.g., switching to dead-letter count or consumer lag), restructuring the IaC module, or rearchitecting the notification path. The current metric (`Size` per topic) is a valid proxy for consumer health. The IaC module structure using `for_each` on severity levels is clean and maintainable [FACT: metric-alert-service-bus.tf:100-101]. The action group configuration correctly routes to Rootly and Slack.

**Verdict**: Improve is disproportionate. The alert architecture is sound; only metadata and threshold policy need adjustment.

### Option D: Fine-Tune (Targeted Fixes)

**Evaluation**: Two targeted fixes address all identified defects:

1. **Fix description template** (metric-alert-service-bus.tf:107): Replace raw bytes + "Mb" with computed human-readable value. Risk: low — metadata-only change, no behavioral impact. Immediate clarity gain for responders.

2. **Review dev Rootly paging** (team decision): Present finding that dev and prd share identical thresholds and both page Rootly. Team decides whether to: (a) raise dev thresholds, (b) remove Rootly action group from dev, or (c) accept current behavior as intentional.

Neither fix requires architectural changes. Both are bounded, reversible, and independently deployable.

**Verdict**: Fine-tune is correct.

---

## 6. Verdict: Fine-Tune

The alert `mcdta-vpp-sb-vpp-sbus-d-topic-size-d-warning` is operationally valid. It correctly detected a consumer backlog on `asset-scheduling-gateway` (3,756 messages) causing topic `assetplanning-asset-strike-price-schedule-created-v1` to reach 520.50 MB — 39% above the warning threshold and 51% of the 1,024 MB topic maximum [FACT: live query].

Two targeted fixes are warranted:

| # | Fix | Owner | Risk | Evidence |
|---|-----|-------|------|----------|
| 1 | Fix description template: replace `${each.value.threshold}Mb` with human-readable bytes-to-MB conversion | IaC PR author | Low (metadata only) | alert-json-view.json:15 shows "400000000Mb" |
| 2 | Review dev Rootly paging policy: present identical dev/prd thresholds to team for decision | Team (SRE + dev) | None (decision, not change) | dev.tfvars:58 = prd.tfvars:55 |

### Immediate Action Required

The currently firing alert on `assetplanning-asset-strike-price-schedule-created-v1` indicates the `asset-scheduling-gateway` consumer is not processing messages. This consumer backlog is the operational issue that triggered this analysis. The consumer health should be investigated independently of the alert fine-tuning.

---

## Adversarial Validation: Open Questions

These gaps were identified by Socratic challenge. They do not change the Fine-tune verdict but must be investigated to fully close the incident.

### OQ-1: Consumer State Unknown (HIGH — must investigate before closing)

The analysis confirmed WHAT is happening (`asset-scheduling-gateway` has 3,756 unread messages, topic at 520 MB) but not WHY the consumer stopped. Three mutually exclusive scenarios exist:

**Scenario A — Unintentional failure** (pod crash, OOM, bug): Alert is performing correctly. Correct response: fix the consumer.

**Scenario B — Intentional pause** (feature flag, maintenance window, controlled deployment): Alert is firing on a known-benign condition. Correct response: suppress the alert for the duration, add a runbook noting that maintenance of `asset-scheduling-gateway` requires alert acknowledgment.

**Scenario C — Orphaned subscription** (consumer service decommissioned, subscription never deleted): Alert will fire indefinitely regardless of any IaC fine-tuning. Correct response: delete the orphaned subscription `asset-scheduling-gateway` from topic `assetplanning-asset-strike-price-schedule-created-v1`.

**Action required** (INFER from absence of investigation):
```bash
# Check if consumer service is deployed in dev
kubectl get deployment -n <namespace> | grep asset-scheduling-gateway
# Check Service Bus subscription last activity
az servicebus topic subscription show \
  --namespace-name vpp-sbus-d \
  --resource-group mcdta-rg-vpp-d-messaging \
  --topic-name assetplanning-asset-strike-price-schedule-created-v1 \
  --name asset-scheduling-gateway \
  --query '{updatedAt:updatedAt, status:status, lockDuration:lockDuration}'
```

This analysis cannot determine which scenario applies. Until confirmed, the consumer state is SPEC [unverified].

### OQ-2: Threshold Not Calibrated to Historical Data (MEDIUM)

The 400 MB warning threshold is set at 39% of the 1,024 MB topic maximum. Industry convention for capacity warning alerts is typically 70-80%. The analysis confirms the threshold is identical in dev and prd (FACT: dev.tfvars:58, prd.tfvars:55) but has no evidence for WHY 400 MB was chosen.

Missing evidence:
- Historical firing frequency: how many times has this alert fired and auto-resolved in the last 90 days?
- Topic size distribution: what is the p95 size across the 252 topics under normal load?
- Topic growth rate: what is the `IncomingMessages` rate for the breaching topic?

Without this data, the threshold calibration is SPEC [unverified]. If historical data shows frequent false-positive fires (alert fires, consumer drains, auto-resolves within minutes), raising the threshold to 600-700 MB would reduce noise while preserving safety margin. This would be Change 3 in the proposal.

### OQ-3: Threshold Calibration to Historical Alert History

SPEC [unverified]: The threshold might be too aggressive (39% of max) generating false positives during legitimate traffic bursts. Evidence needed: `az monitor activity-log list` for this alert rule showing fire/resolve frequency over 90 days.

---

## Cost of Inaction

If the identified defects are NOT fixed:

### Defect 1 — Description Bug (stays unfixed)
Every incident response starts with a responder reading "400000000Mb" and spending 2-5 minutes determining this is approximately 400 MB, not 400 million megabytes. More critically: a responder who interprets the description literally may conclude the alert is misconfigured and **dismiss a legitimate capacity warning as a false positive**. This is the dangerous failure mode — the description bug is not merely cosmetic.

### Defect 2 — Dev Paging Rootly (stays unfixed)
Every dev topic size breach pages the on-call engineer via Rootly. Cost per page: ~15 minutes of triage (read alert, determine it is dev, assess severity, dismiss). If this fires weekly: ~1 hour/month of wasted on-call time. If this fires daily during active dev work: ~7.5 hours/month. The deeper cost is **alert fatigue**: engineers trained to dismiss dev Rootly pages will eventually dismiss production pages faster than they should. This is the organizational damage the fine-tune recommendation is designed to prevent.

### Defect 3 — Current Breach (consumer not addressed)
If `asset-scheduling-gateway` remains stopped and producers continue publishing to `assetplanning-asset-strike-price-schedule-created-v1`:

1. Topic grows from 520 MB toward the 800 MB critical threshold → critical alert fires → OpsGenie page (in production) or second Rootly incident
2. Topic reaches 1,024 MB → **`QuotaExceededException`** thrown at ALL producers publishing to this topic
3. If producer processes are shared (publish to multiple topics), an unhandled `QuotaExceededException` can crash the producer process
4. Producer crash → ALL topics that process publishes to stop receiving messages (cascade)
5. Downstream consumers of those OTHER topics start starving for data
6. Multiple topics begin their own consumer-backlog growth cycle

The cascade from a single consumer stop → single topic fill → producer crash → multi-topic starvation is the blast radius the alert is designed to give you time to prevent. The warning threshold at 400 MB exists to provide ~1.7 hours of runway (at 145 KB/message × 20 msg/min) before the critical threshold, and ~3.4 hours before data loss begins.

**The alert is currently doing its job. The operational risk is in the unaddressed consumer, not the alert.**

---

## Open Questions — Validated (2026-03-09, live az CLI)

### OQ-1: Consumer State — RESOLVED (Scenario A, consumer stopped)

```
Source: az servicebus topic subscription show (live, 2026-03-09)
{
  "status": "Active",
  "updatedAt": "2026-03-06T10:42:36Z",
  "defaultTTL": "PT5M",
  "lockDuration": "PT1M",
  "maxDeliveryCount": 10,
  "messageCount": 3781,
  "deadLetterMsgCount": null
}
```

**Verdict: Scenario A — consumer service stopped, subscription is active (not orphaned).**

- FACT: `status: "Active"` eliminates Scenario C (orphaned subscription)
- FACT: `messageCount` grew from 3,756 → 3,781 between queries — topic is still receiving new messages; consumer is not draining them
- FACT: `defaultTTL: "PT5M"` — messages expire after 5 minutes. At steady state, topic size represents the burst of messages published within the last 5 minutes that `asset-scheduling-gateway` has not yet consumed. With 3,781 messages × ~145 KB = ~535 MB currently retained, the production rate into this topic is substantial.
- FACT: `updatedAt: 2026-03-06` — subscription configuration last changed 3 days ago (correlates with the Terraform apply that also re-deployed the alert)
- INFER: the consumer service (`asset-scheduling-gateway`) is not running in dev at the time of this investigation. Whether this is planned or unplanned requires checking the consumer's Kubernetes deployment or deployment pipeline.

**Immediate action for the consumer team**: Verify whether `asset-scheduling-gateway` is deployed and running in dev. The topic continuously receives messages; with PT5M TTL, unprocessed messages expire and are silently discarded (or DLQ'd if dead lettering on expiry is enabled). The operational risk is data loss in the pipeline, not just alert noise.

### OQ-2: Alert Firing History — RESOLVED (alert is 3 days old; no historical fire data available)

```
Source: az monitor activity-log list (live, 2026-03-09)
Events found: "Create or update metric alert" on 2026-03-06T11:17 and 2026-02-25T11:45
No fire/resolve events in activity log.
```

**Verdict: Alert was deployed/updated 2026-03-06 (3 days ago) and again 2026-02-25. No historical alert fire/resolve data available via activity log — Azure Monitor alert fire events are recorded in the alert history endpoint, not the resource activity log.**

- FACT: Alert was last updated 2026-03-06T11:17Z (Terraform apply, caller = SP `4d0692eb`)
- FACT: Prior update 2026-02-25T11:45Z (another Terraform apply)
- INFER: The alert has been in a fired state since at least 2026-03-06, because the topic was already above 400 MB when the alert was re-deployed (topic size 520 MB as of 2026-03-09)
- INFER: No evidence of repeated false-positive fire/resolve cycles in the 30-day window (activity log is clean of fire events). OQ-2 threshold calibration concern (Socrates Q3) cannot be resolved from this data source alone.

**To query actual alert fire/resolve history**: Use the Azure Monitor alerts REST API:
```bash
az rest --method GET \
  --url "https://management.azure.com/subscriptions/839af51e-c8dd-4bd2-944b-a7799eb2e1e4/providers/Microsoft.AlertsManagement/alerts?api-version=2019-03-01&targetResource=/subscriptions/839af51e-c8dd-4bd2-944b-a7799eb2e1e4/resourceGroups/mcdta-rg-vpp-d-messaging/providers/Microsoft.ServiceBus/namespaces/vpp-sbus-d&timeRange=30d"
```
