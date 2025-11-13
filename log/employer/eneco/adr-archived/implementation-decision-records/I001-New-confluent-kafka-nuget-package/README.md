# Migration from Axual to Confluent Kafka Library for NuGet Package

* Status: Accepted - In development
* Deciders: Pedro Alonso, Roel van de Grint, Alex Shmyga, Ihar Bandarenka, Alexandre Borges, Johan Bastiaan, Sebastian Du Rand
* Date: 2023-11-13

## Decision
**Develop a new NuGet package using the Confluent Kafka library, incorporating an abstraction layer for overwriting default configurations.** (Option 2)

## Decision Drivers
- **Discontinuation of Axual Support**: Axual has ceased the development and support for their library.
- **Enhanced Configuration Options**: Confluent Kafka library offers greater configurability for producers and consumers.
- **Long-term Stability and Community Support**: Confluent’s library promises better long-term stability and community support.
- **Aligning with Current Consumption Strategies**: Aligns with the proposed consumption strategies in the linked PR ([Pull Request 43296](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/DesignDecisions/pullrequest/43296?path=/architecture-decisions/kafka-vpp-messages-consumption/kafka-vpp-messages-consumption.md): Kafka-VPP arch decision request).
- **Producer-Consumer Issue in Axual Library**: The Axual library has limitations when a service needs to function as both a producer and a consumer, a problem resolved in the new implementation.

## Considered Options
1. **Continuing with Axual Library**: Minimal immediate change but significant long-term risks.
2. **Switching to Confluent Kafka Library**: Develop a new NuGet package with an abstraction layer for default configuration values.
3. **Exploring Other Kafka Libraries**: Assessing other libraries for a potentially better fit.

## Positive Consequences
1. **Enhanced Flexibility and Scalability**: Leads to better scalability and adaptability.
2. **Future-proofing the Architecture**: Ensures long-term stability with a widely supported library.
3. **Improved Performance and Efficiency**: Potential for enhanced performance with advanced features.
4. **Alignment with Strategic Consumption Strategies**: Complements the referenced PR's consumption strategies. ([Pull Request 43296](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/DesignDecisions/pullrequest/43296?path=/architecture-decisions/kafka-vpp-messages-consumption/kafka-vpp-messages-consumption.md): Kafka-VPP arch decision request)
5. **Improved Certificate Management**: The new package simplifies certificate handling. Post bug resolution in the Confluent library, it will enable direct use of certificates as received, eliminating the current need to convert them into base64 and recreate local files for services.
6. **Solving Producer-Consumer Limitation**: Addresses the limitation in the Axual library for services that need to be both producers and consumers.

## Negative Consequences
1. **Migration Overhead**: [Mid-Low] Need to migrate services from the old package, incurring resource allocation.
2. **Learning Curve**: [Low] Time needed for teams to familiarize with the new library.
3. **Compatibility Issues**: [Low] Possible risks during the transition phase.
4. **Initial Development Cost**: [Low] Resources needed for development and integration testing. (Johnson Lobo already spent time)

## Migration Strategy
1. **Initial Implementation in a New Service**: The new package will first be used in a new service requiring the producer-consumer feature.
2. **Phased Rollout**:
   - Check CorrelationId implementations using the current package.
   - If possible, implement a deprecation notice on the Axual implementation.
   - Based on the capacity and priorities of different teams, the migration will gradually extend to other services.
3. **Documentation and Training**: Provide comprehensive documentation and training to facilitate the transition. A couple of important points to capture are:
   - Which behaviours will be different between the Axual and Cofluent implementation. Probably none as in Aggregation Layer they already use it. But we will make sure to include it in the doc.
   - Inventory of the steps to migrate over the new library. These will lead the backlog items for the teams.
4. **Parallel Operation**: Maintain both libraries in parallel during the migration phase to ensure service continuity.
5. **Monitoring and Support**: Implement enhanced monitoring and support to quickly resolve issues during migration.
