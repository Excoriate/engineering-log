# Design Decisions Rooftop Solar Mvp

* Status: proposed
* Deciders: Rene Pingen, Pedro Alonso, Arne Knottnerus-Yuzvyak, Wesley Coetzee, Alex Shmyga, Johan Bastiaan
* Date: 2023-02-21
* Updated: 2023-02-21

# Decisions

**Telemetry and strikeprices (input for imbalance) will be presented to the VPP Core as it where any other asset.
That means the aggregated telemetry will be published to the ESP stream we are currently using to receive telemetry.
Strikeprices will be published to the ESP stream we are currently using to receive telemetry in assetplanning. (Approval pending from Rob).
As a result the new Bidmanagement/MarketInteraction service will have to take these inputs and combine them into suitable input for the Imbalance script**

Decision Drivers
* We do not want the VPP Core to have different logic for handling generic input streams such as telemetry/strikeprices depending on the proposition
* We want the VPP Core to be able to monitor Pools in the same way as we monitor any other asset
* We want to re-use existing ESP streams as much as we can
