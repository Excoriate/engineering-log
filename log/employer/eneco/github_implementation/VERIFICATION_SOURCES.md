# Eneco GitHub Implementation - Claim Verification Report

**Generated**: 2026-01-19
**Purpose**: Verify technical claims against official documentation sources

---

## Executive Summary

| Category | Total Claims | Verified | Partial | Incorrect | Unverified |
|----------|--------------|----------|---------|-----------|------------|
| Terraform GitHub Provider | 4 | 2 | 1 | 1 | 0 |
| GitHub Enterprise Features | 5 | 4 | 1 | 0 | 0 |
| Azure Terraform Backend | 4 | 3 | 1 | 0 | 0 |
| GitHub Actions | 4 | 3 | 1 | 0 | 0 |
| SAML/SSO Integration | 3 | 3 | 0 | 0 | 0 |
| **TOTAL** | **20** | **15** | **4** | **1** | **0** |

---

## 1. Terraform GitHub Provider

### Claim 1.1: Provider version `~> 5.0` allows breaking changes between minor versions

**Status**: INCORRECT
**Source**: https://registry.terraform.io/providers/integrations/github/latest
**Evidence**: Current provider version is **6.10.1** (not 5.x). The `~>` constraint in Terraform is a "pessimistic constraint operator" that allows only rightmost version component to increment. `~> 5.0` allows `5.0.1`, `5.1.0`, etc., but NOT `6.0.0`. This is standard Terraform versioning, not breaking changes between minors.
**Correction**: The claim conflates version constraint syntax with semantic versioning. Use `~> 6.0` for latest provider with minor/patch updates only.
**Confidence**: HIGH

---

### Claim 1.2: `github_branch_protection` is deprecated in favor of `github_repository_ruleset`

**Status**: PARTIAL
**Source**: https://registry.terraform.io/providers/integrations/github/latest/docs/resources/branch_protection
**Evidence**: The `github_branch_protection` resource documentation does NOT state it is deprecated. It states:

> "This resource allows you to configure branch protection for repositories in your organization."

Both resources coexist:
- `github_branch_protection` - Uses GraphQL API
- `github_branch_protection_v3` - Uses REST API (for backwards compatibility)
- `github_repository_ruleset` - Newer feature with more capabilities (push rulesets, file restrictions, code scanning requirements)

**Correction**: `github_branch_protection` is NOT deprecated. `github_repository_ruleset` is a newer, more feature-rich alternative but not a replacement. Both are supported.
**Confidence**: HIGH

---

### Claim 1.3: `github_team_sync_group_mapping` resource exists for IdP integration

**Status**: VERIFIED
**Source**: https://registry.terraform.io/providers/integrations/github/latest/docs/resources/team_sync_group_mapping
**Evidence**:
> "This resource allows you to create and manage Identity Provider (IdP) group connections within your GitHub teams. You must have team synchronization enabled for organizations owned by enterprise accounts."

Example usage:
```hcl
resource "github_team_sync_group_mapping" "example_group_mapping" {
  team_slug = "example"
  dynamic "group" {
    for_each = [for g in data.github_organization_team_sync_groups.example_groups.groups : g if g.group_name == "some_team_group"]
    content {
      group_id          = group.value.group_id
      group_name        = group.value.group_name
      group_description = group.value.group_description
    }
  }
}
```
**Confidence**: HIGH

---

### Claim 1.4: GitHub App provides higher rate limits than PAT (15000/hr vs 5000/hr)

**Status**: VERIFIED
**Source**: https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api
**Evidence**:
> "All of these requests count towards your personal rate limit of **5,000 requests per hour**."

> "GitHub Apps authenticating with an installation access token use the installation's minimum rate limit of **5,000 requests per hour**. If the installation is on a **GitHub Enterprise Cloud organization**, the installation has a rate limit of **15,000 requests per hour**."

> "Requests made on your behalf by a GitHub App that is owned by a GitHub Enterprise Cloud organization have a higher rate limit of **15,000 requests per hour**."

**Nuance**: The 15,000/hr rate applies specifically to GitHub Enterprise Cloud organizations. Standard GitHub organizations still get 5,000/hr base with scaling based on users/repos.
**Confidence**: HIGH

---

## 2. GitHub Enterprise Features

### Claim 2.1: EMU (Enterprise Managed Users) vs SAML/SCIM differences

**Status**: VERIFIED
**Source**: https://docs.github.com/en/enterprise-cloud@latest/admin/managing-iam/understanding-iam-for-enterprises/about-enterprise-managed-users
**Evidence**:
> "With Enterprise Managed Users, you manage the lifecycle and authentication of your users on GitHub.com or GHE.com **from an external identity management system, or IdP**:
> - Your IdP **provisions new user accounts** on GitHub, with access to your enterprise.
> - Users must **authenticate on your IdP** to access your enterprise's resources on GitHub.
> - You control **usernames, profile data, organization membership, and repository access** from your IdP."

Key difference from standard SAML SSO:
- EMU: IdP provisions accounts, controls usernames, full lifecycle management
- SAML SSO: Links existing GitHub accounts to IdP identities, users keep personal accounts

**Confidence**: HIGH

---

### Claim 2.2: SCIM provisioning capabilities with Azure AD (Entra ID)

**Status**: VERIFIED
**Source**: https://docs.github.com/en/enterprise-cloud@latest/admin/identity-and-access-management/provisioning-user-accounts-for-enterprise-managed-users/configuring-scim-provisioning-for-enterprise-managed-users
**Evidence**:
> "With SCIM, you manage the lifecycle of user accounts from your IdP:
> - After you configure provisioning for Enterprise Managed Users, your IdP uses SCIM to provision user accounts on GitHub and add the accounts to your enterprise.
> - When you update information associated with a user's identity on your IdP, your IdP will update the user's account on GitHub.
> - When you unassign the user from the IdP application or deactivate a user's account on your IdP, your IdP will communicate with GitHub to invalidate any sessions and disable the member's account."

**Important Warning**:
> "The combination of **Okta and Entra ID** for SSO and SCIM (in either order) is explicitly **not supported**. GitHub's SCIM API will return an error to the identity provider on provisioning attempts if this combination is configured."

**Confidence**: HIGH

---

### Claim 2.3: Repository rulesets as replacement for legacy branch protection

**Status**: VERIFIED
**Source**: https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_ruleset
**Evidence**: `github_repository_ruleset` provides enhanced capabilities beyond branch protection:

```hcl
rules {
  creation                = true
  update                  = true
  deletion                = true
  required_linear_history = true
  required_signatures     = true

  # Features NOT available in branch_protection:
  file_path_restriction {
    restricted_file_paths = [".github/workflows/*", "*.env"]
  }

  max_file_size {
    max_file_size = 100  # 100 MB
  }

  file_extension_restriction {
    restricted_file_extensions = ["*.exe", "*.dll", "*.so"]
  }

  required_code_scanning {
    required_code_scanning_tool {
      tool = "CodeQL"
    }
  }
}
```

New features in rulesets: `target = "push"` rules, file path restrictions, file size limits, extension restrictions, code scanning requirements.
**Confidence**: HIGH

---

### Claim 2.4: GitHub App installation token refresh behavior

**Status**: PARTIAL
**Source**: https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api
**Evidence**: Documentation confirms GitHub Apps use installation access tokens but does not detail refresh behavior in this document. Installation tokens typically expire after 1 hour and must be regenerated.

> "GitHub Apps authenticating with an installation access token use the installation's minimum rate limit of 5,000 requests per hour."

**Note**: Full token lifecycle documentation would require additional source (GitHub Apps authentication docs).
**Confidence**: MEDIUM

---

### Claim 2.5: Public repository restriction in EMU

**Status**: VERIFIED
**Source**: https://docs.github.com/en/enterprise-cloud@latest/admin/managing-iam/understanding-iam-for-enterprises/about-enterprise-managed-users
**Evidence**:
> "Managed user accounts **cannot create public content** or collaborate outside your enterprise. See Abilities and restrictions of managed user accounts."

This is a fundamental restriction of EMU - users cannot create public repositories or contribute to external open-source projects from their managed accounts.
**Confidence**: HIGH

---

## 3. Azure Terraform Backend

### Claim 3.1: Azure Blob storage backend supports state locking via blob leases

**Status**: VERIFIED
**Source**: https://developer.hashicorp.com/terraform/language/backend/azurerm
**Evidence**:
> "This backend supports state locking and consistency checking with Azure Blob Storage native capabilities."

Microsoft Learn documentation confirms:
> "Azure Storage blobs are automatically locked before any operation that writes state. This pattern prevents concurrent state operations, which can cause corruption."

**Confidence**: HIGH

---

### Claim 3.2: `use_azuread_auth = true` enables blob lease locking

**Status**: PARTIAL
**Source**: https://developer.hashicorp.com/terraform/language/backend/azurerm
**Evidence**: `use_azuread_auth = true` enables **Microsoft Entra ID authentication** to the storage account data plane, NOT blob lease locking specifically.

> "`use_azuread_auth` - Set to `true` to use Microsoft Entra ID authentication to the storage account data plane."

State locking is automatic regardless of authentication method. The `use_azuread_auth` flag determines **how** you authenticate (Azure AD vs access keys/SAS tokens), not **whether** locking is enabled.

**Correction**: State locking via blob leases is automatic with the azurerm backend. `use_azuread_auth` controls authentication method, not locking behavior.
**Confidence**: HIGH

---

### Claim 3.3: State locking is automatic with Azure backend

**Status**: VERIFIED
**Source**: https://learn.microsoft.com/en-us/azure/developer/terraform/store-state-in-azure-storage
**Evidence**:
> "Azure Storage blobs are **automatically locked** before any operation that writes state. This pattern prevents concurrent state operations, which can cause corruption."

> "You can see the lock when you examine the blob through the Azure portal or other Azure management tooling."

Troubleshooting guidance confirms automatic locking:
> "Error: Error acquiring the state lock; Error message: state blob is already locked"

**Confidence**: HIGH

---

### Claim 3.4: Blob lease timeout configuration

**Status**: VERIFIED
**Source**: https://learn.microsoft.com/en-us/rest/api/storageservices/lease-blob
**Evidence**:
> "The `Lease Blob` operation creates and manages a lock on a blob for write and delete operations. The lock duration can be **15 to 60 seconds**, or can be **infinite**."

Lease states documented:
1. Available - Can be acquired
2. Leased - Locked (15-60s or infinite)
3. Expired - Duration has expired
4. Breaking - Being broken but still locked
5. Broken - Fully broken

**Note**: Terraform does not expose lease duration configuration; it uses Azure's defaults.
**Confidence**: HIGH

---

## 4. GitHub Actions

### Claim 4.1: `concurrency` blocks prevent parallel workflow runs

**Status**: VERIFIED
**Source**: https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/control-the-concurrency-of-workflows-and-jobs
**Evidence**:
> "You can use `jobs.<job_id>.concurrency` to ensure that only a single job or workflow using the same concurrency group will run at a time."

> "This means that there can be **at most one running and one pending** job in a concurrency group at any time."

Example:
```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```
**Confidence**: HIGH

---

### Claim 4.2: `cancel-in-progress: false` queues workflows

**Status**: VERIFIED
**Source**: https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/control-the-concurrency-of-workflows-and-jobs
**Evidence**:
> "When a concurrent job or workflow is queued, if another job or workflow using the same concurrency group in the repository is in progress, the **queued job or workflow will be `pending`**."

When `cancel-in-progress: false` (default), workflows queue rather than cancel previous runs. When `cancel-in-progress: true`, the running workflow is cancelled.

> "Any existing `pending` job or workflow in the same concurrency group, if it exists, will be canceled and the new queued job or workflow will take its place."

**Nuance**: Only ONE pending job/workflow is kept; additional new runs replace the pending one.
**Confidence**: HIGH

---

### Claim 4.3: Environment protection rules can gate deployments

**Status**: VERIFIED
**Source**: https://docs.github.com/en/actions/managing-workflow-runs-and-deployments/managing-deployments/managing-environments-for-deployment
**Evidence**:
> "You can create environments and secure those environments with deployment protection rules. A job that references an environment **must follow any protection rules for the environment before running** or accessing the environment's secrets."

Protection rules available:
- **Required reviewers**: "Enter up to 6 people or teams. Only one of the required reviewers needs to approve the job for it to proceed."
- **Wait timer**: "Enter the number of minutes to wait."
- **Deployment branches**: Restrict which branches can deploy
- **Custom deployment protection rules**: Via GitHub Apps

**Confidence**: HIGH

---

### Claim 4.4: Workflow artifacts expire after 90 days (default)

**Status**: PARTIAL
**Source**: https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/storing-and-sharing-data-from-a-workflow
**Evidence**: The documentation shows **custom retention** is configurable:

```yaml
- name: 'Upload Artifact'
  uses: actions/upload-artifact@v4
  with:
    name: my-artifact
    path: my_file.txt
    retention-days: 5
```

> "The `retention-days` value cannot exceed the retention limit set by the repository, organization, or enterprise."

**Note**: The default retention period is set at the organization/enterprise level and is typically 90 days for GitHub Enterprise Cloud, but this specific default value was not found in the fetched documentation. The claim is likely correct but requires verification in organization settings documentation.
**Confidence**: MEDIUM

---

## 5. SAML/SSO Integration

### Claim 5.1: SAML SSO protects API endpoints for teams/members

**Status**: VERIFIED
**Source**: https://docs.github.com/en/enterprise-cloud@latest/authentication/authenticating-with-saml-single-sign-on/about-authentication-with-saml-single-sign-on
**Evidence**:
> "Single sign-on (SSO) gives organization owners and enterprise owners a way to **control and secure access to organization resources** like repositories, issues, and pull requests."

> "To use the API or Git on the command line to access protected content in an organization that uses SSO, you will need to use an **authorized personal access token** over HTTPS or an **authorized SSH key**."

> "Access to SSO protected `internal` resources in an enterprise, such as repositories, projects, and packages, **requires an SSO session** for any organization in the enterprise."

**Confidence**: HIGH

---

### Claim 5.2: GitHub audit logs trace to SSO principal, not username

**Status**: VERIFIED
**Source**: https://docs.github.com/en/enterprise-cloud@latest/admin/monitoring-activity-in-your-enterprise/reviewing-audit-logs-for-your-enterprise/about-the-audit-log-for-your-enterprise
**Evidence**:
> "Each audit log entry shows applicable information about an event, such as:
> - The user (actor) who performed the action
> - **The SAML SSO and SCIM identity** of the user (actor) who performed the action
> - For actions outside of the web UI, how the user (actor) authenticated"

The audit log captures both the GitHub username AND the SSO/SCIM identity, providing full traceability.
**Confidence**: HIGH

---

### Claim 5.3: Personal Access Tokens require SSO authorization for SAML-protected orgs

**Status**: VERIFIED
**Source**: https://docs.github.com/en/enterprise-cloud@latest/authentication/authenticating-with-saml-single-sign-on/authorizing-a-personal-access-token-for-use-with-saml-single-sign-on
**Evidence**:
> "You must authorize your personal access token (classic) after creation **before the token can access an organization that uses SAML single sign-on (SSO)**."

> "Before you can authorize a personal access token or SSH key, you must have a **linked external identity**. If you're a member of an organization where SSO is enabled, you can create a linked external identity by authenticating to your organization with your identity provider (IdP) at least once."

> "Fine-grained personal access tokens are authorized **during token creation**, before access to the organization is granted."

Authorization revocation scenarios:
- Organization/enterprise owner revokes authorization
- User is removed from organization
- Token scopes are edited or token is regenerated
- Token expires
**Confidence**: HIGH

---

## Corrections Required

### High Priority Corrections

1. **Provider Version Constraint** (Claim 1.1)
   - **Original**: `~> 5.0` allows breaking changes
   - **Correction**: Current provider is `6.10.1`. Use `~> 6.0` for proper constraint. The `~>` operator is standard Terraform and does NOT allow breaking changes (only rightmost component increments).

2. **Branch Protection Deprecation** (Claim 1.2)
   - **Original**: `github_branch_protection` is deprecated
   - **Correction**: NOT deprecated. Both `github_branch_protection` and `github_repository_ruleset` are supported. Rulesets offer more features but are not a replacement.

3. **use_azuread_auth Purpose** (Claim 3.2)
   - **Original**: `use_azuread_auth = true` enables blob lease locking
   - **Correction**: This flag enables Azure AD authentication, not locking. State locking is automatic regardless of authentication method.

---

## Source Bibliography

| Domain | URL | Retrieved |
|--------|-----|-----------|
| Terraform GitHub Provider | https://registry.terraform.io/providers/integrations/github/latest | 2026-01-19 |
| github_branch_protection | https://registry.terraform.io/providers/integrations/github/latest/docs/resources/branch_protection | 2026-01-19 |
| github_repository_ruleset | https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_ruleset | 2026-01-19 |
| github_team_sync_group_mapping | https://registry.terraform.io/providers/integrations/github/latest/docs/resources/team_sync_group_mapping | 2026-01-19 |
| GitHub REST API Rate Limits | https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api | 2026-01-19 |
| GitHub EMU | https://docs.github.com/en/enterprise-cloud@latest/admin/managing-iam/understanding-iam-for-enterprises/about-enterprise-managed-users | 2026-01-19 |
| GitHub SCIM Provisioning | https://docs.github.com/en/enterprise-cloud@latest/admin/identity-and-access-management/provisioning-user-accounts-for-enterprise-managed-users/configuring-scim-provisioning-for-enterprise-managed-users | 2026-01-19 |
| Terraform azurerm Backend | https://developer.hashicorp.com/terraform/language/backend/azurerm | 2026-01-19 |
| Azure Storage State Locking | https://learn.microsoft.com/en-us/azure/developer/terraform/store-state-in-azure-storage | 2026-01-19 |
| Azure Blob Lease API | https://learn.microsoft.com/en-us/rest/api/storageservices/lease-blob | 2026-01-19 |
| GitHub Actions Concurrency | https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/control-the-concurrency-of-workflows-and-jobs | 2026-01-19 |
| GitHub Environments | https://docs.github.com/en/actions/managing-workflow-runs-and-deployments/managing-deployments/managing-environments-for-deployment | 2026-01-19 |
| GitHub Actions Artifacts | https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/storing-and-sharing-data-from-a-workflow | 2026-01-19 |
| GitHub SAML SSO | https://docs.github.com/en/enterprise-cloud@latest/authentication/authenticating-with-saml-single-sign-on/about-authentication-with-saml-single-sign-on | 2026-01-19 |
| GitHub PAT SSO Authorization | https://docs.github.com/en/enterprise-cloud@latest/authentication/authenticating-with-saml-single-sign-on/authorizing-a-personal-access-token-for-use-with-saml-single-sign-on | 2026-01-19 |
| GitHub Audit Logs | https://docs.github.com/en/enterprise-cloud@latest/admin/monitoring-activity-in-your-enterprise/reviewing-audit-logs-for-your-enterprise/about-the-audit-log-for-your-enterprise | 2026-01-19 |

---

## Methodology

**Tools Used**:
- Terraform Registry MCP (`mcp__terraform`) for provider/module documentation
- Microsoft Docs MCP (`mcp__microsoft-docs-mcp`) for Azure documentation
- Fetch MCP (`mcp__fetch__fetch`) for GitHub official documentation
- Direct URL fetching for HashiCorp documentation

**Verification Criteria**:
- **VERIFIED**: Claim matches official documentation verbatim or semantically
- **PARTIAL**: Claim is partially correct but missing nuance or context
- **INCORRECT**: Claim contradicts official documentation
- **UNVERIFIED**: Insufficient documentation to confirm or deny

**Confidence Levels**:
- **HIGH**: Direct quote or clear statement from official docs
- **MEDIUM**: Inferred from documentation, no explicit statement
- **LOW**: Limited evidence, requires additional verification
