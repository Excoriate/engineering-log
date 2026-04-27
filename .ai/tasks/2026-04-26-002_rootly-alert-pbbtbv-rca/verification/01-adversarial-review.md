---
task_id: 2026-04-26-002
agent: socrates-contrarian
status: complete
summary: Five new attacks the author missed — strongest is Rootly-resolve does not converge Azure-side alert state; rec #1 KQL silently fails if Diagnostic Settings absent; rec #3 Maximum aggregation aggravates rather than fixes the false-positive class.
---

# Adversarial Review — pbbtBV RCA

Win condition (distinct from "verify"): **break the RCA**. Below are NEW attacks not in plan.md's 6Q.

## Findings

### F1 — MAJOR — "Resolve in Rootly" does NOT converge the Azure-side alert state

**Under attack**: Recommended Action → Now, steps 1-2 (L56-64); TL;DR (L22).

**Argument**: Live Azure state is `state=New, monitor=Fired` (L38). Resolving in Rootly closes the **downstream notification record only**; it does not PATCH `Microsoft.AlertsManagement/alerts/3d8b33a6...`. Azure-side alert remains Fired until either a future evaluation drops ≤1000 — impossible per §5 (no traffic) — or someone manually closes via Portal / `az rest`. Operational consequences: Azure Monitor dashboards still show Fired; secondary action-group routes can re-page; future Azure state transitions can re-notify Rootly with confusing context.

**Falsifier**: `az rest GET .../alerts/3d8b33a6.../?api-version=2018-05-05` ≥30min after Rootly-resolve. Right ⇒ `alertState != Closed`; wrong ⇒ `Closed`. Missing probe.

**Fix**: add step "Close Azure-side alert via Portal or `az rest PATCH .../alerts/<id>/changestate?...&newState=Closed`."

---

### F2 — CRITICAL — Upstream rec #1 (KQL) silently fails on KVs without Diagnostic Settings

**Under attack**: Upstream Recommendation #1 (L85-93), labelled "Pick #1 for correctness".

**Argument**: `AzureMetrics` is populated **only** when the resource has a Diagnostic Setting routing `AllMetrics` to a Log Analytics workspace. E9 states no diag-setting probe ran; absent `AzureDiagnostics` (KV `AuditEvent`) suggests no diag setting exists for these KVs. If absent, the scheduled-query rule evaluates against an empty table, returns zero rows, **never fires** — opposite-polarity silent failure (worse than today's noise). Rec #1 has an unstated prerequisite.

**Falsifier**: `az monitor diagnostic-settings list --resource <kv-id>`. Right ⇒ `[]` or no `AllMetrics→LAW` route; wrong ⇒ route exists. Missing probe.

**Fix**: prepend prerequisite — "requires `AllMetrics → Log Analytics` Diagnostic Setting on every consuming KV; module must enforce this together with the rule, or skip where absent."

---

### F3 — MAJOR — Upstream rec #3 ("Maximum + count gate") aggravates the false-positive class

**Under attack**: Upstream Recommendation #3 (L95-96).

**Argument**: With `Maximum` + `ServiceApiHit Total ≥ N`, the rule fires whenever **any single** call exceeds 1000ms AND count ≥ N — one slow outlier in a healthy burst trips it. That is **more** outlier-sensitive than today's `Average`, not less. Bootstrap-vault case unchanged (count gate still blocks); hot-path KVs become noisier. Author appears to have conflated "Maximum" with "Maximum-of-bucket-averages". Correct shape: **keep `Average`, add the count gate** — sustained-mean AND adequate-sample-size matches the intent.

**Falsifier**: prototype `Max>1000 AND Count≥5` on synthetic 5-call vault (4@200ms, 1@1500ms). Right ⇒ fires; wrong ⇒ does not fire. Missing probe.

**Fix**: rewrite #3 as "keep `Average`, add `ServiceApiHit Total ≥ N` count gate". Drop `Maximum`.

---

### F4 — MINOR — Mechanism §5 under-specifies Azure no-data semantics

**Under attack**: Mechanism §5 (L50).

**Argument**: Azure Monitor evaluates every `evaluationFrequency` regardless of new samples; the lever is **no-data handling**, not "nothing to evaluate". Default static-criteria no-data behavior preserves prior `Fired` state — that is why `auto_mitigate` does not act. Author's framing is operationally close but mechanically imprecise; could mislead a reader into thinking "synthetic traffic" is the only lever when no-data config is also one.

**Falsifier**: Microsoft Learn doc on metric-alert no-data behavior. Right ⇒ knob exists; wrong ⇒ docs confirm static criteria genuinely cannot evaluate without samples. Missing probe.

**Fix**: rephrase §5: "auto_mitigate requires the criterion to evaluate to FALSE; with no samples, default no-data behavior preserves the prior Fired state, so the alert does not auto-resolve."

---

### F5 — MINOR — H2 "CONFIRMED" overclaims given unprobed H4 (regional Azure latency)

**Under attack**: Hypothesis Ledger row H2 (L184).

**Argument**: H2 is confirmed only relative to H1 and H3. Author's own Residual Risk admits an unprobed alternative — westeurope KV control-plane micro-incident — effectively H4. Verified Root Cause requires independent disconfirmation; H4 is not disconfirmed. CONFIRMED conflates "best-supported among examined" with "verified to exclusion".

**Falsifier**: Azure Service Health for westeurope at 2026-04-26T03:50Z. Right ⇒ no event; wrong ⇒ event (H2+H4 may both hold). Missing probe.

**Fix**: downgrade H2 to "STRONGLY SUPPORTED — pending H4 disconfirmation".

---

## What I tried but couldn't break

- Mechanism §1-§4: rule definition, breach arithmetic, single-call evidence — tight; payload, az output, IaC reconcile byte-for-byte.
- IaC source chain: locals.tf:22-40 + alerts.tf:126-160 verbatim; `for_each = local.default_metric_alerts` confirmed.
- Action group routing: `ag-trade-platform-d` → `rootly-trade-platform` consistent with payload `routing_rules`.
- "Don't bump threshold in MC-VPP-Infrastructure/main": correct — local file covers `aks-kv` only.
- Rec #4 (`default_metric_alerts_enabled` flag): clean — module already has the `for_each` seam.
- Author's 6Q (Q1-Q7): already attacked; not re-litigated.

---

Verdict: REQUEST CHANGES
