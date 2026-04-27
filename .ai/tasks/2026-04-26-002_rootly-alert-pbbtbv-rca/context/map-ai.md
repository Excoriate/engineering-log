---
task_id: 2026-04-26-002
agent: claude-opus-4-7
status: complete
summary: AI/skills topology — Eneco on-call + Rootly + Azure connect skills available; rootly MCP loaded; az cli available.
---

# Map: AI / Skills / MCP

## Eneco skills relevant to this RCA

- `eneco-tools-connect-mc-environments` — MC SP login (dev/acc/prd), credential caching, IP whitelisting. Required for az-cli access to MC dev subscription.
- `eneco-tools-rootly` — alert triage, on-call queries, payload decoding.
- `eneco-oncall-intake-rootly` — three-mode (ack-only / quick-triage / deep-enrich) Rootly intake flow.
- `eneco-oncall-intake-enrich` — read-only probe enrichment after handover.
- `eneco-oncall-intake-slack` — Slack triage of #myriad-platform intake list.
- `eneco-context-slack` — extract organizational context from Slack workspace.
- `eneco-platform-mc-vpp-infra` — operational knowledge of MC-VPP-Infrastructure repo (16 infrastructure domains).
- `eneco-context-repos` — territory map for ADO repos.
- `eneco-context-docs` — fetch ADO wikis on demand.

## MCPs available

- `mcp__rootly__*` — full Rootly API surface: alerts, incidents, schedules, shifts, teams, services, action items, related incidents, oncall handoff summary.
- `mcp__slack__*` — read/search channels/threads, schedule message, send draft.
- `mcp__obsidian__*` — second-brain vault.
- `mcp__terraform__*` — registry/provider details.
- `mcp__claude_ai_microsoft_docs_mcp__*`, `mcp__awslabs-aws-documentation-mcp-server__*`, `mcp__context7__*` — external docs.

## CLI tools

- `az` — Azure CLI for MC subscriptions.
- `gh` — GitHub.
- `jq`, `rg`, `fd` — local tooling.

## Brain/runtime artifacts

- `$T_DIR` = `/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/.ai/tasks/2026-04-26-002_rootly-alert-pbbtbv-rca/`
- `current-task.json` updated, `manifest.json` initialized.
- Recall bundle at `.ai/runtime/second-brain/recall-bundle.md` references `mc-vpp-infrastructure` repo + `tools/second-brain-hooks` — not directly load-bearing for this RCA.
