---
task_id: 2026-03-23-002
agent: coordinator
status: draft
summary: Final requirements for ADO Wiki PR preparation
---

# Task Requirements — Final

## Changes from Initial
1. **Wiki navigation infrastructure required**: .order file, Guides.md landing page, parent .order update — pages are INVISIBLE without these
2. **Filename convention**: repo uses hyphens, troubleshooting_guide.md needs renaming to Troubleshooting-Guide.md (and cross-refs updated)
3. **ADO wiki title rendering**: filenames become page titles with hyphens→spaces. FAQ.md→"FAQ", Troubleshooting-Guide.md→"Troubleshooting Guide"
4. **Home.md update**: may need Guides section reference
5. **Existing FBE troubleshooting page**: potential overlap to check — the new troubleshooting guide covers FBE issues too

## Verification Strategy
### Acceptance Criteria
- Zero AI-detectable patterns in final docs
- Wiki nav works: .order files correct, Guides.md exists, parent .order includes Guides
- Cross-references between FAQ ↔ Troubleshooting Guide use correct ADO wiki link format
- All markdown renders in ADO wiki (tables, code blocks, blockquotes, emoji)
- No existing wiki pages broken

### Verify-How
| Check | Method |
|-------|--------|
| AI slop | Manual review + grep for common patterns |
| Wiki nav | .order files verified, Guides.md exists |
| Cross-refs | ADO wiki link format confirmed via librarian |
| Rendering | ADO wiki markdown rules checked |
| Repo impact | Diff against existing pages |

### Falsifiers
1. If any .order file is missing, pages won't appear in nav
2. If cross-refs use `./file.md` instead of ADO wiki format, links break
3. If emoji like 📎 don't render, entries look broken
