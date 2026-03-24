---
task_id: 2026-03-23-001
agent: coordinator
status: complete
summary: Config files map
---

# Config Map

## Per-branch configs (pattern repeated across branches)
- `.azuredevops/terraform.ci.pipeline.yaml` — CI pipeline
- `.azuredevops/terraform.cd.pipeline.yaml` — CD pipeline
- `.azuredevops/variables.yaml` — Pipeline variables
- `.tflint.hcl` — Terraform linter config
- `renovate.json` — Dependency update config
- `.pre-commit-config.yaml` — Pre-commit hooks

## Investigation Files (external)
- Engineering log: `/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/log/employer/eneco/ops_ot_the_week/2026_03_e2e_test_failing_nitin/`
