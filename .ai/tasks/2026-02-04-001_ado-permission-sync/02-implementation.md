---
task_id: 2026-02-04-001
agent: bash-shell-script-developer
timestamp: 2026-02-04T10:47:00Z
status: complete

summary: |
  Production-grade bash script implementation for Azure DevOps team membership
  synchronization. Follows architecture design with strict exit code preservation,
  input validation, dry-run default safety, and comprehensive error handling.
  ShellCheck clean at warning severity.

key_findings:
  - finding_1: Script uses `local var; var=$(cmd)` pattern throughout to preserve exit codes
  - finding_2: Manual argument parsing for macOS portability (no GNU getopt dependency)
  - finding_3: Project name regex escaping handles brackets in names like "[Myriad - VPP]"
  - finding_4: Dry-run is default - requires explicit --apply flag for changes
---

# ADO Permission Sync - Implementation Documentation

## 1. Script Location

```
/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/log/employer/eneco/scripts/ado-sync-permissions.sh
```

## 2. Implementation Summary

| Aspect | Implementation |
|--------|----------------|
| Lines of Code | ~700 |
| ShellCheck | Clean at warning severity |
| Bash Version | Requires 4.0+ (associative arrays) |
| Dependencies | az CLI, jq, azure-devops extension |
| Default Mode | Dry-run (safe) |
| Output Modes | Human-readable (default), JSON (--json) |

**macOS Note**: macOS ships with bash 3.2. Install bash 4+ via Homebrew:

```bash
brew install bash
# Then run with:
/opt/homebrew/bin/bash ado-sync-permissions.sh --help
```

The script includes a version check and will error gracefully if run with bash 3.x.

## 3. Exit Code Taxonomy

| Code | Meaning | Example Trigger |
|------|---------|-----------------|
| 0 | Success | All operations completed (including dry-run) |
| 1 | User error | Missing --project, invalid email format |
| 2 | Missing prerequisite | jq not found, az CLI missing |
| 3 | Authentication error | Not logged in to Azure |
| 4 | User not found | Model or target user doesn't exist |
| 5 | API error | Azure DevOps API failure |
| 6 | Partial failure | Some teams added, some failed |

## 4. Key Implementation Patterns

### 4.1 Exit Code Preservation (CRITICAL)

The script uses the `local var; var=$(cmd)` pattern throughout to prevent masking exit codes:

```bash
# CORRECT (used throughout):
local output
output=$("$AZ_CMD" devops user show --user "$email" -o json 2>&1)
exit_code=$?

# WRONG (avoided):
local output=$("$AZ_CMD" devops user show --user "$email" -o json 2>&1)
# $? would be 0 from 'local', not from 'az'
```

### 4.2 Project Name Regex Escaping

For project names with brackets like `[Myriad - VPP]`, the script escapes brackets for jq regex:

```bash
# Escape brackets for jq regex
escaped_project=$(printf '%s' "$project" | sed 's/[][]/\\&/g')

# jq filter with escaped project
"$JQ_CMD" -r --arg proj "\\[$escaped_project\\]\\\\" '
    to_entries[]
    | select(.value.principalName | test($proj; "i"))
    | "\(.key)|\(.value.displayName)"
' <<< "$output"
```

### 4.3 Input Validation

Email validation prevents command injection:

```bash
validate_email() {
    local email="$1"
    local email_regex='^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'

    if [[ ! "$email" =~ $email_regex ]]; then
        return 1
    fi

    # Reject shell metacharacters (security)
    if [[ "$email" =~ [\;\|\&\$\`\(\)\<\>] ]]; then
        return 1
    fi

    return 0
}
```

### 4.4 Mockable Commands for Testing

External commands are declared as variables for testability:

```bash
readonly AZ_CMD="${AZ_CMD:-az}"
readonly JQ_CMD="${JQ_CMD:-jq}"

# In tests:
# AZ_CMD="./mock_az.sh" ./ado-sync-permissions.sh --project "Test" ...
```

## 5. Usage Examples

### 5.1 Dry-Run (Default)

```bash
./ado-sync-permissions.sh \
    --project "Myriad - VPP" \
    --model "Ihar.Bandarenka@eneco.com" \
    --target "Rogier.vanhetSchip@eneco.com"
```

### 5.2 Apply Changes

```bash
./ado-sync-permissions.sh \
    --project "Myriad - VPP" \
    --model "Ihar.Bandarenka@eneco.com" \
    --target "Rogier.vanhetSchip@eneco.com" \
    --apply
```

### 5.3 JSON Output

```bash
./ado-sync-permissions.sh \
    --project "Myriad - VPP" \
    --model "Ihar.Bandarenka@eneco.com" \
    --target "Rogier.vanhetSchip@eneco.com" \
    --json
```

### 5.4 Custom Organization

```bash
./ado-sync-permissions.sh \
    --org "https://dev.azure.com/myorg" \
    --project "MyProject" \
    --model "model@example.com" \
    --target "target@example.com"
```

## 6. Output Format

### 6.1 Human-Readable Output

```
ADO Permission Sync
==================
Organization: https://dev.azure.com/enecomanagedcloud
Project: Myriad - VPP
Model User: Ihar.Bandarenka@eneco.com
Target User: Rogier.vanhetSchip@eneco.com
Mode: DRY-RUN (use --apply to make changes)

Verifying users...
✓ Model user exists: Ihar Bandarenka
✓ Target user exists: Rogier van het Schip

Analyzing team memberships...
Model user teams (in project): 9
Target user teams (in project): 2

Missing Teams (target needs to be added):
-----------------------------------------
  1. Team VPP Backend
  2. Team VPP Optimum
  3. VPP Core Release Masters
  ...

[DRY-RUN] Would add target to 7 team(s)

Run with --apply to make changes.
```

### 6.2 JSON Output

```json
{
  "timestamp": "2026-02-04T12:00:00Z",
  "organization": "https://dev.azure.com/enecomanagedcloud",
  "project": "Myriad - VPP",
  "mode": "dry-run",
  "model_user": {
    "email": "Ihar.Bandarenka@eneco.com",
    "display_name": "Ihar Bandarenka",
    "teams": ["Team VPP Backend", "Team VPP Frontend"]
  },
  "target_user": {
    "email": "Rogier.vanhetSchip@eneco.com",
    "display_name": "Rogier van het Schip",
    "teams": ["Team VPP Backend"]
  },
  "missing_teams": [
    {"name": "Team VPP Frontend", "descriptor": "vssgp.Uy0...", "status": "pending"}
  ],
  "summary": {
    "total_missing": 1,
    "added": 0,
    "failed": 0
  }
}
```

## 7. Validation

### 7.1 ShellCheck Status

```bash
$ shellcheck --severity=warning ado-sync-permissions.sh
# No output (clean)
```

Informational notes (intentional, not bugs):
- SC2329: Functions invoked via trap (cleanup, err_handler)
- SC2016: jq expressions intentionally use single quotes

### 7.2 Help Output

```bash
$ ./ado-sync-permissions.sh --help
ado-sync-permissions.sh v1.0.0 - Azure DevOps Team Permission Sync

USAGE:
    ado-sync-permissions.sh [OPTIONS]

REQUIRED OPTIONS:
    -p, --project NAME      Azure DevOps project name
    -m, --model EMAIL       Model user (copy permissions FROM)
    -t, --target EMAIL      Target user (copy permissions TO)
...
```

## 8. Security Considerations

| Threat | Mitigation |
|--------|------------|
| Command Injection | Email/project validation, variable quoting |
| Privilege Escalation | Script inherits operator's Azure RBAC |
| Credential Leakage | Uses az CLI credential caching |
| Audit Trail Bypass | Dry-run default, structured logging |

## 9. Prerequisites Check

The script validates all prerequisites before execution:

1. **az CLI**: `command -v az`
2. **jq**: `command -v jq`
3. **azure-devops extension**: `az extension list --query "[?name=='azure-devops']"`
4. **Azure login**: `az account show`

## 10. Future Enhancements

Potential improvements for future iterations:

1. **Parallel team additions**: Use background jobs for faster apply
2. **Rollback support**: Track added teams and provide --rollback
3. **Bats test suite**: Create tests/test_ado_sync.bats
4. **Team filtering**: --exclude-pattern to skip certain teams
5. **Audit logging**: Write to ~/.ado-sync/audit.log

## 11. Troubleshooting

### User Not Found (Exit 4)

```
[ERROR] Model user not found: nonexistent@eneco.com
```

**Cause**: Email doesn't exist in Azure DevOps organization.
**Fix**: Verify email spelling, check user is added to organization.

### API Error (Exit 5)

```
[ERROR] API error checking user: AADSTS...
```

**Cause**: Azure authentication expired or network issue.
**Fix**: Run `az login` to re-authenticate.

### Partial Failure (Exit 6)

```
Summary:
  Teams added: 5
  Teams failed: 2
```

**Cause**: Some teams added successfully, others failed (permission denied, team deleted).
**Fix**: Review failed teams, check operator has permission to modify those teams.
