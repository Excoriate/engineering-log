# Eneco GitHub Organization Audit

**Audit Date**: 2026-01-19
**Auditor**: Alex Torres (Excoriate)
**Scope**: Comprehensive GitHub organization configuration review

---

## Executive Summary

| Metric | Value |
|--------|-------|
| **Total Repositories** | 77 |
| **Active Repositories** | 77 (0 archived) |
| **Visibility** | 100% Internal |
| **Members Visible** | 0 (SAML protected) |
| **Teams Visible** | Access denied (SAML) |
| **Primary Language** | HCL (Terraform) - 58% |
| **Rulesets Active** | 2 (1 Org + 1 Enterprise) |
| **Branch Protection** | Via rulesets, not legacy protection |

### Key Security Findings

| Finding | Severity | Status |
|---------|----------|--------|
| SAML SSO enforced | **GOOD** | Active |
| All repos internal | **GOOD** | Enforced via ruleset |
| No public repos | **GOOD** | Enforced via ruleset |
| Repo naming convention | **GOOD** | Enforced (kebab-case) |
| Issues disabled (all repos) | **NOTE** | By design |
| Traditional branch protection | **NOTE** | Replaced by rulesets |
| Security settings visibility | **LIMITED** | Requires elevated access |

---

## 1. Organization Settings

### Basic Information

```json
{
  "login": "Eneco",
  "id": 17332554,
  "name": "Eneco",
  "company": "Eneco",
  "blog": "https://www.eneco.com",
  "location": "Netherlands",
  "email": "FM_Tech_sre_team@eneco.com",
  "is_verified": false,
  "has_organization_projects": false,
  "has_repository_projects": false,
  "public_repos": 0,
  "public_gists": 0,
  "followers": 9,
  "created_at": "2016-02-19T08:29:13Z",
  "updated_at": "2025-12-15T13:28:37Z",
  "type": "Organization"
}
```

### Security Configuration (via API)

| Setting | Value | Notes |
|---------|-------|-------|
| `default_repository_permission` | `null` | Requires admin access to view |
| `members_can_create_repositories` | `null` | Requires admin access to view |
| `two_factor_requirement_enabled` | `null` | Requires admin access to view |
| `advanced_security_enabled_for_new_repositories` | `null` | Requires admin access to view |
| `dependabot_alerts_enabled_for_new_repositories` | `null` | Requires admin access to view |
| `secret_scanning_enabled_for_new_repositories` | `null` | Requires admin access to view |

**Note**: Organization security settings require org admin permissions to query via API. Most fields return `null` for non-admin access.

---

## 2. Members & Teams

### Members

**Status**: Access Denied (SAML Enforcement)

```json
{
  "message": "Resource protected by organization SAML enforcement. You must grant your Personal Access token access to this organization.",
  "status": "403"
}
```

**Observation**: Members list is protected by SAML SSO. This is a security best practice for enterprise organizations.

### Teams

**Status**: Access Denied (SAML Enforcement)

Same SAML restriction applies to teams endpoint.

**Recommendation**: To audit teams, authorize PAT via SAML SSO flow at:
`https://github.com/orgs/Eneco/sso`

---

## 3. Repositories

### Summary Statistics

| Metric | Count | Percentage |
|--------|-------|------------|
| **Total** | 77 | 100% |
| **Active (non-archived)** | 77 | 100% |
| **Archived** | 0 | 0% |
| **Internal visibility** | 77 | 100% |
| **Public visibility** | 0 | 0% |
| **Private visibility** | 0 | 0% |
| **Forked** | 0 | 0% |
| **Template repos** | 2 | 2.6% |

### Feature Configuration

| Feature | Enabled | Disabled |
|---------|---------|----------|
| Issues | 0 | 77 |
| Wiki | 61 | 16 |
| Projects | 0 | 77 |
| Allow Forking | 0 | 77 |

### Default Branch

All 77 repositories use `main` as the default branch. **100% compliance** with modern naming conventions.

### Language Distribution

| Language | Repos | Percentage |
|----------|-------|------------|
| HCL (Terraform) | 45 | 58.4% |
| Not detected | 17 | 22.1% |
| Python | 4 | 5.2% |
| C# | 3 | 3.9% |
| Smarty | 2 | 2.6% |
| Shell | 2 | 2.6% |
| TypeScript | 1 | 1.3% |
| Jupyter Notebook | 1 | 1.3% |
| JavaScript | 1 | 1.3% |
| Java | 1 | 1.3% |

**Observation**: Organization is heavily focused on Infrastructure as Code (58% Terraform).

### Template Repositories

1. `sre-template-tf-module` - Terraform module template
2. `sre-template-tf-infra` - Terraform infrastructure template

### Top 20 Repositories by Size

| Repository | Language | Size (KB) | Last Push |
|------------|----------|-----------|-----------|
| datainfra-tf-infra-databricks | HCL | 1,603 | 2026-01-16 |
| cce-core-processor | C# | 978 | 2026-01-16 |
| sre-idp | TypeScript | 881 | 2025-12-18 |
| sre-tf-module-aks | HCL | 812 | 2026-01-14 |
| sre-platform-services | HCL | 665 | 2026-01-15 |
| sre-validators | Python | 524 | 2025-10-21 |
| sre-pipelines | - | 341 | 2026-01-15 |
| sre-platform-docs | JavaScript | 286 | 2026-01-16 |
| sre-test-workflows | - | 260 | 2025-11-17 |
| sre-tf-github-repositories | HCL | 219 | 2026-01-16 |
| sre-tf-workflows | - | 197 | 2025-10-22 |
| sre-tf-infra-odp | HCL | 187 | 2026-01-19 |
| datainfra-cost-monitoring | Shell | 179 | 2026-01-15 |
| sre-infra-odp | Jupyter | 163 | 2026-01-16 |
| sre-tf-infra-akamai-dns | HCL | 156 | 2026-01-14 |
| sre-k8s-argocd-root-apps | - | 154 | 2026-01-16 |
| sre-test-infra-mgmt | HCL | 141 | 2025-12-16 |
| aks-dev-wallace | HCL | 109 | 2025-11-04 |
| sre-slack-bot | Python | 98 | 2025-11-18 |
| sre-bootstrap-subscription | Shell | 94 | 2025-12-24 |

### Repository Activity Timeline

#### Repos by Last Push (Monthly)

| Month | Repos Pushed |
|-------|--------------|
| 2026-01 | 38 |
| 2025-12 | 16 |
| 2025-11 | 15 |
| 2025-10 | 6 |
| 2025-09 | 1 |
| 2025-04 | 1 |

**Observation**: Very active organization - 49% of repos pushed in January 2026.

#### Repos by Creation Date (Monthly)

| Month | Repos Created |
|-------|---------------|
| 2026-01 | 12 |
| 2025-12 | 23 |
| 2025-11 | 22 |
| 2025-10 | 8 |
| 2025-09 | 3 |
| 2025-08 | 2 |
| 2025-07 | 2 |
| 2025-06 | 1 |
| 2025-05 | 2 |
| 2025-04 | 2 |

**Observation**: Rapid growth - 74% of repos created in last 3 months (Nov 2025 - Jan 2026).

### Complete Repository List

| Repository | Visibility | Default Branch | Wiki | Template |
|------------|------------|----------------|------|----------|
| sre-template-tf-module | internal | main | yes | **yes** |
| sre-challenge | internal | main | yes | no |
| sre-tf-module-aks | internal | main | yes | no |
| sre-tf-module-storage-account | internal | main | yes | no |
| sre-bootstrap-subscription | internal | main | yes | no |
| aks-dev-wallace | internal | main | yes | no |
| sre-tf-module-vmss | internal | main | yes | no |
| sre-packer-gh-runners | internal | main | yes | no |
| sre-validators | internal | main | yes | no |
| sre-tf-workflows | internal | main | yes | no |
| sre-k8s-argocd-root-apps | internal | main | yes | no |
| sre-tf-env-mgmt | internal | main | yes | no |
| sre-tf-github-teams | internal | main | yes | no |
| sre-tf-github-repositories | internal | main | yes | no |
| sre-platform-management | internal | main | yes | no |
| sre-tf-module-acr | internal | main | yes | no |
| sre-test-workflows | internal | main | yes | no |
| sre-test-infra-mgmt | internal | main | yes | no |
| sre-platform-teams-config | internal | main | yes | no |
| sre-dns-parser | internal | main | yes | no |
| sre-pipelines | internal | main | yes | no |
| sre-template-tf-infra | internal | main | yes | **yes** |
| sre-tf-infra-runners | internal | main | yes | no |
| sre-tf-infra-acr | internal | main | yes | no |
| sre-tf-infra-aks-platform | internal | main | yes | no |
| sre-tf-infra-aks-shared | internal | main | yes | no |
| sre-tf-module-keyvault | internal | main | no | no |
| sre-tf-module-postgresql | internal | main | yes | no |
| sre-tf-infra-aks-platform-management | internal | main | yes | no |
| sre-tf-infra-slack-bot | internal | main | yes | no |
| sre-slack-bot | internal | main | yes | no |
| sre-slack-bot-gitops | internal | main | yes | no |
| sre-arc-runners-gitops | internal | main | yes | no |
| sre-tf-infra-akamai-dns | internal | main | yes | no |
| sre-tf-module-agw | internal | main | yes | no |
| sre-tf-infra-token-rotators | internal | main | yes | no |
| sre-token-rotators-gitops | internal | main | yes | no |
| sre-token-rotators | internal | main | yes | no |
| sre-idp | internal | main | no | no |
| sre-tf-sbx-kafka | internal | main | yes | no |
| sre-appreg-creds-watchdog | internal | main | yes | no |
| sre-tf-module-private-endpoint | internal | main | no | no |
| sre-tf-module-waf-policy | internal | main | yes | no |
| sre-tf-infra-agw | internal | main | yes | no |
| sre-tf-infra-sre-idp | internal | main | yes | no |
| sre-pipelines-esp-mgmt | internal | main | yes | no |
| sre-idp-gitops | internal | main | no | no |
| sre-tf-dynatrace-management | internal | main | yes | no |
| sre-tf-module-dynatrace-autotagging-rules | internal | main | yes | no |
| sre-tf-module-dynatrace-teams | internal | main | yes | no |
| sre-tf-module-dynatrace-alert-profiles | internal | main | yes | no |
| sre-tf-infra-appregs-groups | internal | main | yes | no |
| archer-design-decisions-docs | internal | main | yes | no |
| sre-tf-module-cosmos-account | internal | main | yes | no |
| cce-nuget-kafka | internal | main | no | no |
| sre-tf-snyk-test-repo | internal | main | no | no |
| sre-tf-module-databricks-workspace | internal | main | yes | no |
| archer-tf-infra-cce | internal | main | no | no |
| cce-core-processor | internal | main | yes | no |
| sre-tf-module-databricks-resources | internal | main | yes | no |
| sre-infra-odp | internal | main | yes | no |
| sre-tf-infra-odp | internal | main | yes | no |
| sre-tf-module-dynatrace-log-processing | internal | main | yes | no |
| sre-odp-proc-migration-test | internal | main | no | no |
| sre-platform-services | internal | main | no | no |
| dxp-web-gitops | internal | main | yes | no |
| sre-odp-gitops | internal | main | yes | no |
| sre-tf-infra-manageddevopspools | internal | main | yes | no |
| datainfra-tf-infra-astronomer | internal | main | no | no |
| datainfra-tf-infra-databricks | internal | main | no | no |
| sre-tf-infra-databricks-odp | internal | main | yes | no |
| sre-temp-nuget-playground | internal | main | no | no |
| sre-platform-docs | internal | main | no | no |
| datainfra-cost-monitoring | internal | main | no | no |
| archer-cce-gitops | internal | main | yes | no |
| sre-helm-charts | internal | main | no | no |
| sre-tf-pre-commit | internal | main | no | no |

---

## 4. Repository Rulesets

### Organization-Level Ruleset: `base-policy`

**ID**: 5464104
**Source**: Eneco (Organization)
**Enforcement**: Active
**Created**: 2025-05-14
**Current User Can Bypass**: Never

#### Rules Applied

```json
{
  "rules": [
    {
      "type": "repository_transfer"
    },
    {
      "type": "repository_visibility",
      "parameters": {
        "public": false,
        "internal": true,
        "private": false
      }
    },
    {
      "type": "repository_name",
      "parameters": {
        "negate": false,
        "pattern": "^[a-z0-9]+(-[a-z0-9]+)*$"
      }
    }
  ]
}
```

**Effect**:
- Repository transfers are blocked
- Only `internal` visibility allowed (no public, no private)
- Repository names must follow kebab-case pattern: `lowercase-with-dashes`

### Enterprise-Level Ruleset: `Repository management limitation`

**ID**: 9218637
**Source**: eneco (Enterprise)
**Enforcement**: Active
**Created**: 2025-10-27
**Updated**: 2025-11-04
**Current User Can Bypass**: Never

#### Rules Applied

```json
{
  "rules": [
    {
      "type": "repository_create"
    },
    {
      "type": "repository_delete"
    },
    {
      "type": "repository_visibility",
      "parameters": {
        "public": false,
        "internal": true,
        "private": false
      }
    },
    {
      "type": "repository_transfer"
    }
  ]
}
```

**Effect**:
- Repository creation is restricted
- Repository deletion is restricted
- Repository transfers are blocked
- Only `internal` visibility allowed

**Observation**: Strong governance via Enterprise policies. No repositories can be created, deleted, or transferred without bypass. Visibility is locked to internal only.

---

## 5. Branch Protection Rules

### Traditional Branch Protection

**Status**: Not configured (all sampled repos return `null`)

Sampled repositories:
- sre-template-tf-module
- sre-challenge
- sre-tf-module-aks
- sre-tf-module-storage-account
- sre-bootstrap-subscription

**Observation**: Organization uses modern **Repository Rulesets** instead of legacy Branch Protection Rules. No branch-level rulesets were found in the sampled repos.

**Recommendation**: Consider adding branch-level rulesets for `main` branch protection (required reviews, status checks, etc.) if not already enforced at Enterprise level.

---

## 6. Organization Secrets & Variables

### Secrets

**Status**: Access Denied

```json
{
  "message": "You must be an org admin or have the actions secrets fine-grained permission.",
  "status": "403"
}
```

### Variables

**Status**: Access Denied

```json
{
  "message": "You must be an org admin or have the actions variables fine-grained permission.",
  "status": "403"
}
```

---

## 7. Webhooks

**Status**: Not Found (404)

Either no org-level webhooks are configured, or access is restricted.

---

## 8. Installed GitHub Apps

**Status**: Not Found (404)

Either no GitHub Apps are installed at org level, or access is restricted.

---

## 9. Audit Log

**Status**: Access Denied

```json
{
  "message": "Must have admin rights to Repository.",
  "status": "403"
}
```

---

## 10. Security Features

### Security Managers

**Status**: Not Found (404)

### Dependabot Alerts (Org-level)

**Status**: Not Found (404)

### Vulnerability Alerts

All 77 repositories return `null` for `has_vulnerability_alerts` field.

**Observation**: Security feature visibility requires elevated permissions or is not enabled at org level.

---

## Security Observations

### Strengths

1. **SAML SSO Enforced** - Members and teams protected by enterprise SSO
2. **100% Internal Visibility** - No public repositories, enforced via rulesets
3. **Repository Naming Convention** - Enforced kebab-case pattern
4. **No Repository Transfers** - Blocked at both org and enterprise level
5. **Repository Lifecycle Control** - Create/delete restricted at enterprise level
6. **Consistent Default Branch** - All repos use `main`
7. **No Forking Allowed** - Prevents code leakage
8. **Template Repos Available** - Standardized repo creation

### Areas for Investigation

1. **Branch Protection**: No traditional branch protection rules found. Verify if branch-level rulesets are configured at Enterprise level.

2. **Security Features Visibility**: Cannot confirm status of:
   - Dependabot alerts
   - Secret scanning
   - Code scanning
   - Advanced security features

3. **Issues Disabled**: All 77 repos have issues disabled. Verify this is intentional (likely using external issue tracker).

4. **Wiki Enabled**: 61 repos have wiki enabled but may not be in use. Consider disabling if not used.

### Potential Gaps

1. **No Branch-Level Rulesets Visible**: Could not verify required reviews, status checks, or merge restrictions at branch level.

2. **Security Feature Status Unknown**: Due to permission limitations, cannot audit Dependabot, secret scanning, or code scanning configurations.

3. **No Audit Log Access**: Cannot review recent security events or configuration changes.

---

## Recommendations

### High Priority

1. **Verify Branch Protection**: Confirm branch-level rulesets (required reviews, status checks) are configured at Enterprise level or implement at Org level.

2. **Enable Security Features Audit**: Request admin access or audit report for:
   - Dependabot alerts configuration
   - Secret scanning status
   - Code scanning (CodeQL) status

3. **SAML Authorization**: To perform complete audit, authorize PAT via SAML SSO to access members and teams.

### Medium Priority

4. **Wiki Cleanup**: Review 61 repos with wiki enabled - disable if not in active use to reduce attack surface.

5. **Inactive Repo Review**: Consider archiving repos with no activity since 2025-09 or earlier (currently 2 repos).

6. **Template Standardization**: Ensure both templates (`sre-template-tf-module`, `sre-template-tf-infra`) include security best practices:
   - Pre-commit hooks
   - CODEOWNERS file
   - Branch protection configuration
   - Security policy (SECURITY.md)

### Low Priority

7. **Issues Strategy**: Document why issues are disabled org-wide (likely using Azure DevOps/Jira). Add README note for clarity.

8. **Repository Metadata**: Add descriptions to repos lacking them for discoverability.

---

## API Access Summary

| Endpoint | Status | Error Code |
|----------|--------|------------|
| `orgs/Eneco` | SUCCESS | - |
| `orgs/Eneco/members` | EMPTY | SAML |
| `orgs/Eneco/teams` | DENIED | 403 |
| `orgs/Eneco/repos` | SUCCESS | - |
| `orgs/Eneco/rulesets` | NOT FOUND | 404 |
| `orgs/Eneco/actions/secrets` | DENIED | 403 |
| `orgs/Eneco/actions/variables` | DENIED | 403 |
| `orgs/Eneco/hooks` | NOT FOUND | 404 |
| `orgs/Eneco/installations` | NOT FOUND | 404 |
| `orgs/Eneco/audit-log` | DENIED | 403 |
| `orgs/Eneco/security-managers` | NOT FOUND | 404 |
| `orgs/Eneco/dependabot/alerts` | NOT FOUND | 404 |
| `repos/Eneco/*/rulesets` | SUCCESS | - |
| `repos/Eneco/*/branches/*/protection` | NULL VALUES | - |

---

## Appendix: Raw API Responses

### Organization Settings (Full)

```json
{
  "login": "Eneco",
  "id": 17332554,
  "node_id": "MDEyOk9yZ2FuaXphdGlvbjE3MzMyNTU0",
  "url": "https://api.github.com/orgs/Eneco",
  "repos_url": "https://api.github.com/orgs/Eneco/repos",
  "events_url": "https://api.github.com/orgs/Eneco/events",
  "hooks_url": "https://api.github.com/orgs/Eneco/hooks",
  "issues_url": "https://api.github.com/orgs/Eneco/issues",
  "members_url": "https://api.github.com/orgs/Eneco/members{/member}",
  "public_members_url": "https://api.github.com/orgs/Eneco/public_members{/member}",
  "avatar_url": "https://avatars.githubusercontent.com/u/17332554?v=4",
  "description": "",
  "name": "Eneco",
  "company": "Eneco",
  "blog": "https://www.eneco.com",
  "location": "Netherlands",
  "email": "FM_Tech_sre_team@eneco.com",
  "twitter_username": null,
  "is_verified": false,
  "has_organization_projects": false,
  "has_repository_projects": false,
  "public_repos": 0,
  "public_gists": 0,
  "followers": 9,
  "following": 0,
  "html_url": "https://github.com/Eneco",
  "created_at": "2016-02-19T08:29:13Z",
  "updated_at": "2025-12-15T13:28:37Z",
  "archived_at": null,
  "type": "Organization"
}
```

---

*End of Audit Report*
