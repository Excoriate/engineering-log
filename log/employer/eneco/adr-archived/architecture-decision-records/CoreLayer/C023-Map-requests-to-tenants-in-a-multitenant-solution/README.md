# Mapping HTTP Requests to Tenants in a Multitenant (Multi Country) Solution

* Status: accepted
* Deciders: Team Optimum, Team Core, Duncan Teegelaar, Alex Shmyga, Ricardo Duncan
* Date: 2025-01-15

Technical Story: [Feature 626980](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_boards/board/t/Team%20Optimum/Stories?System.AssignedTo=%40me&workitem=626980): Multitenant HTTP Request Mapping

## Context and Problem Statement

In a multitenant solution, it is essential to correctly map HTTP requests to the appropriate tenant. This decision record explores different options for achieving this mapping.

## Decision Drivers

* Security and isolation of tenant data
* Ease of implementation and maintenance
* Performance impact
* Flexibility and scalability

## Considered Options

* **Option 1:** The URL path structure, such as `https://vpp.eneco.com/tennetnl/portfolio/`
* **Option 2:** A query string in the URL, such as `https://vpp.eneco.com/portfolio?tenant=tennetnl`
* **Option 3:** A custom HTTP request header, such as `X-Tenant-ID: tennetnl`

## Pros and Cons of the Options

### Option 1: The URL path structure

Using the URL path structure to include tenant information.

* Good, because it is easy to implement and understand.
* Good, because it is visible in logs and analytics.
* Bad, because it can lead to complex and lengthy URLs.
* Bad, because it may expose tenant information in URLs, which can be a security concern.

### Option 2: A query string in the URL

Using a query string parameter to pass tenant information.

* Good, because it is easy to implement and understand.
* Good, because it keeps the URL path clean.
* Bad, because it can expose tenant information in URLs. It might not be important now, but could be a security concern in the future.
* Bad, because query strings can be easily manipulated by users.

### Option 3: A custom HTTP request header

Using a custom HTTP request header to pass tenant information.

* Good, because it provides a secure way to pass tenant information.
* Good, because it keeps URLs clean and consistent.
* Good, because it is flexible and can be easily extended.
* Bad, because it requires clients to include the custom header in every request.
* Bad, because it may require additional configuration in some web servers or proxies.

## Decision Outcome

Chosen option: **Option 3:** A custom HTTP request header, such as `X-Tenant-ID: tennetnl`

### Positive Consequences

* Provides a clear and secure way to pass tenant information.
* Keeps URLs clean and consistent.
* Easier to manage and enforce security policies.

### Negative Consequences

* Requires clients to include the custom header in every request.
* May require additional configuration in some web servers or proxies.

## Links

* [Azure Architecture Center: Map requests to tenants in a multitenant solution](https://learn.microsoft.com/en-us/azure/architecture/guide/multitenant/considerations/map-requests)