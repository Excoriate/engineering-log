---
task_id: 2026-04-13-001
agent: coordinator
status: draft
summary: Phase 4 complete investigation findings — root cause identified with FACT evidence
---

# Phase 4 Investigation Findings

## Root Cause: Missing `clientgateway` variable in ADO Release-0.145 variable group

### Evidence Chain (ALL FACTS — from CLI output and file reads)

1. **[FACT]** Release-0.145 variable group (ID 5262) does NOT contain `clientgateway` variable
   - Source: `az pipelines variable-group show --id 5262` output
   - All other services present (activationmfrr, asset, etc.)

2. **[FACT]** Release-0.144 variable group (ID 5242) DOES contain `clientgateway = 0.144.0`
   - Source: `az pipelines variable-group show --id 5242` output

3. **[FACT]** One-For-All pipeline (YAML at `azure-pipeline/pipelines/oneforallmsv2.yaml`) references:
   - `group: Release-${{variables['Build.SourceBranchName']}}` (line 5)
   - `"clientgateway:$(clientgateway)"` (line 44)
   - Source: Read of YAML file

4. **[FACT]** When `$(clientgateway)` is undefined, ADO leaves literal `$(clientgateway)` in bash script
   - Bash interprets `$(clientgateway)` as command substitution → "clientgateway: command not found" (stderr)
   - Command output = empty string → version = ""
   - Source: Pipeline log screenshot (line 17)

5. **[FACT]** The script writes empty version: `yq -i ".image.tag = \"$imagetag\""` (line 82)
   - ACC: `0.144.0` → `""` (git diff confirmed)
   - DEV: `0.145.0` → `""` (git diff confirmed)

6. **[FACT]** Damage is LIVE on origin/main: both dev and acc values-override.yaml show `tag: ""`
   - Source: `git show origin/main:Helm/clientgateway/{dev,acc}/values-override.yaml`

7. **[FACT]** PROD is NOT affected: `prod-env = false` in Release-0.145 variable group
   - Source: variable group output

### Mechanism (causal chain)

```
Release-0.145 variable group created WITHOUT clientgateway entry
    ↓
One-For-All pipeline runs on branch release/0.145
    ↓
ADO expands $(clientgateway) → literal (undefined variable, no expansion)
    ↓
Bash receives "clientgateway:$(clientgateway)" in double quotes
    ↓
$(clientgateway) = bash command substitution → "clientgateway: command not found"
    ↓
Command output captured as empty string → version = ""
    ↓
Script writes tag: "" to Helm/clientgateway/{dev,acc}/values-override.yaml
    ↓
ArgoCD syncs VPP-Configuration → sees empty tag → sync fails
    ↓
ClientGateway service broken in DEV and ACC environments
```

### Differential Analysis: Other 3 "command not found" services

| Service | In Release-0.144 | In Release-0.145 | Has dev/acc Helm dirs | Impact |
|---------|------------------|-------------------|-----------------------|--------|
| clientgateway | YES (0.144.0) | **NO** | YES | **DESTRUCTIVE** |
| gatewaynl | NO | NO | NO Helm dir exists | Harmless noise |
| alarmengine | NO | NO | sandbox only | Harmless noise |
| alarmpreprocessing | NO | NO | sandbox only | Harmless noise |

The other 3 are pre-existing — they've never been in release variable groups. They produce "command not found" errors but the script's `if [[ -f $valuesFilePath ]]` check (line 80) skips them because they have no dev/acc Helm directories.

### Historical Precedent
September 1, 2025: Identical pattern with `telemetry` service. Roel van de Grint diagnosed and fixed it same day by restoring the missing variable in the ADO variable group and re-running One-For-All.

### Hypothesis Status
- **H1 (ADO Variable Group Missing Entry)**: CONFIRMED [FACT]
- **H2 (Code Regression)**: ELIMINATED — no code change in ClientGateway, script is correct
- **H3 (Environment Drift)**: ELIMINATED — environment is fine, it's a CI/CD data issue
