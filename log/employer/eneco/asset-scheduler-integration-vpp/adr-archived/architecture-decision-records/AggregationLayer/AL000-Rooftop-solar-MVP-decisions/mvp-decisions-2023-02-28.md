# Technical Decisions Rooftop Solar Mvp

* Status: proposed
* Deciders: Rene Pingen, Pedro Alonso, Arne Knottnerus-Yuzvyak, Wesley Coetzee, Alex Shmyga, Johan Bastiaan
* Date: 2023-02-28
* Updated: 2023-02-28

# Decisions

**We will develop the aggregation layer (for now just RTS) in a separate repository, 
and its components will be deployed in a separate namespace inside the k8 cluster**

Decision Drivers
* As the Aggregation Layer should be separate from the VPP Core, it makes sense to also separate it on a code/deployment level

**The SiteRegistry Service will be developed as a .Net WebAPI with REST endpoints**

Decision Drivers
* The SiteRegistry service will have to expose several endpoints to the VPP Core, thus it makes sense to group these inside a WebAPI.
The REST standard is required if we are to use the Eneco API Gateway (Apigee)

**Telemetry Ingestion will be developed as a separate Azure Function**

Decision Drivers
* As telemetry comes in very often and will expand in the future we need to be able to scale this function out independently

**Telemetry Aggregation will be developed as an Azure Function**

Decision Drivers
* Telemetry aggregation will trigger once every minute. This would mean for a large part of time the function would be inactive.
This is the ideal use case of a function on a timed trigger.

**Data from the SiteRegistry Service will be shared by opening up the data for read access**

Decision Drivers
* We do not want to repeat the syncing mechanism we have in the current VPP Core as it requires a lot of maintenance and is vulnerable
to syncing errors. Exposing grpc endpoints comes with additional network overhead and potential performance (caching) concerns.

**Storage for the SiteRegistry Service will be SQL**

Decision Drivers
* We might have to perform complex queries that join pools, sites and assets. The pool entity will be large as it will have
many sites, and each site will have many assets. Also asset itself is already a complex structure.
Trying to manage this complexity in multiple collections in Mongo will be hard, especially since we cannot predict exactly the queries we might
have to perform.

