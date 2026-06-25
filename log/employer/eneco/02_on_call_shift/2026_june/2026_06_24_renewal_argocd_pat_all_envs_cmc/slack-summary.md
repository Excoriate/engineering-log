---
status: draft
date: 2026-06-24
agent: codex
summary: Slack-ready sanitized summary for MC ArgoCD PAT rotation.
---

# Slack Summary

Hi team, completed the planned Azure DevOps PAT rotation for the CMC-managed ArgoCD repository credentials across MC environments.

Scope covered:
- MC dev, ACC, and PROD ArgoCD repo credential templates.
- Myriad VPP and Asset Optimisation Azure DevOps project prefixes.
- New PATs were created with `Code (Read)` scope, stored in the team credential store, applied to the matching ArgoCD credentials templates, and the old PATs were revoked after validation.

Validation performed:
- Confirmed the recreated credentials template URLs matched the expected ADO project prefixes.
- Checked covered ArgoCD applications after refresh / hard refresh where applicable.
- Confirmed applications remained `Synced` and `Healthy`, with no visible repository authentication / comparison errors.

No secret values were shared in Slack, logs, screenshots, or shell output during the activity.
