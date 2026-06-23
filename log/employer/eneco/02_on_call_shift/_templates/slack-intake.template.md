# {{INCIDENT_TITLE}} (Slack intake)

## Derivation header

| Field | Value |
|-------|-------|
| `template_id` | `slack-intake.template.md` |
| `template_version` | `1.0.0` |
| `template_path` | `log/employer/eneco/02_on_call_shift/_templates/slack-intake.template.md` |
| `instance_id` | `{{INSTANCE_ID}}` |
| `filled_date` | `{{FILLED_DATE}}` |

> **Template contract:** [Mandatory context](#mandatory-context) and [UAC](#uac) are defined in the template. Incident-specific values live only in [Instance manifest](#instance-manifest) and [Input](#input).

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

Substitute these keys when deriving an incident intake. Do not invent values absent from intake evidence.

| Key | Placeholder | This instance |
|-----|-------------|---------------|
| `INCIDENT_TITLE` | Short title | `{{INCIDENT_TITLE}}` |
| `INSTANCE_ID` | Incident directory slug | `{{INSTANCE_ID}}` |
| `FILLED_DATE` | ISO date intake rendered | `{{FILLED_DATE}}` |
| `SLACK_LIST_URL` | Lists or thread URL | `{{SLACK_LIST_URL}}` |
| `ATTACHMENT_REFS` | Screenshots / files | `{{ATTACHMENT_REFS}}` |
| `SLOT` | FBE slot or namespace | `{{SLOT}}` |
| `BUILD_ID` | ADO build id (if any) | `{{BUILD_ID}}` |
| `PIPELINE_ID` | Pipeline id (if any) | `{{PIPELINE_ID}}` |
| `PUBLIC_URL` | Symptom URL | `{{PUBLIC_URL}}` |
| `KUBE_CONTEXT` | kubectl context | `{{KUBE_CONTEXT}}` |
| `AZ_SUBSCRIPTION` | Sandbox subscription id | `{{AZ_SUBSCRIPTION}}` |
| `RESOURCE_GROUP` | AKS resource group | `{{RESOURCE_GROUP}}` |
| `PRIMARY_SKILL` | Main troubleshoot skill | `{{PRIMARY_SKILL}}` |
| `VAULT_FBE_PATH` | Second brain FBE notes | `{{VAULT_FBE_PATH}}` |
| `VAULT_ERRORS_PATH` | Second brain error catalogue | `{{VAULT_ERRORS_PATH}}` |
| `SEARCH_TERMS` | Example context-fetch queries | `{{SEARCH_TERMS}}` |
| `ROUTER_SYMPTOM` | String for `route-fbe-symptom.sh` | `{{ROUTER_SYMPTOM}}` |
| `LEDGER_DATE` | Tool probe date | `{{LEDGER_DATE}}` |
| `SNAPSHOT_NOTE` | Point-in-time probe summary | `{{SNAPSHOT_NOTE}}` |

## Input

### Description

{{SYMPTOM_DESCRIPTION}}

{{CAUTION_CALLOUT}}

### Original request (verbatim)

**Status:** Thread harvest **mandatory before investigation** — paste full Lists filing + key replies below after `eneco-context-slack`. Until then, use the paraphrase as **A2 INFER** only.

{{VERBATIM_REQUEST_BLOCK}}

Save harvest to this section (replace paraphrase) or `slack-intake.txt` in this incident folder.

**Attachment refs:** {{ATTACHMENT_REFS}}

- Slack input: {{SLACK_LIST_URL}}

### Known state from attachments

{{KNOWN_STATE_BLOCK}}

## Mandatory context

### Environmental context

| Field | Value |
|-------|-------|
| ADO project | [Myriad - VPP](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP) (`enecomanagedcloud`) |
| FBE slot | `{{SLOT}}` |
| Pipeline build | {{PIPELINE_BUILD_LINK}} |
| Public URL | {{PUBLIC_URL_MARKDOWN}} |
| Sandbox subscription | `{{AZ_SUBSCRIPTION}}` |
| AKS cluster / context | `{{KUBE_CONTEXT}}` / `{{RESOURCE_GROUP}}` |
| ArgoCD UI | [argocd.dev.vpp.eneco.com](https://argocd.dev.vpp.eneco.com) |

**FBE repos** (populate during investigation via `eneco-context-repos`):

| Repo | Role | ADO |
|------|------|-----|
| *(to be populated)* | | |

### Context to fetch (mandatory)

Complete **before** live probes or destructive actions. Record summaries in task notes and optionally `context-prefetch.md` in the incident folder. Label findings `A1 FACT` (sourced), `A2 INFER`, or `A3 UNVERIFIED`.

| # | Source | Skill | What to fetch | Channels / paths |
|---|--------|-------|---------------|------------------|
| 1 | Slack — platform requests | `eneco-context-slack` | Similar open or recent issues, bot cards, thread resolutions | `#myriad-platform` |
| 2 | Slack — team coordination | `eneco-context-slack` | Team context, prior handlers, PR/CICD notes | `#team-platform` |
| 3 | Slack — intake thread | `eneco-context-slack` | Verbatim Lists filing + companion thread | URL from [Input](#input) |
| 4 | Written runbooks / wiki | `eneco-context-docs` | Troubleshooting Guide, FAQ, Operations & Support, domain wiki | Platform-documentation wiki; Myriad VPP wiki |
| 5 | Second brain | `2ndbrain-obsidian` | Known error recipes, prior incidents, canonical notes | `{{VAULT_FBE_PATH}}` · `{{VAULT_ERRORS_PATH}}` |

**Example search terms (this incident):** {{SEARCH_TERMS}}

**Done when:** At least one of (Slack similar case, vault recipe, or docs runbook) is cited in task notes **or** explicitly marked `A3 UNVERIFIED` with reason (e.g. Slack MCP unavailable — manual queries documented per skill).

> **MC access:** Use `eneco-tools-connect-mc-environments` for sandbox login; turn OFF IP whitelisting when done.

### Skills to use

| Skill | Phase | Role |
|-------|-------|------|
| `eneco-context-slack` | **Before investigation** | Mandatory context fetch |
| `eneco-context-docs` | **Before investigation** | Runbooks and wiki |
| `2ndbrain-obsidian` | **Before investigation** | Vault search |
| `{{PRIMARY_SKILL}}` | **Investigation** | Classify symptom, select probes, safety gates, recipes |
| `eneco-context-repos` | Investigation | Repo map, clone freshness |
| `eneco-tools-connect-mc-environments` | Investigation | MC sandbox connectivity |
| `on-call-log-entry` | Throughout | Log directory layout and artifact sequence |
| `rca-holistic` | Deliverables | `output/rca.html` |
| `how-to-feynman` | Deliverables | `output/how-to-fix.html` |
| `2ndbrain-knowledge-build` | **After completion** | Domain knowledge → Obsidian vault (UAC) |
| `2ndbrain-memory-consolidate` | **After completion** | Episode + agent lessons (UAC) |

**Classification gate:** Load `{{PRIMARY_SKILL}}`, run symptom router when applicable (e.g. `route-fbe-symptom.sh` for FBE), record `FAILURE_CLASS`, `ROUTER_STATUS`, and probe plan in task notes. Re-run router after new orthogonal evidence if status is `needs-more-surfaces` or `unknown`.

### Tools or CLI(s)

**Purpose:** Record tool availability and incident identifiers at intake time. **Does not prescribe a fixed probe script** — the agent chooses commands using fetched context and `{{PRIMARY_SKILL}}`.

#### Agent contract

- **Primary authority:** `{{PRIMARY_SKILL}}` (+ fetched context), not this intake's tool list.
- **Identifiers:** Use [Incident identifiers](#incident-identifiers) — do not invent resource names.
- **Evidence:** Label findings `A1 FACT` · `A2 INFER` · `A3 UNVERIFIED`.
- **Ledger vs live:** Ledger and snapshot rows are historical; re-verify at investigation time.
- **Destructive actions:** explicit user authorization per skill safety gates.
- **Record in RCA:** Commands actually run — not a checklist copied from this template.

#### Incident identifiers

| Constant | Value | Notes |
|----------|-------|-------|
| `SLOT` | `{{SLOT}}` | FBE namespace / URL slot |
| `BUILD_ID` | `{{BUILD_ID}}` | Pipeline run (if applicable) |
| `PIPELINE` | `{{PIPELINE_ID}}` | Pipeline id (if applicable) |
| `PUBLIC_URL` | `{{PUBLIC_URL}}` | Symptom URL |
| `KUBE_CONTEXT` | `{{KUBE_CONTEXT}}` | Sandbox AKS |
| `AZ_SUBSCRIPTION` | `{{AZ_SUBSCRIPTION}}` | Sandbox subscription |
| `ADO_ORG` / `ADO_PROJECT` | `enecomanagedcloud` / `Myriad - VPP` | Default `az devops configure` |
| `ARGOCD_NS` | `argocd` | GitOps control plane |

#### Tool availability ledger

*(Point-in-time — re-check at investigation; versions may drift.)*

| Tool | Version (ledger {{LEDGER_DATE}}) | Typical use |
|------|----------------------------------|-------------|
| `kubectl` | {{KUBECTL_VERSION}} | Namespace, pods, ingress, ApplicationSet |
| `argocd` | {{ARGOCD_VERSION}} | Application sync/health (`--core`) |
| `az` | {{AZ_VERSION}} | Pipeline build, timeline, logs |
| `jq` | {{JQ_VERSION}} | JSON parsing |
| `curl` | (system) | Public URL smoke |
| `rg` | (system) | Filter CLI output |
| `qctl` | {{QCTL_STATUS}} | Optional; use `kubectl` if absent |

#### Investigation surfaces (agent-selected)

Probe **orthogonal surfaces** per the primary skill (for FBE: pipeline, GitOps, runtime URL). Skip none that apply to the assigned failure class.

| Surface | Questions | Example tools (not exhaustive) |
|---------|-----------|------------------------------|
| **Pipeline / ADO** | Green build truthful? Stage/task failures? Branch vs slot? | `az pipelines build show`, timeline invoke |
| **GitOps / ArgoCD** | Apps in sync? Mixed revisions? ApplicationSet errors? | `kubectl` Applications, `argocd app get --core` |
| **Runtime / URL** | HTTP status? Pods Running? Ingress correct? | `curl`, `kubectl get pods,ingress` |

#### Exemplar commands (reference only)

```bash
kubectl config current-context
kubectl get namespace "${SLOT}"
curl -sS -o /dev/null -w "http_code=%{http_code}\n" "${PUBLIC_URL}"
kubectl get applications.argoproj.io -n argocd -o wide | rg "${SLOT}"
az pipelines build show --id "${BUILD_ID}" -o json
```

**SNAPSHOT ({{LEDGER_DATE}}):** {{SNAPSHOT_NOTE}}

### UAC

**Done** means every requirement below is satisfied. **Epistemic labels:** `A1 FACT` · `A2 INFER` · `A3 UNVERIFIED`.

#### Evidence and honesty

| Rule | What it means for the agent |
|------|----------------------------|
| Context fetched | [Context to fetch](#context-to-fetch-mandatory) completed or blocked with documented fallback |
| No unverified claims | Root cause requires probe evidence; hypotheses ≤3 with discriminating probes |
| Honest probes | RCA lists commands **actually run** |
| Re-run rule | Intake snapshots and ledger rows are not live truth |

#### Learning bar

When the fix is confirmed, I must **replay diagnosis and repair myself** from deliverables alone. Opaque steps **fail** UAC even if the incident is fixed.

#### Deliverables

Two HTML artifacts under `output/` (relative to incident folder). Markdown working notes are fine; they do not replace `output/*.html`.

| # | Artifact | Path | Skill |
|---|----------|------|-------|
| 1 | Root cause analysis | `output/rca.html` | `rca-holistic` |
| 2 | How to fix | `output/how-to-fix.html` | `how-to-feynman` |

#### Post-completion: vault and memory

**Mandatory after** fix confirmed and deliverables shipped.

| # | Skill | Done when |
|---|-------|-----------|
| 1 | `2ndbrain-knowledge-build` | Applicable vault neighborhood updated if durable **domain** knowledge emerged |
| 2 | `2ndbrain-memory-consolidate` | Episode + lessons in `llm-wiki/` and `.ai/memory/lessons-learned.json` |

Domain vault writes **after** fix confirmation. Agent behavioral lessons via memory consolidation only.

#### RCA acceptance

- Chain: symptom → context fetched → investigation → conclusion
- Cites Slack, vault, or docs where they shortened the path
- Probe evidence for load-bearing claims; rejected routes explained
- If unverified: ≤3 hypotheses with discriminating probes

#### How-to-fix acceptance

- Ordered, executable steps with verification and rollback
- Code/config changes: repo, branch, files, deploy path, success validation

#### Out of scope for UAC

- HTML before investigation
- Markdown-only substitute for `output/*.html` without approval
- Skipping vault/memory when promotable knowledge or lessons exist
