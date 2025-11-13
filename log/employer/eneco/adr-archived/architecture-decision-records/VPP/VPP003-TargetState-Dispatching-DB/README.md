
# Database for Target State Dispatching

* Status: accepted
* Deciders: Hein Leslie, Wesley Coetzee, Ricardo Duncan, Alex Shmyga
* Date: 2024-10-30

## Context and Problem Statement

Due to restrictions imposed by the German TSO and Purdue security requirements we have to move away from cloud services like Azure CosmosDB,
on which the current Dispatching applications are built, to a technology that could be deployed on-premise.

## Decision Drivers

* Commercial license - Any technology related to the functional components of the VPP must be backed by a commercial license.
* Support/SLA - The VPP is a mission critical system and requires that we have access to timely support during incidents.
* Cost - We should keep costs to a minimum.
* Management difficulty - We will be managing the database itself so it should be easy to manage/maintain.

## Considered Options

* Option 1 - MongoDB
* Option 2 - PostgreSQL

## Pros and Cons of the Options

### Option 1 - MongoDB

MongoDB is a non-relational document database that provides support for JSON-like storage. The MongoDB database has a flexible data model that enables you to store unstructured data, and it provides full indexing support, and replication with rich and intuitive APIs.

* Good, the team already has quite a lot of experience using MongoDB
* Good, less code changes would be required as we are already using the MongoDB API for CosmosDB.
* Good, a Mongo provided K8s operator is available.
* Good, has an OpsManager with a UI that shows DB health, metrics, etc.
* Good, commercial license & support provided directly by Mongo.

### Option 2 - PostgreSQL

PostgreSQL is a powerful, open source object-relational database system with over 35 years of active development that has earned it a strong reputation for reliability, feature robustness, and performance.

* Good, open-source K8s operators are available.
* Good, commercial support provided by "professional services"/third parties.
* Bad, the Dispatching team has little experience with this DB technology.
* Bad, the DAL of all the Dispatching applications would have to be rewritten.

## Decision Outcome

Chosen option: Option 1 - MongoDB, because the team already has experience using this and
the DAL of the current Dispatching implementation is already written to support MongoDB.

This, along with the MongoDB OpsManager and first party support, made MongoDB the preferred option
even though PostgreSQL is a proven database technology.
