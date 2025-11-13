
# Steering aggregated pools is be based on telemetry

* Deciders:  [Hein Leslie](mailto://hein.leslie@eneco.com), [Wesley Coetzee](mailto://wesley.coetzee@eneco.com), [Johnson Lobo](mailto://johnson.lobo@eneco.com), [Sebastian Du Rand](mailto://Sebastian.duRand@eneco.com), [Ricardo Duncan](mailto://Ricardo.Duncan@eneco.com)
* Date: 13-07-2023

## Context and Problem Statement

When the agro pool is steered by the VPP aggregation layer, the aggregation layer needs to receive mFRR setpoints from the VPP core. The question here is: how does the VPP core know what the flex capacity is of the aggregated pool? 


## Decision Drivers <!-- optional -->

* Consistency between pools in aggregation layer and large assets
* Steering a pool must be based on reliable values, e.g. updated frequently if pool-composition changes


## Considered Options

* The current size of the pool and its flex capacity is updated realtime via telemetry to the core
* The current size of the pool and its flex capacity is updated via timeseries, e.g. forecasted values
* The current size of the pool and its flex capacity is updated through changing the configuration of an asset


## Decision Outcome

Chosen option: "* The current size of the pool and its flex capacity is updated realtime via telemetry to the core", because it's the most versatile way of sharing the current state (flex capacity) of the pool to the core

## Pros and Cons of the Options 

### The current size of the pool and its flex capacity is updated realtime via telemetry to the core

The current state of the pool (flex capacity, total production) is sent near-realtime via telemetry. If the theoretical size of the pool increases - example: Agro has a new customer, independent whether the customer will have flex available at that time - this will be updated via asset configuration in the asset service.

As of phase 1 in mFRR VPP core, the pool flex capacity is not shared between the aggregation layer and vpp core. The aggregation layer does share the pool's strike price to the core via the existing strike price topic.

* Good, ingestion of the pool's flex capacity doesn't require any changes in the core
* Good, because it's the most versatile. 
* Bad, the forecasted flex of the pool is not known in the core.

### The current size of the pool and its flex capacity is updated via timeseries, e.g. forecasted values

The aggregation layer shares the schedule and the flex capacity of the pool to the aggregation layer. The core will then disaggregate mFRR requests over the pool based on forecasted values.

* Good, because the core knows how much flex capacity a pool has forecasted
* Good, because it's in line with conventional asset steering.
* Bad, because if the pool's size decreases, you might have to update the the currentdatetime's period of the timeseries. This might lead to undesirable latency.


### The current size of the pool and its flex capacity is updated through changing the configuration of an asset

* Good, because it requires little changes in the core
* Bad, because conceptually it's strange to update a pool's size via configuration which is usually static data. 

