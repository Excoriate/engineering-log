---
title: Synthesis & recommendation — PromQL + FBE metric block
type: analysis
status: complete
task_id: 2026-07-19-002
agent: claude-opus-4-8
summary: The verified most-solid PromQL form for DispatcherOutputHealthZero and the root-cause diagnosis of why dispatcher_output_health cannot be confirmed on any Sandbox FBE, with a staged (unauthorized) fix.
timestamp: 2026-07-19
---

# Synthesis & recommendation

## Deliverable 1 — the most solid, verified PromQL

### What is committed today (A1)
```promql
avg_over_time(dispatcher_output_health{exported_job="Activation mFRR"}[2m]) == 0   # for:2m, severity:critical
```
Rendered by the shared chart `Eneco.Vpp.Core.Dispatching/helm/prometheus-alert-rules/templates/prometheus-rule.yaml`
as `printf "%s %s %s" baseExpr exprOperator thresholdValue`.

**Defect (Alex is right):** on total absence, `avg_over_time` emits **no series** (empty),
so `∅ == 0` is empty → a fully-down / not-reporting dispatcher **does NOT page**. That is
the single most important case for a *critical* health alert, and it is silent.

### Alex's proposed fix — logically correct, operationally fragile
`… == 0 or absent_over_time(…[2m]) == 1` is **logically sound** (russell: precedence
`(A==0) or (B==1)` correct; arms provably mutually exclusive so `or` is collision-safe;
librarian: all doc-semantics confirmed) **but** carries 4 operational defects: absent-arm
self-DoS when the metric isn't emitting yet (FM1), label-flap `for:`-reset (FM2), double
dwell ~4m (FM3), float-brittle `==0` (FM4), and a partial-replica blind spot (FM5/Case5).

### Recommended form (most solid) — two alerts, unified labels, robust threshold
```yaml
# values-prometheus-alert-rules.yaml (acc; mirror to prod when un-commented)
DispatcherOutputHealthZero:          # dispatcher present but unhealthy
  teamLabel: vpp-core
  for: 2m
  severity: { critical: { thresholdValue: "1" } }
  baseExpr: 'max by (exported_job) (dispatcher_output_health{exported_job="Activation mFRR"})'
  exprOperator: "<"                  # renders: max by(exported_job)(...) < 1
  annotations: { baseDescription: "Dispatcher output health below healthy (all replicas unhealthy).", unitOfMeasurement: "" }

DispatcherOutputHealthAbsent:        # dispatcher not reporting / down
  teamLabel: vpp-core
  for: 5m                            # longer: tolerate rolling deploys / scrape gaps
  severity: { critical: { thresholdValue: "1" } }
  baseExpr: 'absent(dispatcher_output_health{exported_job="Activation mFRR"})'
  exprOperator: "=="                 # renders: absent(...) == 1  (==1 forced by template)
  annotations: { baseDescription: "Dispatcher output health metric absent (not reporting).", unitOfMeasurement: "" }
```
Single-alert alternative (if one alertname is preferred) via the template's `additionalValue` slot:
`baseExpr: 'max by (exported_job)(…)'`, `exprOperator: "<"`, `thresholdValue: "1"`,
`addexprOperator: "or"`, `additionalValue: 'absent(dispatcher_output_health{exported_job="Activation mFRR"})'`
→ renders `max by (exported_job)(…) < 1 or absent(…)` (both arms carry `{exported_job="Activation mFRR"}` — unified).

**Why this is the most solid:** `max by (exported_job)` gives a stable label set (kills the
`for:`-reset); `< 1` (not `== 0`) is robust to fractional/negative gauge values and encodes
"never healthy"; instant gauge + single `for:` removes the double dwell; the split gives the
absent case its own longer `for:` to avoid deploy-time false pages.

**Design choice to confirm with Core:** `max by(exported_job)` fires only when *all* replicas
are unhealthy (conservative). If any single unhealthy replica should page, use `min by`. If
replicas can be >1, add `DispatcherOutputHealthReplicaLoss: count(...) < <expected>` (warning).

### BLOCKING merge precondition (russell + sre converge)
Do **not** merge any `absent(...)`/`absent_over_time(...)` arm until
`count(dispatcher_output_health{exported_job="Activation mFRR"}) > 0` returns data in a
healthy env — otherwise the absent arm is a permanent false CRITICAL (self-DoS on the pager).
Also confirm the committed YAML uses lowercase `or` (uppercase `OR` = parse error) and run
`promtool check rules`.

## Deliverable 2 — why the metric can't be confirmed (root cause) + staged fix

### Root cause (A1/A2)
- **No FBE runs Julian's branch** `feature/820018-…`; every slot runs a different branch → Julian has **no running FBE of his own** to test in.
- **`dispatcher_output_health` is not emitted** by the Activation mFRR service in any idle Sandbox FBE (jupiter/boltz `main`, thor/veku `1.2.feat`, ishtar `1.1.feat` — all absent). The service emits **only OTel-auto-instrumented messaging metrics** (`messaging_eventhub_*`, `messaging_kafka_*`, `target_info`) under `exported_job="Activation mFRR"` (114 series). The pipeline (app→OTel→per-slot Prometheus) and the exact `exported_job` label are healthy — the block is upstream: the business health gauge is **feature-flag- and/or activation-traffic-gated** and is not produced at idle (matches Hein=FF, Stefan=traffic).
- **No FBE Prometheus loads the activationmfrr alert rules** (only `monitoring-stack` has 32 default kube-prometheus-stack rules; no `<slot>-monitoring` has any dispatcher rule) → even a deployed branch wouldn't evaluate the alert without wiring the rule into the FBE monitoring values (sandbox path).

### Adjacent (separate issue, NOT Julian's)
- **kidu** `activationmfrr` CrashLoopBackOff (610+ restarts): `System.NullReferenceException` in `AddInfrastructure` (`ServiceCollectionExtensions.cs:42`) at startup → a config/DI gap (different branch `fbe-849399`). Member of the FBE config/feature-flag class (cf. LL-036 App-Config-on-FBE).

### Staged fix (DO NOT APPLY until authorized)
There is **no destructive cluster fix** required — nothing is broken to roll back. The
"fix" is a procedure to make the metric confirmable, then validate the corrected alert:
1. Deploy Julian's branch to an FBE slot (pipeline 2412) **or** reuse a running slot.
2. Enable the feature flag that emits `dispatcher_output_health` (confirm exact flag with Core/Hein) **and/or** drive an mFRR activation so the dispatcher produces output.
3. Confirm emission: `count(dispatcher_output_health{exported_job="Activation mFRR"}) > 0` in that FBE's Prometheus; capture the true cardinality + value domain.
4. Ensure the FBE monitoring loads the alert rule (add it to the sandbox values path if the FBE renders from there).
5. Apply the corrected PromQL (Deliverable 1), then prove fire→clear by toggling health.
6. Only then merge PR 180313.

Nothing above has been executed; awaiting authorization.
