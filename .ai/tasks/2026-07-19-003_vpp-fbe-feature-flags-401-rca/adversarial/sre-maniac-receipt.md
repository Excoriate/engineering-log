---
task_id: 2026-07-19-003
agent: sre-maniac
status: complete
timestamp: 2026-07-19T00:00:00Z
attack_lane: reliability + fix viability (NOT goal-fidelity, NOT terraform-syntax)
summary: |
  Attacked 4 load-bearing reliability claims in how-to-fix.md P1/P2. Core mechanism
  (frozen appconfig.js → stale HMAC → 401) is A1-solid and restart fixes it. But the fix
  ships two real "green-but-wrong" holes and one un-excluded alternative cause. No claim
  breaks the fix outright; two MEDIUM findings must be resolved before the PR gate is trusted.
---

# SRE-Maniac Adversarial Receipt — FBE feature-flags 401 fix

Attack lane: **reliability + fix viability only.** Goal-fidelity (does the deliverable match
Duncan's verbatim ask) and Terraform syntax are other reviewers' lanes — where a finding
straddles the boundary I say so and stop.

Evidence read: `rca.md`, `how-to-fix.md`, `context/live-probe-findings.md`, plus live repo
probe of the create pipeline `Myriad%20-%20VPP/hotfix/azure-pipelines-featurebr-env.yml`
(lines 554-648) and frontend-source greps under `myriad.frontend.edge`.

Belief labels: A1 = live-witnessed this session; A2 = inferred; A3 = blocked.

---

## Verdict table (ranked by severity)

| # | Claim | Verdict | Severity |
|---|-------|---------|----------|
| 3b | "Tennet NL" indicator is driven by App Config → restart restores it | **SURVIVES-WITH-UNCLOSED-RESIDUAL** | **MEDIUM** |
| 1a | P1 pipeline effect-check gate proves the pod is fixed | **BROKEN (green-but-wrong window)** | **MEDIUM** |
| 1b | P1 rollout-restart fixes "the recreate case" | **SURVIVES, but scoped — pipeline-driven recreate only** | LOW |
| 2 | CSI updates the K8s Secret so Reloader fires (not files-only) | **SURVIVES (strong live proof)** | LOW |
| 3a | Duncan's clean 401 == the reproduced drift | **SURVIVES mechanism; exact 401 variant INFERRED not reproduced** | LOW |
| 3c | Mechanism is the ONLY cause (clock/localauth/CORS/firewall) | **SURVIVES — alternatives excluded by healthy jupiter** | LOW |
| 4 | No cascading/again-broken risk from the actions | **SURVIVES — risk LOW and disclosed** | LOW |
| 1c | "the job may have no cluster credentials" (fix's own risk) | **OVERSTATED — creds demonstrably available in-pipeline** | INFO |

---

## Claim 1 — P1 pipeline rollout-restart fixes the recreate case

### 1a — BROKEN: the automated effect-check can pass green while the pod is still stale (MEDIUM)

The pipeline gate in `how-to-fix.md` (lines 96-101) is:

```bash
BAKED=$(... appconfig.js ... Endpoint=)
CUR=$(... application-secret ... Endpoint=)
[ "$BAKED" = "$CUR" ] || { echo "still stale"; exit 1; }
```

**Failure scenario (inputs → wrong outcome):** On a recreate where the namespace/pods
survive, the pipeline restarts the frontend. The re-baked `appconfig.js` is copied FROM
`application-secret`. If CSI rotation has **not yet** propagated the new store into
`application-secret` at restart time (KV write lag, CSI mount hiccup, or the 2 s poll simply
not having fired for this key), then `BAKED == CUR` are **both the OLD store** → the gate
returns 0 (green) → pipeline succeeds → browser still 401. The gate validates *internal
consistency*, not *correctness against Azure*.

This is a textbook looks-correct-while-wrong hole: the RCA's own manual verification (L9
step 1 / how-to-fix Verification step 1) **does** cross-check the endpoint against the live
Azure store (`az resource list ... configurationStores`), but that Azure assertion was
**dropped from the automated pipeline gate**. The strongest check exists on paper and is
absent from the code that actually gates the deploy.

**Discriminating evidence / fix:** the pipeline effect-check MUST also assert the baked
endpoint host resolves to an existing store:
`az resource list -g rg-vpp-app-sb-401 --resource-type Microsoft.AppConfiguration/configurationStores ... --query "[].name" -o tsv | grep -q "$STORE"`.
Without that line, the gate is not a proof.

Probability is low (2 s poll usually wins the race by minutes, since `DeployInfra` writes KV
several stages before `DeployFBEInArgoCD`), but the gate is supposed to be the last line of
defense precisely for the low-probability tail. Severity MEDIUM because it silently converts
a real failure into a green pipeline — the exact "green pipeline ≠ runtime health" trap the
RCA L-lessons warn about.

### 1b — SURVIVES (scoped): only closes pipeline-driven recreate (LOW)

P1 fires only inside the create pipeline. Any store recreate that does NOT go through
pipeline 2412 (manual `terraform apply` hitting ForceNew, drift-correction re-apply, or a
future scheduled reconcile) leaves the surviving pod stale and P1 never runs. The fix is
honest about this ("P1 alone closes Duncan's ask IF the store only ever changes via the
pipeline") and delegates the trigger-agnostic case to P2/Reloader. So claim survives as
written — but P1 shipped **without** P2 would regress on out-of-band recreates. Ship P1+P2
together as the fix already prescribes; do not ship P1 alone.

### 1c — the fix's own "no cluster credentials" risk is OVERSTATED (INFO)

`how-to-fix.md` flags (A2) that the `DeployFBEInArgoCD` job "may have no direct cluster
credentials." Live probe: **A1** — the job (`CreateFeatureBranchEnvironmentStack`, pipeline
lines 564-627) indeed has none today (it only `checkout: gitops`, commits `{slot}.yaml`, and
runs a blind PowerShell 180 s countdown at lines 614-626). **But** the sibling `Infra_tests`
stage (lines 641-648) already authenticates to the same cluster via
`azureSubscription: $(azureSubscription)` + `AKSClusterName: $(aksDevClusterName)` running
Pester against AKS. So the service connection with AKS reach **exists in this pipeline**; the
kubectl variant (`az aks get-credentials -g rg-vpp-app-sb-401 -n vpp-aks01-d`) is directly
feasible by reusing `$(azureSubscription)`. This makes P1 MORE viable than the fix claims, not
less. No action beyond: use `$(azureSubscription)`, not the `<sandbox-service-connection>`
placeholder.

---

## Claim 2 — CSI updates the K8s Secret so Reloader fires (SURVIVES — strong live proof)

The user's sharpest concern: does secrets-store-CSI `secretObjects` actually **UPDATE the
Kubernetes `application-secret`** on rotation, or only refresh the mounted files? If files-only,
Reloader's informer sees nothing and P2 is inert.

**This is settled by live evidence, not doctrine.** The drift table (evidence ledger lines
48-55; RCA L7) shows on all 5 drifted slots the pod has `restarts=0` yet `application-secret`
holds the **NEW** store while the pod's baked file holds the **OLD** one. The only path by
which `application-secret` (a Kubernetes Secret object) changed value **without a pod restart**
is the CSI rotation reconciler mutating the Secret object in place. That is direct proof the
K8s Secret's `resourceVersion` bumps on rotation → Reloader's Secret informer **would** fire.
Combined with `--enable-secret-rotation=true --rotation-poll-interval=2s` (ledger line 39),
claim SURVIVES.

**Stress on "one-time mount vs ongoing rotation":** the user asked whether the evidence proves
*ongoing* rotation or a *one-time* mount snapshot. It proves ongoing: a one-time mount would
have frozen `application-secret` at the pod's creation-date value (the OLD store), exactly like
`appconfig.js` froze. Instead the Secret moved FORWARD to a store created *after* the pod
started, under a pod that never restarted. That is only explicable by continuous reconciliation.

**Residual (LOW, latent — not a current break):** CSI `secretObjects` sync is alive **only
while at least one pod in the namespace mounts the SPC volume**. It is mounted today (that is
why the Secret updates). But if a future chart change drops the CSI volume mount and relies on
`secretKeyRef` alone, the Secret sync silently stops and **both P1 and P2 break at once**, with
no signal (healthz-only probe). Recommend an explicit note in the chart that the SPC volume
mount is load-bearing for rotation, and — ideally — a readiness probe that validates the flag
endpoint (already proposed as P4) so a dead credential can never report Ready.

---

## Claim 3 — the mechanism is the ONLY cause

### 3c — SURVIVES: clock skew / disableLocalAuth / CORS / firewall all excluded (LOW)

The single best discriminator is **jupiter is healthy on the same cluster**:

- **Clock skew >15 min** (HMAC-SHA256 is timestamp-signed): would 401 *every* slot on that
  node/cluster, including jupiter. jupiter serves 200 → cluster clock is fine. Excluded.
- **`disableLocalAuth`**: would reject *all* HMAC keys including jupiter's. jupiter authenticates
  via HMAC and works → local auth enabled fleet-wide. Excluded.
- **CORS**: surfaces as a browser preflight block, not an `HTTP 401 www-authenticate: HMAC-SHA256`
  from the data plane; and would hit all slots. Ledger line 75 shows the live store returns a
  genuine HMAC auth challenge. Excluded.
- **App Config firewall / private-endpoint**: returns **403** (Forbidden), not **401**
  (Unauthorized), and would hit jupiter too. Symptom is 401. Excluded.

All four alternatives collapse against the same two facts: 401≠403 and jupiter-healthy-on-same-cluster.

### 3b — UNCLOSED RESIDUAL: "Tennet NL" → App Config binding not traced in source (MEDIUM)

This is the one place I can materially dent **fix viability** (does restart actually restore
what Duncan sees). The RCA asserts (L1, context ledger line 24) that the Dutch-flag / "Tennet
NL" indicator is a `.appconfig.featureflag/*` value. I could **not** confirm that binding in
source: greps under `myriad.frontend.edge` for `VUE_APP_AZ_CONFIG_CONNECTION_STRING`,
`AppConfigurationClient`, `getConfigurationSetting`, `featureflag` returned **no consuming
code** (the FBE frontend image source that ships chart `frontend-0.4.2` does not appear to be
the checked-out `myriad.frontend.edge`; "tennet" only appears in a `tenantStore` + locale
strings). So whether the indicator renders from the App Config response, from a static
`window.FEATURE_FLAGS`/tenant list, or from a tenant API is **A3 [blocked: consuming source
not located]**.

**Failure scenario:** if "Tennet NL" is rendered from a static/tenant source that does NOT
depend on the App Config data-plane call, then a pod restart fixes the 401 in DevTools but the
**indicator behavior is unchanged**, and Duncan's Definition-of-Done ("indicator visible
without a manual pod delete") is either already met for a different reason or not met by this
fix at all. Restart demonstrably fixes the **401** (the mechanism is A1); it is the
**401→indicator** link that is unproven.

**Discriminating probe (cheap, settles it):** in the FBE frontend image source, grep for how
the top-left indicator binds to the App Config feature-flag response
(`isFeatureEnabled` / flag key name / the component rendering "Tennet"). OR empirically: restart
ONE drifted slot and confirm in DevTools both (a) `.appconfig.featureflag/*` → 200 **and**
(b) the "Tennet NL" indicator appears. The RCA lists this as verification-to-be-done (L9) — it
has **not yet been executed**, so the DoD-satisfaction claim is INFER. Flagging to the
coordinator as a goal-fidelity-adjacent gap that lives partly in my lane (does the reliability
fix produce the observable Duncan wants).

### 3a — SURVIVES mechanism; the exact 401 variant is INFERRED not reproduced (LOW)

Sharp point the RCA soft-pedals: the 5 slots reproduced live have baked stores that are **GONE**
from Azure (ledger lines 62-68), and a gone store gives **HTTP 000 / DNS failure**, NOT Duncan's
clean **401** (ledger lines 70-80, the RCA's own HTTP discriminator). So the fleet state
reproduced live is the *connection-error* variant, and Duncan's *clean-401* variant (stale key
vs a store that still resolves) was **not directly reproduced** — the 401 shown in the ledger is
just the normal unauthenticated-GET challenge any live store returns, which does not by itself
prove that a *stale HMAC key* against a live store yields 401 (vs some other code). It almost
certainly does (rotated/invalid HMAC signature → 401 Unauthorized), so this is INFER not BROKEN.
It does not affect fix viability — restart re-bakes from the current secret and fixes **both**
the 000 and 401 variants. Noting it only so the receipt is not laundering an inference as A1.

---

## Claim 4 — cascading / again-broken risk (SURVIVES — LOW, disclosed)

- **Shared-secret flap:** P2 annotates the frontend to reload on `application-secret`, which
  holds **13 keys used by other workloads** (fix line 156). Any rotation of ANY of those 13
  keys rolls the frontend, even when the App Config credential is unchanged. In FBE/sandbox with
  a stateless frontend this is cheap and acceptable, as the fix states. Not a flap risk unless
  one of those 13 keys rotates on a tight cadence — verify none is a short-TTL/auto-rotated
  secret before shipping; if one is, scope the Reloader trigger to a dedicated single-key secret
  instead of the shared `application-secret`.
- **Double-restart on recreate:** P1 (explicit restart) + P2 (Reloader on the secret change) both
  fire on a pipeline-driven recreate → two sequential frontend rolls. Harmless (idempotent,
  stateless) but redundant; no storm because only the frontend annotates the secret.
- **No restart storm:** blast radius is one Deployment per namespace; nothing fans out.
- **The only genuine "again-broken" path** is 1a (green-but-wrong gate) already scored MEDIUM.

---

## Bottom line for the coordinator

The fix's **core mechanism and its primary remedy are sound** — restart re-bakes the credential
and CSI+Reloader viability is live-proven, not assumed. Two items must close before the PR gate
is trustworthy:

1. **MEDIUM (1a):** add the Azure-store existence assertion to the *automated* pipeline
   effect-check; internal `baked==application-secret` equality is not proof of correctness.
2. **MEDIUM (3b):** prove the "Tennet NL" indicator actually depends on the App Config
   feature-flag call (source grep or a live restart-then-observe on one slot) before claiming the
   fix satisfies Duncan's DoD. Until then the 401→indicator link is INFER.

Everything else survives. Nothing here blocks P0 (the manual restarts are safe and reversible)
or breaks the P1+P2 architecture.
