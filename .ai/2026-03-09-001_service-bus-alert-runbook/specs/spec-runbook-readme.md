---
task_id: 2026-03-09-001
agent: coordinator
status: draft
summary: Specification for README.md SRE runbook for Service Bus Topic Size Warning
---

# Spec: SRE Runbook README.md

## Summary
A comprehensive Rootly-page-ready runbook for the `mcdta-vpp-sb-vpp-sbus-d-topic-size-d-warning` alert. Engineers paged by Rootly must be able to triage, identify root cause, and execute resolution within 30 minutes with zero prior knowledge of this alert.

## Output
`log/employer/eneco/00_incident_sre/01_alert_service_bus_topic_size_warning/runbook/README.md`

## Verified Live Facts (from context/)
- Alert: `mcdta-vpp-sb-vpp-sbus-d-topic-size-d-warning`, Sev2, FIRED since 2026-03-08T10:24:27Z
- Subscription: `839af51e-c8dd-4bd2-944b-a7799eb2e1e4`
- Namespace: `vpp-sbus-d` (Premium, westeurope), RG: `mcdta-rg-vpp-d-messaging`
- Alert RG: `mcdta-rg-vpp-d-mon`
- Warning threshold: 400,000,000 bytes (400 MB). Critical: 800,000,000 bytes (800 MB)
- Current breaching topic: `assetplanning-asset-strike-price-schedule-created-v1` at 552.3 MB
- Root cause TODAY: DLQ accumulation — 3,796 msgs, PT5M TTL, DeadLetteringOnMessageExpiration=True
- Paging: Rootly via `ag-trade-platform-d` → `rootly-trade-platform` webhook
- Slack: `eneco-vpp-service-bus-topic-size-actiongroup` → Logic App

## Required Sections (in order)

### Header Callout Box (MANDATORY — first thing seen)
> WARNING: IGNORE the threshold in the alert description. The description reads "400000000Mb" which is a rendering bug (~381 petabytes). The ACTUAL warning threshold is **400 MB (400,000,000 bytes)**. The alert is valid. Do NOT dismiss it.

### 1. Alert Summary Table
| Field | Value |
- Alert name, severity (Sev2), auto-mitigate (yes)
- What it monitors: `Size` metric on `Microsoft.ServiceBus/Namespaces`, split per topic
- Threshold: 400 MB warning (Sev2), 800 MB critical (Sev0)
- Evaluation: every 1 min, 5-min window, Maximum aggregation
- Paging path: Rootly (dev) + Slack, OpsGenie additional in prd

### 2. Prerequisites
- Az CLI installed (`az --version`)
- Python 3 installed (`python3 --version`)
- Access to `enecotfvppmclogindev` alias (requires VPN or direct corporate network)
- For consumer investigation: kubectl access to VPP dev cluster
- **If no az CLI/Python**: fallback path via Azure Portal documented in Appendix A

### 3. Environment Variables
```bash
# Dev (this runbook — -d- suffix)
export SUBSCRIPTION_ID="839af51e-c8dd-4bd2-944b-a7799eb2e1e4"
export NAMESPACE="vpp-sbus-d"
export MESSAGING_RG="mcdta-rg-vpp-d-messaging"
export ALERT_RG="mcdta-rg-vpp-d-mon"
export ENV_SUFFIX="d"
export WARNING_THRESHOLD_BYTES=400000000
export CRITICAL_THRESHOLD_BYTES=800000000

# Prd (-p- suffix) — update these variables
export SUBSCRIPTION_ID="<prd-subscription-id>"
export NAMESPACE="vpp-sbus-p"
export MESSAGING_RG="mcdta-rg-vpp-p-messaging"
export ALERT_RG="mcdta-rg-vpp-p-mon"
export ENV_SUFFIX="p"
```

### 4. Step 1 — Authenticate (ONE COMMAND)
```bash
enecotfvppmclogindev  # Sets ARM_TENANT_ID and ARM_SUBSCRIPTION_ID

# Verify correct subscription is active:
az account show --query "{name:name, id:id}" --output table
# Expected: Eneco MCC - Development - Workload VPP | 839af51e-c8dd-4bd2-944b-a7799eb2e1e4
```

### 5. Step 2 — Quick Triage (target: 60 seconds to identify breaching topic)
```bash
# Option A: Python script (requires Python 3, recommended)
cd log/employer/eneco/00_incident_sre/01_alert_service_bus_topic_size_warning/runbook/
python3 diagnose.py \
  --namespace "$NAMESPACE" \
  --resource-group "$MESSAGING_RG" \
  --subscription "$SUBSCRIPTION_ID"
# Exit 0 = no topics above threshold (alert may be auto-resolving)
# Exit 1 = ≥1 topic above threshold — outputs ranked table with DLQ state

# Option B: Raw az CLI (no Python required)
az servicebus topic list \
  --namespace-name "$NAMESPACE" \
  --resource-group "$MESSAGING_RG" \
  --subscription "$SUBSCRIPTION_ID" \
  --query "sort_by([?sizeInBytes > \`400000000\`].{topic:name, bytes:sizeInBytes}, &bytes)" \
  --output table
```

### 6. Step 3 — Deep Diagnosis

#### 3.1 Identify all topics above threshold
```bash
az servicebus topic list \
  --namespace-name "$NAMESPACE" \
  --resource-group "$MESSAGING_RG" \
  --subscription "$SUBSCRIPTION_ID" \
  --query "[].{name:name, sizeInBytes:sizeInBytes, maxSizeInMegabytes:maxSizeInMegabytes}" \
  --output json | python3 -c "
import json, sys
WARNING = 400_000_000
CRITICAL = 800_000_000
topics = json.load(sys.stdin)
topics.sort(key=lambda x: x.get('sizeInBytes') or 0, reverse=True)
print(f'{'TOPIC':<80} {'BYTES':>15} {'MB':>8} {'%WARN':>7} {'STATUS':>12}')
print('-'*125)
for t in topics:
    size = t.get('sizeInBytes') or 0
    if size == 0: continue
    pct = size / WARNING * 100
    mb = size / 1_000_000
    status = 'CRITICAL' if size > CRITICAL else 'BREACHING' if size > WARNING else 'NEAR(>70%)' if size > WARNING*0.7 else ''
    if size > WARNING * 0.5:
        print(f\"{t['name']:<80} {size:>15,} {mb:>8.1f} {pct:>7.1f}% {status:>12}\")
"
```

#### 3.2 Identify lagging subscriptions on breaching topic
```bash
# Replace BREACHING_TOPIC with topic name from 3.1
BREACHING_TOPIC="assetplanning-asset-strike-price-schedule-created-v1"

az servicebus topic subscription list \
  --namespace-name "$NAMESPACE" \
  --resource-group "$MESSAGING_RG" \
  --subscription "$SUBSCRIPTION_ID" \
  --topic-name "$BREACHING_TOPIC" \
  --query "[].{name:name, active:countDetails.activeMessageCount, dlq:countDetails.deadLetterMessageCount, status:status}" \
  --output table
```

**Interpretation**:
- If `active > 0` and `dlq = 0`: consumer backlog (Scenario A)
- If `dlq > 0` and `active = 0 or low`: DLQ accumulation (Scenario B) ← CURRENT STATE
- If all subscriptions healthy but topic growing: producer burst (Scenario C)
- If a subscription exists but consumer service unknown: orphaned subscription (Scenario D)

#### 3.3 Get detailed subscription properties (confirm DLQ mechanics)
```bash
LAGGING_SUB="asset-scheduling-gateway"  # from step 3.2

az servicebus topic subscription show \
  --namespace-name "$NAMESPACE" \
  --resource-group "$MESSAGING_RG" \
  --subscription "$SUBSCRIPTION_ID" \
  --topic-name "$BREACHING_TOPIC" \
  --name "$LAGGING_SUB" \
  --query "{name:name, activeMessages:countDetails.activeMessageCount, dlqMessages:countDetails.deadLetterMessageCount, ttl:defaultMessageTimeToLive, deadLetterOnExpiry:deadLetteringOnMessageExpiration, maxDeliveryCount:maxDeliveryCount, lockDuration:lockDuration, status:status}" \
  --output table
```

**Key fields**:
- `ttl`: if PT5M or short → messages expire fast → check if consumer keeps up
- `deadLetterOnExpiry: true` → expired messages go to DLQ (not discarded) → DLQ grows → topic size stays high
- `maxDeliveryCount`: if consumer crashes on a message > N times → message DLQ'd (poison message scenario)

#### 3.4 Measure DLQ growth rate
```bash
NS_RESOURCE_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${MESSAGING_RG}/providers/Microsoft.ServiceBus/namespaces/${NAMESPACE}"

az monitor metrics list \
  --resource "$NS_RESOURCE_ID" \
  --metric "DeadletteredMessages" \
  --filter "EntityName eq '$BREACHING_TOPIC'" \
  --interval PT5M \
  --start-time "$(date -u -v-30M '+%Y-%m-%dT%H:%M:%SZ')" \
  --end-time "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
  --aggregation maximum \
  --output json | python3 -c "
import json, sys
d = json.load(sys.stdin)
ts = d.get('value',[{}])[0].get('timeseries',[])
if ts:
    data = [p for p in ts[0].get('data',[]) if p.get('maximum')]
    if len(data) >= 2:
        first, last = data[0].get('maximum',0), data[-1].get('maximum',0)
        print(f'DLQ: {first:.0f} → {last:.0f} (+{last-first:.0f} in {len(data)*5} min)')
        print(f'Growth rate: {(last-first)/len(data)*12:.0f} DLQ msgs/hour')
    else:
        [print(f'{p[\"timeStamp\"]}: {p.get(\"maximum\",0):.0f}') for p in data]
"
```

#### 3.5 Measure producer vs consumer rate
```bash
NS_RESOURCE_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${MESSAGING_RG}/providers/Microsoft.ServiceBus/namespaces/${NAMESPACE}"
START="$(date -u -v-1H '+%Y-%m-%dT%H:%M:%SZ')"
END="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

# Producer rate
echo "=== IncomingMessages (producer) last 1h ==="
az monitor metrics list \
  --resource "$NS_RESOURCE_ID" \
  --metric "IncomingMessages" \
  --filter "EntityName eq '$BREACHING_TOPIC'" \
  --interval PT5M \
  --start-time "$START" --end-time "$END" \
  --aggregation total \
  --output json | python3 -c "
import json,sys
d=json.load(sys.stdin)
ts=d.get('value',[{}])[0].get('timeseries',[{}])[0].get('data',[])
total=sum(p.get('total',0) or 0 for p in ts)
print(f'Total incoming last 1h: {total:.0f} messages ({total/12:.1f} msg/5min avg)')
"

# Consumer drain rate
echo "=== CompleteMessage (consumer) last 1h ==="
az monitor metrics list \
  --resource "$NS_RESOURCE_ID" \
  --metric "CompleteMessage" \
  --filter "EntityName eq '$BREACHING_TOPIC'" \
  --interval PT5M \
  --start-time "$START" --end-time "$END" \
  --aggregation total \
  --output json | python3 -c "
import json,sys
d=json.load(sys.stdin)
ts=d.get('value',[{}])[0].get('timeseries',[{}])[0].get('data',[])
total=sum(p.get('total',0) or 0 for p in ts)
print(f'Total completed last 1h: {total:.0f} messages ({total/12:.1f} msg/5min avg)')
"
```

**Interpretation**:
- `IncomingMessages >> CompleteMessage`: consumer can't keep up → Scenario A
- `IncomingMessages ≈ CompleteMessage` but DLQ growing: TTL expiry → Scenario B
- `IncomingMessages` spikes suddenly: producer burst → Scenario C
- `CompleteMessage = 0`: consumer completely stopped → Scenario A critical

#### 3.6 Check current alert fired state
```bash
NS_RESOURCE_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${MESSAGING_RG}/providers/Microsoft.ServiceBus/namespaces/${NAMESPACE}"

az rest \
  --method GET \
  --url "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/providers/Microsoft.AlertsManagement/alerts?api-version=2019-03-01&targetResource=${NS_RESOURCE_ID}&timeRange=1d" \
  --output json | python3 -c "
import json, sys
d = json.load(sys.stdin)
alerts = d.get('value', [])
if not alerts:
    print('No active alerts — alert may have auto-resolved')
for a in alerts:
    e = a.get('properties',{}).get('essentials',{})
    print(f'Rule: {e.get(\"alertRule\",\"\").split(\"/\")[-1]}')
    print(f'State: {e.get(\"alertState\")} | Condition: {e.get(\"monitorCondition\")} | Severity: {e.get(\"severity\")}')
    print(f'Fired: {e.get(\"startDateTime\")}')
"
```

#### 3.7 Calculate time to quota exhaustion (critical SLO)
```bash
# Get current topic size and compute ETA to MaxSize
CURRENT_MB=552  # from step 3.1
MAX_MB=1024
GROWTH_RATE_MB_PER_HOUR=8.7  # from step 3.4 (calibrate to live reading)

python3 -c "
current = $CURRENT_MB
max_size = $MAX_MB
rate = $GROWTH_RATE_MB_PER_HOUR  # MB/hour
if rate > 0:
    hours_to_quota = (max_size - current) / rate
    print(f'Current size: {current} MB')
    print(f'Max size: {max_size} MB')
    print(f'Growth rate: {rate} MB/hour')
    print(f'TIME TO QUOTA EXHAUSTION: {hours_to_quota:.1f} hours')
    print(f'  = {hours_to_quota*60:.0f} minutes')
    if hours_to_quota < 2:
        print('  >>> CRITICAL: Less than 2 hours! Escalate immediately!')
    elif hours_to_quota < 6:
        print('  >> HIGH: Less than 6 hours. Immediate action required.')
    else:
        print('  > MEDIUM: > 6 hours. Investigate and resolve within this on-call shift.')
else:
    print('Growth rate = 0. Size is stable or shrinking. Monitor for auto-resolution.')
"
```

### 7. Step 4 — Root Cause Classification

```
Alert fires (topic Size > 400 MB)
│
├── Check activeMessageCount on each subscription
│   ├── active > 0 AND dlq = 0?
│   │   └── SCENARIO A: Consumer Backlog → consumer is stopped or too slow
│   ├── dlq > 0 AND active low?
│   │   └── SCENARIO B: DLQ Accumulation → messages expired to DLQ (TTL issue)
│   │       Sub-check: is consumer running? (CompleteMessage > 0)
│   │       ├── Yes: consumer runs but messages expire before processing → TTL too short OR consumer too slow
│   │       └── No: consumer completely stopped, messages never consumed before TTL
│   ├── all subscriptions healthy (active=0, dlq=0) but topic growing?
│   │   └── SCENARIO C: Producer Burst → spike in incoming messages
│   └── subscription exists but consumer service unknown/decommissioned?
│       └── SCENARIO D: Orphaned Subscription → delete sub after confirming decommission
```

### 8. Step 5 — Resolution Playbook

#### Scenario A: Consumer Backlog (Active Messages High, DLQ=0)
```
1. Identify lagging subscription: az servicebus topic subscription list (Step 3.2)
2. Find consumer service owning this subscription (name usually matches service name)
3. Check consumer pod status:
   kubectl get pods -n <namespace> | grep <consumer-name>
   kubectl describe pod <pod-name> -n <namespace>
4. Check consumer logs for errors:
   kubectl logs -n <namespace> <pod-name> --tail=100
5. If pod crashed: kubectl rollout restart deployment/<consumer-name> -n <namespace>
6. Monitor: watch 'az servicebus topic subscription show ... --query countDetails'
7. Alert auto-resolves when topic size drops below 400MB
```

#### Scenario B: DLQ Accumulation — CURRENT STATE (High DLQ, Low Active)
```
1. Confirm DLQ root cause via Step 3.3:
   - deadLetteringOnMessageExpiration: True + short TTL = TTL expiry scenario
   - maxDeliveryCount exceeded = poison message scenario

2a. TTL expiry scenario (this incident):
   WHY: Consumer was not processing fast enough before PT5M TTL → messages expired → DLQ
   DECISION: Is the consumer now running? (check CompleteMessage metric, step 3.5)

   IF consumer running (CompleteMessage > 0):
     → DLQ messages will NOT be automatically reprocessed
     → Topic size will NOT decrease until DLQ is drained
     → Escalate to consumer team: "DLQ has N messages, topic at X MB.
       Do you want to: (a) replay DLQ messages, (b) discard/purge DLQ, (c) keep for investigation?"
     → Consumer team uses Azure Portal or servicebus-explorer to inspect/purge DLQ

   IF consumer stopped (CompleteMessage = 0):
     → Fix consumer first (Scenario A steps), then handle DLQ

   DLQ PURGE COMMAND (DESTRUCTIVE — requires consumer team approval):
     # Portal: namespace > topic > subscription > Dead Letter > Select All > Delete
     # CLI: No native purge command. Use diagnose.py --purge-dlq flag (see runbook)

2b. Poison message scenario (maxDeliveryCount exceeded):
   → Consumer logs will show repeated processing failures
   → Inspect specific failing message (Azure Portal: DLQ > browse messages)
   → Fix consumer bug OR manually move poison message to DLQ-of-DLQ (dead.letter)
   → Deploy fix, restart consumer
```

#### Scenario C: Producer Burst (All Subscriptions Healthy)
```
1. Confirm: IncomingMessages metric spike (Step 3.5)
2. Alert likely auto-resolves as burst subsides (AutoMitigate: True)
3. If sustained: identify producer service from topic name conventions
4. Check producer health/deployment status
5. If intentional load test: no action needed; monitor until completion
6. If unintentional: escalate to producer team
```

#### Scenario D: Orphaned Subscription
```
1. Subscription name matches a decommissioned service
2. Confirm with team: is <subscription-name> service still running?
3. IF confirmed orphaned:
   az servicebus topic subscription delete \
     --namespace-name "$NAMESPACE" \
     --resource-group "$MESSAGING_RG" \
     --topic-name "$BREACHING_TOPIC" \
     --name "$LAGGING_SUB"
   # WARNING: DESTRUCTIVE — confirm with team lead before executing
4. Alert auto-resolves once orphaned subscription is removed (topic reclaims space)
```

### 9. Step 6 — Escalation Matrix

| Situation | Contact | Channel | SLO |
|---|---|---|---|
| Consumer not responding to restart | Consumer service team lead | Slack #vpp-oncall | 15 min |
| DLQ purge decision needed | Consumer team + SRE lead | Slack #vpp-oncall | 30 min |
| Topic > 800 MB (critical alert) | SRE lead + consumer team | PagerDuty/Rootly escalation | Immediate |
| Time to quota < 2 hours | SRE lead, VP Engineering | Rootly escalation + direct call | Immediate |
| Orphaned subscription delete | Team lead approval required | Slack, document in Rootly | Before action |

### 10. Alert Mechanics

Explain in plain terms:
- What `Size` metric measures (bytes stored per topic, per-subscription cursor)
- Why DLQ messages count toward topic size
- Why AutoMitigate=True does NOT mean the alert resolves on its own if DLQ is the cause
- The "slowest reader" problem: topic retains messages for slowest subscription
- Mermaid diagram: Message lifecycle (Arrive → Active → Completed | Expired → DLQ)

### 11. Cascade Risk

| Stage | Trigger | Impact | Time from alert |
|---|---|---|---|
| 1 | Topic > 400 MB | Warning alert fires, Rootly page | T=0 (this alert) |
| 2 | Topic > 800 MB | Critical alert fires, OpsGenie page (prd) | T + N hours depending on growth rate |
| 3 | Topic = 1,024 MB | QuotaExceededException — producer rejects messages | T + ~54h at current 8.7 MB/hr growth |
| 4 | Producer crash | ALL topics this producer publishes to stop receiving | T + depends on producer error handling |
| 5 | Downstream starvation | Multiple topics grow their own backlogs | T + cascade |

**Formula**: `ETA = (1024 MB - current_MB) / growth_rate_MB_per_hour`

### 12. Appendix A — Azure Portal Fallback

Step-by-step portal navigation for engineers without CLI:
- Portal URL for namespace: https://portal.azure.com → Service Bus → vpp-sbus-d
- How to find topic sizes: Namespace > Topics > sort by size
- How to check subscription state: Topic > Subscriptions > click subscription
- How to view DLQ: Subscription > Service Bus Explorer > Browse DLQ

### 13. Known Issues / False Positives

| Situation | Description | Action |
|---|---|---|
| Alert description "400000000Mb" | Rendering bug. Not a false positive. Real threshold = 400 MB | Ignore description, alert is valid |
| Alert fires in dev at same threshold as prd | Design decision (not yet changed) | Treat as real alert, same investigation |
| Alert auto-resolves quickly after firing | Consumer caught up, topic drained. Check if DLQ accumulated | Verify DLQ count after resolve |

## Verification Criteria
1. All az CLI commands copy-pasteable without modification (using env vars from Step 3)
2. Runbook can be read linearly from top in a terminal (no context switching)
3. Step 2 (Quick Triage) produces output in ≤ 60 seconds
4. Each scenario in Step 5 ends with observable confirmation ("alert auto-resolves" or "verify with...")
5. Cascade Risk table contains all 5 stages
6. Adversarial Q2 resolution (description bug warning) is first thing on the page
