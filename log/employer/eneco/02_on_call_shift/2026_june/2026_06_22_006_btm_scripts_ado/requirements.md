Slack Requests:
- https://grid-eneco.enterprise.slack.com/lists/T039G7V20/F0ACUPDV7HU?record_id=Rec0B7Q9NNJDP

New Slack Request raised (with the same topic)
- https://grid-eneco.enterprise.slack.com/lists/T039G7V20/F0ACUPDV7HU?record_id=Rec0BAXLXUTT2

1) Project/Repo BtM B2C 2) Pipeline URL: https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_build/results?buildId=1676583&view=logs&j=29353514-b51d-5f70-0533-61c3d5c33a42&t=09a3d06a-483e-5550-39c7-23eb7b3ab59f&l=14 3) Priority: :bufo-crying: This is blocking me, 4)If bug:

It is a follow up on this request.

 5) Details:
Our pipeline running under mcc-btm-deployment-dta-sp  identity lost access to our ADO Boards - it cannot see and update the workitems in our space in ADO Boards

Apparently things broke around the time someone/something addedd a mcc-btm-deployment-dta-sp to devops users on 22nd of April. Because our production pipeline running under mcc-btm-deployment-prd-sp still has access to ADO boards (and there is no an ADO user with such name.

Do you know why mcc-btm-deployment-dta-sp  user was created in ADO?
• If it's needed, could you configure it properly?
• if ti's not needed could you try deleting it?

1) Project/Repo Eneco.Vpp.BehindTheMeter 2) Pipeline URL: https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_build/results?buildId=1663945&view=logs&j=29353514-b51d-5f70-0533-61c3d5c33a42&t=09a3d06a-483e-5550-39c7-23eb7b3ab59f 3) Priority: :bufo-goose-hat-happy-dance: I can wait a couple of days, 4)If bug:
ERROR: TF401019: The Git repository with name or identifier eneco.vpp.behindthemeter does not exist or you do not have permissions for the operation you are attempting.  Operation returned a 404 status code.
 5) Details:
We have a pipeline that adds DEV/ACC/PRD tag to the ticket attached to PR when it's deployed to a corresponding environment. This pipeline worked for long time but it started failing some time ago (weeks or months).
Could you help us to figure out why this started happening?
And could you fix it for us if it's not too much work for you?

history of the conversation:
Anton Kultsov  [9:59 AM]
here is the script itself azure-boards-add-tag.sh - Repos
[10:01 AM]Agg team uses the same pipeline, and they (@niels.witte) fixed the issue by switching to the Azure runner provided by the Core Platform team.
I just wanted to check with you (VPP Platform team) whether it's the only option for us or it can be fixed differently.
I'd like to avoid splitting our deployment job between two different runners because my intuition says it would increase the overall cost for EnecoAlex Torres  [10:03 AM]
Hello @anton,
Allow me some moments to take a look, and troubleshoot it.Anton Kultsov  [10:06 AM]
hi Alex, thank you for looking into it!
just in case, it's not an urgent request. Please take your timeNiels Witte  [10:12 AM]
Here's what we did to fix it :slightly_smiling_face:

https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/Eneco.Vpp.BehindTheMeter.B2B/pullrequest/178802?_a=files
spsprodweu2.vssps.visualstudio.comAzure DevOps Services | Sign InAlex Torres  [10:40 AM]
@anton,
This was interesting — regardless that it was fixed, I think it’s important to understand why it occur.

First, in order to call any ADO API, it’s required to pass organization and project context. Always, non-negotiable. If it’s not passed as --organization and --project explicitly, it’s auto-detected. Here’s where things get interesting. The way that it auto-detects it is by reading the checkout’s git config remote.origin.url, then calls GET <org>/<project>/_git/<repo>/vsts/info to resolve which org/project/repo that remote is. The answer is cached in ~/.azure/azuredevops/cache/remotes.json.

You’re using the ephemeral Microsoft-hosted agents (not the ones provided by Core Platform). In this context, there are two things to notice:

The cache is always cold.
2. Your pipeline job runs under the Build Service Identity (which’s the System.AccessToken). The principle here is that the Identity (our System Access Token) is a property of the project, not a property of the agent pool. Why is this relevant? because the project-scoped token is denied that repository-context read;, the TF401019 ADO’s 404 that really means 403… I’m an AWS guy :sweat_smile:, Azure’s errors are sooo esoteric.

So in short, your script assumed things the token can’t do. Auto-detection isn’t free so to speak, and under ènforceJobAuthScope repo-self detection isn’t free — it’s a privileged read the job token lacks. That’s the actual error, a query/permissions error.

Sadly, your script doesn’t handle errors the way it should. When the query fails due to the lack of permissions, since there’s no set -e and also it runs the query inside done < <( … ), so the non-zero exit is literally swallowed. The task exits 0, green build, tag never applied.

I’d like to avoid splitting our deployment job between two different runners because my intuition says it would increase the overall cost for Eneco@anton, if you got my poor explanation, I think you can do two things:

Regardless, improve your script error handling.
Pass --organization/--project/--detect false so the CLI never resolves the repo — there is no /vsts/info call to deny and it should work.




I will close this one, since there’s a way to workaround it, but I strongly suggest to apply my suggestion, and see how it goes. If still doesn’t work, let’s open another one.
Anton Kultsov  [11:21 AM]
hi @alex.torres thank you for looking into it and for taking time to troubleshoot and explain it in detail.
Indeed, the script can be improved thank you for the advice.
Though, with all its flaws this script used to work alright on the same ephemeral runners for quite a long time.
It's clear that something was changed in the security configs somewhere that broke the script's assumptions.

regarding the identity of the pipeline, it's running under mcc-btm-deployment-prd-sp SP credentials, I believe. Could it be that this SP was denied some access rights in our ADO space recently (a month or two ago)?
Alex Torres  [11:25 AM]
regarding the identity of the pipeline, it’s running under mcc-btm-deployment-prd-sp SP credentials, I believe. Could it be that this SP was denied some access rights in our ADO space recently (a month or two ago)?Oh, likely. Worth to cross-check.
Also, the way to confirm it is to pass the organization and the project explicitly as I indicated. The error-handling in the script isn’t optional, otherwise, you wouldn’t be able to see and inspect the actual error (the ADO query error).Anton Kultsov  [2:36 PM]
I've tried to add the parameters you proposed, the error is gone but the command does not output anything. You can see here
spsprodweu2.vssps.visualstudio.comAzure DevOps Services | Sign In[2:36 PM]that's the output on my machine
image.png Alex Torres  [2:41 PM]
Do you have a draft PR, that I can use to play with? —
If you can indicate what you’re trying to update, so I can replicate our scenario, and see what’s the cause of the empty output?Anton Kultsov  [2:47 PM]
before updating anything, I need it query ADO boards for the tickets. Apparently this part is not working as it used before
you can play with this branch and trigger the pipeline here
Anton Kultsov  [5:50 PM]
I enabled the debug output that can be seen here
That is the response we receive here: {...., "workItems":[]} .
So, apparently it boils down to the fact our SP cannot see the work items in our board anymoreNiels Witte  [9:00 PM]
I vaguely remember when I was looking into this that it system.access token was not using the SP credentials but rather the pipeline pool credentials
[9:00 PM]Does the central eneco cloud team not manage the permissions of the built in pool?
[9:01 PM]It could be that they changed the permissioms

Script:
https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/Eneco.Vpp.BehindTheMeter?path=/azure-pipelines/steps/azure-boards-add-tag.sh

Current bbranch for testging purposes: https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/Eneco.Vpp.BehindTheMeter?version=GBfix%2Ftagging
Pipeline can be triggered from here: https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_build?definitionId=4667
