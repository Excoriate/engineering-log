---
title: "oc Sanity-Check Playbook — eneco-vpp-prd — 2026-05-11"
description: "Mandatory pre-close sanity check for the vpp-resource-unhealthy CMC alert. Rules OUT cluster-side impact during the Microsoft 5Z1B-6KG window. Read-only."
version: 1.0
status: review
category: on-call-playbook
incident_date: 2026-05-11
related_rca: ./rca.md
target_cluster: Eneco MCC Production OpenShift
target_namespace: eneco-vpp-prd
purpose: rule-out, not diagnose
---

# oc Sanity-Check Playbook — `eneco-vpp-prd` (Plane 3 of [`rca.md`](./rca.md))

> **Goal**: prove (or disprove) that NO Eneco VPP workload was actually unhealthy in `eneco-vpp-prd` during the alert's evaluation window (13:00–13:20 UTC, 2026-05-11). This is a **falsifier for the RCA's "no workload affected" claim** — not a diagnosis tool. If any probe returns positive evidence of cluster degradation, **STOP closing the alert** and open a real workload incident.

## Prerequisites

1. You can `oc` into the Eneco MCC Production OpenShift cluster (the one whose API serves `eneco-vpp-prd`). If unsure: `oc whoami` and `oc config current-context`.
2. You have at least `view` permission on `eneco-vpp-prd`.
3. The probes below are **read-only**. They will not change cluster state. If any command asks to mutate, STOP — you have the wrong playbook.

```bash
# Confirm context (do this first, every time)
oc whoami
oc config current-context
oc get ns eneco-vpp-prd -o yaml | grep -E '^(metadata.name|status.phase)' | head -5
# Expected: namespace exists, status.phase=Active
```

## Decision matrix

After running the three probes below:

| Outcome | Action |
|---|---|
| All three probes return clean (Expected output column) | Cluster was not impacted. Proceed to [§ Close commands in rca.md](./rca.md#close-commands-az-this-page). |
| Any probe returns positive evidence of degradation in `eneco-vpp-prd` during 13:00–13:20 UTC | **STOP**. The "no workload affected" claim in the RCA collapses. Do NOT close the ServiceNow/Azure alert. Open a real workload incident; this RCA's framing must be revisited. Page #myriad-major-incidents if material. |
| Any probe errors out (auth, transport, namespace missing) | Resolve the prerequisite issue. Do NOT close the alert until probes succeed. |

## Evidence labels in this section

- **A1 FACT** = command output captured by you in this session.
- **A2 INFER** = derived from A1 via the decision rule below it.

## Probe 1 — Are any pods NOT Running in `eneco-vpp-prd` right now?

**Question**: is anything in the namespace in a non-Running state (Pending, CrashLoopBackOff, Error, ImagePullBackOff, Unknown, Failed)?

**Why this command/API**: the OpenShift API is the authority for current pod state; the workspace metrics (which Azure caches) may be stale (per Microsoft's own warning about "incorrect alert activation" during the latency window — metrics from this window should be re-derived from the cluster, not from Azure Monitor).

**Fields selected**: `metadata.name`, `status.phase`, `status.containerStatuses[].state` — only what is needed to decide.

**Command**:

```bash
oc -n eneco-vpp-prd get pods --field-selector=status.phase!=Running -o wide
```

**Expected output (clean)**:

```text
No resources found in eneco-vpp-prd namespace.
```

**Expected output (degraded — STOP closing)**: any row appears. Examples that mean STOP:

```text
NAME                              READY   STATUS                 RESTARTS   AGE     IP
gurobi-compute-xyz                0/1     CrashLoopBackOff       7          15m     10.x.x.x
inbox-ingestion-abc               0/1     ImagePullBackOff       0          5m      10.x.x.x
assetplanning-def                 0/1     Pending                0          12m     <none>
```

**Decision rule**:
- Empty output → A1 clean. Cluster is fine right now. Note: this is a NOW snapshot, not 13:12 UTC; pair with Probe 3.
- Any non-Running pod in `eneco-vpp-prd` → A2 cluster degradation; STOP closing.

**Principle (transferable)**: the cloud-side alert's truth surface is the workspace; the workload's truth surface is the cluster API. When the workspace was demonstrably stale (as today, per Microsoft `5Z1B-6KG`), the workload truth surface is the authority — ALWAYS probe the cluster directly, do not trust the alert's narrative alone.

## Probe 2 — Any unusual events in the last 30 minutes?

**Question**: did the cluster log any abnormal scheduling, image-pull, OOM, or eviction events in or near the alert's evaluation window?

**Why this command/API**: events are the cluster's own audit trail of pod/scheduler/controller actions. They predate metrics and are not subject to Log Analytics ingestion delay.

**Fields selected**: `lastTimestamp`, `type`, `reason`, `involvedObject.name`, `message`.

**Command**:

```bash
oc -n eneco-vpp-prd get events --sort-by='.lastTimestamp' \
  --field-selector=type!=Normal -o custom-columns='LAST:.lastTimestamp,TYPE:.type,REASON:.reason,OBJECT:.involvedObject.name,MSG:.message' | tail -30
```

**Expected output (clean)**: empty or only events with `type=Normal` (this filter already excludes those, so a clean output is empty).

**Expected output (degraded — STOP closing)**: any of the following reasons in the last 30 minutes:

- `BackOff` / `CrashLoopBackOff`
- `FailedScheduling`
- `FailedMount`
- `ImagePullBackOff` / `ErrImagePull`
- `OOMKilling` / `Evicted`
- `Unhealthy` (from a liveness probe)
- `NodeNotReady` (any node affecting this namespace)

**Decision rule**:
- No Warning/Error events in last 30m → A1 clean.
- Any matching reason within 13:00–13:20 UTC ± reasonable padding → A2 cluster degradation; STOP closing.
- Warning/Error events OUTSIDE 13:00–13:20 UTC → record but does not block closing the *Azure* alert; may warrant a separate ticket.

**Principle**: events show *transitions* (state changes), not state. A probe that returns only current state can miss a pod that crashed-and-recovered in the window. Events catch the transient cases.

## Probe 3 — Did any pod's restart count climb during 13:00–13:20 UTC?

**Question**: even if everything is Running now, did any container restart during the alert's window?

**Why this command/API**: `restartCount` is monotonic per container per pod lifetime. A pod that crashed-and-recovered would show a non-zero restartCount with `lastState.terminated.finishedAt` in the window of interest.

**Fields selected**: pod name, container name, restartCount, `lastState.terminated.{reason, finishedAt}`.

**Command** (most readable form):

```bash
oc -n eneco-vpp-prd get pods -o json | jq -r '
  .items[]
  | .metadata.name as $pod
  | .status.containerStatuses[]?
  | select(.restartCount > 0)
  | {
      pod: $pod,
      container: .name,
      restarts: .restartCount,
      lastTerminationReason: (.lastState.terminated.reason // "n/a"),
      lastTerminationAt: (.lastState.terminated.finishedAt // "n/a"),
      lastTerminationExit: (.lastState.terminated.exitCode // "n/a")
    }
' | jq -s 'sort_by(.restarts) | reverse | .[0:15]'
```

**Expected output (clean)**:

```text
[]
```

or a list with `lastTerminationAt` timestamps that are **all OUTSIDE 13:00–13:20 UTC on 2026-05-11** (pre-existing chronic crash loops are noted but do not block closing today's Azure alert).

**Expected output (degraded — STOP closing)**: any entry with `lastTerminationAt` between `2026-05-11T13:00:00Z` and `2026-05-11T13:20:00Z`. Especially if `lastTerminationReason` is `OOMKilled`, `Error`, or `ContainerCannotRun`.

**Decision rule**:
- All terminations outside the window → A1 clean for this incident; A2 "cluster fine for THIS alert; chronic crash loops may exist but are unrelated".
- Any termination inside the window → A2 cluster impact within the alert's eval window; STOP closing.

**Principle**: state-now vs state-during-event. The window-bounded falsifier is the one that matters when the alert is bounded to a window.

## (Optional) Probe 4 — Cluster-wide ResourceHealth events for namespace resources

**Question**: did any Azure resource backing `eneco-vpp-prd` (Azure SQL DB, Cosmos DB, Storage, Key Vault, Event Hub, Service Bus) have a per-resource ResourceHealth Activated event during 13:00–13:20 UTC?

**Why this command/API**: the IaC-defined ResourceHealth alerts (in `prd-alerts.tfvars`) watch per-resource health. If they DIDN'T fire today, that's strong evidence no Azure-side resource went unhealthy. This is the **complementary** Azure-side falsifier to the cluster probes above.

**Command** (run from a shell with `az` set to the prod subscription):

```bash
az monitor log-analytics query --workspace 8bb8b1ca-9b6e-4af8-afca-6e9f1fda544a \
  --analytics-query "AzureActivity | where TimeGenerated between (datetime(2026-05-11T13:00:00Z) .. datetime(2026-05-11T13:20:00Z)) | where CategoryValue == 'ResourceHealth' | where ActivityStatusValue == 'Active' | where OperationNameValue contains 'healthevent/Activated/action' | project TimeGenerated, ResourceProvider, ResourceId, Properties" \
  -o json
```

**Expected output (clean)**: empty array `[]` — no Azure resource went unhealthy in the window.

**Expected output (degraded)**: any row with `ResourceProvider` matching `MICROSOFT.SQL`, `MICROSOFT.DOCUMENTDB`, `MICROSOFT.STORAGE`, `MICROSOFT.KEYVAULT`, `MICROSOFT.EVENTHUB`, `MICROSOFT.SERVICEBUS`, `MICROSOFT.CACHE`, etc. → real Azure-side resource impact during the window; the cluster sanity check above must be cross-referenced before closing.

## After the playbook

1. Save the outputs of Probes 1–3 (and optionally Probe 4) to your incident dir as evidence:

```bash
INCIDENT_DIR="/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/log/employer/eneco/02_on_call_shift/2026_05_11_cmc_alert_vpp_cluster_prod"
oc -n eneco-vpp-prd get pods --field-selector=status.phase!=Running -o wide > "$INCIDENT_DIR/oc-probe1-non-running-pods.txt" 2>&1
oc -n eneco-vpp-prd get events --sort-by='.lastTimestamp' --field-selector=type!=Normal -o yaml > "$INCIDENT_DIR/oc-probe2-events.yaml" 2>&1
oc -n eneco-vpp-prd get pods -o json > "$INCIDENT_DIR/oc-probe3-pod-state.json" 2>&1
```

2. Append a one-line verdict to `rca.md` under the Sign-off section (manually or via PR):
   - *"Pre-close gate satisfied at &lt;timestamp&gt; — `oc-playbook.md` Probes 1/2/3 returned clean; cluster not impacted."*

3. Run the close commands in [`rca.md` § Close commands](./rca.md#close-commands-az-this-page).

## Limitations of this playbook (named)

1. **Snapshot vs window** — Probe 1 is a NOW snapshot; the alert's window was 13:00–13:20 UTC. Probes 2 and 3 are the window-bounded falsifiers. Probe 1 alone is necessary but not sufficient.
2. **Namespace scope only** — these probes do not check infrastructure-level concerns (node pressure, network mesh, ingress) outside the `eneco-vpp-prd` namespace. A cluster-wide degradation that didn't reach a pod in this namespace would be missed. If the broader cluster is suspect, page #myriad-platform.
3. **Cluster-vs-Azure causality** — even if all probes return clean, this only proves the cluster's *visible* state was fine. A Microsoft platform issue affecting Azure-backed services (Cosmos, Service Bus, etc.) could cause workload-level pain that doesn't manifest as a pod failure (e.g., increased latency, retry budget consumption). Probe 4 catches some of that; the rest is out of scope for this playbook.
