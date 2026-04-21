---
task_id: 2026-04-21-001
agent: claude-code
status: complete
summary: Documentation sources for mFRR + Event Hub consumer group semantics
---

# Docs Map

## Internal (Eneco — delegated to `/eneco-context-docs`)

- Myriad VPP architecture / ADRs
- Trade Platform Troubleshooting Guide
- BTM / Aggregation Layer docs (mFRR participates in reserve markets coordinated via BTM)
- Terraform Golden Path styleguide
- Runbooks for Event Hubs / Service Bus on MC-VPP

## External (Microsoft docs — delegated to `librarian` / microsoft-docs-mcp)

- Azure Event Hubs consumer groups semantics (`$Default`, custom names, one active consumer per partition per group)
- Consumer group creation via Terraform `azurerm_eventhub_consumer_group`
- SDK behavior when consumer group missing: `MessagingEntityNotFound` vs silent stall

## Domain (mFRR)

- mFRR = manual Frequent Restoration Reserve (Dutch market: afschakelbaar vermogen, TenneT). "Activation" = the TSO-triggered dispatch signal leg of mFRR.
- [INFER] mFRR-Activation service likely consumes TSO dispatch events (from BTM/TenneT feed) via Event Hub and translates to asset control commands. Probe via `eneco-flex-trade-optimizer` neighbor or `eneco-context-docs`.
