
# Data Prep and Dispatcher should have shorter cycle durations

* Status: proposed
* Deciders: [Mark Beukeboom](mailto://mark.beukeboom@eneco.com), [Hein Leslie](mailto://hein.leslie@eneco.com), [Wesley Coetzee](mailto://wesley.coetzee@eneco.com), [Johnson Lobo](mailto://johnson.lobo@eneco.com), [Sebastian Du Rand](mailto://Sebastian.duRand@eneco.com), [Johan Bastiaan](mailto://johan.bastian@eneco.com), [Ricardo Duncan](mailto://Ricardo.Duncan@eneco.com)
* Date: 2023-07-13

## Context and Problem Statement

**Should Data Prep and Dispatcher have long or short cycle times?**

mFRR activations have a longer time to respond to setpoints they receive, up to 15 minutes. 

This means that in theory we could slow down the cycle time of the Dispatcher and send fewer setpoints, as the assets have more time to ramp to their setpoints.

The problem with slowing down the cycle time is that we would then compensate a lot slower, as we would only compensate when the cycle timer runs. It also counts for allocation of mFRR when the available flex is decreasing, and the mFRR allocation of the previous cycle cannot be allocated to that asset again to the full extent.

If we shorten the cycle time down to 4 seconds, we then have the ability to compensate at real time, however we will be sending a lot of setpoints which isn't technically needed.

## Considered Options

* Option 1: Shorter cycle time, 4 seconds.
* Option 2: Longer cycle time, 1 minute.

## Decision Outcome

**Chosen option: Option 1**, there is no harm in sending more frequent setpoints to the assets and this allows us to handle compensations.

## Pros and Cons of the Options

### Option 1: Shorter cycle time, 4 seconds.

Keep the cycle time down to 4 seconds, this would allow for more real time calculations

* Good, we can compensate more frequently.
* Good, CORE can compensate for aggregation layer if there is an issue there.
* Good, we already calculate all resulting variables in real time as we do the calculations on Telemetry received.
* Good, we already handle ramping in aFRR, so the logic should be the same.
* Good, more accurate calculations as we receive APE frequently.
* Bad, we will be sending a lot more setpoints than are needed.
* Bad, more compute resources that are not technically needed.

### Option 2: Longer cycle time, 1 minute.

As assets have a lot longer to ramp, we do not need to send setpoints regularly to the assets.

#### Pros & cons
* Good, we will send fewer setpoints to assets.
* Good, we would technically need to use a lot less compute power.
* Bad, we would handle compensation infrequently.
* Bad, CORE would respond slower to aggregation layer compensation issues.
* Bad, we would be ignoring a lot of APE values coming in.
* Bad, Data Prep already calculates resulting variables in real time.
