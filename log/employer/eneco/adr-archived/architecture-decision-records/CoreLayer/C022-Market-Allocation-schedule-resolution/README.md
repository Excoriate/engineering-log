
# Market Allocation schedule resolution and boundaries

* Status: accepted
* Deciders: Team Core, Team Optimum
* Date: 2024-11-21

## Context and Problem Statement

In Asset Planning (AP) schedule data could be provided to clients (e.g. Dispatcher) with any bucket size and from/to time.

Market allocation must be the same within each PTU. It means that the following request

```
"from" : "2024-11-11T12:10:00Z",
"to" : "2024-11-11T13:10:00Z",
"bucketSizeMinutes" : 10
```
doesn't match PTU allocation. The first 10 min bucket needs to be calculated from `12:10` to `12:20`. The block falls in between two different PTUs with potentially different market allocations.

## Decision Drivers

* AP must ensure the same market allocation within each PTU

## Considered Options

Market allocation schedule should be always provided with `BucketSize` equal to PTU. `From` and `To` parameters must be multiple of PTU:
* **Option 1:** remove `BucketSize` from the market allocation schedule query data contract. Introduce strict validation for `From` and `To`:
  *  `From` % 15 min == 0
  *  `To` % 15 min == 0
* **Option 2:**  keep the existing data contract. Introduce strict validation for `BucketSize`, `From` and `To`:
  * `BucketSize` == 15 min
  *  `From` % 15 min == 0
  *  `To` % 15 min == 0

## Decision Outcome

Chosen option: **Option 2:**  Enforce strict validation on market allocation schedule query.

### Positive Consequences

* Market allocation schedule is always provided to the AP clients with PTU resolution and only with whole number of PTUs 

### Negative Consequences

* Less flexibility for the AP clients working with market allocation schedule
