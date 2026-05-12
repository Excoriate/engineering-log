---
task_id: 2026-05-11-007
agent: claude-code
status: complete
summary: Spec for new vault pattern — falsifier-driven OpenShift sanity-check playbook (rule out, not diagnose) for Azure-side window-bounded alerts. 4 probes pre-close. Ready to apply to llm-wiki/patterns/playbooks/.
spec_target_path: $SECOND_BRAIN_PATH/llm-wiki/patterns/playbooks/openshift-sanity-check-rule-out-not-diagnose.md
spec_action: create
spec_zone: patterns/playbooks
spec_status: ready_to_apply
---

# Spec — Pattern: OpenShift Sanity-Check Playbook (Rule Out, Not Diagnose)

## Target Path

`$SECOND_BRAIN_PATH/llm-wiki/patterns/playbooks/openshift-sanity-check-rule-out-not-diagnose.md`

## Frontmatter

```yaml
---
description: "Mandatory pre-close sanity check pattern for ANY Azure-side window-bounded alert that names an OpenShift namespace (e.g., CMC vpp-resource-unhealthy on eneco-vpp-prd). Falsifier-driven, 4 probes (non-Running pods snapshot, abnormal events transitions, restart-count terminations in window, optional Azure-side ResourceHealth complementary falsifier). Read-only. Decision matrix: any positive evidence of cluster degradation in the alert's evaluation window → STOP closing, open a workload incident. All probes clean → close-only proceed. Encodes the principle: the cloud-side alert's truth surface is the workspace; the workload's truth surface is the cluster API; when the workspace was demonstrably stale (e.g., during a Microsoft platform latency incident like 5Z1B-6KG), the workload truth surface is the authority."
type: pattern
domain: tech
status: active
source: agent
created: 2026-05-11
last_validated: 2026-05-11
severity: high
confidence: validated
scope: "Eneco MCC OpenShift production cluster (eneco-vpp-prd namespace) and acceptance/dev clusters (eneco-vpp-acc, eneco-vpp-dev) — any incident where an Azure-side alert names a namespace AND the on-call must decide close-only vs open-workload-incident."
tags: [eneco, vpp, openshift, on-call, playbook, pattern, sanity-check, falsifier-driven, oc-cli, azure-alert, microsoft-incident-correlation]
---
```

## Body

> **Goal**: prove (or disprove) that NO workload was actually unhealthy in the named namespace during the alert's evaluation window. This is a **falsifier for the "no workload affected" claim** — not a diagnosis tool. Read-only.

## When to use this pattern

Use this playbook when ALL of the following hold:

- An Azure-side alert (scheduledQueryRule, log alert, metric alert) names an OpenShift namespace as its target
- The alert's `monitorCondition` is `Fired` and you're considering closing it
- You want to RULE OUT cluster-side workload impact before closing, NOT to diagnose the cluster
- The alert has a bounded evaluation window (most do — typically 5 min)

Do NOT use this playbook for:
- Cluster-wide degradation diagnosis (use a full SRE diagnostic playbook)
- Pod-level RCA on a confirmed cluster problem (use the relevant gotcha + RCA process)
- Sandbox/AKS workloads (the `oc` CLI doesn't apply; use `kubectl`)

## Prerequisites

1. `oc` CLI installed and authenticated to the cluster whose API serves the named namespace (`oc whoami`, `oc config current-context`)
2. At least `view` permission on the target namespace
3. All probes below are **read-only**. If any command asks to mutate, STOP — you have the wrong playbook.

```bash
# Confirm context before any probe
oc whoami
oc config current-context
oc get ns <target-namespace> -o yaml | grep -E '^(metadata.name|status.phase)' | head -5
# Expected: namespace exists, status.phase=Active
```

## Decision Matrix

| Outcome | Action |
|---------|--------|
| All probes return clean | Cluster was not impacted. Proceed to close-only on the Azure side. |
| Any probe returns positive evidence of degradation in the namespace during the alert's window | **STOP**. The "no workload affected" claim collapses. Do NOT close. Open a real workload incident; the RCA's framing must be revisited. Page `#myriad-major-incidents` if material. |
| Any probe errors out (auth, transport, namespace missing) | Resolve the prerequisite issue. Do NOT close the alert until probes succeed. |

## Evidence labels used

- **A1 FACT** = command output captured by you in this session
- **A2 INFER** = derived from A1 via the decision rule below it

## Probe 1 — Are any pods NOT Running RIGHT NOW?

**Question**: is anything in the namespace in a non-Running state (Pending, CrashLoopBackOff, Error, ImagePullBackOff, Unknown, Failed)?

**Why this command**: the OpenShift API is the authority for current pod state; the workspace metrics (which Azure caches) may be stale during platform latency incidents (per Microsoft's own warning about "incorrect alert activation" during such windows).

**Command**:

```bash
oc -n <target-namespace> get pods --field-selector=status.phase!=Running -o wide
```

**Expected output (clean)**:

```text
No resources found in <target-namespace> namespace.
```

**Expected output (degraded — STOP closing)**: any row appears. Examples that mean STOP:

```text
NAME                              READY   STATUS                 RESTARTS   AGE     IP
gurobi-compute-xyz                0/1     CrashLoopBackOff       7          15m     10.x.x.x
inbox-ingestion-abc               0/1     ImagePullBackOff       0          5m      10.x.x.x
assetplanning-def                 0/1     Pending                0          12m     <none>
```

**Decision rule**:
- Empty output → A1 clean. **NOW snapshot**, not the alert's window — pair with Probe 3.
- Any non-Running pod → A2 cluster degradation; STOP closing.

**Principle (transferable)**: cloud-side alert's truth surface is the workspace; workload's truth surface is the cluster API. When the workspace was demonstrably stale (e.g., during a known Microsoft platform incident), the workload truth surface is the authority — ALWAYS probe the cluster directly, do not trust the alert narrative alone.

## Probe 2 — Any abnormal events in the last 30 minutes?

**Question**: did the cluster log any abnormal scheduling, image-pull, OOM, eviction, or unhealthy events in or near the alert's evaluation window?

**Why this command**: events are the cluster's own audit trail of pod/scheduler/controller actions. They predate metrics and are not subject to Log Analytics ingestion delay.

**Command**:

```bash
oc -n <target-namespace> get events --sort-by='.lastTimestamp' \
  --field-selector=type!=Normal \
  -o custom-columns='LAST:.lastTimestamp,TYPE:.type,REASON:.reason,OBJECT:.involvedObject.name,MSG:.message' \
  | tail -30
```

**Expected output (clean)**: empty or only `Normal` events (the filter excludes those, so clean = empty).

**Expected output (degraded — STOP closing)**: any of these reasons in the last 30 minutes:

- `BackOff` / `CrashLoopBackOff`
- `FailedScheduling`
- `FailedMount`
- `ImagePullBackOff` / `ErrImagePull`
- `OOMKilling` / `Evicted`
- `Unhealthy` (from a liveness probe)
- `NodeNotReady` (any node affecting this namespace)

**Decision rule**:
- No Warning/Error events in last 30m → A1 clean
- Any matching reason within `<window>±reasonable padding` → A2 cluster degradation; STOP closing
- Warning/Error events OUTSIDE the window → record but does not block closing the Azure alert; may warrant a separate ticket

**Principle**: events show *transitions* (state changes), not state. A probe that returns only current state can miss a pod that crashed-and-recovered in the window. Events catch the transient cases.

## Probe 3 — Did any container's restart count climb during the alert's window?

**Question**: even if everything is Running now, did any container restart during the alert's window?

**Why this command**: `restartCount` is monotonic per container per pod lifetime. A pod that crashed-and-recovered would show a non-zero `restartCount` with `lastState.terminated.finishedAt` in the window of interest.

**Command** (most readable form):

```bash
oc -n <target-namespace> get pods -o json | jq -r '
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

**Expected output (clean)**: `[]` OR a list with all `lastTerminationAt` timestamps OUTSIDE the alert's window (pre-existing chronic crash loops are noted but do not block closing today's alert).

**Expected output (degraded — STOP closing)**: any entry with `lastTerminationAt` inside the window. Especially if `lastTerminationReason` is `OOMKilled`, `Error`, or `ContainerCannotRun`.

**Decision rule**:
- All terminations outside window → A1 clean for THIS incident; A2 "cluster fine for THIS alert; chronic crash loops may exist but are unrelated"
- Any termination inside window → A2 cluster impact within alert's eval window; STOP closing

**Principle**: state-now vs state-during-event. The window-bounded falsifier is the one that matters when the alert is bounded to a window.

## (Optional) Probe 4 — Cluster-wide ResourceHealth events for namespace resources

**Question**: did any Azure resource backing the namespace (Azure SQL DB, Cosmos DB, Storage, Key Vault, Event Hub, Service Bus, Redis Cache) have a per-resource ResourceHealth Activated event during the alert's window?

**Why this command**: the IaC-defined ResourceHealth alerts (in `prd-alerts.tfvars`) watch per-resource health. If they DIDN'T fire today, that's strong evidence no Azure-side resource went unhealthy. Complementary Azure-side falsifier.

**Command** (run with `az` set to the relevant subscription):

```bash
az monitor log-analytics query --workspace <WORKSPACE_GUID> \
  --analytics-query "AzureActivity | where TimeGenerated between (datetime(<WINDOW_START_ISO>) .. datetime(<WINDOW_END_ISO>)) | where CategoryValue == 'ResourceHealth' | where ActivityStatusValue == 'Active' | where OperationNameValue contains 'healthevent/Activated/action' | project TimeGenerated, ResourceProvider, ResourceId, Properties" \
  -o json
```

**Expected output (clean)**: empty array `[]` — no Azure resource went unhealthy in the window.

**Expected output (degraded)**: any row with `ResourceProvider` matching `MICROSOFT.SQL`, `MICROSOFT.DOCUMENTDB`, `MICROSOFT.STORAGE`, `MICROSOFT.KEYVAULT`, `MICROSOFT.EVENTHUB`, `MICROSOFT.SERVICEBUS`, `MICROSOFT.CACHE`, etc. → real Azure-side resource impact during the window; cross-reference with cluster probes before closing.

## After the playbook

1. Save the outputs of Probes 1–3 (and optionally Probe 4) to the incident dir as evidence:

```bash
INCIDENT_DIR="<path-to-your-incident-dir>"
oc -n <target-namespace> get pods --field-selector=status.phase!=Running -o wide > "$INCIDENT_DIR/oc-probe1-non-running-pods.txt" 2>&1
oc -n <target-namespace> get events --sort-by='.lastTimestamp' --field-selector=type!=Normal -o yaml > "$INCIDENT_DIR/oc-probe2-events.yaml" 2>&1
oc -n <target-namespace> get pods -o json > "$INCIDENT_DIR/oc-probe3-pod-state.json" 2>&1
```

2. Append a one-line verdict to the RCA under the Sign-off section:
   - *"Pre-close gate satisfied at <timestamp> — `oc-playbook.md` Probes 1/2/3 returned clean; cluster not impacted."*

3. Run the close commands on the Azure side (and ServiceNow if applicable; see [[azure-alert-close-two-plane-azure-plus-servicenow]]).

## Limitations (named, not hidden)

1. **Snapshot vs window** — Probe 1 is NOW; the alert's window is earlier. Probes 2 and 3 are the window-bounded falsifiers. Probe 1 alone is necessary but not sufficient.
2. **Namespace scope only** — these probes do not check infrastructure-level concerns (node pressure, network mesh, ingress) outside the named namespace. Cluster-wide degradation that didn't reach a pod in this namespace would be missed.
3. **Cluster-vs-Azure causality** — even if all probes return clean, this only proves the cluster's *visible* state was fine. A Microsoft platform issue affecting Azure-backed services (Cosmos, Service Bus, etc.) could cause workload-level pain that doesn't manifest as a pod failure (e.g., increased latency, retry budget consumption). Probe 4 catches some of that; the rest is out of scope for this playbook.

## Origin

Authored 2026-05-11 by Alex Torres during the on-call shift after `el-demoledor` BLOCKING finding F3: the original CMC RCA referenced `oc-playbook.md` but the file did not exist. Source incident: `log/employer/eneco/02_on_call_shift/2026_05_11_cmc_alert_vpp_cluster_prod/oc-playbook.md` (192 lines).

## Cross-Links

- [[2026-05-11-oncall-shift-trade-platform-quad-incident]] — episode of origin (Incident 1)
- [[azure-alert-close-two-plane-azure-plus-servicenow]] — sibling pattern; pair with this playbook for full close discipline
- [[out-of-iac-alerts-decay-silently-quarterly-inventory-diff]] — lesson on why the rule existed in the first place
- [[automitigate-false-orthogonal-to-severity-needs-manual-close-runbook]] — lesson on why the rule needs manual close
- [[azure-monitor-late-ingestion-fires-alerts-from-stale-data]] — gotcha on the mechanism that fired today's alert
- [[oncall-rca-must-close-on-every-state-plane]] — broader operational discipline
- Source: `log/employer/eneco/02_on_call_shift/2026_05_11_cmc_alert_vpp_cluster_prod/oc-playbook.md`
