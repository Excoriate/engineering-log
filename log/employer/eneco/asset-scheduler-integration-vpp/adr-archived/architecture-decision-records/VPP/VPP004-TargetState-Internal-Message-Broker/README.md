- # Internal Message Broker in VPP Target State

- Status: proposed
- Deciders: [Mark Beukeboom](mailto://mark.beukeboom@eneco.com), [Hein Leslie](mailto://hein.leslie@eneco.com), [Wesley Coetzee](mailto://wesley.coetzee@eneco.com), [Alex Shmyga](mailto://alex.shmyga@eneco.com), [Ricardo Duncan](mailto://Ricardo.Duncan@eneco.com)
- Date: 2024-10-030

## Context and Problem Statement

Due to the OT/ Purdue security uplift of the VPP dispatcher in the Target state for VPP International, it is no longer possible
for the VPP dispatcher to communicate (setpoints and telemetry) with the SCADA system via ESP (streaming platform running in L4 IT Zone).
The need for an L3 "internal" message broker therefore arises to enable communications between the VPP dispatcher and the new SCADA system,
Iconics in L3. 

A design principle for VPP international is to keep the country-specific deployment stamp the same across all countries, with
network, storage and compute isolation between stamps. Each stamp therefore requires its own internal broker to communicate
between the country-specific dispatcher and the Iconics SCADA system. The high level architecture is depicted in the
diagram below:

Figure 1- High Level Target State architecture for VPP international
![Target state architecture](.img/vpp_target_state_arch.jpg)

The use of a message broker prevents direct coupling between the dispather and Iconics and as such needs to meet a number of
requirements as outlined in the table below

| Requirement per country Internal Message Broker                                     | Rationale                                                                                                                                                                   | MoSCoW |
|-------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------|
| Message throughput of 2000 messages/ second of 1kb each on a single broker instance | Expected traffic for 500 assets (x2 directions x2 routes)                                                                                                                   | M      |
| Protocol supported by Iconics platform e.g. MQTT                                    | Iconics is the system that will connect to assets                                                                                                                           | M      |
| Support queued and non-queued messaging delivery                                    | Non-queued required for low latency & fast recovery. Queued for use cases prioritizing guaranteed delivery above low latency.                                               | M      |
| Support for custom TTL or retention times                                           | Mitigate delayed resumption of realtime service due to large message backlogs caused by incidents (when message persistence is used)                                        | S      |
| Low latency message transfer through the broker (sub 500ms)                         | The full cycle of responding to portfolio requests is ~9 seconds in BE. aFRR dispatcher is a realtime process. Data transfer should therefore be quick                      | M      |
| Support for clustering                                                              | Increases availability of a single stamp, reduces dependency on failover to other stamp for some node failures                                                              | S      |
| Message persistence capability                                                      | Increased resiliency against message loss for guaranteed message delivery use cases                                                                                         | S      |
| Cluster-wide message and queue topology replication                                 | Increased resiliency against message loss caused by node failures, for guaranteed message delivery use cases                                                                | C      |
| Support for rolling upgrades                                                        | Upgrade mission critical infrastructure with no downtime                                                                                                                    | S      |
| Availability of a management console                                                | Easier management                                                                                                                                                           | M      |
| Comprehensive monitoring of broker operations including metrics                     | Required for mission critical operation                                                                                                                                     | M      |
| Shipped as container image                                                          | No need to create a container image ourselves                                                                                                                               | S      |
| Deployable with an Openshift operator                                               | Easier to manage                                                                                                                                                            | C      |
| Fast broker launch/ restart                                                         | Quick restart is leaner than clustering and stamp failover to other DC                                                                                                      | S      |
| Low and stable resource consumption                                                 | Lower Opex                                                                                                                                                                  | C      |
| Support encryption of messages in transit e.g. transport layer security             | Message confidentiality                                                                                                                                                     | M      |
| No licence servers (OT environment security requirement)                            | OT environment is too restricted for licencing servers                                                                                                                      | M      |
| No functional expiration date (OT environment continuity requirement)               | Functional loss due to expiration of licences is not tolerable. This is a big future risk for the operational continuity and therefore heavy leverage for a broker supplier. | M      |
| Security mechanisms for client authentication and authorization                     | Security control                                                                                                                                                            | M      |
| Commercial license available (including commercially-backed broker client)          | More assurances from commercially-backed software, including support                                                                                                        | M      |
| 24x7 commercial support for broker software                                         | Support mission critical high-availability                                                                                                                                  | M      |
| 24x7 commercial support for client software                                         | Support mission critical high-availability                                                                                                                                  | S      |
| Strong, active development community                                                | Essential for improved software quality, security, bug fixing and new features                                                                                              | S      |
| Support bridging/ federation/ connection of brokers                                 | For connection to external systems                                                                                                                                          | M      |
| Low cost per broker instance (we need many deployment stamps)                       | Full target architecture requires ~20 active acc/prod deployment stamps plus an unknown number of dev/test stamps.                                                          | S      |
| Regular updates (especially security updates)                                       | Essential for improved software quality, security, bug fixing and new features                                                                                              | S      |

## Considered Options

- Option 1: Mosquitto Pro as internal message broker
- Option 2: RabbitMQ as internal message broker

## Pros and Cons of the Options

### Option 1: Mosquitto Pro as internal message broker
Mosquitto is a highly popular MQTT broker that has been commercialized by Cedalo as Mosquitto Pro. 
Mosquitto Pro meets most of the internal message broker requirements, so only the key pros and cons will be
elaborated below.

*Costs for Option 1 [CMC infa prices + vendor licenses]:*

*3 node (4GB RAM, 4CPU, 100GB storage) cluster per country X 3 countries X 2 stamps (failover) X 2 envs (PROD & ACC): **€357k***

*Single node (4GB RAM, 4CPU, 100GB storage) broker per country X 3 countries X 2 stamps (failover) X 2 envs (PROD & ACC): **€123k***

#### Pros & Cons

- Pro: Cheaper than RabbitMQ including volume-based discounts
- Pro: Can be deployed as single node or HA cluster (active/ passive mode with leader election and replication of in-flight messages and persistent sessions
- Pro: Support for low latency message delivery with QoS 0 (no queuing)
- Pro: Support for persistent sessions (with QoS 1)
- Pro: Supports MQTT-bridging to connect to external systems e.g. IoT
- Pro: Light-weight with low resource consumption (reduces Opex) and quick startup time
- Pro: Exportable metrics to Prometheus/ Grafana
- Con: Less seamless deployment process than RabbitMQ
- Con: New technology for all Myriad engineers, increasing operational complexity of solution
- Con: No commercially backed client included in vendor software distribution, necessitating search for a commercial client from a different vendor with uncertain support offering
- Con: Widely used for communication with resource-constrained remote devices over unreliable networks, potentially less used for communication between colocated components in a data center

### Option 2: RabbitMQ as internal message broker

RabbitMQ is a hugely popular message broker with a strong development community. With the recent addition
of Streams, RabbitMQ now supports both AMQP and append-log style message flows. Native MQTT support within RabbitMQ
unlocks the ability to interface to Iconics using MQTT QoS 0 and QoS 1. Using the same technology as the Transfer
Zone message broker improves the quality of the overall solution through standardization of messaging software frameworks, software
design patterns, code reuse, standardization of maintenance and operational processes, etc.

*Costs for Option 2 [CMC infra prices + vendor licences]:*

*3 node (16GB RAM, 8CPU, 100GB storage) cluster per country X 3 countries X 2 stamps (failover) X 2 envs (PROD & ACC): **€489k***

*Single node (32GB RAM, 8CPU, 100GB storage) broker per country X 3 countries X 2 stamps (failover) X 2 envs (PROD & ACC): **€180k***

- Pro: Widely used enterprise grade message broker
- Pro: Support a wide variety of communication paradigms (e.g. queues, streams) suitable for different communication styles/ characteristics
- Pro: Performance test results
- Pro: Support rolling upgrades with clustering to enable zero downtime upgrades
- Pro: Supports a variety of protocols compared with Mosquitto which only supports MQTT
- Pro: Out of the box metrics/ monitoring including integration with Prometheus/ Grafana
- Pro: Support for multi-tenancy through vhosts (logical separation) enabling hosting of several countries/ tenants on a single broker (for downstream environments like dev/ test)
- Pro: Commercial licenses (CPU count based) only needed for Production environment to leverage 24x7 support in production
- Pro: Shared costing/ license model for Transfer zone and Internal Message broker enabling economy of scale and volume discounts
- Pro: Using the same technology as the Transfer Zone message broker improves the quality of the overall solution through standardization of messaging software frameworks, software
  design patterns, code reuse, standardization of maintenance, operational and debugging processes, etc.
- Pro: Supports exchange federation enabling sharing of messages with other RabbitMQ clusters e.g. IoT platform
- Pro: Strong, active development community with several questions answered by Github repository maintainers during POC phase
- Pro: Commercially-backed client included in software distribution from vendor
- Pro: 1 less vendor for 24x7 support simplifies support for mission critical (same vendor for Transfer zone and internal message broker)
- Pro: Native MQTT support (Qos 0 and 1) enabling interfacing to Iconics if MQTT is the chosen protocol
- Pro: Built-in protocol translation can be utilized if needed e.g. AMQP on the dispatcher side, MQTT on the Iconics side
- Pro: Strong clustering support including replicated message stores (quorum queues and streams)
- Pro: Support for partitioned append-log style communication using Super streams. Partitioning also possible using the sharding plugin & `x-modulo-hash` exchange or `rabbitmq_consistent_hash` exchange.
- Con: More expensive licencing that Mosquitto
- Con: Potentially higher resource consumption (Opex) if generic recommendations are followed, but initial performance testing indicates lower resource requirements
- Con: More sophisticated/ feature-rich compared with Mosquitto, so potential for more complexity depending on queue topologies used
- Con: Not as light-weight as Mosquitto requiring potentially longer startup times

## Decision Outcome

### Chosen option - Option 2:
Although the purchase costs of RabbitMQ is 20-40% more expensive than Mosquitto, it is well justified by the advantages 
of RabbitMQ compared with Mosquitto. VPP engineers have production experience with RabbbitMQ and have a higher confidence
as regards managing RabbitMQ operations. The crucial advantages of server and client attracting commercial support
from the same vendor, and using the same technology for the Transfer Zone and Internal Broker translates into a standardized
operating model for message brokers in the architecture, which ultimately promotes the ability to run a mission critical
system. More widespread use of RabbitMQ also promotes negotiability of pricing with the vendor.

To keep costs low it is suggested to start with a single node (with sufficient resources) per country, only if the redundant data centre is operational
to enable failover due to node loss. However if the rollout strategy is to deploy NL and/ or BE first and the second 
data centre and DE later, then a cluster is necessary for NL and/ or BE (potentially shared by NL and BE) to increase
availability until the second DC comes online.
