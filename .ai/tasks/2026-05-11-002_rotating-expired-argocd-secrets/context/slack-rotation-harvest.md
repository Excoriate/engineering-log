---
task_id: 2026-05-11-002
agent: slack-harvest-sidecar
status: complete
summary: Historical Slack context on ArgoCD PAT rotation procedure
phase: 4
---

# Slack Rotation Harvest — ArgoCD PAT Rotation History

Scope: Eneco Online Slack, harvested 2026-05-11. Belief class: all findings INFER until coordinator source-verifies each permalink. Key IDs: Fabrizio `U07FQLZF2MN`, Roel `U063YE3HGAD`, Thomas `U08FYCD7PUM`, Nuno `U0A5T5MHRJ8`.

---

## Q1 — Fabrizio/Roel documented step-by-step ArgoCD PAT rotation procedure?

**Answer: NOT FOUND. Fabrizio explicitly stated "There is no documentation for this."**

Today's thread in `#team-platform` (C063YNAD5QA) ts 1778495545.088229 — permalink <https://eneco-online.slack.com/archives/C063YNAD5QA/p1778495545088229?thread_ts=1778495545.088229&cid=C063YNAD5QA>:
- Fabrizio 12:32:25 CEST: *"Has anybody renewed the Pat Token used by the Argocd in Sandbox?"*
- Alex 12:40:08: *"is there any documentation, or particular caveat that I need to know in advance?"*
- **Fabrizio 12:47:35: *"Nope. There is no documentation for this."*** Then: *"It is a good opportunity to create one."* / *"You can give me a call and I explain you the process."*

No ArgoCD PAT rotation procedure exists anywhere in Slack. Fabrizio carries it orally.

Top in-flight contender (still NOT a procedure, NOT ArgoCD): Fabrizio in `#myriad-platform` 2025-09-29 14:04:42 CEST: *"I have renewed the PAT Tokens used by the private build agents."* Permalink: <https://eneco-online.slack.com/archives/C063SNM8PK5/p1759147482097949>. Build-agent PATs only — evidence that rotations are announced post-hoc.

**Route impact**: runbook MUST flag `[PENDING: ask Fabrizio about documented rotation procedure]`. Vault recipe = primary source; Fabrizio's call = corroborating.

---

## Q2 — MC cluster ArgoCD PAT rotation history (devmc/accmc/prdmc, Goldilocks)?

**Answer: ONE observable mention, NO procedure.**

`#team-platform` C063YNAD5QA, 2026-03-03 14:10:07 CET, Roel van de Grint (inline, not threaded):
> *"Oh don't worry <@thomas.obrien>. I asked him to update a PAT for me in the CMC ArgoCD instance for the Goldilocks application"*

Permalink: <https://eneco-online.slack.com/archives/C063YNAD5QA/p1772543407795229>

Critical caveats:
- "him" unresolved; surrounding inline context names "Lex from CMC" — implying CMC-side staff executed it, NOT a platform-team member. No procedure, no PR link, no KV update mentioned.
- Implication: MC ArgoCD instance PATs may historically be **CMC-side-operated**, explaining the absence of procedure in our Slack.

`argo-cd-devmc OR argo-cd-accmc OR argo-cd-prdmc` returned 7 hits, all empty-text bot block-kit cards in `#myriad-alerts-devops` — these are the PAT-expiry alerts themselves; body content does not surface in search API. No hits for `repository-credentials argocd`, `argocd token renew` (beyond today), `goldilocks pat` (beyond Roel's March 3).

**Route impact**: runbook Section B (MC PATs) needs `[PENDING: ask Fabrizio about MC procedure]` AND `[PENDING: confirm CMC operates past Goldilocks PAT rotations]`. Likely MC procedure differs from sandbox.

---

## Q3 — Who/what generates the PAT-expiry report posted to `#myriad-alerts-devops`?

**Answer: A custom ADO pipeline introduced by PR 140615, monitoring PATs of `sa_platform_vpp@eneco.com`, posting to Slack daily ~13:01 CEST.**

Evidence:
1. Fabrizio 2025-09-18 11:51:02 CEST shared ADO PR 140615: *"Pull request 140615: Add monitoring for the PAT Tokens assigned to the account sa_platform_vpp@eneco.com"* (repo: `Myriad - VPP/devops`). Slack permalink: <https://eneco-online.slack.com/archives/C063YNAD5QA/p1758189062314439>. ADO URL: `https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/devops/pullrequest/140615`.
2. Roel 2025-04-01 in app-reg ownership thread: *"Oh wait, the secret expiration pipeline that pings to slack might use them?"* — corroborates pipeline mechanism. Permalink: <https://eneco-online.slack.com/archives/C063YNAD5QA/p1743503467818629?thread_ts=1743503467.818629&cid=C063YNAD5QA>.
3. Bot in `#myriad-alerts-devops` posts daily at ~13:01 CEST (consistent April-May 2026) — scheduled ADO pipeline.

**Mechanism (INFER, high confidence)**: ADO scheduled pipeline in `Myriad - VPP/devops` repo, reads PAT metadata via ADO API using `sa_platform_vpp@eneco.com`, posts block-kit cards to `#myriad-alerts-devops` via Slack webhook. Alert bodies surface only as fallback in search — coordinator must inspect the pipeline YAML directly.

**Route impact**: automation proposal CAN concretely reference PR 140615 as baseline. New rotation-automation likely extends or sits alongside this pipeline in the same repo.

---

## Q4 — Documentation linked from past PAT rotation messages?

**Answer: NO Confluence/ADO-wiki URL surfaced in any rotation message I retrieved.**

Surrogate evidence that the team's documentation surface for credentials is *not* the wiki:

`#team-platform` (C063YNAD5QA) 2026-01-23 15:56:50 CET, Roel van de Grint (parent ts 1769180210.695469):
> *"I've put the sa_platform_vpp account credentials in our Trade Platform Team vault. This is way cooler than sharing through a stupid KeyVault"*
> Reply: *"<@Fabrizio Zavalloni> try it out, it's awesome"*

Permalink: <https://eneco-online.slack.com/archives/C063YNAD5QA/p1769180210695469?thread_ts=1769180210.695469&cid=C063YNAD5QA>

Thomas OBrien reply context reveals vault supports private + business accounts on phone + macbook — **password-manager-style vault** (1Password / Bitwarden Team style), NOT a Confluence/ADO wiki page. `sa_platform_vpp` credentials live there.

Corroborating: Fabrizio in async standup 2026-04-17 mentioned *"Update the mfrr certificate rotation procedure doc"* (permalink <https://eneco-online.slack.com/archives/C063YNAD5QA/p1776413995423729?thread_ts=1776405204.846589&cid=C063YNAD5QA>) — proves he DOES author procedure docs for mfrr certs, yet today said none exists for ArgoCD PAT. Known gap, not unfound doc.

**Route impact**: no canonical doc to corroborate. Runbook becomes the first doc. Team password vault = credential store referent.

---

## Q5 — Dec 29 2025 F4 AAD SP rotation thread

**Answer: FOUND. Reactive outage, not pre-planned rotation.** Thread in `#myriad-platform` C063SNM8PK5 ts 1767014621.744099 — permalink <https://eneco-online.slack.com/archives/C063SNM8PK5/p1767014621744099?thread_ts=1767014621.744099&cid=C063SNM8PK5>.

Sequence (verbatim where load-bearing):
- Tiago Santos Rios 2025-12-29 14:23:41 CET (parent): Asset Planning API failing on FBE voltex, SQL secret expired.
- Stefan Klopf 14:28: same on Thor. Srinath Dussa 14:29: same on afi, logs cite app `6db398ec-8cb7-4398-a944-f842aa9a67da` (`AADSTS7000215: Invalid client secret provided`).
- **Fabrizio 14:48:23: *"Thor is fixed. I will have a look in the others."*** Then sequentially fixes Voltex, Jupiter, integrationtest (15:00→15:42 CET). 15:09: *"It might be needed to restart some applications."*
- Jan 2 / Jan 5 follow-up: Artem on Kidu — Fabrizio fixes; separate dns/Kusto config issue persists; recommended FBE recreation.

Pattern: the shared SP `6db398ec-…` expired in production-shared use across many FBEs. Fabrizio's pattern = discover-rotate-per-environment-tell-users-to-restart. No procedure, link, or doc posted — only outcomes. Lessons-learned text (`#inc-75` 2024-11-19, written by Fabrizio): *"This manual process is error-prone and must be automated to prevent such issues in the future."* Permalink: <https://eneco-online.slack.com/archives/C081GTVSZFD/p1732022060724869>.

**Implication for our task**: Fabrizio's style is per-environment, per-symptom, manual. The runbook should explicitly enumerate every consumer (KV entries, dependent applications needing restart) — "restart the applications" is a recurring footgun.

---

## Search Log

Workspace: Eneco Online. All searches via `slack_search_public_and_private` unless noted.

| Query | Hits | Top result |
|-------|-----:|------------|
| `"PAT rotation" OR "rotate PAT" OR "renew PAT" argocd` | 0 | — |
| `argo-cd-sandbox` | 20 | Fabrizio 2026-05-11; rest = empty-text bot in #myriad-alerts-devops |
| `argo-cd-devmc OR argo-cd-accmc OR argo-cd-prdmc` | 7 | Fabrizio 2026-05-11; rest = bot |
| `goldilocks pat` | 8 | Roel 2026-03-03; bot |
| `repository-credentials argocd` | 0 | — |
| `"PAT" expir*` | 19 | Fabrizio 2026-05-11; bot stream |
| `from:<@U063YE3HGAD> PAT goldilocks` | 1 | Roel 2026-03-03 |
| `from:<@U07FQLZF2MN> PAT` | 6 | Fabrizio 2025-09-18 (PR 140615); 2025-09-29 (build-agent PATs) |
| `argocd token renew` | 1 | Fabrizio 2026-05-11 |
| `"ApplicationGenerationFromParamsError"` | 0 | — |
| `secret refresh shift` | 1 | Roel 2025-09-18 |
| `from:<@U07FQLZF2MN> 6db398ec OR rotated OR rotation` | 13 | Fabrizio 2024-11-19 INC-75; 2025-04-01 ownership; 2026-03-30 appreg; 2026-04-10 DM |
| `"6db398ec"` | 3 | Srinath 2025-12-29; Fabrizio 2025-01-17; Dmytro 2024-11-15 |
| `FBE F4 secret rotation` | 15 | 2026-05-07 PXQ incident |
| `"sa_platform_vpp"` | 1 | Roel 2026-01-23 vault announcement |
| `"140615"` | 1 | Fabrizio 2025-09-18 |

Threads fully expanded: Fabrizio 2026-05-11 sandbox thread (4 replies); Tiago 2025-12-29 F4 thread (30 replies); Roel 2025-09-18 "secret refresh" (no replies — inline channel discussion only).

---

## Unexpected finds

1. **Automation is already prioritized by Fabrizio** — DM 2026-04-10 17:17:48 CEST: *"this is a shit job to be done and can cause outages."* Permalink: <https://eneco-online.slack.com/archives/D09K5LQSW0G/p1775834268694299>. Directly supports automation proposal angle.

2. **INC-75 post-mortem (2024-11-19)** authored by Fabrizio: *"This manual process is error-prone and must be automated to prevent such issues in the future."* Permalink: <https://eneco-online.slack.com/archives/C081GTVSZFD/p1732022060724869>. Already-documented org pain ~18 months old.

3. **PXQ incident 2026-05-07** — Ankit Senghani: *"client secret on keyvault has expired causing 401... how to rotate the secret for pxq client"*. Permalink: <https://eneco-online.slack.com/archives/C0B239D1FRR/p1778164253499109>. Pattern continues 4 days before today's task.

4. **2025-01-17 sandbox SP renew** reveals rotation surface = **ADO library variable groups** (`eneco-vpp-sandbox` variable group). Permalink: <https://eneco-online.slack.com/archives/C063SNM8PK5/p1737119656203549?thread_ts=1737119147.283369&cid=C063SNM8PK5>. Proves rotation touches >1 plane (KV + ADO variable groups, possibly more).

5. **Coordinator should inspect PR 140615 pipeline YAML directly** (`Myriad - VPP/devops` repo) — Slack search exposes the existence and naming but not the bot's full message bodies.

---

## Belief change per question — runbook plan deltas

- **Q1**: Drop "cite Fabrizio's procedure" branch. Runbook authors procedure for the first time; every step `[PENDING: validate with Fabrizio]`. Source-of-truth = team password vault + Fabrizio's call.
- **Q2**: Section B MUST carry `[PENDING: ask Fabrizio about MC procedure]` + `[PENDING: confirm CMC operates past Goldilocks PAT rotations]`. Hypothesis: MC ArgoCD PATs are CMC-side-operated; we file a request rather than execute.
- **Q3**: Automation proposal names `PR 140615` and `Myriad - VPP/devops` repo as concrete extension surface. Coordinator dispatches context-researcher to fetch pipeline YAML.
- **Q4**: Drop "find canonical doc to corroborate" branch. Vault stores `sa_platform_vpp` credentials; no procedure doc exists. Runbook becomes the first doc.
- **Q5**: Add `## Lessons from Dec 29 2025 outage` section: (a) per-env manual fix is Fabrizio's default; (b) "restart applications" is consistently forgotten; (c) INC-75 (2024-11-19) already prescribed automation — overdue.

End of report.
