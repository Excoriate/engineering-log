# Add steering policies concept as a part of a device on configuration


* Date: 2023-09-25


# Glossary
- VPP Core - Virtual Power Plant
- VPPAL - Virtual Power Plant Aggregation Layer

# Context
Devices in the field have different ways of being controlled/steered.
Within the VPP Core we currently only support analog steering - meaning any setpoint between min/max is possible as long as we adhere to constraints like minimum/maximum operating power.

There are devices which cannot be controlled like this.

Some examples:

Home e-boilers can only be turned on/off.
PV inverters have curtailment settings that only allow the power to be controlled using discrete steps (for example; 100%, 90%, 60%, 30%, 0%).
We expect this to happen often for devices in the VPPAL, and also expect it to be slightly different for different devices.

To support this along with devices which can accept any setpoint, we will implement the concept of steering policies and steering policy levels.

The steering policy determines the way the device can be controlled.


# Decisions
During the disaggregation process we distinguish how we use devices with each of these steering policies:

- Analog devices can be given any setpoint between allowed min & max.
- Discrete devices can be given setpoints that correspond to one of the steeringpolicylevels configured during device onboarding.

Those properties will be filled in during onboarding process of new devices via Site Registry. Example:
```json
{
    ...
    "steeringPolicy": "Discrete", // enum value
    "steps": [
        {
        "value": 20
        },
        {
        "value": 50
        },
        {
        "value": 80
        }
    ]
    ...
}
```


# Decision Drivers
To be able to use devices in the most efficient way we need to apply different ways of steering based on the configuration of devices.

We do not expect the steering policy of a device to change often (or at all). Therefore setting this up as configuration data in device onboarding is the logical choice.