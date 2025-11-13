
# Market Interaction To Forward Contract and Bids data to Azure Service Bus for Dispatcher and Fleet Optimizer

* Status: proposed
* Deciders: Tuba Kaya, Ihar Bandarenka, Hein Leslie, Wesley Coetzee, Roel van de Grint, Khyati Bhatt, Pedro Alonso, Rene Pingen
* Date: 2023-03-03

Technical Story:

## Context and Problem Statement

Market interaction service will be evolved to support many other features such as to provide market data to VPP UI (e.g. missed PTUs).
Decisions reflected in this document are to support **initially** the below two features and ensure compatibility with the future vision of the market interaction service and avoid future rework.
* "Profitable power capacity calculation (in dispatcher)"
* "aFRR obligations calculation (in new Fleet Optimizer)"
  functionalities of the VPP platform, we need to retrieve data from kafka streams for balancing reserve contracts and flex market bids.

Given that
* there is no shared way the data needs to be preprocessed to support different functionalities in VPP, but these two functionalities need the market data to be preprocessed in different ways (dispatcher needs to query it for a given point in time and fleet optimizer needs data in chunks per PTU and calculation of voluntary contracts)
* we want it to be easy to test and debug a feature (no need to learn how to form the input for a service owned by another team to simulate different test scenarios)

We had discussions on the below options.

## Decision Drivers

* Driver 1: Maintainability: from a developer's perspective, ease of local development and being able to drive changes on a specific feature as a team without needing to be dependent on another team. From business perspective low cost of change.
* Driver 2: Availability: dependencies on runtime to an API vs service's own db
* Driver 3: Deployability: being able to release features implemented in autonomous services

## Considered Options

* [option 1]
  Market Interaction service stores data in its database to support all the functionalities and expose the data through its API. Data Preprocessor for dispatcher and a future service part of fleet optimizer implementation retrieve market related data through this API.

* [option 2]
  Data Preprocessor for dispatcher and a future service part of fleet optimizer implementation consume kafka streams for market data directly, which they store in their own database.

* [option 3]
  Market Interaction service acts as a single consumer for market data from kafka streams. It consumes kafka messages and publishes Azure service bus messages after validation and translation of the data. Data Preprocessor for dispatcher and a future service part of fleet optimizer implementation consume the published Azure service bus messages, which they store in their own database.

* [option 4]
  Option 3 but without us implementing a full blown (Market Interaction) service, instead using a tool to make this transformation.

## Pros and Cons of the Options

### [option 1]

Good, because of
* consistency to design of other existing services such as asset planning service which also collects data from kafka streams and exposes it through its API
* having a single point of truth for market related data making the VPP system less eventually consistent but more atomic

Bad, because
* the market interaction service would need to prepare data in different ways to support several functionalities which have different requirements,
* having a dependency on this service in runtime from user services makes it so that we have to deploy them all together,
* local development becomes harder because for example dispatcher team would need to know how to feed the market interaction service in order to simulate test scenarios instead of (from other options) being able to run their own service and ingest data according the contract that they already know from their service

### [option 2]

Good, because
* services can consume data from its source and preprocess it as needed for the feature at hand
* service can be deployed standalone
  Bad, because
* this requires multiple consumers from VPP on kafka streams which requires a bureaucratic discussion within Eneco
* local development is currently harder for developers with kafka streams compared to azure service bus queues/topics due to the fact that on sandbox environment there is a single consumer on kafka streams which is shared between pods from sandbox and locally running services. Adding more consumers (for example one per developer) would again require bureaucratic discussions. Using a local kafka instance is probably the right way to go but this is currently not being done and requires time for somebody from the team to spend time to get it working, which then all other developers can follow.
* using two messaging orchestrators (kafka and azure service bus) from a service is more complicated than using one (azure service bus) since then we need to switch between two very different ways of working (e.g DLQ vs no-DLQ). Also, feeding our service locally with test data becomes harder as we can send azure service bus messages through a tool but to feed kafka streams we would need to write integration test API endpoints

### [option 3]

Good, because
* same as option 2, plus:
* service would only use azure service bus and therefore avoid implementation details in infrastructure level that come with using kafka streams
* we can feed the services easily via azure service bus explorer to simulate test scenarios
* we can create a separate topic and/or subscription per developer easily for local development
  Bad, because
* we would need to maintain a service that consumes to kafka streams for market related data and translates it to azure service bus messages, which seems like either could be done by a general "forwarder" service (instead of one called Market Interaction) or an off the shelf ETL tool

### [option 4]

Good, because
* same as option 2, plus:
* we don't need to maintain a full blown .NET application
  Bad, because
* finding the right tool for this would take time

## Decision Outcome

Chosen option: **Option 3**, because:
* see why option 3 is good, plus:
* tickets are in our current sprints, which puts pressure on timeliness of the solution
* we don't know how long it would take to have the discussions for option 2 regarding having multiple consumers from VPP on kafka streams and whether the conclusions of these discussions would be to allow this
* we don't know how long it would take to consider different options instead of creating a service ourselves to consume kafka streams and forward the data. Given the timeliness requirements, it seems like a good option to build a service ourselves (for now) which can be considered to be replaced later

![Software Architecture - A6. ProfitablePowerCapacity & aFRR Obligations.jpg](.img/Software%20Architecture%20-%20A6.%20ProfitablePowerCapacity_aFRR%20Obligations.jpg)

In the future we will can persist data underneath Market Interaction service for the purpose of providing ingested market data to VPP UI or if this service needs to publish new messages to support features for rooftop solar.


## Links <!-- optional -->

* [User Story 1] https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_workitems/edit/251427
* [User Story 2] https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_workitems/edit/269038
* [User Story 3] https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_workitems/edit/297264
