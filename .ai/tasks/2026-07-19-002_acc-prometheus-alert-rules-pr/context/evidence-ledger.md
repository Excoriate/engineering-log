---
title: Evidence Ledger — ACC Prometheus alert rules PR (180313)
type: analysis
status: partial
task_id: 2026-07-19-002
agent: claude-opus-4-8
summary: A1/A2/A3 evidence for validating the DispatcherOutputHealthZero PromQL and diagnosing why dispatcher_output_health cannot be confirmed on any Sandbox FBE.
timestamp: 2026-07-19
---

# Evidence Ledger — ACC Prometheus alert rules PR (180313)

Scope: (1) validate the `DispatcherOutputHealthZero` PromQL as the most-solid approach;
(2) diagnose why the metric cannot be confirmed on an FBE + stage a verified fix (do NOT apply).

## A1 — FACT (externally witnessed)

### PR / code (ADO, VPP-Configuration, Myriad - VPP)
- **PR 180313**: `active`; branch `feature/820018-dispatcheroutput-health-check-metric` → `main`; head `af3bf0f`; author Julian; repo `VPP-Configuration` (id `6b401df9…`). [`az repos pr show`]
- **Committed ACC rule** `DispatcherOutputHealthZero` @af3bf0f: `baseExpr: 'avg_over_time(dispatcher_output_health{exported_job="Activation mFRR"}[2m])'`, `exprOperator: "=="`, `thresholdValue: "0"`, `for: 2m`, `severity: critical` → **renders `avg_over_time(dispatcher_output_health{exported_job="Activation mFRR"}[2m]) == 0`**. [ADO items @commit]
- PR also edits `prod/values-prometheus-alert-rules.yaml`, but `DispatcherOutputHealthZero` + `TSOLivenessCheck` are **commented out** in prod; only `ActivationMfrrR3HandlerHeartbeatRateDecrease` is active there. [ADO items @commit]
- **Alex's PR comment** (thread 1328414, status `active`/unresolved) on the ACC file: rebuts Julian's `… or absent_over_time(…) * 0` as syntactically broken + semantically wrong; proposes:
  `avg_over_time(dispatcher_output_health{exported_job="Activation mFRR"}[2m]) == 0 or absent_over_time(dispatcher_output_health{exported_job="Activation mFRR"}[2m]) == 1`. **Not yet committed.** [ADO PR threads]
- `/Helm/activationmfrr/{dev,acc,prod,sandbox}/` holds only `values.yaml`, `values-override.yaml`, `values-prometheus-alert-rules.yaml` — **no `templates/`**. The shared rendering template = `Eneco.Vpp.Core.Dispatching` → `/helm/prometheus-alert-rules/templates/prometheus-rule.yaml` (also mirrored under `azure-pipeline/Helm/prometheus-alert-rules/`). [ADO tree + code search]

### Cluster (Sandbox FBE AKS `vpp-aks01-d`, authinfo `rg-vpp-app-sb-401`)
- kubectl current-context `vpp-aks01-d`; `az` = `Alex.Torres@eneco.com`. [kubectl/az]
- FBE slots (each `<slot>` + `<slot>-monitoring` w/ Grafana + OTel collector + Prometheus): afi, boltz, ionix, ishtar, jupiter, kidu, operations, thor, veku. [`kubectl get ns`]
- **No slot runs Julian's branch** `feature/820018-…`. Slot→branch: thor `fbe-862806`, veku `fbe-861767-l4`, kidu `fbe-849399`, jupiter `fbe-856615`, boltz `fbe-851245`, ishtar `fbe-860509`, operations `fbe-861767-l3`. [`kubectl get applications -n argocd`]
- `activationmfrr` run-state: **Running** in boltz/ishtar/jupiter/thor/veku; **CrashLoopBackOff** in kidu (2 pods, 610+ restarts); **absent** in operations. [`kubectl get pods -A`]
- Images: jupiter/boltz `main.447bd6a`; thor `1.2.feat.7e56ac8`; veku `1.2.feat.c2aa5fa`; ishtar `1.1.feat.c5c7433`; kidu `1.2.feat.0d48104`. [kubectl]
- **kidu crash**: `System.NullReferenceException` at `Activation.mFRR.Infrastructure.ServiceCollectionExtensions.AddInfrastructure` (`ServiceCollectionExtensions.cs:42`) ← `Program.<Main>$` (`Program.cs:67`); startup probe `connection refused :8080/healthz`; lastState `exitCode 139`. Config/DI startup crash (different branch → separate issue). [`kubectl logs --previous` / `describe`]

### Metric reality (per-slot Prometheus via promtool)
- jupiter Prometheus queryable: `count(up)=3`. [promtool]
- `exported_job="Activation mFRR"` = **114 series across 17 metric names — ALL messaging/plumbing**: `messaging_eventhub_consumer_handle*`, `messaging_eventhub_producer_*`, `messaging_kafka_consumer_*`, `messaging_kafka_message_processed_*`, `target_info`. [promtool `group by(__name__)`]
- `{exported_job="Activation mFRR", __name__=~".*(output|health|dispatch).*"}` = **EMPTY**. [promtool]
- `dispatcher_output_health` = **EMPTY** across every probed slot & build age: jupiter/boltz (`main.447bd6a`), thor/veku (`1.2.feat`), ishtar (`1.1.feat`). [promtool]
- Domain metrics (`activation_amount_mw`, `activationresponse_cycle_*`, `activation_mfrr_portfolio_deviation_value`) belong to `exported_job="Dispatcher mFRR"`, **not** `"Activation mFRR"`. [promtool `group by(exported_job)`]
- Pipeline healthy: `exported_job` values include Activation mFRR, Dispatcher aFRR/mFRR/Scheduled/Manual, AssetService, MarketInteraction, etc. [promtool]

## A2 — INFER (derived, reasoning named)
- **The committed alert is defective**: `avg_over_time(…) == 0` returns empty when the metric is absent (`==` is a filter over an empty vector) → a fully-down dispatcher **does not page**. Alex's critique is correct; his fix is not yet applied. [committed form + range/filter semantics]
- **Metric-not-confirmable root cause**: `dispatcher_output_health` is not emitted by the running Activation mFRR service in idle Sandbox FBEs; only OTel-auto-instrumented messaging metrics flow. Emission is gated by a **feature flag and/or activation traffic** (dispatcher emits output health only under mFRR activity). Robust across all build ages → not a version lag. [live metric list + thread: Hein=FF, Stefan=traffic]
- **Deploy-order hazard (confirmed by sre-maniac)**: shipping the absent-aware alert *before* the metric emits makes the **critical** alert fire immediately/continuously (`absent_over_time(…) == 1` always true when 0 series). The absent arm is only safe once the metric is confirmed flowing. [absent semantics + metric currently absent]
- **Deployable fix form (values-only)**: keep the shared-chart template; set `baseExpr: 'avg_over_time(…[2m]) == 0 or absent_over_time(…[2m])'`, `exprOperator: "=="`, `thresholdValue: "1"` → renders `… == 0 or absent_over_time(…) == 1` (precedence: `==` binds tighter than `or`). Pending confirmation against `prometheus-rule.yaml`. [template model — A2 until template read]

## A3 — UNVERIFIED[blocked]
- Exact shared-chart rendering of `baseExpr/exprOperator/thresholdValue` (incl. any label injection / `for` handling) — template located, fetch pending.
- Exact feature-flag name gating `dispatcher_output_health` — App Config data-plane is private-endpoint (blocked). Resolves via Core team / Hein or App Config read from AVD.
- Whether an FBE was ever created from Julian's branch (pipeline 2412 history) — not probed.

## Open (route-flip, now moot)
- Which slot is Julian's — **moot**: branch deployed nowhere; metric absent regardless of slot.
