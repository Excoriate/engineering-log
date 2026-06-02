#!/usr/bin/env bash
# ============================================================================
# One-For-All Pipeline — Missing Variable Diagnosis & Fix
# ============================================================================
# PURPOSE: Deterministic check + fix for the recurring pattern where a service
#          variable is missing from the ADO Release-X.Y variable group, causing
#          the One-For-All pipeline to write empty image tags.
#
# PATTERN: Occurred Sep 2025 (telemetry), Apr 2026 (clientgateway).
#          Same mechanism: missing variable → $(service) becomes bash command
#          substitution → "command not found" → empty tag written → ArgoCD fails.
#
# USAGE:
#   ./oneforall-diagnose-and-fix.sh diagnose 0.145
#   ./oneforall-diagnose-and-fix.sh fix 0.145 clientgateway 0.145.0
#   ./oneforall-diagnose-and-fix.sh fix-and-rerun 0.145 clientgateway 0.145.0
#
# PREREQUISITES:
#   - az CLI authenticated (az login)
#   - Access to enecomanagedcloud ADO organization
# ============================================================================

set -euo pipefail

ORG="https://dev.azure.com/enecomanagedcloud"
PROJECT="Myriad - VPP"
PIPELINE_ID=1811  # One-For-All pipeline

# These are the services hardcoded in oneforallmsv2.yaml (lines 40-61)
# Services that have dev/acc/prod Helm directories and MUST have a variable
REQUIRED_SERVICES=(
  "activationmfrr"
  "asset"
  "assetmonitor"
  "assetplanning"
  "clientgateway"
  "dataprep"
  "dispatcherafrr"
  "dispatchermanual"
  "dispatchermfrr"
  "dispatcherscheduled"
  "dispatchersimulator"
  "frontend"
  "marketinteraction"
  "telemetry"
  "integration-tests"
  "monitor"
)

# These are in the script but known to NOT have dev/acc Helm dirs — noise, not bugs
KNOWN_NOISE_SERVICES=(
  "gatewaynl"        # No Helm dir (should be tenant-gateway)
  "alarmengine"      # sandbox only
  "alarmpreprocessing" # sandbox only
)

# Also check these optional services
OPTIONAL_SERVICES=(
  "espmessageconsumer"
  "espmessageproducer"
  "tenant-gateway"
)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# ============================================================================
# Functions
# ============================================================================

usage() {
  cat <<EOF
Usage: $0 <command> <release_version> [service_name] [service_version]

Commands:
  diagnose <version>                         Check Release-X.Y variable group for missing services
  fix <version> <service> <tag>              Add missing service variable to the group
  fix-and-rerun <version> <service> <tag>    Fix variable AND re-run One-For-All pipeline
  verify-fix <version>                       Verify all services are present after fix
  check-repo                                 Check VPP-Configuration for empty tags

Examples:
  $0 diagnose 0.145
  $0 fix 0.145 clientgateway 0.145.0
  $0 fix-and-rerun 0.145 clientgateway 0.145.0
  $0 verify-fix 0.145
  $0 check-repo
EOF
  exit 1
}

get_variable_group_id() {
  local version="$1"
  local group_name="Release-${version}"

  az pipelines variable-group list \
    --org "$ORG" \
    --project "$PROJECT" \
    --output json 2>/dev/null \
    | python3 -c "
import sys, json
groups = json.load(sys.stdin)
for g in groups:
    if g['name'] == '${group_name}':
        print(g['id'])
        sys.exit(0)
print('NOT_FOUND')
"
}

get_variable_group_vars() {
  local group_id="$1"

  az pipelines variable-group show \
    --id "$group_id" \
    --org "$ORG" \
    --project "$PROJECT" \
    --output json 2>/dev/null \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
for k, v in sorted(data.get('variables', {}).items()):
    print(f'{k}={v.get(\"value\", \"<secret>\")}')
"
}

diagnose() {
  local version="$1"

  echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║  One-For-All Pipeline — Variable Group Diagnosis            ║${NC}"
  echo -e "${BOLD}║  Release: ${version}                                              ║${NC}"
  echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  # Step 1: Find variable group
  echo -e "${CYAN}[1/4] Finding variable group Release-${version}...${NC}"
  local group_id
  group_id=$(get_variable_group_id "$version")

  if [[ "$group_id" == "NOT_FOUND" ]]; then
    echo -e "${RED}  ERROR: Variable group 'Release-${version}' not found!${NC}"
    echo "  Available release groups:"
    az pipelines variable-group list \
      --org "$ORG" --project "$PROJECT" --output json 2>/dev/null \
      | python3 -c "
import sys,json
for g in json.load(sys.stdin):
    if g['name'].startswith('Release-0.'):
        print(f\"    {g['id']}: {g['name']}\")
" | tail -5
    exit 1
  fi
  echo -e "${GREEN}  Found: Group ID ${group_id}${NC}"

  # Step 2: Get all variables
  echo -e "${CYAN}[2/4] Reading variable group contents...${NC}"
  local vars
  vars=$(get_variable_group_vars "$group_id")

  # Step 3: Check required services
  echo -e "${CYAN}[3/4] Checking required services...${NC}"
  echo ""

  local missing_count=0
  local present_count=0
  local empty_count=0

  echo -e "  ${BOLD}Required Services (have dev/acc/prod Helm dirs):${NC}"
  for svc in "${REQUIRED_SERVICES[@]}"; do
    local val
    val=$(echo "$vars" | grep "^${svc}=" | cut -d= -f2- || true)

    if [[ -z "$val" ]]; then
      echo -e "    ${RED}✗ ${svc} — MISSING${NC}"
      ((missing_count++))
    elif [[ "$val" == "" || "$val" == '""' ]]; then
      echo -e "    ${YELLOW}⚠ ${svc} = (empty) — EMPTY VALUE${NC}"
      ((empty_count++))
    else
      echo -e "    ${GREEN}✓ ${svc} = ${val}${NC}"
      ((present_count++))
    fi
  done

  echo ""
  echo -e "  ${BOLD}Optional Services:${NC}"
  for svc in "${OPTIONAL_SERVICES[@]}"; do
    local val
    val=$(echo "$vars" | grep "^${svc}=" | cut -d= -f2- || true)

    if [[ -z "$val" ]]; then
      echo -e "    ${YELLOW}○ ${svc} — not present (optional)${NC}"
    else
      echo -e "    ${GREEN}✓ ${svc} = ${val}${NC}"
    fi
  done

  echo ""
  echo -e "  ${BOLD}Known Noise (always fail, no Helm dirs — safe to ignore):${NC}"
  for svc in "${KNOWN_NOISE_SERVICES[@]}"; do
    local val
    val=$(echo "$vars" | grep "^${svc}=" | cut -d= -f2- || true)
    if [[ -z "$val" ]]; then
      echo -e "    ${YELLOW}~ ${svc} — absent (expected)${NC}"
    else
      echo -e "    ${GREEN}✓ ${svc} = ${val} (bonus — not required)${NC}"
    fi
  done

  echo ""
  echo -e "  ${BOLD}Environment Flags:${NC}"
  for flag in "test-env" "acc-env" "prod-env"; do
    local val
    val=$(echo "$vars" | grep "^${flag}=" | cut -d= -f2- || true)
    echo -e "    ${CYAN}${flag} = ${val:-NOT SET}${NC}"
  done

  # Step 4: Summary
  echo ""
  echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║  DIAGNOSIS SUMMARY                                          ║${NC}"
  echo -e "${BOLD}╠══════════════════════════════════════════════════════════════╣${NC}"
  echo -e "  Present:  ${GREEN}${present_count}${NC}"
  echo -e "  Missing:  ${RED}${missing_count}${NC}"
  echo -e "  Empty:    ${YELLOW}${empty_count}${NC}"

  if [[ $missing_count -gt 0 || $empty_count -gt 0 ]]; then
    echo -e "${BOLD}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "  ${RED}STATUS: PROBLEMS DETECTED${NC}"
    echo ""
    echo -e "  ${BOLD}To fix, run:${NC}"
    for svc in "${REQUIRED_SERVICES[@]}"; do
      local val
      val=$(echo "$vars" | grep "^${svc}=" | cut -d= -f2- || true)
      if [[ -z "$val" ]]; then
        echo -e "    ${YELLOW}$0 fix ${version} ${svc} <version-tag>${NC}"
      fi
    done
    echo ""
    echo -e "  ${BOLD}To find the correct version tag, check the CD pipeline:${NC}"
    echo -e "    ${CYAN}az pipelines runs list --pipeline-ids <service-cd-pipeline-id> \\"
    echo -e "      --branch refs/heads/release/${version} --top 1 \\"
    echo -e "      --org ${ORG} --project \"${PROJECT}\" --output table${NC}"
  else
    echo -e "${BOLD}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "  ${GREEN}STATUS: ALL REQUIRED SERVICES PRESENT${NC}"
  fi
  echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"

  return $missing_count
}

fix_variable() {
  local version="$1"
  local service="$2"
  local tag="$3"

  echo -e "${BOLD}Fixing: Adding ${service}=${tag} to Release-${version}${NC}"

  # Get group ID
  local group_id
  group_id=$(get_variable_group_id "$version")

  if [[ "$group_id" == "NOT_FOUND" ]]; then
    echo -e "${RED}ERROR: Variable group 'Release-${version}' not found!${NC}"
    exit 1
  fi

  # Check if variable already exists
  local existing
  existing=$(az pipelines variable-group show --id "$group_id" \
    --org "$ORG" --project "$PROJECT" --output json 2>/dev/null \
    | python3 -c "
import sys,json
d=json.load(sys.stdin)
v=d.get('variables',{}).get('${service}',{})
print(v.get('value','NOT_FOUND'))
")

  if [[ "$existing" != "NOT_FOUND" ]]; then
    echo -e "${YELLOW}WARNING: Variable '${service}' already exists with value '${existing}'${NC}"
    echo -e "  Updating to '${tag}'..."
    az pipelines variable-group variable update \
      --group-id "$group_id" \
      --name "$service" \
      --value "$tag" \
      --org "$ORG" \
      --project "$PROJECT" \
      --output json > /dev/null 2>&1
  else
    echo -e "  Adding variable..."
    az pipelines variable-group variable create \
      --group-id "$group_id" \
      --name "$service" \
      --value "$tag" \
      --org "$ORG" \
      --project "$PROJECT" \
      --output json > /dev/null 2>&1
  fi

  # Verify
  local verify
  verify=$(az pipelines variable-group show --id "$group_id" \
    --org "$ORG" --project "$PROJECT" --output json 2>/dev/null \
    | python3 -c "
import sys,json
d=json.load(sys.stdin)
v=d.get('variables',{}).get('${service}',{})
print(v.get('value','NOT_FOUND'))
")

  if [[ "$verify" == "$tag" ]]; then
    echo -e "${GREEN}SUCCESS: ${service} = ${verify} in Release-${version} (group ${group_id})${NC}"
  else
    echo -e "${RED}FAILED: Verification shows ${service} = ${verify} (expected ${tag})${NC}"
    exit 1
  fi
}

fix_and_rerun() {
  local version="$1"
  local service="$2"
  local tag="$3"

  # Step 1: Fix variable
  fix_variable "$version" "$service" "$tag"

  echo ""
  echo -e "${BOLD}Pre-flight checks before re-running pipeline...${NC}"

  # Step 2: Run full diagnosis
  echo -e "${CYAN}Running full diagnosis...${NC}"
  if diagnose "$version"; then
    echo -e "${GREEN}All services present. Safe to re-run.${NC}"
  else
    echo -e "${YELLOW}WARNING: Some services still missing. Re-run may write empty tags for those.${NC}"
    echo -e "  The known noise services (gatewaynl, alarmengine, alarmpreprocessing) are safe to ignore."
    echo -e "  If any REQUIRED service is missing, fix it first."
    echo ""
    read -rp "Continue with re-run? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
      echo "Aborted."
      exit 0
    fi
  fi

  echo ""
  echo -e "${BOLD}Triggering One-For-All pipeline on release/${version}...${NC}"

  local run_output
  run_output=$(az pipelines run \
    --id "$PIPELINE_ID" \
    --branch "release/${version}" \
    --org "$ORG" \
    --project "$PROJECT" \
    --output json 2>&1)

  local build_id
  build_id=$(echo "$run_output" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null || echo "UNKNOWN")
  local build_number
  build_number=$(echo "$run_output" | python3 -c "import sys,json; print(json.load(sys.stdin)['buildNumber'])" 2>/dev/null || echo "UNKNOWN")

  echo -e "${GREEN}Pipeline triggered!${NC}"
  echo -e "  Build ID: ${build_id}"
  echo -e "  Build Number: ${build_number}"
  echo -e "  Monitor: ${ORG}/Myriad%20-%20VPP/_build/results?buildId=${build_id}&view=results"
  echo ""
  echo -e "${YELLOW}NEXT STEPS:${NC}"
  echo -e "  1. Wait for build to complete (~30s)"
  echo -e "  2. Run: $0 verify-fix ${version}"
  echo -e "  3. Check ArgoCD: clientgateway sync status in ACC and DEV"
}

verify_fix() {
  local version="$1"

  echo -e "${BOLD}Verifying fix for Release-${version}...${NC}"
  echo ""

  # Run diagnosis
  diagnose "$version"

  echo ""
  echo -e "${BOLD}Checking VPP-Configuration repo for empty tags...${NC}"
  check_repo
}

check_repo() {
  local repo_path="/Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src/enecomanagedcloud/myriad-vpp/VPP-Configuration"

  if [[ ! -d "$repo_path" ]]; then
    echo -e "${YELLOW}VPP-Configuration repo not found locally at ${repo_path}${NC}"
    echo "  Checking remote..."
    # Try to fetch and check via ADO API
    return
  fi

  echo -e "${CYAN}Fetching latest from remote...${NC}"
  (cd "$repo_path" && git fetch origin --prune 2>/dev/null)

  echo ""
  echo -e "${BOLD}Services with empty tags on origin/main:${NC}"

  local found_empty=0
  for dir in "$repo_path"/Helm/*/; do
    local svc
    svc=$(basename "$dir")
    for env in dev acc prod; do
      local vfile="${dir}${env}/values-override.yaml"
      if [[ -f "$vfile" ]]; then
        local tag
        tag=$(cd "$repo_path" && git show "origin/main:Helm/${svc}/${env}/values-override.yaml" 2>/dev/null | grep 'tag:' | sed 's/.*tag: *//' | tr -d '"' || true)
        if [[ -z "$tag" || "$tag" == '""' ]]; then
          echo -e "  ${RED}✗ ${svc}/${env}: tag is EMPTY${NC}"
          ((found_empty++))
        fi
      fi
    done
  done

  if [[ $found_empty -eq 0 ]]; then
    echo -e "  ${GREEN}No empty tags found!${NC}"
  else
    echo -e ""
    echo -e "  ${RED}Found ${found_empty} empty tag(s). Fix needed.${NC}"
  fi
}

# ============================================================================
# Main
# ============================================================================

if [[ $# -lt 1 ]]; then
  usage
fi

command="$1"

case "$command" in
  diagnose)
    [[ $# -lt 2 ]] && usage
    diagnose "$2"
    ;;
  fix)
    [[ $# -lt 4 ]] && usage
    fix_variable "$2" "$3" "$4"
    ;;
  fix-and-rerun)
    [[ $# -lt 4 ]] && usage
    fix_and_rerun "$2" "$3" "$4"
    ;;
  verify-fix)
    [[ $# -lt 2 ]] && usage
    verify_fix "$2"
    ;;
  check-repo)
    check_repo
    ;;
  *)
    echo "Unknown command: $command"
    usage
    ;;
esac
