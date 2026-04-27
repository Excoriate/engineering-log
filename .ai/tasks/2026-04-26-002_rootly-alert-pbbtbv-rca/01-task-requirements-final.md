---
task_id: 2026-04-26-002
agent: claude-opus-4-7
status: complete
summary: Confirmed RCA scope — investigation-class read-only diagnosis of Rootly alert pbbtBV with explicit Verification Strategy.
---

# Phase 3 — Final Requirements (pbbtBV RCA)

## Phase 2 → 3 transition

Phase 2 revealed: (a) MC-VPP-Infrastructure repo holds 12 distinct `metric-alert-*.tf` files plus a Log-query alert file plus a Service Bus namespace file — so the alert source dimension has more than just Service Bus; (b) `eneco-tools-connect-mc-environments` skill plus the `enecotfvppmclogindev` shell alias both exist for cached dev login; (c) the Rootly MCP exposes `get_alert_by_short_id` which is the one-call shortcut to the payload; (d) the destination directory is empty — no prior RCA shape to inherit. Hypothesis status — H1/H2/H3 all still LIVE (no probe run yet); Phase 4 step 1 (Rootly payload) is the cheapest discriminator that collapses ≥1 hypothesis. No surprises so far; task remains non-trivial because we do not know whether the alert source is Azure Monitor metric, log-query, or non-Azure.

## Confirmed scope

Diagnose Rootly alert short_id `pbbtBV` (URL: https://rootly.com/account/alerts/pbbtBV). Produce a markdown RCA in:
`/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/log/employer/eneco/02_on_call_shift/shift_alerts_summary/2026-April (20-26)/`

Read-only. No git mutations. No IaC edits. No incident creation, no Slack send unless explicitly requested.

## Decisions confirmed against Phase 2 evidence

| # | Decision | Reason | Evidence basis |
|---|----------|--------|----------------|
| D1 | Use `mcp__rootly__get_alert_by_short_id` first | Cheapest discriminator (one call → metric, resource_id, source). | `map-discovery.md` step 1; FACT (tool listed in MCP). |
| D2 | Read-only az posture; no writes | NN-4 + user request is diagnosis only. | `map-config.md`; FACT. |
| D3 | Connect MC dev via skill, NOT direct CLI | User asked to use `/eneco-tools-connect-mc-environments` to cache creds for autonomy. | User instruction; FACT. |
| D4 | Subscription scope determined by alert payload, not assumption | Alert env (dev/acc/prd) is not encoded in URL slug. | INFER from Rootly URL semantics. |
| D5 | IaC reconciliation BEFORE final RCA | Mirror Drift / Source-Blindness guards. | Brain rule; FACT. |
| D6 | Adversarial review on RCA mandatory | CRUBVG=6 ≥5 → CONTRARIAN trigger. | Pre-flight scoring; FACT. |
| D7 | RCA artifact named after alert id | Stable filename ↔ short_id reduces future-lookup ambiguity. | INFER. |

## Verification Strategy

- **F1 (Identity)**: Rootly payload reproducibly fetchable via `mcp__rootly__get_alert_by_short_id` returning `data.attributes` with `summary`, `source`, `started_at`, `state`, and either `payload` or `raw_payload`. Acceptance: non-empty `summary` + `started_at`. Verify-how: tool round-trip. Who: coordinator (read-only).
- **F2 (Resource grounding)**: Alert payload yields a parseable `resource_id` (Azure ARM resource id) OR a metric query target. Acceptance: regex `^/subscriptions/[0-9a-f-]+/resourceGroups/.+/providers/.+` matches one extracted field, OR the alert is provably non-Azure with explicit source. Verify-how: payload inspection + `az resource show --ids`.
- **F3 (Metric breach)**: For Azure-Monitor-class alert, `az monitor metrics list` over [fired_at-30m, fired_at+30m] confirms the breach value at the metric/aggregation referenced by the rule. Acceptance: max/total ≥ threshold (or ≤ for low-watermark) within window. Verify-how: az CLI in MC dev.
- **F4 (IaC threshold reconciliation)**: Threshold extracted from payload matches an `azurerm_monitor_metric_alert.criteria.threshold` (or `query_alert` equivalent) in `terraform/metric-alert-*.tf` referencing a variable in `configuration/<env>-alerts.tfvars`. Acceptance: exact numeric equivalence. Verify-how: file:line citation.
- **F5 (Hypothesis ledger closure)**: H1/H2/H3 all classified `[CONFIRMED|ELIMINATED|UNVERIFIED]` with named evidence. Acceptance: each row carries a probe and outcome.
- **F6 (Adversarial)**: socrates-contrarian dispatch with distinct win condition ("break the RCA — find a hypothesis incorrectly closed, or a load-bearing claim unfalsified") returns ≥1 attack vector with documented response (Accepted/Rebutted/Deferred). Acceptance: receipt block in verification artifact.
- **F7 (Activation Checklist)**: All NN-1..7 + brain gate rows PASS pre-delivery, including externally-witnessable probes for top-3 load-bearing claims, distinct verify-vs-adversarial win conditions.

## Acceptance criteria for the RCA artifact

1. Front-matter (`task_id`, `agent`, `status`, `summary`).
2. Sections: Identity / Mechanism / Evidence (with file:line + az output anchors) / Hypothesis Ledger / Recommended Action / Residual Risk.
3. Every load-bearing claim labelled FACT/INFER/UNVERIFIED.
4. At least one cross-reference into IaC (`metric-alert-*.tf` line + `<env>-alerts.tfvars` line).
5. State of alert at write-time (firing / resolved / suppressed) explicit.

## Hypotheses (carried forward)

- H1 (Service Bus / messaging metric): live.
- H2 (Other Azure resource — AGW / App Insights / Cosmos / Cosmos-Mongo / Key Vault / Storage / SQL / Kusto / SignalR / Event Hub / Log-query): live.
- H3 (Synthetic / heartbeat / non-Azure): live, but lowest prior given Rootly is wired to Azure Monitor in MC.

## Out of scope

- Remediation IaC PR.
- Re-tuning thresholds.
- Cross-environment audit beyond the firing env.
- Slack auto-reply — only manual action by user after reading RCA.
