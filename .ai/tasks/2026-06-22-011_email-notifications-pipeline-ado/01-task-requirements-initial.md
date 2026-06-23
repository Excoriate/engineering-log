---
task_id: 2026-06-22-011
slug: email-notifications-pipeline-ado
agent: claude-opus-4-8
status: partial
timestamp: 2026-06-22
summary: Initial requirements mirror for ADO build-completion email notifications enablement request.
---

# Task — ADO build-completion email notifications (pipeline 8951)

## Origin

Slack-Lists filing (`#myriad-platform` intake) → captured verbatim in the incident `requirements.md`.

- Slack list: `https://grid-eneco.enterprise.slack.com/lists/T039G7V20/F0ACUPDV7HU?record_id=Rec0BB9MRKZ1R`
- Org: `enecomanagedcloud` · Project: `Myriad - VPP`
- Target pipeline: `definitionId=8951` (`https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_build?definitionId=8951`)

## Verbatim ask (filer)

> i want to be able to enable email notifications on completion of this pipeline [8951].
> I've read that is possible to configure email notifications in this way:
> - navigate to Project Settings → Notifications
> - Select "Build completes" and configure [pipeline 8951] there with the right recipients
> But currently i dont have editing rights for that view. Could you please grant me?

## Classification

- ORIGIN: Slack-Lists (filing self-contained in requirements.md — no re-harvest needed)
- FAILURE SURFACE: `pipeline-ado` (ADO notification configuration + ADO permission model)
- DOMAIN-CLASS: knowledge/enablement (+ optional gated permission action)
- This is an **enablement request**, not a system failure.

## Deliverables requested by Alex

a) Concise, actionable how-to (az CLI + manual) in **HTML + .md**, using `how-to-feynman`.
b) A **runbook** if this is a repeatable process (to complement FAQ/guides).
c) If a quick safe fix exists: verify 100%, then prompt ONCE for authorization before acting.

## Load-bearing insight to verify

ADO has TWO notification scopes:
- **Personal** subscription (User Settings → Notifications) — self-serve, NO elevated rights.
- **Shared project/team** subscription (Project/Team Settings → Notifications) — needs admin rights.

The filer assumed the shared route → assumed they need a grant. If they only want notifications
for themselves, the personal route unblocks them with zero permission change (least-privilege).

## Success criteria

1. requirements.md fully consumed ✓
2. ADO notification mechanics verified against authoritative Microsoft docs (portal nav + permission + az/REST path) — NO fabricated API ids
3. how-to in .md + .html (zero-context engineer can execute)
4. runbook IFF repeatable (it is — platform team gets these recurrently)
5. any fix authorization-gated
