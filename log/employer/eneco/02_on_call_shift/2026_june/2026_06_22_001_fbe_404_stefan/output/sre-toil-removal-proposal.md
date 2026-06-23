---
title: SRE toil-removal proposals — FBE finalizer-wedge class
status: review
timestamp: 2026-06-22T11:55:00Z
agent: eneco-sre-coordinator
---

# SRE Toil Removal Proposal

Each proposal is bound to a row of evidence in [`rca.md`](./rca.md) and the task
probe ledger. The driving fact: this slot sat **wedged mid-deletion for 21 days
(2026-06-01 → 2026-06-22)** with no signal, while three engineers burned recreate
cycles against it. Every proposal names the toil it removes, the evidence it rests
on, a **new** failure mode it could introduce, and the smallest reversible next
action. None of these auto-remove finalizers unattended — finalizer removal completes
a deletion and is irreversible.

## Toil Removal Knowledge Contract

After reading this proposal, a platform owner can:

1. **name the toil** this class generates — a 21-day silent wedge plus repeated
   no-op recreates — and point at the evidence row that proves it;
2. decide **what to automate** (read-only detection and a recreate preflight) versus
   what to **remove from automation's reach** (the irreversible finalizer mutation);
3. for each option, state the **new failure mode** it introduces and the **smallest**
   reversible action that ships it safely;
4. defend the throughline — *detect and surface automatically, mutate manually* —
   against the temptation to auto-clear the wedge.

The contract is falsifiable: every claim below cites an evidence tag (E1–E4) that
resolves to a row in the RCA or the probe ledger.

## RCA Evidence Base

| Tag | Evidence row | Source |
|---|---|---|
| E1 | app-of-apps carried `deletionTimestamp 2026-06-01T10:50:12Z` + lingering finalizer for 21 days; only 2 CRs cluster-wide carried a deletionTimestamp | `rca.md` Evidence Ledger #1, #2; probe `03`, probe `10` |
| E2 | Trigger of the 06-01 deletion unverified — `az` not logged in; timing (12:50 CEST) ≠ 14:30 auto-evict | `rca.md` Residual table; probes `07`, `08` |
| E3 | Three recreates (06-17, 06-18, 06-19) were silent no-ops because the wedged CR held the `operations-app-of-apps` name | `rca.md` Evidence Ledger #11, #12; L7 timeline |
| E4 | A controller restart (~06-16) did **not** clear the wedge | `rca.md` Evidence Ledger #10; probe `09` |

## Options Considered

Three options, each bound to an evidence tag, each naming the toil it removes, the new
failure mode it could introduce, and the smallest reversible next action.

### Option 1 — DETECT stuck app-of-apps finalizers (alert, do not auto-fix)

**Toil/risk removed**: the 21-day silent wedge. Today nothing fires when an ArgoCD
Application sits mid-deletion; the only signal was a human noticing a 404.

**Rests on**: E1 — the single discriminating field is a `deletionTimestamp` older than
N hours on an app-of-apps that no human is actively deleting. E4 shows controller
self-heal cannot be relied on to clear it.

**Expected benefit**: detection latency drops from ~21 days to minutes; the next
occurrence pages instead of festering until a developer is blocked.

**New failure mode it could introduce**: false pages during **legitimate** slow
deletions (large slots whose `resources-finalizer` is genuinely still GC-ing managed
resources). A too-low N would train responders to ignore the alert.

**Smallest reversible next action**: add a read-only alert query (Prometheus/Azure
Monitor over the ArgoCD metrics or a scheduled `kubectl get applications -A` scan)
firing when any Application has `deletionTimestamp` older than e.g. **2h**. Ship it
to a low-priority channel first, tune N against observed healthy deletion times, then
promote. No mutation, fully reversible by deleting the alert rule.

### Option 2 — CONFIRM and close the unknown-trigger gap

**Toil/risk removed**: the same destructive trigger silently recurring. We restored
the slot without learning **what** deleted it on 06-01, so the class can repeat.

**Rests on**: E2 — the trigger is A3-blocked solely because `az` was unauthenticated
during the incident; the resolving probe is already named.

**Expected benefit**: converts a guess ("probably a manual destroy, not the auto-evict")
into a fact, and tells us whether to harden the auto-evict Logic App, the destroy
pipeline `2629`, or a human runbook.

**New failure mode it could introduce**: none from the read itself (run-history is
read-only). The risk is **acting** on a premature reading — concluding "manual destroy"
from timing alone and disabling the auto-evict Logic App that other slots depend on.

**Smallest reversible next action**: post-incident, run `az login` against the Sandbox
subscription, then:

```bash
az logic workflow run list -n vpp-fbe-autodelete-trigger -g rg-vpp-app-sb-401 \
  --query "[?starts_with(startTime,'2026-06-01')]"
```

plus ADO pipeline `2629` run history around 06-01. Record the result in the RCA
Residual table. Read-only; reversible by definition.

### Option 3 — make the FBE recreate path resilient to an occupied name

**Toil/risk removed**: E3 — silent no-op recreates. Three people recreated `operations`
over three days; each "succeeded" while changing nothing, because the wedged CR still
owned the name. The pipeline reports green at "request submitted to ArgoCD", never at
"cluster materialised the slot".

**Rests on**: E3 — the recreate cannot overwrite a name held by a mid-deletion object;
a green build over a wedged slot is a guaranteed no-op.

**Expected benefit**: the recreate path **surfaces the deadlock** instead of hiding it
— the operator learns in one run that the slot is wedged, rather than after three
recreate attempts and a 404.

**New failure mode it could introduce**: a preflight that **blocks** recreate on any
detected deletionTimestamp could deadlock a legitimate recreate-after-clean-delete if
the check races the deletion completing. The preflight must *surface and warn*, not
hard-block, unless the timestamp is older than the same N as Option 1.

**Smallest reversible next action**: add a **non-mutating preflight step** to create
pipeline `2412` that runs probe 2 (read `operations-app-of-apps` deletionTimestamp)
before submitting desired state, and fails the run with a clear message —
"slot wedged mid-deletion since {ts}; clear the finalizer (see how-to-fix) before
recreating" — when a stale deletionTimestamp is found. It only reads; reversible by
removing the step.

## Recommendation

Adopt all three options, **read-only and reversible only** — and explicitly reject
auto-removing the finalizer. The cross-cutting verdict:

| Action class | Verdict | Why |
|---|---|---|
| **Auto-remove the finalizer** on detection | **Do NOT** | E1 — finalizer removal completes an irreversible deletion of 260+-resource slots; unattended automation could wipe a slot a human still wanted. Keep it human-gated (see [`how-to-fix.md`](./how-to-fix.md) safety gates). |
| **Alert** on stale deletionTimestamp (Option 1) | **Yes** | Detection is read-only and reversible; it converts a 21-day silence into a page. |
| **Preflight surface** in recreate (Option 3) | **Yes, as warn/fail not auto-fix** | Read-only; turns three silent no-ops into one explicit signal. |
| **Confirm the trigger** (Option 2) | **Yes** | Read-only; the only way the destructive trigger stops silently recurring. |

Sequencing the smallest reversible actions: ship Option 2 first (a one-off read that
closes the trigger gap), then Option 1 (a read-only alert to a low-priority channel),
then Option 3 (a non-mutating preflight in pipeline `2412`). Each is independently
revertible.

## Systemic Rationale

The throughline: **detect and surface automatically, mutate manually.** The destructive
step (clearing the finalizer) stays behind the human safety gates documented in the
fix; everything proposed for automation here is read-only and reversible.

The deeper class lesson is that this incident was invisible because the system's
**only** failure signal was a human noticing a 404 — a downstream symptom, 21 days
late. A finalizer-wedged Application is a control-plane state with no native alarm, and
ArgoCD's own self-heal (a controller restart) provably does not clear it (E4). The fix
restores one slot; these proposals remove the *toil class* by giving the wedge an early,
read-only signal and by making the recreate path refuse to lie about a no-op. None of
them touch the irreversible boundary, so the blast radius of the automation itself stays
at zero.

## Non-Goals

- **Do not auto-remove finalizers unattended.** Finalizer removal completes an
  irreversible deletion of a 260+-resource slot; it stays human-gated behind the
  [`how-to-fix.md`](./how-to-fix.md) safety gates. No alert and no preflight here is
  permitted to mutate.
- **Do not harden or disarm the auto-evict Logic App or destroy pipeline `2629` yet.**
  Until Option 2 confirms the 06-01 trigger (E2), changing either is acting on a guess
  and could break other slots that legitimately depend on the auto-evict schedule.
- **Do not hard-block legitimate recreates.** Option 3's preflight surfaces and warns;
  it must not deadlock a clean recreate-after-delete by racing a completing deletion.
- **Do not treat this proposal as the RCA.** It is the forward, toil-removal work
  derived from the RCA; the root-cause authority remains [`rca.md`](./rca.md).
