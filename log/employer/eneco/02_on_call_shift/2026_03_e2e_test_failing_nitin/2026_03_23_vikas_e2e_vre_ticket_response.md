# Ticket Response — Vikas E2E Pipeline Failure (Build 1579769)

**Ticket:** Rec0AN3LF6Z4M
**Requester:** Vikas Yadav
**Date:** 2026-03-23

---

## What We Found

We inspected the raw logs for all test steps in build [1579769](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_build/results?buildId=1579769&view=logs). The pipeline ("Dispatching End to End Tests - Sandbox - Daily Run at 1AM UTC") has **two distinct root causes** across its test steps:

### Issue 1: VRE Tests — Integration-tests service was down (503)

The `[BeforeFeature]` hook for VRE tests sends an HTTP POST to the integration-tests service on Sandbox via `IntegrationTestClient.Post<T>()` to set up market allocation data. At 01:02 UTC, the service returned:

```
503 Service Temporarily Unavailable (nginx)
```

This caused all 45 VRE scenarios to cascade-fail (23 failed, 22 skipped). No test logic was reached.

**Call chain:** `Hooks.BeforeFeatureVre` → `SetupAssetForFeature` → `ConfigureAssetMarketAndStartProcessor` → `SetupMarketAllocation` → `IntegrationTestClient.Post<T>()` → 503

**This is likely transient.** The integration-tests pod on Sandbox was unreachable at that time — possibly due to a pod restart, OpenShift LCM activity (v4.18 upgrade was announced for March 19 on ACC), or a transient infrastructure event. Re-running the pipeline should resolve this if the service is now healthy.

### Issue 2: Battery Tests — JSON fixture data defect

The `[BeforeFeature]` hook for Battery tests fails when onboarding a new asset. The JSON test fixture has `"CurtailmentDeviation": null` (line 43), but the C# model expects `double` (non-nullable). Newtonsoft.Json cannot convert null to `System.Double`.

```
Newtonsoft.Json.JsonSerializationException:
  Error converting value {null} to type 'System.Double'.
  Path 'AssetConfiguration.CurtailmentDeviation', line 43, position 34.
```

**Call chain:** `Hooks.BeforeFeatureBattery` → `SetupAssetForFeature` → `SetupAssetWithConfiguration` → `OnboardNewAsset` → `JsonHelper.ParseJson<T>()` → deserialization fails

**This is a deterministic bug** — it will fail on every run until fixed. The fix is one of:
- Set `CurtailmentDeviation` to a numeric value in the JSON fixture (e.g., `0.0`)
- Or change the C# property to `double?` if null is a valid value

### DP and CCGT Tests (Verified)

Both hit the same **503 Service Temporarily Unavailable** from the integration-tests service, via the same `SetupMarketAllocation` → `IntegrationTestClient.Post<T>()` path. DP failed all 8 tests; CCGT failed 19 of 20 (1 skipped).

**Totals across all 4 steps:** 68 failed, 0 passed, 35 skipped, 103 total tests — in 20 seconds.

## What You Need to Do

1. **Fix the Battery JSON fixture** — this is a deterministic code/data defect. The JSON test fixture has `"CurtailmentDeviation": null` (line 43) but the C# model expects `double` (non-nullable). Either set it to a numeric value (e.g., `0.0`), or change the C# property to `double?`. This will fail on every run until fixed.

2. **Re-run the pipeline** — the 503 errors (VRE, DP, CCGT) are transient. The integration-tests service on Sandbox was down at 01:02 UTC. If it's healthy now, those three test suites should pass on retry.

## What's NOT the Issue

- **Credentials are fine.** Azure Login succeeded — service principal `edff16c6-...` authenticated into subscription `7b1ba02e-...` ("Sandbox-Development-Test"). The test failures are 503 (service down) and JSON deserialization errors, not auth failures.
- The `.NET 5` warnings in the pipeline are generic ADO boilerplate — unrelated. Tests correctly target `net10.0`.
- The build and download steps passed fine.

## Minor Pipeline Issue (FYI)

The Azure Login script has a variable reference bug: `sandbox-development_subscription_id` is used as a bare command instead of `$sandbox_development_subscription_id`. This causes `command not found` errors and a failed `az account set`. It doesn't affect this build (the initial login already sets the default subscription), but it should be cleaned up to avoid confusion.

---

*Build ran 2026-03-23 at 01:02 UTC. Raw logs verified for VRE (log 19) and Battery (log 20).*
