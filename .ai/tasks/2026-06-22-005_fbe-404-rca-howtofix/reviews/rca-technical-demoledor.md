---
task_id: 2026-06-22-005
slug: fbe-404-rca-howtofix
agent: el-demoledor
status: complete
adversarial_lane: technical-operational
summary: Technical/fix-safety/command/coherence demolition of rca.md + how-to-fix.md for the FBE operations-slot 404 finalizer-wedge. Verdict PROCEED-WITH-CHANGES — 0 BLOCKING, the two fix commands are command-correct and match the executed fix-apply.log byte-for-byte, safety gates are complete and correctly ordered; but 4 non-blocking findings (1 HIGH coherence/precision, 3 MEDIUM/LOW) on overstated "only assetmonitor" object claim, an unverifiable P3 precondition as written, a verification-probe context-flag gap, and a mermaid edge that under-encodes the name-collision.
timestamp: 2026-06-22T12:10:00Z
---

# Technical Demoledor Review — FBE 404 RCA + Repair Spec

Lane: **technical correctness · fix safety · command validity · cross-section coherence**.
Socrates owns epistemics/goal-fidelity — out of my lane.

Method: every load-bearing claim cross-checked against raw probes
(`context/probes/*`, `prefix-snapshot/*`), NOT against the docs' own prose.

## Verdict

**PROCEED-WITH-CHANGES** · 0 BLOCKING

The fix is technically sound and the commands are correct and safe. The two
`kubectl patch` commands in L8 / how-to-fix §"fix commands" match the executed
`fix-apply.log` exactly (namespaces `argocd` / `operations`, `--type=merge`,
`-p '{"metadata":{"finalizers":[]}}'`, both returned `…/<name> patched`). All
five vault safety gates are present and correctly ordered (workloads-gone BEFORE
patch, snapshot first, 2629-forbidden, auto-evict warning, context-confirm).
The findings below are precision/coherence/robustness, none block promotion.

## Findings

### F1 — HIGH (coherence/precision) — "only assetmonitor exists as an object in ns operations" is an overstatement; leftover Job pods from other services exist

- **Where**: rca.md:57-58 ("Only one orphan child app, `assetmonitor`, still
  existed"), rca.md:296-300 ("only `assetmonitor` actually existed as an object…
  The slot's pods were just `assetmonitor` replicas"), Evidence Ledger #5
  (rca.md:823 "Only `assetmonitor` exists as an object in ns `operations`").
- **Evidence (probe `05-pods.txt`)**: ns `operations` also contains **Completed
  Job pods from OTHER services** — `seed-assets-clientgateway-postsync` (34d),
  `seed-assets-monitor-postsync` (34d), `seed-assets-telemetry-postsync` (34d),
  `seed-assets-activationmfrr`, `seed-assets-alarmengine`, `seed-assets-dataprep`,
  `seed-assets-assetplanning` (all 34d, Completed), plus
  `assetmonitor-database-cleanup-*` and `docker-pull-secret-*` Jobs. So the claim
  "the slot's pods were just assetmonitor replicas" (rca.md:298) is **false as
  written** — there are ~10 non-assetmonitor pods, they are just terminal
  (Completed) Job residue, not running workloads.
- **Why it matters technically**: the precise true statement is "no *running*
  `frontend`/gateway **Application objects or Service/Pod workloads** exist; only
  `assetmonitor` is a live Application and the rest are terminal Job residue from
  prior tenancy." The absolute "only assetmonitor exists" invites a zero-context
  reader to expect a literally empty namespace, then doubt the RCA when `kubectl
  get pods -n operations` returns 18 lines. The mechanism is unharmed (no frontend
  *ingress*/Service — confirmed by `05-ingress.txt`: the **only** ingress is
  `assetmonitor` → so the "only ingress" claim at rca.md:286-287 IS exact and
  correct), but the "only object/pod" phrasing is imprecise.
- **Conditional fix**: narrow the three phrasings to "the only live child
  *Application* is `assetmonitor`; no `frontend`/gateway Application or Service/Pod
  exists (only terminal Job residue from prior tenancy remains)". Evidence Ledger
  #5 should cite the **Application** scan, not "as an object", and acknowledge the
  Job residue. The **ingress** claim (rca.md:286, L3 table:306) needs no change —
  `05-ingress.txt` confirms exactly one `assetmonitor` ingress.

### F2 — MEDIUM (fix-safety / precondition robustness) — how-to-fix P3 cannot be satisfied as written when run on a HEALTHY slot, but more importantly its STOP condition is under-specified for the co-firing case

- **Where**: how-to-fix.md:91-102 (P3 "Prove the managed workloads are already
  gone"). Expected: "web backends (`frontend`, `clientgateway`, `gateway-nl`) to
  be **missing** as objects — only stragglers (e.g. `assetmonitor`) remain. If a
  healthy `frontend` exists … STOP."
- **Evidence / attack**: P3 runs `kubectl -n operations get applications` +
  `get pods,ingress`. In THIS incident `frontend` was absent (correct). But the
  generic spec says "STOP if a healthy `frontend` exists" — yet the finalizer
  wedge can co-exist with a partially-rendered slot where SOME children DID
  render before the parent wedged (the probe-results.md Rank-4 "mixed-branch
  partial render" is explicitly a real secondary artifact here: app-of-apps on
  `fbe-851436`, assetmonitor on `fbe-806738` — confirmed in
  `prefix-snapshot/operations-app-of-apps.yaml:43` vs `assetmonitor.yaml:60`).
  An operator on a future incident could see a `frontend` Application present-
  but-OutOfSync under a wedged app-of-apps and wrongly STOP, OR see it Healthy
  and STOP when finalizer removal was still the right call. P3's binary
  "frontend missing → go / present → stop" does not handle "frontend present but
  the *app-of-apps* carries a deletionTimestamp" — the deletionTimestamp on the
  parent (P2) is the authoritative gate, and P3's "workloads gone" is a
  *secondary* safety check, not a co-equal STOP.
- **Why it matters**: as written, P3 can produce a **false STOP** on a genuine
  wedge that happens to have one straggler child rendered. The fix would be
  wrongly abandoned.
- **Conditional fix**: reword P3 so the STOP is "if a `frontend` Service/Pod is
  **Running and serving** (live workload) AND the app-of-apps has **no**
  deletionTimestamp → not this class, STOP." Subordinate P3 to P2: the
  deletionTimestamp on the app-of-apps (P2) is the decisive gate; P3 proves the
  finalizer's cleanup target is gone, and "straggler present" is tolerated, not a
  STOP, as long as it too is mid-deletion. (This is exactly what happened here:
  `assetmonitor` WAS present and itself wedged — and removal was still correct.)

### F3 — MEDIUM (command validity) — how-to-fix verification probes drop the `--context` flag that every other command carries; on a multi-context kubeconfig they read the wrong cluster

- **Where**: how-to-fix.md:187-190 (Verification table). The four verify probes
  are written WITHOUT `--context vpp-aks01-d`:
  `kubectl get applications -A …`, `kubectl -n argocd get application
  operations-app-of-apps …`, `kubectl -n operations get application frontend …`,
  `curl …`. Every precondition (P1-P6) and both fix commands DO carry
  `--context vpp-aks01-d`.
- **Evidence / attack**: the spec's own P1 (how-to-fix.md:65-73) and safety gate
  (how-to-fix.md:225-227 "Confirm you are on the Sandbox cluster first … Never
  trust a default context") establish that context-binding is load-bearing. The
  verification step is exactly where an operator, having patched the correct
  cluster, then runs a context-less verify against whatever `current-context`
  points at — and could read a DIFFERENT cluster's `operations-app-of-apps`
  (other slots/clusters in this kubeconfig have same-named app-of-apps:
  `04b-credgap-scan.txt` shows `afi-app-of-apps`, `ionix-app-of-apps`, etc., and
  the FBE pattern reuses the `<slot>-app-of-apps` name). A context-less verify is
  a **silent wrong-cluster read** that could falsely report success or failure.
- **Note**: rca.md L11 Step 9 (rca.md:782-786) has the SAME omission — its
  verify block drops `--context` on the `get applications -A` and the `curl`
  (the middle `get application` line keeps it). Internally inconsistent with
  Steps 0-8 which all carry `--context`.
- **Conditional fix**: add `--context vpp-aks01-d` to every verification `kubectl`
  in how-to-fix.md:187-190 and rca.md:782-785, matching the freshness/context
  discipline the doc itself mandates for every remote read.

### F4 — LOW (mermaid encoding) — the L3 diagram under-encodes the name-collision mechanism; ApplicationSet→app-of-apps edge reads as healthy with no indication the wedge blocks regeneration

- **Where**: rca.md:272-280 (L3 mermaid). The edge
  `ASET["ApplicationSet … (healthy)"] --> AOA["operations-app-of-apps (WEDGED,
  deleting)"]` is a plain solid arrow. The decisive mechanism — "the ApplicationSet
  could NOT replace the app-of-apps **while a wedged copy still held the name**"
  (rca.md:290-291, and the entire no-op-recreate causal chain) — is **not encoded**
  in this diagram. A reader reading only L3's picture sees ApplicationSet healthily
  pointing at a wedged child, with no visual that regeneration is blocked.
- **Contrast**: the L5 mermaid (rca.md:361-367) DOES encode it correctly —
  `WEDGE["wedged copy holds the name"] -. "blocks regeneration" .-> GEN`. So the
  mechanism IS drawn, just in L5, not L3.
- **Why it matters (LOW)**: L3 is the reader's first topology picture; leading
  with the failure path is the doc's stated method (rca.md:282), but the single
  most load-bearing causal step (name-collision) is absent from L3 and only
  appears two levels later. Not wrong, just under-encoded at first contact.
- **Conditional fix**: add a dotted `… -. "cannot replace while name held" .->`
  annotation on the `ASET --> AOA` edge in L3, or a node noting the wedged copy
  holds the name. Optional — L5 already carries the full encoding.

## What is solid

- **Fix-command correctness (win condition 1): PASS.** Both L8 / how-to-fix patch
  commands match `fix-apply.log` exactly — correct namespaces (`argocd` for
  app-of-apps, `operations` for assetmonitor), correct `--type=merge`, correct
  `-p '{"metadata":{"finalizers":[]}}'`, both `--context vpp-aks01-d`. Outputs
  `application.argoproj.io/operations-app-of-apps patched` and
  `…/assetmonitor patched` reproduced verbatim from the log. No wrong
  namespace/flag/context. The read-only preconditions P1-P6 are genuinely
  read-only (`get`, `curl -svk`, `get … -o yaml >` to local file) — none mutate.
- **Safety-gate completeness (win condition 2): PASS.** Irreversibility correctly
  framed as a one-way door that COMPLETES a deletion (not a rescue)
  (how-to-fix.md:54-55, 192-200; rca.md:71-73). Workloads-gone precondition (P3)
  is required BEFORE the patch (how-to-fix.md:228-230). Snapshot-first (P6 /
  L11 Step 7) precedes mutation. Destroy pipeline 2629 forbidden with all three
  vault reasons reproduced accurately (recursive-F2, tf 1.13.1-vs-1.14.3 state,
  260+ resource blast radius) — cross-checked against
  `vault-fbe-knowledge.md:113`. Auto-evict 14:30 race surfaced
  (how-to-fix.md:220-224). All five vault gates present.
- **Mechanism correctness (win condition 3): PASS.** Every causal step verified
  against raw probes:
  - app-of-apps `deletionTimestamp 2026-06-01T10:50:12Z` + `resources-finalizer`,
    created `2026-05-27T07:38:19Z`, owner ApplicationSet `controller: true` —
    confirmed `prefix-snapshot/operations-app-of-apps.yaml:4,6-8,15-17`.
  - assetmonitor `deletionTimestamp 2026-06-01T10:50:13Z` (1s later) + same
    finalizer — confirmed `prefix-snapshot/assetmonitor.yaml:10-12`. (Note: RCA
    Ledger #2 correctly cites the snapshot, not a non-existent probe.)
  - ns `operations` `Active`, finalizer `kubernetes` only, no deletionTimestamp —
    confirmed `01-ns-operations.json:18-24`. The "namespace hides the wedge" trap
    (L10 lesson 3, Step 1) is exactly right.
  - 404 from nginx, NO `x-correlation-id`/`Request-Context` header — confirmed
    `06-curl.txt:36-49` (edge 404, `<center>nginx</center>`, Content-Type
    text/html). The "no backend deployed vs path-misaligned" discriminator holds.
  - only ingress in ns operations is `assetmonitor` → `operations.dev.vpp…` on
    `50.85.91.121:80` — confirmed `05-ingress.txt:2`; no `frontend` ingress.
  - ApplicationSet healthy `ErrorOccurred=False` / `ParametersGenerated=True` /
    `ResourcesUpToDate=True` — basis for self-heal; credgap ruled out, only
    `loki` carries an auth-shaped error (unrelated helm-values
    `no such file or directory`, NOT `source N of M authentication required`) —
    confirmed `04b-credgap-scan.txt:29`. The RCA's loki carve-out (Ledger #8,
    Step 4b) is accurate.
  - controller `argocd-application-controller-0 Running 1/1 age 5d22h` (restarted
    after the 06-01 delete, wedge persisted) — confirmed `09-controller.txt:2`.
    The "a restart already failed, so finalizer removal is the fix, not another
    restart" reasoning (Step 6) is correct and is the right rebuttal to vault
    F3's "restart the controller" doctrine.
  - Self-heal mechanism (ApplicationSet owns via ownerReference + still targets
    operations → regenerates fresh app-of-apps on name-free) — confirmed by the
    ownerReference in the snapshot and `fix-result.md` (fresh app-of-apps
    `creationTimestamp 2026-06-22T11:32:48Z`).
  No hand-waved or wrong causal step.
- **Cross-section coherence (win condition 4): PASS with F1/F4 caveats.** Every
  component used in L8/L11/L12 (app-of-apps, ApplicationSet, finalizer,
  deletionTimestamp, ownerReference self-heal, 2629, auto-evict, x-correlation-id)
  is introduced in L1-L6 + Context Ledger before first action use. No retroactive
  reveal of a brand-new named component in L8/L11. L11 reproduces the
  investigation+fix from cold (Step 0 context-bind → Step 9 verify) with no
  forward references — each step builds only on prior outputs. The one precision
  slip is F1 (the "only assetmonitor object" overstatement) and F4 (L3 mermaid
  under-encoding), neither a new-component reveal.
- **A3-blocked discipline: PASS.** The trigger of the 06-01 deletion is honestly
  held A3 — `08-logicapp-runs.txt` confirms `az` failed (`'run' is misspelled or
  not recognized` → az not authenticated/CLI state), matching the doc's "az not
  logged in" blocked classification. The 12:50-CEST-≠-14:30-auto-evict timing
  reasoning is a legitimate A2 inference, correctly NOT promoted to root cause.
  2629-not-rollback safety gate is preserved despite the trigger being unknown.

## Adversarial self-check

- **Pattern-match check**: I did NOT flag the `kubectl patch finalizers:[]` as
  dangerous-by-shape. The probes prove managed workloads were already gone
  (no frontend ingress/Service, only terminal Job residue + a co-wedged
  assetmonitor), so finalizer removal completed an already-in-flight deletion —
  the textbook-safe case. Flagging it CRITICAL would have been pattern-matching
  bias; downgraded correctly to "PASS, gates present."
- **False-positive condition for F1**: F1 is wrong IF the reader interprets "as an
  object" to mean "as a live Application" — but the prose "the slot's pods were
  just assetmonitor replicas" (rca.md:298) is unambiguous about *pods* and is
  contradicted by `05-pods.txt`, so F1 stands as a precision defect.
- **False-positive condition for F3**: F3 is moot IF the operator's kubeconfig has
  only one context — but the doc itself mandates `--context` everywhere else and
  the kubeconfig demonstrably has multiple same-named app-of-apps, so the
  inconsistency is a real robustness gap, not noise.
- **Redundancy**: F1 and F4 share no root cause (precision vs diagram encoding);
  F2 and F3 are independent (precondition logic vs context flag). Four distinct
  root causes, no inflation.
- **Severity honesty**: nothing rated BLOCKING/CRITICAL because the executed fix
  already succeeded (404→200 verified in `fix-result.md`) and the commands are
  byte-correct. The findings improve a REUSABLE spec for the next incident; they
  do not invalidate this one.
