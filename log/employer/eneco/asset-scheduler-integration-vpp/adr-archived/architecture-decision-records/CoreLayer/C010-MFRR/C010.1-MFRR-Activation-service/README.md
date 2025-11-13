# mFRR Activation Service

- Status: proposed
- Deciders: [Mark Beukeboom](mailto://mark.beukeboom@eneco.com), [Hein Leslie](mailto://hein.leslie@eneco.com), [Wesley Coetzee](mailto://wesley.coetzee@eneco.com), [Johnson Lobo](mailto://johnson.lobo@eneco.com), [Sebastian Du Rand](mailto://Sebastian.duRand@eneco.com), [Ricardo Duncan](mailto://Ricardo.Duncan@eneco.com)
- Date: 2023-08-01

## Context and Problem Statement

**Ingest mFRR portfolio request from R3 handler**

The objective is to develop the capability to ingest new portfolio requests from the R3 handler specifically for mFRR activations.

Following this, the acquired activation data will be forwarded to Dataprep, which will conduct a snapshot of all the available EANs within the market. Subsequently, Dataprep will perform calculations to determine the average actual power over a 5-minute interval.

Initially, these portfolio requests will originate from the R3 handler, with future plans to establish direct communication with Tennet.

## Considered Options

- Option 1: Create a new mFRR activation service.
- Option 2: Expand the current portfolio service to handle new mFRR requests..

## Decision Outcome

**Chosen option: Option 1**, Considering the distinct differences in activations for each market, it is more logical to segregate mFRR and aFRR logic into separate services. This approach aids in maintaining market-specific logic within dedicated services, thereby reducing code complexity and enhancing resilience in case of market-specific issues, such as service outages or critical bugs.

The separation of market-specific logic into individual services also facilitates the addition of new markets without undue complexity. For instance, if the Belgian market requires a different interface from the R3 handler, as is likely, incorporating this logic into the current portfolio service would lead to complexities. By preserving 'activation' specific logic within separate services per market, a more natural and scalable solution is achieved.

## Pros and Cons of the Options

### Option 1: Create new mFRR activation service.

#### Pros & Cons

- Pros, Establishes a dedicated microservice for mFRR activation, promoting cleaner separation of concerns.
- Pros, Enables focused development and streamlined maintenance.
- Pros, Facilitates autonomous work on this service, minimizing dependency on other teams' release cycles.
- Pros, This service could potentially serve as a reference for removing aFRR activation from the portfolio service.
- Pros, Retains activation logic per market within its respective service.
- Cons, Requires setting up new pipelines, repositories, and involves additional DevOps work.

### Option 2: Update current portfolio service.

- Pros, Involves comparatively less effort for pipeline adjustments, with some additional configuration required but without building an entirely new service.
- Pros, Consolidates all activation logic in a single location.
- Cons, Leads to increased code complexity as each new market and region is added.
- Cons, Carries the risk of introducing breaking changes that could impact both markets.
- Cons,Depends on other teams and their release cycles.
