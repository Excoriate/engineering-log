---
task_id: 2026-03-23-001
agent: coordinator
status: complete
summary: Live evidence collected for all investigation claims from ADO, pipeline logs, repo code
---

# Claim Verification Evidence

## Build & Pipeline Claims

| # | Claim | Verdict | Live Evidence |
|---|-------|---------|---------------|
| 1 | Build 1579769 in "Dispatching E2E Tests - Sandbox - Daily Run at 1AM UTC" | **CONFIRMED** | `az pipelines runs show --id 1579769`: pipeline name matches, repo=Eneco.Vpp.Core.Dispatching, result=partiallySucceeded |
| 2 | Pipeline scheduled daily at 1AM UTC, ran at ~01:02 | **CONFIRMED** | startTime=2026-03-23T01:01:17 UTC, reason=schedule |
| 3 | VRE tests: 503 Service Temporarily Unavailable from nginx | **CONFIRMED** | Log 19: `System.InvalidOperationException : Request failed: 503 Service Temporarily Unavailable` with nginx HTML |
| 4 | Battery tests: JsonSerializationException CurtailmentDeviation null→double | **CONFIRMED** | Log 20: `Newtonsoft.Json.JsonSerializationException : Error converting value {null} to type 'System.Double'. Path 'AssetConfiguration.CurtailmentDeviation', line 43, position 34.` |
| 5 | DP tests: 503 (same mechanism as VRE) | **CONFIRMED** | Log 21: same 503 nginx HTML response |
| 6 | CCGT tests: 503 (same mechanism as VRE) | **CONFIRMED** | Log 22: same 503 nginx HTML response |
| 7 | Test totals: 68 failed, 0 passed, 35 skipped, 103 total, 20s | **CONFIRMED** | VRE=23F/22S/45T(6s), Battery=18F/12S/30T(4s), DP=8F/0S/8T(5s), CCGT=19F/1S/20T(5s) → 68/0/35/103 in 20s |
| 8 | Azure Login succeeded: SP edff16c6, sub 7b1ba02e | **CONFIRMED** | Log 18: SP `edff16c6-3847-4ed8-9975-f085a5643024`, sub `7b1ba02e-bac6-4c45-83a0-7f0d3104922e` |
| 9 | Azure Login script: `sandbox-development_subscription_id: command not found` | **CONFIRMED** | Log 18 L28-29: missing `$` prefix, L31: `ERROR: The subscription of '' doesn't exist` |
| 10 | All failures cascade from BeforeFeature hooks | **CONFIRMED** | All downstream failures show `Reqnroll.ReqnrollException : Scenario skipped because of previous before feature hook error` |

## Code & Architecture Claims

| # | Claim | Verdict | Live Evidence |
|---|-------|---------|---------------|
| 11 | VRE chain: BeforeFeatureVre → SetupAssetForFeature → ConfigureAssetMarketAndStartProcessor → SetupMarketAllocation → IntegrationTestClient.Post → 503 | **CONFIRMED** | Hooks.cs: BeforeFeatureVre calls SetupAssetForFeature("VRE_ResVarsCalc"). FeatureConfigurationService.cs: SetupAssetWithConfiguration → ConfigureAssetMarketAndStartProcessor → SetupMarketAllocation. Stack trace in log 19 matches. |
| 12 | Battery chain: BeforeFeatureBattery → SetupAssetForFeature → SetupAssetWithConfiguration → OnboardNewAsset → JsonHelper.ParseJson → null→double | **CONFIRMED** | Hooks.cs: BeforeFeatureBattery calls SetupAssetForFeature("Battery_ResVarsCalc"). Battery uses LER schema. ler_onboard_asset.json has CurtailmentDeviation: null. OnboardAssetDto.cs: `double CurtailmentDeviation { get; set; }` (non-nullable). |
| 13 | OpenShift v4.18 LCM announced for ACC March 19 | **PARTIALLY CONFIRMED** | Cannot verify Slack announcement. But 503 onset is between Mar 17 14:26 and Mar 18 15:19 — pre-dates March 19 LCM. Timing is close but doesn't align exactly. |
| 14 | Related PR 168286 — E2E Test Automation .NET 10.0 | **UNVERIFIED** | API call returned empty. PR exists in investigation URL but couldn't be fetched. |
| 15 | Integration-tests service behind nginx on Sandbox | **CONFIRMED** | 503 HTML response contains `<center>nginx</center>` |

## Characterization Claims

| # | Claim | Verdict | Live Evidence |
|---|-------|---------|---------------|
| 16 | "503 is likely transient — re-running should resolve" | **REFUTED** | 503 present in EVERY build from Mar 18 through Mar 23 (6 days). 20+ consecutive builds. Not a single VRE/DP/CCGT pass since Mar 17. |
| 17 | Battery issue is deterministic (will fail every run) | **CONFIRMED** | Same JsonSerializationException in builds on Mar 16, Mar 22, Mar 23. ler_onboard_asset.json has null, model expects double. |
| 18 | JSON fixture has CurtailmentDeviation: null at line 43 | **CONFIRMED** | ler_onboard_asset.json fetched via API: `"CurtailmentDeviation": null`. Other fixtures have numeric values (conventional=2, vre=10, dp=0). |
| 19 | C# model expects double (non-nullable) | **CONFIRMED** | OnboardAssetDto.cs: `public double CurtailmentDeviation { get; set; }` |
| 20 | Historical E2E failure pattern exists | **CONFIRMED** | Investigation documents 5 prior incidents (Jun 2025 - Jan 2026). Current pipeline shows 0 fully succeeded builds in last 50 runs. |
| 21 | .NET 5 warnings unrelated boilerplate | **CONFIRMED** | Pipeline uses .NET SDK 10.0.x, warnings are generic ADO task messages. Tests target net10.0. |

## Additional Findings (Not in Investigation)

| Finding | Evidence |
|---------|----------|
| Battery uses LER schema, not a dedicated "battery" fixture | FeatureConfigurationService.cs: `["Battery_ResVarsCalc"] = new(...("LER", "130", 25, -25))` |
| 503 onset: between Mar 17 14:26 and Mar 18 15:19 | Mar 17 14:26 build: no 503, DP 7/8 passed. Mar 18 15:19 build: 503 present. |
| Before 503: VRE had REAL test assertion failures | Mar 16-17 VRE: `POWER_SCHEDULE Value mismatch. Expected: [70.00000], Actual: [69.31167]` |
| No fully succeeded build in last 50 runs | `az pipelines runs list --top 50 --query "[?result=='succeeded']"` returns empty |
| Pipeline has deep systemic issues beyond current 503 | Even when 503 was absent (Mar 16-17), VRE had test logic failures and Battery had the JSON bug |
| Mar 13: Multiple manual retries (8:10, 8:18, 8:22, 10:03) | Pipeline run history shows troubleshooting activity |
