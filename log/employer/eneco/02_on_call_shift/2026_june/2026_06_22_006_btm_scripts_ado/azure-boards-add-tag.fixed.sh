#!/usr/bin/env bash
#
# azure-boards-add-tag.sh — BTM PR work-item auto-tagging (HARDENED)
#
# Adds an environment tag (DEV/ACC/PRD via $TAG) to the Azure DevOps work items referenced by
# the current build's commits ("Related work items:" lines), within the BtM area
# (System.AreaId = 6393).
#
# ----------------------------------------------------------------------------------------------
# IMPORTANT — IDENTITY (the real fix lives in the pipeline YAML, not here):
#   This script must run in a pipeline job that does NOT perform `az login` (no azure-login.yml).
#   When an `az login` session exists on the agent, the azure-devops CLI uses it IN PREFERENCE
#   to AZURE_DEVOPS_EXT_PAT — so a job that logs in as the deployment service principal would
#   make `az boards` run as that SP, which lacks "View/Edit work items in this node" on Team BtM.
#   Run this in its own job (env: AZURE_DEVOPS_EXT_PAT=$(System.AccessToken), NO azure-login),
#   so `az boards` authenticates as the project Build Service identity, which CAN read+tag.
#
# ROOT-CAUSE HARDENING also fixes two latent bugs in the original:
#   * `az boards query` auto-detected the repo via /vsts/info (cold cache on ephemeral agents)
#     and was denied -> TF401019. We pass --organization/--project/--detect false to remove it.
#   * The original swallowed all errors (no set -e, query inside `done < <(...)`) -> silent green,
#     and wrote `System.Tags=; $TAG`, CLOBBERING existing tags. We surface failures loudly but
#     non-blockingly (SucceededWithIssues) and write the tag UNION.
#
# Local use (read-only inspection): az login; export TAG=DEV; cd <a checkout of the repo>; ./this.sh
# ----------------------------------------------------------------------------------------------
set -uo pipefail   # deliberately NOT -e: a cosmetic tagging failure must be loud, never deploy-blocking

issues=0
warn() {                       # loud (shows in build summary) but non-blocking (exit stays 0)
  echo "##vso[task.logissue type=error]azure-boards-add-tag: $*"
  issues=1
}

: "${TAG:?Missing TAG environment variable (expected DEV, ACC or PRD)}"

ORG_URL="${SYSTEM_COLLECTIONURI:-https://dev.azure.com/enecomanagedcloud/}"
PROJECT="${SYSTEM_TEAMPROJECT:-Myriad - VPP}"

# Two contexts on purpose:
#   * `az boards query`            needs AND accepts --project (WIQL is project-scoped).
#   * `az boards work-item show/update` do NOT accept --project (work items are org-global by id);
#     passing it fails "unrecognized arguments: --project". They take --org only.
# Both use --detect false to skip the git-remote auto-detection that caused TF401019.
query_ctx=(--organization "$ORG_URL" --project "$PROJECT" --detect false)
wi_ctx=(--organization "$ORG_URL" --detect false)

# Work item IDs referenced by the build's commit messages.
work_items=$(git log --format=%B | grep -F 'Related work items:' | grep -Po '\d+' \
  | sort -u | paste -sd, - || true)
if [[ -z "$work_items" ]]; then
  echo "No 'Related work items:' found in commit messages; nothing to tag."
  exit 0
fi

# Candidate IDs only (a flat WIQL query reliably returns ids; it does NOT return tag values).
# Empty IN-list guarded above: an empty `IN ()` is a WIQL parse error, not a no-op.
if ! ids=$(az boards query "${query_ctx[@]}" \
  --wiql "SELECT [System.Id] FROM workitems WHERE [System.AreaId] = 6393 AND [System.Tags] NOT CONTAINS '$TAG' AND [System.Id] IN ($work_items)" \
  --query "[].id" -o tsv); then
  warn "WIQL query failed (auth/scope/availability) — see error above. \
If this is an empty result rather than an error, check the calling identity has 'View work items in this node' on Team BtM."
  echo "##vso[task.complete result=SucceededWithIssues;]Tagging skipped (query failed; non-blocking)"
  exit 0
fi
if [[ -z "$ids" ]]; then
  echo "No BtM work items need the '$TAG' tag (already tagged, or none matched)."
  exit 0
fi

while read -r id; do
  [[ -z "$id" ]] && continue

  # Read current tags so we write the UNION (existing + $TAG) and never clobber.
  current=$(az boards work-item show "${wi_ctx[@]}" --id "$id" \
    --query "fields.\"System.Tags\"" -o tsv 2>/dev/null)
  [[ "$current" == "None" ]] && current=""

  # Defensive exact-match skip (WIQL NOT CONTAINS is a substring match).
  if [[ -n "$current" && ";$(tr -d ' ' <<<"$current");" == *";${TAG};"* ]]; then
    echo "Work item $id already has '$TAG'; skipping."
    continue
  fi

  new_tags="$TAG"; [[ -n "$current" ]] && new_tags="$current; $TAG"
  echo "Work item $id: '$current' -> '$new_tags'"
  if ! az boards work-item update "${wi_ctx[@]}" --id "$id" \
        --fields "System.Tags=$new_tags" \
        --query '[fields."System.Title", fields."System.Tags"]' --output yamlc; then
    warn "failed to tag work item $id"
  fi
  echo
done <<< "$ids"

if [[ $issues -ne 0 ]]; then
  echo "##vso[task.complete result=SucceededWithIssues;]One or more work items could not be tagged (non-blocking)"
fi
exit 0
