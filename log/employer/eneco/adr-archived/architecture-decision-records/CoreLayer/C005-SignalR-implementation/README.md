
# Change Azure SignalR hosting mode to Default

* Status: accepted
* Deciders: Rene, Pedro, Sandeep, Henko
* Date: 2023-03-10

Technical Story: 

## Context and Problem Statement

We are currently running into some limitations with our current SignalR implementation.

When using Azure SignalR there are three hosting modes:

* Default mode
* Serverless mode (Our current mode)
* Classic mode
 
We would like to switch to Default mode to allow us to receive an OnConnected event whenever there is a new connection so we can send the initial state of the data that we are sending on SignalR.
This will allow us to have a single implementation to bind the front end to, instead of our current implementation where we need to fetch the initial state via an API call and then change to binding to a SignalR event.
Examples of components on the Front end that require this are:
* Asset Configruation on monitoring screen
* aFRR delivery widget on homescreen
* Alarms
* Even possibly the graphs on the homescreen

## Decision Drivers <!-- optional -->

* Driver 1: Maintainability: Simplifying and removing duplicate code
* Driver 2: Performance: Removing extra API calls to fetch initial state data
* Driver 3: Future proofing: Once we have a distributed cache we could stream the data from the cache via SignalR

## Considered Options

* Option 1: Keep the solution as is, having duplicate code in the APIs and complex components in the Front end that need to fetch initial state and then subscribe to updates via SignalR
* Option 2: Change Azure SignalR to Default mode allowing to send initial state when new connections are made (When the front end loads and needs the data for the first time)
* Option 3: Keep the Azure SignalR in Serverless mode and add extra complexity by adding Azure Functions to trigger the OnConnected wich would then need to call the APIs or a distributed cache to fetch the initial state and send to the client.

## Decision Outcome

Chosen option: "Option 2 - Change to Default mode", because it is the best solution for all the decision drivers, with minimal changes required.

### Positive Consequences <!-- optional -->


### Negative Consequences <!-- optional -->


## Pros and Cons of the Options <!-- optional -->

### Option 1 - Keep as is (Serverless) - No Change

* Good, because we would not need to change existing SignalR infrastructure
* Bad, because we need to mainain more and more extra code for each new SignalR stream we create
* Bad, because we are currently in a few places still using poling which could be done better.

### Option 2 - Change to Default mode

* Good, because we could cut down on extra duplication of code, making the codebase more maintainable
* Good, because we can reduce the amount of API calls we currently have to make from the front
* Good, because changing the hosted mode to Default will allow the APIs to also connect to hubs and gives us more functionality and options
* Bad, because we would need to change the Azure SignalR deployment which could cause VPP front end downtime. This could be mitigated by deploying a new instance and only switching over.
* Bad, because if all our server hubs (API instances) go down, any existing front end clients would need to reconnect once the new hubs are connected.

### Option 3 - Keep as Serverless mode and add Azure function for extra functionality

* Good, because this would not change the existing SignalR instance
* Good, because we can get access to the onConnected trigger that allows us to send an initial state
* Bad, because it would require a fair bit of extra complexity and work

## Links <!-- optional -->
