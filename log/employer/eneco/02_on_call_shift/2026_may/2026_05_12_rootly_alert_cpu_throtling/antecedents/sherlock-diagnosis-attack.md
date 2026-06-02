---
task_id: 2026-05-11-003
agent: sherlock-holmes
status: pending_review
summary: Corpus has mis-identified the IaC source — feature-branch chart is NOT what runs in eneco-vpp; entire "enabling cause" + causal-direction claims rest on A3, not A1.
---

# Sherlock — diagnosis attack on ln2I9h RCA

Mandate: destroy, not confirm. Coordinator-facing receipts are INFER until source-verified; I attack the inherited analysis itself, not citation parity. Tone of attack is terse by directive.

## 0. Headline (strongest attack first)

**Your corpus has mis-identified the source IaC.** The CR at
`feature-branch-environments-monitoring-stack/chart/templates/opentelemetry-collector.yaml`
is **a feature-branch monitoring-stack template**, NOT the OTel Collector
deployed in namespace `eneco-vpp`. Therefore your **enabling cause** (
"CR omits `spec.resources`, operator default too tight") is an **A3
UNVERIFIED claim presented as A1**. The whole "novel-target, undersized
budget" narrative is sourced from a file that does not describe this pod.

Evidence:

- `feature-branch-environments-monitoring-stack/chart/Chart.yaml:1-30` — name
  `monitoring-stack-feature-branch-environments`, dependency
  `kube-prometheus-stack 58.5.2`. This chart is for *feature-branch
  environments*. Its values.yaml line 1 declares
  `feature_branch_environment: "default"`.
- `feature-branch-environments-monitoring-stack/active-environments/` —
  contains `afi.yaml`, `ionix.yaml`, `jupiter.yaml`, `kidu.yaml`,
  `thor.yaml`, `voltex.yaml`. **None is `eneco-vpp.yaml`.**
  `voltex.yaml:1-2` literally says `environment: voltex`,
  `featureBranch: feature/fbe-adx-shared`.
- `grep -rln 'eneco-vpp\b' VPP.GitOps/feature-branch-environments-monitoring-stack/`
  → **zero matches**. The string `eneco-vpp` does not occur in this chart
  or its values.
- The OTel Application that DOES target namespace `eneco-vpp` is in fact
  ambiguous: the only ArgoCD Application named `opentelemetry-collector`
  (`VPP.GitOps/argocd-configuration/applications/opentelemetry-collector.application.yaml:13-16`)
  has `destination.namespace: opentelemetry-operator-system` and `path:
  opentelemetry-collector` → which is the **OLD Helm path**
  `VPP.GitOps/opentelemetry-collector/opentelemetry-collector.deployment.yaml`,
  a plain Deployment with container `name: collector` (not `otc-container`)
  and image `otel/opentelemetry-collector-contrib:0.93.0`. That Deployment
  is `replicas: 3` — but ALSO not in `eneco-vpp`.
- `git log -1` on the GitOps clone returns `2025-11-18 600a28a`. The clone
  is **6 months stale relative to the alert** (alert 2026-05-11). Any
  claim that "the CR has no spec.resources" is asserted against a
  point-in-time snapshot from before half a year of merges.

Coordinator's §4 ran the right grep across clones and even noted the
right CR is *not* CR (1) in `platform-gitops` (different namespace,
different name). Then it picked CR (2) by name-match alone — without
ever proving that CR (2) is what ArgoCD synced into namespace
`eneco-vpp`. Name match ≠ deployment proof. **The IaC→runtime link is
broken at L3 of the alert-as-code traceback.**

## 1. Competing diagnoses your corpus admits

### D-ALT-A — Noisy upstream rule on observability sidecar (corpus's §8 elevated)

The corpus itself observes (§8): "For an observability sidecar/collector
under bursty load, 25% CFS throttling can be normal background
(collectors batch and burst). The alert label is `severity: info` and
Rootly urgency is `Low`. The team has already calibrated this as 'address
in due course'."

Compatible facts:
- Same namespace has **30 firings/30d** of the same rule on
  `assetplanning` (27) and `integration-tests` (2). The rule has Known
  Noise class.
- Threshold (25%) is **upstream default**, not Eneco-tuned. Project
  memory has precedent for noisy upstream rules on infrastructure
  workloads (CCoE keyvault bootstrap alert,
  `feedback_oncall_argocd_three_plane.md` neighborhood file).
- Measured 49.76% is ~2× threshold — well within the "burst then settle"
  pattern of a `batch:` processor with no explicit `send_batch_size`
  override, which lets it batch as large as memory allows and burst
  hard on flush.
- Memory-pressure trend since May 1 (4 firings) is **also explainable**
  as legitimate growth in telemetry volume from Trade Platform feature
  development tempo, not as a downstream symptom of CPU throttling.

**This is more parsimonious than your story.** Your story requires:
  1. CR has no resources (UNPROVEN — see §0 above),
  2. operator default is too tight (UNPROVEN — never probed),
  3. batch processor backs up under throttle (PLAUSIBLE but UNPROVEN —
     no drop-metric probe),
  4. memory grows because of (3) (INFER from (3) you haven't proved).

D-ALT-A requires: threshold is generic, workload is observability
sidecar, rule is noisy on these workloads. All A1 from your corpus.

### D-ALT-B — Reversed causal direction (the question you asked me to test)

Your §6 claim: "CPU throttling causes memory buildup; memory pressure
alone does not directly cause CFS throttling."

This is **half right and stated as A1**. Counter-evidence in the corpus:

- The pod has **4 prior memory firings since May 1**, BEFORE the CPU
  one today. Timeline order: memory pressure trend → CPU throttling
  appearance. Your story has the arrow pointing the other way.
- OTel Collector with `batch: {}` and **`debug: { verbosity: detailed }`**
  exporter (line 21 of the CR) is a known anti-pattern: detailed-verbosity
  debug exporter serializes every batch to stdout. That is **CPU-heavy
  string formatting work** that can dominate the container's CPU budget
  WITHOUT going through any memory back-pressure path.
- Go runtime under memory pressure → GC frequency rises → GC CPU%
  rises → CFS quota exhausted faster → throttling. This is a textbook
  path that contradicts your "asymmetric, throttling→memory only"
  claim. The Go runtime allocates and scans across goroutines; high
  memory residency directly costs CPU via mark-sweep, ESPECIALLY in a
  container whose CPU limit is low (small denominator).
- Memory firings are ContainerMemoryUsageHigh — i.e. usage approached
  the *memory limit*, not OOMKills (corpus §10 explicitly does not
  confirm no OOMKill, only that it's a probe needed). High residency
  near limit drives sustained GC overhead.

**Verdict on direction**: corpus has not earned the asymmetry claim.
Both directions are admissible from the present evidence. The temporal
order (memory firings first since May 1, CPU firing today) is at least
as consistent with **memory pressure → GC → CPU throttling** as with
your hypothesis. The leader-pre-falsifier sin: §6 picks a direction
without running a discriminator. Treating §6's asymmetry as A1 is
GATE-FAIL.

### D-ALT-C — The `debug: detailed` exporter is the proximate cause

This is the **simplest** explanation you asked me to look for in Q1.
The CR config (lines 19-21 of the file you pointed at) ships **two
exporters in the metrics pipeline**: `debug` with `verbosity: detailed`
AND `prometheus`. The `debug` exporter is documented by OTel as a
diagnostic tool that pretty-prints every datapoint to stdout; with
`verbosity: detailed`, it serializes all attributes and values. Two
problems:

  1. CPU: string formatting + stdout writes scale with telemetry rate.
     As application metrics volume grows (which the memory trend
     suggests), the debug exporter's CPU cost grows linearly.
  2. Memory: stdout buffering + the formatter's intermediate strings
     contribute to heap, AND container logging in OpenShift writes to
     a journald-backed stream that, when slow to drain, back-pressures
     the producer.

This is *one variable*. Remove it (drop `debug` from the pipeline) and
both symptoms could plausibly resolve simultaneously. Your story
requires reasoning about operator defaults AND batch processor AND
queue buildup AND memory growth AND why memory was already trending
before today.

Hickey: your corpus is complecting "resource budget" with "pipeline
configuration" with "operator default behavior". The simpler claim is
the pipeline itself does diagnostic-grade work in dev.

### D-ALT-D — Noisy neighbor / node-level CPU pressure

Q1 asked me to look. Corpus has **zero** evidence either way. It never
fetched node-level metrics or asked which node the pod ran on. A
co-tenant on the same dev node spiking CPU between 11:40-11:50 UTC
would *also* drive `container_cpu_cfs_throttled_periods_total` upward
for any container with a low CPU limit and a hot working set. The 5-min
window of the alert exactly matches the time-scale of a noisy-neighbor
burst (single CI job, single build pod, single test run). Dev cluster
+ low utilisation makes this MORE likely than in prd, not less.

Corpus has no probe to exclude this. It is therefore an admissible
alternative diagnosis, currently with prior probability ≈ background
rate of dev-cluster bursts.

### D-ALT-E — `otc-container` is what I think it is, but the pod is not what corpus thinks

Q4 asked. The OpenTelemetry Operator hard-codes the container name to
`otc-container` ONLY for pods created from an `OpenTelemetryCollector`
CR by that operator. If a *different* tenant deployed an OTel Collector
in `eneco-vpp` namespace via a sidecar or via a different operator
install (the corpus did not enumerate operator installations — it just
asserted the operator is installed), `otc-container` could belong to
that tenant's CR, not to the feature-branch chart at all. The corpus
has not probed:

- Are there multiple OpenTelemetry Operators installed?
- Is there a CR named `opentelemetry-collector` in namespace `eneco-vpp`
  vs cluster-scoped operator watching all namespaces?
- The pod label `app: otel-collector` (corpus §4) and the team label
  `trade-platform` (alert payload) — are these from the CR's metadata
  or from `kube_pod_labels` join in PromQL? §2's PromQL shows
  `* on (namespace, pod) group_left (label_team) kube_pod_labels` —
  i.e. `team` label is **joined in at query time** from kube-state-metrics,
  so the `team=trade-platform` in the alert is a property of the
  pod's labels at scrape time, not proof that Trade Platform owns the
  *CR*. The CR template you cited has `labels: app: otel-collector`,
  no `team` label at all.

Conclusion: corpus has not proven CR ownership of the pod. The pod
could be deployed by **any** team that runs an OTel Collector CR named
`opentelemetry-collector` into namespace `eneco-vpp`. Trade Platform's
ownership is inferred from a kube-state-metrics label that itself is
applied somewhere outside the cited CR.

## 2. Load-bearing assumptions you have promoted from A3 to A1

| # | Claim in your diagnosis | Corpus claims class | Reality | Falsifier |
|---|---|---|---|---|
| 1 | The CR at `feature-branch-environments-monitoring-stack/.../opentelemetry-collector.yaml` describes the pod that fired | A1 (§4) | **A3** — name match, NOT deployment proof; chart targets feature-branch envs, not `eneco-vpp` | `oc -n eneco-vpp get OpenTelemetryCollector -o yaml`; compare to file |
| 2 | `spec.resources` is absent → operator default applies → "too tight" | A1 (§4) | **A3 stacked** — even if (1) holds, "too tight" is unprobed | `oc -n eneco-vpp describe pod $POD \| grep -A5 Limits:` |
| 3 | CPU throttling is upstream cause; memory is downstream symptom | A1 (§6) | **A3** — never tested; temporal order in §3 suggests opposite | Run pod with same memory limit but 4× CPU limit; if mem firings stop → arrow was mem→cpu reversal needed |
| 4 | Trade Platform owns this pod | A1 (alert payload, §5) | **A2** — `label_team` is joined at query time from kube_pod_labels, not from CR metadata | `oc -n eneco-vpp get pod $POD -o jsonpath='{.metadata.labels}'`; check where `label_team` comes from |
| 5 | The 27 firings on `assetplanning` are a different pattern from `otc-container`'s first firing | A1 (§3 verdict "Novel-target") | **A2** — they could be the same pattern (namespace-wide noisy rule on low-CPU-limit infra workloads); "Novel" is a category not a cause | Compare CPU limit + workload class of `assetplanning` vs `otc-container`; if both ≤500m and both infra-class, pattern is one not two |
| 6 | The `batch:` processor backing up is the link between CPU throttling and memory growth | A2 (§5/§6) | **A3** — `batch: {}` has no explicit `send_batch_size`; default behavior is timer-driven flush, not size-driven backup. The link mechanism is asserted, not derived. | OTel internal metrics: `otelcol_processor_batch_batch_size_trigger_send` vs `_timeout_trigger_send` ratio. |

## 3. Causal-direction analysis (Q2)

Your prompt: "What if memory pressure → GC pressure → CPU spike → throttling?"

**Evidence that the reversal is at least as parsimonious as your forward arrow:**

| Observation | Forward (CPU→mem) prediction | Reverse (mem→CPU) prediction | Actual |
|---|---|---|---|
| First memory firing relative to first CPU firing | Memory firing should LAG CPU firing | Memory firings should LEAD CPU firing | **Memory leads by 10 days** (May 1 → May 11). Reverse arrow predicted this; forward arrow did not. |
| 4 memory firings BEFORE today's CPU firing | Forward arrow says "CPU was throttled before today and we missed it" — requires hidden CPU events | Reverse arrow says "memory pressure has been growing; today GC finally crossed CFS threshold" — no hidden events | Reverse fits with fewer hypotheses |
| Today: CPU at 11:45, memory at 11:59 (14 min later) | Forward arrow: CPU throttling backs up batch → 14 min for memory to climb to alert threshold. Plausible. | Reverse arrow: memory was *already* climbing; CPU threshold crossed first because PromQL window is 5min and memory uses different windowing. The 14-min gap could be alert windowing, not causation. | Both directions fit; gap proves nothing. |
| Other containers in the same namespace fire CPU but not memory | Forward arrow: those containers don't have queue-backed processors, so no memory consequence. Acceptable. | Reverse arrow: those containers aren't memory-bound to begin with. Also acceptable. | Both fit; not discriminating. |

**Result: corpus's claim that "memory pressure does not directly cause
CFS throttling" is empirically false for Go workloads with high
mark-and-sweep cost near memory limit.** The §6 asymmetry is not earned.

A discriminating probe exists and is cheap: query Prometheus for
`rate(go_gc_duration_seconds_sum[5m])` on this pod over May 1-11. If GC
seconds rose steadily before May 11 and crossed an inflection where it
consumed ~50% of available CPU at the limit, the arrow is reversed and
your enabling cause changes from "resources too tight" to "memory limit
too tight" — different fix.

## 4. Highest-info missing probe (Q5)

Ranked by belief-change-per-cost:

1. **`oc -n eneco-vpp get OpenTelemetryCollector -o yaml`** — this single
   command flips the **entire** "enabling cause" claim. If the deployed
   CR has `spec.resources` populated (or has a different config than the
   file your corpus cited), your story collapses at root. Cost: ~2s.
   Belief-change: maximal.

2. **`oc -n eneco-vpp describe pod opentelemetry-collector-collector-566b6bd96-2htph`** —
   gives effective Limits/Requests/QoS class, node, OOMKilled status,
   restart count, image SHA. Settles claims 1, 2, and partially 5.
   Cost: ~2s. Belief-change: very high.

3. **PromQL probes on the pod's OTel internal metrics**:
   - `rate(otelcol_processor_dropped_metric_points[5m])`
   - `otelcol_exporter_send_failed_metric_points` per exporter
   - `otelcol_processor_batch_batch_send_size`
   - `go_gc_duration_seconds_sum`
   - `go_memstats_heap_inuse_bytes`
   Over a 24h window straddling May 11. Cost: ~30s. Settles direction
   (D-ALT-B) and exporter-as-cause (D-ALT-C).

4. **`oc -n eneco-vpp get events --field-selector involvedObject.name=opentelemetry-collector-collector-566b6bd96-2htph --sort-by='.lastTimestamp'`** —
   reveals deployment events, image pulls, restarts, OOMKills. Settles
   whether a deploy event today is the simpler explanation (Q1).

5. **`oc adm top pod -n eneco-vpp` + `oc adm top node $NODE`** — settles
   noisy-neighbor (D-ALT-D) and gives the actual CPU% the pod is using
   under the limit, not the throttled-period ratio.

## 5. Surgical recommendations for the RCA

You asked me to attack, not to recommend, but the RCA must NOT be
delivered as-is. Three line-edits before write:

1. **Strike all A1 claims about the IaC source**. Re-class to A3 with
   "Probe: `oc -n eneco-vpp get OpenTelemetryCollector -o yaml`". The
   current §4 conclusion is a name-match fallacy.

2. **Strike §6's causal-direction asymmetry.** Replace with: "Two
   admissible directions; discriminating probe is GC-duration trend."

3. **Add D-ALT-A (rule-is-noisy-on-obs-sidecars) as an equally-ranked
   hypothesis**, not as observation §8. The corpus itself states the
   threshold is generic + the workload is an obs sidecar + the team
   classified it Low. That is three converging A1 facts for D-ALT-A
   and zero new A1 facts for your D-PRIMARY.

## 6. Self-skepticism (FACT/INFER/UNVERIFIED for my own attack)

- §0 IaC mis-identification — **A1**. Files cited, greps run, directory
  listings shown. The chart is the feature-branch chart; `eneco-vpp`
  string is absent.
- D-ALT-A (noisy rule on sidecar) — **A2**. Compatible with corpus
  facts; not independently proven against this specific pod's runtime.
- D-ALT-B (causal reversal) — **A2**. Argued from Go runtime
  mechanism + temporal order; the discriminating probe (GC duration)
  has not been run.
- D-ALT-C (debug exporter is proximate cause) — **A3**. Mechanism is
  documented in OTel docs; cost on this specific deployment is unprobed.
- D-ALT-D (noisy neighbor) — **A4 UNVERIFIED[unknown]** — cannot be
  excluded; needs node-level metrics not present in corpus.
- D-ALT-E (pod ownership) — **A2**. The `label_team` join is in the
  PromQL; what generates that label on the pod is unprobed.
- My local clone of `VPP.GitOps` is dated 2025-11-18 (`git log -1`).
  All statements about the *content* of the chart could be stale
  relative to 2026-05-11. This caveat applies to my attack and equally
  to your diagnosis: **both rely on the same stale snapshot**, which
  means neither story can be A1 about runtime state without `oc`
  access. This is the strongest single takeaway: the RCA needs a
  `[UNVERIFIED[blocked]: live cluster access not authorised]` tag,
  not an A1 enabling cause.

## 7. Verdict

The diagnosis you handed me is **not destroyed at the root** — CPU
throttling on this pod is real and 49.76% is a real measurement — but
your **enabling cause** and your **causal direction** are both A3
asserted as A1. They will not survive an `oc describe` probe and the
RCA should not pretend they will. A defensible RCA writes the proximate
cause as A1 (the metric and the threshold breach), explicitly enumerates
D-ALT-A through D-ALT-E as currently-admissible hypotheses, and frames
the on-call playbook as a *hypothesis-discriminating probe sequence*,
not as a "fix the resource budget" recommendation.

**Strongest single attack**: the chart you cited is for feature-branch
envs (voltex/thor/etc.), not for namespace `eneco-vpp`. Your entire
enabling-cause limb is sourced from the wrong file.
