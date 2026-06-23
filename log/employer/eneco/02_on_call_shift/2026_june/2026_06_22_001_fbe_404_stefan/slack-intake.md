# FBE 404 — Stefan (Slack intake)

## Derivation header

| Field | Value |
|-------|-------|
| `template_id` | `slack-intake.template.md` |
| `template_version` | `1.0.0` |
| `template_path` | [`log/employer/eneco/02_on_call_shift/_templates/slack-intake.template.md`](../../_templates/slack-intake.template.md) |
| `instance_id` | `2026_02_22_001_fbe_404_stefan` |
| `filled_date` | `2026-06-22` |

> **Derived intake:** Generic structure and UAC live in the [template](../../_templates/slack-intake.template.md). This file is a **rendered instance** — edit the template for reusable changes; edit sections below only for this incident.

## Table of contents

- [Instance manifest](#instance-manifest)
- [Input](#input)
  - [Description](#description)
  - [Original request (verbatim)](#original-request-verbatim)
  - [Known state from attachments](#known-state-from-attachments)
- [Mandatory context](#mandatory-context)
  - [Environmental context](#environmental-context)
  - [Context to fetch (mandatory)](#context-to-fetch-mandatory)
  - [Skills to use](#skills-to-use)
  - [Tools or CLI(s)](#tools-or-clis)
  - [UAC](#uac)
    - [Evidence and honesty](#evidence-and-honesty)
    - [Learning bar](#learning-bar)
    - [Deliverables](#deliverables)
    - [Post-completion: vault and memory](#post-completion-vault-and-memory)
    - [RCA acceptance](#rca-acceptance)
    - [How-to-fix acceptance](#how-to-fix-acceptance)
    - [Out of scope for UAC](#out-of-scope-for-uac)

## Instance manifest

Single source of incident-specific values for this derived file. When re-rendering from template, substitute from this table.

| Key | Value |
|-----|-------|
| `INCIDENT_TITLE` | FBE 404 — Stefan |
| `INSTANCE_ID` | `2026_02_22_001_fbe_404_stefan` |
| `SLACK_LIST_URL` | [Slack list record](https://grid-eneco.enterprise.slack.com/lists/T039G7V20/F0ACUPDV7HU?record_id=Rec0BBM3A9VHR) |
| `ATTACHMENT_REFS` | [image.png](./image.png) |
| `SLOT` | `operations` |
| `BUILD_ID` | `1685434` |
| `PIPELINE_ID` | `2412` |
| `PUBLIC_URL` | `https://operations.dev.vpp.eneco.com/` |
| `KUBE_CONTEXT` | `vpp-aks01-d` |
| `AZ_SUBSCRIPTION` | `7b1ba02e-bac6-4c45-83a0-7f0d3104922e` |
| `RESOURCE_GROUP` | `rg-vpp-app-sb-401` |
| `PRIMARY_SKILL` | `eneco-fbe-troubleshoot` |
| `VAULT_FBE_PATH` | `$SECOND_BRAIN_PATH/2-areas/work-eneco/eneco-vpp-platform/fbe/` |
| `VAULT_ERRORS_PATH` | `$SECOND_BRAIN_PATH/2-areas/work-eneco/eneco-vpp-platform/fbe-errors/` |
| `SEARCH_TERMS` | `FBE 404`, `operations` slot, `pipeline 2412`, `green build URL 404`, `OutOfSync app-of-apps` |
| `ROUTER_SYMPTOM` | `operations FBE 404 pipeline 2412 build 1685434 OutOfSync https://operations.dev.vpp.eneco.com/` |
| `LEDGER_DATE` | `2026-06-22` |
| `SNAPSHOT_NOTE` | build `1685434` succeeded; ArgoCD app-of-apps OutOfSync; public URL 404 — re-probe before RCA |

## Input

### Description

**FBE** = Feature Branch Environment (fixed sandbox slot with its own namespace and URL).

The FBE pipeline [build 1685434](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_build/results?buildId=1685434&view=logs&j=af2abfb9-573a-57bf-4a81-271513424d55&t=4081949e-1fba-5926-6c17-1f45851d65dd) (pipeline **2412**, FBE create) reports **succeeded**, but [operations.dev.vpp.eneco.com](https://operations.dev.vpp.eneco.com/) returns **404** and services appear undeployed.

Prior similar case: a pipeline job was stuck (class unknown — do not assume same root cause).

Request: restore the FBE to a live state.

> **Do not close on green build alone.** FBE create pipelines can succeed while runtime URL, GitOps sync, or Pester still fail.

### Original request (verbatim)

**Status:** Thread harvest **mandatory before investigation** — paste full Lists filing + key replies below after `eneco-context-slack`. Until then, use the paraphrase as **A2 INFER** only.

> I have issues with my FBE (**operations**). The create pipeline ([build 1685434](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_build/results?buildId=1685434)) reports succeeded, but [operations.dev.vpp.eneco.com](https://operations.dev.vpp.eneco.com/) returns **404** and services look undeployed. Please help restore the FBE to a live state.

Save harvest to this section (replace paraphrase) or [`slack-intake.txt`](./slack-intake.txt) in this incident folder.

- Slack input: [Slack list record](https://grid-eneco.enterprise.slack.com/lists/T039G7V20/F0ACUPDV7HU?record_id=Rec0BBM3A9VHR)
- Screenshot: [image.png](./image.png)

### Known state from attachments

From [image.png](./image.png) (ArgoCD UI snapshot — **not live truth**; re-probe before conclusions):

- `operations-app-of-apps`: **OutOfSync**, target `feature/fbe-851436-new-tso-adx-changes`
- `operations/assetmonitor`: target `feature/fbe-806738-mfrr-reference-signal` (different branch)
- Investigate **all Applications in the slot**, not only app-of-apps. Mixed branches suggest partial refresh.

## Mandatory context

*Generic text per [template § Mandatory context](../../_templates/slack-intake.template.md#mandatory-context). Instance values substituted below.*

### Environmental context

| Field | Value |
|-------|-------|
| ADO project | [Myriad - VPP](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP) (`enecomanagedcloud`) |
| FBE slot | `operations` |
| Pipeline build | [1685434](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_build/results?buildId=1685434) |
| Public URL | [operations.dev.vpp.eneco.com](https://operations.dev.vpp.eneco.com/) |
| Sandbox subscription | `7b1ba02e-bac6-4c45-83a0-7f0d3104922e` |
| AKS cluster / context | `vpp-aks01-d` / `rg-vpp-app-sb-401` |
| ArgoCD UI | [argocd.dev.vpp.eneco.com](https://argocd.dev.vpp.eneco.com) |

**FBE repos** (populate during investigation via `eneco-context-repos`):

| Repo | Role | ADO |
|------|------|-----|
| *(to be populated)* | | |

### Context to fetch (mandatory)

Complete **before** live probes or destructive actions. Record summaries in task notes and optionally `context-prefetch.md`. Label findings `A1 FACT`, `A2 INFER`, or `A3 UNVERIFIED`.

| # | Source | Skill | What to fetch | Channels / paths |
|---|--------|-------|---------------|------------------|
| 1 | Slack — platform requests | `eneco-context-slack` | Similar open or recent FBE issues, bot cards, resolutions | `#myriad-platform` |
| 2 | Slack — team coordination | `eneco-context-slack` | Team context, prior handlers | `#team-platform` |
| 3 | Slack — intake thread | `eneco-context-slack` | Verbatim Lists filing + companion thread | [Slack list URL](#original-request-verbatim) |
| 4 | Written runbooks / wiki | `eneco-context-docs` | Troubleshooting Guide, FAQ, FBE wiki | Platform-documentation; Myriad VPP wiki |
| 5 | Second brain | `2ndbrain-obsidian` | Known FBE recipes and prior incidents | `eneco-vpp-platform/fbe/` · `fbe-errors/` |

**Example search terms (this incident):** `FBE 404`, `operations` slot, `pipeline 2412`, `green build URL 404`, `OutOfSync app-of-apps`.

**Done when:** At least one of (Slack similar case, vault recipe, docs runbook) is cited in task notes **or** marked `A3 UNVERIFIED` with documented fallback.

> **MC access:** `eneco-tools-connect-mc-environments` — turn OFF IP whitelisting when done.

### Skills to use

| Skill | Phase | Role |
|-------|-------|------|
| `eneco-context-slack` | Before investigation | Mandatory context fetch |
| `eneco-context-docs` | Before investigation | Runbooks and wiki |
| `2ndbrain-obsidian` | Before investigation | Vault search |
| `eneco-fbe-troubleshoot` | Investigation | Classify, probes, safety gates, recipes |
| `eneco-context-repos` | Investigation | Repo map |
| `eneco-tools-connect-mc-environments` | Investigation | MC connectivity |
| `on-call-log-entry` | Throughout | Log layout (`slack-intake.txt`, `context.md`, outputs) |
| `rca-holistic` | Deliverables | `output/rca.html` |
| `how-to-feynman` | Deliverables | `output/how-to-fix.html` |
| `2ndbrain-knowledge-build` | After completion | Vault domain knowledge (UAC) |
| `2ndbrain-memory-consolidate` | After completion | Episode + lessons (UAC) |

**Classification gate:** Run `route-fbe-symptom.sh` with symptom string from [Instance manifest](#instance-manifest) (`ROUTER_SYMPTOM`). Record `FAILURE_CLASS`, `ROUTER_STATUS`, probe plan in task notes.

### Tools or CLI(s)

**Purpose:** Tool ledger and identifiers at intake time. Agent selects probes via `eneco-fbe-troubleshoot` — see [template § Tools](../../_templates/slack-intake.template.md#tools-or-clis) for generic contract.

#### Agent contract

- **Primary authority:** `eneco-fbe-troubleshoot` + fetched context
- **Identifiers:** [Incident identifiers](#incident-identifiers) only
- **Evidence:** `A1 FACT` · `A2 INFER` · `A3 UNVERIFIED`
- **Destructive actions:** explicit user authorization per FBE skill

#### Incident identifiers

| Constant | Value |
|----------|-------|
| `SLOT` | `operations` |
| `BUILD_ID` | `1685434` |
| `PIPELINE` | `2412` |
| `PUBLIC_URL` | `https://operations.dev.vpp.eneco.com/` |
| `KUBE_CONTEXT` | `vpp-aks01-d` |
| `AZ_SUBSCRIPTION` | `7b1ba02e-bac6-4c45-83a0-7f0d3104922e` |
| `ADO_ORG` / `ADO_PROJECT` | `enecomanagedcloud` / `Myriad - VPP` |
| `ARGOCD_NS` | `argocd` |

#### Tool availability ledger

| Tool | Version (2026-06-22) | Notes |
|------|----------------------|-------|
| `kubectl` | v1.36.2 | Context `vpp-aks01-d` |
| `argocd` | v3.4.4 | `--core` OK |
| `az` | 2.87.0 + devops 1.0.2 | Build `1685434` query OK |
| `jq` | 1.8.2 | — |
| `curl` | system | — |
| `rg` | system | — |
| `qctl` | **NOT FOUND** | Use `kubectl` |

#### Investigation surfaces (agent-selected)

FBE three-surface rule: pipeline · GitOps · runtime URL. See template for generic surface table.

#### Exemplar commands (reference only)

```bash
kubectl config current-context
kubectl get namespace operations
curl -sS -o /dev/null -w "http_code=%{http_code}\n" "https://operations.dev.vpp.eneco.com/"
kubectl get applications.argoproj.io -n argocd -o wide | rg operations
az pipelines build show --id 1685434 -o json
```

**SNAPSHOT (2026-06-22):** build succeeded; app-of-apps OutOfSync; URL 404 — re-probe before RCA.

### UAC

*Per [template § UAC](../../_templates/slack-intake.template.md#uac). Summarized below for single-file agent use.*

**Done** = all criteria met. Labels: `A1 FACT` · `A2 INFER` · `A3 UNVERIFIED`.

#### Evidence and honesty

| Rule | Requirement |
|------|-------------|
| Context fetched | [Context to fetch](#context-to-fetch-mandatory) done or blocked with fallback |
| Honest probes | RCA lists commands actually run |
| Re-run rule | Snapshots and ledger are not live truth |

#### Learning bar

Deliverables must allow **self-replay** of diagnosis and fix without guessing.

#### Deliverables

| Artifact | Path | Skill |
|----------|------|-------|
| RCA | `output/rca.html` | `rca-holistic` |
| How to fix | `output/how-to-fix.html` | `how-to-feynman` |

HTML is authoritative over markdown working notes.

#### Post-completion: vault and memory

**Mandatory** after fix confirmed and HTML shipped:

1. **`2ndbrain-knowledge-build`** — update vault if durable domain knowledge emerged (e.g. `fbe-errors/`)
2. **`2ndbrain-memory-consolidate`** — episode + lessons to `llm-wiki/` and `.ai/memory/lessons-learned.json`

Task **not complete** until both run when promotable knowledge exists.

#### RCA acceptance

Symptom → context → probes → conclusion; cites prefetch sources; evidence for load-bearing claims.

#### How-to-fix acceptance

Executable steps, verification, rollback; repo/branch/file detail when code changes required.

#### Out of scope for UAC

HTML before probes; markdown-only substitute for HTML; skipping vault/memory when lessons exist.
