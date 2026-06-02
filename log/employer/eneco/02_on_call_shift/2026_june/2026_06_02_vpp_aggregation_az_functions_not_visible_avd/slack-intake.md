## Slack Metadata

- Channel: `#Myriad-platform`
- Message: https://grid-eneco.enterprise.slack.com/lists/T039G7V20/F0ACUPDV7HU?record_id=Rec0B7HTSTR33

## Original Request Message

https://agg.dev.vpp.eneco.com/telemetryfunctiontestsfn/healthz

This function should be accessible from AVD

for example : https://agg.dev.vpp.eneco.com/api/siteregistry is accessible

## Context

The AVD is a restricted environment, used by developers, to acces resources within the CMC network (azure). AVD stands for Azure Virtual Desktop.

### Repos

Likely, this repo include the function's code: https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/Eneco.Vpp.Aggregation
Other repos worth to look at: https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/Eneco.Vpp.Aggregation.Infrastructure and
https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/Eneco.Vpp.Aggregation.Infrastructure.Mc

Locally, aggregation repositoires are cloned here: Dropbox/@AZUREDEVOPS/eneco-src/enecomanagedcloud/myriad-vpp/
It's allowed to git pull to ensure you're wokring with the most up-to-date local version of the code.

### Skills to use

- `eneco-context-repos`
- `eneco-context-docs`
- `eneco-tools-connect-mc-environments`

> **Note (for `eneco-tools-connect-mc-environments` skill):**
> When you access MC environments, always remember to turn OFF whitelisting after completing your task, to prevent configuration drift.

### Known issues

- Check historical issues in Slack, with AVD from the same user (jhonson lobos)

### UAC

- Ensure the certified are downloaded on this repo first.
- You have to use, at the end when there's full confidence of the result obtained, the `how-to-feynman`skill, so it's explained in a .md document what you did, how, why, etc. So, I learn. I must be able to understand deeply your rationale, and replicate it by myself. If not, it's a failure.
- ensure you're discovering the network configuratoin involved (VNET, Private Endpoint, etc), so if probes must be executed in the AVD, I must be able to do it. E.g.: adding the IP of the AVD's hostfile to the whitelist.
