---
title: "Lane B — Slack Organizational History: agg.dev / AVD / Johnson Lobo"
status: complete
task_id: 2026-06-02-004
agent: eneco-context-slack investigator (lane B sidecar)
summary: "Johnson Lobo's AVD/agg-access history harvested. The exact /healthz 404 on telemetryfunctiontestsfn was NOT reported before; the broader 'agg function not reachable from AVD / needs port-forward' pattern WAS (resolved 2026-04-13). agg.dev = SANDBOX (publicly reachable), NOT a CMC dev env; dev-mc agg is stale/being-retired."
---

# Lane B — Slack Organizational History

Read-only Slack harvest via `eneco-context-slack` skill (Grid-Eneco workspace, connector user U09H7TBJFSQ).
Evidence labels: **A1** = actual quoted Slack message (author + date + permalink). **A2** = my inference from A1s.

## Reporter identity resolution (A1)

The intake spelling "jhonson lobos / Jhonson Lobos / Johnson Lobos" does NOT match any Slack user.
The real reporter is **Johnson Lobo**.

- A1 — User profile: `Johnson Lobo`, User ID `U045CMAR078`, email `johnson.lobo@eneco.com`, title **"Developer - Myriad | VPPAL"** (VPP Aggregation Layer), TZ Europe/Amsterdam. [profile](https://grid-eneco.enterprise.slack.com/team/U045CMAR078)
- A1 — Confirmed in-context as a VPP Aggregation dev: Fabrizio Zavalloni, 2025-11-19 — "Sorry. I am in the Otel collector migration with @Johnson Lobo" ([link](https://grid-eneco.enterprise.slack.com/archives/C063YNAD5QA/p1763537470065729)).
- A2 — Searches using `from:@Johnson Lobo <keywords>` returned 0; the working form is `from:<@U045CMAR078>`. Initial misspelled-name user lookup is why a naive search would report "no history." This is a query-form artifact, not an absence of history.

## Q1 — Prior jhonson lobo messages re AVD / agg.dev / 404 / "not accessible"

### A1 — THE prior near-identical incident (2026-04-13), #Help requests tracker Platform (C0ACUPDV7HU)

Thread parent ts `1776068702.359409`. Johnson could not access aggregation siteregistry from AVD (was using OpenShift port-forward). Resolution given by Alex Torres (U09H7TBJFSQ):

- A1 — Alex Torres, 2026-04-13 11:31 — "the update StrikePrices can be done directly within your AVD; no need to access OpenShift console anymore. I've checked and you're in `rbac/groups/eneco_team_vpp_aggregation.yaml` ... Try to access it directly from your AVD. CC @Nuno Alves Pereira, **I'll also add this to our FAQ**." ([link](https://grid-eneco.enterprise.slack.com/archives/C0ACUPDV7HU/p1776072666717079))
- A1 — Johnson Lobo, 2026-04-13 11:34 — "Without the port forward, what is the other way to access directly inside AVD?" / "Can I access the site registry without port forward now?" ([link](https://grid-eneco.enterprise.slack.com/archives/C0ACUPDV7HU/p1776072874915249))
- A1 — Alex Torres, 2026-04-13 11:34 — "Hit the API directly: `https://agg.vpp.eneco.com/api/siteregistry`" ([link](https://grid-eneco.enterprise.slack.com/archives/C0ACUPDV7HU/p1776072880991469))
- A1 — Alex Torres, 2026-04-13 11:35 — "a curl respecting that API's verbs should suffice. No need to do the port-forward from OpenShift." ([link](https://grid-eneco.enterprise.slack.com/archives/C0ACUPDV7HU/p1776072915047639))
- A1 — Johnson Lobo, 2026-04-13 13:06 — "hey thanks guys for the input. **i can access it from AVD.**" then "you can close the ticket!" ([link](https://grid-eneco.enterprise.slack.com/archives/C0ACUPDV7HU/p1776078394187019))

### A1 — Other AVD-access history from Johnson Lobo (same recurring theme: agg service access from AVD)

- A1 — 2024-05-24, #myriad-platform — "Could you please give me access to 'siteregistry' database on MC environments? I get below error when i try to login from AVD." Resolved (had access via developers group). ([link](https://grid-eneco.enterprise.slack.com/archives/C063SNM8PK5/p1716537851620499))
- A1 — 2025-05-01, #myriad-platform — "i am trying to publish events from AVD to eventhub" → identity/app-registration rights issue; resolved same day. ([link](https://grid-eneco.enterprise.slack.com/archives/C063SNM8PK5/p1746099783712469))
- A1 — 2026-05-29, #Help requests tracker Platform — VPP-agg sandbox broken since a cert expiry "more than 6 months" ago; Johnson fixed a missing `keys` secret manually; debate over whether secrets should come via secret provider. NOT a 404/AVD-routing issue. ([link](https://grid-eneco.enterprise.slack.com/archives/C0ACUPDV7HU/p1780060759004509))

### A1 — The exact /healthz 404 on telemetryfunctiontestsfn: NOT found in Johnson's history

- A1 — Author-scoped searches (`from:<@U045CMAR078>` + healthz/404/telemetryfunctiontestsfn/rewrite) returned **0 results**. Query syntax validated against a known-good author search that DID return 20 results, so this is a genuine absence.
- A2 — The current ticket's specific symptom (`/telemetryfunctiontestsfn/healthz` → 404 while `/api/siteregistry` works) has **no prior Slack report**. What recurs is the broader "agg function not reachable from AVD / had to port-forward" class, last resolved for siteregistry on 2026-04-13.

## Q2 — Prior discussion of telemetryfunctiontestsfn / deliveryreportfn / agg ingress routing / rewrite / path prefix

### A1 — telemetryfunctiontestsfn ingress is an actively-managed Helm chart

- A1 — Roel van de Grint, 2024-07-09, #myriad-team-wattsup — "Here is the ingress/service update for all 3 services that use it." (links `.../Helm/telemetryfunctiontestsfn/values.yaml`, PR 87440). ([link](https://grid-eneco.enterprise.slack.com/archives/C063S88FY91/p1720534155501339))
- A1 — Roel van de Grint, 2025-11-19, #team-platform / #myriad-team-wattsup — PR 150758 "updated ingress to make ingressclass configurable and tls optional" touching `.../Helm/telemetryfunctiontestsfn/templates/ingress.yaml`; part of an ingress-controller migration ("align with the new setup on sandbox"). ([link](https://grid-eneco.enterprise.slack.com/archives/C063YNAD5QA/p1763537470065729))
- A2 — The telemetryfunctiontestsfn ingress was edited as recently as 2025-11 during an ingress-controller migration. Plausible that the no-rewrite-target behavior is a side-effect of that migration, but **no Slack message explicitly discusses rewrite-target / path-prefix rewrite** (see below).

### A1 — Original exposure design (2024-04-02), #myriad-platform — the foundational thread

Thread parent ts `1712059395.516219` (Illia Larka, agg team). This is where agg functions were first exposed out of clusters via ingress path-mapping.

- A1 — Illia Larka, 2024-04-02 — "The aggregation layer team needs to expose new function out of clusters... swagger page should be accessible on DevMC and Acceptance, but for Production only by portforwarding." ([link](https://grid-eneco.enterprise.slack.com/archives/C063SNM8PK5/p1712059395516219))
- A1 — Andrew Casswell, 2024-04-02 — "Note these entries for siteregistry and telemetry func in the mc-vpp-infrastructure repo. We should make the equivalent for the new function." (points at `terraform/env/mcc-dev.tfvars` path mappings). ([link](https://grid-eneco.enterprise.slack.com/archives/C063SNM8PK5/p1712061742373219))
- A1 — Illia Larka, 2024-04-02 — PR 77771 "PR with path mapping for ingress controllers". ([link](https://grid-eneco.enterprise.slack.com/archives/C063SNM8PK5/p1712062876753189))
- A2 — Exposure of agg functions is done via **per-function ingress path-mapping** in MC-VPP-Infrastructure (`mcc-dev.tfvars`) + per-chart `ingress.yaml`. This is the surface where a missing rewrite-target would live. Consistent with the proven root cause, but Slack never names "rewrite-target" explicitly.

### deliveryreportfn

- A1 — Only appears in the 2026-05-29 sandbox-secret thread as an example chart referencing the common secret; **no ingress/routing discussion for deliveryreportfn**. ([link](https://grid-eneco.enterprise.slack.com/archives/C0ACUPDV7HU/p1780063882778319))

### "rewrite" / "rewrite-target" / "path prefix" / nginx

- A1 — Targeted searches for these terms (with healthz/nginx/path-prefix) returned **0 results**. No Slack discussion of ingress rewrite-target behavior exists.

## Q3 — Was THIS exact issue raised/resolved before?

- A2 — **No** for the exact symptom (`/telemetryfunctiontestsfn/healthz` 404). **Yes** for the recurrence CLASS ("agg function not reachable from AVD; was port-forwarding"), resolved for **siteregistry** on 2026-04-13 by directing Johnson to hit the API directly at `https://agg.vpp.eneco.com/api/...` from AVD (no port-forward). Basis: A1 thread C0ACUPDV7HU/1776068702.359409 + 0 author-results for healthz/telemetryfunctiontestsfn.
- A2 — Reusable resolution pattern from 2026-04-13: confirm reporter is in `rbac/groups/eneco_team_vpp_aggregation.yaml`, then hit the ingress-exposed path directly from AVD. **Caveat**: that worked because siteregistry is mounted at `/api/siteregistry` (a path the backend serves); the current ticket's `/healthz` is served at backend root, so the *same* "just hit it from AVD" answer will still 404 until the ingress rewrite/path issue is fixed. (This is the proven root cause from the parent task, restated here only to flag that the prior resolution does NOT transfer cleanly.)

## Q4 — Is agg.dev / vpp-agg legacy/deprecated vs canonical dev environment?

### A1 — agg.dev.vpp.eneco.com = SANDBOX, not a CMC dev env; agg has NO dev-mc-as-dev

- A1 — Andrew Casswell, 2024-04-02, #myriad-platform — "First is sandbox. It is expected that you can access from a laptop plus AVD. CMC environments which are Dev-MC, Acc and Prd can be accessed only from AVD." (re `agg.dev.vpp.eneco.com` vs `agg.dev-mc.vpp.eneco.com`). ([link](https://grid-eneco.enterprise.slack.com/archives/C063SNM8PK5/p1712061336140289))
- A1 — Niels Witte, 2025-09-12, #myriad-platform — "aggregation layer does not have a dev environment, only sb/acc/prd" and "There's no dev-mc environment for agg, **we use SB as our dev env**." ([link](https://grid-eneco.enterprise.slack.com/archives/C063SNM8PK5/p1757669410278809))
- A1 — Niels Witte, 2025-09-12 — "sb aggregation layer is **publicly available right now**" → `https://agg.dev.vpp.eneco.com/api/siteregistry/swagger/index.html`. ([link](https://grid-eneco.enterprise.slack.com/archives/C063SNM8PK5/p1757674491375009))
- A1 — Niels Witte, 2025-09-12 — "We seem to run an **older version of agg in dev-mc, but it hasnt been updated in a while (API is different) - I think at a certain point we tried getting rid of dev-mc as well.**" ([link](https://grid-eneco.enterprise.slack.com/archives/C063SNM8PK5/p1757675011247899))
- A1 — Roel van de Grint, 2025-09-12 — "I think these environments should line up... Opening up things between different environments is a slippery slope." / "there should either be a dev-mc instance of aggregation layer or the onboarding logic in dev-mc for aggregation layer should be disabled." ([link](https://grid-eneco.enterprise.slack.com/archives/C063SNM8PK5/p1757670226131619))

### A2 — Interpretation for the RCA

- A2 — For the aggregation layer, **`agg.dev.vpp.eneco.com` (sandbox) IS the canonical dev environment** ("we use SB as our dev env"), and it is publicly reachable (laptop + AVD). The `agg.dev-mc.vpp.eneco.com` (CMC Dev-MC) instance is the stale/semi-deprecated one ("older version... hasnt been updated... tried getting rid of dev-mc").
- A2 — This nuances the reporter's framing. Johnson's expectation that `agg.dev.vpp.eneco.com/.../healthz` "should be accessible from AVD" is reasonable: sandbox is meant to be reachable. So the 404 is a routing/ingress defect (proven root cause), NOT an environment-deprecation or access-policy issue.

## Coverage / blocked notes

- A1 — All 4 named private alert channels and target channels were searchable via `slack_search_public_and_private` (connector reports logged-in + semantic search). No `channel_not_found` / auth blocks encountered. Nothing reported as **A3 blocked**.
- A2 — Not exhaustively paginated beyond page 1 on broad keyword searches; author-scoped (`from:<@U045CMAR078>`) and the two key threads were read in full. Residual risk: a relevant message authored by a teammate (not Johnson) about the *exact* telemetryfunctiontestsfn 404 could exist beyond page 1 — judged low, since the dedicated telemetryfunctiontestsfn and rewrite searches surfaced only ingress-chart PRs, no 404 complaint.
