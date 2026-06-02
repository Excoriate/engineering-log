---
task_id: 2026-03-23-001
agent: coordinator
status: complete
summary: Codebase structure map for sre-platform-services
---

# Codebase Map

## Repository
- **Origin**: git@github.com:Eneco/sre-platform-services.git
- **Branches**: main, hotfix, ops-scratchpad, ops-boyscout, backlog-prio1/2/3, contrib-*, pr-review1/2, docs/*

## Structure Pattern
Multi-branch workspace — each branch has parallel structure:
- `.azuredevops/` — CI/CD pipeline YAML (terraform.ci.pipeline.yaml, terraform.cd.pipeline.yaml, variables.yaml)
- `terraform/` — rootly/, snyk/, teams/ modules
- `configuration/` — rootly/, snyk/, teams/
- `documentation/` — Diátaxis structure (Explanation, How-To-Guides, Reference, Tutorials)
- Standard: .tflint.hcl, renovate.json, .pre-commit-config.yaml, README.md

## Key Observation
This repo manages SRE platform services (Rootly, Snyk, Teams) via Terraform + Azure DevOps pipelines.
The E2E test investigation is in an EXTERNAL engineering log, not in this repo.
