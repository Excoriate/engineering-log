# Decommissioning Portfolio Service

* Status: accepted
* Deciders: Team Optimum, Alex Shmyga, Ricardo Duncan
* Date: 2025-09-26

## Context and Problem Statement

The Portfolio Service currently performs the following functions:
- Receives time series data from the Asset Planning service.
- Aggregates these time series for BoFit FO on ESP.
- Exposes aggregated time series data via REST API for UI consumption.

However, the ESP messages sent towards BoFit FO are no longer used. Additionally, the time series data is already available in Asset Planning, which can easily perform aggregation and expose the data directly to the UI. This raises the question of whether it is necessary to maintain the Portfolio Service solely for the API functionality.

## Decision Drivers

- ESP messages to BoFit FO are obsolete and no longer required.
- Asset Planning already contains all relevant time series data and can perform aggregation.
- Asset Planning can expose aggregated data directly to the UI, eliminating the need for a separate service.
- Reducing operational and maintenance costs.
- Simplifying the system architecture and domain boundaries.

## Considered Options

- **Option 1:** Maintain two separate microservices (Portfolio Service and Asset Planning).
- **Option 2:** Consolidate all functionality into Asset Planning and decommission the Portfolio Service.

## Pros and Cons of the Options

### Option 1: Maintain Two Separate Microservices

* **Good**, because it preserves clear separation of concerns and domain boundaries.
* **Good**, because it allows independent scaling and deployment of services.

* **Bad**, because it increases operational and maintenance costs.
* **Bad**, because the Portfolio Service would exist solely for API exposure, which is redundant.
* **Bad**, because it adds unnecessary complexity to the system architecture.
* **Bad**, because the original purpose (ESP messages to BoFit FO) is no longer relevant.

### Option 2: Consolidate into Asset Planning and Decommission Portfolio Service

* **Good**, because it reduces operational and maintenance costs.
* **Good**, because it simplifies the system architecture and domain boundaries.
* **Good**, because all required data and aggregation logic already exist in Asset Planning.
* **Good**, because it eliminates redundancy and streamlines data exposure to the UI.

* **Bad**, because it may require minor refactoring in Asset Planning to expose the API directly.
* **Bad**, because it slightly increases the responsibility of Asset Planning.

## Decision Outcome

Chosen option: **Option 2:** Consolidate into Asset Planning and decommission the Portfolio Service

### Positive Consequences

* Lower implementation and maintenance costs.
* Simplified architecture and domain boundaries.
* No redundant services; all functionality is handled in Asset Planning.
* Direct data exposure to the UI from Asset Planning.

### Negative Consequences

* Minor increase in Asset Planning's responsibilities.
* Need for refactoring to expose the API directly from Asset Planning.

