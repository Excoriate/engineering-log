# One-For-All Pipeline: Architecture, Mechanism & Improvement Design

**Author**: Alex Torres (on-call investigation, 2026-04-13)
**Context**: Post-incident analysis of the ClientGateway empty-tag failure
**Purpose**: Understand how the pipeline works end-to-end, where it's fragile, and how to harden it

---

## 1. What One-For-All Does

One-For-All is the **release deployment orchestrator** for VPP Core services. It takes version numbers from an ADO variable group and writes them as image tags into VPP-Configuration's Helm values-override.yaml files. ArgoCD watches those files and deploys accordingly.

In one sentence: **it's a variable-to-gitops bridge** — it translates "which version should each service run?" (stored in ADO) into "what does ArgoCD deploy?" (stored in git).

---

## 2. Architecture

```
                         ┌─────────────────────────────────────────┐
                         │        AZURE DEVOPS                      │
                         │                                          │
  ┌─────────────┐        │   ┌─────────────────────────────┐        │
  │ Individual   │        │   │  ADO Variable Group          │        │
  │ Service CI   │───────▶│   │  "Release-0.145"             │        │
  │ Pipelines    │ build  │   │                              │        │
  │              │ output  │   │  activationmfrr = 0.145.0   │        │
  │ clientgw CI  │───?───▶│   │  asset = 0.145.0             │        │
  │ asset CI     │        │   │  clientgateway = ???          │        │
  │ frontend CI  │        │   │  frontend = 0.145.0          │        │
  │ ...          │        │   │  ...                          │        │
  └─────────────┘        │   │  test-env = true              │        │
                         │   │  acc-env = true               │        │
                         │   │  prod-env = false             │        │
                         │   └──────────┬──────────────────┘        │
                         │              │                            │
                         │              │ $(variable) macro expansion│
                         │              ▼                            │
                         │   ┌─────────────────────────────┐        │
                         │   │  One-For-All Pipeline        │        │
                         │   │  (Definition 1811)           │        │
                         │   │                              │        │
                         │   │  YAML:                       │        │
                         │   │  group: Release-$(branch)    │        │
                         │   │                              │        │
                         │   │  Inline bash script:         │        │
                         │   │  1. Checkout VPP-Config      │        │
                         │   │  2. Build service:version    │        │
                         │   │     array from $(variables)  │        │
                         │   │  3. For each service+env:    │        │
                         │   │     yq write image.tag       │        │
                         │   │  4. git commit + push        │        │
                         │   └──────────┬──────────────────┘        │
                         │              │                            │
                         └──────────────┼────────────────────────────┘
                                        │ git push origin HEAD:main
                                        ▼
                         ┌─────────────────────────────────┐
                         │  VPP-Configuration Repo          │
                         │  (Git, branch: main)             │
                         │                                  │
                         │  Helm/                           │
                         │    clientgateway/                │
                         │      acc/values-override.yaml    │◄─── image.tag: "0.145.0"
                         │      dev/values-override.yaml    │◄─── image.tag: "0.145.0"
                         │      prod/values-override.yaml   │
                         │    asset/                        │
                         │      acc/values-override.yaml    │◄─── image.tag: "0.145.0"
                         │      ...                         │
                         └──────────┬──────────────────────┘
                                    │ ArgoCD watches main
                                    ▼
                         ┌─────────────────────────────────┐
                         │  ArgoCD                          │
                         │                                  │
                         │  Detects change in values-       │
                         │  override.yaml → syncs to AKS   │
                         │  → deploys new image version     │
                         └─────────────────────────────────┘
```

---

## 3. How ADO Variables Are Fetched (The Critical Mechanism)

### 3.1 Variable Group Linkage

The pipeline YAML dynamically selects which variable group to use:

```yaml
variables:
  - group: Release-${{variables['Build.SourceBranchName']}}
  - group: build
```

When the pipeline runs on branch `release/0.145`:
- `${{variables['Build.SourceBranchName']}}` = `0.145`
- Resolves to: `group: Release-0.145`
- ADO loads all variables from this group into the pipeline scope

### 3.2 Macro Expansion (Before Bash Runs)

ADO uses `$(variableName)` as **macro syntax**. Before the bash script is even written to disk, ADO performs text replacement:

```
YAML source:          "clientgateway:$(clientgateway)"
                                          │
                            ADO macro expansion
                                          │
                      ┌───────────────────┴───────────────────┐
                      │                                       │
              Variable EXISTS                         Variable MISSING
              in group                                from group
                      │                                       │
                      ▼                                       ▼
    Bash receives:                              Bash receives:
    "clientgateway:0.145.0"                     "clientgateway:$(clientgateway)"
              │                                               │
              ▼                                               ▼
    Parsed as string:                           Bash sees $(clientgateway)
    service=clientgateway                       as COMMAND SUBSTITUTION
    version=0.145.0                             Tries to execute 'clientgateway'
              │                                               │
              ▼                                               ▼
    yq writes tag: "0.145.0" ✅                 "command not found" on stderr
                                                Output captured = "" (empty)
                                                version = ""
                                                yq writes tag: "" ❌
```

**This is the fundamental design flaw**: ADO's `$(var)` syntax is identical to bash's `$(cmd)` command substitution syntax. When ADO can't expand a variable, it leaves the literal `$(var)` in the script, and bash interprets it as "execute this command."

### 3.3 The Full Script Flow

```
oneforallmsv2.yaml (lines 30-100):
│
├── git checkout main; git pull --ff
│   └── Gets latest VPP-Configuration
│
├── Build serviceVersions array (lines 40-61)
│   ├── "activationmfrr:$(activationmfrr)"  →  "activationmfrr:0.145.0"  ✅
│   ├── "clientgateway:$(clientgateway)"     →  "clientgateway:"           ❌ empty!
│   ├── "gatewaynl:$(gatewaynl)"            →  "gatewaynl:"               ❌ noise
│   └── ... (21 services total)
│
├── For each service in array (lines 62-89):
│   ├── Extract serviceName and imagetag
│   ├── For each env (dev, acc, prod):
│   │   ├── Check if env flag is "true" (test-env, acc-env, prod-env)
│   │   ├── Check if Helm/{service}/{env}/values-override.yaml exists
│   │   └── yq write image.tag = "$imagetag"
│   └── (No validation that imagetag is non-empty!)
│
├── git add . ; git commit ; git push
│   └── Pushes ALL changes (correct + broken) in one commit
│
└── retryCountOnTaskFailure: 7
    └── If push fails (race condition), retry everything from top
```

### 3.4 Environment Gating

The variable group contains environment flags:

| Flag | Value | Effect |
|------|-------|--------|
| `test-env` | `true`/`false` | Controls whether DEV values are updated |
| `acc-env` | `true`/`false` | Controls whether ACC values are updated |
| `prod-env` | `true`/`false` | Controls whether PROD values are updated |

These flags use the same `$(flag)` expansion, so the same ADO→bash vulnerability applies. If `acc-env` were ever missing from the group, `$(acc-env)` in bash would try to execute `acc` with flag `-env` — silently failing and resulting in no environment updates (actually the safer failure mode).

---

## 4. Where It's Fragile (Failure Catalog)

```
╔═══════════════════════════════════════════════════════════════════════╗
║                    FRAGILITY MAP                                      ║
║                                                                       ║
║  ┌─────────────────────┐    ┌─────────────────────┐                  ║
║  │ Variable Group       │    │ Script Logic         │                  ║
║  │                      │    │                      │                  ║
║  │ F1: Manual creation  │    │ F4: No empty-tag     │                  ║
║  │   (human can omit    │    │   guard (writes ""   │                  ║
║  │   any service)       │    │   to YAML)           │                  ║
║  │                      │    │                      │                  ║
║  │ F2: No completeness  │    │ F5: No set -e        │                  ║
║  │   validation (no     │    │   (errors swallowed,  │                  ║
║  │   check all svc      │    │   pipeline succeeds)  │                  ║
║  │   present)           │    │                      │                  ║
║  │                      │    │ F6: Hardcoded 21-svc │                  ║
║  │ F3: Stale versions   │    │   list includes 3    │                  ║
║  │   (group not updated │    │   that always fail   │                  ║
║  │   after hotfixes)    │    │   (noise normalizes  │                  ║
║  │                      │    │   errors)            │                  ║
║  └─────────────────────┘    └─────────────────────┘                  ║
║                                                                       ║
║  ┌─────────────────────┐    ┌─────────────────────┐                  ║
║  │ Git Operations       │    │ Observability        │                  ║
║  │                      │    │                      │                  ║
║  │ F7: Race condition   │    │ F9: Commit message   │                  ║
║  │   (pull → work →     │    │   only records last  │                  ║
║  │   push with no lock) │    │   service's tag      │                  ║
║  │                      │    │                      │                  ║
║  │ F8: 7 retries        │    │ F10: Pipeline status │                  ║
║  │   amplify any bug    │    │   = "succeeded" even │                  ║
║  │   (destructive write │    │   with 4 errors      │                  ║
║  │   repeated 7x)       │    │                      │                  ║
║  └─────────────────────┘    └─────────────────────┘                  ║
║                                                                       ║
║  Incident history:                                                    ║
║  Sep 2025: telemetry missing → F1+F4+F5 → empty tag → ArgoCD fail   ║
║  Apr 2026: clientgateway missing → F1+F4+F5 → empty tag → ArgoCD fail║
║  Next: ??? → same chain → same outcome                               ║
╚═══════════════════════════════════════════════════════════════════════╝
```

---

## 5. Improvement Design

### Improvement 1: Empty-Tag Guard (IMMEDIATE — 5 lines)

**Problem**: F4 — script writes `tag: ""` without checking.
**Fix**: Add guard before the `yq` write.

```bash
# CURRENT (line 77-83 of oneforallmsv2.yaml):
imagetag=$(echo "${service#*:}")
if [[ -f $valuesFilePath ]]; then
  yq -i ".image.tag = \"$imagetag\"" $valuesFilePath
  echo "Updated image tag for $serviceName to $imagetag in $valuesFilePath"
fi

# PROPOSED:
imagetag=$(echo "${service#*:}")
if [[ -z "$imagetag" ]]; then
  echo "WARNING: Empty image tag for $serviceName — SKIPPING to prevent tag erasure"
  continue
fi
if [[ -f $valuesFilePath ]]; then
  yq -i ".image.tag = \"$imagetag\"" $valuesFilePath
  echo "Updated image tag for $serviceName to $imagetag in $valuesFilePath"
fi
```

**Effect**: Converts destructive failure (empty tag written) into safe skip (existing tag preserved).
**Effort**: 5-minute PR to `Myriad - VPP` repo.
**Risk**: Zero — only changes behavior when version is empty, which is always wrong.

---

### Improvement 2: Pre-Flight Variable Validation (SHORT-TERM — 20 lines)

**Problem**: F2 — no check that all services have variables before writing.
**Fix**: Add a validation pass before the write loop.

```bash
# Add BEFORE the service processing loop:
echo "=== Pre-flight: Validating service versions ==="
MISSING=()
for service in "${serviceVersions[@]}"; do
  svcName="${service%%:*}"
  svcTag="${service#*:}"
  if [[ -z "$svcTag" ]]; then
    MISSING+=("$svcName")
  fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "FATAL: Missing versions for: ${MISSING[*]}"
  echo "These services have no version in the Release variable group."
  echo "Fix the variable group and re-run. Aborting to prevent empty tag writes."
  exit 1
fi
echo "All services have versions. Proceeding."
```

**Effect**: Pipeline FAILS FAST with a clear error message instead of silently corrupting values.
**Effort**: 30-minute PR.
**Risk**: Low — may cause pipeline to fail for the 3 noise services (gatewaynl, alarmengine, alarmpreprocessing). Fix by removing them from the array or adding them to an "optional" list.

---

### Improvement 3: Clean Up the Service List (SHORT-TERM — 10 min)

**Problem**: F6 — 3 services in the array that always fail, normalizing errors.
**Fix**: Remove or separate them.

```bash
# CURRENT: 21 services, 3 always fail
# PROPOSED: Split into required (validated) and optional (skip if missing)

requiredServices=( "activationmfrr:$(activationmfrr)"
                   "asset:$(asset)"
                   "assetmonitor:$(assetmonitor)"
                   "assetplanning:$(assetplanning)"
                   "clientgateway:$(clientgateway)"
                   "dataprep:$(dataprep)"
                   "dispatcherafrr:$(dispatcherafrr)"
                   "dispatchermanual:$(dispatchermanual)"
                   "dispatchermfrr:$(dispatchermfrr)"
                   "dispatcherscheduled:$(dispatcherscheduled)"
                   "dispatchersimulator:$(dispatchersimulator)"
                   "frontend:$(frontend)"
                   "marketinteraction:$(marketinteraction)"
                   "telemetry:$(telemetry)"
                   "integration-tests:$(integration-tests)"
                   "monitor:$(monitor)"
                 )

# These are sandbox-only or have naming mismatches — skip silently
optionalServices=( "gatewaynl:$(gatewaynl)"
                   "alarmengine:$(alarmengine)"
                   "alarmpreprocessing:$(alarmpreprocessing)"
                 )
```

**Effect**: Pipeline logs become clean — only real errors show up. No more "boy who cried wolf."
**Effort**: 10-minute PR alongside Improvement 2.

---

### Improvement 4: Dynamic Service List from Helm Structure (MEDIUM-TERM)

**Problem**: F6 — hardcoded service list drifts from actual Helm directory structure.
**Fix**: Derive the service list from the Helm directories themselves.

```bash
# Instead of hardcoding, discover services from the repo:
echo "Discovering services from Helm directory..."
for svcDir in Helm/*/; do
  svcName=$(basename "$svcDir")
  # Skip non-service directories
  [[ "$svcName" == "grafana-dashboards" || "$svcName" == "ocp-prometheus-alerting" ]] && continue
  [[ "$svcName" == "opentelemetry-monitoring" || "$svcName" == "secretprovider" ]] && continue
  [[ "$svcName" == "opstools" || "$svcName" == "watchdog" ]] && continue
  [[ "$svcName" == "vpp-core-app-of-apps"* ]] && continue

  # Check if this service has a variable in the group
  varName="$svcName"
  varValue="${!varName:-}"  # Indirect variable reference

  if [[ -z "$varValue" ]]; then
    echo "WARNING: No version variable for $svcName"
    continue
  fi

  # Process this service
  for env in dev acc prod; do
    # ...existing logic...
  done
done
```

**Effect**: No more drift between service list and reality. New services auto-discovered. Removed services auto-ignored.
**Effort**: ~2 hours. Requires careful testing.
**Risk**: Medium — indirect variable reference (`${!varName}`) has different behavior than `$(varName)` ADO macro. Would need to redesign how variables are passed to the script (e.g., via a JSON file or environment variable prefix).

---

### Improvement 5: Variable Group Automation (MEDIUM-TERM)

**Problem**: F1, F3 — manual variable group creation is error-prone and gets stale.
**Fix**: Automate variable group population from CI build outputs.

**Option A**: Each service CI pipeline adds its version to the release variable group on successful build:
```bash
# In each service's CD pipeline, after successful build:
az pipelines variable-group variable create \
  --group-id $RELEASE_GROUP_ID \
  --name "$(serviceName)" \
  --value "$(Build.BuildNumber)" \
  --org $ORG --project "$PROJECT"
```

**Option B**: A "Release Preparation" pipeline that:
1. Creates the Release-X.Y variable group
2. For each service, queries the CD pipeline for the latest successful build on the release branch
3. Populates the variable group from those build outputs
4. Validates completeness against the expected service list
5. Only THEN triggers One-For-All

**Effect**: Human removed from the critical path. Variables always populated correctly.
**Effort**: 1-2 days.

---

### Improvement 6: Commit Safety (MEDIUM-TERM)

**Problem**: F7, F8, F9 — race conditions, retry amplification, misleading commits.
**Fix**: Multiple changes to the git operations.

```bash
# 1. Better commit message (include ALL changed services)
CHANGED_SERVICES=$(git diff --name-only | grep values-override | sed 's|Helm/||;s|/.*||' | sort -u | tr '\n' ', ')
git commit -m "release $(Build.BuildNumber): update ${CHANGED_SERVICES}"

# 2. Reduce retry count (7 is excessive)
retryCountOnTaskFailure: "2"   # Down from 7

# 3. Add git push conflict detection
if ! git push origin HEAD:main 2>&1; then
  echo "PUSH FAILED — likely concurrent modification. Will retry after pull."
  # Don't retry the entire script — just pull and push
  git pull --rebase origin main
  git push origin HEAD:main
fi
```

---

### Improvement 7: GitOps Validation Gate (LONG-TERM)

**Problem**: No validation that committed values are correct before ArgoCD deploys.
**Fix**: Add a CI check on VPP-Configuration that validates values-override.yaml files.

```yaml
# New pipeline on VPP-Configuration, triggered on main commits:
trigger:
  branches:
    include: [main]
  paths:
    include: [Helm/*/values-override.yaml]

steps:
  - script: |
      echo "Validating Helm values-override.yaml files..."
      ERRORS=0
      for f in Helm/*/acc/values-override.yaml Helm/*/dev/values-override.yaml; do
        tag=$(yq '.image.tag' "$f")
        svc=$(echo "$f" | cut -d/ -f2)
        if [[ -z "$tag" || "$tag" == "null" || "$tag" == '""' ]]; then
          echo "ERROR: Empty image tag in $f"
          ERRORS=$((ERRORS + 1))
        fi
      done
      if [[ $ERRORS -gt 0 ]]; then
        echo "BLOCKING: $ERRORS empty tags detected. This commit should not be deployed."
        exit 1
      fi
    displayName: Validate image tags
```

**Effect**: Empty tags are caught BEFORE ArgoCD deploys them.
**Effort**: 1-2 hours.

---

## 6. Improvement Prioritization

| # | Improvement | Effort | Impact | Risk | Priority |
|---|-------------|--------|--------|------|----------|
| 1 | Empty-tag guard | 5 min | **Prevents destructive writes** | Zero | **P0 — do now** |
| 2 | Pre-flight validation | 30 min | **Pipeline fails fast with clear message** | Low | **P0 — do now** |
| 3 | Clean up service list | 10 min | Eliminates noise, clearer logs | Zero | P1 — this sprint |
| 7 | GitOps validation gate | 1-2 hrs | **Last line of defense** before ArgoCD | Low | P1 — this sprint |
| 6 | Commit safety | 1-2 hrs | Reduces retry/race risk | Low | P2 — next sprint |
| 5 | Variable group automation | 1-2 days | **Removes human from critical path** | Medium | P2 — next sprint |
| 4 | Dynamic service list | 2 hrs | Eliminates drift | Medium | P3 — backlog |

**Minimum viable fix**: Improvements 1 + 2 (35 minutes total) eliminate both the destructive symptom AND provide a clear error message. This should be done before the next release.

---

## 7. What Success Looks Like

```
BEFORE (current state):
  Missing variable → silent empty-tag write → ArgoCD fails → on-call paged →
  hours of investigation → manual variable fix → repeat next release

AFTER (with improvements 1+2+7):
  Missing variable → pipeline FAILS FAST → clear error: "Missing version for
  clientgateway in Release-0.146" → engineer adds variable → re-runs →
  GitOps gate validates tags are non-empty → ArgoCD deploys correct versions

  Time to resolution: minutes instead of hours
  Recurring incidents: zero (structural prevention, not tribal knowledge)
```
