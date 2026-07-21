---
title: "Fix (STAGED — NOT APPLIED) — DispatcherOutputHealthZero + FBE metric confirmation"
type: fix
status: blocked
blocked_reason: "Awaiting explicit authorization from Alex before any code change, PR push, FF toggle, FBE deploy, or cluster mutation."
task_id: 2026-07-19-002
timestamp: 2026-07-19
---

# Fix — STAGED, NOT APPLIED

> **Nothing in this document has been executed.** No PR was pushed, no feature flag toggled, no FBE
> deployed, no cluster resource changed. It is the verified remediation, awaiting authorization.

Two independent fixes, at two altitudes.

## Fix A — the PromQL (a values-only change to PR 180313)

**Mechanism it closes:** the committed rule `avg_over_time(dispatcher_output_health{...}[2m]) == 0` is a
*filter* over an empty vector when the dispatcher is down → it never fires on total absence (a silent
deadman). It also adds smoothing latency. The dispatcher source confirms the metric is a `Gauge<int>`
valued {0,1}, so `< 1` and `== 0` coincide — `< 1` is preferred because it stays correct if the encoding
ever changes and reads as "not healthy."

**Change (edit `Helm/activationmfrr/acc/values-prometheus-alert-rules.yaml`):** replace the single
`DispatcherOutputHealthZero` entry with a two-alert split (unified label sets):

```yaml
DispatcherOutputHealthZero:            # present but unhealthy
  teamLabel: vpp-core
  for: 2m
  severity:
    critical:
      thresholdValue: "1"
  baseExpr: 'max by (exported_job) (dispatcher_output_health{exported_job="Activation mFRR"})'
  exprOperator: "<"                    # renders: max by (exported_job)(...) < 1
  annotations:
    baseDescription: "Dispatcher output health below healthy (all replicas): "
    unitOfMeasurement: ""

DispatcherOutputHealthAbsent:          # not reporting / down
  teamLabel: vpp-core
  for: 5m
  severity:
    critical:
      thresholdValue: "1"
  baseExpr: 'absent(dispatcher_output_health{exported_job="Activation mFRR"})'
  exprOperator: "=="                   # renders: absent(...) == 1  (== forced by the shared template)
  annotations:
    baseDescription: "Dispatcher output health metric absent (not reporting): "
    unitOfMeasurement: ""
```

Single-alert alternative (template compound slot):
`baseExpr: 'max by (exported_job)(dispatcher_output_health{exported_job="Activation mFRR"})'`,
`exprOperator: "<"`, `thresholdValue: "1"`, `addexprOperator: "or"`,
`additionalValue: 'absent(dispatcher_output_health{exported_job="Activation mFRR"})'`.

**What it does NOT change:** it does not decide `max` (fire only when *all* replicas unhealthy) vs `min`
(fire on *any*) — a Core-team severity call; and it does not cover partial-replica loss (add
`count(...) < <expected>` warning if the metric ever has >1 series — cardinality unverified).

**Proof (once the metric emits):** `promtool check rules`; force health to 0 → `DispatcherOutputHealthZero`
fires after 2m; stop the pod → `DispatcherOutputHealthAbsent` fires after 5m; restore → both clear.

**Rollback boundary:** pure GitOps values change — revert the commit. No state, no data.

## Fix B — make the metric confirmable (a procedure WITH side effects)

**Mechanism:** `dispatcher_output_health` is recorded by `DispatcherOutputHealthEvaluator` off the
service's liveliness/activation paths, and its evaluator is not running in the idle Sandbox build (most
likely feature-flag-gated). Additionally, no FBE runs Julian's branch and no FBE Prometheus loads the
rule.

> **These steps have side effects** — deploying a slot, toggling a feature flag, and driving an
> activation all change live state. That is precisely why each requires authorization. (The *diagnosis*
> above required no mutation; this *procedure* does.)

1. Deploy Julian's branch `feature/820018-dispatcheroutput-health-check-metric` to an FBE slot
   (pipeline 2412) **or** reuse a running slot.
2. Enable the feature flag that runs the health evaluator — **confirm the exact flag name with Core /
   Hein first** (App Configuration is private-endpoint; not readable from here) — and/or exercise a
   liveliness/activation path so `RecordDispatcherOutputHealth` runs.
3. Confirm emission **and continuity**: in that slot's Prometheus,
   `count(dispatcher_output_health{exported_job="Activation mFRR"})` returns > 0 **and stays > 0 across a
   quiet window**; cross-check unfiltered `count({__name__="dispatcher_output_health"})`. Record the
   cardinality.
4. Ensure the FBE's Prometheus loads the alert rule (add it to the sandbox values path the FBE renders).
5. Apply Fix A, then prove fire→clear.
6. Only then merge PR 180313.

## BLOCKING merge precondition

Do **not** merge any `absent()` / `absent_over_time()` arm until step 3 confirms the metric emits
**continuously** (not merely `> 0` once) in a healthy env. A `Gauge<int>` recorded only on
liveliness/activation paths could go stale in quiet periods, and an `absent()` critical on a stale
metric is a false page.

## Explicitly out of scope

The **kidu** `activationmfrr` CrashLoopBackOff (`NullReferenceException` in `AddInfrastructure`) is a
*different* slot on a *different* branch — a config/DI startup failure in the FBE feature-flag class. Do
not touch it under this PR; track separately.

## Authorization checklist (nothing proceeds until each is a yes from Alex)

- [ ] Push the PromQL change (Fix A) to PR 180313
- [ ] Deploy an FBE from Julian's branch (pipeline 2412)
- [ ] Enable the metric/health-evaluator feature flag (name TBD with Core)
- [ ] Merge PR 180313
