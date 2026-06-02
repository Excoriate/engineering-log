## Slack Metadata

- Channel: `#Myriad-platform`
- Message: https://grid-eneco.enterprise.slack.com/lists/T039G7V20/F0ACUPDV7HU?record_id=Rec0B7Q9NNJDP

## Original Request Message

1) Project/Repo Eneco.Vpp.BehindTheMeter 2) Pipeline URL: https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_build/results?buildId=1663945&view=logs&j=29353514-b51d-5f70-0533-61c3d5c33a42&t=09a3d06a-483e-5550-39c7-23eb7b3ab59f 3) Priority: :bufo-goose-hat-happy-dance: I can wait a couple of days, 4)If bug:
ERROR: TF401019: The Git repository with name or identifier eneco.vpp.behindthemeter does not exist or you do not have permissions for the operation you are attempting.  Operation returned a 404 status code.
 5) Details:
We have a pipeline that adds DEV/ACC/PRD tag to the ticket attached to PR when it's deployed to a corresponding environment. This pipeline worked for long time but it started failing some time ago (weeks or months).
Could you help us to figure out why this started happening?
And could you fix it for us if it's not too much work for you?

here is the script itself azure-boards-add-tag.sh - Repos
https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/Eneco.Vpp.BehindTheMeter?path=%2Fazure-pipelines%2Fsteps%2Fazure-boards-add-tag.sh
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
Agg team uses the same pipeline, and they (@niels.witte) fixed the issue by switching to the Azure runner provided by the Core Platform team.
I just wanted to check with you (VPP Platform team) whether it's the only option for us or it can be fixed differently.
I'd like to avoid splitting our deployment job between two different runners because my intuition says it would increase the overall cost for Eneco
Niels asnwer with:
Here's what we did to fix it :slightly_smiling_face:

https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/Eneco.Vpp.BehindTheMeter.B2B/pullrequest/178802?_a=files

### UAC

- You have to use, at the end when there's full confidence of the result obtained, the `how-to-feynman`skill, so it's explained in a .md document what you did, how, why, etc. So, I learn. I must be able to understand deeply your rationale, and replicate it by myself. If not, it's a failure.

- Ensure the script can be tested locally, so I can inspect it. If the solution requires ADO, it must be specified in the .md document.
