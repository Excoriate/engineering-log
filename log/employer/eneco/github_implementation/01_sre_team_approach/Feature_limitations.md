# Feature limitations

<!-- Source: Feature limitations.pdf -->
<!-- Converted: 2026-01-19 -->
<!-- Pages: 2 -->

<!-- Page 1 -->

There is a set of features that are not yet available on the new Enterprise instance:

## Currently unavailable features

The following features are currently unavailable on GHE.com, but may be planned for future development.

| # | Feature | Details | More information | Alternative |
|---|---------|---------|------------------|-------------|
| 1 | Copilot Metrics API | Currently unavailable. | [REST API endpoints for Copilot metrics](https://docs.github.com/en/rest/copilot) | |
| 2 | GitHub Codespaces | Currently unavailable. | [Quickstart for GitHub Codespaces](https://docs.github.com/en/codespaces/getting-started/quickstart) | Applications like Eclipse, Coder... |
| 3 | macOS runners for GitHub Actions | Currently unavailable. | [GitHub-hosted runners](https://docs.github.com/en/actions/using-github-hosted-runners) | Possibly used by Mobile App team. Alternative to keep pipelines in Azure DevOps |
| 4 | Maven and Gradle support for GitHub Packages | Currently unavailable. | [Working with the Apache Maven registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-apache-maven-registry) | Check with Data team. Do we need this at all and not the solution in Azure? |
| 5 | Spark | Currently unavailable. | [About GitHub Spark](https://docs.github.com/en/spark) | Check with Data team. Probably not needed. Double check |
| 6 | GitHub Marketplace | GitHub Marketplace, as a means of searching for, purchasing, and directly installing apps and actions, is unavailable. Ecosystem apps and actions can still be discovered and installed from their source, but they may require modification to work on GHE.com. | [GitHub Actions workflows from GitHub Marketplace](https://docs.github.com/en/actions/learn-github-actions/finding-and-customizing-actions) | Research |
| 7 | Certain features of GitHub Connect | Although you can connect an enterprise on GHE.com to a GitHub Enterprise Server instance, certain features of GitHub Connect are not available, including resolution of actions from GitHub.com. | [GitHub Connect](https://docs.github.com/en/enterprise-server/admin/configuration/configuring-github-connect) | N/A |

<!-- Page 2 -->

| # | Feature | Details | More information | Alternative |
|---|---------|---------|------------------|-------------|
| 8 | Some features currently in public preview or private preview | Certain features that are in a preview phase on GitHub.com may not be available on GHE.com until GA. | | |

## Permanently unavailable features

By design, the following features are permanently unavailable on GHE.com. This is generally because they are not intended for large enterprises with strict compliance requirements.

| # | Feature | Details | More information |
|---|---------|---------|------------------|
| 1 | Features unavailable with Enterprise Managed Users | Because Enterprise Managed Users is the only option for identity management on GHE.com, features that are unavailable with Enterprise Managed Users on GitHub.com are also unavailable on GHE.com. Notably, these include gists and public repositories. | [Abilities and restrictions of managed user accounts](https://docs.github.com/en/enterprise-cloud@latest/admin/identity-and-access-management/understanding-iam-for-enterprises/abilities-and-restrictions-of-managed-user-accounts) |
| 2 | GitHub Importer (the "Import repository" button on GitHub.com) | Instead, the **GitHub Enterprise Importer** is available to migrate data. See About GitHub Enterprise Importer. | [About GitHub Importer](https://docs.github.com/en/migrations/importing-source-code/using-github-importer) |

---

<!-- CONVERSION NOTES:
- Source: Feature limitations.pdf (148.6KB, 2 pages)
- Sections: 3 (Introduction, Currently unavailable features, Permanently unavailable features)
- Subsections: 0
- Lists: 0
- Tables: 2 (Currently unavailable: 8 rows x 4 columns, Permanently unavailable: 2 rows x 3 columns)
- Diagrams: 0
- Links preserved: 9 documentation links converted to markdown format
- Issues: None - full content preserved including all table cells
-->
