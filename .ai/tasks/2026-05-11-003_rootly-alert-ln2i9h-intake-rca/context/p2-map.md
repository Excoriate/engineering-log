---
task_id: 2026-05-11-003
agent: claude-code
status: draft
summary: P2 Map — engineering-log repo + Context Universe lanes; map-only, no content reads
---

# P2 — Map (Delta First)

## Map class verdict per surface

| Surface | Class | Evidence |
|---------|-------|----------|
| `.ai/codebase-context/` | **absent** | `find .ai/codebase-context -type f` returns empty; no prior canonical map to delta against |
| `.ai/tasks/` priors | **newly-mapped** | Only `2026-05-11-003_rootly-alert-ln2i9h-intake-rca` exists (prior task dirs already cleaned); maps must be created fresh |
| `log/employer/eneco/02_on_call_shift/` | **reused (structural conventions)** | 12 prior on-call shift folders with established RCA shape; I will mirror conventions, not copy content |
| MC-VPP-Infrastructure repo at memorized path | **reused (lane identity)** | `/Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src/enecomanagedcloud/myriad-vpp/MC-VPP-Infrastructure/main` confirmed present; will be a P4 lane fetch, NOT a P2 read |
| Destination folder | **reused (empty container)** | `log/employer/eneco/02_on_call_shift/2026_05_11_rootly_alert_cpu_throtling/` exists, is empty; RCA artifacts to be written here per user directive |

## Convention precedents (structural reuse)

From sibling on-call shift folders — these set the RCA shape my output should mirror:

- **2026_03_27_gurobi_throttling_alert/** — gold standard for throttling-class RCA with multi-reviewer fan-out:
  - `root-cause-analysis.md` (primary deliverable)
  - `rootly-alert-payload.json` (canonical alert preserved)
  - `linus-review.md`, `sre-review.md`, `demoledor-runbook-review.md`, `linus-runbook-review.md`, `sre-runbook-review.md` (adversarial reviewers, multiple frames)
  - `prompt.txt` (intake context preserved)
- **2026_03_26_alert_sql_acc/** — alert RCA with analysis modules:
  - `alert_payload_rootly.json`, `preliminary_analysis.md`, `container_memory_alert_analysis.md`, `root_cause_analysis.md`
- **2026_04_21_stefan_redis_alerts/** — matches Brain task protocol exactly: requirements + maps + context (with reviewer files) + plan + specs + outcome + verification + lessons-learned
- **2026_04_26_pbbtBV_kv-vppagg-bootstrap-d-latency.md** — single-file summary precedent for the CCoE keyvault bootstrap noisy alert (known recurrence per project memory)

**Inference**: the convention is to mirror full Brain protocol (`requirements/`, `context/`, `plan/`, `specs/`, `outcome/`, `verification/`) under `$T_DIR` and deposit the *deliverable artifacts only* in the external destination folder.

## Context Universe — lane identities (74.4.1 Lock)

Lanes seeded in P1 are enumerated here with concrete fetch shapes and skip-risk classification. **P3 attacks the fit. P4 fetches the highest-info evidence.**

| ID | Identity | Fetch shape | Underfetch risk | Overfetch risk |
|----|----------|-------------|-----------------|----------------|
| L-ROOTLY-ALERT | Canonical alert record `ln2i9h` | `~/.claude/skills/eneco-tools-rootly/scripts/rootly-alert-decode.sh --short-id ln2I9h` (note: rootly short ID is case-sensitive; preserve `I`) | Whole RCA collapses — diagnosis is fiction without canonical payload | None — single small JSON |
| L-ROOTLY-HISTORY | Last 20 firings same rule + similar incidents | `rootly-api.sh GET "/v1/alerts?filter[search]=<rule>"` + MCP `find_related_incidents` | Pattern class (Known/Known-with-change/Novel) cannot be reasoned; trend section missing | Small — bounded by page_size=20 |
| L-AZURE-RULE | ARM definition of Azure Monitor rule | `az monitor metrics alert show -n <rule> -g <rg>` (needs MC dev/acc/prd login first) | Link L2-L3 of alert-as-code traceback fails | Small — single resource |
| L-IAC-SOURCE | Terraform alert rule + tfvars threshold | Read `MC-VPP-Infrastructure/terraform/metric-alert-*.tf` + matching `<env>-alerts.tfvars` | Link L3-L5 missing — no IaC reasoning | Bounded to alert files |
| L-GIT-BLAME | Threshold provenance | `git log -p` + `git blame` on threshold line in MC-VPP-Infra | Link L5 missing — no provenance | Small per line |
| L-VENDOR-DOCS | Microsoft Learn semantics for the metric | `microsoft_docs_search` then `microsoft_docs_fetch` | Link L6 missing — first principles absent | Bounded to focused query |
| L-RUNTIME-METRIC | 7-day metric distribution where firing sits | `az monitor metrics list --resource ... --metric ...` | Link L7 (threshold rationality) is theater without it | Moderate — fetch only relevant window |
| L-ENECO-DOCS | ADRs / wikis / FAQ for resource class | `eneco-context-docs` skill | Eneco-specific instantiation missing | Moderate — focused query |
| L-PRIOR-RCAS | engineering-log + 2ndbrain prior diagnoses on same rule/resource | `find log/employer/eneco/02_on_call_shift -iname "*<keyword>*"` | Duplicate reasoning work; missed recurrence intelligence | Small — local fs |
| L-ADVERSARIAL | Sherlock + Socrates + Russell typed subagents | TYPED subagent dispatch with artifact_path | Self-review of RCA = HALT per Gate 7 | Fan-out cost; ROI > 0 because RCA is action-bearing deliverable |

**Lane prioritization** (P4 highest-info-first): L-ROOTLY-ALERT → L-ROOTLY-HISTORY → L-AZURE-RULE → L-IAC-SOURCE → L-GIT-BLAME → L-PRIOR-RCAS → L-VENDOR-DOCS → L-RUNTIME-METRIC → L-ENECO-DOCS → L-ADVERSARIAL.

## System-coherence pass

Cross-surface contradiction checks executed (map-only, no content reads):

| Pair | Probe | Result |
|------|-------|--------|
| Canonical (Rootly alert) ↔ Derived (folder slug `cpu_throtling`) | Slug is a user-typed working name; the canonical metric is unknown until L-ROOTLY-ALERT fetched in P4 | **Contradiction-pending** — diagnosis is held as UNVERIFIED until P4 |
| `rootly-alert-decode.sh` flag (`--short-id`) ↔ User-provided short ID `ln2I9h` (capital I) | Short ID is case-sensitive in Rootly's database; slug for filesystem uses lowercase `ln2i9h` per regex requirements | Resolved: preserve `ln2I9h` for the script call, lowercase only for slug |
| Brain doc manifest schema (`created`/`modified`) ↔ Hook schema (`created_files`/`modified_files`) | Hook is stricter than brain text | Lesson captured: schema drift between brain doc and hook contract — hook wins (it's the runtime gate). Manifest now carries both. |
| MC-VPP-Infra path memory ↔ filesystem | `ls -d` confirmed present | Reused — no drift |

## Recent git scar (engineering-log)

Last 15 commits all `docs:`/`feat:` — log additions, not code edits. No conflicting in-progress work on the same destination folder.

66 untracked files in working tree (other prior tasks today — `fbe_error_duncan/`, `rotating_expired_argocd_secrets/`). NOT this task's concern; the task-workspace-guard hook only fires on those when the current task sentinel is invalid (it now is valid).

## Gate-out for P2

- ✅ Each surface classified with evidence tag
- ✅ Context Universe lanes enumerated with fetch shape + skip risk
- ✅ Cross-surface coherence pass executed (one contradiction pending — held as UNVERIFIED for P4)
- ✅ No content reads (map-only discipline)
