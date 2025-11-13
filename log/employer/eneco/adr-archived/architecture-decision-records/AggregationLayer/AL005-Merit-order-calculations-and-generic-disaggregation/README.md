# Merit order calculation and generic disaggregation/dispatching in VPP Aggregation Layer

* Date: 2023-10-10
* Deciders: Rene Pingen, Ricardo Duncan, Arne Knottnerus-Yuzvyak, Khyati Bhatt, Cameron Goss, Alex Shmyga

## Glossary
- VPP Core - Virtual Power Plant
- VPPAL - Virtual Power Plant Aggregation Layer
- Pool - a group of devices with similar business (strike prices, etc) and technical (the way how to dispatch) characteristics grouped to participate in a specific market
- Pool type - a combination of Proposition and Market where the pool will be active
- PTU - Programme Time Unit

## Context
### Current state:
Currently disaggregation functionality in VPPAL has two pieces:
- Setpoint ingestion function app
- Disaggregation function app

*Setpoint ingestion function app* is responsible for setpoints ingestions, pool/device strike prices, pool/device telemetry, etc.. Such data is used to determine an order how devices are going to be dispatched.

*Disaggregation function app* is responsible for disaggregation/dispatching pool setpoints into device setpoints.

### A disaggregation logic and a merit order:
Devices in a pool are dispatched to achieve preferred dispatch outcome based on the market the pool is active on. We assume we will always do this using a merit order.

In VPP Core (and the energy industry in general), merit order is based on cost price or a derivative thereof (strike prices).
In VPP Aggregation, the merit order is based on business rules determined per pool (or proposition, where several pools can share the same rules). This can be based on strike prices, but other factors may come into play, such as:
- type of device
- contracted vs redundant capacity
- times a device has been activated throughout the year
- etc...

The calculations of merit order should be done before PTU starts and it's calculated for PTU. The more input data we have and more devices are in the pool the more time it might take to calculate merit order.


## Problem Statement
Currently VPPAL does not have a logic to calculate a merit order and a generic (market and proposition agnostic) disaggregation functionality.

## Decision Drivers
- for different proposition we might have additional input data, such as number of activations, type of device, contracted vs redundant capacity, etc.. to be able to calculate Merit Order. We need to have isolated compute resources to have a predicted calculation time
- setup some base architecture which will allow us to scale later when we face B2C clients
- have a generic way of disaggregation different pool types

## Decisions
- Have a separate function app for Merit Order Calculation which is a part of Disaggregation subdomain in VPPAL
- A separate function per pool type will be implemented inside Merit Order Calculation function app. When we have a completely different and complex logic for calculation merit order UP and DOWN we will have two different functions
- Create a generic disaggregation function inside disaggregation function app
- The new generic disaggregation function will work in shadow mode for RTS proposition during month. If everything ok after we will deprecate RTS disaggregation function and switch to the generic disaggregation function for RTS as well
- Setpoint ingestion function app shall be renamed to Data Ingestion Functions App (or better name)

![Proposed architecture of disaggregation component](.img/GenericDisaggregation.jpg)


## Considered Alternatives
- place merit order calculation function inside *Setpoint ingestion function app* . In this case calculation time won't be predictable, because if other part are having bigger load then calculation might take more time
- place merit order calculation function inside *Disaggregation function app*. Again, the calculation time is not predictable and calculation time might have a negative impact itself on the disaggregation process


## Links <!-- optional -->
- [General rules for disaggregation within the VPP Aggregation Layer](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_wiki/wikis/Myriad---VPP.wiki/32092/General-rules-for-disaggregation-within-the-VPP-Aggregation-Layer)