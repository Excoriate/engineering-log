# Improve Site Registry scalability and remove coupling on the its database

* Status: proposed
* Deciders: Pedro Alonso, Roel van de Grint, Arne Knottnerus-Yuzvyak, Khyati Bhatt, Cameron Goss, Alex Shmyga
* Date: 2023-06-14
* Updated: 2023-06-21

# Context
* Site registry is a service responsible for storing configuration data of pools, sites and devices.
* Currently other components of Agg Layer are connected with Site Registry on the database level. Such integration has limitations on individual component testing and related to scaling.
* It's a central service within the Agg Layer and an instability of the service should not have any impact on components that use Site Registry data


# Decisions
1. use "shared service and state" pattern to store data [ref](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/DesignDecisions/pullrequest/51424)
2. use "shared stateless service" pattern to output data. So as soon as any update happens for pool/site/asset a corresponding messages will be published to notify subscribers [ref](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/DesignDecisions/pullrequest/51424)
3. Site Registry will publish two types of messages: latest state (new or update) and deletion event.
4. Entities stored by Site Registry will have a state version number.
5. When a new subscriber is created it can initiate publishing of all existing data(latest states) to the Service Bus.


# Decision Drivers
1. It's a critical service that can be shared between different propositions and markets
2. It doesn't have any specific proposition/market logic except validations of the pool configurations and base validations of asset configurations
3. The data shared by Site Registry can be eventually consistent
4. Even if Site Registry is down, other components should be able to continue to work