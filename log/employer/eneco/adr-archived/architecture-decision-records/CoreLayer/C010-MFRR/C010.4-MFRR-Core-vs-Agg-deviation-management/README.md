
# VPP core deviation management will not take VPP aggregation deviation management into account

* Deciders: [Mark Beukeboom](mailto://mark.beukeboom@eneco.com), [Hein Leslie](mailto://hein.leslie@eneco.com), [Wesley Coetzee](mailto://wesley.coetzee@eneco.com), [Johnson Lobo](mailto://johnson.lobo@eneco.com), [Sebastian Du Rand](mailto://Sebastian.duRand@eneco.com), [Ricardo Duncan](mailto://Ricardo.Duncan@eneco.com)
* Date: 2023-07-13

## Context and Problem Statement

**Should deviation management in the VPP core take into account that the VPP aggregation layer will do its own deviation management?**

When dispatching mFRR setpoints to assets, assets may not always follow their allocated setpoints or they might follow with some delay or delta. This is called deviation. To manage this, the VPP needs to generate additional setpoint requests so other assets can compensate for the deviating assets, this is called compensation.

The first proposition for mFRR is the Agro-pool which is currently managed by Nemocs, which performs some deviation management. The VPP aggregation layer will be taking over the management of this pool and will also have to do some kind of deviation management.

This raised the concern whether deviation and the management thereof in the aggregation layer could affect the deviation management done in the core and should this be something the VPP core tries to take into account.

Deviation management has generally been straightforward for the aFRR market as asset's have been "single entities" and not an aggregation or pool of many smaller assets, exceptions being propositions like Jedlix and the e-boiler pool. These propositions are similar to the Agro-pool as they are "VPPs within the VPP" and for these propositions the VPP does not take into account whether those assets do their own compensation.

## Considered Options

* Option 1: Deviation management in the VPP core should not try to take into account that deviation management will also be done in the VPP aggregation layer.
* Option 2: In our design, we should attempt to take into account how the VPP aggregation layer does deviation management.

## Decision Outcome

**Chosen option: Option 1**, because it keeps our deviation management simple and similar to the aFRR deviation management. It also eliminates any timing issues or possibility of asset/proposition specific logic creeping in to the core's deviation management logic.

While we could see some unnecessary compensation or small oscillations, these should be short-lived and is something we should specially test for. If the core generates compensation for a pool in the aggregation layer while the aggregation layer is also trying compensating for the pool deviation, once the pool's deviation stops the core will stop generating additional compensation as the pool's delivery would now match the allocated mFRR setpoint.

## Pros and Cons of the Options

### Option 1: Deviation management in the VPP core should not try to take into account that deviation management will also be done in the VPP aggregation layer.

Both the VPP core and VPP aggregation layer would have to do some deviation management but this can be done independently, with little to no affect on each other as shown by propositions like Jedlix and the e-boiler pool in the aFRR market.

* Good, it keeps things simple and similar to aFRR.
* Good, the VPP core remains proposition/asset agnostic.
* Good, keeps the core and aggregation layer deviation management decoupled.
* Bad, a little bit of compensation might done in the core unnecessarily or we might see some oscillations.
    - However, this "unnecessary" compensation should be short-lived.
    - This should specifically be tested for.

### Option 2: In our design, we should attempt to take into account how the VPP aggregation layer does deviation management.

There was some discussion around trying to take into account that compensation might be done in the VPP aggregation layer. The only thing we could try to do in the core is to determine compensation at a slower rate to give the aggregation layer some time to do its own compensation first. This raises a few questions:
* How much slower is "slower"?
* Will this work for each propositions deviation management logic?

#### Pros & cons
* Good, we could possibly avoid doing unnecessary compensation in the core or avoid some small oscillations.
* Bad, couples the core and aggregation layer's deviation management.
* Bad, relying on the timing between 2 distributed systems is fragile and difficult to control.
* Bad, might cause some proposition/asset specific compensation logic to bleed into the VPP core if we encounter problems down the line.
