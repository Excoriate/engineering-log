# Expose SiteRegistry and TestFunctions via https in non prod environments

* Date: 2023-22-11
* Deciders: Rene Pingen, Ricardo Duncan, Arne Knottnerus-Yuzvyak, Khyati Bhatt, Cameron Goss, Alex Shmyga

## Glossary
- VPPAL - Virtual Power Plant Aggregation Layer

## Context and problem statement
In VPPAL we have two components which can be accessed via HTTPS:
    - Site Registry API (with a swagger page) to manage Locations, Sites, Devices and Pools
    - Test Functions (set of azure functions to be able to publish/read data to/from ESP). The intensions to have an ability to perform manual/automated test up to ACC. They never are going to be deployed to PROD environment.

Both SiteRegistry API and Test Functions can be accessible only by authenticated users(AAD authentication). The token can be got from VPP Core UI.

These endpoints are available via the application gateway in the sandbox environment.

For our manual and automated tests, we need to have those components to be exposed via HTTPS on DEV-MC and ACC environments.

Up until now "tester" access to the application in CMC environments has been via port forwading directly to the function. This is cumbersome; direct https access would offer a much better workflow. In addition, the portforwarding solution would be problematic to automate in terms of automated testing.

We would like to have the same testing "workflow" through all non-production environments.

## Decision Drivers

Quick and efficient testing in all non-production environments via the same workflow.

## Decisions

In the Acceptance and DEV-MC environments add an additional listener to the existing core application gateway such that the Site Registry API and Test Functions area available from https://agg.<env>.vpp.eneco.com.
This effectively replicates the solution already in place in the sandbox environment

## Considered Alternatives

Remain with the existing portforwarding solution.
Build a front-end to be able to reach Site Registry API. However, it doesn't solve access issue to Test Functions.

## Links <!-- optional -->