## Overview
This repository is designed to maintain a record of functional/domain design decisions, such as new functional integrations, data models and grouping of functionalities in domains. Each decision is encapsulated in an DDR and organized into its dedicated folder.

This folder holds 

---
## Collaboration
Usually collaboration between Product Managers with recomendations from Architects.

---
## Directory Structure

- `domain-decision-records/`: Root directory containing all IDRs.
  - `<identifier>/`: A unique directory for each DDR.
    - `.img/`: images used in the README file.
    - `README.md`: Markdown file describing the domain decision.
---
## Naming Convention

Each DDR should reside in its own directory within the `domain-decision-records/` folder. The directory name should be a unique identifier.
The unique identifier use the format `NNN-description`, where `NNN` is a zero-padded incremental number.

Example:
```
domain-decision-records/
├─ 001-device-vs-pool/
│ └─ .img
│ └─ README.md
├─ 002-new-asset-characteristic/
│ └─ .img
│ └─ README.md
...
```
---
## Review Process

Each DDR must have designated deciders as required reviewers for any future pull requests that modify it. Please reach a team member if you need help assigning required reviewers.

**Product managers are recommended deciders**, with support from architects (where domain decisions are architecture-impacting).

---

## General Best Practices

- Use clear and concise language.
- Keep records up-to-date.
- DDRs are not set in stone; they can be revisited and revised.

---