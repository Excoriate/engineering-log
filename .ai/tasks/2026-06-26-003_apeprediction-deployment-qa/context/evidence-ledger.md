---
title: ape-prediction ACC/PROD deployment isolation — evidence ledger
task_id: 2026-06-26-003
agent: eneco-sre
status: complete
summary: Evidence ledger for ape-prediction ACC/PROD deployment isolation — pipeline, GitOps folders, ArgoCD app-of-apps syncPolicy, and the all-true env-flag variable group.
timestamp: 2026-06-26
---

# Evidence Ledger — ape-prediction deployment isolation

Sources (local Azure DevOps checkouts under `~/Dropbox/@AZUREDEVOPS/eneco-src/enecomanagedcloud/myriad-vpp/`):
- `ape-prediction` @ main (HEAD 2025-11-07) — app + CI pipeline
- `VPP-Configuration` @ main (local/origin HEAD 2026-04-13 — STALE ~2.5mo for dynamic tags)
- Live ADO query (2026-06-26) — variable group `ape-prediction` (id 604)

## The pipeline (ape-prediction/azurepipelines.yml)

- `trigger: none` — no push trigger (manual / orchestrated). [A1]
- External repos: `VPP-Configuration` (gitops values) + `Myriad - VPP` @ `refs/heads/development` (Helm chart at `azure-pipeline/Helm/apeprediction/`). [A1]
- Image tag by branch: main → `1.<counter>`; develop → `dev.<hash>`; hotfix → `<branch>.hf.<hash>`. [A1]
- Docker build+push → `vppacra.azurecr.io/eneco-vpp/apeprediction:<tag>`. [A1]
- **"Update values-override.yaml" step (NO branch condition → every build):** reads `$(test-env)/$(acc-env)/$(prod-env)`; `for i in dev acc prod` → if flag `true`, writes `Helm/apeprediction/$i/values-override.yaml` with the SAME `<tag>`; `git commit` + `git push origin HEAD:main`. [A1]
- **`HelmDeploy` direct-to-cluster:** `condition: eq(Build.SourceBranch,'refs/heads/develop')` → cluster `vpp-aks01-d` (DEV). acc/prod get NO direct push. [A1]

## GitOps config (VPP-Configuration)

- Separate folders: `Helm/apeprediction/{dev,acc,prod}/` each with `values.yaml` + `values-override.yaml`. [A1]
- Env-specific downstream targets [A1]:
  - acc `values.yaml`: hostAlias `eventhubs-hsp-ape-a-101` (10.7.224.78) — ACC Event Hub
  - prod `values.yaml`: hostAlias `eventhubs-hsp-ape-p-001` (10.9.32.79), mem limit 1Gi — PROD Event Hub
- Image tags (April snapshot): dev `1.176`, acc `1.168`, prod `1.168`. [A1-stale → A3 for live current value]

## ArgoCD topology (VPP-Configuration/Helm/vpp-core-app-of-apps)

- `templates/application.yaml`: one `Application` per `apps[]`; `destination.server = global.cluster.url`; `syncPolicy` = per-app else `global.syncPolicy`. [A1]
- `values.vppcore.acc.yaml` & `values.vppcore.prod.yaml` global block [A1]:
  - `cluster.url: https://kubernetes.default.svc` (in-cluster). NOTE [A3 — adversarial Lane 4]: this does NOT prove separate clusters; ALL env files use the same in-cluster URL + identical Application name `apeprediction-eneco-vpp` + namespace `eneco-vpp`. ACC/PROD cluster isolation is an OUT-OF-REPO invariant (acc & prod must be separate ArgoCD instances, each fed only its own values.vppcore.<env>.yaml; co-locating them would collide). Confirm via ArgoCD/cluster inventory.
  - `namespace: eneco-vpp`, project `vpp-core`, gitops repo = VPP-Configuration @ HEAD
  - `syncPolicy: { syncOptions: [PruneLast=true, Replace=false] }` — **NO `automated:` block → MANUAL sync**
- apeprediction entry (both files): chart `apeprediction` v0.1.0; valueFiles `$values/Helm/apeprediction/acc/*` vs `.../prod/*`. [A1]
- `automated:` syncPolicy appears ONLY in `values.vppcore.devmc.yaml:23` and `values.vppcore.sandbox.yaml:31` — NOT acc/prod. [A1]

## Live control — variable group `ape-prediction` (id 604), queried 2026-06-26 [A1]

- `test-env = "true"`, `acc-env = "true"`, `prod-env = "true"` — **ALL THREE TRUE**
- `apeprediction = "1.193"` (last main tag stored), `ape_prediction = "dev.a5c3a97"`
- `modifiedOn: 2026-06-25` (by Build Service) — changed the day before this request.

## Load-bearing inference [A2]

With all three env flags `true`, every ape-prediction build writes the new image tag into dev, acc, AND prod `values-override.yaml` in one commit to VPP-Configuration `main`. The prod desired-state in git therefore changes on builds intended for acc. The ONLY gate before prod runtime is the MANUAL prod ArgoCD sync (no `automated` on prod). This is the mechanism consistent with "ACC changes appeared in PROD."

## Blocked / caveats

- Live current per-env tags: ADO Git items REST returned TF401444 (SP needs interactive web sign-in); SSH key misconfigured. April snapshot used. [A3 blocked]
- Both local checkouts predate today; pipeline logic is Nov-2025. Recommend confirming live pipeline + flags before acting. [A3]
