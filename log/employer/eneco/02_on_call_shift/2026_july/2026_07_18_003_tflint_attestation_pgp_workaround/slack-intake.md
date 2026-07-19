# TFLint attestation panic — `signature = "pgp"` workaround — Slack intake

## Derivation header

| Field | Value |
|-------|-------|
| `template_id` | `slack-intake.template.md` |
| `template_version` | `2.0.0` |
| `template_path` | `std/skills/10_employer/eneco/eneco-oncall-intake-slack/assets/slack-intake.template.md` |
| `instance_id` | `2026_07_18_003_tflint_attestation_pgp_workaround` |
| `filed_date` | `2026-07-17` |
| `picked_up_date` | `2026-07-18` |
| `produced_by` | `eneco-oncall-intake-slack` |
| `consumed_by` | `eneco-sre` — assembles `sre-intake.md` beside this file |

**Note:** No Slack Lists `record_id` was provided — intake sourced from **`#team-platform` OoTW handover** + ADO build logs + committed `.tflint.hcl` fix.

## Instance manifest

| Key | Value | Provenance |
|-----|-------|------------|
| `INCIDENT_TITLE` | TFLint pipeline crash — GitHub attestation API / `signature = "pgp"` workaround | — |
| `INSTANCE_ID` | `2026_07_18_003_tflint_attestation_pgp_workaround` | — |
| `ORIGIN` | Slack (`#team-platform` handover) + ADO pipeline failure | Known |
| `ORIGIN_URL` | Unknown[blocked] — no Lists URL; probe: link Help Request if one was filed | Unknown |
| `RECORD_ID` | Unknown[blocked] — not supplied | Unknown |
| `SLACK_CHANNEL` | `#team-platform` | Known — user brief |
| `DISCUSSION_THREAD` | OoTW handover thread (partial harvest via brief) — full ts/reply count Unknown | Known — partial |
| `FILER` | Platform team member (OoTW handover quote; author not named in brief) | Unknown[blocked] — probe: `slack_search` OoTW + `tflint --init` in `#team-platform` |
| `SURFACE` (proposed) | ADO CI pre-commit `terraform_tflint` → `tflint --init` plugin install/verify | proposed — `eneco-sre` confirms |
| `ENVIRONMENTS` | ADO hosted agents (Myriad - VPP pipelines); local dev pre-commit | Known |
| `ADO_ORG` / `ADO_PROJECT` | `enecomanagedcloud` / `Myriad - VPP` | Known |
| `ADO_PIPELINE` | `Platform - RBAC` | Known — user brief |
| `ADO_RUN` | `2026.7.17-merge-1000` | Known — user brief |
| `ADO_BUILD_ID` | `1721100` | Known — ADO URL |
| `ADO_BUILD_URL` | https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_build/results?buildId=1721100&view=logs&j=2bc86c81-ca50-5f9b-7c9d-e192176fc8d6&t=775c8301-7cd3-5e67-a434-8d6b711598f8&s=9ff32adf-b7c0-541f-32d8-0d6c4a5150b3 | Known |
| `REPO_MITIGATION` | `Eneco.Vpp.Core.Dispatching.Infrastructure` | Known |
| `TFLINT_CONFIG_URL` | https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/Eneco.Vpp.Core.Dispatching.Infrastructure?path=/.tflint.hcl&version=GC77552752bd78cc34c4163f58983ea48fa60eee37 | Known |
| `TFLINT_VERSION` | `v0.63.1` | Known — brief (Fabrizio/Adnan Slack exchange) |
| `RULESET` | `tflint-ruleset-azurerm` `0.28.0` | Known — `.tflint.hcl` + brief |
| `PRE_COMMIT_HOOK` | `Terraform validate with tflint` (`terraform_tflint`) | Known — build log |
| `FAILURE_RATE` | 5 / 36 runs failed same `tflint --init` error (last 14 days, Task Insights) | Known — brief |
| `UPSTREAM_ISSUE` | [terraform-linters/tflint#2591](https://github.com/terraform-linters/tflint/issues/2591) | Known |
| `UPSTREAM_FIX` | [PR #2600](https://github.com/terraform-linters/tflint/pull/2600) merged 2026-07-17 (follow-up to [#2593](https://github.com/terraform-linters/tflint/pull/2593)) | Known |

## Input

### Problem explanation

Terraform pipelines that run **TFLint via pre-commit** intermittently fail **before any linting** at **`tflint --init`**, while installing the **`azurerm` ruleset plugin**. TFLint **panics** (Go nil pointer) inside **sigstore attestation verification** — not because of Terraform or Azure rule violations.

**Root cause (upstream, Known):** GitHub changed artifact attestation list responses so `bundle` is **`null`** and the real bundle must be fetched from **`bundle_url`**. TFLint ≤ affected releases unmarshals `null` into a nil bundle and crashes in `bundle.TlogEntries` during `VerifyAttestations` — see [tflint#2591](https://github.com/terraform-linters/tflint/issues/2591) and merged fix [PR #2600](https://github.com/terraform-linters/tflint/pull/2600) (2026-07-17).

**Workaround (Known — working in at least one repo):** add **`signature = "pgp"`** on the `azurerm` plugin block in `.tflint.hcl`. That forces **legacy PGP verification** instead of sigstore attestations, bypassing the broken code path while still verifying the plugin cryptographically. **Linting is not disabled** — only the verification method changes.

**Ask for Platform:** document the workaround, roll it to **all affected Terraform repos**, track **TFLint release** containing #2600, then **remove** `signature = "pgp"` after upgrade.

```text
pre-commit (terraform_tflint)
    └── tflint --init
            └── download azurerm ruleset plugin
                    ├── [default] sigstore attestation verify
                    │         └── GitHub returns bundle=null → nil deref → PANIC → job FAIL
                    └── [workaround] signature = "pgp"
                              └── PGP verify → OK → tflint lint runs
```

### Original request (verbatim harvest)

**`#team-platform` OoTW handover (Known — user brief; speaker unnamed):**

```text
One last thing to note is that we are seeing this error with tflint happening more often than not.
This is the proposed solution that got the pipeline to work again (adding signature value in the plugin).
```

**Failing ADO log excerpt (Known — build `1721100`, Platform - RBAC):**

```text
Terraform validate with tflint...........................................Failed
Hook: Terraform validate with tflint (pre-commit terraform_tflint)
Command 'tflint --init' failed:

Installing "azurerm" plugin...

Panic: runtime error: invalid memory address or nil pointer dereference
 -> ... github.com/sigstore/sigstore-go/pkg/bundle.(*Bundle).TlogEntries
 -> ... github.com/terraform-linters/tflint/plugin.(*SignatureChecker).VerifyAttestations
 -> ... github.com/terraform-linters/tflint/plugin.(*InstallConfig).Install
 -> ... github.com/terraform-linters/tflint/cmd.(*CLI).init
 -> ... main.main

TFLint crashed... :(
Please ... post an issue to https://github.com/terraform-linters/tflint/issues
```

**Mitigation committed (Known — `.tflint.hcl` in `Eneco.Vpp.Core.Dispatching.Infrastructure`):**

```hcl
plugin "azurerm" {
  enabled   = true
  version   = "0.28.0"
  source    = "github.com/terraform-linters/tflint-ruleset-azurerm"
  signature = "pgp"
}
```

### Known state from evidence

| Observation | Meaning | Tag |
|-------------|---------|-----|
| Panic at plugin install, not at lint | External tooling bug blocks CI unrelated to TF changes | Known |
| ~5/36 failures in 14 days | Intermittent/flaky — “more often than not” but not 100% | Known |
| `signature = "pgp"` unblocks pipeline | PGP path avoids broken sigstore branch | Known |
| Upstream fix merged 2026-07-17 | Release pin + remove workaround is the exit criteria | Known |
| TFLint `v0.63.1` + ruleset `0.28.0` | Current versions in use per team Slack | Known |

## Recurrence / related requests

**Filer unresolved** → **team-wide tooling-incident pattern**, not filer-specific history.

| Date | Signal | Relation |
|------|--------|----------|
| 2026-07-17 | Build `1721100` panic | Canonical failure example |
| 2026-07-17 | [tflint#2600](https://github.com/terraform-linters/tflint/pull/2600) merged | Upstream fix landed; **release tag TBD** |
| Ongoing | Multiple VPP Terraform repos with `.tflint.hcl` + pre-commit | Rollout surface — inventory Unknown |

Downstream repos publicly used the same **`signature = "pgp"`** pattern while waiting for TFLint release (documented in community PRs referencing #2591).

## Mandatory context

### Environmental context

| Field | Value | Tag |
|-------|-------|-----|
| CI system | Azure DevOps — `Myriad - VPP` | Known |
| Hook | pre-commit `terraform_tflint` | Known |
| Tool chain | TFLint `v0.63.1`, `tflint-ruleset-azurerm` `0.28.0` | Known |
| Affected step | `tflint --init` (plugin download + verify) | Known |
| First repo with fix | `Eneco.Vpp.Core.Dispatching.Infrastructure` | Known |

**Repos to audit** — via `eneco-context-repos` + `rg`:

| Repo (git URL) | Role | Question it answers |
|----------------|------|---------------------|
| https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/Eneco.Vpp.Core.Dispatching.Infrastructure | Mitigation example | Canonical `.tflint.hcl` with `signature = "pgp"` |
| Other `Myriad - VPP` Terraform repos with `.tflint.hcl` | Rollout targets | Which repos still lack `signature = "pgp"` |

> Full repo inventory: `Unknown[blocked]` — probe `rg -l 'plugin \"azurerm\"' --glob '.tflint.hcl'` across ADO org or known repo list.

### Context to fetch — six sources

| # | Source | Skill (proven) | Why required | Status |
|---|--------|----------------|--------------|--------|
| ① | `#team-platform` / handover thread | `eneco-context-slack` | Author, full thread, other repos mentioned | ⬜ partial — brief only |
| ② | `#team-platform` | `eneco-context-slack` | Rollout decisions, ADO template ownership | ⬜ Unknown[blocked] |
| ③ | ADO repos + build `1721100` | `eneco-context-repos` + ADO UI | Confirm fix commit; list failing pipelines | ✅ partial — build URL + `.tflint.hcl` commit |
| ④ | Obsidian work-eneco | `2ndbrain-obsidian` | Prior tooling incident notes | ⬜ Unknown[blocked] |
| ⑤ | engineering-log | filesystem `rg` | Other tflint/pre-commit references | ✅ partial — sparse direct precedent |
| ⑥ | Upstream | GitHub [tflint#2591](https://github.com/terraform-linters/tflint/issues/2591), [PR #2600](https://github.com/terraform-linters/tflint/pull/2600) | Root cause + fix semantics | ✅ cited |

### Environments — connection routing

| Environment | How to connect | Note |
|-------------|----------------|------|
| ADO pipelines | ADO UI / re-run `Platform - RBAC` | No MC cluster access required |
| Local dev | Repo clone + `pre-commit run terraform_tflint` | Reproduce with/without `signature = "pgp"` |

### Skills to use

| Skill (proven) | Phase | Why |
|----------------|-------|-----|
| `eneco-oncall-intake-slack` | Intake | Produced this file |
| `eneco-sre` | Rollout / doc | Platform runbook + repo audit |
| `fowler-buildsmith` | Medium-term | Pin TFLint in ADO templates / pre-commit images |
| `tflint` | Verification | Validate config semantics |
| `eneco-context-repos` | Audit | Find all `.tflint.hcl` consumers |

### Tools / CLI(s)

| Tool | Version (probed 2026-07-18) or status | Fallback | Use |
|------|---------------------------------------|----------|-----|
| `tflint` | `v0.63.1` (Known in CI) | — | `tflint --init` repro |
| `pre-commit` | Unknown — probe in ADO log | ADO task log | Hook runner |
| `az pipelines` | Unknown — probe at investigation | ADO UI | Failure rate across repos |

## Mechanism (cited)

1. **Default:** TFLint downloads official ruleset releases and verifies **GitHub artifact attestations** via sigstore. *(Known — tflint plugin install behaviour.)*
2. **GitHub API change:** attestation list returns `"bundle": null` + `bundle_url`; nil bundle passed to verifier → **panic**. *(Known — [tflint#2591](https://github.com/terraform-linters/tflint/issues/2591), [PR #2593](https://github.com/terraform-linters/tflint/pull/2593) description.)*
3. **Fix upstream:** fetch/decompress bundle from `bundle_url`; reject empty bundles instead of crashing. *(Known — [PR #2600](https://github.com/terraform-linters/tflint/pull/2600), merged 2026-07-17.)*
4. **Workaround:** `signature = "pgp"` selects PGP key verification — **does not skip verification**. *(Known — community + maintainer interim guidance cited in #2591 thread.)*
5. **Intermittency:** likely agent caching, token presence, or timing on attestation API — **Inferred**; falsifier: correlate failures with `GITHUB_TOKEN` / agent pool.

## Claims to verify

| # | Claim | Tag | Falsifier / probe |
|---|-------|-----|-------------------|
| 1 | Panic is attestation path, not Terraform | Known | Stack trace in build `1721100` |
| 2 | `signature = "pgp"` fixes init on Dispatching.Infrastructure | Inferred | Re-run pipeline on commit `77552752…` or local `tflint --init` |
| 3 | All Myriad TF repos need the same hunk | Unknown | Audit every `.tflint.hcl` with `azurerm` plugin |
| 4 | Lint still fails on real violations with PGP | Unknown | Introduce deliberate tflint violation in test branch |
| 5 | First TFLint release containing #2600 | Unknown | Watch [tflint releases](https://github.com/terraform-linters/tflint/releases) post 2026-07-17 |
| 6 | ADO template `tflintVersion` pin location | Unknown | Find `pre-commit.yaml@templates` or equivalent in Platform repo |

## Confidence assessment

- **Ledger:** 12 Known · 4 Inferred · 0 Assumed · 4 Unknown
- **Route-changing unknown:** Which TFLint **release tag** includes #2600, and **full repo inventory** still missing `signature = "pgp"`
- **Resolved by:** Watch upstream release + org-wide `.tflint.hcl` grep
- **Confidence:** **High** on root cause and workaround mechanism; **Moderate** on rollout completeness and release timeline

## Human-decision gates

| Gate | Detail |
|------|--------|
| Near-term DoD | All affected repos: `signature = "pgp"` on `azurerm` plugin; Platform runbook note tied to [#2591](https://github.com/terraform-linters/tflint/issues/2591); confirm pipelines stable |
| Medium-term DoD | Pin TFLint version with #2600 fix in ADO + local tooling; remove `signature = "pgp"`; validate `tflint --init` without override |
| Optional | Short tooling post-mortem (external API change → CI red; mitigation acceptable until release X) |
| Security | PGP workaround **retains** supply-chain verification — not `signature = "skip"` |
| Out of scope (this intake) | Merging repo PRs, changing ADO templates, drafting Slack reply |

## Handoff self-check (four-predicate)

| Predicate | State | Note |
|-----------|-------|------|
| P1 Identity ledger | ✓ | Build, repo, versions, upstream links Known |
| P2 Mechanism + citation | ✓ | GitHub #2591 / #2600 authoritative |
| P3 Probe candidates | ✓ | Re-run build, repo audit, release watch |
| P4 Human-decision gates | ✓ | Near/medium-term DoD explicit |

**Verdict:** **Ready for `eneco-sre`** — primarily **documentation + repo rollout + release tracking**, not application RCA.
