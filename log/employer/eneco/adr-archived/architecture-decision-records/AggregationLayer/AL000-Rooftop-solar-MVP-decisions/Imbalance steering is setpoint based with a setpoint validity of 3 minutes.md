# Imbalance steering is setpoint based with a setpoint validity of 3 minutes

* Status: proposed
* Deciders: Rene Pingen, Pedro Alonso, Arne Knottnerus-Yuzvyak, Mark Beukeboom, Kyati Bhatt, Alex Shmyga, Johan Bastiaan
* Date: 2023-04-03
* Updated: 2023-04-03

# Business requirements
* Aggregation layer should ingest output from imbalance script so we can disaggregate it among aggregated assets
* The imbalance script produces setpoints that should be followed by assets for 3 minutes. This is a constant value in this period.
* Steering for imbalance should be the same across the VPP, whether assets are large assets or smaller aggregated assets.

# Decisions

**We will process the imbalance script output as setpoints instead of schedules. Also we will publish the disaggregated values as setpoints instead of schedules.
This results in changing the functions we had planned from Schedule Ingestion to Setpoint Ingestion, and Schedule Disaggregator to Setpoint Disaggregator.
Another implication is that we should use a setpoint format towards the assets that includes the type of setpoint (e.g. imbalance) as well as the duration it should be followed (in this case 3 minutes/180 seconds)**

Decision Drivers
* Imbalance is real-time calculated every cycle, not looking forwards, so logically it's a setpoint, not a schedule
* Output from imbalance script is one consistent value with a certain validity period and wont change over time
* For IOT it will be easier to use a setpoint to send towards the steering boxes
