# Portfolio Deficits
## New Key Data Entity: Portfolio Deficits
* Status: proposed
* Deciders: Rene, Arne, Mark 
* Date: [2023-08-04] 

## Technical Story: 


## Context and Problem Statement:
When there is not enough capacity to meet the constraint in an optimization deficits are needed. Without the deficits the optimization will fail as the objective cannot be reached.
The entity has a market dimension and can be either for voluntary objectives or contractual objectives. 

An example is a Deficit for aFRR: In the case when we cannot meet our aFRR contracts, we have a deficit for afrr (up or down). 
Short Term Desk needs to know this for their bidding script, to bid in aFRR capacity with a high volume.
The operator needs to know this to contact the ID trader, to ensure that the trader changes the schedule from an asset to ensure enough capacity.

## Definition Portfolio Deficit:
The shortage in the portfolio for the contractual agreement made in a certain (energy) market.

## Proposal:
* Entity: Portfolio
* SubEntity: Deficit
* Attribute Names: Contracted or Voluntary
* Full Name: PortfolioDeficit.Contracted.aFRRUp or PortfolioDeficit.Voluntary.aFRRDown
* Data Type: Time Series
* Data Format: Decimal/Floating Point
* Has Market Dimension: Yes
* Generic: Yes