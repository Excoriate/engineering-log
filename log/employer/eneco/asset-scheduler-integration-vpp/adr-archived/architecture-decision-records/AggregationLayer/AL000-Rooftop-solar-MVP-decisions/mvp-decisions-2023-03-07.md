# Design Decisions Rooftop Solar Mvp

* Status: proposed
* Deciders: Rene Pingen, Pedro Alonso, Arne Knottnerus-Yuzvyak, Wesley Coetzee, Alex Shmyga, Johan Bastiaan
* Date: 2023-03-07
* Updated: 2023-03-07

# Business requirements
* B2B rooftop solar panes proposition should be able to curtail assets
* In VPP Core UI we should be able to see the telemetry data

# Decisions

**
For MVP version was decided to use imbalance script directly from the aggregation layer. That means that an input for the imbalance script will be prepared in the Telemetry Ingestion/Aggregation functions and an output from the script will be handled directly in the aggregation layer as well, in Schedule Ingestion function. An integration with the imbalance script should be done in a way that it can be reused later in Market Interaction service. Follow up discussion will be performed to do a simple integration with the imbalance script in Market Interaction service when we have more clarity about the last one.
Aggregated telemetry will be published to ESP even if it's not going to be used during in MVP
Aggregated capacity will be published to ESP even if it's not going to be used during in MVP (Rene and Arne will have more discussion about that, might be revisited later)
Strike prices will be published to ESP even if it's not going to be used during in MVP 
Registering pool in VPP Core asset service will be done manually. VPPCoreId in the Site Registry service will be updated manually as well.
Use Azure Functions in telemetry and steering flows.
We shall create a new app (for example "vpp-aggregation") for integration with ESP topics which will be used in the Agg Layer.**

Decision Drivers
* Considering short deadlines (4 sprints) decided to take a short cut remove most of integrations with VPP Core. Mainly because of Market interaction service.
* Since we have some questions opened related to api gateway between core and aggragation layers we think that to manually register a pool in VPP core. In this case we will be able to show telemetry data in VPP Core UI. In the future the same manual steps will be automated.
