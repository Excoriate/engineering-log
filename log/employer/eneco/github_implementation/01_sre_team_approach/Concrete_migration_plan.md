# Concrete migration plan

<!-- Source: Concrete migration plan.pdf -->
<!-- Converted: 2026-01-19 -->
<!-- Pages: 2 -->

<!-- Page 1 -->

For the migration, it has been confirmed by Microsoft that we can use a trial Enterprise instance, that we can extend to 90 days, if needed. For migration it is advised to do this per repository. There is a migration tool available that can help, but it can't migrate everything. This tool has to be researched and tested out thoroughly.

For the licenses, we are allowed to gradually move our licenses to the new Enterprise instance. Allowing us to do it step by step without incurring a lot of extra costs. It also allows us to set up metered billing for licenses. Meaning, we don't have to buy bundles of licenses, but the costs just increases on the amount of users in the Enterprise instance.

## Preparation steps

1. ~~Create trial enterprise account~~
2. ~~Try out GHE (EU with Data Residency) and figure out differences and how to tackle them~~
3. ~~Create management organization manually in the new enterprise instance.~~
4. ~~Set up SSO with SCIM and onboard SRE team members~~
5. Experiment with migration tool for our SRE team and repositories, including environment variables, permissions, etc.
6. Clone the management repo in the management org, adjust and create main organization from Terraform
7. Manually create repo of repos, and clone from existing Enterprise instance org
8. Create full team structure and repositories
9. Validate

## Actual migration steps per repository

1. Make sure all environment variables, secrets, apps are recreated
   a. Use the migration tool to migrate everything that's possible and we don't manage in code (environment variables, runners, apps, etc.)

<!-- Page 2 -->

   b. Manually add anything that can't be created
2. Onboard team and users through SCIM
3. Instruct users to not use the old org / block permissions
4. Clone the repository
5. Grant access to GitHub Copilot
6. Have it validated by owning team
7. After approval, remove from old organization

---

<!-- CONVERSION NOTES:
- Source: Concrete migration plan.pdf (57.1KB, 2 pages)
- Sections: 3 (Introduction, Preparation steps, Actual migration steps per repository)
- Subsections: 0
- Lists: 2 (preparation: 9 items with 4 strikethrough, migration: 7 items with 2 sub-items)
- Tables: 0
- Diagrams: 0
- Formatting preserved: Strikethrough on items 1-4 in Preparation steps (completed tasks)
- Issues: None - full content preserved
-->
