# SRE Operational Readiness Review: Eneco GitHub Implementation

**Review Date**: 2026-01-19  
**Reviewer**: Alex Torres (Excoriate)  
**Review Type**: Production Reliability & Operational Excellence  
**Verdict**: **FIX FIRST** - Critical operational gaps require remediation before scale

---

## Executive Summary

| Metric | Assessment |
|--------|------------|
| **Overall Readiness** | 65/100 - Functional but operationally fragile |
| **Highest Severity Issue** | State corruption risk from concurrent applies |
| **Toil Score** | ~4-6 hours/week manual intervention |
| **MTTR Estimate** | 30min-4hr depending on failure mode |
| **Blast Radius** | 77 repos, 12+ teams, 50+ users at risk per incident |

### Top 3 Operational Risks

1. **CRITICAL**: No visible state locking - concurrent PR merges can corrupt Terraform state
2. **HIGH**: No drift detection - manual GitHub changes create silent divergence
3. **HIGH**: Single point of failure on GitHub App token - expiration breaks ALL automation

---

## 1. Failure Mode Analysis

### 1.1 State Corruption Scenarios

#### FM-001: Concurrent Terraform Applies (CRITICAL)

**Severity**: CRITICAL  
**Likelihood**: MEDIUM (occurs when 2 PRs merge within seconds)  
**MTTR**: 2-4 hours

**Mechanism**:
```
Timeline:
T+0s:  PR-A merges, triggers workflow A
T+2s:  PR-B merges, triggers workflow B
T+5s:  Workflow A: terraform init (acquires state)
T+7s:  Workflow B: terraform init (acquires state)
T+10s: Workflow A: terraform apply (writes state v1)
T+12s: Workflow B: terraform apply (OVERWRITES with stale state)
Result: Changes from PR-A are lost, state is corrupted
```

**Evidence**: 
- Backend config (`backend.tf:1-9`) uses Azure Blob with `snapshot = true`
- NO explicit state locking configuration visible
- Azure Blob backend DOES support locking via blob leases, but requires proper configuration
- Two separate workflows can run simultaneously on merged PRs

**Cascade**:
1. State corruption → Terraform detects "drift" on next run
2. Next apply attempts to "fix" drift → destroys/recreates resources
3. Team memberships lost → users locked out of repos
4. Repository collaborators reset → developers lose push access
5. Branch protection removed → unprotected main branches

**Current Mitigation**: GitHub Actions concurrency controls are NOT configured in workflows

**Required Fix**:
```yaml
# Add to on-merge.yml
concurrency:
  group: terraform-apply
  cancel-in-progress: false  # Queue, don't cancel
```

---

#### FM-002: Azure Blob Lease Failure (HIGH)

**Severity**: HIGH  
**Likelihood**: LOW (Azure SLA 99.9%)  
**MTTR**: 30min-2hr

**Mechanism**:
- Terraform acquires blob lease for state locking
- Azure storage transient failure prevents lease acquisition
- Terraform apply fails with "Error acquiring the state lock"
- Retry logic may not be sufficient

**Evidence**: Backend uses Azure Blob (`backend.tf:2`) with `use_azuread_auth = true`

**Cascade**:
1. Lease failure → workflow fails
2. Manual retry needed → toil
3. If lease stuck → manual lease break required via Azure Portal/CLI

**Recovery Procedure** (currently undocumented):
```bash
# Break stuck lease
az storage blob lease break \
  --blob-name "sre-tf-github-teams/terraform.tfstate" \
  --container-name "tfstate" \
  --account-name "sasretfstate16a6dd7a"
```

---

#### FM-003: Partial Apply Failure (HIGH)

**Severity**: HIGH  
**Likelihood**: MEDIUM  
**MTTR**: 1-2 hours

**Mechanism**:
```hcl
# main.tf:30-45 - Membership creation depends on team
resource "github_team_membership" "maintainers" {
  for_each = merge([...])
  team_id  = each.value.team_id  # References local.all_teams[team_key].id
  ...
}
```

If team creation succeeds but membership fails:
- Team exists in GitHub
- State marks team as created
- Membership resources fail (API error, rate limit, invalid username)
- Partial state: team without members

**Evidence**: `main.tf:31-44` creates memberships in a `for_each` loop with dynamic references

**Cascade**:
1. Team created without maintainers → no one can manage team
2. Repo collaborator assignment may reference non-existent team → apply fails
3. Recovery requires manual GitHub intervention OR state manipulation

---

### 1.2 Cascading Failure Risks

#### FM-004: YAML Malformation Blocks All PRs (HIGH)

**Severity**: HIGH  
**Likelihood**: MEDIUM (human error in manual YAML edits)  
**MTTR**: 15-30 minutes

**Mechanism**:
```hcl
# locals.tf:6-9
repositories_configs = {
  for file in local.repository_files : file => yamldecode(file("..."))
  if length(trimspace(file("..."))) > 0
}
```

Single malformed YAML file causes `yamldecode()` to fail during `terraform plan`.

**Evidence**: 70+ YAML files in `config/repositories/`, 12+ in `config/teams/`

**Cascade**:
1. Any YAML syntax error → `terraform plan` fails
2. Failed plan → PR blocked (cannot merge)
3. ALL PRs blocked until YAML fixed
4. Blast radius: 100% of changes blocked

**Current Mitigation**: None visible (no YAML schema validation, no pre-commit hooks)

**Required Fix**:
```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/adrienverge/yamllint
    rev: v1.35.0
    hooks:
      - id: yamllint
        files: \.yaml$
```

---

#### FM-005: GitHub Token Expiration (HIGH)

**Severity**: HIGH  
**Likelihood**: CERTAIN (tokens expire)  
**MTTR**: 30min-2hr (depending on rotation process)

**Mechanism**:
- GitHub App PEM file stored as secret (`APP_PRIVATE_KEY`)
- App installation ID in variables
- JWT tokens generated from PEM expire in 10 minutes
- Installation access tokens expire in 1 hour

**Evidence**: `on-merge.yml:17-19`:
```yaml
TF_VAR_github_app_id: ${{ vars.GH_APP_ID }}
TF_VAR_github_app_installation_id: ${{ vars.GH_APP_INSTALLATION_ID }}
TF_VAR_github_app_pem_file: ${{ secrets.APP_PRIVATE_KEY }}
```

**Cascade** (if PEM key compromised or expires):
1. ALL Terraform automation fails
2. No teams/repos can be created or modified
3. Manual intervention required to rotate key
4. Key rotation requires GitHub App admin access + secrets update

**Required Fix**: Implement token rotation alerting and automated renewal

---

#### FM-006: SAML Misconfiguration Causes Mass Access Loss (CRITICAL)

**Severity**: CRITICAL  
**Likelihood**: LOW (requires Azure AD misconfiguration)  
**MTTR**: 4-8 hours

**Mechanism** (per ADR document):
- EMU (Enterprise Managed Users) with SCIM provisioning
- Users provisioned/deprovisioned via Azure AD
- SAML misconfiguration could deauthorize all users

**Evidence**: ADR document mentions "automatic org invitations and offboarding"

**Cascade**:
1. Azure AD group misconfiguration → SCIM deprovisioning
2. Users removed from GitHub org
3. Team memberships cascade-deleted
4. Repository access lost for entire organization
5. Recovery requires Azure AD fix + SCIM resync

**Required Fix**: 
- Implement SCIM provisioning alerts
- Create "break glass" org admin account NOT managed by SCIM
- Document manual recovery procedure

---

#### FM-007: Branch Protection Applied to IaC Repos (MEDIUM)

**Severity**: MEDIUM  
**Likelihood**: CERTAIN (protection is enabled)  
**MTTR**: 30min-2hr

**Mechanism**:
```hcl
# repositories/main.tf:85-100
resource "github_branch_protection" "this" {
  for_each = { for key, repo in local.repositories : key => repo
    if repo.default_branch_policies_enabled == true }
  ...
  required_pull_request_reviews {
    require_code_owner_reviews = true
    required_approving_review_count = 1
  }
}
```

During P0 incident, if IaC repo has branch protection:
- Cannot push emergency fix directly
- Requires PR + review + approval
- CODEOWNERS may be unavailable at 3 AM

**Evidence**: `main.tf:85-100` applies branch protection to repos with `default_branch_policies_enabled = true`

**Cascade**:
1. P0 incident requires immediate config change
2. PR required → SRE waits for reviewer
3. CODEOWNERS on vacation/asleep → blocked
4. No bypass mechanism documented

**Required Fix**: Document emergency bypass procedure, consider bypass accounts

---

### 1.3 Recovery Scenarios

| Scenario | Recovery Path | Estimated MTTR | Runbook Exists? |
|----------|---------------|----------------|-----------------|
| Terraform state corrupted | Restore from Azure blob snapshot | 1-2 hours | NO |
| Bypass automation during P0 | Manual GitHub UI changes | 15-30 min | NO |
| Manually create team if TF down | GitHub UI + later import | 30-60 min | NO |
| Rollback bad config | git revert + new PR + merge | 30-60 min | PARTIAL |
| GitHub App token compromised | Rotate PEM, update secrets | 1-2 hours | NO |
| Mass user deprovisioning | Azure AD fix + SCIM resync | 4-8 hours | NO |

**CRITICAL GAP**: No runbooks exist for any recovery scenario.

---

## 2. Operational Complexity Assessment

### 2.1 Toil Analysis

| Task | Frequency | Time/Instance | Weekly Total | Automatable? |
|------|-----------|---------------|--------------|--------------|
| YAML config edits | 10/week | 5 min | 50 min | YES (self-service portal) |
| PR reviews for team changes | 10/week | 10 min | 100 min | PARTIAL (auto-approve simple) |
| CI babysitting (flaky failures) | 3/week | 15 min | 45 min | YES (retry logic) |
| Manual retries on rate limits | 2/week | 10 min | 20 min | YES (backoff) |
| Investigating access issues | 2/week | 30 min | 60 min | PARTIAL (better logging) |
| State lock troubleshooting | 1/week | 30 min | 30 min | YES (auto-break stale) |

**Total Estimated Toil**: ~305 min/week (~5 hours/week)

**Toil Score**: 5 hours/week (MEDIUM - requires reduction)

### 2.2 Debugging Difficulty

| Failure Type | Root Cause Identification | Skills Required | Tooling Gap |
|--------------|--------------------------|-----------------|-------------|
| Team access broken | 30min-2hr | Terraform + GitHub API | No correlation tool |
| Repo permission denied | 15-60min | GitHub RBAC knowledge | No permission tracer |
| Apply failed mid-run | 15-30min | Terraform state understanding | No apply visualization |
| YAML parse error | 5-15min | YAML syntax | No inline validation |
| SAML/SCIM issue | 1-4hr | Azure AD + GitHub EMU | Limited audit logs |

**Key Debugging Gap**: When team access breaks, no single tool correlates:
- Terraform state (what TF thinks exists)
- GitHub reality (what actually exists)
- Azure AD (SCIM provisioning status)
- GitHub Audit Log (what changed and when)

**Recommendation**: Build correlation dashboard or CLI tool.

### 2.3 Change Velocity Bottlenecks

```
USER REQUEST: "I need repo access"
├─ T+0: User submits request (Slack? Email? Form?)
├─ T+???: Request reaches SRE (no formal intake process documented)
├─ T+10min: SRE creates YAML config change
├─ T+15min: SRE creates PR
├─ T+30min-4hr: PR review and approval (depends on CODEOWNERS availability)
├─ T+5min: PR merges, triggers workflow
├─ T+3min: Terraform plan
├─ T+2min: Terraform apply
└─ TOTAL: 1-5 hours (mostly waiting for review)
```

**Bottleneck**: PR review approval gate

**Emergency Access Gap**: No documented bypass for urgent access grants

**Recommendation**: Implement auto-approval for low-risk changes (e.g., adding user to existing team)

---

## 3. Observability Gaps

### 3.1 Monitoring Status

| Metric | Currently Monitored? | Recommended Alert |
|--------|---------------------|-------------------|
| Terraform apply success rate | NO | Alert if <95% over 24h |
| Terraform drift detected | NO | Alert on any drift |
| GitHub API rate limit | NO | Alert at 80% consumed |
| State file age (last modified) | NO | Alert if >24h stale |
| PR merge-to-apply latency | NO | Alert if >30min |
| Team count matches expected | NO | Alert on unexpected change |
| Repo count matches expected | NO | Alert on unexpected change |

**CRITICAL GAP**: No alerting on Terraform drift. If someone makes manual change in GitHub UI, system has no visibility.

### 3.2 Drift Detection Requirements

```hcl
# Recommended: Add drift detection workflow
# .github/workflows/drift-detection.yml
name: Drift Detection
on:
  schedule:
    - cron: '0 */4 * * *'  # Every 4 hours
jobs:
  detect-drift:
    steps:
      - run: terraform plan -detailed-exitcode
      # Exit code 2 = drift detected
      - if: steps.plan.outcome == 'failure'
        run: |
          # Alert to Slack/PagerDuty
```

### 3.3 Audit Trail Gaps

| Event | Can Track in Git? | Can Track in GitHub Audit? | Correlation Tool? |
|-------|-------------------|---------------------------|-------------------|
| YAML config change | YES (git history) | N/A | NO |
| Terraform apply | YES (workflow logs) | YES (partial) | NO |
| Manual GitHub change | NO | YES | NO |
| SCIM user provision | NO | YES (Enterprise) | NO |

**Gap**: Cannot easily correlate "who changed what when" across all systems.

---

## 4. Security & Compliance Concerns

### 4.1 Least Privilege Analysis

| Role | Current Access | Recommended | Gap |
|------|----------------|-------------|-----|
| GitHub Org Owners | "Cloud & SRE team" | 2-3 individuals max | Unknown count |
| State File Access | Azure AD auth | Limit to CI + SRE | May be broader |
| GitHub App | Full org permissions? | Minimum required | Needs audit |
| CODEOWNERS bypass | Not documented | Emergency accounts | None exist |

**Recommendation**: Audit who has org owner access, document explicitly.

### 4.2 Blast Radius Analysis

| Compromise Vector | Blast Radius | Detection Time | Recovery Time |
|-------------------|--------------|----------------|---------------|
| GitHub App PEM key leaked | ALL repos, ALL teams | Hours-Days | 1-2 hours |
| Azure storage account compromised | State corruption | Hours-Days | 2-4 hours |
| Malicious YAML commit | Depends on change | Minutes (PR review) | 30-60 min |
| SCIM admin compromised | ALL user access | Hours | 4-8 hours |

**Highest Risk**: GitHub App PEM key (stored in GitHub Secrets) - single key controls everything.

### 4.3 Malicious YAML Commit Analysis

What can an attacker achieve with a malicious YAML commit?

```yaml
# Example malicious change in teams/*.yaml
teams:
  cloud-sre:
    maintainers:
      - username: "attacker-account"  # Add attacker as maintainer
        email: "attacker@evil.com"
```

**Result**: If PR approved (review bypass, compromised reviewer):
- Attacker gains team maintainer access
- Can add more users
- Can modify team repositories
- Cascading privilege escalation

**Mitigation**: CODEOWNERS review + require 2 approvers for team/permission changes

---

## 5. Comparison vs Industry Best Practices

### 5.1 Eneco vs Industry Leaders

| Capability | Eneco | GitLab | Terraform Cloud | GitHub Enterprise Best Practice |
|------------|-------|--------|-----------------|--------------------------------|
| IaC for GitHub config | YES | N/A | YES | YES |
| State locking | PARTIAL | N/A | YES (native) | YES |
| Drift detection | NO | Built-in | YES (native) | Recommended |
| SCIM provisioning | YES (planned) | YES | N/A | YES |
| Policy as Code | NO | YES | Sentinel | Recommended |
| Self-service portal | NO | YES | YES | Recommended |
| Audit correlation | NO | YES | YES | Recommended |

### 5.2 What Would a Principal SRE at Google/Netflix/Stripe Do Differently?

1. **Google SRE Approach**:
   - Implement error budget for access provisioning (SLO: 99% of requests fulfilled within 4 hours)
   - Automated rollback on drift detection
   - Blameless postmortem process for access-related incidents
   - Eliminate toil through self-service automation

2. **Netflix Approach**:
   - Build internal developer portal for self-service access requests
   - Implement "paved road" patterns for common team structures
   - Chaos engineering: randomly inject failures to test recovery
   - Everything observable by default

3. **Stripe Approach**:
   - Policy as Code (OPA/Sentinel) for security guardrails
   - Automated compliance checks in CI
   - Zero-trust: no standing access, just-in-time provisioning
   - Correlation IDs through entire request lifecycle

### 5.3 Critical Missing Capabilities

| Capability | Business Impact | Implementation Effort |
|------------|-----------------|----------------------|
| Self-service portal | -80% toil, +50% velocity | HIGH (weeks) |
| Drift detection | -90% silent failures | LOW (hours) |
| State locking | -100% corruption risk | LOW (config change) |
| Policy as Code | +Security, -review burden | MEDIUM (days) |
| Observability dashboard | -50% debugging time | MEDIUM (days) |

---

## 6. Recommendations

### 6.1 Critical (Fix Within 1 Week)

| # | Issue | Fix | Effort | Risk if Unfixed |
|---|-------|-----|--------|-----------------|
| 1 | No concurrency control | Add `concurrency` block to workflows | 30 min | State corruption |
| 2 | No recovery runbooks | Document 5 critical scenarios | 4 hours | Extended outages |
| 3 | No emergency bypass | Create bypass account + document | 2 hours | P0 blocked |

### 6.2 High (Fix Within 1 Month)

| # | Issue | Fix | Effort | Benefit |
|---|-------|-----|--------|---------|
| 4 | No drift detection | Add scheduled plan workflow | 2 hours | Silent failure prevention |
| 5 | No YAML validation | Add pre-commit hooks | 1 hour | Reduce PR failures |
| 6 | No observability | Add metrics to DataDog/Prometheus | 8 hours | Faster debugging |
| 7 | No self-service intake | Implement request form/Slack bot | 16 hours | Reduce toil |

### 6.3 Medium (Fix Within Quarter)

| # | Issue | Fix | Effort | Benefit |
|---|-------|-----|--------|---------|
| 8 | No policy as code | Implement OPA/Sentinel policies | 2 weeks | Security + velocity |
| 9 | Manual YAML edits | Self-service portal | 4 weeks | -80% toil |
| 10 | No correlation tool | Build audit correlation CLI | 1 week | -50% debug time |

---

## 7. Risk Register

| ID | Risk | Likelihood | Impact | Current Control | Residual Risk | Owner |
|----|------|------------|--------|-----------------|---------------|-------|
| R1 | State corruption | MEDIUM | CRITICAL | Blob snapshots | HIGH | SRE |
| R2 | Token compromise | LOW | CRITICAL | Secrets rotation | MEDIUM | SRE |
| R3 | Mass deprovisioning | LOW | CRITICAL | None | HIGH | SRE |
| R4 | YAML blocks all PRs | MEDIUM | HIGH | PR review | MEDIUM | SRE |
| R5 | Silent drift | HIGH | MEDIUM | None | HIGH | SRE |
| R6 | Emergency access blocked | LOW | HIGH | None | HIGH | SRE |

---

## 8. Implementation Roadmap

### Week 1: Critical Fixes
- [ ] Add concurrency control to workflows
- [ ] Document state corruption recovery runbook
- [ ] Document emergency bypass procedure
- [ ] Create break-glass org admin account

### Week 2-4: High Priority
- [ ] Implement drift detection workflow
- [ ] Add YAML pre-commit validation
- [ ] Set up basic monitoring/alerting
- [ ] Implement structured logging in workflows

### Month 2-3: Medium Priority
- [ ] Design self-service request system
- [ ] Implement OPA policies for common violations
- [ ] Build audit correlation tooling
- [ ] Create SLO for access provisioning

---

## Appendix A: Failure Mode Summary Table

| ID | Failure Mode | Severity | MTTR | Runbook? | Monitoring? |
|----|--------------|----------|------|----------|-------------|
| FM-001 | Concurrent applies | CRITICAL | 2-4hr | NO | NO |
| FM-002 | Azure lease failure | HIGH | 30min-2hr | NO | NO |
| FM-003 | Partial apply | HIGH | 1-2hr | NO | NO |
| FM-004 | YAML malformation | HIGH | 15-30min | NO | NO |
| FM-005 | Token expiration | HIGH | 30min-2hr | NO | NO |
| FM-006 | SAML misconfiguration | CRITICAL | 4-8hr | NO | NO |
| FM-007 | IaC branch protection | MEDIUM | 30min-2hr | NO | NO |

---

## Appendix B: Quick Reference Commands

### Break Azure Blob Lease
```bash
az storage blob lease break \
  --blob-name "sre-tf-github-teams/terraform.tfstate" \
  --container-name "tfstate" \
  --account-name "sasretfstate16a6dd7a"
```

### Force Unlock Terraform State
```bash
terraform force-unlock <LOCK_ID>
```

### Check Current State
```bash
terraform state list
terraform state show github_team.parent_teams["cloud-sre"]
```

### Import Manually Created Resource
```bash
terraform import 'github_team.parent_teams["emergency-team"]' <TEAM_ID>
```

---

*End of SRE Operational Review*
