# Gurobi parallel models

* Status: [proposed]
* Deciders: Quinten de Wit, Ihar Bandarenka, Dmytro Ivanchyshyn, Alex Shmyga, Richardo Dunkan

## Context and Problem Statement

Fleet Optimizer Solver (Solver) CPU consumption is growing over time and current cluster computational power is not enough for the predicted consumption. Solver needs more computational power to keep working with requested non-functional and functional requirements.

* Currently Solver uses around 1 CPU for successful run and up to 1.5-2 CPU for infeasible run.
* Currently Solver calculates successful run in 30-50 seconds and infeasible run around 5 minutes with ~1.5 CPU
* Current Solver hard limit on optimization is 5 minutes. After this optimization is ended without infeasibility file created. Which is needed for trouble shooting.
* Currently optimization cycle is 15 minutes.

## Decision Drivers

* Price
* Execution time
* Trouble shooting possibilities
* Performance
* Sustainability
* Dynamic market enablement functionality
* Addition of new assets

## Experiments

* Experiment 1
Given:
60 assets
1CPU limit
Result:
37s

* Experiment 2
Given:
60 assets
0.5CPU limit
Result:
100s

TL;DR;
Solver can be throttled. It does not break the optimization but slows it down a lot.
Looking at consumption for infeasible run at 1.5-2 CPU if it is throttled to 1 CPU execution time can be increased up to 3 times which is up to 15 minutes.

## Considered Options

* Option 1: 
    * Don't do anything
    * Outcome: Solver does not work. VPP does not work.

* Option 2: 
    * Throttling
    * Outcome: longer run time for the successful run (depends on number os assets and input data). Around 30%. Which is 1.5 minutes.
    * longer run time for the failed run (depends on number os assets and input data). Up to 300% if CPU limit is 1 CPU. Leads to up to 15 minutes execution time.
    * Changes in logic to handle longer execution time.

* Option 3:
    * New node added to the cluster.

* Option 4:
    * Gurobi Computation Server.


## Decision Outcome

* Short term: Add more computational power by purchasing dedicated node for the Solver in mission critical cluster. 
* Long term: Introducing Gurobi computational service. Transfer CPU consumption from mission critical cluster to Gurobi computational service

### Positive Consequences

### Negative Consequences

## Appendix