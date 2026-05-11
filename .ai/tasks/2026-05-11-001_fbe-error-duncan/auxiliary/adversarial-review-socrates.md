---
task_id: 2026-05-11-001
agent: socrates-contrarian
status: complete
summary: Diagnosis is materially correct; fix is materially safe but has 4 reader-traps and 2 unstated assumptions that should be hardened before next-shift hand-off
verdict: conditional
verdict_label: PROCEED-WITH-CHANGES
---

# Adversarial Review — Socrates Contrarian

> Scope: rca.md, fix.md, evidence-ledger.md, 01-task-requirements-final.md, with corroboration against fbe-failure-modes-catalog.md, fbe-operations-runbook.md, fbe-creation-lifecycle-deep-dive.md, the original intake (context.md), and the in-session probes under proofs/outputs/.
>
> Method: I attacked the diagnosis (Is it actually F2 Azure-resource sub-class? Is the orphan actually orphan? Could the namespace have a hidden consumer?), the fix path (Is delete-then-rerun actually safe? Can the rerun hit a different failure mode? Can the destroy-version mismatch from F19 invalidate the prior-tenant story?), the named reader (Can a cold next-shift on-call execute L11→fix.md without other docs?), and the vocabulary continuity (Does L8 introduce names not present in L1-L6?). I went hunting for A1 FACTs that should be A2 INFER, inherited claims that were never re-probed in-session, and stalled assumptions that flip the answer if false.
>
> Net assessment: The diagnosis is **materially correct and well-evidenced**. The fix is **materially safe** because the destructive Step 3 is gated by an empirical emptiness check in Step 2. But there are **four executable-script defects** and **two epistemic over-claims** that a next-shift on-call could trip over. I recommend addressing these before treating the package as zero-friction hand-off material.

---

## Strongest objection (the hill)

**`output/fix.md:170-205` Step 5/Step 6 — the `BRANCH` shell variable is set ONLY inside Option B; readers who choose Option A (ADO UI) hit unset `$BRANCH` at Step 6, and Step 5's "Branch: select Duncan's `feature/fbe-*` branch" instruction expects the reader to *know* Duncan's branch name — which is `A3 UNVERIFIED[blocked]` per evidence-ledger C13.**

Trace it through:

- `output/fix.md:172` writes `BRANCH="feature/fbe-XXXX-YYYY"` inside the **Option B** code block only.
- `output/fix.md:196-205` Step 6 references `--branch "$BRANCH"` unconditionally.
- An Option-A reader (UI trigger) never set `$BRANCH` → `az pipelines runs list --branch ""` returns the wrong filter (or all runs, depending on az version).
- Worse, both options assume the reader **knows the branch name**. The RCA's evidence ledger explicitly flags `C13` (Duncan's branch name) as `A3 UNVERIFIED[blocked]` because nobody pulled it from the build via `az pipelines runs show --id 1638601`. Duncan's branch is not in slack-intake.txt, not in context.md, not in rca.md.

**The failure scenario**: a next-shift on-call reads the fix doc, runs Step 1-4 cleanly, opens the ADO UI to trigger pipeline 2412, and is then *stuck* — they need Duncan's actual branch name but the fix doc does not tell them how to get it (it just says "Duncan's `feature/fbe-*` branch"). They could ask Duncan, but Duncan may be off-shift. The most efficient resolution is documented inside the evidence ledger but not surfaced in the fix:

```bash
# Resolve Duncan's actual branch from build 1638601
az pipelines runs show --id 1638601 \
  --org https://dev.azure.com/enecomanagedcloud \
  --project "Myriad - VPP" \
  --query "{branch:sourceBranch, requestedFor:requestedFor.displayName}" -o jsonc
```

This single command turns the A3 blocker into an A1 fact. It belongs **at the top of fix.md** as a preflight, not buried as a probe-of-a-probe in the evidence ledger.

**If this objection is valid → ACTION**: add a "Step 0 — Resolve Duncan's branch from the failing build" before Step 1; define `BRANCH=...` once at the top so Steps 5 and 6 both reference the same variable regardless of trigger path; remove the `feature/fbe-XXXX-YYYY` placeholder noise.

**If FALSE → NO CHANGE**.

---

## High-priority gaps (ordered by impact)

### HP-1. The F2 classification stretches the catalog's published definition

`output/rca.md:14` and `output/rca.md:13` declare the incident is `classification: F2 (Cleanup Residue) — Azure-resource sub-class`. But the F2 entry in the catalog (`fbe-failure-modes-catalog.md:94-145`) explicitly describes:

- **Pre-Dec-9 mechanism**: K8s namespace residue from terraform/fbe + ArgoCD dual-ownership
- **Post-Dec-9 residual**: only one specific 2026-02-05 incident where the destroy pipeline failed at Plan Terraform changes and pods were left in a "weird state"

The catalog says (`fbe-failure-modes-catalog.md:106`): *"Other non-namespace residue still occurs (e.g., 2026-02-05: \"FBE delete pipeline failed during 'Plan Terraform changes'\")"*. That is a **single-incident anchor**, not a generalized "Azure-resource sub-class".

The RCA promotes that single Feb-5 mention into a named sub-class ("F2 Azure-resource sub-class") that the catalog itself does not define. The classification is **plausible-but-novel**; calling it `F2` is convenient framing, not catalog citation.

This matters because:

1. **Symptom routing**: `fbe-failure-modes-catalog.md:610` symptom matrix routes "Pipeline 2412 fails at stage 3 DeployInfra terraform errors" to **F1, F6, F7** — NOT F2. The runbook routes "Pipeline 2412 succeeded but no pods" to F2/F3. A future on-call who follows the published catalog will route Duncan's symptom to F1/F6/F7 and miss F2 entirely.
2. **`fbe-operations-runbook.md:341-353` symptom table** has the same wiring: apply-time "already exists" is not routed to F2.

The RCA correctly flags this gap at `output/rca.md:482` ("a Phase-9 task should patch the runbook"). But the gap is **deeper than runbook patching**: the catalog itself does not yet have an "Azure-resource sub-class" entry. Either:

- **(a)** the catalog needs a new F entry (say F21: "FBE create blocked by Azure-resource orphan on slot reuse") with its own trigger/symptom/cause/fix, OR
- **(b)** F2's text needs to be amended to formally promote the 2026-02-05 anchor into a named "Azure-resource sub-class" with the apply-time symptom routed in the symptom matrix.

**If TRUE → ACTION**: downgrade `classification: F2 Azure-resource sub-class` in rca.md frontmatter to `classification: F2-adjacent — apply-time Azure-resource orphan, catalog patch required (see L10 Lesson 1, Phase-9 follow-up)`. Add a one-line note in L1 or L10 acknowledging the classification is provisional pending catalog patch.

### HP-2. The "orphan was created by a prior failed FBE-create on `kidu`" causal story is A2, not A1

`output/rca.md:339` correctly labels this as `(A2) The namespace was created by a much-earlier failed FBE attempt`. But the **rest of the RCA narrates this A2 as if it were settled**:

- `output/rca.md:452` (L7 plain-language takeaway): *"The orphan is **11 months old**. Duncan is the latest tenant of `kidu` to encounter it; he is likely not the first..."* — narrated as fact.
- `output/rca.md:534` (L10 Lesson 1): *"When an FBE destroy fails partway through, Azure resources can survive the destroy without state entries."* — generalized as if mechanism is confirmed.
- `output/rca.md:719` (L12 one-pager): *"PATTERN: F2 Azure-resource sub-class — orphan resource from prior failed/incomplete destroy on the same slot"* — declared without hedging.

The only evidence is:
- Namespace exists since 2025-06-10 (A1)
- Tags are empty (A1)
- State `terraform.kidu` does not contain the namespace (A1)
- Lease-table history is blocked (A3 per probe-10-lease-kidu.json showing RBAC 403)

Alternative hypotheses the RCA does not seriously falsify:

- **H-alt-1**: the namespace was created **out-of-band by an operator** (az cli, portal, ARM template) for a manual test in June 2025, not via pipeline 2412. Empty tags + 11-month-orphan + no state ref is consistent with this. **The RCA implicitly assumes pipeline-2412 provenance because it fits the F2 narrative; but no probe confirms provenance.**
- **H-alt-2**: the namespace **was** terraform-managed by an earlier `terraform.kidu` state file *that has since been overwritten*. The current state's lineage `8357bcbf-3d50-2550-2db2-54a751ae3333` (per probe-04-state-summary.json) is one lineage; if a destroy ran `terraform destroy` and then a subsequent create ran `terraform init` on a *fresh* backend (no migration), the lineage rolls. Empty tags + missing state entry follow naturally without ever invoking a "failed destroy".
- **H-alt-3**: F19 (terraformVersion drift). The destroy pipeline pins 1.13.1 (`fbe-failure-modes-catalog.md:572`); current state was written by 1.14.3. If a prior destroy attempt was triggered before the 1.14.3 upgrade, terraform 1.13.1 may have **silently skipped** resources whose state version it couldn't parse, leaving them in Azure while the destroy reported success. This is a structurally-different cause story.

These alternatives **do not change the fix** (delete-empty-orphan-then-retry works regardless of provenance). But they do change **L10 Lesson 1** ("F2 Azure-resource sub-class is alive — the vault is correct") which currently asserts a mechanism the in-session evidence cannot confirm.

**If TRUE → ACTION**: in `output/rca.md:339-342`, expand the A2 hedge: list all three alternative provenance hypotheses, mark them as not falsified, and add to the "What I CANNOT verify in this session" block at `output/rca.md:516-519`. Also soften L10 Lesson 1's phrasing — "F2 Azure-resource sub-class is alive" → "An apply-time Azure-resource orphan on slot reuse is empirically alive; the precise upstream provenance (failed destroy vs out-of-band create vs version-drift skip) is not in-session falsifiable."

### HP-3. The rollback in fix.md:241-249 may itself crash on the same F2 mechanism the fix is treating

`output/fix.md:241-251` proposes, as rollback, triggering destroy pipeline 2629 with `bypassEnvironmentOwnerValidation=true`. But the **rollback's own caveat at line 251** says: *"destroy itself can fail at orphan resources; in pathological cases you may need Fabrizio's intervention."*

The pathological case is **exactly the case we are in**: a kidu slot with state-vs-Azure disagreement. If the destroy pipeline runs after Step 3 succeeded and Step 5 failed, the destroy will read `terraform.kidu`, attempt `terraform destroy` on the 260 resources in state (which were all created today and are still in Azure), and then — depending on F19 (terraform version mismatch) — may or may not silently leave residue.

Worse: triggering pipeline 2629 with `environment=kidu` and `bypassEnvironmentOwnerValidation=true` will **delete Duncan's in-flight FBE**. The state has 261 resources from today's run; destroying them is exactly *not* what an operator wants if Step 5 fails. The rollback escalates the blast radius from "namespace re-orphan" to "destroy Duncan's entire half-built FBE".

**If TRUE → ACTION**: rewrite the rollback section to:

1. Make explicit that the destroy pipeline rollback **deletes Duncan's slot entirely** (not just the orphan).
2. Recommend **escalate to Fabrizio first** before triggering destroy as rollback.
3. Note that a less-destructive rollback for the specific "Step 5 fails again with same namespace error" case is `az eventhubs namespace show` → if still present, retry delete; if absent, look for a different orphan; never auto-trigger 2629 from the fix.

### HP-4. `Microsoft.EventHub/namespaces/delete` RBAC is asserted as a precondition but no in-session probe checks it

`output/fix.md:23` precondition P3 says: *"You have `Microsoft.EventHub/namespaces/delete` permission on `vpp-evh-premium-kidu`."* The mitigation text says "if you are running this as Duncan personally, your individual RBAC must include namespace delete. If unsure: see Escalation below."

But the next-shift on-call may not be Duncan; the doc names them as the reader (`output/rca.md:12`). The on-call's individual RBAC is **unverified** — and unverified at the very moment they are about to execute a destructive operation.

A probe that costs ~3 seconds resolves this before Step 3 commits:

```bash
# Dry-run the delete via what-if (Azure supports this for most resource types via PUT-with-validate)
# OR check effective permissions:
az role assignment list \
  --scope /subscriptions/7b1ba02e-bac6-4c45-83a0-7f0d3104922e/resourceGroups/rg-vpp-app-sb-401/providers/Microsoft.EventHub/namespaces/vpp-evh-premium-kidu \
  --assignee $(az ad signed-in-user show --query id -o tsv) \
  --query "[].{role:roleDefinitionName, scope:scope}" -o table
```

**If TRUE → ACTION**: add a probe between Step 2 (verify empty) and Step 3 (delete) that confirms the executor has `Contributor` or equivalent on the namespace scope. If absent, route to Escalation BEFORE the destructive command is typed.

### HP-5. Step 7 commands in fix.md cannot run until pipeline 2412's stages 5-7 complete (~30+ minutes after Step 5 starts) — but they are presented inline with no timing gate

`output/fix.md:213-233` Step 7 includes:

- `kubectl get ns kidu` — only meaningful AFTER stage 6 DeployFBEInArgoCD has created the namespace via ArgoCD.
- `curl https://kidu.dev.vpp.eneco.com/` — only meaningful AFTER ArgoCD has synced and pods are running.

But per `fbe-creation-lifecycle-deep-dive.md:188-245`, stages 5 (DeployServices) takes 20-30 min and stage 6 takes a further 3-5 min. Step 7 presented immediately after Step 6 ("verify pipeline success") with no explicit "wait until pipeline 2412 reports `result: succeeded`" gate means an over-eager reader runs `kubectl get ns kidu` 5 minutes after triggering the pipeline, sees `NotFound`, and panics that the fix failed.

The fix doc has a verification cascade at L9 in rca.md (`output/rca.md:506-513`) that DOES mention sequencing ("If `kubectl get ns kidu` returns Terminating → F2/F3 ArgoCD-finalizer; different failure mode"). But the cascade lives in the **diagnostic doc**, not the **executable doc**.

**If TRUE → ACTION**: prefix Step 7 with an explicit gate: *"Run Step 7 only AFTER `az pipelines runs list` (Step 6) shows `result: succeeded` AND `finishTime` is within the last 5 minutes."* Or insert a Step 6.5 that waits/polls for pipeline completion before proceeding to Step 7.

---

## Medium-priority gaps

### MP-1. `output/rca.md:268` claim about "the provider intentionally fails with the resource needs to be imported guard rail" is A2/training-derived, not in-session source-traced

The RCA describes the AzureRM provider's "exists check" mechanism in detail (`output/rca.md:260-269`). The claim is structurally correct in the sense that the error message itself (`output/rca.md:275-282`) names "needs to be imported". But the provider-internal mechanism description ("when CreateContext sees an existing resource at the same ID and state has no record, the provider intentionally fails with the 'resource needs to be imported into the state' guard rail") is **training-derived**, not source-traced to the hashicorp/azurerm GitHub repo or to provider docs.

This is low-risk — the description is consistent with how the azurerm provider has worked since at least v2.x — but it is exactly the kind of "training memory ≠ FACT" the brain warns about (Temporal Gap guard rail, `>2 months + versioned software → probe or context-researcher`). hashicorp/azurerm@4.40.0 is recent enough that the mechanism could be source-traced via `mcp__grep__searchGitHub`.

**Action**: either source-trace the claim (cheap; one mcp call) or downgrade the prose from declarative to "the error string implies the provider performs this check; the precise call-site is not source-traced in this RCA".

### MP-2. Vocabulary continuity — `output/rca.md:418` introduces `azurepipelines-fbe.yaml` as the "stale obsolete file" but it is introduced in L6 rather than the L2 repo inventory

L2's repo inventory (`output/rca.md:99-107`) lists the canonical pipeline as `azure-pipelines-featurebr-env.yml`. The obsolete `azurepipelines-fbe.yaml` is introduced as a parenthetical at `output/rca.md:418`. Per the vocabulary-continuity rule asked about in the brief (#10: "Does the 'name first introduced in L8 must already appear in L1-L6' rule hold?"), this is a borderline case — a cold reader hitting L6 sees the obsolete-file warning without prior exposure.

Strictly, the violation is not L8 (the fix introduces no new names beyond Context-Ledger ones), it is L6. Not a serious defect; the parenthetical is well-flagged. But by the RCA's own vocabulary-discipline standard, the obsolete-file fact would more comfortably live in L2 as a "Note: the following file is stale and should not be confused with the active pipeline" row.

**Action**: move the obsolete-file note into the L2 repo inventory as a separate row or footnote.

### MP-3. `output/rca.md:436-437` timeline rows are A1 for the *creation* timestamps but A2 (or stronger) for the *cause* attribution

Both 2025-03-05 (Standard NS) and 2025-06-10 (Premium NS) rows are tagged A1 with evidence "az eventhubs namespace show". But the rows assert *"created (by an FBE-create run, presumably)"* and *"created (by an FBE-create run, possibly the same one ... or a later attempt)"*. The createdAt timestamps are A1; the *creation mechanism* ("by an FBE-create run") is A2 or weaker — see HP-2 above.

**Action**: split the cells. `createdAt: 2025-06-10T17:28:27` is A1; `creator: pipeline 2412 attempt` is A3 UNVERIFIED[blocked: ADO build history older than retention].

### MP-4. `fix.md:23` precondition P3 implies the pipeline's SP (`SC rg-vpp-app-sb-401`) has Contributor, but no in-session probe confirms this

The precondition asserts the pipeline service principal has Contributor. This is **plausible** (the pipeline successfully created 261 other resources today, per probe-04), so the SP clearly has write-permission breadth. But "Contributor includes namespace delete" is a TRAINING-DERIVED claim that has not been re-verified against the current Azure RBAC role definition.

Operational impact is low (the doc says "if you are running this as Duncan personally, your individual RBAC must include namespace delete") but the SP-RBAC claim is unverified.

**Action**: either add a confirming probe or downgrade the precondition language to "the pipeline's service principal is expected to have Contributor; the deletion will be executed by *your* identity, not the pipeline SP, so verify your own RBAC". Sharpens the operator's mental model.

### MP-5. The Pester latent bug from F-creation-lifecycle is not in scope but is a known false-positive risk on the rerun

`fbe-creation-lifecycle-deep-dive.md:438-449` documents that the Stage 7 Pester script has a `$token` used-before-assigned bug that can silently produce false negatives on the URL check. This is **not the failure mode the RCA addresses**, but if the pipeline rerun (Step 5) "succeeds with test failures" (`output/fix.md:159` "Pipeline fails at stage 5/6/7 → not in scope of this fix; refer to the operations runbook"), the reader may misattribute the test failure to a lingering F2 issue when it is in fact the latent Pester bug.

**Action**: add one line to fix.md Step 6: *"Note: Pester (stage 7) has a known false-negative on the URL check (see fbe-creation-lifecycle-deep-dive#Pester latent bug). Stage 7 'failed' but stages 1-6 green is NOT a fix failure — verify against `curl` in Step 7 instead."*

### MP-6. The fix's Authorization gate (fix.md:27-36) does not satisfy the brain's "Destructive-action lexicon" hard requirement

The brain's CLAUDE.md HALT-on-procedure list (specifically Destructive-action lexicon section) requires `AskUserQuestion citing scope+reversibility BEFORE execution` for any lexicon-listed verb. The fix has an Authorization gate but it does NOT include an `AskUserQuestion` step — it relies on a human reader voluntarily pausing to "type / paste each `az` command yourself."

For an AI agent executing this fix (as the fix.md reader assumption states at line 11: "You are Duncan (or an AI agent assisting Duncan)"), the prose-level gate is insufficient: an AI executor with no built-in halt at `az eventhubs namespace delete` will pipe Step 3 through without an explicit user-confirmation tool call.

**Action**: prepend Step 3 with an explicit instruction that an AI executor MUST issue an `AskUserQuestion` (or equivalent confirmation tool call) before running `az eventhubs namespace delete`. The current "type it yourself" guidance assumes a human reader; the doc explicitly addresses AI executors too.

### MP-7. `output/rca.md:438` timeline row for the prior tenant's destroy attempt is A3 UNVERIFIED[blocked] but cited as the *root cause* in L10 Lesson 1

The L7 timeline correctly tags the prior-tenant destroy as A3. But L10 Lesson 1 (`output/rca.md:534`) is built on the *generalization* of this A3 mechanism. The cited probe (`for ENV in afi boltz ...; do az resource list...`) at `output/rca.md:540-544` is sensible but does not actually probe destroy-pipeline behavior — it just enumerates current Azure residue.

The L10 Defense recommendation (`output/rca.md:548`) — "The destroy pipeline ... should verify zero residue before releasing the slot" — is sound regardless of provenance. But the lesson is presented as if the destroy-failed-without-cleanup mechanism is established. It is not.

**Action**: rephrase L10 Lesson 1 to: "**Pattern**: Azure resources can survive slot release for reasons including failed destroys, out-of-band creates, terraform version drift (F19), or `terraform state rm` operator overrides. Regardless of the upstream cause, the slot release path lacks a residue-zero check." This is the actual lesson; the current phrasing prematurely closes on a specific cause story.

---

## Low-priority / cosmetic

### LP-1. `output/rca.md:60` Pipeline 2412 ADO URL uses unencoded `%20` — clickable but ugly

`Myriad - VPP` paths have `%20` (space encoded). Some markdown renderers double-encode. Cosmetic.

### LP-2. `output/fix.md:223` `az aks get-credentials` line is commented-out without explanation

`# az aks get-credentials --resource-group $(az aks list --query "[?name=='vpp-aks01-d'].resourceGroup | [0]" -o tsv) --name vpp-aks01-d` — a reader who doesn't have kubectl context set will hit a NoCurrentContext error from the next line. Either explain "uncomment if kubectl context isn't already pointed at vpp-aks01-d" or make it active.

### LP-3. `output/rca.md:307` L5 table row uses "I am NOT managing any resource at address ..." narrative voice that is harder to parse than the equivalent factual statement

Consider: *"The state does not contain `module.eventhub_namespace_premium.azurerm_eventhub_namespace.eventhub_namespace`."* vs the current personification. Style preference; not a defect.

### LP-4. `output/rca.md:74` L1 says Duncan "needed an FBE this morning" — without a UTC anchor

Duncan's Slack timestamp is 9:59 AM Amsterdam = `07:59Z`. The RCA dates are mostly UTC. Minor inconsistency.

### LP-5. `output/fix.md:142` `2>&1 | grep -i "not found" && echo "OK: namespace is gone"` will silently print nothing and exit success if the `grep` matches in the wrong language locale or if Azure changes the error wording

A more robust check: `az eventhubs namespace show ... 2>&1; [ $? -ne 0 ] && echo "OK: gone" || echo "STILL PRESENT"`. Cosmetic robustness improvement.

### LP-6. The evidence ledger refers to `probe-10-lease-kidu.json` in P-LEASE-TABLE but the file (per in-session ls) contains the RBAC 403 error text, not a JSON object

`evidence-ledger.md:49` references the lease-table probe. The file at `proofs/outputs/probe-10-lease-kidu.json` per my in-session read contains an ERROR text, not JSON. This is honest (the probe failed and was recorded with the failure text) but the `.json` extension is misleading. Either rename to `.txt` or wrap the error in a JSON envelope.

---

## What I tried to attack but could NOT find a hole

I tested the following falsification probes and they survived:

1. **Could the "orphan is empty" claim be a snapshot-in-time artifact?** — i.e., the probe returned `[]` for event hubs, but could the namespace have, say, application-level metadata (network rule sets, IP filters) whose deletion has downstream impact? Probe-01-namespace-show.json shows the namespace has `tags: {}`, `provisioningState: Succeeded`, and (implicitly, from probe shape) no network filter referenced by other resources. The standard EH namespace `vpp-evh-kidu` is separate; the storage account `vppevhpremiumkidu` (in state, created today) is the only resource that references the premium namespace by name, and it is a sibling (storage account name pattern), not a child. **No hidden consumer found.**

2. **Could the pipeline rerun hit F1 (stale branch drift)?** — Duncan's branch could be old enough that recent `development` changes invalidate it. But Duncan ran the pipeline on 2026-05-11; the failure was specifically at the namespace-conflict line, NOT at any "variable not declared" or "missing module" line. The 261 resources that DID get created today prove the branch is compatible with current terraform/fbe. F1 is excluded by the in-session state evidence.

3. **Could the same orphan exist on other slots?** — RCA correctly flags this as Phase-9 follow-up (`output/rca.md:480-481`). My objection cannot improve on the RCA's own acknowledgment.

4. **Could there be a hidden Standard EH namespace orphan in parallel with the Premium one?** — Probe P-STD-NS-OK (`evidence-ledger.md:45`) confirms the Standard NS `vpp-evh-kidu` IS tracked in state and IS in Azure. No standard-NS orphan.

5. **Could `terraform import` be a better fix than `delete + recreate`?** — Theoretically yes; the RCA chose delete-recreate because the orphan is empty (no data to preserve), the orphan is 11 months stale (likely has drift from current IaC config), and `terraform import` requires precise resource-address knowledge and exposes the operator to import-block-vs-state-merge complexity. The choice is defensible. (A small improvement: the RCA could state this rationale at `output/rca.md:464` to make the chosen path's reasoning explicit.)

6. **Could the rerun fail at F6 (Microsoft SKU)?** — The Premium SKU has been valid in westeurope for 11+ months (per the existing orphan). The pipeline successfully created 261 other resources today, including Premium-SKU dependencies like the Premium storage account. F6 is excluded by present-tense evidence.

7. **Could the rerun fail at F7 (secrets_to_copy)?** — The 261 resources successfully applied today include `module.key_vault.module.access_policy[...]` rows, `module.keyvault_secret_eventhub_namespace_premium_storage_account_primary_connection_string`, etc. F7 is excluded by partial-success evidence.

8. **The Linus-frame compounding-fragility attack: do the assumptions in the diagnosis correlate under load?** — Diagnosis assumes (a) orphan exists, (b) orphan is empty, (c) state lacks namespace entry, (d) IaC code is correct. All four are independently in-session A1. The compound risk is that the next pipeline rerun introduces a new failure mode (F19 version drift on a state-write?). Pipeline 2412 uses 1.14.3 (create), state was last written by 1.14.3 (probe-04 serial=7589, terraform_version=1.14.3). F19 does not apply on the create direction. **Compound fragility does not multiply unfavorably.**

---

## Recommended deltas (consolidated)

### Changes to `output/rca.md`

| Where | Change |
|---|---|
| `:14` frontmatter | Downgrade `classification: F2 (Cleanup Residue) — Azure-resource sub-class` → `classification: F2-adjacent — apply-time Azure-resource orphan; catalog patch pending (Phase-9)` |
| `:339-342` L5 A2/A3 block | Expand to list three alternative provenance hypotheses (failed destroy, out-of-band create, F19 version-drift skip); note all are not falsified in-session |
| `:436-437` L7 timeline | Split each "created (by an FBE-create run, presumably)" cell into A1 createdAt + A3 mechanism attribution |
| `:418` L6 obsolete-file note | Move (or duplicate) into the L2 repo inventory as a flagged row |
| `:464` L8 Fix | Add explicit rationale for "why delete-recreate over `terraform import`" — orphan empty, 11-month stale, import-block complexity |
| `:516-519` L9 honest-gap | Add: "(c) The precise provenance of the orphan (failed destroy / out-of-band create / version-drift skip) is not in-session falsifiable." |
| `:534` L10 Lesson 1 phrasing | Soften: "An apply-time Azure-resource orphan on slot reuse is empirically alive; precise upstream provenance is not in-session falsifiable. The lesson does not depend on provenance." |
| `:268` L4 provider mechanism | Either source-trace via grep-github on hashicorp/terraform-provider-azurerm@v4.40.0, OR downgrade prose to "the error string implies this check; the precise call-site is not source-traced in this RCA." |

### Changes to `output/fix.md`

| Where | Change |
|---|---|
| Before `:37` Step 1 | Insert **Step 0 — Resolve Duncan's branch** using `az pipelines runs show --id 1638601 --query "{branch:sourceBranch}" -o jsonc`; set `BRANCH=<result>` once, reference in Steps 5/6 |
| `:23` P3 precondition | Add a probe: `az role assignment list --scope /.../namespaces/vpp-evh-premium-kidu --assignee $(az ad signed-in-user show --query id -o tsv)` to verify executor has Contributor before Step 3 |
| Between Step 2 and Step 3 | Insert AI-executor gate: *"If you are an AI agent: ISSUE AN ASKUSERQUESTION TOOL CALL before executing Step 3's `az eventhubs namespace delete`."* |
| Step 5 → Step 6 boundary | Add explicit gate: *"Run Step 6 only after pipeline 2412 reports `result: succeeded`. Do NOT proceed to Step 7 (kubectl/curl) before stage 6 (DeployFBEInArgoCD) has had ~3-5 min to sync."* |
| `:170-205` Step 5/6 | Define `BRANCH=...` at top (set in Step 0); both Option A and Option B reference the same variable; remove `feature/fbe-XXXX-YYYY` placeholder noise |
| `:241-251` Rollback | Rewrite: make explicit that pipeline 2629 destroys Duncan's ENTIRE in-flight FBE (not just the orphan); recommend Fabrizio escalation FIRST; do not auto-trigger destroy from a fix-doc step |
| `:158` Step 5 decision rule | Add: *"Pipeline shows stage 7 (Pester) failure but stages 1-6 green: NOT a fix failure — Pester has a known latent `$token` bug (see fbe-creation-lifecycle-deep-dive#Pester latent bug). Verify against Step 7's `curl` instead."* |
| `:223` commented `az aks get-credentials` | Explain inline: *"Uncomment if your kubectl context is not already pointed at vpp-aks01-d (check via `kubectl config current-context`)."* |
| `:142` grep "not found" check | Replace with explicit exit-code check: `az eventhubs namespace show ... 2>&1; [ $? -ne 0 ] && echo "OK: gone" \|\| echo "STILL PRESENT"` |

### Changes to `evidence-ledger.md`

| Where | Change |
|---|---|
| `:49` P-LEASE-TABLE | Note that `probe-10-lease-kidu.json` contains the RBAC-403 error text, not a JSON object; either rename to `.txt` or wrap the error in a JSON envelope for parseability |
| `:37` C16 INFER block | Tighten: the inferred mechanism is "destroy-then-state-rm OR out-of-band create OR version-drift skip"; current text reads as if "destroy then state-rm" is the singular mechanism |

---

## Meta-falsifier (Rule 11)

**What would prove this review wrong?**

1. If, after Step 0 is added, `az pipelines runs show --id 1638601` returns a `sourceBranch` that resolves Duncan's branch — proving the C13 blocker was always one cheap probe away — then **HP-1** is even stronger than I claim (the fix should have had Step 0 from the start). My finding stands or strengthens.

2. If a hashicorp/terraform-provider-azurerm source trace **disagrees** with the RCA's mechanism description at `output/rca.md:268`, **MP-1** sharpens. If it agrees verbatim, **MP-1** softens to "the prose could cite the source code".

3. If the on-call who executes the fix reports **no friction** from the BRANCH-variable ambiguity in Steps 5/6, my **strongest objection** is over-stated. Likelihood: low; the doc is explicitly written for a cold-context reader who would not know Duncan's branch by heart.

4. If the F2 catalog is **amended** in a Phase-9 follow-up to formally accept the Azure-resource sub-class with the apply-time symptom routed in the symptom matrix, **HP-1** is retired by the structural fix the RCA already proposes.

**What domain knowledge might invalidate my critique?**

- If there is an Eneco-internal convention I'm unaware of where on-call engineers always know all in-flight branches by team intuition, the BRANCH-ambiguity objection weakens.
- If the destroy pipeline 2629 has additional safety gates (e.g., owner re-validation despite `bypassEnvironmentOwnerValidation=true`, or pre-destroy state inspection) that I haven't probed, the **HP-3 rollback** objection weakens.

**Where might I be pattern-matching from training rather than reasoning?**

- My instinct that "Authorization gate prose ≠ AskUserQuestion tool call" is a brain-doctrine claim, not a domain-empirical one. If real-world AI executors of this fix do honor prose-level halt instructions, **MP-6** is theoretical. The doctrine is more restrictive than empirical observation may justify.

---

## Final verdict

**PROCEED-WITH-CHANGES.**

- **Diagnosis**: materially correct. The in-session probes (probe-01 namespace, probe-02 state-blob list, probe-04 state-summary 261 resources, probe-10 lease-blocked) substantiate every load-bearing claim. The orphan is real, empty, and not state-managed. The alternative provenance hypotheses (HP-2) do not change the fix path.
- **Fix safety**: the destructive Step 3 is properly gated by the empirical emptiness check in Step 2. Delete-then-recreate is a defensible choice over `terraform import` for an empty 11-month-stale orphan.
- **Required pre-execution changes**: address the **strongest objection** (Step 0 + BRANCH variable) and **HP-3 rollback rewrite** before a fresh next-shift on-call executes the fix cold. The other HP/MP findings improve epistemic honesty but do not block execution.
- **Catalog/runbook patches** (HP-1) are correctly scoped as Phase-9 follow-ups by the RCA itself; my critique adds that the catalog text needs amendment, not just the runbook's symptom table.

The RCA's authoring discipline — A1/A2/A3 labeling, evidence ledger with re-probes, explicit "What I CANNOT verify in this session" — is genuinely good and resisted most of my falsification attempts. The defects I found are at the **edges**: classification stretch, reader-trap script defects, AI-executor gate, and rollback blast-radius — not in the core diagnostic reasoning.
