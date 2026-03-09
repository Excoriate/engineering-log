---
task_id: 2026-02-04-001
agent: bash-shell-script-architect
timestamp: 2026-02-04T12:00:00Z
status: complete

summary: |
  Production-grade bash script architecture for Azure DevOps team membership
  synchronization. Design includes execution model analysis, function decomposition,
  security threat model, error handling taxonomy, and testability architecture.
  Dry-run default with explicit --apply for safety.

key_findings:
  - finding_1: az CLI subprocess calls require explicit exit code capture (local masks codes)
  - finding_2: JSON parsing via jq requires careful quoting for email addresses with special chars
  - finding_3: Project name filtering requires regex escaping for brackets in principalName
  - finding_4: Dry-run default prevents accidental permission changes
---

# ADO Permission Sync Script - Architecture Design

## 1. Execution Model

### 1.1 Process Hierarchy

```text
ado-sync-permissions.sh (main process)
├── az devops user show (subprocess) → verify model user exists
├── az devops user show (subprocess) → verify target user exists
├── az devops security group membership list (subprocess) → model user teams
├── az devops security group membership list (subprocess) → target user teams
├── jq (subprocess) → JSON parsing for team extraction
└── az devops security group membership add (subprocess, conditional) → add to teams
```

**Key Insight**: All `az` commands run as subprocesses. Exit codes MUST be captured explicitly.

### 1.2 Exit Code Flow

```text
CRITICAL: local var=$(cmd) MASKS exit code - local always succeeds!

CORRECT PATTERN:
  local output
  output=$(az devops user show --user "$email" 2>&1)
  local exit_code=$?

WRONG PATTERN (exit code lost):
  local output=$(az devops user show --user "$email" 2>&1)
  # $? is now 0 (from 'local'), not from 'az'
```

### 1.3 Signal Handling

```text
Trap handlers for cleanup:
├── SIGINT (Ctrl+C) → cleanup temp files, restore terminal
├── SIGTERM → graceful shutdown
├── EXIT → final cleanup (always runs)
└── ERR → log failure context (with set -E for function inheritance)
```

## 2. Function Decomposition

### 2.1 Function Hierarchy

```text
main()
├── parse_args()           # Argument parsing with getopt
├── validate_prerequisites()
│   ├── check_az_cli()     # Verify az CLI installed
│   ├── check_jq()         # Verify jq installed
│   └── check_az_login()   # Verify Azure DevOps auth
├── validate_users()
│   ├── verify_user_exists() → model user
│   └── verify_user_exists() → target user
├── get_team_memberships()
│   ├── fetch_memberships() → model user
│   └── fetch_memberships() → target user
├── compute_diff()         # Teams model has but target lacks
├── display_diff()         # Pretty-print table
└── apply_changes()        # Conditional on --apply flag
    └── add_to_team()      # Per-team addition
```

### 2.2 Function Specifications

```bash
# -----------------------------------------------------------------------------
# Function: verify_user_exists
# Purpose:  Check if user exists in Azure DevOps organization
# Inputs:   $1 = email address
# Outputs:  stdout = user display name (if exists)
# Returns:  0 = exists, 1 = not found, 2 = API error
# -----------------------------------------------------------------------------
verify_user_exists() {
    local email="$1"
    local output
    local exit_code

    output=$(az devops user show --user "$email" -o json 2>&1)
    exit_code=$?

    case $exit_code in
        0)
            jq -r '.user.displayName // empty' <<< "$output"
            return 0
            ;;
        *)
            if [[ "$output" == *"does not exist"* ]]; then
                return 1  # User not found
            fi
            log_error "API error checking user $email: $output"
            return 2  # API error
            ;;
    esac
}
```

```bash
# -----------------------------------------------------------------------------
# Function: fetch_memberships
# Purpose:  Get all team memberships for a user, filtered by project
# Inputs:   $1 = email, $2 = project name
# Outputs:  stdout = newline-separated "descriptor|displayName" pairs
# Returns:  0 = success, 1 = API error
# Pitfall:  Validated against BashPitfall #1 (no word splitting on output)
# -----------------------------------------------------------------------------
fetch_memberships() {
    local email="$1"
    local project="$2"
    local output
    local exit_code
    local escaped_project

    # Escape brackets for regex (project names like "Myriad - VPP")
    escaped_project=$(printf '%s' "$project" | sed 's/[][]/\\&/g')

    output=$(az devops security group membership list \
        --id "$email" \
        --relationship memberof \
        -o json 2>&1)
    exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        log_error "Failed to fetch memberships for $email: $output"
        return 1
    fi

    # Extract teams matching project, output as descriptor|displayName
    # Using jq with proper escaping
    jq -r --arg proj "\\[$escaped_project\\]\\\\" '
        to_entries[]
        | select(.value.principalName | test($proj))
        | "\(.key)|\(.value.displayName)"
    ' <<< "$output"
}
```

```bash
# -----------------------------------------------------------------------------
# Function: compute_diff
# Purpose:  Find teams model user has that target user lacks
# Inputs:   $1 = model teams (newline-sep), $2 = target teams (newline-sep)
# Outputs:  stdout = missing teams (descriptor|displayName per line)
# Returns:  0 = success
# Method:   Associative array diff (requires bash 4+)
# -----------------------------------------------------------------------------
compute_diff() {
    local model_teams="$1"
    local target_teams="$2"

    declare -A target_map

    # Build map of target's current teams (key = displayName)
    while IFS='|' read -r descriptor name; do
        [[ -n "$name" ]] && target_map["$name"]=1
    done <<< "$target_teams"

    # Output model teams not in target
    while IFS='|' read -r descriptor name; do
        if [[ -n "$name" && -z "${target_map[$name]:-}" ]]; then
            printf '%s|%s\n' "$descriptor" "$name"
        fi
    done <<< "$model_teams"
}
```

## 3. Error Handling Strategy

### 3.1 Exit Code Taxonomy

| Code | Meaning | Caller Action | Example |
|------|---------|---------------|---------|
| 0 | Success | Continue | All operations completed |
| 1 | User error | Fix input | Invalid email format |
| 2 | Missing prerequisite | Install/configure | jq not found |
| 3 | Authentication error | Re-login | az devops not authenticated |
| 4 | User not found | Check email | Model user doesn't exist |
| 5 | API error | Retry/escalate | Azure DevOps API failure |
| 6 | Partial failure | Review output | Some teams added, some failed |

### 3.2 Error Propagation Pattern

```bash
#!/usr/bin/env bash
set -euo pipefail

# ERR trap inherits to functions with -E
set -E

# Global for error context
declare -g CURRENT_OPERATION=""

# Structured error logging
log_error() {
    local msg="$1"
    local ts
    ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    printf '{"timestamp":"%s","level":"ERROR","operation":"%s","message":"%s"}\n' \
        "$ts" "$CURRENT_OPERATION" "$msg" >&2
}

# ERR trap with context
err_handler() {
    local exit_code=$?
    local line_no=$1
    log_error "Failed at line $line_no with exit code $exit_code"
    exit $exit_code
}
trap 'err_handler $LINENO' ERR
```

### 3.3 Graceful Degradation

```text
Strategy: Fail-fast for prerequisites, accumulate for batch operations

Phase 1 (Prerequisites): ANY failure → immediate exit
├── az CLI missing → exit 2
├── jq missing → exit 2
└── Not logged in → exit 3

Phase 2 (Validation): ANY failure → immediate exit
├── Model user not found → exit 4
└── Target user not found → exit 4

Phase 3 (Execution): Accumulate failures, report at end
├── Team A added → success
├── Team B failed → log, continue
├── Team C added → success
└── Final: exit 6 if any failures, exit 0 if all succeeded
```

## 4. Argument Parsing

### 4.1 Interface Design

```bash
USAGE: ado-sync-permissions.sh [OPTIONS]

Required:
  -p, --project NAME      Azure DevOps project name
  -m, --model EMAIL       Model user (copy permissions from)
  -t, --target EMAIL      Target user (copy permissions to)

Optional:
  -o, --org URL           Organization URL [default: https://dev.azure.com/enecomanagedcloud]
  -a, --apply             Actually add user to teams (default: dry-run)
  -v, --verbose           Enable verbose output
  -h, --help              Show this help message
  --json                  Output results as JSON

Examples:
  # Dry-run: show what would happen
  ./ado-sync-permissions.sh \
    --project "Myriad - VPP" \
    --model "Ihar.Bandarenka@eneco.com" \
    --target "Rogier.vanhetSchip@eneco.com"

  # Actually apply changes
  ./ado-sync-permissions.sh \
    --project "Myriad - VPP" \
    --model "Ihar.Bandarenka@eneco.com" \
    --target "Rogier.vanhetSchip@eneco.com" \
    --apply
```

### 4.2 Argument Parsing Implementation

```bash
parse_args() {
    # Defaults
    ORG_URL="https://dev.azure.com/enecomanagedcloud"
    PROJECT=""
    MODEL_USER=""
    TARGET_USER=""
    DRY_RUN=true
    VERBOSE=false
    JSON_OUTPUT=false

    # Use getopt for long options (GNU getopt on macOS via brew)
    local opts
    opts=$(getopt -o p:m:t:o:avh \
        --long project:,model:,target:,org:,apply,verbose,help,json \
        -n 'ado-sync-permissions.sh' -- "$@") || {
        usage
        exit 1
    }

    eval set -- "$opts"

    while true; do
        case "$1" in
            -p|--project)  PROJECT="$2"; shift 2 ;;
            -m|--model)    MODEL_USER="$2"; shift 2 ;;
            -t|--target)   TARGET_USER="$2"; shift 2 ;;
            -o|--org)      ORG_URL="$2"; shift 2 ;;
            -a|--apply)    DRY_RUN=false; shift ;;
            -v|--verbose)  VERBOSE=true; shift ;;
            --json)        JSON_OUTPUT=true; shift ;;
            -h|--help)     usage; exit 0 ;;
            --)            shift; break ;;
            *)             usage; exit 1 ;;
        esac
    done

    # Validate required args
    if [[ -z "$PROJECT" || -z "$MODEL_USER" || -z "$TARGET_USER" ]]; then
        log_error "Missing required arguments"
        usage
        exit 1
    fi

    # Validate email format (basic)
    local email_regex='^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
    if [[ ! "$MODEL_USER" =~ $email_regex ]]; then
        log_error "Invalid email format for model user: $MODEL_USER"
        exit 1
    fi
    if [[ ! "$TARGET_USER" =~ $email_regex ]]; then
        log_error "Invalid email format for target user: $TARGET_USER"
        exit 1
    fi
}
```

## 5. Output Format

### 5.1 Human-Readable Table (Default)

```text
================================================================================
Azure DevOps Permission Sync
================================================================================
Organization: https://dev.azure.com/enecomanagedcloud
Project:      Myriad - VPP
Model User:   Ihar.Bandarenka@eneco.com (Ihar Bandarenka)
Target User:  Rogier.vanhetSchip@eneco.com (Rogier van het Schip)
Mode:         DRY-RUN (use --apply to make changes)
================================================================================

Model User Teams (3):
  - Team VPP Backend
  - Team VPP Frontend
  - Team VPP DevOps

Target User Teams (1):
  - Team VPP Backend

================================================================================
MISSING TEAMS (2):
================================================================================
  #   Team Name              Status
  --- ---------------------- ----------
  1   Team VPP Frontend      [PENDING]
  2   Team VPP DevOps        [PENDING]
================================================================================

DRY-RUN complete. Use --apply to add target user to missing teams.
```

### 5.2 JSON Output (--json flag)

```json
{
  "timestamp": "2026-02-04T12:00:00Z",
  "organization": "https://dev.azure.com/enecomanagedcloud",
  "project": "Myriad - VPP",
  "mode": "dry-run",
  "model_user": {
    "email": "Ihar.Bandarenka@eneco.com",
    "display_name": "Ihar Bandarenka",
    "teams": ["Team VPP Backend", "Team VPP Frontend", "Team VPP DevOps"]
  },
  "target_user": {
    "email": "Rogier.vanhetSchip@eneco.com",
    "display_name": "Rogier van het Schip",
    "teams": ["Team VPP Backend"]
  },
  "missing_teams": [
    {"name": "Team VPP Frontend", "descriptor": "vssgp.Uy0xLT...", "status": "pending"},
    {"name": "Team VPP DevOps", "descriptor": "vssgp.Uy0yLT...", "status": "pending"}
  ],
  "summary": {
    "total_missing": 2,
    "added": 0,
    "failed": 0
  }
}
```

### 5.3 Output Implementation

```bash
# Table formatting helper
print_table_row() {
    local num="$1"
    local name="$2"
    local status="$3"
    printf '  %-3s %-30s %s\n' "$num" "$name" "$status"
}

display_results() {
    local -n missing_ref=$1  # nameref to array

    if [[ "$JSON_OUTPUT" == true ]]; then
        output_json "${missing_ref[@]}"
        return
    fi

    # Header
    printf '%s\n' "$(printf '=%.0s' {1..80})"
    printf 'Azure DevOps Permission Sync\n'
    printf '%s\n' "$(printf '=%.0s' {1..80})"
    printf 'Organization: %s\n' "$ORG_URL"
    printf 'Project:      %s\n' "$PROJECT"
    printf 'Model User:   %s (%s)\n' "$MODEL_USER" "$MODEL_DISPLAY_NAME"
    printf 'Target User:  %s (%s)\n' "$TARGET_USER" "$TARGET_DISPLAY_NAME"

    if [[ "$DRY_RUN" == true ]]; then
        printf 'Mode:         DRY-RUN (use --apply to make changes)\n'
    else
        printf 'Mode:         APPLY\n'
    fi
    printf '%s\n\n' "$(printf '=%.0s' {1..80})"

    # Missing teams table
    printf '%s\n' "$(printf '=%.0s' {1..80})"
    printf 'MISSING TEAMS (%d):\n' "${#missing_ref[@]}"
    printf '%s\n' "$(printf '=%.0s' {1..80})"
    print_table_row "#" "Team Name" "Status"
    print_table_row "---" "$(printf '%-30s' '' | tr ' ' '-')" "----------"

    local i=1
    for entry in "${missing_ref[@]}"; do
        local name="${entry#*|}"
        print_table_row "$i" "$name" "[PENDING]"
        ((i++))
    done
    printf '%s\n' "$(printf '=%.0s' {1..80})"
}
```

## 6. Safety Mechanisms

### 6.1 Dry-Run Default (CRITICAL)

```text
SAFETY PRINCIPLE: Default behavior MUST be non-destructive.

Implementation:
├── DRY_RUN=true (default)
├── --apply flag required to make changes
├── All mutating operations check: if [[ "$DRY_RUN" == false ]]; then
└── Clear visual indicator of mode in output
```

### 6.2 Confirmation Prompt (--apply mode)

```bash
confirm_apply() {
    local team_count=$1

    if [[ "$DRY_RUN" == true ]]; then
        return 0  # No confirmation needed for dry-run
    fi

    printf '\n'
    printf '⚠️  WARNING: About to add %s to %d team(s)\n' "$TARGET_USER" "$team_count"
    printf '\n'
    read -r -p "Type 'yes' to confirm: " response

    if [[ "$response" != "yes" ]]; then
        log_info "Operation cancelled by user"
        exit 0
    fi
}
```

### 6.3 Idempotency

```text
Safe to run multiple times:
├── User already in team → az CLI returns success (no-op)
├── Script checks current state before proposing changes
└── Re-running after partial failure only adds remaining teams
```

## 7. Security Threat Model

### 7.1 Threat Analysis

| Threat | Vector | Mitigation |
|--------|--------|------------|
| Command Injection | Email with shell metacharacters | Validate email format, quote all variables |
| Privilege Escalation | Adding user to admin teams | Script inherits operator's Azure RBAC permissions |
| Credential Leakage | Logging secrets | Use az CLI credential caching, no inline secrets |
| Audit Trail Bypass | Silent permission changes | Structured logging, require --apply flag |

### 7.2 Input Validation

```bash
validate_email() {
    local email="$1"
    local email_regex='^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'

    if [[ ! "$email" =~ $email_regex ]]; then
        return 1
    fi

    # Additional: no shell metacharacters
    if [[ "$email" =~ [\;\|\&\$\`\(\)] ]]; then
        return 1
    fi

    return 0
}

validate_project_name() {
    local project="$1"

    # Allow alphanumeric, spaces, hyphens, brackets
    if [[ ! "$project" =~ ^[A-Za-z0-9\ \-\[\]]+$ ]]; then
        return 1
    fi

    return 0
}
```

### 7.3 Environment Sanitization

```bash
# At script entry (after shebang)
export PATH="/usr/local/bin:/usr/bin:/bin"
unset IFS CDPATH GLOBIGNORE
umask 077
```

## 8. Testability Architecture

### 8.1 Mockable External Commands

```bash
# Declare command variables at top
readonly AZ_CMD="${AZ_CMD:-az}"
readonly JQ_CMD="${JQ_CMD:-jq}"

# Use variables in functions
fetch_memberships() {
    local email="$1"
    # ...
    output=$("$AZ_CMD" devops security group membership list \
        --id "$email" \
        --relationship memberof \
        -o json 2>&1)
    # ...
}

# In tests:
# AZ_CMD="./mock_az.sh" ./ado-sync-permissions.sh --project "Test" ...
```

### 8.2 Testable Trap Handlers

```bash
# TESTABLE: trap calls function
cleanup() {
    [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
    log_info "Cleanup complete"
}
trap cleanup EXIT

# NOT TESTABLE (inline):
# trap 'rm -rf "$TEMP_DIR"' EXIT
```

### 8.3 Test Scenarios

```text
Unit Tests (bats):
├── test_parse_args_valid
├── test_parse_args_missing_required
├── test_validate_email_valid
├── test_validate_email_injection_attempt
├── test_compute_diff_empty
├── test_compute_diff_with_missing
├── test_compute_diff_all_present

Integration Tests (with mocks):
├── test_user_not_found
├── test_api_error_handling
├── test_dry_run_no_changes
├── test_apply_adds_teams
├── test_partial_failure_reporting
```

## 9. File Structure

```text
/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/log/employer/eneco/scripts/
├── ado-sync-permissions.sh      # Main script
├── lib/
│   ├── common.sh                # Shared utilities (logging, validation)
│   └── ado-api.sh               # Azure DevOps API wrappers
└── tests/
    ├── test_ado_sync.bats       # Bats test suite
    └── mocks/
        └── mock_az.sh           # Mock az CLI for testing
```

**Note**: The `scripts/` directory does not exist yet. Create with:
```bash
mkdir -p /Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/log/employer/eneco/scripts/lib
mkdir -p /Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/log/employer/eneco/scripts/tests/mocks
```

## 10. Portability Decision Matrix

| Feature | Decision | Reason |
|---------|----------|--------|
| Associative arrays | Require bash 4+ | Essential for O(1) team lookup in diff |
| `local -n` (nameref) | Require bash 4.3+ | Clean array passing to functions |
| GNU getopt | Require (brew install gnu-getopt on macOS) | Long option support |
| jq | Require | JSON parsing, no pure-bash alternative |
| Process substitution `<()` | Use (bash feature) | Avoid subshell variable loss in while loops |

**Minimum Requirements:**
- bash 4.3+
- jq 1.6+
- az CLI 2.x
- GNU getopt (macOS: `brew install gnu-getopt`)

## 11. Implementation Checklist

- [ ] Create directory structure
- [ ] Implement `lib/common.sh` (logging, validation)
- [ ] Implement `lib/ado-api.sh` (API wrappers)
- [ ] Implement main script with argument parsing
- [ ] Add dry-run logic
- [ ] Add --apply confirmation prompt
- [ ] Implement JSON output mode
- [ ] Write bats tests
- [ ] Create mock az CLI for tests
- [ ] Add shellcheck validation to tests
- [ ] Document in README

## 12. Validation Commands

```bash
# Static analysis
shellcheck -x ado-sync-permissions.sh lib/*.sh

# Test suite
bats tests/

# Manual dry-run test
./ado-sync-permissions.sh \
  --project "Myriad - VPP" \
  --model "Ihar.Bandarenka@eneco.com" \
  --target "Rogier.vanhetSchip@eneco.com" \
  --verbose

# Verify no actual changes made (dry-run default)
az devops security group membership list --id "Rogier.vanhetSchip@eneco.com" --relationship memberof -o json | jq 'keys | length'
```
