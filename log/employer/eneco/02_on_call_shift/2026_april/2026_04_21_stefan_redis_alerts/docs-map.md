---
task_id: 2026-04-21-001
agent: claude-code
status: complete
summary: Phase-2 docs map. External authoritative sources to consult in Phase 4.
---

# Docs map

| Source | What it grounds | Use in Phase |
|--------|-----------------|--------------|
| Microsoft Learn — Azure Cache for Redis: monitor metrics | Semantics + units of `cachelatency`, `usedmemory`, `usedmemorypercentage`, `allconnectedclients`, `allserverload`, `errors`, `usedmemoryRss` | Phase 4 (briefly — only to ground threshold recommendations) |
| Microsoft Learn — Azure Cache for Redis pricing tier comparison | Memory caps per Standard C0–C6 and Premium P1–P5; tier-relative reasoning for absolute-bytes thresholds | Phase 4 |
| HashiCorp azurerm `azurerm_monitor_metric_alert` | Confirm criteria block, dimension semantics — already confirmed by reading v2.5.3 main.tf | reference only |
| Stefan's Slack thread (record `Rec0ATVMGS4J1`) | Acceptable-fix shape ("configurable per env, adjust thresholds, maybe disable") | Phase 5 plan |
| Eneco internal docs | Not strictly required — the IaC repos are self-contained for this fix | n/a this session |
