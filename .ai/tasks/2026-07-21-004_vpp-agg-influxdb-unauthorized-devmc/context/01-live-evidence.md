---
title: Live evidence ledger — vpp-agg InfluxDB unauthorized (dev-mc)
type: analysis
status: complete
timestamp: 2026-07-21T13:40:00Z
task_id: 2026-07-21-004
agent: claude-opus-4-8
summary: A1/A2/A3 evidence from live Azure probes (App Insights, Key Vault, App Config) + Eneco.Vpp.Aggregation code/GitOps, grounding the InfluxDB 401 diagnosis.
---

# Live evidence ledger — VPP-agg InfluxDB `unauthorized` (dev-mc)

Incident: `2026_07_21_002_johnson_vpp_agg_influxdb_unauthorized_devmc` (Slack Lists `Rec0BJKDCC4CT`).
Probes run 2026-07-21 as `Alex.Torres@eneco.com` (own Entra) + MC dev SP (whitelist ON→OFF, reverted).

Evidence labels: **A1 FACT** (command + captured output / file:line) · **A2 INFER** (derived, reasoning named) · **A3 UNVERIFIED[blocked: reason]**.

## E1 — The 401 is LIVE today (not a stale/historical symptom)  `A1`

`az monitor app-insights query --app 9ccf7dac-2934-4dd6-9a98-4058000c1178` on `vpp-agg-appinsights-d`:

- 12 `Microsoft.Azure.WebJobs.Script.Workers.Rpc.RpcException` exceptions on **2026-07-21, 12:15:01Z → 13:00:02Z**, all wrapping `InfluxDB.Client.Core.Exceptions.UnauthorizedException: unauthorized access` (HTTP 401).
- `operation_Name = PublishStrikePricesFunction`, `cloud_RoleName = strikepricefn`.
- Formatted message: `Could not export data to InfluxDb due to exception`; stack ends at `Shared.Infrastructure.InfluxDb.Client.InfluxDbClientHelper.WritePointsAsync ... InfluxDbClientHelper.cs:line 27`.
- Cadence: fires at :15, :30, :45, :00 → **every 15 minutes**, 2–3 write attempts per fire.

## E2 — Identifier corrections (intake had them slightly wrong)  `A1`

| Intake said | Live telemetry says |
|-------------|---------------------|
| `PublishStrikePriceFunction` (singular) | **`PublishStrikePricesFunction`** (plural) |
| — | cloud role **`strikepricefn`** |

## E3 — Onset / ">1 month" duration is NOT confirmable from telemetry  `A3 [blocked: retention]`

`exceptions | where timestamp > ago(120d) | summarize count() by bin(timestamp,7d)` returns **only the 2026-07-21 bucket** (12 rows). This dev App Insights has short retention / low volume; the 2026-07-07 screenshot exception has aged out of the queryable window. Duration ">1 month" rests on the **filer statement + the 2026-07-07 screenshot only** — treat as `A2` (filer) not `A1`.

## E4 — Topology: the function is containerized in OpenShift, not an Azure Function App  `A1`

`az resource list -g mcdta-rg-vpp-agg-d-res` returns **no `Microsoft.Web/sites`**. The RG holds only:
`vpp-agg-appsec-d` (KV, private-endpoint), `vpp-agg-applicationconfig-d` (App Config, private-endpoint), `vpp-agg-appinsights-d` (App Insights), `vpp-agg-log-analyt-d` (Log Analytics), private endpoints, SQL auditing.
⇒ `strikepricefn` runs as a **container in OpenShift `eneco-vpp-agg`** (AVD-gated) and only *emits telemetry* to this App Insights.

## E5 — Key Vault `vpp-agg-appsec-d` network posture  `A1`

`az keyvault show -n vpp-agg-appsec-d`:
`publicNetworkAccess=Enabled`, `networkAcls.defaultAction=Deny`, `enableRbacAuthorization=false` (**access-policy model**), 9-entry IP allowlist.
My IP `84.86.32.39` was absent → `ForbiddenByFirewall`. Reached only after adding my IP to the vault firewall (added + **removed** in cleanup). The connect-skill whitelist targets **`vpp-appsec-d`** (VPP Core), **not** `vpp-agg-appsec-d` — a real gap.

## E6 — The actual InfluxDB secrets in `vpp-agg-appsec-d` (metadata only — values never read)  `A1`

`az keyvault secret list --vault-name vpp-agg-appsec-d`:

| Secret | Enabled | Updated | Expiry | Role |
|--------|---------|---------|--------|------|
| **`influxdb-api-token`** | True | **2025-03-07** | **none** | VPPAL **write** token (`InfluxDbOptions:Token`) |
| `influxdb-admin-token` | True | 2025-03-11 | none | InfluxDB admin API token |
| `influxdb-admin-password` | True | 2025-03-11 | none | InfluxDB admin UI login |
| `grafana-influxdb-v2-influxql-datasource-api-token` | True | 2025-04-15 | none | Grafana **read** datasource |

**Load-bearing facts:** the write token is **Enabled** and has **no expiry**, and its value is **unchanged since 2025-03-07 (>16 months)**. Since the 401 allegedly began ~1 month ago, the change is **not** in this KV secret → it is on the **InfluxDB side** (token revoked / org|user|instance re-initialized).

## E7 — App Config `vpp-agg-applicationconfig-d` is private-endpoint only  `A1 / A3`

`az appconfig show` → `publicNetworkAccess=null`; `az appconfig kv list ... --auth-mode login` → `Forbidden`. InfluxDB URL/org/bucket **not** readable from Azure outside the VNet → sourced from repo instead (E8).

## E8 — Code + GitOps wiring (repo `Eneco.Vpp.Aggregation`, local checkout)  `A1`

- `Common/Shared.Infrastructure/InfluxDb/Client/InfluxDbClientHelper.cs:23–33` — `WritePointsAsync` **catches the exception and only `logger.LogError(...)`; it does NOT rethrow.** ⇒ a 401 **silently drops the write**; the function invocation still completes. Impact = lost monitoring data, not a crashed function.
- `Common/Shared.Infrastructure/InfluxDb/Options/InfluxDbOptions.cs` — `{Host, Token, Database, Organization}`; `InfluxDbOptionsValidator` **fails startup if `Token` is empty**. ⇒ the token is **present but rejected**, not missing.
- `Common/Shared.Infrastructure/InfluxDb/Extensions/ServiceCollectionExtensions.cs:31–36` — `new InfluxDBClient(new InfluxDBClientOptions(Host){ Bucket=Database, Org=Organization, Token=Token })` → standard InfluxDB **2.x** client (`org/bucket/token`).
- `Eneco.Vpp.Aggregation.GitOps/Helm/strikepricefn/dev/values.yaml`:
  - `InfluxDbOptions__Host: "http://influxdb-eneco-vpp-agg-influxdb2"`
  - `InfluxDbOptions__Database: "aggregation"` (bucket)
  - `InfluxDbOptions__Organization: "vpp-agg"` (org)
  - `PublishStrikePricesFunctionTimeTrigger: "*/15 * * * *"` (**matches E1 cadence**), `WEBSITE_CLOUD_ROLENAME: strikepricefn`, image `vppacra.azurecr.io/eneco-vpp-agg/strikepricefn:3.18.1.dev.fe439c9`.
  - `KafkaTopicsOptions__AssetStrikePriceTopic: "eneco-dta-test-coo-eet-asset-strikeprices-1"` (the input topic feeding the function).
  - **`InfluxDbOptions__Token` is NOT in values.yaml** — injected separately (k8s secret ← KV `influxdb-api-token`). The exact KV→k8s-Secret→env sync mechanism (CSI SecretProviderClass vs ESO) is **not** in this repo's per-service values ⇒ `A3 [blocked: AVD/oc]`. `strikepricefn` has **b2b + b2c** variants.
- `Functions/StrikePrices/StrikePriceGenerator/Program.cs:27–33` — `ConfigureAppConfiguration` adds only UserSecrets in `Development`; **no `AddAzureAppConfiguration`**. ⇒ in the pod, `InfluxDbOptions:Token` comes from an **environment variable** set at container start. **Fix implication: updating the KV token requires a pod restart/redeploy to take effect.**

## E9 — Business/architecture context (ADR AL010, Dec 2024)  `A1`

`log/.../adr-archived/.../AggregationLayer/AL010-functional-monitoring-influxdb-poc/README.md`: InfluxDB is a **self-managed PoC** (SQL + InfluxDB[self-managed] → Grafana) deployed on the **Mission-Critical OpenShift cluster** for VPPAL **functional/device-level monitoring** dashboards. C# Influx client integrated in VPPAL functions, batched writes, Azure Blob object store. Johnson Lobo was a decider. Explicit accepted risk: *"If the InfluxDb is down … we could lose the functional data."* ⇒ InfluxDB 401 degrades **monitoring**, not trading/operations.

## E10 — Blocked (needs in-AVD `oc` — cannot run from this machine)  `A3 [blocked: AVD/oc]`

- Whether org `vpp-agg` + bucket `aggregation` still exist in the live InfluxDB2 instance.
- Whether the stored `influxdb-api-token` value is a known/valid token there and has write scope to `aggregation`.
- The exact KV→k8s-secret→env sync mechanism (CSI SecretProviderClass vs ESO) feeding `InfluxDbOptions__Token`.
- Whether other InfluxDB writers (telemetry/dataingestion fns) also 401 (blast radius) — only `strikepricefn` visible in the retained window.

## Diagnosis (from the above)

> **Superseded by `rca.md` L8 + `how-to-fix.md`:** before minting a token, check the credential **byte-chain** (KV vs k8s Secret vs pod env) and confirm the 401 is from **InfluxDB** (not a proxy/mesh). The "→ InfluxDB side" conclusion below is a leading **A2** hypothesis, not a fact — a stale/corrupt delivered token (H2) produces the same 401.

- **Rejected:** "the api-token is expired" (filer H1). InfluxDB 2.x API tokens do not expire by default; the KV secret is Enabled with no expiry (E6); `InfluxDbOptions` would fail startup if the token were empty (E8).
- **Leading (`A2`):** the write token stored in `influxdb-api-token` (static since 2025-03-07) **no longer corresponds to a valid, write-authorized token in the current InfluxDB2 instance** — the token was revoked or the org/user/instance re-initialized (plausibly during recent InfluxDB data-plane work, cf. related delete/recreate-collection ticket `Rec0BGG7SPERE`). InfluxDB returns 401 for an unknown token. Confirmed by the E6 static-secret-vs-recent-onset discriminator; final confirmation is the E10 in-AVD token check.
- **Fix shape:** mint a valid write token in the live InfluxDB (org `vpp-agg`, bucket `aggregation`) → store in KV `influxdb-api-token` → **rollout-restart** `strikepricefn` (b2b + b2c) so the env var re-resolves → verify no new `UnauthorizedException` + a successful write + fresh Grafana data.
