# ADR: GitHub 2.0 - migration & design

<!-- Source: ADR_ GitHub 2.0 - migration & design.pdf -->
<!-- Converted: 2026-01-19 -->
<!-- Pages: 3 -->

<!-- Page 1 -->

**Status:** Investigation

**Date:** 21-12-2025

**Decision Makers:** SRE Team

---

## Management summary

### Context

Since 2019, Eneco has been making use of a GitHub Enterprise instance that we are still making use of today. This Enterprise instance holds several GitHub organizations, including some that have been in use since that same time.

However, Azure DevOps has been the main Git provider for Eneco. But since Eneco has decided to shift that focus on GitHub, we are working on optimizing our GitHub setup.

Since we are working in the new Eneco organization for GitHub, and managing it as code, we are facing some challenges regarding user management. In our current Enterprise instance (Enterprise with Personal Accounts), users can be invited to the Eneco org based on their personal account. They are required to use SSO based on their Eneco credentials, but their personal GitHub account is not bound to their Eneco account. The consequence is that users can disassociate both accounts, and GitHub doesn't allow for automated on- and offboarding (using SCIM).

Since our goal is to fully automated user provisioning and management, and with the benefits involved with SCIM user provisioning, it is recommended to consider migrating to a different Enterprise type (GitHub Enterprise with Managed Users), as this type of Enterprise does allow us to automate user management. Migrating involves different steps and has some impact that needs to be considered. In this document, the research done around this migration will be described and a conclusion will be presented that will allow us to make an informed decision to do this or not. This document will also include a (re)design of our current setup.

<!-- Page 2 -->

<!-- [Diagram: User Lifecycle Management Flow]
A circular workflow diagram showing 5 stages of employee lifecycle management:

1. "New Employees" (starting point, with people icon)
   -> Arrow leads to...
2. "Provision" (with server/infrastructure icons, labeled "2")
   -> Flows into circular process...
3. "Enforce" (with lock/security icon, labeled "3")
   -> Continues to...
4. "Update" (with person/sync icon, labeled "4")
   -> Flows to...
5. "Offboard" (with exit icon, labeled "5")
   -> Loops back to beginning

The diagram illustrates the automated user provisioning lifecycle enabled by SCIM integration with GitHub Enterprise Managed Users.
-->

## Migration impact

### Positive

- Automatic org invitations and offboarding, limiting manual actions
- Addresses the concerns of working with GitHub usernames
- Automatic user information updates, based on their Entra ID information
- Alignment with the users setup for Rootly, Snyk, etc.
- End-to-end automation across different aspects within our self-service developer platform
- Improved compliancy

### Negative

- Time and effort to set it up
- Some features are currently not available

### Raised as concern

- No option for public repositories

<!-- Page 3 -->

## Decision

TBD

---

<!-- CONVERSION NOTES:
- Source: ADR_ GitHub 2.0 - migration & design.pdf (116.7KB, 3 pages)
- Sections: 4 (Management summary, Context, Migration impact, Decision)
- Subsections: 4 (Context, Positive, Negative, Raised as concern)
- Lists: 3 (Positive: 6 items, Negative: 2 items, Raised as concern: 1 item)
- Tables: 0
- Diagrams: 1 (User Lifecycle Management Flow - described in HTML comment)
- ADR Metadata: Status, Date, Decision Makers preserved
- Issues: None - full content preserved including diagram description
-->
