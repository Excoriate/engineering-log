## Slack Metadata

- Channel: `#Myriad-platform`
- Message:  https://grid-eneco.enterprise.slack.com/lists/T039G7V20/F0ACUPDV7HU?record_id=Rec0B6L0PHVNG

## Original Request Message

Can you provide us the Kafka certificate for dev and test. We tried to read the PEM content from key vault. it looks like it is not in good format.

Keyvault : vpp-agg-sb.vault.azure.net

Keys: kafka-cacert, kafka-clientcert,kafka-sslkey

## Context

Dev and Test, means you have to get this information from the MC Dev, and MC Test environments.

### Repos

Not specified.

### Skills to use

- `eneco-context-repos`
- `eneco-context-docs`
- `eneco-tools-connect-mc-environments`

> **Note (for `eneco-tools-connect-mc-environments` skill):**
> When you access MC environments, always remember to turn OFF whitelisting after completing your task, to prevent configuration drift.

### UAC

- Ensure the certified are downloaded on this repo first.
- You have to use, at the end when there's full confidence of the result obtained, the `how-to-feynman`skill, so it's explained in a .md document what you did, how, why, etc. So, I learn. I must be able to understand deeply your rationale, and replicate it by myself. If not, it's a failure.
