
# CosmosDB: dedicated cosmosdb accounts for scalaGW, dispatcher and one shared 

* Status: decided
* Deciders: Rene Pingen, Pedro Alonso, Bram Eldering, Hein Leslie, Tuba Kaya, Johan Bastiaan, Henko Rabie
* Date: 2022-12-15
* Updated: 2022-12-16

Technical Story: 

## Context and Problem Statement

For MVP2.9 there is a need for Cosmos DB storage to serve the following purposes:
1. A CosmosDB for the ScalaGateway, this already exists (named vpp-cosmos-<env>), NoSQL API 
2. Storage for the Dispatcher domain (which consists of 3 services, datapreprocessing, referencesignal, and dispatcher services), which requires a MongoDB API
3. Storage for ConcurrencyConsistency purposes, which can use either NoSQL API or MongoDB API
4. Storage for the ManagementService to store the UI Configuration

Notes:
1. The current vpp-cosmos-<env> Cosmos resource is the ScalaGateway Cosmos DB.  
2. The Health/Watchdog service will use SQL Server for now.

## Decision Drivers 

* Driver 1: Performance: In particular important for the DataPreprocessing service
* Driver 2: Security: Connection strings and keys are maintained on the Cosmos Account level
* Driver 3: Availability: Covered by Cosmos DB 
* Driver 4: Maintanability, from a DevOps and coding perspective.

## Considered Options

* [option 1]
Two Cosmos DB accounts: one for the ScalaGateway (NoSQL API) and one for the rest (all MongoDB API)

* [option 2]
A Cosmos DB account for each purpose

* [option 3]
Three Cosmos DB Accounts:
    * A Cosmos DB account for the ScalaGateway (NoSQL API) (already in place as vpp-cosmos-<env> and we keep that name because changing this name will have a lot of impact and the ScalaGateway is only needed while Eneco still has Scala) 
    * A Cosmos DB account for the Dispatcher domain (which consists of 3 services, datapreprocessing, referencesignal, and dispatcher services) (MongoDB API). This is already in place in the sandbox as vpp-cosmos-dispatcher-d.
    * A Cosmos DB account for the rest (ConcurrencyConsistency and ManagementService as well as other future needs).  Note that the ConcurrencyConsistency is a cross-cutting concern of each service.

## Decision Outcome

Chosen option: "Option 3", because:
* Having a separate Cosmos DB account for the DataPreprocessing provides maximum performance, security and availability for these high throughput and critical services.
* Combining the other MongoDB needs in one Cosmos DB Account avoids having to create unnecessary seperate accounts, so that maintainability is optimal.

### Positive Consequences 
We can continue using the already existing vpp-cosmos-dispatcher-<env> database for the datapreprocessing purposes.
We safeguard the DataProcessing needs in terms of throughput limits and security.

## Pros and Cons of the Options

### [option 1]

* Good, because of maintainability, we only have one Cosmos DB MongoDB Account for all purposes in scope
* Bad, because performance and security may be affected which is a concern in particular for the DataPreprocessing.

### [option 2]

* Good, because performance is safeguarded optimally.
* Bad, because of maintainability, many different instances, connection strings, secrets, etc to manage

### [option 3]

* Good, because performance is safeguarded for the DataPreprocessing purpose.
* Good, because of maintainability, we only have two Cosmos DB MongoDB Account for all purposes in scope

## Links <!-- optional -->

* [User Story] https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_workitems/edit/268643
* [Cosmos DB limitations] https://learn.microsoft.com/en-us/azure/cosmos-db/concepts-limits
