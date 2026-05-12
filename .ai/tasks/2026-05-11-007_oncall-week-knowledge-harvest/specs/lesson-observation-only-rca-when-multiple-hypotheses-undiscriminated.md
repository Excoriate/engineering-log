---
task_id: 2026-05-11-007
agent: claude-code
status: complete
summary: Spec for new vault lesson — when multiple causal hypotheses are not yet discriminated, the correct RCA shape is observation-only (install the discriminator + the mental model, no fix recommendation). Shipping a fix before discrimination ships the wrong fix and masks the real cause. Ready to apply to llm-wiki/learnings/lessons/.
spec_target_path: $SECOND_BRAIN_PATH/llm-wiki/learnings/lessons/observation-only-rca-when-multiple-hypotheses-undiscriminated.md
spec_action: create
spec_zone: learnings/lessons
spec_status: ready_to_apply
---

# Spec — Lesson: Observation-Only RCA When Multiple Hypotheses Are Undiscriminated

## Frontmatter (apply verbatim)

```yaml
---
description: "When an incident's RCA would have to choose between multiple uneliminated causal hypotheses, the correct RCA shape is observation-only: install the discriminator probes + the reader's mental model, but ship NO fix recommendation. Shipping a fix before discrimination ships the wrong fix and masks the real cause. Today's CPU throttling RCA (otc-container, eneco-vpp namespace, dev cluster) carries 4 uneliminated hypotheses (H-A undersized CPU limit, H-B memory pressure upstream, H-C rule mis-calibrated for sidecar class, H-D debug exporter verbose); each implies a different fix; choosing one without discrimination would have shipped wrong code. The RCA installs the next-shift on-call's mental model and the cold-start command playbook instead."
type: lesson
domain: tech
status: active
source: agent
created: 2026-05-11
last_validated: 2026-05-11
severity: high
confidence: validated
tags: [eneco, vpp, rca, methodology, hypotheses, discriminator, observation-only, otel-collector, cpu-throttling, dev-cluster]
---
```

## The Rule

If the next action depends on which of N hypotheses is true, and N > 1 and none is eliminated, **do not ship a fix in the RCA**. Ship the discriminator instead. The RCA's job is to install the next-shift's mental model and the cheapest path to discrimination — not to guess.

## Why (mechanism)

Each hypothesis maps to a different fix surface:

| Hypothesis | Fix surface | Cost of being wrong |
|-----------|-------------|---------------------|
| H-A: CPU limit too tight | Add `spec.resources.limits.cpu` | If actually H-B, raising CPU delays the next memory alert without fixing root |
| H-B: Memory pressure upstream → GC bursts | Investigate heap + tune `memory_limiter` processor + raise memory limit OR find upstream services emitting high-cardinality metrics | If actually H-A, you over-investigated memory and still get throttled |
| H-C: PrometheusRule mis-calibrated for sidecar class | Add exclusion to kube-prometheus-stack rule for observability containers | If actually H-A/B/D, real pressure exists and the alert just stops paging while the pressure continues |
| H-D: Debug exporter verbose | Flip `spec.config.exporters.debug.verbosity` from `detailed` → `basic` | If actually H-A/B/C, the debug fix does nothing |

Hypothesis dependency matters too — H-A is the SYMPTOM (pressure exceeded limit); H-B and H-D are CANDIDATE UPSTREAM CAUSES; H-C is ORTHOGONAL (rule itself, not this pod). So even confirming H-A doesn't tell you what to fix.

**Adjudication heuristic** (today's RCA, durable): run all four probes; if H-D confirms, ship the debug fix first (cheapest, most reversible). If H-B confirms with H-A, do NOT raise CPU until memory is understood. If H-C confirms cluster-wide, the rule itself is the actionable issue.

## How to apply

### When you receive a paged incident

1. **List candidate hypotheses BEFORE drafting any fix** — write them down with their mechanism and falsifier
2. **For each hypothesis, name the cheapest discriminator probe** — single-line if possible
3. **If ≥2 hypotheses remain after cheap discrimination, ship observation-only RCA**:
   - L1-L9 of the RCA still get filled (business, repo, runtime, code flow, IaC, pipeline, timeline, fix-shape-per-hypothesis, verification)
   - L8 is **observation-only**: list the fix SHAPE per hypothesis but recommend NONE
   - L9 verification is per-hypothesis probes (the discriminators)
   - L11 cold-start playbook drives the next-shift on-call through the discriminator path
4. **Acknowledge the alert** in Rootly (or equivalent) but do NOT resolve it
5. **Hand off to the next on-call** with the RCA as the canonical context

### RCA L8 template for observation-only

```markdown
## L8 — Fix — observation only, no prescription

**No fix ships with this RCA.** The discriminating probes in L9 must run first; N competing hypotheses imply N different fixes. Recommending one before discrimination ships the wrong fix and masks the real cause.

**What would change under each hypothesis** (descriptive only):

| Hypothesis | Fix shape | Sizing input | What it does NOT fix |
| ... | ... | ... | ... |

**What this RCA does NOT change**: no PR is shipped; no threshold is recommended; no runtime mutation is performed.

**What this RCA DOES install**: the next-shift on-call's mental model. After reading, the on-call runs the discriminator BEFORE recommending a fix. That sequencing is the correct first action.
```

## What to avoid

- **"Just raise the limit and see what happens"** — this is fix-by-default-on-symptom. It works for transient issues but is exactly wrong when the symptom is a downstream artifact of an upstream cause.
- **Picking the most-likely hypothesis without elimination** — "I think it's H-A, let me try the H-A fix and see" → if H-B is the real cause, H-A fix masks the symptom for hours/days, then the real cause re-emerges differently.
- **Treating observation-only as a failure of the on-call** — it's the OPPOSITE: shipping observation-only RCA when hypotheses are undiscriminated is the **disciplined** choice. The failure mode is shipping a guess.

## Cross-Links

- [[2026-05-11-oncall-shift-trade-platform-quad-incident]] — episode of origin (Incident 3)
- [[routing-label-is-not-severity-grading]] — sibling lesson from same RCA
- [[causal-arrow-from-snapshot-can-be-falsified-by-timeline]] — sibling lesson from same RCA
- [[name-match-is-not-deployment-proof-cluster-api-is-authoritative]] — sibling lesson from same RCA
- [[oncall-rca-must-close-on-every-state-plane]] — adjacent operational discipline
- Source RCA: `log/employer/eneco/02_on_call_shift/2026_05_11_rootly_alert_cpu_throtling/output/rca.md` (925 lines)
