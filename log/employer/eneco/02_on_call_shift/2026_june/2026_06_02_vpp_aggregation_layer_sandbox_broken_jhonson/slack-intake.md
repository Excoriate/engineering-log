## Slack Metadata

- Channel: `#Myriad-platform`
- Message: https://grid-eneco.enterprise.slack.com/lists/T039G7V20/F0ACUPDV7HU?record_id=Rec0B6SP09F8B

## Original Request Message
It also include the comments exchanged by Nuno, and Jhonson Lobos.
> "VPP aggregation sandbox is broken. It is missing the secret called 'keys'.
>
> Events:
> Warning  FailedMount  2m1s (x32 over 50m)  kubelet  MountVolume.SetUp failed for volume 'keys': secret 'keys' not found
>
> Our certificates were also expired. Now I have used the ones from VPP Core."

And the thread is:

> Nuno Alves Pereira  [3:18 PM]
>
> Hi @Johnson Lobo. Can provide some additional details to help troubleshooting? What is the namespace, project app in ArgoCD?
>
> [3:18 PM] Also, for how long has it been broken in Sandbox for?
>
> Johnson Lobo  [3:19 PM]
>
> VPP-agg is the namespace
>
> [3:19 PM] It was broken since the day when certificate was expired
>
> [3:19 PM] Most probably more than 6 months
>
> Nuno Alves Pereira  [3:51 PM]
>
> Which pod / deployment are you getting this error from? Im finding nothing failed in this namespace at the moment
>
> Johnson Lobo  [3:57 PM]
>
> Yes , because I fixed it manually
>
> [3:57 PM] Secret called keys was missing
>
> [3:57 PM] I added it manually
>
> [4:00 PM] Can you delete the keys secret and see
>
> [4:01 PM] Ideally those secrets needs to be installed via secret provide right ?
>
> Nuno Alves Pereira  [4:01 PM]
>
> Can you delete the keys secret and see No need, I believe you
>
> [4:03 PM] Ideally those secrets needs to be installed via secret provide right ? That's what I was going to ask, what is the expectation here. I'm not 100% sure on this as the setup in sandbox is very different from MC envs, but will find out
>
> Johnson Lobo  [4:06 PM]
>
> Sure
>
> [4:10 PM] https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/Eneco.Vpp.Aggregation[…]/common/templates/secret.yaml&version=GBdevelopment&_a=contents
>
> spsprodweu2.vssps.visualstudio.com Azure DevOps Services | Sign In
>
> [4:10 PM] this is common secret
>
> [4:11 PM] and it is referenced in each function for example
>
> [4:11 PM] https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/Eneco.Vpp.Aggregation[…]/fn/templates/deployment.yaml&version=GBdevelopment&_a=contents
>
> spsprodweu2.vssps.visualstudio.com Azure DevOps Services | Sign In






## Context

The sandbox is a development environment, used by developers, to test the aggregation layer. It's not VNET integrated, and you have full access through the skill `eneco-tools-connect-mc-environments`.

The repos mentioned by Jhonson Lobos are:
- https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/Eneco.Vpp.Aggregation
- https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/Eneco.Vpp.Aggregation.Infrastructure
- https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/Eneco.Vpp.Aggregation.Infrastructure.Mc

### Skills to use

- `eneco-context-repos`
- `eneco-context-docs`
- `eneco-tools-connect-mc-environments`

> **Note (for `eneco-tools-connect-mc-environments` skill):**
> When you access MC environments, always remember to turn OFF whitelisting after completing your task, to prevent configuration drift.

### UAC

- You have to use, at the end when there's full confidence of the result obtained, the `how-to-feynman`skill, so it's explained in a .md document what you did, how, why, etc. So, I learn. I must be able to understand deeply your rationale, and replicate it by myself. If not, it's a failure.
