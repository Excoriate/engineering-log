---
task_id: 2026-06-02-001
agent: sherlock-holmes
status: complete
timestamp: 2026-06-02T11:30:00+02:00
summary: |
  Adversarial attack on the BTM TF401019 causal chain. Attempted to DESTROY the
  diagnosis "TF401019 originates from az boards query git-remote auto-detection
  (/vsts/info), therefore --org/--project/--detect false fixes it." Result: the
  CORE causal attribution SURVIVES and is strengthened by live probes — TF401019
  can ONLY come from /vsts/info (it embeds the repo id; --detect false issues 0
  such calls even cold-cache), and az boards work-item update does NOT emit
  /vsts/info at all. BUT three load-bearing sub-claims are corrected/qualified:
  (1) the trigger is a COLD detection cache (ephemeral MS-hosted agent = always
  cold), not merely "omitting --org/--project" as context.md line 16 states;
  global az defaults do NOT suppress detection but explicit flags do — the
  mechanism statement in E4/L1 is imprecise though the fix is unaffected.
  (2) The admitted INFER (E12/Q4) is NOT fatal — wiql runs collection-scoped at
  _apis/wit/wiql with no repo segment; only the CLI's repository self-detection
  needs /vsts/info, which the project-scoped token is denied — DEFER on exact
  ACL but the fix removes the call regardless. (3) A SECOND uncovered failure
  mode exists: empty work_items → WIQL "IN ()" → "Expecting constant value",
  also silently swallowed; the fix alone does not cover it (hardening does).
  Hypothesis eliminations (cross-project, self-hosted PAT, projects-call-404)
  are SOUND. Version-drift (Q5) is plausible but not load-bearing.
---

# Adversarial Receipt — Sherlock: attack the BTM TF401019 causal chain

Role: destroy the root-cause diagnosis, do not confirm it. All probes run live
read-only as `Alex.Torres@eneco.com` against org `enecomanagedcloud`, project
`Myriad - VPP`. No ADO mutation. `az` 2.86.0, `azure-devops` ext **1.0.2**.

## Verdict at a glance

| # | Attack target | Status | Belief-change |
|---|---------------|--------|---------------|
| 1 | TF401019 provably from `/vsts/info` (not work-item update / projects-call / git log) | **REBUT (diagnosis survives)** + mechanism CORRECTION | If the error were from a call `--detect false` does NOT remove, the fix is void. Proven it is removable. |
| 2 | INFER hole (E12/Q4): why token denied on same-project `/vsts/info` while checkout self works | **DEFER (not fatal)** | If token genuinely lacks ALL repo access AND a post-fix call still needs it → fix incomplete. Shown post-fix path needs NO repo resolution. |
| 3 | Falsifier to distinguish "detection is cause" from alternatives | **RUN — discriminating** | Output below CONFIRMS detection-as-cause and the fix's sufficiency. |
| 4 | Soundness of H2/H3/H4/H5 + self-hosted-PAT elimination | **REBUT (sound)** with one qualifier | Cross-project / projects-404 / self-hosted-PAT correctly eliminated; version-drift retained as masking, not cause. |

---

## Finding 1 — Is TF401019 PROVABLY from `/vsts/info`? (the load-bearing claim)

### What the actual script does (fetched live from repo @ main)

`azure-pipelines/steps/azure-boards-add-tag.sh` (via `az devops invoke … git/items`):

```bash
work_items=$(git log --format=%B | grep 'Related work items:' | grep -Po '\d+' | sort | uniq | paste -sd, -)
query=$(cat <<- END
  SELECT System.Id, System.Tags
  FROM workitems
  WHERE System.AreaId = 6393 AND System.Tags NOT CONTAINS '$TAG' AND System.Id IN ($work_items)
END
)
while read -r work_item_id tags ; do
  az boards work-item update --id "$work_item_id" --field "System.Tags=$tags; $TAG" ...
done <  <(az boards query --wiql "$query" --output table | tail -n +3)
```

Three candidate emitters of TF401019, tested independently:

- **`git log --format=%B`** — local, no network. **A1 FACT**: cannot emit a server-side `TF401019`. Eliminated.
- **`az boards work-item update`** (proxied read-only by `az boards work-item show`,
  same client/detection path) — **A1 FACT (probe C/D)**: with NO flags it issues
  `/_apis/projects?$top=1` then `/_apis/wit/workItems/<id>` — **ZERO `/vsts/info`
  calls**. It does not perform git-remote repository detection. Therefore the
  byte-for-byte `eneco.vpp.behindthemeter` string **cannot** come from the update call.
- **`az boards query`** — **A1 FACT (probe, cold cache)**:
  `DEBUG: GET https://enecomanagedcloud@dev.azure.com/enecomanagedcloud/myriad%20-%20vpp/_git/eneco.vpp.behindthemeter/vsts/info`
  — the lowercased repo id is byte-identical to build 1663945 log 43.

**Conclusion of attack 1**: TF401019 can originate from **only** `az boards query`'s
`/vsts/info` repository self-detection. The diagnosis's attribution is CORRECT.
**Status: REBUT (the diagnosis survives the attack).**

### BUT — the MECHANISM statement is imprecise (correction, not a kill)

context.md line 16 + E4 + plan L1 say detection fires *"because the calls omit
`--organization`/`--project`"*. Live probes show the true trigger is a **COLD
detection cache**, modulated by how org/project are supplied:

| Condition | `/vsts/info` issued? | Source |
|-----------|----------------------|--------|
| no flags, **cold** `remotes.json` | **YES (count=2)** | A1 probe (cold) |
| no flags, **warm** cache | NO (count=0) | A1 probe (re-run) |
| global `az devops configure` defaults set, cold | **YES** | A1 probe (first run) |
| explicit `--organization` **and** `--project` flags (no `--detect false`) | **NO** | A1 probe A |
| `--organization --project --detect false`, **cold** | **NO (count=0)** | A1 probe G |

Cache file: `~/.azure/azuredevops/cache/remotes.json` (keyed by git remote;
populated by the `/vsts/info` round-trip, reused after).

**Why this matters and why it does NOT break the fix:**
- The **Microsoft-hosted `ubuntu-24.04` agent is ephemeral → the detection cache
  is ALWAYS cold** → `az boards query` with no flags **always** hits `/vsts/info`
  on the agent. This *strengthens* the "fails every run" claim (E11) versus my
  laptop where a warm cache hid it intermittently.
- Global config defaults do **not** suppress detection (cold run still fired);
  only **explicit `--detect false`** removes it deterministically (probe G,
  cold, count=0). The plan's fix passes `--detect false`, so it is correct.

**CONDITIONAL belief-change**: *If* the fix had relied on `--org/--project`
ALONE (no `--detect false`), probe A shows that would ALSO have worked on the
agent — but probe (global-defaults, cold) shows config defaults are NOT
equivalent to flags, so the brittle path would be config-dependent. The chosen
fix (`--detect false`) is the robust one. No route change; **amend E4/L1 wording**
from "omits --org/--project → detection" to "cold detection cache + no explicit
context flags → /vsts/info repository self-detection; --detect false removes it".

---

## Finding 2 — Is the admitted INFER (E12/Q4) a FATAL hole?

The diagnosis honestly labels E12 **A2 INFER**: it cannot fully explain why the
project-scoped Build Service token is denied on the same-project `/vsts/info`
while `checkout: self` succeeds with the same token; and asks whether the true
cause is that the token genuinely lacks repo access (so a later op fails anyway).

### Attack and evidence

1. **The work itself never needs `/vsts/info`.** Probe O: the real Boards
   operation is `POST https://dev.azure.com/enecomanagedcloud/_apis/wit/wiql`
   — **collection root, no project segment, no repository segment** (200 OK).
   `az boards work-item show/update` hits `/_apis/wit/workItems/<id>` (probe C/D).
   **A1 FACT**: none of the functional Boards calls touch the BtM git repository.
   `/vsts/info` is *purely* the CLI resolving "which repo is this working dir?"
   — an artifact of context auto-detection, not a data dependency of tagging.

2. **`--detect false` makes repo-resolution structurally absent.** Probe G (cold):
   `/vsts/info` count = 0. With no repo-resolution call, a `TF401019` *naming the
   git repo* is structurally impossible on the post-fix query path. **A1 FACT.**

3. **Could the token lack repo access such that a LATER op fails?** The only call
   that referenced the repo was `/vsts/info`. After removing it, no remaining call
   in the script references `Eneco.Vpp.BehindTheMeter` (probes E/G/O: only
   `/_apis/projects`, `/_apis/wit/wiql`, `/_apis/wit/workItems`). So even if the
   project-scoped token has zero Git-repo read on that repo, the tagging flow does
   not exercise repo read post-fix. **A2 INFER (strong)**: the fix does not merely
   move the denial — it eliminates the only repo-scoped call.

4. **Why checkout self works but `/vsts/info` is denied (the unexplained part).**
   Still **A2 INFER / DEFER**. `checkout: self` uses the repo-scoped checkout
   credential the agent injects for the triggering repo; the `/vsts/info` endpoint
   is reached by the azure-devops CLI as a *generic API caller* using
   `AZURE_DEVOPS_EXT_PAT=$(System.AccessToken)`, and the 404-masks-403 indicates
   the Build Service identity is denied the `vsts/info` repository-context read
   under `enforceJobAuthScope=true`. I could **not** run the pipeline-side
   `system.debug=true` trace in this session (read-only, cannot mutate/queue),
   so the exact ACL that distinguishes the two credentials is **UNVERIFIED[blocked:
   needs in-pipeline --debug trace + repo ACL on the Build Service identity]**.

**Status: DEFER (the hole is real but NOT fatal to the fix).**

**CONDITIONAL belief-change**:
- *If* an in-pipeline `system.debug=true` trace shows TF401019 emitted by a call
  **other than** `/vsts/info` (e.g. a repo read still issued after `--detect false`),
  → the fix is INVALID and the route must change to a token/permission fix
  (grant the Build Service repo read, or use a scoped service connection / PAT).
  Probe G makes this unlikely but it is the decisive disconfirmation.
- *If* the trace confirms `/vsts/info` is the only TF401019 source AND it vanishes
  under `--detect false`, → E12 can be promoted A2→A1 and Q4 closed. Until then,
  E12 must remain INFER and the package must NOT claim "permission fully explained."

---

## Finding 3 — Discriminating falsifier (designed + RUN)

**Design**: a probe whose output differs depending on whether "detection is the
cause" vs "token lacks repo access regardless of detection."

| Probe | Detection-is-cause predicts | Token-lacks-access predicts |
|-------|----------------------------|-----------------------------|
| cold cache, no flags, `--debug` | `/vsts/info` GET present, repo id in URL | (same — does not discriminate alone) |
| cold cache, `--org --project --detect false`, `--debug` | **`/vsts/info` count = 0**, wiql succeeds | repo-scoped call still present and would 404 |
| `az boards work-item show` no flags | **no `/vsts/info`** (update path repo-independent) | repo call present |

**RUN (A1 FACT, this session):**

- Cold, no flags: `grep -c vsts/info` = **2**; URL =
  `.../myriad%20-%20vpp/_git/eneco.vpp.behindthemeter/vsts/info` (matches log 43).
- Cold, `--org --project --detect false`: `grep -c vsts/info` = **0**; wiql
  `POST /_apis/wit/wiql HTTP/1.1 200`.
- `az boards work-item show` no flags: emits `/_apis/projects` + `/_apis/wit/
  workItems/<id>`, **no `/vsts/info`**.

**Interpretation**: CONFIRMS detection-as-cause and the fix's sufficiency on the
query path; REFUTES "token lacks access so even detection-off fails" for every
call the script actually makes. The only residual that would REFUTE is an
in-pipeline trace showing a different repo-scoped call (Finding 2, blocked).

**What output would have REFUTED the diagnosis** (none observed):
`grep -c vsts/info` > 0 under `--detect false`; OR a `/_apis/git/repositories/...`
call in the work-item path; OR TF401019 text on a non-`/vsts/info` request line.

---

## Finding 4 — Are the hypothesis eliminations sound?

- **Cross-project work-item update (plan Q1 / H "dubious ownership")** —
  **REBUT (sound)**. A1 probe N: work item 407582 → `project: Myriad - VPP`,
  `area: Myriad - VPP\Team BtM`. AreaId 6393 is in-project; wiql is collection
  scoped (probe O). No cross-project call. Eliminated correctly.
- **Self-hosted agent expired PAT (Q2 / LL-006)** — **REBUT (sound)**. A1 (E8):
  failing run is on `vmImage: ubuntu-24.04` (MS-hosted) with
  `AZURE_DEVOPS_EXT_PAT=$(System.AccessToken)`; no self-hosted agent in the path.
  LL-006 (self-hosted PAT) does not apply to THIS pipeline. Eliminated correctly.
- **`/_apis/projects?$top=1` as the 404 source** — **REBUT (sound)**, newly tested.
  A1 probe I: that call returns `200` with a *project* object (`CCoE`), not a git
  repo; TF401019 names a *git repository* and embeds the repo id — structurally it
  can only come from `/vsts/info`. The projects-call hypothesis is dead.
- **Ref / network / force-push (H2/H3/H4/H5 per prompt)** — **REBUT (sound by
  exclusion)**. TF401019 = documented 404-masks-403 on repo resolution; the repo
  exists and is enabled (A1: `az repos show` → `isDisabled:false`,
  defaultBranch `refs/heads/main`, id `718866fa…`). A transient network/ref/
  force-push fault would not produce a deterministic, every-cold-run `/vsts/info`
  403, nor a byte-stable repo-id error. Detection mechanism is deterministic
  (probe: cold → always fires). Eliminated correctly.
- **Version drift ubuntu-24.04 vs sre-managed-linux (Q5)** — **DEFER (correctly
  scoped as masking, not cause)**. Local ext = 1.0.2; agent bundled version
  unknown this session. The plan treats the pool switch as masking (different az/
  ext version or cached broad credential), NOT as fixing the root cause — that is
  the right call. **CONDITIONAL**: *if* a future probe shows the MS-hosted agent's
  bundled `azure-devops` ext does NOT perform `/vsts/info` detection at all, then
  the "detection" mechanism would be version-specific and the byte-match could be
  a local-only artifact → re-open. Mitigation: validate against the agent's actual
  ext version via a pipeline `--debug` run before declaring victory.

---

## Residual risks the diagnosis/fix MUST carry forward

1. **Empty-work-items second failure mode (NOT covered by the --detect-false fix).**
   A1 FACT (probe L): when `git log` finds zero "Related work items", the script
   builds `... System.Id IN ()` and `az boards query` returns
   `ERROR:  Expecting constant value. The error is caused by «)».` — a *different*
   error that is **also silently swallowed** (no `set -e`, inside `< <( )`). The
   primary fix does not address this; only the **hardening** (`set -euo pipefail`
   + empty-`work_items` guard) does. **Stakes: MEDIUM** — without the guard,
   `set -e` would turn legitimately-empty commits into RED pipelines (false
   failures), so the guard is REQUIRED before adding `set -e`, not optional.
2. **In-pipeline confirmation still owed.** The decisive A1 promotion of E12 needs
   a `system.debug=true` pipeline run showing `/vsts/info` 403 then its absence
   post-fix. Until then the package must keep E12 as A2 and must NOT claim the
   permission mechanism is fully proven.
3. **Agent ext-version parity.** The repro ran on ext 1.0.2 locally; confirm the
   MS-hosted agent's bundled `azure-devops` ext also issues `/vsts/info` (it
   almost certainly does — same SDK), via the same debug run.

## Bottom line

The **central causal claim withstands demolition**: TF401019 is provably and
exclusively a product of `az boards query`'s cold-cache git-remote repository
self-detection (`/vsts/info`), and `--org/--project/--detect false` removes that
call deterministically even on a cold cache (the agent's permanent state). The
work-item update path never touches the repo, so the fix cannot merely relocate
the denial. Three corrections stand: (a) restate the mechanism as cold-cache +
explicit-flag-dependent, not "omits --org/--project"; (b) keep E12 as INFER and
owe one in-pipeline `--debug` trace; (c) ship the empty-`IN()` guard alongside
`set -e` or risk a new false-RED failure mode. Hypothesis eliminations are sound.
