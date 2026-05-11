# FBE creation — Terraform deploy failure (Duncan, 2026-05-11)

## Agent description (use in task frontmatter or handover)

**Description:** On-call: Duncan cannot complete a new **FBE** creation — **Terraform deploy** fails in **Azure DevOps** (`Myriad - VPP`); initial run (build `1638601`) failed; **retry failed faster**, so treat as **non-transient** until logs prove otherwise. Next agent: pull **both** pipeline log URLs from Slack, compare stages/errors, trace to repo/module and failing resource, then propose fix or escalation with evidence.

## Canonical knowledge anchor (Obsidian)

Vault path for condensed FBE notes (navigate before deep work):

`/Users/alextorresruiz/Documents/obsidian/2-areas/work-eneco/eneco-vpp-platform/fbe`

Per the **2ndbrain-obsidian** skill: validate `$SECOND_BRAIN_PATH`, read that folder’s `_index.md` before adding vault notes, and prefer existing FBE runbooks or ADRs linked from there.

## Intake pointers

- Slack Lists record: thread in `slack-intake.txt` (request + build links).
- **Discriminator:** if the same root error appears on both runs → steady config or backend issue; if different → concurrency, lock, or flaky dependency.

## Errors

```


##[error]Terraform command 'apply' failed with exit code '1'.
##[error]╷
│ Error: A resource with the ID "/subscriptions/7b1ba02e-bac6-4c45-83a0-7f0d3104922e/resourceGroups/rg-vpp-app-sb-401/providers/Microsoft.EventHub/namespaces/vpp-evh-premium-kidu" already exists - to be managed via Terraform this resource needs to be imported into the State. Please see the resource documentation for "azurerm_eventhub_namespace" for more information.
│
│   with module.eventhub_namespace_premium.azurerm_eventhub_namespace.eventhub_namespace,
│   on .terraform/modules/eventhub_namespace_premium/terraform/modules/event_hub_namespace/main.tf line 2, in resource "azurerm_eventhub_namespace" "eventhub_namespace":
│    2: resource "azurerm_eventhub_namespace" "eventhub_namespace" {
│
╵

##[warning]RetryHelper encountered task failure, will retry (attempt #: 1 out of 3) after 1000 ms
/opt/hostedtoolcache/terraform/1.14.3/x64/terraform version
Terraform v1.14.3
on linux_amd64
+ provider registry.terraform.io/betr-io/mssql v0.3.1
+ provider registry.terraform.io/hashicorp/azuread v3.8.0
+ provider registry.terraform.io/hashicorp/azurerm v4.40.0
+ provider registry.terraform.io/hashicorp/kubernetes v2.37.1
+ provider registry.terraform.io/hashicorp/random v3.8.1
+ provider registry.terraform.io/hashicorp/time v0.10.0
+ provider registry.terraform.io/hashicorp/tls v4.0.4

Your version of Terraform is out of date! The latest version
is 1.15.2. You can update by downloading from https://developer.hashicorp.com/terraform/install

/opt/hostedtoolcache/terraform/1.14.3/x64/terraform apply -auto-approve -auto-approve -var environment=kidu -var kusto_cluster_name=vppkustocluster01sb -var kafka_queue_name=com-eneco-eet-vpp-streamcopy-dev10
data.terraform_remote_state.platform_shared: Reading...
random_string.random: Refreshing state... [id=xsk]
random_integer.environment: Refreshing state... [id=319]
module.sa-appreg-mc-vpp-monitor-d.data.azuread_service_principal.ent-app[0]: Reading...
module.sa-appreg-vpp-gatewaynl-id-d.data.azuread_application.this[0]: Reading...
module.sa-appreg-mc-vpp-monitor-d.data.azuread_application.this[0]: Reading...
module.sa-appreg-vpp-marketinteraction-id-d.data.azuread_service_principal.ent-app[0]: Reading...
module.sa-appreg-vpp-marketinteraction-id-d.data.azuread_application.this[0]: Reading...
module.sa-appreg-mcdta-vpp-frontend-d.data.azuread_application.this[0]: Reading...
module.sa-appreg-vpp-alarmpreprocessing-id-d.data.azuread_service_principal.ent-app[0]: Reading...
module.sa-mcdta-vpp-clientgateway-id-d.data.azuread_application.this[0]: Reading...
module.sa-appreg-mc-vpp-monitor-d.data.azuread_service_principal.ent-app[0]: Read complete after 0s [id=/servicePrincipals/23300ccf-f835-4c20-9970-a568e5b19fa4]
module.sa-appreg-vpp-alarmpreprocessing-id-d.data.azuread_service_principal.ent-app[0]: Read complete after 0s [id=/servicePrincipals/4db14681-0deb-4513-bbe6-745a11c72daf]
module.sa-mcdta-vpp-clientgateway-id-d.data.azuread_service_principal.ent-app[0]: Reading...
module.sa-appreg-vpp-alarmpreprocessing-id-d.data.azuread_application.this[0]: Reading...
module.sa-appreg-vpp-marketinteraction-id-d.data.azuread_service_principal.ent-app[0]: Read complete after 0s [id=/servicePrincipals/accdb097-896a-4b4b-85d6-38fbf7601e0e]
module.sa-appreg-mcdta-vpp-frontend-d.data.azuread_service_principal.ent-app[0]: Reading...
module.sa-mcdta-vpp-clientgateway-id-d.data.azuread_application.this[0]: Read complete after 0s [id=/applications/7d50de78-49d0-4c0f-9720-9769c4377550]
module.sa-appreg-vpp-gatewaynl-id-d.data.azuread_service_principal.ent-app[0]: Reading...
```
https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_build/results?buildId=1638601&view=logs&j=d0b7661b-aef9-52be-2818-520ebf295b7a&t=9f7abc30-d714-5362-f957-fa7ee894c36d&s=a3813e30-f650-581b-089b-fb9d9cadcd17
