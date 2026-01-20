# General organization setup

<!-- Source: General organization setup.pdf -->
<!-- Converted: 2026-01-19 -->
<!-- Pages: 1 -->

<!-- Page 1 -->

- One organization "Eneco" that includes all teams and repositories. No special exceptions for departments to create separate orgs
- Cloud & SRE team has owner permissions on org level
- Security team can have security manager permission on org level, if needed
- Partner Management team can have billing manager permission on org level, if needed
- All other members have all-repository reader as base organization permission
- Teams are set up according to the org chart, meaning, as example:
  - On highest level, we will have Platform Engineering as a team
  - In the Platform Engineering team, you have 3 sub teams, including Cloud & SRE
  - Custom teams are not allowed to ensure a clean organization
- Teams own applications and have therefore admin/collaborator permissions on the repositories related to their applications
- Individual permissions to users outside the repository's owning team need to be assigned directly. For instance, in case of cross-collaboration
- Additional organization permissions for non-Cloud & SRE team members are NOT allowed

## How to further maintain a clean state

- There is only one GitHub <> Azure DevOps integration with Azure Boards
- The use of GitHub projects is not enabled. All work management stays in Azure DevOps
- All integrations, apps, services and setup are maintained by Cloud & SRE team
- All requests for GitHub apps, Copilot, etc. need to go to #help-sre

---

<!-- CONVERSION NOTES:
- Source: General organization setup.pdf (58.1KB, 1 page)
- Sections: 2 (Main setup, How to further maintain a clean state)
- Subsections: 0
- Lists: 2 (main list: 9 items with 3 nested items, maintenance list: 4 items)
- Tables: 0
- Diagrams: 0
- Issues: None - full content preserved
-->
