---
task_id: 2026-06-22-003
slug: fbe-404-stefan-intake
agent: sre-maniac
status: complete
timestamp: 2026-06-22T00:00:00Z
summary: |
  Adversarial SRE/operational review of sre-intake.md (FBE 404 operations slot).
  Verdict UNSOUND — 1 BLOCKING (§5#1 "top discriminator" mis-rejects Rank-1: a
  stuck app-of-apps Application finalizer leaves the destination namespace Active,
  not Terminating, so `kubectl get ns operations`=Active would falsely kill the
  most-likely hypothesis). Plus 1 HIGH command-validity defect (probe #3/#4 jq
  pipes run against an absent-field jsonpath that emits invalid/empty JSON), and
  ranking-confidence and safety findings. Resolved ids check clean vs screenshot
  + slack-harvest. Safety gates (2629-not-rollback, auto-evict race, finalizer
  force-removal gating) are accurate and load-bearing.
---

# Technical-surface SRE review — sre-intake.md (FBE 404 operations)

Read-only. Deliverable NOT modified. Checked against: `image.png` (ArgoCD UI
screenshot), `vault-fbe-knowledge.md`, `slack-harvest.md`.

## Verdict

**UNSOUND — 1 BLOCKING, 1 HIGH, 2 MEDIUM, 1 LOW.**

The intake is operationally careful and its safety gates are correct, but its
single self-declared "top discriminator" (§5#1) can FALSE-REJECT the Rank-1
hypothesis it is meant to confirm, and two probe commands (§5#3, §5#4) have a
jq-input defect that yields a silent no-op rather than a decision. A fix-agent
following §5 in order could discard the correct root cause at step 1.

## Findings

### F1 — BLOCKING — §5#1 `get ns operations` does NOT discriminate Rank-1 vs Rank-2; it can mis-reject Rank-1

**Evidence.** §5 row #1 (sre-intake.md:134) is labelled "**(top discriminator)**":
`kubectl ... get ns operations` → "`Terminating`" confirms Rank 1, "`Active` →
reject Rank 1, go Rank 2/3". But Rank-1's stated mechanism (sre-intake.md:96-104)
is a stuck **app-of-apps `Application` CR** holding `resources-finalizer.argocd.argoproj.io`
with a `deletionTimestamp` — an object that lives in the `argocd` namespace
(confirmed: §2 and §5#2 both correctly target `-n argocd`; screenshot card
`argocd/operations-app-of-apps`). A blocked ArgoCD Application finalizer blocks
deletion of the Application's *managed resources*; it does **not** require the
*destination* namespace `operations` to enter `Terminating`. The screenshot is
direct counter-evidence: child `operations/assetmonitor` shows `Last Sync
06/19/2026 14:14:41 (a few seconds ago)` and `Syncing` INTO namespace
`operations` (image.png) — a namespace actively being synced into is `Active`,
not `Terminating`. The vault note treats the ns check as an **OR** with the
deletionTimestamp check, not the decider: "namespace `Terminating` **OR**
app-of-apps has a non-empty `deletionTimestamp`" (vault-fbe-knowledge.md:40).
The intake collapsed that OR into a hard single-probe reject.

**Why this is BLOCKING.** A fix-agent runs §5 "in order," #1 first
(sre-intake.md:128 "Run read-only first"). #1 almost certainly returns `Active`
here. Per the table, `Active → reject Rank 1` — discarding the
finalizer/`Deleting`-badge hypothesis (the only one that explains the badge,
sre-intake.md:104) at the first step, then chasing Rank 2/3 while the real
wedge persists. Symptom-over-mechanism: ns state is a proxy, the Application
`deletionTimestamp` is the mechanism.

**Conditional belief-change.** If true → demote §5#1 from "top discriminator"
and make §5#2 (`get application operations-app-of-apps -n argocd -o yaml` →
read `.metadata.deletionTimestamp` + `.metadata.finalizers`) the decisive
Rank-1 split. §5#1 becomes corroborating only, with the reject rule rewritten:
"`Active` does NOT reject Rank 1 — a stuck Application finalizer commonly leaves
the destination ns `Active`; only an empty `deletionTimestamp` on the
app-of-apps (§5#2) rejects Rank 1." The `Deleting` badge in the screenshot
already implies a non-empty `deletionTimestamp` exists, so §5#2 is expected to
CONFIRM Rank-1, which §5#1=Active would have wrongly overridden.

### F2 — HIGH — §5#3 and §5#4 jq pipelines silently no-op on absent fields (command-validity)

**Evidence.** §5#3 (sre-intake.md:136):
`kubectl ... get applicationset ... -o jsonpath='{.status.conditions}' | jq '.[]|select(.type=="ErrorOccurred")'`.
`kubectl -o jsonpath` emits Go-template text, NOT guaranteed JSON: if
`.status.conditions` is **absent/empty** the jsonpath prints an **empty string**,
and piping empty string into `jq` yields `jq: error (at <stdin>:0): ... empty
input` (or nothing) — i.e. the probe neither confirms nor rejects, it errors.
Even when present, jsonpath renders a Go list, which is JSON-compatible only by
luck of ArgoCD's serialization; the vault's own version (vault:52) uses the same
construct and is equally fragile. §5#4 (sre-intake.md:137) uses `-o json | jq ...`
which is SAFE (json output is always valid JSON) — but its `select(... and
(.message|test(...)))` will throw `jq: error: null has no keys` /
`test() requires string` if any condition object lacks `.message`. The
`//[]` guard only defends `.status.conditions` being null, not a member
condition missing `.message`.

**Conditional belief-change.** If true → (a) §5#3 switch to
`kubectl ... get applicationset ... -o json | jq '.status.conditions[]? |
select(.type=="ErrorOccurred")'` (json output + `[]?` optional iterator
tolerates absent array); (b) §5#4 harden the inner test to
`select((.message // "") | test("source [0-9]+ of [0-9]+";"i"))` so a
condition without `.message` is skipped, not fatal. Without this, both
credential-mode probes can return "nothing" for the WRONG reason (jq error,
not field-absent), and a fix-agent reads a no-op as "rejected."

### F3 — MEDIUM — Rank-1 over Rank-2 is defensible but stated more confidently than this evidence licenses

**Evidence.** Rank-1 rests entirely on the `Deleting` badge being a finalizer
signal (sre-intake.md:104 "Only this mode explains the `Deleting` badge";
vault:94). That inference is sound. BUT: (a) the `operations` slot is a
*documented victim* of the Rank-2 cred-gap on 2026-05-12 (sre-intake.md:114,
vault:48) — a recorded prior, vs Rank-1 which has zero recorded `operations`
instance, only a generic mechanism note; (b) the two modes "can fire together"
(vault:71,97). So the evidence supports "Rank-1 explains the badge" but NOT
"Rank-1 is the cause" to the exclusion of a co-firing Rank-2. The intake does
keep Rank-2 live (good), but §11 ledger line 223 promotes "Rank 1:
stuck-finalizer caused the 404" as the single A2 mechanism claim, understating
the confounder.

**Conditional belief-change.** If accepted → keep ordering (badge logic is
valid) but reframe §4 Rank-1 as "explains the `Deleting` badge; does NOT exclude
a co-firing Rank-2 cred-gap (operations is a recorded victim)" and make §5#4
(cred-gap child probe) MANDATORY even when §5#2 confirms the finalizer — do not
let a confirmed Rank-1 short-circuit the Rank-2 check, because unsticking the
finalizer then re-rendering into an uncovered repo-creds gap re-404s the slot.
This is a sequencing safety point, not a reorder.

### F4 — MEDIUM — §6 "redeploy into Terminating namespace" trap is stated, but the more likely trap here (sync/recreate INTO a finalizer-wedged Application) is not gated

**Evidence.** §6 (sre-intake.md:164) correctly warns "Do not redeploy blindly
into a `Terminating` namespace." But per F1, the namespace is likely `Active`
while the **app-of-apps Application** is the wedged object (`Deleting` badge).
The realistic operator footgun is re-running the create pipeline 2412 or
hitting ArgoCD SYNC on an Application that still carries a `deletionTimestamp`
— ArgoCD will report the sync accepted (green) while the finalizer prevents the
new generation from materializing (exactly the vault's "green pipeline only
proves the request reached ArgoCD" failure, vault:29). The §6 gate covers the
ns case but not the Application-CR-mid-deletion case, which is the one the
screenshot actually shows.

**Conditional belief-change.** If accepted → add a §6 HALT: "Do NOT SYNC or
re-run pipeline 2412 against `operations-app-of-apps` while it carries a
`deletionTimestamp` (the `Deleting` badge). A sync into a finalizer-wedged
Application reports green and renders nothing; resolve the deletion
(finalizer/Controller, gated per §6) or let it complete FIRST."

### F5 — LOW — §5#8 Logic App run-list query is valid but `startTime` field name is provider-version-fragile; az pipelines/build show + curl probes are valid

**Evidence.** §5#8 (sre-intake.md:141)
`az logic workflow run list -n vpp-fbe-autodelete-trigger -g rg-vpp-app-sb-401
--top 5 --query "[].{startTime:startTime,status:status}" -o table` — the
`az logic workflow run list` run object exposes `startTime`/`endTime`/`status`,
so this runs; LOW risk only that older api-version surfaces `properties.startTime`.
§5#7 `az pipelines build show --id 1685434 --org ... -p "Myriad - VPP" -o json`
is valid (quoted project with space is correct). §5#6 curl
`curl -svk "..." 2>&1 | grep -iE "Request-Context|x-correlation-id|Content-Type"`
is valid and correctly read-only (GET, `-v` to stderr merged via `2>&1`). No
mutating probe found in §5 — all reads. Resolved-id audit vs screenshot +
slack-harvest: ctx `vpp-aks01-d`, ns `operations`, app `operations-app-of-apps`,
ApplicationSet `vpp-feature-branch-environments`, sub `7b1ba02e...`, RG
`rg-vpp-app-sb-401`, build `1685434`, branches `fbe-851436` / `fbe-806738`,
app-of-apps Path `Helm/vpp-core-app-of-apps` — **all match the screenshot and
harvest exactly.** No misroute risk from ids.

**Conditional belief-change.** If §5#8 returns no rows due to field-name skew →
fall back to `... -o json` and read raw, before concluding "no recent run /
human trigger." Minor.

## What is operationally solid

- **Resolved-id manifest (§2) is clean.** Every id cross-checks against the
  screenshot and slack-harvest; the app-of-apps `Namespace: operations` vs
  Application-object-in-`argocd` distinction is handled correctly (§5#2 uses
  `-n argocd`). No fix-agent misroute from ids.
- **Safety gates (§6) are accurate and load-bearing.** "destroy-2629 is NOT a
  rollback" is faithfully transcribed from vault:113 (recursive-F2, F19 tf
  version skew, 260+ resource blast radius). Auto-evict race
  (`vpp-fbe-autodelete-trigger`, Mon–Fri 14:30 W.Europe, >4-day TTL, 2629 with
  `bypassEnvironmentOwnerValidation=true`) matches vault:121-122. Finalizer
  force-removal correctly gated behind live proof + authorization (vault:114),
  with the missing-recipe GAP honestly flagged (§7).
- **"Green build ≠ live slot" framing** (§1, Infra Tests 2/4) is the right
  anchor and is well-sourced.
- **§5#6 routing split** (404 with vs without `x-correlation-id`) correctly
  hands authority to `eneco-howto-fix-activation-mfrr-feature-branch-404` on the
  with-header branch — accurate scope handoff.
- **Read-only-first discipline** and human-decision gates (§10) are coherent and
  conservative.
