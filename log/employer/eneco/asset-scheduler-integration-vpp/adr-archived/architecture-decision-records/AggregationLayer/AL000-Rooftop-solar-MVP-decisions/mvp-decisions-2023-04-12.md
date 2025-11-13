# Imbalance steering based on ideal setpoint (RTS)

* Status: proposed
* Deciders: Rene Pingen, Pedro Alonso, Arne Knottnerus-Yuzvyak, Wesley Coetzee, Alex Shmyga, Johan Bastiaan
* Date: 2023-04-12
* Updated: 2023-04-12

# Business requirements
* Imbalance steering should be delivered in the least expensive way across sites/devices
* STD has a preference for under-delivery compared to setpoints for imbalance (this means we always fall short of the setpoint, rather than exceeding it)
* Under-delivery should be minimized
* Functionality should be re-usable where possible

# Decisions
1. Setpoints are dispatched to individual devices on ideal-setpoint base and (ignoring the discrete nature of the physical devices)
2. Dispatch is based on ranking. Ranking is based on availability and strike price.
3. Dispatch logic:
- Start with remaining setpoint = total setpoint
- Choose highest ranked device regime whose capacity fully fits in the remaining setpoint
- Remove capacity from setpoint to calculate remaining setpoint
- Repeat previous steps until no device regime capacity fits in remaining setpoint
- Dispatch setpoints on device level

# Decision Drivers
1. 
- Limitation of discrete levels may change at any time in future, for different physical devices, etc. We don't want to base the design of our functionality specifically on these devices.  
- Ingoring discrete levels creates a solution that works with any number of discrete levels, and with devices that can handle any setpoint as well.
2. 
- We maintain a general dispatch ranking: When the pool of RTS sites receives a request to deliver imbalance, this request is allocated across the different sites based on merit-order ranking. Typically this is is based on availability of the asset and strike prices.
3. 
- No optimization is needed
- Under-delivery is guaranteed (can never have over-delivery)
- Logic is simple, easy to understand