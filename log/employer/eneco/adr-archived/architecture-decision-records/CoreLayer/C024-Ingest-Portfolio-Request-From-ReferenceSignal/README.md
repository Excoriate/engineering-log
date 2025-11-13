# Move Portfolio Request ingestion to Reference Signal service

* Status: accepted
* Deciders: Team Optimum, Team Core, Alex Shmyga, Ricardo Duncan
* Date: 2025-01-21

Technical Story: [User Story 516120](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_workitems/edit/516120/): Move Portfolio Request Ingestion to Reference Signal Service

## Context and Problem Statement

When moving to target state we want to keep the services running in L3 to a minimum, this means we do not want to bring Portfolio Service into L3. We also want to combine Dispatcher aFRR with Reference Signal service, in order to do this, we need to align these services with the same structure as mFRR. Currently, the Activation mFRR service ingests the set point.

## Decision Drivers

* Reduce services
* Combine services logically
* Increase reliability
* Flexibility and scalability

## Considered Options

* **Option 1:** Leave services as they are
* **Option 2:** Move portfolio request ingestion into Reference Signal service

## Pros and Cons of the Options

### Option 1: Leave services as they are

Leave services as they are.

* Good, no code changes.
* Bad, another service will need to be brought into L3.
* Bad, currently we have two services writing to the same collection for dispatching (Data Prep and Reference Signal).

### Option 2: Move portfolio request ingestion into Reference Signal service

Move portfolio request ingestion into Reference Signal service.

* Good, the service responsible for ingesting the setpoint will also be responsible for calculating the compensation setpoint (one writer).
* Good, remove dependency on Azure Service Bus to retrieve the Portfolio Request from Portfolio Service.
* Good, aligns aFRR and mFRR services.
* Good, Reference Signal service is already responsible for writing health metrics to Scala.
* Bad, code change so requires more testing.

## Decision Outcome

Chosen option: **Option 2:** Move portfolio request ingestion into Reference Signal service

### Positive Consequences

* Good, the service responsible for ingesting the setpoint will also be responsible for calculating the compensation setpoint (one writer).
* Good, remove dependency on Azure Service Bus to retrieve the Portfolio Request from Portfolio Service.
* Good, aligns aFRR and mFRR services.
* Good, Reference Signal service is already responsible for writing health metrics to Scala.

### Negative Consequences

* Bad, code change so requires more testing.

## Links
