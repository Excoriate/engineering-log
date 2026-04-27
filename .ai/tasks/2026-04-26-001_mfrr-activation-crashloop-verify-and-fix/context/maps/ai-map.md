---
task_id: 2026-04-26-001
agent: coordinator
status: complete
summary: AI workspace map for this verify-and-fix task
---

# AI workspace map

```
.ai/                                    (engineering-log git root)
├── runtime/
│   └── current-task.json               sentinel — task_id 2026-04-26-001 phase 1
└── tasks/2026-04-26-001_mfrr-activation-crashloop-verify-and-fix/
    ├── manifest.json                    allowed_external_paths: 5 entries
    ├── 01-task-requirements-initial.md  Phase 1 done
    ├── context/maps/                    Phase 2 (this map + 4 siblings)
    ├── plan/                            Phase 5
    ├── specs/                           Phase 6
    ├── verification/                    Phase 8
    ├── outcome/                         (end-state artifacts mirrored to user folder)
    └── lessons-learned/                 promote to llm-wiki on consolidation
```

External authorized paths (manifest):
- `VPP - Infrastructure` worktree (literal path uses `VPP%20-%20Infrastructure`).
- `Eneco.Vpp.Core.Dispatching`, `VPP.GitOps`, `VPP-Configuration` (read-only context).
- `02_on_call_shift/2026_04_21_stefan_vpp_infrastructure_mfrr/` (deliverables target).
