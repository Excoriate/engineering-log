
# Use PowerSchedule as datamodel for all dispatchable powerschedules with a Type field that indicates the type (VRE and non-vre)

* Status: accepted
* Deciders: Arne Knottnerus, Mark Beukeboom 
* Date: 16/12/2022
## Context and Problem Statement

How to deal with different types of schedules for different asset types that result in different stages of the scheduling process within the VPP?

## Requirements/constraints
- Each asset will have one schedule that is dispatchable, meaning that it is used to steer the asset. This ensures there is only one truth within the VPP which schedule the asset should follow.
- A schedule for a VRE (VRE= Variable Renewable Asset, Wind/Solar) (curtailmentschedule) can contain nulls (meaning no curtailment), a schedule for a non-vre asset may not contain nulls.
- For specific consumers, it is needed for VRE's to combine the ProductionForecast with the Curtailmentschedule to calculate the expectedpoweroutput.
- Currently there are multiple processes that create dispatchable PowerSchedules:
  - For non-VRE's the outcome of the FleetOptimizer process results in the dispatchable PowerSchedule. (to be published in ESP AssetPowerSchedule)
    - The output of asset specific models for conventionals also create powerschedules, but as these can be updated by the FleetOptimizer (technicals) we do not consider the output of asset specific models as dispatchable. These will be published as FeasiblePowerSchedules on feasible-power-schedule-1 topic ESP.
  - For VRE's the outcome of intraday trading processes create dispatchable CurtailmentSchedules (currently published in ESP  AssetCurtailmentSchedule)
    - In the future this might change if it is decided to allow the fleetoptimizer update CurtailmentSchedules.


## Decision Drivers

* Understandability/maintainability: Ensure data definitions are clear and understandable.
* Future proof: Avoid rework when we build out the VPP later on.

## Considered Options

* [option 1]: Use the PowerSchedule data object for both curtailmentschedules and regular PowerSchedules, add a Type=CurtailmentSchedule/PowerSchedule field to indicate the type.
  * Pro: One single timeserie for all dispatchable powerschedules. Dispatching schedules as well as setpoints do not need to differentiate beteween asset types (asset agnostic logic)  
  * Con: Potentially confusing for developers as in the current state two ESP topics (one for curtailmentschedules and one for PowerSchedules) end up in the same data entity.
  * Pro: The con above will disappear if the fleetoptimizer will also update curtailmentschedules. Then the fleetoptimizer produces all powerschedules for both VRE's and non-VRE's.

* [option 2]: Use a dedicated timeserie for PowerSchedule (non-VRE) and CurtailmentSchedule (VRE)
  * Pro: One-to-one mapping of incoming ESP topic to data entity
  * Con: Most consumers (Asset monitor for UI, alerting UI, Asset Dispatcher, Reference Signal) will need to consume different timeseries depending on asset type. (not asset-agnostic)

## Decision Outcome

Chosen option: "[option 1]", because this model allows consumers to decide if they need to differentiate between CurtailmentSchedules and regular PowerSchedules. Consumers that don't need this information do not need to differentiate between asset types.
