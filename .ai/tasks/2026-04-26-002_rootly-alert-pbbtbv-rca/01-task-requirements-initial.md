---
task_id: 2026-04-26-002
agent: claude-opus-4-7
status: draft
summary: Initial pre-flight for Rootly alert pbbtBV RCA — investigation-class diagnostic with az-cli + rootly MCP probe path.
---

# Phase 1 — Initial Requirements (pbbtBV RCA)

## Pre-Flight (mirrored from terminal)

- Phase: 1 | Brain: 67.4.0 | task_id: 2026-04-26-002
- Request: Diagnose ongoing Rootly alert https://rootly.com/account/alerts/pbbtBV. Connect to MC dev (cache creds via `eneco-tools-connect-mc-environments`), use az-cli + Eneco skills. Produce RCA written into the shift_alerts_summary 2026-April (20-26) directory. User wants autonomy ("don't need to babysit").
- USER PRE-FRAMING: "rich variety of skills" + "don't need to babysit" + "rich variety of eneco's skills" — autonomy push, NOT complexity-minimizing. Framing does not waive phase gates.
- DOMAIN-CLASS: investigation
- ROOT-ARTIFACT: n
- CRUBVG: C/R/U/B/V/G = 1/0/2/1/1/1 → Total: 6
  - C=1: Rootly + Azure Monitor + IaC tfvars + on-call channel context
  - R=0: read-only diagnosis (no remediation commits requested)
  - U=2: alert metric/source/threshold all unknown until payload fetched
  - B=1: scope tied to whatever Azure resource emitted the metric (likely single-service)
  - V=1: Rootly + Azure metrics partially verifiable; Slack thread is heuristic
  - G=1: docs ↔ canonical IaC reconciliation needed
- System view: consumers=on-call engineers reading the RCA; operators=Trade Platform on-call; boundaries=Rootly API → Azure Monitor → MC dev subscription → Service Bus / target resource; time=alert is ONGOING (freshness matters, snapshot value); derived surfaces=eneco-src IaC tfvars (alert thresholds), Slack incident threads.
- Counterfactual: Without RCA → on-call engineer carries opaque alert into next shift, may auto-resolve without root-cause learning, recurrence likely.
- Hypotheses:
  - H1: Service Bus / messaging threshold breach (DLQ depth, message age, server errors) tied to mFRR pipeline. Eliminate if alert source is non-Service-Bus resource.
  - H2: Other Azure resource alert (AGW health, App Config, Key Vault throttle, Cosmos RU, Redis CPU). Eliminate if Rootly payload names Service Bus or app metric.
  - H3: Synthetic / heartbeat / pipeline / deploy alert (CI/CD, sandbox health). Eliminate if Rootly source is Azure Monitor metric.
- Triggers: LIBRARIAN:n | CONTRARIAN:y (CRUBVG≥5) | EVALUATOR:n | COGNITIVE:n | DOMAIN:y (eneco-oncall-intake-rootly + eneco-platform-mc-vpp-infra + eneco-tools-rootly + eneco-context-slack) | TOOLS:y (az cli, mcp__rootly__*, eneco-tools-connect-mc-environments)
- BRAIN SCAN: Dangerous assumption = treating the URL slug pbbtBV as authoritative without fetching the alert payload (the slug is opaque; metric name + resource id + firing window live inside `data.attributes`). Falsifier = fetch via `mcp__rootly__get_alert_by_short_id` or `mcp__rootly__getAlert` and inspect raw payload before reasoning. Likely failure = misidentifying which Azure resource fired and writing an RCA against the wrong subsystem.

## What "done" means

A markdown RCA placed under `log/employer/eneco/02_on_call_shift/shift_alerts_summary/2026-April (20-26)/` containing:
1. Alert identity (short_id, source, fingerprint, firing window, severity, current state).
2. Mechanism — what metric crossed which threshold on which resource and WHY (causal chain to root cause, not just symptom).
3. Evidence — Rootly payload citation + Azure metric series snapshot + IaC threshold reference (file:line).
4. Hypothesis ledger (H1/H2/H3 status with elimination evidence).
5. Recommended action (next-step for on-call: ack-only, mitigation, or escalation) + residual risk.
6. Adversarial challenge artifact (separate file) where socrates-contrarian attacks the RCA with a distinct win condition.

## Verification Strategy (placeholder — refined in Phase 3)

- Falsifier-1: Rootly alert payload reproducibly readable; metric + resource + threshold extractable.
- Falsifier-2: Azure metric series in MC dev (or relevant subscription) shows the same breach in the same window.
- Falsifier-3: IaC threshold value matches the value Rootly fired against (reconciled at file:line).
- Falsifier-4: Independent adversarial reviewer (socrates-contrarian) cannot find a hypothesis among H1/H2/H3 incorrectly eliminated.

## Non-Goals

- No remediation commits, no IaC edits, no git mutations.
- No paging changes, no Rootly workflow edits.
- Slack messages only if user explicitly requests them.
