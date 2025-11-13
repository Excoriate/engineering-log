# Message broker in Transfer Zone in VPP International

* Date: 2024-10-06
* Deciders: Ricardo Duncan, Hein Leslie, Wesley Coetzee, Roel van de Grint, Alex Shmyga

## Glossary
- L4 zone - security Purdue model 4, public cloud IT landing zone. OpenShift cluster with network and resource isolation
- L3 zone - security Purdue model 3, private cloud, on-prem, OT landing zone. OpenShift cluster with network and resource isolation
- Transfer Zone – so-called Purdue 3.5, part of OT landing zone, used for transferring data between L3 and L4 zone
- Stamp - OpenShift cluster with dispatcher services and infra. In L3 will be 2 stamps, one active, and one redundant hot stand-by.
- VPP Core - set of services responsible for optimization and steering enterprise-level assets

# Context
Currently VPP Core is running in the L4 zone. 
To be able to meet German requirements for VPP, asset control-related services have to be moved to Purdue model 3. It means that dispatching services (dispatchers for aFRR and mFRR, DataPrep, ReferenceSignal, Activation, TelemetryIngestion) should be deployed to L3.
Communication between dispatching services and services in L4 (for example AssetPlanning, AssetServices and VPP UI) should be done via Transfer Zone.
Since most of the current communication between services is asynchronous,  a message broker should be selected. It will be placed in TransferZone.

## Requirements
- Full RBAC control per country/queue/stream
- Should be able to handle at least 1k messages 50kBytes each
- Max size of a message > 200kBytes
- Durable messages
- Costs effective
- Highly Available setup
- Support rolling upgrades (no downtime during upgrades)
- It should be able to run on-prem

## Decision Drivers
- meet requirements
- costs effective
- one instance(clustered) of message broker to handle all countries, multi-tenancy
- nice to have: 
    - support of DeadLetter queues
    - support of streaming functionality
    - ease of integration with ESP/Kafka
    - engineers familiar with technology
    - be installed and managed via the OpenShift operator

## Considered Options
| **Criteria**                | **Mosquitto**                  | **RabbitMQ**                            | **Kafka**               |
|---------------------------|----------------------------------------------|-------------------------------------------------------|--------------------------------------------------------|
| **Primary Use Case**       | Lightweight messaging for IoT devices        | Message queueing for distributed systems              | High-throughput distributed streaming and log management |
| **Message Protocol**       | MQTT (Message Queuing Telemetry Transport)   | AMQP 0-9-1, 1.0, STOMP (Streams), MQTT (via plugin or Native MQTT from RabbitMQ 3.12), HTTP, WebSockets              | Custom protocol, binary over TCP (Optimized for throughput) |
| **Architecture**           | Single-node broker. Mosquitto Pro enterprise supports clustering                          | Single-node with support for clustering               | Distributed, designed for scalability and partitioning  |
| **Persistence**            | Supports both persistent and non-persistent messages | Messages can be persistent or transient               | Messages are persistent by default (log-based)          |
| **Scaling**                | Primarily single-node, limited scaling       | Supports clustering, horizontal scaling via sharding  | Horizontally scalable via partitioning and replication |
| **Performance**            | Low latency, lightweight for constrained environments | High performance for many-to-many communication       | Extremely high throughput, optimized for large volumes of data |
| **Data Retention**         | Typically short-lived (transient messaging). Persistent sessions can be used in Mosquitto for QoS 1 and 2 which means messages are persisted until clients acknowledge them (and persisted between client disconnects)  | Messages retained until consumed (or based on TTL), streams can be persisted permanently    | Configurable retention periods, can persist data for long-term |
| **Message Delivery Semantics** | At most once, at least once, or exactly once (QoS levels) | At most once, at least once, or exactly once, QoS0 and QoS1          | At most once (default), at least once (with idempotence) |
| **Fault Tolerance**        | Basic, single-node reliability (Pro version supports HA via clustering whereby queues are synchronized across the cluster nodes enabling new nodes to be elected as leader if previous leader node dies.)              | Supports queue and stream mirroring for fault tolerance                | Replication, leader election, automatic failover        |
| **Ordering Guarantees**    | Ordered within topic with QoS 2             | Messages ordered in a queue, FIFO with some configurations, for super streams an order only guaranteed per partition | Per-partition ordering (strong within a partition, weak across partitions) |
| **Throughput**             | Low-to-medium, designed for lightweight IoT data | Medium throughput, suitable for enterprise applications | Extremely high throughput, suitable for large-scale event streaming |
| **Message Size**           | Typically small messages                    | Small-to-medium messages, configurable limits         | Designed for large-scale message sizes (even batch mode) |
| **Security**               | TLS/SSL, basic authentication               | TTLS/SSL, LDAP, OAuth, SASL, virtual hosts, access control | TLS/SSL, Kerberos, ACLs (fine-grained security)         |
| **Ease of Use**            | Simple to set up and configure, minimal dependencies | Broad ecosystem, many libraries, and client support   | Requires more expertise to configure and manage         |
| **Use Cases**              | - IoT (Internet of Things) applications<br> - Lightweight device communication | - Distributed systems<br> - Task scheduling<br> - Messaging between microservices | - Real-time streaming<br> - Log aggregation<br> - Big data analytics |
| **Maturity**               | Highly specialized for MQTT use cases       | Mature, broad usage in industry                       | Very mature for event streaming, log processing, analytics |
| **Community & Support**    | Active MQTT community                       | Very active, strong enterprise support                | Large open-source community, strong support from Confluent |
| **Plugins & Extensibility**|Limited plugin support|Extensive plugin system and custom extensions|Extensive plugin system and custom extensions|
|**Availability**|3 node clustering (1 active node, 2 passive nodes with full sync) and automated leader election through Mosquitto Pro|Native clustering with master-slave architecture. Quorum queues and streams| Clustering|
|**Federation**|federation through MQTT brokering|Supports federation for distributed messaging|yes|
|**Payload size constraints**|268 mbytes, can be configurable|3.7GB, can be configurable| default 1mb, can be changed|
|**Payload Schemas**| no|no|yes, via schema registry|
|**Message replay/ event sources**| no|yes|yes|
|**Partitioned message flows**|no|yes|yes|yes|
|**Multi-tenancy**|no|yes|yes|
|**Paid support response time for P1 incidents**|on the website stated up to 4 hours|Low Severity (< 1 business day), Medium (< 8 business hours), High ( < 2 business hours), Critical (< 30 minutes 24 * 7 * 365)| via CMC|
|**Installed as OpenShift Operator**|only under the Enterprise licence |yes|yes|
|**Costs**|an estimation for infra costs for Mosquito based on 1x 3 node cluster for PROD and ACC, and a single node each for DEV and TEST. Infra node cost for 4GB RAM, 4 CPU node as recommended for Mosquitto is 8k euros per year with CMC (a bit less than the higher spec RabbitMQ node). This comes to 64k for infra for Mosquitto across all envs |One cluster: €58 546.24 per stamp, Two: €117 092.48 per stamp (PROD and ACC). However, the cluster will be very heavily un-utilized, so we can use it for another load. Plus additional costs for maintenance. Total costs needed for prod licenses is 50k (with negotiation it can go <40k per year)|€211k|

## Decisions

RabbitMQ looks like the most prominent option for the following reasons:
- meeting requirements  (mentioned above)
- suitable for event-driven architecture
- licenses only needed for production environment
- can be installed as an OpenShift operator
- most acceptable option from a cost point of view
- routing keys enable more sophisticated message routing to consumers, if needed
- best vendor support for both broker and client
- support for both streaming (append-log) and queuing semantics
- support of multi-tenancy

In the future, we might also consider replacing ServiceBus in L4 with RabbitMQ. It will help to be more cloud-agnostic in L4 services as well.

## Links and references
[Mosquitto vs RabbitMQ vs Kafka comparison table](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_wiki/wikis/Myriad---VPP.wiki/48212/Mosquitto-vs-RabbitMQ-vs-Kafka)
[RabbitMQ multi-tenancy support](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_wiki/wikis/Myriad---VPP.wiki/47931/RabbitMQ.-Multi-tenancy-support)
[RabbitMQ. Overview and performance tests](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_wiki/wikis/Myriad---VPP.wiki/47348/RabbitMQ-overview-and-performance-tests)



