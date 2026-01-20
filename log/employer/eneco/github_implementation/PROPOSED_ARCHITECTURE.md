# GitHub Organization Architecture: Technical Design Document

> **Status**: PROPOSED
> **Version**: 1.0
> **Date**: 2026-01-19
> **Author**: Platform Engineering

---

## Executive Summary

This document proposes an ideal GitHub Enterprise Cloud architecture with maximum developer self-service, zero-friction onboarding/offboarding, and governance through guardrails rather than gates.

**Key Design Decisions**:

| Decision | Choice | Rationale |
|----------|--------|-----------|
| User Model | Public GitHub + SAML SSO | Better DevEx than EMU, external collaboration enabled |
| Provisioning | SCIM from Azure AD | Automatic onboarding/offboarding, IdP as source of truth |
| Repo Creation | Self-service (no PRs) | 60-200x faster TTV, guardrails ensure compliance |
| Team Management | IdP group sync | Eliminates manual membership, audit trail automatic |
| Governance | Org-level rulesets | Policy enforcement without per-repo configuration |

**Target Metrics**:

| Metric | Current | Target |
|--------|---------|--------|
| Time to create repo | 1-10 hours | < 3 minutes |
| Time to team access | Hours/days | < 2 minutes |
| Self-service rate | ~20% | > 85% |
| First-day productivity | Varies | 100% (push code day 1) |

---

## 1. Architecture Overview

### 1.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        IDENTITY LAYER (Source of Truth)                  │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                     Azure AD / Entra ID                          │    │
│  │  • User lifecycle (hire/transfer/terminate)                      │    │
│  │  • Group membership (maps to GitHub teams)                       │    │
│  │  • Role assignments (maps to GitHub permissions)                 │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                    │ SCIM Provisioning          │ SAML SSO              │
│                    │ (automatic sync)           │ (authentication)      │
│                    ▼                            ▼                       │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      GITHUB ENTERPRISE CLOUD                             │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                    Organization: eneco                             │  │
│  │                                                                    │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐               │  │
│  │  │ Org-Level   │  │ Repository  │  │  Custom     │               │  │
│  │  │ Rulesets    │  │ Templates   │  │ Properties  │               │  │
│  │  │ (governance)│  │ (standards) │  │ (metadata)  │               │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘               │  │
│  │                                                                    │  │
│  │  ┌──────────────────────────────────────────────────────────────┐ │  │
│  │  │                        TEAMS                                  │ │  │
│  │  │  (Synced from Azure AD groups via SCIM)                      │ │  │
│  │  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐     │ │  │
│  │  │  │Team Alpha│  │Team Beta │  │Team Gamma│  │ ...      │     │ │  │
│  │  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘     │ │  │
│  │  └──────────────────────────────────────────────────────────────┘ │  │
│  │                                                                    │  │
│  │  ┌──────────────────────────────────────────────────────────────┐ │  │
│  │  │                     REPOSITORIES                              │ │  │
│  │  │  (Created via self-service, governed by org rulesets)        │ │  │
│  │  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐     │ │  │
│  │  │  │ repo-a   │  │ repo-b   │  │ repo-c   │  │ ...      │     │ │  │
│  │  │  │ internal │  │ private  │  │ private  │  │          │     │ │  │
│  │  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘     │ │  │
│  │  └──────────────────────────────────────────────────────────────┘ │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                    SELF-SERVICE LAYER                              │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐               │  │
│  │  │   CLI       │  │   Portal    │  │  Slack Bot  │               │  │
│  │  │  (gh ext)   │  │  (Backstage)│  │ (optional)  │               │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘               │  │
│  │                           │                                        │  │
│  │                           ▼                                        │  │
│  │  ┌─────────────────────────────────────────────────────────────┐  │  │
│  │  │              GitHub Actions (Automation)                     │  │  │
│  │  │  • workflow_dispatch for self-service operations            │  │  │
│  │  │  • Scheduled compliance scans                                │  │  │
│  │  │  • Drift detection and remediation                          │  │  │
│  │  └─────────────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Design Principles

| Principle | Implementation |
|-----------|----------------|
| **Default to Yes** | Tier 1-2 operations auto-approve; denials require justification |
| **Guardrails Over Gates** | Org rulesets enforce policy; no per-repo approval needed |
| **IdP is Truth** | All access derived from Azure AD; no shadow permissions in GitHub |
| **Async is Failure** | Self-service completes in < 3 min; no "wait for approval" |
| **Audit Everything, Approve Little** | Comprehensive logging; approval only for Tier 3 |
| **Undo Over Redo** | Archive before delete; history preserved; easy recovery |

---

## 2. Identity & Access Management

### 2.1 Authentication: SAML SSO with Public GitHub Accounts

**Why Public GitHub (not EMU)**:

| Aspect | Public GitHub + SAML | EMU |
|--------|---------------------|-----|
| External collaboration | Full support | Very limited |
| Developer familiarity | Use existing account | New managed account |
| Personal repos/contributions | Allowed | Not allowed |
| OSS contribution | Seamless | Separate account needed |
| User experience | Familiar | Restrictive |

**Configuration**:

```yaml
# Organization SAML Settings
authentication:
  type: saml_sso
  identity_provider: azure_ad
  require_sso: true  # All members must authenticate via SSO

  # Session settings
  session_timeout: 12h
  require_2fa: true  # Enforce 2FA for all members
```

### 2.2 Provisioning: SCIM from Azure AD

**Automatic Lifecycle Management**:

```
ONBOARDING FLOW (Zero Touch)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. New employee added to Azure AD
   └─► Added to relevant AD groups (by HR/Manager)

2. SCIM sync triggers (real-time)
   └─► GitHub receives provisioning event

3. GitHub creates/links user account
   └─► User invited to org (if new) or activated (if existing)

4. Team membership synced from AD groups
   └─► User automatically added to mapped GitHub teams

5. User receives notification
   └─► Can access repos immediately via SSO

ELAPSED TIME: < 15 minutes (typically < 5 minutes)
MANUAL STEPS: 0


OFFBOARDING FLOW (Zero Touch)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Employee terminated in Azure AD
   └─► AD account disabled/deleted

2. SCIM sync triggers (real-time)
   └─► GitHub receives deprovisioning event

3. GitHub suspends user
   └─► Removed from all teams
   └─► Access to all repos revoked
   └─► SSO sessions invalidated

4. Audit log entry created
   └─► "User suspended via SCIM"

ELAPSED TIME: < 15 minutes
MANUAL STEPS: 0
DATA RETAINED: User's contributions preserved (commits, issues, PRs)
```

### 2.3 Team Synchronization

**Azure AD Group → GitHub Team Mapping**:

```yaml
# Team sync configuration (conceptual)
team_sync:
  enabled: true
  identity_provider: azure_ad

  mappings:
    # AD Group → GitHub Team
    - ad_group: "GRP-Engineering-Platform"
      github_team: "platform-engineering"
      role: maintainer

    - ad_group: "GRP-Engineering-Frontend"
      github_team: "frontend"
      role: member

    - ad_group: "GRP-Engineering-Backend"
      github_team: "backend"
      role: member

    # Nested teams supported
    - ad_group: "GRP-Engineering-All"
      github_team: "engineering"
      role: member
      children:
        - platform-engineering
        - frontend
        - backend
```

**Sync Behavior**:

| Event | GitHub Action |
|-------|---------------|
| User added to AD group | Added to mapped GitHub team |
| User removed from AD group | Removed from mapped GitHub team |
| AD group deleted | GitHub team membership cleared (team preserved) |
| AD group renamed | No change (linked by ID, not name) |

---

## 3. Repository Self-Service

### 3.1 Self-Service Tiers

```
TIER 1: FULLY AUTOMATED (< 3 minutes)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
No human approval required. Guardrails enforce compliance.

✓ Create repository (from template)
✓ Add user to team (if IdP-synced)
✓ Enable GHAS features
✓ Create/update topics and labels
✓ Configure webhooks

TIER 2: AUTO-APPROVE + AUDIT (< 5 minutes)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Completes automatically. Audit entry for governance.

✓ Create new team
✓ Modify branch protection (within policy)
✓ Transfer repository (within org)
✓ Change repository visibility (private → internal)

TIER 3: REQUIRES APPROVAL (< 4 hours SLO)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Security-sensitive. Requires explicit approval.

✓ Archive/delete repository
✓ Branch protection exceptions
✓ External collaborator admin access
✓ Disable security features
✓ Change visibility (private → public)
```

### 3.2 Repository Creation Flow

**Self-Service Interface Options**:

```bash
# Option A: GitHub CLI Extension
gh repo create eneco/my-new-service \
  --template service-template-go \
  --team backend \
  --visibility internal

# Option B: workflow_dispatch via GitHub Actions
# Triggered via GitHub UI or API
curl -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/eneco/platform-automation/dispatches \
  -d '{"event_type": "create-repo", "client_payload": {
    "name": "my-new-service",
    "template": "service-template-go",
    "team": "backend",
    "visibility": "internal"
  }}'

# Option C: Backstage / Developer Portal
# Form-based UI that triggers the same workflow
```

**Automation Workflow**:

```yaml
# .github/workflows/create-repository.yml
name: Create Repository (Self-Service)

on:
  workflow_dispatch:
    inputs:
      name:
        description: 'Repository name'
        required: true
        type: string
      template:
        description: 'Template to use'
        required: true
        type: choice
        options:
          - service-template-go
          - service-template-python
          - service-template-typescript
          - library-template
          - documentation-template
      team:
        description: 'Owning team'
        required: true
        type: string
      visibility:
        description: 'Repository visibility'
        required: true
        type: choice
        options:
          - internal
          - private

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - name: Validate naming convention
        run: |
          if [[ ! "${{ inputs.name }}" =~ ^[a-z][a-z0-9-]*$ ]]; then
            echo "::error::Repository name must be lowercase alphanumeric with hyphens"
            exit 1
          fi

      - name: Validate team exists
        env:
          GH_TOKEN: ${{ secrets.ORG_ADMIN_TOKEN }}
        run: |
          gh api orgs/eneco/teams/${{ inputs.team }} || {
            echo "::error::Team '${{ inputs.team }}' not found"
            exit 1
          }

  create:
    needs: validate
    runs-on: ubuntu-latest
    steps:
      - name: Create repository from template
        env:
          GH_TOKEN: ${{ secrets.ORG_ADMIN_TOKEN }}
        run: |
          gh repo create eneco/${{ inputs.name }} \
            --template eneco/${{ inputs.template }} \
            --${{ inputs.visibility }} \
            --confirm

      - name: Assign team ownership
        env:
          GH_TOKEN: ${{ secrets.ORG_ADMIN_TOKEN }}
        run: |
          gh api -X PUT \
            orgs/eneco/teams/${{ inputs.team }}/repos/eneco/${{ inputs.name }} \
            -f permission=push

      - name: Set custom properties
        env:
          GH_TOKEN: ${{ secrets.ORG_ADMIN_TOKEN }}
        run: |
          gh api -X PATCH repos/eneco/${{ inputs.name }}/properties/values \
            --input - << EOF
          {
            "properties": [
              {"property_name": "owning-team", "value": "${{ inputs.team }}"},
              {"property_name": "created-via", "value": "self-service"},
              {"property_name": "created-by", "value": "${{ github.actor }}"}
            ]
          }
          EOF

      - name: Notify requestor
        run: |
          echo "::notice::Repository created: https://github.com/eneco/${{ inputs.name }}"
          # Could also send Slack notification, email, etc.
```

### 3.3 Repository Templates

**Template Structure**:

```
eneco/service-template-go/
├── .github/
│   ├── workflows/
│   │   ├── ci.yml           # Standard CI pipeline
│   │   ├── release.yml      # Semantic release
│   │   └── security.yml     # GHAS scanning
│   ├── CODEOWNERS           # Team-based ownership
│   └── pull_request_template.md
├── src/                     # Application code structure
├── Dockerfile               # Standard container build
├── Makefile                 # Common tasks
├── README.md                # With placeholders
└── .gitignore
```

**Templates Available**:

| Template | Use Case | Includes |
|----------|----------|----------|
| `service-template-go` | Go microservices | CI, Docker, K8s manifests |
| `service-template-python` | Python services | CI, Poetry, Docker |
| `service-template-typescript` | Node.js services | CI, npm, Docker |
| `library-template` | Shared libraries | CI, semantic release |
| `documentation-template` | Docs sites | MkDocs, GitHub Pages |
| `terraform-module-template` | IaC modules | CI, tests, docs gen |

---

## 4. Governance Without Friction

### 4.1 Organization-Level Rulesets

**Replace per-repo branch protection with org-wide rules**:

```yaml
# Conceptual ruleset configuration
# Applied automatically to all matching repositories

ruleset:
  name: "Production Branch Protection"
  target: branch
  enforcement: active

  # Apply to all repos with property: environment=production
  conditions:
    repository_property:
      include:
        - property: environment
          values: [production]

  # Target branches
  ref_name:
    include:
      - "~DEFAULT_BRANCH"  # main/master
      - "refs/heads/release/*"

  rules:
    # Require pull request
    - type: pull_request
      parameters:
        required_approving_review_count: 1
        dismiss_stale_reviews_on_push: true
        require_code_owner_review: true
        require_last_push_approval: true

    # Require status checks
    - type: required_status_checks
      parameters:
        strict_required_status_checks_policy: true
        required_status_checks:
          - context: "ci / build"
          - context: "ci / test"
          - context: "security / ghas"

    # Prevent force push
    - type: non_fast_forward

    # Require signed commits
    - type: required_signatures

---

ruleset:
  name: "Default Repository Rules"
  target: branch
  enforcement: active

  # Apply to ALL repositories
  conditions:
    repository_property:
      include:
        - property: "*"  # All repos

  ref_name:
    include:
      - "~DEFAULT_BRANCH"

  rules:
    # Minimum protection for all repos
    - type: pull_request
      parameters:
        required_approving_review_count: 1

    - type: non_fast_forward
```

### 4.2 Custom Properties for Classification

```yaml
# Organization custom properties

properties:
  - name: owning-team
    description: "Team responsible for this repository"
    type: single_select
    required: true
    allowed_values:
      - platform-engineering
      - frontend
      - backend
      - data
      - sre

  - name: environment
    description: "Deployment environment classification"
    type: single_select
    required: true
    allowed_values:
      - production
      - staging
      - development
      - sandbox

  - name: data-classification
    description: "Data sensitivity level"
    type: single_select
    required: true
    allowed_values:
      - public
      - internal
      - confidential
      - restricted

  - name: compliance-scope
    description: "Regulatory compliance requirements"
    type: multi_select
    required: false
    allowed_values:
      - gdpr
      - pci-dss
      - sox
      - none
```

**Property-Based Ruleset Targeting**:

```yaml
# Stricter rules for production + confidential data
ruleset:
  name: "High Security Requirements"
  conditions:
    repository_property:
      include:
        - property: environment
          values: [production]
        - property: data-classification
          values: [confidential, restricted]

  rules:
    - type: pull_request
      parameters:
        required_approving_review_count: 2  # More reviewers
        require_code_owner_review: true

    - type: required_status_checks
      parameters:
        required_status_checks:
          - context: "security / sast"
          - context: "security / secret-scan"
          - context: "security / dependency-review"
```

### 4.3 GitHub Advanced Security (GHAS)

**Auto-Enable for All Repositories**:

```yaml
# Organization security settings
security:
  # Enable by default for all new repos
  advanced_security:
    enabled_for_new_repositories: true

  secret_scanning:
    enabled_for_new_repositories: true
    push_protection: true  # Block commits with secrets

  dependabot:
    alerts: true
    security_updates: true

  code_scanning:
    default_setup: true  # CodeQL auto-configured
```

---

## 5. Compliance & Audit

### 5.1 Audit Log Integration

```yaml
# Stream audit logs to SIEM
audit_log:
  streaming:
    enabled: true
    endpoint: "https://siem.eneco.nl/github-audit"

  # Events to capture
  events:
    - repo.create
    - repo.destroy
    - team.add_member
    - team.remove_member
    - org.invite_member
    - org.remove_member
    - protected_branch.policy_override
    - repository_ruleset.create
    - repository_ruleset.update
```

### 5.2 Compliance Dashboard

**Automated Compliance Checks**:

```yaml
# .github/workflows/compliance-scan.yml
name: Compliance Scan

on:
  schedule:
    - cron: '0 6 * * *'  # Daily at 6 AM
  workflow_dispatch:

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - name: Check all repos for compliance
        env:
          GH_TOKEN: ${{ secrets.ORG_ADMIN_TOKEN }}
        run: |
          gh api graphql -f query='
            query {
              organization(login: "eneco") {
                repositories(first: 100) {
                  nodes {
                    name
                    branchProtectionRules(first: 1) {
                      nodes {
                        requiresApprovingReviews
                        requiredApprovingReviewCount
                      }
                    }
                    securityPolicyUrl
                    hasVulnerabilityAlertsEnabled
                  }
                }
              }
            }
          ' | jq '.data.organization.repositories.nodes[] |
            select(.branchProtectionRules.nodes | length == 0) |
            .name' > non_compliant_repos.txt

          if [ -s non_compliant_repos.txt ]; then
            echo "::warning::Non-compliant repositories found"
            cat non_compliant_repos.txt
          fi
```

---

## 6. Migration Strategy

### 6.1 Migration Phases

```
PHASE 1: FOUNDATION (Week 1-2)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Objective: Enable SCIM + SSO, establish org-level governance

Tasks:
├─ Configure SCIM provisioning from Azure AD
├─ Enable SAML SSO (require for all members)
├─ Create org-level rulesets (replace per-repo protection)
├─ Define custom properties schema
├─ Create initial repository templates

Success Criteria:
✓ New users auto-provisioned via SCIM
✓ All members authenticated via SSO
✓ Org rulesets enforcing baseline protection


PHASE 2: SELF-SERVICE (Week 3-4)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Objective: Enable Tier 1 self-service, eliminate PR bottleneck

Tasks:
├─ Deploy repository creation workflow
├─ Create CLI extension or portal integration
├─ Document self-service process
├─ Train teams on new workflow
├─ Sunset PR-based repo creation

Success Criteria:
✓ P95 repo creation < 3 minutes
✓ 0 PRs for Tier 1 operations
✓ > 50% adoption in first week


PHASE 3: TEAM SYNC (Week 5-6)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Objective: Full IdP-based team management

Tasks:
├─ Map Azure AD groups to GitHub teams
├─ Enable team sync for all teams
├─ Migrate existing manual memberships
├─ Remove Terraform team management
├─ Implement team creation self-service

Success Criteria:
✓ 100% team membership from IdP
✓ < 15 min sync latency
✓ Offboarding < 15 min revocation


PHASE 4: COMPLIANCE AUTOMATION (Week 7-8)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Objective: Automated compliance and drift detection

Tasks:
├─ Deploy compliance scanning workflows
├─ Enable auto-remediation for drift
├─ Create compliance dashboard
├─ Integrate audit logs with SIEM
├─ Document exception process (Tier 3)

Success Criteria:
✓ 100% repos compliant with baseline
✓ < 1% drift month-over-month
✓ Audit trail 100% complete
```

### 6.2 Deprecation of Current Terraform Approach

**What Changes**:

| Current (Terraform) | Future (Self-Service) |
|---------------------|----------------------|
| YAML file + PR + TF apply | workflow_dispatch (< 3 min) |
| Manual team YAML edits | IdP group sync (automatic) |
| Per-repo branch protection in TF | Org-level rulesets |
| TF state for repo config | GitHub native + properties |

**What Remains (Terraform Still Useful For)**:

- Organization settings (one-time setup)
- GitHub App configuration
- Webhook configurations
- Enterprise-level settings
- Backup/disaster recovery (export org state)

**Migration Path for Existing Repos**:

```bash
# One-time migration script
# Apply custom properties to existing repos
for repo in $(gh repo list eneco --json name -q '.[].name'); do
  gh api -X PATCH repos/eneco/$repo/properties/values \
    --input - << EOF
  {
    "properties": [
      {"property_name": "migrated-from", "value": "terraform"},
      {"property_name": "environment", "value": "production"}
    ]
  }
EOF
done
```

---

## 7. Success Metrics

### 7.1 Developer Experience Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Time to create repo (P95) | < 3 min | workflow timestamps |
| Time to team access (P95) | < 2 min | SCIM sync logs |
| Self-service rate | > 85% | Tier 1+2 / total ops |
| First-day productivity | 100% | New hire surveys |
| Developer satisfaction (NPS) | > 50 | Quarterly surveys |

### 7.2 Platform Health Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Guardrail compliance | 100% | Daily compliance scan |
| Policy drift | < 1%/month | Drift detection workflow |
| Audit coverage | 100% | Audit log completeness |
| Tier 3 SLO adherence | 95% | Request queue monitoring |
| SCIM sync latency (P95) | < 15 min | Azure AD sync logs |

### 7.3 Security Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| GHAS coverage | 100% repos | GitHub security dashboard |
| Secret scan alerts (P95 resolution) | < 24 hours | Alert age tracking |
| Dependency alerts (P95 resolution) | < 7 days | Alert age tracking |
| Branch protection coverage | 100% | Compliance scan |

---

## 8. Appendix

### 8.1 Comparison: Current vs Proposed

| Capability | Current (SRE Terraform) | Proposed (Self-Service) |
|------------|------------------------|-------------------------|
| Repo creation | PR → Review → TF (hours) | workflow_dispatch (minutes) |
| Team membership | YAML edit → PR → TF | IdP sync (automatic) |
| Branch protection | Per-repo TF resource | Org ruleset (automatic) |
| User onboarding | Manual invite | SCIM (automatic) |
| User offboarding | Manual removal | SCIM (automatic) |
| Compliance | Manual audit | Automated scanning |
| Governance | PR review | Guardrails + audit |

### 8.2 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Self-service abuse | Low | Medium | Audit trail, rate limits, property-based targeting |
| SCIM sync failures | Low | High | Monitoring, manual fallback, retry logic |
| Ruleset misconfiguration | Low | High | Staged rollout, test org, change review |
| Template drift | Medium | Low | Template version pinning, update notifications |

### 8.3 Decision Log

| Decision | Choice | Alternatives Considered | Rationale |
|----------|--------|------------------------|-----------|
| User model | Public GH + SAML | EMU | Better DevEx, external collab |
| Self-service mechanism | workflow_dispatch | Backstage, custom portal | Native GitHub, no extra infra |
| Team management | IdP sync | Terraform, manual | Eliminates drift, automatic lifecycle |
| Governance | Org rulesets | Per-repo TF | Scales, no per-repo management |

---

## 9. References

- [GitHub SCIM Provisioning](https://docs.github.com/en/enterprise-cloud@latest/admin/identity-and-access-management/provisioning-user-accounts-for-enterprise-managed-users/configuring-scim-provisioning-for-enterprise-managed-users)
- [GitHub Repository Rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)
- [GitHub Custom Properties](https://docs.github.com/en/organizations/managing-organization-settings/managing-custom-properties-for-repositories-in-your-organization)
- [GitHub Team Sync](https://docs.github.com/en/enterprise-cloud@latest/admin/identity-and-access-management/using-saml-for-enterprise-iam/managing-team-synchronization-for-organizations-in-your-enterprise)
- [Backstage GitHub Integration](https://backstage.io/docs/integrations/github/locations)

---

*Document generated: 2026-01-19*
*Next review: After Phase 1 completion*
