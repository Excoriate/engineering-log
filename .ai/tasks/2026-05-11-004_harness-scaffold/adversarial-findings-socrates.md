---
task_id: 2026-05-11-004
agent: socrates-contrarian
timestamp: 2026-05-11T00:00:00Z
status: complete
summary: |
  Audit of scaffolded harness for content gaps under the future-session test.
  Five HIGH/MEDIUM gaps identified: dual-path protocol ordering contradicts
  llm-wiki Read step; L1-L12 layer text in rule does not match the actual
  RCA template used in real incidents; ubiquitous language under-covers
  Azure surface seen in real RCAs; "Top 5 Gotchas" omit several validated
  Second Brain gotchas; "add term before completing" rule has no
  enforcement hook and no example of what triggers an addition.
---

# Adversarial Findings — Socrates (Gap Discovery)

## Key Findings

- **S1**: Dual-path write step ordering ambiguous + zone routing for ddd term updates undefined
- **S2**: L1-L12 phrasing in rule diverges from actual RCA exemplar wording, risking layer-name drift
- **S3**: Ubiquitous language under-covers Azure/k8s surface visible in real on-call dirs (AKS, Container Apps, Postgres, Redis, SQL, Gurobi, Event Hubs checkpoint)
- **S4**: Top-5 gotchas list excludes 3+ validated llm-wiki gotchas with higher recurrence than LL-005
- **S5**: "Add new term before completing log entry" has no verification hook; skill verification step only checks ledger→language parity

## [FINDING-S1] severity: HIGH — Dual-path write protocol has an ordering trap

**Evidence**: `rules/governance/memory-freshness.md:30-37` says "Markdown FIRST … JSON second". `rules/governance/llm-wiki-protocol.md:28-32` agrees. BUT `skills/on-call-log-entry.md:63-66` step 7 reads "Add to `.ai/memory/lessons-learned.json`" first, then "If Second Brain configured: dual-path write to `llm-wiki/learnings/`". The skill step inverts the canonical order. A new agent following the skill literally will write JSON first and may skip the markdown if the session ends.

**Fix**: Rewrite skill step 7 to mirror the canonical "markdown first → JSON second" sequence and add a verification line in step 7 acceptance: "If `$SECOND_BRAIN_PATH` set, the markdown file MUST exist before JSON entry is written."

## [FINDING-S2] severity: HIGH — L1-L12 phrasing in the rule diverges from actual RCA template

**Evidence**: `on-call-incident-workflow.md:44-58` lists e.g. `L5 IaC declarative contract` and `L11 Command playbook`. Real exemplar `2026_05_11_fbe_error_duncan/rca.md` uses `L5 — IaC / state / Azure — the three truths` and `L11 — End-to-end command playbook`. A new agent will produce L5/L11 sections that pass the rule's literal text test but fail the established narrative pattern (and the rca-holistic skill assumes the longer headings). Net effect: silent template drift across log entries.

**Fix**: Replace the L1-L12 table in the rule with the exact heading strings from the canonical exemplar, and add: "If `/rca-holistic` skill is invoked, those headings supersede this table — single source of truth lives in the skill."

## [FINDING-S3] severity: MEDIUM — Ubiquitous language under-covers Azure/k8s surface seen in real on-call dirs

**Evidence**: Existing `02_on_call_shift/` directories reference services absent from `ddd-ubiquitous-language.md`: `2026_03_26_alert_sql_acc` (Azure SQL), `2026_05_11_rootly_alert_cpu_throtling` (likely AKS/Container Apps CPU), `2026_03_27_gurobi_throttling_alert` (Gurobi solver), `2026_04_21_stefan_redis_alerts` (Redis), `azure-eventhubs-checkpoint-container-name-is-convention-not-sdk-guarantee.md` gotcha (Event Hubs Checkpoint container). None appear in the Azure Services table.

**Fix**: Add rows for: Azure SQL Database, AKS (or Azure Container Apps if that is the runtime), Redis (Azure Cache for Redis), Gurobi solver / licence server, Event Hubs Checkpoint container, Postgres (if used). Each row needs the same "Relevance" column the existing rows use so an agent knows which incident class they map to.

## [FINDING-S4] severity: MEDIUM — Top-5 Gotchas omits validated llm-wiki gotchas with higher recurrence

**Evidence**: `~/Documents/obsidian/llm-wiki/learnings/gotchas/` has ~14 gotcha notes. `ddd-project.md:79-83` ships exactly 5, mirroring `MEMORY.md`. At least three notable misses: (a) `azure-eventhubs-checkpoint-container-name-is-convention-not-sdk-guarantee.md` (data-plane class, has caused FBE incidents), (b) `argocd-app-of-apps-product-team-cannot-sync.md` (separate ArgoCD class from the three-plane RBAC), (c) `ado-trigger-none-plus-approval-timeout-is-silent-state-drift.md` is duplicated as LL-003 but the llm-wiki note has a richer diagnostic recipe not captured. LL-005 (CCoE KV bootstrap noise) currently ranks above these despite being categorised `severity: medium`.

**Fix**: Re-rank "Top Gotchas" by `severity` then by recurrence rate (count of distinct incident dirs touching that class). Expand list to 7 or replace LL-005 with the EventHubs Checkpoint gotcha; cross-link each entry to its `llm-wiki/learnings/gotchas/<slug>.md`.

## [FINDING-S5] severity: MEDIUM — "Add new term before completing" has no enforcement hook

**Evidence**: `ddd-ubiquitous-language.md:10-11` mandates adding unknown terms before completing log entry. The `on-call-log-entry.md` skill has step 8 ("Update ubiquitous language") and a verification line "No new domain terms in RCA that are absent from ddd-ubiquitous-language.md". But there is no scripted check (no hook, no grep recipe, no example). For a NEW Azure service unfamiliar to the agent, the failure mode is silent: agent invents a synonym (e.g. "the messaging service" instead of registering "Azure Service Bus Premium" as a distinct term from existing "Service Bus") and the verification step rubber-stamps it because the synonym is not in the ledger to flag.

**Fix**: (a) Add to skill step 8 a concrete grep recipe: `grep -oE '\b[A-Z][A-Za-z0-9]{2,}\b' rca.md | sort -u | comm -23 - <(awk '/\|/{print $2}' ddd-ubiquitous-language.md | sort -u)` and treat any non-empty output as a HALT for log entry close. (b) Add an example: "If you encounter e.g. 'Azure Container Apps' and it is not in the table, STOP, add the row with definition + first incident reference, then resume."

---

## Meta-Falsifier

Would prove this review wrong if: (a) the skill's step 7 sequence is intentionally JSON-first for a reason documented elsewhere; (b) the L1-L12 wording in the rule is meant to be the abstract spec and the exemplar's wording is a stylistic variant (in which case S2 downgrades to LOW); (c) the existing `/rca-holistic` skill already enforces the heading text, making S2 already covered.

Domain gaps: I did not read the `/rca-holistic` skill body or the cursor/claude rule deployments — those may already enforce S2 and S5.
