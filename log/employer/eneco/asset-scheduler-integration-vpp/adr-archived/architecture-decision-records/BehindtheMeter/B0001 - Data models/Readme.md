# Use Medallion architecture for data modelling in ADX

[[_TOC_]]
* Status: proposed
* Deciders: Rene Pingen, Ricardo Duncan, Pedro Alonso
* Date: 2023-11-22

# Context and Problem Statement
For the behind-the-meter optimisation (HEMS and Hermes propositions) we need to process many data streams and timeseries. To ensure scalability, reliability and maintainability we need to organize the data effectively. As such, we propose data modeling standards.

## Decision Drivers

* Driver 1: Flexibility to support multiple propositions, device types, markets while keeping structure and overview
* Driver 2: Correctness of data insights and processing

# Considered Options

## 1. Create data structures as we need them for propositions (point-solutions)
In this scenario we just create data structures as we need them for propositions.
- Pro: fastest time to market for initial propositions
- Con: limited reusability of data definitions and insights 
- Con: will become less maintainable on the long run and lead to problems

## 2. Medallion architecture (three layers) [PROPOSED OPTION]
A medallion architecture is a data design pattern used to logically organize data in a lakehouse, with the goal of incrementally and progressively improving the structure and quality of data as it flows through each layer of the architecture (from Bronze -> Silver -> Gold layer tables). 
The concept of medallion is the current industry standard on data modeling and widely used.
Links:
- [Microsoft: What is the medallion lakehouse architecture?](https://learn.microsoft.com/en-us/azure/databricks/lakehouse/medallion)
- [Databricks: Medallion Architecture](https://www.databricks.com/glossary/medallion-architecture)

The proposal is to use the following layers
- ***Bronze:*** Bronze tables contain the raw data from external source systems such as the ESP, and include the raw data and metadata such as correlation ID's and timestamps for traceabilty.
- ***Silver:*** Deduplicated re-usable data products that can be used directly or combined with other datasets for optimal re-use. Is decoupled from the source system.
- ***Gold:*** Datasets designed specifically for a use case, which typically includes aggregates and combinations of silver data sets.

Guidelines to work with the different layers are documented below.

### Considerations
- Pro: Enables the use of clearly defined datasets decoupled from source systems.
- Pro: Promotes re-usability of datasets across different uses of the data. 
- Pro: Promotes a data driven way of working to enable more use cases and standardisation even outside the VPP.
- Pro: allows for better testability of data transformations.

- Con: Creating data definitions requires clear alignment between product managers and architects (more work).

## 3. Follow separate layers (e.g. Raw, Cleansed, Curated,Transformed)
Alternatively it is possible to add more layers, such as a separate layer for data cleansing and curated data sets. 

- Pro: Allows more finegrained data definitions, access control and separation of concerns
- Con: Each layer adds complexity and overhead
- Con: Each layer adds potential latency in data processing

# Guidelines
This section below is an initial set of guidelines which will be updated on the wiki later. This is included here to give an indication, while presenting a decision on the use of the Medallion architecture.

Key guidelines for the layers:
- The Bronze layer is implemented as Tables which typically ingest Events. The bronze layer is not intended to be read directly by other applications, as that will cause coupling.
  
- The Silver layer will be implemented as [MaterializedViews](https://learn.microsoft.com/en-us/azure/data-explorer/kusto/management/materialized-views/materialized-view-overview). 
  
  _Rationale: Materialized views allow aggregation (Tables with Update policies do not), which is needed to deduplicate data (e.g. duplication or newer events overwriting older events)_ 
- The Gold layer will be implemented as Queries/ADX Functions, or where possible Materialized View or supported by caching or materialize() functions for performance.

 _Rationale: Queries and functions will allow easy joining of the data. Materialized views over multiple tables combining data are not an option at this stage. If lower latency is needed, we need to look at alternatives._

## Layers
### Bronze layer data conventions
Bronze tables contain the raw data from external source systems such as the ESP. Examples of Bronze layer tables are `TelemetryBronze` and `ForecastBronze`.
- Bronze layer tables contain the raw data as it was retrieved/created or generated, and should include basic metadata as timestamp and correlationID's.
- Bronze layer tables  have the `Bronze` postfix in their name. For example: `TelemetryBronze`. 
- Bronze layer tables have a datetime column that indicates the moment the data was generated/created/retrieved. This can be used to deduplicate the data in the Silver/Gold layer.
- Although data is kept in a mostly raw state, additional (metadata) fields may be added which may be helpful later.

### Silver layer data conventions
Deduplicated re-usable data products that can be used directly or combined with other datasets for optimal re-use. Is decoupled from the source system.
- Silver layer is used to transform, filter or enrich the Bronze layer data.
- Silver layer should not have duplicate data. 
- Silver layer should have the `Silver` postfix in their name. For example: `CustomerSilver`. 

### Gold layer data conventions
Gold layer data sets should be consumption-ready and use-case specific. 
- Gold layer should not have duplicate data.



## Standards for different types of data
### Timeseries
- Timestamps in timeseries data should always be in UTC. 
- Timeseries data should contain a from and a to timestamp. This will make it clear what the period of each individual record is. These columns should be named `From` and `To`. 
- Timeseries data in the Silver or Gold layer should be normalized so that entries are expanded to multiple rows. So each entry is one row in the dataset. 

### Reference/master data
- Reference data should include a UTC timestamp called `ChangedAt` that indicates when the data was published. This allows us to retrieve the latest values of reference data and create a State data format.

### State data
- State data is data that returns the last known state for a entity. For example, the most recent value of EV.IsConnected indicates if the EV is still connected.
- The state data should contain timestamp information on when the information was last updated. If different properties of the state entity have different update timestamps, multiple update timestamps should be returned in the row. For example, the latest state of an EV contains columns for the `BatteryLevel` and `Range`, so we should have two corresponding timestamp columns, one for each EV property.

## Naming conventions
Below we have setup a list of naming conventions for tables and columns in our ADX database. 
1. Use PascalCase names for tables and columns.
2. Postfix table names with the `Bronze/Silver/Gold` standard names. For example: `TelemetryBronze`, `CustomerSilver`, `EvStateGold`.
3. Avoid abbrevations if possible, prioritize readability. The exception to this rule is common abbrevations that are used for units of measure in the energy market, such as MWh and kW.
4. Maintain consistency in naming across different tables. For example, if a column is named `CustomerId` in table A, it should **not** be called `CustomerIdentifier` in another. 
5. Choose column names that are descriptive of the data they represent. Avoid ambiguous or overly generic names.
6. Table names and columns should not contain spaces.
7. Table names and columns should not contain underscore or other types of symbols.
8. Adhere to the [ADX entity naming conventions](https://learn.microsoft.com/en-us/azure/data-explorer/kusto/query/schema-entities/entity-names) from Microsoft. 

## Guidelines for retrieving data from ADX from code or dashboards
In order to avoid breaking applications or dashboards when data formats change, applications or dashboards should never directly query Bronze or Silver tables. Applications should only retrieve data through ADX functions or by directly querying Silver tables. 

## Guidelines on when to use materialized views / update policy
There are two different ways to transform data between different layers of the medallion architecture: Materialized views and update policies. Both have their pro's and con's and choosing between these two options will depend on your use case. We should follow the [Microsoft guidelines](https://learn.microsoft.com/en-us/azure/data-explorer/kusto/management/materialized-views/materialized-view-overview#how-to-choose-between-materialized-views-and-update-policies), which are as follows:
- Materialized views are suitable for aggregations, while update policies are not. Update policies run separately for each ingestion batch, and therefore can only perform aggregations within the same ingestion batch. If you require an aggregation query, always use materialized views.
- Update policies are useful for data transformations, enrichments with dimension tables (usually using lookup operator) and other data manipulations that can run in the scope of a single ingestion.
- Update policies run during ingestion time. Data is not available for queries, neither in source table nor in target table(s), until all update policies have run on it. Materialized views, on the other hand, are not part of the ingestion pipeline. The materialization process runs periodically in the background, post ingestion. Records in source table are available for queries before they are materialized.
- Neither update policies nor materialized views are suitable for joins. Both can include joins, but they are limited to specific use cases. Namely, only when matching data from both sides of the join is available when the update policy / materialization process runs. If the matching entities are expected to be ingested to the join left and right tables during the same time, there is a chance data is missed when the update policy / materialization runs. See more about dimension tables in materialized view query parameter and in fact and dimension tables.