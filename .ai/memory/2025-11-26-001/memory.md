---
task_id: 2025-11-26-001
type: memory
summary: >
  Formatted Azure Key Vault rotation documentation with validated CLI commands,
  C4 model architecture (5 levels), and 15+ Mermaid diagrams for complete technical design.
---

# Memory

## Decisions

- Used YAML frontmatter for document metadata (title, status, domain, date)
- Removed redundant H1 headings (title in frontmatter is sufficient)
- Added Mermaid diagrams for: Discovery funnel, Component interaction, Architecture, State machine, Permissions, Workflow, Implementation Gantt
- Included ASCII fallback diagrams in appendix for non-Mermaid renderers
- Validated all CLI commands against official Azure docs via MCP
- **C4 Model Architecture**: Restructured Section 2 to follow C4 model hierarchy
  - Level 1 (System Context): Shows system as black box with users and external systems
  - Level 2 (Container): Shows CLI application and YAML config as containers
  - Level 3 (Component): Shows internal packages (config, domain, provider) and interfaces
  - Dynamic Diagram: Enhanced sequence diagram with numbered steps
  - Deployment Diagram: Shows local dev vs CI/CD execution contexts
- Used Font Awesome icons in Mermaid (`fa:fa-*`) for visual clarity
- Added relationship tables alongside each C4 diagram for explicit documentation

## Constraints

- Azure CLI `az keyvault secret list` JMESPath cannot perform date math (Today - Expiry)
- MS Graph `addPassword` requires Object ID, not Client ID - code must resolve first
- `Application.ReadWrite.OwnedBy` is least privilege for Graph permissions
- `Key Vault Secrets Officer` is the correct RBAC role for secret management

## Lessons

- Always wrap Mermaid diagrams in proper ```mermaid code fences
- Tables in markdown require proper pipe alignment
- Frontmatter title + H1 = MD025 lint violation (use one or the other)
- Lists need blank lines before/after (MD032)
- C4 model: Start with System Context (L1) for big picture, then zoom in progressively
- C4 model: Container = deployable unit (not Docker), Component = code module
- C4 model: Dynamic diagrams complement static structure with runtime behavior
- C4 model: Deployment diagrams essential for showing auth patterns across environments
- Include relationship tables with each C4 diagram for explicit documentation of interactions

## Related Tasks

- None (first task in this project)
