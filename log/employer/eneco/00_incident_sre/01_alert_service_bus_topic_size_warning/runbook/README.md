---
alert: mcdta-vpp-sb-vpp-sbus-d-topic-size-d-warning
severity: Sev2 (warning) / Sev0 (critical)
paging: Rootly (dev) · OpsGenie + Rootly (prd)
updated: 2026-03-09
---

# SRE Runbook — Service Bus Topic Size Warning

> **STOP — description bug**: The alert fires with the text
> *"Action will be triggered when any topic exceeds size of 400000000Mb"*.
> That is a rendering defect (~381 petabytes). The **real threshold is 400 MB**.
> The alert is valid. Do not dismiss it.

---

## Alert at a glance

| Field | Value |
|---|---|
| Alert name | `mcdta-vpp-sb-vpp-sbus-d-topic-size-d-warning` |
| Metric | `Size` on `Microsoft.ServiceBus/Namespaces` |
| Split by | `EntityName` (per-topic) |
| Warning (Sev2) | > 400 MB — pages Rootly |
| Critical (Sev0) | > 800 MB — pages OpsGenie (prd) + Rootly |
| Evaluation | every 1 min · 5-min window · Maximum aggregation |
| AutoMitigate | **Yes** — resolves automatically when size drops below threshold |
| Namespace | `vpp-sbus-d` (dev) · `vpp-sbus-p` (prd) · Premium · westeurope |

---

## Prerequisites

| Requirement | Check |
|---|---|
| `az` CLI | `az --version` |
| `cargo` / Rust | `cargo --version` (to build the triage tool) |
| Corporate VPN or direct network | required for `enecotfvppmclogindev` alias |
| kubectl (optional) | consumer pod investigation only |

**No kubectl?** — all az CLI steps still work. kubectl steps are marked *(k8s)*.

---

## Environment variables

Set these once at the top of your terminal session. All commands below reference them.

```bash
# Dev (default — this alert)
export SUBSCRIPTION_ID="839af51e-c8dd-4bd2-944b-a7799eb2e1e4"
export NAMESPACE="vpp-sbus-d"
export MESSAGING_RG="mcdta-rg-vpp-d-messaging"
export ALERT_RG="mcdta-rg-vpp-d-mon"

# Prd — swap these if paged on a production alert
# export SUBSCRIPTION_ID="<prd-subscription-id>"
# export NAMESPACE="vpp-sbus-p"
# export MESSAGING_RG="mcdta-rg-vpp-p-messaging"
# export ALERT_RG="mcdta-rg-vpp-p-mon"
```

---

## Step 1 — Authenticate (one command)

```bash
enecotfvppmclogindev
```

Sets `ARM_TENANT_ID` and `ARM_SUBSCRIPTION_ID`. Verify the correct subscription is active:

```bash
az account show --query "{name:name, id:id}" --output table
# Expected: Eneco MCC - Development - Workload VPP | 839af51e-...
```

---

## Step 2 — Quick triage (target: < 60 seconds)

Run the triage tool from this directory:

```bash
# Build once
make build

# Run against dev (default)
make run

# Or with explicit overrides
make run NAMESPACE=vpp-sbus-p MESSAGING_RG=mcdta-rg-vpp-p-messaging
```

The tool outputs a ranked table of all topics above threshold, subscription DLQ state,
growth rate, ETA to quota exhaustion, and a verdict with next steps.

**Exit codes**: `0` = healthy · `1` = action required · `2` = auth/az failure

---

## Step 3 — Manual az CLI deep-dive

Use these commands individually if the tool output needs confirmation or if you
prefer raw CLI during an incident.

### 3.1 All topics ranked by size

```bash
az servicebus topic list \
  --namespace-name "$NAMESPACE" \
  --resource-group "$MESSAGING_RG" \
  --subscription "$SUBSCRIPTION_ID" \
  --query "[].{name:name, sizeInBytes:sizeInBytes}" \
  --output json | python3 -c "
import json, sys
WARNING = 400_000_000
topics = sorted(json.load(sys.stdin), key=lambda x: x.get('sizeInBytes') or 0, reverse=True)
print(f'{\"TOPIC\":<70} {\"BYTES\":>15} {\"MB\":>8} {\"% WARN\":>8}')
print('-' * 108)
for t in topics:
    b = t.get('sizeInBytes') or 0
    if b == 0: continue
    flag = '<<< BREACHING' if b > WARNING else ''
    print(f\"{t['name']:<70} {b:>15,} {b/1e6:>8.1f} {b/WARNING*100:>8.1f}%  {flag}\")
"
```

### 3.2 Subscriptions on a breaching topic

```bash
TOPIC="assetplanning-asset-strike-price-schedule-created-v1"  # from 3.1

az servicebus topic subscription list \
  --namespace-name "$NAMESPACE" \
  --resource-group "$MESSAGING_RG" \
  --subscription "$SUBSCRIPTION_ID" \
  --topic-name "$TOPIC" \
  --query "[].{name:name, active:countDetails.activeMessageCount, dlq:countDetails.deadLetterMessageCount, status:status}" \
  --output table
```

**Reading the output**:

| Signals | Root cause |
|---|---|
| `active` high, `dlq` = 0 | Consumer backlog → Scenario A |
| `dlq` high, `active` low | DLQ accumulation → Scenario B |
| All subscriptions at 0, topic still growing | Producer burst → Scenario C |
| Subscription exists, service unknown | Orphaned subscription → Scenario D |

### 3.3 Subscription detail (TTL, DLQ-on-expiry)

```bash
SUB_NAME="asset-scheduling-gateway"  # from 3.2

az servicebus topic subscription show \
  --namespace-name "$NAMESPACE" \
  --resource-group "$MESSAGING_RG" \
  --subscription "$SUBSCRIPTION_ID" \
  --topic-name "$TOPIC" \
  --name "$SUB_NAME" \
  --query "{ttl:defaultMessageTimeToLive, dlqOnExpiry:deadLetteringOnMessageExpiration, maxDelivery:maxDeliveryCount, active:countDetails.activeMessageCount, dlq:countDetails.deadLetterMessageCount}" \
  --output table
```

**Key fields**:
- `ttl: PT5M` + `dlqOnExpiry: true` → messages expire in 5 min → go to DLQ → topic size stays high even after consumer recovers
- `maxDelivery` exceeded → poison message in DLQ

### 3.4 DLQ growth rate (last 30 min)

```bash
NS_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${MESSAGING_RG}/providers/Microsoft.ServiceBus/namespaces/${NAMESPACE}"

az monitor metrics list \
  --resource "$NS_ID" \
  --metric "DeadletteredMessages" \
  --filter "EntityName eq '$TOPIC'" \
  --interval PT5M \
  --start-time "$(date -u -v-30M '+%Y-%m-%dT%H:%M:%SZ')" \
  --end-time "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
  --aggregation maximum \
  --output json | python3 -c "
import json, sys
d = json.load(sys.stdin)
pts = d['value'][0]['timeseries'][0]['data']
vals = [p.get('maximum', 0) for p in pts if p.get('maximum')]
if len(vals) >= 2:
    delta = vals[-1] - vals[0]
    rate = delta / len(vals) * 12
    print(f'DLQ: {vals[0]:.0f} → {vals[-1]:.0f}  (+{delta:.0f} msgs in {len(vals)*5} min)')
    print(f'Growth: ~{rate:.0f} msgs/h ≈ {rate*145/1000:.1f} MB/h')
"
```

> **Note**: Use `--filter "EntityName eq '...'"` — do **not** combine with `--dimension` (they are mutually exclusive).

### 3.5 Producer vs consumer rate (last 1 hour)

```bash
START="$(date -u -v-1H '+%Y-%m-%dT%H:%M:%SZ')"
END="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

# Producer rate
az monitor metrics list \
  --resource "$NS_ID" --metric "IncomingMessages" \
  --filter "EntityName eq '$TOPIC'" \
  --interval PT5M --start-time "$START" --end-time "$END" \
  --aggregation total --output json | \
  python3 -c "import json,sys; d=json.load(sys.stdin); pts=d['value'][0]['timeseries'][0]['data']; t=sum(p.get('total',0) or 0 for p in pts); print(f'IncomingMessages: {t:.0f}/h ({t/12:.1f}/5min)')"

# Consumer drain rate
az monitor metrics list \
  --resource "$NS_ID" --metric "CompleteMessage" \
  --filter "EntityName eq '$TOPIC'" \
  --interval PT5M --start-time "$START" --end-time "$END" \
  --aggregation total --output json | \
  python3 -c "import json,sys; d=json.load(sys.stdin); pts=d['value'][0]['timeseries'][0]['data']; t=sum(p.get('total',0) or 0 for p in pts); print(f'CompleteMessage:  {t:.0f}/h ({t/12:.1f}/5min)')"
```

### 3.6 Current alert fired state

```bash
az rest \
  --method GET \
  --url "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/providers/Microsoft.AlertsManagement/alerts?api-version=2019-03-01&targetResource=${NS_ID}&timeRange=1d" \
  --output json | python3 -c "
import json, sys
alerts = json.load(sys.stdin).get('value', [])
if not alerts: print('No fired alerts — may have auto-resolved')
for a in alerts:
    e = a['properties']['essentials']
    print(f'Rule: {e[\"alertRule\"].split(\"/\")[-1]}')
    print(f'Condition: {e[\"monitorCondition\"]} | State: {e[\"alertState\"]} | {e[\"severity\"]}')
    print(f'Fired: {e[\"startDateTime\"]}')
"
```

### 3.7 ETA to quota exhaustion

```bash
# Get current topic size in MB
CURRENT_MB=$(az servicebus topic show \
  --namespace-name "$NAMESPACE" --resource-group "$MESSAGING_RG" \
  --subscription "$SUBSCRIPTION_ID" --name "$TOPIC" \
  --query "sizeInBytes" --output tsv | python3 -c "import sys; print(float(sys.stdin.read())/1e6)")

python3 -c "
current = $CURRENT_MB
max_mb  = 1024.0
rate_mb_hr = 8.7        # update from Step 3.4 output
remaining  = max_mb - current
eta_hours  = remaining / rate_mb_hr if rate_mb_hr > 0 else float('inf')
print(f'Current: {current:.0f} MB  |  Max: {max_mb:.0f} MB  |  Remaining: {remaining:.0f} MB')
print(f'Growth: {rate_mb_hr:.1f} MB/h  |  ETA: {eta_hours:.1f}h ({eta_hours*60:.0f} min)')
severity = 'CRITICAL — escalate immediately' if eta_hours < 2 else 'HIGH — act within the hour' if eta_hours < 6 else 'MEDIUM — resolve this shift'
print(f'>>> {severity}')
"
```

---

## Step 4 — Root cause classification

```
Alert fires (topic Size > 400 MB)
│
├─ active > 0  AND  dlq = 0?
│   └─ SCENARIO A: Consumer Backlog
│
├─ dlq > 0  AND  active ≈ 0?
│   ├─ dlqOnExpiry = true?  →  SCENARIO B1: TTL expiry into DLQ  ← CURRENT (2026-03-09)
│   └─ dlqOnExpiry = false? →  SCENARIO B2: Poison message (maxDeliveryCount exceeded)
│
├─ all subscriptions at 0, topic growing?
│   └─ SCENARIO C: Producer Burst
│
└─ subscription exists, service unknown/decommissioned?
    └─ SCENARIO D: Orphaned Subscription
```

---

## Step 5 — Resolution playbook

### Scenario A — Consumer Backlog

Active messages high, DLQ = 0. Consumer is stopped or too slow.

```bash
# 1. Find which subscription is lagging (Step 3.2)

# 2. Locate the consumer pod   (k8s)
kubectl get pods -n <namespace> | grep <subscription-name>
kubectl describe pod <pod-name> -n <namespace>

# 3. Check consumer logs   (k8s)
kubectl logs -n <namespace> <pod-name> --tail=100

# 4. Restart if crashed   (k8s)
kubectl rollout restart deployment/<consumer-name> -n <namespace>

# 5. Monitor
watch -n 10 'az servicebus topic subscription show \
  --namespace-name "$NAMESPACE" --resource-group "$MESSAGING_RG" \
  --subscription "$SUBSCRIPTION_ID" \
  --topic-name "$TOPIC" --name "$SUB_NAME" \
  --query "countDetails" --output table'
```

Alert auto-resolves when topic size drops below 400 MB (AutoMitigate = true).

---

### Scenario B1 — DLQ via TTL expiry ← current state (2026-03-09)

DLQ is high, active ≈ 0, `deadLetteringOnMessageExpiration = true`, short TTL.

**Why the alert does not auto-resolve**: Consumer recovery drains active messages, but
DLQ messages are not automatically reprocessed. DLQ bytes count toward topic size.
The alert stays fired until the DLQ is explicitly drained.

```bash
# 1. Confirm consumer is running (CompleteMessage > 0 in Step 3.5)

# 2. Get current DLQ count
az servicebus topic subscription show \
  --namespace-name "$NAMESPACE" --resource-group "$MESSAGING_RG" \
  --subscription "$SUBSCRIPTION_ID" \
  --topic-name "$TOPIC" --name "$SUB_NAME" \
  --query "countDetails.deadLetterMessageCount" --output tsv

# 3. Escalate to consumer team with this message:
#    "DLQ on <topic>/<subscription> has N messages (X MB).
#     Topic is at Y MB / 400 MB threshold. Please decide: replay or purge?"

# 4. DLQ purge (requires consumer team approval — DESTRUCTIVE):
#    Azure Portal:
#    Namespace → Topics → <topic> → Subscriptions → <subscription>
#    → Dead-letter tab → Select All → Delete
#
#    No native az CLI purge command exists.

# 5. Verify resolution
az monitor metrics list \
  --resource "$NS_ID" --metric "Size" \
  --filter "EntityName eq '$TOPIC'" \
  --interval PT5M \
  --start-time "$(date -u -v-15M '+%Y-%m-%dT%H:%M:%SZ')" \
  --end-time "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
  --aggregation maximum --output table
```

---

### Scenario B2 — DLQ via poison messages

Consumer crashes on specific message(s), maxDeliveryCount exceeded.

```bash
# 1. Check consumer logs for repeated processing errors   (k8s)
kubectl logs -n <namespace> <pod-name> --tail=200 | grep -i "error\|exception\|fail"

# 2. Inspect DLQ messages (Azure Portal only — no CLI command):
#    Namespace → Topic → Subscription → Dead-letter → Service Bus Explorer → Peek

# 3. Fix the consumer bug that causes the crash

# 4. Deploy fix and restart
kubectl rollout restart deployment/<consumer-name> -n <namespace>

# 5. Discard or reprocess the poison messages after the fix
```

---

### Scenario C — Producer Burst

All subscriptions healthy (active = 0, dlq = 0) but topic is growing.

```bash
# 1. Check IncomingMessages spike (Step 3.5)

# 2. Alert likely auto-resolves when burst ends (AutoMitigate = true)

# 3. If burst is sustained: identify and contact the producer team

# 4. If this is a load test: monitor until it completes
```

---

### Scenario D — Orphaned Subscription

Subscription exists but its consumer service is decommissioned or unknown.

```bash
# 1. Confirm with team: is <subscription-name> service still running?

# 2. If confirmed orphaned — DELETE (DESTRUCTIVE, requires team lead approval):
az servicebus topic subscription delete \
  --namespace-name "$NAMESPACE" \
  --resource-group "$MESSAGING_RG" \
  --subscription "$SUBSCRIPTION_ID" \
  --topic-name "$TOPIC" \
  --name "$SUB_NAME"

# 3. Alert auto-resolves as topic reclaims space
```

---

## Step 6 — Escalation matrix

| Condition | Contact | Channel | SLO |
|---|---|---|---|
| Consumer not responding to restart | Consumer service team lead | Slack `#vpp-oncall` | 15 min |
| DLQ purge decision needed | Consumer team + SRE lead | Slack `#vpp-oncall` | 30 min |
| Topic > 800 MB (critical alert) | SRE lead + consumer team | Rootly escalation | Immediate |
| ETA to quota < 2 hours | SRE lead + VP Engineering | Rootly + direct call | Immediate |
| Orphaned subscription delete | Team lead written approval | Slack thread, document in Rootly | Before action |

---

## Alert mechanics

**Why a single slow consumer fills the whole topic**

A Service Bus topic holds messages for the _slowest_ subscription. If a topic has
three subscriptions and two are healthy but one is stopped, the broker retains every
message until the stopped subscription either consumes it or the message TTL expires.

```
Producer → topic → subscription A (healthy, reads fast)   → complete
                 → subscription B (healthy, reads fast)   → complete
                 → subscription C (stopped / slow)        → accumulates → size grows
```

**Why DLQ keeps the alert fired even after consumer recovery**

When `deadLetteringOnMessageExpiration = true` and the subscription TTL is short
(e.g. `PT5M`), messages that expire before the consumer reads them are moved to the
Dead-Letter Queue. DLQ messages are real bytes — they count toward the topic's `Size`
metric. The consumer processing new messages does **not** drain the DLQ.

---

## Cascade risk

| Stage | Trigger | Impact |
|---|---|---|
| 1 | Topic > 400 MB | Sev2 warning · Rootly page |
| 2 | Topic > 800 MB | Sev0 critical · OpsGenie page (prd) |
| 3 | Topic = 1,024 MB | `QuotaExceededException` — producers can no longer publish to this topic |
| 4 | Producer crash | All other topics this process publishes to stop receiving messages |
| 5 | Cascade | Downstream consumers starve, their topics begin filling |

**ETA formula** (calibrate `RATE_MB_HR` from Step 3.4):

```
ETA = (1024 - current_MB) / RATE_MB_HR   hours
```

At the rate observed on 2026-03-09 (~8.7 MB/h): ~54 hours from 552 MB to quota.

---

## Known issues / false positives

| Situation | Explanation | Action |
|---|---|---|
| Description reads "400000000Mb" | Rendering bug in IaC template. Real threshold = 400 MB. | Ignore the description; alert is valid |
| Dev alert at same threshold as prd | Team decision — not yet changed | Treat as real alert, same steps |
| Alert auto-resolves within minutes | Consumer caught up, topic drained normally | Verify DLQ did not accumulate; check post-resolution |
| Alert stays fired after consumer restart | DLQ accumulation — consumer restart alone is not enough | Follow Scenario B1 steps |

---

## Portal quick links

```
Namespace:  https://portal.azure.com/#resource/subscriptions/839af51e-c8dd-4bd2-944b-a7799eb2e1e4/resourceGroups/mcdta-rg-vpp-d-messaging/providers/Microsoft.ServiceBus/namespaces/vpp-sbus-d/topics
Alert rule: https://portal.azure.com/#@Eneco.onmicrosoft.com/resource/subscriptions/839af51e-c8dd-4bd2-944b-a7799eb2e1e4/resourceGroups/mcdta-rg-vpp-d-mon/providers/Microsoft.Insights/metricalerts/mcdta-vpp-sb-vpp-sbus-d-topic-size-d-warning/overview
```

---

## Triage tool reference

```bash
# Build
make build

# Run (dev defaults)
make run

# Run against prd
make run-prd SUBSCRIPTION_ID=<prd-sub-id>

# Pass custom flags directly
./target/release/diagnose --help
./target/release/diagnose --namespace vpp-sbus-p --resource-group mcdta-rg-vpp-p-messaging

# Clean build artifacts
make clean
```

The binary calls `az` for every query — no Azure credentials are embedded in the binary.
Authenticate with `enecotfvppmclogindev` before running.
