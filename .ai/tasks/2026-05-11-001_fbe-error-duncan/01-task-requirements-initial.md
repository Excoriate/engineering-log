---
task_id: 2026-05-11-001
agent: claude-opus-4-7
status: draft
summary: Initial task requirements for FBE creation failure RCA (Duncan, 2026-05-11)
---

# Task Requirements — Initial

## Reader (Endgame)

**Named reader**: A next-shift on-call engineer (and Duncan himself, who is blocked right now) who has zero context on this incident. After reading the RCA, they MUST be able to:

1. **Replicate** the diagnosis end-to-end with commands they can paste.
2. **Explain** what an FBE is, how Terraform fits, where state lives, why the error fires.
3. **Defend** the conclusions when challenged — every load-bearing claim cites externally-witnessable evidence.
4. **Execute the fix** without breaking shared Sandbox infrastructure.

## Request (verbatim)

> for this incoming request, in #myriad platform. Check here, there are the initial atencedents you have to check: /Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/log/employer/eneco/02_on_call_shift/2026_05_11_fbe_error_duncan
>
> The RCA must indicate clearly, how to fix it. This is blocking that person.
>
> Use also /eneco-context-docs , and /eneco-context-repos  - also /eneco-tools-connect-mc-environments if needed. - all claims verified, no space for mistaks. You have access, adn skils for everything.

## Antecedent inventory (Phase 0 — input claim list)

### Inputs present

| Path | Content |
|---|---|
| `log/employer/eneco/02_on_call_shift/2026_05_11_fbe_error_duncan/slack-intake.txt` | Slack Lists URL + Duncan's two failing build URLs + retry-failed-faster signal |
| `log/employer/eneco/02_on_call_shift/2026_05_11_fbe_error_duncan/context.md` | Pre-extracted Terraform error block + build log excerpt + intake doctrine |

### Discrete load-bearing claims to verify in Phase 2 (freshness audit)

| C# | Claim from antecedents (INFER until re-probed) | Source line |
|---|---|---|
| C1 | Duncan tried to create an FBE this morning | slack-intake.txt:3 |
| C2 | The failure is on `terraform apply` step | context.md:25, "Terraform command 'apply' failed" |
| C3 | The error mode is "resource already exists, not in state" | context.md:27 |
| C4 | The specific orphan Azure resource is `azurerm_eventhub_namespace` with name `vpp-evh-premium-kidu` | context.md:27 |
| C5 | The resource group is `rg-vpp-app-sb-401` | context.md:27 |
| C6 | The subscription is `7b1ba02e-bac6-4c45-83a0-7f0d3104922e` (Sandbox per CLAUDE.md memory) | context.md:27 + auto-memory |
| C7 | The Terraform module path is `.terraform/modules/eventhub_namespace_premium/terraform/modules/event_hub_namespace/main.tf` | context.md:30 |
| C8 | The Terraform variable `environment=kidu` is passed at apply | context.md:50 |
| C9 | Terraform version is 1.14.3 | context.md:37 |
| C10 | Provider versions: azurerm 4.40.0, azuread 3.8.0, kubernetes 2.37.1, random 3.8.1, time 0.10.0, tls 4.0.4, mssql 0.3.1 | context.md:39-45 |
| C11 | The retry "failed even quicker" → non-transient | slack-intake.txt:12 + context.md:5 |
| C12 | The pipeline lives in ADO project `Myriad - VPP`, build IDs 1638601 (first) + 1638601 with different stage segment (second) — note: second URL was *truncated* in slack intake, must reconfirm | slack-intake.txt:3,17 |
| C13 | The branch/feature name producing env=kidu is unknown — must derive from pipeline parameters | absent |
| C14 | What is "FBE" mechanically: who creates it, which repo, which pipeline definition, what gets provisioned, where state lives — UNKNOWN, must reconstruct via eneco-context-repos + eneco-context-docs | absent |
| C15 | The state backend (where Terraform stores state for FBE pipelines) — UNKNOWN | absent |
| C16 | Whether `vpp-evh-premium-kidu` was created by a prior pipeline run for the same env=kidu, or by a different mechanism — UNKNOWN | absent |

### Context dimensions still missing (must resolve before L1)

- What does the Myriad VPP platform do (business role)
- What is an FBE mechanically (repo, pipeline, env binding, lifecycle)
- Service architecture (which app components live behind the failing Terraform module)
- Tech stack confirmed: Terraform, Azure DevOps, AzureRM provider; need to know if AKS/ArgoCD layer is downstream
- Deployment architecture (FBE feature-branch → Sandbox subscription binding)
- Pipeline topology (how the FBE pipeline triggers, where state is, what stages run)
- Local platform mechanism: how "FBE" automation maps branch → env name → resource set

## Success Criteria

| # | Criterion | Externally witnessable |
|---|---|---|
| SC1 | RCA document at `output/rca.md` follows the 12-level holistic ladder (L1-L12 per Phase 1 selection) | `test -s output/rca.md`; section-headers grep |
| SC2 | Every load-bearing FACT cites file:line or replayable command output | grep for unsourced "FACT" or A1 labels |
| SC3 | Fix recommendation includes exact commands AND expected output AND decision rule AND rollback | grep `## Fix` section + L8 |
| SC4 | All inherited claims C1-C16 re-probed in Phase 2 (Freshness Audit) | `proofs/outputs/` directory populated |
| SC5 | Adversarial dispatch (socrates-contrarian + el-demoledor) completed and findings absorbed | `auxiliary/adversarial-review-*.md` exists, manifest.gate_witnesses populated |
| SC6 | A zero-context reader can replicate the diagnosis cold by following L11 | Reproducibility self-test |
| SC7 | Fix command is safe — does not destroy shared Sandbox infrastructure | Destructive-action lexicon check + risk note in L8 |
| SC8 | Duncan unblocked: he can execute the fix from the RCA and complete the FBE Terraform apply | Functional outcome — verifiable post-fix by Duncan re-running pipeline |

## Hypotheses

| H | Statement | Elimination probe |
|---|---|---|
| H1 | Orphan resource: previous FBE creation/destruction for env=kidu (or env name collision) created the namespace, then state was lost or workspace was different | `az eventhubs namespace show -n vpp-evh-premium-kidu -g rg-vpp-app-sb-401`; check createdAt + tags; check state file for prior records |
| H2 | The Event Hub namespace name `vpp-evh-premium-kidu` is colliding because `kidu` is being injected as env *and* another pipeline (sandbox/main) provisions the same name | inspect IaC for the namespace naming pattern; check if `kidu` is the random suffix or the explicit env var |
| H3 | State backend (azurerm backend or remote state) lost track of the resource due to backend config change | inspect backend config in pipeline + state file diff |
| H4 | A prior FBE for env=kidu was destroyed via `terraform destroy` but `azurerm_eventhub_namespace` failed to delete (Premium SKU is slow + sometimes leaves orphan) — second run blocked | Azure portal/CLI: check namespace `provisioningState`, `createdAt`, `tags.terraform`, `tags.environment`; check pipeline history for prior runs with env=kidu |
| H5 | The variable `environment=kidu` was reused by Duncan after a prior FBE was torn down without state cleanup | check Slack/ADO history for prior `env=kidu` runs |

## Verification Strategy (placeholder — finalized in Phase 3)

- Re-probe each C1-C16 via the freshness probes in Phase 2.
- Use eneco-context-repos to locate the FBE pipeline definition + Terraform module source.
- Use eneco-context-docs to find FBE runbooks/ADRs that explain env naming, state location, and the documented recovery procedure for orphan resources.
- Use eneco-tools-connect-mc-environments + Sandbox subscription to live-probe the resource state.
- Reconstruct the timeline of `kidu` env name in Sandbox: who/when created, what destroyed (if anything), why state is empty.
