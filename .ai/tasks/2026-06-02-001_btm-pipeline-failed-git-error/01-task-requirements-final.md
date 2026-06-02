---
task_id: 2026-06-02-001
agent: claude-opus-4-8
status: partial
summary: Final requirements for the BTM (Eneco.Vpp.BehindTheMeter) PR-tagging pipeline TF401019 failure — RCA + fix-option analysis + Feynman explainer.
---

# Final Requirements — BTM pipeline TF401019 "git error"

## Verbatim user asks (goal-fidelity corpus — do NOT paraphrase)

From the on-call intake (`slack-intake.md`) and the session brief:

1. "Could you help us to figure out **why this started happening**?"
2. "And could you **fix it** for us if it's not too much work for you?"
3. "I just wanted to check with you (VPP Platform team) whether **it's the only option for us or it can be fixed differently**." (referring to Agg team's fix = switching to Core Platform's Azure runner)
4. "I'd like to **avoid splitting our deployment job between two different runners** because my intuition says it would **increase the overall cost** for Eneco."
5. UAC-A: "you have to use ... the `how-to-feynman` skill, so it's explained in a .md document what you did, how, why, etc. So, I learn. I must be able to **understand deeply your rationale, and replicate it by myself**. If not, it's a failure."
6. UAC-B: "Ensure the **script can be tested locally**, so I can inspect it. If the solution **requires ADO, it must be specified** in the .md document."
7. Session meta: "Ensure max. verification. No space for assumptions. Ensure max. quality and reliability." + "discover and use other /eneco-* skills if needed."

## Hard facts extracted (A1 — from intake)

- Repo: `Eneco.Vpp.BehindTheMeter`, ADO project `Myriad - VPP`, org `enecomanagedcloud`. (A1: intake line 8)
- Failing build: `buildId=1663945`. (A1: intake pipeline URL)
- Error: `ERROR: TF401019: The Git repository with name or identifier eneco.vpp.behindthemeter does not exist or you do not have permissions ... 404 status code.` (A1: intake line 9)
- Failing step script: `azure-pipelines/steps/azure-boards-add-tag.sh` — adds DEV/ACC/PRD tag to the work item attached to a PR on deploy. Does `git log --format=%B | grep 'Related work items:'` then `az boards query` / `az boards work-item update`. (A1: intake lines 15-50)
- Onset: "worked for a long time", "started failing some time ago (weeks or months)". (A1: intake line 11)
- Agg team fix: "@niels.witte fixed the issue by switching to the Azure runner provided by the Core Platform team." Fix PR: `Eneco.Vpp.BehindTheMeter.B2B/pullrequest/178802`. (A1: intake lines 51, 57)

## Hypothesis set (post-intake; H2-H5 eliminated by TF401019 semantics)

- H1a — Job authorization scope limited ("Limit job authorization scope to referenced Azure DevOps repositories" / "Protect access to repositories in YAML pipelines") so System.AccessToken cannot reach the repo. Policy rollout → matches gradual onset.
- H1b — Build Service identity (Project/Collection Build Service) lost Read on the repo (security change).
- H1c — Self-hosted agent credential/PAT expiry; Core Platform runner uses fresh managed System.AccessToken. (LL-006 link.)
- H1d — Pipeline executes in a project/identity context where the repo is not in scope; runner switch changes the effective identity/scope.

Master discriminators (in priority order):
1. PR 178802 diff (the exact change that fixed the identical failure).
2. Failing build 1663945 log — WHICH task/step emitted TF401019 (checkout vs script vs az call) + the agent pool used.
3. The BTM pipeline YAML — pool, `checkout`, `resources.repositories`, `persistCredentials`, token usage.
4. Project setting "Limit job authorization scope to referenced Azure DevOps repositories".

## Verification strategy (witness != producer)

- Truth surface: live ADO (build log, PR diff, YAML, project settings) + Microsoft Learn authoritative docs on TF401019 / job-auth-scope / System.AccessToken.
- GATE-ZERO (this step): confirm live ADO read access. If blocked → all ADO-derived claims are A3[UNVERIFIED[blocked]] and the user must run named probes via `!`; I will say so explicitly rather than assume.
- Fix must ship with a locally-runnable repro/test of the script logic + a clearly-separated "ADO-side change required" section.

## Out of scope (flagged, not acted)

- ~30+ prior on-call log folders show as DELETED in the uncommitted working tree. Pre-existing; not created by this task; will NOT restore/commit (NN-4). Surfaced to user.
