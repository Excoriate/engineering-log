# AssetPowerSchedule.IsReschedulable
## Include new Asset Characteristic logic: AssetPowerSchedule.IsReschedulable (similar as steering mode)
* Status: proposed 
* Deciders: Rene, Arne, Mark
* Date: 2023-08-04

## Technical Story:
For optimization logic to determine if it is allowed to change the powerschedule of an asset. 

Reschedulable: 
The possibility to change the powerschedule of an asset which has been made by the traders for other reasons than technical limitations. 
(An example why recscheduling an asset may happen, is as a result of optimal allocation of aFRR capacity by the FleetOptimizer)

## Context and Problem Statement:
After the sales position of an asset has been determined, optimizations may want to change the schedule of an asset for reasons other than technical feasibility.
For certain assets, this may only be possible and/or desirable in one direction (up/down) due to restrictions such as existing congestion deals.

An example:
We have an aFRR up contract of 100MW. At a certain point there is in the portfolio a deficit for this contract of 10MW. 
An solution would be to change the powerschedule of Enecogen 10MW to ensure we meet the contract again. 
The FleetOptimizer should now know if it can change this schedule or not. 

## Proposal:
- During onboarding the state is set automatically to disabled.
  (Can in future be an option in onboarding file)
- In the UI the state can be changed to Disabled, Enabled, EnabledUp, EnabledDown.
- Then if there is a congestion deal for an asset (deal on the stream: coo-eet-std-alignecongestiondeals-1), the state of that asset changes automatically with the following logic:
   - If CongestionDirection == Buy
    Disabled -> Disabled
    Enabled -> EneabledUp
    EnabledUp -> EnabledUp
    EnabledDown -> Disabled
  - If congestionDirection == SELL
    Disabled -> Disabled
    Enabled -> EnabledDown
    EnabledUp -> Disabled
    EnabledDown ->EnabledDown

- First iteration: An asset can only have one state for an optimization. With the following prioritization:
Disabled > EnabledUp/EnabledDown (if both in optimization window then Disabled) > Enabled

- Future iteration: an asset can have multiple states for an optimization. Work in progress. 

## Decision Drivers
We need to catogorize each asset for the optimization
We need to have the option for congestion deals

## Links
- Wikipage:
[https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_wiki/wikis/Myriad---VPP.wiki/13221/Asset-Characteristic-AssetPowerSchedule.Reschedulable-logic]

- Tickets:
[https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_workitems/edit/286271]
[https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_workitems/edit/314571/] (work in progress)