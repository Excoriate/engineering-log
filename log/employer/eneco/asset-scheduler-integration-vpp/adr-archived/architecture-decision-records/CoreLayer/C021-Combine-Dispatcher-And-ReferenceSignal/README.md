# Combine Dispatcher and Reference Signal per Market

* Status: proposed
* Deciders: Alex Shmyga, Hein Leslie, Wesley Coetzee
* Date: 22/10/2024

Technical Story: [Target State Epic](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_workitems/edit/512341)

## Context and Problem Statement

As a starting note, in this document when referring to "ReferenceSignal", it is also referring to the Activation.mFRR Service as they perform the same functionality.

In the context of Dispatching we have two parts, one part is calculating the setpoints for the assets and the other is to report what we are doing as the VPP.
These 2 processes run on the same timer interval, but they are doing this in two separate services. The output from the Dispatcher is also needed in the ReferenceSignal calculation.

This requires us to load a lot of the same data twice, as Dispatcher will load data, then save its output to a collection and then Reference Signal will need to load some similar inputs as well as those setpoints.

## Decision Drivers

Driver 1: Maintainability
Driver 2: Cost reduction
Driver 3: Simplification of process
Driver 4: Performance

## Considered Options

* *Option 1* Leave as separate services
* *Option 2* Combine into a single service

## Pros and Cons of the Options 

### Option 1 - Leave as separate services

* Good, because less development work to be done
* Good, because services can be scaled independently (reaching)
* Bad, because Reference Signal calculations rely on output from Dispatcher
* Bad, because we do more reads than necessary
* Bad, since we need 3 instances of each service, we are not running 6 pods instead of 3
* Bad, the service report our health (Reference Signal) is a different process that is dispatching to assets (Dispatcher)

### Option 2 - Combine into a single service

* Good, because we report health from the same service we dispatch from
* Good, because reduces number of resources needed
* Good, because we reduce the load on the database by not needing to load the same data in two different services
* Good, because both loops will be run in the same process, so the calculations will be in sync.
* Bad, because more development work to be done

## Decision Outcome

Chosen option: "Option 2", because we want to reduce the number of moving parts in L3.

### Positive Consequences

* Reduced load on database as we will need to fetch less data to perform the same calculations
* Reduced number of resources needed

### Negative Consequences

* More development work to be done