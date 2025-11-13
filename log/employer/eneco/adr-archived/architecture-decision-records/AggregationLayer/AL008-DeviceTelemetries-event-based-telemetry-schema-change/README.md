# Support event-based and cycle telemetry

* Status: proposed 
* Deciders: Cameron Goss, Arne Knottnerus, Khyati Bhatt, Johnson Lobo, Illia Larka  
* Date: 29 Jul 2024 

Technical Story: https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_workitems/edit/529175/ 

## Glossary

Cycle Telemetry

	-  Cycle telemetry refers to a type of telemetry data that is sent at regular intervals.
	If this telemetry data is not updated within the expected period, it indicates that the device may not be functioning correctly and should be excluded from the process. 

Event-Based Telemetry

	- Event-based telemetry refers to telemetry data that is sent only when there is a change in values.
	Each change updates the last timestamp to the current date and time, leading to a longer validity period.

## Context and Problem Statement

Currently we have a requiremenet to support event-based telemetry for existing or new devices, so system can work with mixed telemetry at the same time.
The current schema poses several challenges:

High Read/Write Rate: The existing schema requires frequent and numerous read and write operations (upserts), which can be inefficient and resource-intensive.
This high operation rate can lead to performance bottlenecks and increased operational costs.
Event-base Telemetry Maintenance: Managing multiple documents for MDP codes complicates the maintenance process.
Difficulty in Discarding Unsupported Codes: Removing unsupported MDP codes from multiple documents is a tedious process. This can lead to the accumulation of outdated or invalid codes, further complicating the maintenance and potentially affecting system performance.
Complicated Queries: Querying all documents to validate telemetry data and determine the latest update timestamps is complex and resource-consuming. This complexity can hinder timely data validation and impact the overall efficiency of the system.

The system must support cycle and event-based telemetry at the same time beacause not every is device ready to work with event-based telemetry.

## Decision Drivers

* Technically easy to maintain
* Preserve or improves costs
* Preserve or improves RUs consumptions  

## Considered Options

* Consolidate MDP codes into a single document to maintain the uniqueness and validity period of device telemetry.

	Cons: 

		- Requires a change in the schema.
		- A brief downtime is required during the schema change release. 

	Pros:

		- Easy to find time stamp of device telemetry.
		- A single point for maintaining a set of allowed MDP codes. 
		- Deacreases operation rate. For instance event-based telemetry is being send every 1 minute, and there are 7 MDP(n) codes we are operating.
		We have 100(d) devices. The operation rate will be: d * 2 = 100 * 2 = 200  write(upserts) operations per minute, where 2 - is a read and write operations. 
		- Decreases RU usage. For instance event-based telemetry is being send every 1 minute, and there are 7 MDP(n) codes we are operating.
		We have 100(d) devices. According to the documentation upsert operation of a document sized 600 bytes may consume ~6 RUs (depends on index).
		For 200 upserts: 200 * 6 = 1200 RUs per minute. For cycle telemetry the consumption remains the same.
		- Supports cycle and event-based telemetry.


* Maintain the current approach where a document is stored per MDP code.

	Cons:

		- Requires updating multiple documents and reading multiple documents during ingestion for each request which increases complexity of querying.
		- Validating a device telemetry according to the telemetry validity period requires querying all documents and identifying the latest update timestamp.
		- Preserves the same operation rate. For instance cycle telemetry is being sent every 1 minute, and there are 7 MDP(n) codes we are operating.
		We have 100(d) devices. The operation rate will be: n * d = 7 * 100 = 700 write(upserts) operations per minute. 
		- Preverses the same RU consumption. For instance cycle telemetry is being sent every 1 minute, and there are 7 MDP(n) codes we are operating.
		We have 100(d) devices and average document size ~350 bytes. Accodring to the documentation the average operation may consume ~4 RUs for 350 bytes document.
		For 700 operations: 700 * 4 = 2800 RUs per minute. 


	Pros:

		- No schema changes required.
		- Supports cycle and event-based telemetry.

## Decision Outcome

Chosen option: Consolidate MDP codes into a single document to maintain their uniqueness and validity period for device telemetry.
This approach decreases the operation rate (although it may increase document size), simplifies maintenance by facilitating the removal of
unsupported MDP codes, and streamlines queries to find telemetries based on their validity period. 

A new document schema.

```
{
    "id": "cce26c06-b5c7-4184-4f11-08dcafa82647",
    "DeviceId": "cce26c06-b5c7-4184-4f11-08dcafa82647",
    "Telemetries": [
        {
            "Code": "MDP.DER.1",
            "Value": "-1.000",
            "ValueType": "_decimal"
        },
        {
            "Code": "MDP.DER.2",
            "Value": "-1.000",
            "ValueType": "_decimal"
        }
    ],
    "TimeStamp": "2024-07-29T14:11:52.854558Z",
    "_rid": "4dQDAJ-iBYEBAAAAAAAAAA==",
    "_self": "dbs/4dQDAA==/colls/4dQDAJ-iBYE=/docs/4dQDAJ-iBYEBAAAAAAAAAA==/",
    "_etag": "\"8700d7ee-0000-0d00-0000-66a90cf80000\"",
    "_attachments": "attachments/",
    "_ts": 1722354936
}
```

In the result if telemetry rate remains at the same level, lets say once per minute, the RU usages will decrease from 2800 to 1200 RUs per minute. It will simplify querying to find latest telemetry for device.

### Positive Consequences 

* Easy to find time stamp of device telemetry.
* A single point for maintaining a set of allowed MDP codes. 
* Deacreases operation rate from 700 upsert operations to 200 upsert uperations. 
* Decreases RUs usage from 2800 RUs per minute to 1200 RUs per minute.

### Negative Consequences

* Requires a change in the schema.
* A brief downtime is required during the schema change release. 

