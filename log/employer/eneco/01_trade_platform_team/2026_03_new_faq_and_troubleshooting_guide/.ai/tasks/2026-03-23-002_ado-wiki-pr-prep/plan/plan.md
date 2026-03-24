---
task_id: 2026-03-23-002
agent: coordinator
status: draft
summary: Plan for ADO wiki PR preparation
---

# Plan

## Steps

### S1: Rename files to match wiki conventions
- `faq.md` → `FAQ.md`
- `troubleshooting_guide.md` → `Troubleshooting-Guide.md`
- Acceptance: filenames match PascalCase-with-hyphens convention

### S2: Fix cross-references
- FAQ: `./troubleshooting_guide.md` → `./Troubleshooting-Guide.md` (2 places)
- Troubleshooting: `./faq_draft.md` → `./FAQ.md` (3 places)
- Acceptance: grep returns 0 for old refs, >0 for new

### S3: Create wiki infrastructure
- Create `Guides/.order` with page list
- Create `Guides.md` section page
- Add `Guides` to parent `.order`
- Acceptance: all files exist, .order includes Guides

### S4: Update Home.md
- Add Guides section to Diátaxis structure list
- Acceptance: Home.md references Guides

### S5: AI slop pass
- Scan for and remove AI-detectable patterns
- Acceptance: no suspicious patterns remain

### S6: ADO wiki rendering check
- Verify tables, code blocks, blockquotes, emoji render correctly (per librarian)
- Acceptance: no known ADO wiki incompatibilities

### S7: Contrarian review
- Dispatch contrarian on final state
- Acceptance: no uncaught issues

## Adversarial Challenge
- Phase 4 finding: documents read human, slop risk is low
- Phase 1 hypothesis "wiki-incompatible" CONFIRMED: infrastructure gaps are the real risk
- Q1: What if ADO wiki doesn't support emoji? → librarian checking
- Q2: What if anchor links break with renamed files? → will verify
- Q3: What if .order format is wrong? → will check existing .order files

## verify-strategy
See Phase 3 requirements-final.md
