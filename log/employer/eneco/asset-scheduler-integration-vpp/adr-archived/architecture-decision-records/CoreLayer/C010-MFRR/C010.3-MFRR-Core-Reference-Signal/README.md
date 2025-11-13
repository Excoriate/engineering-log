# VPP core reference signal service

- Status: proposed
- Deciders: [Mark Beukeboom](mailto://mark.beukeboom@eneco.com), [Hein Leslie](mailto://hein.leslie@eneco.com), [Wesley Coetzee](mailto://wesley.coetzee@eneco.com), [Johnson Lobo](mailto://johnson.lobo@eneco.com), [Sebastian Du Rand](mailto://Sebastian.duRand@eneco.com), [Ricardo Duncan](mailto://Ricardo.Duncan@eneco.com)
- Date: 2023-07-13

## Context and Problem Statement

**Change reference signal service to handle new mFRR calculations**

The current reference signal service handles calculations for aFRR every 4 seconds based on real-time data. However, for mFRR, the calculations require the use of historic data and the computation of an average over a 5-minute period.

## Considered Options

- Option 1: Update the current reference signal service to handle historic data and mFRR calculations.
- Option 2: Build a new mFRR reference signal service..

## Decision Outcome

**Chosen option: Option 2**, because it keeps market-specific logic contained within its own service and reduces code complexity.

There will likely be common code that can be reused in both services. Extracting this code into its own library is recommended. Implementing a Factory or Abstract Factory pattern would be a good option to simplify future implementations for additional markets..

## Pros and Cons of the Options

### Option 1: Update the current reference signal service to handle historic data and mFRR calculations.

The reference signal service will need to calculate differently for different markets.

#### Pros & Cons

- Pros, Time saved by not building a new service.
- Pros, No extraction of common code.
- Cons, The code will need to be modified to accommodate the new market, increasing complexity and behavior variations based on markets.
- Cons, Increased difficulty if implementing a new market, requiring extensive regression testing.

### Option 2: Build a new mFRR reference signal service.

As mentioned above, a simple design pattern can provide a clean and scalable solution, allowing each service to operate independently. Implementing a new market or modifying regulations for an existing market would have minimal impact on the other service.

#### Pros & Cons

- Pros, Each service is market-specific.
- Pros, Clean code and adherence to design patterns.
- Pros, Isolated impact of a service failure on a specific market.
- Cons, Requires some rework on the current aFRR service to extract common code into a separate service.
- Cons, Regression testing needs to be performed on aFRR again.
