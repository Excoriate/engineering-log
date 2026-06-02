---
task_id: 2026-06-02-002
agent: eneco-context-slack-research
status: complete
summary: Slack search for VPP Aggregation Layer Kafka cert expiry/rotation. Owner = Fabrizio Zavalloni (with Roel van de Grint) on Trade Platform; certs requested via Networking4All/ServiceNow. Strong precedent: a Dec-2025 company-wide ESP cert rotation was already in progress ("Fabrizio is already rotating all certificates right now"), and a Sep-2025 Aggregation-layer expired-secret incident in sandbox/acc. A dedicated #expiring-certificates monitoring bot exists but does NOT list the already-expired esp-eet-vpp-dt/-acc certs. The exact recent "kafka cert dev/test not in good format" request thread did NOT surface via keyword search (A3 — likely a Slack List intake card).
timestamp: 2026-06-02
---

# Slack Context — VPP Aggregation Layer Kafka Certificate Expiry / Rotation

Source workspace: Eneco Online (grid-eneco.enterprise.slack.com), authenticated as user `U09H7TBJFSQ`. Slack MCP search/read tools available — NOT blocked.

Search executed: 12 searches across `slack_search_public_and_private` + 1 thread read + 1 channel read + 1 user lookup. Query variants run: `kafka certificate dev test`, `esp-eet-vpp`, `vpp-agg cert certificate rotation`, `streaming.eneco.com kafka`, `kafka cert not in good format dev test`, `vpp-agg-sb keyvault kafka certificate sandbox`, `aggregation layer certificate expired`, `kafka certificate dev test in:#myriad-platform`, `esp certificate renewal vpp rotating all certificates`, `kafka cert dev test vpp aggregation`. Date-filtered variants (after 2026-05-01 / 2026-05-25) also run.

## TL;DR (for the on-call / RCA author)

- **Owner of VPP/Agg Kafka (ESP) cert rotation**: **Fabrizio Zavalloni** (`U07FQLZF2MN`, fabrizio.zavalloni@eneco.com), Trade Platform, with **Roel van de Grint** (`U063YE3HGAD`) as the historical fallback who creates Axual apps and plugs certs. [A1]
- **How certs are obtained**: Networking4All issues them (PFX/P12 keystore) via a ServiceNow ticket; Integration/ESP team requests them; DigiCert Global Root G2 only; 1-year validity. [A1]
- **Prior precedent — directly relevant**: A **company-wide ESP/VPP certificate rotation was already in progress in Dec 2025** ("Fabrizio is already working on rotating all certificates right now", 2025-12-19). VPP and Agg historically **share the same ESP certs** (called out as "not correct"). [A1]
- **Prior expiry incident (same family)**: 2025-09-08, Tiago reported Aggregation-layer **sandbox + (suspected) acceptance broken due to an expired/invalid secret**; Fabrizio + Abhilash handled it. Touches the exact KVs in scope (`vpp-agg-sb`, `vpp-agg-appsec-d/-a/-p`). [A1]
- **Monitoring gap (notable)**: A dedicated **#expiring-certificates** bot channel (`C0AH801T95F`) posts a weekly expiry digest by Common Name. It tracks `*.streaming.eneco.com` ESP certs — **but `esp-eet-vpp-dt` / `esp-eet-vpp-acc` do NOT appear in any Mar–Jun 2026 digest**, consistent with them having already expired on 2026-01-10 (the bot only lists not-yet-expired certs). [A1/A2]
- **The exact recent request thread** ("kafka cert for dev and test, not in good format") **was NOT found** via keyword search. [A3 — not found]

## (a) Relevant messages / threads

### A1 — Owner & in-progress rotation: #myriad-platform thread, Dec 2025

Parent: Alexandre Freire Borges, 2025-12-15 13:46 CET, `C063SNM8PK5` ts `1765802808.374279`.
[permalink](https://grid-eneco.enterprise.slack.com/archives/C063SNM8PK5/p1765802808374279)

Most load-bearing replies (read in full via `slack_read_thread`):

- Reply 16 — **Roel van de Grint**, 2025-12-15 16:12: "To do this really properly, we would need to get new ESP certificates to represent the new application. **Currently VPP and Agg use the same certs, which is also not correct.**" [A1]
- Reply 35 — **Roel van de Grint**, 2025-12-16 09:55: "We just got new certs, so I'll plug the new one." → Reply 36: "certs are configured on the environments in Axual." [A1]
- Reply 40 — **Roel van de Grint**, 2025-12-19 10:21 (`1766136115.051159`): "Hey Alex, **Fabrizio is already working on rotating all certificates right now.** Can you please align with him? You guys can reuse the vpp-core certs for now and then discuss all separate certs in januari." [A1]
  [permalink](https://grid-eneco.enterprise.slack.com/archives/C063SNM8PK5/p1766136115051159)

> A2 INFER: The Dec-2025 rotation effort + the "discuss all separate certs in januari" plan is the most likely origin of the 2026-05-29 sandbox-vault rotation (`vpp-agg-sb`). The dedicated `esp-eet-vpp-dt`/`-acc` CNs are the "separate certs" that were deferred from the shared vpp-core certs. NOT confirmed by a direct message naming the 2026-05-29 rotation.

### A1 — Fabrizio runs ESP cert renewals operationally: #myriad-platform, 2026-01-07

Fabrizio Zavalloni, `C063SNM8PK5` ts `1767775244.216759`: "Just to inform that we will start the **ESP Certificates renewal CN=esp-eet-vpp-prd.streaming.eneco.com** soon... The maintenance has been done."
[permalink](https://grid-eneco.enterprise.slack.com/archives/C063SNM8PK5/p1767775244216759) [A1]

> A2 INFER: This is the PRD counterpart of the in-scope dt/acc certs. Same CN family (`esp-eet-vpp-*.streaming.eneco.com`), same owner. Confirms Fabrizio is the operator who runs `esp-eet-vpp-*` renewals.

### A1 — Prior Aggregation-layer expiry incident: #myriad-platform, 2025-09-08

Tiago Santos Rios, `C063SNM8PK5` ts `1757315192.924619` (14 replies): "I noticed that some **Aggregation layer environments (at least sandbox and acceptance) are currently broken due to an invalid secret (I believe expired)** ... make sure that Production is not going to fail soon?" Handled by Fabrizio Zavalloni + Abhilash Keloth. Thread explicitly enumerates the in-scope KVs: `vpp-agg-sb, vpp-agg-appsec-d, vpp-agg-appsec-a and vpp-agg-appsec-p`.
[permalink](https://grid-eneco.enterprise.slack.com/archives/C063SNM8PK5/p1757315192924619) [A1]

> A2 INFER: This is a near-identical prior incident (Agg-layer secret expiry, sandbox+acc, same KVs, same owner). Establishes a recurrence pattern: Agg-layer credential expiry hits sandbox/acc and is fixed reactively, with PRD checked "for sanity". The fix in 2025-09 was a secret restart/refresh, not the structural fix.

### A1 — Cert procurement procedure (how a new esp-eet-vpp cert is obtained): #apollo-scheduling-devs, 2026-05-07

Mykola Levchenko + Fabrizio, `C09GH11RCH1` ts `1778153095.950339`: shows the exact procedure for a sibling cert — extract CN from PFX (`esp-eet-vpp-asset-scheduling-dt.streaming.eneco.com`), Networking4All issues PFX against a ServiceNow ticket, requires a valid CSR/CN. "When we first got our certificates, Roel shared them with us directly."
[permalink](https://grid-eneco.enterprise.slack.com/archives/C09GH11RCH1/p1778153095950339) [A1]

### A1 — The CN family for the broken symptom: #apollo-scheduling-devs, 2026-02-09

Martijn Meijer + Izi Hitimana, `C09GH11RCH1` ts `1770644446.630269`: shows the exact runtime failure mode for an `esp-eet-vpp-*` Kafka client cert — KeyVault secrets `kafka-client-certificate` / `kafka-client-key`, error `x509 certificate routines::key values mismatch`, CN form `esp-eet-vpp-asset-scheduling-prd.streaming.eneco.com`.
[permalink](https://grid-eneco.enterprise.slack.com/archives/C09GH11RCH1/p1770644446630269) [A1]

> A2 INFER: Directly relevant to the "not in good format" symptom — a cert/key mismatch or wrong PEM extraction produces this exact class of error. Corroborates lessons-learned LL on "PEM not in good format = read-method/format artifact".

### A1 — #expiring-certificates monitoring channel (NOT in skill registry — harness gap)

Bot `B0AGV1FUCH0`, channel `C0AH801T95F`. Weekly digest "These certificates are expiring soon... order via ServiceNow". Latest read 2026-06-01 (`1780318886.442279`) + 5 prior weeks.
[permalink](https://grid-eneco.enterprise.slack.com/archives/C0AH801T95F/p1780318886442279) [A1]

- The digest DOES list `streaming.eneco.com` / `streaming-dta.eneco.com` ESP CNs (e.g. `esp-eet-nifi-*`, `esp-greenbyte-*`, `esp-dms-*`, `esp-jedlix-adapter-*`, `esp-eet-python-*`) and `*.vpp.eneco.com`, `dev-mc.vpp.eneco.com`. [A1]
- It does **NOT** list `esp-eet-vpp-dt` or `esp-eet-vpp-acc` in any digest from 2026-03 through 2026-06. [A1]

> A2 INFER: The bot reports only certs that are *about to* expire (within 7/30 days), not certs that already expired. Because `esp-eet-vpp-dt/-acc` expired 2026-01-10, they fell off the radar before any 2026-Q2 digest — explaining why the expiry went unflagged in the monitoring channel. This is the structural blind spot, not a missing cert.

## (b) Who owns the cert rotation

- **Primary operator**: **Fabrizio Zavalloni** (`U07FQLZF2MN`) — runs ESP cert renewals (`esp-eet-vpp-prd` 2026-01-07; led the 2025-09 Agg-layer expiry fix; named by Roel as the person "rotating all certificates" in Dec 2025). [A1]
- **Historical owner / unblocker**: **Roel van de Grint** (`U063YE3HGAD`) — creates Axual applications, plugs certs into Axual environments, manages the Networking4All contact list, requests/configures certs. Explicitly says this "should be self-service for you guys" — i.e. ownership is intended to move to the requesting team. [A1]
- **Issuer**: Networking4All (external), via a ServiceNow catalog ticket; certs delivered as PFX/P12. [A1]
- A how-to exists: **`platform-documentation` repo → How-To-Guides/Certificates/esp-certificates-renewal.md** (PR 118713, authored Mar 2025 by Roel/Fabrizio). [A1 — referenced in #team-platform 2025-03-26 `1742978907.105529`]

## (c) Prior precedent for THIS expiry

- **Yes, strong precedent.** 2025-09-08 Aggregation-layer expired-secret incident (sandbox + acc, same KVs `vpp-agg-*`) — same failure shape, same owner. [A1]
- **Yes, an in-flight rotation effort.** Dec 2025 company-wide ESP/VPP cert rotation, with the explicit note that VPP and Agg shared certs (incorrectly) and that "separate certs" were to be discussed in January 2026. [A1]
- General pattern: Eneco-wide ESP/Axual cert expiry waves are routine (Jan/Feb 2025 code.eneco.com + apigee-teamcode waves; recurring "more certificates about to expire"). Cert expiry is a known, recurring operational class. [A1]

## (d) Does the current request have an existing thread / owner?

- **Owner: YES** — Fabrizio Zavalloni (operator) + Roel van de Grint (fallback). [A1]
- **Existing thread for THIS exact 2026 "kafka cert for dev and test, not in good format" request: NOT FOUND via search.** [A3 — not found]
  - Searched `kafka cert not in good format dev test`, `kafka certificate dev test in:#myriad-platform` (after 2026-05-01), `kafka cert dev test vpp aggregation` (after 2026-05-25). No matching recent #myriad-platform message surfaced.
  - A2 INFER on WHY: #myriad-platform intake uses **Slack Lists request cards** (bot-driven, `slack.com/lists/...` record_ids — visible in #help-core-platform digests). Free-text keyword search does NOT index List-card field content, so an intake card titled around "kafka cert dev/test" would not appear in these results. The request likely exists as a List card, not a plain threaded message.
  - Resolving probe (not done here — out of Slack-search scope): open the #myriad-platform Slack List intake and filter records by date ~2026-05/06, or ask the requester directly for the record_id.

## (e) Explicit nothing-found items

- `streaming.eneco.com kafka` → 0 results. [A3]
- `kafka certificate format dev test from:U07FQLZF2MN` → 0 results. [A3]
- Any message naming the **2026-05-29 sandbox rotation** of `vpp-agg-sb` directly → NOT FOUND. The 2026-05-29 date is inferred from the vault, not from a Slack message. [A3 — not found]
- Any message naming `esp-eet-vpp-dt` or `esp-eet-vpp-acc` by exact string → NOT FOUND (closest is the `-asset-scheduling-dt/-prd` and `-prd` siblings). [A3 — not found]
- The exact original 2026 requester's identity → NOT CONFIRMED via search (no surfaced thread). [A3 — not found]

## Harness notes (for ddd / skill maintenance)

- **NEW CHANNEL** not in `eneco-context-slack` registry: `#expiring-certificates` (`C0AH801T95F`) — bot-driven weekly cert-expiry digest by Common Name. High-signal for any cert-expiry on-call task. Recommend adding to the channel registry under a "Certificates / Security" group, with the caveat that it only lists not-yet-expired certs (already-expired certs are invisible there).
- People confirmed: Fabrizio Zavalloni `U07FQLZF2MN`, Roel van de Grint `U063YE3HGAD`, Tiago Santos Rios `UUDNLFD3J`, Abhilash Keloth `U07EV8KQ7SA`, Alexandre Freire Borges `U064ECTTXQQ`.

## Evidence labels

- **A1 FACT** — cited Slack message: channel ID + timestamp + permalink + verbatim/near-verbatim quote, returned by `slack_search_public_and_private` / `slack_read_thread` / `slack_read_channel`.
- **A2 INFER** — derived from A1(s) via the named reasoning; not directly stated in any single message.
- **A3 UNVERIFIED[not found / blocked]** — search returned no result; the blocking reason (List-card indexing, already-expired invisibility, out-of-scope probe) is named alongside.
