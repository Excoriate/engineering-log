---
title: "PR description — BTM tag step runs as Build Service identity"
status: complete
timestamp: 2026-06-26T00:00:00Z
task_id: 2026-06-26-005
agent: claude-opus-4-8
summary: "Final PR description for the BTM auto-tagging fix (identity relocation + hardened script), post adversarial receipts."
---

# Fix BTM PR auto-tagging — run the tag step as the Build Service identity (own job, no SP login)

## Summary

The post-deploy step that stamps `DEV`/`ACC`/`PRD` tags on the linked Azure Boards work items stopped applying tags — the pipeline stayed green while the tags silently never appeared. This PR makes tagging run as the project **Build Service identity** (which can read/write Team BtM work items) and hardens the tag script so it tags the right items, never clobbers existing tags, and never blocks a deploy.

## Root cause

Each deployment job runs `azure-login.yml` → `az login --service-principal` (`mcc-btm-deployment-dta-sp`) so Terraform can deploy. The inline tag step then set `AZURE_DEVOPS_EXT_PAT=$(System.AccessToken)` intending to call `az boards` as the Build Service identity. But **when an `az login` session already exists on the agent, the azure-devops CLI uses it in preference to `AZURE_DEVOPS_EXT_PAT`** — so `az boards` actually ran as the deployment SP. That SP lacks *View/Edit work items* on Team BtM (area 6393), producing two symptoms from one cause: the repo-context auto-detect (`/vsts/info`) was denied → `TF401019`, and once suppressed the work-item query returned an empty set. The original script swallowed both errors (no `set -e`, query inside `done < <( … )`) → green build, zero tags.

## What changed

**1. `azure-pipelines/deploy-terraform.pipeline.yml` — tagging moved to its own job (the operative fix)**

For each environment, the inline tag step was removed from the `deployment` job and placed in a sibling `job` (`ApplyTagDevelopment` / `ApplyTagAcceptance` / `ApplyTagProduction`) that:

- does **not** run `azure-login.yml` → no `az login` session → `az boards` uses the only credential present, `AZURE_DEVOPS_EXT_PAT=$(System.AccessToken)` = the **Build Service identity**, which has board read/write;
- `dependsOn` the matching deploy job (only tags a successful deploy);
- has **no `pool:` override** → inherits the existing `ubuntu-24.04` Microsoft-hosted pool → **no extra/paid runner**.

**2. `azure-pipelines/steps/azure-boards-add-tag.sh` — hardened**

- **Identity-safe** by design (must run in a job without `az login`; documented in the header).
- Passes `--organization/--project/--detect false` to `az boards query` (no `/vsts/info` auto-detect → no `TF401019`); `--organization/--detect false` to `work-item show/update` (they reject `--project`).
- **Scopes work-item harvest to the triggering commit** (`git log -1`, the PR merge/squash commit) and extracts only `#NNN` ids — the original walked the whole shallow checkout and would tag work items from dozens of unrelated PRs.
- Reads each item's current tags and writes the **union**; if that read fails, it **skips the item** rather than clobbering its existing tags.
- Guards the empty work-item list (an empty `IN ()` is a WIQL parse error).
- Surfaces failures with `##vso[task.logissue]` + `SucceededWithIssues` — loud but **non-blocking**; a cosmetic tag must never fail a deployment (including a missing `TAG`).

## Why this matches the Aggregation team's fix (and needs no second runner)

The sibling `Eneco.Vpp.BehindTheMeter.B2B` team fixed the same break in PR 178802 by moving tagging into a separate job. The operative change there was that the separate job **drops `azure-login.yml`** (so the Build Service token is used); the runner-pool switch was incidental. This PR achieves the same identity change on the **same** pool — directly addressing the cost concern about a second runner.

## Testing / acceptance (never trust the green build)

After this merges and a deploy runs on a branch whose commits reference a Team BtM work item:

1. The `Add DEV tag in ADO` job log shows `Work item <id>: … -> 'DEV'` and **no `TF401019`**.
2. Assert the realized state:
   ```bash
   az boards work-item show --org https://dev.azure.com/enecomanagedcloud --detect false \
     --id <work_item_id> --query "fields.\"System.Tags\""
   # GO = output contains DEV (and any tags it had before)
   ```

The script logic was validated locally with a stubbed `az`/`git` harness (GNU grep): scoped harvest, tag-union with no clobber, clobber-skip on read failure, and non-blocking on missing `TAG` all behave as intended.

## Risk / rollback

- **Blast radius:** operational-visibility only (board tags). No customer/trading impact. Tagging is non-blocking by design, so even a regression cannot fail a deploy.
- **Rollback:** revert this PR; tagging returns to its prior (silently non-functional) state with no deploy impact.

## Scope

- Touches only `Eneco.Vpp.BehindTheMeter` (B2C). **Do not** touch `Eneco.Vpp.BehindTheMeter.B2B` (already fixed, PR 178802).
- Does **not** change the deployment SP's permissions, the Terraform deploy path, or any environment/approval gates.

## References

- RCA: `log/employer/eneco/02_on_call_shift/2026_june/2026_06_22_006_btm_scripts_ado/rca.md`
- Live-verified evidence (identity precedence, Build Service ACL bitmask): task `2026-06-22-010`.
