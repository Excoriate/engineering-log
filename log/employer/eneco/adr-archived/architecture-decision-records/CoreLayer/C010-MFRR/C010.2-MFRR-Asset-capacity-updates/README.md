
# Asset capacity in VPP core will only be updated when a new site is added to, updated in, or removed from a pool in the VPP aggregation layer.

* Deciders: [Mark Beukeboom](mailto://mark.beukeboom@eneco.com), [Hein Leslie](mailto://hein.leslie@eneco.com), [Wesley Coetzee](mailto://wesley.coetzee@eneco.com), [Johnson Lobo](mailto://johnson.lobo@eneco.com), [Sebastian Du Rand](mailto://Sebastian.duRand@eneco.com), [Ricardo Duncan](mailto://Ricardo.Duncan@eneco.com)
* Date: 2023-07-14

## Context and Problem Statement

Sites in the VPP aggregation layer could change the pools they are allocated to based on their availability and the market they are allocated to. New sites may also be added to, updated in, or removed from a proposition.

For the Agro proposition, there will be two pools. One for aFRR and one for mFRR, these pools may have a varying amount of sites allocated to them at a given time. Each of these pools are represented as an asset in the VPP core.

As part of their configuration, assets in the VPP core have the following properties, `Max/MinPowerOperating` and `Max/MinPowerCapacityNameplate`. These are typically fairly static but with sites being able to be reallocated from pool to pool, and this potentially affecting these configured properties, this raised the question:

Should asset "static" configuration be updated when sites change pools or only when a new site is registered to or removed from the proposition as a whole?

## Decision Drivers

* The above-mentioned asset configuration is rarely used, and when used, it is only used to apply some limits.
* The aggregation layer will send real-time capacity as telemetry.
* Site allocation can change fairly often (multiple times a day).
* Complexity in the aggregation layer of keeping their Site Registry service up to date with real-time allocation data.

## Considered Options

* Option 1: Every time a site gets allocated to a pool, the asset's configuration will be updated in the VPP core.
* Option 2: Only when new sites get registered/removed will the asset's configuration be updated in the VPP core.

## Decision Outcome

Chosen option: **Option 2**, because it keeps things simple in the aggregation layer and seeing as the real-time capacity of pools will be supplied as telemetry, there is no need to update the assets' configuration every time a site gets allocated to a different pool.

There is one configuration property we need to make a decision about, `MaxRampUp/Down`, which will be discussed as part of a different decision. As sites are allocated to different pools, it could affect how quickly that pool can ramp up and/or down.

## Pros and Cons of the Options

### Option 1: Every time a site gets allocated to a pool, the asset's configuration will be updated in the VPP core.

Taking the Agro proposition as an example, when a new site is allocated from the aFRR to the mFRR pool, the aFRR pool's capacity will decrease and the mFRR pool's capacity will increase. This will cause an update in both assets in the core. Keep in mind that site allocation may change multiple times a day.

* Good, because the asset's configuration will match what the pool max and mins really are.
* Bad, there is a fair bit of complexity with keeping the Site Registry in the aggregation layer up to date when site allocation changes.
* Bad, there could be delays in applying these updates from the aggregation layer, potentially affecting how we steer the assets.
    - This exists for option 2 as well, however, updates are much less frequent in option 2.

### Option 2: Only when new sites get registered/removed will the asset's configuration be updated in the VPP core.

Taking the Agro proposition as an example, when a new site is registered the aFRR and mFRR pools will both be updated with the site's information, i.e. both pool's configured capacity will increase. This will cause an update in both assets in the core. The registration of new sites do not occur as frequently as the reallocation of sites to pools.

This means the "static" configuration of assets in the core and the pools in the aggregation layer will reflect the 
"installed" min/max power operating and capacity.

* Good, because less updates between core and aggregation layer is required.
* Good, because the Site Registry does not need to be aware of real-time site allocation.
* Bad, the asset's configuration might not have a accurate view of the real-time values of these properties.
    - The real-time data will be supplied as telemetry, so this is not really a problem.