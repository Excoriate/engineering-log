---
title: RCA adversarial receipts — socrates + el-demoledor
type: review
status: complete
task_id: 2026-07-19-002
agent: claude-opus-4-8
summary: Disposition of the two Phase-5 RCA adversaries; both PROCEED-WITH-CHANGES; the shared unknown (metric type + emission cadence) was resolved by reading the dispatcher source.
timestamp: 2026-07-19
---

# RCA adversarial receipts

Both adversaries independently pointed at the same missing fact — *what is this metric, and how does it
emit?* — which I then settled by reading `Eneco.Vpp.Core.Dispatching` source.

## Source facts that resolved the reviews (A1)

- `dispatcher.output.health` is a **`Gauge<int>`**, domain **{0,1}** ("1=healthy, 0=unhealthy"), meter
  `Activation.mFRR.Metrics`, defined in the **Activation.mFRR** app → emits under
  `exported_job="Activation mFRR"`. [`MetricsConstants.cs`, `PortfolioRequestMetrics.cs`]
- Recorded by `DispatcherOutputHealthEvaluator.IsHealthy` (reads ASP.NET `HealthCheckService`, records
  1/0, records 0 if the health entry is missing), invoked from the **V1 liveliness endpoints**
  (`GetLiveliness` for Activations + Deactivations) and the **activation command handler** — NOT an
  unconditional periodic timer. [`DispatcherOutputHealthEvaluator.cs`, endpoint/handler callers]

## socrates (verdict PROCEED-WITH-CHANGES)

| Finding | Disposition | Evidence |
|---------|-------------|----------|
| Selector `exported_job="Activation mFRR"` may be wrong — sibling domain gauges use `"Dispatcher mFRR"` | **RESOLVED (confirmed correct)** | Metric is defined in the Activation.mFRR app; live `exported_instance=activationmfrr-…` ↔ `exported_job="Activation mFRR"`. The "dispatcher" in the name describes what it measures, not the emitter. |
| E13 confirmation probe should be unfiltered | **ACCEPTED** | Fix's confirmation step now also runs `count({__name__="dispatcher_output_health"})` unfiltered as a cross-check. |
| `TSOLivenessCheck` (same PR) unreviewed | **ACCEPTED (noted)** | `tso.livenesscheck.received.count` is a **Counter**; its `rate(...) * 120 <= 1` form is a rate-deadman, a different pattern — flagged in the RCA as adjacent, same-selector-family, out of this deliverable's scope. |

## el-demoledor (verdict PROCEED-WITH-CHANGES)

| Finding | Disposition | Evidence / change |
|---------|-------------|-------------------|
| D1/D2: `absent()` + `count>0` precondition can **page-storm prod** if the metric is traffic-gated | **ACCEPTED — strengthened** | Confirmed the gauge is recorded via liveliness/activation paths, so emission is **not guaranteed continuous**. Merge precondition upgraded: confirm the metric emits **continuously over a quiet window**, not just `count>0`. |
| D3/D4: `<1`/`max` present-arm ships on unverified value domain + cardinality | **RESOLVED (domain) / DEFER (cardinality)** | Source shows `Gauge<int>` {0,1} → `<1 ≡ ==0`, no float brittleness. Cardinality still A3 (confirm series count when it emits). |
| D5: "nothing to roll back" ignores activation-injection / FF / slot-reuse side effects | **ACCEPTED** | `fix.md` corrected: the *diagnosis* required no mutation; the *fix procedure* (drive activation, enable FF, deploy/reuse slot) has side effects — that is precisely why it is gated on authorization. |
| D6: L11 not cold-runnable without cluster auth + slot discovery | **ACCEPTED** | L11 now opens with a Step 0 (establish `az`/`kubectl` context + discover slot pods) and a freshness probe before every remote read. |

## Net

Both PROCEED-WITH-CHANGES; all CRITICAL/HIGH findings absorbed with source or live evidence; no finding
Rebutted without evidence; the one strengthened risk (emission-cadence → `absent()` safety) is the most
valuable output of the pass and is now the RCA's headline merge precondition.
