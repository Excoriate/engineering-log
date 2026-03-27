---
task_id: 2026-03-27-001
agent: sre-maniac
status: complete
summary: |
  SRE verification of all RCA factual claims against the Rootly alert payload,
  plus comprehensive production-safe OpenShift troubleshooting commands for
  investigating the ~15-minute periodic CosmosDB 429 throttling pattern on
  the Gurobi RSM platform.
key_findings:
  - finding_1: All 12 verifiable claims in the RCA match the alert payload exactly
  - finding_2: One timeline nuance worth noting — evaluation window is 13:39-13:44, alert fired at 13:46
  - finding_3: RCA correctly identifies the periodic burst pattern as root cause
  - finding_4: Missing from RCA — no mention of autoMitigate behavior from payload, retry amplification risk, or partition-level hotspot diagnosis
  - finding_5: OpenShift commands provided cover 12 investigation areas with explanatory context
---

# SRE Maniac Review: Gurobi CosmosDB 429 Throttling RCA

## PART 1: Claim-by-Claim Verification

### Methodology

Every factual claim in the RCA was extracted and cross-referenced against the
`rootly-alert-payload.json` source data. Claims are classified as:

- **VERIFIED** — exact match with source data
- **INFERRED** — reasonable conclusion from data, but not directly stated in payload
- **UNVERIFIABLE** — cannot be confirmed from the alert payload alone (requires Azure portal)
- **INACCURATE** — contradicts source data

---

### Claim Verification Table

| # | RCA Claim | Source Field | Payload Value | Verdict |
|---|-----------|-------------|---------------|---------|
| 1 | Alert rule name: `gurobi-cosmos-throttling-429-a` | `essentials.alertRule` | `"gurobi-cosmos-throttling-429-a"` | **VERIFIED** |
| 2 | Severity: Sev2 | `essentials.severity` | `"Sev2"` | **VERIFIED** |
| 3 | Resource: `cosmosdb-gurobi-platform-a` | `essentials.configurationItems[0]` | `"cosmosdb-gurobi-platform-a"` | **VERIFIED** |
| 4 | Resource Group: `rg-gurobi-platform-a` | `essentials.targetResourceGroup` | `"rg-gurobi-platform-a"` | **VERIFIED** |
| 5 | Resource type: MongoDB API (CosmosDB) | `essentials.targetResourceType` | `"microsoft.documentdb/databaseaccounts"` | **VERIFIED** — `microsoft.documentdb` is the CosmosDB provider. The "MongoDB API" flavor is INFERRED (not in payload, but consistent with `grb_rsm` database name and collection names like `fs.files`/`fs.chunks` which are GridFS patterns exclusive to MongoDB API) |
| 6 | Fired at: `2026-03-27T13:46:47 UTC` | `essentials.firedDateTime` | `"2026-03-27T13:46:47.5480095Z"` | **VERIFIED** — exact match (RCA truncated sub-seconds, which is fine) |
| 7 | Alert description: "Trigger on Request status code of 429" | `essentials.description` | `"Trigger on Request status code of 429"` | **VERIFIED** — verbatim match |
| 8 | Metric: `TotalRequests` filtered by StatusCode=429 | `alertContext.condition.allOf[0]` | `metricName: "TotalRequests"`, `dimensions[0].name: "StatusCode"`, `dimensions[0].value: "429"` | **VERIFIED** |
| 9 | Threshold: >= 20 | `alertContext.condition.allOf[0].threshold` | `"20"` with `operator: "GreaterThanOrEqual"` | **VERIFIED** |
| 10 | Aggregation: Count | `alertContext.condition.allOf[0].timeAggregation` | `"Count"` | **VERIFIED** |
| 11 | Window: 5 minutes | `alertContext.condition.windowSize` | `"PT5M"` (ISO 8601 = 5 minutes) | **VERIFIED** |
| 12 | Metric value at trigger: 24 | `alertContext.condition.allOf[0].metricValue` | `24` | **VERIFIED** |
| 13 | Evaluation window: 13:39-13:44 UTC | `alertContext.condition.windowStartTime` / `windowEndTime` | `"2026-03-27T13:39:32.994Z"` / `"2026-03-27T13:44:32.994Z"` | **VERIFIED** — RCA states "13:39 → 13:44 UTC" in the timeline diagram, matching the payload |
| 14 | Subscription: "Eneco MCC - Acceptance - Workload VPP" | Not in payload | Payload has subscription ID `b524d084-edf5-449d-8e92-999ebbaf485e` only | **UNVERIFIABLE** — subscription name not in payload; the ID is present but name requires Azure lookup |
| 15 | Action Group: `ag-trade-platform-a` in `rg-pltfrm-infra-a` | Not in payload | Payload routes to escalation policy `1b6ee744-4aca-45ed-9d00-2d1d2b5edbfa` via Rootly | **UNVERIFIABLE** — Action group name is not in the Rootly payload; it would be in the Azure alert rule config |
| 16 | `autoMitigate: true` | Not in payload | Not present in this payload schema | **UNVERIFIABLE** — This is an Azure Monitor alert rule property, not part of the Common Alert Schema payload. INFERRED as reasonable since it is the default for metric alerts |
| 17 | Repeating ~15 min pattern with specific 429 counts per interval | Not in payload | Payload only contains trigger-time data point (24) | **UNVERIFIABLE from payload alone** — The time-series data in the RCA (the table at lines 27-41) would come from Azure Monitor Metrics Explorer, not from the alert payload. The payload only confirms the trigger-time value of 24. The broader pattern is a reasonable investigation finding |
| 18 | All collections at 100 RU/s, autoscale OFF | Not in payload | Not present | **UNVERIFIABLE from payload** — Would require Azure portal or `az cosmosdb` CLI queries. Reasonable finding from investigation |
| 19 | `metrics` collection is the primary suspect (2,814 req/hr) | Not in payload | Not present | **UNVERIFIABLE from payload** — Would require Azure Monitor metrics breakdown by collection. Reasonable inference |
| 20 | Condition met: "24 >= 20" | Derived from claims 9+12 | `threshold: "20"`, `metricValue: 24`, `operator: "GreaterThanOrEqual"` | **VERIFIED** — 24 >= 20 is true, correctly stated |

---

### Verification Summary

```
CLAIM VERIFICATION RESULTS
==========================
VERIFIED:          13/20  (all claims checkable against payload are correct)
INFERRED:           0/20  (one sub-claim under #5 is inferred but well-supported)
UNVERIFIABLE:       7/20  (require Azure portal access, not available in payload)
INACCURATE:         0/20  (zero errors found)

VERDICT: RCA is factually accurate for all verifiable claims.
         No contradictions with source data.
```

---

### Nuances and SRE Observations

#### 1. Timeline Precision (Observation, Not Error)

The RCA timeline diagram (Section 5) shows the alert fired at 13:46 based on a
5-minute window of 13:39-13:44. This is consistent with the payload:

```
windowStartTime: 2026-03-27T13:39:32.994Z
windowEndTime:   2026-03-27T13:44:32.994Z
firedDateTime:   2026-03-27T13:46:47.548Z
```

The ~2 minute gap between window end (13:44) and fire time (13:46) is the Azure
Monitor evaluation pipeline latency — this is normal and expected. The RCA
correctly captures this.

#### 2. staticThresholdFailingPeriods (Not Discussed in RCA)

The payload shows:

```json
"staticThresholdFailingPeriods": {
  "minFailingPeriodsToAlert": 0,
  "numberOfEvaluationPeriods": 0
}
```

Both values are 0, meaning the alert fires on the FIRST evaluation period that
exceeds the threshold — there is no "must fail N out of M times" buffer. This
makes the alert highly sensitive. The RCA does not mention this, but it is
relevant context: the alert will fire on every single burst that hits >=20 429s,
with no dampening.

**SRE Concern**: With `minFailingPeriodsToAlert: 0`, every 15-minute burst
cycle that produces >=20 429s will fire an alert. If `autoMitigate` is indeed
true (as the RCA states), the alert will auto-resolve, then re-fire, creating
alert fatigue. Consider setting `minFailingPeriodsToAlert: 2` of
`numberOfEvaluationPeriods: 3` to distinguish sustained throttling from
transient bursts — but only AFTER confirming the business impact of individual
bursts is acceptable.

#### 3. Missing Cascade Analysis (SRE Gap in RCA)

The RCA describes WHAT happens (429s) but does not trace the CASCADE:

```
CASCADE ANALYSIS (not in RCA — should be):
Initial Failure: CosmosDB returns 429 to Gurobi RSM
├─ First Order: Application receives 429 — does it retry? With backoff?
│   If retry without backoff → amplification: N retries × M concurrent pods
│   If no retry → data loss / incomplete batch
├─ Second Order: If batch fails, what downstream processes depend on it?
│   Metrics collection is HOT → are dashboards/reports stale?
│   Registry/settings writes fail → does RSM lose configuration?
├─ Third Order: If GridFS writes fail (fs.files, fs.chunks) →
│   Are optimization model files partially written? Data corruption?
└─ Blast Radius: Unknown without application-side investigation
```

This is the most important gap in the RCA. The payload tells us 429s happened.
The application-side behavior during 429s determines actual user impact.

#### 4. Retry Amplification Risk (Not Calculated in RCA)

The RCA mentions "retry logic" as something to check but does not model the
amplification. For a Gurobi RSM platform:

```
RETRY AMPLIFICATION SCENARIO:
├─ Assume: 3 retries per 429 (common MongoDB driver default)
├─ Assume: 2 pods (conservative)
├─ Base 429s per burst: 24 (from payload)
├─ With retries: 24 × 3 = 72 additional requests
├─ With 2 pods: potentially 72 × 2 = 144 retry requests
├─ Each retry hits an already-saturated partition → more 429s
└─ RESULT: Self-amplifying failure loop until burst subsides

If the MongoDB driver uses default retryWrites=true without
rate limiting, the burst of 24 429s could generate 100+ additional
requests, all hitting the same saturated partition.
```

#### 5. Partition Hot-Spotting (Deeper Root Cause)

The RCA correctly explains NormalizedRUConsumption but could go deeper:

```
100% NormalizedRUConsumption means at least ONE physical partition is saturated.

CosmosDB distributes 100 RU/s across physical partitions.
If there is 1 partition: it gets all 100 RU/s.
If there are 2 partitions: each gets 50 RU/s.

The `metrics` collection at 2,814 req/hr with 100 RU/s suggests:
- If partitioned poorly (e.g., all writes to same partition key),
  the effective budget could be as low as 25-50 RU/s per partition
- The burst pattern could be hitting a single partition harder
```

This can be verified in Azure with the "Partition Key Range ID" dimension on
the TotalRequests metric.

---

## PART 2: OpenShift Investigation Commands

### Prerequisites

```bash
# ============================================================================
# PREREQUISITES
# ============================================================================
# 1. Connect to the AVD (Azure Virtual Desktop)
# 2. Open a terminal
# 3. Verify oc CLI is available and you are logged in:

oc whoami                    # Should show your username
oc whoami --show-server      # Should show the cluster API URL
oc whoami --show-context     # Shows current context (verify it is ACC cluster)

# If not logged in:
# oc login <cluster-url> --token=<your-token>
# Or use the web console to copy the login command
```

---

### Section 1: Discover the Gurobi Namespace(s)

```bash
# ============================================================================
# 1. NAMESPACE DISCOVERY
# ============================================================================
# WHY: We need to find where Gurobi RSM is deployed. Namespace naming varies
#      by organization. Common patterns: gurobi, grb, rsm, gurobi-rsm, etc.
# WHAT: Lists all namespaces matching common Gurobi patterns.
# SAFETY: Read-only (oc get)
# ============================================================================

# Broad search — try multiple patterns
oc get namespaces | grep -iE 'gurobi|grb|rsm|solver|optim'

# If nothing found, list ALL namespaces and eyeball it
# (sometimes teams use project codes or abbreviations)
oc get namespaces --no-headers | awk '{print $1}' | sort

# Once you identify the namespace, set it as a variable for all subsequent commands:
# IMPORTANT: Replace <namespace> with the actual value found above
export GRB_NS="<namespace>"
echo "Using namespace: $GRB_NS"
```

---

### Section 2: Pod Health Assessment

```bash
# ============================================================================
# 2. POD HEALTH — STATUS, RESTARTS, AGE
# ============================================================================
# WHY: 429 errors may cause application retries that lead to pod restarts,
#      OOMKills (if retry buffers grow unbounded), or CrashLoopBackOff.
#      We need to know if the app is HEALTHY despite 429s or DEGRADED because
#      of them.
# WHAT: Shows all pods with status, restart counts, node placement, and age.
# SAFETY: Read-only
# ============================================================================

# Overview of all pods — status, restarts, age, node
oc get pods -n "$GRB_NS" -o wide

# Sort by restart count — high restarts = potential 429 retry storm or OOM
oc get pods -n "$GRB_NS" --sort-by='.status.containerStatuses[0].restartCount' \
  -o custom-columns=\
'NAME:.metadata.name,STATUS:.status.phase,RESTARTS:.status.containerStatuses[0].restartCount,LAST_STATE:.status.containerStatuses[0].lastState.terminated.reason,AGE:.metadata.creationTimestamp'

# Check for OOMKilled pods — if the app buffers retries in memory,
# 429 storms can cause OOM
oc get pods -n "$GRB_NS" -o json | \
  jq -r '.items[] | select(.status.containerStatuses[]?.lastState.terminated.reason == "OOMKilled") | .metadata.name'

# Pod resource requests vs limits — are pods under-provisioned?
oc get pods -n "$GRB_NS" -o custom-columns=\
'NAME:.metadata.name,CPU_REQ:.spec.containers[0].resources.requests.cpu,CPU_LIM:.spec.containers[0].resources.limits.cpu,MEM_REQ:.spec.containers[0].resources.requests.memory,MEM_LIM:.spec.containers[0].resources.limits.memory'
```

---

### Section 3: CronJobs and Periodic Schedulers

```bash
# ============================================================================
# 3. CRONJOBS / SCHEDULED TASKS — THE ~15 MIN BURST SOURCE
# ============================================================================
# WHY: The RCA shows a CLEAR ~15-minute periodic burst pattern. This strongly
#      suggests a CronJob, a Kubernetes Job triggered by a timer, or an
#      in-app scheduler (e.g., Quartz, node-cron, APScheduler).
#      Finding the scheduler is THE critical investigation step.
# WHAT: Lists all CronJobs, Jobs, and recent Job executions.
# SAFETY: Read-only
# ============================================================================

# Check for CronJobs in the namespace
oc get cronjobs -n "$GRB_NS" -o wide

# If CronJobs exist, check their schedule (look for */15 or similar)
oc get cronjobs -n "$GRB_NS" -o custom-columns=\
'NAME:.metadata.name,SCHEDULE:.spec.schedule,SUSPEND:.spec.suspend,ACTIVE:.status.active,LAST_SCHEDULE:.status.lastScheduleTime'

# Check recently completed/running Jobs (CronJobs spawn Jobs)
oc get jobs -n "$GRB_NS" --sort-by='.metadata.creationTimestamp' \
  -o custom-columns=\
'NAME:.metadata.name,STATUS:.status.conditions[0].type,START:.status.startTime,COMPLETIONS:.status.succeeded,FAILED:.status.failed'

# If NO CronJobs found, the scheduler is likely IN-APP.
# Check for Deployments/DeploymentConfigs that might contain scheduler components:
oc get deployments -n "$GRB_NS" -o custom-columns='NAME:.metadata.name,REPLICAS:.spec.replicas,IMAGE:.spec.template.spec.containers[0].image'
oc get deploymentconfigs -n "$GRB_NS" -o custom-columns='NAME:.metadata.name,REPLICAS:.spec.replicas,IMAGE:.spec.template.spec.containers[0].image' 2>/dev/null

# Check if any pod has "scheduler", "cron", "batch", "worker" in its name
oc get pods -n "$GRB_NS" --no-headers | grep -iE 'sched|cron|batch|work|job|timer'
```

---

### Section 4: Application Logs — 429 Evidence

```bash
# ============================================================================
# 4. APPLICATION LOGS — 429 ERRORS, RETRIES, COSMOSDB BEHAVIOR
# ============================================================================
# WHY: The MOST important evidence. We need to see:
#      a) Does the app LOG 429 errors? (observability check)
#      b) Does the app RETRY on 429? With backoff? Without?
#      c) What operation triggers the 429? (write? query? aggregation?)
#      d) Does the app handle 429 gracefully or crash?
# WHAT: Searches pod logs for throttling-related patterns.
# SAFETY: Read-only (oc logs)
# NOTE: Replace <pod-name> with actual pod names from Section 2.
#        Run for EACH pod that might talk to CosmosDB.
# ============================================================================

# List pods first (copy names from output)
oc get pods -n "$GRB_NS" --no-headers -o custom-columns='NAME:.metadata.name'

# --- For each relevant pod, run these searches: ---
# Replace POD_NAME below with actual pod name(s)

# 4a. Find 429 / throttling errors in logs (last 2 hours)
oc logs -n "$GRB_NS" <POD_NAME> --since=2h | \
  grep -iE '429|throttl|rate.limit|too.many.request|TooManyRequests|RequestRateTooLarge' | \
  tail -50

# 4b. Find retry behavior — does the app retry? How?
oc logs -n "$GRB_NS" <POD_NAME> --since=2h | \
  grep -iE 'retry|retrying|backoff|back.off|attempt|reconnect' | \
  tail -50

# 4c. Find CosmosDB / MongoDB connection activity
oc logs -n "$GRB_NS" <POD_NAME> --since=2h | \
  grep -iE 'cosmos|mongodb|mongo|documentdb|connection.*string|x-ms-retry' | \
  tail -50

# 4d. Find error patterns (stack traces, exceptions)
oc logs -n "$GRB_NS" <POD_NAME> --since=2h | \
  grep -iE 'error|exception|fatal|panic|traceback|ECONNREFUSED|ETIMEDOUT' | \
  tail -50

# 4e. Timestamp analysis — isolate logs around burst times (13:26, 13:41, 13:56, 14:11)
#     This correlates app behavior with the CosmosDB metric spikes
oc logs -n "$GRB_NS" <POD_NAME> --since=2h --timestamps | \
  grep -E '13:2[5-7]|13:4[0-2]|13:5[5-7]|14:1[0-2]' | \
  tail -100

# 4f. If the app uses structured logging (JSON), find all error-level entries
oc logs -n "$GRB_NS" <POD_NAME> --since=2h | \
  grep -iE '"level"\s*:\s*"(error|warn|fatal)"' | \
  tail -50

# --- MULTI-CONTAINER PODS ---
# If pods have sidecar containers (istio-proxy, etc.), specify the container:
# oc logs -n "$GRB_NS" <POD_NAME> -c <CONTAINER_NAME> --since=2h | grep -i 429

# List containers in a pod:
oc get pod -n "$GRB_NS" <POD_NAME> -o jsonpath='{.spec.containers[*].name}'
```

---

### Section 5: Resource Consumption (CPU / Memory)

```bash
# ============================================================================
# 5. RESOURCE CONSUMPTION — CPU AND MEMORY
# ============================================================================
# WHY: If pods are under memory pressure, retry buffers during 429 storms
#      could push them toward OOM. If CPU is saturated, the app may not
#      process CosmosDB retry-after headers fast enough, causing pileups.
# WHAT: Shows current CPU/memory usage vs requests/limits.
# SAFETY: Read-only
# NOTE: Requires metrics-server to be running in the cluster.
# ============================================================================

# Current resource usage (requires metrics-server)
oc adm top pods -n "$GRB_NS"

# Node-level resources (to see if the node itself is under pressure)
oc adm top nodes

# Compare usage vs limits — high ratio = risk during 429 retry storms
oc adm top pods -n "$GRB_NS" --containers

# Check if resource quotas exist for the namespace (could limit scaling)
oc get resourcequotas -n "$GRB_NS"

# Check LimitRanges (default limits applied if not specified in pod spec)
oc get limitranges -n "$GRB_NS" -o yaml
```

---

### Section 6: HPA / Autoscaler Configuration

```bash
# ============================================================================
# 6. HORIZONTAL POD AUTOSCALER (HPA)
# ============================================================================
# WHY: If HPA is configured, more pods during load = MORE concurrent requests
#      to CosmosDB = FASTER RU exhaustion. This is a COUNTER-INTUITIVE failure:
#      autoscaling the app can WORSEN CosmosDB throttling by multiplying
#      the request rate against a FIXED 100 RU/s budget.
# WHAT: Shows HPA configuration, current/target replicas, and scaling metrics.
# SAFETY: Read-only
# ============================================================================

# Check for HPA
oc get hpa -n "$GRB_NS"

# Detailed HPA config (target metrics, min/max replicas)
oc get hpa -n "$GRB_NS" -o yaml

# If using OpenShift-specific autoscaling:
oc get machineautoscaler -A 2>/dev/null
oc get clusterautoscaler 2>/dev/null
```

---

### Section 7: Deployment Configuration and Environment Variables

```bash
# ============================================================================
# 7. DEPLOYMENT CONFIG — ENVIRONMENT VARIABLES AND COSMOSDB CONNECTION
# ============================================================================
# WHY: Environment variables reveal:
#      a) CosmosDB connection string (confirms which DB the app targets)
#      b) Retry configuration (some apps expose retry count/backoff as env vars)
#      c) Scheduler intervals (the ~15 min pattern might be configurable)
#      d) Batch size settings (larger batches = more RUs per burst)
# WHAT: Extracts env vars from deployments (redacting sensitive values).
# SAFETY: Read-only. Connection strings may contain credentials — DO NOT
#         paste them in public channels.
# ============================================================================

# List all deployments
oc get deployments -n "$GRB_NS" -o wide
oc get deploymentconfigs -n "$GRB_NS" -o wide 2>/dev/null

# For each deployment, check environment variables
# (look for COSMOS, MONGO, CONNECTION, SCHEDULE, CRON, BATCH, RETRY patterns)
oc set env deployment/<DEPLOYMENT_NAME> -n "$GRB_NS" --list

# If using DeploymentConfig instead:
# oc set env dc/<DC_NAME> -n "$GRB_NS" --list

# Search ALL deployments for CosmosDB-related env vars
for deploy in $(oc get deployments -n "$GRB_NS" --no-headers -o custom-columns='NAME:.metadata.name'); do
  echo "=== $deploy ==="
  oc set env deployment/"$deploy" -n "$GRB_NS" --list 2>/dev/null | \
    grep -iE 'cosmos|mongo|connection|database|db_|retry|batch|schedule|cron|interval|period'
done

# Check ConfigMaps for application configuration
oc get configmaps -n "$GRB_NS"

# Look at ConfigMaps that might contain scheduler or DB config
for cm in $(oc get configmaps -n "$GRB_NS" --no-headers -o custom-columns='NAME:.metadata.name'); do
  echo "=== ConfigMap: $cm ==="
  oc get configmap "$cm" -n "$GRB_NS" -o yaml | \
    grep -iE 'cosmos|mongo|schedule|cron|interval|retry|batch|period|timer' || echo "(no matches)"
done

# Check Secrets that reference CosmosDB (names only — DO NOT dump values)
oc get secrets -n "$GRB_NS" -o custom-columns='NAME:.metadata.name,TYPE:.type' | \
  grep -ivE 'service-account|dockercfg|token'
```

---

### Section 8: Recent Events and Warnings

```bash
# ============================================================================
# 8. CLUSTER EVENTS — WARNINGS, FAILURES, SCHEDULING ISSUES
# ============================================================================
# WHY: Events reveal:
#      a) Pod restarts caused by 429-induced crashes
#      b) OOMKilled events from retry buffer growth
#      c) Failed scheduling (resource pressure on nodes)
#      d) Image pull failures (deployment issues)
#      e) Liveness/readiness probe failures (429 storm makes app unresponsive)
# WHAT: Shows recent events sorted by time, filtered for warnings.
# SAFETY: Read-only
# ============================================================================

# All events, most recent last
oc get events -n "$GRB_NS" --sort-by='.lastTimestamp'

# WARNING events only (most actionable)
oc get events -n "$GRB_NS" --field-selector type=Warning --sort-by='.lastTimestamp'

# Events in the last 1 hour
oc get events -n "$GRB_NS" --sort-by='.lastTimestamp' | \
  grep -E "$(date -u -d '1 hour ago' '+%Y-%m-%dT%H' 2>/dev/null || date -u -v-1H '+%Y-%m-%dT%H')"

# Pod-specific events (for a suspicious pod)
oc describe pod <POD_NAME> -n "$GRB_NS" | sed -n '/^Events:/,$ p'
```

---

### Section 9: Network Policies and Service Mesh

```bash
# ============================================================================
# 9. NETWORK POLICIES AND EGRESS — CAN PODS REACH COSMOSDB?
# ============================================================================
# WHY: If network policies restrict egress, some pods may fail to reach
#      CosmosDB entirely (connection refused != 429). If a service mesh
#      (Istio/Envoy) is present, it may add retries ON TOP of application
#      retries — compounding the thundering herd effect.
# WHAT: Checks network policies, egress rules, and service mesh config.
# SAFETY: Read-only
# ============================================================================

# Network policies in the namespace
oc get networkpolicies -n "$GRB_NS"

# Check if Istio/Service Mesh is injected (sidecar present)
oc get pods -n "$GRB_NS" -o jsonpath='{range .items[*]}{.metadata.name}{" containers: "}{.spec.containers[*].name}{"\n"}{end}' | \
  grep -i 'istio\|envoy\|sidecar'

# If service mesh is present, check retry policies (THIS IS CRITICAL):
# Mesh-level retries MULTIPLY with app-level retries.
# 3 mesh retries × 3 app retries = 9× amplification per request
oc get destinationrules -n "$GRB_NS" 2>/dev/null
oc get virtualservices -n "$GRB_NS" 2>/dev/null
oc get servicemeshpolicies -n "$GRB_NS" 2>/dev/null
```

---

### Section 10: Persistent Volume Claims and Storage

```bash
# ============================================================================
# 10. STORAGE — PVCS AND GRIDFS CONTEXT
# ============================================================================
# WHY: The CosmosDB has GridFS collections (fs.files, fs.chunks), which store
#      large binary data. If optimization model files are stored in GridFS,
#      each file upload = multiple chunk writes = HIGH RU cost.
#      Additionally, if the app uses local PVCs for temp storage and they
#      fill up, it may increase CosmosDB writes as a fallback.
# WHAT: Lists PVCs and their usage.
# SAFETY: Read-only
# ============================================================================

# Check PVCs
oc get pvc -n "$GRB_NS"

# Check PVC details (bound status, capacity)
oc get pvc -n "$GRB_NS" -o custom-columns=\
'NAME:.metadata.name,STATUS:.status.phase,CAPACITY:.status.capacity.storage,STORAGECLASS:.spec.storageClassName'
```

---

### Section 11: Service and Route Configuration

```bash
# ============================================================================
# 11. SERVICES AND ROUTES — EXTERNAL ACCESS PATTERNS
# ============================================================================
# WHY: If the Gurobi RSM API is exposed via a Route, external clients
#      may be triggering the batch operations. Understanding the access
#      pattern helps determine if the 15-min burst is internal (CronJob)
#      or external (API caller on a schedule).
# WHAT: Lists Services and Routes.
# SAFETY: Read-only
# ============================================================================

# Services
oc get services -n "$GRB_NS"

# Routes (external access)
oc get routes -n "$GRB_NS" -o custom-columns=\
'NAME:.metadata.name,HOST:.spec.host,SERVICE:.spec.to.name,TLS:.spec.tls.termination'
```

---

### Section 12: Quick One-Liner Diagnostic Summary

```bash
# ============================================================================
# 12. DIAGNOSTIC SUMMARY — RUN THIS FIRST FOR A QUICK PICTURE
# ============================================================================
# This single block gives you a fast overview before deep-diving.
# Set GRB_NS first!
# ============================================================================

echo "====== NAMESPACE: $GRB_NS ======"
echo ""
echo "--- PODS ---"
oc get pods -n "$GRB_NS" -o wide
echo ""
echo "--- CRONJOBS ---"
oc get cronjobs -n "$GRB_NS" 2>/dev/null || echo "No CronJobs found"
echo ""
echo "--- JOBS (last 10) ---"
oc get jobs -n "$GRB_NS" --sort-by='.metadata.creationTimestamp' 2>/dev/null | tail -10 || echo "No Jobs found"
echo ""
echo "--- HPA ---"
oc get hpa -n "$GRB_NS" 2>/dev/null || echo "No HPA found"
echo ""
echo "--- DEPLOYMENTS ---"
oc get deployments -n "$GRB_NS" -o wide
echo ""
echo "--- RESOURCE USAGE ---"
oc adm top pods -n "$GRB_NS" 2>/dev/null || echo "Metrics not available"
echo ""
echo "--- RECENT WARNINGS ---"
oc get events -n "$GRB_NS" --field-selector type=Warning --sort-by='.lastTimestamp' 2>/dev/null | tail -10
echo ""
echo "--- CONFIGMAPS ---"
oc get configmaps -n "$GRB_NS"
echo ""
echo "====== END SUMMARY ======"
```

---

## PART 3: SRE Maniac Addendum — What the RCA Should Add

### Missing Failure Modes Not Addressed in RCA

| Gap | Risk | Investigation Needed |
|-----|------|---------------------|
| **Retry amplification** | App retries on 429 without backoff → self-amplifying storm | Check MongoDB driver config (`retryWrites`, `retryReads`, max retries) |
| **Partition hot-spotting** | If `metrics` collection has poor partition key, effective RU budget per partition could be 25-50 RU/s, not 100 | Check partition key via Azure portal or `az cosmosdb mongodb collection show` |
| **GridFS write cost** | Uploading a 1MB file via GridFS = ~16 chunk writes × ~5 RU each = ~80 RU — nearly the entire 100 RU/s budget in one operation | Check if batch job uploads model files to GridFS |
| **Connection pool exhaustion** | During 429 storm, connections waiting for retry-after may pile up, exhausting the pool | Check MongoDB driver connection pool settings (`maxPoolSize`) in app config |
| **Alert fatigue** | With `minFailingPeriodsToAlert: 0`, every 15-min burst fires an alert → 4 alerts/hour → on-call fatigue | Consider adjusting failing periods or increasing threshold |
| **Data consistency** | If batch job partially completes before 429s stop it, is the data consistent? Does it use transactions? | Check application retry/idempotency logic |

### Recommended RCA Additions

1. **Add Section 3.4: Retry Amplification Risk** — Calculate worst-case retry multiplication based on MongoDB driver configuration found in OpenShift investigation.

2. **Add Section 3.5: Partition Analysis** — Determine if the `metrics` collection has a hot partition that reduces effective RU/s below the nominal 100.

3. **Expand Section 6** — Once OpenShift investigation is complete, document:
   - The exact CronJob/scheduler causing the burst
   - The batch job's operation type (writes? queries? aggregations?)
   - The retry configuration
   - Pod replica count during bursts

4. **Add Section 9: Alert Tuning** — The `minFailingPeriodsToAlert: 0` means every burst fires. Recommend tuning to reduce noise while preserving detection of sustained throttling.
