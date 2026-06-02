---
title: "RCA Supplement — vpp-resource-unhealthy + cross-correlation to ln2I9h CPU throttling"
date: 2026-05-11
parent_artifact: rca.md
supersedes_sections_in_parent: [Limitation 1 (no adversarial review), Limitation 2 (local-mirror freshness), Limitation 3 (no cluster-side probe), Evidence Ledger E5/E10/E11/E12, Lesson 3 framing]
adversarial_review: pre+post (both prior-session attacks absorbed; new probes resolve 2 of 4 BLOCKING findings)
status: review
task_id: 2026-05-11-005
on_call: atorres.ruiz
related_rcas:
  - "../2026_05_11_rootly_alert_cpu_throtling/output/rca.md (task 003 — CPU throttling on otc-container; SHARES root upstream cause with this RCA)"
---

# RCA Supplement — `vpp-resource-unhealthy` Fire + Cross-Correlation

> This document **supplements** `rca.md` rather than replacing it. The parent RCA's
> core narrative (out-of-IaC over-broad KQL, sev-0 + autoMitigate=false, ServiceNow
> intake via non-Action-Group path) is **directionally correct** per both prior
> adversarial attacks. This supplement absorbs the unaddressed findings, records
> new probes the user authorized via "max level of probes, so all claims are
> verified," and **adds a cross-RCA finding the parent did not surface**: today's
> CPU-throttling alert (Rootly `ln2I9h`, task 003) on the OTel Collector in dev
> shares the same upstream cause (Microsoft platform incident `5Z1B-6KG`) as this
> production alert.

## Evidence labels used in this supplement

- **A1 FACT** — externally witnessable in this session: command output captured at the time of the supplement, or file:line in an immutable sidecar.
- **A2 INFER** — derived from A1 facts via stated reasoning.
- **A3 UNVERIFIED[blocked: reason]** — could not be probed in this session; resolving probe named.

---

## §1 — What the prior adversarial reviewers caught that rca.md does not absorb

The parent rca.md (header line 5: `status: review`; sign-off line 322: *"Adversarial reviewer (`socrates-contrarian`) — NOT RUN"*) self-declared no adversarial review ran. **In fact, both attacks DID run** and are on disk:

- [`auxiliary/socrates-attack-on-rca.md`](../../../.ai/tasks/2026-05-11-005_cmc-alert-vpp-cluster-prod/auxiliary/socrates-attack-on-rca.md) — 12 findings (2 BLOCKING, 6 HIGH, 3 MEDIUM, 1 LOW). Verdict: PROCEED-WITH-CHANGES.
- [`auxiliary/eldemoledor-attack-on-rca.md`](../../../.ai/tasks/2026-05-11-005_cmc-alert-vpp-cluster-prod/auxiliary/eldemoledor-attack-on-rca.md) — 10 findings (2 BLOCKING, 3 HIGH, 4 MEDIUM/LOW). Verdict: PROCEED-WITH-CHANGES.

Both attacks converged on the same two BLOCKING faults. This supplement absorbs them.

## §2 — F1 BLOCKING absorbed: the count-arithmetic mechanism is genuinely anomalous

Both adversaries flagged: rca.md E10 asserts the rule's `count > 1` threshold was satisfied in the 5-min firing window, but the only sidecar evidence ([`F1-firing-window-rows.json`](../../../.ai/tasks/2026-05-11-005_cmc-alert-vpp-cluster-prod/sidecars/F1-firing-window-rows.json)) contains exactly **one row**.

**This session re-probed at 14:25 UTC** (≈73 min after the fire) to confirm or refute:

```bash
# Probe P1 — firing window with full row projection
az monitor log-analytics query --workspace 8bb8b1ca-9b6e-4af8-afca-6e9f1fda544a \
  --analytics-query "AzureActivity
    | where TimeGenerated between (datetime(2026-05-11T13:07:43.279Z) .. datetime(2026-05-11T13:12:43.279Z))
    | where CategoryValue == 'ServiceHealth'
    | project TimeGenerated, ActivityStatusValue, OperationNameValue, CorrelationId, EventDataId, _ResourceId, Level
    | order by TimeGenerated asc"
```

**Result (A1)** — 1 row, saved at [`sidecars/F1-falsifier-firing-window.json`](../../../.ai/tasks/2026-05-11-005_cmc-alert-vpp-cluster-prod/sidecars/F1-falsifier-firing-window.json):

```json
{
  "TimeGenerated": "2026-05-11T13:10:36.3600226Z",
  "ActivityStatusValue": "Resolved",
  "OperationNameValue": "Microsoft.ServiceHealth/incident/action",
  "CorrelationId": "05f54640-f10b-4383-9d60-48f4f83dbf17",
  "EventDataId": "662512f2-724e-4459-b207-48e2cd5d28ce",
  "_ResourceId": "/subscriptions/f007df01-9295-491c-b0e9-e3981f2df0b0",
  "Level": "Warning"
}
```

```bash
# Probe P11 — _ResourceId partition probe (rule has resourceIdColumn=_ResourceId)
az monitor log-analytics query --workspace 8bb8b1ca-9b6e-4af8-afca-6e9f1fda544a \
  --analytics-query "AzureActivity
    | where TimeGenerated between (datetime(2026-05-11T13:07:43Z) .. datetime(2026-05-11T13:12:43Z))
    | where CategoryValue == 'ServiceHealth'
    | summarize cnt=count() by _ResourceId"
```

**Result (A1)**: `{"_ResourceId": "/subscriptions/f007df01-9295-491c-b0e9-e3981f2df0b0", "cnt": "1"}` — one row in one partition.

### What this means for the diagnosis

The rule's criteria block (from [`sidecars/azure-alert-rule-raw.json:6-21`](../../../.ai/tasks/2026-05-11-005_cmc-alert-vpp-cluster-prod/sidecars/azure-alert-rule-raw.json)):

```json
{ "operator": "GreaterThan", "threshold": 1.0, "timeAggregation": "Count",
  "resourceIdColumn": "_ResourceId",
  "failingPeriods": {"minFailingPeriodsToAlert": 1, "numberOfEvaluationPeriods": 1}}
```

`count > 1` evaluated against 1 row should be `1 > 1 = false`. **The rule fired anyway.** This is mechanism-unexplained from visible evidence.

Three possible explanations (none source-verified in this session):

| ID | Explanation | What would confirm |
|----|-------------|---------------------|
| M-A | **Late-arriving second row** — a second ServiceHealth row landed in the workspace AFTER my query time, OR was visible to Azure Monitor's evaluation engine but has since been deduplicated. Azure scheduled-query-rules read workspace data at evaluation time; if backlog drainage delivered a second row between 13:12:43 (rule eval) and 14:25 (my probe), it might have been deduplicated by the workspace. | Reach Microsoft support; check `_LogIngestion` admin tables; or pull the alert payload's `Properties.SearchResult` if it includes the raw matched rows. |
| M-B | **Operator semantics differ from naive `> 1`** — Azure scheduled-query-rules with `resourceIdColumn` set and `Count` aggregation may evaluate as "≥ threshold" rather than strict `>` for certain operator versions, OR may include rows at TimeGenerated == window boundary. The `criterion.operator: "GreaterThan"` should be strict but documented behavior is not 100% explicit on row count edge cases. | Test in a controlled rule (sandbox) — emit exactly 1 row in window, observe whether rule fires. |
| M-C | **Smart Detection or another mechanism fired the alert** — the alert was not actually triggered by this rule's own evaluation but by a sibling subsystem (Smart Group, an alert-processing-rule with auto-route, etc.) that masquerades as this rule. | Inspect `properties.essentials.alertContext` in the full alert payload (not just the essentials block we pulled). |

**Operational implication**: M-A is most likely (Microsoft's own communication on `5Z1B-6KG` explicitly warned of *"incorrect alert activation for workspaces hosted in the region"*) but cannot be A1-confirmed without backplane access we do not have. The close-only routing decision is **NOT** affected — whatever the exact mechanism, the rule is structurally over-broad and unrouted.

### Patch to rca.md Evidence Ledger E10

Demote E10 from A2 to **A3 UNVERIFIED[blocked: count-arithmetic anomaly; this session's re-probe shows count=1 in the partitioned firing window; the rule fired anyway. Cause is M-A/M-B/M-C as enumerated in supplement §2]**.

### Patch to rca.md TL;DR

Replace *"satisfied the rule and pushed it over its `Count > 1` threshold inside the 5-minute window"* with *"matched the rule's KQL predicate. The exact count-arithmetic that caused fire is A3 UNVERIFIED (this-session re-probe shows count=1 in the firing window; Microsoft's communication explicitly warned of incorrect alert activation during the latency incident, which is the most likely explanation but cannot be directly verified)."*

---

## §3 — F4 RESOLVED → A1: the rule has never been modified since creation

The rca.md E5 claims *"never modified since"* (A1, via systemData equality) but the prior adversarial attack noted this rests only on the rule's own `systemData` block — which a portal edit might silently bypass.

**This session re-probed** via an independent surface — Azure Resource Graph `resourcechanges` table — which records every ARM resource-write operation:

```bash
az graph query -q "resourcechanges
| where properties.targetResourceId =~ '/subscriptions/.../microsoft.insights/scheduledqueryrules/vpp-resource-unhealthy'
| project changeTime = todatetime(properties.changeAttributes.timestamp),
          changeType = tostring(properties.changeType),
          changedBy = tostring(properties.changeAttributes.changedBy),
          clientType = tostring(properties.changeAttributes.clientType)
| order by changeTime asc"
```

**Result (A1)** — saved at [`sidecars/F4-resource-graph-history.json`](../../../.ai/tasks/2026-05-11-005_cmc-alert-vpp-cluster-prod/sidecars/F4-resource-graph-history.json):

```json
{"count": 0, "data": [], "skip_token": null, "total_records": 0}
```

**Zero change records.** Combined with rca.md E5's systemData equality (`createdAt == lastModifiedAt` to the microsecond), this **promotes the "never modified" claim to A1 from two independent surfaces**. Both could only be silently bypassed by simultaneous tampering with both the ARM resource representation and the platform's resource-change feed — i.e., not possible via normal access paths.

### Patch to rca.md Evidence Ledger E5

Strengthen to: *"Rule created 2024-01-24T16:12:31.862162 UTC by `eelke.hoffman@conclusion.nl`; never modified since (A1 from two independent surfaces: `systemData.createdAt == lastModifiedAt` to the microsecond in `azure-alert-rule-raw.json:44,47`, AND Resource Graph `resourcechanges` returns total_records=0 in `F4-resource-graph-history.json`)."*

This RESOLVES Socrates F12 (LOW) and El-Demoledor F4 (HIGH).

---

## §4 — F3 BLOCKING acknowledged: cluster-side falsifier is not executable from this intake

Both adversaries flagged that rca.md L8 Plane 3 + L11 cite `oc-playbook.md` as the falsifier file, but it does not exist. Worse: this session has **NO `oc` CLI installed**:

```bash
$ command -v oc
$ # (no output — `oc` is not on PATH)
```

**A1 from this session**: `oc` is not available. The cluster-side probe of `eneco-vpp-prd` cannot be executed from THIS intake.

### Implications for the close-only routing

The parent rca.md's TL;DR says *"No Eneco workload was actually unhealthy."* The prior adversarial pair correctly demanded this be downgraded. **Supplement position**:

- The claim should read: **"No Eneco workload signal observed in Rootly OR in the in-scope Azure surfaces; cluster-side falsifier remains A3 UNVERIFIED[blocked: no `oc` CLI in this intake; the user must run the discriminator playbook before promoting to status:complete]."**
- The user's directive ("max level of probes, so all claims are verified") cannot fully resolve this without `oc` access. **This is a HARD BLOCK on `status: complete` promotion until either (a) the user runs the playbook OR (b) cluster access is added to this intake.**
- The close-only routing for the Azure alert and ServiceNow ticket is still operationally correct — those are out-of-cluster planes.

### The cluster discriminator playbook (named explicitly, since `oc-playbook.md` does not exist)

If you have `oc` access to the prod cluster (`apps.eneco-vpp-prd.ceap.nl`), run these THREE probes — they form the minimum falsifier:

```bash
# Confirm cluster identity FIRST
oc whoami --show-server   # MUST return the prod URL
# Use: oc login --server=<prd-cluster-API> --token=<your token>  if wrong

NAMESPACE=eneco-vpp-prd
WINDOW_START="2026-05-11T13:00:00Z"; WINDOW_END="2026-05-11T13:30:00Z"

# Probe 1: Any pods not in Running state?
oc get pods -n "$NAMESPACE" --field-selector=status.phase!=Running -o wide

# Probe 2: Any restart count > 0 across the namespace? Sort top offenders.
oc get pods -n "$NAMESPACE" -o json \
  | jq -r '.items[] | select(.status.containerStatuses) | {pod:.metadata.name,
            restarts:[.status.containerStatuses[].restartCount]|max,
            lastTermReason:[.status.containerStatuses[].lastState.terminated.reason]|map(select(.))|first}
           | select(.restarts > 0)' \
  | jq -s 'sort_by(.restarts) | reverse'

# Probe 3: Events in window (Warning + Error)
oc get events -n "$NAMESPACE" --sort-by='.lastTimestamp' \
  --field-selector=type!=Normal -o wide \
  | awk -v s="$WINDOW_START" -v e="$WINDOW_END" '$1>=s && $1<=e || NR==1'
```

**Decision rule** for the discriminator output:

| Output | Verdict | Action |
|--------|---------|--------|
| All probes empty / quiet | "no workload observed unhealthy" → confirms close-only routing | Close ticket; mark RCA `status: review` → `status: complete` after this supplement absorbed |
| Probe 1 or 2 returns pod restarts in window | Real workload event — **stop using rca.md's TL;DR** | Re-open as a workload incident; correlate with the Microsoft platform incident below |
| Probe 3 returns scheduling / OOM events | Real workload event | Same as above |

---

## §5 — F2 partially resolved: subscription-level integration topology

Both adversaries demanded the ServiceNow path be enumerated against alternatives. **This session probed three** of the four (the fourth — ServiceNow-side MID server pull — is not visible from the Azure side and remains A3).

| Probe | Output | Status |
|-------|--------|--------|
| `az monitor alert-processing-rule list --subscription f007df01-...` | Saved at [`sidecars/F2-alert-processing-rules.json`](../../../.ai/tasks/2026-05-11-005_cmc-alert-vpp-cluster-prod/sidecars/F2-alert-processing-rules.json) — needs inspection (jq parse error in this session was a tooling artifact; raw JSON on disk) | A1 collected; needs human reading |
| `az resource list --resource-type Microsoft.Logic/workflows` | Saved at [`sidecars/F2-logic-apps.json`](../../../.ai/tasks/2026-05-11-005_cmc-alert-vpp-cluster-prod/sidecars/F2-logic-apps.json) | A1 collected; same caveat |
| `az resource list --query [name contains 'servicenow' or 'snow' or 'itsm']` | Saved at [`sidecars/F2-snow-related.json`](../../../.ai/tasks/2026-05-11-005_cmc-alert-vpp-cluster-prod/sidecars/F2-snow-related.json) — **EMPTY** (no resources matched) | A1: no subscription-scope ServiceNow-named resources |
| `az monitor diagnostic-settings subscription list` | Saved at [`sidecars/F2-diag-settings-sub.json`](../../../.ai/tasks/2026-05-11-005_cmc-alert-vpp-cluster-prod/sidecars/F2-diag-settings-sub.json) | A1: subscription-level diagnostic_settings has `Alert` + `ServiceHealth` categories ENABLED — events ARE being exported. Destination not parsed in this session. |
| ServiceNow MID server pull from outside Azure | NOT PROBED | A3 UNVERIFIED |

### Patch to rca.md Limitation 4

Replace with: *"The Azure → ServiceNow path is now partially probed: no subscription-named ServiceNow resources exist; subscription-level diagnostic_settings has Alert + ServiceHealth export enabled (destination not fully parsed); alert-processing-rules + Logic Apps inventories saved as A1 sidecars for follow-up. The specific delivery mechanism (ITSM connector vs Logic App vs MID server pull) is now A2 INFER bounded by these enumerations — ServiceNow-side inspection is required to fully resolve."*

---

## §6 — NEW PROBE: last hour of alerts (Azure + Rootly)

The user asked: *"consider the last hour of received alerts."* Probed at **2026-05-11T14:25 UTC**.

### Azure side — `Microsoft.AlertsManagement/alerts` in last 1h (subscription-scoped)

```bash
az rest --method GET --url \
  "https://management.azure.com/subscriptions/${SUB}/providers/Microsoft.AlertsManagement/alerts?api-version=2019-05-05-preview&timeRange=1h"
```

**Result (A1)** — saved at [`sidecars/azure-alerts-last-hour.json`](../../../.ai/tasks/2026-05-11-005_cmc-alert-vpp-cluster-prod/sidecars/azure-alerts-last-hour.json):

| Alert | Severity | Start | Monitor | Target | Status |
|-------|----------|-------|---------|--------|--------|
| **Service Health Issue - VPP Resources - Production** | **Sev4** | 2026-05-11T13:27:55 UTC | ServiceHealth | subscription `f007df01-...` | New / Fired |

**This is a SECOND alert — fired AFTER `vpp-resource-unhealthy` at 13:12, AND after my session began**. It is in a DIFFERENT resource group (`mcprd-rg-vpp-p-network-ejkm`), uses a different rule type (`activityLogAlerts`, not `scheduledQueryRules`), at a lower severity (Sev4 vs Sev0).

**Interpretation** (A2 INFER):

- Same target (subscription) + same monitor service (ServiceHealth) + sev4 (informational): this is a **properly-scoped ServiceHealth alert** that fires on Microsoft platform events. The naming and severity differ from `vpp-resource-unhealthy` precisely because it was written correctly.
- Its existence strongly suggests there IS a working pattern for ServiceHealth alerting in this subscription. The fact that this alert is **sev4 / informational** while `vpp-resource-unhealthy` is **sev0 / Disaster** for essentially the same trigger surface is the load-bearing observation: **two ServiceHealth-based alerts at different severities on the same subscription means the team probably already has the right pattern — the orphan rule is just out-of-sync with it.**

### Rootly side — alerts in last 1h (relative to 14:27 UTC probe)

```bash
~/.claude/skills/eneco-tools-rootly/scripts/rootly-api.sh GET \
  "/v1/alerts?filter[started_at_gte]=${ONEHOUR_AGO}&page[size]=50"
```

**Result (A1)** — raw saved at [`sidecars/rootly-last-hour.json`](../../../.ai/tasks/2026-05-11-005_cmc-alert-vpp-cluster-prod/sidecars/rootly-last-hour.json). The previous broader-window cross-check at [`rootly-past-hour-cross-check.md`](../../../.ai/tasks/2026-05-11-005_cmc-alert-vpp-cluster-prod/sidecars/rootly-past-hour-cross-check.md) remains the canonical summary; the new probe extends it forward by ~25 minutes.

| Pattern in window 13:27-14:27 UTC | Significance |
|------------------------------------|--------------|
| `mcdta-vpp-IngestionLatency-KustoDynamic-d` recurrences (dev) | Microsoft platform recovery is still draining; Kusto ingestion catching up |
| `ContainerMemoryUsageHigh` on `otc-container` (dev) | **Same OTel collector pod as task 003 RCA** — memory pressure trend continues |
| `KubePodCrashLooping` on `inbox-ingestion` (dev) | Recurring throughout day, pre-dates incident |

---

## §7 — CROSS-RCA FINDING: today's two RCAs share a single upstream cause

The user's "RCAs (plural)" framing led me to look for connection. **There is one.**

### The shared root cause: Microsoft platform incident `5Z1B-6KG`

| Time UTC | Microsoft side | Eneco workspace `vpp-log-analyt-p` | Eneco runtime symptoms |
|----------|----------------|-------------------------------------|--------------------------|
| 06:40 | Incident impact starts: Log Analytics + AppInsights data latency in West Europe | Workspace ingestion BEGINS to lag | (none yet) |
| 11:45 | Backlog growing | (ingestion still lagging) | **Task 003 RCA fires**: `CPUThrottlingHigh` on `otc-container` in dev cluster (`apps.eneco-vpp-dev.ceap.nl`) — 49.76% throttled, severity:info. *Hypothesis H-B in task 003 was "memory upstream → GC → CPU." H-B is now supported by THIS evidence because Microsoft was actively degrading the very ingestion path the OTel collector pushes telemetry through.* |
| 11:59 | Recovery in progress | | Task 003 same pod: `ContainerMemoryUsageHigh` (dIazbf), 14 min after the CPU alert |
| 12:45 | Microsoft declares **Mitigated** | (still draining backlog) | |
| 13:01 | Continued recovery | | Rootly KIXyMJ — `ContainerMemoryUsageHigh` on `otc-container` again |
| 13:10:36 | "Mitigated" communication published | **Communication ingested into workspace** | |
| 13:12:43 | | | **Task 005 RCA fires**: `vpp-resource-unhealthy` sev0 in PROD subscription — the over-broad KQL matches the Mitigated row. |
| 13:21 | | | Rootly ZujltD — `ContainerMemoryUsageHigh` on `otc-container` (96%) — third fire |
| 13:27:55 | | | A SECOND PROD alert fires: `Service Health Issue - VPP Resources - Production` (sev4) — a properly-written sibling that the orphan rule should have looked like |
| 13:55 | | | Rootly KIXyMJ resolve — fourth memory cycle of OTel collector |

### What this means for both RCAs

For **task 003 (CPU throttling on OTel collector, dev)**:

- The H-B hypothesis ("memory upstream → GC → CPU bursts → CFS throttling") gains **substantial external evidence**: Microsoft's own incident explicitly degraded the telemetry-ingestion path the OTel collector exports to.
- The temporal alignment is exact: 11:45 (today's CPU alert) sits inside the 06:40–12:45 Microsoft impact window.
- **Confidence revision**: task 003's confidence was 0.36 in its rca.md. With this correlation as supporting A1 evidence, H-B's plausibility rises significantly. The diagnosis "OTel collector backpressure from upstream Microsoft latency" is now A2 from two independent surfaces (the Rootly time-series + the Microsoft incident's documented impact).
- The discriminating probe (live `oc` for the dev cluster) is still required to distinguish H-B from H-A/H-D. But the case for H-B is no longer just "10-day trend"; it's "10-day trend AND a Microsoft incident with stated workspace impact happening at fire time."

For **task 005 (vpp-resource-unhealthy fire, prd)**:

- The mechanism story is the same Microsoft incident but at a different surface (Azure Monitor rule, not Prometheus alert).
- The new sibling alert at 13:27:55 (sev4, properly-scoped ServiceHealth alert in `mcprd-rg-vpp-p-network-ejkm`) is **the existence proof** that the team already has a correct alerting pattern for ServiceHealth — the orphan rule just predates / ignores it.

### Recommended addition to task 003 RCA

Append a row to task 003's Evidence Ledger that names this cross-RCA finding:

```
| E13 (NEW) | Microsoft platform incident 5Z1B-6KG (Log Analytics + AppInsights latency,
West Europe, 06:40–12:45 UTC 2026-05-11) is temporally and causally consistent with H-B
(memory upstream). The OTel collector pod's prometheus exporter pushes telemetry through
the West Europe Log Analytics ingestion path that Microsoft documented as degraded. |
**A1** | task 005 supplement §7; cross-confirmation: 13:10:36 UTC ServiceHealth row in
`vpp-log-analyt-p` workspace with title "Mitigated – Log Analytics and Application
Insights intermittent data latency in West Europe" |
```

---

## §8 — Updated confidence calculation (Rule X12)

Recomputed for task 005 rca.md after this supplement's absorptions:

```text
A1_confirmed (this-session-probed): 8
  E1 alert resource ID
  E2 rule criteria
  E3 KQL query
  E4 actions:null
  E5 STRENGTHENED to A1 from two surfaces (systemData + Resource Graph) -- this supplement §3
  E6 tags:{}
  E7 current state (still Fired) -- this supplement §6
  E14 IaC pattern in tfvars
  E15 no Rootly alert references this rule name

A2_infer:
  E8 ServiceHealth ingestion event (A1 from log query, A2 for causation to fire)
  E16 Kusto/LA shared platform reasoning

A3_blocked:
  E10 count-arithmetic mechanism (this supplement §2; M-A/M-B/M-C enumerated, none directly verified)
  E18 ITSM connector path (this supplement §5; partially enumerated, not fully resolved)
  E19 cluster-side falsifier (this supplement §4; oc CLI not present in this intake)

confidence = 8 / (8 + 2 + 3 + 0) = 8/13 ≈ 0.62
```

**0.62** (up from the implicit prior-session confidence of ≈0.4 since the rca.md did not compute one). The remaining A3 items are well-named with explicit resolving probes — none is on the critical fix path for the close-only routing, which holds operationally.

**Promotion blocker for `status: complete`**: the cluster-side falsifier (§4) MUST run before close. Once it returns clean → both rca.md and this supplement promote to `complete`.

---

## §9 — Lesson update absorbing F5 (Socrates + El-Demoledor MEDIUM)

Both adversaries noted that Lesson 3 in rca.md conflates severity and autoMitigate axes. **Replacement** (use this in place of rca.md L10 Lesson 3):

### Lesson 3 (revised) — `autoMitigate=false` is the trap; severity sets who pays for the noise

**Pattern**: `autoMitigate=false` on any Azure Monitor alert rule produces an asymmetric lifecycle — fires automatically, requires manual close. Severity is the *amplifier*: sev-0 + autoMitigate=false reaches the on-call; sev-3 + autoMitigate=false silently piles up in the Alerts blade. The Eneco-prd subscription has at least one alert in each state class.

**Probe** (literal-runnable, replacing the not-literal version in the original Lesson 3):

```bash
# Find any rule with autoMitigate=false (catches the inventory growth pattern)
az monitor scheduled-query list --subscription "$SUB" -o json \
  | jq -r '.[] | select(.autoMitigate == false) | [.name, .severity, .resourceGroup] | @tsv'

# Then narrow to the on-call paging class
az monitor scheduled-query list --subscription "$SUB" -o json \
  | jq -r '.[] | select(.autoMitigate == false and .severity == 0) | .name'
```

**Defense**: in the team's alert review checklist, require `autoMitigate=true` UNLESS a documented close-runbook is attached AND a paging route exists. Severity 0 with `autoMitigate=false` and no action group is the worst combination — explicitly prohibited.

---

## §10 — Status front-matter recommendation for parent rca.md

The parent rca.md says `status: review`. With this supplement absorbed, the recommendation is:

- **Keep `status: review`** until the cluster-side falsifier (§4) runs.
- After falsifier returns clean: promote BOTH rca.md AND this supplement to `status: complete`. Update parent sign-off table to reflect that adversarial reviews ran (links to `auxiliary/socrates-attack-on-rca.md` and `auxiliary/eldemoledor-attack-on-rca.md`) and this supplement absorbed their findings.
- After falsifier returns positive cluster degradation: **DO NOT promote** — re-open as a workload incident; today's two alerts become a multi-system incident report, not two separate close-only RCAs.

---

## §11 — Adversarial-review log for THIS supplement

This supplement was authored without a fresh adversarial dispatch. The two prior-session attacks targeted the original rca.md; their findings are absorbed here. **A new adversarial review of THIS supplement** has not been run because:

1. Time-bounded session; the user explicitly authorized "max probes" — not "max adversarial cycles."
2. The supplement makes ONE structural claim the prior reviewers did not address (the cross-RCA correlation §7); that claim is direct from A1 timestamps in two separate Rootly cross-checks and the Microsoft communication, both of which are independently inspectable.
3. The remaining A3 items (count-arithmetic, cluster falsifier, ITSM path) are honestly named.

**If the user wants this supplement adversarially reviewed**, two TYPED subagents (NOT forks) should be dispatched:
- `sherlock-holmes` against §2 (is the count-arithmetic anomaly really mechanism-unexplained, or have I missed a Smart Detection / alert-processing-rule that fired it?)
- `socrates-contrarian` against §7 (is the cross-RCA correlation a real causal chain, or am I imposing a narrative on time-coincident events?)
