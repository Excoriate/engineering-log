<font style="font-size:32px;color:#E12A03;font-weight: bold" > mFRR core implementation build permit </font>
---

<font style="font-size:30px;color:#E12A03" > PERMIT #: 21/07/2023</font>  

|        |        |
|-------------------|----------------------------------------------------------------------------------------------------------------------------|
|**TITLE:**| **mFRR core implementation build permit**                                                                                                        | 
| **Summary of proposition/ feature:**|  **This proposition involves extending the existing VPP core to allow participation in the mFRR market. The scope included in this build permit is limited to development of steer wind assets and an aggregated pool of Agro CHPs. We therefore continue to rely on the existing R3 handler for communcation with Tennet but replace Nemocs and allow for the addition of renewable assets. Also note that this permit only includes work expected from Team Dispatcher** |                                                                                                        |


<h1 style="font-size:30px;color:#E12A03" >APPROVALS: </h1>

**Product Owner approval:**
- [ ] Yes 
- [ ] No

**Solution Architect approval:**
- [ ] Yes 
- [ ] No

**DevOps approval:**
- [ ] Yes 
- [ ] No

**Platform approval:**
- [ ] Yes 
- [ ] No

**QA approval:**
- [ ] Yes 
- [ ] No

 **DATE ALL APPROVED:** <span style="font-weight:bold;color:#E12A03;font-size=-1.6m"> xx/xx/xxxx</span>

## DEVELOPMENT TEAM(S) & INDIVIDUALS:
**1. Team dispatcher:**
- Mark Beukeboom
- Hein Leslie
- Johan Bastiaan
- Wesley Coetzee
- Johnson Lobo
- Sebastian du Rand
- Dhawal Salvi

<h1 style="font-size:30px;color:#E12A03" > PRODUCT PERSPECTIVE </h1>

<span style="font-size:16px;font-weight:bold;background-color:#FFAF75;margin: 2px 2px;display:inline-block;">1. List of key functionalities to be developed: </span>

From the total list of functional flows relevant to mFRR developments (described [here](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_wiki/wikis/Myriad---VPP.wiki/13119/The-mFRRda-system)), the following functionality has been designated for development within the core:

- Add/update/remove an mFRR capable asset(s) to the VPP core (e.g. a single large asset, or a pool from the aggregation layer)
- Update the VPP core representation of an aggregation layer pool, following a change in the aggregation layer composition
- Update the R3 handler representation of a VPP core asset/pool, following a change in the core layer composition
- Aggregation of availability and active power data from Assets in VPP Core. Output to R3 Handler
- VPP Core ingests R3 Handler setpoint and distributes, using VPP Core business logic rules
- Portfolio response communication and update
- Deviation management (VPP Core)
- Operator monitors relevant mFRR data during an activation (VPP Core)
- VPP Core ensures an asset which is qualified on multiple mutually exclusive markets can not be actived on more than one (like aFRR and mFRR) based on market allocation data, and ensures a 15 minute window of downtime when switching between markets

<span style="font-size:16px;font-weight:bold;background-color:#FFAF75;margin: 2px 2px;display:inline-block;">2. Not in scope: </span>
<p style="font-weight:bold;font-size:14px;color: #FF8536;font-style:italic;font-weight:normnal;margin: 2px 2px;display:inline-block;">List any scope being excluded or
tactical decisions made
</p>

- Asset planning: The functionality to define which market each asset can and should operate in is out of scope for Team dispatcher, but the core functionality being built will of course support market switching. Storage of market allocation/planning data is also out of scope for team dispatcher, expected development within the asset planning service. This is stored in asset planning under AllocatedIn entity, which is used by the data preparation to decide whether the asset can be operated for mFRR, aFRR or other. See [here](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/DesignDecisions/pullrequest/53551). This data is shared between AssetPlanning and Dataprep in the same way as other timeseries are shared between these two services (gdpr).
- mFRR phase 3: Phase 3 is replacing all R3 handler functionality within the VPP, this is currently out of scope. This build permit only considers phase mFRR wind and Agro pool on mFRR.
described on the [wiki](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_wiki/wikis/Myriad---VPP.wiki/13119/The-mFRRda-system), flows 3.1, 3.2, 5.1a are only relevant for phase 3 and hence out of scope for this build permit. 
- Aggregation of small assets: Core will only consider 'large' assets (large renewables, conventionals and pooled assets). Logic relating to the aggregation of small assets should be contained entirely within the aggregation layer and are therefore not listed here. 


<span style="font-size:16px;font-weight:bold;background-color:#FFAF75;margin: 2px 2px;display:inline-block;">3. Non-functional requirements (NFR's): </span>
<p style="font-weight:bold;font-size:14px;color: #FF8536;font-style:italic;font-weight:normnal;margin: 2px 2px;display:inline-block;">e.g. expected requests/second,
support 10k assets, process 
duration < 4s, etc.
</p>

- The core expects to support a relatively small number of 'large' mFRR assets. The mFRR chain is designed to steer up to 1000 assets, but the performance will be tested up to 20 assets. 
- The dispatcher cycle is designed to run on a 4 second cycle. This running frequency guarantees a sufficient granularity to promptly steer and accurately monitor assets behaviour, with the aim of satisfying business requirements (all edge cases comprised)  

<span style="font-size:16px;font-weight:bold;background-color:#FFAF75;margin: 2px 2px;display:inline-block;">4. Extensibility/ Product Vision: </span>
<p style="font-weight:bold;font-size:14px;color: #FF8536;font-style:italic;font-weight:normnal;margin: 2px 2px;display:inline-block;">Will this functionality need to be extended
to support other markets, countries, asset types, business propositions? To what extent should this be included in the design?
</p>

- Should support all asset types
- Should be integrated with the market switching functionality, to support assets operating on multiple markets (e.g. aFRR and mFRR)
- At this stage other countries are not considered 

<span style="font-size:16px;font-weight:bold;background-color:#FFAF75;margin: 2px 2px;display:inline-block;">5. Planned Delivery date: </span>
<p style="text-decoration:underline;font-weight:bold"> Very rough estimation but assume end of year 2023</p>


<h1 style="font-size:30px;color:#E12A03" > TECHNICAL PERSPECTIVE </h1>

<span style="font-size:16px;font-weight:bold;background-color:#FFAF75;margin: 2px 2px;display:inline-block;">1. Solution design diagram:</span>

<p style="font-weight:bold;font-size:14px;color: #FF8536;font-style:italic;font-weight:normnal;margin: 2px 2px;display:inline-block;">Be sure to include all external interfaces, internal VPP components and infrastructure dependencies in the diagram
</p>

**Note that this design only covers part of the total core layer functionality for mFRR. This picture and accompanying descriptions will be expanded following further refinement sessions**

![Deliverable 1](https://eneco.sharepoint.com/:i:/r/sites/EET_004/Extern2/mFRRda/NewDeliverable.png?csf=1&web=1&e=m4cNoK)

**Overview:**

Each asset (be it core or aggregation layer) provides telemetry data to the telemetry ingestion service. This service reads the data and passes it on to data preparation. Separately,
the asset planning service provides data on which assets from those enabled for mFRR, are currently allocatedTo the mFRR market (as opposed to aFRR or others). 
- Data preparation uses both datasets in its resulting variable equations which are passed on to the dispatcher. A subset of these resulting variables are also used in the reference signal service. 
- A new service ingests the activation request from R3 handler and passes it on to the dispatcher via data preparation. Furthermore, it calculates the reference value (in this case a static value), and forwards it to Reference Signal Service.
- The reference signal service provides largely the same functionalities as for aFRR, but injests the reference value, rather than actively calculating it. Furthermore, during the whole activation time, it compiles a list with volume allocated volume per-EAN, that's shared to R3 Handler and subsequently to TenneT, as by requirement. 

When an mFRR portfolio request is received in the mFRR dispatcher, this service first combines the portfolio request with any compensation request that may also be received from the reference signal service. 
The dispatcher then takes the total mFRR request and distributes it amongst the mFRR allocated assets with consideration of strike price, asset schedules, asset ramping limitations, reference value and other factors. 
Ultimately this service outputs 4-second setpoints for each mFRR allocated asset, together the setpoints allocated to the mFRR portfolio should meet the desired response of the portfolio request (i.e. the static reference value + portfolio request).

Note that details on the specific functionality of affected services that can be picked up or released later has been excluded given that these things are likely to change. Also, existing technology is used where we can. No new technologies have been identified.


<span style="font-size:16px;font-weight:bold;background-color:#FFAF75;margin: 2px 2px;display:inline-block;">2. Solution Context: </span>
<p style="font-weight:bold;font-size:14px;color: #FF8536;font-style:italic;font-weight:normnal;margin: 2px 2px;display:inline-block;">How does the solution fit into
the broader landscape? What are the external Interfaces?
</p>

- Aggregation layer: Provides telemetry data to the core, receives a pool-level setpoint(s) for each pooled asset.
- Asset Planning: Provides the allocatedTo timeseries that indicates on which market (aFRR, mFRR, imbalance, null) each asset and pooled asset is allocated to for each PTU. 
- R3 handler: Provides the mFRR portfolio request. Receives reporting and monitoring data tbd. 


<span style="font-size:16px;font-weight:bold;background-color:#FFAF75;margin: 2px 2px;display:inline-block;">3. Infrastructure & network design: </span>
<p style="font-weight:bold;font-size:14px;color: #FF8536;font-style:italic;font-weight:normnal;margin: 2px 2px;display:inline-block;">What infrastructure changes
are needed?
</p>

There are no expected infrastructure changes.
The only currently expected technology change is to use .NET 7

<span style="font-size:16px;font-weight:bold;background-color:#FFAF75;margin: 2px 2px;display:inline-block;">4. Dependencies on other teams:</span>
<p style="font-weight:bold;font-size:14px;color: #FF8536;font-style:italic;font-weight:normnal;margin: 2px 2px;display:inline-block;">Summarize the work required by
other teams for this feature/proposition to go live?
</p>
 
<ins>Team WattsUp:</ins>
The main dependency here is to ensure the core layer design is compatible/cohesive with the aggregation layer implementation. This is expected to be particularly important for:
- Core layer asset onboarding of pooled assets: to ensure the asset characteristics and telemetry ingestion of pooled assets is compatible
- Dispatching decisions: to ensure the dispatching requests we send to pooled assets are in the expected format and works with aggregation layer dispatching
- Monitoring: To ensure we receive all necessary monitoring data, in the correct format, from pooled assets
- Communication with Tenergy and Agro. All connections with Tenergy and Agro are handled via the aggregation layer, the core is therefore dependent on Team Wattsup's successful implementation of these connections.

<ins>Team Planning and/or Operations team (whomever is responsible for building the Asset Planning service): </ins>
Again, the main dependency is to ensure the design intention for the market switching mechanism is compatible/cohesive with the core layer. Particularly for:
- Dispatching: the mFRR dispatcher should only send setpoints to those assets which are allocated to the mFRR market at that moment, the way in which asset planning implements market allocation will have implications on how the dispatcher is built
The core will also be dependent on asset planning to ensure there are no scheduling conflicts, i.e. that an asset is not allocated to both aFRR and mFRR at one time. 
Details of the feature found here: https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_workitems/edit/358548

<ins>Team Yellow:</ins>
- To ensure TY can ingest the VPP portfolio data (via ESP) and integrate it into the R3 handler such that we can offer mFRR from the VPP portfolio
- Dependent on their cooperation to understand the existing data connections and data formats used for the NEMOCS connection



<span style="font-size:16px;font-weight:bold;background-color:#FFAF75;margin: 2px 2px;display:inline-block;">7. Quality/ Health Metrics:</span>
<p style="font-weight:bold;font-size:14px;color: #FF8536;font-style:italic;font-weight:normnal;margin: 2px 2px;display:inline-block;">What quality/ health metrics will be
exposed to reflect health of the feature?</p>

The same monitoring will be in place for mFRR as for aFRR. An overview below:

Dispatcher and reference signal:    
- cycleCount, cycleTime,  inputLoadTime, inputPrepareTime, LogicTime and outputWriteTime

Data preparation:
- ResultingVariable CalculationTime,

Schedule ingestion:
- grpcCallTime
- HydrationTime

Reporting on functional flows
- PortfolioRealtimeDeliveryReport
- AssetRealtimeDeliveryReport
- AssetPostDeliveryReport

<span style="font-size:16px;font-weight:bold;background-color:#FFAF75;margin: 2px 2px;display:inline-block;">8. A high-level QA strategy has been agreed by relevant stakeholders </span>

- [X] Yes 
- [ ] No

> High level QA strategy: https://eneco.sharepoint.com/:w:/r/sites/EET_004/_layouts/15/Doc.aspx?sourcedoc=%7BC877DB88-5DE7-4F62-B9D1-3305CA2B592F%7D&file=mFRR%20QAStrategy%20.docx&action=default&mobileredirect=true

<span style="font-size:16px;font-weight:bold;background-color:#FFAF75;margin: 2px 2px;display:inline-block;">10. Key DevOps changes, if any, have been identified </span>
- [X] Yes 
- [ ] No
> Describe the key devOps changes here
- seperate release pipeline for dispatcher
- activation service`
