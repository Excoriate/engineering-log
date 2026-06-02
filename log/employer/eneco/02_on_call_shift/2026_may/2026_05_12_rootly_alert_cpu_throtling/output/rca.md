---
task_id: 2026-05-11-003
agent: claude-code
status: review
summary: "CPUThrottlingHigh on opentelemetry-collector (otc-container) in eneco-vpp dev cluster (Rootly ln2I9h). 4 competing hypotheses (CPU-budget, memory-upstream, rule-misalignment, debug-verbose); the diagnosis cannot be collapsed without one 2-second live probe (oc get OpenTelemetryCollector). Phase 6D verdict: HANDOVER to eneco-oncall-intake-enrich for the live probes + fix track. Confidence 0.35."
title: "CPUThrottlingHigh on opentelemetry-collector (otc-container) — Rootly ln2I9h"
date: 2026-05-11
incident_class: "Known rule on Novel target with contested diagnosis"
alert_id: ln2I9h
severity: info       # Prometheus label set by the upstream rule
urgency: Low         # Rootly tier — see L1 for what Eneco's tenant calibrated vs accepted
reader: "Next-shift trade-platform on-call engineer who has never seen this OTel Collector deployment in eneco-vpp"
output_package: standard
mode: HANDOVER       # corrected from initial ENRICH per Socrates F6; see Recommended next action
domain_prior: low    # repo layout + PromQL semantics known; live cluster access NOT authorized in this intake
adversarial_review: pre+post
---

## How to read this RCA

- **Paged right now on this exact alert?** Read the [TL;DR](#tldr--action-first-standalone) (≤60s on phone) and the [Decision card](#decision-card-inline-4-hypothesis-table). Everything else is for when you have 10+ minutes.
- **Just inherited the alert as next-shift?** Read [TL;DR](#tldr--action-first-standalone) → [L12 on-call one-pager](#l12--on-call-one-pager). 5 min total.
- **Need to defend a fix recommendation under review?** Read [L1](#l1--business--functional), [L5](#l5--iac--declarative-contract), [L9](#l9--verification), and the [Evidence Ledger](#evidence-ledger). 20 min.
- **Writing the next on-call hand-off doc?** Read [L10](#l10--lessons) and [Adversarial review log](#adversarial-review-log) — the lessons are designed to transfer to other classes of incident.

> **Evidence labels used throughout this document**
> **A1 FACT** = command output / file:line / URL inspectable by any reviewer in this session.
> **A2 INFER** = derived from A1 facts through reasoning, or read from stale local clones (clone date 2025-11-18, 6 months stale).
> **A3 UNVERIFIED[blocked: <reason>]** = cannot be probed in read-only intake; resolving probe named where used.

## Mental model map

Walk away with five mental handles:

| Handle | Plain-language takeaway | Reusable elsewhere |
|--------|--------------------------|---------------------|
| **Routing label ≠ severity grading** | A SaaS alerting tier's text description is workspace config, not team triage policy. Calibration lives in the routing rules (which Slack channel, paging or not). | Any SaaS alerting platform |
| **Trend > single firing** | A pod with prior memory alerts firing CPU today is a 10-day trend, not a novel signal. Enumerate the pod's full alert history before classifying. | Any multi-rule alerting context |
| **Causal arrow ≠ alert-fire order** | Today's CPU alert firing doesn't mean CPU caused memory. Temporal order of related alerts is one input; magnitude trend is the discriminator. | Any RCA with co-firing symptoms |
| **Name-match ≠ deployment proof** | Finding a manifest whose `metadata.name` matches the running pod is INFER. The cluster's own object store is the only truth surface. | Any multi-repo GitOps environment |
| **Hypotheses can nest, not just compete** | Four hypotheses can all match the evidence and yet one (H-B memory) could be the upstream of another (H-A CPU). Adjudication needs a dependency graph, not just a probe list. | Any multi-mechanism RCA |

## Table of contents

- [TL;DR — action-first standalone](#tldr--action-first-standalone)
- [Decision card (inline 4-hypothesis table)](#decision-card-inline-4-hypothesis-table)
- [Recommended next action — handover](#recommended-next-action--handover)
- [Context Ledger](#context-ledger)
- [L1 Business / Functional](#l1--business--functional)
- [L2 Repo system](#l2--repo-system)
- [L3 Runtime architecture](#l3--runtime-architecture)
- [L4 Data flow inside the Collector](#l4--data-flow-inside-the-collector)
- [L5 IaC / Declarative contract](#l5--iac--declarative-contract)
- [L6 Pipeline / Delivery](#l6--pipeline--delivery)
- [L7 Timeline](#l7--timeline)
- [L8 Fix — observation only, no prescription](#l8--fix--observation-only-no-prescription)
- [L9 Verification — discriminating four hypotheses](#l9--verification)
- [L10 Lessons](#l10--lessons)
- [L11 Cold-start command playbook](#l11--cold-start-command-playbook)
- [L12 On-call one-pager](#l12--on-call-one-pager)
- [Evidence Ledger](#evidence-ledger)
- [Confidence](#confidence)
- [What this RCA does NOT claim](#what-this-rca-does-not-claim)
- [Adversarial review log](#adversarial-review-log)

---

## TL;DR — action-first standalone

**You are paged on `CPUThrottlingHigh` for `otc-container` in `eneco-vpp` (Rootly `ln2I9h`).** Here is the 60-second decision branch:

| You are… | Do this first |
|----------|---------------|
| **On phone, no VPN** | Ack the alert if not yet acked; post in `#trade-platform-on-call` asking "who acked `ln2I9h`?"; wait. The Rootly tier is Low (workspace default; see L1). Out-of-hours, this can wait for laptop. |
| **At laptop, VPN up** | Run the [3-line discriminator](#decision-card-inline-4-hypothesis-table) below, then match the output to one of four hypotheses (table inline below — no need to scroll). |
| **Inheriting from prior shift** | Find the ack thread in `#trade-platform-on-call`; read `rootly-api.sh GET /v1/alerts/ln2I9h | jq '.data.attributes.timeline'`. Resume where prior shift stopped. |

The alert was already `acknowledged` in Rootly meta as of intake — someone touched it. Confirm WHO before duplicating work.

## Decision card (inline 4-hypothesis table)

**Run** (with `oc` against the dev cluster):

```bash
# 1. Find the live pod (do NOT hardcode the suffix)
POD=$(oc -n eneco-vpp get pods -l app.kubernetes.io/instance=opentelemetry-collector \
      -o jsonpath='{.items[0].metadata.name}')

# 2. Get the CR's resources + debug-exporter config
oc -n eneco-vpp get OpenTelemetryCollector opentelemetry-collector -o yaml \
  | yq '{resources: .spec.resources, debug: .spec.config.exporters.debug,
         pipelines: .spec.config.service.pipelines}'

# 3. Get the live pod's effective limits + current CPU/memory use
oc -n eneco-vpp adm top pod "$POD" --containers --use-protocol-buffers
```

**Then map** (this table is the diagnosis branch; no need to scroll):

| You see in the CR/top | Hypothesis | Cheapest next action |
|------------------------|------------|----------------------|
| `debug.verbosity: detailed` AND `debug` listed in any active pipeline | **H-D** (debug verbose burns CPU) | PR to set `verbosity: basic` or drop `debug` from pipelines. Route via [handover skill](#recommended-next-action--handover). |
| `spec.resources` absent AND `top pod` shows CPU near limit during normal load | **H-A** (CPU budget too tight, possibly post-migration regression) | Need memory trend first — run [L9 H-B probe](#l9--verification) before sizing. Avoid raising CPU without that. |
| Memory `working_set_bytes` has been growing monotonically since ~May 1 (L9 H-B probe) | **H-B** (memory upstream → GC → CPU bursts) | Investigate upstream telemetry volume; do NOT raise CPU before identifying the source. |
| Same alert fires on multiple observability sidecars cluster-wide | **H-C** (upstream rule mis-calibrated for sidecars) | PR a workload-class exclusion. Most reversible if wrong. |
| **None of the above clean-match** | Diagnosis is open — escalate to [handover skill](#recommended-next-action--handover) | Do NOT recommend a fix from this data alone. |

The hypotheses are **not strictly peer** — see [L9 dependency note](#hypothesis-dependency-note). H-B can cause H-A; H-D can cause H-A; H-C is orthogonal.

## Recommended next action — handover

Per the `eneco-oncall-intake-rootly` Phase 6D rule, this incident's diagnosis path **HANDS OVER** to the sibling skill `eneco-oncall-intake-enrich` because:

- **Phase 6D criterion (3)** fires: A3-blocked claims (E8, E9, E12-equivalents) need live `oc` access this read-only intake does not have.
- **Phase 6D criterion (4)** fires: the user explicitly asked for deeper investigation via the `/rca-holistic` skill, which **encapsulates** enrich's playbook into L11/L12 — but the LIVE PROBES that resolve A3 claims still require enrich-class access.

**Entry conditions for `eneco-oncall-intake-enrich`** (run when the on-call has the relevant access):

| Confirmed hypothesis (from Decision card) | Enrich track |
|-------------------------------------------|--------------|
| H-D (debug verbose) | Locate the running CR repo (L11 Step 8 — ArgoCD `applications` probe). Open a PR to drop `verbosity: detailed`. Cheapest fix; ship first. |
| H-A (undersized CPU budget) | First run H-B memory probe to size the eventual `requests/limits` block correctly. THEN PR. Coordinate with **Platform VPP team** (owns the OTel Collector lifecycle per the migration runbook). |
| H-B (memory upstream) | This is an investigation into upstream telemetry-volume growth; involve the services emitting high-cardinality metrics. Out of scope for a same-day fix; track separately. |
| H-C (rule mis-calibrated) | PR an exclusion to the cluster's PrometheusRule for `CPUThrottlingHigh` on observability-class labels (`app.kubernetes.io/component=otel-collector` or equivalent). Coordinate with the team that owns kube-prometheus-stack chart values for this cluster. |
| None of the above | Escalate to `#trade-platform-on-call` with the discriminator output attached; do not recommend a fix. |

The RCA itself does NOT ship a PR, a threshold change, or a runtime mutation — the deliverable at the named path is the on-call's mental model + the discriminating-probe playbook. The fix track lives downstream in enrich.

---

## Context Ledger

> Every acronym, service, repo, and platform mechanism referenced below has a row here. Read this before L1 if any name is unfamiliar.

| Item | Plain-language meaning | Source / Confidence | Why it matters here |
|------|-------------------------|----------------------|---------------------|
| **Trade Platform** | Eneco's electricity-trading operational platform; runs day-ahead/intraday market participation, balancing, and dispatch | A2 — sibling repo at `enecomanagedcloud/trade-platform/` confirms team ownership | The OTel Collector under stress is THIS platform's observability sidecar |
| **VPP** | Virtual Power Plant — Eneco's product name for the aggregated flexibility platform | A2 — namespace `eneco-vpp` literal | Encoded in cluster + namespace names |
| **MFRR** | Manual Frequency Restoration Reserve — TSO balancing service Trade Platform participates in | A2 — sibling RCA `2026_04_21_stefan_vpp_infrastructure_mfrr/` | Tells you the trading product class; Collector emits telemetry from these workloads |
| **OpenTelemetry Collector** | Open-source telemetry pipeline that receives OTLP traces/metrics/logs, batches them, and exports to one or more backends | A1 — upstream docs at https://opentelemetry.io/docs/collector/ | The pod being CPU-throttled |
| **otc-container** | The hardcoded container name the **OpenTelemetry Operator** uses inside every Deployment/StatefulSet it creates from an `OpenTelemetryCollector` CR | A2 — operator convention; cross-checked against payload `container: otc-container` | Confirms operator-managed, NOT raw Helm-chart Deployment |
| **CR (Custom Resource)** | Kubernetes object defined by a CRD; here `apiVersion: opentelemetry.io/v1beta1, kind: OpenTelemetryCollector` | A1 — observed in multiple manifests | The declarative source for the deployment |
| **eneco-vpp namespace** | OpenShift namespace where Trade Platform application workloads run on the dev cluster | A1 — alert payload `namespace: eneco-vpp` | This is the namespace under stress |
| **eneco-vpp-telemetry namespace** | DIFFERENT namespace hosting the Dynatrace-exporting OTel Collector | A2 — `platform-gitops/opentelemetry-collector/overlays/cmc-eneco-vpp-dev/namespaces/eneco-vpp-telemetry/kustomization.yaml` | The migration runbook is about THIS namespace, not the one that fired the alert |
| **CFS throttling** | Linux Completely Fair Scheduler pauses a container that hits its CPU quota until the next 100-ms scheduling period | A1 — Linux kernel docs | The alert measures throttled CFS periods over a 5-min window |
| **kube-prometheus-stack** | Community Helm chart bundling Prometheus Operator, Grafana, Alertmanager, and default PrometheusRules — including `CPUThrottlingHigh` | A1 — `VPP.GitOps/feature-branch-environments-monitoring-stack/chart/Chart.yaml:33` dependency declaration | The 25% threshold is the chart's default value |
| **OpenTelemetry Operator** | Kubernetes operator reconciling `OpenTelemetryCollector` CRs into Deployments/StatefulSets/DaemonSets; hardcodes container name to `otc-container` | A2 — operator convention | Container resources can come from CR spec OR operator default OR namespace LimitRange |
| **AlertmanagerConfig** | OpenShift/Prometheus-Operator CR that scopes Alertmanager routes/receivers per namespace; here `eneco-vpp/alertmanagerconfig/rootly-trade-platform` | A2 — referenced by `receiver` field in alert payload; the CR itself NOT probed live | The team's actual calibration of WHERE alerts go (not their severity) |
| **Rootly** | The on-call / alerting platform Eneco uses; receives Alertmanager webhooks, routes to escalation policies | A1 — `rootly-alert-meta.json` | The platform that emitted the page |
| **enecotfvppmclogindev** | Project memory alias for read-only Azure CLI login to dev MC environment | A2 — `MEMORY.md` project section | NOT used for OpenShift `oc` login; mentioned to avoid confusion |

---

## L1 — Business / Functional

> **Anchor question**: Why does an OTel Collector for Trade Platform's dev cluster matter to me right now?

**Trade Platform** is Eneco's electricity-trading operational system — day-ahead, intraday, balancing, MFRR/aFRR activations, and dispatch to the aggregated VPP. Its applications produce **telemetry** that needs to reach Prometheus (for alert rules + Grafana dashboards), Dynatrace (for APM in higher environments), and stdout (debug log streams). The **OpenTelemetry Collector** in namespace `eneco-vpp` is the pipeline that ingests OTLP-format telemetry from those applications and fans it out. When this Collector is degraded, dashboards develop gaps, traces get dropped, and downstream alert rules may fire on missing data.

The alert that paged you ([Rootly `ln2I9h`](../antecedents/rootly-alert-raw-decoded.txt)):

```text
ALERT:        CPUThrottlingHigh
DESCRIPTION:  49.76% throttling of CPU in namespace eneco-vpp for container
              otc-container in pod opentelemetry-collector-collector-566b6bd96-2htph
SEVERITY:     info                       # Prometheus label set by upstream rule
URGENCY:      Low                        # Rootly tier — see "What the labels mean" below
STATUS:       acknowledged (Rootly meta)
FIRED:        2026-05-11T11:45:29.281Z
CLUSTER:      apps.eneco-vpp-dev.ceap.nl
NAMESPACE:    eneco-vpp
TEAM:         trade-platform             # from PromQL group_left join, NOT from CR metadata (A2)
ESCALATION:   EscalationPolicy 1b6ee744-4aca-45ed-9d00-2d1d2b5edbfa
RUNBOOK:      https://runbooks.prometheus-operator.dev/runbooks/kubernetes/cputhrottlinghigh
```

**Note on alert status** (E1 reconciliation): the decode helper output says `STATUS: triggered` (alert is firing in Prometheus); the Rootly meta API says `status: acknowledged` (someone has ack'd the page in Rootly). These are **not contradictory** — the rule's firing state is still `triggered` while the Rootly engagement state is `acknowledged`. They are two surfaces of the alert lifecycle.

### What the labels mean (and don't)

What I have **A1 evidence** for (probed [`rootly-api.sh GET /v1/alert_urgencies`](../proofs/outputs/rootly-alert-urgencies.tsv)):

- All four urgency tiers in Eneco's Rootly tenant were created within ~1 minute of each other on 2025-11-18 (workspace seeding).
- Tiers `Critical` and `High` share **identical** description text `"Alerts that require immediate attention"` — the kind of duplication that suggests accepted defaults, not team-authored descriptions.
- All tiers have `team_id: null` — workspace-scoped, not team-customized.

What this means (A2 INFER): the tier `description` field looks like accepted workspace defaults. The team probably did not author "Alerts that can be addressed in due course" — it appears to be Rootly's default text for the Low tier.

What the team HAS calibrated (A2 INFER from the alert payload's `receiver` and `groupKey` fields; the actual `AlertmanagerConfig` CR was NOT probed live in this intake): the routing — `eneco-vpp/alertmanagerconfig/rootly-trade-platform` directs this rule to the Rootly group `trade-platform-on-call` with `alerts_email_enabled: false` and `alert_broadcast_enabled: false`. That maps to **Slack-notify the on-call channel, do not page out-of-hours**.

> **Read once**: urgency label is workspace config (likely defaults). Team calibration is the routing config. The "is this actionable?" question is answered by the rest of this RCA, not by either label.

---

## L2 — Repo system

> **Evidence labels in this section** — A1 = grep against local clones (clones dated 2025-11-18, treat as A2 for any claim about current state); A2 = inferred deployment relationships; A3 = blocked by lack of live cluster access.

> **Anchor question**: Which code/IaC components are in play, and how do they relate?

The reader should walk away knowing that **four candidate manifests look like sources for this pod**, and **none of them are confirmed-running** in our read-only intake — only live `oc` is authoritative.

### Repo rigor table — four candidate sources of truth

| # | Repo | Role | Tech / Artifact | Source | Deployment handoff | Incident relevance |
|---|------|------|------------------|---------|---------------------|---------------------|
| 1 | [`enecomanagedcloud/myriad-vpp/Eneco.HelmCharts/opentelemetry-collector/`](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/Eneco.HelmCharts) | **Legacy** Helm chart for the OTel Collector | Helm v3, `Chart.yaml` declares `name: opentelemetry-collector` (clone date 2025-11-18) | Local clone path | Was applied via Helm pre-migration; container name `{{ .Chart.Name }}` = `opentelemetry-collector` — **NOT** `otc-container` | **NOT the running source** — wrong container name (A2 from stale clone) |
| 2 | [`enecomanagedcloud/myriad-vpp/VPP.GitOps/feature-branch-environments-monitoring-stack/chart/templates/opentelemetry-collector.yaml`](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/VPP.GitOps) | **Feature-branch environments** monitoring stack | Helm chart embedding kube-prometheus-stack as subchart + an `OpenTelemetryCollector` CR named `opentelemetry-collector` | Local clone path | Applied per-FBE via active-environments list (`jupiter, ionix, afi, kidu, voltex, thor`) | **NOT the running source** — `eneco-vpp` is not in active-environments list (A2 from stale clone; Sherlock §0 attack) |
| 3 | [`enecomanagedcloud/myriad-vpp/platform-gitops/opentelemetry-collector/base/otel-collector.deployment.yaml`](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/platform-gitops) | Platform-managed Collector for Dynatrace export | `OpenTelemetryCollector` CR named `otel-collector-eneco-vpp-telemetry`, mode:deployment, replicas:5 | Local clone path | Applied via ArgoCD apps `otel-collector-{dev,acc,prd}.argocd.application.yaml` to namespace `eneco-vpp-telemetry` | **NOT the running source** — wrong namespace AND wrong CR name (A2 from stale clone) |
| 4 | **Unknown / unmapped** | The CR the operator reconciled into THIS pod | A3 UNVERIFIED[blocked: live cluster access required] | `oc -n eneco-vpp get OpenTelemetryCollector opentelemetry-collector -o yaml` resolves | Operator-managed; truth surface is the cluster | **THIS is the source — but we cannot read it without live access** |

The repo table tells the artifact-flow story: legacy chart → operator-managed CR pattern (migration), with the new CR sourced from a manifest that is **not in my mapped repos**. The "which file represents the running pod?" question routes through the cluster, not the local repo grep.

> **Why this matters for the diagnosis**: H-A's "(post-migration regression)" framing depends on knowing what the current CR contains. We don't, until row #4 is probed live. The legacy chart's `cpu: 256m` baseline is A2 (stale clone), not A1, so the "regression" hypothesis is informed but not established.

---

## L3 — Runtime architecture

> **Anchor question**: Which deployed pieces touch this incident?

The cluster topology:

```text
                       OpenShift dev cluster: apps.eneco-vpp-dev.ceap.nl
                       ───────────────────────────────────────────────────
       (application workloads)                         (telemetry pipelines)

       ┌─────────────────────────┐                     ┌──────────────────────────┐
       │ namespace: eneco-vpp    │                     │ namespace:               │
       │                         │  OTLP gRPC :4317    │ eneco-vpp-telemetry      │
       │  - assetplanning-*      │  OTLP HTTP  :4318   │                          │
       │  - integration-tests-*  │  ───────────────►   │  - otel-collector-       │
       │  - <other trade-plat>   │                     │    eneco-vpp-telemetry-  │
       │                         │                     │    collector-*           │
       │  - opentelemetry-       │                     │    (Dynatrace exporter,  │
       │    collector-collector- │                     │     replicas: 5)         │
       │    <RS-hash>-<suffix>   │                     │                          │
       │    container:otc-       │  THIS IS THE        └──────────────────────────┘
       │    container         ◄──┤  PAGED POD
       └─────────────────────────┘
                  │ scraped by ServiceMonitor
                  ▼
       ┌──────────────────────────────────────────┐
       │ namespace: openshift-monitoring          │
       │  kube-prometheus-stack → Prometheus      │
       │  evaluates rule CPUThrottlingHigh        │
       │  (upstream chart default threshold: 25%) │
       │  → fires Alertmanager webhook            │
       └──────────────────────────────────────────┘
                  │
                  ▼
       ┌──────────────────────────────────────────┐
       │ Rootly (SaaS)                            │
       │  alertmanagerconfig/rootly-trade-platform│
       │  → group: trade-platform                 │
       │  → escalation policy 1b6ee744-...        │
       │  → Slack: #trade-platform-on-call        │
       └──────────────────────────────────────────┘
```

Two distinct OTel Collectors run in this cluster, in different namespaces:

- **In-namespace collector** (this alert's pod): in `eneco-vpp`. CR named `opentelemetry-collector`. CR source file is **not in my mapped repos** (L2 row #4).
- **Telemetry-namespace collector**: in `eneco-vpp-telemetry`. CR named `otel-collector-eneco-vpp-telemetry`. CR at `platform-gitops/opentelemetry-collector/base/otel-collector.deployment.yaml`. The migration runbook at `enecomanagedcloud/myriad-vpp/platform-documentation/.../Runbooks/Otel-Collector-Migration.md` is about THIS namespace, not the one that fired.

**Pod naming decoder**:
`opentelemetry-collector-collector-<RS-hash>-<suffix>` =
`<CR name>` + `-collector` (added by OTel Operator for `mode: deployment`)
+ `-<ReplicaSet hash>-<pod suffix>`. The CR's `metadata.name` is exactly `opentelemetry-collector`.

**Pod-identity note** (E10 caveat): pods restart. The pod name in the original alert (`opentelemetry-collector-collector-566b6bd96-2htph`) is point-in-time; if any of the 5 alerts in 10 days triggered a restart, the ReplicaSet hash may have rolled. The L7 timeline reads alerts as "this pod" but does NOT confirm pod-instance continuity across the May 1→May 11 window. Live `oc -n eneco-vpp get events --field-selector involvedObject.kind=Pod` would discriminate.

---

## L4 — Data flow inside the Collector

> **Evidence labels in this section**: A1 = upstream Collector docs (https://opentelemetry.io/docs/collector/internal-telemetry/); A2 = inference about CPU/memory paths from those docs + Eneco's CR config.

> **Anchor question**: What does the failing code actually do?

The OTel Collector is an in-memory pipeline:

```text
   ┌──────────────────┐    ┌────────────────────┐    ┌───────────────────────────┐
   │  Receivers       │    │  Processors        │    │  Exporters                │
   │  • otlp/grpc     │───►│  • batch           │───►│  • debug   (stdout!)      │
   │    :4317         │    │    (groups items   │    │    verbosity may be       │
   │  • otlp/http     │    │     before export) │    │    "detailed" — A3 until  │
   │    :4318         │    │                    │    │    live CR is read        │
   │                  │    │                    │    │                           │
   │                  │    │                    │    │  • prometheus :8889       │
   │                  │    │                    │    │    (scrape endpoint)      │
   │                  │    │                    │    │  • otlphttp ? (Dynatrace) │
   └──────────────────┘    └────────────────────┘    └───────────────────────────┘
```

**CFS throttling primer**: a Linux container with `cpu` cgroup limit `X cores` gets `X × 100ms` of CPU time per 100-ms scheduling period; once spent, the kernel pauses it until the next period. The PromQL in the alert measures the throttled fraction over 5 min:

```promql
( increase(container_cpu_cfs_throttled_periods_total{...}[5m])
  / increase(container_cpu_cfs_periods_total{...}[5m])
  > 0.25 )
```

Derived from the alert payload's `data.alerts[0].generatorURL` ([`antecedents/rootly-alert-payload.json`](../antecedents/rootly-alert-payload.json)).

**Where CPU time goes in this pipeline** (A2 from upstream Collector docs):

- OTLP receivers: protobuf decode. CPU scales with payload size × rate.
- Batch processor: timer-driven flush. CPU spikes at flush boundaries.
- **debug exporter** with `verbosity: detailed`: prints every span/metric/log to stdout via stdlib formatting. CPU scales linearly with telemetry rate; well-known anti-pattern in production. (See [H-D](#h-d--debug-exporter-verbose).)
- prometheus exporter: maintains an in-memory metric registry; CPU spikes when registry is GC'd or on scrape (every 30s).

For an observability sidecar, sustained 50% throttled periods means one or more of: (a) the limit is too tight for steady-state workload, (b) steady-state workload is anomalously elevated, (c) a CPU-heavy exporter is active. **Memory pressure can also cause this** via GC: a Go runtime (the Collector is in Go) running near its memory limit performs frequent GC cycles, and each GC cycle is CPU-intensive. **So memory pressure can drive CFS throttling even when the workload itself is steady.** This couples H-A and H-B (see [hypothesis dependency note](#hypothesis-dependency-note) in L9).

---

## L5 — IaC / Declarative contract

> **Evidence labels in this section** — A1 reserved for live-probe outputs (none in this intake); A2 = inference from stale clones; A3 = blocked.

> **Anchor question**: What does the spec say should exist?
> **This section is the most easily mis-read** — read carefully.

Three places could set the container's CPU limit:

| Source | Lives in | Authoritative? | Live-probe to confirm |
|--------|----------|-----------------|------------------------|
| `OpenTelemetryCollector.spec.resources` (CR) | Repo (4), unmapped locally | **YES — if set** | `oc -n eneco-vpp get OpenTelemetryCollector opentelemetry-collector -o jsonpath='{.spec.resources}'` |
| **OTel Operator default** (when CR omits resources) | Operator manager config | YES — fallback | `oc -n opentelemetry-operator-system get deploy opentelemetry-operator-controller-manager -o yaml \| grep -A5 resources` |
| **Namespace LimitRange** | `eneco-vpp` ns | YES — if set; can override/be overridden | `oc -n eneco-vpp get limitrange -o yaml` |

**Pre-migration baseline (historical reference, A2 from stale local clone — NOT confirmed for current state)**:

The legacy `Eneco.HelmCharts/opentelemetry-collector` chart at `values.yaml:220-223` (clone date 2025-11-18) declares:

```yaml
resources:
  limits:
    cpu: 256m
    memory: 1Gi
```

No `requests:` block in the chart values, meaning the Helm chart's pod ran with effective requests = limits (Kubernetes default).

**The "post-migration regression" hypothesis** (H-A's plausibility framing — currently A3 UNVERIFIED): IF the running CR (repo row 4) omits `spec.resources` AND no namespace LimitRange compensates, THEN the migration left the Collector without explicit budget. This hypothesis is consistent with Socrates F3.3 but **cannot be confirmed without the live probe**. Treat H-A's "(suspected, unverified)" annotation in [L9](#l9--verification) as load-bearing.

**On verbose debug in the CR pattern**: the FBE chart's CR (repo row 2) has `debug: { verbosity: detailed }` on line 21 of its template. Since that CR is NOT the running source, but is a **template Eneco authored**, the unmapped CR (row 4) MAY follow the same pattern. H-D depends on this and is A3 until probed.

---

## L6 — Pipeline / Delivery

> **Evidence labels in this section**: A2 = inference from clone-grep; A3 = blocked.

> **Anchor question**: How does spec become runtime (or fail to)?

GitOps via ArgoCD is the cluster's standard delivery pattern (`enecomanagedcloud/myriad-vpp/VPP.GitOps/argocd/` directory in the local clone). Known ArgoCD apps managing OTel Collectors:

- `platform-gitops/opentelemetry-collector/argo-cd/otel-collector-{dev,acc,prd}.argocd.application.yaml` — manages the `eneco-vpp-telemetry` Collector (NOT this alert's pod).
- The application that manages the `eneco-vpp` namespace's Collector is **A3 UNVERIFIED** — not visible in my mapped IaC. Either in a different ArgoCD app, or applied by a separate operator/CR-source not in my clones, or applied imperatively.

**Implication for any fix**: locating the GitOps app that owns the CR is a prerequisite to shipping a change. [L11 Step 8](#l11-step-8) is the probe.

---

## L7 — Timeline

> **Anchor question**: What happened, when?
> **Read the timeline as a trend, not as a single event.**

| # | Time (UTC) | Event | Short ID | Evidence |
|---|-----------|-------|----------|----------|
| 1 | 2026-05-01 14:06 | ContainerMemoryUsageHigh on pod tagged `opentelemetry-collector-collector-*` | `XLXtEC` | [`proofs/outputs/rootly-otc-container-history.tsv`](../proofs/outputs/rootly-otc-container-history.tsv) |
| 2 | 2026-05-01 14:25 | ContainerMemoryUsageHigh — 19 min after #1 | `feuam6` | same |
| 3 | 2026-05-04 08:47 | ContainerMemoryUsageHigh — 3 days later | `imhh5o` | same |
| 4 | **2026-05-11 11:45:29Z** | **CPUThrottlingHigh — TODAY (ln2I9h)** | `ln2I9h` | [`antecedents/rootly-alert-payload.json`](../antecedents/rootly-alert-payload.json) |
| 5 | 2026-05-11 11:59:16Z | ContainerMemoryUsageHigh — 14 min after CPU alert | `dIazbf` | rootly-otc-container-history.tsv |
| 6 | (between #4 and intake) | Someone acknowledged `ln2I9h` in Rootly | — | [`antecedents/rootly-alert-meta.json`](../antecedents/rootly-alert-meta.json) `status: acknowledged` — who/when not surfaced; L11 Step 1.5 is the probe |

**Pod-identity continuity assumption** (E10 caveat): the timeline reads alerts 1-5 as "same pod" because the labels in the Rootly payload all reference the pod-name template `opentelemetry-collector-collector-*`. The five entries do NOT share the exact same ReplicaSet hash — some entries have `?` for pod (the alertmanager grouping dropped the full pod label). The continuity of "this is one pod's failure trend" vs "the Deployment's pods failing repeatedly" is A2; only `oc get events` for the eneco-vpp namespace over the May 1→May 11 window can confirm whether ReplicaSets rolled.

**Trend reading**: even with the pod-continuity caveat, the same Deployment has fired memory alerts 4× in 10 days plus today's CPU+memory pair. Whether it's "one pod degrading" or "the Deployment's replica is degrading repeatedly," the system is on an escalating curve — not at a single threshold crossing.

**Causal direction is OPEN.** Three readings of the same data are consistent — see [L9](#l9--verification) hypothesis dependency note.

---

## L8 — Fix — observation only, no prescription

> **Anchor question**: What changes, what doesn't, why?

**No fix ships with this RCA.** The discriminating probes in [L9](#l9--verification) must run first; four competing hypotheses imply four different fixes. Recommending one before discrimination ships the wrong fix and masks the real cause.

**What would change under each hypothesis** (descriptive only):

| Hypothesis | Fix shape | Sizing input | What it does NOT fix |
|------------|-----------|--------------|----------------------|
| H-A (suspected undersized CPU) | Add `spec.resources` to the CR with explicit `limits` + `requests` | **Peak CPU usage from `oc adm top pod` over a sustained window** (see [L12 §3](#l12--on-call-one-pager)), NOT the memory probe — sizing CPU off memory data was wrong in my draft. | If H-B is the upstream cause, raising CPU just delays the memory alert. |
| H-B (memory upstream) | Investigate the Collector's heap; tune `memory_limiter` processor; raise memory limit; OR find upstream services emitting too many high-cardinality metrics | Memory time series + per-service metric cardinality from Prometheus | CPU throttling will continue if memory wasn't actually upstream. |
| H-C (rule mis-calibrated for sidecar) | Add exclusion to the kube-prometheus-stack `PrometheusRule` for observability-class containers (label `app.kubernetes.io/component=otel-collector` or similar) | Cluster-wide firing rate of this rule by container-class | If real pressure exists, the alert just stops paging; pressure continues. **Most reversible fix.** |
| H-D (debug verbosity) | Change `spec.config.exporters.debug.verbosity` from `detailed` → `basic`, or remove `debug` from the active metrics pipeline | None — config flip | None — if D is the cause, cheapest fix; if D is not active, no harm done. |

**What this RCA does NOT change**: no PR is shipped; no threshold is recommended; no runtime mutation is performed.

**What this RCA DOES install**: the next-shift on-call's mental model. After reading, the on-call runs the discriminator BEFORE recommending a fix. That sequencing is the correct first action.

---

## L9 — Verification

> **Anchor question**: How would we know which diagnosis is right?

### Hypothesis dependency note

Before adjudicating the four hypotheses, the reader should know they are **NOT all peers**:

```text
H-B (memory pressure)  ─► (drives GC) ─► CPU bursts ─► CFS throttled ─► CPUThrottlingHigh fires
                                                      ▲
H-A (tight CPU limit)  ───────────────────────────────┘
                                                      ▲
H-D (debug verbose)    ─► (stdout I/O CPU draw) ──────┘

H-C (rule mis-calibrated for sidecar workload class)   ◄ orthogonal: the rule itself, not this pod
```

H-A is the SYMPTOM ("CPU pressure exceeds limit"); H-B and H-D are CANDIDATE UPSTREAM CAUSES. So:

- Confirming H-A alone tells you only that the pressure exceeded the limit; it does NOT tell you WHY.
- Confirming H-B (memory monotonic growth) and H-A together: H-B is the upstream; raising CPU without fixing memory just delays the next memory alert.
- Confirming H-D and H-A together: H-D is upstream; fixing the debug config is cheapest.
- H-C is orthogonal: if the rule itself is mis-calibrated for sidecar workload class cluster-wide, this pod's pressure may be normal-for-sidecars and the alert is the issue.

**Adjudication heuristic**: run all four probes; if H-D confirms, ship the debug fix first (cheapest, most reversible). If H-B confirms with H-A, do not raise CPU until memory is understood. If H-C confirms cluster-wide, the rule itself is the actionable issue.

### Per-hypothesis probes

#### H-A — Suspected undersized CPU budget (regression vs. legacy chart suspected, unverified)

**Probe**:

```bash
# Step 1: find live pod (do not hardcode)
POD=$(oc -n eneco-vpp get pods -l app.kubernetes.io/instance=opentelemetry-collector \
      -o jsonpath='{.items[0].metadata.name}')

# Step 2: read the CR's resources
oc -n eneco-vpp get OpenTelemetryCollector opentelemetry-collector -o yaml \
  | yq '.spec.resources'

# Step 3: read the pod's effective limits + recent events
oc -n eneco-vpp describe pod "$POD" | sed -n '/Limits:/,/Requests:/p; /Events:/,$p'

# Step 4: check namespace LimitRange
oc -n eneco-vpp get limitrange -o yaml
```

- **Confirms H-A if**: CR omits `spec.resources` AND effective `cpu` limit ≤ legacy 256m baseline AND no LimitRange compensates.
- **Falsifies H-A if**: CR has `spec.resources.limits.cpu` well above measured peak, OR LimitRange provides a generous floor.

#### H-B — Memory pressure upstream

**Probe**:

```promql
# 14-day memory working-set per pod
container_memory_working_set_bytes{namespace="eneco-vpp",pod=~"opentelemetry-collector-collector-.*",container="otc-container"}

# Per-pod CPU rate to correlate with GC bursts
rate(process_cpu_seconds_total{namespace="eneco-vpp",pod=~"opentelemetry-collector-collector-.*"}[5m])
```

- **Confirms H-B if**: monotonic memory growth 2026-05-01 → 2026-05-11 AND CPU rate spikes coincident with apparent GC cycles.
- **Falsifies H-B if**: memory flat or only spiked on/around 2026-05-11.

#### H-C — Upstream rule mis-calibrated for sidecar workload

**Probe**:

```promql
# Cluster-wide firing of this rule by container class
sum by (container) ( ALERTS{alertname="CPUThrottlingHigh", alertstate="firing"} )
```

- **Confirms H-C if**: observability-class containers (otel-collectors, fluentd, prometheus exporters) systematically fire this rule cluster-wide.
- **Falsifies H-C if**: only this pod is anomalous.

#### H-D — Debug exporter verbose

**Probe**:

```bash
oc -n eneco-vpp get OpenTelemetryCollector opentelemetry-collector -o yaml \
  | yq '{exporters: .spec.config.exporters, pipelines: .spec.config.service.pipelines}'
```

- **Confirms H-D if**: `debug.verbosity: detailed` is set AND `debug` is in any active pipeline (look at `.spec.config.service.pipelines.*.exporters`).
- **Falsifies H-D if**: debug exporter `verbosity: basic` or not in any active pipeline.

---

## L10 — Lessons

> **Evidence labels in this section** — Each lesson distills a class-level pattern; the underlying A1/A2 evidence is in the Evidence Ledger.

> **Anchor question**: What durable knowledge do I keep?

Each lesson is `pattern + probe + defense`, rephrased to survive removal of incident-specific nouns (rca-holistic Phase 6 rephrase test).

1. **Routing label ≠ severity grading.** A SaaS alerting platform's tier description (Low/Medium/High/Critical) can be workspace default rather than team policy. **Probe**: query the platform's tiers API; identical descriptions across tiers or batch-created timestamps suggest defaults. **Defense**: team-level urgency calibration belongs in routing config and team runbooks, not in the alert label.

2. **Causal arrow asserted from a snapshot can be falsified by the timeline.** When an alert fires with adjacent symptoms (here, CPU and memory), don't read causal direction from which alert fires; read it from the temporal order + magnitude trend. **Probe**: enumerate all related alerts on the same target over the longest window the platform retains; the upstream cause should appear first in time AND show monotonic growth in raw metrics. **Defense**: hold both causal directions as candidates until a time-series probe (not just alert-firing-list) discriminates.

3. **Name-match is not deployment proof.** In multi-repo environments with similarly-named manifests, finding a file whose `metadata.name` matches the pod's expected source is INFER, not FACT. **Probe**: the runtime cluster's own object store (`kubectl get -o yaml`) is the only authoritative source. **Defense**: any RCA's IaC section MUST lead with the live-cluster probe; file-based diagnosis is A2 until the runtime probe confirms.

---

## L11 — Cold-start command playbook

> **Evidence labels in this section** — Steps 1-3 produce A1 evidence (Rootly API live). Steps 4-8 require live cluster access and are A3 until run.

### Preconditions (read these BEFORE any step)

| Precondition | How to satisfy |
|--------------|----------------|
| `ROOTLY_API_KEY` env var set | `export ROOTLY_API_KEY=<personal token>` — get it from Rootly user profile → API Keys |
| `~/.claude/skills/eneco-tools-rootly/scripts/` available | Skill is loaded; scripts are executable |
| `oc` CLI installed for Steps 4-8 | Install OpenShift CLI; verify `oc version` |
| Logged into the dev cluster | `oc login --server=https://api.eneco-vpp-dev.ceap.nl:6443` (use your dev-cluster IDP credentials) |
| Bearer token for Thanos queries (Steps 6, 7) | `OCP_TOKEN=$(oc whoami -t)` then pass as `-H "Authorization: Bearer $OCP_TOKEN"` |

> The project-memory alias `enecotfvppmclogindev` is for **Azure CLI** read-only login to the Azure dev MC environment — it does NOT log you into OpenShift. Don't conflate.

### Step 1 — Identify the alert (Rootly-side)

**Question**: What alert was I paged on, and what's its current Rootly state?

**Why this API**: Rootly v1 `/alerts/{short_id}` is the source of truth for the page you received. No other surface has the routing, urgency tier, AND canonical `data` payload in one fetch.

**Fields selected**: `attributes.summary`, `attributes.status`, `attributes.alert_urgency`, `attributes.data.commonLabels.{namespace,pod,container}`, `attributes.data.alerts[0].generatorURL`.

**Expected output**: JSON document; for `ln2I9h`, status `acknowledged`, urgency `Low`, container `otc-container`, generatorURL contains the PromQL query of the firing rule.

**Decision rule**: if status is `triggered` AND no Rootly engagement timeline entry, you are first responder. If `acknowledged`, someone is on it — go to Step 1.5 to find them.

**Principle**: the platform that emitted the page owns the canonical state; do not start with the runbook URL or the Slack thread.

```bash
~/.claude/skills/eneco-tools-rootly/scripts/rootly-alert-decode.sh --short-id ln2I9h
```

### Step 1.5 — Who acknowledged this alert?

**Question**: If status is `acknowledged`, who acked, when, and what did they say?

**Why this API**: Rootly v1 `/alerts/{id}/timeline` exposes engagement events. Without it, the next-shift duplicates work.

**Fields selected**: `engagement_events[].{type, user, created_at, note}`.

**Expected output**: a list of events; look for `type: acknowledged` or `commented`.

**Decision rule**: if there's an ack thread from a teammate, coordinate via Slack before running discriminators. If you don't find an engagement event, the `acknowledged` flag may have been set via a different surface — post in `#trade-platform-on-call` asking who acked.

**Principle**: state changes have provenance; the engagement timeline carries it.

```bash
~/.claude/skills/eneco-tools-rootly/scripts/rootly-api.sh GET "/v1/alerts/ln2I9h/timeline" \
  | jq -r '.data[] | [.attributes.created_at, .attributes.type, (.attributes.user.full_name // "?"), (.attributes.note // "")] | @tsv'
```

(If `/timeline` is not the correct endpoint name in this Rootly API version, fall back to `~/.claude/skills/eneco-tools-rootly/scripts/rootly-api.sh GET "/v1/alerts/ln2I9h"` and inspect `engagement_events` in the attributes.)

### Step 2 — Establish pattern intelligence (Rootly history)

**Question**: Is this rule recurring? On which targets?

**Why this API**: Rootly v1 `/alerts?filter[search]=<rulename>` history is the same source's history view; more reliable than reconstructing from Slack.

**Fields selected**: `short_id, created_at, status, namespace, container` per row.

**Expected output**: rows summarizing recent firings.

**Decision rule**: if ≥10 firings in last 30 days on this namespace, rule is "known noisy here." **Pagination guard**: if `wc -l` of output equals `page_size`, increase page size or paginate — the count is likely truncated.

**Principle**: novelty is multi-dimensional (rule × target × time); classify all three.

```bash
PAGE=50
N=$(~/.claude/skills/eneco-tools-rootly/scripts/rootly-api.sh GET \
    "/v1/alerts?filter[search]=CPUThrottlingHigh&page[size]=${PAGE}" \
    | jq -r '.data[] | [.attributes.short_id, .attributes.created_at, .attributes.status, (.attributes.data.commonLabels.namespace // "?"), (.attributes.data.commonLabels.container // "?")] | @tsv' \
    | tee /tmp/cputhrot-30d.tsv | wc -l)

[ "$N" -eq "$PAGE" ] && echo "WARN: result count == page size; raise page or paginate" >&2
```

### Step 3 — Pod-level history (Rootly cross-rule)

**Question**: What other alerts has this same pod fired?

**Why this API**: same `/alerts` endpoint, filter by pod identifier; reveals multi-rule trends.

**Fields selected**: `short_id, created_at, summary`.

**Expected output**: ≤20 rows, one per alert this pod fired across all rule names. Columns: short_id (Rootly ID), created_at (UTC), summary (the rule's title — e.g., `CPUThrottlingHigh`, `ContainerMemoryUsageHigh`).

**Decision rule**: if ≥3 alerts on different rules in last 14 days → sustained multi-rule trend; escalate beyond a single-firing fix.

**Principle**: cross-rule history on the same target surfaces trend signals single-rule history misses.

```bash
~/.claude/skills/eneco-tools-rootly/scripts/rootly-api.sh GET \
  "/v1/alerts?filter[search]=otc-container&page[size]=20" \
  | jq -r '.data[] | [.attributes.short_id, .attributes.created_at, .attributes.summary] | @tsv'
```

### Step 4 — Identify the running CR (A3 until live access)

**Question**: Which manifest is the operator reconciling into the live pod, and what does it say about resources and debug verbosity?

**Why this API**: `oc get` against the live cluster is the only authoritative source. File-based search returns multiple candidates; local clones are 6 months stale.

**Fields selected**: `.spec.resources`, `.spec.config.exporters.debug`, `.spec.config.service.pipelines`.

**Expected output**: a YAML doc; `.spec.resources` either present or absent; `.spec.config.exporters.debug` either present with `verbosity: detailed|basic` or absent; pipelines list which exporters are active.

**Decision rule**:
- `spec.resources` absent → H-A plausibility raised; cross-check with Step 5 effective limits.
- `debug.verbosity: detailed` AND `debug` in pipelines → H-D supported.
- Both → both contribute; fix H-D first (cheaper).

**Principle**: cluster state is the truth surface; local repo clones are INFER until live-probed.

**Freshness probe**: BEFORE the read, confirm cluster identity.

```bash
oc whoami --show-server   # MUST return "https://api.eneco-vpp-dev.ceap.nl:6443" or equivalent
# If WRONG cluster: oc login --server=https://api.eneco-vpp-dev.ceap.nl:6443

oc -n eneco-vpp get OpenTelemetryCollector opentelemetry-collector -o yaml \
  | yq '{resources: .spec.resources, debug: .spec.config.exporters.debug, pipelines: .spec.config.service.pipelines}'
```

### Step 5 — Describe the pod (effective limits + recent events)

**Question**: What CPU/memory limits are ACTUALLY in effect (post-admission), and has the pod restarted or been OOMKilled?

**Why this API**: `oc describe pod` shows the COMPUTED resource block (kernel cgroup settings post-admission) plus recent events. Strictly more authoritative than the CR alone.

**Fields selected**: `Limits:`, `Requests:`, `Events:` sections.

**Expected output**: a long block; the relevant lines are under `Containers: otc-container: Limits:` and `Containers: otc-container: Requests:`, plus an `Events:` table at the bottom.

**Decision rule**: compare `Limits.cpu` against observed peak usage from `oc adm top pod` (also Step 5 below). Limit / peak < 2 → tight envelope; collector is sensitive to bursts.

**Principle**: post-admission pod spec is the truth surface for what the kernel enforces; the CR is intent.

```bash
# Use label selector, not hardcoded pod name (pods restart)
POD=$(oc -n eneco-vpp get pods -l app.kubernetes.io/instance=opentelemetry-collector \
      -o jsonpath='{.items[0].metadata.name}')

oc -n eneco-vpp describe pod "$POD"
# Look for: Limits:, Requests:, Events:

# CPU usage during steady-state and bursts
oc -n eneco-vpp adm top pod "$POD" --containers --use-protocol-buffers
```

### Step 6 — Memory time series (discriminate H-B)

**Question**: Is memory growing monotonically over 14 days, or only spiking today?

**Why this API**: Prometheus is the source of truth for resource time series. Grafana dashboards are presentation; in-cluster Prometheus has the raw data. Authenticate with the OpenShift token to bypass the SSO redirect.

**Fields selected**: `container_memory_working_set_bytes` over a 14d range, grouped by pod.

**Expected output**: a JSON range-vector with `values` arrays per pod.

**Decision rule**: monotonic growth → H-B supported (memory upstream). Flat-until-today → H-A or H-D more likely.

**Principle**: trend > single-point; time series > alert-firing-list for causal direction.

```bash
OCP_TOKEN=$(oc whoami -t)
THANOS=https://thanos-querier-openshift-monitoring.apps.eneco-vpp-dev.ceap.nl

curl -sG \
  -H "Authorization: Bearer $OCP_TOKEN" \
  --data-urlencode 'query=container_memory_working_set_bytes{namespace="eneco-vpp",pod=~"opentelemetry-collector-collector-.*",container="otc-container"}' \
  --data-urlencode "start=$(date -u -v-14d +%FT%TZ)" \
  --data-urlencode "end=$(date -u +%FT%TZ)" \
  --data-urlencode 'step=1h' \
  "${THANOS}/api/v1/query_range"
```

### Step 7 — Cross-cluster rule sanity check (discriminate H-C)

**Question**: Does this rule fire across many observability-class containers cluster-wide?

**Why this API**: Prometheus `ALERTS` synthetic metric exposes per-rule firing state with full label set.

**Decision rule**: if the rule fires on many sidecars/collectors/exporters → H-C supported.

**Principle**: a rule firing on the same workload-class across unrelated targets is suspected calibration-bug.

```bash
curl -sG \
  -H "Authorization: Bearer $OCP_TOKEN" \
  --data-urlencode 'query=sum by (container) (ALERTS{alertname="CPUThrottlingHigh",alertstate="firing"})' \
  "${THANOS}/api/v1/query"
```

### Step 8 — Locate the GitOps owner

**Question**: Which ArgoCD app manages the `eneco-vpp` namespace's OpenTelemetryCollector? Where does a fix PR land?

**Why this API**: ArgoCD `applications` CRs in the cluster are the source of truth.

**Decision rule**: find the app whose `.spec.source` points to the CR YAML — that repo+path is the PR target. If no app exists, escalate to Platform VPP (it may be applied via a separate operator).

**Principle**: in a GitOps cluster, "where does the spec live?" is in ArgoCD, not tribal memory.

```bash
# ArgoCD commonly lives in openshift-gitops; may also be argocd or gitops
oc get applications.argoproj.io -A -o json \
  | jq -r '.items[] | select(.spec.destination.namespace=="eneco-vpp") | [.metadata.namespace, .metadata.name, .spec.source.repoURL, .spec.source.path] | @tsv'

# If empty, search all namespaces / all apps for any OTel reference
oc get applications.argoproj.io -A -o json \
  | jq -r '.items[] | select(.spec.source.path | tostring | test("opentelemetry|otel")) | [.metadata.namespace, .metadata.name, .spec.destination.namespace, .spec.source.repoURL, .spec.source.path] | @tsv'
```

> Rootly-side steps (1–3) are scripted in [`proofs/scripts/replay-rootly-intake.sh`](../proofs/scripts/replay-rootly-intake.sh). Steps 4–8 require live cluster access and become A1 the moment they run.

---

## L12 — On-call one-pager

> **Evidence labels in this section** — Read these probes' outputs as A1 the moment you run them. Until then, the table-mapped hypotheses are A3.

> Paged on `CPUThrottlingHigh` for `otc-container` in `eneco-vpp`?
> Read this page; act in 5 minutes.

### 1. Triage triple — 30 seconds

| Check | Decision |
|-------|----------|
| Rootly status | `acknowledged` → coordinate via Slack first ([Step 1.5](#step-15--who-acknowledged-this-alert)) before duplicating work; `triggered` → you are first responder |
| Container label | `otc-container` → this card; otherwise different RCA |
| Namespace label | `eneco-vpp` → this card; `eneco-vpp-telemetry` → different collector, see migration runbook |

### 2. Pull history — 1 minute

| Check | Decision |
|-------|----------|
| `CPUThrottlingHigh` firings on `otc-container` in last 30 days (L11 Step 2 + 3) | ≤1 → continue; ≥2 → check `#trade-platform-on-call` for prior thread first |
| Other rules this pod has fired in last 14 days | 0 → isolated event; ≥1 memory alert → memory-CPU co-pressure ([H-B](#h-b--memory-pressure-upstream) likely); ≥3 alerts → multi-rule trend; escalate to Platform VPP |

### 3. Run the discriminator — 2 minutes (REQUIRES VPN + `oc` access)

```bash
# Verify cluster (must match dev API URL)
oc whoami --show-server
# Expected: https://api.eneco-vpp-dev.ceap.nl:6443 (or equivalent)
# If WRONG: oc login --server=https://api.eneco-vpp-dev.ceap.nl:6443

# Find live pod (do NOT hardcode the suffix)
POD=$(oc -n eneco-vpp get pods -l app.kubernetes.io/instance=opentelemetry-collector \
      -o jsonpath='{.items[0].metadata.name}')

# Get the CR + current usage
oc -n eneco-vpp get OpenTelemetryCollector opentelemetry-collector -o yaml \
  | yq '{resources: .spec.resources, debug: .spec.config.exporters.debug, pipelines: .spec.config.service.pipelines}'

oc -n eneco-vpp adm top pod "$POD" --containers --use-protocol-buffers
```

> **No VPN / on phone?** Skip Section 3. Ack the alert if needed; coordinate via `#trade-platform-on-call`. The urgency is Low (workspace default), so this can wait for laptop access during normal hours.

### 4. Map to hypothesis — 30 seconds

| You see | Hypothesis | Cheapest next action |
|---------|------------|---------------------|
| `debug.verbosity: detailed` AND `debug` in active pipeline | **H-D** | Cheapest fix — PR to set `verbosity: basic`. Locate CR via [Step 8](#step-8--locate-the-gitops-owner). |
| `spec.resources` absent + low/idle CPU on `top pod` + memory not growing | **H-A only** | Bring resource budget back, size from L11 Step 5 peak. |
| Memory monotonic growth for ≥7d (L11 Step 6) | **H-B** (probably driving H-A too) | Investigate upstream telemetry volume; do NOT raise CPU before identifying source. |
| Rule also firing on multiple other sidecars cluster-wide (L11 Step 7) | **H-C** | PR a workload-class exclusion. Most reversible. |

### 5. Escalation — 1 minute

| Situation | Action |
|-----------|--------|
| Diagnosis matches [Lesson 3](#l10--lessons) trap (name-match without live probe) | Stop. Run live probe first. |
| Multi-hypothesis (H-A + H-B together) | Escalate to **Platform VPP** team (owners of OTel Collector lifecycle per migration runbook). Post in `#myriad-platform`. Owner: Fabrizio Zavalloni (per `Otel-Collector-Migration.md`). |
| Trend looks new (no prior memory alerts on this pod) | Genuinely novel; involve **Aggregation** or **Fleet Optimizer** team (telemetry-volume sources). Owners per migration runbook: Jonhson Lobo (Aggregation) / Alexandre Borges (Fleet Optimizer). |
| Nothing actionable found | Ack-only with reasoning in the Rootly comment; do NOT silently close. |

### 6. Post-investigation

| Step | Command |
|------|---------|
| Update Rootly alert comment so next-shift inherits the work | `~/.claude/skills/eneco-tools-rootly/scripts/rootly-api.sh PATCH "/v1/alerts/ln2I9h" --data '{"data":{"type":"alerts","attributes":{"note":"<your notes>"}}}'` (verify schema with skill first if uncertain) |
| Continue investigation if a fix is needed | Invoke `eneco-oncall-intake-enrich` per the [Recommended next action](#recommended-next-action--handover) section |
| Capture lessons in this folder if pattern recurs | Append findings to `auxiliary/` |

---

## Evidence Ledger

> **Evidence labels in this section** — A1/A2/A3 as decoded at the top.

| # | Claim | Class | Probe / Source | Status |
|---|-------|-------|----------------|--------|
| E1 | Alert `ln2I9h` fired 2026-05-11T11:45:29Z with description "49.76% throttling of CPU in namespace eneco-vpp for container otc-container in pod ..." | **A1** | `rootly-alert-decode.sh --short-id ln2I9h` → [`antecedents/rootly-alert-raw-decoded.txt`](../antecedents/rootly-alert-raw-decoded.txt) | Confirmed |
| E1b | Rootly engagement status is `acknowledged`; Prom alert state is `triggered` — these are not contradictory (two surfaces of the alert lifecycle); WHO acked is A3 until L11 Step 1.5 runs | **A1 / A3** | [`antecedents/rootly-alert-meta.json`](../antecedents/rootly-alert-meta.json) status field | Confirmed (composite) |
| E2 | Rule's threshold is 25%, joined with `kube_pod_labels` for team routing | **A1** | `data.alerts[0].generatorURL` PromQL in [`antecedents/rootly-alert-payload.json`](../antecedents/rootly-alert-payload.json) | Confirmed |
| E2b | Eneco has NOT overridden the 25% threshold in any local PrometheusRule | **A2** (grep across stale local clones; live `oc get prometheusrule -A` would resolve) | clone-grep result in [`antecedents/p4-evidence-corpus.md`](../antecedents/p4-evidence-corpus.md) §2 | Unresolved at A1 |
| E3 | Rootly urgency tiers in Eneco's tenant were created in batch on 2025-11-18, all `team_id: null`, with Critical+High sharing identical descriptions — consistent with workspace defaults | **A1** | [`proofs/outputs/rootly-alert-urgencies.tsv`](../proofs/outputs/rootly-alert-urgencies.tsv) (live probe of `/v1/alert_urgencies`) | Confirmed |
| E3b | The team has NOT actively re-described these tiers (the description fields are Rootly defaults) | **A2** (inferred from E3 patterns; live diff against a fresh Rootly tenant would resolve) | E3 patterns | Plausible-not-proven |
| E4 | `CPUThrottlingHigh` fired 30× in namespace `eneco-vpp` in last 30 days — 27× on `assetplanning`, 2× on `integration-tests`, 1× (today) on `otc-container`; pagination at page_size=30 may truncate | **A1** | [`proofs/outputs/rootly-cputhrottlinghigh-30d-history.tsv`](../proofs/outputs/rootly-cputhrottlinghigh-30d-history.tsv) | Confirmed; pagination caveat noted |
| E5 | The Deployment behind `opentelemetry-collector-collector-*` fired 4× `ContainerMemoryUsageHigh` since 2026-05-01 + 1× today (14 min after CPU alert) | **A1 for the Deployment-level trend** / **A2 for "same pod instance"** (pod-identity continuity across May 1→May 11 not probed; ReplicaSet rolls would alias the suffix) | [`proofs/outputs/rootly-otc-container-history.tsv`](../proofs/outputs/rootly-otc-container-history.tsv) | Confirmed at Deployment level |
| E6 | Pod naming `<crname>-collector-<RS-hash>-<suffix>` is OTel Operator convention; container name `otc-container` is hardcoded by operator | **A2** | Operator convention; cross-checked with payload `container: otc-container` | Inferred but consistent |
| E7 | Pre-migration `Eneco.HelmCharts/opentelemetry-collector` had `cpu: 256m, memory: 1Gi` | **A2** (stale clone — clone date 2025-11-18; chart-freeze NOT confirmed) | `values.yaml:220-223` in stale local clone | Plausible historical baseline, not current-state |
| E8 | The CR currently reconciled into the running pod has NOT been read in this session | **A3[blocked: live cluster access not authorized in read-only intake]** | Live probe at [L11 Step 4](#step-4--identify-the-running-cr-a3-until-live-access) resolves | Unresolved |
| E9 | The FBE chart CR at `feature-branch-environments-monitoring-stack/chart/templates/opentelemetry-collector.yaml` is the running source for this pod | **A3[blocked: name-match is not deployment proof; FBE active-environments do not include eneco-vpp]** | Live probe E8 resolves | Inverted from initial corpus claim (Sherlock §0) |
| E10 | Causal arrow `CPU → memory` is established | **A3[blocked: temporal evidence + L4 mechanism both admit reverse direction; only Prometheus working-set time series discriminates]** | L9 H-B probe resolves | Inverted from initial corpus claim |
| E11 | Rootly's Low-tier description is "team-calibrated 'address in due course'" | **A2 → workspace default, not team-authored** (per E3 + E3b) | Live diff against fresh Rootly tenant would fully prove | Demoted from corpus claim |
| E12 | AlertmanagerConfig CR `eneco-vpp/alertmanagerconfig/rootly-trade-platform` routes this rule | **A2** (referenced by the alert payload's `receiver` and `groupKey` fields; the actual CR not probed live) | `oc get alertmanagerconfig -n eneco-vpp rootly-trade-platform -o yaml` resolves | Plausible, not directly probed |

> **Note on routing verdict**: the Phase 6D HANDOVER decision is documented in the [Recommended next action](#recommended-next-action--handover) section, not in the Evidence Ledger — it's a routing meta-decision, not a probeable evidence claim, per Socrates Check 1c.

---

## Confidence

Per rca-holistic Rule X12 confidence formula (recomputed after Evidence Ledger corrections):

```text
A1_confirmed   = 5  (E1, E1b A1-portion, E2, E3, E4)
A2_infer       = 5  (E2b, E3b, E5 A2-portion, E6, E7, E12 — note E11 also A2 conceptually; rounded)
A3_blocked     = 4  (E1b A3-portion, E8, E9, E10)
contradictions_open = 0  (the corpus inversions ARE the resolution path, not unresolved contradictions)

confidence = 5 / (5 + 5 + 4 + 0) = 5/14 ≈ 0.36
```

**0.36 is honestly low** — and it should be. The diagnosis is contested by design; four hypotheses fit the evidence. The fastest way to raise confidence is the **single discriminator probe at L11 Step 4** (`oc -n eneco-vpp get OpenTelemetryCollector opentelemetry-collector -o yaml`) — that one 2-second command resolves E8, E9, and the H-A vs H-D question, jumping confidence to ~0.6.

**What would lower it further**: discovering the live CR is owned by an operator/repo not in my mapped IaC (E12 also unresolved); OR finding pod-identity continuity broke during May 1→May 11 (E5 A2-portion not the same pod's failure mode).

**What CANNOT raise this without a live probe**: anything about the running CR's spec, effective CPU limit, exact telemetry volume, or who acknowledged.

> `status: review` is the correct front-matter. Promotion to `status: complete` would require executing the [handover](#recommended-next-action--handover) probes and resolving E8/E9/E10 with A1 evidence — which is the enrich track's job, not this RCA's.

---

## What this RCA does NOT claim

To prevent over-reads of this artifact:

- **Not "the team mishandles low-severity alerts."** The team's routing (Slack-notify, not pager-out) is reasonable for the rule's calibration; what we observed is that the alert's metric VALUE (49.76%) + the 10-day pattern is a separate signal that the LABEL doesn't capture. That's a calibration question to surface, not a process failure.
- **Not "the Collector is misconfigured."** Until [L11 Step 4](#step-4--identify-the-running-cr-a3-until-live-access) runs, we don't know what the CR contains.
- **Not "the migration introduced a regression."** That's a SUSPECTED hypothesis (H-A), informed by the legacy chart's baseline but unverified against current state.
- **Not "the threshold should change."** We observed the threshold is the kube-prometheus-stack default (25%). The decision to keep, raise, or exclude is the team's, made WITH the discriminator output, NOT from this RCA alone.

---

## Adversarial review log

### Pre-RCA dispatches (input attack — DONE)

| Subagent | Win condition | Artifact | Outcome |
|----------|--------------|----------|---------|
| `sherlock-holmes` | Show a competing diagnosis the corpus admits | [`antecedents/sherlock-diagnosis-attack.md`](../antecedents/sherlock-diagnosis-attack.md) | PROBLEMATIC: 5 findings — file-source wrong; D-ALT-A and D-ALT-C produced; local clones 6mo stale |
| `socrates-contrarian` | Find framing imports / hidden premises | [`antecedents/socrates-framing-attack.md`](../antecedents/socrates-framing-attack.md) | PROBLEMATIC: 9 faults, 4 critical (F6 TERMINAL→HANDOVER, F1.3 causal direction, F3.3 migration regression, F2.1 vendor stock copy) |

### Post-draft dispatches (artifact attack — DONE)

| Subagent | Win condition | Artifact | Outcome |
|----------|--------------|----------|---------|
| `socrates-contrarian` (fresh) | Find A1-that-should-be-A2; cross-section incoherence; rationalization survivors | [`auxiliary/socrates-post-draft-attack.md`](../auxiliary/socrates-post-draft-attack.md) | PROCEED-WITH-CHANGES: 12 must-fix; strongest = Check 6 HANDOVER rhetorical-only |
| `el-demoledor` | Break the RCA on reader pressure, evidence chain, structural coherence, playbook reproducibility, claim honesty | [`auxiliary/el-demoledor-post-draft-attack.md`](../auxiliary/el-demoledor-post-draft-attack.md) | DELAY-AND-FIX: 19 breaks (4 CRITICAL, 8 HIGH, 7 MEDIUM); strongest = S3-V1 scratchpad in published RCA, S1-V1 TL;DR forward-reference, S2-V3 unprobed "vendor stock" claim |

### Absorption map (which finding → where in THIS revision)

| Finding | Absorbed in this revision |
|---------|---------------------------|
| Socrates Check 1a (E1 triggered/acknowledged) | E1b row reconciles as composite lifecycle states |
| Socrates Check 1b (E6 class/math mismatch) | Confidence formula recomputed; E6 now correctly in A2_infer |
| Socrates Check 1c (E12 routing verdict not A3 claim) | Phase 6D verdict moved to its own section; removed from confidence accounting |
| Socrates Check 2a (L8 H-A cross-ref wrong) | L8 H-A now points at L11 Step 5 (top pod CPU), not the memory probe |
| Socrates Check 2b/9 (hypothesis nesting) | New "Hypothesis dependency note" in L9 with diagram and adjudication heuristic |
| Socrates Check 2c / Check 5 (hardcoded pod name) | L11 Step 5 + Decision card + L12 all use `oc get pods -l app.kubernetes.io/instance=...` label selector |
| Socrates Check 4a (Eneco-not-overridden A1 → A2) | E2b explicitly A2 in Evidence Ledger |
| Socrates Check 4b (E7 stale clone) | E7 now A2 with "stale clone" + "chart-freeze not confirmed" caveat |
| Socrates Check 5 (pagination) | L11 Step 2 has pagination guard |
| Socrates Check 5 (Step 4 wrong-cluster handling) | L11 preconditions section + Step 4 freshness probe |
| Socrates Check 5 (Step 6/7 auth) | L11 preconditions section + `OCP_TOKEN` in Steps 6/7 |
| Socrates Check 6 (HANDOVER rhetorical only) | New "Recommended next action — handover" section names `eneco-oncall-intake-enrich` explicitly with entry-condition table; frontmatter `mode: HANDOVER` |
| Socrates Check 7 (selective staleness) | E7 demoted to A2; L2 row #1, #2 carry stale-clone qualifier; E2b documented |
| Socrates Check 8 (H-A label) | H-A renamed to "Suspected undersized CPU budget (regression vs. legacy chart suspected, unverified)" |
| Socrates Check 9 (peer vs nested) | L9 dependency diagram + adjudication heuristic |
| Socrates Check 10 (L12 escalation owners) | L12 §5 names Platform VPP + owners from migration runbook |
| Socrates X1 (sorry-wrong-path artifact) | Removed from L3 |
| Socrates X2 (AlertmanagerConfig A1 → A2) | E12 explicitly A2 |
| Socrates X3 (who-acked probe) | L11 Step 1.5 added |
| Socrates Check 10d (update-Rootly-comment command) | L12 §6 names the `rootly-api.sh PATCH` command |
| El-Demoledor S1-V1 (TL;DR forward-reference) | TL;DR rewritten action-first; Decision card inline with the 4-hypothesis table |
| El-Demoledor S1-V2 (L12 phone-actionable branch) | TL;DR has 3-branch "you are…" table including "on phone" branch |
| El-Demoledor S1-V3 (TL;DR sermons) | Sermon material moved to L1; TL;DR is action-first |
| El-Demoledor S2-V1 (E10 pod-identity continuity) | L7 and Evidence Ledger E5 both carry the pod-continuity caveat |
| El-Demoledor S2-V3 (unprobed vendor-stock claim) | `/v1/alert_urgencies` probe RAN; results in [`proofs/outputs/rootly-alert-urgencies.tsv`](../proofs/outputs/rootly-alert-urgencies.tsv); E3 + E3b now carry the probe-backed framing |
| El-Demoledor S2-V6 + S5-V2 (confidence formula errors) | Recomputed; E6 in A2, E12 removed from accounting; new total = 0.36 |
| El-Demoledor S3-V1 (sorry-wrong-path) | Removed |
| El-Demoledor S3-V3 (routing-vs-calibration restated 7×) | Mention only in L1 + Lesson 1; removed from other sections |
| El-Demoledor S4-V1 (ROOTLY_API_KEY precondition) | L11 preconditions section |
| El-Demoledor S4-V3 (Thanos auth) | L11 preconditions + Steps 6/7 use `OCP_TOKEN` |
| El-Demoledor S4-V6 (hardcoded pod name) | Replaced with label selector throughout |
| El-Demoledor S6-V1 (gaslighting narrative risk) | New "What this RCA does NOT claim" section |
| El-Demoledor S6-V3 (1043-line RCA at 03:00) | TL;DR + Decision card + Recommended next action + L12 are all standalone-actionable; the depth is for the engineer who has 10+ minutes |

> **Verdict**: The bones survived both adversarial passes. The fixes were coherence + labeling + cold-start preconditions + a real handover section. None required new probes except `/v1/alert_urgencies`, which ran. The artifact is now ready for `status: complete` IF a third-party reviewer confirms absorption. As shipped here, `status: review` is honest pending that confirmation.
