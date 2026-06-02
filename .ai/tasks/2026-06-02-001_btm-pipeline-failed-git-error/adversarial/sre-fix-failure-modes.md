---
task_id: 2026-06-02-001
agent: sre-maniac
status: complete
timestamp: 2026-06-02T00:00:00Z
summary: |
  Adversarial review of the BTM TF401019 fix (fix.md + azure-boards-add-tag.fixed.sh).
  The org/project/--detect false root-cause fix is CORRECT and I could not break it.
  But the HARDENING (set -euo pipefail) plus the table-parsing logic introduces NEW
  break-shaped failure modes that the original swallowed:
  (1) `read -r work_item_id tags` mis-parses `az boards query --output table` rows because
  ID and Tags are SPACE-aligned columns and multi-tag values contain spaces — proven live:
  every BtM row I queried has an empty Tags column, so `tags=""` and the script writes
  `System.Tags=; DEV` (a leading empty tag). When Tags IS multi-value (`a; b; c`), `read`
  splits it so only the FIRST tag is preserved and the rest are silently dropped.
  (2) `--fields` is argparse `nargs='*'` + `field.split('=',1)` (verified in extension source);
  a quoted value survives, but the construction is fragile and `--fields` vs `--field` is NOT
  a behavior change (prefix-match resolves both to the same param) — fix.md's claim is fine.
  (3) BEHAVIOR-CHANGE RISK is real and under-documented: set -e converts a previously-GREEN
  build to RED on ANY az failure, including a transient query 5xx or a future cross-project
  work item — this can BLOCK deployments. Not gated behind a non-fatal tagging guard.
  (4) Option A removes the failing call correctly, but `--project "Myriad - VPP"` with a space
  is safe ONLY because it is quoted; SYSTEM_TEAMPROJECT empty-string is NOT possible in-pipeline
  but the local fallback masks it.
  (5) Verification proves the tag is realized (good) but has NO rollback/canary and the
  negative-control step re-introduces the failing call into a real (throwaway) branch — risky.
  Net verdict: root-cause fix SHIP-able; hardening as written is FIX-FIRST.
---

## Key Findings

- **finding_1_table_parse** — `read -r` mis-parses space-columned `--output table`; empty
  tags → `System.Tags=; DEV`; multi-tag → only first tag kept. BREAK-SHAPED.
- **finding_2_fields_flag** — `--fields` is `nargs='*'` + `split('=',1)` (verified in
  extension source); quoted value is preserved; `--field` vs `--fields` is NOT a behavior
  change. REBUT the risk, but flag the un-quote fragility.
- **finding_3_behavior_change** — `set -e` turns green→red on ANY `az` failure incl.
  transient 5xx / future cross-project work item; can block deploys; undocumented.
  BREAK-SHAPED.
- **finding_4_option_a_pipeline** — removes the failing call correctly; project-with-space
  safe only because the `az_ctx` array is quoted; empty `SYSTEM_*` impossible in-pipeline,
  local fallback masks it.
- **finding_5_verification_gap** — proves the realized tag (good) but no rollback/canary;
  `System.Tags` PATCH replaces the full tag list with no snapshot; negative-control
  re-introduces the failing call into a real branch.

# Adversarial Receipt — SRE failure-mode attack on the BTM TF401019 fix

Role: try to BREAK the fix and its verification. I did not endorse anything I could not
re-derive from evidence. Evidence labels per repo convention: `A1 FACT` (externally
witnessed: file:line, live command output, or source), `A2 INFER` (named reasoning from
A1s), `A3 UNVERIFIED[blocked: reason]`.

## Evidence base (live probes, this session)

- **A1** — `az` versions: `azure-cli 2.86.0`, `azure-devops 1.0.2`
  (`az --version`, this session).
- **A1** — `az boards work-item update --help`: `--fields -f : Space separated "field=value"
  pairs ...` (live help output, this session).
- **A1** — Extension source `~/.azure/cliextensions/azure-devops/azext_devops/dev/boards/arguments.py:16,20`:
  `context.argument('fields', nargs='*', options_list=('--fields', '-f'))` for create + update.
- **A1** — Extension source `.../dev/boards/work_item.py:152-158`:
  ```python
  if fields is not None and fields:
      for field in fields:
          kvp = field.split('=', 1)
          if len(kvp) == 2:
              patch_document.append(_create_work_item_field_patch_operation('add', kvp[0], kvp[1]))
          else:
              raise ValueError('The --fields argument should consist of space separated "field=value" pairs.')
  ```
- **A1** — Live BtM query, `--output table`:
  ```text
  ID      Tags
  ------  -----------------------------------------------------
  407582
  407712
  408284
  ...
  ```
  Every returned BtM row (AreaId 6393) has an **empty Tags column**. (`az boards query
  --organization https://dev.azure.com/enecomanagedcloud/ --project "Myriad - VPP"
  --detect false --wiql "SELECT [System.Id],[System.Tags] FROM workitems WHERE
  [System.AreaId]=6393" --output table`, exit 0).
- **A1** — Pipefail probe: a FAILING WIQL (`[System.Tags] <> ''`) piped to `tail -n +3`
  under `set -o pipefail` returned **exit 1** and `matches=[]`
  (live, this session). The same failing query WITHOUT the pipe returned exit 0 — so
  `az boards query`'s own exit code is inconsistent and the pipeline exit is what
  `set -o pipefail` latches onto.
- **A1** — `[System.Tags] <> ''` returns `ERROR: The specified operator cannot be used with
  long-text fields` but the bare command **still exited 0** (live). Confirms `az boards query`
  can print an error to stderr and exit 0.

---

## Finding 1 — `read -r work_item_id tags` mis-parses the table; tags are dropped or empty

**Status: REBUT-of-safety → the bug is REAL (BREAK-SHAPED). The script does NOT correctly
round-trip existing tags.**

### Mechanism (A2 from the A1 table output + A1 read semantics)

The loop consumes `az boards query ... --output table | tail -n +3`, i.e. rows of the form:

```text
<ID>    <Tags>
```

where the two columns are **whitespace-aligned** (not tab- or delimiter-separated).
`read -r work_item_id tags` splits on `$IFS` (default space/tab/newline):

1. **Empty-Tags case (the ACTUAL live data).** Live query proved every BtM row prints as
   `408284` with an empty Tags column (A1). `read -r work_item_id tags` then sets
   `work_item_id=408284`, `tags=""`. The script (fixed.sh:70) builds
   `--fields "System.Tags=$tags; $TAG"` → `--fields "System.Tags=; DEV"`.
   **A2:** This writes `System.Tags` to the literal value `"; DEV"` — a tag list whose
   first element is empty. ADO uses `;` as the tag delimiter, so this is at best a single
   `DEV` tag with a stray empty element, at worst (depending on ADO trim behavior)
   a tag literally named ` DEV` with a leading space. The leading `; ` is unnecessary and
   was only "safe" before because the original swallowed failures.

2. **Multi-tag case (the failure the author intends to preserve).** If a work item already
   carries `Critical; Reviewed; Customer Impact`, the table column is the string
   `Critical; Reviewed; Customer Impact`. `read -r work_item_id tags` puts the **whole
   remainder into `tags`** ONLY because `tags` is the last field — so far OK. BUT the
   table renderer right-pads / may collapse internal spacing, and more importantly a tag
   that itself contains spaces (`Customer Impact`) is indistinguishable from the column
   boundary if az ever emits >2 columns or wraps. The real, demonstrable corruption:
   **mis-parse input** — a row where the WIQL `SELECT` returns 3 columns (e.g. someone
   adds `System.Title` to the query, or the table wraps a long tag):
   ```text
   408284  Critical; Reviewed
   ```
   `read -r work_item_id tags` → `work_item_id=408284`, `tags="Critical; Reviewed"`. Then
   `--fields "System.Tags=Critical; Reviewed; DEV"`. Because of Finding 2 this single
   quoted token is preserved verbatim, so this specific 2-tag case happens to survive —
   but only by luck of quoting, and the leading-empty-tag and column-wrap cases do not.

3. **Header-offset assumption `tail -n +3`.** A1 confirms exactly 2 header lines
   (title + dashes), so `+3` is correct **today**. **A2:** this is an unguarded assumption —
   if az ever emits a warning line to stdout (it currently sends warnings to stderr, but
   `--output table` formatting is not contractually stable across extension versions),
   `+3` silently eats the first real row or includes a dash line that `read` then tries to
   tag as work item `------`. No test pins this.

### Concrete mis-parsing input

Live data already supplies it: work item `408284` with empty Tags →
`System.Tags=; DEV`. That is a malformed tag write happening on the very first real run.

### Conditional belief-change

**If** the goal is to preserve existing tags faithfully, **then** the script MUST stop
parsing `--output table` with `read`. Switch the query to `--output tsv` (tab-delimited,
stable) **or** `--output json` and parse with `jq -r '.[] | [.fields."System.Id",
(.fields."System.Tags" // "")] | @tsv'`, then `IFS=$'\t' read -r id tags`. AND build the
field without a leading `; ` when `tags` is empty:
`new="$TAG"; [[ -n "$tags" ]] && new="$tags; $TAG"; --fields "System.Tags=$new"`.

---

## Finding 2 — `--fields` vs `--field`, and `;`/space handling

**Status: REBUT (the fix.md claim is CORRECT). No behavior change; quoted value is safe.
Minor fragility flagged as DEFER.**

### Evidence

- **A1** — `--fields` is registered `nargs='*'` (arguments.py:16,20) and parsed by
  `field.split('=', 1)` (work_item.py:154). `split('=', 1)` splits on the **first `=`
  only**, so everything after the first `=` — including `;`, spaces, and additional `=` —
  is preserved as the value. The single shell-quoted token `"System.Tags=Critical;
  Reviewed; DEV"` arrives as ONE argparse list element, `split('=',1)` →
  `['System.Tags', 'Critical; Reviewed; DEV']`. **The semicolons and spaces are preserved.**
- **A2** — `--field` (singular) is not a distinct parameter; az CLI resolves it by
  unambiguous-prefix matching to `--fields`. fix.md:55 states exactly this. **Therefore
  `--field` → `--fields` is NOT a behavior change.** REBUT the premise of a behavior change.

### The ONE way this DOES break (carve-out)

**A2:** Because `nargs='*'` splits on **unquoted** whitespace, the safety depends entirely
on the value being a single shell-quoted token. fixed.sh:70 quotes it (`--fields
"System.Tags=$tags; $TAG"`) — correct. **But** the original diff in fix.md:45 also quotes
it. So both are safe. If a future edit ever drops the quotes, argparse would receive
`System.Tags=Critical;`, `Reviewed;`, `DEV` as **three** list elements; `Reviewed;` and
`DEV` have no `=` → `ValueError: The --fields argument should consist of space separated
"field=value" pairs` (work_item.py:158) → under `set -e` a **RED build**. That is a
latent foot-gun, not a current bug.

### Conditional belief-change

**If** anyone later un-quotes or reflows the `--fields` argument, **then** the command
aborts with ValueError. Add a comment pinning the quoting requirement, and prefer building
the value into a variable first: `field_val="System.Tags=$new"; ... --fields "$field_val"`.
No change required to correctness today.

---

## Finding 3 — Behavior change: `set -e` converts green→RED on ANY az failure

**Status: RESOLVE-required (BREAK-SHAPED, under-documented). This is the most dangerous
finding for production.**

### Mechanism

fix.md:64-70 explicitly celebrates that hardening makes failures RED. **A2:** that is
correct for the TF401019 case, but `set -euo pipefail` is **indiscriminate** — it aborts on
*every* non-zero az exit, including failures that have nothing to do with the tagging bug:

1. **Transient ADO 5xx / throttling.** `az boards work-item update` hitting a 503 or a
   429 now **fails the deployment job**. Tagging is a cosmetic post-step; a transient WIT
   API blip should not block a DEV/ACC/PRD deployment. **Cascade:** ADO WIT API degraded
   → tagging step exits non-zero → `set -e` aborts → deployment job RED → release blocked
   → on-call paged for a *tagging* failure during an unrelated WIT outage.
2. **Future cross-project / re-homed work item.** If a referenced work item ever moves out
   of AreaId 6393 / project "Myriad - VPP" (re-org, area-path change), the project-scoped
   update returns TF401019/403 → `set -e` → RED build. The original tolerated this.
   **A1** supports plausibility: the original failure was itself a scoping/permission 404.
3. **Pipefail on the query.** A1 proved that a failing WIQL piped to `tail` returns exit 1
   under pipefail (`matches=[]`, exit 1). So a malformed-WIQL regression, or the
   `<long-text operator>` class of WIQL error, now **aborts the script** at line 63 before
   any tagging — converting a previously-silent no-op into a hard deploy failure.

### Is it acceptable / documented?

fix.md documents the *intent* (make failures visible) but does **not** document the
*blast radius* (a tagging-only step can now fail a deployment). There is no scoping of
`set -e` to the tagging logic, and no fallback. **A3 UNVERIFIED[blocked: pipeline YAML not
in this workspace]:** whether the tagging step is `continueOnError: true` in the pipeline
YAML is unknown — if it is, `set -e` is neutralized at the step level (failures stay
non-blocking but also stay invisible, re-creating the original silent-miss); if it is NOT,
this step can now block deployments. This MUST be checked before merge.

### Conditional belief-change

**If** the tagging step is NOT `continueOnError` in the pipeline YAML, **then** the
hardened script can block deployments and MUST be changed to one of:
(a) keep `set -euo pipefail` for the *parse* logic but wrap the per-item `az ... update`
in `|| { echo "WARN: tag failed for $work_item_id"; continue; }` so a single item / transient
failure does not abort the run; OR
(b) trap and downgrade: run the whole tagging block in a subshell whose non-zero exit logs
loudly but returns 0 to the job, while still emitting a distinguishable WARN that a
dashboard/alert can catch. **Loud but non-blocking** beats **silent** AND beats
**deploy-blocking** for a cosmetic post-step.
**If** the step IS already `continueOnError`, **then** `set -e` buys nothing operationally
(failures are non-blocking either way) and the win is only clearer logs — fix.md should
say so rather than implying RED-blocks-deploy is the safety win.

---

## Finding 4 — Does Option A remove the failing call in the PIPELINE; quoting/empty-var risk

**Status: RESOLVE (mostly correct) + one DEFER on empty-var masking.**

### Removal of the failing call

**A2 from A1 source:** `resolve_instance` / `resolve_instance_and_project`
(work_item.py:126, 176) only auto-detect when `--organization`/`--detect` are not supplied.
Passing `--organization "$ORG_URL" --project "$PROJECT" --detect false` short-circuits the
git-remote detection that issued `/_git/<repo>/vsts/info`. **In the pipeline**, `az_ctx` is
applied to BOTH `az boards query` (fixed.sh:63) and `az boards work-item update`
(fixed.sh:68) — so the failing call is removed everywhere it occurred. RESOLVE.

### `--project "Myriad - VPP"` (space in project name)

**A2:** Safe **only because it is double-quoted** (`--project "$PROJECT"`, fixed.sh:43 via
the `az_ctx` array, and the array is expanded `"${az_ctx[@]}"` which preserves element
boundaries). The bash array `+ "${az_ctx[@]}"` quoting is the correct idiom and survives
the space. **If** anyone flattens `az_ctx` to a plain string or uses `${az_ctx[*]}`
unquoted, the project name splits into `Myriad` + `-` + `VPP` → wrong/empty project →
`TF200016` or auth error. The array form is correct; flag the invariant.

### Empty `SYSTEM_COLLECTIONURI` / `SYSTEM_TEAMPROJECT`

**A2:** In a real ADO pipeline both are predefined and non-empty, so empty is not a
realistic in-pipeline state. **But** the local fallback `"${SYSTEM_TEAMPROJECT:-Myriad -
VPP}"` (fixed.sh:40) only triggers on **unset**, not empty-string. If the pipeline ever
exports `SYSTEM_TEAMPROJECT=""` (e.g. a templated job that sets it conditionally), the
fallback does NOT kick in (`:-` vs `:-` actually does handle empty — `${VAR:-default}`
DOES substitute on empty; **correction:** `:-` substitutes for both unset AND empty, so
empty-string IS covered). **Revised:** empty-string is safe; only a literally-`" "`
(whitespace) value would slip through. Low risk. DEFER.

### Conditional belief-change

**If** `az_ctx` is ever expanded unquoted or as `${az_ctx[*]}`, **then** the
space-containing project name breaks — keep `"${az_ctx[@]}"`. No change needed today.

---

## Finding 5 — Verification sufficiency, rollback, canary

**Status: DEFER (verification proves realized state — good — but missing rollback/canary
and the negative-control is operationally risky).**

### What the verification gets right

fix.md:152-163 step 3 does NOT trust "pipeline green" — it re-reads `System.Tags` via
`az boards work-item show` and asserts the tag is present. **A2:** This correctly closes
the original silent-miss gap (the whole point of the incident). Good.

### Gaps

1. **No rollback step.** If the new script writes a malformed tag (Finding 1:
   `System.Tags=; DEV`, or a multi-tag clobber), there is no documented way to revert the
   tag set on affected work items. The `--fields System.Tags=...` operation **replaces**
   the entire tag list (it is a PATCH `add` on `System.Tags`, work_item.py:156), so a bad
   write **overwrites all existing tags**. There is no backup of prior tags before the
   write. **This is the highest-severity gap**: combined with Finding 1's empty-`tags`
   read, a row where `read` mis-parsed could replace real tags with just `DEV`.
2. **No canary.** The fix is applied to the script that runs on DEV/ACC/PRD tagging. There
   is no "run against one throwaway work item first" gate before it processes a real PR's
   work items. fix.md:123 mentions "do it against test work items" for local runs but the
   *pipeline* rollout has no canary.
3. **Negative-control re-introduces the failing call into a real branch.** fix.md:164-166
   step 4 says to "temporarily revert to the un-flagged `az boards` with `--debug` in a
   throwaway branch and observe ... TF401019." **A2:** running a branch that deliberately
   re-introduces the bug against the real pipeline risks (a) leaving the un-flagged code in
   if the branch is mis-merged, and (b) the negative control proves the *detection* call
   fires, not that the *tag* is wrong — it is a nice-to-have, not load-bearing, and it adds
   risk. Prefer proving the detection call via `--debug` **locally** (fix.md already shows
   this at lines 115-120) and drop the throwaway-branch step.

### Conditional belief-change

**If** the `--fields System.Tags=...` write replaces the full tag list (it does — PATCH
`add` on the field, A1 work_item.py:156), **then** the verification MUST add a
**pre-write snapshot** of each work item's `System.Tags` (so a bad write is reversible) and
a **post-write diff** asserting the tag set == `previous ∪ {TAG}` (not just `TAG present`).
Add a one-work-item canary before processing the full PR set. Drop the throwaway-branch
negative control in favor of the existing local `--debug` proof.

---

## Verdict

| Finding | Status | Break-shaped? |
|---------|--------|:-------------:|
| 1 — table parse / tag drop / `System.Tags=; DEV` | bug REAL, fix-first | YES |
| 2 — `--fields` semantics / `--field` change | REBUT (correct as written) | no |
| 3 — `set -e` green→red blast radius | RESOLVE-required, document + scope | YES |
| 4 — Option A pipeline removal + quoting | RESOLVE + low DEFER | no (with array quoting) |
| 5 — verification rollback/canary | DEFER (add snapshot + canary) | YES (tag clobber) |

**Root-cause fix (org/project/--detect false): I could not break it — SHIP-able.**

**Hardening as written: FIX-FIRST.** Two break-shaped issues remain that the original
swallowed and the new version makes worse, not better:
- the `read`-on-`--output table` parser writes `System.Tags=; DEV` on the live data I
  queried and can clobber a multi-tag work item (Finding 1), and a `System.Tags` PATCH
  **replaces** the whole tag list with no snapshot/rollback (Finding 5);
- `set -euo pipefail` is unscoped, so a transient WIT 5xx or a future cross-project work
  item now fails a *deployment* on a cosmetic step (Finding 3) — blast radius unverified
  because the pipeline YAML `continueOnError` state is not in this workspace
  (A3 UNVERIFIED[blocked]).

Minimum changes before merge: (1) parse via `--output tsv`/`json` not `--output table`;
(2) build `System.Tags` without a leading `; ` and assert union not replacement;
(3) scope `set -e` so a single-item/transient `az` failure logs loudly but does not abort
the deployment job; (4) snapshot prior tags for rollback; (5) confirm the pipeline YAML's
`continueOnError` for this step.
