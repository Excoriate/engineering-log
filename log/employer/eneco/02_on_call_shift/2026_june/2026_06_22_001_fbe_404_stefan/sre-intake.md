# FBE 404 — operations slot (sre-intake)

> **eneco-sre handover.** Origin-agnostic intake assembled around the existing
> [`slack-intake.md`](./slack-intake.md) (the `eneco-oncall-intake-slack` harvest) — this file ADDS
> surface classification, the ranked mechanism set, resolved-id probes, and the
> one-way-door safety gates so a **different** agent can troubleshoot/fix without
> re-gathering. **This intake does NOT perform the fix** — it is the dispatch contract for the fix-agent.
>
> Epistemic tags: **A1 FACT** (probe/cmd output, screenshot, or authoritative URL) ·
> **A2 INFER** (named inference chain) · **A3 UNVERIFIED** (gap + the probe that resolves it).
> Non-contradiction ≠ confirmation. **Never fabricate an identifier — it is marked `A3`.**
>
> Evidence sidecars (full detail, repo-relative):
> [`.ai/tasks/2026-06-22-003_fbe-404-stefan-intake/context/slack-harvest.md`](../../../../../../.ai/tasks/2026-06-22-003_fbe-404-stefan-intake/context/slack-harvest.md) ·
> [`.ai/tasks/2026-06-22-003_fbe-404-stefan-intake/context/vault-fbe-knowledge.md`](../../../../../../.ai/tasks/2026-06-22-003_fbe-404-stefan-intake/context/vault-fbe-knowledge.md)

## 1. Classification (eneco-sre spine — done BEFORE any probe)

| Axis | Value | Basis |
|------|-------|-------|
| **Signal origin** | `Slack-Lists` filing (`record_id=Rec0BBM3A9VHR`) | A1 — Lists record URL present. Verbatim filing text **A3 [blocked]** (Lists records not API-readable); the deployment event is A1 via the `#myriad-env-fbe` bot card |
| **Failure surface** | `gitops-argocd` (app-of-apps **OutOfSync + Deleting**, mixed branches) | A1 — screenshot; `classify-incident.sh` score gitops=5 (dominant) |
| **Incident kind / ref** | FBE (Sandbox feature-branch-env) → `surface-gitops-argocd` + `eneco-fbe-troubleshoot` | A1 — slot `operations` + pipeline `2412` + ArgoCD vocabulary |
| **Confidence tier** | **~80% on the CLASS** (a GitOps-layer wedge — stuck finalizer and/or credential gap — caused the 404, **not** a build failure); **lower on the exact sub-mode** (finalizer vs cred-gap vs routing) → intake + falsifier + "taking it" reply, **no fix claim** | rubric |
| **Route** | **Intake (R1)** — handover only. Troubleshoot (R2) is the **fix-agent's** job, after probes + authorization | — |
| **Routed-to skills** | `eneco-fbe-troubleshoot` (probe/fix) · `eneco-context-slack` + `2ndbrain-obsidian` (DONE — see sidecars) · `eneco-oncall-intake-enrich` (if a probe round-trip is needed) | — |

> **Do not close on green build alone.** Build `1685434` reported *succeeded* but its
> **Infra Tests were 2/4 (Total 4 / Success 2 / Failures 2)** — A1, bot card. A green-ish
> build never proves the URL serves (`eneco-fbe-troubleshoot` H-STAGE-1; vault
> `...routing-architecture.md:57-61`).

## 2. Instance manifest (resolved identifiers — no placeholders)

| Key | Value |
|-----|-------|
| `INSTANCE_ID` | `2026_02_22_001_fbe_404_stefan` |
| `FILER` | **Stefan Klopf** — `stefan.klopf@eneco.com`, Slack `U063XG59ZFV` (A1; identified via slot-recreate bot card) |
| `SLACK_LIST_URL` | https://grid-eneco.enterprise.slack.com/lists/T039G7V20/F0ACUPDV7HU?record_id=Rec0BBM3A9VHR |
| `SLOT` / namespace | `operations` |
| `BUILD_ID` | `1685434` |
| `PIPELINE_ID` | `2412` (FBE **create**) |
| `APP_OF_APPS_BRANCH` (target) | `feature/fbe-851436-new-tso-adx-changes` (the 06-19 recreate branch) |
| `CHILD_ASSETMONITOR_BRANCH` | `feature/fbe-806738-mfrr-reference-signal` (**different** branch — A1 screenshot) |
| `PUBLIC_URL` | https://operations.dev.vpp.eneco.com/ |
| `KUBE_CONTEXT` | `vpp-aks01-d` (Sandbox AKS — **direct agent access**, NOT AVD) |
| `ARGOCD_NS` / `APPLICATIONSET` | `argocd` / `vpp-feature-branch-environments` |
| `AZ_SUBSCRIPTION` | `7b1ba02e-bac6-4c45-83a0-7f0d3104922e` (Sandbox) |
| `RESOURCE_GROUP` | `rg-vpp-app-sb-401` |
| `ADO_ORG` / `ADO_PROJECT` | `enecomanagedcloud` / `Myriad - VPP` |
| `AUTO_EVICT_LOGIC_APP` | `vpp-fbe-autodelete-trigger` (RG `rg-vpp-app-sb-401`) — see §6 |
| `VAULT_FBE_PATH` | `$SECOND_BRAIN_PATH/2-areas/work-eneco/eneco-vpp-platform/fbe/` |
| `VAULT_ERRORS_PATH` | `$SECOND_BRAIN_PATH/2-areas/work-eneco/eneco-vpp-platform/fbe-errors/` |
| `ROUTER_SYMPTOM` | `operations FBE 404 pipeline 2412 build 1685434 OutOfSync https://operations.dev.vpp.eneco.com/` |

## 3. Input

### Description

FBE = Feature Branch Environment (fixed Sandbox slot with its own namespace + URL).
The `operations` create pipeline [build `1685434`](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_build/results?buildId=1685434)
(pipeline `2412`) reports **succeeded**, but [operations.dev.vpp.eneco.com](https://operations.dev.vpp.eneco.com/)
returns **404** and services appear undeployed. Request: **restore the FBE to a live state.**

### Original request (verbatim) — A3 UNVERIFIED [blocked]

The filing lives as a Slack **Lists** record (`F0ACUPDV7HU` / `Rec0BBM3A9VHR`), whose field
content is **not retrievable** via the message-oriented Slack MCP tools (every exact-term
search returned zero). **The verbatim text was NOT fabricated.** Resolving path: open the
Lists record in the Slack UI (it may also carry a status/assignee field not visible to the API).

### Deployment event — A1 FACT (from `#myriad-env-fbe` bot card, the real ground truth)

| When (CEST, 2026-06-19) | Event | Evidence |
|---|---|---|
| 12:07:50 | **Terminate** `operations` by `Stefan.Klopf@eneco.com` | [permalink](https://grid-eneco.enterprise.slack.com/archives/C066CGC5VCY/p1781863670573499) (ts `1781863670.573499`) |
| 13:28:42 | **Recreate** `operations` — build `1685434`, URL set, branch `fbe-851436-new-tso-adx-changes`, **Infra Tests 4 / Success 2 / Failures 2** | [permalink](https://grid-eneco.enterprise.slack.com/archives/C066CGC5VCY/p1781868522055889) (ts `1781868522.055889`) |

- **A2 INFER:** the build/URL/user match the incident anchors → this terminate→recreate cycle **is** the event behind the 404 filing. The bot card has **no replies → no owner/resolution attached.**
- **A1 context:** the `operations` slot was recreated repeatedly in this window (Duncan Teegelaar 06-17 build `1681985`; Stefan Klopf 06-18 build `1683302`; Stefan Klopf 06-19 build `1685434`) → churn/orphan risk on slot reuse.

### Known state from attachment (`image.png` — ArgoCD UI snapshot, NOT live truth — re-probe)

- `argocd/operations-app-of-apps`: **`Progressing · OutOfSync · Deleting`**, target `feature/fbe-851436-new-tso-adx-changes`, Path `Helm/vpp-core-app-of-apps`, **Created & Last-Sync `05/27/2026` (23 days stale)** — **A1** (screenshot, re-verified).
- `operations/assetmonitor`: **`Progressing · Synced · Syncing`**, target `feature/fbe-806738-mfrr-reference-signal` (**different branch**), Path `azure-pipeline/Helm/assetmonitor`, Last-Sync `06/19/2026` — **A1**.
- The **`Deleting` badge + 23-day-stale app-of-apps**, despite a 06-19 recreate, reads as a CR **wedged mid-deletion** — **A2** (this is the §4 Rank-1 anchor; the prior `slack-intake.md` did not capture the `Deleting` badge).

## 4. Mechanism hypothesis — ranked (handover predicate 2 — cited)

> Re-ranked against the actual evidence using the vault FBE corpus. **This corrects the
> generic "mixed-branch partial render" story** — that mode produces OutOfSync but gives
> **no reason for a `Deleting` badge**, so it is demoted to an artifact (Rank 4), not the cause.
> Also note (A2, Slack): per Roel van de Grint, ArgoCD `OutOfSync` right after a fresh release is
> "a valid state, not a fail state" → **lean on the 404 + 2/4-infra-fail + `Deleting`, not OutOfSync alone.**

**Primary (Rank 1) — Stuck ArgoCD Application finalizer / app-of-apps frozen mid-deletion.**
**A2 INFER:** the 06-19 terminate left one or more child `Application` CRDs holding
`resources-finalizer.argocd.argoproj.io`; the app-of-apps is wedged with a `deletionTimestamp`
the finalizer cannot complete, so the recreate's sync request reports green while Kubernetes
creates nothing new → the app-of-apps's managed resources never render (the ns can stay `Active` from other syncing children) → ingress has no backend →
**404.** Cites `fbe/eneco-vpp-argocd-finalizer-blocks-feature-branch-deployments.md`
("a green pipeline only proves the request reached ArgoCD … not that Kubernetes accepted the
workload objects", `:46`) + catalog **F3** ("ArgoCD finalizer / sync stuck", `active`) with **F2**
(namespace residue) sibling. **Only this mode explains the `Deleting` badge** — but it does **not**
exclude a *co-firing* Rank 2 (the `operations` slot is a recorded cred-gap victim), so run §5#4 even
after the finalizer is confirmed. Possible trigger →
the auto-eviction Logic App fired destroy-`2629` (§6) on the stale slot ~as Stefan recreated it.

**Competing hypotheses kept LIVE (discriminated in §5):**

- **(Rank 2) Per-Application source-N credential gap.** A child `Application`'s `sources[N]` points
  at a private ADO repo with no covering `repo-creds`; manifest generation 401s
  (`ComparisonError: … source N of M … authentication required`), `selfHeal` cannot rescue it,
  `sync.status=Unknown`, pods never render → 404. **A1: the `operations` slot was a *named victim*
  of exactly this on 2026-05-12** (`fbe-errors/pattern-argocd-per-application-source-credential-gap.md`,
  `2026-05-12-jupiter-source1-credential-gap.md`). It **co-exists** with finalizer issues — the
  strongest live confounder. Ready recipe exists (§7). No F-number assigned (do not invent one).
- **(Rank 3) ArgoCD-sandbox PAT expiry** (ApplicationSet generator dead). **Poor fit** — this mode
  predicts *no* app-of-apps row at all, but ours exists; retained only because PAT rotation can leave
  some repos uncovered and the two credential modes can fire together.
- **(Rank 4, de-emphasized) Mixed-branch partial render** — contributing surface, not generator;
  unexplained `Deleting` badge rules it out as the standalone cause.
- **(Rank 5, low) F12 health-probe typo / F8 stale AppConfig / F20 AKS CPU pressure** — would leave
  pods *present-but-unready*; our snapshot suggests *undeployed*. Hold unless §5#5 shows running pods.

**Not yet a root cause** — every rank above is A2 until the §5 probes run.

## 5. Probes with resolved IDs + falsifiers (handover predicate 3)

Run **read-only** first. FBE Sandbox is **direct agent access** — `kubectl --context vpp-aks01-d`
and the `argocd` CLI (`argosandboxlogin`, then `argo-sick`/`argo-drift`/`argo-why operations-app-of-apps`)
both work without AVD. Confirm the Sandbox subscription before any `az` (§6).

| # | Probe (resolved IDs) | Expected if Rank-1 holds | If instead → |
|---|----------------------|--------------------------|--------------|
| 1 | `kubectl --context vpp-aks01-d get ns operations` | `Terminating` → **F2 namespace-residue compounding** | `Active` does **NOT** reject Rank 1 — a stuck *Application* finalizer commonly leaves the destination ns `Active` (assetmonitor is actively syncing into it); only §5#2 decides |
| 2 **(top discriminator — decides Rank 1)** | `kubectl --context vpp-aks01-d get application operations-app-of-apps -n argocd -o yaml` → read `.metadata.deletionTimestamp`, `.metadata.finalizers`, `.status` | non-empty `deletionTimestamp` + lingering finalizers (the `Deleting` badge ⇒ expected) → **confirms Rank 1** | empty `deletionTimestamp` → reject Rank 1, go Rank 2/3 |
| 3 | `kubectl --context vpp-aks01-d get applicationset vpp-feature-branch-environments -n argocd -o json \| jq '.status.conditions[]? \| select(.type=="ErrorOccurred")'` | `status=="False"` (generator healthy) → Rank 2 candidate | `status=="True"` + `authentication required` → **Rank 3 (PAT expiry)** |
| 4 **(run even if §5#2 confirms Rank 1)** | `kubectl --context vpp-aks01-d get application -n operations -o json \| jq -r '.items[]? \| select((.status.conditions//[])\|map(select(.type=="ComparisonError" and ((.message//"")\|test("source [0-9]+ of [0-9]+";"i"))))\|length>0) \| .metadata.name'` | ≥1 child with `source N of M … authentication required` → **Rank 2 (can co-fire)** | none → reject Rank 2 |
| 5 | `kubectl --context vpp-aks01-d get pods,ingress -n operations` | few/no pods; ingress without backend | pods Running + ingress OK → routing (P7) / Rank 5 |
| 6 **(routing split)** | `curl -svk "https://operations.dev.vpp.eneco.com/" 2>&1 \| grep -iE "Request-Context\|x-correlation-id\|Content-Type"` | 404 **without** those headers (NGINX/AGW, no backend → nothing deployed) | 404 **with** `x-correlation-id` → objects exist, `PathBase`/ingress misaligned → authority is `eneco-howto-fix-activation-mfrr-feature-branch-404` (NOT this intake) |
| 7 | `az pipelines build show --id 1685434 --org https://dev.azure.com/enecomanagedcloud -p "Myriad - VPP" -o json` (+ Timeline) | which **2 of 4 infra tests** failed | a hard-failed stage → build-side class |
| 8 **(trigger check)** | `az logic workflow run list -n vpp-fbe-autodelete-trigger -g rg-vpp-app-sb-401 --top 5 --query "[].{startTime:startTime,status:status}" -o table` | a run firing 2629 near 06-19 13:xx → explains the `Deleting` w/o a human | no recent run → human/other trigger |

> **Probe fidelity note:** #1, #6, #8 are **verbatim** from the vault notes/runbook (paths in the
> sidecar). #3/#4 are the vault probes **hardened** (`-o json` + `[]?` / `(.message//"")`) so an
> absent field is *skipped*, not read as a jq error = false "rejected". #2's `-o yaml` read is the
> vault's named *resolving probe*; the compact `deletionTimestamp/finalizers` jsonpath is
> **assembled from prose (A2)** — prefer the `-o yaml` read as authoritative. (#8: if no rows, fall
> back to `-o json`; `startTime` may be `properties.startTime` on older api-versions.)
>
> **Sequencing (review-hardened):** §5#2 is the decisive Rank-1 test, **not** §5#1 — the ns is
> likely `Active` (a child is syncing into it), which does NOT rule out a wedged Application. Do
> **not** pre-stage finalizer force-removal (§6, destructive) before §5#2 returns. Keep §5#4 even
> after a confirmed finalizer: unsticking it then re-rendering into an uncovered `repo-creds` gap
> re-404s the slot.

## 6. Safety gates (surface-specific — READ BEFORE acting)

- **HALT — destroy pipeline `2629` is NOT a rollback** (vault `pattern-azure-resource-orphan-on-slot-reuse.md:87-90`,
  `fbe-errors/_index.md:25`). It (a) **recursive-F2** — the destroy pipeline's own failures *create* these
  orphans; (b) **F19** — pinned to terraform `1.13.1` vs state written by `1.14.3`; (c) **wipes the slot's
  260+ resources**, escalating blast radius from "one stuck app-of-apps" to "entire FBE wiped". Do **NOT**
  reach for `2629` to "reset" the stuck slot. Requires a human platform-owner to accept residue risk — and it is **not the fix anyway**.
- **HALT — auto-eviction may re-delete the slot mid-fix.** `vpp-fbe-autodelete-trigger` (Sandbox, RG
  `rg-vpp-app-sb-401`) runs **Mon–Fri 14:30 W.Europe**, and for any limiter-table row `active='used'` older
  than **4 days** POSTs pipeline `2629` with **`bypassEnvironmentOwnerValidation=true`** (vault `fbe/fbe-glossary.md:56,76-80`).
  The fix-agent must be aware the `operations` slot could be auto-deleted again while being repaired (and this is a candidate cause of the `Deleting` state — §5#8).
- **HALT — finalizer force-removal is DESTRUCTIVE cleanup, gated on live proof.** Per the finalizer note
  (`:70-73`), force-removing `resources-finalizer.argocd.argoproj.io` / restarting the Argo Application
  Controller is allowed **only after** live checks prove the namespace is genuinely blocked by orphaned
  `Application` CRDs and the managed workloads are already gone. **There is NO paste-able vault recipe for
  this** (gap) — it is doctrine + an admin Controller restart; author the exact commands carefully and get
  explicit authorization. Do **not** redeploy blindly into a `Terminating` namespace (`:65-66`).
- **HALT — do NOT `SYNC` or re-run pipeline `2412` against `operations-app-of-apps` while it carries a
  `deletionTimestamp` (the `Deleting` badge).** A sync into a finalizer-wedged Application reports green
  and renders nothing (the vault's "green pipeline only proves the request reached ArgoCD"). Resolve the
  deletion (finalizer/Controller, gated above) **or let it complete FIRST** — this, not the `Terminating`-ns
  case, is the realistic footgun here since the namespace is likely `Active`.
- **Confirm Sandbox subscription** `7b1ba02e-bac6-4c45-83a0-7f0d3104922e` before any `az`
  (`az account show --query id -o tsv`); never trust the default `az` sub.
- **Tier-1 minimal mutation only**, with explicit current-turn authorization: one targeted sync; do **not**
  batch-disable prune/selfHeal; isolated `KUBECONFIG` per incident. **Never echo PATs/secrets.**
- If the fix turns out to be **Rank 3 (PAT rotation)**, recipe `recipe-rotate-argocd-sandbox-pat.md` has
  gate **G5**: `AskUserQuestion` **before** PAT mint AND **before** the Secret patch (irreversible-class).

## 7. Context to fetch — STATUS (mostly DONE; cited)

| # | Source | Skill | Status / what it gave |
|---|--------|-------|-----------------------|
| 1 | Slack intake thread | `eneco-context-slack` | **DONE** → sidecar `slack-harvest.md`. Verbatim filing **A3 [blocked]**; deployment event **A1**. **Open the Lists record UI** for a status/assignee field (A3 [blocked] via API) before assuming no owner |
| 2 | Second brain (FBE) | `2ndbrain-obsidian` | **DONE** → sidecar `vault-fbe-knowledge.md`. Ranked modes + recipes + safety gates |
| 3 | Wiki / runbooks | `eneco-context-docs` | **A3 — fix-agent if a probe round-trip needed**: FBE Troubleshooting Guide / FAQ (Myriad VPP wiki) |
| 4 | Routing 404 howto | `2ndbrain-obsidian` | **A3 — conditional**: `eneco-howto-fix-activation-mfrr-feature-branch-404` becomes the authority **only if §5#6 returns 404 *with* `x-correlation-id`** (objects exist, path misaligned) |

**Real recipe pointers (verified to exist):**

| Recipe | When |
|--------|------|
| `fbe-errors/recipe-register-missing-credential-template.md` | Rank 2 — register coverage (`argocd repocreds add --core`, reuse existing PAT bytes, **NOT rotate**) |
| `fbe-errors/recipe-rotate-argocd-sandbox-pat.md` | Rank 3 — rotate sandbox PAT (G5 `AskUserQuestion` gates) |
| *(no recipe — GAP)* | **Rank 1 finalizer-unstick** — doctrine only (`...finalizer-blocks...md` + F3 "restart Argo Application Controller"); author commands after §5#1/#2 prove the namespace is genuinely blocked |

## 8. Skills to use (fix-agent, in order)

1. `eneco-fbe-troubleshoot` — **primary authority** (FBE classifier + `route-fbe-symptom.sh`, safety gates, recipes).
2. `eneco-context-repos` — resolve which repo/branch hosts `Helm/vpp-core-app-of-apps` if a branch convergence is needed.
3. `eneco-tools-connect-mc-environments` — only the **Sandbox** `az` sub (FBE GitOps itself is direct AKS, not MC/AVD).
4. Deliverables: `rca-holistic` → `output/rca.html`; `how-to-feynman` → `output/how-to-fix.html`.
5. Post-fix: `2ndbrain-knowledge-build` (→ `fbe-errors/`, esp. **author the missing finalizer-unstick recipe**) + `2ndbrain-memory-consolidate`.

## 9. Tools / CLI(s) (ledger A1, dated 2026-06-22 — from `slack-intake.md`)

- Primary authority: `eneco-fbe-troubleshoot` + the fetched context — not a fixed probe list.
- Identifiers: the §2 manifest only — **do not invent resource names**.
- `kubectl` v1.36.2 (ctx `vpp-aks01-d`) · `argocd` v3.4.4 (`--core` OK; `argosandboxlogin` + `argo-*` aliases) · `az` 2.87.0 + devops 1.0.2 (build `1685434` query OK) · `jq` 1.8.2 · `curl`, `rg` (system) · `qctl` **NOT FOUND** → use `kubectl`.

## 10. Human-decision gates (handover predicate 4)

- **Any GitOps mutation beyond a read** (a sync, a finalizer edit, a Controller restart) → explicit current-turn user authorization.
- **Finalizer force-removal / Application-Controller restart** → authorization + live proof the namespace is genuinely blocked (destructive; §6).
- **PAT mint / Secret patch** (if Rank 3) → `AskUserQuestion` per recipe gate G5.
- **Triggering pipeline `2629`** → platform-owner authorization (residue, 260+ resources) — and it is **not** the corrective action.
- **Severity:** single user (Stefan) blocked on a Sandbox slot → low; but repeated multi-person recreates + a possible auto-evict race → flag if the slot keeps re-breaking.

## 11. Deliverables (UAC) & epistemic ledger

- `output/rca.html` (`rca-holistic`) · `output/how-to-fix.html` (`how-to-feynman`) — HTML authoritative over
  markdown notes; the command list must be the commands **actually run**. Post-fix vault + memory writes.

| Load-bearing claim | Tag |
|--------------------|-----|
| Build `1685434`/pipeline `2412`; **Infra Tests 2/4 failed** | A1 (bot card) |
| `operations` terminated 12:07 → recreated 13:28 on 06-19 by Stefan Klopf | A1 (bot card permalinks) |
| app-of-apps `Progressing·OutOfSync·Deleting`, target `fbe-851436`, 23-day-stale; child `assetmonitor` Synced on `fbe-806738` | A1 (screenshot, re-verified) |
| No one is actively handling / has resolved THIS filing | **A2** — A1 only on *no replies on the bot card*; **A3 [blocked]** on the Lists status/assignee field (check the Lists UI). The "I'm on it" thread is a *separate* ArgoCDSyncAlert-noise incident — do NOT conflate |
| `operations` was a named victim of the source-N credential gap on 2026-05-12 | A1 (vault note) |
| **Rank 1: stuck-finalizer (Deleting) best explains the 404** — does NOT exclude a co-firing Rank-2 cred-gap | **A2** (unprobed — §5#2 + §5#4) |
| destroy-`2629` is not a rollback; finalizer force-removal is destructive | A1 (vault, load-bearing safety) |
| exact root cause / fix | **A3** — pending §5 probes + authorization |
