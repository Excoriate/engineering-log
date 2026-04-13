---
task_id: "2026-04-13-001"
agent: coordinator
status: complete
summary: "VPP-Configuration repo investigation: pipeline YAML, bash script, Helm structure, commit diff, variable group analysis"
---

# VPP-Configuration Repository Investigation

## Access Method
- Local clone at `/Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src/enecomanagedcloud/myriad-vpp/VPP-Configuration` (stale, Nov 2025)
- SSH fetch failed (key mismatch). Used `az devops` CLI (authenticated) for all remote queries.

---

## 1. Pipeline YAML — One-For-All (Definition 1811)

**Location**: `azure-pipeline/pipelines/oneforallmsv2.yaml` in the **Myriad - VPP** repo (NOT VPP-Configuration)
**Repo ID**: `55cd6176-e0fb-4288-a901-aeb48946a643`

```yaml
trigger:
  - none

variables:
  - group: Release-${{variables['Build.SourceBranchName']}}
  - group: build

resources:
  repositories:
    - repository: configurationRepository
      type: git
      name: VPP-Configuration
      ref: refs/heads/main

pool:
  vmImage: ubuntu-latest

steps:
  - checkout: configurationRepository
    fetchDepth: 0
    persistCredentials: true

  - task: Bash@3
    retryCountOnTaskFailure: "7"
    displayName: Update values-override.yaml
    condition: startsWith(variables['Build.SourceBranch'], 'refs/heads/release/')
    inputs:
      targetType: "inline"
      workingDirectory: $(System.DefaultWorkingDirectory)/
      script: |
        git config --local user.email azurepipeline@eneco-myriad.com
        git config --local user.name "azurepipelines"

        # checkout and pull with fast-forward are in place in case this pipeline step is retried.
        git checkout main
        git pull --ff

        echo "Branch is $(Build.SourceBranch)"
        echo "Setting service versions"
        serviceVersions=( "activationmfrr:$(activationmfrr)"
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
                          "espmessageconsumer:$(espmessageconsumer)"
                          "espmessageproducer:$(espmessageproducer)"
                          "frontend:$(frontend)"
                          "marketinteraction:$(marketinteraction)"
                          "telemetry:$(telemetry)"
                          "integration-tests:$(integration-tests)"
                          "monitor:$(monitor)"
                          "gatewaynl:$(gatewaynl)"
                          "alarmengine:$(alarmengine)"
                          "alarmpreprocessing:$(alarmpreprocessing)"
                        )
        for service in "${serviceVersions[@]}";
        do
          serviceName="${service%%:*}"
          echo "Service name is $serviceName"
          dev=$(test-env)
          acc=$(acc-env)
          prod=$(prod-env)
          for env in dev acc prod;
          do
            if [[ "${!env}" == "true" ]];
            then
              # Update the image tag in values.yaml
              valuesFilePath="Helm/$serviceName/$env/values-override.yaml"
              echo "valuesFilePath is $valuesFilePath"

              imagetag=$(echo "${service#*:}")

              # Only update if the path exists
              if [[ -f $valuesFilePath ]]; 
              then
                yq -i ".image.tag = \"$imagetag\"" $valuesFilePath
                echo "Updated image tag for $serviceName to $imagetag in $valuesFilePath"
              else
                echo "File not found: $valuesFilePath. Skipping update."
              fi
            fi
          done
        done

        git add .

        if [[ -z $(git status -s) ]]
        then
          echo "Nothing to commit, exiting"
        else
          git commit -m "build $(Build.BuildNumber) $imagetag"
        fi

        git push origin HEAD:main
```

---

## 2. Root Cause Analysis of "command not found" Errors

### The Mechanism

The script uses Azure DevOps macro syntax `$(variable)` for pipeline variable expansion. Azure DevOps expands these BEFORE bash executes. However, when a variable is **NOT DEFINED** in the variable group, Azure DevOps leaves the literal `$(variable)` text in place. Bash then interprets `$(variable)` as **command substitution** and tries to execute the variable name as a shell command.

### Release-0.145 Variable Group (ID: 5262) — Variables Defined

| Variable | Value | Notes |
|----------|-------|-------|
| `a_placeholder` | `delete_me` | |
| `acc-env` | `true` | ACC environment enabled |
| `activationmfrr` | `0.145.0` | |
| `asset` | `0.145.0` | |
| `assetmonitor` | `0.145.1` | Higher patch |
| `assetplanning` | `0.145.0` | |
| `dataprep` | `0.145.0` | |
| `dispatcherafrr` | `0.145.0` | |
| `dispatchermanual` | `0.145.0` | |
| `dispatchermfrr` | `0.145.0` | |
| `dispatcherscheduled` | `0.145.0` | |
| `dispatchersimulator` | `0.145.0` | |
| `espmessageconsumer` | `0.145.0` | |
| `espmessageproducer` | `0.145.0` | |
| `frontend` | `0.145.0` | |
| `integration-tests` | `0.145.0` | |
| `marketinteraction` | `0.145.0` | |
| `monitor` | `0.145.0` | |
| `prod-env` | `false` | PROD not enabled |
| `telemetry` | `0.145.0` | |
| `tenant-gateway` | `0.145.0` | NOTE: different name than script |
| `test-env` | `true` | DEV environment enabled |

### Variables MISSING from the Variable Group (Root Cause)

| Pipeline Script References | Variable Group Has | Result |
|---|---|---|
| `$(clientgateway)` | **MISSING** | "clientgateway: command not found" |
| `$(gatewaynl)` | **MISSING** (has `tenant-gateway` instead) | "gatewaynl: command not found" |
| `$(alarmengine)` | **MISSING** | "alarmengine: command not found" |
| `$(alarmpreprocessing)` | **MISSING** | "alarmpreprocessing: command not found" |

### Why the Build Still "Succeeded"

1. The bash script does NOT use `set -e` (errexit), so "command not found" errors are non-fatal
2. The `retryCountOnTaskFailure: "7"` means the task retries on failure, but the errors occur within the script without causing a non-zero exit code
3. The `if [[ -f $valuesFilePath ]]` check handles missing Helm directories gracefully (prints "File not found" and skips)

### Damage Done by the Pipeline

Despite the "command not found" errors, the script still proceeded and wrote **empty image tags** for clientgateway:

| File | Before (parent `70cb6543`) | After (commit `25d008a`) | Impact |
|------|---------------------------|-------------------------|--------|
| `Helm/clientgateway/dev/values-override.yaml` | `image.tag: "0.145.0"` | `image.tag: ""` | **REGRESSED to empty** |
| `Helm/clientgateway/acc/values-override.yaml` | `image.tag: "0.144.0"` | `image.tag: ""` | **REGRESSED to empty** |
| `Helm/clientgateway/prod/values-override.yaml` | `image.tag: "0.144.0"` | `image.tag: "0.144.0"` | No change (prod-env=false) |

The succeeded services show NO changes because they already had 0.145.0:

| File | Before | After |
|------|--------|-------|
| `Helm/activationmfrr/dev/values-override.yaml` | `0.145.0` | `0.145.0` (no-op) |
| `Helm/asset/dev/values-override.yaml` | `0.145.0` | `0.145.0` (no-op) |
| `Helm/assetmonitor/dev/values-override.yaml` | `0.145.1` | `0.145.1` (no-op) |

---

## 3. Helm Directory Structure — clientgateway

```
Helm/clientgateway/
  acc/
    values-override.yaml    (image.tag: "" -- BROKEN)
    values.yaml
  dev/
    values-override.yaml    (image.tag: "" -- BROKEN)
    values.yaml
  prod/
    values-override.yaml    (image.tag: "0.144.0" -- OK, prod-env=false)
    values.yaml
  sandbox/
    values-override.yaml
    values.yaml
```

### Helm Directory State for Other Failing Services

| Service | Helm Dirs | Issue |
|---------|-----------|-------|
| `clientgateway` | `dev/`, `acc/`, `prod/`, `sandbox/` | Dirs exist but var missing from group |
| `gatewaynl` | **NONE** (no `/Helm/gatewaynl/` directory exists) | Name mismatch: script says `gatewaynl`, Helm dir is `tenant-gateway` |
| `alarmengine` | `sandbox/` only | No `dev/`, `acc/`, `prod/` dirs |
| `alarmpreprocessing` | `sandbox/` only | No `dev/`, `acc/`, `prod/` dirs |

---

## 4. Commit Diff — `25d008a143a240d7b254582c803a9a096237bd11`

**Commit message**: `build 20260413.1`
**Author**: `azurepipelines <azurepipeline@eneco-myriad.com>`
**Date**: `2026-04-13T07:34:17Z`
**Parent**: `70cb6543d85887bad944cb4ca070be8af147be1d`
**Pushed by**: Myriad - VPP Build Service

**Changes confirmed**:
- `Helm/clientgateway/dev/values-override.yaml`: `0.145.0` -> `""` (REGRESSION)
- `Helm/clientgateway/acc/values-override.yaml`: `0.144.0` -> `""` (REGRESSION)

Note: clientgateway is the ONLY service with existing `dev/` and `acc/` directories whose variable was missing. For `gatewaynl`, `alarmengine`, and `alarmpreprocessing`, the missing files/dirs meant the `-f` check skipped them (no file damage, but no update either).

---

## 5. Build 1605902 Details

| Field | Value |
|-------|-------|
| Build Number | `20260413.1` |
| Status | `completed` |
| Result | `succeeded` |
| Source Branch | `refs/heads/release/0.145` |
| Start Time | `2026-04-13T07:34:08Z` |
| Finish Time | `2026-04-13T07:34:22Z` |
| Triggered By | Diachenko, AV (Artem) |
| Trigger Reason | manual |
| Variable Group | `Release-0.145` (ID: 5262) |

---

## 6. Summary of Findings

### Primary Root Cause
The `Release-0.145` variable group is missing 4 variables (`clientgateway`, `gatewaynl`, `alarmengine`, `alarmpreprocessing`). When Azure DevOps cannot expand `$(clientgateway)`, it leaves the literal `$(clientgateway)` in the bash script, which bash interprets as command substitution, producing "command not found".

### Secondary Issue — Name Mismatch
The pipeline script references `gatewaynl`, but the variable group defines `tenant-gateway` and the Helm directory is `/Helm/tenant-gateway/`. This is a permanent naming inconsistency.

### Tertiary Issue — Missing `set -e`
The bash script does not use `set -e`, allowing "command not found" errors to be silently swallowed. The build reports "succeeded" despite data corruption (empty image tags written to clientgateway's values files).

### Immediate Impact
- **clientgateway dev**: Image tag regressed from `0.145.0` to `""` (empty)
- **clientgateway acc**: Image tag regressed from `0.144.0` to `""` (empty)
- ArgoCD will attempt to deploy with an empty image tag, which will either fail to pull or pull `latest` depending on the Helm chart's default behavior
