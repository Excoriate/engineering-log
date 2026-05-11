---
task_id: 2026-05-11-003
agent: claude-code
status: pending_review
summary: P5 plan — RCA structure for Rootly ln2I9h post-adversarial; 4 competing hypotheses held; HANDOVER framing; rca-holistic skill executes the draft
---

# P5 — Plan

## Revised diagnosis posture (post-adversarial)

The corpus admits **four competing diagnoses**, all of which fit the
externally-witnessable evidence. The RCA does not collapse them prematurely
because the discriminating probes require live cluster access not authorized
in read-only intake.

| ID | Diagnosis | Strongest A1 fact supporting | Strongest A1 fact against |
|----|-----------|-------------------------------|----------------------------|
| H-A | Undersized CPU budget upstream → CFS throttling → batch queue → memory pressure downstream | 49.76% throttling measured today (alert-payload.json) | Memory alerts precede CPU by 10 days — temporal order inverts the arrow |
| H-B | Memory pressure upstream → GC overhead → CPU bursts → CFS throttling | 4 memory firings on this pod since 2026-05-01 (rootly-otc-container-history.tsv) | No GC metrics in current corpus; needs Prometheus probe |
| H-C | Upstream rule's 25% threshold is calibrated for application workloads, NOT observability sidecars that burst by design — alert itself is the root cause | Generic upstream `_config.kubeStateMetricsCpuThrottlingPercent` (PromQL); severity:info / urgency:Low team mapping | The same rule fires routinely on `assetplanning` and `integration-tests` — namespace-wide tightness is real |
| H-D | `debug: { verbosity: detailed }` exporter in the CR drives CPU via stdout I/O | Line 21 of corpus §4's CR has `debug: { verbosity: detailed }` (a known CPU sink) | CR file attribution itself is INFER (name-match, FBE chart, 6mo stale) |

**The honest position**: I cannot rank H-A/H-B/H-C/H-D without a single
inexpensive probe — `oc -n eneco-vpp get OpenTelemetryCollector
opentelemetry-collector -o yaml` + memory time-series — that the on-call
engineer can run in 2 minutes. The RCA's job is to teach the reader to
**resist premature single-diagnosis collapse** and run the discriminating
probe.

## Six Questions (Q1–Q6) — SUBSTANCE, not boilerplate

### Q1 — Most dangerous assumption that could flip the route?

**Assumption**: the CR I cited in corpus §4 (FBE chart at
`VPP.GitOps/feature-branch-environments-monitoring-stack/chart/templates/opentelemetry-collector.yaml`)
is the source of the running pod. Sherlock falsified this by name-match
argument: the chart's `active-environments/` are `jupiter/thor/voltex/ionix/kidu/afi`
— `eneco-vpp` is not there.

**Step change**: Stop citing that CR as A1 source for the running pod. The
RCA's L5 IaC section must state "the configured CR for this pod is
A3 UNVERIFIED[blocked: live cluster access required]" and name the
discriminating probe explicitly.

**Residual risk**: even if I find a non-FBE manifest in `platform-gitops/`,
local clones are 6mo stale — runtime probe is the only truth surface.

### Q2 — Simplest explanation I might be missing?

**Sherlock's D-ALT-C**: `debug: { verbosity: detailed }` is the simplest
plausible cause. Detailed stdout debug on a high-rate metric receiver burns
CPU on string formatting + I/O. This single config flag could DOUBLE the
collector's CPU draw — and if the CR actually has it enabled in dev (as
the FBE-chart CR does), the diagnosis is **CR-misconfiguration**, not
**resource-budget undersizing**.

**Step change**: Add a Hypothesis Section (HS) to the RCA naming H-D and
the discriminating probe (live CR YAML grep for `verbosity: detailed`).

### Q3 — What probe would DISPROVE the current narrative?

Single probe: `oc -n eneco-vpp get OpenTelemetryCollector opentelemetry-collector -o yaml | grep -A3 -E 'resources:|verbosity:'`.

- If `verbosity: detailed` is present → H-D ascends
- If `spec.resources.limits.cpu` exists and ≤ 256m → H-A persists
- If neither → operator default applies (unknown until live probe)

A second probe: `kubectl -n eneco-vpp top pod opentelemetry-collector-collector-566b6bd96-2htph --containers` over 5 min → discriminates burst vs sustained CPU pattern.

A third: PromQL `rate(container_memory_working_set_bytes{namespace="eneco-vpp",pod=~"opentelemetry-collector-collector-.*"}[1h])` over last 14 days → tests H-B (memory upstream).

### Q4 — Hidden complexity? What looks simple but is not?

The "Known rule, Novel target" framing **obscures** the fact that **4
memory-pressure alerts fired on the SAME POD in the preceding 10 days**.
"Novel" is technically true (first CPU alert on otc-container) but the
larger pattern is **NOT novel** — it's an escalating memory trend that
the urgency label has not caught up to.

**Step change**: Reframe the pattern section as "trend analysis: this pod
has been escalating since 2026-05-01; today is the latest point in the
trend, not a novel signal."

### Q5 — Version / Currency probe?

| Surface | Version checked? | Status |
|---------|-----------------|--------|
| Rootly API | `rootly-api.sh` against live API today 2026-05-11 | A1 — current |
| Local clones of `enecomanagedcloud/myriad-vpp/*` | Per Sherlock: dated 2025-11-18 | **A3 STALE (6 months)** — cannot make A1 claims about file contents |
| kube-prometheus-stack rule template | Inferred from PromQL — `_config.kubeStateMetricsCpuThrottlingPercent` default 25% | A2 INFER — exact chart version on dev cluster not probed |
| OpenTelemetry Operator version on dev cluster | Not probed | A3 UNVERIFIED — needed for operator-default resources behavior |

**Implication**: the RCA must mark all file-based diagnoses (including
H-D's CR-content dependency) as A3 with the live-probe resolution path.

### Q6 — Silent failure modes? How could the RCA look successful but be wrong?

| Silent failure | How it looks successful | Method to detect |
|----------------|--------------------------|-------------------|
| Reader takes H-A as "the diagnosis" because it's listed first | Reader runs IaC PR to add `cpu: 1` resources; alert quiets for the wrong reason (debug flag still on, memory trend still climbing) | RCA must present H-A through H-D as competing peers in L4-L6; L8 fix section must explicitly say "no fix applied here — name what would change after live probe" |
| Reader treats the rca-holistic skill's own status:complete as adversarial validation | Reader assumes the published RCA is independently reviewed when it's only self-graded by the skill | Front-matter `adversarial_review:` must name BOTH pre-RCA dispatch (this artifact) AND post-draft dispatch (rca-holistic Phase 5); coordinator-only grading triggers `status: review` |
| Wrong file-source attribution sneaks back in because the corpus had it as A1 | Future on-call reads the L5 IaC section, finds the FBE chart, treats it as source of truth | The L5 section must lead with the negative claim "the running CR is not necessarily this file" and the live probe to discriminate |
| The handover decision (Phase 6D) is rationalized again as TERMINAL | RCA reads complete because the user named a path | The RCA explicitly names the enrich-class follow-ups in L11/L12 and acknowledges that those need live probes |

## Adversarial dispatch plan (per Frame Matrix)

| Dispatch | Subagent | Win condition | Artifact path | Timing |
|----------|----------|----------------|---------------|--------|
| Pre-RCA diagnosis attack | sherlock-holmes | Demonstrate the diagnosis is contested or wrong | `context/sherlock-diagnosis-attack.md` | **DONE** — outcome PROBLEMATIC; absorbed above |
| Pre-RCA framing attack | socrates-contrarian | Find framing imports / hidden premises | `context/socrates-framing-attack.md` | **DONE** — outcome PROBLEMATIC; absorbed above |
| Post-draft attack #1 | socrates-contrarian (fresh dispatch on the DRAFTED rca.md) | Per rca-holistic Phase 5: find any A1 that should be A2; any incoherence; any inherited claim un-reprobed | `auxiliary/socrates-post-draft-attack.md` | After P7 draft, before status:complete |
| Post-draft attack #2 | el-demoledor | Per rca-holistic Phase 5: try to break the RCA on every surface (reader, evidence, structure) | `auxiliary/el-demoledor-post-draft-attack.md` | After P7 draft, parallel with socrates |

Verify ≠ adversarial: the rca-holistic skill's own `validate-rca-completeness.sh`
is verification (mechanical structure check); the post-draft typed subagents
are adversarial (destructive win condition). Both required for
`status: complete` per rca-holistic Phase 7 rule.

## Q7 — Orthogonal probe (CRUBVG≥4 trigger — applies here)

**Orthogonal lane**: Slack history search for "CPUThrottlingHigh" /
"otc-container" / "opentelemetry" in `#trade-platform-on-call` and adjacent
channels — does the team have prior discussion of this exact pattern? If
yes, that's prior reasoning the RCA must cite (H-CLAIM-3 refinement, not
silent reinvention). Lane: `eneco-context-slack` skill.

**ROI decision**: this is **deferred to enrich** if user moves there;
within the RCA, name the orthogonal lane as a follow-up recommendation.
`[ROI-NEGATIVE-IF-TERMINAL: named-falsifier = 'enrich phase will run this
probe with full Slack MCP context; running it here adds latency without
flipping the route']`. Honest because the user's deliverable is the RCA at
the named path; the orthogonal Slack probe doesn't change the RCA structure,
only confirms whether prior team reasoning exists.

## L1–L12 level selection per rca-holistic DF2

For this incident class (multi-system, multi-day trend, contested diagnosis):

| Level | Use? | Why |
|-------|------|-----|
| L1 Business | YES | Reader needs to know what Trade Platform is, why an OTel Collector matters |
| L2 Repo system | YES | Three IaC source candidates (Eneco.HelmCharts old, VPP.GitOps FBE, platform-gitops other-namespace); reader must understand the candidate map |
| L3 Runtime architecture | YES | OpenShift cluster, namespace boundaries (eneco-vpp vs eneco-vpp-telemetry), operator-managed CR pattern |
| L4 SDK/code flow | YES (compact) | OTel Collector pipeline: receivers → batch → exporters; explains where verbose debug could burn CPU |
| L5 IaC | YES — heavy adversarial framing | The contested CR source is HERE; L5 must lead with the live-probe as truth surface |
| L6 Pipeline | YES (compact) | GitOps via ArgoCD — relevant for understanding "is the CR I see locally actually deployed?" |
| L7 Timeline | YES | Multi-event (5 firings on this pod since May 1) |
| L8 Fix | **MODIFIED — observation only** | This is an RCA, not a fix shipping with it; L8 names what enrich would do |
| L9 Verification | YES | How a reader verifies each competing diagnosis |
| L10 Lessons | YES | "Pattern: vendor stock urgency description ≠ team calibration"; "Diagnosis collapse before discriminating probe is the trap" |
| L11 Command playbook | YES | Cold-start reproduction; the replay-rootly-intake.sh script already drafted |
| L12 On-call one-pager | YES | Pattern recognition card for next-shift — "you see CPUThrottlingHigh on otc-container, here's the 4-hypothesis-resolver in 2 commands" |

## rca-holistic skill invocation parameters

I will invoke `rca-holistic` at P7 with this evidence package:

- **Mode**: ENRICH (existing diagnostic corpus in `context/p4-evidence-corpus.md` + pre-RCA adversarial reports)
- **Reader**: "Next-shift on-call engineer who has never seen the OTel Collector deployment in eneco-vpp and is paged on this same rule again"
- **Output package level**: `standard` (multi-system, command-heavy, reusable pattern)
- **Input artifacts**: alert-raw.json, alert-payload.json, alert-meta.json, p4-evidence-corpus.md, sherlock-diagnosis-attack.md, socrates-framing-attack.md, p2-map.md, plus the local IaC sources (cited as A2/A3 per staleness)
- **Domain prior**: MEDIUM — I know Eneco's repo layout and the kube-prometheus-stack rule semantics; I do NOT have live cluster access. Mark `domain_prior: low` for any prediction about the running CR's exact spec.
- **Required adversarial dispatches at Phase 5**: socrates-contrarian + el-demoledor on the FULL drafted rca.md (per rca-holistic mandatory rule)

## Verification strategy (for P8)

| Concern | Acceptance | Witness | Truth surface |
|---------|-----------|---------|---------------|
| RCA artifact exists at named path | `test -s output/rca.md` | filesystem | local fs |
| 4 hypotheses presented as competing peers | grep RCA for H-A/H-B/H-C/H-D with comparable depth | adversarial reviewer reading | post-draft dispatch artifact |
| Phase 6D HANDOVER stated explicitly | grep for "HANDOVER" + "live probe" + "enrich" in RCA | reader | RCA prose |
| Live-probe playbook reproducible | replay-rootly-intake.sh runs end-to-end (Rootly probes) | runtime CLI | external tool output |
| Confidence calculated from Evidence Ledger per Rule X12 | RCA includes confidence section with formula | rca-holistic validator | scripts/validate-rca-completeness.sh |
| Mermaid diagrams (if any) parse | `scripts/check-mermaid-syntax.sh output/rca.md` | rca-holistic validator | mmdc parser |
| Adversarial review BOTH pre + post | manifest.gate_witnesses references all 4 dispatch artifacts | manifest jq | manifest schema |
