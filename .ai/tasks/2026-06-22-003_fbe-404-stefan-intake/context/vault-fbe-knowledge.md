---
title: Vault FBE knowledge synthesis — FBE 404 operations slot (Stefan intake)
description: Ranked FBE failure-mode synthesis from the eneco-vpp-platform Obsidian vault for the operations-slot 404 incident (Deleting badge + mixed branches + 23-day-stale sync + green build)
type: research
status: complete
agent: general-purpose
summary: Ranks FBE 404 failure modes against the operations-slot evidence (Deleting badge + mixed branches + 23-day-stale app-of-apps + green build). Rank 1 = stuck ArgoCD Application finalizer / app-of-apps mid-deletion (F3/F2, finalizer note) — only mode that explains the Deleting badge; Rank 2 = per-Application source credential gap (operations was a verified victim, no F#); Rank 3 = ArgoCD-sandbox PAT expiry. Includes routing 404 mechanism, the 2629-is-not-a-rollback safety gate, the vpp-fbe-autodelete-trigger Logic App, recipe index, and gaps (no finalizer-removal recipe).
timestamp: 2026-06-22T00:00:00Z
task_id: 2026-06-22-003
slug: fbe-404-stefan-intake
---

# Vault FBE knowledge synthesis — operations-slot 404

## Scope and method

Read-only synthesis from `/Users/alextorresruiz/Documents/obsidian/2-areas/work-eneco/eneco-vpp-platform/`. Every claim below is labeled **Known** (vault note path + quote), **Inferred** (derived from vault facts via named reasoning), or **Assumed** (no vault basis — flagged for live probe). Resolved IDs for this incident: ctx `vpp-aks01-d`, ns/slot `operations`, ApplicationSet `vpp-feature-branch-environments`, subscription `7b1ba02e-bac6-4c45-83a0-7f0d3104922e`, RG `rg-vpp-app-sb-401`.

**Critical orientation fact (Known):** the symptom "URL 404 with a green/partial build" is explicitly **NOT a single F# entry** in the catalog. Two routing rows say so: `fbe/fbe-failure-modes-catalog.md:630` ("URL returns 404 with x-correlation-id header | (not in F#) | See [[eneco-howto-fix-activation-mfrr-feature-branch-404]]") and `fbe/fbe-operations-runbook.md:352` ("URL 404 | (not in F#)"). The 404 is a downstream signal; the cause lives in the ArgoCD/namespace/routing layer. So ranking is by **which upstream mechanism produced the 404**, not by matching "404" to an F-number.

**Discriminator that splits the field (Known):** the snapshot shows `argocd/operations-app-of-apps` **OutOfSync + Progressing + "Deleting" badge**, child `operations/assetmonitor` **Syncing on a different branch**, app-of-apps **last sync 23 days stale (05/27/2026)**, child synced **06/19/2026**. The "Deleting" badge + stuck app-of-apps is the single highest-information signal and only ONE vault note explains it directly.

---

## Ranked failure modes

### Rank 1 — Stuck ArgoCD Application finalizer / app-of-apps mid-deletion (the "Deleting" badge)

1. **Mechanism (Known + Inferred).** An older feature-branch tenancy on the `operations` slot started deletion; one or more child `Application` CRDs kept `resources-finalizer.argocd.argoproj.io` and never completed cleanup, so the app-of-apps (and/or namespace) is stuck mid-delete. ArgoCD/pipeline reports the sync request as accepted (green), but Kubernetes creates nothing new — "a green pipeline only proves the request reached ArgoCD. It does not prove Kubernetes accepted the resulting workload objects" (Known: `fbe/eneco-vpp-argocd-finalizer-blocks-feature-branch-deployments.md:46`). The result is "deceptively clean deployment reporting with zero resulting pods" (Known: same note, line 28-29). **Inferred:** the "Deleting" badge on `operations-app-of-apps` is the UI surfacing of exactly this — an Application carrying a `deletionTimestamp` whose finalizer cannot complete; the 23-day-stale last-sync is consistent with an app frozen at the moment deletion was requested.
   - Source: `fbe/eneco-vpp-argocd-finalizer-blocks-feature-branch-deployments.md` (whole note); catalog entries `fbe/fbe-failure-modes-catalog.md` **F3** (lines 149-167, "ArgoCD finalizer / sync stuck", `recurrence_status: active`) and **F2** (lines 94-145, K8s-namespace sub-class, "pipeline shows green but no pods deploy").

2. **Discriminating probe (Known — commands present in the finalizer note + runbook).** The finalizer note prescribes this exact order (`...finalizer-blocks...md:50-58`):
   ```bash
   # ctx = vpp-aks01-d, slot = operations
   kubectl get ns operations                 # Active vs Terminating
   kubectl get applications.argoproj.io -n argocd | grep operations
   # then inspect the app-of-apps for a deletionTimestamp + lingering finalizers:
   kubectl get application operations-app-of-apps -n argocd -o jsonpath='{.metadata.deletionTimestamp}{"\n"}{.metadata.finalizers}'
   ```
   **Note on fidelity:** the first three lines (`kubectl get ns`, `kubectl get applications ... | grep`) are verbatim from the note/runbook (`...finalizer-blocks...md:52`, `fbe/fbe-operations-runbook.md:227,378`). The fourth line (the explicit `deletionTimestamp`+`finalizers` jsonpath) is **Inferred** — the note says in prose to check "`Application` CRDs with `deletionTimestamp` and remaining finalizers" (`...finalizer-blocks...md:56`) but does **not** give a copy-paste jsonpath; I assembled it from the prose. Confirms-this-mode: namespace `Terminating` OR app-of-apps has a non-empty `deletionTimestamp` with finalizers still present. Rejects-this-mode: namespace `Active` AND app-of-apps has no `deletionTimestamp` (then go to Rank 2).

3. **Fix recipe.** **No dedicated recipe file exists in `fbe-errors/` for the finalizer-unstick action.** The finalizer note gives doctrine only: force-removal of ArgoCD finalizers is "destructive cleanup and should only be used after live checks prove the namespace is genuinely blocked by orphaned `Application` CRDs and managed workloads are already gone" (Known: `...finalizer-blocks...md:70-73`). Operational gist from catalog F3: "Manual restart of Argo Application Controller (admin operation)" (Known: `fbe/fbe-failure-modes-catalog.md:161`; quote "Argo Application Controller needed a small kick to start working" line 157). **Gap flagged** — no paste-able finalizer-removal recipe; this is doctrine + an admin action, not a one-shot recipe.

4. **F-number:** **F3** (primary — "ArgoCD finalizer / sync stuck", `active`), with **F2** as the namespace-residue sibling. The vault explicitly cross-links both F2 and F3 to the finalizer note (`fbe/fbe-failure-modes-catalog.md:145,167`).

### Rank 2 — ArgoCD per-Application source credential gap (operations was a verified victim)

1. **Mechanism (Known).** A child `Application`'s `spec.sources[N].repoURL` points at a private ADO repo with no `Repository` CR and no covering `repo-creds` template; `argocd-repo-server` falls through to anonymous HTTP, ADO returns 401, and the Application records `ComparisonError: ... source N of M: ... authentication required`. "`selfHeal=true` cannot rescue it because manifest generation fails before the controller ever computes a diff" → `status.sync.status = Unknown`, pods never render, URL 404 (Known: `fbe-errors/pattern-argocd-per-application-source-credential-gap.md:24,30,100-104`). **`operations` is named explicitly** among the 8 affected slots in the 2026-05-12 instance (Known: same note line 112 "afi, ionix, ishtar, jupiter, operations, thor, veku, voltex"; blast-radius table line 213).
2. **Discriminating probe (Known — verbatim from the note).**
   ```bash
   # 0. Rule out the PAT-expiry sibling first (ApplicationSet must be healthy for THIS mode):
   kubectl get applicationset vpp-feature-branch-environments -n argocd -o jsonpath='{.status.conditions}' | jq '.[] | select(.type=="ErrorOccurred")'
   #   status=False → candidate for THIS mode ; status=True → Rank 3 (PAT expiry)

   # 1. Does any operations child Application carry the source-N auth error?
   kubectl get application -n operations -o json | jq -r '.items[] | select((.status.conditions // []) | map(select(.type=="ComparisonError" and (.message|test("source [0-9]+ of [0-9]+"; "i")))) | length>0) | .metadata.name'
   ```
   (Probes verbatim from `pattern-argocd-per-application-source-credential-gap.md:171-173` and signatures lines 120-124; I narrowed `-A` to `-n operations` to resolve to this slot.) Confirms: ApplicationSet `ErrorOccurred=False` **and** ≥1 `operations` Application shows `ComparisonError ... source N of M ... authentication required` with `sync.status=Unknown`. Rejects: ApplicationSet `ErrorOccurred=True` (→ Rank 3) or no `source N of M` substring anywhere.
3. **Fix recipe.** `fbe-errors/recipe-register-missing-credential-template.md` — gist (Known, from its description): register the missing project-level `repo-creds` template via `argocd repocreds add --core`, **reusing PAT bytes from an existing working Repository CR Secret** (no new PAT mint); rely on the ~3-min ApplicationSet reconcile + `selfHeal=true` natural cascade (validated "60 → 0 broken Apps in ~2 minutes"). **The fix is register coverage, NOT rotate** (Known: `pattern-...credential-gap.md:24,160`).
4. **F-number:** **none assigned** — the vault states this is "a candidate Fnn entry (TBD which F-number)" (Known: `pattern-...credential-gap.md:223`). Do not invent one.

### Rank 3 — ArgoCD-sandbox PAT expiry blocks new/recycled FBE apps (ApplicationSet generator dead)

1. **Mechanism (Known).** The sandbox-cluster ArgoCD's HTTPS PAT to VPP.GitOps expires; the `vpp-feature-branch-environments` ApplicationSet Git generator silently fails with `ApplicationGenerationFromParamsError: ... authentication required`. Existing app-of-apps survive cached in etcd; newly-created/recycled slots get **zero** child Applications, namespace `Active` but empty, URL 404, pipeline `partiallySucceeded`, Slack "Pester 1/4" (Known: `fbe-errors/pattern-argocd-pat-expiry-blocks-new-fbe-apps.md:25,31-39`).
2. **Discriminating probe (Known — verbatim).**
   ```bash
   kubectl describe applicationset vpp-feature-branch-environments -n argocd | grep -A3 'ErrorOccurred\|ParametersGenerated\|ResourcesUpToDate'
   kubectl get applications.argoproj.io -n argocd | grep operations-app-of-apps   # nothing → app never generated
   ```
   (From `pattern-argocd-pat-expiry-...md:140,166-172`.) Confirms: ApplicationSet `ErrorOccurred=True` with recent `lastTransitionTime` + `authentication required`. Rejects: `ErrorOccurred=False` (→ Rank 2).
   - **Fit caveat (Inferred):** this mode predicts **no app-of-apps row at all** for the slot. Our snapshot shows `operations-app-of-apps` **does exist** (OutOfSync, Deleting) and a child IS syncing — so the pure PAT-expiry signature is a **partial/poor fit**. It stays ranked because the note warns PAT rotation can leave SOME repos covered and others not, and the two credential modes "can fire together" (Known: `pattern-...credential-gap.md:44`).
3. **Fix recipe.** `fbe-errors/recipe-rotate-argocd-sandbox-pat.md` — gist (Known, from description + lines 144-149 of the pattern): mint new PAT for `sa_platform_vpp@eneco.com` (Code Read on VPP.GitOps) → base64-patch the `argocd`-namespace repo Secret `.data.password` → force-refresh ApplicationSet (`argocd.argoproj.io/refresh=hard`) → verify `ErrorOccurred=False`. **AI-executor gate (Known):** recipe gate G5 requires `AskUserQuestion` before PAT mint and before the Secret patch (`recipe-rotate-argocd-sandbox-pat.md` pre-execution gates).
4. **F-number:** **none assigned** (NEW credential-lifecycle class; not in F1-F20). Adjacent F-entries the note links are F4 and F10, which are NOT this (Known: `pattern-argocd-pat-expiry-...md:46-47`).

### Rank 4 — Mixed-branch partial render (the generic "different target branches" story)

1. **Mechanism (Inferred from Known architecture).** App-of-apps targets `feature/fbe-851436-new-tso-adx-changes` while child `assetmonitor` targets `feature/fbe-806738-mfrr-reference-signal`. The routing note establishes that FBE children inherit values from `Helm/<service>/sandbox/values.yaml` and the parent sets `hostnamePrefix` per branch (Known: `fbe/eneco-vpp-sandbox-fbe-request-routing-architecture.md:63-70`). **Inferred:** a parent on a stale branch that never finished reconciling (OutOfSync, 23-day-stale) while a child reconciled on a newer branch yields a half-rendered slot — some children present, the front-door/SPA or ingress objects the app-of-apps owns absent → 404. This is the "generic mixed-branch-partial-render" story the prompt names.
2. **Discriminating probe.** **No vault command is specific to "mixed target branches."** Closest Known probe is the verify decision tree (`fbe/fbe-operations-runbook.md:170-207`): pipeline status → ArgoCD child status (Synced/OutOfSync/Missing) → `kubectl get pods -n operations` → curl for `Request-Context`/`x-correlation-id`. **Gap flagged** — branch divergence per se has no dedicated probe; you read each Application's `spec.source.targetRevision` manually.
3. **Fix recipe.** **No recipe.** Doctrine only: a single sandbox-values file is the source of truth for all FBEs, "fixing one file fixes all of them" (Known: `...routing-architecture.md:70`). Corrective action is to converge the app-of-apps onto the intended branch and let it re-sync — not captured as a paste-able recipe.
4. **F-number:** none (this is the "(not in F#)" 404 routing row). **Inferred** this is the LEAST likely standalone cause because it does not explain the **"Deleting" badge** at all — a mid-deletion app-of-apps is a stuck-finalizer signal, not a branch-mismatch signal.

### Rank 5 (lower-fit, retain for completeness)

- **F12 — health-probe path typo** (`fbe/fbe-failure-modes-catalog.md:395-412`): green pipeline + service never Ready. Probe: `kubectl describe pod` for probe failures. Discriminates from Rank 1 because pods would EXIST but be unready; our snapshot suggests undeployed (no pods), so lower fit. `retired_by_PR-150785`.
- **F8 — per-FBE config not refreshed** (`...catalog:310-327`): produces stale content / 404 if AppConfig wasn't applied; fix = run AppConfiguration FBE pipeline manually. Lower fit — doesn't explain Deleting badge or OutOfSync app-of-apps.
- **F20 — sandbox AKS CPU pressure** (`...catalog:582-600`): pods pending/CrashLoop under 90%+ CPU. Probe `kubectl top nodes`. Possible compounding factor, not the primary cause of a Deleting badge.

---

## Explicit comparison: finalizer-stuck (Rank 1) vs mixed-branch-partial-render (Rank 4)

The prompt asks which better explains "app-of-apps OutOfSync 23 days + undeployed children."

- **The "Deleting" badge is decisive (Known).** Only the finalizer mechanism produces a `deletionTimestamp` on the app-of-apps. The mixed-branch story produces OutOfSync (Git ≠ cluster) but gives **no reason for a Deleting badge**. The badge means the object was asked to delete and a finalizer is blocking it — `fbe/eneco-vpp-argocd-finalizer-blocks-feature-branch-deployments.md` is the only note that maps this exact signal.
- **23-day-stale last-sync fits "frozen mid-deletion" (Inferred)** better than "actively rendering wrong branch": a Progressing app that is genuinely reconciling would show recent sync attempts; 23 days of no successful sync while showing Progressing+Deleting reads as "wedged on a finalizer," consistent with F3's "Argo Application Controller hung" (Known: `...catalog:159`).
- **The child syncing on a newer branch is the partial-render artifact, not the root cause (Inferred).** Per F3/F2, a stuck parent can leave individual children in mixed states; the divergent child branch is a symptom of an app-of-apps that never converged, not an independent failure.
- **Conclusion (Inferred):** finalizer-stuck (Rank 1, F3/F2 class) is the better single explanation. Mixed-branch is a contributing surface, not the generator. **Confounder to keep live:** Rank 2 (per-Application credential gap) independently hit the `operations` slot in the vault's record and can co-exist; if `kubectl get ns operations` returns `Active` (not Terminating) and the app-of-apps has no `deletionTimestamp`, pivot from Rank 1 to Rank 2.

---

## Why the URL 404s (routing)

Known, from `fbe/eneco-vpp-sandbox-fbe-request-routing-architecture.md`:

- Five-layer path: DNS (`*.dev.vpp.eneco.com` → AGW public IP `20.76.210.221`) → AGW WAF_v2 (pass-through in dev, single backend = NGINX LB `50.85.91.121`) → NGINX Ingress (host + longest-path-prefix match, no path rewrite) → ClusterIP Service → Pod (Kestrel 8080, `PathBase` from Azure App Configuration) (lines 34-44).
- **A 404 means a layer ArgoCD does not test failed.** "ArgoCD does not exercise the end-to-end path from the internet to the pod... The failure always lives in a layer ArgoCD does not test" (Known: lines 59-61).
- **For THIS incident (Inferred):** if the app-of-apps never finished deploying (Rank 1) or children never rendered manifests (Rank 2/3), then no `Ingress`/`Service`/`Pod` objects exist for `operations` → NGINX has no matching ingress → 404. This is the "undeployed services" branch, distinct from the activation-mFRR case where objects exist but `PathBase`/ingress-path are misaligned. The catalog routes a 404-with-`x-correlation-id` to `[[eneco-howto-fix-activation-mfrr-feature-branch-404]]` (Known: `...catalog:630`); that howto note was **not in my read set** (see Gaps). A response from the pod carries `Request-Context` + `x-correlation-id`; a 404 WITHOUT those headers came from NGINX/AGW (no backend) — i.e., nothing deployed (Known: `...routing-architecture.md:44`, runbook `:238-240`). **Probe (Known, runbook:238):** `curl -svk "https://operations.dev.vpp.eneco.com/" 2>&1 | grep -iE "Request-Context|x-correlation-id|Content-Type"` — absence of those headers on the 404 supports the undeployed-services hypothesis (Ranks 1-3) over a PathBase routing typo.

---

## Safety gates from vault

1. **Destroy pipeline 2629 is NOT a rollback (Known — explicit, load-bearing).** `fbe-errors/pattern-azure-resource-orphan-on-slot-reuse.md:87-90`: "**Do NOT trigger pipeline 2629 (destroy) as rollback**" for three reasons: (a) "Recursive F2 risk — the destroy pipeline's historic failures ARE the cause of these orphans"; (b) "F19 risk — destroy pipeline pinned to terraform 1.13.1, state may be written by 1.14.3"; (c) "Destroy would also delete the in-flight slot's other 260+ resources, escalating the blast radius from 'one orphan' to 'entire FBE wiped'." The `fbe-errors/_index.md:25` names this anti-pattern at the top level: "never trigger destroy pipeline as rollback." **Directly relevant:** an operator looking at a stuck/Deleting `operations` app-of-apps must NOT reach for 2629 to "reset" it.
2. **Finalizer force-removal is destructive cleanup, gated on live proof (Known).** `...finalizer-blocks...md:70-73`: force-removal "should only be used after live checks prove the namespace is genuinely blocked by orphaned `Application` CRDs and managed workloads are already gone." Also `:65-66`: "Do not redeploy blindly into a terminating namespace."
3. **"pipeline succeeded" ≠ "deployment succeeded" (Known).** `...finalizer-blocks...md:62`; reinforced by `...routing-architecture.md:57-61`. Green build is not evidence of a working slot.
4. **PAT-rotation recipe AI-executor gate (Known).** `recipe-rotate-argocd-sandbox-pat.md` gate G5: `AskUserQuestion` before PAT mint AND before Secret patch (credential changes are irreversible-class).
5. **Don't delete/recreate the FBE as a reflex (Known).** Both credential patterns warn it lands in the same broken state and risks F19 on the destroy side (`pattern-argocd-pat-expiry-...md:156`; `pattern-...credential-gap.md:162`).

### Auto-eviction Logic App (Known)

- `vpp-fbe-autodelete-trigger` (Sandbox sub, RG `rg-vpp-app-sb-401`): runs **Mon-Fri 14:30 W. Europe**, queries the limiter table for `active eq 'used'` rows whose `Timestamp` is **older than 4 days**, and for each match POSTs ADO pipeline **2629** with `bypassEnvironmentOwnerValidation=true`. "Sole authoritative source for FBE timestamp TTL = 4 days" (Known: `fbe/fbe-glossary.md:56`; TTL FACT also line 140, from Logic App `Set_variable.value = "@addDays(utcNow(), -4)"`). Two sibling Logic Apps: `vpp-fbe-delete-handler` (Mon-Fri 14:06 UTC, Slack "still using {env}?" prompts) and `vpp-fbe-deletion-trigger` (HTTP from Slack "No" button → posts 2629 with bypass) (Known: `fbe/fbe-glossary.md:76-80`).
- **Inferred relevance:** if the `operations` slot row has sat `active=used` >4 days, the autodelete Logic App may itself have **triggered the 2629 destroy** that left the app-of-apps in the "Deleting" state. Probe (Known, runbook:388-390): `az logic workflow run list -n vpp-fbe-autodelete-trigger -g rg-vpp-app-sb-401 --top 5 --query "[].{startTime:startTime,status:status}" -o table`. This is a strong candidate explanation for HOW the app-of-apps entered deletion without a human running 2629.

---

## Recipe index (path -> gist)

| Recipe path | Gist (corrective action — do NOT execute here) |
|---|---|
| `fbe-errors/recipe-register-missing-credential-template.md` | Register a project-level ADO `repo-creds` template in ArgoCD via `argocd repocreds add --core`, reusing PAT bytes from an existing working Repository CR; rely on ~3-min reconcile + selfHeal cascade. For per-Application `source N of M: authentication required`. (Rank 2 fix.) |
| `fbe-errors/recipe-rotate-argocd-sandbox-pat.md` | Mint new PAT for `sa_platform_vpp@eneco.com` → base64-patch argocd-namespace repo Secret `.data.password` → force-refresh ApplicationSet → verify `ErrorOccurred=False`. G5 gate: AskUserQuestion before mint and before patch. (Rank 3 fix.) |
| `fbe-errors/recipe-resolve-apply-time-resource-already-exists.md` | For Stage-3 terraform "already exists - needs to be imported": delete the empty/inert orphan in Azure after inertness checks, re-run the create pipeline; NEVER use 2629 as rollback. (Not this incident — no terraform apply failure reported; included for the safety-gate provenance.) |
| `fbe-errors/recipe-resolve-nu1902-nu1903-build-failure.md` | ⚠️ status: review — do NOT execute Route A/B as written (adversarial-rejected). Symptom-ID only for Stage-5 Docker `dotnet restore` NU1902/NU1903. (Not this incident.) |
| (no recipe) finalizer-unstick | **GAP** — no paste-able recipe for removing a stuck ArgoCD Application finalizer / kicking the Application Controller. Doctrine in `fbe/eneco-vpp-argocd-finalizer-blocks-feature-branch-deployments.md` + F3 ("restart Argo Application Controller"). (Rank 1 — the most-likely mode has no one-shot recipe.) |

---

## Gaps

- **No finalizer-removal recipe (HIGH).** The single most-likely mode (Rank 1, the Deleting badge) has only doctrine, not a paste-able recipe. The destructive force-removal of `resources-finalizer.argocd.argoproj.io` is gated behind live proof but the exact commands are not in the vault read set. Resolving probe: live `kubectl get application operations-app-of-apps -n argocd -o yaml` to read finalizers + deletionTimestamp, then decide.
- **`eneco-howto-fix-activation-mfrr-feature-branch-404` not read.** Both the catalog and runbook route a bare-404 to this howto (`...catalog:630`, runbook:352). It lives in `eneco-howto/` (outside my `fbe/`+`fbe-errors/` scope) and was not in the priority list. If the live curl shows a 404 **with** `x-correlation-id` (object exists, path misaligned) rather than without, that howto — not this synthesis — is the authority. Resolving probe: read that note.
- **`eneco-vpp-argocd-healthy-but-unreachable-troubleshooting` not read.** It is the generalized triage pattern the routing note repeatedly defers to; out of priority scope. Relevant if curl returns 200-SPA-catchall instead of 404.
- **`fbe-creation-lifecycle-deep-dive` and `fbe-live-deployed-state` not read in full.** "What healthy looks like" baselines (live state 2026-05-07: 10/10 slots used, twin-namespace pattern) are summarized only via the index; not load-bearing for ranking but would sharpen the "undeployed vs partially-deployed" call.
- **The `feature/fbe-851436` and `feature/fbe-806738` branches are not referenced anywhere in the vault** (no Known mapping of these specific branch names to incidents). The mixed-branch reasoning is Inferred from architecture, not from a recorded incident.
- **No vault note maps the literal "Deleting" UI badge to a probe command.** The badge → finalizer inference is sound (Inferred) but the jsonpath to read `deletionTimestamp` is assembled by me, not quoted from a note.
