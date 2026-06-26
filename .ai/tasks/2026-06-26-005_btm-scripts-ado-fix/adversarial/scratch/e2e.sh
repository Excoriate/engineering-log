#!/usr/bin/env bash
set -uo pipefail
issues=0
warn() { echo "##vso[task.logissue type=error]azure-boards-add-tag: $*"; issues=1; }
: "${TAG:?Missing TAG environment variable (expected DEV, ACC or PRD)}"
ORG_URL="x"; PROJECT="y"
query_ctx=(q); wi_ctx=(w)

# STUBS (controlled by env): GIT_BODY, QUERY_IDS, QUERY_FAIL, SHOW_FAIL, SHOW_TAGS
git()  { printf '%s' "${GIT_BODY:-}"; }
az() {
  case "$2" in
    query) [[ "${QUERY_FAIL:-0}" == 1 ]] && return 5; printf '%s' "${QUERY_IDS:-}";;
    work-item)
      if [[ "$3" == show ]]; then
        [[ "${SHOW_FAIL:-0}" == 1 ]] && return 7
        printf '%s' "${SHOW_TAGS:-None}"
      else  # update
        echo "  >> UPDATE id-fields: $*"; return 0
      fi;;
  esac
}

work_items=$(git log --format=%B | command grep -F 'Related work items:' | ggrep -Po '\d+' | sort -u | paste -sd, - || true)
if [[ -z "$work_items" ]]; then echo "No related work items; nothing to tag."; exit 0; fi
if ! ids=$(az boards query "${query_ctx[@]}" --wiql "... IN ($work_items)" --query "[].id" -o tsv); then
  warn "WIQL query failed"; echo "##vso[task.complete result=SucceededWithIssues;]query failed"; exit 0
fi
if [[ -z "$ids" ]]; then echo "No BtM work items need '$TAG'."; exit 0; fi
while read -r id; do
  [[ -z "$id" ]] && continue
  current=$(az boards work-item show "${wi_ctx[@]}" --id "$id" --query "..." -o tsv 2>/dev/null)
  [[ "$current" == "None" ]] && current=""
  if [[ -n "$current" && ";$(tr -d ' ' <<<"$current");" == *";${TAG};"* ]]; then echo "WI $id already has '$TAG'; skip."; continue; fi
  new_tags="$TAG"; [[ -n "$current" ]] && new_tags="$current; $TAG"
  echo "WI $id: '$current' -> '$new_tags'"
  if ! az boards work-item update "${wi_ctx[@]}" --id "$id" --fields "System.Tags=$new_tags" --query '...' --output yamlc; then warn "failed to tag $id"; fi
done <<< "$ids"
[[ $issues -ne 0 ]] && echo "##vso[task.complete result=SucceededWithIssues;]some failed"
exit 0
