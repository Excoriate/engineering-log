---
task_id: 2026-04-21-001
agent: claude-code
status: complete
summary: Open discovery questions that Phase 4 context harvest must answer
---

# Discovery

## Must-answer before Phase 5 plan

1. **Identity**: exact Event Hub namespace + event hub name + expected consumer group name that mFRR-Activation pod is configured to use on Sandbox.
2. **Mechanism**: what does the pod log on startup? (`ConsumerGroupNotFound` vs auth vs network vs config-missing). The log line discriminates H1 vs H2 vs H3.
3. **IaC state**: does the consumer group exist as an `azurerm_eventhub_consumer_group` resource in MC-VPP-Infrastructure, and is it parameterized for Sandbox env?
4. **Pipeline outcome**: did ADO buildId=1616964 succeed? If yes, did it report creating the consumer group (plan/apply diff)? If no, what failed?
5. **Runtime state**: after the pipeline, does `az eventhubs eventhub consumer-group list --namespace <ns> --eventhub <eh>` on the Sandbox subscription return the expected name?
6. **Slack thread context**: what did Stefan + teammates say before filing the list record? Is there a Rootly incident link? Previous fix attempts?

## Derived questions (depend on above)

- If IaC missing → which PR / commit introduced or removed the resource? `archeologist`.
- If IaC present but unapplied → what was the last successful apply and why the drift? ADO pipeline run history.
- If IaC applied but service still crashes → connection-string / RBAC / network / service config issue; re-classify.
