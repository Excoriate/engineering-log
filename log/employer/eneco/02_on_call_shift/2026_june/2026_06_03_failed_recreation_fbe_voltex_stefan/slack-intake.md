## Slack Metadata

- Channel: `#Myriad-platform`
- Message: https://grid-eneco.enterprise.slack.com/lists/T039G7V20/F0ACUPDV7HU?record_id=Rec0B8B35TTCH

## Original Request Message

I have some issues with the recreation of my fbe (voltex).
I see that the create pipeline is done and everything was successful but when I check argo cd for voltex I only see the voltex-app-of-apps and alarmengine.
Somehow I have the suspicion that I messed up the vpp-config for the fbe branch (feature/fbe-826335-update-appconfig-with-new-tso) but I have no permission to delete the branch to start over again.

Could you please help me to get a fbe back to live.


## Context provided
- FBE Creator piopeline pointed out by stefan https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_build/results?buildId=1668061&view=results
- ArgoCD sandbox for voltex https://argocd.dev.vpp.eneco.com/applications?showFavorites=false&proj=&sync=&autoSync=&health=&namespace=voltex&cluster=&labels=

## Context

The sandbox is a development environment, used by developers and there is always the fbe are deployed, to test the aggregation layer. It's not VNET integrated, and you have full access through the skill `eneco-tools-connect-mc-environments`.

### Skills to use

Load first eneco-fbe-troubleshoot Skill

- `eneco-context-repos`
- `eneco-context-docs`
- `eneco-tools-connect-mc-environments`

> **Note (for `eneco-tools-connect-mc-environments` skill):**
> When you access MC environments, always remember to turn OFF whitelisting after completing your task, to prevent configuration drift.

Actual error on Running INfra Test With Pester pipeline https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_build/results?buildId=1668061&view=logs&j=2c7373ec-8689-5226-2b54-530d89525138&t=6924b3f9-359e-5c1f-c1bd-89e4b76c16f1&l=45
```
File saved!
Import-Module -Name /usr/share/az_14.6.0/Az.Accounts/5.4.0/Az.Accounts.psd1 -Global
Clear-AzContext -Scope Process
Clear-AzContext -Scope CurrentUser -Force -ErrorAction SilentlyContinue
 Connect-AzAccount -ServicePrincipal -Tenant eca36054-49a9-4731-a42f-8400670fc022 -ApplicationId *** -FederatedToken ***** -Environment AzureCloud -Scope Process
WARNING: TenantId 'eca36054-49a9-4731-a42f-8400670fc022' contains more than one active subscription. First one will be selected for further use. To select another subscription, use Set-AzContext.
WARNING: To override which subscription Connect-AzAccount selects by default, use `Update-AzConfig -DefaultSubscriptionForLogin 00000000-0000-0000-0000-000000000000`. Go to https://go.microsoft.com/fwlink/?linkid=2200610 for more information.
 Set-AzContext -SubscriptionId 7b1ba02e-bac6-4c45-83a0-7f0d3104922e -TenantId eca36054-49a9-4731-a42f-8400670fc022
Testing environment [voltex]
Importing AKS Credentials
WARNING: You're using Az version 14.6.0. The latest version of Az is 16.0.0. Upgrade your Az modules using the following commands:
  Update-PSResource Az -WhatIf    -- Simulate updating your Az modules.
  Update-PSResource Az            -- Update your Az modules.
There will be breaking changes from 14.6.0 to 16.0.0. Open https://go.microsoft.com/fwlink/?linkid=2241373 and check the details.
Retrieving PODs from namespace [voltex]. Excluding Jobs.
================PODS================

Name                        Ready Status    Restarts Node
----                        ----- ------    -------- ----
alarmengine-6569ddf57-lks5j 1/1   Running       0.00 aks-agentpool-25996883-vm…
frontend-8556c9dffd-7t9w5   0/1   Succeeded     1.00 aks-agentpool-25996883-vm…
monitor-5b45c988c5-sr45x    0/1   Succeeded     1.00 aks-agentpool-25996883-vm…

================PODS================
Retrieve authentication token for the VPP
Pester v5.7.1

Starting discovery in 1 files.
Discovery found 4 tests in 146ms.
Running tests.
Describing Kubernetes
  [+] Should return at least one pod 57ms (32ms|25ms)
##[error]   [-] Should all the pods have Running status 38ms (35ms|2ms)
##[error]    Expected collection Running to contain 'Succeeded', but it was not found.
##[error]    at $pods.Status | Should -BeIn @("Running"), /home/vsts/work/1/s/azure-pipeline/pipelines/scripts/fbe/tests/FBE.FunctionalTests.ps1:115
##[error]    at <ScriptBlock>, /home/vsts/work/1/s/azure-pipeline/pipelines/scripts/fbe/tests/FBE.FunctionalTests.ps1:115

Describing VPP-Application
  [+] Azure AD authentication token should exist 13ms (11ms|2ms)
##[error]   [-] [FrontEnd] should get 200 93ms (92ms|1ms)
##[error]    HttpResponseException: Response status code does not indicate success: 404 (Not Found).
##[error]    at <ScriptBlock>, /home/vsts/work/1/s/azure-pipeline/pipelines/scripts/fbe/tests/FBE.FunctionalTests.ps1:142
Tests completed in 608ms
Tests Passed: 2, Failed: 2, Skipped: 0, Inconclusive: 0, NotRun: 0
Output variables used in the Slack report

/usr/bin/pwsh -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Unrestricted -Command . '/home/vsts/work/_tasks/AzurePowerShell_72a1931b-effb-4d2e-8fd8-f8472a07cb62/5.273.3/RemoveAzContext.ps1'
Disconnect-AzAccount -Scope CurrentUser -ErrorAction Stop
Disconnect-AzAccount -Scope Process -ErrorAction Stop
Clear-AzContext -Scope Process -ErrorAction Stop

Finishing: Running infra tests with Pester
```

### UAC

- You have to use, at the end when there's full confidence of the result obtained, the `how-to-feynman`skill, so it's explained in a .md document what you did, how, why, etc. So, I learn. I must be able to understand deeply your rationale, and replicate it by myself. If not, it's a failure.

