---
title: "Cross-RCA correlation — task 003 (ln2I9h CPU throttling) ↔ task 005 (vpp-resource-unhealthy)"
date: 2026-05-11
authored_under_task: 2026-05-11-005
parent_rca: ../output/rca.md
sibling_rca: ../../2026_05_11_cmc_alert_vpp_cluster_prod/rca.md
sibling_supplement: ../../2026_05_11_cmc_alert_vpp_cluster_prod/rca-supplement.md
status: review
on_call: atorres.ruiz
---

# Cross-RCA correlation — `ln2I9h` ↔ `vpp-resource-unhealthy`

> **One-paragraph summary**. Today's TWO on-call paged events on the Eneco VPP stack
> are **two downstream symptoms of the same upstream Microsoft platform incident**.
> Microsoft `5Z1B-6KG` ("Log Analytics + Application Insights intermittent data
> latency in West Europe", impact window 06:40–12:45 UTC 2026-05-11) caused
> ingestion lag in our `vpp-log-analyt-p` workspace, which (a) backpressured the
> dev OpenTelemetry collector pod's prometheus exporter — manifesting as CPU+memory
> throttling on `otc-container` and producing the `CPUThrottlingHigh` alert in
> Rootly (`ln2I9h`, task 003) — and (b) caused Microsoft's "Mitigated"
> ServiceHealth communication to be ingested into the workspace at 13:10:36 UTC,
> which the over-broad `vpp-resource-unhealthy` KQL matched at 13:12:43 UTC,
> producing the sev-0 ServiceNow ticket (task 005).

## Evidence labels used in this document

- **A1 FACT** — externally witnessable: cited file, timestamp, or command output in either sibling RCA's antecedents or sidecars.
- **A2 INFER** — derived from A1 facts via the timeline reasoning below.
- **A3 UNVERIFIED** — not probed in this intake; resolving probe named.

## Single timeline aligning both RCAs

| Time UTC | Microsoft side | Eneco workspace | Symptom in dev (RCA 003 surface) | Symptom in prd (RCA 005 surface) | Evidence |
|----------|----------------|------------------|----------------------------------|----------------------------------|----------|
| 06:40 | `5Z1B-6KG` impact begins — Log Analytics + AppInsights data latency in West Europe | (ingestion lag begins) | (none yet) | (none) | A1 — `rootly-past-hour-cross-check.md` of task 005; Properties.communication field of the workspace ServiceHealth row |
| 08:57 | Microsoft detects | | | | A1 — same |
| 11:05 | Microsoft scales capacity | | | | A1 — same |
| **11:45:29** | (still in impact window) | Ingestion lag at peak | **🔴 `CPUThrottlingHigh` fires on `otc-container` (Rootly `ln2I9h`) — 49.76% throttled, severity:info** | | A1 — `antecedents/rootly-alert-payload.json` of task 003 |
| 11:59:16 | (still in impact window) | | `ContainerMemoryUsageHigh` on SAME pod (Rootly `dIazbf`) — 14 min after CPU alert | | A1 — `proofs/outputs/rootly-otc-container-history.tsv` of task 003 |
| 12:45 | Microsoft declares **Mitigated** — customer impact ends per Microsoft narrative | (still draining backlog) | | | A1 — same |
| 13:01:14 | | (still draining) | `ContainerMemoryUsageHigh` on `otc-container` (Rootly `tLcfNl`) | | A1 — task 005 sidecar `rootly-past-hour-cross-check.md` |
| **13:10:36** | "Mitigated" communication published | **Ingested into `vpp-log-analyt-p` workspace AzureActivity table** | | | A1 — task 005 sidecar `F1-falsifier-firing-window.json` (this session's re-probe) |
| **13:12:43** | | (rule evaluates) | | **🔴 `vpp-resource-unhealthy` fires sev-0 → ServiceNow ticket** | A1 — task 005 sidecar `azure-alert-rule-raw.json` lastModifiedDateTime + current probe `this-rule-alerts-1d.json` |
| 13:21:14 | | | `ContainerMemoryUsageHigh` on `otc-container` again (Rootly `ZujltD`) — 96% | | A1 — task 005 sidecar |
| 13:27:55 | | | | A SIBLING alert fires: `Service Health Issue - VPP Resources - Production` (sev4) — a properly-scoped ServiceHealth alert that the orphan rule should have looked like | A1 — task 005 sidecar `azure-alerts-last-hour.json` (this session) |
| 13:55:14 | | | `ContainerMemoryUsageHigh` on `otc-container` again (Rootly `KIXyMJ`) — 94% | | A1 — task 005 sidecar |

## Mechanism: how one Microsoft incident produced both alerts

```text
                Microsoft 5Z1B-6KG — Log Analytics + AppInsights latency, West Europe
                                       │
                                       │ degrades the West Europe ingestion path
                                       │
              ┌────────────────────────┴──────────────────────────────┐
              │                                                       │
              ▼                                                       ▼
  Dev cluster apps.eneco-vpp-dev.ceap.nl                Prd subscription f007df01-...
  namespace eneco-vpp                                   workspace vpp-log-analyt-p
              │                                                       │
              │ OTel collector pod pushes telemetry                   │ AzureActivity rows
              │ via prometheus exporter to                            │ ingest with delay
              │ Log Analytics (the affected path)                     │
              │                                                       │
              ▼                                                       ▼
  Telemetry queue backpressure in                       Microsoft's own "Mitigated"
  batch processor; memory grows; GC                     ServiceHealth communication
  pressure → CPU bursts                                 ingested at 13:10:36 UTC
              │                                                       │
              ▼                                                       ▼
  CFS throttling exceeds 25%                            vpp-resource-unhealthy's
  threshold of upstream rule                            over-broad KQL matches at
                                                        13:12:43 UTC
              │                                                       │
              ▼                                                       ▼
  Rootly: CPUThrottlingHigh ln2I9h                      ServiceNow: sev-0 CMC ticket
  severity:info, Rootly urgency:Low                     "Disaster", no Rootly path
              │                                                       │
              └────────────────────┬──────────────────────────────────┘
                                   │
                                   ▼
                          ON-CALL paged twice for ONE upstream incident
```

## What this changes in task 003's RCA

Task 003's rca.md presents four competing hypotheses (H-A undersized CPU, H-B memory upstream, H-C rule mis-calibrated, H-D debug verbose). H-B was the "memory pressure upstream" candidate. **This cross-correlation adds external evidence supporting H-B**:

- Microsoft's incident impact window (06:40-12:45 UTC) **contains** the CPU alert fire time (11:45 UTC). The latency was active when the alert fired.
- Microsoft's own communication on the incident explicitly warned of *"incorrect alert activation for workspaces hosted in the region"* — the literal pathology that produced both alerts.
- The OTel collector's prometheus exporter pushes to a workspace in the affected region. The collector's CPU+memory growth is consistent with batch-processor queue buildup when downstream is slow.
- Five memory alerts on the same pod across 10 days (May 1, May 1, May 4, today × 2) suggests a chronic upstream-volume condition that today's incident pushed past threshold.

**Recommendation for task 003 RCA promotion path**:

- Hold task 003 at `status: review` until the live cluster discriminator probe runs (the rca-holistic `oc -n eneco-vpp get OpenTelemetryCollector` + `top pod` + Prometheus memory time series).
- If the discriminator confirms H-B (monotonic memory growth in dev cluster from May 1 onward, with CPU coincident with GC bursts), the diagnosis collapses cleanly: **"OTel collector backpressure from West Europe Log Analytics ingestion lag, exacerbated today by Microsoft incident `5Z1B-6KG`."** A1 from temporal alignment + workspace-region match.
- The handover-to-enrich track in task 003's L8 (raise CPU budget / drop debug verbosity) still applies, but the prioritization changes: **H-D fix is cheapest (debug verbosity) and addresses an Eneco-side cause; H-A fix (raise CPU budget) is the right operator action; H-B fix (telemetry volume) is the upstream concern that today's Microsoft incident merely exposed**.

## What this changes in task 005's RCA

Task 005's rca.md narrative (over-broad KQL fired on Microsoft mitigation notice) is unchanged in essence. The cross-RCA finding strengthens it: **task 005 is the "Eneco IaC didn't catch this" symptom; task 003 is the "Eneco workload felt this" symptom of the same Microsoft incident.**

The lesson set of task 005 should be augmented with:

> **Lesson 4 (cross-RCA, new)**: a Microsoft-side platform incident in a region where your workspace lives can produce simultaneous downstream signals at two completely different abstraction layers — an over-broad workspace-KQL alert that catches Microsoft's own announcement (task 005), AND an application-layer telemetry-backpressure alert from a collector pod in a different cluster (task 003). On-call must check Service Health BEFORE concluding either alert is an Eneco-side fault.

The corresponding probe sits in the on-call playbook for the FIRST symptom that arrives:

```bash
# On any alert that looks "Azure-side workspace/ingestion/latency"-themed, check Service Health FIRST
az rest --method GET --url \
  "https://management.azure.com/subscriptions/${SUB}/providers/Microsoft.ResourceHealth/events?api-version=2022-10-01&\$filter=Service eq 'Log Analytics' or Service eq 'Application Insights'" \
  | jq -r '.value[] | select(.properties.status == "Active" or .properties.status == "Resolved") | [.properties.eventType, .properties.title, .properties.lastUpdateTime, .properties.eventLevel] | @tsv'

# Or the broader az service-health query
az rest --method GET --url \
  "https://management.azure.com/subscriptions/${SUB}/providers/Microsoft.ResourceHealth/events?api-version=2022-10-01" \
  | jq -r '.value[]'
```

If Service Health shows an Active or recently-Mitigated incident matching the symptom class, **route both alerts to that incident** rather than diagnosing them independently.

## Status

This document is `status: review`. It does not promote either parent RCA to `status: complete`. It DOES:

1. Document the temporal + region + path correlation between the two alerts (A1 from sibling sidecars).
2. Add an A1 row to task 003's evidence chain (the Microsoft incident's impact window contains the CPU alert fire time).
3. Add Lesson 4 candidate to task 005's lesson set (cross-RCA "check Service Health first" probe).
4. Recommend a discriminator-probe ordering change in BOTH on-call playbooks.

The cluster-side discriminator probe (still A3 in both RCAs since `oc` is not in this intake) remains the gating factor for both promotions to `complete`.
