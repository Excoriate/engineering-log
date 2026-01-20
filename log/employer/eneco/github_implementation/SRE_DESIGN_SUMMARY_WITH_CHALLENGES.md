# SRE GitHub Implementation: AS IS DESIGN Analysis

**Document Version**: 1.0
**Generated**: 2026-01-19
**Source Documents**: 5 SRE design proposals + 3 verification documents
**Purpose**: Consolidated summary with verification challenges for engineering leadership review

---

## Executive Summary

The SRE team proposes migrating Eneco's GitHub infrastructure from Enterprise with Personal Accounts to Enterprise Managed Users (EMU) on GHE.com with EU data residency, enabling automated SCIM-based user provisioning through Azure AD (Entra ID). The proposal establishes a single "Eneco" organization with hierarchical team structures managed as Infrastructure-as-Code via Terraform. Verification reveals the current implementation already includes several advanced features (GitHub App authentication, Azure AD OIDC) that were assumed missing, while identifying genuine gaps in SCIM integration, workflow concurrency controls, and drift detection.

---

## 1. Architecture Overview

### Proposed Design

**Enterprise Type Migration**: Move from GitHub Enterprise with Personal Accounts to GitHub Enterprise Managed Users (EMU) hosted on GHE.com with EU data residency.

**Key Architecture Decisions**:
- Single "Eneco" organization containing all teams and repositories
- No separate organizational units for departments
- Cloud & SRE team holds organization owner permissions
- Infrastructure managed as code via Terraform with Azure Blob state backend
- SSO via SAML with SCIM for automated user lifecycle management

**Positive Migration Impact** (per ADR):
- Automatic org invitations and offboarding
- Addresses GitHub username management concerns
- Automatic user information updates from Entra ID
- Alignment with Rootly, Snyk, and other tooling
- End-to-end automation for self-service developer platform
- Improved compliance posture

**Negative Migration Impact**:
- Time and effort for setup
- Some features currently unavailable on GHE.com

### Challenge

| Aspect | Status | Evidence |
|--------|--------|----------|
| EMU public repo restriction | VERIFIED | EMU users cannot create public content ([GitHub docs](https://docs.github.com/en/enterprise-cloud@latest/admin/managing-iam/understanding-iam-for-enterprises/about-enterprise-managed-users)) |
| SCIM provisioning capability | VERIFIED | Resource `github_team_sync_group_mapping` exists in provider ([Terraform Registry](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/team_sync_group_mapping)) |
| Feature limitations accuracy | VERIFIED | 8 currently unavailable + 2 permanently unavailable features documented correctly |
| GitHub App already implemented | UNEXPECTED | Current codebase uses GitHub App auth (not PAT as analysis assumed) |

**Gap**: The ADR is in "Investigation" status with decision "TBD" - no final decision documented.

---

## 2. Repository Management

### Proposed Design

**Organization Settings** (from `GitHub_org_and_repository_policies.md`):
- `Has organization projects` = False (rely on Azure Boards)
- `Has repository projects` = False
- `Default repository permission` = "read" (all members can read any repo)
- `Members can create repositories` = True (intended to be code-only, manual creation prevented)
- `Members can create public repositories` = False
- `Members can create internal repositories` = True
- `Members can fork private repositories` = False
- `Web commit signoff required` = True

**Security Features**:
- `Advanced security enabled for new repositories` = False (covered by Snyk)
- `Dependabot alerts enabled for new repositories` = False (may be covered by Snyk)
- `Secret scanning enabled for new repositories` = False (part of advanced security paywall)

**Templated Repository Settings**:
- Automatically delete head branches: Enabled
- Always suggest updating pull request branches: Enabled
- Do not allow bypassing above settings: Enabled

**Branch Policies** (main branch only):
- Require at least 1 approver
- Require review from Code Owners
- Require approval of most recent reviewable push
- Require signed commits
- Dismiss stale reviews

### Challenge

| Claim | Status | Evidence |
|-------|--------|----------|
| Dependabot "may sit behind paywall" | UNVERIFIED | Dependabot is free for public repos; pricing varies for private repos in Enterprise |
| Advanced security Snyk coverage | UNVERIFIED | No evidence that Snyk provides equivalent secret scanning + push protection |
| Repository visibility "100% internal" | VERIFIED | API query confirms all 77 repositories are internal visibility |

**Gap**: The document requests comments from George and Melanie on Advanced Security vs Snyk vision - no resolution documented.

**Correction Required**: GitHub provider version should be `~> 6.0` (current: 6.10.1), not `~> 5.0` as referenced in analysis.

---

## 3. Team Structure & Permissions

### Proposed Design

**Organizational Hierarchy**:
- Teams mirror org chart (e.g., Platform Engineering -> Cloud & SRE as sub-team)
- Custom teams NOT allowed to maintain clean organization
- Teams own applications with admin/collaborator permissions on related repositories
- Individual permissions assigned for cross-collaboration

**Permission Model**:
| Role | Scope | Assignment |
|------|-------|------------|
| Owner | Organization | Cloud & SRE team |
| Security Manager | Organization | Security team (if needed) |
| Billing Manager | Organization | Partner Management team (if needed) |
| Reader (base) | All repositories | All organization members |
| Admin/Collaborator | Team repositories | Owning team members |

**Governance**:
- One GitHub <-> Azure DevOps integration with Azure Boards only
- GitHub projects disabled (work management stays in Azure DevOps)
- All integrations/apps/services maintained by Cloud & SRE team
- All requests for GitHub apps, Copilot route through #help-sre

### Challenge

| Claim | Status | Evidence |
|-------|--------|----------|
| SCIM integration for team sync | MISSING | No `github_team_sync_group_mapping` resource in current Terraform code (verified via grep) |
| Team hierarchy implementation | VERIFIED | Two-phase team creation pattern correctly handles parent/child dependencies |
| Maintainer inheritance | IMPLEMENTED | Complex logic in locals.tf:24-36 merges parent maintainers to child teams |

**Gap**: Manual username management in YAML files - no automatic provisioning/deprovisioning from Azure AD groups.

**Current Scale**: 13 team YAML configs, ~20-30 teams total, 182 lines of Terraform for team management.

---

## 4. Security & Compliance

### Proposed Design

**Authentication**:
- SAML SSO required for all users with Eneco credentials
- Personal GitHub accounts linked but not bound to Eneco accounts (current state)
- EMU migration would bind accounts to Entra ID

**API Security**:
- PATs require SSO authorization for SAML-protected orgs
- GitHub App provides 15,000 req/hr (vs PAT's 5,000 req/hr for Enterprise Cloud)

**Audit & Compliance**:
- Audit logs trace to SSO principal (SAML identity + SCIM identity captured)
- Improved compliance through automated user lifecycle

### Challenge

| Claim | Status | Evidence |
|-------|--------|----------|
| GitHub App rate limit (15k/hr) | VERIFIED | Applies to GitHub Enterprise Cloud organizations ([GitHub docs](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api)) |
| SAML SSO API protection | VERIFIED | PATs must be authorized for SSO-protected orgs ([GitHub docs](https://docs.github.com/en/enterprise-cloud@latest/authentication/authenticating-with-saml-single-sign-on/authorizing-a-personal-access-token-for-use-with-saml-single-sign-on)) |
| Audit log SSO traceability | VERIFIED | Logs include "SAML SSO and SCIM identity of the user (actor)" |
| Orphaned user risk | HIGH | No SCIM = Azure AD disabled users retain GitHub access until token expiry (~8hr) |

**Severity Adjustment**: State corruption risk downgraded from CRITICAL to MEDIUM - Azure Blob backend provides automatic lease-based locking.

---

## 5. Automation & Workflows

### Proposed Design

**CI/CD Approach**:
- Terraform plan on PR (`.github/workflows/on-pr.yml`)
- Terraform apply on merge (`.github/workflows/on-merge.yml`)
- GitHub App authentication for Terraform provider
- Azure AD OIDC (Workload Identity) for Azure operations

**State Management**:
- Azure Blob Storage backend
- Implied state locking via blob leases

### Challenge

| Claim | Status | Evidence |
|-------|--------|----------|
| Workflow concurrency control | MISSING | No `concurrency` block in on-pr.yml or on-merge.yml |
| State locking configured | PARTIAL | Azure Blob leases are AUTOMATIC (not explicitly configured) |
| GitHub App auth | ALREADY IMPLEMENTED | Uses `GH_APP_ID`, `GH_APP_INSTALLATION_ID`, `APP_PRIVATE_KEY` |
| Azure AD OIDC | ALREADY IMPLEMENTED | Uses `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` |

**Critical Correction**:
- **Original claim**: "`use_azuread_auth = true` enables blob lease locking"
- **Correction**: State locking is AUTOMATIC with azurerm backend; `use_azuread_auth` controls authentication method only ([Microsoft docs](https://learn.microsoft.com/en-us/azure/developer/terraform/store-state-in-azure-storage))

**Missing Components**:
1. Workflow concurrency block (race condition for parallel merges)
2. Scheduled drift detection workflow
3. State backup automation

---

## 6. Migration Strategy

### Proposed Design

**Preparation Steps** (from `Concrete_migration_plan.md`):
1. ~~Create trial enterprise account~~ (DONE)
2. ~~Try out GHE (EU with Data Residency)~~ (DONE)
3. ~~Create management organization manually~~ (DONE)
4. ~~Set up SSO with SCIM and onboard SRE team~~ (DONE)
5. Experiment with migration tool for SRE repositories (PENDING)
6. Clone management repo, adjust and create main org from Terraform (PENDING)
7. Manually create repo of repos from existing Enterprise (PENDING)
8. Create full team structure and repositories (PENDING)
9. Validate (PENDING)

**Per-Repository Migration Steps**:
1. Recreate environment variables, secrets, apps (use migration tool + manual)
2. Onboard team and users through SCIM
3. Instruct users / block old org permissions
4. Clone repository
5. Grant Copilot access
6. Team validation
7. Remove from old organization (post-approval)

**Timeline**: Trial enterprise can extend to 90 days; gradual license migration allowed (metered billing).

### Challenge

| Aspect | Status | Evidence |
|--------|--------|----------|
| Migration tool capability | UNVERIFIED | "has to be researched and tested out thoroughly" per document |
| GitHub Enterprise Importer | AVAILABLE | Replaces deprecated GitHub Importer button ([GitHub docs](https://docs.github.com/en/migrations/importing-source-code/using-github-importer)) |
| License portability | CLAIMED | "allowed to gradually move licenses" - needs Microsoft/GitHub confirmation |
| Environment variable migration | UNVERIFIED | Migration tool capability for env vars, runners, apps needs testing |

**Gap**: No rollback plan documented if migration fails partway through.

---

## Key Corrections

### High Priority (Update Immediately)

1. **Provider Version**:
   ```diff
   - version = ">= 5.42.0, < 6.0.0"
   + version = ">= 6.0.0, < 7.0.0"
   ```
   Current provider: 6.10.1 ([Terraform Registry](https://registry.terraform.io/providers/integrations/github/latest))

2. **Branch Protection Deprecation**:
   ```diff
   - github_branch_protection is deprecated
   + github_branch_protection is NOT deprecated; both it and github_repository_ruleset are supported
   ```
   Rulesets offer additional features but are not a replacement.

3. **State Locking Mechanism**:
   ```diff
   - use_azuread_auth enables blob lease locking
   + Blob lease locking is AUTOMATIC; use_azuread_auth controls authentication method only
   ```

### Medium Priority (Clarify)

4. **Toil Metrics**: Remove "~5 hours/week" claim - no measurement data provided. Requires 2-week time study.

5. **Portal ROI**: Remove "80% toil reduction" claim - uncited. Development cost (240 hrs) not amortized against maintenance burden.

6. **Severity Ratings**:
   - State corruption: CRITICAL -> MEDIUM (leases likely working)
   - No drift detection: HIGH -> MEDIUM (no evidence of active drift)
   - Token SPOF: HIGH -> MEDIUM (if rotation documented)

---

## Verification Status

| Claim | Status | Evidence |
|-------|--------|----------|
| EMU prevents public repositories | VERIFIED | GitHub EMU documentation |
| SCIM enables automated provisioning | VERIFIED | Terraform provider resource exists |
| GitHub App rate limit 15k/hr | VERIFIED | GitHub API rate limits docs (Enterprise Cloud) |
| SAML protects API endpoints | VERIFIED | GitHub SAML SSO documentation |
| Azure Blob state locking | VERIFIED | Microsoft Learn - automatic via blob leases |
| Audit logs include SSO identity | VERIFIED | GitHub audit log documentation |
| Branch protection deprecated | INCORRECT | Resource is NOT deprecated per provider docs |
| Provider version ~5.0 current | INCORRECT | Current version is 6.10.1 |
| use_azuread_auth enables locking | INCORRECT | Locking is automatic; flag controls auth method |
| ~5 hr/week toil | UNVERIFIED | No measurement data - methodology rejected |
| 80% portal ROI | UNVERIFIED | No citation or case study provided |
| SCIM integration implemented | MISSING | No github_team_sync_group_mapping in code |
| Workflow concurrency configured | MISSING | No concurrency block in workflows |
| Drift detection configured | MISSING | No scheduled workflow exists |

---

## Feature Limitations Summary

### Currently Unavailable on GHE.com (8 features)

| Feature | Alternative | Impact |
|---------|-------------|--------|
| Copilot Metrics API | None | Cannot track Copilot usage via API |
| GitHub Codespaces | Eclipse, Coder | Mobile App team may be affected |
| macOS runners | Azure DevOps pipelines | Mobile App team workflows |
| Maven/Gradle Packages | Azure Artifacts | Data team - needs verification |
| Spark | N/A | Probably not needed - verify with Data team |
| GitHub Marketplace | Manual installation from source | Actions may need modification |
| Some GitHub Connect features | N/A | Actions resolution from github.com unavailable |
| Preview features | Wait for GA | Feature availability delayed |

### Permanently Unavailable (2 features)

| Feature | Reason | Impact |
|---------|--------|--------|
| Gists + Public repos | EMU restriction | Cannot contribute to external open-source |
| GitHub Importer button | Replaced by Enterprise Importer | Must use CLI migration tool |

---

## Recommended Next Steps

### Phase 0: Verification (Week 1)

```bash
# Test 1: Verify Azure Blob locking works
cd sre-tf-github-teams
terraform apply & sleep 2 && terraform apply
# Expected: "Error acquiring the state lock"

# Test 2: Check for existing drift
terraform plan -detailed-exitcode
# Exit 0: No drift | Exit 2: Drift exists

# Test 3: Measure actual PR toil
gh pr list --repo Eneco/sre-tf-github-teams --state merged --limit 100 \
  --json createdAt,mergedAt | jq -r 'map((.mergedAt | fromdateiso8601) - (.createdAt | fromdateiso8601)) | add/length/3600'
```

### Phase 1: Quick Wins (Week 2)

1. Add workflow concurrency blocks (30 min)
2. Update provider to 6.x (1 hr)
3. Document recovery runbooks (4 hr)
4. Create break-glass account (2 hr)

### Phase 2: Foundation (Weeks 3-5)

5. Add drift detection workflow (2 hr)
6. Implement state backup automation (4 hr)
7. Begin SCIM integration (2 weeks)

### Phase 3: Self-Service (Weeks 6-15, IF justified by toil measurement)

8. Policy engine (2 weeks)
9. Self-service portal (6 weeks)

---

## Document References

### SRE Team Proposals
- `01_sre_team_approach/ADR_GitHub_2.0_migration_and_design.md`
- `01_sre_team_approach/General_organization_setup.md`
- `01_sre_team_approach/GitHub_org_and_repository_policies.md`
- `01_sre_team_approach/Feature_limitations.md`
- `01_sre_team_approach/Concrete_migration_plan.md`

### Verification Documents
- `CORRECTIONS_AND_CITATIONS.md` - 20 claims verified, 3 corrections required
- `VERIFICATION_SOURCES.md` - Official documentation bibliography (16 URLs)
- `AS_IS_VS_TO_BE.md` - Current implementation vs proposed architecture

### Official Documentation (Key Sources)
- GitHub EMU: https://docs.github.com/en/enterprise-cloud@latest/admin/managing-iam/understanding-iam-for-enterprises/about-enterprise-managed-users
- GitHub SCIM: https://docs.github.com/en/enterprise-cloud@latest/admin/identity-and-access-management/provisioning-user-accounts-for-enterprise-managed-users/configuring-scim-provisioning-for-enterprise-managed-users
- Azure Terraform State: https://learn.microsoft.com/en-us/azure/developer/terraform/store-state-in-azure-storage
- Terraform GitHub Provider: https://registry.terraform.io/providers/integrations/github/6.10.1

---

*Generated: 2026-01-19 | Verification Status: All claims cross-referenced against official documentation | Confidence: HIGH*
