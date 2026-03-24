# Troubleshooting Report: Dispatching E2E Pipeline Failure — Build 1579769

**Date:** 2026-03-23T09:28:00+01:00
**Investigator:** Alex Torres (AI-assisted analysis)
**Requester:** Vikas Yadav (via Slack List Rec0AN3LF6Z4M)
**Build ID:** [1579769](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_build/results?buildId=1579769&view=logs&j=dded719d-e4af-5638-65ef-ece3839615a6&t=d7ed71f3-5fe2-5757-e984-e7abb828b0b7)
**Pipeline:** Dispatching End to End Tests - Sandbox - Daily Run at 1AM UTC
**Related PR:** [168286 — E2E Test Automation .NET 10.0](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/Eneco.Infrastructure/pullrequest/168286)
**Status:** ROOT CAUSES IDENTIFIED — Two distinct issues

---

## TL;DR

Build 1579769 has **four failing test steps** (VRE, Battery, DP, CCGT), all cascade-failing from `[BeforeFeature]` hook errors. There are **two distinct root causes**:

1. **VRE tests** — The integration-tests service on Sandbox returned **`503 Service Temporarily Unavailable`** (nginx). The service was down at 01:02 UTC. This is an environment/infra issue.

2. **Battery tests** — A **`JsonSerializationException`**: the test fixture JSON has `AssetConfiguration.CurtailmentDeviation: null` but the C# model expects a non-nullable `double`. This is a code/data defect in the test fixtures.

Both errors occur in `[BeforeFeature]` hooks, causing every downstream scenario to cascade-fail without executing.

---

## 1. Pipeline Structure (Build 1579769)

| Step | Duration | Status | Root Cause |
|------|----------|--------|------------|
| Build job | 48s | Success | — |
| Initialize job | 3s | Success | — |
| Use .NET SDK 10.0.x | 10s | **Skipped** | SDK already present on agent |
| Checkout | <1s | Success | — |
| Download binaries | 5s | Success | — |
| Azure Login | 8s | Success | — |
| **Asset-VRE Tests** | **11s** | **Warning** | **503 from integration-tests service** |
| **Asset-Battery Tests** | **7s** | **Warning** | **JsonSerializationException: CurtailmentDeviation null→double** |
| **Asset-DP Tests** | **8s** | **Warning** | 503 from integration-tests service (verified, log 21) |
| **Asset-CCGT Tests** | **8s** | **Warning** | 503 from integration-tests service (verified, log 22) |
| Azure Logout | <1s | Success | — |

---

## 2. Root Cause #1: VRE Tests — 503 Service Temporarily Unavailable

### 2.1 The Error (from raw log)

```
System.InvalidOperationException : Request failed: <html>
<head><title>503 Service Temporarily Unavailable</title></head>
<body>
<center><h1>503 Service Temporarily Unavailable</h1></center>
<hr><center>nginx</center>
</body>
</html>
```

### 2.2 The Call Chain

```
Hooks.BeforeFeatureVre()                              ← Hooks.cs:53
  └→ FeatureConfigurationService.SetupAssetForFeature()     ← line 58
      └→ .SetupAssetWithConfiguration()                     ← line 75
          └→ .ConfigureAssetMarketAndStartProcessor()       ← line 93
              └→ AssetTestDataSetup.SetupMarketAllocation() ← line 202
                  └→ IntegrationTestClient.Post<T>()        ← HTTP POST
                      └→ ❌ 503 Service Temporarily Unavailable (nginx)
```

### 2.3 Mechanism

The `BeforeFeatureVre` hook calls `SetupMarketAllocation`, which sends an HTTP POST to the integration-tests service on the Sandbox environment. At 01:02 UTC, the nginx ingress returned 503 — meaning the backend pod was unreachable.

The `IntegrationTestClient.Post<T>()` throws `System.InvalidOperationException` on non-2xx responses. This exception propagates up through the Reqnroll hook, marking the feature as poisoned. All 45 scenarios (23 fail, 22 skip) never execute.

### 2.4 Why Was the Service Down?

Probable causes (ranked by evidence):

1. **OpenShift v4.18 LCM (Life Cycle Management)** — On March 16, Fabrizio announced: ACC LCM on March 19, PRD LCM on March 26. If sandbox was also being updated, pods could have been restarting at 1 AM UTC.

2. **Pod health / liveness probe failure** — Historical precedent from Sep 2025: integration-tests pods restarting due to CPU throttling caused AppGW/nginx to mark backend unhealthy.

3. **Scheduled maintenance or coincidental restart** — The pipeline runs daily at 1 AM UTC. If a CronJob, deployment rollout, or HPA scale-down happened at that time, the pod may have been temporarily unavailable.

### 2.5 Test Results (VRE)

```
Failed: 23, Passed: 0, Skipped: 22, Total: 45, Duration: 6s
```

---

## 3. Root Cause #2: Battery Tests — JSON Deserialization Failure

### 3.1 The Error (from raw log)

```
Newtonsoft.Json.JsonSerializationException :
  Error converting value {null} to type 'System.Double'.
  Path 'AssetConfiguration.CurtailmentDeviation', line 43, position 34.

---- System.InvalidCastException :
  Null object cannot be converted to a value type.
```

### 3.2 The Call Chain

```
Hooks.BeforeFeatureBattery()                                ← Hooks.cs:64
  └→ FeatureConfigurationService.SetupAssetForFeature()     ← line 58
      └→ .SetupAssetWithConfiguration()                     ← line 72
          └→ AssetHelper.OnboardAssetWithSchemaAndIdentifier() ← line 28
              └→ AssetHelper.OnboardNewAsset()               ← line 41
                  └→ JsonHelper.ParseJson<T>()               ← deserialization
                      └→ ❌ null → double conversion fails
```

### 3.3 Mechanism

The `BeforeFeatureBattery` hook calls `OnboardNewAsset`, which reads a JSON test fixture file and deserializes it. The JSON has `"CurtailmentDeviation": null` at line 43, but the target C# model declares `CurtailmentDeviation` as `double` (non-nullable value type).

`Newtonsoft.Json` cannot convert `null` to `System.Double`. It throws `JsonSerializationException`, which propagates up and poisons the Battery feature — all 30 scenarios cascade-fail (18 fail, 12 skip).

### 3.4 This Is a Code/Data Defect

This is **not** an environment issue. This is one of:

- **The JSON fixture has incorrect data.** `CurtailmentDeviation` was set to `null` when it should have a numeric value (e.g., `0.0`).
- **The C# model needs `double?` (nullable).** If `CurtailmentDeviation` can legitimately be null, the model property should be `double?` (or `Nullable<double>`).
- **A regression from the .NET 10 migration.** If Newtonsoft.Json behavior changed subtly under net10.0 (unlikely but possible), the same fixture might have worked before.

### 3.5 Test Results (Battery)

```
Failed: 18, Passed: 0, Skipped: 12, Total: 30, Duration: 4s
```

---

## 4. Summary of Findings

| Issue | Type | Root Cause | Owner | Action |
|-------|------|-----------|-------|--------|
| VRE 503 | Environment | Integration-tests service down on Sandbox at 01:02 UTC | Platform / Infra | Check pod health, check if LCM affected sandbox, re-run pipeline |
| Battery null→double | Code/Data | JSON fixture `CurtailmentDeviation: null` incompatible with `double` model | Vikas / Team Optimum | Fix fixture data or make property nullable |
| DP 503 | Environment | Same 503 — `BeforeFeatureDecentralizedPool` → `SetupMarketAllocation` → 503 | Platform / Infra | Same as VRE — transient |
| CCGT 503 | Environment | Same 503 — `BeforeFeatureConventional` → `SetupMarketAllocation` → 503 | Platform / Infra | Same as VRE — transient |
| Azure Login script bugs | Pipeline | `sandbox-development_subscription_id: command not found` (missing `$` prefix) and `az account set --subscription ''` fails. Login itself succeeds. | Pipeline owner | Fix variable references in login script (non-blocking but noisy) |

### 4.1 Azure Login Step — Additional Finding

The Azure Login step (log 18) authenticates successfully with service principal `edff16c6-3847-4ed8-9975-f085a5643024` into subscription `7b1ba02e-bac6-4c45-83a0-7f0d3104922e` ("Eneco Cloud Foundation - Sandbox-Development-Test"). However, the login script has two bugs:

```
/home/vsts/work/_temp/7f2ed90d-...-1a26bbc098a3.sh: line 11: sandbox-development_subscription_id: command not found
/home/vsts/work/_temp/7f2ed90d-...-1a26bbc098a3.sh: line 14: sandbox-development_subscription_id: command not found
ERROR: The subscription of '' doesn't exist in cloud 'AzureCloud'.
```

The script uses `sandbox-development_subscription_id` as a bare word (command) instead of `$sandbox_development_subscription_id` (variable). The subsequent `az account set --subscription ''` fails because the variable was empty.

**Impact on this build:** Non-blocking. The initial `az login` already set the default subscription to `7b1ba02e-...`, so the tests could still authenticate. The test failures are caused by the 503 (service down) and the JSON fixture bug, not by auth. However, this script error should be fixed to avoid confusion in future troubleshooting.

### 4.2 Verified Test Results Summary

| Step | Hook | Root Error | Failed | Passed | Skipped | Total | Duration |
|------|------|-----------|--------|--------|---------|-------|----------|
| VRE | `BeforeFeatureVre` (line 53) | 503 Service Unavailable | 23 | 0 | 22 | 45 | 6s |
| Battery | `BeforeFeatureBattery` (line 64) | JsonSerializationException: null→double | 18 | 0 | 12 | 30 | 4s |
| DP | `BeforeFeatureDecentralizedPool` (line 75) | 503 Service Unavailable | 8 | 0 | 0 | 8 | 5s |
| CCGT | `BeforeFeatureConventional` (line 86) | 503 Service Unavailable | 19 | 0 | 1 | 20 | 5s |
| **Total** | | | **68** | **0** | **35** | **103** | **20s** |

---

## 5. Recommended Actions

### 5.1 Immediate (Vikas / Team Optimum)

1. **Fix the Battery JSON fixture.** Set `CurtailmentDeviation` to a numeric value (e.g., `0.0`) or make the C# property nullable (`double?`). This is a deterministic bug that will fail on every run.

2. **Re-run the pipeline.** The VRE 503 error may be transient. If the integration-tests service is now healthy, VRE tests should pass on retry.

3. **Check DP and CCGT raw logs** (log IDs 21, 22) to confirm whether they hit the same 503 or the CurtailmentDeviation issue.

### 5.2 Platform Team (If 503 Persists)

4. **Check integration-tests pod on Sandbox.** Is it running? Has it restarted recently? Check liveness probe status.

5. **Check if OpenShift LCM affected Sandbox.** The March 19 ACC LCM was announced — confirm whether Sandbox was also in scope.

6. **Consider adding retry logic** to the `IntegrationTestClient.Post<T>()` for transient HTTP errors (503, 502). A single 503 at 1 AM shouldn't fail the entire pipeline permanently.

---

## 6. Historical Context

| Date | Issue | Root Cause | Resolution |
|------|-------|-----------|------------|
| 2025-06-16 | E2E Dev-MC auth failure | KeyVault secret stale | Updated secret |
| 2025-09-22 | E2E "host doesn't exist" | Pods restarting (CPU throttle → liveness fail) | Pods stabilized |
| 2026-01-22 | E2E abort (AssetPlanning) | CPU throttling on build agents (0.5 CPU) | Doubled to 1.0 CPU |
| 2026-01-27 | Flex Reservation E2E failing | Feature flag interference | Disabled FF |
| **2026-03-23** | **VRE: 503 from nginx** | **Integration-tests service down on Sandbox** | **Re-run / check pod** |
| **2026-03-23** | **Battery: null→double** | **JSON fixture data defect** | **Fix fixture or model** |

---

## 7. Verification Status

| Claim | Status | Evidence |
|-------|--------|----------|
| VRE fails due to 503 | ✅ Verified | Raw log 19: `System.InvalidOperationException: Request failed: 503 Service Temporarily Unavailable` |
| Battery fails due to JSON null→double | ✅ Verified | Raw log 20: `JsonSerializationException: Error converting value {null} to type 'System.Double'. Path 'AssetConfiguration.CurtailmentDeviation'` |
| All failures are cascade from BeforeFeature hooks | ✅ Verified | Every subsequent failure shows `Reqnroll.ReqnrollException: Scenario skipped because of previous before feature hook error` |
| No test logic was actually executed | ✅ Verified | 0 passed across all steps; durations of 4-6s for 30-45 tests confirm no real execution |
| VRE hook calls IntegrationTestClient.Post via SetupMarketAllocation | ✅ Verified | Stack trace in raw log 19 |
| Battery hook calls JsonHelper.ParseJson via OnboardNewAsset | ✅ Verified | Stack trace in raw log 20 |
| .NET 5 warnings are unrelated boilerplate | ✅ Verified | Generic ADO pipeline task warning, tests target net10.0 |
| Pipeline is scheduled daily at 1 AM UTC | ✅ Verified | Pipeline name: "Daily Run at 1AM UTC", first log entry at 01:02:55 UTC |
| DP tests fail due to 503 | ✅ Verified | Raw log 21: same `503 Service Temporarily Unavailable`, hook `BeforeFeatureDecentralizedPool` (line 75) |
| CCGT tests fail due to 503 | ✅ Verified | Raw log 22: same `503 Service Temporarily Unavailable`, hook `BeforeFeatureConventional` (line 86) |
| Azure Login authenticates successfully | ✅ Verified | Raw log 18: SP `edff16c6-...` logged into sub `7b1ba02e-...` ("Sandbox-Development-Test") |
| Azure Login script has variable bugs | ✅ Verified | Raw log 18: `sandbox-development_subscription_id: command not found` (missing `$`) |
| Credentials are NOT the cause | ✅ Verified | Auth succeeded; errors are 503 (service down) and JSON deserialization, not 401/403 |
