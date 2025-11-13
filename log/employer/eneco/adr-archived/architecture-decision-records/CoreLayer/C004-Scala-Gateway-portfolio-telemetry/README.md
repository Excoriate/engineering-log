
# Write all portfolio telemetry from the Reference Signal service

* Status: accepted
* Deciders: [Hein Leslie](mailto://hein.leslie@eneco.com), [Rene Pingen](mailto://rene.pingen@eneco.com), [Pedro Alonso](mailto://pedro.alonso@eneco.com), [Mark Beukeboom](mailto://mark.beukeboom@eneco.com)
* Date: 16-02-2023

Technical Story: [285909](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_workitems/edit/285909)

## Context and Problem Statement

Historically, with the MVP2.5 implementation, we had to aggregate and write some portfolio telemetry from the Asset Dispatcher service to the Scala Gateway as only it had the required data available. This meant that both the Asset Dispatcher and Reference Signal services had to write portfolio telemetry to Scala Gateway.

With the move to MVP2.9 and onwards, the required data is provided by the resulting variable calculations which the Reference Signal service has full access to. So now we can write all portfolio telemetry from the Reference Signal service, offloading some complexity & dependencies from the Asset Dispatcher service.

## Decision Drivers

* The Asset Dispatcher loop needs to be as fast as possible.
* The Reference Signal service now has all the required data.
* Originally, only the Reference Signal service was supposed to write to Scala Gateway.
* One less dependency in the Asset Dispatcher, and Reference Signal already has this dependency.

## Considered Options

* Option 1: Keep the solution as is, some telemetry calculated and written from each service.
* Option 2: Move all portfolio telemetry to the Reference signal service.
* Option 3: Move functionality to an Azure Function

## Decision Outcome

Chosen option: Option 2, it simplifies the current solution and reduces the responsibility of the Asset Dispatcher.

### Positive Consequences

* No longer need to remember if some telemetry is written from the Asset Dispatcher vs the Reference Signal service.
* Simplifies the Scala Gateway integration as 2 services don't have to update the same document.

### Negative Consequences

* The behaviour of MVP2.5 and MVP2.9 is different.

## Pros and Cons of the Options

### Option 1: Keep the solution as is, some telemetry calculated and written from each service.

* Good, because no changes are requried..

### Option 2: Move all portfolio telemetry to the Reference signal service

* Good, does not require big code changes.
* Good, it simplifies the Asset Dispatcher by removing a dependency
* Good, the Asset Dispatcher has to do less improving perfomance and freeing up cycle time.
* Good, the Reference Signal already has a dependency on the Scala Gateway.
* Bad, because the Reference signal has to do more work.

### Option 3: Move functionality to an Azure Function
The Scala Gateway functionality is part of a migration phase and will eventually be removed. Moving this to a function simplifies separates it from our core code/services.

* Good, can be removed once the migration layer is no longer needed.
* Good, removes the responsibility from the Asset Dispatcher and Reference Signal. Similar to reasons in Option 2.
* Bad, would require a fair amount of new development.

## Links

* [Scala Gateway integration](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_wiki/wikis/Myriad---VPP.wiki/6936/Scala-Gateway-Cosmos-DB)