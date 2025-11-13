# Communication between VPP Core Dispatcher Services (L3) and VPP Aggregation Layer (L4) in VPP International

* Status: accepted
* Deciders: Hein Leslie, Wesley Coetzee, Tomasz Brzezinski, Alex Shmyga
* Date: [2025-09-18]

## Glossary
- VPPCore = VPP dispatcher services
- VPPAL = VPP Aggregation Layer

## Context and Problem Statement
In the target architecture, VPPCore will move to Level 3 (L3) to comply with the Purdue Reference Model.

Currently, communication between VPPCore and VPPAL occurs via the ESP. However, in the future state, VPPCore at L3 will not have direct connectivity to Level 4 (L4) where ESP resides. Communication must therefore pass through the Transfer Zone, which will utilize Azure Event Hubs to facilitate secure and decoupled data exchange between L3 and L4.

This ADR outlines the decision regarding how aggregated telemetry and setpoints should be exchanged between VPPCore and VPPAL under the new constraints.


## Decision Drivers
* Simplicity
* Efficient data flows
* Ease of maintenance
* Compliance with the Purdue Model

## Considered Options
* Sync aggregated telemetry and setpoints between ESP (L4) and IoT Event Hubs (L3)
* Sync aggregated telemetry and setpoints between ESP and L3.5 Event Hubs
* VPPAL publish directly to L3.5 Event Hubs, bypassing ESP

## Pros and Cons of the Options 

### Option 1: VPPAL → ESP → IoT Event Hubs (L3) → Iconics
![](img/option1.png)
* Good, aggregated assets are integrated with VPPCore the same way as real assets
* Bad, requires additional integration between ESP and Event Hubs
* Bad, two brokers in the communication path (ESP + Event Hubs)
* Bad, violates the Purdue Model by allowing L4 to write directly to L3
* Bad, adds maintenance overhead
* Bad, inefficient data flow due to intermediary layers


### Option 2: VPPA → ESP → L3.5 Event Hubs → Iconics
![](img/option2.png)
* Good, aggregated assets are integrated similarly to real assets
* Good, complies with Purdue Model (using Transfer Zone at L3.5)
* Bad, requires additional integration between ESP and Event Hubs
* Bad, two brokers in the communication path (ESP + Event Hubs)
* Bad, increased maintenance complexity
* Bad, inefficient data flow

### VPPAL → L3.5 Event Hubs → Iconics
![](img/option3.png)
* Good, aggregated assets are integrated with VPPCore the same way as real assets
* Good, fully compliant with the Purdue Model
* Good, only one broker in the communication path (Event Hubs)
* Good, more efficient and streamlined data flow
* Good, reduces reliance on ESP for data routing
* Bad, requires small refactoring VPPAL to publish directly to Event Hubs

## Decision Outcome
Chosen option: Option 3 – VPPAL publishes directly to L3.5 Event Hubs
This option best meets our acceptance criteria:
 * It aligns with the Purdue Model
 * It simplifies the architecture by reducing intermediaries
 * It ensures efficient data flows and easier maintenance over time
 

