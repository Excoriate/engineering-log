---
task_id: 2026-04-13-001
agent: coordinator
status: draft
summary: "Spec for root cause analysis document with visual aids"
---

# Spec: Root Cause Analysis Document

## Summary
Produce a comprehensive RCA document for the activationmfrr 404 incident that explains the what/why/how deeply enough for the reader to independently arrive at the same conclusion.

## What/Why
The VPP developer and the on-call engineer need to understand:
1. Why the endpoint returns 404 despite ArgoCD showing Healthy
2. The exact mechanism of the failure (path naming inconsistency)
3. The full request flow through the infrastructure layers
4. How to fix it and verify the fix
5. Mental model for debugging similar issues in the future

## Structure
1. **Incident Summary**: one-paragraph summary
2. **Request Flow Diagram**: ASCII diagram showing Client → DNS → AGW → NGINX → Service → Pod for BOTH working and broken paths
3. **Root Cause**: the path naming inconsistency with evidence table
4. **Why It Matters**: how the NGINX ingress forwards paths to pods
5. **Why Prod/Acc Work**: OpenShift Routes vs NGINX Ingress
6. **Why Dispatchersimulator Works**: Blazor PathBase vs Web API
7. **Proposed Fix**: specific file/line change
8. **Verification Commands**: curl commands to verify after fix
9. **Mental Model**: "How would I debug this from scratch?" checklist

## Verification
- All FACT claims have file:line or curl evidence
- Diagrams match the actual infrastructure
- Fix section is actionable (specific file, specific change)
