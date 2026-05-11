---
task_id: 2026-05-11-002
agent: claude-opus-4-7
status: complete
summary: Hypothesis state + elimination conditions + what each sidecar would resolve
phase: 4
---

# Hypotheses — current state (mid-P4)

## H1 — Procedure described in Slack history by Fabrizio/Roel

**Hypothesis**: There exist Slack messages (in `#myriad-platform` or adjacent channels) where Fabrizio/Roel posted a multi-step rotation procedure for ArgoCD PATs.

**Current evidence**:
- Vault incident page line 50 — Fabrizio's question `2026-05-11T~12:23Z`: "Has anybody renewed the Pat Token used by the Argocd in Sandbox?" — implies he doesn't have a one-line "yes here's how" answer at hand
- Vault incident page line 67 — Alex's reply: "is there any documentation, or particular caveat that I need to know in advance?" — implies the question of documentation existence is OPEN as of 12:30Z

**Elimination condition**: Slack sidecar finds zero substantive rotation-procedure threads after exhausting search terms.

**State**: PENDING sidecar result. Initial lean: vault evidence suggests **H1 is FALSE** (Fabrizio's own question implies no canonical procedure exists in his memory at the moment of the incident — though there could be one buried in older threads he forgot about).

## H2 — Procedure in ADO wiki

**Hypothesis**: An ADO wiki page (Trade Platform Troubleshooting, FAQ, BTM, etc.) documents the ArgoCD PAT rotation procedure.

**Current evidence**:
- Vault recipe Step 9 mentions Fabrizio's authority but cites no wiki URL
- Vault notes have no wiki citations for rotation procedure
- Vault pattern doc class-level-lesson 4: "rotation cadence is a control surface" implies the team doesn't yet have one — would have been documented if so

**Elimination condition**: Wiki sidecar finds zero matching pages across enumerated wiki spaces.

**State**: PENDING. Initial lean: **H2 is FALSE** with low confidence (wiki might have a stub or a related page that just isn't surfaced in my vault notes).

## H3 — Vault has it (sandbox case)

**Hypothesis**: Vault contains an end-to-end procedure for the sandbox PAT rotation.

**State**: **CONFIRMED for sandbox** (recipe + pattern + incident page; 9 numbered steps, anti-patterns, escalation template, decision rules at each step).

**Important caveat**: vault note is MY OWN PRIOR WRITE — INFER until Slack/wiki/IaC corroborate. If sidecars contradict (e.g., wiki says "use IaC PR, not manual kubectl patch"), vault recipe is INVALID for that env.

## H3' — Vault has it (MC case)

**Hypothesis**: Vault contains an end-to-end procedure for the MC PAT rotations.

**State**: **NOT CONFIRMED for MC**. Vault recipe says "repeat Steps 1-8 against that cluster's ArgoCD" — generic guidance, but does not name:
- The MC cluster (AKS vs OpenShift, name, RG, sub)
- The MC ArgoCD namespace
- The MC secret naming pattern (`repo-*` or different)
- The KV-→-cluster sync mechanism (which the vault recipe assumes is manual patch)

## H4 — Tribal knowledge / partial across surfaces

**Hypothesis**: Procedure is partially in vault, partially in Slack threads, partially in IaC, but no single canonical source exists.

**State**: PARTIALLY CONFIRMED. Vault has sandbox surface. MC surface, KV-→-cluster sync, and PAT-expiry alert generator are all gaps. The 3 IaC repos + 2 wiki spaces + Slack channels MAY collectively cover the gaps, but no one document does.

## H5 (new) — Sync mechanism differs between sandbox and MC

**Hypothesis** (emerged from P2 system-coherence): The sandbox PAT is rotated via direct kubectl patch (per vault recipe). The MC PATs are stored in `vpp-appsec-d` KV (per vault keyvault-secrets) — implying a KV-→-cluster sync mechanism (ESO / CSI / IaC) exists for MC and the rotation operator updates KV, not the cluster Secret.

**Elimination condition**: IaC sidecar finds the actual mechanism for MC and either:
- (a) confirms H5: MC uses ESO/CSI/IaC reading from KV
- (b) refutes H5: MC also uses manual kubectl patch, vault keyvault-secrets list is stale, KV entries are vestigial

**State**: PENDING IaC sidecar. Initial lean: **H5 is TRUE with high confidence** because (i) the existence of named KV entries for MC PATs is implausible if no sync mechanism reads them, (ii) the absence of similar KV entries for the sandbox PAT supports the asymmetry, (iii) the MC ecosystem is more "managed-cloud" style which typically uses ESO patterns.

## H6 (new) — PAT-expiry alert is a Logic App / Function

**Hypothesis**: A Logic App or Function App, deployed somewhere in `enecomanagedcloud` Azure subscriptions, queries the Azure DevOps PAT REST API on a schedule and posts the report to `#myriad-alerts-devops`.

**Current evidence**: None — pure inference. Slack-channel-posting-bots in Eneco context are typically:
- Logic App with Slack connector
- Azure Function with custom HTTP
- Scheduled GitHub Action
- ADO pipeline with curl-to-Slack

**Elimination condition**: IaC sidecar finds the resource OR Slack sidecar finds the post author identity.

**State**: PENDING. Affects automation proposal.

## H7 (new) — "goldilocks" is a specific repo

**Hypothesis**: `cmc-goldilocks-repository` in MC PAT names refers to a literal repo (likely on `dev.azure.com/enecomanagedcloud/...`) containing CCoE policy / version-pinning / managed-cloud bootstrap content.

**Elimination condition**: Wiki sidecar finds a "goldilocks" page OR IaC sidecar finds the repo name in code.

**State**: PENDING. Affects how Section B of `how-to-rotate.md` names the MC repo. If unresolved, `[PENDING: ask Fabrizio: what is the goldilocks repository — name, URL, content?]` becomes load-bearing.

## Decision matrix — what each sidecar result drives

| Sidecar | Result type | Action |
|---|---|---|
| Slack: Q1 procedure FOUND | Procedure quote + author | Cite as source-of-truth in Section A; corroborate vault |
| Slack: Q1 procedure NOT FOUND | Empty | Section A cites vault; `[PENDING: ask Fabrizio for canonical reference]` |
| Slack: Q2 MC rotation HISTORY | Procedure example | Section B cites the example, replaces conjecture with citation |
| Slack: Q2 NOT FOUND | Empty | Section B keeps `[PENDING]` blocks |
| Slack: Q3 alert generator IDENTIFIED | Bot/App name | Automation proposal references concretely |
| Slack: Q3 NOT FOUND | Empty | Proposal `[PENDING]` |
| Wiki: any procedure FOUND | URL + content | Cite as canonical; vault becomes corroborator |
| Wiki: nothing FOUND | Empty | `[PENDING]` per question |
| IaC: H5 sync mechanism FOUND | (ESO/CSI/IaC) name | Section B procedure becomes concrete (update KV not cluster) |
| IaC: H6 alert generator FOUND | Repo path | Proposal references concretely |
| IaC: H7 goldilocks FOUND | Repo + content | Section B + draft both name the repo |

## Counterfactual: if all 3 sidecars return NOT FOUND

Then `how-to-rotate.md` for Section A is fully grounded in vault (still source-cited, declared INFER) + Section B is mostly `[PENDING]` with the candidate-mechanism enumeration. The gap-list grows to ~10 items. **This is an honest valid outcome.** The user's directive was "list pending points so I can ask Fabrizio" — a thorough `[PENDING]` list IS the deliverable in this counterfactual.
