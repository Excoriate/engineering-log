#!/usr/bin/env bash
# =============================================================================
# ado-sync-permissions.sh - Azure DevOps Team Permission Synchronization
# =============================================================================
# Purpose:  Copy team memberships from a model user to a target user within
#           a specific Azure DevOps project.
# Author:   Alex Torres
# Created:  2026-02-04
# Version:  1.0.0
#
# Exit Codes:
#   0 - Success (including dry-run success)
#   1 - Missing required arguments or invalid input
#   2 - Missing prerequisite (az CLI, jq, devops extension)
#   3 - Authentication error (not logged in)
#   4 - User not found in organization
#   5 - API error from Azure DevOps
#   6 - Partial failure (some teams added, some failed)
# =============================================================================

set -euo pipefail
set -E  # ERR trap inherits to functions

# =============================================================================
# Bash Version Check (requires bash 4+ for associative arrays)
# =============================================================================
if ((BASH_VERSINFO[0] < 4)); then
    echo "[ERROR] This script requires bash 4.0 or later." >&2
    echo "        Current version: ${BASH_VERSION}" >&2
    echo "        On macOS, install with: brew install bash" >&2
    echo "        Then run: /opt/homebrew/bin/bash $0 $*" >&2
    exit 2
fi

# =============================================================================
# Environment Sanitization
# =============================================================================
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"
unset IFS CDPATH GLOBIGNORE
umask 077

# =============================================================================
# Global Configuration
# =============================================================================
readonly SCRIPT_NAME="${0##*/}"
readonly SCRIPT_VERSION="1.0.0"

# Mockable commands for testing
readonly AZ_CMD="${AZ_CMD:-az}"
readonly JQ_CMD="${JQ_CMD:-jq}"

# Default values
DEFAULT_ORG_URL="https://dev.azure.com/enecomanagedcloud"

# Runtime state (global by default at script level)
ORG_URL=""
PROJECT=""
MODEL_USER=""
TARGET_USER=""
DRY_RUN=true
VERBOSE=false
JSON_OUTPUT=false
CURRENT_OPERATION=""

# User display names (populated during validation)
MODEL_DISPLAY_NAME=""
TARGET_DISPLAY_NAME=""

# =============================================================================
# Logging Functions
# =============================================================================
log_info() {
    local msg="$1"
    if [[ "$JSON_OUTPUT" != true ]]; then
        printf '[INFO] %s\n' "$msg"
    fi
}

log_verbose() {
    local msg="$1"
    if [[ "$VERBOSE" == true && "$JSON_OUTPUT" != true ]]; then
        printf '[DEBUG] %s\n' "$msg"
    fi
}

log_error() {
    local msg="$1"
    if [[ "$JSON_OUTPUT" == true ]]; then
        local ts
        ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        printf '{"timestamp":"%s","level":"ERROR","operation":"%s","message":"%s"}\n' \
            "$ts" "$CURRENT_OPERATION" "$msg" >&2
    else
        printf '[ERROR] %s\n' "$msg" >&2
    fi
}

log_success() {
    local msg="$1"
    if [[ "$JSON_OUTPUT" != true ]]; then
        printf '%s %s\n' "✓" "$msg"
    fi
}

log_pending() {
    local msg="$1"
    if [[ "$JSON_OUTPUT" != true ]]; then
        printf '%s %s\n' "○" "$msg"
    fi
}

# =============================================================================
# Error Handling
# =============================================================================
err_handler() {
    local exit_code=$?
    local line_no=$1
    log_error "Failed at line $line_no with exit code $exit_code"
    exit "$exit_code"
}
trap 'err_handler $LINENO' ERR

cleanup() {
    # Currently no temp files to clean up, but structure in place
    :
}
trap cleanup EXIT INT TERM

# =============================================================================
# Usage and Help
# =============================================================================
usage() {
    cat <<EOF
${SCRIPT_NAME} v${SCRIPT_VERSION} - Azure DevOps Team Permission Sync

USAGE:
    ${SCRIPT_NAME} [OPTIONS]

REQUIRED OPTIONS:
    -p, --project NAME      Azure DevOps project name
    -m, --model EMAIL       Model user (copy permissions FROM)
    -t, --target EMAIL      Target user (copy permissions TO)

OPTIONAL OPTIONS:
    -o, --org URL           Organization URL
                            [default: ${DEFAULT_ORG_URL}]
    -a, --apply             Actually add user to teams (default: dry-run)
    -v, --verbose           Enable verbose output
        --json              Output results as JSON
    -h, --help              Show this help message

EXIT CODES:
    0 - Success (including dry-run success)
    1 - Missing required arguments or invalid input
    2 - Missing prerequisite (az CLI, jq, devops extension)
    3 - Authentication error (not logged in)
    4 - User not found in organization
    5 - API error from Azure DevOps
    6 - Partial failure (some teams added, some failed)

EXAMPLES:
    # Dry-run: show what would happen
    ${SCRIPT_NAME} \\
        --project "Myriad - VPP" \\
        --model "Ihar.Bandarenka@eneco.com" \\
        --target "Rogier.vanhetSchip@eneco.com"

    # Actually apply changes
    ${SCRIPT_NAME} \\
        --project "Myriad - VPP" \\
        --model "Ihar.Bandarenka@eneco.com" \\
        --target "Rogier.vanhetSchip@eneco.com" \\
        --apply

    # With verbose output
    ${SCRIPT_NAME} \\
        --project "Myriad - VPP" \\
        --model "Ihar.Bandarenka@eneco.com" \\
        --target "Rogier.vanhetSchip@eneco.com" \\
        --verbose

NOTES:
    - Default mode is dry-run (no changes made)
    - Use --apply to actually add the target user to teams
    - Requires az CLI with devops extension and jq
    - Script inherits your Azure DevOps RBAC permissions
EOF
}

# =============================================================================
# Input Validation Functions
# =============================================================================
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

validate_project_name() {
    local project="$1"

    # Allow alphanumeric, spaces, hyphens, underscores
    # Using POSIX character classes for bash compatibility
    # Note: Brackets removed from pattern as they cause regex issues
    local pattern='^[[:alnum:][:space:]_-]+$'
    if [[ ! "$project" =~ $pattern ]]; then
        return 1
    fi

    return 0
}

# =============================================================================
# Argument Parsing
# =============================================================================
parse_args() {
    # Set defaults
    ORG_URL="$DEFAULT_ORG_URL"
    PROJECT=""
    MODEL_USER=""
    TARGET_USER=""
    DRY_RUN=true
    VERBOSE=false
    JSON_OUTPUT=false

    # Manual parsing for portability (no GNU getopt dependency)
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--project)
                if [[ -z "${2:-}" ]]; then
                    log_error "Option $1 requires a value"
                    exit 1
                fi
                PROJECT="$2"
                shift 2
                ;;
            -m|--model)
                if [[ -z "${2:-}" ]]; then
                    log_error "Option $1 requires a value"
                    exit 1
                fi
                MODEL_USER="$2"
                shift 2
                ;;
            -t|--target)
                if [[ -z "${2:-}" ]]; then
                    log_error "Option $1 requires a value"
                    exit 1
                fi
                TARGET_USER="$2"
                shift 2
                ;;
            -o|--org)
                if [[ -z "${2:-}" ]]; then
                    log_error "Option $1 requires a value"
                    exit 1
                fi
                ORG_URL="$2"
                shift 2
                ;;
            -a|--apply)
                DRY_RUN=false
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --json)
                JSON_OUTPUT=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                log_error "Unexpected argument: $1"
                usage
                exit 1
                ;;
        esac
    done

    # Validate required arguments
    local missing=()
    [[ -z "$PROJECT" ]] && missing+=("--project")
    [[ -z "$MODEL_USER" ]] && missing+=("--model")
    [[ -z "$TARGET_USER" ]] && missing+=("--target")

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required arguments: ${missing[*]}"
        usage
        exit 1
    fi

    # Validate email formats
    if ! validate_email "$MODEL_USER"; then
        log_error "Invalid email format for model user: $MODEL_USER"
        exit 1
    fi
    if ! validate_email "$TARGET_USER"; then
        log_error "Invalid email format for target user: $TARGET_USER"
        exit 1
    fi

    # Validate project name
    if ! validate_project_name "$PROJECT"; then
        log_error "Invalid project name format: $PROJECT"
        exit 1
    fi

    log_verbose "Configuration:"
    log_verbose "  Organization: $ORG_URL"
    log_verbose "  Project: $PROJECT"
    log_verbose "  Model User: $MODEL_USER"
    log_verbose "  Target User: $TARGET_USER"
    log_verbose "  Dry Run: $DRY_RUN"
}

# =============================================================================
# Prerequisite Checks
# =============================================================================
check_prerequisites() {
    CURRENT_OPERATION="check_prerequisites"
    log_verbose "Checking prerequisites..."

    # Check az CLI
    if ! command -v "$AZ_CMD" &>/dev/null; then
        log_error "az CLI not found. Install with: brew install azure-cli"
        exit 2
    fi
    log_verbose "  az CLI: found"

    # Check jq
    if ! command -v "$JQ_CMD" &>/dev/null; then
        log_error "jq not found. Install with: brew install jq"
        exit 2
    fi
    log_verbose "  jq: found"

    # Check az devops extension
    local ext_check
    ext_check=$("$AZ_CMD" extension list --query "[?name=='azure-devops'].name" -o tsv 2>/dev/null)
    if [[ -z "$ext_check" ]]; then
        log_error "Azure DevOps extension not found. Install with: az extension add --name azure-devops"
        exit 2
    fi
    log_verbose "  azure-devops extension: found"

    # Check az login status
    local login_check
    login_check=$("$AZ_CMD" account show -o json 2>&1) || true
    if [[ "$login_check" == *"az login"* || "$login_check" == *"AADSTS"* ]]; then
        log_error "Not logged in to Azure. Run: az login"
        exit 3
    fi
    log_verbose "  Azure login: authenticated"

    log_verbose "Prerequisites OK"
}

# =============================================================================
# Azure DevOps API Functions
# =============================================================================

# -----------------------------------------------------------------------------
# Function: verify_user_exists
# Purpose:  Check if user exists in Azure DevOps organization
# Inputs:   $1 = email address
# Outputs:  stdout = user display name (if exists)
# Returns:  0 = exists, 1 = not found, 2 = API error
# CRITICAL: Uses separate local declaration to preserve exit code
# -----------------------------------------------------------------------------
verify_user_exists() {
    local email="$1"
    local output
    local exit_code

    # CRITICAL: Separate declaration from assignment to preserve exit code
    output=$("$AZ_CMD" devops user show \
        --user "$email" \
        --org "$ORG_URL" \
        -o json 2>&1)
    exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        # User exists, extract display name
        local display_name
        display_name=$("$JQ_CMD" -r '.user.displayName // empty' <<< "$output")
        if [[ -n "$display_name" ]]; then
            printf '%s' "$display_name"
            return 0
        fi
        return 0
    fi

    # Check if it's a "not found" error vs other API error
    if [[ "$output" == *"does not exist"* ]] || [[ "$output" == *"could not be found"* ]]; then
        return 1  # User not found
    fi

    log_error "API error checking user $email: $output"
    return 2  # API error
}

# -----------------------------------------------------------------------------
# Function: fetch_memberships
# Purpose:  Get all team memberships for a user, filtered by project
# Inputs:   $1 = email, $2 = project name
# Outputs:  stdout = newline-separated "descriptor|displayName" pairs
# Returns:  0 = success, 1 = API error
# -----------------------------------------------------------------------------
fetch_memberships() {
    local email="$1"
    local project="$2"
    local output
    local exit_code
    local escaped_project

    # Escape brackets for jq regex (project names like "[Myriad - VPP]")
    # The principalName format is: [ProjectName]\TeamName
    escaped_project=$(printf '%s' "$project" | sed 's/[][]/\\&/g')

    log_verbose "Fetching memberships for $email in project '$project'..."
    log_verbose "  Escaped project pattern: \\[$escaped_project\\]\\\\"

    # CRITICAL: Separate declaration from assignment
    output=$("$AZ_CMD" devops security group membership list \
        --id "$email" \
        --org "$ORG_URL" \
        --relationship memberof \
        -o json 2>&1)
    exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        log_error "Failed to fetch memberships for $email: $output"
        return 1
    fi

    # Extract teams matching project, output as descriptor|displayName
    # principalName format: [ProjectName]\TeamName
    # We filter where principalName contains [ProjectName]\
    "$JQ_CMD" -r --arg proj "\\[$escaped_project\\]\\\\" '
        to_entries[]
        | select(.value.principalName != null)
        | select(.value.principalName | test($proj; "i"))
        | "\(.key)|\(.value.displayName)"
    ' <<< "$output"
}

# -----------------------------------------------------------------------------
# Function: compute_diff
# Purpose:  Find teams model user has that target user lacks
# Inputs:   $1 = model teams (newline-sep), $2 = target teams (newline-sep)
# Outputs:  stdout = missing teams (descriptor|displayName per line)
# Returns:  0 = success
# -----------------------------------------------------------------------------
compute_diff() {
    local model_teams="$1"
    local target_teams="$2"

    declare -A target_map

    # Build map of target's current teams (key = displayName for comparison)
    while IFS='|' read -r descriptor name; do
        if [[ -n "$name" ]]; then
            target_map["$name"]=1
        fi
    done <<< "$target_teams"

    # Output model teams not in target
    while IFS='|' read -r descriptor name; do
        if [[ -n "$name" && -z "${target_map[$name]:-}" ]]; then
            printf '%s|%s\n' "$descriptor" "$name"
        fi
    done <<< "$model_teams"
}

# -----------------------------------------------------------------------------
# Function: add_to_team
# Purpose:  Add user to a team by team descriptor
# Inputs:   $1 = team descriptor, $2 = user email
# Returns:  0 = success, 1 = failure
# -----------------------------------------------------------------------------
add_to_team() {
    local team_descriptor="$1"
    local user_email="$2"
    local output
    local exit_code

    # CRITICAL: Separate declaration from assignment
    output=$("$AZ_CMD" devops security group membership add \
        --group-id "$team_descriptor" \
        --member-id "$user_email" \
        --org "$ORG_URL" \
        -o json 2>&1)
    exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        log_error "Failed to add $user_email to team: $output"
        return 1
    fi

    return 0
}

# =============================================================================
# Output Functions
# =============================================================================
print_header() {
    if [[ "$JSON_OUTPUT" == true ]]; then
        return
    fi

    printf '\n'
    printf 'ADO Permission Sync\n'
    printf '==================\n'
    printf 'Organization: %s\n' "$ORG_URL"
    printf 'Project: %s\n' "$PROJECT"
    printf 'Model User: %s\n' "$MODEL_USER"
    printf 'Target User: %s\n' "$TARGET_USER"
    if [[ "$DRY_RUN" == true ]]; then
        printf 'Mode: DRY-RUN (use --apply to make changes)\n'
    else
        printf 'Mode: APPLY\n'
    fi
    printf '\n'
}

print_team_list() {
    local title="$1"
    local teams="$2"
    local count=0

    if [[ "$JSON_OUTPUT" == true ]]; then
        return
    fi

    # Count teams
    while IFS='|' read -r descriptor name; do
        [[ -n "$name" ]] && ((count++)) || true
    done <<< "$teams"

    printf '%s (%d):\n' "$title" "$count"
    while IFS='|' read -r descriptor name; do
        if [[ -n "$name" ]]; then
            printf '  - %s\n' "$name"
        fi
    done <<< "$teams"
    printf '\n'
}

print_missing_teams() {
    local missing_teams="$1"
    local count=0
    local i=1

    if [[ "$JSON_OUTPUT" == true ]]; then
        return
    fi

    # Count missing
    while IFS='|' read -r descriptor name; do
        [[ -n "$name" ]] && ((count++)) || true
    done <<< "$missing_teams"

    if [[ $count -eq 0 ]]; then
        printf 'No missing teams - target user has all model user teams in this project.\n'
        return
    fi

    printf 'Missing Teams (target needs to be added):\n'
    printf -- '-----------------------------------------\n'
    while IFS='|' read -r descriptor name; do
        if [[ -n "$name" ]]; then
            printf '  %d. %s\n' "$i" "$name"
            ((i++))
        fi
    done <<< "$missing_teams"
    printf '\n'
}

output_json() {
    local model_teams="$1"
    local target_teams="$2"
    local missing_teams="$3"
    local added_count="${4:-0}"
    local failed_count="${5:-0}"

    local model_arr='[]'
    local target_arr='[]'
    local missing_arr='[]'

    # Build model teams array
    while IFS='|' read -r descriptor name; do
        if [[ -n "$name" ]]; then
            model_arr=$("$JQ_CMD" -c --arg n "$name" '. + [$n]' <<< "$model_arr")
        fi
    done <<< "$model_teams"

    # Build target teams array
    while IFS='|' read -r descriptor name; do
        if [[ -n "$name" ]]; then
            target_arr=$("$JQ_CMD" -c --arg n "$name" '. + [$n]' <<< "$target_arr")
        fi
    done <<< "$target_teams"

    # Build missing teams array with descriptors
    while IFS='|' read -r descriptor name; do
        if [[ -n "$name" ]]; then
            local status="pending"
            [[ "$DRY_RUN" == false ]] && status="processed"
            missing_arr=$("$JQ_CMD" -c --arg n "$name" --arg d "$descriptor" --arg s "$status" \
                '. + [{"name": $n, "descriptor": $d, "status": $s}]' <<< "$missing_arr")
        fi
    done <<< "$missing_teams"

    local mode="dry-run"
    [[ "$DRY_RUN" == false ]] && mode="apply"

    local total_missing
    total_missing=$("$JQ_CMD" 'length' <<< "$missing_arr")

    "$JQ_CMD" -n \
        --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        --arg org "$ORG_URL" \
        --arg proj "$PROJECT" \
        --arg mode "$mode" \
        --arg model_email "$MODEL_USER" \
        --arg model_name "$MODEL_DISPLAY_NAME" \
        --argjson model_teams "$model_arr" \
        --arg target_email "$TARGET_USER" \
        --arg target_name "$TARGET_DISPLAY_NAME" \
        --argjson target_teams "$target_arr" \
        --argjson missing "$missing_arr" \
        --argjson total "$total_missing" \
        --argjson added "$added_count" \
        --argjson failed "$failed_count" \
        '{
            timestamp: $ts,
            organization: $org,
            project: $proj,
            mode: $mode,
            model_user: {
                email: $model_email,
                display_name: $model_name,
                teams: $model_teams
            },
            target_user: {
                email: $target_email,
                display_name: $target_name,
                teams: $target_teams
            },
            missing_teams: $missing,
            summary: {
                total_missing: $total,
                added: $added,
                failed: $failed
            }
        }'
}

# =============================================================================
# Confirmation for Apply Mode
# =============================================================================
confirm_apply() {
    local team_count=$1

    if [[ "$DRY_RUN" == true ]]; then
        return 0  # No confirmation needed for dry-run
    fi

    if [[ "$JSON_OUTPUT" == true ]]; then
        return 0  # No interactive confirmation in JSON mode
    fi

    printf '\n'
    printf 'WARNING: About to add %s to %d team(s)\n' "$TARGET_USER" "$team_count"
    printf '\n'
    read -r -p "Type 'yes' to confirm: " response

    if [[ "$response" != "yes" ]]; then
        log_info "Operation cancelled by user"
        exit 0
    fi
}

# =============================================================================
# Main Execution
# =============================================================================
main() {
    # Parse arguments
    parse_args "$@"

    # Check prerequisites
    check_prerequisites

    # Print header
    print_header

    # Verify users exist
    CURRENT_OPERATION="verify_users"
    if [[ "$JSON_OUTPUT" != true ]]; then
        printf 'Verifying users...\n'
    fi

    # Verify model user
    log_verbose "Checking model user: $MODEL_USER"
    local model_result
    model_result=$(verify_user_exists "$MODEL_USER") || {
        local rc=$?
        if [[ $rc -eq 1 ]]; then
            log_error "Model user not found: $MODEL_USER"
            exit 4
        else
            log_error "Failed to verify model user: $MODEL_USER"
            exit 5
        fi
    }
    MODEL_DISPLAY_NAME="$model_result"
    log_success "Model user exists: $MODEL_DISPLAY_NAME"

    # Verify target user
    log_verbose "Checking target user: $TARGET_USER"
    local target_result
    target_result=$(verify_user_exists "$TARGET_USER") || {
        local rc=$?
        if [[ $rc -eq 1 ]]; then
            log_error "Target user not found: $TARGET_USER"
            exit 4
        else
            log_error "Failed to verify target user: $TARGET_USER"
            exit 5
        fi
    }
    TARGET_DISPLAY_NAME="$target_result"
    log_success "Target user exists: $TARGET_DISPLAY_NAME"

    # Fetch team memberships
    CURRENT_OPERATION="fetch_memberships"
    if [[ "$JSON_OUTPUT" != true ]]; then
        printf '\nAnalyzing team memberships...\n'
    fi

    local model_teams
    model_teams=$(fetch_memberships "$MODEL_USER" "$PROJECT") || {
        log_error "Failed to fetch model user memberships"
        exit 5
    }

    local target_teams
    target_teams=$(fetch_memberships "$TARGET_USER" "$PROJECT") || {
        log_error "Failed to fetch target user memberships"
        exit 5
    }

    # Count teams
    local model_count=0
    local target_count=0
    while IFS='|' read -r descriptor name; do
        [[ -n "$name" ]] && ((model_count++)) || true
    done <<< "$model_teams"
    while IFS='|' read -r descriptor name; do
        [[ -n "$name" ]] && ((target_count++)) || true
    done <<< "$target_teams"

    if [[ "$JSON_OUTPUT" != true ]]; then
        printf 'Model user teams (in project): %d\n' "$model_count"
        printf 'Target user teams (in project): %d\n' "$target_count"
        printf '\n'
    fi

    # Compute diff
    CURRENT_OPERATION="compute_diff"
    local missing_teams
    missing_teams=$(compute_diff "$model_teams" "$target_teams")

    # Count missing
    local missing_count=0
    while IFS='|' read -r descriptor name; do
        [[ -n "$name" ]] && ((missing_count++)) || true
    done <<< "$missing_teams"

    # Display missing teams
    print_missing_teams "$missing_teams"

    # Handle apply or dry-run
    local added_count=0
    local failed_count=0

    if [[ $missing_count -eq 0 ]]; then
        if [[ "$JSON_OUTPUT" == true ]]; then
            output_json "$model_teams" "$target_teams" "$missing_teams" 0 0
        fi
        exit 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        if [[ "$JSON_OUTPUT" != true ]]; then
            printf '[DRY-RUN] Would add target to %d team(s)\n' "$missing_count"
            printf '\nRun with --apply to make changes.\n'
        else
            output_json "$model_teams" "$target_teams" "$missing_teams" 0 0
        fi
        exit 0
    fi

    # Apply mode - add user to missing teams
    CURRENT_OPERATION="apply_changes"
    confirm_apply "$missing_count"

    if [[ "$JSON_OUTPUT" != true ]]; then
        printf '\nAdding target user to teams...\n'
    fi

    while IFS='|' read -r descriptor name; do
        if [[ -n "$name" && -n "$descriptor" ]]; then
            log_verbose "Adding to team: $name (descriptor: $descriptor)"
            if add_to_team "$descriptor" "$TARGET_USER"; then
                log_success "Added to: $name"
                ((added_count++))
            else
                log_error "Failed to add to: $name"
                ((failed_count++))
            fi
        fi
    done <<< "$missing_teams"

    # Summary
    if [[ "$JSON_OUTPUT" == true ]]; then
        output_json "$model_teams" "$target_teams" "$missing_teams" "$added_count" "$failed_count"
    else
        printf '\n'
        printf 'Summary:\n'
        printf '  Teams added: %d\n' "$added_count"
        printf '  Teams failed: %d\n' "$failed_count"
    fi

    # Exit code based on results
    if [[ $failed_count -gt 0 ]]; then
        if [[ $added_count -gt 0 ]]; then
            exit 6  # Partial failure
        else
            exit 5  # Complete failure
        fi
    fi

    exit 0
}

# =============================================================================
# Entry Point
# =============================================================================
main "$@"
