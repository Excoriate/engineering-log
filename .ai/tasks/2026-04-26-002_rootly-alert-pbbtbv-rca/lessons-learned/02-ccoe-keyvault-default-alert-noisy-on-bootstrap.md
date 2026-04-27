---
task_id: 2026-04-26-002
agent: claude-opus-4-7
status: complete
type: finding
summary: CCoE terraform-azure-keyvault module ships hardcoded ServiceApiLatency Avg>1000ms PT5M alert that mathematically false-fires on low-volume bootstrap KVs.
---

# CCoE keyvault default alert is noisy on bootstrap KVs

**Fact**: `enecomanagedcloud/ccoe/terraform-azure-keyvault/locals.tf:22-40` defines `default_metric_alerts.kv-latency-above-1000ms` with `criteria=[ServiceApiLatency Average GreaterThan 1000ms over PT5M]`, no `failing_periods`, `auto_mitigate=true`, hardcoded across every product/env via `terraform-bootstrap` (`?ref=v0.4.0`) and `platform-bootstrap`. Bootstrap KVs (vppagg, vppfo, vppidd, gurobi, astsch) have ~1 ServiceApiHit per day; any single slow request (e.g., a 2712 ms `vaultget`) makes the 5-min bucket Average = the single-sample latency, breaches threshold, and the rule fires.

**Why**: The rule's contract assumes "many samples per window"; consumers are heterogeneous. Bootstrap KVs are by design rarely accessed.

**How to apply**:
- Recurrence: ~2 firings per ~3.5 weeks across all products' bootstrap KVs (Rootly `Anjhdp` 2026-04-02 kv-gurobi-platform-a; `pbbtBV` 2026-04-26 kv-vppagg-bootstrap-d). Sporadic but structural.
- When this rule fires on a bootstrap KV, almost always a benign single-sample false positive. Verify via `az monitor metrics list --metric ServiceApiHit --aggregation Total --interval P1D` over 30 days and confirm baseline ≤ 5 hits/day.
- Real fix is module-owner work. Cheapest viable repair: add a second `criteria` block on `ServiceApiHit Total ≥ N` (count gate); preserves intent without LAW dependency. Avoid switching aggregation to `Maximum` — that makes the rule MORE outlier-sensitive.

**Promote to durable memory**: yes — useful across all future Eneco on-call shifts where any bootstrap KV's `kv-*-latency-above-1000ms` alert fires.
