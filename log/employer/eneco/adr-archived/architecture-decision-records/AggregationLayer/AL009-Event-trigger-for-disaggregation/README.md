# Event Hub Trigger for Disaggregation Function to Avoid Delayed Setpoints

**Status:** Proposed  
**Deciders:** Cameron Goss, Johnson Lobo, Arne Knottnerus, Illia Larka  
**Date:** 2024-12-12  

---

## Technical Story

The current implementation flow involves receiving the setpoint via the **DataIngestion** function and saving it to **Cosmos DB**. Disaggregation functions are triggered by a Cosmos DB trigger on the setpoint collection.  

Internally, the Cosmos DB trigger in Azure Functions utilizes the **Cosmos Change Feed**, which has a default polling period of 5 seconds. This default period can result in triggering the function at the end of the 4-second setpoint cycle, causing a delay in disaggregation function execution.  

---

## Context and Problem Statement

```plaintext
     T1                                             Td                                     T2                                   TA
    00:00.00 ----------------------------------> 00:04.000 --------------------------> 00:05.000 ---------------------------> 00:05.400

    Pool setpoint received                Device setpoints deadline          Triggered disaggregation            Actual device setpoints
```

As shown in the diagram, the **pool setpoint** is received at the beginning of the 4-second cycle (`T1`). However, due to the internal implementation of the Cosmos DB trigger, the **disaggregation function** is triggered only after 5 seconds (`T2`) when trigger pools Cosmos DB change feed. Consequently, the actual device setpoints (`TA`) are generated past the deadline (`Td`), introducing a delay.

---

## Decision Drivers

* Alignment with business use cases  
* Maintainability of current throughput across resources 
* Chronological processing per pool

---

## Considered Options

1. Decrease the Cosmos DB trigger polling period.  
2. Use Event Hub to trigger the disaggregation.  
3. Re-architect the disaggregation flow to be event-based, supporting scalability.  

---

### Option 1: Decrease Cosmos DB Trigger Polling Period  

The Cosmos DB trigger provides a parameter to specify the polling period. Reducing it to 1 second would limit the delay in triggering the disaggregation function to a maximum of 1 second.  

#### Pros:

* Minimal code changes required.  
* Compatible with the existing business use case.  

#### Cons:

* Increases RU usage on Cosmos DB across all four collections.  

---

### Option 2: Use Event Hub to Trigger Disaggregation  

In this approach, the disaggregation function is triggered by an Event Hub instead of a Cosmos DB trigger. The **DataIngestion** function sends an event after saving the setpoint to Cosmos DB.

#### Pros:

* Fits within the existing toolset.  
* Avoids increased RU usage on Cosmos DB.  
* Compatible with the existing business use case.  
* Cronological processing is guaranteed

#### Cons:

* Slightly increases Event Hub usage 

---

### Option 3: Re-Architect Disaggregation Flow to Support Scalability  

This involves modifying the flow to split the disaggregation process into two stages:  
1. Batch splitting of setpoints based on merit order and available device capacity.  
2. Immediate dispatch of device setpoints, either maximizing availability or dispatching smaller device setpoints, including the last setpoint.  

#### Pros:

* Addresses scalability challenges for future use cases.  
* Cronological processing per pool is guaranteed

#### Cons:

* Introduces significant changes that require time to implement.  
* There is no immediate business use case to justify the need for extensive scalability.  

---

## Decision Outcome

**Chosen Option**: Use Event Hub to trigger the disaggregation function with `N` number of Event Hub partitions and `M` number of pods.

To support high load (an edge case, where sudden activation occurs for all pools across all markets) and guarantee that every setpoint is processed chronologically and at best possible time (service execution), the value of `N` must be greater than or equal to the number of `P` pools in the aggregation layer.

Partitioning by pool identifier guarantees that setpoints are directed to a single partition (one partition per pool).

Partitioning by pool identifier for each pool ensures the chronological order of processing setpoints.

The ideal scenario that guarantees the best performance during sudden, large-scale activation is when N = M = P. In short, one partition and one pod per pool.

The Event Hub number of paritions will be increased to 10, which is 3 more than current number of pools (`N` > `P`).

Taking into account resources (RAM, CPU) at cluster, the number of data ingestion pods will be increased to 2 (a pod per topic parition).

The number of set point disaggregation pods will be increase to 4. Having 4 pods of disaggregation is acceptable for now. If we see increasing latency in processing asset setpoints we will scale pods manually to improve it.

The latency between publishing to Event Hub and starting handling setpoint in disaggregation is around 100ms.

To validate the changes introduced in our system, we conducted a performance test in the acceptance environment (MC). The goal was to assess the stability and resource usage of the new setup under simulated load.

Event hub had 10 paritions. Data ingestion function has been scaled to 2 pods. Disaggregation function has been scaled to 4 pods. 10 pool have been activated during 30 minutes period of time.

Maximum CPU & RAM usage per pod during run:

DataIngestion 

* CPU Usage: 0.075 CPU per pod (rounded up to 0.1 CPU per pod for safety margin)
* RAM Usage: 668 MiB (rounded up to 700 MiB for safety margin)

SetpointDisaggregation

* CPU Usage: 0.075 CPU per pod (rounded up to 0.1 CPU per pod for safety margin)
* RAM Usage: 475 MiB (rounded up to 500 MiB for safety margin)

### Positive Consequences

* Maintains alignment with existing business use cases.  
* Avoids increasing RU (Request Units) usage on Cosmos DB.  
* Chronological processing per pool 

### Negative Consequences

* To support edge cases `N` of paritions must be equal to `M` of pods (consumers) which brings high resource usage 

---

## Links

- [CosmosDB Change Feed Delay](https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/troubleshoot-changefeed-functions#your-changes-are-taking-too-long-to-be-received)
