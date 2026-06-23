---
task_id: 2026-06-22-010
agent: ado-static-artifact-fetcher
status: complete
summary: Byte-exact ADO artifacts for BTM tagging RCA — tagging script @main/@fix-tagging (identical), deploy pipeline tag-steps, fix/tagging Experiment commit, PR 178802 (B2B) pool-switch diff. Pure retrieval; no diagnosis.
---

# Static ADO Artifacts — BTM Tagging RCA (verbatim)

**Org**: `https://dev.azure.com/enecomanagedcloud` | **Project**: `Myriad - VPP`
**Identity used**: `Alex.Torres@eneco.com` (subscription default: Eneco Cloud Foundation - Sandbox-Development-Test)
**Mode**: READ-ONLY. All content below is verbatim from `az devops invoke ... --out-file` then file read. No interpretation.

## Repo identity (A1 FACT)

```text
az repos show --repository Eneco.Vpp.BehindTheMeter --project "Myriad - VPP" --org https://dev.azure.com/enecomanagedcloud
  -> id 718866fa-75c4-48d9-af82-9cf23a3d5b8c, defaultBranch refs/heads/main

az repos show --repository Eneco.Vpp.BehindTheMeter.B2B --project "Myriad - VPP" --org https://dev.azure.com/enecomanagedcloud
  -> id 5bb311ec-b20c-42c1-9139-d36e1c4aab0f, defaultBranch refs/heads/main
```

Branch objectIds in BTM repo (A1 FACT, `az repos ref list --filter heads`):

```text
refs/heads/main         11cdc0cd28bb
refs/heads/fix/tagging  abba2c37dc82   (head commit = "Experiment", full hash abba2c37dc82d56d3f71bfa8015e4e3ea3a3519e, parent 9b2b2c15e6d9f7911461709d85d47d34aa5960cf)
```

---

## ARTIFACT 1 — `azure-pipelines/steps/azure-boards-add-tag.sh` @ branch `main` (repo Eneco.Vpp.BehindTheMeter)

Retrieval command:

```bash
az devops invoke --area git --resource items \
  --route-parameters project="Myriad - VPP" repositoryId=Eneco.Vpp.BehindTheMeter \
  --query-parameters path=/azure-pipelines/steps/azure-boards-add-tag.sh '$format=text' includeContent=true \
  --api-version 7.1 --org https://dev.azure.com/enecomanagedcloud --out-file <out>
# EXIT 0; 865 bytes; md5 836f7c8656d83f7dcbf88cab166ba66b
```

Verbatim content:

```bash
#!/usr/bin/env bash

if [[ -z "$TAG" ]]; then
  echo "Missing TAG environment variable"
fi

# get work items IDs from the commits
work_items=$(git log --format=%B | grep 'Related work items:' | grep -Po '\d+' | sort | uniq | paste -sd, -)

# WIQL query to get work items ID with the tags not containing $TAG
query=$(cat <<- END
  SELECT System.Id, System.Tags
  FROM workitems
  WHERE System.AreaId = 6393
    AND System.Tags NOT CONTAINS '$TAG'
    AND System.Id IN ($work_items)
END
)

while read -r work_item_id tags ; do
  echo "Adding '$TAG' tag to work item $work_item_id with existing tags '$tags'"

  az boards work-item update \
    --id "$work_item_id" \
    --field "System.Tags=$tags; $TAG" \
    --output yamlc \
    --query '[fields."System.Title", fields."System.Tags"]'

  echo
done <  <(az boards query --wiql "$query" --output table | tail -n +3)
```

---

## ARTIFACT 2 — SAME file @ branch `fix/tagging` (repo Eneco.Vpp.BehindTheMeter)

Retrieval command:

```bash
az devops invoke --area git --resource items \
  --route-parameters project="Myriad - VPP" repositoryId=Eneco.Vpp.BehindTheMeter \
  --query-parameters path=/azure-pipelines/steps/azure-boards-add-tag.sh '$format=text' includeContent=true \
    'versionDescriptor.versionType=branch' 'versionDescriptor.version=fix/tagging' \
  --api-version 7.1 --org https://dev.azure.com/enecomanagedcloud --out-file <out>
# EXIT 0; 865 bytes; md5 836f7c8656d83f7dcbf88cab166ba66b
```

**DIFF vs main = NONE. The file is byte-identical on `main` and `fix/tagging`** (`diff` reports no difference; md5 identical). The `fix/tagging` branch does NOT contain `--detect false` or extra debug output **in this script file**. (Fact, `diff` + `md5` on the two retrieved files.)

The change the user is testing on `fix/tagging` is NOT in `azure-boards-add-tag.sh` — it is in `deploy-terraform.pipeline.yml` (see ARTIFACT 3b below; the fix/tagging head commit "Experiment" edits only `/azure-pipelines` and `/azure-pipelines/deploy-terraform.pipeline.yml`, confirmed via `az devops invoke --area git --resource changes commitId=abba2c37dc82d56d3f71bfa8015e4e3ea3a3519e`).

---

## ARTIFACT 3 — `azure-pipelines/deploy-terraform.pipeline.yml` (repo Eneco.Vpp.BehindTheMeter)

### 3a — @ branch `main` (141 lines, EXIT 0)

Retrieval command:

```bash
az devops invoke --area git --resource items \
  --route-parameters project="Myriad - VPP" repositoryId=Eneco.Vpp.BehindTheMeter \
  --query-parameters path=/azure-pipelines/deploy-terraform.pipeline.yml '$format=text' includeContent=true \
  --api-version 7.1 --org https://dev.azure.com/enecomanagedcloud --out-file <out>
```

Verbatim full content (@main):

```yaml
trigger:
  branches:
    include:
      - main
  paths:
    include:
      - src/*
      - terraform/*
      - data/adx/*

parameters:
  - name: forceRedeploy
    displayName: Redeploy all services
    type: boolean
    default: false

pool:
  vmImage: ubuntu-24.04

stages:
  - stage: Build
    jobs:
      - job: Build
        displayName: Build Artefacts
        steps:
          - task: UsePythonVersion@0
            inputs:
              versionSpec: "3.11"
              addToPath: true
          - template: ./steps/dot-net-build-ci-solution.yml
            parameters:
              solutionFilePath: src/Eneco.Vpp.BehindTheMeter.sln
              skipTests: true
          - pwsh: |
              Set-PSDebug -Trace 1
              ./terraform/scripts/build_zip.ps1 -NoBuild `
                -ArtifactsPath '$(Build.ArtifactStagingDirectory)' `
                -ForceRedeploy:$${{ parameters.forceRedeploy }}
            displayName: Build zip deployment packages
          - publish: $(Build.ArtifactStagingDirectory)
            displayName: Publish zip deployment packages
            artifact: zip_deploy

  - stage: Development
    dependsOn: Build
    jobs:
      - deployment: ApplyDevelopment
        displayName: Apply Development
        environment: btm-development
        variables:
          - group: eneco-btm-dta-lz
          - group: eneco-btm-deployment-dev
        strategy:
          runOnce:
            deploy:
              steps:
                - checkout: self
                  fetchDepth: 10
                - template: steps/azure-login.yml
                - template: steps/terraform.yml
                  parameters:
                    command: apply
                - script: ./azure-pipelines/steps/azure-boards-add-tag.sh
                  env:
                    AZURE_DEVOPS_EXT_PAT: $(System.AccessToken)
                    TAG: DEV
                  displayName: Add DEV tag in ADO

      - job: PlanAcceptance
        displayName: Plan Acceptance
        variables:
          - group: eneco-btm-dta-lz
          - group: eneco-btm-deployment-acc
        steps:
          - template: steps/azure-login.yml
          - template: steps/terraform.yml
            parameters:
              command: plan

  - stage: Acceptance
    dependsOn: Development
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    jobs:
      - deployment: ApplyAcceptance
        displayName: Apply Acceptance
        environment: btm-acceptance
        variables:
          - group: eneco-btm-dta-lz
          - group: eneco-btm-deployment-acc
        strategy:
          runOnce:
            deploy:
              steps:
                - checkout: self
                  fetchDepth: 100
                - template: steps/azure-login.yml
                - template: steps/terraform.yml
                  parameters:
                    command: apply
                - script: ./azure-pipelines/steps/azure-boards-add-tag.sh
                  env:
                    AZURE_DEVOPS_EXT_PAT: $(System.AccessToken)
                    TAG: ACC
                  displayName: Add ACC tag in ADO

      - job: PlanProduction
        displayName: Plan Production
        variables:
          - group: eneco-btm-prd-lz
          - group: eneco-btm-deployment-prd
        steps:
          - template: steps/azure-login.yml
          - template: steps/terraform.yml
            parameters:
              command: plan

  - stage: Production
    dependsOn: Acceptance
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    jobs:
      - deployment: ApplyProduction
        displayName: Apply Production
        environment: btm-production
        variables:
          - group: eneco-btm-prd-lz
          - group: eneco-btm-deployment-prd
        strategy:
          runOnce:
            deploy:
              steps:
                - checkout: self
                  fetchDepth: 100
                - template: steps/azure-login.yml
                - template: steps/terraform.yml
                  parameters:
                    command: apply
                - script: ./azure-pipelines/steps/azure-boards-add-tag.sh
                  env:
                    AZURE_DEVOPS_EXT_PAT: $(System.AccessToken)
                    TAG: PRD
                  displayName: Add PRD tag in ADO
```

**Identity/token per environment (verbatim from @main):** ALL THREE tag steps (DEV/ACC/PRD) run as the LAST step INSIDE the `runOnce.deploy` block of the `deployment:` job, using:

```yaml
                - script: ./azure-pipelines/steps/azure-boards-add-tag.sh
                  env:
                    AZURE_DEVOPS_EXT_PAT: $(System.AccessToken)
                    TAG: DEV | ACC | PRD
```

i.e. each environment's tag step uses `AZURE_DEVOPS_EXT_PAT: $(System.AccessToken)` (the pipeline's own job access token) and inherits the pipeline-level `pool: vmImage: ubuntu-24.04` (lines 17-18). No per-tag-step `pool:` override exists on `main`.

### 3b — @ branch `fix/tagging` (145 lines, EXIT 0) — the "Experiment"

Retrieval command (same as 3a + `versionDescriptor.versionType=branch versionDescriptor.version=fix/tagging`).

DIFF vs `main` (`diff main fix/tagging`), verbatim. The Experiment commit (abba2c37dc82d56d3f71bfa8015e4e3ea3a3519e) does the following:

1. Comments out (with leading `#`) the entire `Build` stage, `PlanAcceptance` job, `Acceptance` stage, `PlanProduction` job, and `Production` stage.
2. Comments out `dependsOn: Build` on the `Development` stage.
3. In `ApplyDevelopment` → comments out the `terraform.yml apply` template step and INSERTS a new inline debug script BEFORE the existing `azure-boards-add-tag.sh` step.

The effective (uncommented) `Development` stage on `fix/tagging` reads verbatim:

```yaml
stages:
#  - stage: Build
#    ... (entire Build stage commented out) ...

  - stage: Development
#    dependsOn: Build
    jobs:
      - deployment: ApplyDevelopment
        displayName: Apply Development
        environment: btm-development
        variables:
          - group: eneco-btm-dta-lz
          - group: eneco-btm-deployment-dev
        strategy:
          runOnce:
            deploy:
              steps:
                - checkout: self
                  fetchDepth: 10
                - template: steps/azure-login.yml
#                - template: steps/terraform.yml
#                  parameters:
#                    command: apply
                - script: |
                    set -x
                    query='SELECT [System.Id] ,[System.Title] FROM workitems WHERE [System.AreaId] = 6393'
                    az boards query --debug --wiql "$query" --organization https://dev.azure.com/enecomanagedcloud/ --project 6393
                - script: ./azure-pipelines/steps/azure-boards-add-tag.sh
                  env:
                    AZURE_DEVOPS_EXT_PAT: $(System.AccessToken)
                    TAG: DEV
                  displayName: Add DEV tag in ADO

#      - job: PlanAcceptance
#        ... (everything below Development commented out) ...
```

Note (verbatim observation, not diagnosis): the inserted experiment runs `az boards query --debug` with `set -x`. There is NO `--detect false` token anywhere in the fix/tagging pipeline or script. The tag step itself still runs inside the `runOnce.deploy` block (NOT moved to a separate pool job).

---

## ARTIFACT 4 — PR 178802 (repo Eneco.Vpp.BehindTheMeter.B2B)

Retrieval commands:

```bash
az repos pr show --id 178802 --org https://dev.azure.com/enecomanagedcloud
az devops invoke --area git --resource changes \
  --route-parameters project="Myriad - VPP" repositoryId=Eneco.Vpp.BehindTheMeter.B2B \
  commitId=6f37c5fcd7344f9c46f662021d4d143524343944 --api-version 7.1 --org ...
az devops invoke --area git --resource items ... versionDescriptor.versionType=commit version=<src|tgt>
```

PR metadata (A1 FACT, `az repos pr show`):

```text
title:         Fix tag apply for dev/acc/prd
status:        completed
sourceRefName: refs/heads/fix/789378-automatic-story-tagging
targetRefName: refs/heads/main
repo:          Eneco.Vpp.BehindTheMeter.B2B
description:   - Fixed application of tags to our stories by changing the pool that the job for tagging is ran on.
source commit (after): 2d10cb94d66ba32e41e07f2ab88898fe36f18364
target base (before):  eb6575697fa288e38c146ff95b31a960d33edfd9
merge commit:          6f37c5fcd7344f9c46f662021d4d143524343944
```

Changed files in PR 178802 (A1 FACT, `--resource changes`):

```text
edit /azure-pipelines/deploy-terraform.pipeline.yml
```

**The exact change (BEFORE = target base eb6575697fa2, AFTER = source 2d10cb94d66b), `diff before after` verbatim:**

```diff
58d57
<                   fetchDepth: 10
63,68d61
<                 - script: ./azure-pipelines/steps/azure-boards-add-tag.sh
<                   env:
<                     AZURE_DEVOPS_EXT_PAT: $(System.AccessToken)
<                     TAG_SUFFIX: -BTM
<                     TAG_ENVIRONMENT: DEV
<                   displayName: Add DEV-BTM tag in ADO
80a74,86
>       - job: ApplyTagDevelopment
>         pool: sre-managed-linux
>         dependsOn: ApplyDevelopment
>         steps:
>           - checkout: self
>             fetchDepth: 10
>           - script: ./azure-pipelines/steps/azure-boards-add-tag.sh
>             env:
>               AZURE_DEVOPS_EXT_PAT: $(System.AccessToken)
>               TAG_SUFFIX: -BTM
>               TAG_ENVIRONMENT: DEV
>             displayName: Add DEV-BTM tag in ADO
97d102
<                   fetchDepth: 100
102,107d106
<                 - script: ./azure-pipelines/steps/azure-boards-add-tag.sh
<                   env:
<                     AZURE_DEVOPS_EXT_PAT: $(System.AccessToken)
<                     TAG_SUFFIX: -BTM
<                     TAG_ENVIRONMENT: ACC
<                   displayName: Add ACC-BTM tag in ADO
119a119,131
>       - job: ApplyTagAcceptance
>         pool: sre-managed-linux
>         dependsOn: ApplyAcceptance
>         steps:
>           - checkout: self
>             fetchDepth: 100
>           - script: ./azure-pipelines/steps/azure-boards-add-tag.sh
>             env:
>               AZURE_DEVOPS_EXT_PAT: $(System.AccessToken)
>               TAG_SUFFIX: -BTM
>               TAG_ENVIRONMENT: ACC
>             displayName: Add ACC-BTM tag in ADO
135d146
<                   fetchDepth: 100
140,145c151,163
<                 - script: ./azure-pipelines/steps/azure-boards-add-tag.sh
<                   env:
<                     AZURE_DEVOPS_EXT_PAT: $(System.AccessToken)
<                     TAG_SUFFIX: -BTM
<                     TAG_ENVIRONMENT: PRD
<                   displayName: Add PRD-BTM tag in ADO
---
>
>       - job: ApplyTagProduction
>         pool: sre-managed-linux
>         dependsOn: ApplyProduction
>         steps:
>           - checkout: self
>             fetchDepth: 100
>           - script: ./azure-pipelines/steps/azure-boards-add-tag.sh
>             env:
>               AZURE_DEVOPS_EXT_PAT: $(System.AccessToken)
>               TAG_SUFFIX: -BTM
>               TAG_ENVIRONMENT: PRD
>             displayName: Add PRD-BTM tag in ADO
```

**What PR 178802 changed (verbatim, no interpretation beyond reading the diff):** for each of DEV / ACC / PRD, the tag step was REMOVED from inside the `deployment` job's `runOnce.deploy.steps` block and RE-ADDED as a separate top-level `job:` (`ApplyTagDevelopment` / `ApplyTagAcceptance` / `ApplyTagProduction`) with:
- `pool: sre-managed-linux` (explicit pool, distinct from the pipeline-level `pool: vmImage: ubuntu-24.04`)
- `dependsOn: ApplyDevelopment | ApplyAcceptance | ApplyProduction`
- `checkout: self` + `fetchDepth: 10` (DEV) / `100` (ACC, PRD)
- identical `script` + `env` (`AZURE_DEVOPS_EXT_PAT: $(System.AccessToken)`, `TAG_SUFFIX: -BTM`, `TAG_ENVIRONMENT: <env>`)

i.e. the only behavioral change is: the tagging step now runs in its OWN job on `pool: sre-managed-linux` instead of inline within the deployment job (which inherited `vmImage: ubuntu-24.04`).

---

## SUPPORTING — B2B `azure-boards-add-tag.sh` @ main (env-var contract differs from BTM)

The B2B pipeline (ARTIFACT 4) passes `TAG_SUFFIX` + `TAG_ENVIRONMENT`, NOT `TAG`. The B2B repo's copy of the script (different from the BTM-repo ARTIFACT 1 script) confirms this — included for the lead since the env-var contract differs.

Retrieval: `az devops invoke --area git --resource items repositoryId=Eneco.Vpp.BehindTheMeter.B2B path=/azure-pipelines/steps/azure-boards-add-tag.sh ... main` (EXIT 0, 40 lines).

```bash
#!/usr/bin/env bash

if [[ -z "$TAG_ENVIRONMENT" ]]; then
  echo "Missing TAG_ENVIRONMENT environment variable"
fi

if [[ -z "$TAG_SUFFIX" ]]; then
  echo "Missing TAG_SUFFIX environment variable"
fi

# get work items IDs from the commits
work_items=$(git log --format=%B | grep 'Related work items:' | grep -Po '\d+' | sort | uniq | paste -sd, -)

team_agg_area_id=4928

# WIQL query to get work items ID with the tags not containing $TAG_ENVIRONMENT$TAG_SUFFIX
query=$(cat <<- END
  SELECT System.Id, System.Tags
  FROM workitems
  WHERE System.AreaId = $team_agg_area_id
    AND System.Tags NOT CONTAINS '$TAG_ENVIRONMENT$TAG_SUFFIX'
    AND System.Id IN ($work_items)
END
)

# Echo query
echo "WIQL query:"
echo "$query"
echo

while read -r work_item_id tags ; do
  echo "Adding '$TAG_ENVIRONMENT$TAG_SUFFIX' tag to work item $work_item_id with existing tags '$tags'"

  az boards work-item update \
    --id "$work_item_id" \
    --field "System.Tags=$tags; $TAG_ENVIRONMENT$TAG_SUFFIX" \
    --output yamlc \
    --query '[fields."System.Title", fields."System.Tags"]'

  echo
done <  <(az boards query --wiql "$query" --output table | tail -n +3)
```

Verbatim difference vs BTM ARTIFACT 1 script (factual, from the two files):
- BTM script: env var `TAG`; hardcoded `System.AreaId = 6393`; no query echo.
- B2B script: env vars `TAG_ENVIRONMENT` + `TAG_SUFFIX`; `team_agg_area_id=4928`; echoes the WIQL query before running.

---

## Retrieval ledger (all EXIT 0)

| # | Artifact | Command resource | Result |
|---|----------|------------------|--------|
| 1 | BTM tag script @main | git/items branch=main | 865 B, md5 836f7c86... |
| 2 | BTM tag script @fix/tagging | git/items branch=fix/tagging | 865 B, md5 836f7c86... — IDENTICAL to main |
| 3a | BTM pipeline @main | git/items branch=main | 141 lines |
| 3b | BTM pipeline @fix/tagging | git/items branch=fix/tagging + git/changes commitId=abba2c37... | 145 lines; Experiment edits ONLY this yml |
| 4 | PR 178802 (B2B) | repos pr show + git/changes + git/items commit src/tgt | changed 1 file; pool switch to sre-managed-linux in separate jobs |
| + | B2B tag script @main | git/items repositoryId=...B2B branch=main | 40 lines; TAG_SUFFIX/TAG_ENVIRONMENT, AreaId 4928 |

No artifact was unreachable. No content fabricated. Subagent output = INFER until source-verified by lead against the commands above.
