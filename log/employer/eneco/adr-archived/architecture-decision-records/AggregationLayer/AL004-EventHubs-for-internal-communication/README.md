# Use EventHubs for  internal communication between different components inside Agg Layer

* Date: 2023-08-16
* Updated: 2023-08-16

# Context
* Currently all components of Aggregation Layer (azure functions) use an integration on a database level.
* Aggregation Layer should be able to handle B2B and B2C customers of Eneco.
* We see growth in the number of sites in the B2C domain to a level where we need to consider scaling to order of magnitude of millions.
* Site telemetry is used during disaggregation process, so data from TelemetryIngestion function should be streamed to Disaggregation component. In case we have 1 mln clients and each of them publishing telemetry every 10 seconds and we have a normal distribution of it then we would need to handle 100k temetries/events per second.
* Strike prices is used during disaggregation process as well, so from time to time we would need to share a couple of millions of messages between components. In theory it's possilbe that we would need to do that every minute in the future.
* For the future market allocation and scheduling will have huge volume of data as well to be shared.
* Service Bus on premium subscription (with 16 MUs) can handle maximum 66912 messages per second in AND out. So it's no an option for us.
* EventHubs on premuim subscription can handle multiple millions of messages per second.
* Comparison table between standard and premium subscriptions for EventHubs:

| Characteristic | Standard | Premium
|---	|---	|---	
| Number of consumer groups per event hub | 20 | 100
| Number of brokered connections per namespace | 5,000 | 10000 per PU. For example, if the namespace is assigned 3 PUs, the limit is 30000.
| Maximum TUs or PUs or CU | 40 TUs | 16 PUs
| Number of event hubs per namespace | 10 | 100 per PU
| Throughput per unit | Ingress - 1 MB/s or 1000 events per second  Egress – 2 MB/s or 4096 events per second | No limits per PU
| Customer-managed key (Bring your own key) | N/A | Yes
| Dynamic Partition scale out | N/A | Yes
| Maximum size of Event Hubs publication | 1mb | 1mb

**Glossary**

*Throughput units*
The throughput capacity of Event Hubs is controlled by throughput units. Throughput units are pre-purchased units of capacity. A single throughput unit lets you:
- Ingress: Up to 1 MB per second or 1000 events per second (whichever comes first).
- Egress: Up to 2 MB per second or 4096 events per second.


*Processing units*
Event Hubs Premium provides superior performance and better isolation within a managed multitenant PaaS environment. The resources in a Premium tier are isolated at the CPU and memory level so that each tenant workload runs in isolation. This resource container is called a Processing Unit (PU). You can purchase 1, 2, 4, 8 or 16 processing Units for each Event Hubs Premium namespace.
How much you can ingest and stream with a processing unit depends on various factors such as your producers, consumers, the rate at which you're ingesting and processing, and much more.
For example, Event Hubs Premium namespace with 1 PU and 1 event hub (100 partitions) can approximately offer core capacity of ~5-10 MB/s ingress and 10-20 MB/s egress for both AMQP or Kafka workloads.

* Some usuful links about EventHubs:
- [azure event hubs kafka overview](https://learn.microsoft.com/en-us/azure/event-hubs/azure-event-hubs-kafka-overview)
- [event hubs quotas](https://learn.microsoft.com/en-us/azure/event-hubs/event-hubs-quotas)
- [event hubs scalability](https://learn.microsoft.com/en-us/azure/event-hubs/event-hubs-scalability)
- [event hubs federation overview](https://learn.microsoft.com/en-us/azure/event-hubs/event-hubs-federation-overview)
- [dynamically add partitions](https://learn.microsoft.com/en-us/azure/event-hubs/dynamically-add-partitions)
- [monitor event hubs](https://learn.microsoft.com/en-us/azure/event-hubs/monitor-event-hubs)

# Costs

An overview of the monthly cost can be found in the screenshot below

![Cost breakdown - Monthly](.img/montlycost.png)

For details how the cost is distibuted across individual tiers is displayed below

![Cost breakdown - Details](.img/detailedcost.png)


# Decisions
1. Use standard EventHubs on sandbox and MC-Dev environments.
2. Use premium EventHubs on MC-ACC and Prod environments.
3. For the whole internal (async) communication inside Agg Layer use EventHubs
4. ESP remains a standard for external communication


# Decision Drivers
1. It's critical Agg Layer should be able to scale and handle huge volume (internally hundreds of thousands communication messages per second)
2. We don't need to handle huge volume of messages between all components inside Agg Layer, but having one standard protocol of doing that we would be more beneficial for gaining knowledge and also more cost effective