---
task_id: 2026-03-09-001
agent: architect-kernel
status: complete
summary: First-principles explanation of Service Bus topic size alert — mechanics, lifecycle, worked example
---

# Alert Explanation: `mcdta-vpp-sb-vpp-sbus-d-topic-size-d-warning`

This document explains the Azure Monitor metric alert for Service Bus topic size from first principles. It is written for an engineer who has been paged and needs to understand exactly what triggered, why, and what the numbers mean before deciding how to respond.

---

## 1. Azure Service Bus: The Pub/Sub Substrate

Azure Service Bus is a message broker. The relevant hierarchy is:

```
Namespace (vpp-sbus-d)
 └── Topic (e.g., assetplanning-asset-strike-price-schedule-created-v1)
      ├── Subscription A (e.g., asset-scheduling-gateway)
      ├── Subscription B
      └── Subscription C
```

**Namespace** is the top-level container. It is a deployed resource with its own FQDN (`vpp-sbus-d.servicebus.windows.net`), its own throughput units, and its own billing. All topics live inside a namespace.

**Topic** is a named message channel. Producers publish messages to a topic. A topic does not deliver messages directly to consumers. It fans out to subscriptions.

**Subscription** is a named cursor on a topic. Each subscription gets an independent copy of every message published to the topic. A consumer application connects to a subscription, reads messages, and completes them (acknowledges). Completing a message removes it from that subscription.

The critical property is this: **a message occupies space in a topic for as long as ANY subscription has not consumed it** (or until the message's time-to-live expires, whichever comes first). If a topic has 3 subscriptions and 2 are healthy but 1 is stopped, the messages accumulate because the stopped subscription still holds references to them. The topic cannot reclaim that storage until every subscription has either consumed or abandoned the message.

This is the fundamental reason a single slow or stopped consumer causes topic size growth. The broker retains messages for the slowest reader.

## 2. The `Size` Metric — What It Measures

The `Size` metric on `Microsoft.ServiceBus/Namespaces` reports the **total byte footprint of all active (not-yet-expired, not-yet-completed) messages stored in a topic**, summed across all its subscriptions' active message stores.

Key properties:

- **Unit: bytes.** Not kilobytes, not megabytes. A reported value of `545,782,443` means 545,782,443 bytes = ~520.50 MiB.
- **Grows when:** new messages arrive faster than consumers drain them, OR when a consumer stops entirely (messages accumulate with no drain).
- **Shrinks when:** consumers process (complete) messages, OR messages expire via TTL and the broker garbage-collects them.
- **Scope:** per-topic when dimension-split on `EntityName` (explained in section 4).

Why bytes instead of message count? Because message payload size varies. A topic holding 100 messages of 4 MB each (400 MB total) is far closer to its capacity limit than a topic holding 50,000 messages of 1 KB each (50 MB total). The `Size` metric tracks the resource that actually runs out: storage bytes.

Related metrics that this alert does NOT use:

| Metric | What it measures | Why not used here |
|--------|-----------------|-------------------|
| `ActiveMessageCount` | Number of messages ready for delivery | Does not reflect storage pressure |
| `DeadLetteredMessages` | Messages moved to DLQ | Different failure mode |
| `ScheduledMessages` | Messages with future delivery time | Not relevant to backlog |

## 3. Azure Monitor Metric Alert Lifecycle (First Principles)

The alert evaluates on a fixed cycle. Here is the exact sequence:

**Step 1 — Metric emission.** Azure Service Bus emits the `Size` metric with a resolution of 1 minute (PT1M). Every minute, each topic's current byte size is recorded as a data point.

**Step 2 — Evaluation frequency.** Azure Monitor evaluates the alert rule every 1 minute (frequency = PT1M). This means every 60 seconds, the alert engine wakes up and runs the evaluation logic.

**Step 3 — Lookback window.** At each evaluation, the engine looks back over a 5-minute window (window = PT5M). It collects all `Size` data points for the last 5 minutes.

**Step 4 — Aggregation.** Within that 5-minute window, it computes the **Maximum** value across all data points. This means: if any single 1-minute sample in the last 5 minutes exceeded the threshold, the aggregated value exceeds the threshold. Maximum aggregation is the most conservative (most sensitive) choice — a single spike triggers it.

**Step 5 — Threshold comparison.** It checks: `Maximum > 400,000,000` bytes? (GreaterThan, not GreaterThanOrEqual.) If the maximum value across the window is 400,000,001 bytes or more, the condition is met.

**Step 6 — State transition.** If condition is met for ANY topic (due to dimension splitting), the alert transitions from `Healthy` to `Fired`.

**Step 7 — Action groups fire.** The alert triggers its configured action groups, which send webhooks, create incidents, and page on-call (detailed in section 7).

**Step 8 — Auto-mitigation.** Because `autoMitigate = true`, once the Maximum value in the evaluation window drops back below 400,000,000 bytes, the alert automatically transitions from `Fired` back to `Resolved`. No human intervention is needed to clear the alert state.

### Timeline: Consumer Failure to Page

```
Time   Event                                          Topic Size
─────  ─────────────────────────────────────────────── ──────────
T+0    Consumer pod crashes                            300 MB
T+1    Messages arrive, no drain                       310 MB
T+2    Messages arrive, no drain                       320 MB
       ...
T+8    Size crosses 400 MB                             405 MB
       ┌──────────────────────────────────────────┐
T+9    │ Azure Monitor evaluates:                  │
       │   Window = [T+4 .. T+9]                   │
       │   Max(310, 320, 340, 370, 405) = 405 MB   │
       │   405,000,000 > 400,000,000? YES           │
       │   Alert state: Healthy → Fired             │
       └──────────────────────────────────────────┘
T+9    Action groups triggered → webhooks fire
T+9    Rootly receives webhook → creates incident → pages on-call
T+10   Engineer receives page
```

The delay from consumer failure to page depends entirely on the message ingestion rate. With a starting size well below threshold and a slow producer, it could take hours. With a starting size near threshold and a fast producer, it fires within minutes.

## 4. Dimension Splitting: EntityName = *

The alert is configured with dimension filter `EntityName = *`. This is critical to understand correctly.

Without dimension splitting, Azure Monitor would aggregate the `Size` metric across all 252 topics in the namespace into a single time series. That would be useless: you would get the sum of all topic sizes, which tells you nothing about individual topic health.

With `EntityName = *`, Azure Monitor creates **one independent evaluation per topic**. Each of the 252 topics gets its own time series, its own 5-minute window, and its own threshold comparison. The portal displays this as "252 time series monitored."

The consequence: the alert fires if **any single topic** exceeds 400 MB. Not the average. Not the sum. Any one topic.

This is the correct design. The failure mode you care about is a specific topic filling up and rejecting messages. A namespace where 251 topics are at 1 MB and 1 topic is at 900 MB is in danger. A namespace where all 252 topics are at 100 MB each (25.2 GB total) is healthy. Dimension splitting captures this distinction.

When the alert fires, the alert payload includes the `EntityName` dimension value that triggered it. This tells you which specific topic breached the threshold without requiring manual investigation.

## 5. Threshold Rationale: Why 400 MB?

Each topic in this namespace has a maximum size of **1,024 MB** (1 GiB). This is configured at the topic level in Service Bus.

When a topic reaches its maximum size, the broker **rejects new messages** from producers. The producer receives a `QuotaExceededException`. Messages are not queued, not buffered, not retried by the broker. They are rejected at the protocol level. If the producer does not handle this exception with retry logic, those messages are lost.

The thresholds create a two-stage warning system:

```
0 MB                    400 MB              800 MB           1,024 MB
 |────── healthy ────────|──── WARNING ──────|─── CRITICAL ───|── FULL ──
                         39% of max          78% of max       100%
                         624 MB headroom     224 MB headroom  0 MB
                                                              Messages REJECTED
```

| Level | Threshold | % of Max | Headroom | Meaning |
|-------|-----------|----------|----------|---------|
| WARNING | 400,000,000 bytes (~381 MiB) | 39% | ~624 MB | Investigate. Consumer is likely lagging or stopped. |
| CRITICAL | 800,000,000 bytes (~763 MiB) | 78% | ~224 MB | Act immediately. Topic will fill within hours. |
| FULL | 1,073,741,824 bytes (1,024 MiB) | 100% | 0 | Producers receive `QuotaExceededException`. Data loss risk. |

The warning threshold at 39% is deliberately early. It gives the team a substantial buffer to investigate the root cause (identify which subscription is lagging, determine why the consumer stopped, restart or redeploy) before the topic approaches capacity.

The gap between warning (400 MB) and critical (800 MB) is 400 MB. At a typical ingestion rate, this gap represents hours of additional runway, ensuring the team has time to respond even if the warning is initially missed.

## 6. Worked Example: Current Breach

The topic `assetplanning-asset-strike-price-schedule-created-v1` is currently at **520.50 MB** (545,782,443 bytes).

The consumer `asset-scheduling-gateway` has **3,756 unread messages** in its subscription.

### Calculating average message size

```
Total topic size:    545,782,443 bytes
Unread messages:     3,756
Average message size: 545,782,443 / 3,756 = 145,322 bytes ~ 145 KB per message
```

(This is approximate — it assumes one subscription is responsible for the bulk of retained messages. If other subscriptions are current, the retained size is dominated by this subscription's backlog.)

### Scenario A: Consumer resumes processing at 50 messages/minute

```
Backlog:         3,756 messages
Processing rate: 50 messages/minute
Drain time:      3,756 / 50 = 75.1 minutes ~ 1 hour 15 minutes

During drain (assuming producers still publish at 20 msg/min):
  Net drain rate:    50 - 20 = 30 messages/minute
  Effective drain:   3,756 / 30 = 125 minutes ~ 2 hours 5 minutes
  Topic size trend:  decreasing at ~30 x 145 KB/min = 4.25 MB/min
  Time to drop below 400 MB: (520 - 400) / 4.25 = ~28 minutes
  Alert auto-resolves ~28 minutes after consumer resumes
```

### Scenario B: Consumer remains stopped, producers continue at 20 messages/minute

```
Current size:    520.50 MB
Ingestion rate:  20 messages/minute x 145 KB = 2.83 MB/minute = ~170 MB/hour

Projection:
  Now:          520 MB  (WARNING — already breached)
  +1 hour:      690 MB  (approaching CRITICAL)
  +1h 39min:    800 MB  (CRITICAL threshold breached)
  +2h 58min:  1,024 MB  (FULL — producers start receiving QuotaExceededException)

Time from now to data loss risk: approximately 3 hours
Time from now to CRITICAL alert:  approximately 1 hour 40 minutes
```

### Scenario C: Consumer stopped AND producer burst (100 messages/minute)

```
Ingestion rate:  100 x 145 KB = 14.2 MB/minute

Time to CRITICAL:  (800 - 520) / 14.2 = ~20 minutes
Time to FULL:      (1,024 - 520) / 14.2 = ~35 minutes
```

This scenario demonstrates why the 39% warning threshold exists. A producer burst combined with a stopped consumer can fill a topic in under an hour.

## 7. The Action Group Chain — How You Got Paged

When the alert fires, it triggers **3 action groups simultaneously**:

```
Alert Fires
 │
 ├──► ag-trade-platform-d
 │     └──► Webhook: rootly-trade-platform
 │           └──► Rootly receives payload
 │                 └──► Rootly creates incident
 │                       └──► On-call engineer paged
 │
 ├──► eneco-vpp-service-bus-topic-size-actiongroup
 │     └──► Webhook: Logic App endpoint
 │           └──► Logic App processes alert payload
 │                 └──► Posts to Slack #myriad-alerts-devops
 │
 └──► eneco-vpp-devops-actiongroup
       └──► (no receivers configured in dev environment — no-op)
```

The critical path is the first one: `ag-trade-platform-d` sends a webhook to Rootly, which creates an incident and pages the on-call engineer. This is why you were woken up.

The Slack notification via the Logic App is informational. The third action group is a no-op in the dev (`-d`) environment — it exists in the Terraform configuration but has no active receivers.

All three action groups fire in parallel. There is no dependency chain between them. If Rootly's webhook endpoint is down, the Slack notification still fires (and vice versa).

## 8. What This Alert Does NOT Tell You

The alert payload tells you:
- Which topic exceeded the threshold (`EntityName` dimension)
- The metric value at the time of firing
- When it fired

The alert payload does NOT tell you:

| Missing Information | Why it matters | How to get it |
|---------------------|----------------|---------------|
| Which subscription is lagging | A topic with 5 subscriptions could have 1 lagging and 4 healthy | `az servicebus topic subscription list --namespace-name vpp-sbus-d --resource-group <rg> --topic-name <topic> -o table` then check `messageCount` per subscription |
| Why the consumer stopped | Could be: pod crash, failed deployment, network partition, application bug, resource exhaustion, poison message | Check consumer pod status (`kubectl get pods`), logs, recent deployments |
| Producer surge vs. consumer down | Both produce identical metric growth — size increases either way | Compare `IncomingMessages` metric (producer rate) with `CompleteMessage` metric (consumer rate) over time |
| Per-subscription size | The `Size` metric is per-topic, not per-subscription | Query subscriptions individually via CLI or portal |
| Dead-letter queue state | Messages could be dead-lettering instead of processing | Check `DeadLetteredMessages` metric or `deadLetterMessageCount` on the subscription |

The alert is a smoke detector. It tells you there is smoke. It does not tell you which room is on fire or what started it. The investigation steps above are how you move from "alert fired" to "root cause identified."

## 9. Known Limitation: Description Bug in IaC

The alert's description field currently reads:

> "Action will be triggered when any topic exceeds size of 400000000Mb"

This is generated in Terraform at `metric-alert-service-bus.tf:107`:

```hcl
description = "...size of ${each.value.threshold}Mb"
```

The bug: `each.value.threshold` is `400000000` (the value in **bytes**). The template appends `Mb` (megabytes). The resulting string reads as "400 million megabytes," which is ~381 petabytes.

The actual threshold is 400,000,000 **bytes** = ~381 MiB = ~400 MB.

This is a cosmetic bug in the description string only. The actual alert logic evaluates correctly against 400,000,000 bytes. The metric is emitted in bytes, the threshold is set in bytes, and the comparison operates in bytes. Only the human-readable description is wrong.

The fix is straightforward — change the template to convert bytes to MB:

```hcl
description = "...size of ${each.value.threshold / 1000000} MB"
```

Or, for precision:

```hcl
description = "...size of ${each.value.threshold} bytes (~${each.value.threshold / 1000000} MB)"
```

Until fixed, responders should ignore the unit in the description and treat the number as bytes.
