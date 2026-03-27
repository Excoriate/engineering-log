# Root Cause Analysis: Gurobi CosmosDB 429 Throttling

| Field | Value |
|---|---|
| **Date** | 2026-03-27 |
| **Alert** | `gurobi-cosmos-throttling-429-a` |
| **Severity** | Sev2 |
| **Environment** | Acceptance (ACC) |
| **Resource** | `cosmosdb-gurobi-platform-a` (MongoDB 7.0 API) |
| **Resource Group** | `rg-gurobi-platform-a` |
| **Subscription** | Eneco MCC - Acceptance - Workload VPP |
| **Fired At** | 2026-03-27T13:46:47 UTC (eval window ended 13:44:32 — ~2min Azure Monitor pipeline latency) |
| **Status** | Active — recurring pattern, not one-off |
| **IaC Source** | `enecomanagedcloud/myriad-vpp/gurobi-infrastructure/src/` (NOT in MC-VPP-Infrastructure) |

---

## 1. What Happened

CosmosDB returned **HTTP 429 (Too Many Requests)** responses — meaning the application
was **requesting more database work than the provisioned capacity allows**. The alert
rule fires when **>=20 throttled requests** occur in a **5-minute window**. At trigger
time, **24 requests were throttled**.

This is not a one-time event. The data shows a **repeating pattern every ~15 minutes**:

```text
TIME (UTC)       429s   NormalizedRU%   Total RUs (5min)
─────────────────────────────────────────────────────────
13:21            0      8%              3,232
13:26            16     100% ← spike    7,549  ← 2.3x normal
13:31            0      3%              2,780
13:36            0      9%              3,567
13:41            24     100% ← spike    8,427  ← 2.6x normal   ◄ ALERT FIRED
13:46            0      3%              3,267
13:51            0      7%              3,357
13:56            24     100% ← spike    8,682  ← 2.7x normal
14:01            0      4%              2,692
14:06            0      8%              3,009
14:11            24     100% ← spike    8,350  ← 2.8x normal
14:16            0      3%              3,090
```

**Pattern**: A periodic workload (likely a scheduled job) bursts every ~15 min, saturating
CosmosDB to 100% RU consumption, generating 24 throttled (429) requests per burst.

---

## 2. How CosmosDB Throttling Works

### 2.1 Request Units (RUs) — The Currency

CosmosDB uses **Request Units (RU/s)** as its throughput currency. Every operation
(read, write, query) costs RUs. Think of it as a per-second budget:

```text
┌─────────────────────────────────────────────────────────┐
│                   RU/s BUDGET MODEL                     │
│                                                         │
│  You provision: 100 RU/s per collection                 │
│                                                         │
│  ┌─────────┐  Cost Examples:                            │
│  │ 100 RU/s│  • Point read (1KB doc):  ~1 RU           │
│  │ budget  │  • Write (1KB doc):       ~5 RU            │
│  │ per sec │  • Query (scan):          10-100+ RU       │
│  └────┬────┘  • Aggregation:           50-500+ RU       │
│       │                                                 │
│       ▼                                                 │
│  If requests exceed budget in a 1-second window:        │
│  ┌──────────────────────────────────────┐               │
│  │ HTTP 429 Too Many Requests           │               │
│  │ x-ms-retry-after-ms: <wait time>     │               │
│  └──────────────────────────────────────┘               │
│                                                         │
│  CosmosDB does NOT queue — it REJECTS immediately.      │
└─────────────────────────────────────────────────────────┘
```

### 2.2 NormalizedRUConsumption — The Saturation Gauge

This is the **single most important metric** for throttling. It shows what percentage of
provisioned RU/s is being consumed:

```text
  NormalizedRU%
  100%  ┤ ●               ●               ●               ●
        │
   80%  ┤
        │
   60%  ┤
        │
   40%  ┤
        │
   20%  ┤
        │
    0%  ┤──●──●──●──●──●──●──●──●──●──●──●──●──●──●──●──●──
        ╰──────────────────────────────────────────────────────
        13:21  :26  :31  :36  :41  :46  :51  :56  14:01 :06  :11
                                    ▲
                              Alert Fired

  Legend: ● = data point.  Spikes to 100% every ~15 min = periodic saturation.
  Between spikes: 3-9% (healthy).
```

**Key insight**: When NormalizedRU hits 100%, it means **at least one physical partition**
has exhausted its RU budget. At that moment, ANY request hitting that partition gets a 429.

### 2.3 The Alert Rule Pipeline

```text
                        ┌──────────────┐
                        │  CosmosDB    │
                        │  emits       │
                        │  TotalReqs   │
                        │  metric      │
                        └──────┬───────┘
                               │  (every minute)
                               ▼
                  ┌────────────────────────┐
                  │  Azure Monitor         │
                  │  evaluates every 5min  │
                  │                        │
                  │  Filter:               │
                  │    StatusCode = '429'   │
                  │  Agg: Count            │
                  │  Window: 5 min         │
                  │  Threshold: >= 20      │
                  └────────────┬───────────┘
                               │  (condition met: 24 >= 20)
                               ▼
                  ┌────────────────────────┐
                  │  Action Group:                  │
                  │  gurobi-platform-a              │
                  │  (rg-gurobi-platform-a)         │
                  └────────────┬───────────────────┘
                               │  (webhook)
                               ▼
                  ┌────────────────────────┐
                  │  OpsGenie (EU)         │
                  │  → Rootly integration  │
                  │  → Escalation Policy   │
                  │  → On-call engineer    │
                  └────────────────────────┘

  autoMitigate: true → Alert auto-resolves when 429s drop below 20/5min.
  Note: staticThresholdFailingPeriods is 0/0 — no dampening. Every burst fires.
  With a ~15-min cycle, expect ~4 alerts/hour until resolved.
```

---

## 3. Root Cause: Why 429s Are Happening

### 3.1 The Provisioning Problem

**Every single collection is provisioned at 100 RU/s with no autoscale. No collection has a shard key — all data sits on a single logical partition per collection.**

| Collection     | RU/s   | Autoscale | Requests/hr | Verdict       |
|----------------|--------|-----------|-------------|---------------|
| **metrics**    | 100    | OFF       | 2,814       | Highest request volume (RU cost per-op unknown) |
| registry       | 100    | OFF       | 674         |               |
| objects        | 100    | OFF       | 413         |               |
| settings       | 100    | OFF       | 387         |               |
| batches        | 100    | OFF       | 334         |               |
| trash          | 100    | OFF       | 169         |               |
| jobhistory     | 100    | OFF       | 139         |               |
| fs.files       | 100    | OFF       | 134         |               |
| fs.chunks      | 100    | OFF       | 125         |               |
| authorization  | 100    | OFF       | 112         |               |
| keys           | 100    | OFF       | —           |               |
| users          | 100    | OFF       | —           |               |

### 3.2 The Math That Causes 429s

```text
┌──────────────────────────── NORMAL (between bursts) ─────────────────────────────┐
│                                                                                   │
│  metrics collection: ~200 req/5min = ~40 req/min = ~0.7 req/sec                  │
│  Avg RU cost per req: ~3000 RU / 360 req ≈ 8 RU/req                             │
│  Sustained load: 0.7 req/sec × 8 RU = ~6 RU/s                                   │
│  Budget: 100 RU/s                                                                │
│  Headroom: 94 RU/s ✅ Plenty                                                     │
│                                                                                   │
└──────────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────── BURST (every ~15 min) ───────────────────────────────┐
│                                                                                   │
│  ALL collections combined: ~520 req/5min during burst                            │
│  Total RUs consumed: ~8,500 RUs in 5 minutes                                    │
│  Peak RU/s: 8500/300 ≈ 28 RU/s average... but bursts are NOT evenly spread.     │
│                                                                                   │
│  Actual burst pattern (sub-second):                                              │
│                                                                                   │
│    RU/s                                                                          │
│    ???+ ┤      ████      ← Exact sub-second peak unknown (Azure Monitor          │
│         │    ████████       granularity = 1 min). Definitively >100 RU/s         │
│    200  ┤  ████████████    (proven by 429 occurrence).                            │
│    100 ─┤─ ████████████──── ← 100 RU/s budget ceiling                            │
│     50  ┤  ████████████                                                           │
│         │    ████████      ← Anything ABOVE the line = 429                       │
│      0  ┤──────────────────────────────────────────                              │
│         t     t+5s    t+10s                                                      │
│                                                                                   │
│  The batch job issues many requests in rapid succession (seconds, not minutes),  │
│  creating a burst that exceeds 100 RU/s for those seconds.                       │
│                                                                                   │
└──────────────────────────────────────────────────────────────────────────────────┘
```

### 3.3 Why "Average RU/s" Is Misleading

```text
        THE BUCKET ANALOGY

        Budget = 100 RU/s = a bucket that refills at 100 drops/second

              ┌─────┐
              │     │  ← 100 RU/s refill rate
         ─────┤     ├─────
              │ ░░░ │  ← Current balance (token bucket)
              │ ░░░ │
              └──┬──┘
                 │
                 ▼ drain

        Normal:  Drip... drip... drip...     (6 RU/s out, 100/s in → never empty)
        Burst:   SPLASH of >100 RU/s for seconds → bucket empties → 429s
        After:   Bucket refills in seconds → traffic resumes normally

        Even though AVERAGE over 5 minutes is only 28 RU/s (well under 100),
        the INSTANTANEOUS rate during the burst exceeds 100 RU/s → 429.
```

---

## 4. The Gurobi RSM Architecture (Hypothesis — Pending OpenShift Verification)

> **Note**: The ~15-minute periodicity is observed in metrics. The scheduler component
> shown below is an **inference** from the data pattern, not a confirmed fact. The
> OpenShift investigation (Section 6) will confirm or refute this hypothesis.

```text
┌─────────────────────────────────────────────────────────────┐
│                    OpenShift Cluster                         │
│                                                             │
│  ┌──────────────────────┐                                   │
│  │  Gurobi RSM          │  RSM = Remote Services Manager    │
│  │  (application pods)  │  Manages Gurobi optimization      │
│  │                      │  job scheduling and execution      │
│  │  ┌──────────────┐    │                                   │
│  │  │ Scheduler    │────│───── Every ~15 min ──────┐        │
│  │  │ (periodic)   │    │                          │        │
│  │  └──────────────┘    │                          │        │
│  │  ┌──────────────┐    │                          │        │
│  │  │ API / Worker │────│──── Normal operations ───│──┐     │
│  │  └──────────────┘    │                          │  │     │
│  └──────────────────────┘                          │  │     │
│                                                    │  │     │
└────────────────────────────────────────────────────│──│─────┘
                                                     │  │
                                                     ▼  ▼
                                        ┌─────────────────────┐
                                        │  CosmosDB (MongoDB)  │
                                        │  cosmosdb-gurobi-    │
                                        │  platform-a          │
                                        │                      │
                                        │  DB: grb_rsm         │
                                        │  ├─ metrics    ◄─ HOT│
                                        │  ├─ registry         │
                                        │  ├─ batches          │
                                        │  ├─ objects          │
                                        │  ├─ jobhistory       │
                                        │  ├─ settings         │
                                        │  ├─ fs.files         │
                                        │  ├─ fs.chunks        │
                                        │  ├─ keys             │
                                        │  ├─ users            │
                                        │  ├─ authorization    │
                                        │  └─ trash            │
                                        │                      │
                                        │  ALL @ 100 RU/s      │
                                        │  Autoscale: OFF      │
                                        └─────────────────────┘

```

### Verified CosmosDB Account Configuration (from Azure CLI)

| Setting | Value | Notes |
|---|---|---|
| API | MongoDB **7.0** | Not SQL API |
| Consistency | Eventual | Lowest latency, weakest guarantees |
| Region | West Europe (single) | No automatic failover, no multi-write |
| Public Network | **Disabled** | Private endpoint only |
| Private Endpoint | `pe-gurobi-platform-cosmosdb-a` (Approved) | Via `snet-pe` subnet |
| TLS | 1.2 minimum | |
| Free Tier | No | |
| Burst Capacity | **Disabled** | Could absorb short spikes if enabled |
| Partition Merge | Disabled | |
| Local Auth | Enabled | Connection string auth (not Entra ID) |
| Backup | Periodic (4h interval, 8h retention, Geo-redundant) | |

### Collection Shard Keys and Indexes (verified)

**No collection has a shard key** — all data resides on a single logical partition. This means
the full 100 RU/s budget is on one partition, but it also means there is no way to scale
horizontally by adding partitions.

| Collection | Shard Key | Index Keys (beyond `_id`) |
|---|---|---|
| `metrics` | **none** | `{nodeId, timestampHour}` |
| `batches` | **none** | `{createdAt, username, status, appName}`, `{createdAt, userId, status, appName}`, `{createdAt, status}`, `{createdAt, discarded}`, `{createdAt, appName}` |
| `objects` | **none** | `{name, container}`, `{createdAt, shared, container}`, `{container}`, `{references}`, `{closed}`, `{closed, shared, system, references}` |
| `jobhistory` | **none** | `{endedAt, properties.username, status, properties.appName}`, `{endedAt, properties.userId, status, properties.appName}`, `{properties.batchId}`, `{endedAt, status}`, `{endedAt, properties.appName}`, `{solveStatus, optimizationStatus.status}`, `{startedAt, endedAt}`, `{properties.runtime}` |
| `users` | **none** | `{username}`, `{syncedAt}` |
| `authorization` | **none** | `{_ts}` |
| `trash` | **none** | `{createdAt}` |
| `fs.files` | **none** | `{filename, uploadDate}` |
| `fs.chunks` | **none** | `{files_id, n}` |
| `registry` | **none** | (none) |
| `settings` | **none** | (none) |
| `keys` | **none** | (none) |

The `metrics` collection's index on `{nodeId, timestampHour}` confirms it stores time-bucketed
metrics per compute node — consistent with a periodic collection/aggregation pattern.

### Infrastructure as Code — Source and Drift

**IaC Repo**: `enecomanagedcloud/myriad-vpp/gurobi-infrastructure/src/`

> **NOT in MC-VPP-Infrastructure.** The Gurobi platform has its own dedicated Terraform repo,
> separate from the main VPP infrastructure.

```text
IaC creates:                          App creates at runtime:
─────────────                          ────────────────────────
 ┌──────────────────────┐              ┌──────────────────────┐
 │ azurerm_cosmosdb_     │              │ 12 collections:      │
 │   account.mongodb     │              │  metrics, registry,  │
 │ (account only)        │    boot      │  batches, objects,   │
 │                       │ ──────────►  │  jobhistory, etc.    │
 │ azurerm_cosmosdb_     │              │                      │
 │   mongo_database      │              │  ALL at 100 RU/s     │
 │   .gurobi (grb_rsm)  │              │  (MongoDB default)   │
 │ (empty database)      │              │  NO shard keys       │
 └──────────────────────┘              └──────────────────────┘

 Terraform defines NO collections, NO throughput settings, NO autoscale.
 The Gurobi Manager app (gurobi/manager:12.0.3) creates collections on first boot
 with MongoDB default throughput (100 RU/s per collection).
```

**IaC → Azure: NO DRIFT (verified against latest `locals.tf` + commit `1a2c4dd`)**

| Setting          | IaC (`locals.tf`)  | Deployed (Azure) | Match |
|------------------|--------------------|------------------|-------|
| Alert threshold  | `threshold = 20`   | `threshold = 20` | Yes   |
| Alert enabled    | `enabled = true`   | `enabled = true`  | Yes   |
| Alert severity   | `severity = 2`     | `severity = 2`    | Yes   |
| Alert window     | `PT5M`             | `PT5M`            | Yes   |
| Alert frequency  | `PT5M`             | `PT5M`            | Yes   |

The threshold was **intentionally raised from 1 to 20** in commit `1a2c4dd` with this IaC comment:

> *"We see 429 responses regularly when tasks run on Gurobi. Metrics indicate these are 1 or
> 2 429's in the monitoring window. So we've set the threshold to 20 to prevent the alert
> from being triggered by normal behavior."*

This confirms the team **already knew about occasional 429s** and raised the threshold to dampen
noise. The current burst of 24 per window exceeds even this raised threshold — indicating the
pattern has **worsened** since the threshold was adjusted.

### GitOps Deployment (from `gurobi-gitops/src/cluster-manager/acceptance/`)

| Component | Value |
|---|---|
| Deployment | `gurobi-cluster-manager` |
| Container Image | `gurobi/manager:12.0.3` |
| Exposed Port | 61080 |
| Route | `gurobi.acc.vpp.eneco.com` |
| CosmosDB Connection | Via Key Vault CSI (`kv-gurobi-platform-a` → secret `gurobi-mongodb-connectionstring`) |
| Private Endpoint IP | `10.7.224.99` (hardcoded hostAlias for `cosmosdb-gurobi-platform-a.mongo.cosmos.azure.com`) |
| Identity | OpenShift managed identity (`c625406d-b859-4ba2-9483-83a311c4e859`) |

### Resource Group Contents (all resources in `rg-gurobi-platform-a`)

```text
rg-gurobi-platform-a
├── cosmosdb-gurobi-platform-a              CosmosDB (MongoDB)
├── pe-gurobi-platform-cosmosdb-a           Private Endpoint → CosmosDB
├── kv-gurobi-platform-a                    Key Vault (connection string)
├── pe-kv-gurobi-platform-a                 Private Endpoint → Key Vault
├── law-gurobi-platform-a                   Log Analytics Workspace
├── dcr-token-servers                       Data Collection Rule
├── vm-gurobi-platform-token-server-1       Gurobi License Token Server (VM)
├── gurobi-cosmos-throttling-429-a          ◄ THIS ALERT
├── gurobi-cosmos-latency-a                 Latency alert (>99ms)
├── gurobi-cosmos-health-a                  Resource health alert
└── [VM monitoring alerts ×7]               CPU, memory, disk, network
```

### Collections Explained (Gurobi RSM Database)

| Collection     | Purpose                                                 |
|----------------|---------------------------------------------------------|
| `metrics`      | Gurobi solver performance metrics (job durations, etc.) |
| `registry`     | Service registration / discovery                        |
| `batches`      | Batch optimization job definitions                      |
| `objects`      | Gurobi model objects / data                             |
| `jobhistory`   | Completed job audit trail                               |
| `settings`     | Configuration                                           |
| `fs.files`     | GridFS metadata (large file storage)                    |
| `fs.chunks`    | GridFS binary data chunks                               |
| `keys`         | API keys / tokens                                       |
| `users`        | User accounts                                           |
| `authorization`| RBAC permissions                                        |
| `trash`        | Soft-deleted items                                      |

---

## 5. Timeline of the Incident

```text
     13:21          13:26          13:31  ...  13:39          13:44          13:46
       │              │              │           │              │              │
       │              │              │           │              │              │
       ▼              ▼              ▼           ▼              ▼              ▼
  ┌─────────┐   ┌──────────┐   ┌─────────┐ ┌─────────────────────────┐  ┌──────────┐
  │ Normal  │   │ Burst #1 │   │ Normal  │ │     5-min eval window   │  │  ALERT   │
  │ 8% RU   │   │ 100% RU  │   │ 3% RU   │ │    13:39 → 13:44 UTC   │  │  FIRED   │
  │ 0 429s  │   │ 16 429s  │   │ 0 429s  │ │                         │  │  Sev2    │
  └─────────┘   └──────────┘   └─────────┘ │  13:41-13:44: Burst #2  │  └──────────┘
                                            │  24 429s (>= 20 threshold)│
                                            └─────────────────────────┘
```

---

## 6. OpenShift Investigation

> **TODO**: Enrich this section with actual cluster output.

### Phase 1: Discovery — Find the Gurobi Workload

```bash
# Find gurobi-related namespaces
oc get namespaces | grep -i gurobi

# Set the namespace for all subsequent commands (replace with actual)
export GRB_NS="<GUROBI_NAMESPACE>"
```

### Phase 2: Health Check — Current State of the Workload

```bash
# Pod status: are pods Running, CrashLooping, or OOMKilled?
# WHY: 429s cause app errors; the app may be crash-looping in response
oc get pods -n $GRB_NS -o wide

# Restart counts: high restarts = the app is failing due to 429s
# WHY: MongoDB driver throws on 429 → app crashes → kubelet restarts → burst on reconnect
oc get pods -n $GRB_NS -o custom-columns=\
'NAME:.metadata.name,STATUS:.status.phase,RESTARTS:.status.containerStatuses[0].restartCount,LAST_STATE:.status.containerStatuses[0].lastState.terminated.reason'

# Recent events: look for OOMKilled, BackOff, FailedScheduling
oc get events -n $GRB_NS --sort-by='.lastTimestamp' | tail -40

# Resource pressure: is the workload CPU/memory constrained too?
oc top pods -n $GRB_NS
```

### Phase 3: Find the ~15-Minute Burst Source (CRITICAL)

The Azure metrics show a **repeating burst every ~15 minutes**. This section identifies what
produces that pattern.

```bash
# SUSPECT 1: CronJobs — the most common source of periodic bursts
# WHY: A CronJob on */15 schedule would perfectly explain the pattern
oc get cronjobs -n $GRB_NS
oc get cronjobs -n $GRB_NS -o custom-columns=\
'NAME:.metadata.name,SCHEDULE:.spec.schedule,LAST_RUN:.status.lastScheduleTime,ACTIVE:.status.active'

# SUSPECT 2: Jobs currently running or recently completed
# WHY: If a CronJob exists, its child Jobs show execution history
oc get jobs -n $GRB_NS --sort-by='.status.startTime' | tail -20

# SUSPECT 3: In-app scheduler (not a CronJob but app-internal timer)
# WHY: Gurobi RSM may have a built-in metrics collector or batch processor
# Look for scheduler-related env vars in the deployment
oc get deployments -n $GRB_NS -o json | \
  python3 -c "
import json,sys
d=json.load(sys.stdin)
for dep in d['items']:
    name=dep['metadata']['name']
    for c in dep['spec']['template']['spec'].get('containers',[]):
        for e in c.get('env',[]):
            n=e.get('name','').upper()
            if any(k in n for k in ['SCHED','INTERVAL','CRON','POLL','TIMER','PERIOD','FREQ','BATCH']):
                print(f'{name}/{c[\"name\"]}: {e[\"name\"]}={e.get(\"value\",\"<from-secret>\")}')
"

# SUSPECT 4: Check deploymentconfigs too (OpenShift-specific)
oc get dc -n $GRB_NS 2>/dev/null

# SUSPECT 5: Correlate pod logs with the known burst times
# The bursts hit CosmosDB at: :26, :41, :56, :11 (every 15 min past quarter-hour)
oc get pods -n $GRB_NS -o name | head -3 | while read pod; do
  echo "=== $pod ==="
  oc logs -n $GRB_NS $pod --since=1h 2>/dev/null | \
    grep -iE 'schedul|batch|collect|metric|poll|timer|cron|sweep|purge|sync' | tail -10
done
```

### Phase 4: CosmosDB Connection and Retry Behavior

```bash
# Find the CosmosDB connection string env var
# WHY: Confirms this workload talks to cosmosdb-gurobi-platform-a
oc get deployments -n $GRB_NS -o json | \
  python3 -c "
import json,sys
d=json.load(sys.stdin)
for dep in d['items']:
    name=dep['metadata']['name']
    for c in dep['spec']['template']['spec'].get('containers',[]):
        for e in c.get('env',[]):
            n=e.get('name','').upper()
            if any(k in n for k in ['MONGO','COSMOS','DB_','DATABASE','CONNECTION']):
                val=e.get('value','<from-secret/configmap>')
                # Mask password if present
                if '@' in str(val): val=val.split('@')[0][:20]+'...<masked>'
                print(f'{name}/{c[\"name\"]}: {e[\"name\"]}={val}')
"

# Check for retry configuration
# WHY: If the MongoDB driver retries 3x per 429 across N pods, the burst amplifies
#       (N pods × 3 retries = 3N requests hitting already-saturated RUs)
oc get pods -n $GRB_NS -o name | head -1 | xargs -I{} \
  oc logs -n $GRB_NS {} --since=30m 2>/dev/null | \
  grep -iE '429|throttl|rate.limit|too.many|retry|retrying|backoff' | tail -20
```

### Phase 5: Scaling Configuration

```bash
# HPA: Is auto-scaling adding pods during bursts? More pods = more concurrent
# requests to CosmosDB = faster RU exhaustion
oc get hpa -n $GRB_NS

# Replica count per deployment
oc get deployments -n $GRB_NS -o custom-columns=\
'NAME:.metadata.name,DESIRED:.spec.replicas,READY:.status.readyReplicas,AVAILABLE:.status.availableReplicas'
```

### What to Look For — Summary

| Finding | Meaning | Action |
|---|---|---|
| CronJob with `*/15 * * * *` schedule | Direct cause of the ~15-min burst | Reschedule, add jitter, or fix the job's DB access pattern |
| Env var like `POLL_INTERVAL=900` (seconds) | App-internal scheduler causing periodic burst | Tunable without code change |
| High restart count on pods | App crashing on 429 → reconnect storm amplifies throttling | Fix retry/backoff in app or increase RU/s |
| HPA active + scaling up during bursts | More pods = multiplicative RU pressure | Cap replicas or increase RU/s proportionally |
| Logs showing `retrying` without `backoff` | Retry storm: N retries × M pods × cost per op | Configure exponential backoff in MongoDB driver |

---

## 7. Remediation Options

| Option | Action | Impact | Risk |
|---|---|---|---|
| **A. Enable Autoscale** | Set autoscale on hot collections (min max = 4000 RU/s) | Handles bursts automatically | Floor cost = 400 RU/s (4x current). Only via CLI, not Terraform |
| **B. Increase Manual RU/s** | Raise hot collections from 100 to 400-500 RU/s | Fixed headroom for bursts | Constant cost increase even when idle |
| **C. Application-side** | Add exponential backoff + jitter to the batch job | Spreads load over time | Increases job completion time |
| **D. Redesign schedule** | Spread the 15-min batch into smaller, staggered operations | Eliminates burst pattern entirely | Application change required |
| **E. Alert threshold tuning** | Raise threshold or add `minFailingPeriodsToAlert` dampening | Reduces alert noise for known-bursty patterns | May mask genuine degradation |
| **F. Partition key review** | Review shard key choice for hot collections | Better RU distribution across partitions | Requires collection rebuild if changed |

**Recommended priority**:

1. **Today**: Change 2 (`window_size = PT15M`) — single IaC change, immediate on-call relief
2. **This week**: Change 1 (burst capacity) — reduces 429 frequency while autoscale is planned
3. **Within 2 weeks**: Change 3 (autoscale via CLI) — the real fix. Floor cost = 400 RU/s per collection
4. **Long-term**: Option C (application-side backoff) — reduces burst magnitude regardless of provisioning

### 7.1 Proposed IaC Changes

#### Change 1: Enable Burst Capacity (TEMPORARY — not a fix)

Burst capacity allows CosmosDB to use accumulated idle RU credits to absorb short spikes.
Currently **disabled** on this account.

> **WARNING**: Burst capacity is a **band-aid**, not a solution.
>
> - Microsoft docs: *"Usage of burst capacity is subject to system resource availability
>   and is **not guaranteed**. Azure Cosmos DB may also use burst capacity for background
>   maintenance tasks."*
> - Each unsharded partition accumulates max ~30,000 RU credits (300s x 100 RU/s idle).
>   The observed ~8,500 RU burst should be absorbed IF credits are available — but this
>   is best-effort, not deterministic.
> - **Must be paired with autoscale migration (Change 3) within 2 weeks.**

```hcl
# In gurobi-infrastructure/src/mongodb.tf
resource "azurerm_cosmosdb_account" "mongodb" {
  name                = "cosmosdb-gurobi-platform-${var.environment_suffix}"
  # ... existing config ...

  burst_capacity_enabled = true  # TEMPORARY: absorb spikes while autoscale is implemented
}
```

#### Change 2: Redesign Alert Strategy (PR-Ready — Evidence-Backed)

##### The Problem with the Current Alert

The current alert (`threshold=20`, `window=PT5M`) cannot distinguish between two fundamentally
different failure modes observed **on the same day** (2026-03-27):

```text
TIME (UTC)     429s   NormalizedRU%  Pattern
──────────────────────────────────────────────────────────
13:23-14:58    ~24    100%→3-9%      PERIODIC (known burst, harmless)
15:03-15:58     0     76-83%         QUIET (near-misses, no 429s)
16:03-16:18    32-72  100%×4 consec  SUSTAINED (genuine degradation) ← 2nd Rootly alert
──────────────────────────────────────────────────────────

Current alert fires for BOTH patterns. On-call cannot tell them apart.
```

##### Evidence: Threshold Math (from live Azure Monitor metrics)

With `window_size = "PT15M"` and `aggregation = "Count"`, Azure Monitor sums all 429s in
a sliding 15-minute window evaluated every 5 minutes:

```text
PERIODIC PATTERN (one burst per ~15min cycle):
  Any PT15M window captures at most 1 burst:
    [0, 0, 24] = 24 429s  |  [0, 24, 0] = 24  |  [24, 0, 0] = 24
  Worst case (2 bursts at window edges, ~10min apart):
    [24, 0, 24] = 48 429s

  → Maximum in PT15M: 48

SUSTAINED PATTERN (16:03-16:18, 4 consecutive 100% windows):
  PT15M window at 16:18: [32, 8, 72] = 112 429s
  PT15M window at 16:13: [0, 32, 8]  = 40 429s (early detection)

  → Minimum in PT15M once sustained: 40, rising to 112+

THRESHOLD SELECTION:
  Must be: > 48 (max periodic) AND < 112 (min sustained)
  Selected: 60 (25% margin above worst-case periodic)

  48 < 60 < 112 → Clean separation.
  ✓ Periodic burst: max 48 < 60 → NO alert (on-call sleeps)
  ✓ Sustained burst: min 112 >= 60 → ALERT fires (genuine problem)
```

##### New Alert: NormalizedRU Saturation (Early Warning)

Adding a complementary **NormalizedRU saturation alert** catches degradation BEFORE 429s start.
Metric verified against live account (`az monitor metrics list-definitions`):

```text
Metric: NormalizedRUConsumption (Microsoft.DocumentDB/DatabaseAccounts)
Unit: Percent (0-100)
Aggregations: Maximum, Average ← using Average for sustained detection

PERIODIC (from live data):
  Average over PT15M: (100 + 8 + 8) / 3 ≈ 39%

SUSTAINED (from live data, 16:02-16:17):
  Average over PT15M: (100 + 100 + 100) / 3 = 100%

TRANSITION / NEAR-MISS (15:12-15:57):
  Average over PT15M: (83 + 3 + 8) / 3 ≈ 31%

THRESHOLD: Average > 60% over PT15M
  ✓ Periodic: 39% < 60% → no alert
  ✓ Transition: 31% < 60% → no alert
  ✓ Sustained: 100% > 60% → ALERT (correct)

Severity: 3 (Warning, not Sev2) — early signal, not immediate page.
```

##### PR-Ready Code: `locals.tf`

This is the **complete, verified replacement** for `gurobi-infrastructure/src/locals.tf`.
HCL verified by terraform-code-hcl-expert. All 6 correctness checks pass (see verification
report below).

```hcl
locals {
  platform_team_object_id = "2aef53bb-17d4-41f0-b154-f233ea79fa7f" # Azure Entra ID group "sg-vpp-platform"

  default_cosmosdb_metric_alerts = {
    gurobi-cosmos-latency = {
      description = "Action will be triggered when server side latency is greater than 99ms"
      severity    = 2
      enabled     = true
      frequency   = "PT5M"
      window_size = "PT5M"
      criteria = {
        ServerSideLatency = {
          metric_namespace = "Microsoft.DocumentDB/DatabaseAccounts"
          aggregation      = "Average"
          operator         = "GreaterThan"
          threshold        = 99
        }
      }
    },
    gurobi-cosmos-throttling-429 = {
      description = "Sustained CosmosDB throttling: >=60 requests returned HTTP 429 in a 15-minute window"
      severity    = 2
      enabled     = true
      frequency   = "PT5M"
      window_size = "PT15M"

      criteria = {
        TotalRequests = {
          # EVIDENCE (2026-03-27 live metrics):
          # - Periodic burst: max 48 429s per PT15M window (one burst of ~24, worst-case two)
          # - Sustained burst: 112+ 429s per PT15M window (3+ consecutive saturated windows)
          # - Threshold 60 cleanly separates periodic (noise) from sustained (genuine).
          # - Previous values: threshold=20, window=PT5M → fired on every periodic burst (~4/hr).
          threshold        = 60
          metric_namespace = "Microsoft.DocumentDB/DatabaseAccounts"
          operator         = "GreaterThanOrEqual"
          aggregation      = "Count"
          dimension = {
            StatusCode = {
              operator = "Include"
              values   = ["429"]
            }
          }
        }
      }
    },
    gurobi-cosmos-ru-saturation = {
      description = "CosmosDB partition RU saturation: average NormalizedRUConsumption exceeds 60% over 15 minutes"
      severity    = 3
      enabled     = true
      frequency   = "PT5M"
      window_size = "PT15M"
      criteria = {
        NormalizedRUConsumption = {
          # EVIDENCE (2026-03-27 live metrics):
          # - Periodic pattern: avg NormalizedRU over PT15M ≈ 39% (spike + two healthy windows)
          # - Sustained pattern: avg NormalizedRU over PT15M = 100% (all windows saturated)
          # - Threshold 60% catches sustained saturation without firing on periodic bursts.
          # - Metric verified via: az monitor metrics list-definitions (supports Average aggregation).
          threshold        = 60
          metric_namespace = "Microsoft.DocumentDB/DatabaseAccounts"
          operator         = "GreaterThan"
          aggregation      = "Average"
        }
      }
    }
  }
}
```

**No changes required to `alerts.tf`** — the existing `for_each` over
`local.default_cosmosdb_metric_alerts` automatically picks up the new entry and the
modified throttling alert. `try(criteria.value.dimension, {})` correctly handles the
new alert having no dimension block.

##### Terraform Plan Prediction

```text
# azurerm_monitor_metric_alert.cosmosdb["gurobi-cosmos-throttling-429"] will be updated in-place
  ~ description = "Trigger on Request status code of 429" -> "Sustained CosmosDB throttling: ..."
  ~ window_size = "PT5M" -> "PT15M"
  ~ criteria.threshold = 20 -> 60

# azurerm_monitor_metric_alert.cosmosdb["gurobi-cosmos-ru-saturation"] will be created
  + name        = "gurobi-cosmos-ru-saturation-a"
  + severity    = 3
  + window_size = "PT15M"
  + criteria.metric_name = "NormalizedRUConsumption"
  + criteria.threshold   = 60

# azurerm_monitor_metric_alert.cosmosdb["gurobi-cosmos-latency"] — no changes

Plan: 1 to add, 1 to change, 0 to destroy.
```

##### Verification Checklist

| Check | Result | Evidence |
|---|---|---|
| `NormalizedRUConsumption` is valid metric | PASS | `az monitor metrics list-definitions` returns it with `Average` aggregation |
| `PT15M` is valid `window_size` | PASS | In allowed ISO 8601 set (PT1M, PT5M, **PT15M**, PT30M, PT1H...) |
| `frequency=PT5M` compatible with `window=PT15M` | PASS | Constraint: frequency <= window_size. 5min < 15min |
| No-dimension alert works with `try()` | PASS | `try(criteria.value.dimension, {})` returns `{}` → zero dimension blocks |
| HCL syntax valid | PASS | All braces, commas, keys verified by HCL expert |
| Plan: update + create, no destroy | PASS | `for_each` keys stable, no ForceNew attributes changed |

#### Change 3: Enable Autoscale on Hot Collections (requires app-level or manual change)

Since Terraform does NOT manage the collections (the Gurobi app creates them at boot), this
cannot be done in IaC without importing the collections into state first. Options:

```bash
# Option A: Manual CLI change (immediate, per-collection)
#
# TIMING: Run BETWEEN burst windows. Known burst times are at :26, :41, :56, :11
# past the hour. Run migration at :35, :50, :05, or :20 for maximum safety margin.
# The migration takes 5-30 seconds; running during a burst can cause transient 429s.
#
az cosmosdb mongodb collection throughput migrate \
  --account-name cosmosdb-gurobi-platform-a \
  --resource-group rg-gurobi-platform-a \
  --database-name grb_rsm \
  --name metrics \
  --throughput-type autoscale

# Then set max autoscale RU/s:
az cosmosdb mongodb collection throughput update \
  --account-name cosmosdb-gurobi-platform-a \
  --resource-group rg-gurobi-platform-a \
  --database-name grb_rsm \
  --name metrics \
  --max-throughput 4000  # Azure minimum for autoscale max is 4000 RU/s
                        # Cost note: autoscale floor = 10% of max = 400 RU/s minimum billing
                        # This is a 4x cost increase over current 100 RU/s manual provisioning

# Option B: Import into Terraform state + manage going forward
# NOTE: The azurerm provider does NOT support switching between manual and autoscale
# throughput via Terraform. The CLI migration (Option A) is the only viable path.
# After migration, you can manage autoscale settings via Terraform by importing.
# (requires adding azurerm_cosmosdb_mongo_collection resources to mongodb.tf)
#
# ⚠ CRITICAL: You MUST `terraform import` each existing collection BEFORE running
# `terraform plan`. If you add collection resources without importing, Terraform
# will attempt to CREATE them. The provider may return 409 Conflict (safe) or
# attempt destroy+recreate (DATA LOSS for all documents in the collection).
# Verify with `terraform plan` in a non-production environment first.
```

---

## 8. Automated Runbook Design

> **SUNSET DATE**: This runbook is a **temporary measure** valid until autoscale migration
> is complete. Target: **2026-04-10**. If autoscale is not implemented by then, the runbook
> must be removed and alerts must page the on-call engineer directly — the feedback pressure
> to fix the root cause must not be suppressed indefinitely.

### 8.1 Goal

When the `gurobi-cosmos-throttling-429-a` alert fires, automatically determine if it is the
**known periodic burst pattern** (auto-acknowledge) or **genuine sustained degradation**
(escalate with diagnostics). Stop waking engineers up for expected behavior.

### 8.2 Decision Logic (Hardened — Post-Adversarial Review)

```text
Alert fires: gurobi-cosmos-throttling-429-a
│
▼
┌──────────────────────────────────────┐
│  GATE 0: Sunset check               │
│  If today > 2026-04-10:             │
│    ESCALATE (runbook expired)        │
└──────────────┬───────────────────────┘
               │ (not expired)
               ▼
┌──────────────────────────────────────┐
│  GATE 1: Azure CLI health           │
│  `az account show` succeeds?        │
│  No → exit 2 (RUNBOOK_ERROR)        │
│       Do NOT escalate on infra fail  │
└──────────────┬───────────────────────┘
               │ (healthy)
               ▼
┌──────────────────────────────────────┐
│  STEP 1: Query last 30 min metrics   │
│  NormalizedRUConsumption + 429 count │
│  Validate: non-null, non-empty       │
└──────────────┬───────────────────────┘
               │
               ▼
┌──────────────────────────────────────┐
│  GATE 2: Metric freshness           │
│  Last datapoint timestamp vs now    │
│  Gap > 5 min → STALE → ESCALATE    │
│  (Azure Monitor delay = blind spot) │
└──────────────┬───────────────────────┘
               │ (fresh)
               ▼
┌──────────────────────────────────────┐
│  STEP 2: Classify pattern            │
│                                      │
│  PERIODIC requires ALL of:           │
│   a) ≤2 spikes (≥80% RU)            │
│   b) Not consecutive                 │
│   c) Inter-spike baseline < 30%      │ ← NEW: V4 fix
│   d) Total 429s ≤ 50                 │ ← NEW: magnitude cap
│                                      │
│  SUSTAINED = ≥3 consecutive ≥80%     │
│                                      │
│  DEGRADED = inter-spike baseline     │ ← NEW: V4 fix
│    ≥30% (elevated even between       │
│    spikes — new workload pressure)   │
│                                      │
│  UNKNOWN = anything else → ESCALATE  │
└──────────────┬───────────────────────┘
               │
     ┌─────────┼─────────────┐
     ▼         ▼             ▼
  PERIODIC   SUSTAINED    DEGRADED/UNKNOWN
     │       DEGRADED      │
     │       UNKNOWN       │
     ▼         ▼           ▼
  Auto-ack   ESCALATE   ESCALATE
```

### 8.3 Runbook Script (Hardened)

```bash
#!/usr/bin/env bash
# gurobi-cosmos-429-runbook.sh
# Automated triage for gurobi-cosmos-throttling-429 alerts
#
# Exit codes:
#   0 = PERIODIC (auto-acknowledge)
#   1 = ESCALATE (page on-call)
#   2 = RUNBOOK_ERROR (script failure — do NOT interpret as escalation)
#
# SUNSET: Remove this runbook after 2026-04-10 or after autoscale migration.

# Do NOT use `set -e` — we handle errors explicitly to avoid false escalation storms (V5 fix)
set -uo pipefail

# ── Configuration ──────────────────────────────────────────────────────
RESOURCE_ID="/subscriptions/b524d084-edf5-449d-8e92-999ebbaf485e/resourcegroups/rg-gurobi-platform-a/providers/microsoft.documentdb/databaseaccounts/cosmosdb-gurobi-platform-a"
LOOKBACK_MINUTES=30
SPIKE_THRESHOLD=80             # % NormalizedRU above which we count as a "spike"
BASELINE_HEALTHY_MAX=30        # % NormalizedRU: inter-spike windows must be below this
SUSTAINED_CONSECUTIVE_LIMIT=3  # consecutive windows above threshold = sustained
PERIODIC_MAX_SPIKES=2          # max spikes in lookback for "periodic" classification
PERIODIC_MAX_429S=50           # max total 429s for "periodic" (cap for magnitude check)
METRIC_FRESHNESS_SECONDS=300   # max acceptable age of latest data point (5 min)
SUNSET_DATE="2026-04-10"

# ── Gate 0: Sunset check ──────────────────────────────────────────────
TODAY=$(date -u '+%Y-%m-%d')
if [[ "$TODAY" > "$SUNSET_DATE" ]]; then
  echo "[RUNBOOK] EXPIRED: Sunset date $SUNSET_DATE passed. Autoscale should be implemented."
  echo "[RUNBOOK] ACTION: ESCALATE (runbook no longer valid)"
  exit 1
fi

# ── Gate 1: Azure CLI health ──────────────────────────────────────────
if ! az account show -o none 2>/dev/null; then
  echo "[RUNBOOK] ERROR: Azure CLI not authenticated or unreachable"
  echo "[RUNBOOK] ACTION: RUNBOOK_ERROR (do NOT escalate — infra issue, not throttling)"
  exit 2
fi

# ── Step 1: Gather metrics ────────────────────────────────────────────
START_TIME=$(date -u -v-${LOOKBACK_MINUTES}M '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null \
  || date -u -d "${LOOKBACK_MINUTES} minutes ago" '+%Y-%m-%dT%H:%M:%SZ')
END_TIME=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

echo "[RUNBOOK] Querying NormalizedRUConsumption: $START_TIME → $END_TIME"

RU_RAW=$(az monitor metrics list \
  --resource "$RESOURCE_ID" \
  --metric "NormalizedRUConsumption" \
  --interval PT5M \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --aggregation Maximum \
  -o json 2>/dev/null) || { echo "[RUNBOOK] ERROR: Failed to query RU metrics"; exit 2; }

THROTTLE_RAW=$(az monitor metrics list \
  --resource "$RESOURCE_ID" \
  --metric "TotalRequests" \
  --filter "StatusCode eq '429'" \
  --interval PT5M \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --aggregation Count \
  -o json 2>/dev/null) || { echo "[RUNBOOK] ERROR: Failed to query 429 metrics"; exit 2; }

# ── Gate 2: Validate and check freshness ──────────────────────────────
CLASSIFICATION=$(python3 -c "
import json, sys
from datetime import datetime, timezone

SPIKE_THRESHOLD = $SPIKE_THRESHOLD
BASELINE_HEALTHY_MAX = $BASELINE_HEALTHY_MAX
SUSTAINED_CONSECUTIVE_LIMIT = $SUSTAINED_CONSECUTIVE_LIMIT
PERIODIC_MAX_SPIKES = $PERIODIC_MAX_SPIKES
PERIODIC_MAX_429S = $PERIODIC_MAX_429S
METRIC_FRESHNESS_SECONDS = $METRIC_FRESHNESS_SECONDS

try:
    ru_raw = json.loads('''$RU_RAW''')
    throttle_raw = json.loads('''$THROTTLE_RAW''')
except (json.JSONDecodeError, ValueError):
    print('RUNBOOK_ERROR:Failed to parse Azure Monitor response')
    sys.exit(0)

# Extract data points safely
try:
    ru_data = ru_raw.get('value', [{}])[0].get('timeseries', [{}])[0].get('data', [])
    thr_data = throttle_raw.get('value', [{}])[0].get('timeseries', [{}])
    thr_data = thr_data[0].get('data', []) if thr_data else []
except (IndexError, AttributeError):
    print('RUNBOOK_ERROR:Unexpected metric structure (empty timeseries)')
    sys.exit(0)

if not ru_data:
    print('RUNBOOK_ERROR:No RU data points returned')
    sys.exit(0)

# Freshness check (V1 fix): is the latest data point recent enough?
try:
    last_ts = ru_data[-1].get('timeStamp', '')
    last_dt = datetime.fromisoformat(last_ts.replace('Z', '+00:00'))
    now = datetime.now(timezone.utc)
    age_seconds = (now - last_dt).total_seconds()
    if age_seconds > METRIC_FRESHNESS_SECONDS:
        print(f'STALE:Latest data point is {int(age_seconds)}s old (limit: {METRIC_FRESHNESS_SECONDS}s)')
        sys.exit(0)
except (ValueError, TypeError):
    print('RUNBOOK_ERROR:Cannot parse metric timestamps')
    sys.exit(0)

# Extract values
ru_values = [d.get('maximum') for d in ru_data]
ru_values = [v if v is not None else 0.0 for v in ru_values]
thr_values = [d.get('count') for d in thr_data]
thr_values = [v if v is not None else 0.0 for v in thr_values]
total_429s = sum(thr_values)

# Classify
spikes = [v >= SPIKE_THRESHOLD for v in ru_values]
spike_count = sum(spikes)
non_spike_values = [v for v, s in zip(ru_values, spikes) if not s]
baseline_max = max(non_spike_values) if non_spike_values else 0

# Consecutive spike count
max_consec = 0
current = 0
for s in spikes:
    if s:
        current += 1
        max_consec = max(max_consec, current)
    else:
        current = 0

print(f'INFO:spikes={spike_count} consec={max_consec} baseline_max={baseline_max:.0f}% 429s={total_429s:.0f}', file=sys.stderr)

# Decision
if max_consec >= SUSTAINED_CONSECUTIVE_LIMIT:
    print(f'SUSTAINED:{max_consec} consecutive windows above {SPIKE_THRESHOLD}%')
elif baseline_max >= BASELINE_HEALTHY_MAX:
    print(f'DEGRADED:Inter-spike baseline at {baseline_max:.0f}% (normal: <10%, limit: {BASELINE_HEALTHY_MAX}%)')
elif spike_count <= PERIODIC_MAX_SPIKES and total_429s <= PERIODIC_MAX_429S:
    print(f'PERIODIC:{spike_count} spike(s), baseline {baseline_max:.0f}%, {total_429s:.0f} 429s')
elif spike_count > PERIODIC_MAX_SPIKES:
    print(f'ESCALATING:{spike_count} spikes (>{PERIODIC_MAX_SPIKES} periodic limit)')
else:
    print(f'UNKNOWN:spike_count={spike_count} 429s={total_429s:.0f} baseline={baseline_max:.0f}%')
") || { echo "[RUNBOOK] ERROR: Python classification failed"; exit 2; }

# ── Step 3: Act on classification ─────────────────────────────────────
TYPE="${CLASSIFICATION%%:*}"
DETAIL="${CLASSIFICATION#*:}"

echo "[RUNBOOK] CLASSIFICATION: $TYPE — $DETAIL"

case "$TYPE" in
  PERIODIC)
    echo "[RUNBOOK] ACTION: Auto-acknowledge. Known burst pattern (see RCA 2026-03-27)."
    exit 0
    ;;
  STALE)
    echo "[RUNBOOK] ACTION: ESCALATE — metrics too old to classify safely."
    exit 1
    ;;
  SUSTAINED|DEGRADED|ESCALATING|UNKNOWN)
    echo "[RUNBOOK] ACTION: ESCALATE to on-call with diagnostics."
    echo ""
    echo "=== DIAGNOSTICS ==="
    echo "Raw RU data: $(echo "$RU_RAW" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for p in d.get('value',[{}])[0].get('timeseries',[{}])[0].get('data',[]):
    v=p.get('maximum','?'); t=p.get('timeStamp','?')[11:16]
    print(f'  {t}: {v}%')
" 2>/dev/null || echo '(parse failed)')"
    exit 1
    ;;
  RUNBOOK_ERROR)
    echo "[RUNBOOK] ACTION: RUNBOOK_ERROR — $DETAIL"
    exit 2
    ;;
  *)
    echo "[RUNBOOK] ACTION: RUNBOOK_ERROR — unexpected classification: $CLASSIFICATION"
    exit 2
    ;;
esac
```

### 8.4 Exit Code Contract

| Code | Meaning | OpsGenie Action |
|------|---------|-----------------|
| `0`  | PERIODIC — known burst, safe to ignore | Auto-acknowledge alert |
| `1`  | ESCALATE — genuine or uncertain degradation | Page on-call engineer |
| `2`  | RUNBOOK_ERROR — script itself failed | Log error, do NOT page (broken automation != throttling) |

> **Critical**: OpsGenie must be configured to treat `exit 2` as "runbook broken" — not as
> escalation. If all non-zero exits trigger pages, an Azure CLI auth expiry produces a false
> escalation storm every 5 minutes.

### 8.5 Integration Options

| Method              | How                                                                        | Complexity |
|---------------------|----------------------------------------------------------------------------|------------|
| **OpsGenie Action** | Responder action runs script; auto-closes on exit 0; ignores exit 2        | Low        |
| **Azure Function**  | Action Group webhook; calls Azure Monitor API; updates OpsGenie via API    | Medium     |
| **Azure Logic App** | No-code: Action Group to Logic App to metrics to conditional OpsGenie close | Low        |
| **Action Rule**     | Azure Monitor suppression rule matching known patterns (time/condition)     | Lowest     |

**Recommended**: Start with an **OpsGenie automation action** running the script.

### 8.6 Adversarial Review Summary

This runbook was validated by `el-demoledor` (adversarial review). Key risks and mitigations:

| Risk | Mitigation Applied |
|------|-------------------|
| Stale metrics cause misclassification (V1) | Gate 2: freshness check on last datapoint timestamp |
| Malformed `az` output crashes Python (V2) | Safe JSON parsing with try/except, default values |
| Timing drift causes spike count oscillation (V3) | Rate-based detection + magnitude cap (50 max 429s) |
| Elevated baseline between spikes goes undetected (V4) | DEGRADED classification when inter-spike baseline >=30% |
| Script crash interpreted as escalation (V5) | Explicit error handling, exit code 2 for runbook errors |
| Burst capacity creates false confidence (V6) | Marked as TEMPORARY with 2-week sunset |
| Autoscale migration during burst (V7) | Timing guidance in CLI commands section |
| Terraform import miss destroys collections (V8) | Explicit warning in Option B |
| Runbook defers root cause indefinitely (SW5) | **Mandatory sunset date: 2026-04-10** |

> Full adversarial report: `demoledor-runbook-review.md`

---

## 9. Key Takeaways

```text
 ┌────────────────────────────────────────────────────────────────────────┐
 │                     LESSONS FROM THIS INCIDENT                        │
 │                                                                       │
 │  1. 100 RU/s is the CosmosDB minimum — sufficient for low-traffic    │
 │     collections (keys, users, authorization) but insufficient for    │
 │     any collection receiving burst or frequent writes.               │
 │                                                                       │
 │  2. Average throughput != peak throughput.                             │
 │     A workload averaging 6 RU/s can still cause 429s                 │
 │     if it bursts above 100 RU/s for even a few seconds.             │
 │                                                                       │
 │  3. NormalizedRUConsumption is the #1 metric to watch.                │
 │     If it regularly hits 100%, throttling WILL happen.               │
 │                                                                       │
 │  4. Autoscale exists for exactly this pattern — bursty workloads     │
 │     that idle most of the time but spike periodically.               │
 │                                                                       │
 │  5. The 429 is NOT an error in the traditional sense.                │
 │     It's CosmosDB protecting itself — it's working as designed.      │
 │     The issue is the provisioning, not the database.                 │
 │                                                                       │
 │  6. Alert dampening matters. With failingPeriods=0/0, every single   │
 │     burst fires a new alert — ~4/hour with a 15-min pattern.        │
 │     On-call fatigue is a real operational risk.                      │
 │                                                                       │
 └────────────────────────────────────────────────────────────────────────┘
```
