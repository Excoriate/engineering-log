# Design Decisions Rooftop Solar Mvp

* Status: proposed
* Deciders: Rene Pingen, Pedro Alonso, Arne Knottnerus-Yuzvyak, Wesley Coetzee, Alex Shmyga, Johan Bastiaan
* Date: 2023-02-15
* Updated: 2023-02-15

# Decisions

**We will build a SiteRegistry component (probably a web api) that will allow for onboarding of 'pooled assets',
aka assets that are part of a pool (like Rooftop Solar). In the case of the Rooftop Solar asset, 
the pooled asset to be onboarded in the Vpp Core will have 2 regimes.**

Decision Drivers

* We want the VPP Core to only worry about 'big' assets or toplevel assets. Assets that fall under a pool are not part of VPP Core.
* Having 'pooled assets' in the VPP Core might lead to all kinds of complications on the level of asset syncs, dispatching etc.
* The site registry will also support future aggregation use cases such as Hermes, where 1 site has multiple assets/devices.

**We will integrate the Aggregation layer components with the VPP Core using an interface. 
That interface will use Eneco standards for app-to-app integration (ESP or API Gateway, depending on the specific interface). 
Onboarding assets, updating assets, but also input/output from imbalance script will flow through this interface.**

Decision Drivers

* We want Rooftop Solar and other new propositions to not be self contained projects, but part of the Myriad VPP projects.
* We want to be able to update the VPP Core if changes in assets occur in Rooftop Solar, but want to hide details from Vpp Core.
* We want to design Rooftop Solar in such a way that it can easily participate in other markets like AFRR in the future.

**We will skip Site Planning in the Mvp.**

Decision Drivers

* For the Rooftop Solar proposition Site planning is not needed yet

**The VPP Core interface for imbalance trading is standardised so that all needed data is provided at once for an asset or pool of aggregated smaller assets. 
This interface can be re-used for big assets and other pools.**

Decision Drivers

* Even though strikeprices might be for now 'hardcoded' in the aggregation layer for Rooftop Solar, from the VPP Core's point of view they
  still need to be part of the imbalance calculation input. 
* Strikeprices might be calculated differently (not hardcoded but from actual timeseries) in the future depending on the proposition.