
# Scheduled Dispatcher

* Status: proposed
* Deciders: Team Core
* Date: 2024-10-23

Technical Story: [Feature 513020](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_backlogs/backlog/VPP%20Core/Epics/?workitem=513020): Scheduled Dispatching

## Context and Problem Statement

With the introduction of multiple markets, market switching, and the SCHEDULE effective steering mode, we require functionality that can send an asset's schedule as setpoints for assets that are currently not allocated to a market or that do not meet all the requirements for realtime steering on a market (due to missing telemetry, schedules, and so on).

## Decision Drivers

* The scheduled dispatching logic is much simpler than and thus quite different to market dispatching.
* It should be easy to determine which component is responsible for a certain type of dispatching (aFRR, mFRR, Manual, Scheduled).
* We want to keep market dispatching as similar as possible between markets.

## Considered Options

* **Option 1:** Steer these assets as part of the market dispatching logic.
* **Option 2:**  "Piggy-back" the steering of these assets on one of the two market dispatchers.
* **Option 3:**  Create a Scheduled Dispatcher which has the responsibility of steering these assets.

## Decision Outcome

Chosen option: **Option 3:**  Create a Scheduled Dispatcher which has the responsibility of steering these assets.

### Positive Consequences

* Scheduled dispatching can be implemented with little-to-no impact on the market dispatchers.

### Negative Consequences

* Additional service to deploy and maintain
* Extra resources required to run the 3 instances of the service.

## Pros and Cons of the Options

### Option 1: Steer these assets as part of the market dispatching logic

Update the dispatching logic to load and apply schedule setpoints to assets in SCHEDULE steering.

* Good, because we do not have to create another service.
* Bad, because the market dispatching logic would have to be modified to deal with SCHEDULE assets.
* Bad, because we would have to somehow constrain these assets to only be picked up by one of the two market dispatchers. Leading to some inconsistency between the market dispatchers.
* Bad, if the chosen market dispatcher goes down we lose the market and scheduled steering.
* Bad, adds overhead to dispatching logic as it would have to load and loop through assets that don't contribute to the market.

### Option 2: "Piggy-back" the steering of these assets on one of the two market dispatcher

In this option we would write the scheduled dispatching code as separate functionality but it would be hosted by one of the market dispatcher services. We currently do this for manual dispatching.

* Good, because we do not have to create another service.
* Good, because we already have an example of how this would work.
* Bad, creates less inconsistency between the implementation of the two market dispatchers than option 1 but there would still be some inconsistency.
* Bad, if the chosen market dispatcher goes down we lose the market and scheduled steering.
* Bad, performance issues from market dispatching and scheduled dispatching could affect each other.

### Option 3:  Create a Scheduled Dispatcher which has the responsibility of steering these assets

Create and deploy a separate service for schedule dispatching that works the same as the other dispatcher, except for its allocation logic.

* Good, because all dispatcher work similarly.
* Good, because each dispatcher is only responsible for a specific type of steering and don't affect each other.
* Good, because the market dispatching logic remains unchanged and specific to realtime markets.
* Bad, because we have to deploy and maintain a separate service and request more resources from the cluster.

## Links

* [Scheduled Dispatcher wiki](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_wiki/wikis/Myriad---VPP.wiki/47075/Schedule-Dispatcher-Useful-Notes-(soon-to-be-schedule-dispatcher-page))
* [Dispatchers per market wiki](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_wiki/wikis/Myriad---VPP.wiki/41212/Dispatchers-per-market)
* [ESM logic](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_wiki/wikis/Myriad---VPP.wiki/41212/Dispatchers-per-market)