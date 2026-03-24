# Root Cause Analysis — Dispatching E2E Pipeline Failure (Build 1579769)

**Ticket:** Rec0AN3LF6Z4M
**Requester:** Vikas Yadav
**Date:** 2026-03-23
**Pipeline:** Dispatching End to End Tests - Sandbox - Daily Run at 1AM UTC
**Repo:** Eneco.Vpp.Core.Dispatching
**Verification method:** Live Azure DevOps API, pipeline logs, repo code inspection, build history analysis (71 builds)

---

## Summary

Build 1579769 has **103 tests, all failing** (68 failed, 35 skipped, 0 passed) across four test steps (VRE, Battery, DP, CCGT). Every failure originates in `[BeforeFeature]` hooks — no test logic was executed. There are **three distinct root causes**, not two.

---

## Root Cause 1: Integration-tests service down on Sandbox (PERSISTENT)

**Affects:** VRE (45 tests), DP (8 tests), CCGT (20 tests) — 73 tests total

**What happens:** The `[BeforeFeature]` hook sends an HTTP POST to the integration-tests service on Sandbox to set up market allocation data. The service returns `503 Service Temporarily Unavailable` from nginx. The exception poisons the entire feature — all downstream scenarios cascade-fail via `Reqnroll.ReqnrollException: Scenario skipped because of previous before feature hook error`.

**Call chain (verified from Hooks.cs + FeatureConfigurationService.cs + build log 19):**

```
Hooks.BeforeFeatureVre()
  → FeatureConfigurationService.SetupAssetForFeature("VRE_ResVarsCalc")
    → SetupAssetWithConfiguration()
      → ConfigureAssetMarketAndStartProcessor()
        → AssetTestDataSetup.SetupMarketAllocation()
          → IntegrationTestClient.Post<T>()
            → 503 Service Temporarily Unavailable (nginx)
```

**Error from raw log (log ID 19, build 1579769):**

```
System.InvalidOperationException : Request failed: <html>
<head><title>503 Service Temporarily Unavailable</title></head>
<body>
<center><h1>503 Service Temporarily Unavailable</h1></center>
<hr><center>nginx</center>
</body>
</html>
```

**This is NOT transient.** Build history analysis shows:

| Date | Build | VRE 503? | Evidence |
|------|-------|----------|----------|
| Mar 16 14:05 | 1571100 | No | DP passed 8/8 in 2m50s. VRE had assertion failures (service was UP). |
| Mar 17 14:26 | 1572965 | No | DP passed 7/8 in 2m49s. VRE had assertion failures (service was UP). |
| **Mar 18 15:19** | **1575069** | **Yes** | **First 503 observed.** |
| Mar 19 01:01 | 1575476 | Yes | 503 in VRE log. |
| Mar 20 01:01 | 1577299 | Yes | 503 in VRE log. |
| Mar 21 01:01 | 1578983 | Yes | 503 in VRE log. |
| Mar 22 01:01 | 1579367 | Yes | 503 in VRE log — identical error. |
| Mar 23 01:01 | 1579769 | Yes | 503 in VRE log — identical error. |

**The 503 started between March 17 14:26 and March 18 15:19** and has persisted in every build since — 6 consecutive days, 12+ builds. Re-running the pipeline will not fix this. The integration-tests service on Sandbox needs investigation by the platform/infra team (pod status, OpenShift events, nginx ingress configuration).

---

## Root Cause 2: JSON fixture data defect (DETERMINISTIC)

**Affects:** Battery (30 tests)

**What happens:** The `[BeforeFeatureBattery]` hook calls `OnboardNewAsset`, which deserializes a JSON test fixture. The fixture file `ler_onboard_asset.json` has `"CurtailmentDeviation": null` at line 43, but the target C# model `OnboardAssetDto.AssetConfiguration.CurtailmentDeviation` is declared as `double` (non-nullable). Newtonsoft.Json cannot convert null to `System.Double`.

**Call chain (verified from Hooks.cs + FeatureConfigurationService.cs + OnboardAssetDto.cs + build log 20):**

```
Hooks.BeforeFeatureBattery()
  → FeatureConfigurationService.SetupAssetForFeature("Battery_ResVarsCalc")
    → SetupAssetWithConfiguration(AssetSetupConfig("LER", "130", 25, -25))
      → AssetHelper.OnboardAssetWithSchemaAndIdentifier("LER", "130")
        → AssetHelper.OnboardNewAsset()
          → JsonHelper.ParseJson<T>()  // reads ler_onboard_asset.json
            → Newtonsoft.Json.JsonConvert.DeserializeObject<T>()
              → JsonSerializationException: null → double
```

**Error from raw log (log ID 20, build 1579769):**

```
Newtonsoft.Json.JsonSerializationException :
  Error converting value {null} to type 'System.Double'.
  Path 'AssetConfiguration.CurtailmentDeviation', line 43, position 34.
---- System.InvalidCastException :
  Null object cannot be converted to a value type.
```

**Code evidence:**

| File | Location | Content |
|------|----------|---------|
| `ler_onboard_asset.json` | `TestData/AssetOnboardingFiles/` | `"CurtailmentDeviation": null` |
| `OnboardAssetDto.cs` | `Models/Request/` | `public double CurtailmentDeviation { get; set; }` |
| `FeatureConfigurationService.cs` | `Services/` | Battery maps to `AssetSetupConfig("LER", ...)` — uses LER fixture |

**Other fixtures for reference:** `conventional_onboard_asset.json` has `CurtailmentDeviation: 2`, `vre_onboard_asset.json` has `10`, `decentralizedpool_onboard_asset.json` has `0`. Only `ler_onboard_asset.json` has `null`.

**Fix (one of):**
- Set `CurtailmentDeviation` to a numeric value in `ler_onboard_asset.json` (e.g., `0.0`)
- Or change the C# property to `double?` in `OnboardAssetDto.cs` if null is a valid business value

**This will fail on every run until fixed.** Confirmed identical error in builds 1571100 (Mar 16), 1579367 (Mar 22), 1579769 (Mar 23).

---

## Root Cause 3: VRE test assertion failures (PRE-EXISTING)

**Affects:** VRE (45 tests) — currently masked by the 503

**What happens:** Before the 503 started (Mar 16-17), VRE tests were actually executing but failing with assertion mismatches. The integration-tests service was healthy, tests ran for minutes (not seconds), but produced wrong calculation results.

**Evidence from build 1572965 (Mar 17 14:26, before 503):**

```
POWER_SCHEDULE Value mismatch. Expected: [70.00000], Actual: [69.31167]
```

**Impact:** Even after the 503 is resolved, VRE tests will not pass. They have separate test logic or calculation bugs that need investigation. The 503 is currently masking this third layer of failure.

---

## Additional Issue: Azure Login Script Variable Bug

**Impact:** Non-blocking (does not cause test failures) but noisy and should be cleaned up.

The Azure Login script uses `sandbox-development_subscription_id` as a bare command instead of `$sandbox_development_subscription_id` (missing `$` prefix). This causes:

```
line 11: sandbox-development_subscription_id: command not found
ERROR: The subscription of '' doesn't exist in cloud 'AzureCloud'.
```

The initial `az login` already sets the correct default subscription (`7b1ba02e-bac6-4c45-83a0-7f0d3104922e`, "Sandbox-Development-Test"), so tests can still authenticate. However, this has not been formally ruled out as a contributing factor to the 503.

---

## What's NOT the Issue

- **Credentials are fine.** Azure Login succeeded — SP `edff16c6-3847-4ed8-9975-f085a5643024` authenticated into subscription `7b1ba02e-bac6-4c45-83a0-7f0d3104922e`.
- **.NET 5 warnings are unrelated.** Generic ADO pipeline task boilerplate. Tests target `net10.0`.
- **Build and download steps pass fine.** Only the test execution steps fail.

---

## Test Results (Build 1579769)

| Step | Hook | Root Cause | Failed | Passed | Skipped | Total | Duration |
|------|------|-----------|--------|--------|---------|-------|----------|
| VRE | `BeforeFeatureVre` | 503 Service Unavailable | 23 | 0 | 22 | 45 | 6s |
| Battery | `BeforeFeatureBattery` | JsonSerializationException: null→double | 18 | 0 | 12 | 30 | 4s |
| DP | `BeforeFeatureDecentralizedPool` | 503 Service Unavailable | 8 | 0 | 0 | 8 | 5s |
| CCGT | `BeforeFeatureConventional` | 503 Service Unavailable | 19 | 0 | 1 | 20 | 5s |
| **Total** | | | **68** | **0** | **35** | **103** | **20s** |

---

## Pipeline Health Context

**Last fully successful build: June 28, 2024** (Build 871658) — 9 months ago, 71 builds since then with zero successes. The current failures are the latest layer in a chronic pattern:

| Era | Dates | Failure Mode |
|-----|-------|-------------|
| Pre-Mar 13 | Unknown | Multiple historical incidents (auth, pod restarts, CPU throttling) |
| Mar 13-17 | Active troubleshooting | Battery JSON bug + VRE assertion failures. No 503. Manual retries on Mar 13. |
| Mar 18-23 | Current | 503 added on top of existing Battery + VRE failures. All 103 tests fail. |

---

## Recommended Actions

### Immediate

1. **Fix the Battery JSON fixture.** In `ler_onboard_asset.json`, change `"CurtailmentDeviation": null` to `"CurtailmentDeviation": 0.0` (or make the C# property nullable). This is a one-line fix for a deterministic bug.

2. **File an infrastructure ticket for the 503.** The integration-tests service on Sandbox has been unreachable since ~March 18. This needs platform team investigation: pod status, OpenShift events, nginx ingress logs, deployment history. Do NOT just re-run the pipeline — it has failed on every attempt for 6 days.

### After 503 Is Resolved

3. **Investigate VRE assertion failures.** VRE tests have pre-existing calculation mismatches (e.g., `Expected: 70.00, Actual: 69.31`) that are currently masked by the 503. These are separate bugs.

4. **Fix Azure Login variable references.** Add `$` prefix to `sandbox-development_subscription_id` in the login script. Low priority but reduces log noise.

### Strategic

5. **This pipeline has not succeeded in 9 months.** The three root causes above are the current visible failures, but the pipeline has deeper systemic issues. Consider assigning an owner accountable for pipeline health: health-check pre-gates, test fixture validation, retry logic for transient HTTP errors, and active monitoring of pipeline results.

---

## Verification Confidence

This analysis was verified against live systems on 2026-03-23:

- **21 claims checked**: 19 confirmed, 1 refuted ("transient" label), 1 unverified (PR 168286)
- **Evidence sources**: `az pipelines runs show/list`, ADO build timeline API, raw build logs (IDs 18-22), ADO Git Items API for repo file contents
- **Cross-build validation**: Error patterns confirmed across builds 1571100 (Mar 16), 1572965 (Mar 17), 1575069 (Mar 18), 1579367 (Mar 22), 1579769 (Mar 23)
- **Adversarial review**: Contrarian challenge completed — factual verification graded ACCEPTABLE

Supporting evidence files in this directory:
- `context/claim-verification-evidence.md` — full claim-by-claim verification table
- `verification/phase-8-results.md` — detailed verification report
- `verification/contrarian-challenge.md` — adversarial challenge findings
- `2026_03_23_vikas_e2e_vre_beforefeature_hook_failure.md` — original investigation
