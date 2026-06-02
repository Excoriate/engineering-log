---
task_id: 2026-06-02-001
agent: sherlock-holmes
status: complete
summary: >-
  Adversarial root-cause review of the vpp-agg Sandbox keys-secret RCA. The
  SANDBOX-level conclusion (CD does not create `keys` in Sandbox; SPC excludes
  it; manual stop-gap; durable fix = wire KV->CSI) SURVIVES. But the RCA's
  GLOBAL framing is REFUTED on three load-bearing claims: (1) "common chart is
  dead code / created by NO environment's CD" is FALSE — `common` is packaged
  and pushed to OCI `vppacra.azurecr.io/helm-agg` on every build and consumed by
  the previously-unsearched `Eneco.Vpp.Aggregation.GitOps` app-of-apps, which
  sets container.env=DevMC and fires the `keys` branch in MC dev/acc/prd; (2)
  the provenance argument "managedFields:[] => created by hand" is INVALID —
  the CSI-projected application-secret also has empty managedFields on this
  cluster; ownerReferences (not managedFields) is the real discriminator; (3)
  "ESO is documented intent, not configured" understates reality — ESO IS
  installed and actively syncing in Sandbox. Verdict: SOUND-WITH-CAVEATS for the
  Sandbox fix; the regression-class narrative and several A1 labels need
  correction. Strongest unEliminated alternative: in MC the `keys` provisioning
  IS automated via GitOps+OCI, so the real Sandbox gap is "Sandbox is not
  enrolled in the GitOps deploy path that MC uses", not "keys is universally
  dead code".
timestamp: 2026-06-02T12:15:00+02:00
---

# Adversarial Root-Cause Receipt — Sherlock (Investigation & Reproduction)

> Win condition: FALSIFY the root cause, not confirm it. I attacked the five
> named claims with read-only ADO + read-only live Sandbox probes. The dispatch
> explicitly demanded I close the cross-repo residual the RCA left open (rca.md
> line 310). I closed it — and it broke part of the RCA.

## Method note (provenance of my own evidence)

- ADO read-only via `eneco-context-repos` scripts (PAT in env). No git mutation.
- Live Sandbox via the pre-provisioned isolated kubeconfig
  `/tmp/sb-kubeconfig-2026-06-02-001`. No `az account set`, no `~/.kube/config`
  touch, no destructive ops, no secret/private-key values printed.
- A `task-workspace-guard.sh` PostToolUse hook fired on a sibling agent's
  sentinel (`current-task.json` points at task `2026-06-02-004`). I did NOT
  overwrite it; my only write is this receipt, inside my own task workspace.

---

## Finding 1 — "The `keys` secret is created by NO environment's CD; only ever via manual helm/kubectl"

**Verdict attempt: REFUTED (as a global claim). The residual the RCA flagged
A3-low is actually a live provisioning path. The Sandbox-scoped version of the
claim survives, but the RCA's wording and the "dead code" mechanism are wrong.**

**Severity: HIGH** (the central mechanism statement in TL;DR, L5, L6, L10 is
built on a false-negative search; the regression class is mis-told).

### Evidence (the surviving path the RCA missed)

The RCA + all lanes searched only `Eneco.Vpp.Aggregation`, `…Infrastructure`,
`…Infrastructure.Mc`, and (by name only) `VPP.GitOps`. They never searched the
repo that actually deploys the agg charts via GitOps. `ado-list-repos` shows it:

```text
Eneco.Vpp.Aggregation.GitOps                  main   1899 KB   <-- NEVER SEARCHED
```
(command: `ado-list-repos.sh --project "Myriad - VPP"`)

That repo is an ArgoCD app-of-apps. Its `common` chart pulls the OCI-published
`common` chart as a dependency and sets the env that fires the `keys` branch:

```yaml
# Eneco.Vpp.Aggregation.GitOps : Helm/common/dev/Chart.yaml
dependencies:
  - name: common
    version: 0.1.6
    repository: oci://vppacra.azurecr.io/helm-agg     # <-- common IS published & consumed

# Eneco.Vpp.Aggregation.GitOps : Helm/common/dev/values.yaml
common:
  enabled: true
  container:
    env: DevMC                                        # <-- the "dead" branch IS set
```
(command: `ado-repo-file.sh --repo Eneco.Vpp.Aggregation.GitOps --path Helm/common/dev/values.yaml --branch main`)

And `common` is pushed to that OCI registry by the app repo's own build, by
**glob iteration over every chart** — which is exactly why the RCA's literal
`ado-repo-search "Helm/common" = 0 hits` was a false negative:

```bash
# Eneco.Vpp.Aggregation : azure-pipeline/pipelines/build/stages/helm-chart-push.yaml
ls azure-pipeline/Helm/ > /tmp/input.txt
cd azure-pipeline/Helm/
for i in $(cat /tmp/input.txt); do
  helm lint $i; helm package $i
  helm push $i-*.tgz oci://${{ parameters.containerRegistry }}.azurecr.io/helm-agg
done
```
(command: `ado-repo-file.sh --repo Eneco.Vpp.Aggregation --path azure-pipeline/pipelines/build/stages/helm-chart-push.yaml --branch development`)

The GitOps AppProject confirms the OCI source is a sanctioned, automated source:

```yaml
# platform-gitops : eneco-vpp-argocd/argocd-projects/base/aggregation-layer.yaml
sourceRepos:
  - .../Eneco.Vpp.Aggregation.GitOps
  - vppacra.azurecr.io
  - vppacra.azurecr.io/helm-agg
destinations:
  - namespace: eneco-vpp-agg           # MC namespace, NOT Sandbox vpp-agg
```
(command: `ado-repo-file.sh --repo platform-gitops --path eneco-vpp-argocd/argocd-projects/base/aggregation-layer.yaml --branch main`)

### What survives and what does not

- **SURVIVES (Sandbox scope):** In Sandbox (`vpp-aks01-d`, namespace `vpp-agg`),
  `keys` is NOT created by CD. The GitOps app-of-apps targets `eneco-vpp-agg`
  (MC), and on the Sandbox cluster there is **no `eneco-vpp-agg` namespace**:
  ```text
  $ kubectl get ns | grep -iE 'vpp|agg'
  aggregation-layer  vpp  vpp-agg  vpp-agg-monitoring  vpp-agg-test
  # eneco-vpp-agg ABSENT
  ```
  The Sandbox `*fn` charts are Helm-deployed by the in-repo ADO pipeline (gated
  to environment vpp-agg/afi), which does not deploy `common`. No
  `sh.helm.release.v1.common.*` exists in `vpp-agg`. So the Sandbox symptom is
  correctly explained.
- **REFUTED (global framing):** "the `common` chart is referenced by NO deploy
  pipeline (dead code). So CD creates `keys` in NO environment." (rca.md TL;DR
  lines 38-39; lane-r1 lines 236-237; L10 lesson #1 "created in no environment").
  In MC dev/acc/prod, `common` is published to OCI and consumed by the GitOps
  app-of-apps with `container.env=DevMC` → the `keys` branch renders. The
  "dead code in every environment" story is false.

  Caveat on my own evidence: I did NOT confirm by live MC probe that the GitOps
  `apps:` list actually enrolls `common` as an ArgoCD Application — the
  `agg-argocd-application/values.{dev,acc,prod}.yaml` `apps:` lists I read do
  NOT include a `common` app (they list `*fn` + `secretprovider` +
  `ocp-prometheus-alerting`). So `common/dev` exists in the tree and is wired as
  an OCI dependency, but its enrollment as a standalone synced app is
  **[A3 UNVERIFIED[blocked: no MC cluster access in this dispatch]]**. Either
  way, the existence of the published OCI chart + the DevMC env value + the
  app-repo push loop is enough to refute "dead code / created by no CD".

### If accepted → which sections must change

- rca.md **TL;DR** (lines 36-49): rewrite `CAUSE` — `common` is not dead code; it
  is OCI-published and GitOps-consumed in MC. The Sandbox cause is "Sandbox is
  served by the legacy in-repo Helm pipeline, which does not deploy `common`,
  and is not enrolled in the `Eneco.Vpp.Aggregation.GitOps` app-of-apps that MC
  uses."
- rca.md **L5 TRUTH 1** (lines 143-145) and **L6** (lines 162-174): the
  `ado-repo-search "Helm/common" = 0 hits` evidence must be retracted as a
  false negative; add the OCI push loop + GitOps dependency.
- rca.md **L2 repo table** (lines 82-90): add `Eneco.Vpp.Aggregation.GitOps`,
  `platform-gitops`, and the OCI registry `vppacra.azurecr.io/helm-agg`.
- rca.md **L10 lesson #1** (line 223): the "created in no environment" claim is
  false; reframe as "the lookup stopped at the wrong repo — the GitOps repo was
  never searched."
- rca.md **Challenge-defense row** (line 310): the named residual is no longer
  A3-low; it is resolved and partially overturns the global claim.
- rca.md **Evidence ledger #2** (line 293): downgrade from A1 to corrected.

---

## Finding 2 — "Never-created" vs "created-then-lost"; is `managedFields:[]` conclusive?

**Verdict attempt: PARTIALLY REFUTED. The specific inference
"managedFields empty ⇒ created by hand" is INVALID on this cluster. The broader
"created manually" conclusion still stands on OTHER evidence (Johnson's own
statement + no helm/CSI annotations + no ownerReferences), but the RCA
over-claims its strength and cites the wrong discriminator.**

**Severity: MEDIUM** (conclusion survives via other evidence, but a stated A1
proof is wrong and the challenge-defense rests on it).

### Evidence

The RCA's decisive provenance line (live-sandbox-probe.md line 22; rca.md L5
TRUTH 3 line 153; Challenge-defense line 307) is: `managedFields: []` ⇒ "created
by hand." I tested that discriminator against a secret the RCA itself certifies
as CSI-created (`application-secret`, created 2025-01-20):

```text
$ kubectl -n vpp-agg get secret keys              -> managedFields: null  (empty)
$ kubectl -n vpp-agg get secret application-secret -> managedFields: []    (empty)  AND ownerReferences: [Job, ReplicaSet, ...]
```

So **empty managedFields is NOT unique to manual creation** here — the
CSI/controller-projected secret also has empty managedFields (likely SSA field
tracking stripped or not recorded for these projected secrets on K8s 1.31.11).
The valid discriminator is **ownerReferences**: `application-secret` has them
(Job/ReplicaSet), `keys` has none. The RCA conflated managedFields with
ownerReferences.

"Created-then-lost by a controller" remains effectively unfalsifiable now
(events aged out), but it is also unnecessary: no controller in Sandbox claims
`keys` (no SPC projects it, no ExternalSecret targets it — see Finding 5
evidence), so there is no controller that would have created it. That argument
is sound; the managedFields argument is not.

### If accepted → which sections must change

- live-sandbox-probe.md (lines 20-25) and rca.md **L5 TRUTH 3** (line 153):
  replace "NO managedFields … → created by hand" with "NO ownerReferences and
  NO helm.sh/release or csi labels → not owned by Helm/CSI/Argo; consistent with
  manual creation (corroborated by Johnson's statement)." Drop managedFields as
  the proof.
- rca.md **Challenge-defense** row 1 (line 307): remove "no managedFields" from
  the three-fact argument; keep the no-owner + no-pipeline + SPC-excludes facts.
- rca.md **Evidence ledger #4** (line 295): the basis is owner/annotation
  absence + reporter statement, not managedFields.

---

## Finding 3 — Audit A1 labels that are actually A2/A3

**Verdict attempt: CONFIRMED mislabels found.**
**Severity: MEDIUM** (evidence-label discipline is mandatory per repo rules;
several A1 claims are inference or false-negative).

| rca.md location | Claim | Stated | Should be | Why |
|---|---|---|---|---|
| L5 line 145; ledger #2 (293) | "`common` referenced by NO pipeline (search=0 hits)" | A1 | **Refuted** | False negative; `common` is OCI-pushed via glob + GitOps-consumed (Finding 1). |
| L5 line 153; ledger #4 (295) | "no managedFields → created by hand" | A1 | **A2, and the cited proof is invalid** | CSI secret also has empty managedFields (Finding 2). |
| L3 line 99 | "ArgoCD … only an influxdb app touches anything agg-named" | A1 | **A2 / incomplete** | Live: Sandbox ArgoCD also runs ESO, cert-manager, an `aggregation-layer` AppProject + namespace, FBE app-of-apps. The agg `*fn` are Helm-deployed (true), but "ArgoCD manages nothing agg-related" is an overread (Finding 5). |
| L10 line 36 / line 225; Challenge-defense (308) | "ESO is the documented ideal but is NOT configured" | A1/A2 | **A2, partly wrong** | ESO IS installed & syncing in Sandbox (Finding 5). Correct statement: "ESO is installed but no ExternalSecret targets `keys`." |
| Ledger #9 (300) | "previous cert expired ~6 months ago" | A2 | A2 (correct) | Properly hedged; see Finding 4. |

### If accepted → which sections must change

- Correct the four mislabeled rows above; the RCA's own Evidence ledger and the
  on-call rule (`.claude/rules/domain/on-call-incident-workflow.md`: "Unverified
  claims stated as facts = harness violation") require it.

---

## Finding 4 — Timeline: "previous cert expired ~6 months ago" given notBefore 2025-12-09 / KV refresh 2026-05-29

**Verdict attempt: NOT REFUTED, but the RCA correctly flags it A2 and should go
further: there is NO evidence a `keys` secret EVER existed in Sandbox before
2026-06-01.**
**Severity: LOW** (already hedged; severity is low anyway).

### Evidence / reasoning

- Live facts: manual `keys` created `2026-06-01T08:56:40Z`; KV `kafka-*`
  (re)created `2026-05-29`; client cert `notBefore 2025-12-09`,
  `notAfter 2027-01-09`. (live-sandbox-probe.md lines 49-50; my re-probe
  confirms creationTimestamp 2026-06-01T08:56:40Z.)
- The "~6 months" rests entirely on (a) Johnson's verbal "most probably more
  than 6 months" (slack-intake.md lines 28-30) and (b) the new cert's notBefore
  ~6 months before the fix. Neither establishes that an OLD `keys` secret
  existed in Sandbox and expired. The "broken since the cert expired" story and
  the "never-created in Sandbox" story (Finding 1/2) are in tension: if `keys`
  was NEVER created by Sandbox CD (true), then "it broke when the cert expired"
  implies a prior hand-made `keys` that later vanished — which is the
  "created-then-lost" branch the RCA dismisses. The RCA cannot have it both
  ways without acknowledging the tension.
- Most parsimonious reconciliation consistent with all evidence: a human
  hand-applied `keys` at some past point (as humans do — Johnson just did it
  again); it was lost on a namespace/redeploy event; and "expired cert" is
  Johnson's recollection of why he had to refresh material, not proof of an
  automated expiry. The RCA's notBefore-based "~6 months" is plausible but
  underdetermined.

### If accepted → which sections must change

- rca.md **L7 timeline** (lines 184-193) and ledger #9 (300): add the explicit
  caveat that no evidence shows a pre-existing Sandbox `keys`; the "expired"
  framing is the reporter's account, and "never-created vs created-then-lost"
  cannot be distinguished from current evidence. This also forces consistency
  with Finding 2.

---

## Finding 5 — Strongest alternative hypothesis the RCA failed to eliminate + cheapest discriminating probe

**Strongest unEliminated alternative (H-alt):**
"The Sandbox `vpp-agg` failure is not a universal provisioning defect — it is a
**Sandbox enrollment gap**: MC environments provision `keys` automatically via
the `Eneco.Vpp.Aggregation.GitOps` app-of-apps + OCI `common` chart
(container.env=DevMC fires the secret), but the **Sandbox cluster was never
enrolled in that GitOps path** (it still runs the legacy in-repo Helm pipeline
that omits `common`). Therefore the durable fix is not necessarily 'add keys to
the CSI SPC and delete the inline secret'; it could equally be 'enroll Sandbox
in the same GitOps `common` deployment MC already uses' — and the inline
`common/secret.yaml` is NOT dead code that can be safely deleted, because MC
relies on it via the OCI-published chart."

This matters because **fix.md Layer 1 step 2 says "Delete
`common/templates/secret.yaml`"**. If MC provisions `keys` through exactly that
template (via the OCI chart + DevMC branch), deleting it would **break MC
dev/acc/prod** — the fix could regress production. The RCA never eliminated this.

Secondary unEliminated alternative: ESO. ESO is installed and syncing in
Sandbox (`external-secrets-operator` ArgoCD app; 5 live `ExternalSecret`s in FBE
namespaces, `SecretSynced/True`). An ExternalSecret for `keys` is a viable
durable fix the RCA/fix never considered (it only weighs CSI). Evidence:

```text
$ kubectl get externalsecret -A
ionix/jupiter/kidu/thor/voltex  dispatcher-secrets  ...  SecretSynced  True
# ESO is live; no ExternalSecret targets vpp-agg/keys
```

**Cheapest discriminating probe (≤5 min, read-only):** confirm whether MC
`keys` comes from the inline `common` template before anyone deletes it.
```bash
# 1. Does the GitOps app-of-apps actually enroll `common` as a synced app in MC?
#    (read-only ADO already done: apps: list does NOT include `common`; but the
#     common/dev Chart pulls the OCI common chart as a dependency of *fn? verify)
ado-repo-file.sh --repo Eneco.Vpp.Aggregation.GitOps --path Helm/dataingestionfn/dev/Chart.yaml --branch main
#    -> if *fn charts depend on the OCI `common` chart, then `keys` is rendered
#       as a sub-chart resource of every *fn release in MC (NOT a standalone app).
# 2. Live MC (if access granted to a dev MC cluster), read-only:
kubectl -n eneco-vpp-agg get secret keys -o json | jq '{owner:.metadata.ownerReferences, mgr:[.metadata.managedFields[]?.manager], helm:(.metadata.annotations["meta.helm.sh/release-name"])}'
#    -> if it carries a helm release annotation for a *fn or common release,
#       then deleting common/templates/secret.yaml WILL break MC. Discriminates
#       H-alt (enrollment gap, do-not-delete) vs RCA (safe-to-delete dead code).
```
A `helm` annotation or `common` sub-chart dependency on the MC `keys` ⇒ H-alt
holds ⇒ fix.md must not blindly delete the template. Absence everywhere ⇒ RCA's
delete step is safe.

### If accepted → which sections must change

- fix.md **Layer 1 step 2** (lines 78, 200 of rca.md): gate the
  "delete `common/templates/secret.yaml`" step behind the MC-provenance probe
  above; today it risks regressing MC. Add ESO as an alternative provider option
  (it is already installed).
- rca.md **L8 / Knowledge-contract claim #5** ("reject three plausible-but-wrong
  explanations"): the "Sandbox has no secret provider / ArgoCD drift" rejections
  are too strong given the live ArgoCD+ESO+cert-manager stack; re-scope them.

---

## Cross-cutting note on the supporting lanes (where the gap entered)

- lane-r1 line 249 and lane-r2 lines 100/129 BOTH explicitly punted the
  cross-repo GitOps question to "a separate lane" — and that lane was never run
  before the RCA was written. The RCA imported the lanes' A3 residual as a
  low-risk footnote (rca.md line 310) instead of resolving it. The dispatch was
  right to demand it be closed. This is a process finding: a negative existential
  ("created by NO CD") was published as the central mechanism while its own
  evidence chain flagged an unsearched repo.

---

## Overall verdict

**SOUND-WITH-CAVEATS.**

- The **operational Sandbox diagnosis** (why 10 `*fn` pods FailedMount in
  `vpp-agg`: `keys` absent, SPC excludes it, no `common` Helm release, manual
  stop-gap restored it) is **correct and well-evidenced** — it survives attack.
- But the **root-cause NARRATIVE is partly wrong**: "common is dead code created
  by no environment's CD" is REFUTED for MC (Finding 1); the "managedFields ⇒
  manual" proof is INVALID (Finding 2); "ESO not configured" is wrong (Finding
  5); four A1 labels are mislabeled (Finding 3).
- The **proposed durable fix carries an unEliminated regression risk to MC**
  (deleting the inline `common` secret template that MC may depend on — Finding
  5). That single step should be gated behind the cheap MC-provenance probe
  before the RCA is taken out of `pending_review`.

Net: the firefight conclusion is safe; the "mechanism + class + delete-the-
template" parts need the corrections above before this RCA is trustworthy as a
durable, copy-pasteable fix.
