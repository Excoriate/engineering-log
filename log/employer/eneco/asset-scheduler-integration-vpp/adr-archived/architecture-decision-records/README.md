## Overview
This repository is designed to maintain a record of all significant architecture decisions made for a given service. Each decision is encapsulated in an ADR and organized into its dedicated folder.

It is the place to holds all the decisions with an architectural/technical design nature. Infrastructure changes, adding new cloud components, creation of new services, big refactoring decisions, technical patterns to use generally in multiple services, etc..

---
## Collaboration

Usually collaboration between Architects, with inputs from Developers and Product Managers.

---
## Directory Structure

- `architecture-decision-records/`: Root directory containing all ADRs.
  - `<identifier>/`: A unique directory for each ADR.
    - `.img/`: images used in the README file.
    - `README.md`: Markdown file describing the architecture decision.
---
## Naming Convention

Each ADR should reside in its own directory within the `architecture-decision-records/` folder. The directory name should be a unique identifier.
The unique identifier use the format `NNN-description`, where `NNN` is a zero-padded incremental number.

Example:
```
architecture-decision-records/
├─ 001-choose-database/
│ └─ .img
│ └─ README.md
├─ 002-frontend-framework/
│ └─ .img
│ └─ README.md
...
```
---
## Review Process

Each ADR must have designated deciders as required reviewers for any future pull requests that modify it. Please reach a team member if you need help assigning required reviewers.

**Architects are recommended deciders**, with support from developers and product managers.

---

## General Best Practices

- Use clear and concise language.
- Keep records up-to-date.
- ADRs are not set in stone; they can be revisited and revised.

---