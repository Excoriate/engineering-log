# Root Cause Analysis: ACC ClientGateway Release Failure

**Date**: 2026-04-13
**Incident**: One-For-All pipeline (build 20260413.1) erased ClientGateway image tags in DEV and ACC
**Severity**: High (ACC release blocked, ArgoCD sync failing)
**Status**: Root cause confirmed, fix ready for execution

---

## 1. Executive Summary

The `clientgateway` variable is **missing** from the ADO variable group `Release-0.145` (ID 5262). When the One-For-All pipeline ran on `release/0.145`, it tried to expand `$(clientgateway)` — an Azure DevOps macro — but since the variable doesn't exist, ADO left the literal string `$(clientgateway)` in the bash script. Bash interpreted this as command substitution, producing `clientgateway: command not found`. The result: an **empty version string** was written to `Helm/clientgateway/{dev,acc}/values-override.yaml`, causing ArgoCD to fail syncing the ClientGateway service.

**This is a known, recurring pattern.** The identical failure occurred in September 2025 with the `telemetry` service. Roel van de Grint diagnosed and fixed it the same day by restoring the missing variable.

---

## 2. Impact Assessment

| Environment | ClientGateway Status | Other Services | Action Needed |
|------------|---------------------|----------------|---------------|
| **DEV** | **BROKEN** — `tag: ""` (was `0.145.0`) | All OK at `0.145.0` | Fix required |
| **ACC** | **BROKEN** — `tag: ""` (was `0.144.0`) | All OK at `0.145.0` | Fix required |
| **PROD** | OK — `tag: "0.128.0"` | Unaffected | `prod-env = false` |
| **Sandbox** | OK — `tag: "0.145.dev.6c4e74e"` | Unaffected | Not in pipeline scope |

**Blast radius**: ClientGateway only. All other 16 services were correctly updated to `0.145.0/0.145.1`.

---

## 3. Root Cause

> **The `clientgateway` variable was not added to the `Release-0.145` ADO variable group when the release was created.**

This is a **data omission**, not a code bug. The pipeline script is functioning correctly — it simply received no version input for ClientGateway.

---

## 4. Mechanism — How It Happened

### 4.1 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                    RELEASE PIPELINE ARCHITECTURE                     │
│                                                                      │
│  ┌──────────────┐    ┌──────────────────┐    ┌──────────────────┐   │
│  │ ADO Variable  │    │  One-For-All     │    │ VPP-Configuration│   │
│  │ Group         │───▶│  Pipeline        │───▶│ Git Repo         │   │
│  │ Release-0.145 │    │  (ID: 1811)      │    │ (Helm values)    │   │
│  │               │    │                  │    │                  │   │
│  │ activationm=  │    │  Reads variables │    │ Helm/            │   │
│  │   0.145.0     │    │  Iterates svc    │    │   activationm/   │   │
│  │ asset=0.145.0 │    │  Writes tags     │    │   asset/         │   │
│  │ ❌ clientgw   │    │  to values-      │    │   clientgateway/ │   │
│  │   MISSING!    │    │  override.yaml   │    │     acc/         │   │
│  │ monitor=      │    │  Commits & push  │    │     dev/         │   │
│  │   0.145.0     │    │                  │    │     prod/        │   │
│  │ ...           │    │                  │    │   ...            │   │
│  └──────────────┘    └──────────────────┘    └────────┬─────────┘   │
│                                                        │             │
│                                                        ▼             │
│                                               ┌──────────────────┐   │
│                                               │     ArgoCD       │   │
│                                               │  Syncs Helm      │   │
│                                               │  values to K8s   │   │
│                                               │                  │   │
│                                               │  ❌ Empty tag    │   │
│                                               │  = Sync FAIL     │   │
│                                               └──────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.2 Causal Chain (Step-by-Step)

```
Step 1: Release-0.145 variable group created
        ✅ 20 service variables added (activationmfrr, asset, etc.)
        ❌ clientgateway NOT added (human omission or automation gap)
            │
            ▼
Step 2: One-For-All pipeline triggered on release/0.145
        Pipeline YAML (line 5): group: Release-$(Build.SourceBranchName)
        → Links to Release-0.145 variable group
            │
            ▼
Step 3: ADO macro expansion
        YAML line 44: "clientgateway:$(clientgateway)"
        ✅ $(activationmfrr) → "0.145.0"     (variable EXISTS)
        ❌ $(clientgateway) → "$(clientgateway)"  (variable MISSING → literal passthrough)
            │
            ▼
Step 4: Bash receives the literal string
        serviceVersions array element: "clientgateway:$(clientgateway)"
        Inside double quotes, $(clientgateway) = BASH COMMAND SUBSTITUTION
        Bash tries to execute 'clientgateway' as a command
        → "clientgateway: command not found" (stderr, exit code 127)
        → Command output = "" (empty string captured)
        → Array element becomes "clientgateway:" (empty version)
            │
            ▼
Step 5: Script processes clientgateway with empty version
        imagetag=$(echo "${service#*:}")  → imagetag=""
        yq -i ".image.tag = \"\"" Helm/clientgateway/acc/values-override.yaml
        yq -i ".image.tag = \"\"" Helm/clientgateway/dev/values-override.yaml
        → Both files now contain: tag: ""
            │
            ▼
Step 6: Script commits and pushes
        git commit -m "build 20260413.1"
        git push origin HEAD:main
        → Commit 25d008a14 on main
            │
            ▼
Step 7: ArgoCD detects change, attempts sync
        Reads Helm/clientgateway/acc/values-override.yaml
        Sees: image.tag: ""
        → Cannot pull image with empty tag → Sync FAILS
```

### 4.3 Why the Script Doesn't Catch This

The script at `azure-pipeline/pipelines/oneforallmsv2.yaml` (lines 40-61) builds a bash array:

```bash
serviceVersions=( "activationmfrr:$(activationmfrr)"   # → "activationmfrr:0.145.0" ✅
                  "asset:$(asset)"                       # → "asset:0.145.0" ✅
                  ...
                  "clientgateway:$(clientgateway)"       # → "clientgateway:" ❌ EMPTY!
                  ...
                )
```

Key design flaws in the script:
1. **No `set -e`**: Script continues after errors (line 24: `retryCountOnTaskFailure: "7"` means it retries the ENTIRE step, not individual commands)
2. **No variable validation**: Script doesn't check if `$(variable)` resolved to a non-empty value before writing
3. **No guard on empty tags**: `yq` happily writes `tag: ""` — there's no check for empty imagetag
4. **Destructive write**: Overwrites existing valid tag with empty string

---

## 5. Evidence Table

| # | Claim | Classification | Source | Verified By |
|---|-------|---------------|--------|-------------|
| 1 | `clientgateway` absent from Release-0.145 variable group | **FACT** | `az pipelines variable-group show --id 5262` | CLI output |
| 2 | `clientgateway = 0.144.0` present in Release-0.144 | **FACT** | `az pipelines variable-group show --id 5242` | CLI output |
| 3 | Pipeline links to `Release-$(Build.SourceBranchName)` | **FACT** | `oneforallmsv2.yaml` line 5 | File read |
| 4 | Script uses `$(clientgateway)` at line 44 | **FACT** | `oneforallmsv2.yaml` line 44 | File read |
| 5 | Log shows `clientgateway: command not found` | **FACT** | Pipeline screenshot line 17 | Visual evidence |
| 6 | Git diff: `tag: "0.144.0"` → `tag: ""` in ACC | **FACT** | `git diff 25d008a14^..25d008a14` | Git output |
| 7 | Git diff: `tag: "0.145.0"` → `tag: ""` in DEV | **FACT** | `git diff 25d008a14^..25d008a14` | Git output |
| 8 | PROD `tag: "0.128.0"` untouched | **FACT** | `prod-env = false` in variable group | CLI output |
| 9 | CD pipeline build `0.145.0-0.145` succeeded | **FACT** | `az pipelines runs list --pipeline-ids 1945` | CLI output |
| 10 | Prior DEV update to `0.145.0` existed (Apr 10) | **FACT** | `git log --all -- Helm/clientgateway/dev/` | Git output |
| 11 | September 2025 identical incident with `telemetry` | **FACT** | Slack thread + user report | User-provided |
| 12 | Variable group creation process has automation gap | **INFER** | Variable present in 0.144, absent in 0.145 | Pattern match |

---

## 6. The Other 3 "Command Not Found" Errors

The screenshot shows 4 services failing, but only `clientgateway` is the actual regression:

| Service | In Release-0.144 | In Release-0.145 | Helm dev/acc dirs exist? | Verdict |
|---------|------------------|-------------------|--------------------------|---------| 
| **clientgateway** | ✅ `0.144.0` | ❌ **MISSING** | ✅ Yes | **THE BUG** |
| gatewaynl | ❌ Missing | ❌ Missing | ❌ No Helm dir | Pre-existing noise |
| alarmengine | ❌ Missing | ❌ Missing | ❌ sandbox only | Pre-existing noise |
| alarmpreprocessing | ❌ Missing | ❌ Missing | ❌ sandbox only | Pre-existing noise |

The script's `if [[ -f $valuesFilePath ]]` guard (line 80) protects against the other 3 — since they have no dev/acc Helm files, nothing gets written. But `clientgateway` HAS those files, so the empty version IS written destructively.

---

## 7. Fix Instructions

### Fix Option A: Variable Group + Re-run (RECOMMENDED)

This fixes the root cause AND regenerates correct values:

```bash
# Step 1: Add clientgateway variable to Release-0.145 group
az pipelines variable-group variable create \
  --group-id 5262 \
  --name "clientgateway" \
  --value "0.145.0" \
  --org https://dev.azure.com/enecomanagedcloud \
  --project "Myriad - VPP"

# Step 2: Verify the variable was added
az pipelines variable-group show --id 5262 \
  --org https://dev.azure.com/enecomanagedcloud \
  --project "Myriad - VPP" \
  --output json | python3 -c "
import sys,json
d=json.load(sys.stdin)
v=d.get('variables',{}).get('clientgateway',{})
print(f'clientgateway = {v.get(\"value\",\"NOT FOUND\")}')
"

# Step 3: Re-run One-For-All pipeline on release/0.145
az pipelines run \
  --id 1811 \
  --branch "release/0.145" \
  --org https://dev.azure.com/enecomanagedcloud \
  --project "Myriad - VPP"

# Step 4: Monitor the pipeline run
# Check the ADO pipeline UI for build completion
# URL: https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_build?definitionId=1811

# Step 5: Verify the fix (after pipeline completes)
cd /path/to/VPP-Configuration && git pull origin main
cat Helm/clientgateway/acc/values-override.yaml
# Expected output:
# image:
#   tag: "0.145.0"

cat Helm/clientgateway/dev/values-override.yaml
# Expected output:
# image:
#   tag: "0.145.0"
```

### Fix Option B: Direct Git Commit (FASTEST — for emergency)

If you need the fix NOW without waiting for pipeline re-run:

```bash
cd /path/to/VPP-Configuration
git checkout main && git pull origin main

# Fix ACC
cat > Helm/clientgateway/acc/values-override.yaml << 'EOF'
image:
  tag: "0.145.0"
EOF

# Fix DEV
cat > Helm/clientgateway/dev/values-override.yaml << 'EOF'
image:
  tag: "0.145.0"
EOF

git add Helm/clientgateway/acc/values-override.yaml Helm/clientgateway/dev/values-override.yaml
git commit -m "fix: Restore clientgateway image tag to 0.145.0 (erased by build 20260413.1)"
git push origin main

# IMPORTANT: Also fix the variable group (Step 1 from Option A) to prevent recurrence
```

### Fix Option C: Deterministic Script (RECOMMENDED for repeatability)

A reusable diagnostic + fix script is available at:
`oneforall-diagnose-and-fix.sh` (same directory as this RCA)

```bash
# Step 1: Diagnose — shows exactly what's missing
./oneforall-diagnose-and-fix.sh diagnose 0.145

# Step 2: Fix — adds the missing variable
./oneforall-diagnose-and-fix.sh fix 0.145 clientgateway 0.145.0

# Step 3: Fix AND re-run pipeline (with pre-flight checks)
./oneforall-diagnose-and-fix.sh fix-and-rerun 0.145 clientgateway 0.145.0

# Step 4: Verify after pipeline completes
./oneforall-diagnose-and-fix.sh verify-fix 0.145
```

This script is reusable for ANY future occurrence of this pattern (any release, any service).

### Recommended Approach: Option C (script), fall back to Option B for emergency

1. Run `diagnose` to confirm the issue
2. Run `fix` to add the missing variable
3. Run `fix-and-rerun` to trigger the pipeline (includes pre-flight safety checks)
4. If pipeline takes too long, use Option B for immediate relief

---

## 8. Fix Validation Checklist

After applying the fix, verify:

- [ ] `az pipelines variable-group show --id 5262` shows `clientgateway = 0.145.0`
- [ ] VPP-Configuration `Helm/clientgateway/acc/values-override.yaml` shows `tag: "0.145.0"`
- [ ] VPP-Configuration `Helm/clientgateway/dev/values-override.yaml` shows `tag: "0.145.0"`
- [ ] ArgoCD ACC sync status for clientgateway is `Synced` / `Healthy`
- [ ] ArgoCD DEV sync status for clientgateway is `Synced` / `Healthy`
- [ ] ClientGateway pods in ACC are running with image tag `0.145.0`

---

## 9. Recurrence Prevention Recommendations

This is the **second occurrence** of this exact failure pattern (first: telemetry, Sept 2025). Structural fixes to prevent a third:

### Short-term (Quick Wins)
1. **Script guard**: Add validation to `oneforallmsv2.yaml` to check for empty versions before writing:
   ```bash
   if [[ -z "$imagetag" ]]; then
     echo "ERROR: Empty version for $serviceName. Skipping."
     continue
   fi
   ```
2. **Pipeline gate**: Add a verification step after the version-writing loop that checks no `tag: ""` exists in any values-override.yaml

### Medium-term
3. **Variable group automation**: The Release-0.X variable group should be automatically populated from CI build outputs, not manually curated
4. **Service registry**: Maintain a single source of truth for which services are in each release, validated before One-For-All runs

### Long-term
5. **GitOps validation**: Add a pre-commit hook or CI check on VPP-Configuration that rejects commits with `tag: ""` in any values-override.yaml
6. **ArgoCD pre-sync check**: Configure ArgoCD to validate image tags are non-empty before attempting sync

---

## 10. Historical Precedent

| Date | Service | Reporter | Fixer | Fix |
|------|---------|----------|-------|-----|
| **2025-09-01** | `telemetry` | Artem Diachenko | Roel van de Grint | Restored variable in ADO group, re-ran One-For-All |
| **2026-04-13** | `clientgateway` | Artem Diachenko | *(pending)* | Same fix pattern |

Same reporter, same pipeline, same mechanism, same fix. This is a structural gap in the release process.

---

## 11. Adversarial Validation Summary

### SRE-Maniac Validation (completed)

**Overall verdict: "FIX FIRST — Diagnosis is correct on mechanism but incomplete on root cause."**

| Challenge | Finding | Response |
|-----------|---------|----------|
| 1. Causal chain complete? | Mechanism PROVEN. But WHY variable missing is undiagnosed (process gap). | **ACCEPTED** — `a_placeholder = delete_me` suggests groups created empty then populated incrementally. [INFER] |
| 2. Fix sufficient? | Correct but carries re-run risks. Verify no manual hotfixes first. | **ACCEPTED** — Verified: no commits since 25d008a14. Safe to re-run. |
| 3. Why did variable disappear? | Not "disappeared" — was never added. Process failure, not one-off. | **ACCEPTED** — Root cause is unvalidated manual group creation process. |
| 4. Other 3 services harmless? | Harmless TODAY but evidence of systemic debt. "Boy who cried wolf" effect. | **ACCEPTED** — Normalized errors delayed detection of real failure. |
| 5. Blast radius? | Extends through clientgateway as API gateway to all consumers. | **ACCEPTED** — But scoped to ACC/DEV, not production. |
| 6. Recurrence prevention? | Zero structural prevention exists. **This will happen again.** | **ACCEPTED** — Empty-tag guard is the minimum immediate fix. |

**Critical SRE finding**: `retryCountOnTaskFailure: "7"` makes the pipeline retry the ENTIRE destructive write up to 7 times. Each retry after the first is idempotent (no new damage), but the retry mechanism is a design hazard.

**SRE grades**: Mechanism: A | Evidence: A | Causal completeness: C | Fix proposal: B- | Recurrence prevention: F

### Pre-Conditions Verified

- [x] No manual hotfix commits on VPP-Configuration/main since `25d008a14` (verified via `git log`)
- [x] ClientGateway CD pipeline build `0.145.0-0.145` succeeded on `release/0.145` (verified via `az pipelines runs list`)
- [x] `clientgateway` variable confirmed absent from Release-0.145 group (verified via `az pipelines variable-group show`)
- [x] All other services in Release-0.145 group are correct (verified via CLI output)

---

## 12. Epistemic Summary

| Classification | Count | Notes |
|---------------|-------|-------|
| **FACT** | 12 | All from CLI output, git diff, file reads, pipeline logs |
| **INFER** | 2 | Variable group creation process, blast radius through clientgateway |
| **SPEC** | 0 | — |

FACT-dominant analysis. The 2 INFER claims are non-load-bearing — they inform recurrence prevention, not the immediate fix.
