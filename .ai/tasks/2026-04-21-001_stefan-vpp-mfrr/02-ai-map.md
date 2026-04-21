---
task_id: 2026-04-21-001
agent: claude-code
status: complete
summary: AI harness surfaces for mFRR ticket diagnosis
---

# AI Map

- Coordinator: claude-code (this session)
- Task root: `.ai/tasks/2026-04-21-001_stefan-vpp-mfrr/`
- Second brain: `$SECOND_BRAIN_PATH` → vault with `llm-wiki/`. Recall bundle = SessionStart hook output (see primacy). No explicit llm-wiki reads planned in Phase 1/2/3 per TOOL LOCK.
- Skills routed (external to coordinator, canonical names):
  - `/eneco-oncall-intake-slack` — Phase 4 context harvest (Slack thread + list record + first-principles grounding)
  - `/eneco-oncall-intake-enrich` — Phase 7 read-only probes (Azure CLI, kubectl, ArgoCD, OpenShift)
  - `/eneco-platform-mc-vpp-infra` — IaC domain knowledge (Event Hubs + Service Bus modules, 16 infra domains)
  - `/eneco-context-repos` — locate exact ADO repo + branch for mFRR service + IaC
  - `/eneco-context-docs` — ADO wiki/runbook lookup for mFRR, Event Hubs consumer-group conventions
  - `/eneco-context-slack` — deeper Slack harvest if intake-slack surfaces gaps
  - `/eneco-tradeit-servicebus` — check only if reporter's "EventHub" term is actually Service Bus (terminology verification)
- Subagents on call: `socrates-contrarian`, `kant-cognitive-scientist` (adversarial), `sherlock-holmes` / `forensic-pathologist` (investigation), `librarian` (docs), `architect-kernel` (topology review if needed).
