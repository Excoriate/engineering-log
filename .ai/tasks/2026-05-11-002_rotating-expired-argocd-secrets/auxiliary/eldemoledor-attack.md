---
task_id: 2026-05-11-002
agent: el-demoledor
status: complete
summary: Adversarial attack on Decision Rules and counter-example construction
phase: 5
---

# El Demoledor — Adversarial Attack on `how-to-rotate.md` Decision Rules

**Target**: Decision rules embedded in Section A (sandbox PAT rotation, 9 steps adapted from vault recipe) + Section B (3 MC PATs, speculative procedure)
**Scope**: Full (CRUBVG=8, action-bearing rotation of live credentials)
**Method**: Construct concrete counter-example per Decision Rule where the success-branch fires while operational outcome is FAILURE. Cite artifacts. No hedging. Verdicts mandatory.

**Evidence basis**: `context/vault-extracts.md` (recipe quotes), `context/iac-secret-templates.md` (Helm chart smoking gun), `context/wiki-rotation-search.md` (two-ArgoCD-per-MC topology), `context/slack-rotation-harvest.md` (Fabrizio "no doc" + Roel CMC hint), `plan/plan.md` (Q1/Q5/Q6 hypotheses).

---

## DESTRUCTION SUMMARY

| Metric | Count |
|---|---|
| Decision Rules attacked | 13 (9 Section A + 3 Section B + 1 NEW) |
| EXPLOIT-VERIFIED | 4 |
| PATTERN-MATCHED | 7 |
| THEORETICAL | 2 |
| HOLD verdicts | 0 |
| HARDEN verdicts | 9 |
| REWRITE verdicts | 4 |
| Highest-severity finding | V5 (kubectl patch reverted by Helm reconcile on MC) — silent regression mid-rotation |

---

## SECTION A — SANDBOX DECISION RULES

### V1 — Step 1 "Anything other than `vpp-aks01-d` context → STOP" — [EXPLOIT-VERIFIED]

**Decision Rule**: `vault-extracts.md:45-47` Expected: `vpp-aks01-d`. Visuals draft `visuals-draft.md:128-132` says "NO → STOP. Fix context first."

**Counter-example (concrete)**: Alex runs `kubectl config current-context` and gets the literal string `vpp-aks01-d` — but the kubeconfig has a context-name shadowing a stale cluster endpoint. Specifically: Alex previously had access to a now-decommissioned sandbox cluster also named `vpp-aks01-d` in a different RG/subscription (Eneco retired and re-created `vpp-aks01-d` once; precedent in IaC sidecar `iac-secret-templates.md:171` "search bounded to local clones... drift possible"). The kubeconfig caches the OLD cluster's `server:` URL + AAD token. `az aks get-credentials --overwrite-existing` from `vault-extracts.md:44` is supposed to refresh — but if Alex skips that command (it's in the same code block as `az account set`, easy to copy-paste only the bottom line), the context name matches while the API server endpoint resolves to a dead/wrong IP. `kubectl` may even succeed against a different live cluster if the IP got reassigned within Azure.

**Plausibility**: POSSIBLE — copy-paste truncation is the modal sandbox-recipe failure mode; cluster recreation in dev environments is normal at Eneco (per `iac-secret-templates.md` Q6 the MC clusters are independently provisioned per-env, similar churn likely for sandbox).

**Detection delay**: 30s-5min. Step 2 secret enumeration may return zero or unfamiliar secrets, but if Alex's recent dev work had a similar `repo-*` pattern in the wrong cluster, he proceeds to Step 3 carrying false confidence. Worst case: Step 5 patch executes against the wrong cluster — and the recipe gives no signature to detect it.

**Mitigation (one sentence)**: Add an additional probe after Step 1: `kubectl cluster-info | grep "https://"` AND `kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'`, both must match the AKS API server FQDN expected for `vpp-aks01-d` (e.g., resolved via `az aks show -n vpp-aks01-d -g $AKS_RG --query fqdn -o tsv`).

**Counter-hypothesis**: Safe if Alex always runs the full vault recipe block (lines 43-46 inclusive) so `--overwrite-existing` refreshes the cached endpoint. Favor vulnerability because copy-paste discipline is a tradition, not a guarantee; recipe `vault-extracts.md:45` puts the verify (`current-context`) AFTER the get-credentials, but does NOT verify the API server endpoint.

**Verdict**: **HARDEN**.

---

### V2 — Step 2 "Find the row whose URL contains `VPP.GitOps`" — [EXPLOIT-VERIFIED]

**Decision Rule**: `vault-extracts.md:53-58` loop emits all `argocd.argoproj.io/secret-type=repository` secrets; Alex picks the one with `VPP.GitOps` in URL. Visuals `visuals-draft.md:135-137` says "exactly 1 match".

**Counter-example (concrete)**: The Helm chart at `iac-secret-templates.md:36-51` proves that **multiple repository-typed Secrets exist** in `eneco-vpp-argocd` (e.g., the `acr-helm` OCI Helm Secret). On sandbox the namespace is `argocd` (per `vault-extracts.md:36` + recipe context), but `iac-secret-templates.md:9-19` documents **three distinct repo-secret patterns** existing across the platform. Concretely: sandbox cluster may legitimately have BOTH a `repo-NNNN` Opaque for VPP.GitOps **AND** an `acr-helm` Secret for ACR OCI. Alex's grep for `VPP.GitOps` returns 1 match — but what if a developer previously added a SECOND repo secret pointing at `https://dev.azure.com/enecomanagedcloud/VPP.GitOps.OldFork` (a forked repo containing `VPP.GitOps` substring) for a one-off experiment that was never cleaned up? Step 2's substring match is non-anchored; URL containing `VPP.GitOps` matches both. Loop returns 2 rows. Recipe assumes exactly 1.

**Additionally**: ADO URLs can be URL-encoded as `VPP%2EGitOps` or `Myriad%20-%20VPP/_git/VPP.GitOps` — the recipe does the base64-decode at `vault-extracts.md:54` but does NOT case-normalize. If Helm-rendered values capitalized differently than what dev mind-models say, lookup fails silently.

**Plausibility**: LIKELY for the multi-match case (sandbox cluster has accumulated state since v2.10.5 install; Helm chart `iac-secret-templates.md:36` proves at minimum the acr-helm secret coexists in eneco-vpp-argocd ns — same pattern likely on argocd ns); POSSIBLE for URL encoding.

**Detection delay**: 0s (Alex sees 2 rows) → 5-30s (decides which is right). If both have `username: sa_platform_vpp@eneco.com`, he has no disambiguator and may guess wrong → Step 5 patches the wrong Secret → Step 6 reports "still ErrorOccurred" → 2-10 min lost diagnosing. WORST CASE: he picks one, it happens to also fail for the same expired-PAT reason, he proceeds to Step 5, patches the wrong one with the new PAT — and ApplicationSet still fails because the secret it actually consults is unchanged.

**Mitigation**: Step 2 MUST require exact match against ApplicationSet's `repoURL` field: `kubectl get applicationset vpp-feature-branch-environments -n argocd -o jsonpath='{.spec.generators[*].git.repoURL}'` → this is the EXACT URL ArgoCD looks up; pick the Secret whose `url` field byte-equals this value (after base64 decode). Refuse to proceed if 0 or 2+ matches.

**Counter-hypothesis**: Safe if sandbox has exactly one VPP.GitOps repo Secret in clean steady state. Favor vulnerability because `iac-secret-templates.md:172` explicitly warns drift is possible — and the same vault recipe didn't probe for drift either.

**Verdict**: **HARDEN** (move to anchored equality match against ApplicationSet repoURL).

---

### V3 — Step 3 "Mint PAT under sa_platform_vpp, Code Read, +1y" — [PATTERN-MATCHED]

**Decision Rule**: `vault-extracts.md:70-78`: sign in as SA → New Token → `argo-cd-sandbox-YYYY-MM-DD` → enecomanagedcloud → 1y → Code Read.

**Counter-example (concrete)** — four destructive paths:

1. **SA password unknown** (Slack harvest `slack-rotation-harvest.md:73-78` says SA creds live in Trade Platform Team password vault — 1Password-style; if Alex's vault access is revoked or 2FA device unavailable at the moment, he hits a wall mid-rotation).
2. **SA MFA blocks login** (`sa_platform_vpp@eneco.com` is an account; Eneco AAD policy may require MFA registration; SA is shared — MFA token registration is likely on someone else's device, e.g., Fabrizio's. Alex calls Fabrizio at 3 AM scenario: SA MFA = single point of failure).
3. **Personal-PAT-by-mistake**: `vault-extracts.md:72` says "If you are NOT impersonating sa_platform_vpp" — but Alex's ADO session may be unstickly tied to his personal account; ADO `/_usersSettings/tokens` page shows tokens of whoever is signed in. He clicks "New Token", forgets to verify the user picker (top-right corner), mints a PAT under his personal account `atorres.ruiz@hotmail.com`. Step 4 curl test PASSES (Alex has Code Read on VPP.GitOps too — he's a dev on the project!). Step 5 patches the Secret with Alex's personal PAT. Step 6 → ErrorOccurred=False → Step 8 → all green. **Six months later, Alex leaves Eneco, his AAD account is disabled, ArgoCD breaks across all sandbox FBEs with the same 401 — but now no Slack alert because the monitoring pipeline only watches sa_platform_vpp PATs (per `iac-secret-templates.md:140` "the script only checks the PAT tokens that belongs to the service account itself"). The break is silent until a developer triggers FBE-create. RECURSION of the original incident.
4. **PAT scope leakage**: "Code Read" in ADO is per-organization, not per-repo. A Code Read PAT minted under sa_platform_vpp grants read access to ALL repos in `enecomanagedcloud` org that sa_platform_vpp has access to (likely hundreds — Asset.*, MC-VPP-Infrastructure, devops, VPP.GitOps, Myriad - VPP project, etc.). Scope is wider than what the cluster needs. Leak surface is the entire org's code.

**Plausibility**: (1) POSSIBLE; (2) LIKELY in off-hours scenario; (3) **LIKELY** — UI-state confusion is the modal failure for SA PAT minting; (4) EDGE-CASE for active exploit, LIKELY for compliance audit findings.

**Detection delay**: (3) is the most dangerous — months to years until Alex's account is disabled. (4) zero detection unless org has secret-scanning / DLP.

**Mitigation**: Step 3 MUST require a post-mint probe BEFORE Step 4: `curl -sH "Authorization: Basic $(echo -n :$NEW_PAT|base64)" "https://dev.azure.com/enecomanagedcloud/_apis/connectionData?connectOptions=includeServices&api-version=7.1" | jq -r '.authenticatedUser.providerDisplayName'` — must equal `sa_platform_vpp@eneco.com`, else ABORT and revoke. Additionally: scope restriction is impossible in ADO PAT UI (Code Read is org-wide), so this is structurally `[PENDING: ask Fabrizio]` — propose Workload Identity Federation as automation alternative.

**Counter-hypothesis**: Safe if Alex always remembers to verify user-picker in ADO. Favor vulnerability because (3) has been the exact failure mode in adjacent contexts at Eneco — `slack-rotation-harvest.md:137` quotes Fabrizio post-INC-75: "This manual process is error-prone and must be automated."

**Verdict**: **HARDEN** (add user-identity probe; flag scope-leakage as `[PENDING]` for proposal doc).

---

### V4 — Step 4 "curl with new PAT → HTTP 200" — [PATTERN-MATCHED]

**Decision Rule**: `vault-extracts.md:84-89`: `curl -sI -u ":${NEW_PAT}" "${URL}/info/refs?service=git-upload-pack"` → HTTP 200 means PAT works.

**Counter-example (concrete)** — three destructive paths:

1. **Egress proxy interferes**: Eneco corporate egress may route `dev.azure.com` through a proxy that strips/rewrites `Authorization` headers, or returns a 200 cached response from a different request (rare but documented for some MITM-style corporate proxies). Curl from Alex's laptop returns 200 because of a proxy cache hit on the public `/info/refs` endpoint (Azure DevOps allows anonymous read on some `_apis/git` paths if repo is public-readable). PAT is never actually validated.
2. **Network DNS to dev.azure.com fails**: Egress firewall blocks; curl returns connection error; Alex retries; second attempt happens to coincide with `.azconfig` redirect or a temporary DNS-rebinding-protection state; reads stale 200 from local resolver. UNLIKELY but POSSIBLE.
3. **The PAT-curl test uses Alex's laptop network, but the CLUSTER curls from a different egress** (AKS managed cluster may have firewall rules / NAT gateway / Azure-native egress with IP allowlists at dev.azure.com side). PAT works from laptop, fails from cluster. ArgoCD repo-server is the actual consumer; if its egress IP isn't on the SA's PAT IP-allowlist (ADO supports IP-restricted PATs as an org policy), 401 from cluster while curl shows 200.

**Plausibility**: (1) EDGE-CASE; (2) EDGE-CASE; (3) **POSSIBLE** — Eneco may run IP-allowlisted SA PATs as a security control; not documented in any harvest but absence-of-evidence ≠ evidence-of-absence.

**Detection delay**: (3) 30-90s — Step 6 watch loop times out at ErrorOccurred=True; Alex re-runs Step 4, sees 200 from his laptop, concludes "PAT is fine, must be something else". Burns 10-30 min before noticing the asymmetry.

**Mitigation**: Add a post-Step-5 in-cluster probe BEFORE Step 6: `kubectl run -n argocd --rm -it pat-test --image=curlimages/curl --restart=Never --command -- curl -sI -u ":$NEW_PAT" "$URL/info/refs?service=git-upload-pack"` — same curl, but from the cluster's egress. If cluster curl returns 401 while laptop curl returned 200 → ABORT, PAT has IP/network restriction.

**Counter-hypothesis**: Safe if Eneco does not use IP-restricted PATs; this is `[PENDING: ask Fabrizio]`. Favor vulnerability because it's a known ADO feature; absence is unverified.

**Verdict**: **HARDEN** (cluster-egress probe added).

---

### V5 — Step 5 "kubectl patch replaces /data/password; wc -c = 52" — [EXPLOIT-VERIFIED] — **HIGHEST-STAKES**

**Decision Rule**: `vault-extracts.md:93-110` patches Secret in-place; verifies length by `base64 -d | wc -c`.

**Counter-example (concrete) — THE smoking gun**: `iac-secret-templates.md:35-51` proves that on the **MC clusters' `eneco-vpp-argocd` namespace**, repository Secrets are **rendered by a Helm chart** (`myriad-vpp/ArgoCD-Config/Helm/repositories/templates/deployment.yaml`) with `name`, `username`, `password` materialized from `.Values`. The chart is applied via the pipeline. Now: if the SAME Helm chart pattern is used on the sandbox cluster (the recipe `vault-extracts.md` assumes it's NOT, but `plan/plan.md:34-44` Q1 explicitly marks this as the load-bearing assumption), then:

1. Alex runs `kubectl patch secret repo-NNNN -n argocd` — succeeds immediately. `wc -c` shows 52. 
2. ApplicationSet auth recovers within 90s. Step 6 reports SUCCESS.
3. Step 7-8 all green. Alex closes the incident.
4. **30 minutes to 24 hours later**, the next Helm/ArgoCD reconcile cycle runs on the `ArgoCD-Config` Application (the meta-app that manages the repository Secret). It re-renders the Helm template from `.Values` — which still contains the OLD PAT (or a placeholder, per `iac-secret-templates.md:52` "real values are pipeline-overridden"). Helm reconcile pushes the OLD Secret back into `argocd` namespace. ApplicationSet starts failing again with the same 401 — but now Alex is gone, alarm-fatigued, or the next on-call has no context.

Even WORSE: the patch may survive on `argocd` namespace (sandbox) because the Helm chart targets `eneco-vpp-argocd` namespace (MC). But on MC, this is a guaranteed regression. **Section B's most dangerous failure**: Alex picks up the runbook for devmc PAT and applies a kubectl patch — wins in 90s — loses in 30min when the pipeline reconciles.

Additional vector: **OpenShift GitOps Operator on MC owns the ArgoCD CR** (`iac-secret-templates.md:99-103`). The operator may revert any Secret in the operator's watched namespace if the Secret is referenced in `spec.repo.repositories` — this is operator-class behavior, not Helm.

**Plausibility**: (Helm revert on MC) **LIKELY** — Helm chart exists at `iac-secret-templates.md:36-51`, namespace matches MC ArgoCD; (Operator revert) **POSSIBLE** — depends on operator config, `[PENDING: ask Fabrizio]`; (Sandbox Helm revert) POSSIBLE per plan.md Q1.

**Detection delay**: 5min - 24h depending on reconcile interval. **The runbook's success signal (Step 6 ErrorOccurred=False) is FALSE-POSITIVE because the controller hasn't done its reconcile cycle yet.** This is a textbook silent-fail.

**Mitigation**: Step 5 MUST be preceded by a Step 4.5 ownership probe: `kubectl get secret $ARGOCD_REPO_SECRET -n $NS -o jsonpath='{.metadata.labels.app\.kubernetes\.io/managed-by}{.metadata.annotations.argocd\.argoproj\.io/instance}{.metadata.annotations.helm\.sh/release-name}'`. If ANY of those fields is non-empty → ABORT kubectl-patch path; switch to "update upstream source-of-truth (Helm values / SealedSecret / Operator CR / KV)" path. Step 6 success criterion MUST be hardened: wait ≥ MAX(180s, 2× longest reconcile cycle observed in cluster) AND re-verify Secret value at end of wait. The vault recipe's 90s ceiling is INSUFFICIENT for catching slow reconcile reverts.

**Counter-hypothesis**: Safe if sandbox cluster's `repo-*` Secret has zero ownership annotations (truly hand-applied). `plan/plan.md:54-57` Q2 says this is "the simplest mechanism" — but plan.md itself marks it `[PENDING]`. Favor vulnerability because the smoking gun (Helm chart `iac-secret-templates.md:36-51`) makes silent revert a default-position concern, not a tail risk.

**Verdict**: **REWRITE** — add mandatory ownership-label probe + extend Step 6 wait window + require re-verify at wait-end. The current Decision Rule structurally cannot distinguish "PAT works" from "PAT works for 30 minutes."

---

### V6 — Step 6 "ErrorOccurred=False + fresh lastTransitionTime ≤2min = auth recovered" — [PATTERN-MATCHED]

**Decision Rule**: `vault-extracts.md:117-128` 6×15s loop; success = `ErrorOccurred=False`.

**Counter-example (concrete)**:

1. **Condition is stale-cached for >3 min**: ApplicationSet controller in v2.10.5 caches the condition state; the `lastTransitionTime` may reflect when the *condition* changed, not when the *underlying cause* changed. If the cache TTL exceeds 90s (default in some Argo versions is 3-5min for controller informer resync), the `False` reading is from a window BEFORE Alex even started the rotation. Recipe wrongly attributes recovery to its own action.
2. **ApplicationSet was already disabled**: If a previous on-call set `spec.syncPolicy.preserveResourcesOnDeletion: true` or otherwise paused the AppSet, ErrorOccurred won't update because the generator isn't running. Recipe sees stale False, declares victory. Pattern doc `vault-extracts.md:179-180` warns "Disable ApplicationSet sync policy — silences symptom; GitOps contract still broken" — meaning this anti-pattern has historical precedent at Eneco.
3. **The controller is restarting**: `argocd-applicationset-controller` pod just OOM-killed and is in CrashLoopBackOff; no conditions are updating. Recipe sees the LAST condition from before crash = False (if last cycle pre-crash had recovered). False signal.
4. **Wrong condition type**: `vault-extracts.md:124` uses `conditions[?(@.type=="ErrorOccurred")]`. If ArgoCD changed condition type names between v2.10.5 and any cluster's actual version (the MC operator-managed ArgoCD is `[UNVERIFIED]` version per `plan/plan.md:94`), the JSONPath returns empty → bash treats empty as success in some shells, reporting `ErrorOccurred=` (empty string) which compared to "False" in `[ "$STATUS" = "False" ]` returns FALSE → loop times out — but recipe says "still True after 90s ────► Re-check Step 4" while reality is "condition type doesn't exist."
5. **Timeout insufficient under load**: ApplicationSet reconcile is every 3 min by default. If Alex's annotation lands 5 seconds into a 3-min cycle, the next force-refresh fetches ~2:55 later. 90s ceiling misses it; recipe sees stale True, recommends "re-check Step 4" — Alex re-curls, sees 200, is confused.

**Plausibility**: (1) POSSIBLE, (2) EDGE-CASE for sandbox, LIKELY-as-history for MC, (3) EDGE-CASE, (4) LIKELY on MC operator version, (5) POSSIBLE under cluster load.

**Detection delay**: (5) self-corrects in 2-5 min when next reconcile happens; (1)(4) are most dangerous — false-positive "auth recovered" leads to closing incident while broken.

**Mitigation**: Step 6 MUST also probe the ApplicationSet's *generator output* (not just condition): `kubectl get applicationset vpp-feature-branch-environments -n argocd -o jsonpath='{.status.resources}'` should show fresh ResourceStatus entries for the slot's child Applications. Additionally: extend timeout to 6× reconcile-interval observed (`kubectl get applicationset ... -o jsonpath='{.spec.template.spec.syncPolicy.automated}'` + cluster reconcile config). Lastly: pin the condition type to ArgoCD version (probe `kubectl api-resources | grep applicationset` for the CRD's version + spec).

**Counter-hypothesis**: Safe in steady-state v2.10.5 sandbox with normal load. Favor vulnerability because (4) is a 100% silent-fail on the MC class and Section B has not been explicitly version-pinned.

**Verdict**: **HARDEN** (add generator-output probe; pin condition type to ArgoCD version; extend timeout based on observed reconcile interval).

---

### V7 — Step 7 "child Applications materialize within 30-60s" — [PATTERN-MATCHED]

**Decision Rule**: `vault-extracts.md:135-145` polls for `${SLOT}` namespace child apps; expects ≥10 in 2 min.

**Counter-example (concrete)**:

1. **Sync policy is manual**: ApplicationSet generates Application CRDs, but those CRDs have `spec.syncPolicy: manual` (no `automated:`). Children appear in `argocd` namespace as CRDs but never sync to `${SLOT}` namespace — wc -l returns counts of CRDs but checking `${SLOT}` ns shows nothing. Recipe `vault-extracts.md:140` counts `applications.argoproj.io -n "$SLOT"` which DOES count CRDs in the slot namespace — but if Argo's ApplicationSet generates child Application CRDs in `argocd` namespace (the default for v2.10+) targeting slot ns, the grep at line 140 picks them up. AMBIGUOUS — depends on cluster's ArgoCD configuration of ApplicationSet `goTemplate` and child CRD destination namespace. Recipe is ambiguous about WHERE child Applications materialize.
2. **Goldilocks app has resource-hooks** (Section B MC scenario): the goldilocks Application's pre-sync hooks may run a job that depends on a separate secret that's also been rotated/broken. Children appear, then immediately fail their pre-sync hook, leave Applications in `OutOfSync + Degraded` — but the recipe at line 142 counts CRDs, not their health. Returns 10. Recipe declares success.
3. **Cascade prune deleted apps mid-rotation**: While Alex was patching, a developer pushed a commit to `VPP.GitOps` removing the slot's app-of-apps definition. ApplicationSet's next reconcile correctly removes the child CRDs. Step 7 counts 0 children — Alex thinks rotation failed. Spends 15 min diagnosing PAT before noticing git history.

**Plausibility**: (1) POSSIBLE (sync policy is per-Application; default per VPP convention `[UNVERIFIED]`); (2) **LIKELY for Section B** (Goldilocks is unknown; could absolutely have hooks); (3) EDGE-CASE.

**Detection delay**: (2) up to several hours — `degraded` doesn't trigger a Slack alert in Eneco's current alerting (no `argocd_app_health` alert per `vault-extracts.md:253`).

**Mitigation**: Step 7 must check both COUNT and HEALTH: `kubectl get applications.argoproj.io -n "$SLOT" -o jsonpath='{range .items[*]}{.metadata.name}{" health="}{.status.health.status}{" sync="}{.status.sync.status}{"\n"}{end}'`. Required: ≥10 + ALL Healthy + ALL Synced. Failures itemize remediation per Application.

**Counter-hypothesis**: Safe if the recipe is only used for sandbox FBE recovery where sync policy = auto. Favor vulnerability because Section B applies the same logic to MC where sync policy is `[UNVERIFIED]`.

**Verdict**: **HARDEN** (health + sync + count, not just count).

---

### V8 — Step 8 "HTTP/2 200 + Request-Context + x-correlation-id = healthy" — [EXPLOIT-VERIFIED]

**Decision Rule**: `vault-extracts.md:156-165`. Vault note already warns about SPA fallback returning 200.

**Counter-example (concrete)**: The vault recipe at `vault-extracts.md:163` already names this trap: "HTTP/2 200 only → SPA fallback (different class)." But the recipe's success-branch at line 162 says "HTTP/2 200 + Request-Context + x-correlation-id headers → FBE healthy". Counter-examples that the runbook's positive signal ALSO fires while broken:

1. **Ingress points to wrong namespace**: A misconfigured ingress route (e.g., during a kustomize overlay merge) sends `https://{slot}.dev.vpp.eneco.com/` to a different slot's service (e.g., `cylon` instead of `kidu`). Cylon's service responds with HTTP/2 200 + the SAME header pattern (Request-Context + x-correlation-id are .NET ApplicationInsights middleware — every service emits them). Alex sees 200, thinks slot=kidu is healthy. Reality: kidu has no pods; he's seeing cylon's response. Detection: only by checking response body for slot-name string match.
2. **Correlation-id header source unclear**: `x-correlation-id` is added by either: (a) the upstream API service, (b) the ingress controller (some NGINX configs inject correlation-id at ingress level), (c) APIM in front of the cluster. Per `vault-extracts.md:163` only (a) implies "service backed". If ingress is (b) or (c), the header fires regardless of whether any pod is alive. Probe is fragile.
3. **Stale CDN/proxy cached the headers**: If the URL is fronted by Azure Front Door or similar with header caching, the success-signal headers come from a 5-minute-old healthy response. Reality: pods are now down. Detection: only by force-refresh / different cache key.

**Plausibility**: (1) POSSIBLE during overlay merges (Slack `slack-rotation-harvest.md:99` Fabrizio's pattern is per-FBE-per-symptom — overlay merges happen); (2) **LIKELY** (NGINX correlation-id injection is common); (3) EDGE-CASE.

**Detection delay**: (1) immediately wrong but invisible without body inspection; (2) the test was always wrong (POPULATION-LEVEL false positive); (3) up to cache TTL.

**Mitigation**: Step 8 MUST probe the response BODY for slot-specific content (`grep -i "$SLOT"` in body, or grep a known API endpoint return: `curl -svk "https://${SLOT}.dev.vpp.eneco.com/api/version" | jq -r '.environment'` returning `${SLOT}`). Headers alone are necessary but not sufficient. Additionally: probe pod readiness directly: `kubectl get pods -n "$SLOT" -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.phase}{"\n"}{end}'` — must show ≥1 Running pod per service.

**Counter-hypothesis**: Safe if Eneco's headers are stable + ingress routing is reliable + no CDN in path. Favor vulnerability because (2) makes the headers irrelevant evidence — the rule has population-level FPR.

**Verdict**: **REWRITE** — body content + pod readiness, not headers.

---

### V9 — NEW DECISION RULE (you didn't name): "Old PAT remains valid until 2026-05-10 (already past for sandbox); revoking is optional" — [THEORETICAL]

**Decision Rule** (implicit in current plan: "Step 9 documents the rotation, but doesn't enforce old-PAT cleanup"). Vault recipe `vault-extracts.md` ends at Step 8 with "verify URL recovery"; no explicit "revoke the old PAT" step.

**Counter-example (concrete)**: After Step 5, the old PAT is still listed in ADO `/_usersSettings/tokens` page until its natural expiry (2026-05-10 for sandbox — ALREADY past, so this is moot for sandbox, BUT 2026-06-01 for the three MC PATs which the runbook is supposed to cover proactively). For MC: Alex rotates devmc on 2026-05-11. The OLD devmc PAT remains valid in ADO until 2026-06-01 (21 days). If the old PAT was leaked (e.g., dumped in a pipeline log; archived in chat history; sitting in a developer's ~/.kube cache that's been git-committed), an attacker has 21 days of valid-PAT credentials with Code Read across the entire `enecomanagedcloud` org. Recipe makes no statement; runbook (if it inherits the omission) makes no statement.

**Plausibility**: THEORETICAL for unauthorized use; LIKELY for compliance audit gap (any security-review process at Eneco would flag this).

**Detection delay**: Indefinite — old PAT may never be detected as leaked; expiry alone closes the window.

**Mitigation**: New Step 9.5: "Immediately revoke the prior PAT in ADO UI (`/_usersSettings/tokens` → Revoke). Confirm revocation by curling `/info/refs` with the OLD PAT — must return 401. Document revocation timestamp."

**Counter-hypothesis**: Safe if the old PAT is never leaked. Favor vulnerability because at zero cost (Revoke button) you eliminate the residual exposure window; not doing it is a defect.

**Verdict**: **HARDEN** (add explicit revoke step).

---

## SECTION B — MC DECISION RULES (Speculative)

### V10 — Section B step 1 "Mint new PAT in ADO UI ... Code Read scope" — [PATTERN-MATCHED]

**Decision Rule**: Same as V3 but for three MC PATs (devmc, accmc, prdmc).

**Counter-example (concrete)** — three destructive paths beyond V3:

1. **CMC-side-operated PAT**: `slack-rotation-harvest.md:38-42` Roel: "I asked him to update a PAT for me in the CMC ArgoCD instance for the Goldilocks application" — "him" is "Lex from CMC". This is the most route-flipping evidence in the entire task: **MC ArgoCD PATs may not be mintable by Trade Platform**. Alex tries to mint, succeeds (ADO doesn't enforce CMC's operational boundary), files a CMC ticket, but the CMC ticket flow expects a CMC-controlled PAT minted in a CMC SA. Alex's PAT is rejected/ignored. Worse: Alex doesn't know it was rejected — he files the ticket, gets "received" acknowledgment, declares victory; CMC silently uses a different (unrotated) PAT or escalates back days later.
2. **Rate limit / batch minting**: Alex mints 3 PATs in sequence (devmc, accmc, prdmc) over ~3 minutes. ADO PAT API may rate-limit; second/third minting fails silently with HTTP 429 returning a partial token (truncated) that visually looks correct. Step 4 curl returns 401 for the partial token.
3. **Naming convention drift**: Recipe says `argo-cd-{env}mc-cmc-goldilocks-repository-YYYY-MM-DD` — but `slack-rotation-harvest.md:23-25` shows CURRENT names are `argo-cd-devmc-cmc-goldilocks-repository` (NO date suffix). If the PAT-expiry monitoring pipeline (`iac-secret-templates.md:122-138`) filters by exact-name match (the PS1 script may do a `where {$_.Name -eq "argo-cd-devmc-cmc-goldilocks-repository"}`), Alex's date-suffixed PAT is INVISIBLE to monitoring. The next expiry alert (around 2026-05-31 for the OLD names, since old PATs not yet revoked) fires confusingly: "argo-cd-devmc-cmc-goldilocks-repository expires 06/01" — but Alex thinks he rotated it. He looks up new PAT, says "but I rotated this 3 weeks ago" — the rotation just used a different name. Reality: pipeline still watches old name, not new. **Coverage gap.**

**Plausibility**: (1) **LIKELY** based on Roel's quote — single strongest evidence in entire task; (2) EDGE-CASE; (3) **LIKELY** depending on PS1 script's filter logic — `iac-secret-templates.md:138` script docstring says "checks the PAT tokens that belongs to the service account (itself)" implying it iterates all SA-owned tokens, but doesn't say how the alert correlates name-to-expiry.

**Detection delay**: (1) days (CMC turnaround for tickets); (3) 21-30 days (next alert cycle).

**Mitigation**: Section B step 0 = `[PENDING: ask Fabrizio: are MC PATs minted by Trade Platform, or filed as a request to CMC?]`. If CMC-operated → REWRITE Section B to be a request template, not a procedure. Naming convention: KEEP the existing name (no date suffix) to preserve monitoring correlation. Naming MUST match what monitoring filters on.

**Counter-hypothesis**: Safe if Trade Platform has full PAT-minting authority over `sa_platform_vpp` AND monitoring is name-agnostic. Favor vulnerability because Slack evidence directly contradicts (1).

**Verdict**: **REWRITE** — Section B's first decision is "do I execute or file ticket?", not "what name do I use?"

---

### V11 — Section B option Y "Update KV `vpp-aks-devops`/`vpp-appsec-d` via `az keyvault secret set`" — [EXPLOIT-VERIFIED]

**Decision Rule**: Update KV → propagation → cluster Secret updated.

**Counter-example (concrete)** — **THE silent-fail crown jewel for MC**:

1. **No sync mechanism**: `iac-secret-templates.md:55-56` confirms ESO is NOT deployed. `iac-secret-templates.md:84` confirms CSI for repo creds is OCI-only on MC (NOT ADO Git). **There is no KV → cluster sync mechanism for ADO Git repo PATs on MC**. Alex runs `az keyvault secret set`, succeeds. Nothing propagates. Cluster Secret remains stale. ApplicationSet/Goldilocks keeps failing with the OLD (now-also-expired-or-soon-expiring) PAT. **The entire option Y is structurally broken.**
2. **Wrong KV**: vault note at `vault-extracts.md:194-198` says KV is `vpp-appsec-d`; wiki at `wiki-rotation-search.md:107-108` says appreg secrets live in `vpp-aks-devops`. `iac-secret-templates.md:32` says `vpp-appsec-d` is "argocd-repository-credentials-template-url-{acc,devmc}" — only 2 of 4 entries, missing accmc/prdmc. **The KV is incomplete AND ambiguous.** Alex picks the wrong KV → silent no-op.
3. **KV entry stale-by-design**: If those KV entries were created for a sync mechanism that was never deployed (or was deprecated), updating them does nothing. The IaC harvest at `iac-secret-templates.md:88-93` explicitly states: "these two KV secrets (argocd-repository-credentials-template-url-acc and -devmc) were created **manually via Azure Portal or `az keyvault secret set`**, NOT by Terraform. There is no IaC declarations for them" — meaning they are documentation theatre, not active sync surfaces.

**Plausibility**: (1) **VERY LIKELY** — three independent IaC sidecar findings (no ESO, no CSI for ADO Git, no Terraform); (2) LIKELY; (3) **LIKELY**.

**Detection delay**: 0s for the KV write; INDEFINITE for the cluster effect (it never happens). Alex thinks rotation done; next FBE-create on MC (or whatever consumes Goldilocks) fails when old PAT expires on 2026-06-01. Surprise outage 21 days later.

**Mitigation**: **DELETE option Y from Section B**. Replace with: "Confirm there is no KV→cluster sync mechanism for the MC ArgoCD repo PATs. Updating the KV is at best a redundant write to a documentation artifact; at worst it gives false-confidence of rotation. The actual rotation must happen IN-CLUSTER (option Z, kubectl/oc apply path), preceded by `[PENDING: ask Fabrizio: who can kubectl/oc into MC clusters?]`."

**Counter-hypothesis**: Safe if a sync mechanism exists that we haven't discovered. Favor vulnerability because three orthogonal IaC harvests all confirm absence; no sidecar found a sync surface.

**Verdict**: **REWRITE** — option Y must be removed or relabeled as "documentation-only update; no operational effect."

---

### V12 — Section B option Z "File CMC service request with new PAT value" — [THEORETICAL]

**Decision Rule**: File ticket → CMC applies PAT → Goldilocks recovers.

**Counter-example (concrete)**:

1. **Ticket SLA unknown**: No documented CMC SLA in any harvest. If Alex files a ticket on 2026-05-12 for a PAT that expires 2026-06-01, CMC may not action it in time. PAT-expiry pipeline keeps alerting (Critical at 5 days = 2026-05-27). Alex thinks "filed ticket, my job is done." Outage at 2026-06-01.
2. **Wrong ArgoCD targeted**: `wiki-rotation-search.md:53-56` confirms TWO ArgoCD per MC cluster: `eneco-vpp-argocd` (legacy/custom) and `openshift-gitops` (Red Hat Operator). If Alex's ticket says "rotate the goldilocks PAT" without naming WHICH ArgoCD instance, CMC might:
   - Rotate it in `openshift-gitops` while the actual consumer is `eneco-vpp-argocd` → silent no-op
   - Rotate it in `eneco-vpp-argocd` while the actual consumer is `openshift-gitops` → silent no-op
   - Rotate in both → operational success, but Alex's runbook didn't tell him to verify the disambiguation. ESCALATION risk.
3. **PAT value transmission**: How does Alex transmit the new PAT to CMC? Email = leak risk; Slack DM = leak risk + retention; ticket attachment = depends on CMC ticket system encryption; **the ticket platform is `[UNVERIFIED]`**. If transmitted in cleartext through a system that logs/archives, the PAT is now a long-lived secret in a place neither Trade Platform nor CMC controls. PAT scope (V3.4: full org Code Read) makes this a high-impact leak surface.

**Plausibility**: (1) POSSIBLE (CMC SLA is unknown but not infinite); (2) **LIKELY** (the two-ArgoCD topology is documented but the rotation flow has never explicitly disambiguated — see `wiki-rotation-search.md:174`); (3) LIKELY (cleartext-in-ticket is the modal way platform-team-to-CMC handoffs work absent explicit secret-sharing infra).

**Detection delay**: (1) 21 days; (2) until next Goldilocks-driven outage; (3) indefinite.

**Mitigation**: Section B option Z MUST require: (a) explicit ArgoCD-instance naming in the ticket (`eneco-vpp-argocd` namespace specifically), (b) confirmed PAT-transmission channel (1Password share / Bitwarden / Azure KV with CMC-readable access policy — NEVER email/Slack/cleartext), (c) confirmed CMC SLA before filing (set ticket priority to match expiry urgency), (d) post-ticket-fulfillment verification probe (`oc -n eneco-vpp-argocd get secret <name> -o jsonpath='{.data.password}' | base64 -d | head -c5` to confirm new value is in cluster).

**Counter-hypothesis**: Safe if CMC has a documented secret-rotation flow with secure transmission + SLA. Favor vulnerability because no harvest surfaced one.

**Verdict**: **HARDEN** (explicit disambiguation, transmission channel, SLA, verify).

---

### V13 — Section B step "Wait for sync mechanism (unknown — could be manual oc apply or operator pickup)" — [PATTERN-MATCHED]

**Decision Rule**: Wait then verify Goldilocks reconcile.

**Counter-example (concrete)**:

1. **Operator-managed Secret revert** (mirror of V5 for MC): If the `argoproj.io/v1beta1 ArgoCD` CR (`iac-secret-templates.md:99-103`) lists the repo Secret in `spec.repo.repositories[].secretRef`, OpenShift GitOps Operator may reconcile the Secret from the CR's view. If CMC applies the new PAT via `oc patch secret` instead of updating the CR's source-of-truth, operator reverts → silent regression after ~5min.
2. **Goldilocks sync policy = manual**: Even with the new PAT, Goldilocks Application may have `spec.syncPolicy: manual`. PAT works (auth recovers) but Goldilocks doesn't sync. Alex/CMC needs to manually trigger `argocd app sync goldilocks` or `oc patch application goldilocks --type merge -p '{"operation":{"sync":{}}}'`. Verification step missing.
3. **Refresh annotation doesn't apply**: `vault-extracts.md:119-120` uses `argocd.argoproj.io/refresh=hard` annotation on ApplicationSet — but on MC, the consumer is `Application` (singular, Goldilocks), not ApplicationSet. The annotation target is wrong; the controller-restart annotation may differ. `[PENDING: ask Fabrizio]`.

**Plausibility**: (1) POSSIBLE (depends on operator config); (2) **LIKELY** (operators favor manual sync for prod-touching apps); (3) LIKELY (CRD semantics differ).

**Detection delay**: (1) ~5min revert; (2) indefinite until manual sync triggered.

**Mitigation**: Section B verify step MUST include: `oc get application goldilocks -n eneco-vpp-argocd -o jsonpath='{.status.sync.status}{" "}{.status.health.status}{" "}{.status.operationState.phase}'`. Expected: `Synced Healthy Succeeded`. If sync policy is manual, the runbook must EXPLICITLY trigger sync as a step.

**Counter-hypothesis**: Safe if CMC's procedure includes the manual sync + the operator config doesn't revert. Favor vulnerability because both are `[UNVERIFIED]`.

**Verdict**: **HARDEN** (explicit post-rotation sync trigger + health probe).

---

## ADVERSARIAL SELF-CHECK

### Self-Questioning Results

1. **Pattern-matching check**: V1 (context typo) is partially pattern-matched. The Eneco-specific evidence (cluster recreation history) is weak. **Downgrade plausibility from LIKELY to POSSIBLE**; rule still HARDEN because cost of mitigation is trivial.

2. **False positive check**:
   - V4 (curl test): IP-allowlisted PAT is `[UNVERIFIED]`; if not present, the cluster-egress mitigation is busy-work. **Conditional**: HARDEN only if `[PENDING: ask Fabrizio: do we use IP-restricted PATs?]` returns yes.
   - V8 (correlation-id header): If Eneco's NGINX does NOT inject correlation-id, the rule is fine. **Conditional**: REWRITE only if header source can't be probed to be application-layer.

3. **Redundancy check / Root cause grouping**:
   - V5 + V11 + V13 share root cause: "the runbook lacks a model of *who owns the cluster Secret* and the consequent reconcile loop." ONE root cause, three manifestations on different surfaces (sandbox kubectl-patch, MC KV-write, MC oc-patch).
   - V2 + V6 + V7 + V8 share root cause: "the success probes are necessary but not sufficient — each is one signal, none triangulates." Could be reframed as 1 finding "weak success criteria" with 4 examples.
   - V3 + V10 share root cause: "PAT-minting identity verification is missing across both sandbox + MC paths."
   - **By root cause: 3-4 distinct findings, not 13.** I've kept 13 line-items because the user asked for per-Decision-Rule attacks, but the *generator* count is 3-4.

### Bias Scan

- **Severity Inflation**: I initially scored V5 as the highest-stakes finding. Validated: silent regression mid-rotation is the textbook EXPLOIT-VERIFIED case because the smoking-gun Helm chart exists at `iac-secret-templates.md:36-51`. NO downgrade.
- **Pattern-Matching Bias**: V1 (kubeconfig drift) was initially LIKELY because "context cache bugs are everywhere." Downgraded to POSSIBLE because Eneco-specific evidence is thin. Stated explicitly.
- **Accumulation Bias**: Yes — 13 line-items. Acknowledged in Redundancy section: real root-cause count is 3-4.

### Meta-Falsifier

**"Which finding would I REJECT if someone else presented it?"**
- V1: Borderline. The kubeconfig-drift argument needs Eneco-specific evidence. Keep but cite low confidence.
- V4.3 (cluster egress IP-restriction): Borderline. Pure speculation absent the `[PENDING]` answer. Keep because mitigation cost is trivial.
- All others: Defensible with cited evidence.

**"Strongest argument against V5 (highest-stakes)?"**: The argument that V5 is wrong is "the live sandbox `repo-*` Secret has no Helm/Operator owner annotations because the recipe has been used successfully many times by Fabrizio." Steelman: this is empirically true for sandbox per `slack-rotation-harvest.md:18-22` (Fabrizio's "you can give me a call and I explain you the process" implies operational success history). However: the steelman only protects sandbox. On MC, the Helm chart `iac-secret-templates.md:36-51` is explicitly deployed to `eneco-vpp-argocd` namespace — operational success on sandbox does not protect MC. **V5 stays EXPLOIT-VERIFIED for MC application; downgrade to PATTERN-MATCHED for pure-sandbox application.**

**"What assumption did I not challenge?"**: I assumed the runbook authors will adopt my mitigations. If Alex decides "this is too much for sandbox; I'll keep the vault recipe as-is for sandbox", that's a routing decision, not an evidence problem. The findings stand; the user decides which to apply.

### Results

- **Confirmed**: V2, V3, V5, V8, V10, V11, V12, V13 (8 of 13)
- **Downgraded plausibility (rule still HARDEN/REWRITE)**: V1, V4, V6, V7, V9 (5 of 13)
- **Removed**: None

---

## VERDICT

**Findings**: 13 attacks across 13 Decision Rules (counted as line-items; **3-4 root-cause generators** underneath).

| Verdict | Count | Rules |
|---|---|---|
| HOLD | 0 | — |
| HARDEN | 9 | V1, V2, V3, V4, V6, V7, V9, V12, V13 |
| REWRITE | 4 | V5, V8, V10, V11 |

**Highest-stakes**: V5 (kubectl-patch silently reverted by Helm/Operator reconcile on MC) — Section A's silent-success mode is rotation-victory at t=90s, rotation-defeat at t=30min. This rule must be REWRITTEN before any user-facing publication.

**Section B verdict**: TWO of three Section B rules require REWRITE (V10 mint-flow if CMC-operated, V11 KV-write structurally non-propagating). **Section B as currently planned is structurally broken absent `[PENDING: ask Fabrizio]` resolution.** Do not publish Section B as an executable procedure; publish only as a structured `[PENDING]` questionnaire targeted at Fabrizio + CMC, with three conditional procedure branches keyed on his answers.

**Root-cause generators identified** (3):

1. **Ownership model absent**: Runbook does not model the controller that owns the in-cluster Secret. Every Decision Rule that assumes "kubectl/oc/az writes the truth" is vulnerable to silent reconcile-revert. → V5, V11, V13.
2. **Single-probe success criteria**: Each verification step probes one signal. Triangulation absent. → V2, V6, V7, V8.
3. **Identity-of-minter ambiguous**: PAT minting can occur under personal-by-mistake, can hit MFA dead-end, or may not be Alex's prerogative at all. → V3, V10.

**Recommended coordinator action**: Before authoring `how-to-rotate.md` in P7:
1. Block on `[PENDING]` resolution for the four highest-stakes questions:
   - (a) Sandbox `repo-*` Secret ownership annotations (`managed-by`/Helm release/operator instance)
   - (b) MC ArgoCD repo Secret ownership (eneco-vpp-argocd vs openshift-gitops; manual vs Helm vs operator)
   - (c) MC PAT minting authority (Trade Platform vs CMC-operated)
   - (d) IP-restricted PAT policy (yes/no — affects V4)
2. If (a)-(c) cannot be resolved before publication, the runbook MUST mark Section B explicitly as `DRAFT — DO NOT EXECUTE`, with the questionnaire as primary content.
3. Apply all 9 HARDEN mitigations to Section A regardless of `[PENDING]` resolution — they are zero-cost defense-in-depth.
4. Recommend coordinator invoke `verification-engineer` (tandem) to author regression-test probes for V5 (ownership-label check) and V8 (body-content match) before runbook publication.

---

*El Demoledor: proving resilience through destruction. The runbook works in 99% of paths — these are the 1% where it lies to the operator about success while the system remains broken. Find the crack; the user fixes the bridge.*
