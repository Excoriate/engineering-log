---
task_id: 2026-05-11-007
agent: claude-code
status: complete
summary: Spec for new vault lesson — at Trade Platform, on-call incidents land in 4+ different intake surfaces (Slack public, Slack private, Rootly, ServiceNow). Reading only #myriad-platform misses 50%+ of an on-call's actual work. Future summarizers must sample ALL surfaces. Ready to apply to llm-wiki/learnings/lessons/.
spec_target_path: $SECOND_BRAIN_PATH/llm-wiki/learnings/lessons/oncall-summary-cannot-reconstruct-from-single-intake-channel.md
spec_action: create
spec_zone: learnings/lessons
spec_status: ready_to_apply
---

# Spec — Lesson: An On-Call Summary Cannot Be Reconstructed From A Single Intake Channel

## Frontmatter (apply verbatim)

```yaml
---
description: "At Eneco Trade Platform, on-call work surfaces in 4+ different intake channels per shift: (1) #myriad-platform (public; bot-driven Slack Lists cards for FBE / PR / CICD / RBAC requests); (2) #team-platform (private internal; the actual decisions and triage); (3) Rootly direct page (alertmanager-routed alerts; no Slack mention); (4) ServiceNow CMC ticket (sometimes copy-pasted into Slack as a URL, sometimes not). Today's 2026-05-11 shift had FOUR incidents and EACH was in a different intake channel. Reading only #myriad-platform misses 50%+ of the on-call's actual work. Future on-call summarizers MUST sample all intake surfaces."
type: lesson
domain: tech
status: active
source: agent
created: 2026-05-11
last_validated: 2026-05-11
severity: high
confidence: validated
tags: [eneco, trade-platform, on-call, intake-surfaces, slack-discipline, rootly, servicenow, summarization, agent-context]
---
```

## The Rule

If you're summarizing an Eneco Trade Platform on-call shift, sampling a single intake channel is insufficient. The full surface is at least: Slack public + Slack private + Rootly + ServiceNow + (RCA dirs if a written-up incident is in scope).

## Why (mechanism — today's evidence)

Four incidents on 2026-05-11, four different intake channels:

| Incident | Intake channel | Reason this channel |
|----------|---------------|---------------------|
| FBE-create Duncan/kidu | `#myriad-platform` (public) — Slack Lists card `Rec0B3SKFGNRW` | Trade Platform's canonical public intake (bot-mediated) |
| CMC `vpp-resource-unhealthy` (prd) | ServiceNow `INC2384584` — Alexandre Freire Borges manually pasted the URL into `#myriad-platform` at 15:30 CEST | ServiceNow received the alert via an A3-UNVERIFIED separate path (not via Action Group → not in Rootly); human paste was the only Slack signal |
| CPU throttling `ln2I9h` (otc-container, dev cluster) | Rootly direct page (alertmanager → escalation policy `1b6ee744-…`) | Low-tier urgency; no Slack mention either channel; alertmanager routing only |
| ArgoCD PAT expiry (sandbox CRITICAL) | `#team-platform` (private) — Fabrizio's question at 12:32 CEST: *"Has anybody renewed the Pat Token used by the Argocd in Sandbox?"* | Internal discovery; the original Slack alert (expiry monitor) is in `#myriad-alerts-devops` (separate private channel) |

Reading only `#myriad-platform` would see 2 of 4 incidents (FBE Duncan + the CMC URL paste) and miss the CPU throttling + the ArgoCD PAT rotation entirely. The ArgoCD PAT work was actually the **highest-impact** incident of the day (22h silent failure blocking 3 FBE slots).

## How to apply

### Multi-surface intake sampling (for on-call summary + handoff)

When summarizing an on-call shift, sample ALL of:

| Surface | Tool / command | What you get |
|---------|---------------|--------------|
| `#myriad-platform` (public) | `slack_read_channel C063SNM8PK5 limit=60` | Bot cards: General Request / PR Review / CICD Request / RBAC; on-call announcements; ServiceNow URL pastes (occasionally) |
| `#team-platform` (private) | `slack_read_channel C063YNAD5QA limit=60` | Team-internal triage decisions; off-record discoveries (today's PAT discovery); scheduling; PR-among-team |
| `#myriad-alerts-devops` (private) | `slack_read_channel C066CFUEC7J limit=30` | DevOps alerts (PAT expiry, CI/CD failures); often the FIRST signal for credential issues |
| `#myriad-alerts-ocp-prd` (private) | `slack_read_channel C065PGC4AQJ limit=15` | Production OCP alerts |
| Rootly | `mcp__rootly__listAlerts` with appropriate filter / `eneco-tools-rootly` skill | Alerts routed by alertmanager + Azure → Rootly; the ones with no Slack mention |
| ServiceNow | Manual portal check OR ticket URL parse from Slack | CMC tickets; sometimes Azure→SN-integrated alerts that bypass Rootly |
| `log/employer/eneco/02_on_call_shift/<DATE>_*/` | `find` + `Read` | Written-up incidents (canonical RCAs); the OUTPUT of today's work that didn't fit any one channel |

### Triage discipline (active on-call)

1. **First action after Rootly page**: check the alert's `actions` field — if `null`, this alert was NOT routed via Action Group → check Slack public + Slack private + ServiceNow for the human-pasted URL (today's CMC pattern)
2. **First action after Slack list intake**: read the linked Lists card AND check Rootly history for the same target (the request may reference a recent Rootly alert)
3. **First action when triaging `#team-platform` mention**: search adjacent surfaces — today's PAT discovery in #team-platform was upstream-cause of an FBE failure already filed in #myriad-platform

## What to avoid

- **Reading only one channel and reporting "the day was quiet"** — today's #myriad-platform looked quiet (12 bot cards across the shift); the actual work was elsewhere
- **Treating Rootly silence as workload silence** — Low-tier alerts route through Rootly without Slack noise; the on-call must pull Rootly state explicitly
- **Treating ServiceNow as primarily a CMDB** — at Eneco, ServiceNow receives Azure alerts via a separate Azure→SN integration plugin (A3 path); the on-call should not assume Rootly-or-Slack covers all paging

## Cross-Links

- [[2026-05-11-oncall-shift-trade-platform-quad-incident]] — episode of origin (4-incident worked example)
- [[oncall-rca-must-close-on-every-state-plane]] — sibling operational lesson
- [[azure-alert-close-two-plane-azure-plus-servicenow]] — sibling pattern (the close discipline that pairs with multi-intake awareness)
- `eneco-context-slack` skill — provides the channel registry + per-channel intent routing
- `eneco-tools-rootly` skill — provides Rootly query mechanics
- `eneco-oncall-intake-rootly` skill — Rootly-side intake mode
- `eneco-oncall-intake-slack` skill — Slack-side intake mode
