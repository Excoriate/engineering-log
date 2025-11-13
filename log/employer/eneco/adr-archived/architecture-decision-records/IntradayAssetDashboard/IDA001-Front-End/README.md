# Intraday Trading Dashboard Frontend Implementation Strategy

- Status: accepted
- Deciders: Development Team
- Date: 2025-03-04

Technical Story: Decision on frontend implementation approach for intraday trading dashboard POC

## Context and Problem Statement

We need to implement a proof-of-concept intraday trading dashboard that allows for rapid development and iteration. The key decision is whether to extend the existing VPP (Virtual Power Plant) frontend or create a new, separate Vue.js application. How can we best implement this while balancing development speed, system reliability, and future maintainability?

## Decision Drivers

- Development speed and iteration capability
- Impact on existing VPP system stability
- Future maintainability and potential system merger
- Infrastructure and pipeline requirements
- UI/UX consistency across platforms
- Release cycle independence

## Considered Options

- Option 1: Extend existing VPP frontend
- Option 2: Create new standalone Vue.js application

## Pros and Cons of the Options

### Option 1: Extend existing VPP frontend

- Good, because it maintains complete system consistency
- Good, because it leverages existing infrastructure and pipelines
- Good, because it requires no additional Azure AD setup
- Bad, because it's tightly coupled to VPP release cycles
- Bad, because complex existing implementation slows development
- Bad, because changes risk impacting mission-critical VPP system
- Bad, because it constrains architectural improvements

### Option 2: Create new standalone Vue.js application

- Good, because it enables rapid development and iteration
- Good, because it isolates risk from VPP system
- Good, because it allows for clean, modern implementation
- Good, because it provides release cycle independence
- Bad, because it requires new infrastructure setup
- Bad, because it needs separate pipeline configuration
- Bad, because it requires additional Azure AD group management
- Bad, because future SAAS offering might require system merger

## Decision Outcome

Chosen option: "Create new standalone Vue.js application", because it provides the necessary development freedom and speed while isolating risk from the mission-critical VPP system, despite requiring additional infrastructure setup.

### Positive Consequences

- Independent development and release cycles
- Faster iteration and development speed
- No risk to existing VPP system stability
- Clean, modern codebase without legacy constraints
- Opportunity to implement improved architecture patterns

### Negative Consequences

- Need to set up new infrastructure and pipelines
- Separate Azure AD group management required
- Additional effort if future SAAS offering requires system merger
- Duplicate maintenance of some components
- Need to actively maintain UI consistency

