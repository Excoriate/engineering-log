# Share device telemetry via cosmos database with other components in Aggregation Layer

* Date: 2024-04-17
* Deciders: Khyati Bhatt, Cameron Goss, Illia Larka, Arne Knottnerus, Alex Shmyga

## Glossary
- VPPAL - Virtual Power Plant Aggregation Layer

## Context and problem statement
The TelemetryIngestion function receives telemetry data from ESP and then:
- Stores data in cosmosDB for us in Telemetry Aggregation
- Publishes data to EventHub to be consumed and stored in cosmosDB for Setpoint Disaggregation. It is used in calculating available capacity per device.

The format we store data in is one document per MDP code.
This makes updates simple and efficient, as MDP codes may come in several ESP messages for one device.

We were unable to find a way to have EventHub producer client batch messages for different partitions in one batch. 
Example: if we handle 1000 devices spread evenly over 12 ESP partitions (and 12 telemetry ingestion pods), we would have ~83 ESP messages at a time per telemetry ingestion pod which results in 83 EventHub producer client requests.

During performance testing we found several challenges with this setup.

### Performance test setup
First of all let's take a look on our performance tests setup:
- 1000 devices
- 7 MDP codes per device per message
- Telemetry is published every 10 seconds for every device

### Issues

Faced problems:
- Too many 429 errors (rate limiter) from cosmosDB
- Slow processing of ESP messages.

## Decisions

To handle the load we implemented the following:
- Removed all unused indexes. Result: We decrease the number of used RU units in cosmosDB
- Implemented batching during storing device telemetry. Result: We decrease the number of used RU units in cosmosDB
- Share TelemetryIngestion cosmosDB with Setpoint Disaggregation directly instead of through EventHub with a seperate cosmosDB for Setpoint Disaggregation
- Changed number of telemetry ingestion pods to match the number of ESP partitions (12)
- Changed RU units from 400 to 10k in the device telemetry collection
- Only store historical telemetry for pool types where it's needed (f.e. RTS)

After trying these changes, we saw clear improvements in performance and concluded the problem is mostly coming from the lack of batching during publishing to EventHub.

## Decision Drivers

Cost effective simple maintainable solution to be able to handle large amounts (1000+) devices with telemetry published every 10 seconds.

## Considered Alternatives

- use the Confluent package to publish data to EventHubs to be able to publish message for several partitions on one batch
    - pros: would reduce number of messages. 
    - cons: not really, just another implementation, still we have the duplication of device telemetry data which lead to additional costs for cosmosDB
- instead of having one EventHubs message per MDP code to have one messages per device telemetry
    - pros: less messages on EventHubs
    - cons: a bit more complex handlers of EventHubs messages
- instead of having a document/message per MDP code have a document per device
    - pros: less load on cosmosDB
    - cons: updating such message would require quite some work

## Outcome
With the proposed changes VPPAL can comfortably handle 1000+ devices publishing telemetry every 10 seconds and receiving setpoints to disaggregate every 4 seconds.
This was confirmed during testing on Sandbox.

This means increasing cosmosDB RU's for telemetry, and removing cosmosDB from disaggregation.
As we reduced load on EventHub, we can change from the EventHub plan from Premium to Standard.

Cost implications for cosmosDB (approximate):
- minus 35.04$/month, since we don't need disaggregation device telemetry collection
- plus 549$/month for device telemetry collection (increase from 400RU to 10000 RU), no autoscaling needed since we have a cosnt load on teletry
- plus 549$/month for device flex reservation collection (increase from 400 RU to 10000 RU)
- plus 198$/month for device strike prices collection (increase from 400 RU to 4000 R)
total: plus 1 261$ per month

*note for pricing per collection:
400RU $ 35.04/mo
4000RU $ 233.60/mo
10000RU $ 584.00/mo*

Cost implications for EventHubs: 
Since we reduced the main load on EventHubs we consider to move from Premium to Standard plan
- Premium - €1.234/hour per Processing Unit (PU) ~ 900 Euros/month 
- Standard - €0.028/hour per Throughput Unit ~20.44 Euros/month + a bit more for Throughput

 *Throughput Unit provides 1 MB/s ingress and 2 MB/s egress.*

**Total cost changes:**
* + ~ €1300/month CosmosDB
* - ~ €800/month EventHub
* Total: + ~ €500/month


## Conclusion
**With current production load we don't need to scale cosmosDB right away, we can do it step by step when we start facing 429 (rate limiter) exceptions from cosmosDB, so price after current changes will go down, since we don't need premium EventHubs anymore (or yet).

With scaling cosmosDB even more (>1000RU) we can handle even more decices without additional changes to architecture of Agg Layer, however, during curent perfornce tests we tried to find the limit with cosmosDB setup of 10000RU.

Caching of flex reservation data for device calculation functionality is added, so potentially we need less RU units there. Still needs to be confirmed.

Another proposal is in case we go for really much bigger than 1k numbers of devices we shall switch to `on change` telemetry to remove main load from cosmosDB.**