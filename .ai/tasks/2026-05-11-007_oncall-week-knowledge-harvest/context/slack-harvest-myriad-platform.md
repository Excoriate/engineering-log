---
task_id: 2026-05-11-007
agent: claude-code
status: complete
summary: Harvest of #myriad-platform (public intake channel, Trade Platform) for window 2026-05-04 → 2026-05-11 inclusive.
source_tool: mcp__claude_ai_Slack__slack_read_channel + slack_search_public_and_private
window: 2026-05-04 → 2026-05-11
channel_id: C063SNM8PK5
channel_type: public
---

# Slack Harvest — #myriad-platform (public intake) — 2026-05-04 → 2026-05-11

## Channel Identity

- **Purpose**: Trade Platform's PUBLIC inbound-request intake. Driven primarily by bots (Rootly on-call announcements, Review-PR bot, CICD-Request bot, RBAC bot, General-Request bot, FAQ reminder bot).
- **Signal class**: ticket cards (one per request), PR-review notifications, on-call handoffs.
- **Behavioral pattern**: humans rarely write here directly — they file via Slack Lists intake (`https://eneco-online.slack.com/lists/T039G7V20/F0ACUPDV7HU?record_id=…`) and the bot posts a card.

## On-Call Rotation (week 19/20 2026)

| Date | On-Call (Primary) | Until |
|------|-------------------|-------|
| 2026-05-04 09:00 → 2026-05-04 17:00 | Michael Ströh | May 04, 5pm CEST |
| 2026-05-04 17:00 → 2026-05-05 09:00 | Roel van de Grint (off-hours) | May 05, 9am CEST |
| 2026-05-05 09:00 → 2026-05-05 17:00 | Roel van de Grint | May 05, 5pm CEST |
| 2026-05-05 17:00 → 2026-05-06 09:00 | Roel van de Grint | May 06, 9am CEST |
| 2026-05-06 09:00 → 2026-05-06 17:00 | Nuno Alves Pereira | May 06, 5pm CEST |
| 2026-05-07 09:00 → 2026-05-07 17:00 | Nuno Alves Pereira | May 07, 5pm CEST |
| 2026-05-07 17:00 → 2026-05-08 09:00 | Roel van de Grint (off-hours) | May 08, 9am CEST |
| 2026-05-08 09:00 → 2026-05-08 17:00 | Nuno Alves Pereira | May 08, 5pm CEST |
| 2026-05-08 17:00 → 2026-05-11 09:00 | Roel van de Grint (off-hours, weekend) | May 11, 9am CEST |
| **2026-05-11 09:00 → 2026-05-11 17:00** | **Alex Torres** | May 11, 5pm CEST |
| **2026-05-11 17:00 → 2026-05-12 09:00** | **Fabrizio Zavalloni** (off-hours) | May 12, 9am CEST |

**Insight (durable)**: Trade Platform on-call schedule is split — office-hours rotation rotates daily across the team; off-hours appears to default to Roel (and on weekends, Fabrizio gets the Monday morning slot today). This week's split confirmed by Fabrizio in #team-platform: *"We have overwritten only the on-call during the business hours, the schedule outside the business hours remained the same"*.

## Today's Requests / Incidents (2026-05-11)

| Time CEST | Event | Source |
|-----------|-------|--------|
| 09:56 | **Duncan Teegelaar** filed General Request — FBE-create Terraform deploy failure (kidu slot) | `Rec0B3SKFGNRW`; ties to `2026_05_11_fbe_error_duncan/` |
| 13:46 | Coco Langens: ad-hoc Slack ask — "give Yitzi Snow all the same access I have" (in-channel, not via Lists) | Direct message in channel |
| 13:31 | Ihar Bandarenka: CICD Request | `Rec0B2TCTFQTV` |
| 14:24 | Ihar Bandarenka: CICD Request | `Rec0B3UCLRV16` |
| 15:30 | **Alexandre Freire Borges**: ServiceNow incident **INC2384584** flagged for on-call | (in-channel, not via Lists) → ties to `2026_05_11_cmc_alert_vpp_cluster_prod/` (CMC alert vpp-resource-unhealthy) |
| 15:41 | Alexandre Freire Borges filed General Request | `Rec0B2YL8HPC6` |
| 10:12 | Ihar Bandarenka: CICD Request | `Rec0B2YETBMQS` |
| 16:46 | Srinath Dussa: PR review request — VPP-Configuration #174027 | `Rec0B336YEBDX` |
| 12:24 | Aleksandr Trifonov: PR review — Eneco.Vpp.Messaging.EventualConsistency #176686 | `Rec0B2HTVV895` |

**Note**: No Slack-side discussion of CPU throttling (`otc-container`) — that came via Rootly direct page (`ln2I9h`), not via #myriad-platform. No mention of ArgoCD PAT rotation in this channel either — that conversation is in #team-platform (private, see sister harvest).

## Request Volume — 1-week window (2026-05-04 → 2026-05-11)

| Day | General Req | PR Review | CICD Req | RBAC | Notes |
|-----|-------------|-----------|----------|------|-------|
| 2026-05-04 | 1 (Sebastian du Rand `Rec0B1EMEHC14`) | 3 (Niels Witte, Mykola Levchenko, Aleksandr Trifonov) | 0 | 1 (Niels Witte `Rec0B29C1BGF2`) | — |
| 2026-05-05 | 0 | 0 | 0 | 0 | Quiet day |
| 2026-05-06 | 1 (Niels Witte `Rec0B1WT08NA1`) | 3 (Mykola, Efe Ozyer, Srinath Dussa, Martijn Meijer) | 0 | 1 (Alexandre Freire Borges `Rec0B1HKQ1Z9D`) | — |
| 2026-05-07 | 4 (Johnson Lobo, Vikas Yadav, Ihar Bandarenka, Martijn Meijer) | 2 (Ihar, Alexandre) | 0 | 0 | Heaviest day for ad-hoc requests |
| 2026-05-08 | 1 (Timothée Macquart `Rec0B3DNHHH7A`) | 2 (Mykola, Ihar) | 0 | 0 | — |
| 2026-05-09 | 0 | 0 | 0 | 0 | Weekend |
| 2026-05-10 | 0 | 0 | 0 | 0 | Weekend |
| 2026-05-11 | 2 (Duncan Teegelaar, Alexandre Freire Borges) | 2 (Aleksandr, Srinath) | 3 (Ihar Bandarenka ×3) | 0 | Today's on-call surface |

**Insight**: Ihar Bandarenka filed 3 CICD requests on 2026-05-11 alone — concentrated burst. Niels Witte authored multiple General Requests + RBAC + PR reviews during the week — high activity.

## Out-of-Window but Relevant

- **2026-05-01 16:53 (Alex Torres)**: *"SQL Server DB(s) for VPP Production, all with Long-Term Retention and Immutable Backups"* — announcement that 6 databases on `vpp-sqlserver-p` now have LTR + locked time-based immutability: `asset`, `assetmonitor`, `assetplanning`, `assetplanning-tennetde`, `assetplanning-assets`, `assetplanning-elia`. Until retention window expires, **no admin / script / Microsoft Support / ransomware can alter or delete the backups**. *This is durable architectural knowledge — proposed for vault `context/repos/` or `decisions/`.*
- **2026-04-30 13:15 (Roel)**: *"Performing a little bit of testing with Prometheus alerts. They might drop completely for 30 mins causing some alerts."* — drop-window pattern; useful operational context.
- **2026-04-29 09:15 (Thomas OBrien)**: *"Today there is a disaster recovery test in the acceptance environment taking place. This will involve VMs in the ACC environment being taken down to test zone redundancy."* — DR test announcement; ties to existing vault episode `2026-04-29-acc-dr-test-zone-failover.md`.
- **2026-04-29 15:59 (Roel)**: *"I'm going to reconfigure metrics on dev-mc for about 20 minutes to confirm a change required for alert routing will not degrade the existing stuff."* — alert routing investigation; ties to broader alert-routing initiative documented in #team-platform.

## Bot-Recurring Reminder

`FAQ and Docs reminders` bot posts daily at 08:45 CEST — pushes everyone to read FAQ + Troubleshooting Guide at `myriad-vpp/platform-documentation`. Same payload daily — telemetric noise, not actionable signal. **Durable insight**: when scanning for action items, filter out this bot's daily message before counting "incidents."

## Channel Hygiene Observations

- **Slack Lists intake** (`F0ACUPDV7HU`) is the canonical request format. Direct posts (Coco's access request, Alexandre's INC link) are exceptions and harder to track.
- **On-call announcements** are bot-posted by Rootly — distinguishing primary vs off-hours requires reading the time-window in the message.
- **No incident threads** in the 1-week window in this channel — major incidents go to `#myriad-major-incidents` (separate channel; search returned 0 results in window, suggesting no Major Incident-class events).

## Cross-References to Today's Log Dirs

| Log dir | Slack origin in #myriad-platform | Permalink |
|---------|----------------------------------|-----------|
| `2026_05_11_fbe_error_duncan` | Duncan Teegelaar General Request at 09:56 CEST | `https://eneco-online.slack.com/lists/T039G7V20/F0ACUPDV7HU?record_id=Rec0B3SKFGNRW` |
| `2026_05_11_cmc_alert_vpp_cluster_prod` | Alexandre Freire Borges flagged INC2384584 at 15:30 CEST | (in-channel, not via Lists) |
| `2026_05_11_rootly_alert_cpu_throtling` | No mention here — Rootly page only | — |
| `2026_05_11_rotating_expired_argocd_secrets` | No mention here — surfaced in #team-platform | — |

## Durable Signals Extracted

1. **On-call split is split-shift**: business hours rotate; off-hours default to specific person(s). Confirmed pattern, week-stable. → memory/feedback if not already in vault.
2. **Public channel ≠ incident channel**: today's PAT rotation + CPU throttling work happened entirely off this channel (private + Rootly). → operational knowledge: when triaging "what happened today", reading #myriad-platform alone misses ~50% of the on-call's actual work.
3. **CMC alerts arrive via humans + ServiceNow URL, not via Action Group**: today's CMC INC2384584 was flagged by Alexandre Freire Borges manually pasting the SN URL — confirms the rca.md observation that the alert rule has `actions: null` and ServiceNow received it via a separate (A3 UNVERIFIED) path. → reinforces lesson "do not assume Azure-close propagates to ServiceNow-close".
