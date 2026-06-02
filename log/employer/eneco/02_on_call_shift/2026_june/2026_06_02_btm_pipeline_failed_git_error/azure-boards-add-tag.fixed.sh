#!/usr/bin/env bash
#
# azure-boards-add-tag.sh  —  BTM PR work-item auto-tagging (HARDENED, adversarially reviewed)
#
# Adds an environment tag (DEV/ACC/PRD via $TAG) to the Azure DevOps work items referenced
# by the current build's commits ("Related work items:" lines), within the BtM area
# (System.AreaId = 6393). Runs in the BTM deployment pipeline AND locally.
#
# ----------------------------------------------------------------------------------------
# ROOT-CAUSE FIX (2026-06-02)
# ----------------------------------------------------------------------------------------
# `az boards` (the azure-devops CLI) auto-detects org/project/repo from the local git remote
# when --organization/--project are omitted AND its per-remote cache is cold. On an ephemeral
# Microsoft-hosted agent the cache is ALWAYS cold, so EVERY run issues:
#     GET <org>/<project>/_git/<repo>/vsts/info
# which a PROJECT-SCOPED pipeline job token (project setting enforceJobAuthScope=true) is
# denied -> "TF401019: The Git repository ... does not exist or you do not have permissions
# ... 404". Passing --organization/--project/--detect false removes that call deterministically
# (verified cold-cache). The Boards APIs the script actually needs (wiql, work-item update)
# never touch the git repo, so nothing else needs repo access.
#
# This version also fixes two latent bugs the ORIGINAL script hid:
#   * `az boards query` does NOT return System.Tags for a flat query, so the old
#     `read -r id tags` always got tags="" and wrote `System.Tags=; DEV` — REPLACING any
#     existing tags (System.Tags is one ';'-delimited field; a field PATCH overwrites it).
#     We now read each item's CURRENT tags and write the UNION.
#   * the original swallowed every error (no `set -e`, query inside `done < <(...)`), so the
#     tag silently stopped applying with a GREEN build. We surface failures LOUDLY but keep
#     them NON-BLOCKING: the tagging step has no `continueOnError` and a cosmetic tag must
#     never fail a deployment, so we use ADO `SucceededWithIssues` (orange, visible, non-fatal).
#
# Local use:
#     az login                 # interactive; az boards uses this token (no PAT needed)
#     export TAG=DEV
#     cd <a checkout of Eneco.Vpp.BehindTheMeter>
#     ./azure-boards-add-tag.sh
# ----------------------------------------------------------------------------------------
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
#   * `az boards query` needs AND accepts --project (WIQL is project-scoped).
#   * `az boards work-item show/update` do NOT accept --project (work items are org-global by
#     id) — passing it fails with "unrecognized arguments: --project". They take --org only.
# Both use --detect false to skip the git-remote auto-detection that caused TF401019.
query_ctx=(--organization "$ORG_URL" --project "$PROJECT" --detect false)   # array keeps the space in "Myriad - VPP" intact
wi_ctx=(--organization "$ORG_URL" --detect false)

# Work item IDs referenced by the build's commit messages.
work_items=$(git log --format=%B | grep -F 'Related work items:' | grep -Po '\d+' \
  | sort -u | paste -sd, - || true)
if [[ -z "$work_items" ]]; then
  echo "No 'Related work items:' found in commit messages; nothing to tag."
  exit 0
fi

# Candidate IDs only (a flat WIQL query reliably returns ids; it does NOT return tag values).
if ! ids=$(az boards query "${query_ctx[@]}" \
  --wiql "SELECT [System.Id] FROM workitems WHERE [System.AreaId] = 6393 AND [System.Tags] NOT CONTAINS '$TAG' AND [System.Id] IN ($work_items)" \
  --query "[].id" -o tsv); then
  warn "WIQL query failed (auth/scope/availability) — see error above"
  echo "##vso[task.complete result=SucceededWithIssues;]Tagging skipped (query failed; non-blocking)"
  exit 0
fi
if [[ -z "$ids" ]]; then
  echo "No BtM work items need the '$TAG' tag."
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
