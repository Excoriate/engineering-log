---
task_id: 2026-05-11-003
agent: claude-code
status: pending_review
summary: P6 spec — output package structure + per-section acceptance criteria for the rca-holistic-driven RCA at the user's named path
---

# P6 — RCA Output Package Spec

## Target

```
/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/log/employer/eneco/02_on_call_shift/2026_05_11_rootly_alert_cpu_throtling/
├── output/
│   └── rca.md                         (PRIMARY DELIVERABLE)
├── antecedents/
│   ├── rootly-alert-raw-decoded.txt   (decode script stdout)
│   ├── rootly-alert-payload.json      (canonical payload)
│   ├── rootly-alert-meta.json         (attributes)
│   ├── p4-evidence-corpus.md          (the synthesized intake corpus)
│   ├── sherlock-diagnosis-attack.md   (pre-RCA adversarial #1)
│   └── socrates-framing-attack.md     (pre-RCA adversarial #2)
├── proofs/
│   ├── scripts/
│   │   └── replay-rootly-intake.sh    (Rootly-side probe replay — A1)
│   └── outputs/
│       ├── rootly-cputhrottlinghigh-30d-history.tsv  (rule history)
│       └── rootly-otc-container-history.tsv          (pod history)
└── auxiliary/
    ├── socrates-post-draft-attack.md  (rca-holistic Phase 5 #1 — written AFTER draft)
    └── el-demoledor-post-draft-attack.md (rca-holistic Phase 5 #2 — written AFTER draft)
```

Antecedents will be copied from `$T_DIR/context/` (mirroring discipline:
canonical lives under $T_DIR; deliverable copy at destination).

## RCA front-matter contract (per rca-holistic Phase 7 status rule)

```yaml
---
title: "CPUThrottlingHigh on opentelemetry-collector (otc-container) — Rootly ln2I9h"
date: 2026-05-11
incident_class: "Known rule on Novel target with contested diagnosis"
alert_id: ln2I9h
severity: info  # Prometheus label
urgency: Low    # Rootly tier (NOT team calibration — see L1)
reader: "Next-shift trade-platform on-call engineer who has never seen this OTel Collector deployment"
output_package: standard
mode: ENRICH
domain_prior: low  # I have repo layout and PromQL semantics but no live cluster access
adversarial_review: pre+post  # Two pre-RCA + two post-draft dispatches
status: complete  # IF post-draft attacks pass; ELSE review
---
```

`status: complete` requires:
- `validate-rca-completeness.sh` exits 0
- `check-mermaid-syntax.sh` exits 0 (or no Mermaid fences)
- BOTH post-draft adversarial artifacts present at `auxiliary/`
- All adversarial findings absorbed or marked deferred-with-reason
- No A3 assumption on the causal mechanism (we EXPLICITLY have A3s — these
  must be named as the discriminating probes, not as load-bearing claim
  retentions)

If the rca-holistic skill's Phase 7 verification fails any of the above,
front-matter goes to `status: review`.

## Per-section acceptance criteria

### L1 — Business / Functional

**Reader question**: "Why does an OTel Collector for Trade Platform's dev cluster matter to me right now?"

Required:
- One sentence on Trade Platform's business role (electricity trading platform; high-volume aggregation/dispatch)
- One sentence on why observability matters here (regulatory + ops visibility under burst load)
- One sentence on what a stale or broken Collector causes (dashboard gaps, dropped traces, delayed alert routing)
- Explicit clarification: severity:info / urgency:Low are LABELS, not team-validated triage tiers — Rootly tier description is vendor stock copy
- Source links: Trade Platform on-call group, EscalationPolicy ID, Rootly workspace URL

### L2 — Repo system

**Reader question**: "Which code/IaC components are in play and how do they relate?"

Required:
- Repo rigor table: 4 repos (Eneco.HelmCharts legacy, VPP.GitOps FBE chart, platform-gitops other-namespace CR, MC-VPP-Infrastructure Terraform), each with role, technology, clickable source, deployment handoff, incident relevance
- Explicit "WHICH file represents the running pod" subsection — leading with the negative answer (the FBE chart is NOT it because active envs don't include eneco-vpp; the platform-gitops CR is also NOT it because that's in eneco-vpp-telemetry namespace; the legacy chart's container name doesn't match)
- The actual answer: **A3 UNVERIFIED[blocked: live cluster access required]** with the discriminating probe `oc -n eneco-vpp get OpenTelemetryCollector -o yaml`
- Local-clone staleness disclosure (clones dated 2025-11-18, 6 months stale)

### L3 — Runtime architecture

**Reader question**: "Which deployed pieces touch this incident?"

Required:
- Cluster identity (apps.eneco-vpp-dev.ceap.nl OpenShift)
- Namespace map (eneco-vpp for application workloads + its OTel Collector; eneco-vpp-telemetry for the Dynatrace-export collector; openshift-monitoring for kube-prometheus-stack)
- OpenTelemetry Operator pattern (CR → Deployment named `<crname>-collector` → container named `otc-container` by hardcoded operator convention)
- Pod identity (opentelemetry-collector-collector-566b6bd96-2htph) with the ReplicaSet hash interpretation
- Mermaid or table for namespace boundaries and which Prometheus scrapes what

### L4 — SDK / Data flow (compact)

**Reader question**: "What does the failing code actually do?"

Required:
- OTel Collector pipeline: OTLP receivers (gRPC :4317, HTTP :4318) → batch processor → exporters (debug, prometheus, possibly otlphttp)
- CFS throttling primer (100ms periods; container quota; what 49.76% throttled means in user-visible terms)
- Where in this pipeline CPU is most likely spent: batch processor on high-rate metric ingestion, debug exporter on verbose stdout

### L5 — IaC / Declarative contract — **HEAVY ADVERSARIAL FRAMING**

**Reader question**: "What does the spec say should exist?"

Required:
- The CR kind is `OpenTelemetryCollector` (apiVersion `opentelemetry.io/v1beta1`)
- Three candidate file sources mapped + each falsified as the running source
- The **discriminating probe** named explicitly: `oc -n eneco-vpp get OpenTelemetryCollector opentelemetry-collector -o yaml`
- The **pre-migration baseline** (`Eneco.HelmCharts` chart had `cpu: 256m, memory: 1Gi` at `values.yaml:220-223`) — Socrates F3.3 observation
- The **post-migration regression hypothesis**: if the running CR omits `spec.resources`, the migration dropped the explicit budget — but this is A2 INFER, not A1, until the live probe runs
- Mention `debug: { verbosity: detailed }` in the FBE-chart CR as evidence the CR PATTERN supports verbose debug, even if THIS pod's CR differs (per Sherlock D-ALT-C)

### L6 — Pipeline / Delivery (compact)

**Reader question**: "How does spec become runtime (or fail to)?"

Required:
- GitOps via ArgoCD (per VPP.GitOps `argocd/` directory presence)
- ArgoCD application names per env (otel-collector-dev/acc/prd.argocd.application.yaml in platform-gitops)
- Important caveat: the ArgoCD app for `eneco-vpp` namespace deployment is NOT visible in my corpus — A3 UNVERIFIED

### L7 — Timeline

**Reader question**: "What happened, when?"

Required: timeline table

| Time (UTC) | Event | Evidence |
|------------|-------|----------|
| 2026-05-01T14:06 | First ContainerMemoryUsageHigh on this pod (XLXtEC) | rootly-otc-container-history.tsv |
| 2026-05-01T14:25 | Second ContainerMemoryUsageHigh (feuam6) | same |
| 2026-05-04T08:47 | Third ContainerMemoryUsageHigh (imhh5o) | same |
| 2026-05-11T11:45:29Z | CPUThrottlingHigh fires (ln2I9h) — TODAY | alert-payload.json |
| 2026-05-11T11:59:16Z | Fourth ContainerMemoryUsageHigh (dIazbf) — 14 min later | same |
| (unknown) | Someone acknowledges ln2I9h | alert-meta.json status:acknowledged — who/when not visible without further probe |

The timeline must FRAME the trend: memory pressure has been escalating for
10 days; today's CPU is the latest data point, not a novel signal.

### L8 — Fix — **OBSERVATION ONLY, NO PRESCRIPTION**

**Reader question**: "What changes, what doesn't, why?"

Required:
- Explicit statement: **no fix is applied with this RCA** — the next step is the discriminating probe at L11/L12
- For EACH of the 4 hypotheses, name what a fix WOULD look like:
  - H-A: add `spec.resources.limits` to the CR — magnitude TBD by load profile probe
  - H-B: address the upstream memory leak/growth — requires Prometheus working-set time series first
  - H-C: split the PromQL rule by namespace label OR add a workload-class exclusion — Eneco-local PrometheusRule patch
  - H-D: change `debug: { verbosity: detailed }` → `verbosity: basic` (or drop the debug exporter)
- "What this RCA does NOT change": no PR is being shipped; no threshold change is being recommended; no runtime mutation is performed

### L9 — Verification

**Reader question**: "How would we know which diagnosis is right?"

Required: discrimination table — one probe per hypothesis

| Hypothesis | Discriminating probe | Confirms if | Falsifies if |
|------------|----------------------|-------------|--------------|
| H-A undersized CPU | `oc -n eneco-vpp describe pod ... \| grep Limits:` | CPU limit ≤ 256m AND no obvious upstream memory cause | No CPU limit set OR limit ≫ measured peak usage |
| H-B memory upstream | Promql `rate(container_memory_working_set_bytes{pod=~"opentelemetry-collector-collector-.*"}[1h])` over 14d | Monotonic memory growth before today | Flat memory until today |
| H-C noisy rule | Cluster-wide: PromQL over all namespaces for this rule's trigger rate; compare app-workload-class vs observability-class containers | Observability sidecars systematically trigger above 25% | Only this pod is anomalous |
| H-D debug verbose | `oc -n eneco-vpp get OpenTelemetryCollector opentelemetry-collector -o yaml \| yq '.spec.config.exporters.debug'` | `verbosity: detailed` present | `verbosity: basic` or `debug` exporter not in config |

### L10 — Lessons

**Reader question**: "What durable knowledge do I keep?"

Required: 2–3 lessons, each `pattern + probe + defense`. The lessons MUST survive the "rephrase without naming this incident's nouns" test (rca-holistic Phase 6).

Candidate lessons:
1. **Pattern**: when a Rootly alert's severity/urgency is the vendor's stock label (Low = "addressed in due course"), do NOT read it as team-validated triage. **Probe**: check the urgency tier description verbatim in the API; if it matches Rootly's stock copy, treat it as routing config, not calibration. **Defense**: team-level urgency calibration belongs in a team runbook entry, not in the alert label.
2. **Pattern**: causal direction asserted from a snapshot ("CPU throttled → memory") can be falsified by the temporal record. **Probe**: order the events; the upstream cause should appear before the downstream effect. **Defense**: hold both directions as candidates until the time series probe runs.
3. **Pattern**: file-source attribution by name-match ("CR named X is in this file") is INFER, not FACT. **Probe**: live runtime CR YAML. **Defense**: the L5 IaC section leads with the live probe, not the static file.

### L11 — Command playbook (cold-start)

**Reader question**: "How do I recreate this RCA from scratch?"

Required: step-by-step, each with rationale + freshness probe + decision rule. Builds on `replay-rootly-intake.sh` already in `proofs/scripts/` for the Rootly half.

Must include the live-cluster discriminator probes (commented as A3 UNVERIFIED[blocked] until on-call has live access):

```bash
# REQUIRES: oc login <dev cluster> + token + project switch
oc -n eneco-vpp get OpenTelemetryCollector opentelemetry-collector -o yaml > otel-cr-live.yaml
yq '.spec.resources, .spec.config.exporters.debug' otel-cr-live.yaml
```

### L12 — On-call one-pager

**Reader question**: "Spot this class next time in 5 minutes."

Required: 1-page checklist (table or compact list) — pattern recognition trigger → 4 hypotheses → 2 discriminating probes → decision tree → escalation rule. Targets the next-shift on-call who is paged on the same rule again.

## Internal evidence-key (X9 rule)

The RCA will repeat A1/A2/A3 decoder near any dense section, not rely on
a single document-header legend.

## Hand-off boundary

This spec is consumed by P7 (rca-holistic skill invocation). P7 produces
`output/rca.md`. P8 verifies against this spec.
