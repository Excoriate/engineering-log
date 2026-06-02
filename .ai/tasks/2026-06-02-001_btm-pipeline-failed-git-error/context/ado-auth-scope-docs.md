---
task_id: 2026-06-02-001
agent: librarian
status: complete
summary: Official Microsoft Learn evidence that TF401019/404 in ADO YAML pipelines is a 404-masks-403 job-auth-scope/repo-protection symptom; the git identity is the Build Service identity regardless of agent pool, so switching runner alone cannot fix a scope/permission failure.
---

# Azure DevOps Job Authorization Scope & TF401019 — Official-Doc Evidence

Scope: grounding for RCA of `enecomanagedcloud` YAML pipeline failing with `TF401019 ... 404 status code` on a long-unchanged pipeline. All sources are Tier-1 (learn.microsoft.com). Evidence labels: A1 = URL-cited primary fact; A2 = derived from A1; A3 = unverified/not-found-in-docs.

## TL;DR (load-bearing conclusions)

- **A2** — TF401019 ("repository does not exist or you do not have permissions ... 404") in a pipeline checkout is, in the documented Microsoft scenarios, a **permission/scope** symptom, NOT a deleted repo. Microsoft's own worked example produces this exact error purely by tightening job authorization scope while the repo still exists (Q1, Q2).
- **A1** — The git operation authenticates as the **Build Service identity** (Project Collection Build Service or `{Project} Build Service`), and "all job access tokens in a project have identical permissions." The identity is a property of the **project/scope**, NOT of the agent pool. ([new-service-connection roadmap](https://learn.microsoft.com/azure/devops/release-notes/roadmap/2025/new-service-connection); [access-tokens#scoped-build-identities](https://learn.microsoft.com/azure/devops/pipelines/process/access-tokens?view=azure-devops#scoped-build-identities))
- **A2** — Therefore **switching the agent pool / build runner does NOT change the identity used for git auth** and cannot, by itself, fix a job-auth-scope or repo-permission TF401019. If a sibling team's "switch runner" fix worked, the effective change was almost certainly something else that travelled with it (different pipeline in a different project/scope, a `resources.repositories`/`checkout` declaration, or a granted permission) — see Q5.
- **A1/A3** — The "started failing weeks/months ago with no pipeline change" onset is consistent with the repo-scoping feature being **on by default since May 2020** for new orgs/projects. Whether Microsoft retroactively auto-enabled it on a **pre-existing** org at a later date is **A3[UNVERIFIED]** (docs say existing orgs "must enable it" manually) — see Q4.

---

## Q1 — What TF401019 means; is it "404-masks-403"?

**A1** — The documented checkout failure is verbatim:

```log
remote: TF401019: The Git repository with name or identifier XYZ does not exist or you do not have permissions for the operation you are attempting.
fatal: repository 'XYZ' not found
##[error] Git fetch failed with exit code: 128
```

Microsoft's troubleshooting steps for this error are **ordered as a permission/scope diagnosis**, not a "repo deleted" diagnosis: (1) confirm the repo still exists, then (2) check **Protect access to repositories in YAML pipelines**, then (3) check the **job authorization scope** and whether the **Build Service account** lost access. Source: [Build Azure Repos Git — FAQ: Failing checkout](https://learn.microsoft.com/azure/devops/pipelines/repos/azure-repos-git?view=azure-devops#faq).

**A2 (404-masks-403)** — The message string couples "does not exist" OR "you do not have permissions" into a single error, and the task surfaces it with a `404 status code`. In Microsoft's worked example the repo **provably still exists** yet the same TF401019/404 is returned solely because the identity's scope was restricted (see Q2). Conclusion: a 404/TF401019 here is the documented manifestation of an **authorization denial** (the service does not disclose existence of a repo the identity can't see), i.e. the classic "404 instead of 403" pattern. Microsoft does not use the literal phrase "404 masks 403," so that exact framing is **A2 (derived)**, not a quoted A1.

## Q2 — "Limit job authorization scope to current project" & "Protect access to repositories in YAML pipelines"

Two distinct settings, both at **Organization settings > Pipelines > Settings** and/or **Project settings > Pipelines > Settings**. Org-level enablement grays out and overrides project-level. Source: [access-tokens#job-authorization-scope](https://learn.microsoft.com/azure/devops/pipelines/process/access-tokens?view=azure-devops#job-authorization-scope), [azure-repos-git#limit-job-authorization-scope](https://learn.microsoft.com/azure/devops/pipelines/repos/azure-repos-git?view=azure-devops#limit-job-authorization-scope).

- **A1 — "Limit job authorization scope to current project for non-release pipelines"**: switches the job access token from **collection-scoped** (can read any repo in any project of the org) to **project-scoped** (only repos in the pipeline's own project). Applies to YAML + classic build pipelines.
- **A1 — "Protect access to repositories in YAML pipelines"**: finer-grained. With it ON, a YAML pipeline may access **only** the Azure Repos repos **explicitly referenced** by a `checkout` step or a `uses` statement in the job. "You won't be able to fetch code using scripting tasks and git commands for an Azure Repos Git repository unless that repo is first explicitly referenced." Source: [azure-repos-git#limit-job-authorization-scope](https://learn.microsoft.com/azure/devops/pipelines/repos/azure-repos-git?view=azure-devops#limit-job-authorization-scope).

**A1 — How it manifests as TF401019 (Microsoft's own example)**: A pipeline in project `SpaceGameWeb` that checks out repos in project `FabrikamFiber`. After enabling **Limit job authorization scope to current project**, "The pipeline fails because it can't check out the repositories in the FabrikamFiber project. You see the errors `remote: TF401019: The Git repository with name or identifier FabrikamFiber does not exist or you do not have permissions...`". The repos still exist; only the scope changed. Source: [secure-access-to-repos#azure-repos-repositories](https://learn.microsoft.com/azure/devops/pipelines/security/secure-access-to-repos?view=azure-devops#azure-repos-repositories).

**A1 — Remediation options** (any one of):
1. **Declare the repo** so the identity is authorized: add a `checkout` step or a `resources.repositories` / `uses` reference (preferred for cross-project / scripted git). Source: [azure-repos-git#limit-job-authorization-scope](https://learn.microsoft.com/azure/devops/pipelines/repos/azure-repos-git?view=azure-devops#limit-job-authorization-scope); [multi-repo-checkout](https://learn.microsoft.com/azure/devops/pipelines/repos/multi-repo-checkout?view=azure-devops).
2. **Grant the Build Service identity Read** on the target repo (and, cross-project, grant the build identity access to the other project). Source: [secure-access-to-repos#steps-to-improve-repository-access-security](https://learn.microsoft.com/azure/devops/pipelines/security/secure-access-to-repos?view=azure-devops#steps-to-improve-repository-access-security); [access-tokens#example---configure-permissions-to-access-another-repo-in-the-same-project-collection](https://learn.microsoft.com/azure/devops/pipelines/process/access-tokens?view=azure-devops#manage-build-service-account-permissions).
3. **Disable the setting** (org or project level) — reduces security; least preferred. Source: [access-tokens#job-authorization-scope](https://learn.microsoft.com/azure/devops/pipelines/process/access-tokens?view=azure-devops#job-authorization-scope).

**A1 — Documented exceptions where you do NOT need to reference the repo** even with "Protect access" ON: (a) no explicit checkout → implicit `checkout: self`; (b) script doing **read-only** ops on a repo in a **public** project; (c) script that **provides its own auth** (e.g. a PAT). Source: [azure-repos-git#limit-job-authorization-scope](https://learn.microsoft.com/azure/devops/pipelines/repos/azure-repos-git?view=azure-devops#limit-job-authorization-scope).

## Q3 — Relationship between "Protect access" and "Limit job authorization scope"

**A1** — They are layered, both under **Pipelines > Settings**. "Limit job authorization scope" controls **collection-vs-project** breadth of the token. "Protect access to repositories in YAML pipelines" is "**In addition to** the job authorization scope settings" and narrows YAML access further to **only explicitly-referenced repos**, regardless of project. Source: [access-tokens#job-authorization-scope](https://learn.microsoft.com/azure/devops/pipelines/process/access-tokens?view=azure-devops#job-authorization-scope) ("In addition to the job authorization scope settings ... Azure Pipelines provides a Protect access to repositories in YAML pipelines setting"); [secure-access-to-repos#steps-to-improve-repository-access-security](https://learn.microsoft.com/azure/devops/pipelines/security/secure-access-to-repos?view=azure-devops#steps-to-improve-repository-access-security) (recommended hardening enables both together).

**A1** — Either one, when enabled, can produce TF401019 for a repo accessed without proper declaration/permission. "Protect access" also breaks **Classic** pipelines that reach other repos: "Enabling this setting also prevents Classic build pipelines from accessing any repositories except the repo specified ... You get ... `TF401019: The Git repository with name or identifier FabrikamFiber does not exist or you do not have permissions...`". Source: [secure-access-to-repos#azure-repos-repositories](https://learn.microsoft.com/azure/devops/pipelines/security/secure-access-to-repos?view=azure-devops#azure-repos-repositories). Note: neither setting applies to GitHub repos.

## Q4 — TIMELINE: when did this become default-ON? (load-bearing for "started failing with no change")

**A1 — Sprint 160 (2019)**: introduced restricting the scope of access tokens. "Now, every new project and organization that you create will automatically have this setting turned on." and "Turning this setting on in existing projects and organizations may cause certain pipelines to fail if your pipelines access resources that are outside the team project using access tokens." Source: [release-notes/2019/sprint-160-update#azure-pipelines](https://learn.microsoft.com/azure/devops/release-notes/2019/sprint-160-update#azure-pipelines).

**A1 — Sprint 168 (2020), "Limit build service repos scope access"**: extended scoping to **per-repo** for YAML pipelines (the "Protect access" feature). "This feature will be on by default for new projects and organizations. For existing organizations, you must enable it in Organization Settings > Pipelines > Settings." Source: [release-notes/2020/sprint-168-update#azure-pipelines](https://learn.microsoft.com/azure/devops/release-notes/2020/sprint-168-update#azure-pipelines).

**A1 — Current docs (recurring "Important" banner)**: "**Protect access to repositories in YAML pipelines** is enabled by default for new organizations and projects created **after May 2020**." Source: [access-tokens#job-authorization-scope](https://learn.microsoft.com/azure/devops/pipelines/process/access-tokens?view=azure-devops#job-authorization-scope).

**A1 — Sprint 186 (2021)**: "Repos as a protected resource in YAML pipelines" — repos became protected resources with per-pipeline **Checks** and **Pipeline permissions** (Project settings > Repositories > Security). Adds another gate that can deny a previously-working pipeline. YAML-only. Source: [release-notes/2021/sprint-186-update#features](https://learn.microsoft.com/azure/devops/release-notes/2021/pipelines/sprint-186-update#features); [process/repository-resource#add-pipeline-permissions-to-a-repository-resource](https://learn.microsoft.com/azure/devops/pipelines/process/repository-resource?view=azure-devops#add-pipeline-permissions-to-a-repository-resource).

**A3[UNVERIFIED] — Retroactive auto-enable on a pre-existing org**: I did **not** find an official release note stating Microsoft flipped these settings ON for **already-existing** orgs at a specific later date. Every doc consistently says existing orgs "**must enable it**" manually. So a "no-change onset weeks/months ago" is more likely explained by one of: (a) an admin enabled the org/project setting; (b) a **per-repo Pipeline permission / Check** (Sprint 186 feature) was added or a repo's Build Service Read was revoked; (c) the repo, project, or a `resources.repositories` reference changed. Where to confirm definitively: Azure DevOps **release notes** index (https://learn.microsoft.com/azure/devops/release-notes/) filtered by year, and the org's **Pipelines > Settings** audit / Repository **Security** audit log. (A3 because absence-of-doc is not proof Microsoft never did a staged rollout.)

## Q5 — System.AccessToken / Build Service identity vs agent pool (does switching runner change the auth identity?)

**A1 — The identity is the Build Service identity, scoped by project, with uniform permissions**: "a 'checkout' task uses this token [`System.AccessToken`] to authenticate to the repository ... the permissions of this token are based on the **Project Build Service identity**, meaning **all job access tokens in a project have identical permissions**." Source: [release-notes/roadmap/2025/new-service-connection](https://learn.microsoft.com/azure/devops/release-notes/roadmap/2025/new-service-connection).

**A1 — Two built-in identities, selected by scope (not by pool)**: Collection-scoped `Project Collection Build Service ({Org})` or project-scoped `{Project} Build Service ({Org})`; "By default, the collection-scoped identity is used, unless configured otherwise" by the job-authorization-scope setting. Source: [access-tokens#scoped-build-identities](https://learn.microsoft.com/azure/devops/pipelines/process/access-tokens?view=azure-devops#scoped-build-identities).

**A1 — Microsoft-hosted vs self-hosted agent registration uses different mechanisms, but that is REGISTRATION, not per-job git auth**: self-hosted agents register via PAT / Service Principal / Entra device-code; "These methods of authentication are used only during agent registration." Per-job resource access (incl. git checkout) uses the dynamically-generated **job access token**. Source: [agents/agent-authentication-options](https://learn.microsoft.com/azure/devops/pipelines/agents/agent-authentication-options?view=azure-devops); [access-tokens (intro)](https://learn.microsoft.com/azure/devops/pipelines/process/access-tokens?view=azure-devops) ("A job access token is ... dynamically generated by Azure Pipelines for each job at run time. The agent ... uses the job access token in order to access these resources").

**A2 — Decisive answer to the RCA question**: The git-auth identity is determined by **job authorization scope + Build Service account permissions**, both of which are properties of the **pipeline's project**, not of the agent pool. **Switching the build runner / agent pool does NOT change the identity** used to authenticate the git checkout. Therefore "switch to a Core-Platform-provided runner" cannot, on its own, resolve a TF401019 caused by job-auth-scope or repo permissions. If it appeared to fix it, the real cause was a co-travelling change (a different pipeline definition in a differently-scoped project, an added `checkout`/`resources.repositories` declaration, a granted Build Service Read, or a different service-connection/PAT-based auth path). Derived from the A1 facts above.

## Q6 — Reading another repo's git log / fetching sources; auth after checkout

**A1 — Multi-repo checkout**: declare additional Azure Repos Git repos as a `resources.repositories` resource or inline `checkout`. Each non-`self` repo is checked out into a folder named after the repo (unless `path` set). Cross-project checkout requires **Limit job scope** to allow access. First-time cross-repo access may prompt for authorization (Permit). Source: [multi-repo-checkout](https://learn.microsoft.com/azure/devops/pipelines/repos/multi-repo-checkout?view=azure-devops); [steps-checkout#examples](https://learn.microsoft.com/azure/devops/pipelines/yaml-schema/steps-checkout?view=azure-pipelines#examples).

```yaml
resources:
  repositories:
    - repository: other
      type: git
      name: MyProject/OtherRepo
steps:
  - checkout: self
  - checkout: other            # checked out to $(Agent.BuildDirectory)/s/OtherRepo
  - script: git -C OtherRepo log -n 20    # works because 'other' is referenced
```

**A1 — Auth that `git` uses after checkout (`persistCredentials`)**: by default the checkout-injected credential is removed after checkout. Set `persistCredentials: true` to keep the `System.AccessToken`-backed credential on the local repo so later `git` commands (log, fetch, push) authenticate. Source: [scripts/git-commands#enable-scripts-to-run-git-commands](https://learn.microsoft.com/azure/devops/pipelines/scripts/git-commands?view=azure-devops#enable-scripts-to-run-git-commands).

```yaml
steps:
  - checkout: self
    persistCredentials: true   # keeps the System.AccessToken git credential for later git commands
```

**A1 — The underlying credential is a bearer `http.extraheader`**: scripted git auth uses `git -c http.extraheader="AUTHORIZATION: bearer $(System.AccessToken)" clone https://dev.azure.com/{org}/{project}/_git/{repo}` (Microsoft's documented pattern). The token's reach is still bounded by job authorization scope + Build Service permissions — i.e. a raw `git clone` to an undeclared repo can still hit TF401019 when "Protect access" is ON. Sources: [secure-access-to-repos#azure-repos-repositories (Classic example)](https://learn.microsoft.com/azure/devops/pipelines/security/secure-access-to-repos?view=azure-devops#azure-repos-repositories); [repos/git/auth-overview#authentication-mechanisms](https://learn.microsoft.com/azure/devops/repos/git/auth-overview?view=azure-devops#authentication-mechanisms).

**A1 — Required Build Service permissions to write (push/tag) via git**: grant `{Project} Build Service ({Org})` (NOT Project Collection Build Service) Read + Contribute + Create branch + Create tag on the repo. Read alone is default. Source: [scripts/git-commands#grant-permissions-to-the-build-service](https://learn.microsoft.com/azure/devops/pipelines/scripts/git-commands?view=azure-devops#enable-scripts-to-run-git-commands).

---

## Evidence Ledger (source authority + freshness)

| # | Source URL | Tier | Used for |
|---|-----------|------|----------|
| 1 | [pipelines/process/access-tokens](https://learn.microsoft.com/azure/devops/pipelines/process/access-tokens?view=azure-devops) | 1 (official) | Q2, Q3, Q4 (May-2020 banner), Q5 (identities) |
| 2 | [pipelines/repos/azure-repos-git#faq + #limit-job-authorization-scope](https://learn.microsoft.com/azure/devops/pipelines/repos/azure-repos-git?view=azure-devops#faq) | 1 | Q1 (error string + triage), Q2 (exceptions) |
| 3 | [pipelines/security/secure-access-to-repos](https://learn.microsoft.com/azure/devops/pipelines/security/secure-access-to-repos?view=azure-devops#azure-repos-repositories) | 1 | Q2/Q3 (worked TF401019 example, classic pipelines) |
| 4 | [release-notes/2019/sprint-160-update](https://learn.microsoft.com/azure/devops/release-notes/2019/sprint-160-update#azure-pipelines) | 1 | Q4 (2019 token-scope default-on for new) |
| 5 | [release-notes/2020/sprint-168-update](https://learn.microsoft.com/azure/devops/release-notes/2020/sprint-168-update#azure-pipelines) | 1 | Q4 (per-repo YAML scope; existing orgs must opt-in) |
| 6 | [release-notes/2021/sprint-186-update](https://learn.microsoft.com/azure/devops/release-notes/2021/pipelines/sprint-186-update#features) | 1 | Q4 (repos as protected resource; Checks/permissions) |
| 7 | [release-notes/roadmap/2025/new-service-connection](https://learn.microsoft.com/azure/devops/release-notes/roadmap/2025/new-service-connection) | 1 | Q5 (System.AccessToken = Project Build Service identity, uniform perms) |
| 8 | [pipelines/agents/agent-authentication-options](https://learn.microsoft.com/azure/devops/pipelines/agents/agent-authentication-options?view=azure-devops) | 1 | Q5 (agent registration auth ≠ per-job git auth) |
| 9 | [pipelines/repos/multi-repo-checkout](https://learn.microsoft.com/azure/devops/pipelines/repos/multi-repo-checkout?view=azure-devops) | 1 | Q6 (resources.repositories / multi-checkout) |
| 10 | [pipelines/scripts/git-commands](https://learn.microsoft.com/azure/devops/pipelines/scripts/git-commands?view=azure-devops#enable-scripts-to-run-git-commands) | 1 | Q6 (persistCredentials, Build Service perms) |
| 11 | [repos/git/auth-overview](https://learn.microsoft.com/azure/devops/repos/git/auth-overview?view=azure-devops#authentication-mechanisms) | 1 | Q6 (http.extraheader bearer pattern) |
| 12 | [pipelines/yaml-schema/steps-checkout](https://learn.microsoft.com/azure/devops/pipelines/yaml-schema/steps-checkout?view=azure-pipelines#examples) | 1 | Q6 (checkout self/none/other semantics) |

Freshness: CURRENT (fetched 2026-06-02; `?view=azure-devops` is the live Azure DevOps Services view).

Negative information (conspicuously absent):
- No official doc states Microsoft **retroactively** auto-enabled job-auth-scope/repo-protection on **pre-existing** orgs at a dated rollout — see Q4 A3. Confirm via the org's Pipelines/Repository Security **audit logs**, not docs.
- Docs do not enumerate a "404 masks 403" phrase; that interpretation is A2-derived from the worked example, not an A1 quote.
