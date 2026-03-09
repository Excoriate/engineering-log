---
task_id: 2026-03-09-001
agent: coordinator
status: partial
summary: Final confirmed requirements for Service Bus Topic Size Warning SRE runbook
---

# Task Requirements — Final

## Confirmed Scope Changes vs Initial

1. **NEW FALSIFIER** (not in initial): Runbook MUST include `diagnose.py` script that executes all diagnostic az CLI commands, computes % of threshold for each topic, outputs ranked table, and exits 0 (healthy) or 1 (action required). Falsifier: `python diagnose.py --namespace vpp-sbus-d --resource-group mcdta-rg-vpp-d-messaging --subscription 839af51e-c8dd-4bd2-944b-a7799eb2e1e4 && echo OK`

2. **ENV-AGNOSTIC** (changed from initial): Runbook uses environment variables at top (`SUBSCRIPTION_ID`, `NAMESPACE`, `MESSAGING_RG`, `ALERT_RG`, `ENV_SUFFIX`). Works for dev (`-d-`) and prd (`-p-`) with different escalation trees. This is a structural change — initial spec assumed dev-only.

3. **PREREQUISITE ACCESS MATRIX** (new section): Runbook documents which diagnosis steps require az CLI only vs also kubectl. Steps that REQUIRE kubectl are clearly gated with "if you have k8s access" — fallback documented for those who don't.

4. **AUTHENTICATION STRATEGY** (refined): `enecotfvppmclogindev` alias is called once at top of session. All subsequent commands inherit the session token from `~/.azure/`. The runbook auth section documents the alias call and shows how to verify the correct subscription is set with `az account show --output table`.

## Confirmed Acceptance Criteria (Falsifiable)

| # | Criterion | Falsifier |
|---|-----------|-----------|
| 1 | Every az CLI command in runbook executes without error in dev | Live run in Phase 4 with 0 non-zero exits |
| 2 | `diagnose.py` ranks all 252 topics by size, computes % threshold | `python diagnose.py` exits 0, produces table with % column |
| 3 | Runbook identifies breaching topic within 60 seconds of reading | On-call time-to-identify test: step 2 of runbook produces topic name |
| 4 | Cascade risk section covers all 4 stages (consumer → topic → quota → cascade) | Section "Cascade Risk" contains all 4 escalation stages |
| 5 | Runbook works for both dev and prd (env var substitution) | Single variable change at top produces valid prd commands |
| 6 | sre-maniac review PASS with ≤3 MINOR findings, 0 CRITICAL/MAJOR | Agent sign-off artifact in verification/ |
| 7 | linus-torvalds code review PASS on diagnose.py with ≤3 MINOR findings | Agent sign-off artifact in verification/ |

## Confirmed Structure

```
log/employer/eneco/00_incident_sre/01_alert_service_bus_topic_size_warning/
└── runbook/
    ├── README.md              # Main runbook (the "book")
    └── diagnose.py            # Python triage script
```

## Confirmed Live Data Requirements

Phase 4 MUST capture live output for:
1. `az account show` — verify subscription context
2. `az servicebus namespace show` — namespace state
3. `az monitor metrics alert list` — alert fired state
4. `az servicebus topic list --query` — all topics with size, ranked DESC
5. `az servicebus topic subscription list` — per-topic subscription message counts
6. `az monitor metrics list` — IncomingMessages + CompleteMessage rate (producer/consumer delta)
7. `az monitor activity-log list` — alert fire history
8. Alert JSON via REST API — current alert status (Fired/Resolved)

All outputs written to `context/` as `.txt` files for runbook factual grounding.
