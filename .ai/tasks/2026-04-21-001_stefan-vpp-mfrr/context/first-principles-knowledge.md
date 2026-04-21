---
task_id: 2026-04-21-001
agent: claude-code
status: complete
summary: First-principles knowledge build — mechanism chain, MS Learn citations, failure↔success pairing, falsifiers
---

# First-Principles Knowledge Build

## 1. Un-braided terms (load-bearing only)

### "mFRR-Activation on Sandbox" — three planes
```
                        ┌─ mFRR = market product (TenneT reserve, Dutch TSO)
                        │   owner: regulator / product spec
                        │
 "mFRR-Activation"  ────┼─ Activation = dispatch leg (TSO-triggered)
                        │   owner: Eneco.Vpp.Core.Dispatching repo (Core team)
                        │
                        └─ service = K8s workload (container running activation logic)
                            owner: ArgoCD sync of helm chart → AKS Sandbox cluster

                        ┌─ Env "Sandbox" = Eneco separate-from-MC Azure subscription
 "on Sandbox"       ────┼─ Cluster = Azure AKS (NOT OpenShift)
                        │   — FACT per Sebastian du Rand 2026-04-10 17:14 CEST
                        └─ Topology asymmetry: dev-mc/acc/prd run OpenShift on MC;
                            tooling and probes differ (kubectl vs oc, AAD workload
                            identity vs OpenShift SCC, etc.)
```
Seam: the service (owned by Core team code) reads a **consumer group name** from its config, passes it to `EventProcessorClient`, which calls the Event Hubs data plane on the Sandbox namespace. If the consumer group entity does not exist on that namespace, the SDK throws a non-retryable exception and the process dies.

### "EventHub consumer (group)" — two planes
```
                                     ┌─ Azure Event Hubs namespace (ARM resource
                                     │   Microsoft.EventHub/namespaces)
                                     │
                                     ├─ Event Hub entity inside the namespace
                                     │   (Microsoft.EventHub/namespaces/eventhubs)
  "EventHub consumer group"     ─────┤
                                     ├─ Consumer group = independent view of the hub
                                     │   (Microsoft.EventHub/namespaces/eventhubs/
                                     │    consumergroups) — separate ARM resource,
                                     │    separate RBAC scope, separate checkpoint
                                     │    state, separate reader quota
                                     │
                                     └─ Service-side config (appsettings / ConfigMap
                                         / helm values): a string naming which
                                         consumer group to bind EventProcessorClient
                                         to
```
Seam: Terraform owns the ARM resource (`azurerm_eventhub_consumer_group`); service owns the config string; both must agree exactly (case-sensitive string match).

## 2. Mechanism chain (H1 = reporter's hypothesis)

```
 0. IaC (MC-VPP-Infrastructure or VPP-Infrastructure repo) either
    does not declare an azurerm_eventhub_consumer_group for the CG the
    Activation service reads from, OR declares it but fails to apply
    it on Sandbox (env gate, env tfvars, pipeline stage).
 1. Azure Event Hubs namespace on Sandbox therefore has no consumer
    group matching the name `<cg-name>` under
    `.../eventhubs/<eh-name>/consumergroups/`.
 2. mFRR-Activation pod starts on Sandbox AKS.
 3. On startup, the pod constructs an EventProcessorClient (Azure.Messaging.EventHubs
    .NET SDK) with `consumerGroup: "<cg-name>"` bound from appsettings /
    ConfigMap / helm values.
 4. EventProcessorClient issues a management-plane probe / data-plane
    AMQP open against `sb://<namespace>/<eh-name>/consumergroups/<cg-name>`.
 5. Event Hubs service returns ResourceNotFound — the consumer group
    entity does not exist.
 6. SDK throws:
      new SDK: EventHubsException(Reason=ResourceNotFound,
               IsTransient=false)
      legacy:  Microsoft.Azure.EventHubs.MessagingEntityNotFoundException
    — both classified by Microsoft as "Setup/configuration error". Quote
    (Microsoft Learn): "Entity associated with the operation does not
    exist or it has been deleted. Make sure the entity exists. Retry
    will not help."
 7. The pod's hosting startup pipeline treats this as fatal → process
    exits non-zero.
 8. Kubernetes restart policy (likely Always) re-creates the pod →
    same exception → pod enters CrashLoopBackOff (exponential back-off
    up to 5 minutes between restarts).
 9. Reporter observes "crash loop due to missing consumer group".
```

**Citations** (sourced via `mcp__microsoft-docs-mcp` 2026-04-21):
- EventHubsException reasons: https://learn.microsoft.com/azure/event-hubs/exceptions-dotnet
  > "Resource Not Found: The Event Hubs service couldn't find a resource such as an event hub, consumer group, or partition."
- Legacy MessagingEntityNotFoundException: https://learn.microsoft.com/azure/event-hubs/event-hubs-messaging-exceptions
  > Category: "Setup/configuration error" — "Retry will not help." — "General action: Review your configuration and change if necessary."
- Consumer group concept (Java SDK, but equivalent conceptual model): https://learn.microsoft.com/java/api/overview/azure/messaging-eventhubs-readme — "A consumer group is a view of an entire Event Hub. Consumer groups enable multiple consuming applications to each have a separate view of the event stream."

## 3. Failure ↔ Success pairing (so the invariant is visible)

| Surface | Failure (today on Sandbox) | Success (the invariant) |
|---|---|---|
| ARM existence | `az eventhubs eventhub consumer-group list --namespace <ns> --eventhub <eh>` does NOT include `<cg-name>` | list INCLUDES `<cg-name>` exactly (case-sensitive) |
| SDK open | `EventHubsException(Reason=ResourceNotFound)` at startup, non-retryable | EventProcessorClient connects, `PartitionInitializingAsync` fires for each partition |
| K8s pod state | `CrashLoopBackOff`, restartCount growing, `Last State: Terminated Exit Code != 0` | `Running`, `Ready: 1/1`, restartCount stable |
| Consumer ownership | No entry in Event Hubs portal → "Consumer groups" → `<cg-name>` → Active consumers | One active consumer per partition, ownership balanced if multiple pods |
| Checkpoint blob | No container/blobs for `<cg-name>` in the checkpoint storage account | Blob container `<cg-name>` exists under vppstoraged (sandbox) with partition ownership + checkpoint JSON |
| Terraform state | No `azurerm_eventhub_consumer_group.<tag>` instance in state targeting Sandbox | Resource present, address matches live ARM, `terraform plan` = no drift |

## 4. Falsifiers (named, visible, checkable)

### F1 — Claim: "Consumer group is missing on Sandbox Event Hub namespace"
- **Probe**: `az eventhubs eventhub consumer-group list --subscription <sandbox-sub> --resource-group <rg> --namespace-name <ns> --eventhub-name <eh> -o tsv`
- **Falsifier**: if the list INCLUDES the expected CG name, H1 is false → investigate H2/H3.

### F2 — Claim: "Service is configured to read from a CG name that matches F1's list"
- **Probe**: `kubectl -n <namespace> get configmap <activation-cm> -o yaml` and/or `kubectl -n <ns> get deploy <activation-deploy> -o yaml | grep -A2 ConsumerGroup`
- **Falsifier**: if the service's CG string differs (typo, renamed) from what IaC creates, H3 is true (fix = service config, not IaC).

### F3 — Claim: "ADO pipeline buildId=1616964 (Stefan's trigger) reconciles the drift"
- **Probe**: open pipeline run; read stage outcomes; in the Terraform stage targeting Sandbox, check `terraform plan` output for `+ azurerm_eventhub_consumer_group.<tag>` lines naming the missing CG. Then check apply stage status.
- **Falsifier**: if the pipeline succeeded but did NOT create the CG (e.g. plan shows no changes), the IaC does not yet declare the resource → the pipeline trigger does not fix the problem; a PR is needed.

### F4 — Claim: "The pod's crash-loop log line matches Reason=ResourceNotFound referencing consumer group (H1), not auth/connectivity (H2)"
- **Probe**: `kubectl -n <ns> logs <activation-pod> --previous | head -n 200`
- **Falsifier**: if the log line reports `UnauthorizedAccessException`, `SocketException`, `DNS` failure, or `Could not load connection string`, H1 is wrong → H2; different fix.

### F5 — Claim: "Sandbox is the only affected environment" (blast radius)
- **Probe**: Rootly alert feed + kubectl on dev-mc/acc/prd; also `az eventhubs eventhub consumer-group list` on dev-mc/acc/prd EH namespaces.
- **Falsifier**: if any non-Sandbox env shows the same missing CG or crash loop, this is a cross-env regression (likely tied to Apr 16 P3 thread).

### F6 — Claim: "No related prior-period production impact"
- **Probe**: search Rootly incidents + `#myriad-major-incidents` for mFRR activation failures in the last 30 days.
- **Falsifier**: open incident found → escalate severity of this ticket immediately.

## 5. Blast radius (initial, pre-enrich)

- **Direct (Sandbox)**: mFRR-Activation cannot start → cannot consume from its input Event Hub topic → no downstream publish of Activation Response. Sandbox dispatching subsystem is effectively offline for mFRR testing until fixed.
- **Adjacent (Core team work)**: any Sandbox-based developer workflow that expects activation response publication is blocked. Watchtower / Dispatcher CI tests that round-trip via activation could flake. Release candidate validation for mFRR features in R147 (Stefan's original release master slot) could be delayed.
- **Non-impact (dev-mc / acc / prd)**: `A3 — UNVERIFIED[assumption: missing CG is Sandbox-only, boundary: confirmed by F5]`. mFRR activation in prd runs against prd Event Hub namespace with its own CG; unless the same IaC omission exists there, production mFRR is untouched.
- **Business-level**: Sandbox is dev/test only — no direct TenneT exposure. This is a **P3/P4-class developer-experience incident**, not an outage. Reporter's priority tag `:this-is-fine:` is consistent with that classification.

## 6. Confidence (pre-enrich)

**70% — mechanism Known, execution depends on three facts probed in Phase 7**:
1. The exact EH namespace + event hub name + expected CG name the service reads from.
2. The current live state of consumer groups on that namespace.
3. Whether `buildId=1616964` declared & applied the missing CG.

Assumptions that, if wrong, shift confidence:
- [A3] Reporter's self-diagnosis (missing CG vs config drift) is the true cause — probed by F4.
- [A3] Pipeline trigger is the right remediation — probed by F3 (if IaC does not declare the resource, triggering the pipeline is noise).
- [A3] Sandbox-only blast radius — probed by F5.

Confidence will lift to ≥95% once F1+F2+F3+F4 return consistent evidence.

## 7. What this implies for Phase 5 plan

- The fix is **likely**, but not certainly, a one-line Terraform PR + apply. We must not skip F4 (pod log) — if the real cause is H3 (config mismatch), the Terraform fix creates a CG the service will never use.
- If F3 shows the pipeline already applied the CG but pods still crash, something else is the actual root cause — do NOT close the ticket on Stefan's assumption.
- If F5 reveals non-Sandbox impact, escalate and re-scope.
- The ticket reporter is on vacation; the fix cannot wait for his confirmation. Coordinate with Hein Leslie (R147 release master, stand-in) + Core team (Alexandre Freire Borges, Artem Diachenko) for any IaC PR review.
