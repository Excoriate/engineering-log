# Manual Dispatcher

* Status: proposed
* Deciders: Alex Shmyga, Hein Leslie, Wesley Coetzee
* Date: 22/10/2024

Technical Story: [Target State Epic](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_workitems/edit/512341)

## Context and Problem Statement

VPP Core has the ability for an operator to manually send a setpoint to an asset in the event of an issue with steering, or to test the connection between VPP and the asset.

This functionality is currently built into the aFRR Dispatcher, which is not correct as this functionality has nothing to do with any market.

## Decision Drivers

Driver 1: Separation of concerns
Driver 2: Maintainability
Driver 3: Scalability
Driver 4: We should keep the market dispatcher market specific

## Considered Options

* *Option 1*: Create a new Manual Dispatcher
* *Option 2*: Leave Manual Dispatcher piggy backing off of Dispatcher aFRR
* *Option 3*: Put this logic in the Scheduled Dispatcher

## Pros and Cons of the Options

### Option 1 - Create a new Manual Dispatcher

Create a separate Manual Dispatcher that handles steering assets that are in ESM Manual.

* Good, because separation of concerns
* Good, because single responsibility
* Good, because aFRR/Scheduled Dispatcher will not affect manual steering and vice versa
* Good, because Manual Dispatcher will need less changes over time
* Bad, because another service to run and maintain

### Option 2 - Leave Manual Dispatching in aFRR Dispatcher

Currently Manual dispatching is handled by the aFRR Dispatcher

* Good, because no additional development needed
* Bad, because Manual Steering can affect aFRR steering and vice versa
* Bad, because manual steering is not specific to a market at all
* Bad, because we now have logic in the loops to handle manual assets

### Option 3 - Put Manual steering logic into Scheduled Dispatcher

Since Scheduled Dispatching is not market specific, we could put all non market specific steering into a single Dispatcher.

* Good, because all non market related steering is done in one place
* Good, because less resources
* Bad, because additional development work
* Bad, because the logic to steering manual assets vs scheduled is vastly different, so the loop would still need to handle these separately.

## Decision Outcome

Chosen option: "Option 1", because Manual Dispatching does not belong to any specific market.

### Positive Consequences

* Changes to Manual Dispatcher will not affect any of the market dispatchers

### Negative Consequences

* Another service running
* Additional resources