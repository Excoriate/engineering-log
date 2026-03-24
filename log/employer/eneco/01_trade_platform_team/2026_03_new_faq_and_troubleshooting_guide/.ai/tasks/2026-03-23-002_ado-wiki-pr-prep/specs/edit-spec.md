---
task_id: 2026-03-23-002
agent: coordinator
status: draft
summary: Edit specifications for wiki PR
---

# Edit Specification

## File Operations
1. Rename faq.md → FAQ.md
2. Rename troubleshooting_guide.md → Troubleshooting-Guide.md
3. Create Guides/.order
4. Create Guides.md
5. Update parent .order
6. Update Home.md

## Content Edits
7. FAQ: update 2 cross-refs to Troubleshooting-Guide.md
8. Troubleshooting-Guide: update 3 cross-refs from faq_draft.md to FAQ.md
9. AI slop removal pass on both docs

## Verification
10. grep for old references
11. check .order files
12. ADO wiki compat check
