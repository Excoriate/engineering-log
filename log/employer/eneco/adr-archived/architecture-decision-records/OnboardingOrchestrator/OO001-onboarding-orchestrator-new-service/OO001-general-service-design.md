# ADR: OO001 - Onboarding Orchestrator as a new service

**Status:** Proposed  
**Deciders:** Ricardo Duncan, Arne Knottnerus, Thomas O'Brien, Alex Shmyga, Niels Witte  
**Date:** 2025-4-24

Technical Story: [Feature 655916](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_boards/board/t/Team%20VPP%20Watts%20Up/Stories?workitem=673079): VVPAL: DA 3. Onboarding

---

## Context and Problem Statement

The current onboarding process is manual and inconsistent, causing inefficiencies across value streams. There is no standard approach, leading to varying quality and reliability. Additionally, the Data Aggregation Layer, being mission-critical, cannot directly interact with public-facing systems, requiring a secure and efficient intermediary for onboarding requests. In addition to this, due to the manual intervention required, the feedback loop is quite slow, which can lead to delays in onboarding new devices, especially when the data provided is incorrect or incomplete.

## Decision Drivers

- Simplify integration with VPP services accross all value streams.
- Protection of mission-critical systems from public-facing systems.
- Improved Security.
- Data consistency and reliability.

## Considered Options

### Option 1: Build a centralized Onboarding Orchestrator service

- Host in a non-mission-critical environment.
- Implement conservative retry policies and circuit breakers when calling downstream (mission-critical) systems.
- Since it serves as an entry point for onboarding requests, the orchestrator will accept user-based authentication tokens. From the orchestrator onwards it will be converted to service to service authentication with a strong preference for passwordless methods such as managed identities, depending on the downstream system's capabilities.
- Track separate onboarding state which keeps a record of the devices have been onboarded in a specific downstream system.
- Persistent audit log of all interactions that a user has with the orchestrator and which operations are performed on the downstream systems.
- Focus on providing synchronous feedback to the consuming API.

Technical details:

- New API endpoint for onboarding, written using ASP.NET 9. ASP.NET is the most commonly used framework in the VPP, and there are no specific knock-out requirements to warrant a framework switch.
- The orchestrator will be hosted in a non-mission-critical environment, simplifying hosting. In order to facilitate moving it to the mission-critical environment, the API will run inside a container, on an Azure app service. Other options considered were Azure Container instances, which requires manual maintenance, and Azure Kubernetes Service, which is overkill, as we do not use any of the advanced features of Kubernetes as well as Azure Container Apps, which is also overkill for this use case.
- In order to store state and audit logs, we will use Azure SQL as it is an affordable and easy to use solution. The main deciding factor is the complexity of the data model, which will mostly be tabular therefore making a relational database a good fit.
- In order to limit data being ingressed into the system, A rate-limiting solution on application level will be implemented. Other options included Azure Front Door and application gateway, but these target a use-case for public internet. All of our consumers will be internal Eneco systems and thus it is relatively safe to assume that there will be no ill-intent when using the service. Thus negating the need for the advanced features such as bot protection. What we do have to protect against is accidental mistakes in for example retry policies or loops from our consumers. This is where the rate-limiting solution comes in. The primary goal is not to protect the orchestrator, but the downstream systems instead.
- For Monitoring & Disaster Recovery, the following measures will be implemented:
  - Application Insights
  - Azure SQL Zone-redundant storage with automatic backups enabled.
  - App Service failover to a secondary zone.

This results in the following architecture:
![Onboarding Orchestrator Azure Architecture](./azure-architecture.jpg)
[Cost Estimation](https://azure.microsoft.com/en-us/pricing/calculator/?shared-estimate=52c5e4be42f34d8b8690fff86161f8dd)

An alternative architecture was also considered, using enterprise resources such as application gateway as well as Azure Container Apps. However, considering that the needs for scaling is not significant, and that the costs of running these resources is significantly higher, this architecture was not chosen. [Cost Estimation](https://azure.microsoft.com/en-us/pricing/calculator/?shared-estimate=043c9e51f11348ca888bbf4aa998c766)

![Onboarding Orchestrator Architecture - ACA + AGW](./azure-architecture-2.jpg)

Relevant documentation:

- [Azure Front Door](https://learn.microsoft.com/en-us/azure/frontdoor/front-door-faq#what-is-the-difference-between-azure-front-door-and-azure-application-gateway-)
- [Azure Application Gateway](https://learn.microsoft.com/en-us/azure/application-gateway/overview)

Communication through this service will be done using REST APIs in a synchronous manner. Another considered approach considered was to use some form of messaging, resulting in asynchronous communication. This would allow the orchestrator to determine the data contracts for onboarding messages, and would appear to reduce dependencies between the orchestrator and the downstream systems. This was later however deemed to be untrue, as the orchestrator would still need to know whether or not the downstream systems succesfully processed the messages, meaning those systems would need to be modified to accomodate for the orchestrator and in turn the orchestrator would need to know which messages to listen to. Another strong argument for event based processing would be performance, as downstream APIs would be able to scale depending on the load. However, the expectation of the max amount of devices onboarded during the day is relatively low (<1000), nullifying the need for (highly)-scalable architecture. All of these reasons, combined with the increased complexity in state management, led to the decision to use synchronous communication.

### Option 2: Decentralized onboarding handled by individual systems

- Each value stream manages its own onboarding logic and integration with downstream systems.

---

## Pros and Cons of the Options

### Option 1: Centralized Onboarding Orchestrator

**Pros:**

- Simplifies integration for developers.
- Provides a single point of control for onboarding logic.
- Ensures consistent error handling and feedback.
- Improves traceability and security with user-based authentication.
- New downstream systems can be added without updating consumers of the orchestrator service.
- Can serve as a starting point for the synchronization of data between different VPP systems such as Aggregation layer, BTM and VPP Core, enabling the onboarding of medium B2B and B2C devices.

**Cons:**

- Adds a new service to maintain.
- Not every downstream system has the same requirements, and in order to fulfill the requirements of these systems, additional work in the downstream systems is required.
- Once device state is being tracked it is at risk of being out of sync with the data known to the downstream systems, if the data ends up being updated there.

### Option 2: Decentralized Onboarding

**Pros:**

- Each value stream can customize onboarding logic to its specific needs.

**Cons:**

- Increased complexity for developers integrating with VPP services. As in order to integrate with the VPP, all products need to call each of the systems that are part of the VPP.
- Risk of inconsistent onboarding processes.
- Adding new downstream systems requires updates to multiple products.
- As some services are mission critical, they will need proxies, requiring additional work.
- Requires state management in each system, leading to potential inconsistencies.

---

## Decision Outcome

**Chosen Option:** Option 1 - Centralized Onboarding Orchestrator

### Positive Consequences

- Simplified onboarding integration for B2B and B2C systems.
- Consistent and interpretable error handling.
- Enhanced security and traceability with OBO authentication.

### Negative Consequences

- Additional maintenance overhead for the new service.
- Performance and reliability constraints must be carefully managed.

---

## Links

- [Feature 655916](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_boards/board/t/Team%20VPP%20Watts%20Up/Stories?workitem=673079)
- [OBO Authentication Documentation](https://learn.microsoft.com/en-us/azure/active-directory/develop/v2-oauth2-on-behalf-of-flow)

## Supporting diagrams:

System architecture
![Onboarding Orchestrator Architecture](./high-level-system.jpg)
