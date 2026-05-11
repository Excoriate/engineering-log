---
task_id: 2026-05-11-003
agent: claude-code
status: pending_review
summary: P4 Context — evidence corpus from L-ROOTLY-ALERT + L-ROOTLY-HISTORY + L-IAC-SOURCE + L-VENDOR-DOCS + L-PRIOR-RCAS for CPUThrottlingHigh on otc-container
---

# P4 — Evidence Corpus (Phase 0–2 of eneco-oncall-intake-rootly + repo trace)

> **Mode (Phase 1 of intake)**: deep-enrich. **One-line rationale**: user
> explicitly asked for a holistic RCA at a named path; this is not ack-only,
> not quick-triage. Auto-classified deep-enrich.

## §1 — Phase 0: Alert resolution & 8-field decode (L-ROOTLY-ALERT)

Probe: `~/.claude/skills/eneco-tools-rootly/scripts/rootly-alert-decode.sh --short-id ln2I9h`

| Field | Value | Class |
|-------|-------|-------|
| WHAT | `CPUThrottlingHigh` — kube-prometheus-stack upstream rule | A1 (CLI output) |
| DESCRIPTION | "49.76% throttling of CPU in namespace eneco-vpp for container otc-container in pod opentelemetry-collector-collector-566b6bd96-2htph." | A1 |
| SEVERITY (Prom label) | `info` | A1 |
| URGENCY (Rootly) | **Low** — "Alerts that can be addressed in due course" | A1 |
| WHERE | Cluster `apps.eneco-vpp-dev.ceap.nl` (dev OpenShift); namespace `eneco-vpp`; pod `opentelemetry-collector-collector-566b6bd96-2htph`; container `otc-container`; team `trade-platform` | A1 |
| WHEN | Started 2026-05-11T11:45:29.281Z (UTC) — 04:45 PT | A1 |
| CONDITION (PromQL) | See §2 below — verbatim from `generatorURL` | A1 |
| STATUS | Rootly: `acknowledged` (someone has touched it). Prom alert: `firing`. | A1 |
| INVESTIGATE | OpenShift console graph: https://console-openshift-console.apps.eneco-vpp-dev.ceap.nl/monitoring/graph?... | A1 |
| ESCALATION | EscalationPolicy `1b6ee744-4aca-45ed-9d00-2d1d2b5edbfa` routed via group `trade-platform` (Slack alias `S0ADA9HGT60` = `trade-platform-on-call`) | A1 |
| RUNBOOK | Upstream Prometheus Operator runbook: https://runbooks.prometheus-operator.dev/runbooks/kubernetes/cputhrottlinghigh | A1 |

Also fetched at 04:59 PT (14 min later) on SAME pod: `ContainerMemoryUsageHigh` (`dIazbf`). The OTel Collector has memory pressure too.

## §2 — The PromQL — exact rule mechanism

Decoded from `generatorURL` query parameter:

```promql
(
  sum by (container, pod, namespace) (
    increase(container_cpu_cfs_throttled_periods_total{container!="",namespace="eneco-vpp"}[5m])
  )
  /
  sum by (container, pod, namespace) (
    increase(container_cpu_cfs_periods_total{namespace="eneco-vpp"}[5m])
  )
  > (25 / 100)
) * on (namespace, pod) group_left (label_team)
  kube_pod_labels{job="kube-state-metrics",namespace="eneco-vpp"}
```

**Reading**:

- Numerator: how many 100-ms CFS scheduling periods in the last 5 min got
  throttled (container hit its CPU limit and got paused until next period).
- Denominator: total CFS periods in the last 5 min.
- Threshold: **25%** — fires when more than a quarter of scheduling periods
  see the container hit its limit.
- The `* on (namespace, pod) group_left (label_team) kube_pod_labels{...}`
  join attaches `label_team` so Alertmanager can route by team —
  Eneco-specific routing customization on top of the upstream rule.

**Threshold provenance**: 25% is the **upstream default** in
kube-prometheus-stack — the `_config.kubeStateMetricsCpuThrottlingPercent`
value, baked into `kubernetes-resources.yaml` of the chart. Eneco has NOT
overridden this threshold in any local PrometheusRule (the OTel Collector
chart's own PrometheusRule defines OTel-internal alerts only —
ReceiverDroppedSpans etc., not CPUThrottlingHigh). A1 (confirmed by grep
across all clones).

Measured value: **49.76%** — almost exactly 2x the threshold.

## §3 — Phase 2: Rootly pattern intelligence (L-ROOTLY-HISTORY)

Probe: `rootly-api.sh GET "/v1/alerts?filter[search]=CPUThrottlingHigh&page[size]=30"`

| Container | Firings (last 30d) |
|-----------|---------------------|
| `assetplanning` | 27 |
| `integration-tests` | 2 |
| `otc-container` | **1 (today, `ln2I9h`)** |

Probe: `rootly-api.sh GET "/v1/alerts?filter[search]=otc-container&page[size]=20"`

| Short ID | Time | Type |
|----------|------|------|
| dIazbf | 2026-05-11T04:59:16 PT | ContainerMemoryUsageHigh |
| **ln2I9h** | 2026-05-11T04:45:30 PT | CPUThrottlingHigh — this alert |
| imhh5o | 2026-05-04T01:47:45 PT | ContainerMemoryUsageHigh |
| feuam6 | 2026-05-01T07:25:16 PT | ContainerMemoryUsageHigh |
| XLXtEC | 2026-05-01T07:06:46 PT | ContainerMemoryUsageHigh |

**Pattern classification per H-ROOTLY-2 of eneco-oncall-intake-rootly**:

- Rule (`CPUThrottlingHigh` in namespace `eneco-vpp`): **Known** — recurring,
  the namespace is a chronic throttling generator (~1 firing/day on average).
- Container (`otc-container`): **Novel** for CPUThrottlingHigh —
  first time the OpenTelemetry Collector appears in this rule's history.
  Memory-pressure history on the OTel pod since May 1 (5 incidents in
  10 days, MOM stress trend).

**Verdict**: Known-rule, Novel-target → diagnosis must explain why the OTel
Collector specifically is now hitting CPU throttling AFTER showing memory
pressure since early May, rather than assuming the same shape as the
27-firing assetplanning pattern.

## §4 — L-IAC-SOURCE: where is the OTel Collector defined?

Pod name pattern `opentelemetry-collector-collector-*` + container literal
`otc-container` is the **OpenTelemetry Operator naming convention**:

- CR kind: `OpenTelemetryCollector` (apiVersion `opentelemetry.io/v1beta1`)
- The operator creates a Deployment named `<crname>-collector` for `mode: deployment`
- The container in that pod is hardcoded to `otc-container`
- So CR name = `opentelemetry-collector`

**Search across all eneco-src clones (`rg -l 'kind:\s*OpenTelemetryCollector'`)**:

1. `enecomanagedcloud/myriad-vpp/platform-gitops/opentelemetry-collector/base/otel-collector.deployment.yaml`
   — CR named `otel-collector-eneco-vpp-telemetry`. Deployed to namespace
   `eneco-vpp-telemetry`. **NOT this alert's pod** (wrong name, wrong namespace).
2. `enecomanagedcloud/myriad-vpp/VPP.GitOps/feature-branch-environments-monitoring-stack/chart/templates/opentelemetry-collector.yaml`
   — CR named `opentelemetry-collector`. **Matches our pod's name.**

**The matching CR** (`feature-branch-environments-monitoring-stack`):

```yaml
apiVersion: opentelemetry.io/v1beta1
kind: OpenTelemetryCollector
metadata:
  name: opentelemetry-collector
  labels:
    app: otel-collector
spec:
  config:
    receivers:
      otlp:
        protocols: { grpc: { endpoint: 0.0.0.0:4317 }, http: { endpoint: 0.0.0.0:4318 } }
    processors: { batch: {} }
    exporters:
      debug: { verbosity: detailed }
      prometheus:
        endpoint: "0.0.0.0:8889"
        resource_to_telemetry_conversion: { enabled: true }
        add_metric_suffixes: false
    service:
      pipelines:
        metrics: { receivers: [otlp], processors: [batch], exporters: [debug, prometheus] }
```

**Key observation**: **`spec.resources` is ABSENT**. The OpenTelemetry Operator
applies its **default container resources** when the CR omits this field —
historically this default is **CPU limit 250m, memory limit 128Mi** in older
operator versions, or no defaults at all in newer versions. The exact default
depends on the operator's `--feature-gates` and CR webhook configuration
deployed in the dev cluster (lane probe NOT executed; live cluster access
required to confirm — see §10).

**Older Eneco.HelmCharts/opentelemetry-collector** at
`enecomanagedcloud/myriad-vpp/Eneco.HelmCharts/opentelemetry-collector/values.yaml:220-223`:

```yaml
resources:
  limits:
    cpu: 256m
    memory: 1Gi
```

This is a **historical reference** — the chart container is `{{ .Chart.Name }}`
(= `opentelemetry-collector`), NOT `otc-container`. So the chart was the
**pre-migration** deployment shape. The Otel-Collector-Migration runbook at
`platform-documentation/.../Runbooks/Otel-Collector-Migration.md` documents
the migration from this Helm chart to the OpenTelemetry Operator pattern;
all 7 change steps marked done. Pre-migration PR refs: Fleet Optimizer
PR 148747, Aggregation PR 148751, Core PR 148745.

## §5 — Service/business context (L-ENECO-DOCS — minimal)

- The OpenTelemetry Collector in namespace `eneco-vpp` is the **telemetry
  collector for the Trade Platform application workloads** in the dev
  OpenShift cluster.
- Pipeline (from the CR config): OTLP receivers (gRPC :4317 + HTTP :4318)
  → `batch` processor → exporters (`debug` for stdout + `prometheus` at
  :8889 for scraping by Prometheus).
- The `prometheus` exporter exposes a `/metrics` endpoint on port 8889 that
  Prometheus then scrapes via a ServiceMonitor → into kube-prometheus-stack
  Prometheus → into Grafana dashboards.
- Memory pressure since May 1 on the same pod (4 prior firings) suggests a
  systemic load increase: more application metrics arriving than the
  collector can comfortably process within its current resource envelope.

## §6 — L-VENDOR-DOCS: CFS throttling semantics

`container_cpu_cfs_throttled_periods_total` is a kernel-exposed counter via
cAdvisor; it counts CFS (Completely Fair Scheduler) periods where the
container hit its `cpu` cgroup quota and got paused until the next period.

- Default CFS period in Linux: **100 ms**.
- When a container has CPU limit `X cores`, it gets `X × 100ms` of CPU time
  per 100-ms period; once consumed, kernel pauses it for the remainder.
- Setting CPU limits → guaranteed throttling under burst load.
  Setting CPU requests only → no throttling but scheduling priority only.

49.76% throttled means roughly every other 100-ms scheduling slot the
container was CPU-starved by the kernel. Effect: **latency spikes in
telemetry processing**, possible queue backup in the `batch` processor,
eventual memory growth as queued spans/metrics accumulate
(explains the parallel ContainerMemoryUsageHigh firings).

**Cause/effect direction is asymmetric**: CPU throttling causes memory
buildup (batch processor backs up); memory pressure alone does not directly
cause CFS throttling. So **CPU throttling is the upstream cause**, memory
pressure is the downstream symptom.

## §7 — L-PRIOR-RCAS: engineering-log search

`rg -l -i 'CPUThrottlingHigh|otc-container' log/` returned empty. **No prior
RCA in this log on this rule/target.** Project memory note on the noisy
CCoE keyvault bootstrap alert is unrelated.

## §8 — Threshold rationality (Link 7 of alert-as-code traceback — OBSERVATION ONLY)

Per `references/threshold-sanity.md` of eneco-oncall-intake-rootly: surface
the observation. STOP. **Do NOT recommend changes autonomously.**

**Observation**:

- Threshold **25%** is the upstream kube-prometheus-stack default.
- Measured value **49.76%** is firmly in "fire" territory (≈ 2× threshold).
- For an **observability sidecar/collector** under bursty load, 25% CFS
  throttling can be normal background (collectors batch and burst). Whether
  it's "actionable" depends on:
  1. Whether telemetry is being **dropped** (check OTel-internal alerts
     `ProcessorDroppedSpans` / `ProcessorDroppedMetrics`).
  2. Whether downstream Grafana dashboards show **gaps** during throttled
     windows.
  3. Whether the **memory pressure trend** (4 firings since May 1) is
     correlated.
- The alert label is `severity: info` and Rootly urgency is `Low`. The team
  has already calibrated this as "address in due course," not paging.

**No recommendation crossed.** The team owns the threshold and the
collector's resource budget; an RCA observes, the team decides.

## §9 — Phase 6D route decision

Per `eneco-oncall-intake-rootly` Phase 6D rule:

- (1) Diagnosis reveals an IaC/code change is needed: **NOT YET** — the
  RCA reveals a possible undersized resource budget AND a memory trend;
  recommendation is observation + a triage probe sequence, not an IaC patch.
- (2) Resource-level change: **NOT YET** — same reason.
- (3) An Assumed claim requires repo or deep Azure inspection: **YES** — the
  exact effective CPU limit on the pod (CR-default vs operator-default vs
  namespace LimitRange) requires live cluster `oc describe pod`.
- (4) User explicitly asked for deeper investigation: **YES** — the user
  asked for a holistic RCA via rca-holistic.
- (5) Adversarial pass surfaces a contradiction needing repo evidence:
  pending — pre-RCA Sherlock + Socrates dispatch will determine.

**Route**: TERMINAL **at this skill's scope** (write the RCA in the
personal on-call log; do not hand off to `eneco-oncall-intake-enrich` for
a fix PR). The RCA will name the **next-probe playbook** (oc describe,
check OTel internal drops, inspect memory trend) as the on-call action,
but those probes belong to the on-call shift, not to this artifact.

## §10 — Outstanding A3 UNVERIFIED claims (for the RCA "Residual risk" section)

These cannot be eliminated without live cluster `oc` access (not authorized in
read-only intake):

| Claim | Probe to flip |
|-------|---------------|
| The pod's effective CPU limit RIGHT NOW is the operator default, NOT a chart-defaulted 256m | `oc -n eneco-vpp describe pod opentelemetry-collector-collector-566b6bd96-2htph \| grep -A3 "Limits:"` |
| There is no namespace LimitRange overriding pod limits | `oc -n eneco-vpp get limitrange -o yaml` |
| The pod has NOT been OOMKilled or evicted recently | `oc -n eneco-vpp get events --field-selector involvedObject.name=opentelemetry-collector-collector-566b6bd96-2htph` |
| No telemetry is being dropped during throttle windows | Query Prometheus: `rate(otelcol_processor_dropped_spans[5m]) > 0` AND `rate(otelcol_exporter_send_failed_metric_points[5m]) > 0` |

These probes form the on-call recognition playbook in the RCA.
