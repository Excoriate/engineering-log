# Sales Deficits
## New Key Data Entity: Trade Position Deficits 
* Status: proposed
* Deciders: Rene, Arne, Mark 
* Date: [2023-08-04] 

## Technical Story: 
Sales deficits will be results of optimization, when the sales plan cannot be met due to certain reasons. 
These results should be published towards the traders and shown in the UI. 
The traders can react accordingly on the sales deficits. 

## Context and Problem Statement:
When traders make a sales position which is not feasible there is a defict on the sales position. This deficit is a result from the feasibility simulation/optimization done by asset specific models.
The deficit should be comunicated to the traders and the operators. 

An example is when technically the asset cannot follow the sales position, due to either ramping, capacity constraints or to meet aFRR. 
In this case should the trader change the sales position as such that the asset can follow the desired sales position. 

## Definition Portfolio Deficit:
The difference between the sales position and the powerschedule which is technically feasible for an asset. 

## Proposal:
* Entity: Asset
* SubEntity: PowerTradePosition
* Attribute Names: SalesDeficits
* Full Name: AssetPowerTradePosition.SalesDeficits
* Data Type: Time Series
* Data Format: Decimal/Floating Point
* Has Marget Dimension: Yes
* Generic: Yes