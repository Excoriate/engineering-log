---
task_id: 2026-04-13-001
agent: sre-maniac
status: complete
summary: |
  SRE adversarial validation of root cause analysis for clientgateway empty-tag incident.
  Diagnosis is SOLID on the proximate cause but INCOMPLETE on root cause (WHY the variable
  is missing). The proposed fix (add variable + re-run) is NECESSARY but carries re-run risks
  and does NOTHING to prevent recurrence. The retry-7 configuration on the pipeline task is a
  force multiplier for destruction. Six adversarial challenges addressed with specific gaps
  and structural recommendations.
---

## Key Findings

1. Causal chain is mechanistically correct but stops at proximate cause -- WHY clientgateway was omitted from Release-0.145 variable group is undiagnosed
2. retryCountOnTaskFailure=7 means the destructive write was attempted up to 7 times, amplifying blast radius of any git conflict or partial failure
3. Re-running One-For-All will overwrite ANY manual hotfix committed to VPP-Configuration main between now and re-run due to git checkout main + pull + push pattern
4. The 3 other "command not found" services (gatewaynl, alarmengine, alarmpreprocessing) are evidence of a SYSTEMIC naming/inclusion debt, not harmless noise
5. No structural prevention exists -- variable group creation is unvalidated manual process, guaranteeing recurrence

# SRE Adversarial Validation: ClientGateway Empty-Tag Root Cause Analysis

**Verdict: FIX FIRST -- Diagnosis is correct on mechanism but incomplete on root cause. Proposed fix is necessary but insufficient.**

---

## Challenge 1: Is the Causal Chain Complete?

### Assessment: MECHANISTICALLY CORRECT, CAUSALLY INCOMPLETE

The stated chain is:

```
Missing variable --> ADO leaves literal $(clientgateway) --> bash command substitution
--> "command not found" --> empty string captured --> yq writes tag: "" --> ArgoCD fails
```

**This chain is CONFIRMED by multiple independent FACT-level evidence sources.** The pipeline YAML (vpp-configuration-repo.md, Section 1) shows the exact mechanism at line 65:

```bash
"clientgateway:$(clientgateway)"
```

When `$(clientgateway)` is undefined in ADO, it remains literal. Bash interprets `$(clientgateway)` as command substitution. The command `clientgateway` does not exist on the build agent. Command substitution captures empty stdout. The `service#*:` extraction at line 98 yields empty string. `yq -i ".image.tag = \"$imagetag\""` writes `tag: ""`. This is airtight.

**However, the chain is INCOMPLETE in two critical ways:**

**Gap 1: The chain does not explain WHY `clientgateway` is missing from Release-0.145.**

The diagnosis says "the variable is missing" but not WHY. This matters because:
- If the variable group is created MANUALLY, this is a human error in a manual process (different fix: checklist/automation)
- If the variable group is created by AUTOMATION, the automation has a bug (different fix: fix the automation)
- If the variable group is CLONED from a prior release and variables are added incrementally as services build, then the timing of the One-For-All run matters (different fix: run ordering)

The investigation identified the build was triggered MANUALLY by "Diachenko, AV (Artem)" [FACT: acc-environment-state.md, Section 5]. The trigger reason is `manual`. This means someone manually ran the One-For-All pipeline on release/0.145 branch, and at that moment, the Release-0.145 variable group did not contain `clientgateway`. But WHO creates the variable group? When? How? These questions are unanswered.

**Gap 2: The chain does not explain the ArgoCD failure mode precisely.**

The diagnosis says "ArgoCD sync fails." But HOW does ArgoCD handle `tag: ""`?

- Does it attempt to pull `<registry>/clientgateway:` (empty tag)? This would be a Docker pull error.
- Does it attempt to pull `<registry>/clientgateway:latest` (some Helm charts default empty tag to `latest`)? This might SUCCEED with wrong version -- potentially worse than a failure.
- Does the ArgoCD Application go into `Degraded` state? `OutOfSync`? `Error`?
- Does the Helm chart have a `required` validation on `.image.tag`? If so, it fails at template rendering, not at pull time.

Without knowing the exact ArgoCD failure mode, we cannot confirm the diagnosis explains ALL observed symptoms. If the user reported a specific error message from ArgoCD, it should be matched against the mechanism.

**Symptoms this DOES explain:**
- `clientgateway` service broken in DEV and ACC [FACT]
- Git diff showing `tag: "0.144.0"` to `tag: ""` in acc, `tag: "0.145.0"` to `tag: ""` in dev [FACT]
- Pipeline log showing "clientgateway: command not found" [FACT]
- Other services updated correctly in the same commit [FACT]

**Symptoms this might NOT explain (if they exist):**
- Any clientgateway errors that predate commit 25d008a14 (would indicate a different root cause)
- Any ArgoCD issues on services OTHER than clientgateway (would indicate broader problem)
- Any clientgateway issues in PROD (the diagnosis says PROD is unaffected -- if PROD has issues, the diagnosis is incomplete)

### Verdict on Challenge 1: The proximate causal chain (missing variable --> empty tag --> broken deployment) is PROVEN. But the ROOT cause (why the variable is missing) remains at hypothesis level. This is the difference between "how did the gun fire?" (answered) and "who loaded the gun?" (unanswered).

---

## Challenge 2: Is the Fix Sufficient?

### Assessment: NECESSARY BUT CARRIES RISKS. DO NOT BLINDLY RE-RUN.

The proposed fix is: "Add `clientgateway = 0.145.0` to Release-0.145 variable group, re-run One-For-All pipeline."

**Risk 2a: Re-running One-For-All WILL overwrite any manual fixes.**

[FACT] The pipeline script (vpp-configuration-repo.md, lines 56-58) does:

```bash
git checkout main
git pull --ff
```

Then it writes ALL service tags (not just clientgateway) and pushes to main. If someone has manually committed a hotfix to VPP-Configuration/main between the broken commit and the re-run, the pipeline will:

1. Pull the manual fix (good)
2. Overwrite ALL service tags with the variable group values (potentially bad if the manual fix set a DIFFERENT version)
3. Push the result

This is safe ONLY IF no manual commits have been made to VPP-Configuration/main since the broken commit. **Verify with `git log` on VPP-Configuration before re-running.**

**Risk 2b: Environment correctness depends on variable group flags.**

[FACT] The variable group has `test-env=true`, `acc-env=true`, `prod-env=false`. The script (lines 87-93) checks these:

```bash
dev=$(test-env)    # SAME BUG PATTERN! $(test-env) is command substitution in bash
acc=$(acc-env)     # SAME BUG PATTERN!
prod=$(prod-env)   # SAME BUG PATTERN!
```

Wait. This is a CRITICAL observation. Lines 87-89 use `$(test-env)`, `$(acc-env)`, `$(prod-env)`. These are ADO variable references using the `$(...)` syntax. Since `test-env`, `acc-env`, and `prod-env` ARE defined in the variable group [FACT], ADO expands them before bash sees them. So lines 87-89 become:

```bash
dev=true
acc=true
prod=false
```

This works. But the variable names contain HYPHENS (`test-env`, `acc-env`, `prod-env`). In bash, `$(test-env)` would be interpreted as "execute command `test` with argument `-env`" which is a VALID bash command (`test -env` evaluates whether the string `-env` is non-empty, which is always TRUE, returning exit code 0, and command substitution captures stdout which is EMPTY).

**CRITICAL FINDING**: If ADO ever fails to expand these variables (e.g., typo, variable group not linked), the bash fallback behavior is:
- `dev=$(test-env)` --> bash executes `test -env` --> returns true (exit 0), stdout is empty --> `dev=""`
- `acc=$(acc-env)` --> bash executes `acc` --> "acc: command not found" (exit 127), stdout is empty --> `acc=""`
- `prod=$(prod-env)` --> bash executes `prod` --> "prod: command not found" (exit 127), stdout is empty --> `prod=""`

When `dev=""`, `acc=""`, `prod=""`, the `[[ "${!env}" == "true" ]]` check at line 93 would be FALSE for all environments, and NO files would be updated. This is actually the SAFE failure mode -- it would produce a no-op commit. But it's still a latent bug in the script design.

**Risk 2c: Does the clientgateway 0.145.0 container image actually exist?**

The variable group says the version to write is `0.145.0`. But does `vppacra.azurecr.io/eneco-vpp/clientgateway:0.145.0` (or equivalent) actually exist in the container registry?

[FACT from acc-environment-state.md]: The ACC container registry is `vppacra.azurecr.io`. The DEV environment previously had `tag: "0.145.0"` [FACT: it was changed FROM 0.145.0 to "" by the broken commit]. So the 0.145.0 image existed and was deployed to DEV before the incident.

For ACC, the previous tag was `0.144.0`. Setting it to `0.145.0` assumes the 0.145.0 image exists in the ACC registry. Since DEV already had it, and the registries are likely shared (or ACC pulls from the same source), this is LOW RISK but should be verified:

```bash
az acr repository show-tags --name vppacra --repository eneco-vpp/clientgateway --query "[?contains(@, '0.145')]"
```

**Risk 2d: Could re-running create a conflicting commit?**

The script does `git push origin HEAD:main`. If another pipeline or human has pushed to main between the `git pull --ff` and the `git push`, the push will FAIL (non-fast-forward). The script does NOT handle this failure. However, the pipeline has `retryCountOnTaskFailure: "7"` [FACT], so it will retry. Each retry does a fresh `git checkout main` + `git pull --ff`, so the retry WILL pick up the intervening commit and try again.

This retry mechanism is DANGEROUS. Seven retries means seven potential commits if each retry succeeds after pulling a new commit. In practice, the retries are there to handle exactly this race condition. But the blast radius of 7 retries writing empty tags is 7x the damage. If the variable is STILL missing during retries (which it would be -- the variable group doesn't change between retries), each retry writes the same empty tags.

**CRITICAL**: The `retryCountOnTaskFailure: "7"` is a FORCE MULTIPLIER for the bug. The pipeline already ran once and wrote empty tags. If it failed for another reason (git push conflict), it would retry and write empty tags AGAIN up to 7 times. The only saving grace is that writing empty tags is idempotent -- writing "" over "" is a no-op, so `git status -s` would show nothing to commit after the first successful push.

### Verdict on Challenge 2: The fix (add variable + re-run) is correct in principle but requires pre-conditions:
1. **VERIFY** no manual hotfix commits exist on VPP-Configuration/main since commit 25d008a14
2. **VERIFY** the 0.145.0 image exists in the container registry
3. **VERIFY** the Release-0.145 variable group has ALL expected variables (not just clientgateway)
4. **CONSIDER** Option A (direct git fix) from acc-environment-state.md instead of re-running the pipeline -- it's surgical and avoids all re-run risks

---

## Challenge 3: Why Did the Variable Disappear?

### Assessment: THIS IS THE ACTUAL ROOT CAUSE AND IT IS UNDIAGNOSED

The investigation identified WHAT happened (variable missing) and HOW it caused damage (bash command substitution --> empty tag). But the WHY is missing. This is the most dangerous gap in the analysis.

**The variable did not "disappear" -- it was never added.**

[FACT] Release-0.144 variable group (ID 5242) HAS `clientgateway = 0.144.0`.
[FACT] Release-0.145 variable group (ID 5262) does NOT have `clientgateway`.

This means either:
1. Variable groups are created by CLONING the previous release's group and updating versions. If so, the clone was incomplete or someone deleted the clientgateway entry.
2. Variable groups are created FRESH for each release, and variables are added as services build. If so, clientgateway's build either failed, was not triggered, or has not run yet.
3. Variable groups are created by an automation script that enumerates services. If so, the script missed clientgateway.

**The `a_placeholder = delete_me` variable [FACT] is highly suspicious.** Its presence in Release-0.145 suggests that the variable group was created EMPTY (or near-empty) and then variables were added incrementally. The placeholder might be there because ADO requires at least one variable to create a group. This pattern is consistent with scenario 2 above: the group is created first, then populated as builds complete.

**If the variable group is populated incrementally by CI pipelines:**
- Each service's CI pipeline, when it completes a build for release/0.145, adds its version to the Release-0.145 variable group
- clientgateway's CI pipeline either: (a) hasn't run, (b) failed, (c) doesn't add to the variable group
- One-For-All was triggered before clientgateway's CI completed

**The trigger being MANUAL [FACT] changes the calculus:** Someone (Artem Diachenko) manually triggered the One-For-All pipeline. This person may not have verified that all service builds completed and all variables were populated before triggering.

**Historical precedent confirms this is a process problem:**
- September 2025: Identical failure with `telemetry` service [FACT from phase4-investigation-findings.md]
- Same mechanism: missing variable --> empty tag --> broken deployment
- Same fix: add missing variable, re-run pipeline

**Two identical incidents 7 months apart with the same mechanism = PROCESS FAILURE, not a one-off mistake.**

### Verdict on Challenge 3: The root cause is NOT "missing variable." The root cause is: **the One-For-All pipeline has no pre-condition validation that all required variables are present before executing destructive writes.** The variable group population process (manual or automated) has no completeness check. This is a systemic design flaw.

---

## Challenge 4: Are the Other 3 "Command Not Found" Services Truly Harmless?

### Assessment: HARMLESS TODAY, EVIDENCE OF SYSTEMIC DEBT

The diagnosis claims gatewaynl, alarmengine, and alarmpreprocessing are "pre-existing noise." Let me challenge this rigorously.

**The claim is partially correct:**

[FACT] `gatewaynl` has NO Helm directory at all. The variable group has `tenant-gateway` instead. The script references `gatewaynl` at line 79. This is a NAMING MISMATCH that has existed across releases.

[FACT] `alarmengine` and `alarmpreprocessing` have only `sandbox/` Helm directories, not `dev/`, `acc/`, or `prod/`.

[FACT] The `if [[ -f $valuesFilePath ]]` check at line 101 means missing directories cause a skip, not a destructive write.

**So yes, today these 3 services cause no DAMAGE because the file-existence check prevents writes to non-existent paths.**

**But this masks several problems:**

**Problem 4a: The script hardcodes 21 services (lines 61-82) including 4 that will ALWAYS fail.** This is not "noise" -- it is technical debt that:
- Clutters pipeline logs with red-herring errors, making REAL failures harder to spot
- Means the pipeline has 4 errors in EVERY run, normalized as "expected"
- Trained the team to IGNORE "command not found" errors -- which is exactly why the clientgateway failure was not caught immediately

**Problem 4b: The `gatewaynl` / `tenant-gateway` naming mismatch is a LIVE bug.**

If someone creates a `Helm/gatewaynl/dev/values-override.yaml` directory (or if `tenant-gateway` is renamed to `gatewaynl` in the Helm structure), the script would suddenly start writing empty tags for this service too. The only thing preventing damage is the absence of the directory, not the presence of a guard.

**Problem 4c: Were alarmengine and alarmpreprocessing SUPPOSED to be deployed to dev/acc?**

The script includes them in the service list. They have sandbox directories. Were they intended for eventual dev/acc deployment? If so, someone needs to either:
- Add their Helm dev/acc directories + add their variables to the variable group
- Or remove them from the script's service list

Their presence in the script with no corresponding variables or directories is a perpetual source of confusion.

**Problem 4d: The December 2025 incident [FACT from sherlock-pipeline-trigger-investigation.md] involved stuck ArgoCD finalizers for `alarmengine`, `assetmonitor`, `assetplanning`, `clientgateway`, `monitor`.** The same service names keep recurring in incidents. This pattern suggests these services have a fragile relationship with the deployment pipeline.

### Verdict on Challenge 4: The 3 services are harmless TODAY only because they lack directory structure. But they are evidence of systemic naming/inclusion debt that normalizes pipeline errors, making real failures harder to detect. The "boy who cried wolf" effect is a production reliability hazard.

---

## Challenge 5: Blast Radius Assessment

### Assessment: BLAST RADIUS IS LARGER THAN DIAGNOSED

**Direct impact (confirmed):**
- clientgateway DEV: tag erased, ArgoCD sync affected [FACT]
- clientgateway ACC: tag erased, ArgoCD sync affected [FACT]
- clientgateway PROD: unaffected (prod-env=false) [FACT]

**Indirect impact (needs investigation):**

**5a: What else depends on VPP-Configuration's values-override.yaml?**

VPP-Configuration is a GitOps repository. ArgoCD watches it. But:
- Are there other tools watching VPP-Configuration? (e.g., monitoring that scrapes deployed versions, dashboards, alerting on version drift)
- Does the `build 20260413.1` commit message get parsed by anything? (e.g., release tracking, audit logs)
- Are there branch protection rules or PR requirements on VPP-Configuration/main? The pipeline pushes DIRECTLY to main without PR. If branch protection was added after the pipeline was written, the push would fail.

**5b: Could other services be affected by empty clientgateway?**

If clientgateway is an API gateway (the name suggests this), it likely serves as an ingress point for other services. An empty tag causing deployment failure means:
- Frontend cannot reach backend services through clientgateway
- External integrations routing through clientgateway are broken
- Any service-to-service communication going through clientgateway is disrupted

The blast radius is not "clientgateway is broken" -- it is "everything that talks THROUGH clientgateway is broken." In a VPP (Virtual Power Plant) context, this could affect:
- Market interactions (if they route through clientgateway)
- Alarm processing
- Telemetry collection
- Frontend user access

**5c: Are there downstream pipelines triggered by VPP-Configuration commits?**

[FACT from vpp-configuration-repo.md, Section 1]: The One-For-All pipeline YAML has `trigger: - none`, meaning it is NOT auto-triggered by repo changes. But VPP-Configuration itself might have pipelines that trigger on main commits. If ArgoCD is configured with auto-sync (which is typical in GitOps), the empty tag would be deployed IMMEDIATELY upon push -- no human gate.

**5d: The `release-version.yaml` shows `acc: "false"` [FACT from acc-environment-state.md, Section 6].**

This is a separate file from the variable group flags. The variable group has `acc-env=true` [FACT], but the release-version.yaml has `acc: "false"`. These could serve different purposes (variable group controls One-For-All, release-version.yaml controls something else). But the inconsistency should be investigated -- if both control ACC deployments, which one wins?

### Verdict on Challenge 5: Blast radius extends beyond clientgateway itself to everything that routes through it. The GitOps model means damage is deployed automatically and immediately upon push. The `acc: "false"` in release-version.yaml vs `acc-env: true` in the variable group is an inconsistency that needs explanation.

---

## Challenge 6: Recurrence Prevention

### Assessment: NO STRUCTURAL PREVENTION EXISTS. THIS WILL HAPPEN AGAIN.

**The facts are damning:**
- September 2025: telemetry variable missing from variable group --> empty tag --> broken deployment [FACT]
- April 2026: clientgateway variable missing from variable group --> empty tag --> broken deployment [FACT]
- Same mechanism, same pipeline, same class of human error, 7 months apart

**The script has ZERO defensive measures against missing variables:**

1. No validation that all expected variables are present before writing files
2. No `set -e` or `set -o pipefail` to fail fast on errors
3. No pre-flight check comparing the service list against the variable group
4. No empty-value guard before writing tags (`if [ -z "$imagetag" ]; then echo "FATAL: empty tag for $serviceName"; exit 1; fi`)
5. No dry-run or diff-preview before pushing to main

**The variable group creation process (manual or automated) has no completeness validation:**

1. No checklist of required variables
2. No automation that cross-references the script's service list against the variable group
3. No ADO pipeline gate that verifies variable completeness before allowing One-For-All to run

**Structural recommendations (ordered by impact-to-effort ratio):**

### Fix 1: Empty-Tag Guard in Script (IMMEDIATE, LOW EFFORT)

Add a guard before the yq write. This prevents the DESTRUCTIVE SYMPTOM while leaving the root cause (missing variable) to be caught by other means.

```bash
imagetag=$(echo "${service#*:}")

# GUARD: Never write an empty tag
if [[ -z "$imagetag" ]]; then
  echo "ERROR: Empty image tag for $serviceName. Skipping to prevent erasure."
  continue  # Skip this service entirely
fi

if [[ -f $valuesFilePath ]]; then
  yq -i ".image.tag = \"$imagetag\"" $valuesFilePath
  echo "Updated image tag for $serviceName to $imagetag in $valuesFilePath"
fi
```

### Fix 2: Pre-Flight Variable Validation (IMMEDIATE, LOW EFFORT)

Add a validation step at the beginning of the script that checks all expected service variables are non-empty:

```bash
echo "Validating service versions..."
MISSING_VARS=()
for service in "${serviceVersions[@]}"; do
  serviceName="${service%%:*}"
  imageTag="${service#*:}"
  if [[ -z "$imageTag" || "$imageTag" == *"command not found"* ]]; then
    MISSING_VARS+=("$serviceName")
  fi
done

if [[ ${#MISSING_VARS[@]} -gt 0 ]]; then
  echo "FATAL: Missing versions for: ${MISSING_VARS[*]}"
  echo "Aborting to prevent empty tag writes."
  exit 1
fi
```

### Fix 3: Variable Group Automation (MEDIUM EFFORT)

Create a script/pipeline that generates the variable group from authoritative sources:
- Query the container registry for the latest image tags per service
- Cross-reference against the script's hardcoded service list
- Flag any services in the script that lack images
- Auto-populate the variable group

### Fix 4: Remove Hardcoded Service List (MEDIUM EFFORT)

Instead of hardcoding 21 services in the script, derive the list dynamically from:
- The Helm directory structure in VPP-Configuration (`ls Helm/`)
- The variable group contents (only process services that HAVE variables)

This eliminates the gatewaynl/alarmengine/alarmpreprocessing noise AND prevents future services from being added to the script but forgotten in the variable group.

### Fix 5: Pipeline Gate (LOW-MEDIUM EFFORT)

Add a separate pipeline step BEFORE the "Update values-override.yaml" step that:
- Reads the variable group
- Compares against expected service list
- Fails the pipeline if any expected service is missing
- Provides clear error message identifying which services lack versions

---

## SRE MANIAC VERDICT

```
SRE MANIAC VERDICT
==================
Overall Status: FIX FIRST
Confidence: HIGH (on mechanism), MEDIUM (on root cause completeness)
Critical Issues: 1 (missing empty-tag guard enables destructive writes)
High Issues: 3 (no variable validation, retry amplification, manual process without checklist)
Cascade Risks: clientgateway down --> all services routing through it affected
Recommendation: Apply immediate fix (add variable), but ALSO add empty-tag guard to script
```

### The Diagnosis Quality Assessment

| Aspect | Grade | Rationale |
|--------|-------|-----------|
| Mechanism identification | A | Exact code path traced with FACT evidence |
| Evidence quality | A | Multiple independent FACT sources (CLI output, git diff, pipeline YAML) |
| Causal completeness | C | Stops at proximate cause; WHY variable is missing is undiagnosed |
| Fix proposal | B- | Correct but carries re-run risks; no defensive measures proposed |
| Recurrence prevention | F | Zero structural prevention recommended in original diagnosis |
| Blast radius analysis | C | Identified PROD is safe, but did not assess downstream impact through clientgateway |

### Immediate Actions Required

1. **NOW**: Verify no manual hotfix commits on VPP-Configuration/main since 25d008a14
2. **NOW**: Add `clientgateway = 0.145.0` to Release-0.145 variable group
3. **BEFORE RE-RUN**: Verify 0.145.0 image exists in container registry
4. **CONSIDER**: Direct git fix (Option A from acc-environment-state.md) instead of pipeline re-run -- safer and more surgical
5. **THIS SPRINT**: Add empty-tag guard to the One-For-All script (Fix 1 above)
6. **THIS SPRINT**: Add pre-flight variable validation (Fix 2 above)
7. **THIS QUARTER**: Investigate and document the variable group creation process; automate it (Fix 3)

### Murphy's Law Final Assessment

```
MURPHY ASSESSMENT (One-For-All Pipeline):
+-- Network: Push to VPP-Configuration/main fails (non-ff) --> retry 7x [DANGEROUS]
+-- Disk: N/A (ADO hosted agent)
+-- Database: N/A
+-- Memory: N/A
+-- CPU: N/A
+-- Concurrent: Two manual runs of One-For-All simultaneously --> git push conflict
|   --> retry 7x each = 14 potential commits [DANGEROUS]
+-- Variables: Any undefined variable --> bash command substitution --> empty tag
|   --> destructive overwrite of existing good tag [CRITICAL]
+-- Retry: retryCountOnTaskFailure=7 --> bug is executed up to 8 times total [AMPLIFIER]
+-- Observability: Pipeline reports "succeeded" despite writing empty tags [CRITICAL GAP]
+-- Human: Manual trigger without pre-validation --> same bug every release [PROVEN PATTERN]
+-- VERDICT: FRAGILE -- happy-path-only design with retry amplification
```

**The One-For-All pipeline is a denial-of-service attack on your own deployment infrastructure.** It writes destructive changes without validation, reports success despite errors, retries failures 7 times, and depends entirely on human diligence to ensure correctness. The September 2025 telemetry incident proved this. The April 2026 clientgateway incident proved it again. Without structural fixes, the question is not IF this happens again, but WHICH service and WHEN.

Hope is not a strategy. Fix the guard rails.
