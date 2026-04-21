---
task_id: 2026-04-21-001
agent: claude-code
status: complete
summary: CI/CD surfaces touched by this ticket
---

# Automation Map

- **ADO pipeline**: Myriad - VPP project / VPP-Infrastructure pipeline, `buildId=1616964` triggered by Stefan.
  - URL: `https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_build/results?buildId=1616964&view=logs&j=c4a10d1f-fbee-5cf8-583b-7e6bc88f2b58`
  - Job id `c4a10d1f-fbee-5cf8-583b-7e6bc88f2b58`
  - Dispatch via `/azure-devops-pipeline-debugger` skill for log extraction.
- **ArgoCD Sandbox**: deploys workloads into Sandbox MC AKS/OpenShift. Service "mFRR-Activation" is crash-looping → inspect sync state + pod logs via `/eneco-oncall-intake-enrich` read-only probes.
- **Terraform plan/apply**: expected to run inside the ADO pipeline. If consumer-group is declared in IaC, `terraform apply` in Sandbox stage creates it.
