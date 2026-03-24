---
task_id: 2026-03-23-002
agent: coordinator
status: draft
summary: Wiki repo structure map
---

# Codebase Map — platform-documentation wiki repo

## Branch/Worktree
- Bare repo with worktree: `ootw-add-faq-troubleshooting-guide`
- Working dir: `.../platform-documentation/ootw-add-faq-troubleshooting-guide/platform-documentation/`

## Diátaxis Structure (platform-documentation/)
```
platform-documentation/
├── .order              (Home, How-To-Guides, Reference, Tutorials, Explanation) ← MISSING: Guides
├── Home.md             (32 lines — landing page, may need TOC update)
├── Explanation/        (.order exists, empty)
├── Explanation.md
├── Guides/             ← NEW (user-created, no .order, no Guides.md)
│   ├── faq.md          (303 lines)
│   └── troubleshooting_guide.md  (271 lines)
├── How-To-Guides/
│   ├── .order
│   ├── images/
│   └── Troubleshooting.FeatureBranchEnvironments.md (148 lines ← OVERLAP with new guide)
├── How-To-Guides.md
├── images/
├── Reference/
│   ├── Architecture/
│   └── MC-Azure-Cloud/
├── Reference.md
├── Tutorials/
│   └── .order
└── Tutorials.md
```

## Critical Findings
1. NO .order in Guides/ → pages invisible in wiki nav
2. NO Guides.md landing page → section won't render in wiki sidebar
3. Guides NOT in parent .order → entire section missing from nav
4. troubleshooting_guide.md uses underscore → should use hyphens per repo convention
5. Existing FBE troubleshooting page in How-To-Guides/ — potential overlap
6. Home.md may need updating to reference new section
