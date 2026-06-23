---
task_id: 2026-06-22-008
agent: socrates-contrarian
timestamp: 2026-06-22T00:00:00Z
status: complete

summary: |
  Six attack lanes executed against the FBE thor RCA and quick-fix. Three findings require
  changes before this document can be marked complete: (1) the quick-fix uses wrong ADO
  expression syntax for the stage condition referencing the appconfig output variable —
  the real pipeline uses stageDependencies not dependencies.*; (2) the "44 secrets" claim
  in the RCA is wrong by count (actual 49 in locals.tf); (3) E3 claim classification is
  correctly A2 but the RCA narrative body states the cert was "manually added" as if it
  were A1 FACT in multiple places without flagging the inference. All other lanes are
  SOUND with minor notes. Overall verdict: PROCEED-WITH-CHANGES.
---

# Adversarial Review — FBE thor RCA (socrates-contrarian)

## Key Findings

- **Lane 4 — Fix soundness (WRONG):** quick-fix `dependencies.*.outputs` syntax is wrong for this pipeline — must use `stageDependencies` pattern consistent with `:168-171`
- **Lane 1 — Claim classification (WEAK):** "44 secrets" stated as fact; actual count is 49 (`locals.tf:64-118`)
- **Lane 2 — Assumption E3 (WEAK):** E3 correctly classified A2 in the ledger, but RCA prose asserts "manually added" as plain fact in 4 places without surfacing the inference
- **Lane 5 — Coherence (WEAK):** quick-fix guard condition references wrong ADO expression namespace; inconsistent with existing pipeline pattern at `:168-171`
- **Lane 3 — Reader gap (WEAK):** `featurebranchdeployment` storage account name not in Context Ledger; referenced in quick-fix break-glass without prior definition in rca.md

---

Reviewed artifacts:

- `rca.md` (2026-06-22, status: review)
- `quick-fix.md` (companion)
- `context/evidence-ledger.md`
- `azure-pipeline-fbe-del.yml` (pipeline source of truth)
- `terraform/fbe/key-vault.tf`, `data.tf`, `locals.tf` (IaC source of truth)

Methodology: read all source files first, derive findings from file:line evidence, never from memory. Every finding names the specific change it forces.

---

## Lane 1 — Claim Classification

**Verdict: WEAK (one factual error; E3 correctly classified but leaks into prose)**

### Finding 1-A: "44 secrets" is wrong — actual count is 49

**Claim in question:**

> "copies a fixed list of secrets from the shared `vpp-aks-d` into the per-FBE Key Vault" ... "44 secrets" (rca.md:L4 prose, L3 diagram tooltip, quick-fix.md:25, evidence-ledger.md mechanism section)

**Evidence:**

`locals.tf:64-118` contains the `secrets_to_copy` list. Counting non-comment string entries:

```
lines 65-112: 48 quoted strings (no comments)
line 117: "vpp-eneco-com"  ← 49th entry (below the comment block at :114-116)
```

Total: **49 secrets**, not 44. The comment at `:114-117` is about `vpp-eneco-com` being stored as a secret due to Terraform limitations; it does not reduce the list size.

The claim "44 secrets" appears stated as A1 FACT in:
- `rca.md` L4 (data flow section, `data.tf:42-51` cited)
- `quick-fix.md:25` ("the FBE module reads 44 secrets from the shared KV")
- `evidence-ledger.md` (mechanism F1 section, "data.tf:42-51")

**Belief basis of this finding:** REPO-GROUNDED — verified by listing `secrets_to_copy` entries in `locals.tf:64-118`.

**Impact if not corrected:** Minor credibility hit for a next-shift reader who counts the list. More importantly, the data.tf citation `42-51` covers the `azurerm_key_vault_secret.sandbox_kv_secrets` data source, which is correct, but the prose count is wrong. The fix citation is sound; the number is not.

**Forced change:** Update "44 secrets" to "49 secrets" in rca.md (L4 and L3 diagram note), quick-fix.md:25, and evidence-ledger.md mechanism F1. Update evidence label on the count claim to A2 INFER (derived from list enumeration) or leave as A1 FACT with cite `locals.tf:64-118` explicitly.

---

### Finding 1-B: E3 classification is correctly A2, but the inference leaks into narrative prose as asserted fact

**E3 in evidence ledger:**

> `A2 INFER (from owner statement + the 403 semantics; \`managed\` flag)` — correctly classified.

**But in rca.md prose (multiple locations):**

- Executive summary line 24: "Someone had **manually added a certificate** of that exact name into the FBE's Key Vault."
- L4 Mechanism 1: "someone **manually imported a certificate** of the same name"
- L10 Lessons: "if you must, delete the **certificate** (not the secret) to clean up" (implies the manual-add is established fact for future playbook)
- L12 playbook: "a manual **certificate** captured a Terraform-managed secret"

None of these prose locations mark the inference. A reader of the main body — not the evidence ledger — receives "manually added" as an unqualified assertion.

**Evidence basis of this finding:** REPO-GROUNDED (rca.md lines ~24, ~130, ~224, ~272 vs evidence-ledger.md E3).

**Steelman:** The RCA correctly argues that the fix does NOT depend on E3 being true (E4 proves the cert is gone regardless of how it got there, and the mechanism holds whether the cert was manual or pipeline-added). So E3's uncertainty does not change the remediation. That reasoning appears in the evidence ledger confidence note. It does not appear in the prose.

**Why this matters anyway:** The L10 lesson "Never hand-add a certificate whose name collides with a Terraform-managed secret" and the L12 playbook both depend on E3 being true. If the certificate was added by an automated process (a CI job, a Helm chart, a runbook) — not by a human — the prevention lesson is wrong. A2 inference used as A1 fact in a playbook = future on-call engineer follows the wrong prevention advice.

**Forced change:** In rca.md, at first use of "manually added" (executive summary ~line 24), add a parenthetical: "(inferred — not directly observed; consistent with the 403 semantics and owner statement, but an automated process is not ruled out)." In L10 and L12, reframe the lesson as "if a certificate of the same name as a Terraform-managed secret exists in the KV — however it got there — you must delete the certificate first." This makes the lesson correct regardless of E3's truth value.

---

### Finding 1-C: E7 — "slot still assigned because run 1 never reached Release environment" is A1 FACT but the cited mechanism has a subtlety

**Claim:** E7 is labeled A1 FACT, cited as `azure-pipeline-fbe-del.yml:319-358` and "run 1 stopped at DestroyInfra."

**Reading the pipeline:** The "Release environment" step at `:319-358` has `condition: succeeded()` (`:321`). This means it only runs if the preceding step in the DestroyInfra job succeeds. Since the job-level `condition: succeeded()` (`:193`) already gates the whole job on the preceding stage, the explanation in the RCA is accurate. The slot is still `used` because the DestroyInfra job failed before reaching step `:319`.

**Verdict:** SOUND. No change required. Citing the exact step lines is correct.

---

## Lane 2 — Assumption Hunt

**Verdict: WEAK (one load-bearing assumption not surfaced; fix is sound under primary hypothesis but a second hypothesis is not eliminated)**

### Finding 2-A: The "empty name = destroyed store" causal link is asserted, not proven

**Claim (rca.md L4 Mechanism 2, E6 in evidence ledger):**

> "After run 1 destroyed the App Configuration store, this query returns **empty**."

The causal chain asserted: run 1 → DestroyAppConfiguration stage succeeded → store destroyed → `az appconfig list` returns empty → empty name → CLI error.

**Evidence basis:** The evidence ledger labels E6 as A1 FACT, citing `azure-pipeline-fbe-del.yml:99/103` and "live: no `thor` AppConfig store."

**The hidden alternative hypothesis:** The `az appconfig list --resource-group ... --query "[?contains(name,'thor')]"` could return empty for a reason *other than* the store being destroyed:

1. The store exists but is in a different resource group (e.g., created in a different RG than `rg-vpp-app-sb-401`).
2. The store exists but the name does not contain the literal string `thor` (e.g., uses a different naming convention for this slot).
3. The pipeline SP lacks list permissions on AppConfig in this subscription (auth gap returns empty rather than error).

**Is this hypothesis eliminated?** Partially. The evidence ledger notes "live: no `thor` AppConfig store" as A1 FACT, meaning a live `az appconfig list` probe found no store. This covers hypothesis 1 and 2 (a live probe with the same subscription/RG scope would find it if it existed anywhere in the RG). It does not cover hypothesis 3 (auth gap would silently return empty from both the original pipeline call and the live probe if the probe is run with the same SP).

**However:** The live probe note says it was run on 2026-06-22, days after run 1 on 2026-06-18. Even if the store was found now, it would not prove it was present at run 2. Conversely, the live absence is consistent with run 1 having destroyed it.

**Verdict:** The A1 label on E6 is defensible if the live probe was run with sufficient subscription/RG scope. The assumption that the store is gone because run 1 destroyed it (rather than it never existing, or the name pattern being wrong at that time) is an A2 INFER not surfaced as such. The fix is correct regardless — if the store is gone (for any reason), the guard makes the stage a no-op success.

**Forced change:** E6 in the evidence ledger should be split: (a) "No `thor` AppConfig store exists today" — A1 FACT (live probe); (b) "The store was destroyed in run 1's DestroyAppConfiguration stage" — A2 INFER (derived from timeline: run 1's stage 3 completed before run 1's failure, and the store is absent on 2026-06-22). The RCA prose conflates these. The fix does not change; the evidence classification does.

---

### Finding 2-B: Is "DestroyInfra's Release environment is the ONLY slot-release path" verified?

**Claim (rca.md L8, quick-fix.md):**

> "Only `DestroyInfra` does both [finish teardown AND release the slot], so the fix must let a re-run reach `DestroyInfra`."

**Load-bearing assumption:** There is no other code path that can write `active=unused` to the `featurebranchenvdetails` table.

**Evidence check:** The pipeline has 5 stages. Reading the full YAML (lines 63-404):

- `Preparation` (:63-105): reads the table, does not write `active` state.
- `KubernetesCleanup` (:107-161): no table write.
- `DestroyAppConfiguration` (:163-185): calls shared template; template is not read in this session but its scope is AppConfig, not Storage Table.
- `DestroyInfra` (:187-358): contains the only `az storage entity replace ... active='unused'` call at `:354`.
- `Slacknotify` (:360-404): only a Slack webhook call.

**Verdict:** SOUND for the pipeline. However, the break-glass Option B in quick-fix.md also writes `active=unused` directly via `az storage entity merge` — which is a correct alternative path explicitly documented. The RCA L8 claim is about the *automated pipeline* path; the manual break-glass path is a valid out-of-band alternative. The claim is accurate in context.

---

### Finding 2-C: "DestroyInfra only" cascade-skip — is E8 correctly A2 INFER?

**Claim (rca.md L8, E8 in evidence ledger):**

> `DestroyInfra` has no explicit `dependsOn`; its implicit predecessor `DestroyAppConfiguration` would be Skipped; `condition: succeeded()` treats Skipped as failure → cascade-skip.

**Evidence:** `azure-pipeline-fbe-del.yml:187-193`:

```yaml
- stage: DestroyInfra
  displayName: DestroyInfra
  jobs:
    - job: DestroyInfra
      displayName: DestroyInfra
      timeoutInMinutes: 120
      condition: succeeded()
```

**CRITICAL FINDING:** The `condition: succeeded()` at `:193` is on the **job**, not the **stage**. There is no `condition:` on the **stage** itself, and no `dependsOn:` on the stage. Per ADO behavior: when a stage has no `dependsOn`, it implicitly depends on the immediately preceding stage in declaration order — here, `DestroyAppConfiguration`. When the preceding stage is *Skipped* (via stage-selection), ADO evaluates the stage-level implicit condition (which defaults to `succeeded()` at the stage level) and skips `DestroyInfra` as well. The job-level `condition: succeeded()` is in addition to this, not a substitute for it.

The RCA and E8 attribute the cascade-skip to the job-level `condition: succeeded()`. The actual mechanism is the implicit stage-level dependency + ADO's default stage condition (`succeeded()`). The job condition is irrelevant to the stage-selection scenario — the stage never gets far enough to evaluate the job condition.

**Impact:** The explanation in the RCA is functionally correct (cascade-skip happens, run-DestroyInfra-only is a no-op) but the mechanism cited is at the wrong level. This matters because the *fix* in quick-fix.md adds a condition at the **stage level** with explicit `dependsOn: [...]` — which is the right level. The mismatch between the RCA's "job condition" explanation and the fix's "stage condition" intervention could confuse a reader verifying the fix logic.

**Forced change:** In rca.md L8 and L6, clarify: the cascade-skip occurs because `DestroyInfra` has no explicit `dependsOn` and no stage-level `condition`, so ADO's default `succeeded()` stage condition triggers when `DestroyAppConfiguration` is Skipped. The job-level `condition: succeeded()` at `:193` is a job guard, not the stage guard. E8 should be updated to: "A2 INFER — ADO stage-level implicit dependency + default `succeeded()` stage condition; the job-level `condition: succeeded()` at `:193` is a redundant guard, not the cascade trigger."

---

## Lane 3 — Reader Gap

**Verdict: WEAK (two terms appear before formal introduction; one command assumption unexplained)**

### Finding 3-A: `featurebranchdeployment` storage account appears in rca.md L9 without definition

**Location:** `rca.md` L9 verification command (line ~264):

```bash
# (slot assignment lives in the featurebranchenvdetails storage table — needs Storage Table Data Reader)
```

And implicitly in L6 table description (the table name `featurebranchenvdetails` appears in the Context Ledger row for that term, but `featurebranchdeployment` — the *account name* — does not).

The quick-fix.md break-glass (Option B, step 3) uses `az storage entity query --account-name featurebranchdeployment` without prior definition of the account name in rca.md.

**Gap:** A next-shift on-call engineer reading rca.md sees `featurebranchenvdetails` explained in the Context Ledger but cannot determine from rca.md alone what storage *account* the table lives in. They must open quick-fix.md to find `featurebranchdeployment`. The Context Ledger entry for `featurebranchenvdetails` says "Where it lives: pipeline `:75-94`, `:319-358`" but the storage account name is not surfaced.

**Forced change:** Add `featurebranchdeployment` to the Context Ledger row for `featurebranchenvdetails` (e.g., "Azure Storage table in account `featurebranchdeployment`"). The rca.md L9 verification comment should also include the account name inline.

---

### Finding 3-B: "vuo" suffix unexplained at first use

**Location:** Context Ledger, `vpp-fbe-thor-vuo` row: "(`vuo` = random suffix)."

**Issue:** The explanation is present, which is good. However, the term appears in the L3 diagram (`vpp-fbe-thor-vuo<br/>(per-FBE Key Vault)`) before a reader reaches the Context Ledger row. In markdown, the Context Ledger is above L3, so this is read-order fine. No forced change, but noted: if the Context Ledger is ever moved or the document is read non-linearly, this becomes a gap.

**Verdict:** SOUND as currently structured. No change required.

---

### Finding 3-C: L8 references "the tempting shortcut" before naming what it is

**Location:** rca.md L8 first paragraph:

> "The tempting shortcut that does NOT work: 're-run with Stages to run → DestroyInfra only.'"

This is self-contained and immediately explained. No gap.

---

## Lane 4 — Fix Soundness

**Verdict: WRONG (critical syntax error in the quick-fix stage condition)**

### Finding 4-A: The quick-fix condition uses the wrong ADO expression for referencing the output variable

**Quick-fix.md proposed condition (lines 41-44):**

```yaml
- stage: DestroyAppConfiguration
  dependsOn: [Preparation, KubernetesCleanup]
  condition: >-
    and(succeeded(),
        ne(dependencies.Preparation.outputs['Environment.DetermineEnvironment.appconfig'], ''))
```

**What the actual pipeline uses** (azure-pipeline-fbe-del.yml:168-171):

```yaml
variables:
  appconfig: $[ stageDependencies.Preparation.Environment.outputs['DetermineEnvironment.appconfig'] ]
```

**The problem:** ADO uses two different expression namespaces:

1. **`stageDependencies`** — used in `variables:` blocks at the stage level to pull output variables from upstream stages into stage-scoped pipeline variables.
2. **`dependencies`** — used in `condition:` expressions to check the *result/status* of a dependent stage (e.g., `dependencies.Preparation.result`).

The quick-fix conflates the two. `dependencies.Preparation.outputs[...]` is not the correct ADO syntax for reading a job output variable in a stage-level `condition:`. In ADO YAML, stage-level `condition:` expressions reference stage outcomes via `dependencies.<StageName>.result` — they do not have direct access to the job-level output variable value through `dependencies.<Stage>.outputs[...]`. That path is a job-level syntax, and even then the format differs.

**The correct ADO approach** for this guard is to NOT try to dereference the output variable value in the condition expression at the stage level. Instead, one of:

- (A) The Preparation stage explicitly fails (exits 1) when `appconfig` is empty — already the case for `environmentName` (lines 91-94) but NOT for `appconfig` (line 99-105 sets it to empty without exit 1). Preparation could be modified to treat empty `appconfig` as non-fatal by skipping that variable's requirement.
- (B) The guard is placed at the **job level** inside `DestroyAppConfiguration`, not at the stage level — jobs can reference `stageDependencies` in their `variables:` and then use the resolved variable in a task condition or a bash `if` check.
- (C) Accept the empty `appconfig` variable value in the stage variable (`:171`) and add a `condition:` to the job or template invocation using `$(appconfig)` which resolves at job runtime: `condition: ne(variables['appconfig'], '')`.

The quick-fix.md itself contains this note: "Verify the exact `dependencies.<stage>.outputs[...]` reference syntax in ADO before merging — the output var is set with `isOutput=true` at `azure-pipeline-fbe-del.yml:105`." This note acknowledges the uncertainty but leaves the wrong syntax as the proposed code. A PR opened with the as-written YAML will fail to guard correctly — the `condition` expression will either error or silently evaluate incorrectly.

**Evidence basis:** REPO-GROUNDED. The pipeline at `:168-171` uses `$[ stageDependencies.Preparation.Environment.outputs['DetermineEnvironment.appconfig'] ]` exclusively. No `dependencies.*.outputs[...]` pattern appears anywhere in the file. The proposed syntax is not used in this pipeline and is inconsistent with the existing pattern.

**Forced change:** Rewrite the quick-fix condition to use a syntax consistent with the pipeline's existing patterns. The safest implementation that matches the current pipeline idiom:

```yaml
- stage: DestroyAppConfiguration
  dependsOn:
    - Preparation
    - KubernetesCleanup
  variables:
    appconfig: $[ stageDependencies.Preparation.Environment.outputs['DetermineEnvironment.appconfig'] ]
  condition: succeeded()
  jobs:
    - job: GuardAppConfigDestroy
      condition: ne(variables['appconfig'], '')
      steps:
        - template: ./azure-appconfiguration/sandbox.template.yml@pipelines
          parameters:
            appConfigurationName: $(appconfig)
            ...
```

This moves the guard to the job level where `appconfig` is already resolved as a stage variable — consistent with how the existing `DestroyAppConfiguration` stage variables work at `:168-171`. Alternatively, a bash `if` check inside the template call's first step is the lowest-risk approach with the smallest diff.

---

### Finding 4-B: The `DestroyInfra` condition in quick-fix uses correct result-level syntax but must also add explicit `dependsOn`

**Quick-fix.md proposed DestroyInfra condition (lines 49-54):**

```yaml
- stage: DestroyInfra
  dependsOn: [Preparation, KubernetesCleanup, DestroyAppConfiguration]
  condition: >-
    and(eq(dependencies.Preparation.result, 'Succeeded'),
        in(dependencies.DestroyAppConfiguration.result, 'Succeeded', 'Skipped'))
```

**Evidence:** `azure-pipeline-fbe-del.yml:187` — current `DestroyInfra` has NO `dependsOn` and NO stage-level `condition`. The proposed fix adds both, which is the correct intervention level.

**ADO `in(...)` syntax check:** ADO YAML pipeline expressions do support `in(value, 'A', 'B')` syntax in condition expressions. The `dependencies.<Stage>.result` path is the correct way to check stage outcomes in a stage-level condition. This part of the proposed fix is syntactically correct per ADO documentation patterns.

**However:** The condition omits checking `KubernetesCleanup` result. If `KubernetesCleanup` fails, `DestroyInfra` would still run under the proposed condition (the condition only checks `Preparation` and `DestroyAppConfiguration`). Currently `KubernetesCleanup` has `continueOnError: true` on the Helm uninstall task (`:115`) and the git push step does not have `continueOnError`, so a failure there would mark the stage failed. The proposed `DestroyInfra` condition would then execute even when `KubernetesCleanup` failed, which may or may not be the intent.

**Verdict:** Partially SOUND (result-checking syntax is right; `in()` works in ADO; explicit `dependsOn` is the right fix level) but incomplete (no KubernetesCleanup result check). Not a blocking issue given `continueOnError` on the main failure-prone step, but should be documented as a deliberate choice.

**Forced change (minor):** Quick-fix.md should note explicitly that the proposed condition intentionally omits `KubernetesCleanup` from the result-check, and the rationale (e.g., "K8s cleanup has `continueOnError: true` so its failure is non-fatal to the teardown goal").

---

## Lane 5 — Coherence

**Verdict: WEAK (one cross-artifact inconsistency; derives from Finding 4-A)**

### Finding 5-A: The condition syntax inconsistency between quick-fix.md and the existing pipeline pattern

Already documented in Lane 4 Finding 4-A. The RCA (rca.md L8) describes the fix at the conceptual level ("skip cleanly when the resolved AppConfig name is empty; let `DestroyInfra` tolerate a Skipped AppConfig stage") — these descriptions are sound and consistent. The inconsistency is only in quick-fix.md's concrete YAML syntax, not in rca.md's explanation.

**No additional contradictions** found between rca.md, quick-fix.md, and the evidence ledger on:
- Build IDs (1683298, 1683370) — consistent across all three
- Failure locations (DestroyInfra stage 1, DestroyAppConfiguration stage 2) — consistent
- Certificate state (gone, not soft-deleted) — consistent
- Slot assignment mechanism (`featurebranchenvdetails` row via `Release environment` step) — consistent
- KV state (soft-delete on, retention 7d, purge protection off) — consistent

---

### Finding 5-B: Evidence ledger E2 line reference vs actual file

**E2 claim:** "`key-vault.tf:26-32`, `locals.tf:110`, `data.tf:42-51`"

**Verification:**
- `key-vault.tf:26-32`: `resource "azurerm_key_vault_secret" "copied_secrets"` with `for_each = data.azurerm_key_vault_secret.sandbox_kv_secrets` — CORRECT.
- `locals.tf:110`: `"activationmfrr-eneco-signing-certificate"` — CORRECT (it is line 110).
- `data.tf:42-51`: `data "azurerm_key_vault_secret" "sandbox_kv_secrets"` reading from `data.azurerm_key_vault.sandbox_kv.id` (vpp-aks-d) — CORRECT.

All line references verified. SOUND.

---

## Lane 6 — Human Comprehension (A1/A2 code leakage into prose)

**Verdict: SOUND**

### Finding 6-A: Evidence codes are confined to the Evidence Ledger table and not used in narrative prose

Reading rca.md:
- The "Evidence Ledger" section (bottom) uses A1/A2 labels in the table — correct usage.
- The narrative prose (L1 through L12, Executive Summary, Slack explanation) does not use A1/A2 codes inline. Terms like "verified live" and "not yet verified" appear, but these are plain English.
- The evidence ledger confidence note at the bottom uses "E3" to refer back to a table row — acceptable (ledger references a ledger entry, not leaking into narrative prose).

**Verdict:** SOUND. No bare evidence codes in narrative. The separation is clean.

---

### Finding 6-B: The Slack explanation section ("paste-ready") contains the manual-add assertion without qualification

**Location:** rca.md, Slack explanation section:

> "1. First run failed because a **certificate was manually added** into the FBE's Key Vault..."

This carries the E3 inference (Finding 1-B) into an external communication. If the inference is wrong, the Slack message misleads the team about the root cause.

**Forced change:** This is a minor variant of Finding 1-B. Same fix: soften "was manually added" to "had a certificate added (likely manually)" in the Slack paste, or omit the adverb entirely ("a certificate of the same name appeared in the KV").

---

## Meta-Falsifier (Rule 11)

What would prove this review wrong?

1. If ADO pipeline documentation shows `dependencies.<Stage>.outputs[<Job>.<TaskName>.<VarName>]` IS valid in a stage-level `condition:` expression — Finding 4-A is wrong. (TRAINING-DERIVED knowledge here; the note in quick-fix.md itself expresses this uncertainty, which is why this finding is grounded in the inconsistency with the existing pipeline's own pattern, not solely in doc knowledge.)
2. If the `secrets_to_copy` list has been modified since `locals.tf` was last read in this session — the count of 49 would need revision. (REPO-GROUNDED at read time; no modification occurred in this session.)
3. If the App Config store was NOT destroyed in run 1 (i.e., `DestroyAppConfiguration` completed but did not actually destroy the store) — E6 causal chain is wrong. The live probe (store absent on 2026-06-22) would still stand, but the timeline inference would weaken.

---

## VERDICT

**PROCEED-WITH-CHANGES**

Required changes before this RCA can be marked `status: complete`:

| # | Finding | Location | Change |
|---|---------|----------|--------|
| C1 | "44 secrets" wrong — actual 49 | rca.md L4, L3 diagram; quick-fix.md:25; evidence-ledger.md mechanism F1 | Replace "44" with "49"; cite `locals.tf:64-118` explicitly |
| C2 | "manually added" stated as A1 fact in prose | rca.md Executive Summary, L4, L10, L12, Slack section | Add inference qualifier at first use; reframe L10/L12 lesson to be cert-name-collision focused, not manual-add focused |
| C3 | E6 A1 label covers two distinct claims | evidence-ledger.md E6 | Split into (a) live-probe absence (A1) and (b) destroyed-in-run-1 (A2 INFER) |
| C4 | quick-fix condition syntax uses wrong ADO expression namespace | quick-fix.md:41-44 | Replace `dependencies.Preparation.outputs[...]` guard with job-level `condition: ne(variables['appconfig'], '')` or equivalent, consistent with `:168-171` pattern |
| C5 | Cascade-skip mechanism cited at wrong level | rca.md L8, E8 | Clarify: stage-level implicit dependency + default stage `succeeded()` triggers skip; job-level `condition` at `:193` is a job guard, not the stage-select trigger |
| C6 | `featurebranchdeployment` account name not in Context Ledger | rca.md Context Ledger | Add storage account name to `featurebranchenvdetails` row |
| C7 | Slack paste carries unqualified "manually added" | rca.md Slack section | Soften to "a certificate of the same name appeared in the KV" |

Non-blocking observations (no forced change):

- KubernetesCleanup result not checked in proposed DestroyInfra condition — document as deliberate choice.
- `vuo` suffix explained in Context Ledger — SOUND as-is.
- Evidence codes (A1/A2) correctly confined to evidence ledger table — SOUND.
- All build IDs, line references (E2), KV state claims, and slot-release mechanism citations verified correct.
