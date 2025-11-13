
# Battery Collocation (BaCo) Power Capacity Restrictions

* Status: proposed
* Deciders: : Team Optimum, Alex Shmyga, Ricardo Duncan
* Date: 2025-04-18

## Context and Problem Statement

Battery collocation refers to the practice of combining energy storage systems, such as batteries, with renewable energy assets like wind turbines or solar panels.
This approach optimizes energy production and storage by balancing supply and demand, improving grid stability, and maximizing economic returns.
For more details, see [this article](https://hub.enspired-trading.com/blog/how-to-optimize-a-co-located-battery).

Currently, all incoming data, such as power and curtailment schedules, capacity forecasts, asset availability and its characteristics, is ingested in the Asset Planning service.
Asset Planning performs the necessary boundaries checks and calculations to ensure that the data is valid and usable.
However, the current system takes into consideration only static restrictions like Max Energy Capacity Nameplate, Min and Max Power Capacity Nameplates. 
It does not account for the restrictions that arise from collocating batteries with other assets.
The new feature, which calculates the minimum and maximum power capacity for all assets based on a set of restrictions, needs to be integrated into the system.

The key decisions to be made are:
1. Where to place the new feature: Should it be incorporated into the existing Asset Planning service or implemented as a new microservice?
2. How to store and convey the new data: What data storage and communication mechanisms should be used to handle the additional information effectively?

## Decision Drivers

* The need to ingest three new schedules:
    - Congestion Schedule. Expected frequency is 1 event per 15 min per asset.
    - Collocation Forecast. Expected frequency is 1 event per 15 min per asset.
    - kWMax Targets (Grid Tariffs). Expected frequency is 1 event per day per asset
* Ensure the new schedules are integrated into the Min and Max power capacity calculations.
* The restrictions derived from the new schedules must:
    - Be utilized in the Fleet Optimizer for power schedule calculations.
    - Replace the capacity operating (asset availability) and forecasted capacity currently used by the Dispatching services.
    - Be accessible for the future Asset Intra Day Trading application.
* Maintain data consistency and availability across all dependent services.
* Ensure scalability and flexibility for future enhancements.
* Minimize the impact on existing services and workflows.

## Considered Options

* The new schedules are ingested and stored in Asset Planning. Min/Max capacity recalculation is triggered by events, meaning the outcome is recalculated whenever there is a change in any of the input data.
* The new schedules are ingested and stored in Asset Planning. Min/Max capacity recalculation is performed by a scheduled (cron) job that recalculates the values for each asset in the portfolio at fixed intervals (e.g., every 1/2/5/10 minutes).
* Asset Planning remains unchanged. A new microservice is introduced with the sole responsibility of power capacity calculation. This service ingests and stores all required data locally and can use either an event-driven or scheduled recalculation strategy.

## Pros and Cons of the Options

### Option 1: Extended Asset Planning with Event-Driven Design

* **Good**, because it ensures real-time updates and accurate calculations based on the latest data.
* **Good**, because it leverages the existing infrastructure of Asset Planning.
* **Good**, because Asset Planning already handles and stores other schedules.
* **Good**, because currently Asset Planning has relatively low CPU and RAM usage and can handle extra load.

* **Bad**, because it may increase the complexity and load on the Asset Planning service.
* **Bad**, because frequent updates could lead to performance bottlenecks under high data change rates. Power capacity calculation depends on several input streams. A change in any of the streams will trigger recalculation, adding extra complexity and extra load both on the application and the database.
* **Bad**, because it may increase the complexity. It introduces too much business logic into the Asset Planning service, which might make its purpose too broad.

### Option 2: Extended Asset Planning with a Scheduled Job

* **Good**, because it reduces the average load on the system compared to event-driven recalculation.
* **Good**, because it is easier to implement and maintain compared to real-time event-driven processing.

* **Bad**, because it introduces a delay in updates, which may lead to less accurate results in time-sensitive scenarios.
* **Bad**, because it still increases the responsibilities of the Asset Planning service.
* **Bad**, because it causes load spikes that may impact other data processing occurring simultaneously.

### Option 3: New Power Capacity Microservice

* **Good**, because it adheres to the single responsibility principle, isolating the new functionality.
* **Good**, because it reduces the impact on the existing Asset Planning service.
* **Good**, because it provides flexibility to choose between event-driven or scheduled recalculation strategies.
* **Bad**, because it introduces additional complexity in terms of service orchestration and data synchronization.
* **Bad**, because it requires additional infrastructure and maintenance efforts including separate storage per tenant 

## Decision Outcome

Chosen option: **Option 1:** Extended Asset Planning with Event-Driven Design

### Positive Consequences

* Low implementation and maintenance costs.
* Ensures real-time updates and accurate calculations based on the latest data.
* Leverages the existing infrastructure of Asset Planning.
* Asset Planning already handles and stores other schedules, making integration straightforward.
* Currently, Asset Planning has relatively low CPU and RAM usage and can handle the extra load.

### Negative Consequences

* May increase the complexity and load on the Asset Planning service.
* Frequent updates could lead to performance bottlenecks under high data change rates.
* Power capacity calculation depends on several input streams, which could add extra complexity and load to both the application and the database.
* Introduces additional business logic into the Asset Planning service, potentially broadening its purpose too broad.

## Links

* [BESS Co Location Miro board](https://miro.com/app/board/uXjVITbKwQM=/)