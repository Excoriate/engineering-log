
# Market interaction as dedicated domain/service

* Status: Decided
* Deciders: Rene Pingen, Pedro Alonso
* Advisors: Arne Knottnerus-Yuzvyak, Mark Beukeboom, Johan Bastiaan, Hein Leslie, Wesley Coetzee
* Date: 2023-03-20

Technical Story: -

## Context and Problem Statement
We designed the portfolio service as a migration layer to communicate the **VPP Portfolio** with external service as one only asset.
Now we have to ingest data related to the **Eneco Portfolio** and also add some logic at that level.
Adding all these features to the same service could generate a position where removing the VPP Portfolio layer is harder or a potential issue.
We would like to keep the layer of VPP Portfolio (migration) intact and isolated to drop it off whenever it is not needed.

## Decision Drivers
* Driver 1: Clarity. VPP Portfolio vs Eneco Portfolio.
* Driver 2: Maintainability, from a coding perspective.

## Considered Options

* Option 1: Create new service for Eneco Portfolio
  A new service will be created, and the new timeseries and logic will reside there.

* Option 2: Maintain Portfolio service
  The same service will ingest the timeseries and do the new calculation to apply the required logic at the Eneco Portfolio level.

## Decision Outcome
Chosen option: **Option 1**

- The current portfolio service remains as a connection with the legacy system, and can be removed in the future.
- New service will be the marketinteraction service
- The service will be created and started by the dispatcher team in collaboration with the planning team. In the mid-term, the service will land in the planning domain.

The functional flow (A6) where this service is needed
![Software Architecture - A6. Asset compensation &amp; profitablepowercapacity.jpg](.img/Software%20Architecture%20-%20A6.%20Asset%20compensation.jpg)

## Pros and Cons of the Options

### Option 1: Dedicated service for MarketInteraction

* Good, because we keep the two concepts in separate services, VPP Portfolio != Eneco Portfolio
* Good, because we can remove the VPP Portfolio layer (migration/temporal logic) when it is not needed with no impact on the logic of the long-term solution.
* Bad(?) because we need to add a new service to the system.

### Option 2: Merge functionalities in Portfolio service

* Good, because we already have the service, we can immediately start the ingestion and implement the logic.
* Bad, because we couple the two concepts, removing the unnecessary part of the service could be more challenging.

## Links
