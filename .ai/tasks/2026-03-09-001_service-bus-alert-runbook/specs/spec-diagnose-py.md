---
task_id: 2026-03-09-001
agent: coordinator
status: draft
summary: Specification for diagnose.py triage script for Service Bus Topic Size Warning
---

# Spec: diagnose.py

## Summary
Python 3 triage script that runs all key az CLI diagnostic commands, parses JSON output, computes derived metrics (% of threshold, DLQ growth rate, ETA to quota), and outputs a structured summary table. Exits 0 if no topics above threshold, exits 1 if action is required.

## Output Path
`log/employer/eneco/00_incident_sre/01_alert_service_bus_topic_size_warning/runbook/diagnose.py`

## Design Constraints
- **NO external dependencies** — stdlib + `subprocess` only. Do not import `azure-servicebus`, `azure-identity`, or any pip package.
- **READ-ONLY** — no mutations to Azure resources. Every command is GET/list only.
- **Requires az CLI** — assumes `az` is in PATH and authenticated (enecotfvppmclogindev called before running)
- **Python 3.9+** compatible
- Exit code: `0` = healthy (no topics above warning threshold), `1` = action required

## CLI Interface
```
python3 diagnose.py [OPTIONS]

Options:
  --namespace          Service Bus namespace name (default: vpp-sbus-d)
  --resource-group     Messaging resource group (default: mcdta-rg-vpp-d-messaging)
  --subscription       Azure subscription ID (default: 839af51e-c8dd-4bd2-944b-a7799eb2e1e4)
  --warning-threshold  Warning threshold in bytes (default: 400000000)
  --critical-threshold Critical threshold in bytes (default: 800000000)
  --top-n              Show top N topics by size (default: 10)
  --help               Show help

Environment variable override (lower priority than flags):
  SUBSCRIPTION_ID, NAMESPACE, MESSAGING_RG
```

## Required Output Sections

### Section 1: Header
```
=== Service Bus Topic Size Triage ===
Namespace:  vpp-sbus-d
RG:         mcdta-rg-vpp-d-messaging
Sub:        839af51e-c8dd-4bd2-944b-a7799eb2e1e4
Time:       2026-03-09T04:30:00Z
Warning:    400 MB | Critical: 800 MB
Topics:     252 total
```

### Section 2: Breaching Topics Table (ONLY topics above threshold)
```
BREACHING TOPICS (above 400 MB warning threshold):
TOPIC                                                    SIZE(MB)  %WARN  %CRIT  STATUS
assetplanning-asset-strike-price-schedule-created-v1      552.3   138.1%  69.0%  BREACHING
```

If empty: `No topics currently above threshold. Alert may be auto-resolving.`

### Section 3: Near-Threshold Topics (70%-100% of warning)
```
NEAR THRESHOLD (70%-100% of 400 MB warning):
[none]
```

### Section 4: Subscription State for Each Breaching Topic
```
Subscriptions on: assetplanning-asset-strike-price-schedule-created-v1
SUBSCRIPTION                ACTIVE    DLQ    STATUS  TTL    DLQ-ON-EXPIRY
tenant-gateway-subscription      0      0    Active  -      -
dataprep                         0      0    Active  -      -
asset-scheduling-gateway *       5   3796    Active  PT5M   YES  ← CULPRIT
```
Mark culprit subscription with `*`.

### Section 5: DLQ Growth Rate (last 30 min)
```
DLQ Growth Rate (last 30 min):
  3736 → 3796 = +60 messages | Rate: +120 DLQ msgs/hour = +17.4 MB/hour

Estimated time to quota exhaustion:
  Current: 552 MB | Max: 1024 MB | Growth: 17.4 MB/hr
  ETA TO QUOTA: 27.1 hours [MEDIUM priority]
```

### Section 6: Producer vs Consumer (last 1h)
```
Message Flow (last 1 hour):
  IncomingMessages:  60 msgs  (5.0/5min avg)
  CompleteMessage:  120 msgs  (10.0/5min avg)
  Net drain:        +60 msgs/hr from active queue

  ✓ Consumer is active and draining faster than arrival
  ! DLQ accumulation is keeping topic size elevated
```

### Section 7: Current Alert State
```
Alert State:
  mcdta-vpp-sb-vpp-sbus-d-topic-size-d-warning
  Condition: FIRED | State: New | Severity: Sev2
  Fired since: 2026-03-08T10:24:27Z (duration: 18h 6m)
```

### Section 8: Summary Verdict + Next Action
```
=== VERDICT ===
Status:     ACTION REQUIRED
Exit code:  1

Diagnosis:  DLQ Accumulation (Scenario B)
Evidence:   asset-scheduling-gateway has 3796 DLQ messages. TTL=PT5M, DeadLetterOnExpiry=True.
            Messages expire before processing → accumulate in DLQ → inflate topic size.
            Alert will NOT auto-resolve. DLQ must be explicitly drained.

Next steps:
  1. Escalate to consumer team: does 'asset-scheduling-gateway' need to replay or discard DLQ?
  2. Check consumer pod: kubectl get pods -n <namespace> | grep asset-scheduling-gateway
  3. If consumer team approves DLQ purge: use Azure Portal > DLQ > Browse > Delete All

Run with --help for full options.
```

## Implementation Steps (for executor agent)

1. Parse CLI args with `argparse` — all params have defaults matching dev environment
2. Run `az account show --output json` — verify authenticated, extract subscription name for display
3. Run `az servicebus topic list ... --output json` — capture all topics
4. Compute: sort by sizeInBytes DESC, flag breaching (>warning), near (>70% warning)
5. For each breaching topic: run `az servicebus topic subscription list ... --output json`
6. For each breaching topic: run `az servicebus topic subscription show` for each subscription to get TTL + deadLetterOnExpiry
7. Run `az monitor metrics list --metric DeadletteredMessages --filter "EntityName eq 'topic'"` for last 30 min
8. Run `az monitor metrics list --metric IncomingMessages` and `CompleteMessage` for last 1h
9. Run `az rest` for AlertsManagement current state
10. Compute ETA to quota: `(max_size_bytes - current_size_bytes) / growth_rate_bytes_per_hour`
11. Classify scenario: A (active high), B (dlq high), C (all healthy but growing), D (unknown subscription)
12. Print all sections in order
13. Exit 0 if no breaching topics, else 1

## Error Handling
- If `az account show` fails (not authenticated): print clear error with auth instruction, exit 2
- If `az servicebus topic list` fails: print error with az CLI error, exit 2
- If metrics call fails (transient): print WARNING, continue (don't block triage)
- Each `subprocess.run` call: `check=False`, capture stderr, if returncode != 0 → print warning and continue

## Verification Criteria
1. `python3 diagnose.py --help` exits 0
2. `python3 diagnose.py` runs end-to-end in < 60 seconds
3. Output contains all 8 sections
4. Exit code is 1 when breaching topics exist, 0 when none
5. ETA calculation uses live data (not hardcoded)
6. No mutations — all commands are read-only
7. Script runs without any `pip install` commands (stdlib only)
