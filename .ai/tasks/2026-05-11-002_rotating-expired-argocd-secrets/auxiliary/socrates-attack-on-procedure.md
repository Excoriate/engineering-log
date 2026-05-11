---
task_id: 2026-05-11-002
agent: socrates-contrarian
status: complete
summary: Socratic attack on 3 load-bearing items before deliverable authoring
phase: 5
---

# Socratic Attack — Pre-Authoring Adversarial Review

> Adversarial win condition: destroy inherited interpretations. No cheerleading. No explanation of agreement. Each attack ends with a VERDICT.
> Citations use `file:line` format; files are the 6 artifacts named in the dispatch (final-reqs, vault-extracts, slack-harvest, wiki-search, iac-templates, plan).

---

## Attack 1 — The vault recipe's `kubectl patch` step

### Steel-man (the strongest version of what is being claimed)

The coordinator believes that on the sandbox AKS cluster `vpp-aks01-d`, the in-cluster Kubernetes Secret matching `argocd.argoproj.io/secret-type=repository` whose `data.url` contains `VPP.GitOps` is an **unmanaged**, hand-applied `Opaque` Secret. Therefore the recipe step `kubectl patch secret repo-NNNNNNNNNN -n argocd --type=json -p '[{"op":"replace","path":"/data/password","value":<base64>}]'` (vault-extracts.md:103-107) is durable: no reconciler will overwrite it, and after `argocd.argoproj.io/refresh=hard` on the ApplicationSet (vault-extracts.md:118-120), auth recovers within minutes (vault-extracts.md:131). The IaC sidecar's negative findings (iac-secret-templates.md:26-30, 56, 86-92) reinforce this — no `kubernetes_secret` Terraform, no ESO, no CSI for ADO PATs — leaving "manual apply" as the residual mechanism.

### Three hidden assumptions that flip the conclusion if false

**H1 — "No Terraform / Helm / CSI / ESO declares it ⇒ nothing reconciles it."** This is a false dichotomy. The IaC sidecar's search scope is *cloned local repos* (iac-secret-templates.md:11, 171). Non-cloned surfaces are blind spots, explicitly admitted: "Repos not cloned locally (e.g., `platform-services`, `Eneco.HelmCharts/eneco-vpp-argocd*` if any) were NOT searched" (iac-secret-templates.md:171). A Helm release deployed manually by Fabrizio with `helm install` from a non-cloned chart (or a Kustomize overlay in a repo we did not enumerate) would leave the `app.kubernetes.io/managed-by: Helm` label on the live Secret. The IaC absence proves *I did not find code that manages it*; it does NOT prove *no code manages it*.

**H2 — "The Secret has the same name as the recipe's `repo-NNNNNNNNNN` shape."** The recipe assumes ArgoCD's canonical naming convention (`repo-<hash>`). But the Helm template at `myriad-vpp/ArgoCD-Config/Helm/repositories/templates/deployment.yaml:1-12` (iac-secret-templates.md:36-51) names the Secret literally `acr-helm` — NOT `repo-*`. ArgoCD treats *any* Secret with the `argocd.argoproj.io/secret-type: repository` label as a repository — the name pattern is convention, not enforcement. If the sandbox cluster's gitops-vpp repo Secret is named e.g. `vpp-gitops-repo` or `gitops-vpp` (Helm-chart pattern), then the recipe's Step 5 name-guard `case "$ARGOCD_REPO_SECRET" in repo-*) ...` (vault-extracts.md:95-101) ABORTS — not because the rotation is wrong but because the *name guard* was authored against the wrong pattern. Cost: the operator sees `ABORT: secret name does not match repo-*` and (worst case) edits the guard out, bypassing the only safety check.

**H3 — "The patch survives long enough for `argocd.argoproj.io/refresh=hard` to do its work."** Even if the Secret is *currently* unmanaged, the recipe assumes there is no race with an ArgoCD application that itself manages a Secret of `kind: Secret` in the `argocd` namespace via `vpp-feature-branch-environments`-adjacent Application. ArgoCD self-management is a known gotcha — if any Application's `spec.source` produces a Secret with the same name, ArgoCD will sync OUT-OF-SYNC and either revert or alert depending on sync policy. The recipe does not verify that the Secret is NOT itself tracked by any Application (`kubectl get application -A -o jsonpath='{.items[*].status.resources[*]}'` filtered for Secret kind).

### Falsification scenario (a plausible world where the interpretation is wrong)

Fabrizio, two years ago, installed a small Helm chart from a private `Eneco.HelmCharts` repo (not cloned locally) that renders the `repo-vpp-gitops` Secret with `argocd.argoproj.io/secret-type: repository` and `app.kubernetes.io/managed-by: Helm`. Values come from `values-sandbox.yaml` in that repo, where `password:` is wired to a CI pipeline variable `$(SA_PLATFORM_VPP_PAT)`. The Helm release was never tracked anywhere visible to the team. Fabrizio rotates by editing the pipeline variable + `helm upgrade`. The team password vault stores the PAT manually as a courtesy. An operator running `kubectl patch` succeeds at the API level; for ~30 minutes (until next pipeline run or until someone re-deploys), ApplicationSet recovers. Then the *next* pipeline run with a stale PAT silently reverts the Secret, ApplicationSet breaks again at 3 AM, and the on-call cannot explain why their procedure "worked yesterday."

Observable signature: `kubectl get secret <name> -n argocd -o yaml` shows `metadata.labels: app.kubernetes.io/managed-by: Helm` and/or annotations `meta.helm.sh/release-name: vpp-gitops-repo` / `meta.helm.sh/release-namespace: <ns>`.

### Cost of being wrong

The runbook ships, on-call rotates per Section A, ApplicationSet recovers visibly within minutes (verification PASSES — vault-extracts.md:131), the on-call closes the ticket and updates the vault note as "procedure works." Hours-to-days later, the Helm release runs (manually or scheduled), the patched Secret is silently reverted to the old PAT, ApplicationSet fails again. The on-call's vault note is now actively misleading; the next operator follows it and reproduces the same silent-revert. F2 (KV-as-PENDING in plan.md) and F7 (Agent Laundering) both regress: the runbook will have promoted MY vault note to FACT without checking the runtime ownership.

### Discriminating probe (<5 min)

```bash
kubectl get secret -n argocd -l argocd.argoproj.io/secret-type=repository -o json | \
  jq -r '.items[] | {name: .metadata.name, managedBy: (.metadata.labels["app.kubernetes.io/managed-by"] // "none"), helmRelease: (.metadata.annotations["meta.helm.sh/release-name"] // "none"), ownerRefs: (.metadata.ownerReferences // []), trackingId: (.metadata.annotations["argocd.argoproj.io/tracking-id"] // "none")} | @json'
```

If `managedBy != "none"` OR `helmRelease != "none"` OR `trackingId != "none"` OR `ownerRefs != []` for the target Secret → recipe's `kubectl patch` is the WRONG mechanism. Section A must change.

Companion probe (also cheap): `kubectl get applications.argoproj.io -A -o yaml | grep -B2 -A5 'kind: Secret' | grep -A5 repo` — surfaces any Application that owns a Secret.

### Verdict

**REVISE.** The vault recipe's `kubectl patch` step is not yet falsified, but the interpretation is not strong enough to ship. Specifically:

1. plan.md Q1 already proposes a Step 4.5 ownership-probe (plan.md:39-44) — this MUST become a hard gate in Section A, not a recommendation. Wording: "If ANY of the following is non-empty, STOP this runbook and consult the named controller: `app.kubernetes.io/managed-by`, `meta.helm.sh/release-name`, `argocd.argoproj.io/tracking-id`, `ownerReferences`."
2. The recipe's name-guard `repo-*` (vault-extracts.md:95-101) must be RELAXED to `argocd.argoproj.io/secret-type=repository` label match (which is ArgoCD's actual selector), not name match. Add a `[PENDING: confirm the exact Secret name on live sandbox]` to be resolved by Step 2 probe output.
3. The runbook must explicitly state: "absence of declarative IaC ≠ absence of reconciler. Run Step 4.5 to confirm."

---

## Attack 2 — Fabrizio's "Nope. There is no documentation for this."

### Steel-man

Today at 12:47:35 CEST, in `#team-platform` (slack-rotation-harvest.md:22-23, ts 1778495545.088229), Fabrizio answered Alex's question about documentation with two sentences: "Nope. There is no documentation for this." then "It is a good opportunity to create one." The Slack sidecar performed 14 searches (slack-rotation-harvest.md:108-123) and found no canonical rotation procedure for ArgoCD PATs. The wiki sidecar performed 19 searches (wiki-search.md:133-152) and found no step-by-step ArgoCD PAT rotation runbook. Across three independent surfaces (Slack, ADO wiki, ADO repos — wiki-search.md:151), Fabrizio's claim is corroborated. Conclusion: this runbook is the first formal documentation; the procedure must be authored from first principles + Fabrizio's oral knowledge.

### Three hidden assumptions that flip the conclusion if false

**H1 — "Documentation" means "written, discoverable, English-language procedure indexed by my search tools."** Fabrizio's quote is bounded by what HE considers "documentation." A canvas in `#team-platform` Slack (Slack canvases are non-search-indexed in the default `slack_search_public_and_private` API), a pinned message, a 1Password vault note shared inside the Trade Platform Team vault (where `sa_platform_vpp` already lives — slack-rotation-harvest.md:75-78), or a private Notion/Obsidian workspace owned by Fabrizio personally — none of these would surface in the Slack/wiki/IaC searches actually performed. The Slack sidecar's search log (slack-rotation-harvest.md:108-123) is impressive in breadth but does not include canvas search, pinned-message enumeration in `#team-platform`, or DM history with Fabrizio. None of the wiki searches (wiki-search.md:133-152) covered the **third wiki** that the sidecar itself flagged as unindexed: "Platform-team-internal" (wiki-search.md:172).

**H2 — Fabrizio's "no documentation" answer is about the FULL procedure, not just the public-facing one.** Re-read the exact exchange: "Alex: 'is there any documentation, or particular caveat that I need to know in advance?'" → Fabrizio: "Nope. There is no documentation for this." (slack-rotation-harvest.md:20-22). Alex's question merged two things — *documentation* AND *caveats*. Fabrizio's "Nope" could be answering "no public/team-shared documentation that you can read instead of calling me" while a PRIVATE Fabrizio-only knowledge surface exists (his Obsidian, an ADO wiki page that requires a non-default permission, a `Platform-team-internal` page he authored but didn't link). His follow-up "You can give me a call and I explain you the process" (slack-rotation-harvest.md:22) explicitly admits the knowledge exists in HIS head, not in zero locations.

**H3 — Cost of trusting the quote at face value is symmetric.** It is not. If Fabrizio's quote is correct → authoring the runbook from scratch has cost = effort to write. If Fabrizio's quote is wrong → authoring the runbook contradicts an internal canvas/page/note that a future operator might find and follow instead of mine, OR my runbook is silently inferior to the existing one but published with more authority (frontmatter, falsifiers, wiki location). The asymmetry: the wrong-direction cost is *active divergence*, which is worse than the right-direction cost.

### Falsification scenario

Fabrizio has a `Platform-team-internal` wiki page titled "Rotating PATs for ArgoCD repo connections" that he authored 6 months ago and forgot exists. The wiki sidecar's search backend (`wiki-search.sh`) is configured against the two registries `Myriad---VPP.wiki` and `Platform-documentation` (wiki-search.md:133, 136). The third wiki, `Platform-team-internal`, is searchable only via `repo-search.sh` and even then only for paths the user knows to look for (wiki-search.md:172, "Not in the skill's primary registry"). When Alex publishes the new runbook to `log/employer/eneco/...`, a future on-call finds it via personal-log search but never sees Fabrizio's older page. Two procedures coexist, drift over time, neither is canonical, and the next outage exposes the contradiction.

Observable signature: a `repo-tree.sh --wiki Platform-team-internal --path /` or a manual UI scroll through `https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_wiki/wikis/Platform-team-internal` would surface a section titled approximately "ArgoCD" or "Secrets" or "PAT".

### Cost of being wrong

The 3 deliverables go to the user's personal engineering log (final-reqs:105) but a copy will likely be proposed to live in Eneco's `Platform-team-internal` wiki (wiki-search.md:172, "Worth flagging to the coordinator — runbook may want to live there if it is internal"). If a Fabrizio-authored page already exists there, my runbook either: (a) gets rejected at review with embarrassment, (b) creates a duplicate page that diverges over time, or (c) replaces a tested page with my untested one (worst case if mine has bugs the existing one doesn't). The Slack quote also influences `proposal-rotation-automation.md` — if "no procedure exists" is the framing for "automation is overdue," and a procedure DOES exist in `Platform-team-internal`, the framing is exaggerated and Fabrizio (the reviewer of the proposal) will see right through it.

### Discriminating probe (<5 min)

Two-probe combination:

1. Ask Fabrizio directly, ONE question, in the same thread he already started today: *"Quick check before I write this up — is there anything in `Platform-team-internal` wiki, a canvas in #team-platform, or in the Trade Platform Team vault notes (not just the SA credential), that documents the rotation? I want to make sure I extend rather than duplicate."*
2. Independently, run `repo-tree.sh --wiki Platform-team-internal --path /` (or the equivalent ADO wiki API call) to enumerate page titles. Look for any title containing `argocd|argo|pat|rotation|secret|repository`.

The first probe is the source-of-truth (Fabrizio knows what he authored). The second is the corroboration (in case Fabrizio forgot). Total elapsed: <5 min if Fabrizio responds; <2 min for probe 2 alone.

### Verdict

**REVISE.** The "Fabrizio said no docs" claim is corroborated but bounded. The runbook must:

1. Add an explicit `[PENDING: confirm with Fabrizio that Platform-team-internal wiki has NO ArgoCD PAT rotation page]` to the gap list (final-reqs:54, slot for `[PENDING]` items).
2. Include the literal probe above in the runbook's "Before you start" gate (NOT before publishing, BEFORE rotating — because if a Fabrizio doc exists, it may have better caveats than mine).
3. The `proposal-rotation-automation.md` framing CANNOT lead with "no documentation exists" as a problem statement; it must lead with "*current rotation is manual, oral, and only one person carries it*" (which is supported by Fabrizio's "give me a call" line — slack-rotation-harvest.md:22 — and is robust to the existence of any private page).

---

## Attack 3 — The "simplest mechanism" hypothesis (plan Q2)

### Steel-man

plan.md:46-56 frames the simplest mechanism: all 4 PATs are minted manually under `sa_platform_vpp@eneco.com` in the ADO UI; PAT values stored in the Trade Platform Team password vault + optionally Azure KV (`vpp-appsec-d` has 2 of 4 entries — vault-extracts.md:194-198, iac-secret-templates.md:86-92); each cluster's repo Secret is manually applied; CMC-side may operate MC PATs because MC clusters live on CMC-managed OpenShift; the 2/4 KV gap is drift. This is supported by: (i) no IaC declares the KV secrets (iac-secret-templates.md:86-92), (ii) the rotator Terraform module is AAD-SP-only (iac-secret-templates.md:94), (iii) Slack mentions of "Lex from CMC" for Goldilocks (slack-rotation-harvest.md:42-43), (iv) "no documented SLA" + "Fabrizio carries it orally" (slack-rotation-harvest.md:24, 145).

### Three hidden assumptions that flip the conclusion if false

**H1 — "Minted under `sa_platform_vpp@eneco.com`" = "minted *by* `sa_platform_vpp` (a human signed in as the SA)."** The ADO PAT API report (slack-rotation-harvest.md:54-60, iac-secret-templates.md:138) reports PATs *owned by* the SA. Ownership ≠ creation authority. ADO supports impersonation flows (`Azure DevOps Personal Access Token via OAuth client-credentials grant`) and admin-mint flows (Project Collection Administrator can create PATs on behalf of users via Graph API in some configurations). It is plausible that `sa_platform_vpp@eneco.com` is a *target identity* and the actual mint is performed by an OAuth client or by an admin acting on behalf of the SA — not by a human signing in as the SA with the SA's MFA. The vault recipe Step 3 (vault-extracts.md:71-78) assumes a human-interactive flow ("sign in as that service account first... PATs are user-scoped"). If the actual mechanism is OAuth or admin-mint, the runbook step "sign in as sa_platform_vpp" is impossible (no MFA device, no interactive password) and the operator hits a dead end.

**H2 — "Stored in Trade Platform Team password vault" applies to the PATs, not just to the SA login.** Re-read Roel's Slack message (slack-rotation-harvest.md:75-76): *"I've put the sa_platform_vpp account credentials in our Trade Platform Team vault."* "Account credentials" = the SA's *login* (password + MFA seed), NOT the PATs the SA mints. PATs are minted *after* signing in as the SA; they are time-limited derived tokens. The vault note about credentials does not imply the PATs themselves are stored there. If they ARE stored there, it's a convention not documented in the Slack message. If they are NOT stored there, then the PATs exist between mint and cluster-apply ONLY in the operator's clipboard / terminal scrollback / shell history — a wide security window the runbook does not currently address.

**H3 — "CMC-side may operate MC PATs" is a single hypothesis that handles both PAT mint AND cluster apply.** It conflates two separable operations. Mint authority and cluster-apply authority are different: it's plausible that *Trade Platform mints* the MC PATs (because the SA `sa_platform_vpp@eneco.com` is a Trade Platform identity, not a CMC identity — vault-extracts.md:206-213 implies the SA is owned by Trade Platform Team) but *CMC applies* them to the MC clusters (because Trade Platform doesn't have `oc` access to MC OpenShift). If true, the runbook Section B has TWO actors and a handoff: Alex mints, CMC applies; Alex sends the new PAT to CMC by secure channel (which channel? Slack DM is NOT acceptable for a PAT; KV update is one option; out-of-band password-vault share is another). The plan currently frames Section B as a single decision: "Alex executes" OR "Alex files request" (plan.md:58-61) — but the real shape may be "Alex mints + Alex hands off + CMC applies + Alex verifies".

### Falsification scenario

The MC PAT lifecycle is actually: Trade Platform Team password vault holds the SA login. When a CMC engineer ("Lex" — slack-rotation-harvest.md:42) needs to update an MC ArgoCD's repo connection, they ping Fabrizio. Fabrizio signs in as `sa_platform_vpp` (with the vault-stored credential + his own MFA device, because the SA's MFA is registered to a hardware key kept in the Trade Platform office). Fabrizio mints the new PAT in ADO UI, copies it, sends it to Lex via 1Password's "secure share" link (single-view, expires in 1 hour). Lex receives the link, copies the PAT, runs `oc patch secret <repo-secret> -n eneco-vpp-argocd` on the MC cluster, restarts whatever needs restarting (per Goldilocks app), and confirms. The PAT never lives in Trade Platform's KV; the KV entries `argocd-repository-credentials-template-url-{acc,devmc}` (vault-extracts.md:194-198) are vestigial from an abandoned CSI-mount attempt that was never deleted. The "missing" `accmc` and `prdmc` entries don't exist because that attempt was abandoned mid-implementation.

Observable signature: ADO PAT audit log shows `created_by: <Fabrizio's user OID> for_target: sa_platform_vpp@eneco.com` (admin-mint), the `vpp-appsec-d` KV `argocd-repository-credentials-template-url-*` secrets have a `created` date older than 6 months with no rotation history (`az keyvault secret show --vault-name vpp-appsec-d --name <name> --query attributes`), and no `oc` command from a Trade Platform identity appears in MC audit logs for the `eneco-vpp-argocd` namespace.

### Cost of being wrong

Three layered costs:

1. **Runbook Section B writes the wrong actor**. If "Alex files a request with CMC" but actually Alex needs to mint, then file a request with the PAT in the request — the runbook misses the most security-sensitive step (how to transmit the PAT to CMC). Worst case: the operator pastes the PAT in a Slack DM to "Lex from CMC" because the runbook didn't specify a channel.

2. **`proposal-rotation-automation.md` Option B (KV+ESO)** is framed as a target state (plan.md:159-161). If the KV entries are vestigial from an abandoned attempt and the actual mechanism never touches Azure KV for MC, then proposing "extend the existing KV+ESO pattern" is proposing to build on a foundation that never worked. Fabrizio reads the proposal, sees the wrong premise, dismisses the document as "doesn't understand our setup."

3. **`draft-rotation-secrets.md` cross-source corroboration table (final-reqs:32, plan.md:13-27)** currently lists "sa_platform_vpp creds in Trade Platform Team password vault" as A2 INFER (plan.md:22). If the more-accurate claim is "SA login in vault, PATs ephemeral between mint and apply, transmission channel undocumented," the table is technically correct but operationally misleading. The deliverable's value-add (the cross-source matrix) is undermined.

### Discriminating probe (<5 min)

Two probes, both <5 min:

1. **ADO PAT audit log probe**: `az devops invoke --area Token --resource SessionTokens --org enecomanagedcloud --api-version 7.1-preview` (or equivalent REST call to `https://vssps.dev.azure.com/enecomanagedcloud/_apis/Token/SessionTokens?api-version=7.1-preview`) filtered for `displayName eq 'sa_platform_vpp@eneco.com'`. The response includes `authorizationId`, `targetAccounts`, and `validFrom`/`validTo`. Compare `targetAccounts` to expected `sa_platform_vpp` IDs — if `clientId` of an OAuth client appears as creator, mint is OAuth-based. Caveat: this requires the operator to ALREADY have PAT API access; chicken-and-egg if the only access is via the PAT under rotation. Alternative: ADO Web UI, sign in as Fabrizio (who has admin), navigate to https://dev.azure.com/enecomanagedcloud/_settings/users → sa_platform_vpp → PATs → view audit.

2. **One Fabrizio question**, asked in the same thread he opened: *"When you renew these, do you sign in as `sa_platform_vpp` interactively in the ADO UI, or is there an automated mint flow? And for the MC PATs — do you mint them and hand to CMC, or does CMC mint them via their own SA?"* This single question discriminates H1 and H3 in one go.

### Verdict

**REVISE.** The simplest-mechanism hypothesis is plausible but underspecified. Three concrete plan changes:

1. plan.md Q2 (plan.md:46-56) must split into "mint authority" and "apply authority" — two columns, not one. The runbook Section A and Section B inherit this split.
2. The runbook's pre-execution gate (final-reqs:50, G1-G5) must include a step "Confirm with Fabrizio whether mint requires SA interactive login or is OAuth/admin-mint." This is a single question; resolvable in 5 minutes.
3. Section B's handoff to CMC (if CMC-applies) must include an EXPLICIT secure-transmission channel: 1Password secure share, NOT Slack DM, NOT email. The runbook currently does not address this because the simplest-mechanism hypothesis doesn't surface it.
4. `proposal-rotation-automation.md` Option B (KV+ESO) needs a footnote: "Assumes the `argocd-repository-credentials-template-url-*` KV secrets in `vpp-appsec-d` are alive and consumed. If vestigial, Option B is greenfield not extension." Already partly addressed in plan.md F6 (plan.md:161); tighten further.

---

## Attack 4 (NEW — not in the dispatch's three items)

### The two-clock problem: PAT expiry + cluster Secret resourceVersion divergence

### Steel-man

The runbook's verification step (vault-extracts.md:117-129) reads the ApplicationSet's `status.conditions[?(@.type=="ErrorOccurred")].lastTransitionTime` and decides PASS when it is "≤2 min" fresh AND `status=False`. This is the truth surface for "auth recovered" (final-reqs:114). The recipe also annotates `argocd.argoproj.io/refresh=hard` to force a sync (vault-extracts.md:118-120). Together, these are the post-rotation control loop.

### The hidden assumption I haven't named yet

**The runbook conflates "the new PAT works" with "the new PAT is what's in use."** Two clocks tick during rotation:

- **Clock A**: ApplicationSet's `lastTransitionTime` — updated when the controller's reconcile cycle (every ~3 min — vault-extracts.md:36) runs and finds the auth condition resolved.
- **Clock B**: ArgoCD's in-memory cache of credentials for this Secret — which is updated when the Secret's `resourceVersion` changes AND the controller notices.

If `kubectl patch` increments `resourceVersion` (it does, normally) BUT the ArgoCD application controller's informer cache is stale or has been desync'd by a prior CRD reconcile error, the controller can fail to notice the Secret change. The `refresh=hard` annotation forces an Application reconcile, not a Secret cache invalidation. The Application reconcile then re-reads the *cached* credentials — which are the OLD ones. The result: ApplicationSet status flips to `ErrorOccurred=False` *because the cached controller was retried with stale creds and the retry just happened to occur in a window where the source server returned a transient 200 OR because ArgoCD's error condition has its own debounce* — and then later flips back when the actual stale creds are used. Worse: an operator sees `ErrorOccurred=False` and `lastTransitionTime` fresh, declares success, and walks away. 30 minutes later, the next reconcile fails again with the SAME message but the *new* `lastTransitionTime` is now beyond the "≤2 min" window — the on-call sees "old error, ignore" and the issue silently persists.

### Falsification scenario

Operator runs Steps 1-5 cleanly. `kubectl patch` succeeds, Secret's `resourceVersion` increments. `kubectl annotate applicationset ... refresh=hard` succeeds. The 6-iteration wait loop (vault-extracts.md:121-128) sees: iteration 1 = `ErrorOccurred=True` (old cache); iteration 2 = `ErrorOccurred=True`; iteration 3 = `ErrorOccurred=False`, `lastTransitionTime=now-30s`. Loop breaks: "OK: ApplicationSet auth recovered" (vault-extracts.md:127). Operator runs the curl test (vault-extracts.md:158), gets HTTP/2 200 + Request-Context. Closes ticket.

Next morning, `vpp-feature-branch-environments` ApplicationSet has been red for 4 hours; pattern is the SAME `ApplicationGenerationFromParamsError: ... authentication required` (vault-extracts.md:36); `lastTransitionTime` is 4 hours ago. The on-call sees "stale error, controller probably stuck" and restarts `argocd-application-controller` (explicitly anti-patterned: vault-extracts.md:171, 178). Now ArgoCD restarts, picks up the patched Secret correctly, recovers — and the on-call mis-attributes the fix to the controller restart, which the vault recipe forbids. Future operators learn the wrong lesson.

### Cost of being wrong

Cumulative: (a) runbook's Step 6 verification gives false positives → on-call declares success prematurely; (b) the anti-pattern `argocd-application-controller restart` (vault-extracts.md:171, 178) becomes accidentally validated in the team's oral knowledge; (c) the pattern doc's signature #5 (vault-extracts.md:189-190 — "recent `lastTransitionTime`") becomes ambiguous because the recipe's "fresh transition" can be a stale cache flip, not a true recovery; (d) the on-call burns trust with Fabrizio when the third incident proves the runbook's verification is unreliable.

### Discriminating probe (<5 min)

Two-probe combination, run AFTER Step 5 patch and BEFORE declaring success:

1. **Direct credential validation through ArgoCD's own credential path**, not through ApplicationSet condition: `argocd repo get $(kubectl get secret <name> -n argocd -o jsonpath='{.data.url}' | base64 -d) --grpc-web -o json | jq .connectionState` — or, if argocd CLI not available, exec into the `argocd-repo-server` Pod and run a `git ls-remote` using the credentials *as the server reads them from its watcher*. Decision: `connectionState.status == "Successful"` AND `connectionState.attemptedAt` is post-patch.

2. **`resourceVersion` delta check**: capture `kubectl get secret <name> -n argocd -o jsonpath='{.metadata.resourceVersion}'` before AND after patch. The new `resourceVersion` MUST be > pre-patch value. Then: `kubectl logs deployment/argocd-application-controller -n argocd --since=2m | grep -i "secret.*<name>"` — verify the controller logged a re-read of the Secret. If no log entry, the controller's informer didn't see it.

### Verdict

**REVISE.** The current verification surface (ApplicationSet `ErrorOccurred=False` + curl HTTP 200) is necessary but not sufficient. Add to the runbook:

1. Step 6.5: `argocd repo get` (or the in-pod `git ls-remote` equivalent) using the ArgoCD-server-rendered credentials, NOT the operator's locally-stored new PAT. The locally-stored PAT proved valid at Step 4 (curl test, vault-extracts.md:82-87); Step 6.5 proves the *cluster* uses that PAT — closing the two-clock gap.
2. Add `connectionState.attemptedAt` to the success criteria. The current `lastTransitionTime` check (vault-extracts.md:125) is insufficient because that field is the *condition's* transition, not the credential's.
3. Pattern doc cross-reference: pattern-argocd-pat-expiry-blocks-new-fbe-apps.md signature #5 (vault-extracts.md:189-190) should be updated to require BOTH ApplicationSet condition AND `argocd repo` `connectionState` checks.

This attack is route-flipping for the runbook because it changes Section A's verification gate, which is the most-used part of the deliverable.

---

## Cross-attack synthesis

The four attacks share a common generator: **the inherited interpretation treats *observable absence* as *evidence of absence*, and *observable success* as *evidence of correctness*.** 

- Attack 1: "no IaC found" ≠ "no reconciler exists"
- Attack 2: "no documentation surfaced in 33 searches" ≠ "no documentation exists"
- Attack 3: "no mint authority documented" ≠ "mint authority is what we assumed"
- Attack 4: "ApplicationSet condition flipped" ≠ "credentials are actually being used"

**Recurrence class**: search-bounded-by-tool conclusions promoted to FACT without naming the boundary. **Pattern-level falsifier for the runbook**: every load-bearing absence claim MUST cite the search scope ("searched X, Y, Z; absence in those scopes") and either name what could still falsify it OR mark `[PENDING]` if a cheap probe exists.

**Three concrete runbook changes that address all four attacks together**:

1. **Pre-flight ownership probe (Step 4.5)**: ownership labels, OwnerReferences, Helm/Kustomize/sealed-secret/ArgoCD annotations. Addresses Attack 1 directly, Attack 4 by exposing controller identity.
2. **Two-question Fabrizio pre-call**: (i) mint mechanism + actor split, (ii) third-wiki / canvas / private-doc existence. Addresses Attack 2 + Attack 3 in one DM.
3. **Two-clock verification (Step 6.5)**: `argocd repo` connection state + Secret `resourceVersion` delta + controller log evidence. Addresses Attack 4.

These three additions cost <15 min of operator time per rotation and discriminate against all four falsification scenarios.

---

## Meta-falsifier (Rule 11)

**What would prove THIS REVIEW wrong?**

- Attack 1: A `kubectl get secret -o yaml` of the live sandbox `repo-*` Secret showing zero ownership labels, zero annotations, zero ownerReferences → my "Helm-managed" hypothesis is dead, the recipe's `kubectl patch` is durable.
- Attack 2: A targeted question to Fabrizio "anything in Platform-team-internal?" returning "no" → the search-scope-bounded concern is mitigated to negligible.
- Attack 3: Fabrizio's answer "I sign in as the SA interactively, I do the cluster apply for MC too, the KV entries are stale" → the simplest-mechanism hypothesis IS correct; the actor-split nuance is moot.
- Attack 4: A controlled test run where `argocd repo get` `connectionState` flips to Successful at the same moment as ApplicationSet's `lastTransitionTime` → the two-clock concern is illusory at this version of ArgoCD.

**What am I assuming about the work that might be incorrect?**

- I assume the deliverables target an audience that is NOT Fabrizio (because Fabrizio doesn't need a runbook). If the actual primary reader IS Fabrizio (for review + canonicalization), my emphasis on "ask Fabrizio" loops is wrong; the runbook becomes self-referential.
- I assume `argocd repo get` is available in the operator's environment (CLI installed, gRPC reachable). If not, my Step 6.5 prescription is impossible without alternative.

**Domain gaps**

- I do NOT have direct knowledge of OpenShift GitOps Operator's reconciler behavior re: Secrets it does not own. My Attack 1 H1 generalization that "any external reconciler could revert" is strong for Helm but speculative for the OpenShift GitOps Operator on MC. Section B may need its own Attack 1 variant by an OpenShift-domain specialist.
- I do NOT have access to ADO's PAT admin-mint API behavior in detail. Attack 3 H1's "OAuth or admin-mint" alternatives are plausible but not authoritatively cited from Microsoft Learn. Coordinator may want to dispatch a `microsoft-docs-mcp` search before committing to my prescription.

**If I'm wrong, how would I find out?** P7 runtime probes (the live `kubectl get secret -o yaml` is the single most-discriminating evidence) + Fabrizio's response to the two-question DM. Both are <10 min of effort and either confirms or destroys my four attacks.
