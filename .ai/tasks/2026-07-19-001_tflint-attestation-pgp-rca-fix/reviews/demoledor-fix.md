---
task_id: 2026-07-19-001
agent: el-demoledor
status: complete
timestamp: 2026-07-19T18:55:00Z
target: "fix.md PR — pin tflintVersion v0.64.0 + remove signature=pgp (Eneco.Vpp.Core.Dispatching.Infrastructure)"
summary: "Core PR verified sound end-to-end; two doc/optional-path defects (variable-promotion footgun, arch-hardcoded verify cmds). Verdict SHIP-WITH-CHANGES."
---

# DEMOLEDOR REPORT — tflint v0.64.0 pin + remove pgp

Target: the PR the fix.md tells the engineer to submit to `Eneco.Vpp.Core.Dispatching.Infrastructure`.
Scope: Full. All 6 break-points executed against the real clones (`/tmp/dispatching-infra`, `/tmp/ado-templates` @ tag `2.6.9`) and live GitHub. Win condition: make it fail in CI or review.

## Destruction summary

| Break-point | Result | Grade |
|---|---|---|
| 1. `tflintVersion: "v0.64.0"` threads through | HELD — threads cleanly, URL well-formed | EXPLOIT-VERIFIED (held) |
| 2. cosign binary verify works on v0.64.0 | HELD — all assets 200 | EXPLOIT-VERIFIED (held) |
| 3. remove `signature=pgp` reintroduces panic | HELD — v0.64.0 `--init` w/ token exits 0 | EXPLOIT-VERIFIED (held) |
| 4. v0.64.0 minor bump breaks linting | HELD — identical bundled ruleset, real code green | EXPLOIT-VERIFIED (held) |
| 5. single-PR misses a `latest`-resolving path | HELD — CD path never runs tflint | EXPLOIT-VERIFIED (held) |
| 6. wrong thing to type in fix commands | **BROKEN** — verify cmds hardcode `arm64`; optional var path is a footgun | EXPLOIT-VERIFIED |

Findings that BLOCK the PR: **0**. Findings that should change the doc before it ships: **2** (both MEDIUM/LOW, in guidance not in the diff).

---

## What I tried to break and could NOT (the PR core is sound)

### Point 1 — version threads through. HELD. [EXPLOIT-VERIFIED]

Chain, file:line:
- `/tmp/dispatching-infra/.azuredevops/infra-ci.pipeline.yaml:23-25` and `azure-devops-ci-pipeline.yaml:23-25` both call `jobs/test/terraform/pre-commit.yaml@templates` and today pass **only** `terraformVersion`. Adding `tflintVersion:` here is the edit.
- `/tmp/ado-templates/jobs/test/terraform/pre-commit.yaml:4-6` declares param `tflintVersion` (default `'latest'`) and `:21` forwards it to the install step. Param name is **EXACTLY** `tflintVersion`. No rename.
- `/tmp/ado-templates/steps/test/tflint/install.yaml:2-4` param `tflintVersion`; `:29` `if [[ "${{ parameters.tflintVersion }}" == "latest" ]]` → with `v0.64.0` this is false → `:40` `TFLINT_VERSION="v0.64.0"`; `:48` `BASE_URL=".../releases/download/${TFLINT_VERSION}"` → `.../download/v0.64.0`.
- The GitHub release tag IS `v0.64.0` (with the `v`). The fix uses `"v0.64.0"` **with** the `v` — correct. `0.64.0` (no `v`) would 404. Confirmed the fix does not make that mistake.

Counter-hypothesis: could a quoting/scoping gotcha eat the literal? No — it's a compile-time template substitution of a plain string; verified the resulting URL returns 200 (Point 2). I favor "threads correctly" because I traced all three template hops and the asset resolves.

### Point 2 — cosign verify-blob works on v0.64.0. HELD. [EXPLOIT-VERIFIED]

`install.yaml:61-66` runs `cosign verify-blob` on `checksums.txt` using `checksums.txt.pem` + `checksums.txt.keyless.sig`, identity-regexp `^https://github.com/terraform-linters/tflint`, issuer `token.actions.githubusercontent.com`. Live asset check for `v0.64.0`:

```
200  checksums.txt
200  checksums.txt.pem
200  checksums.txt.keyless.sig
200  tflint_linux_amd64.zip
```

All present. The pinned install's Layer-1 binary verification does not break on v0.64.0.

### Point 3 — removing `signature=pgp` does NOT reintroduce the crash on v0.64.0. HELD. [EXPLOIT-VERIFIED]

Ran the exact 0.63.1 crash condition on v0.64.0 — no signature line, `GITHUB_TOKEN` present (token = the trigger that makes `auto` prefer the attestation path):

```
TFLint version 0.64.0  (+ ruleset.terraform 0.15.0-bundled)
Installing "azurerm" plugin...
Installed "azurerm" (... version: 0.28.0)
init exit=0  (token present: yes)
```

Exit 0, no panic. The fix in #2600 is compiled into the binary, so it is version-fixed, not config-fixed — reopening GitHub's attestation window cannot re-panic a pinned v0.64.0. Counter-hypothesis: "it only passed because the API window is closed today." Rebutted — the crash was a nil-deref on a non-empty/null-bundle response; v0.64.0's code follows `bundle_url` and rejects empty bundles regardless of window state. The pin removes the code path, not just the trigger.

### Point 4 — the minor bump does NOT introduce new lint reds. HELD. [EXPLOIT-VERIFIED]

The feared vector: 0.63.1→0.64.0 bundles a newer built-in `terraform` ruleset that enables new default rules → previously-green TF fails. Tested directly:

```
v0.63.1: + ruleset.terraform (0.15.0-bundled)
v0.64.0: + ruleset.terraform (0.15.0-bundled)   # IDENTICAL
```

Both versions bundle the **same** terraform ruleset 0.15.0, and the azurerm ruleset is pinned `0.28.0` (untouched by this PR). So zero rule surface changes. Then I linted the repo's real code with v0.64.0 + post-PR config (`--call-module-type=none`, mimicking the `terraform_tflint` hook at `.pre-commit-config.yaml:20`):

```
terraform/infra                      lint exit=0
terraform/azure-devops               lint exit=0
terraform/azure-devops/repository    lint exit=0
```

Additional fact that kills this vector: the repo has run `latest` all along; since 2026-07-17 15:37Z `latest` = v0.64.0, so green PRs are **already** running exactly this binary. Pinning freezes what is already green. The fix does not need a "may surface new findings" warning for THIS bump (the RCA's warning at L8/extension applies to the *ruleset 0.29.0* bump, which is correctly deferred).

### Point 5 — single PR does NOT miss a `latest`-resolving path. HELD. [EXPLOIT-VERIFIED]

I enumerated every `.azuredevops/*.pipeline.yaml` and traced every stage template, not just the two the fix names.

- tflint is installed in exactly one place: `steps/test/tflint/install.yaml`, reached only via `jobs/test/terraform/pre-commit.yaml`.
- In this repo, `pre-commit.yaml@templates` is referenced **only** in the two CI files the fix names (`grep` across `.azuredevops/` confirms — nowhere else).
- The CD pipelines (`infra-cd-{dev,acc,prd,sandbox}.pipeline.yaml`, `azure-devops-cd-pipeline.yaml`) route `azure-oidc-validate-and-apply.yaml` / `validate-and-apply.yaml` → `validate.yaml` → `jobs/infrastructure/terraform/plan-and-iac-test.yaml`, which installs **terraform only** (`plan-and-iac-test.yaml:40` terraform install; init; plan; snyk). No tflint, no pre-commit.
- The one template that DOES pass `tflintVersion` through a different route, `stages/infrastructure/terraform/code-quality.yaml:30-33`, is **not referenced** by any Dispatching pipeline.
- Pool nuance the prompt flagged: `azure-devops-ci-pipeline.yaml:14-15` sets top-level `self-hosted-mcprod-k8s`, but the validation stage overrides `pool: vmImage: ubuntu-latest` (`:20-21`), so the tflint install (`sudo mv tflint /usr/local/bin/`, install.yaml:74) runs on the hosted ubuntu image in both CI files. No self-hosted `sudo` gap for this PR.

Conclusion: editing the two CI files is a **complete** fix for the tflint path. The single-PR claim holds.

---

## What BROKE (fix before shipping the doc — not the diff)

### V1 — Optional `$(tflintVersion)` variable promotion is a CI-red footgun. [PATTERN-MATCHED] — MEDIUM

fix.md:153-162 offers: "promote it to a variable in `.azuredevops/variables.yaml` (and `azure-devops-variables.yaml`) ... then reference `tflintVersion: "$(tflintVersion)"`."

There are **two separate** variable files — `variables.yaml` (used by `infra-ci.pipeline.yaml`) and `azure-devops-variables.yaml` (used by `azure-devops-ci-pipeline.yaml`). If an engineer promotes the value to a variable but adds it to **only one** file (easy — they are different files consumed by different pipelines), the other pipeline's `$(tflintVersion)` macro is undefined. ADO then leaves the literal string `$(tflintVersion)` in the inline script, and install.yaml executes:

- `:29` `if [[ "$(tflintVersion)" == "latest" ]]` — under `set -euo pipefail` (install.yaml:24), bash runs command-substitution on `tflintVersion` (no such command).
- `:40` `TFLINT_VERSION="$(tflintVersion)"` — `VAR=$(failing-cmd)` under `set -e` exits non-zero. Step dies with **`tflintVersion: command not found`** — a fresh CI red that looks unrelated to tflint versioning and will burn debugging time.

Exploitability MED (requires taking the optional path + a one-file omission, both plausible). Impact MED (new CI red, cryptic). Confidence MED (ADO macro/`set -e` behavior is well-established; not executed in live ADO here). Severity = MEDIUM.

Counter-hypothesis: "an engineer will always edit both files." Possibly — but the doc presents it as an offhand "optionally," the two files are non-obviously paired, and the literal `tflintVersion: "v0.64.0"` path (fix.md:146-151) achieves the same result with zero footgun. False-positive IF the reviewer mandates both-file edits. Recommendation is DATA for the coordinator, not a fix: the literal path is strictly safer than the variable path for a two-file repo.

### V2 — Verification commands hardcode `arm64` (and `darwin`) → mislead on linux/amd64. [EXPLOIT-VERIFIED] — LOW-MEDIUM

fix.md:206-208 and 217-219 build the download URL as:

```
tflint_$(uname -s | tr '[:upper:]' '[:lower:]')_arm64.zip
```

OS is dynamic, **architecture is hardcoded `arm64`**. rca.md:440 is worse — fully hardcoded `tflint_darwin_arm64.zip`. On the author's Mac (darwin/arm64) both work. But the real CI runners and most Linux dev boxes are **amd64**. Simulated on a linux/amd64 host the command resolves `tflint_linux_arm64.zip`:

```
tflint_linux_arm64.zip  -> HTTP 200   (exists — wrong arch)
tflint_linux_amd64.zip  -> HTTP 200   (what it SHOULD fetch)
```

So it does **not** 404 (the task brief guessed 404); it silently downloads a real **ARM64** binary that then fails with `cannot execute binary file: Exec format error`. An engineer or reviewer running the "convergence proof" on a Linux/amd64 box gets a failure that looks like *the fix is broken*, when the fix is fine and the proof command is wrong. Since CI runs amd64 (install.yaml pins `tflint_linux_amd64.zip`, install.yaml:52), the verification snippet does not match the platform it claims to prove.

Exploitability HIGH (anyone not on Apple Silicon hits it). Impact LOW (verification/proof only — the shipped PR is unaffected; wastes time / false alarm). Confidence HIGH (measured). Severity = LOW-MEDIUM. Fix is a detection-arch derivation, but per my mandate I only report the defect: the arch must be derived (`uname -m` → amd64/arm64), not pinned.

---

## Residuals (INFO — not this PR, not counted)

- Both CI files are edited as a safe superset. Both carry `trigger: none`; whichever is the real branch-policy PR gate, editing both is harmless. Confirm which is wired so a future reader is not misled that both run.
- The self-hosted-vs-ubuntu pool safety depends on the stage-level `vmImage: ubuntu-latest` override staying in `azure-devops-ci-pipeline.yaml:20-21`. If a later change removes it, the `sudo mv` in tflint install could fail on the self-hosted k8s pool. Out of scope for this PR; flagged as latent.
- Systemic `latest` default in CCoE `install.yaml:4` remains; the fix correctly defers it to CCoE. Every other VPP repo not passing `tflintVersion` stays exposed to the next upstream regression (RCA U1). Not this PR's job.

---

## Adversarial self-check

- Pattern-matching: V1 is the only unexecuted finding; it rests on documented ADO macro + bash `set -e` semantics, not a guess. Graded MEDIUM, not CRITICAL, precisely because the primary (literal) path avoids it.
- False-positive conditions named per finding (V1: reviewer mandates both files; V2: everyone is on Apple Silicon).
- No accumulation inflation: Points 1–5 are reported as HELD, not padded into findings. Only two real defects, both in guidance/proof text, neither in the PR diff.
- Severity honesty: I found NO block-level defect in the actual change. Resisted the adversary's urge to inflate — the pin + remove-pgp is verified green end-to-end (init exit 0, real code lint exit 0, assets 200, both CI files complete, CD unaffected).

## Meta-falsifier

Strongest argument against my whole report: "the PR is fine, so this is a rubber-stamp." I attacked that by running the exact historical crash condition (token + no signature) on the pinned binary and by diffing bundled rulesets — both could have surfaced a BLOCK and did not. The two findings survive because they are about what the *document tells a human to do* (optional var path, arch-pinned proof), which is where an otherwise-correct PR actually goes wrong in practice.
