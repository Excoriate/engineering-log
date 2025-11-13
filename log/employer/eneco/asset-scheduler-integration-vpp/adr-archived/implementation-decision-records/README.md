
## Overview
This repository is designed to maintain a record of all significant implementation decisions made for a given service. Each decision is encapsulated in an IDR and organized into its dedicated folder.

Using a library or another for a specific use case, removing MassTranssit from a service, using Confluent or Axual could be some examples.

---
## Collaboration

Usually collaboration between Developers and Architects.

---
## Directory Structure

- `implementation-decision-records/`: Root directory containing all IDRs.
  - `<identifier>/`: A unique directory for each IDR.
    - `.img/`: images used in the README file.
    - `README.md`: Markdown file describing the domain decision.
---
## Naming Convention

Each ADR should reside in its own directory within the `implementation-decision-records/` folder. The directory name should be a unique identifier.
The unique identifier use the format `NNN-description`, where `NNN` is a zero-padded incremental number.

Example:
```
implementation-decision-records/
├─ 001-remove-masstranssit/
│ └─ .img
│ └─ README.md
├─ 002-use-confluent-esp-connectivity/
│ └─ .img
│ └─ README.md
...
```
---
## Review Process

Each IDR must have designated deciders as required reviewers for any future pull requests that modify it. Please reach a team member if you need help assigning required reviewers.

**Developers are recommended deciders**, with support from architects.

---

## General Best Practices

- Use clear and concise language.
- Keep records up-to-date.
- IDRs are not set in stone; they can be revisited and revised.

---