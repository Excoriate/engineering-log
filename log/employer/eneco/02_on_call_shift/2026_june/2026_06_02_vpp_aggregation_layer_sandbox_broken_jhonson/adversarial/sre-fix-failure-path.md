---
task_id: 2026-06-02-001
agent: sre-maniac
status: complete
timestamp: 2026-06-02T10:40:00Z
summary: |
  Adversarial operator review of the durable CSI-from-KeyVault fix for the vpp-agg
  `keys` secret. Live read-only probe of AKS vpp-aks01-d found the fix is NOT
  invalid (it will materialize `keys`) but rests on an UNSTATED, FRAGILE
  dependency: CSI secretObjects are only synced while a pod mounting the SPC as a
  CSI volume is running, and the 10 *fn pods that consume `keys` mount it as a
  plain secret volume — none mount the SPC. The projection lives ONLY because one
  unrelated pod (siteregistry, 1 replica) happens to mount the SPC; postdeliveryreportjob
  is an ephemeral CronJob. Scale siteregistry to 0 / evict it and `keys` stops being
  reconciled. Verdict: SAFE-WITH-CHANGES. Five findings: one BLOCKING (CSI
  mount-coupling not designed for), one HIGH (pfx assembly under-specified +
  rotation-surface), one HIGH (L9 "delete keys, do nothing else" is a live outage
  trigger as written), one MEDIUM (MC blast radius / no staged rollout guard),
  one MEDIUM (class fix expires:null gap + no rotation actor).
---

# Adversarial SRE Review — Durable Fix Failure Paths (`vpp-agg` `keys` secret)

## Key Findings

- **F1 (BLOCKING):** secretObjects only project while a pod mounts the SPC CSI volume; the `*fn` pods do NOT — projection survives by accident via `siteregistry`.
- **F2 (HIGH):** pfx assembly options (a/b/c) under-specified; (b) needs verified Confluent PEM support, (a) adds an unrotated KV pfx surface.
- **F3 (HIGH):** L9 verification "delete manual keys, do nothing else, confirm recovery" is a fresh-outage trigger if projection not pre-confirmed.
- **F4 (MEDIUM):** MC rollout (dev/acc/prd) lacks a staged-rollout guard; deleting `common/templates/secret.yaml` is a one-way blast across all envs.
- **F5 (MEDIUM):** class fix — `kafka-*` KV secrets have `expires:null` today; no named rotation actor; alarm closure depends on a manual upload-time attribute.

**Stance:** win condition is to BREAK the fix, not approve it. Read-only live probe of
AKS `vpp-aks01-d` (KUBECONFIG `/tmp/sb-kubeconfig-2026-06-02-001`) + KV `vpp-agg-sb`
(`--subscription 7b1ba02e-…`). No mutations, no `az account set`, no kubeconfig change,
no secret/private-key values read.

**Headline:** the durable fix is *not* invalid — it WILL create `keys` — but for a
reason the fix.md never states, and that reason is itself a new, undocumented failure
mode. The fix is **SAFE-WITH-CHANGES**. The single most dangerous gap is that
fix.md treats "the SPC already projects 3 secrets, so adding a 4th works" as obviously
true, without noting *what keeps that projection alive*. It is alive by accident.

---

## Decisive live evidence (the CSI mount-coupling gotcha)

`A1` (live `kubectl get pods -o json`, 2026-06-02):

```text
PODS mounting the CSI SPC volume (secrets-store.csi.k8s.io, SPC=secret-provider-agg-kv): 3
   siteregistry-8494bfcf6c-7shtp            phase=Running    csi_vols=[secrets-store-inline] keys_vol=[]
   postdeliveryreportjob-29671095-mzff8     phase=Succeeded  csi_vols=[secrets-store-inline] keys_vol=[]
   postdeliveryreportjob-29672535-j6kld     phase=Succeeded  csi_vols=[secrets-store-inline] keys_vol=[]

PODS mounting secret:keys DIRECTLY as a volume: 10  (ALL the *fn pods)
   dataingestionfn, deliveryreportfn, flexreservationingestionfn, marketinputpreparationfn,
   meritordercalculationfn, setpointdisaggregationfn, strikepricefn, telemetryaggregationfn,
   telemetryfunctiontestsfn, telemetryingestionfn
```

`A1` (live, secret labels): `application-secret`, `ingress-tls`, `dockerpullsecret` all
carry `secrets-store.csi.k8s.io/managed=true`, created `2025-01-20`. They are
CSI-projected — and they exist **because `siteregistry` (1 replica, Running) and the
`postdeliveryreportjob` CronJob mount the SPC as a CSI volume.**

`A1` (live): `siteregistry` Deployment `replicas=1 available=1`; `postdeliveryreportjob`
is a **CronJob** (`schedule: 15 0 * * *`, `suspend: false`) — its pods are ephemeral
(`phase=Succeeded`).

**Mechanism that matters (the Azure/Kubernetes Secrets Store CSI Driver contract):** a
`SecretProviderClass`'s `secretObjects` (the synced K8s Secrets) are created and
**continuously reconciled only while at least one pod that references that SPC as a CSI
volume is running on the node**. The Secret is *not* an independent object the driver
maintains in the background; it is a side-effect of an active CSI volume mount. When the
last mounting pod on a node terminates, the driver's `SecretProviderClassPodStatus`
goes away and the synced Secret is eligible for deletion. `A2` (CSI driver semantics;
this is the documented "secretObjects are only created when a pod consumes the SPC"
behavior — confirmed observationally here: the 3 secrets exist precisely alongside the
2 SPC-mounting workloads).

---

## F1 — BLOCKING — `keys` projection is coupled to an unrelated pod's lifecycle, and fix.md never says so

**Severity:** BLOCKING (for the fix *as written*; the wiring works, the *reasoning and
operational contract* are wrong).

**Mechanism:**
The fix adds `keys` to the SPC `secretObjects`. The driver will materialize `keys` —
**but only while a pod that mounts the SPC CSI volume is running.** The 10 `*fn` pods
that actually consume `keys` mount it as a *plain secret volume* (`secret: { secretName:
keys }`), **NOT** as the SPC CSI volume (`A1`). They therefore exert **zero** pull on the
CSI driver. The thing keeping the projection alive is `siteregistry` (1 replica) plus the
nightly CronJob. Concretely:

- Scale `siteregistry` to 0, or it gets evicted/cordoned/crashlooping, or it's moved to
  another node and the *fn pods stay where they are → on the node(s) with no SPC-mounting
  pod, the CSI driver tears down its `keys` projection.
- Worse second-order: the `*fn` pods are *already Running* with `keys` volume-mounted.
  A volume-mounted Secret update/deletion does **not** restart a Running pod, and a
  deleted Secret does not evict a Running pod — so the breakage stays *latent* until the
  next `*fn` pod reschedule (deploy, node drain, OOM, HPA). Then those pods hit
  `FailedMount: secret "keys" not found` — **the exact incident this fix claims to
  eliminate**, now with a green PR behind it. This is a textbook *green-pipeline,
  broken-outcome* trap, identical in shape to the original (RCA L6).

**Evidence:**
- `A1` live: 10 `*fn` pods mount `secret:keys`; 0 mount the SPC. Only `siteregistry`
  (1 replica) + `postdeliveryreportjob` (CronJob) mount the SPC.
- `A1` live: existing 3 projected secrets carry `secrets-store.csi.k8s.io/managed=true`
  — proving projection is the CSI side-effect of those mounting pods, not a standalone object.
- `A1` chart (`lane-r1-chart.md` Q5, `dataingestionfn/templates/deployment.yaml`): `*fn`
  volume is `secret: { secretName: keys }`, never a CSI volume.

**Why this beats the fix.md claim:** fix.md L70/L82 and rca.md L216 assert "the existing
CSI driver projects 3 secrets; we add `keys` to it" as if the synced Secret were a durable
object. It is not. The fix *happens* to work today only because `siteregistry` is the
incidental SPC anchor. fix.md L101 even proposes the discriminating test "delete the
manual `keys`, do nothing else, confirm pods recover" — that test will pass *today*
(siteregistry anchors the projection) and still leave the system one `siteregistry`
outage away from re-breaking. A passing test that does not exercise the real failure
mode is a false green.

**If accepted → which fix.md section changes:**
- **Layer 1 "What changes" (fix.md:72-78):** add a step making the projection robust,
  one of:
  1. **Preferred:** switch the 10 `*fn` deployments to mount the cert files via the **SPC
     CSI volume directly** (`csi: { driver: secrets-store.csi.k8s.io, volumeAttributes:
     { secretProviderClass: secret-provider-agg-kv } }`) at `/app/certs`, instead of
     `secret: keys`. Then each consuming pod is its own anchor — projection can never
     outlive its consumers, and there is no orphan-secret window. This is the only option
     that removes the coupling entirely. (Requires the SPC `objects` to expose the 4
     cert files, which the fix already adds.)
  2. If keeping the `secretObjects`→`secret:keys` indirection, **document and guard the
     anchor:** state explicitly that the synced `keys` Secret only persists while an
     SPC-mounting pod runs, pin a long-lived SPC-mounting workload (siteregistry must stay
     ≥1 and be PDB-protected), and add an alert on the `keys` Secret's existence/age.
- **rca.md L216 / L9 acceptance:** the acceptance criteria must include "projection
  survives `siteregistry` going to 0 replicas" (or option-1 removes the need).
- **L10 Lessons:** add "CSI secretObjects are a mount side-effect, not a standalone
  object — a consumer must mount the SPC, or the projection is orphaned."

---

## F2 — HIGH — pfx assembly is under-specified; every option carries an un-costed operational risk

**Severity:** HIGH.

**Mechanism:**
`A1` live KV `vpp-agg-sb` holds `kafka-sslkey` (PEM) and `kafkasslkeystorepassword`, but
**no `.pfx`/keystore secret** (grep for `pfx|keystore|sslkey` returns only `kafka-sslkey`
and `kafkasslkeystorepassword`). The chart's `KafkaOptions__SslKeystoreLocation`
(`A1` rca.md L131, lane-r1 Q4) requires `/app/certs/ssl-key.pfx` (PKCS#12). The CSI
driver projects KV bytes **verbatim** — it cannot assemble a pfx. fix.md offers (a) store
pfx in KV, (b) app uses PEM keystore + drop pfx, (c) init `openssl pkcs12`. Each has an
unstated failure path:

- **(a) store assembled pfx in KV** — viable and lowest-code, but creates a **second,
  divergent copy** of the private key in KV (`kafka-sslkey` PEM + `kafka-sslkeystore`
  pfx). At the next cert rotation, whoever uploads the new PEM **must remember to
  re-assemble and re-upload the pfx** or the two drift. fix.md L84 flags "adds a rotation
  surface" but does not size it: this is *exactly* the LL-006 class defect (a credential
  with a manual, un-alarmed maintenance step) that Layer 2 is trying to kill. Choosing (a)
  re-introduces the class problem in a new place.
- **(b) PEM keystore, drop pfx** — cleanest, BUT it is asserted ("the Confluent client
  supports PEM keystore … it does in recent versions") with **no version evidence**. The
  `ssl.keystore.type=PEM` option exists in librdkafka ≥1.5 / Confluent.Kafka ≥1.5, but
  whether *this* app's pinned client version and config code path support it is
  **UNVERIFIED** — and it requires an **app code + config change** (drop
  `SslKeystoreLocation`, set keystore type), i.e. it is NOT a chart-only fix. If shipped
  on the assumption it "just works," the *fn pods will start (mount succeeds) and then
  fail mTLS at runtime against `*.esp.eneco.com:9094` — a worse failure than FailedMount
  because the pod is Running/Ready and the breakage is invisible until Kafka traffic is
  attempted.
- **(c) init-container openssl** — works but adds a per-pod moving part and bakes the
  keystore password into an init step; rotation of the password now touches the init
  spec too.

**Evidence:**
- `A1` live KV list: no pfx/keystore-form secret; only `kafka-sslkey` (PEM) +
  `kafkasslkeystorepassword`.
- `A1` chart: `KafkaOptions__SslKeystoreLocation=/app/certs/ssl-key.pfx` is a hard
  requirement of the running config.
- `A2`: CSI projects bytes verbatim → no in-driver pfx assembly path exists.

**Least-risky option (operator view):** **(b) only if** the app's pinned
`Confluent.Kafka`/librdkafka version is confirmed to support `ssl.keystore.type=PEM` AND
the change is shipped with a runtime mTLS smoke test against ESP (not just "pod Ready").
Otherwise **(a)** is the least-bad stop-gap *provided* the pfx is added to the same
rotation runbook entry as the PEM and both are alarmed (Layer 2). (c) is last — most
moving parts. fix.md currently recommends (b) "else (a)" without gating (b) on the
version probe; that gate is mandatory.

**If accepted → which fix.md section changes:**
- **fix.md Caveat block (L84-88):** make (b) conditional on a *named, verified* client
  version supporting PEM keystore + add an explicit runtime mTLS verification step;
  if not verified, fall to (a) **with** a mandatory paired-rotation runbook note.
- **rca.md L201:** same — strike "(it does in recent versions)" as an unverified claim or
  back it with the actual pinned client version.

---

## F3 — HIGH — the L9 "delete the manual `keys`, do nothing else, confirm recovery" step is a live-outage trigger as written

**Severity:** HIGH (operationally dangerous instruction, even in Sandbox).

**Mechanism:**
fix.md L101 / rca.md L218 instruct: *"delete the manual `keys`, do nothing else, and
confirm pods still recover."* Combined with F1, this is unsafe **ordering**:

1. The synced `keys` only exists if the SPC change is merged, synced, AND an SPC-mounting
   pod (siteregistry) is currently Running on the relevant node. If the operator runs the
   delete **before** confirming the CSI projection has actually produced a `keys` Secret
   (driver-owned, `secrets-store.csi.k8s.io/managed=true` label present), they delete the
   only copy and there is **no** projection to refill it → instant return to the original
   incident: 10 `*fn` pods FailedMount on next reschedule, retry forever.
2. Even if projection IS up: a Running `*fn` pod does not pick up the swap (volume Secret
   already mounted), so "confirm pods still recover" requires a **rollout restart** —
   which the step says NOT to do ("do nothing else"). So either the test is a no-op
   (pods never re-read the Secret) or it forces a restart that the instruction forbids.
   The instruction is internally contradictory.
3. **Outage window:** if projection is not ready, the window is **unbounded** (FailedMount
   retries forever until a human recreates `keys`). In Sandbox that blocks all dev/test
   Kafka consumers; if this pattern is copied to MC (see F4) the same instruction is an
   uncontrolled prod outage.

**Evidence:**
- `A1` F1 evidence: `*fn` pods mount `secret:keys` directly; deleting the Secret does not
  restart them, and a missing volume Secret = indefinite FailedMount on reschedule
  (rca.md L58 "retries forever").
- fix.md L101 + rca.md L218: the verbatim instruction.

**If accepted → which fix.md section changes:**
- **fix.md L90-101 (Verify durable fix):** re-order into a *gated* sequence:
  1. Merge + sync SPC change.
  2. **Confirm** the projected `keys` exists AND is driver-owned
     (`kubectl get secret keys -o json | jq '.metadata.labels'` shows
     `secrets-store.csi.k8s.io/managed=true`) — this is the real pass/fail, not "pods
     recover."
  3. ONLY THEN delete the manual `keys` (now redundant) and `rollout restart` to prove
     the *fn pods consume the projected copy.
  4. Keep a one-command rollback ready (recreate manual `keys` from KV, Layer 0) in case
     step 2 shows projection absent.
- **rca.md L218:** replace "do nothing else, confirm pods still recover" with the gated
  sequence; the discriminating test is *the driver-owned label on `keys`*, not pod state.

---

## F4 — MEDIUM — MC blast radius: deleting `common/templates/secret.yaml` is a one-way change across all envs with no staged-rollout guard

**Severity:** MEDIUM (Sandbox-safe; dangerous if the recommendation is read as
"apply everywhere").

**Mechanism:**
fix.md L78 step 2 deletes `common/templates/secret.yaml`. That template is the inline-Helm
`keys` provider for the **`vpp-agg` namespace branch and the DevMC/Acceptance branches**
(`A1` lane-r1 Q2: `if ns==vpp-agg / elif container.env==DevMC / elif ==Acceptance`).
fix.md L115 correctly says "does not touch MC … apply the same SPC pattern there only
after Sandbox is proven" — but the *delete* of the shared template and the *MC rollout*
are in tension:

- The `common` chart is dead in CD today (never deployed — RCA L6), so in Sandbox the
  delete is harmless. **BUT** if any MC/prod-style environment was ever bootstrapped by a
  **manual `helm install common`** (rca.md L225 explicitly hypothesizes "whoever set up
  prod/DevMC/Acceptance ran it"), then the committed certs in that template are the only
  record of what those envs were seeded with. Deleting it removes the only git trace of
  the MC/Acc cert material *before* the CSI path is proven in MC. That is an
  ordering/blast-radius hazard: the fix removes the old mechanism repo-wide in one PR
  while only validating the new mechanism in one environment.
- Second-order: the MC KVs are **private** (rca.md L86, `Eneco.Vpp.Aggregation.Infrastructure.Mc`).
  The Sandbox CSI identity has read on `vpp-agg-sb`; the MC SPC identities must each be
  granted read on the MC `kafka-*` objects — and the MC KVs **must actually contain** the
  `kafka-*` material (unverified for MC; only `vpp-agg-sb` was probed, `A1`). If MC KVs
  lack the certs, the same SPC change in MC projects an empty/absent `keys` → MC outage.

**Evidence:**
- `A1` lane-r1 Q2/Q-deploy: `common/templates/secret.yaml` carries the `vpp-agg` +
  DevMC + Acceptance branches; `common` deployed by no pipeline.
- `A1` rca.md L86/L225: MC KVs private; manual `helm install common` is the suspected MC
  seed path.
- `A3 UNVERIFIED[blocked: out of scope — MC KV not probed]`: whether MC KVs hold `kafka-*`.

**If accepted → which fix.md section changes:**
- **fix.md L78 + L115:** split the delete from the Sandbox SPC change. Sequence: (1)
  Sandbox SPC `keys` projection proven (F1+F3 gates pass), (2) MC KVs confirmed to hold
  `kafka-*` + MC SPC identity granted read + MC `keys` projection proven per-env, (3)
  ONLY THEN delete `common/templates/secret.yaml`. Until step 3, leave the template in
  place (it is dead code, harmless to keep) so MC seed material is not lost prematurely.
- Add an explicit "MC pre-flight" checklist item: probe each MC KV for `kafka-cacert/
  clientcert/sslkey` and verify the MC CSI identity's KV access policy BEFORE touching MC.

---

## F5 — MEDIUM — class fix won't close the alarm gap as written: `expires:null` today + no named rotation actor

**Severity:** MEDIUM.

**Mechanism:**
fix.md Layer 2 proposes "set `--expires` on the KV secrets at upload time and extend
pipeline def 2735" OR "store the client cert as a KV certificate object." Live state
undercuts the first option's reliability:

- `A1` live: `kafka-cacert`, `kafka-clientcert`, `kafka-sslkey`, `kafkasslkeystorepassword`
  ALL have **`expires: null`** today (KV secret attributes). So the alarm gap is real and
  open right now.
- Setting `--expires` is a **manual, upload-time** attribute on a *secret* (not a
  certificate object). It is the same failure class as the original incident: it depends
  on a human remembering to set it on every future rotation, and it is invisible if
  forgotten. An alarm whose coverage depends on an optional manual attribute being set
  correctly each rotation is **structurally identical to the defect being fixed** (LL-006).
- The "better control" is the second option fix.md lists almost in passing: store the
  client cert as a **KV certificate object**, which has an intrinsic, non-optional expiry
  that the *existing* pipeline (def 2735) already watches. That removes the
  "remember-to-set-expires" failure mode entirely. fix.md ranks these as equal
  ("Either … or …"); the operator-correct ranking is: **certificate-object first**,
  `--expires`-on-secret only as a fallback when the material genuinely cannot be a cert
  object (e.g. the CA chain or the raw PEM key).
- **Rotation actor is unnamed.** fix.md L107 says "name an owner (a named person +
  backup)" but does not name one and does not say **what triggers** rotation (calendar
  reminder? pipeline? alert N days before expiry?). Without a trigger, an owner is just a
  blame target after the next expiry. The client cert is valid to `2027-01-09` (`A1`) —
  ~7 months of runway — so this is not urgent, but it is the actual root of the
  "broken >6 months" history.

**Evidence:**
- `A1` live: all 4 `kafka-*` KV secrets `expires: null`.
- `A1` rca.md L108/L225: def 2735 watches KV *certificate objects*, not these secrets.
- `A1` live: client cert valid `2025-12-09 → 2027-01-09`.

**If accepted → which fix.md section changes:**
- **fix.md L108 (Layer 2 item 2):** re-rank — **store the client cert as a KV certificate
  object** (covered by the existing alarm automatically) as the *primary* control;
  `--expires`-on-secret + pipeline extension only as fallback. State that `expires:null`
  is the current live gap.
- **fix.md L107 (item 1):** require the PR that introduces the control to name the actual
  owner + backup + the **rotation trigger** (alert at expiry-minus-N-days), not just a role.

---

## Cross-cutting: what fix.md gets RIGHT (so the rewrite keeps it)

- Layer 0 stop-gap correctly writes private-key material only to a `mktemp -d` (0700) and
  shreds it (`A1` fix.md L55/L58) — operationally sound, keep it.
- `--dry-run=client | apply` idempotence (fix.md L53) — good.
- Using the AGG's own `eet-vpp-dt` identity, not a borrowed cert (rca.md L228) — correct,
  the live secret already uses it.
- The `-o tsv` PEM gotcha (rca.md L259) — correct and important.

---

## VERDICT

**SAFE-WITH-CHANGES.**

The durable fix is directionally correct (KV is the source of truth; the certs already
exist there; CSI is the right mechanism) and it is **not** invalid — it will produce a
`keys` Secret. But as written it ships on an unstated, fragile premise and contains one
operationally dangerous verification step. Required changes before it is safe to
recommend (in priority order):

1. **(F1, BLOCKING)** Resolve the CSI mount-coupling. Preferred: switch the 10 `*fn`
   deployments to mount the SPC as a CSI volume directly (each consumer becomes its own
   anchor) — this is the only change that removes the orphan-projection failure mode. If
   the `secretObjects`→`secret:keys` indirection is kept, document the anchor dependency,
   pin/PDB-protect a long-lived SPC-mounting workload, and alert on `keys` existence/age.
2. **(F3, HIGH)** Rewrite the L9 verification into a gated sequence whose pass/fail is the
   **driver-owned label on `keys`**, not "pods recover"; never delete the manual `keys`
   before confirming the projection is materialized; keep the Layer-0 rollback ready.
3. **(F2, HIGH)** Gate pfx option (b) on a *verified* client-version PEM-keystore probe +
   a runtime mTLS smoke test; if unverified, use (a) with a mandatory paired-rotation
   runbook entry. Strike the unverified "(it does in recent versions)" claim.
4. **(F4, MEDIUM)** Split the `common/templates/secret.yaml` delete from the Sandbox SPC
   change; gate MC rollout on per-env KV-content + CSI-identity pre-flight; keep the dead
   template until MC is proven.
5. **(F5, MEDIUM)** Re-rank the class fix to prefer a KV **certificate object** (intrinsic,
   auto-alarmed expiry) over manual `--expires` on a secret; name the rotation **trigger**,
   not just an owner. Note the live `expires:null` gap.

The fix becomes SAFE once F1 and F3 are addressed (BLOCKING + the dangerous step); F2/F4/F5
are required for it to be durable and safe to extend beyond Sandbox.
