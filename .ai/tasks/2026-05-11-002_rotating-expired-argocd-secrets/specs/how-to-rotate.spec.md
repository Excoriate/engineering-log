---
task_id: 2026-05-11-002
agent: claude-opus-4-7
status: draft
summary: Spec — how-to-rotate.md (action-bearing runbook with visuals + PENDING gaps)
phase: 6
---

# Spec — `how-to-rotate.md`

## Purpose (REVISED per user 2026-05-11)

**Mastery-grade documentation**, not a checklist.

After reading + following this runbook ONCE, the reader (Alex on-call) should:
1. **Understand the system** — the 4 PATs, the 3 ArgoCD installs, the auth flow, the silent-failure mechanism, the KV/cluster topology — well enough to explain it to a colleague at a whiteboard.
2. **Execute confidently** — copy-paste the sandbox procedure without re-reading vault notes; understand WHY each command exists, what failure shapes mean, and which anti-patterns to refuse.
3. **Reason about edge cases** — recognise when the procedure does not apply, when to escalate, what to file with Fabrizio/CMC, what a competing controller would look like.
4. **Defend the rotation** — explain to Fabrizio (or a security reviewer) why each verification step is necessary, what hidden assumption it falsifies, what its failure mode is.
5. **Author the next iteration** — once the [PENDING] items resolve, the runbook should self-evidently invite revision (clear placeholders, named gaps, traceable evidence).

The reader is NOT a beginner — Alex is a principal engineer — but Alex is NEW to this procedure (no Eneco engineer has documented it). The doc therefore explains:
- Mechanism (what is happening internally when each command runs)
- Provenance (where each claim comes from — vault, Slack, wiki, IaC, runtime)
- Tradeoffs (why these specific tools/flags vs alternatives)
- Pitfalls (the exact failure mode the step defends against)

This is the Feynman + Linux kernel maintainer + Linus standard — pedagogically clear, structurally rigorous, no fluff.

## Target path

`/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/log/employer/eneco/02_on_call_shift/2026_05_11_rotating_expired_argocd_secrets/how-to-rotate.md`

## Required sections (REVISED per adversarial receipts + user 2026-05-11 mastery-grade directive)

1. **TL;DR — what this doc is + the 4 PATs at a glance** — mermaid V1 (4-PAT topology); 1-paragraph plain-English mission statement
2. **Reader contract** — what this doc promises after one read; pedagogical structure (WHAT/WHY/WHY-THIS-COMMAND/WHAT-TO-EXPECT per step); AI-executor AskUserQuestion gates
3. **The 60-second mental model** — what is a PAT, what is ArgoCD, what is an ApplicationSet, what is `sa_platform_vpp@eneco.com`, why are there 4 separate PATs, what is `goldilocks` — 1 paragraph each, plain English
4. **The system architecture** — diagram + prose explaining:
   - Where the PAT lives (ADO mint → Trade Platform vault → either cluster Secret directly OR an intermediate KV)
   - How ArgoCD uses the PAT (Application controller / repo-server / ApplicationSet generator)
   - The silent-failure mechanism (PAT expires → ApplicationSet auth dies → existing apps survive from etcd → new apps never generated → silent FBE degradation)
   - The four moving parts (PAT lifecycle → alert generator → human rotation → cluster propagation → ArgoCD reconcile)
   - Mermaid V1 + ASCII V5 (silent-failure chain) + new mermaid for ArgoCD auth flow
5. **The 3 ArgoCD installs and their secret patterns** — sandbox (Kustomize+upstream v2.10.5, AKS, namespace `argocd`) / MC (OpenShift GitOps Operator CR, OpenShift, namespace `eneco-vpp-argocd`) / asset-scheduling (Bitnami SealedSecret); EXPLAIN WHY THEY DIFFER and what each difference means for rotation
6. **When to use this runbook** — 5 empirical signatures with mechanism prose (not just signature list)
7. **Pre-execution gates G1-G7** — each gate has a 2-3 sentence rationale; G7 (NEW per S2+S3) is the two-question Fabrizio DM
6. **Section A — Sandbox PAT (`argo-cd-sandbox`)** — 10 numbered steps, each with WHAT / WHY / WHY-THIS-COMMAND / WHAT-TO-EXPECT prose
   - Step 1: Cluster context (with API server FQDN check per V1 HARDEN)
   - Step 2: Identify the repo Secret (anchored repoURL match per V2 HARDEN)
   - Step 3: Mint PAT in ADO UI + post-mint user-identity probe (per V3 HARDEN)
   - Step 4: Curl test BEFORE patching cluster
   - **Step 4.5 (MANDATORY per S1 + V5 REWRITE)**: Ownership-label probe; STOP if controller-managed
   - Step 5: Patch (with AskUserQuestion gate; label-based secret guard not name-based per V2)
   - Step 6: Force-refresh ApplicationSet; watch ErrorOccurred=False with EXTENDED timeout (per V6 HARDEN)
   - **Step 6.5 (MANDATORY per S4 NEW + V5 REWRITE)**: Two-clock verification — `argocd repo get connectionState` + resourceVersion delta + controller log evidence
   - Step 7: Verify child Applications — count + sync + health (per V7 HARDEN)
   - Step 8: Verify URL recovery — body content + pod readiness, NOT headers alone (per V8 REWRITE)
   - Step 9: Document rotation + save new PAT to Trade Platform Team password vault
   - **Step 10 (NEW per V9)**: Revoke the OLD PAT in ADO; confirm by curling old PAT → expect 401
   - Mermaid V2 (sequence diagram)
7. **Section B — MC PATs (`argo-cd-{devmc,accmc,prdmc}-cmc-goldilocks-repository`)** — opens with **DRAFT — DO NOT EXECUTE** banner; opens with the mint-authority decision (per V10 REWRITE)
   - **Step B-0: Disambiguate (PENDING blocks)** — (a) which ArgoCD instance per MC cluster (eneco-vpp-argocd vs openshift-gitops); (b) mint authority (Trade Platform vs CMC); (c) ownership of the repo Secret (Helm? Operator? manual?); (d) Goldilocks application's sync policy
   - **Step B-1A (if Trade Platform mints + Trade Platform applies)**: procedure analog to Section A, adapted for OpenShift (`oc` instead of `kubectl`); same Step 4.5 ownership probe + 6.5 two-clock
   - **Step B-1B (if Trade Platform mints + CMC applies)**: CMC ticket template — names ArgoCD instance + namespace, requires secure-transmission channel (1Password share / KV with ACL — NEVER Slack DM or email per V12 + S3), states SLA expectation, includes post-fulfillment verification probe
   - **Step B-1C (if CMC mints + CMC applies)**: file CMC request with rotation justification; no PAT value to transmit
   - **Step B-X (REMOVED per V11)**: explicitly call out and DELETE the "just update KV" path; explain it is documentation theater because no sync mechanism exists
   - Verify Goldilocks application reconciles — health + sync + manual-sync-trigger-if-needed (per V13 HARDEN)
   - Mermaid V3 (decision-tree for Section B branches)
8. **Post-rotation verification** — pattern doc Step 5+8 quoted, with the V8 REWRITE applied
9. **Anti-patterns** — extended list with prose explanations: do NOT delete and recreate FBE; do NOT restart controllers; do NOT widen PAT scopes; do NOT echo PAT; do NOT skip the curl test; do NOT use personal PAT in cluster; do NOT execute MC without ownership confirmation; do NOT manually apply on Operator-managed Secret; **do NOT update only KV on MC and assume sync (V11)**; **do NOT skip Step 4.5 ownership probe (V5)**; **do NOT skip Step 10 old-PAT revocation (V9)**; **do NOT use Slack DM / email for PAT transmission to CMC (V12+S3)**
10. **Escalation template** — Slack message to `#myriad-platform` + Trade Platform Team password vault update + CMC ticket if MC path
11. **Gap list — ASK FABRIZIO** — extracted, deduplicated, numbered; this is THE deliverable for the user's "questionnaire to Fabrizio" outcome — ASCII V7 with prose context per question
12. **Glossary** (NEW per mastery-grade) — every Eneco-specific term used, plain-English definitions: PAT, ApplicationSet, repo Secret, ArgoCD application of applications, FBE, goldilocks, `sa_platform_vpp@eneco.com`, `vpp-aks01-d`, the 3 MC clusters, OpenShift GitOps Operator, ESO, CSI driver, SealedSecret, Trade Platform Team password vault
13. **Cross-references + evidence ledger** — every claim's source: vault notes, wiki URLs (with page-id), Slack permalinks (with ts), IaC paths (with file:line), this task's adversarial receipts
14. **Closing — durable principles** (NEW per mastery-grade) — 4-5 invariants that survive future tooling changes:
    - "Absence of IaC ≠ absence of reconciler — always probe ownership labels"
    - "ApplicationSet ErrorOccurred=False ≠ credentials are in use — verify the controller's view"
    - "Response headers can be injected by ingress — always check body content + pod readiness"
    - "Single-source claim ≠ FACT — verify before promoting"
    - "Old PAT remains valid until revoked — always revoke after rotation"

## Per-step prose template (MANDATORY for every step per user directive)

Every step in Section A and Section B (when executable) MUST follow this structure:

```markdown
### Step N — <one-sentence headline>

**WHAT this step does** (1-2 sentences):
<plain language description of the operation>

**WHY this step is here** (1-3 sentences):
<purpose — what problem in the procedure this step solves; what would fail without it; where it sits in the dependency chain>

**Command(s)**:
```bash
<commands with copy-paste-able variables>
```

**WHY these specific commands** (2-4 sentences):
<rationale for the tool choices and flags; what alternatives were considered and rejected; specific Eneco-context reasoning where applicable>

**WHAT to expect** (2-4 sentences + observable evidence):
<expected output shape; success signal; time budget; what failure looks like — be specific about exit codes, response shapes, and headers>

**Decision rule**:
<success branch> → continue to Step N+1
<failure branch A> → specific remediation (link to anti-patterns + next-step)
<failure branch B> → STOP + escalate
```

## Pedagogical bar (NEW per user 2026-05-11)

The runbook is intended to PRODUCE MASTERY. After ONE careful read + execution of Section A, the reader should:

1. Be able to draw the 4-PAT topology and the silent-failure chain on a whiteboard from memory.
2. Be able to name and explain the 3 ArgoCD installs and their secret patterns.
3. Be able to explain WHY Step 4.5 exists, WHY Step 6.5 exists, WHY headers alone are insufficient at Step 8.
4. Be able to refuse anti-patterns in real time (delete-and-recreate-FBE, restart-controllers, kubectl-patch-on-Helm-managed-Secret) and explain why.
5. Be able to file the right CMC ticket (with all required fields) without re-reading the template.

**Verification of pedagogical bar**: present 5 hypothetical scenarios at the end of the doc; reader can answer correctly using only the doc:
- Scenario 1: "ApplicationSet shows ErrorOccurred=False but `kubectl get applications.argoproj.io -n kidu` returns nothing. What now?"
- Scenario 2: "You curled the URL, got HTTP 200 + Request-Context. Is the FBE healthy?"
- Scenario 3: "You ran `kubectl patch secret repo-XXXX -n argocd` and the wc -c shows 52. Are you done with Step 5?"
- Scenario 4: "Fabrizio says 'I'll handle the MC rotations.' What do you do next?"
- Scenario 5: "You rotated the PAT but the OLD PAT is still listed in ADO. What's the security exposure?"

## Hard requirements

| Falsifier | Test |
|---|---|
| F1 ≥1 mermaid + ≥1 ASCII diagram | grep ```` ```mermaid ```` + ASCII block markers |
| F2 Section B (MC) has ≥3 explicit `[PENDING: ask Fabrizio]` blocks; each has (a) Q (b) why load-bearing (c) probe-to-resolve | grep + sample-review |
| F3 Each step has a "Decision rule" line + explicit failure mode + remediation pointer (per P5 Q6 tightening) | grep + sample-review |
| F4 Pre-flight gate G5 requires AskUserQuestion before destructive steps (Step 3 mint + Step 5 patch) — explicit instruction to AI executors | grep |
| F5 Step 4.5 Secret-ownership probe included (per P5 Q1 + Socrates S1 + el-demoledor V5) | grep |
| F6 Step 10 covers the old-PAT cleanup (per el-demoledor V9) | grep |
| F7 Section B disambiguates eneco-vpp-argocd vs openshift-gitops (per wiki sidecar) | grep |
| F8 Gap list contains ≥10 numbered questions | count |
| F9 Decision rules pass adversarial review (el-demoledor + Socrates receipts addressed) | per-receipt review |
| F10 No FACT promotion of single-source claims; Agent Laundering guard | sample |
| **F11 (NEW per user 2026-05-11)** Every step has 4 prose blocks: WHAT (what the step does), WHY (purpose; why it's needed at this point in the procedure), WHY-THIS-COMMAND (why these specific tools/flags/probes vs alternatives), WHAT-TO-EXPECT (success signal, observable state, time budget). NO step is a bare command + decision rule. | per-step review |
| **F12 (NEW per user)** Each step's prose is reader-first (Alex's POV): "you will run X. This is because Y. The command uses Z flag because alternatives W are wrong. You'll see output that looks like... if you see ... that means ..." | sample-review |
| F13 (NEW per Socrates S1+S4 + el-demoledor V5+V8) Step 4.5 (ownership probe) + Step 6.5 (two-clock verification) are mandatory and explained in full prose | grep |
| F14 (NEW per el-demoledor V8) Step 8 uses body-content match + pod readiness; headers ALONE are NEVER sufficient evidence | grep |
| F15 (NEW per el-demoledor V11) Section B explicitly DELETES the "just update KV" path; lists it as documentation-theater anti-pattern | grep |
| F16 (NEW per el-demoledor V10) Section B opens with the mint-authority decision branch | grep |
| F17 (NEW per Socrates S3) Section B explicitly names secure-transmission channel (1Password share / KV with ACL), forbids Slack DM / email | grep |
| F18 (NEW per receipts) Section B carries "DRAFT — DO NOT EXECUTE" banner until PENDING blocks (b) and (c) are resolved by Fabrizio | grep |

## AskUserQuestion blocks (mandatory in the document)

The runbook is meant to be readable by both humans and AI executors. AI executors MUST AskUserQuestion before:
- Step 3 (PAT mint) — confirms authority + scope
- Step 5 (Secret patch) — confirms target + irreversibility
- Section B execute-vs-file-CMC-ticket decision

Each block prompts: "Are you authorized to mint a PAT for sa_platform_vpp@eneco.com?" / "Confirm target Secret name and that you have no controller reverting it" / "Confirm whether MC PATs are Trade-Platform-rotated or CMC-operated."

## Non-requirements

- Does NOT cover F4 AAD SP rotation
- Does NOT cover ESP cert / TF SP rotation
- Does NOT propose automation (that's deliverable 3)
- Does NOT execute the rotation — provides commands for Alex to run
