# Eneco GitHub Implementation: Context Map

> **Purpose**: Navigation guide for efficient document discovery using JIT (Just-In-Time) knowledge principles.
> **Last Updated**: 2026-01-19
> **Total Corpus**: 5,530 lines across 18 documents

---

## Quick Start by Role

### Executive (5 min)
| Order | Document | Lines | Focus |
|-------|----------|-------|-------|
| 1 | `EXECUTIVE_SUMMARY.md` | 440 | Full read |
| 2 | `INDEX.md` | 152 | "Summary for Leadership" section |

**Key anchors**: `INDEX.md:132-148` (What SRE Has vs What's Missing)

---

### Technical Lead (15 min)
| Order | Document | Lines | Focus |
|-------|----------|-------|-------|
| 1 | `INDEX.md` | 152 | Orientation |
| 2 | `AS_IS_VS_TO_BE.md` | 756 | Actual code analysis |
| 3 | `ERRATA_AND_IMPROVEMENTS.md` | 644 | Corrections applied |
| 4 | `SRE_DESIGN_SUMMARY_WITH_CHALLENGES.md` | 384 | Consolidated challenges |

**Key anchors**: `INDEX.md:47-62` (Critical Discovery: GitHub App Already Implemented)

---

### Implementer (30 min)
| Order | Document | Lines | Focus |
|-------|----------|-------|-------|
| 1 | SRE Source Docs (see below) | 304 | Original proposal |
| 2 | `AS_IS_VS_TO_BE.md` | 756 | Current implementation |
| 3 | `SRE_OPERATIONAL_REVIEW.md` | 591 | Failure modes |
| 4 | `02_repos_involved/` | — | Actual Terraform code |

---

### Auditor (20 min)
| Order | Document | Lines | Focus |
|-------|----------|-------|-------|
| 1 | `VERIFICATION_SOURCES.md` | 446 | 16 official doc URLs |
| 2 | `CORRECTIONS_AND_CITATIONS.md` | 587 | Evidence basis tags |
| 3 | `ERRATA_AND_IMPROVEMENTS.md` | 644 | 3 technical fixes |

**Key anchors**: `INDEX.md:76-82` (Evidence Basis Distribution: 84% grounded)

---

## Document Dependency Graph

```
┌─────────────────────────────────────────────────────────────────┐
│                    SRE SOURCE MATERIAL                          │
│  01_sre_team_approach/                                          │
│  ├── ADR_GitHub_2.0_migration_and_design.md (85)                │
│  ├── GitHub_org_and_repository_policies.md (78)                 │
│  ├── Feature_limitations.md (51)                                │
│  ├── Concrete_migration_plan.md (51)                            │
│  └── General_organization_setup.md (39)                         │
│  TOTAL: 304 lines                                               │
└─────────────────────────────────┬───────────────────────────────┘
                                  │
          ┌───────────────────────┼───────────────────────┐
          │                       │                       │
          ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   ANALYSIS      │    │  VERIFICATION   │    │   ACTUAL CODE   │
│                 │    │                 │    │                 │
│ AS_IS_VS_TO_BE  │    │ VERIFICATION_   │    │ 02_repos_       │
│ (756)           │    │ SOURCES (446)   │    │ involved/       │
│                 │    │                 │    │                 │
│ ENECO_GITHUB_   │    │ CORRECTIONS_    │    │ sre-tf-github-  │
│ ORG_AUDIT (604) │    │ AND_CITATIONS   │    │ teams/          │
│                 │    │ (587)           │    │ (Terraform)     │
│ SRE_OPERATIONAL │    │                 │    │                 │
│ _REVIEW (591)   │    │ ERRATA_AND_     │    │ sre-tf-github-  │
│                 │    │ IMPROVEMENTS    │    │ repositories/   │
│                 │    │ (644)           │    │ (Terraform)     │
└────────┬────────┘    └────────┬────────┘    └─────────────────┘
         │                      │
         └──────────┬───────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                       SYNTHESIS                                  │
│  ├── EXECUTIVE_SUMMARY.md (440) - Leadership brief              │
│  ├── SRE_DESIGN_SUMMARY_WITH_CHALLENGES.md (384) - Consolidated │
│  ├── FINAL_DELIVERABLES.md (225) - Recommendations              │
│  ├── README.md (275) - Navigation                               │
│  └── INDEX.md (152) - Master index                              │
└─────────────────────────────────────────────────────────────────┘
```

---

## Document Catalog

### SRE Source Material (304 lines total)
| File | Lines | Key Content |
|------|-------|-------------|
| `01_sre_team_approach/ADR_GitHub_2.0_migration_and_design.md` | 85 | Architecture decision record |
| `01_sre_team_approach/GitHub_org_and_repository_policies.md` | 78 | Org/repo policy definitions |
| `01_sre_team_approach/Feature_limitations.md` | 51 | Known EMU/GHE limitations |
| `01_sre_team_approach/Concrete_migration_plan.md` | 51 | Migration phases |
| `01_sre_team_approach/General_organization_setup.md` | 39 | Org structure setup |

### Analysis Documents (1,951 lines total)
| File | Lines | Key Content |
|------|-------|-------------|
| `AS_IS_VS_TO_BE.md` | 756 | **Actual .tf files, YAML configs, workflows** |
| `ENECO_GITHUB_ORG_AUDIT.md` | 604 | GitHub org audit (77 repos, SAML enforced) |
| `SRE_OPERATIONAL_REVIEW.md` | 591 | 7 failure modes, toil analysis |

### Verification Documents (1,677 lines total)
| File | Lines | Key Content |
|------|-------|-------------|
| `ERRATA_AND_IMPROVEMENTS.md` | 644 | **3 technical fixes, 4 severity downgrades** |
| `CORRECTIONS_AND_CITATIONS.md` | 587 | Evidence basis tagging system |
| `VERIFICATION_SOURCES.md` | 446 | 16 authoritative URLs |

### Synthesis Documents (1,476 lines total)
| File | Lines | Key Content |
|------|-------|-------------|
| `EXECUTIVE_SUMMARY.md` | 440 | Leadership overview, readiness 65/100 |
| `SRE_DESIGN_SUMMARY_WITH_CHALLENGES.md` | 384 | **Consolidated summary with challenges** |
| `README.md` | 275 | Navigation with severity downgrades |
| `FINAL_DELIVERABLES.md` | 225 | Action items |
| `INDEX.md` | 152 | Master document index |

---

## Token Budget Guide

| Category | Lines | Est. Tokens | Context % (128K) |
|----------|-------|-------------|------------------|
| SRE Source Material | 304 | ~3,000 | 2.3% |
| Analysis Documents | 1,951 | ~19,500 | 15.2% |
| Verification Documents | 1,677 | ~16,800 | 13.1% |
| Synthesis Documents | 1,476 | ~14,800 | 11.6% |
| **FULL CORPUS** | **5,530** | **~55,000** | **43%** |

**Optimization Strategy**:
- Quick context: `INDEX.md` only (~1,500 tokens, 1.2%)
- Technical work: `AS_IS_VS_TO_BE.md` + `SRE_DESIGN_SUMMARY_WITH_CHALLENGES.md` (~11K tokens, 8.6%)
- Full verification: Add `VERIFICATION_SOURCES.md` + `ERRATA_AND_IMPROVEMENTS.md` (~22K tokens, 17%)

---

## Search Patterns

| Question | File | Section |
|----------|------|---------|
| "What did SRE propose?" | `01_sre_team_approach/*.md` | All 5 docs |
| "What code exists?" | `AS_IS_VS_TO_BE.md` | Full doc |
| "What was corrected?" | `ERRATA_AND_IMPROVEMENTS.md` | Lines 1-100 |
| "Is claim X verified?" | `VERIFICATION_SOURCES.md` | Search by topic |
| "What are the gaps?" | `SRE_OPERATIONAL_REVIEW.md` | "Failure Modes" |
| "Executive summary?" | `EXECUTIVE_SUMMARY.md` | Full doc |
| "Official doc links?" | `INDEX.md` | Lines 109-129 |

### Grep Commands
```bash
# Find corrections
rg -n "CORRECTED|INCORRECT|severity" *.md

# Find verified claims
rg -n "VERIFIED|SOURCE-TRACED|CODE-GROUNDED" *.md

# Find GitHub App evidence
rg -n "GH_APP|github_app" --type yaml --type md
```

---

## Critical Findings (from INDEX.md)

| Finding | Original | Corrected | Evidence |
|---------|----------|-----------|----------|
| Token SPOF | HIGH | **N/A** | Already using GitHub App (`on-pr.yml:20-22`) |
| State corruption | CRITICAL | MEDIUM | Azure Blob has automatic leases |
| No drift detection | HIGH | MEDIUM | No active drift found |
| Toil calculation | 5hr/week | UNMEASURED | Estimated without data |

---

## Verification Tests (from INDEX.md:89-105)

```bash
# Test 1: Verify Azure Blob locking (2 hours)
terraform apply & sleep 3 && terraform apply
# Expected: "Error acquiring the state lock"

# Test 2: Check for drift (30 min)
terraform plan -detailed-exitcode
# Exit 0: No drift | Exit 2: Drift exists

# Test 3: Measure toil (2 weeks)
gh pr list --state merged --limit 100 --json createdAt,mergedAt | \
jq -r '.[] | (.mergedAt | fromdateiso8601) - (.createdAt | fromdateiso8601)' | \
awk '{sum+=$1; count++} END {print sum/count/3600 " hours avg"}'
```

---

## Evidence Quality Summary

| Category | Count | % |
|----------|-------|---|
| SOURCE-TRACED (official docs) | 47 | 67% |
| CODE-GROUNDED (file inspection) | 12 | 17% |
| INFERRED (logical) | 8 | 11% |
| SPECULATIVE (unverified) | 3 | 4% |

**Quality Score**: 84% grounded in verifiable evidence

---

*Generated by Context Engineering Protocol - Indiana Jones Methodology*
