
# Setpoint sending logic is based on asset characteristics to be more asset agnostic instead of the same logic for all assets.

* Status: proposed
* Deciders: Rene Pingen, Ricardo Duncan, Hein Leslie, Johan Bastiaan, Pedro Alonso, Arne Knotternerus
* Date: 2023-05-25

Technical Story:

## Context and Problem Statement
In the current set up for setpoint sending logic in the dispatcher, a mix of steering activation and dispatcher logic:
* https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_wiki/wikis/Myriad---VPP.wiki/12010/Asset-Activation-v2
* https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_wiki/wikis/Myriad---VPP.wiki/6817/Version-0.3-(MVP3)?anchor=**f17-%7C-setassetsetpointfornonancillaryservicessteering**

it cannot correctly take into account the differences between:
* a wind asset that needs scheduled setpoints: A wind asset that does not have a steering box to translate schedules into setpoints and thereby relies on the VPP to do so.
* a wind asset that only needs setpoints when there's an aFRR request or if there's any curtailment. A wind asset that has a steeringbox and only needs setpoint for aFRR steering.
* a conventional asset that requires a setpoint all the time.

As a result, a conventional asset cannot be correctly steered in this design if the total setpoint is higher than the power schedule (bug currently in production). In the current logic, we only send setpoints if we're curtailng. So, if the totalsetpoint comes close to the resultingpmaxpowercapacity, we're not curtailing, and therefore we send NULL setpoints. This logic in the dispatcher doesn't go well with conventional assets that always need a setpoint.


We had discussions on the below options.

## Decision Drivers

* Driver 1: Have a more asset agnostic solution in place that is flexible in the future.
* Driver 2: Uniform implementation based on asset characteristics instead of configuration.
* Driver 3: IOT Platform will create setpoints based on schedules.

## Considered Options

* current implementation
  Stick to the current solution with AncillarySetpointsOnly and add a characteristic where the asset type is included. Use that to determine whether a setpoint should be sent to an asset.

* setpoint sending logic based on asset characteristics.
  Base the logic on asset characteristics, so that you have one characteristic per asset whether you a setpoint should be sent, similar to data preparation calculations. This will also mean that we will remove the asset configuration AncillarySetpointsOnly.

Possible characteristics:
* SEND_SETPOINT_IF_CURTAILED: only applicable to renewable assets connected via Scala
* SEND_SETPOINT_IF_REALTIME_COMPONENT (default): applicable to all assets with a steeringbox that can run a schedule.
* SEND_SETPOINT_CONTINUOUSLY: for conventional assets that are steered via Scala, for scheduled steering and for aFRR steering.


## Pros and Cons of the Options

### current implementation

Good, because of
* Add some logic on top of the current logic might be less risky because we stick to the current implementation

Bad, because
* it's relatively complex

### setpoint sending logic based on asset characteristics.

Good, because
* Logic is simplified per asset
* Resulting variables from data preparation don't have to be manipulated to allow for more advanced setpoint sending logic.
* Asset characteristics are used in the asset dispatcher to determine whether the calculated setpoints should be sent to IOT.
* Determining whether a setpoint should be sent is independent of the asset type.

Bad, because
* asset characteristics are used, so performane isn't great to get the right the right characteristics have to be filtered every time.


## Decision Outcome

Chosen option: **setpoint sending logic based on asset characteristics.**, because:
it simplifies the setpoint sending logic to a few lines of code for an asset and therefore better understandable.

## Links <!-- optional -->
