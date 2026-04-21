---
task_id: 2026-04-21-001
agent: claude-code
status: draft
summary: Initial pre-flight requirements — Stefan Klopf's Slack Lists ticket Rec0ATVMGS4J1, Redis alert spam on dev-mc, request to make alert thresholds env-configurable.
---

# 01 — Task Requirements (initial)

## Pre-flight mirror

```
TASK ANALYSIS
- Phase: 1 | Brain: 67.0.0 | task_id: 2026-04-21-001
- Request: Triage Stefan Klopf's Slack Lists ticket about Azure Redis alerts spamming on dev-mc; produce diagnosis + step-by-step fix document for Alex to inspect and implement himself.
- DOMAIN-CLASS: investigation
- ROOT-ARTIFACT: n
- CRUBVG: C=1 (cross-repo, Eneco.Infrastructure module + MC-VPP-Infrastructure consumer, but a tight slice)
           R=1 (Terraform IaC change with PR review, reversible — but Azure alerts can be modified live too)
           U=2 (don't yet know: which alerts the Redis module actually defines, what overrides exist today, how thresholds flow from module → consumer → env tfvars; and we don't yet know whether prd is also affected or only dev)
           B=1 (per-env scope; touches an alert surface used by 24/7 ops — incorrectly silencing prod is the worst-case)
           V=1 (terraform plan + Azure portal + Rootly are deterministic verifiers)
           G=1 (memory points at MC-VPP-Infrastructure alert files, but the ticket says the module defaults live in Eneco.Infrastructure — need to read both)
           Total raw = 7; G≥1 → 8
- Triggers: LIBRARIAN:y (Microsoft docs on Azure Cache for Redis metrics + alert rules)
            CONTRARIAN:y (CRUBVG ≥ 5)
            EVALUATOR:y (CRUBVG ≥ 4)
            DOMAIN:y (eneco-platform-mc-vpp-infra, eneco-context-repos may help)
            TOOLS:n
- BRAIN SCAN:
    Most dangerous assumption: that the working-directory folder name "stefan_redis_alerts" accurately
        encodes the ticket scope. The thread itself reveals at least two distinct alerts misbehaving
        (CacheLatency — actually firing — and UsedMemory — chronically over an absolute-bytes threshold)
        plus one well-behaved alert (AllUsedMemoryPercentage). Conflating them = wrong fix.
    Most likely failure: proposing a fix that silences alerts in dev by lowering severity or disabling
        them, when the actual ask is to make thresholds env-configurable so dev's Standard SKU and
        prd's Premium SKU can carry different sensible defaults. Disabling > tuning is a regression.
```

## What the user asked for (from prompt)

> "I want a clear diagnosis, and a proposed document with the fix, step by step, so I can inspect it,
>  understand it, and implement it by me."

Two artifacts: (a) diagnosis, (b) inspectable fix document. Implementation is **out of scope** for this
session — the user implements himself. We do **not** edit the Terraform repos.

## Ticket facts (from `slack-input.txt`)

- **Slack Lists URL**: `https://eneco-online.slack.com/lists/T039G7V20/F0ACUPDV7HU?record_id=Rec0ATVMGS4J1`
- **List ID**: `F0ACUPDV7HU` → companion comments channel `C0ACUPDV7HU` (Trade Platform intake in `#myriad-platform`)
- **Record**: `Rec0ATVMGS4J1`
- **Filer**: Stefan Klopf
- **On-call**: Alex Torres (the user)
- **Filer's stated scope**:
    - "azure alerts for Redis"
    - "default alerts introduced in the Redis module in the Eneco.Infrastructure repository"
    - "in the MC-Infrastructure we are using the same default alerts for all envs equally"
    - "since last week we get spammed by one of this alerts on dev-mc which uses standard instead of Premium"
    - "make the alerts configurable by env that we can adjust and maybe disable alerts"
- **Stefan's qualitative review** (already done with the team last Friday):
    - `UsedMemory-vpp-rediscache01-xx` threshold "way too low"
    - `AllUsedMemoryPercentage-vpp-rediscache01-xx` "more useful"

## Image evidence (the load-bearing observations)

| File | Surface | Observation |
|------|---------|-------------|
| `image.png` | Rootly dashboard | 10+ resolved fires of **`CacheLatency-vpp-rediscache01-d`**, last 1–4 days, durations 1–13 minutes, all Low, vpp-core team. **This is the spam.** |
| `image (1).png` | Azure portal — Edit alert rule `UsedMemory-vpp-rediscache01-d` | Static `Maximum` of `Used Memory` > **200 000 000 bytes (≈190 MB)**. Live preview shows steady ≈ **455.68 MB** for hours → alert is in continuous fired state. Threshold is an absolute byte count, not a percentage. |
| `image (2).png` | Azure portal — Edit alert rule `AllUsedMemoryPercentage-vpp-rediscache01-d` | Static `Average` of `Used Memory Percentage (Instance Based)` > **85 %**. Live preview shows ≈ **18.6 %** → not firing. Healthy design. |
| `image (3).png` | Azure portal — Edit alert rule `CacheLatency-vpp-rediscache01-d` | Static `Average` of `Cache Latency Microseconds (Preview)` > **15 000 µs (15 ms)**, evaluated every 1 min over a 15-min lookback window. Preview chart Apr 13–20 shows latency oscillating **7k–17k µs** with frequent crossings of 15k → matches the Rootly fire-resolve cycles in `image.png`. Latency drops after Apr 19 (≈ 7–10 k). |

## Initial entity ledger

- **Resource**: `vpp-rediscache01-d` (Azure Cache for Redis, dev-mc) — naming suffix `-d` confirms env baked into resource name; presumably `-a` (acc) and `-p` (prd) exist
- **Tier**: dev-mc = **Standard** (Stefan's claim), prd = **Premium**
- **Repos in scope**:
    - `Eneco.Infrastructure` — owns the Redis module (per Stefan); local at `/Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src/eneco-temp/Eneco.Infrastructure`
    - `MC-VPP-Infrastructure` — consumes the module across envs; local at `/Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src/enecomanagedcloud/myriad-vpp/MC-VPP-Infrastructure/main`
- **Specific alerts identified**:
    - `UsedMemory-vpp-rediscache01-d` — absolute bytes threshold
    - `AllUsedMemoryPercentage-vpp-rediscache01-d` — percentage threshold (well-behaved)
    - `CacheLatency-vpp-rediscache01-d` — microseconds threshold (the actual spammer)
- **Action group**: routes to Rootly (per `image.png`); Eneco standard `actiongroup.tf`

## Counterfactual (Phase 1)

If we don't do this: dev-mc continues spamming the Rootly channel, on-call coverage degrades from
alert fatigue, and the next genuine dev-mc Redis incident gets lost in the noise. Stefan goes on
vacation tomorrow leaving the rest of the 24/7 core team to absorb it. Definitely worth doing.

## Triggers actually intended this session

- LIBRARIAN: dispatch context-researcher to Microsoft Learn for Azure Cache for Redis metrics
  semantics (UsedMemory vs UsedMemoryPercentage, Standard vs Premium memory caps, CacheLatency Preview
  metric meaning + sampling, default values, alert rule recommended thresholds). Phase 4 only.
- CONTRARIAN: dispatch socrates-contrarian to attack the Phase 5 fix plan, particularly the silent-fail
  case "the per-env override mechanism still ships defaults that don't fit Standard."
- EVALUATOR: dispatch a separate evaluator on the final spec at Phase 8.
- DOMAIN: use eneco-platform-mc-vpp-infra mental model knowledge of the MC-VPP repo (Redis is one of
  its 16 infrastructure domains).

## Out of scope this session

- Editing either Terraform repo
- Posting to Slack
- Touching production thresholds without Stefan/team review
- Investigating *why* CacheLatency briefly spiked (capacity / workload analysis is a separate ticket;
  Stefan said the metric is "getting back to the initial state")
- Adding new alerts; we tune what exists

## Verification anchor (initial — refined in Phase 3)

A correct fix is one where:

1. The Redis module's alert resources accept env-tunable threshold inputs (each alert's threshold
   becomes an input variable with a sane Premium-tuned default).
2. `MC-VPP-Infrastructure`'s consumer wires those inputs from per-env tfvars.
3. dev tfvars override the brittle ones (UsedMemory absolute, CacheLatency µs) to either much higher
   values or `null`/`disabled` for the dev-only spam.
4. prd tfvars are unchanged in behavior (no prod regression).
5. `terraform plan` per env shows changes only on dev (and possibly acc) for the targeted alerts.

This is the strawman; Phase 3 produces the falsifier-bearing version.
