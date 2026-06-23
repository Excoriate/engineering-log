---
title: Slack Harvest — Duncan Teegelaar FBE / App-Config 401 Filing (Rec0BC1FTLV35 + Rec0BBGJ9DMFU)
type: research
status: complete
task_id: 2026-06-22-006
timestamp: 2026-06-22T14:05:00+02:00
agent: eneco-context-slack-harvester
summary: Verbatim harvest of both Duncan Teegelaar Slack-Lists records — EARLIER (Rec0BBGJ9DMFU, Done) resolved by-design as private-endpoint App Config (use AVD); NEW (Rec0BC1FTLV35, In progress, assignee Alex Torres) reports 401s while ON AVD with zero replies/no resolution yet; the by-design network explanation does not cover the new 401-on-AVD symptom, which most resembles AVD-VM-identity authorization failure.
---

# Slack Harvest — Duncan Teegelaar FBE / App-Config 401 Filing

Harvest of the Trade Platform Slack-Lists intake (list `T039G7V20 / F0ACUPDV7HU`,
channel `#myriad-platform` `C063SNM8PK5`, tracker channel
`#FC:F0ACUPDV7HU:Help requests tracker Platform` `C0ACUPDV7HU`) plus all reachable
thread replies and related messages. Workspace `grid-eneco.enterprise.slack.com`.
Harvested 2026-06-22 by the on-call Slack context harvester (logged-in user
`U09H7TBJFSQ` = Alex Torres). All quotes verbatim; load-bearing claims labelled A1/A2/A3.

## Evidence access note (read before trusting record fields)

- `slack_search_public_and_private` (message search) does NOT return the body of a
  Slack-Lists *record*. It returns only the bot announcement card
  ("`<user> filed a <…|request>`") posted in `#myriad-platform`. **A1 FACT** — search
  for `Rec0BC1FTLV35` returns exactly one result, the General Request bot card, with
  empty text body (ts `1782125389.434079`).
- The verbatim record fields (Details / Assignee / Status / dates) were recovered by
  reading the underlying Slack-Lists CSV export, file `F0ACUPDV7HU`
  ("Help requests tracker Platform", text/csv, 250.1 KB, created 2026-02-04). The CSV
  columns are: `Request, Priority, Submitted by, Date submitted, Details, Assignee,
  Status, Completed, Due Date`. **The CSV does not contain the `record_id` strings**,
  so the two records were matched to CSV rows by submitter + date + verbatim Details
  text (A2 binding, high confidence — exact-text match on a unique long quote).
- Thread replies attach to the bot-card / Slackbot "A comment was added" parent in the
  TRACKER channel `C0ACUPDV7HU`, not under the `#myriad-platform` card.

---

## 1. Verbatim text of BOTH Slack-Lists records

### 1a. NEW record — Rec0BC1FTLV35

- **A1 FACT** (CSV row, file `F0ACUPDV7HU` line 2456) — verbatim:
  - **Request (title):** `Asset Optimization`
  - **Priority:** *(empty)*
  - **Submitted by:** `duncan.teegelaar@eneco.com`
  - **Date submitted:** `6/22/26, 12:49 PM`
  - **Details (verbatim):** `It's similar to my earlier one from Thursday about feature flags and FBEs. Now I have Jupiter FBE and I am looking at it though AVD, but the calls for app configuration are failing. So the FFs cannot be set properly as I am getting 401's.  I can see the FFs set properly in the app config. Am I missing something?`
  - **Assignee:** `alex.torres@eneco.com`
  - **Status:** `In progress`
  - **Completed:** `false`
  - **Due Date:** *(empty)*
- **A1 FACT** — filing announced in `#myriad-platform` by `General Request` bot
  (`B0B35S3GJD7`) at 2026-06-22 12:49:49 CEST, ts `1782125389.434079`, text:
  `<@U07PELC2C30|Duncan Teegelaar> filed a <https://grid-eneco.enterprise.slack.com/lists/T039G7V20/F0ACUPDV7HU?record_id=Rec0BC1FTLV35|request>`.
  Permalink: https://grid-eneco.enterprise.slack.com/archives/C063SNM8PK5/p1782125389434079
- **A1 FACT** — `slack_read_thread(C063SNM8PK5, 1782125389.434079)` returns
  `No thread messsages` (sic). **This NEW record has ZERO replies / no diagnosis / no
  resolution as of harvest time.** It was filed ~13 minutes after the on-call override
  handing primary from Alex Torres to Roel van de Grint (11:10 → 14:00, see §3).

> Note the literal Details text says "though AVD" (typo for "through AVD"); the
> coordinator's brief paraphrased it as "through AVD". The verbatim is "though".

### 1b. EARLIER record (Thursday) — Rec0BBGJ9DMFU

- **A1 FACT** (CSV row, file `F0ACUPDV7HU` lines 946–952) — verbatim:
  - **Request (title):** `VPP frontend`
  - **Priority:** *(empty)*
  - **Submitted by:** `duncan.teegelaar@eneco.com`
  - **Date submitted:** `6/18/26, 11:51 AM`
  - **Details (verbatim, multi-line):**

    ```text
    Preface: I have not worked on VPP in a bit so I don't remember exactly how it used to be.

    Has something changed regarding feature flags? I do not know how long this has been, but I feel like before I could fetch the feature flags on dev-mc with just my VPN. Now it does not work (anymore) but it does work on AVD.

    I also noticed with FBEs that feature flags are inconsistent on VPN; sometimes they work, sometimes they don’t. I am recreating an FBE that did not succeed in fetching the FFs yesterday, so let's see.

    I also feel like before I could've seen the FFs while on VPN, but again not sure. https://portal.azure.com/#@Eneco.onmicrosoft.com/resource/subscriptions/839af51e-c8dd[…]Configuration/configurationStores/vpp-applicationconfig-d/ff
    ```
  - **Assignee:** `Nuno.AlvesPereira@eneco.com`
  - **Status:** `Done`
  - **Completed:** `true`
  - **Due Date:** *(empty)*
- **A1 FACT** — filing announced in `#myriad-platform` by `General Request` bot at
  2026-06-18 11:51:34 CEST, ts `1781776294.992429`, text:
  `<@U07PELC2C30|Duncan Teegelaar> filed a <…record_id=Rec0BBGJ9DMFU|request>`.

> The App Config store URL in Duncan's text resolves (per coordinator brief +
> verbatim fragment) to `vpp-applicationconfig-d` in RG `mcdta-rg-vpp-d-res`, sub
> `839af51e-c8dd-4bd2-944b-a7799eb2e1e4` (dev-mc). **A1** — sub id and `/configurationStores/vpp-applicationconfig-d/ff` are present verbatim in the CSV line 952.

---

## 2. All thread replies / responses + RESOLUTION / root cause

### 2a. EARLIER record (Rec0BBGJ9DMFU) thread — `C0ACUPDV7HU`, parent ts `1781776290.916239`

**A1 FACT** — `slack_read_thread(C0ACUPDV7HU, 1781776290.916239)`, 5 replies verbatim:

1. **Duncan Teegelaar** (U07PELC2C30) — 2026-06-18 12:13:22 CEST, ts `1781777602.256799`:
   `I got confirmation that indeed it works on AVD for dev-mc and up, it should not with just VPN.  I'll investigate a bit more later today on if it still happens on an FBE.`
2. **Duncan Teegelaar** — 2026-06-18 14:37:06 CEST, ts `1781786226.657159`:
   `This ticket can be closed for now. I cannot reproduce it anymore and it seems fine now. Once I will see it again, I will report it again :smile:`
3. **Nuno Alves Pereira** (U0A5T5MHRJ8) — 2026-06-19 09:53:04 CEST, ts `1781855584.412339`:
   `Hi <@U07PELC2C30|Duncan Teegelaar>, sorry, just got around to look at this now`
4. **Nuno Alves Pereira** — 2026-06-19 09:55:11 CEST, ts `1781855711.220489` — **THE STATED ROOT CAUSE / RESOLUTION (A1 FACT):**
   `But yes, this is how it works by design. The App Configuration you are using is private endpointed, so there is no of sight outside the VNet. AVD is the way forward here`
5. **Duncan Teegelaar** — 2026-06-19 09:55:50 CEST, ts `1781855750.374489`:
   `Ah, thanks for the confirmation! It was a while back that I was involved in VPP things so I was a little confused on how it worked. But thanks!`

**A2 INFER (resolution of EARLIER ticket):** Root cause stated by the platform team
(Nuno, the assignee) is **by-design network isolation** — the dev-mc App Configuration
store `vpp-applicationconfig-d` is **private-endpointed (no line of sight outside the
VNet)**, so feature-flag fetches succeed from AVD (inside the VNet) but fail from
plain Eneco VPN. The prescribed answer is "use AVD." It is NOT an access-key /
RBAC / secret bug. Ticket status `Done`. (Derived from replies 2 + 4; both A1.)

### 2b. NEW record (Rec0BC1FTLV35) thread

**A1 FACT** — no thread, no replies, no resolution (see §1a). Status `In progress`,
assignee Alex Torres. This is the OPEN item the RCA must address.

### 2c. Related cross-channel context on the SAME problem (Duncan, last ~1 week)

These are NOT the Lists-record threads but are Duncan discussing the identical
symptom days before/around filing — directly load-bearing for the RCA.

**A1 FACT** — `#myriad-releases` (C064CQ0NAGZ), R155-on-DEV thread, parent ts
`1781773139.061449`, 2026-06-18 (`from:<@U07PELC2C30>` search):

- Jove Dojchinovski (U09BUB7H2P4) 11:18:59: `R155 is on DEV :bananadance2:`
- Duncan 11:10:01, ts `1781773801.495699`:
  `I am unsure, but the feature flags seem to be failing on FE? Also the thing I was investigating regarding no update events from monitor (on the portfolio with the market cards) is happening on dev-mc. While it is not happening on sandbox. Any idea?`
- Duncan 11:14:33, ts `1781774073.908399`:
  `<@U063XG59ZFV|Stefan Klopf> is very sharp (we briefly talked about this yesterday already for my FBE) and it's most likely because of the failing FFs that we do not get the update events`
- Duncan 11:32:31, ts `1781775151.957579`:
  `No, not that I know of. It seems to work on AVD and I was checking with VPN. Starting up the AVD now`
- Duncan 11:36:26, ts `1781775386.365089`: `Yeah, I have the same thing with using VPN.`
- Duncan 11:36:41, ts `1781775401.903089`:
  `But it seems it still works on AVD, so false alarm (but I still want to verify myself)`
- Stefan Klopf (U063XG59ZFV) 11:37:00, ts `1781775420.071939`:
  `From the AVD everything seems to work. I can see the FF on appconfig`
- Jove 11:42:01 (file F0BBGEVLDDG, screenshot): asked `is there any specific message why the FF fails?`
- Duncan 11:41:48, ts `1781775708.710499`:
  `No just connection timed out. But it works on AVD so there is not a big urgent issue I would say. I will contact platform to ask about the FFs since I saw this behaviour happening on some FBEs as well`

**A2 INFER:** Duncan's own symptom for the EARLIER (VPN-vs-AVD) issue was a
**connection timeout**, not a 401 — consistent with Nuno's private-endpoint /
no-VNet-line-of-sight by-design diagnosis. The NEW record is different: it reports
**401s while ON AVD** (i.e. inside the VNet, network reachable), which the EARLIER
by-design network explanation does NOT cover. (Derived from §1a "looking at it though
AVD … getting 401's" vs §2c "connection timed out … works on AVD".)

---

## 3. Related #myriad-platform / tracker messages (App Config / FF / 401 / access-key /
private endpoint / VPN-vs-AVD), last ~2 weeks and key precedents

### Current on-call + concurrent dev-mc incident context (A1 FACT, channel read of C063SNM8PK5)

- 2026-06-22 09:00:21 CEST, ts `1782111621.626049` — Rootly: `*<@U09H7TBJFSQ|Alex Torres> is now on-call* for trade-platform-primary … Ends Jun 22, 5:00 PM CEST`.
- 2026-06-22 11:12:34 CEST, ts `1782119554.409439` — Rootly override: `Original owner: Alex Torres → New owner: Roel van de Grint`, time range `June 22 11:10 AM → 2:00 PM CEST`. (So Roel held primary when the NEW record was filed at 12:49.)
- 2026-06-19 — dev-mc ArgoCD / pod-replacement incident (CMC `INC0260956`), opened by Nuno 14:48:08 (`There is currently an issue with replacing Pods in dev-mc in Development`), temporary fix 15:24, `ArgoCD on dev-mc is back in business` 17:20:48 by Roel. Relevant only as concurrent dev-mc noise; not the FF/401 cause.

### Duncan's parallel ArgoCD dev-access thread (A1 FACT, C0ACUPDV7HU parent ts `1781083751.904859`)

Duncan also had a separate dev-mc ACCESS gap being worked the same week:

- Michael Ströh (U0A9ZCM050D) 2026-06-11 15:10:23 — created PRs + CMC tickets granting Duncan + Erik Lumbela + Ricardo Duncan access (gitops-vpp PR 181975, RITM0189120 etc.).
- Michael 2026-06-19 10:56:25: `can you please verify that you now have access to Argo in all envs? Specifically dev.`
- Duncan 2026-06-19 11:13:51, ts `1781860431.567649`: `Hi Michael, I can sync on acc & prd, but not dev yet. Still getting:` (+ screenshot F0BBU52NP6V).
- Michael 2026-06-19 11:22:14: `Thanks for the feedback, we are going to have to raise a ticket to CMC for dev. I will keep you up to date.`

**A2 INFER:** As of 2026-06-19 Duncan had ArgoCD access on acc & prd but NOT dev-mc
(CMC ticket pending). This is an access/RBAC gap on the dev-mc plane and may be
related to the NEW 401-on-AVD record, but the two are not explicitly linked in any
message — flagged as a candidate enabling factor, NOT confirmed. **A3 UNVERIFIED
[blocked: no message ties the ArgoCD dev-access gap to the App-Config 401].**

### High-value precedents (same failure family, older — A1 FACT, message search of C063SNM8PK5)

- **2025-01-30, ts `1738229396.927149`** (Nykyta Kozhevnykov, the closest analog to the NEW 401):
  `Guys, can anyone give me a hand please? I need to connect from my local laptop to dev-mc app config, but getting 401. Although i can navigate through other tabs. Does anyone know of some special permission/roles?` →
  Roel van de Grint: `Does this work from your AVD?` → Nykyta: `yes` →
  Roel (ts `1738229676.068869`, **the policy statement**):
  `Please use that for now. Since this is an MC environment, we cannot just open up networking for random things. … But it's still an MC environment, and the normal rule there is 'everything through AVD'`.
  → Alex Shmyga later: `have you tried from VPN?`
  **A2 INFER:** Same canonical platform answer for dev-mc App-Config 401: MC
  environment, access is via AVD; networking is locked down by design.
- **2025-07-03 thread, parent ts `1751535766.953989`** (Ihar Bandarenka / Dmytro Ivanchyshyn / Alexandre Freire Borges): AVD-based local dev getting `403 Forbidden` from Key Vault (`vpp-aks-d`), error `does not have secrets get permission on key vault`. Fabrizio Zavalloni diagnosis: `In the Alexandre case, it was using the AVD VM Identity to access the Key vault. … these AVD are recreated time to time.` **A2 INFER:** AVD VM managed-identity drift after AVD recreation is a known cause of 401/403 against KV/App-Config from inside AVD — a candidate mechanism for the NEW "401 on AVD" record (identity, not network).
- **2025-06-16 thread, parent ts `1750073583.800809`** (Anton Kultsov / Andrew Casswell): App Config (`appcs-vpp-btm-dev.azconfig.io`) DNS started resolving to private IP `10.7.40.71`; works from some AVDs, not others / not VPN. Fabrizio: `For ACC and PRD all external access are disabled` / `Internal communication should go through private network`. **A2 INFER:** private-endpoint/DNS resolution issues produce the AVD-vs-VPN split — matches the EARLIER record's by-design explanation.
- **2025-09-18, ts `1758197165.214819`** (Duncan himself, FBE Kidu FF not showing): resolved when Roel pointed out the **App Configuration pipeline was waiting for approval**; once approved the FF appeared. Duncan: `Who would've thought... it's there! Magic! … I overlooked the fact it needed to be approved.` **A2 INFER:** a *separate* FF-not-visible cause (un-approved config pipeline) — different from a 401, but shows Duncan's prior FF/App-Config history and that "FF not present" ≠ "401".

---

## 4. Who is Duncan + ticket status

- **A1 FACT** (`slack_search_users("Duncan Teegelaar")`):
  - Name: **Duncan Teegelaar**; User ID `U07PELC2C30`; Email `duncan.teegelaar@eneco.com`.
  - **Title: `Frontend Software Engineer | VPP & Flex Trading Optimizer | Tech`**;
    Timezone Europe/Amsterdam.
  - Permalink: https://grid-eneco.enterprise.slack.com/team/U07PELC2C30
- **A2 INFER:** Duncan is a **frontend engineer on the VPP / Flex Trade Optimizer (FTO)
  team** (corroborated A1 by his 2026-06-22 activity in `#myriad-ao-flex-trade-optimizer`
  releasing "FTO 0.0.5 to dev-mc" and his Lists record titles "VPP frontend" /
  "Asset Optimization"). He is a CONSUMER of the platform, not a platform-team member;
  he states himself: `I have not worked on VPP in a bit so I don't remember exactly how
  it used to be` (A1, §1b).

### Ticket status (A1 FACT, CSV)

| Record | record_id | Title | Date | Assignee | Status | Completed |
|---|---|---|---|---|---|---|
| NEW | `Rec0BC1FTLV35` | Asset Optimization | 6/22/26 12:49 PM | alex.torres@eneco.com | **In progress** | false |
| EARLIER | `Rec0BBGJ9DMFU` | VPP frontend | 6/18/26 11:51 AM | Nuno.AlvesPereira@eneco.com | **Done** | true |

- **EARLIER (Rec0BBGJ9DMFU): RESOLVED / Done** — closed as by-design (private-endpoint,
  use AVD); Duncan himself said it could be closed and could not reproduce. (A1)
- **NEW (Rec0BC1FTLV35): OPEN / In progress**, assigned to Alex Torres, NO replies yet.
  This is the live item. (A1)

---

## 5. Synthesis flags for the RCA coordinator (clearly labelled inference)

- **A2 INFER — the two records are NOT the same failure:** EARLIER = FF fetch fails on
  *VPN*, works on *AVD*, symptom = connection timeout → resolved as by-design private
  endpoint. NEW = app-config calls fail with *401 while ON AVD* → the by-design network
  explanation does NOT apply (AVD is inside the VNet). The NEW record's mechanism is
  most consistent with an **identity/authorization failure from the AVD VM identity**
  (cf. 2025-07-03 AVD-VM-identity-after-recreation precedent) rather than a network
  reachability problem. This is the central open question.
- **A3 UNVERIFIED[blocked]:** No message states the resolution/root cause of the NEW
  401-on-AVD record (it has zero replies). Resolving path: monitor thread under
  `#myriad-platform` card ts `1782125389.434079` / tracker `C0ACUPDV7HU`, or ask the
  assignee (Alex Torres) / platform team directly; or reproduce against
  `vpp-applicationconfig-d` from an AVD session.
- **A3 UNVERIFIED[blocked]:** The Slack-Lists per-record *audit fields* beyond the CSV
  columns (e.g. created-vs-modified timestamps, comment history inside the Lists UI,
  who changed Status) are not exposed by the available MCP tools. Resolving path: open
  the list record URLs directly in Slack
  (`…/lists/T039G7V20/F0ACUPDV7HU?record_id=Rec0BC1FTLV35` and `…=Rec0BBGJ9DMFU`).

## Key people / IDs (A1 FACT)

| Person | ID | Role (per profile / activity) |
|---|---|---|
| Duncan Teegelaar | U07PELC2C30 | Frontend SWE, VPP & Flex Trade Optimizer (filer) |
| Nuno Alves Pereira | U0A5T5MHRJ8 | Platform team — assignee/diagnoser of EARLIER record |
| Alex Torres | U09H7TBJFSQ | On-call primary; assignee of NEW record (logged-in harvester user) |
| Roel van de Grint | U063YE3HGAD | Platform team; held on-call primary 11:10–14:00 on 2026-06-22 |
| Stefan Klopf | U063XG59ZFV | Engineer; corroborated FF-works-on-AVD |
| Jove Dojchinovski | U09BUB7H2P4 | Engineer in R155 release thread |
| Fabrizio Zavalloni | U07FQLZF2MN | Platform team; AVD-VM-identity / private-network precedents |
| Michael Ströh | U0A9ZCM050D | Handling Duncan's ArgoCD dev-mc access (CMC tickets) |
