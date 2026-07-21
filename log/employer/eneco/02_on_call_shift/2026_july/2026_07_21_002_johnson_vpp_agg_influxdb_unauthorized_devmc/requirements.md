# Requirements — VPP agg InfluxDB unauthorized (dev-mc)

Consolidate of Slack Lists tickets + App Insights evidence for the next troubleshooting agent.
**Do not discard detail** — this file is the raw corpus; `slack-intake.md` is the hand-off contract.

## Current ticket (open)

| Field | Value |
|-------|-------|
| Slack Lists | https://grid-eneco.enterprise.slack.com/lists/T039G7V20/F0ACUPDV7HU?record_id=Rec0BJKDCC4CT |
| `record_id` | `Rec0BJKDCC4CT` |
| Filer | Johnson Lobo |
| Env | **dev-mc** |
| Surface (stated) | VPPAL / Aggregation workloads → InfluxDB write |
| Symptom | `InfluxDB.Client.Core.Exceptions.UnauthorizedException: unauthorized access` |
| Filer hypothesis | API token expired; needs a new token |
| Blocker for filer | Cannot port-forward / access InfluxDB from AVD; no access to aggregation project on OpenShift |
| Related prior ticket | `Rec0BGG7SPERE` (Nuno) — see below |
| CMC access ticket cited | `RITM0191780` (raised by Nuno previously) |

## Related ticket (already worked by Nuno) — `Rec0BGG7SPERE`

| Field | Value |
|-------|-------|
| Slack Lists | https://grid-eneco.enterprise.slack.com/lists/T039G7V20/F0ACUPDV7HU?record_id=Rec0BGG7SPERE |
| `record_id` | `Rec0BGG7SPERE` |
| Filer | Johnson Lobo |
| Theme | ACC InfluxDB login / port-forward / delete+recreate measurement collection; datatype inconsistency DEV_MC / ACC / PROD |
| Status (as of harvest) | Effectively waiting on Johnson after Nuno unblocked access + auto-sync clarity |

## App Insights evidence (screenshot)

Local copy: `proofs/screenshots/01-appinsights-publishstrikeprice-influxdb-unauthorized.png`

| Field | Value |
|-------|-------|
| Component | `vpp-agg-appinsights-d` |
| Subscription | `839af51e-c8dd-4bd2-944b-a7799eb2e1e4` (dev-mc) |
| Resource group | `mcdta-rg-vpp-agg-d-res` |
| Function | `PublishStrikePriceFunction` |
| Exception | `Microsoft.Azure.WebJobs.Script.Workers.Rpc.RpcException` wrapping InfluxDB `UnauthorizedException` |
| Event time (UI) | 7/7/2026, 7:30:01.310 AM (local in screenshot) |
| Event time (portal URL) | `2026-07-07T05:30:01.310Z` |
| InvocationId | `eb75ed7e-79c4-41f1-8065-6045bd8a7071` (screenshot); portal URL also uses `eb75ed7e-79c4-11f1-8065-6045bd8a7071` — confirm exact GUID when probing |
| HostInstanceId | `cfe2b041-99df-46f8-adc2-228c17bca19b` |
| Category | `Function.PublishStrikePriceFunction.User` |
| Formatted message | Could not export data to InfluxDb due to exception |
| Code path | `Shared.Infrastructure.InfluxDb.Client.InfluxDbClientHelper.WritePointsAsync` → `/src/Common/Shared.Infrastructure/InfluxDb/Client/InfluxDbClientHelper.cs:line 27` |
| Downstream links in transaction | many `Link to PoolStrikePriceEventHandler` |

Portal deep link (App Insights exception blade):

https://portal.azure.com/#view/AppInsightsExtension/DetailsV2Blade/ComponentId~/%7B%22SubscriptionId%22%3A%22839af51e-c8dd-4bd2-944b-a7799eb2e1e4%22%2C%22ResourceGroup%22%3A%22mcdta-rg-vpp-agg-d-res%22%2C%22Name%22%3A%22vpp-agg-appinsights-d%22%2C%22LinkedApplicationType%22%3A0%2C%22ResourceId%22%3A%22%252Fsubscriptions%252F839af51e-c8dd-4bd2-944b-a7799eb2e1e4%252FresourceGroups%252Fmcdta-rg-vpp-agg-d-res%252Fproviders%252FMicrosoft.Insights%252Fcomponents%252Fvpp-agg-appinsights-d%22%2C%22ResourceType%22%3A%22microsoft.insights%252Fcomponents%22%2C%22IsAzureFirst%22%3Afalse%7D/DataModel~/%7B%22eventId%22%3A%22eb75ed7e-79c4-11f1-8065-6045bd8a7071%22%2C%22timestamp%22%3A%222026-07-07T05%3A30%3A01.310Z%22%2C%22cacheId%22%3A%22ea1333af-3ed4-416a-9944-c40f816b99fe%22%2C%22eventTable%22%3A%22exceptions%22%7D

## Error message (verbatim — current ticket)

```text
Result:
Could not export data to InfluxDb due to exception
Type:
Exception: InfluxDB.Client.Core.Exceptions.UnauthorizedException: unauthorized access
 ---> System.Net.Http.HttpRequestException: Request failed with status code Unauthorized
   --- End of inner exception stack trace ---
   at InfluxDB.Client.Api.Service.WriteService.PostWriteAsyncWithIRestResponse(String org, String bucket, Byte[] body, String zapTraceSpan, String contentEncoding, String contentType, Nullable`1 contentLength, String accept, String orgID, Nullable`1 precision, CancellationToken cancellationToken)
   at InfluxDB.Client.Api.Service.WriteService.PostWriteAsyncWithHttpInfo(String org, String bucket, Byte[] body, String zapTraceSpan, String contentEncoding, String contentType, Nullable`1 contentLength, String accept, String orgID, Nullable`1 precision, CancellationToken cancellationToken)
   at InfluxDB.Client.WriteApiAsync.WritePointsAsync(List`1 points, String bucket, String org, CancellationToken cancellationToken)
   at Shared.Infrastructure.InfluxDb.Client.InfluxDbClientHelper.WritePointsAsync(IEnumerable`1 pointsData, CancellationToken cancellationToken) in /src/Common/Shared.Infrastructure/InfluxDb/Client/InfluxDbClientHelper.cs:line 27
Stack:    at InfluxDB.Client.Api.Service.WriteService.PostWriteAsyncWithIRestResponse(...)
   at InfluxDB.Client.Api.Service.WriteService.PostWriteAsyncWithHttpInfo(...)
   at InfluxDB.Client.WriteApiAsync.WritePointsAsync(...)
   at Shared.Infrastructure.InfluxDb.Client.InfluxDbClientHelper.WritePointsAsync(...) in /src/Common/Shared.Infrastructure/InfluxDb/Client/InfluxDbClientHelper.cs:line 27
```

## Current ticket narrative (Johnson — Rec0BJKDCC4CT)

Verbatim / near-verbatim from harvest:

> VPPAL workloads on dev-mc env can't export the data to influxdb due to below, this issue is there for more than a month now. we just noticed it today.
>
> This means the api-token is expired and we want to create new one. i can't do it myself because i can't port forward it and access it from my AVD.
>
> we don't have access to aggregation project on openshift cluster
> Nuno worked on this ticket in the past. he created a ticket for CMC (RITM0191780). But i can't browse through any aggregation workloads
>
> points to related ticket Rec0BGG7SPERE

## Related ticket narrative — Rec0BGG7SPERE (datatype / collection recreate)

### Original ask (Johnson)

> We identified inconsistent datatype setup between DEV_MC, ACC and PROD for device telemetry measurement collection.
>
> The only way to get it working on DEV-MC, ACC is to delete the collection and recreate it.
>
> How can i login to ACC influxdb instance? can i port forward it ?
> Can i disable auto sync on dev-mc/acc while i delete and recreate the collection ?
>
> Let me know if you need more details

### Thread summary (do not lose)

**Issue at the center**

Johnson needed to reproduce a production bug on ACC for device telemetry, which required clearing/recreating the measurement collection in the ACC InfluxDB instance. Root cause of the recurring problem: a datatype change from the producer left some environments out of sync, and the only fix is to delete and recreate the collection. Johnson lacked InfluxDB login and port-forward access on ACC.

**What Johnson Lobo shared**

- The ask (Jul 7): Wanted priority on the ticket — a prod bug needed testing on ACC first, which meant clearing measurement data on the ACC InfluxDB instance. Didn’t know how to log in.
- Scope of sync (Jul 8): Only syncs applications deployed to the `eneco-vpp-agg` namespace. Asked for flexibility to disable/enable auto-sync on dev-mc himself, to avoid waiting on the platform team each time.
- Cause & history (Jul 8): The problem “mainly happened due to a datatype change from the producer” — not frequent, but some prod data was out of sync with the rest. Historically he logged in with admin credentials and did it manually; the platform team gave him access and logins.
- Status (Tuesday, Jul 14): Tied up with other work; hasn’t reviewed the comments yet. Will raise a new request if anything is unclear.

**What Nuno Alves Pereira shared**

- Port-forward command (**dev-mc only**):

  ```bash
  oc port-forward -n eneco-vpp-agg svc/influxdb-eneco-vpp-agg-influxdb2 8086:80
  ```

  Noted that ACC/PROD port-forwarding wasn’t permitted for them either (at that time).

- Why ACC access broke: The OpenShift restructuring ~3 months ago narrowed developer permissions across projects, which is why port-forwarding to ACC stopped working.

- Access fix (Jul 9–10): Raised access request **RITM0191780**; once implemented, the aggregation team can now do **pod-exec and port-forward** in the aggregation namespace across **all environments**.

- Auto-sync: Sync can’t be modified because this app sits in the **default ArgoCD project** — but auto-sync is currently **disabled** on both **dev and acc**, so Johnson is clear to delete/recreate.

- Credentials: The old `int` credentials in the secrets no longer work (they were changed, nobody on the team knew). The current InfluxDB credentials live in **`vpp-agg-appsec-{env}`**.

- Close-out (Tuesday): Asked whether anything else is needed or if the request can be closed.

**Bottom line (Rec0BGG7SPERE)**

Nuno resolved the two blockers Johnson raised — access (via RITM0191780, now granting pod-exec/port-forward across all envs for the agg namespace) and auto-sync (already disabled on dev and acc). The credentials Johnson needs are in `vpp-agg-appsec-{env}`. The ticket is effectively waiting on Johnson to act and confirm it can be closed.

## Identity ledger (for probes — resolve or mark Unknown)

| Key | Value | Status |
|-----|-------|--------|
| Env | `dev-mc` | Known — current ticket |
| Subscription | `839af51e-c8dd-4bd2-944b-a7799eb2e1e4` | Known — App Insights URL |
| RG | `mcdta-rg-vpp-agg-d-res` | Known |
| App Insights | `vpp-agg-appinsights-d` | Known |
| OpenShift namespace | `eneco-vpp-agg` | Known — Nuno |
| InfluxDB service | `svc/influxdb-eneco-vpp-agg-influxdb2` | Known — Nuno port-forward |
| Port-forward local | `8086:80` | Known — Nuno |
| Key Vault / appsec | `vpp-agg-appsec-{env}` (dev → likely `vpp-agg-appsec-dev` or similar) | Inferred naming — **confirm exact vault name before mutate** |
| Failing function | `PublishStrikePriceFunction` | Known — screenshot |
| CMC RITM | `RITM0191780` | Known — access grant |
| Prior Lists record | `Rec0BGG7SPERE` | Known |
| Current Lists record | `Rec0BJKDCC4CT` | Known |

## Competing hypotheses (do not collapse early)

| ID | Hypothesis | Predicts | Discriminator |
|----|------------|----------|---------------|
| H1 | InfluxDB API token expired / rotated; Function still holds old token | 401 Unauthorized on write | Compare token in Function app settings / Key Vault secret vs InfluxDB UI tokens; create new token + update secret |
| H2 | Wrong org/bucket or token scope (read-only / wrong org) | 401 or forbidden write | InfluxDB token permissions vs configured org/bucket |
| H3 | Credentials in `vpp-agg-appsec-{env}` changed (as Nuno noted for `int`) but consumers not refreshed | Same 401 after access restored | Diff secret versions vs deployed app env |
| H4 | Access still missing for Johnson’s identity despite RITM0191780 (RBAC lag / wrong group) | `oc` denied on `eneco-vpp-agg` | `oc auth can-i port-forward` / project membership |
| H5 | Unrelated to token — InfluxDB operator / auth endpoint misconfigured | Broader auth failures | Health of InfluxDB pod + admin login with vault creds |

Filer stated H1 as fact (“this means the api-token is expired”) — treat as **Assumed** until vault/token probe confirms.

## Suggested next probes (for eneco-sre / troubleshoot agent)

1. Confirm OpenShift context for **dev-mc** and access to `eneco-vpp-agg` (RITM0191780 outcome).
2. Port-forward (Nuno’s command) and open InfluxDB UI/API on `localhost:8086`.
3. Pull current credentials from `vpp-agg-appsec-{env}` (exact name TBD) — **never commit secrets**.
4. Locate which secret/setting `PublishStrikePriceFunction` uses for InfluxDB token (Function App / Key Vault reference).
5. Reproduce write with current token; if 401, create new write token in InfluxDB and rotate secret; restart/redeploy consumer.
6. Check whether failure is still active after Jul 7 sample (App Insights query for recent Unauthorized).
7. Do **not** conflate with Rec0BGG7SPERE’s “delete collection” fix unless datatype/schema errors appear — this ticket’s signature is **Unauthorized**, not schema mismatch.

## Human gates

- Creating/rotating InfluxDB API tokens and updating Key Vault / Function config is a **credential change** — coordinate with Aggregation + Platform; do not paste tokens into Slack/logs.
- ACC/PROD out of scope for the *current* ask unless Johnson expands — current ask is **dev-mc**.
- Auto-sync already disabled on dev/acc per Nuno — still verify before any destructive InfluxDB collection ops.

## Definition of done (proposed — confirm with Johnson)

- `PublishStrikePriceFunction` (and related VPPAL exporters) can write to InfluxDB on **dev-mc** without `UnauthorizedException`.
- Johnson can port-forward / browse aggregation workloads as needed (or has a documented path using vault credentials).
- Optional: document how to rotate the InfluxDB API token so Aggregation does not need Platform for every expiry.
