
# Remove Pending Operator Decision

* Status: accepted
* Deciders: Alberto Rottigni, Hein Leslie, Koen Vos, Mark Beukeboom, Wesley Coetzee
* Date: 03/07/2024
## Context and Problem Statement

When the pending operator decision flag is set on an asset, if that asset is in a CSM of AUTOMATIC, but is missing data and has an ESM of EXTERNAL, once the data is received again the asset will move into a ESM of PENDING_OPERATOR_DECISION. This means that the operator needs to manually put the asset back into AUTOMATIC so that it can be steered by the VPP again.

This adds a lot of complexity to the ESM calculation and also means that we are updating the CSM based on the ESM, which is not correct as the CSM is a steering mode that is manually configured by the operator for that asset.

There are currently no assets in the VPP that use this functionality anymore, so it's been decided to remove it.

## Requirements/constraints

- Simplify the ESM calculation
- Ensure all assets can fallback to their CSM
- Remove the Autofallback option from the UI and the Asset Configuration
- Remove PENDING_OPERATOR_DECISION from the SteeringModes Enum
- Remove logic from ESM Calculation
- Clean up Wiki and Documentation

## Decision Drivers

- Simplify the ESM calculation
- Clean up code that is no longer needed (tech debt)

## Considered Options

N/A

## Decision Outcome

PENDING_OPERATOR_DECISION will be removed from the ESM calculation and the CSM will be used as the source of truth for the steering mode of the asset.
