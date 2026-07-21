---
task_id: 2026-07-19-003
agent: terraform-oraculum
timestamp: 2026-07-19T00:00:00Z
status: complete
summary: |
  Adversarial Terraform/IaC verification of RCA L5 + how-to-fix P3 for the VPP FBE
  feature-flags 401 incident. All 5 load-bearing claims CONFIRMED against on-disk HCL
  and the pinned git tag v0.1.0 (verified the pinned tag, not just worktree HEAD).
  Three additional gotchas surfaced: (A) MEDIUM — the appconfig+keyvaultsecret modules
  main HEAD has drifted from v0.1.0 (dropped ignore_changes=[tags], added tags/data_owners,
  added providers.tf azurerm ~>4.0 / required_version >=1.12.0), so cutting v0.2.0 from
  HEAD bundles unrelated changes into the FBE; (B) LOW/latent — local_auth_enabled is
  unset (defaults true); disabling it later kills read AND write HMAC keys; (C) LOW —
  the "30-day purge lockout" figure for the App Config store is imprecise (App Config
  soft-delete is 1-7 days, purge_protection defaults off, and the random suffix avoids
  name collisions anyway). Provider-behavior claims are PROVIDER-DOCUMENTED (azurerm 4.x
  schema) not PLAN-VERIFIED — terraform plan / live registry were not runnable this session.
---

# Terraform Oraculum — Adversarial Receipt

## Key Findings

- claim_1: CONFIRMED — store name embeds `random_string.random.result`; keeper stable per slot; re-apply preserves, destroy->create regenerates
- claim_2: CONFIRMED — name is ForceNew on `azurerm_app_configuration`; incident's destroy->create path yields a new store with new HMAC keys regardless
- claim_3: CONFIRMED — v0.1.0 module outputs only the write-key conn string; azurerm exposes `primary_read_key[0].connection_string`
- claim_4: CONFIRMED — read-key switch is a KV secret value update (not ForceNew, no store recreate, no purge lockout); module tag+ref-bump gotcha IS stated in how-to-fix P3
- claim_5: THREE gotchas found — module-drift-on-tag-cut (MEDIUM), `local_auth_enabled` latent (LOW), 30-day purge figure imprecise (LOW)

**Target:** RCA `output/rca.md` (L5) + `output/how-to-fix.md` (P3) for incident
`2026_07_18_001_vpp_frontend_fbe_feature_flags_401`.
**Mode:** read-only verification. **Task:** confirm/refute 5 load-bearing IaC claims.

## Evidence base (all read this session)

| Artifact | Path | Role |
|----------|------|------|
| FBE app-config | `VPP - Infrastructure/terraform/fbe/app-config.tf` | store name + KV wiring |
| FBE random | `VPP - Infrastructure/terraform/fbe/common.tf` | random_string + keeper |
| FBE key-vault | `VPP - Infrastructure/terraform/fbe/key-vault.tf` | secret-copy pattern |
| FBE provider | `VPP - Infrastructure/terraform/fbe/provider.tf` | azurerm `~> 4.0` |
| FBE tfvars | `VPP - Infrastructure/terraform/fbe/terraform.tfvars:19-21` | App Config sku = `standard` |
| appconfig module @ **pinned tag v0.1.0** | `git show v0.1.0:terraform/modules/appconfig/{main,output}.tf` | what the FBE ACTUALLY runs |
| keyvaultsecret module @ **v0.1.0** | `git show v0.1.0:terraform/modules/keyvaultsecret/main.tf` | value-update path |
| module drift | `git diff v0.1.0 HEAD -- terraform/modules/appconfig terraform/modules/keyvaultsecret` | HEAD vs pinned tag |

**Epistemic boundary:** the Terraform registry MCP and `terraform plan` were **not runnable**
in this session (only Read/Write/Edit/Bash exposed). HCL-structure claims are **A1 FACT**
(file:line + `git show`). Provider-behavior claims (ForceNew flags, attribute existence,
defaults) are **PROVIDER-DOCUMENTED** from the azurerm 4.x schema — high confidence, but not
PLAN-VERIFIED. Where that distinction is load-bearing it is flagged.

---

## Claim 1 — store name embeds the random; keeper stable per slot; teardown regenerates

**VERDICT: CONFIRMED (A1 FACT for the HCL mechanism).**

- `app-config.tf:7` — `app_configuration_name = format("%s-appconfig-fbe-%s-%s", var.project-prefix, var.environment, random_string.random.result)`. The store name **does** embed `random_string.random.result`. **A1.**
- `common.tf:1-9` — `random_string "random"` with `keepers = { id = format("%s-random-fbe-%s", var.project-prefix, var.environment) }`. Both keeper inputs (`project-prefix`, `environment`=slot) are **static per slot**. **A1.**
- Mechanism (PROVIDER-DOCUMENTED, hashicorp/random `keepers`): a keeper forces regeneration only when its value **changes**. Here it never changes within a slot's lifetime → on a plain `terraform apply` the result is **preserved from state** (store name stable). Keepers do **not** guard against `destroy` — a `terraform destroy` (delete pipeline 2629) removes the `random_string` from state; the next `terraform apply` (create pipeline 2412) generates a **fresh** 3-char result → **new store name**.
- This exactly matches the RCA L5 wording "stable within a Terraform state but regenerates when the state is destroyed and rebuilt." The keeper is NOT what changes the name on recreate — the state teardown is. **Correctly framed.**

Nuance for the record: the ONLY ways the name changes are (a) destroy→create, (b) a keeper input change (project-prefix/environment), or (c) taint/removal. A normal re-apply never changes it. The RCA scopes it to (a). Correct.

---

## Claim 2 — name change is ForceNew on azurerm_app_configuration → new store → new HMAC keys

**VERDICT: CONFIRMED (PROVIDER-DOCUMENTED; conclusion also holds via the stronger destroy→create path).**

- `azurerm_app_configuration.name` is **ForceNew** in the azurerm 4.x schema (the name is part of the ARM resource ID; it cannot change in place). RCA L5 labels this `A2` — accurate. **PROVIDER-DOCUMENTED** (not runnable to PLAN-VERIFY here).
- More importantly for the actual incident: the store is not renamed in place — it is **fully destroyed** (pipeline 2629) and **recreated** (2412) with a new random suffix. A freshly created App Config store receives **fresh** primary/secondary read+write HMAC keys from Azure. So "new store → new keys" is true **independent of** ForceNew — it follows from "new resource." ForceNew is the correct label for the hypothetical in-place-rename path the how-to-fix "do-NOT" list warns against.

No refutation. Both the ForceNew label and the new-keys conclusion stand.

---

## Claim 3 — module outputs ONLY the write-key conn string; read-key attribute exists

**VERDICT: CONFIRMED (A1 FACT, verified against the PINNED tag).**

- `git show v0.1.0:terraform/modules/appconfig/output.tf` → exactly three outputs: `app_configuration_primary_write_key_connection_string`, `id`, `name`. **No read-key output.** **A1** — and critically verified against **`ref=v0.1.0`** (`app-config.tf:2`), the version the FBE actually sources, **not** just the worktree HEAD.
- `app-config.tf:15` — `key_vault_secret_value = module.appconfig.app_configuration_primary_write_key_connection_string`. The KV secret `connectionstrings-app-config` is wired to the **write** key. **A1.** (Whether the browser then receives it is the RCA's live-verified runtime claim, outside Terraform scope — but the HCL confirms the write key is what enters the KV → CSI → pod chain.)
- Does azurerm expose `primary_read_key[0].connection_string`? **Yes** — `azurerm_app_configuration` exports `primary_read_key` / `secondary_read_key` / `primary_write_key` / `secondary_write_key`, each a block with `id`, `secret`, `connection_string`, indexed `[0]`. The P3 proposed output `azurerm_app_configuration.app_configuration.primary_read_key[0].connection_string` is **syntactically valid**. **PROVIDER-DOCUMENTED.**

---

## Claim 4 — read-key switch is a value update (not ForceNew); pinning gotcha stated

**VERDICT: CONFIRMED (A1 for the HCL path, PROVIDER-DOCUMENTED for ForceNew).**

- The switch changes `key_vault_secret_value` (module input) → flows to `azurerm_key_vault_secret.value` in the keyvaultsecret module (`git show v0.1.0:terraform/modules/keyvaultsecret/main.tf`: `value = var.key_vault_secret_value`, name stays `connectionstrings-app-config`). **A1.**
- `azurerm_key_vault_secret.value` is **NOT ForceNew** — updating it creates a **new secret version** under the same secret; `name` is ForceNew but is unchanged. So the switch is an in-place version bump: **no store touched, no KV recreate, no purge lockout.** **PROVIDER-DOCUMENTED.** Correct.
- The read key lives on the **same existing store** (read + write keys coexist), so referencing it does not force any `azurerm_app_configuration` replacement. Even the module `ref` bump (v0.1.0→v0.2.0) does **not** recreate the store: adding an output has zero resource impact, and the store's `name`/`sku`/`public_network_access` inputs are unchanged. Claim 4's "no store recreate" holds even under the ref bump.
- **Pinning gotcha stated?** YES. `how-to-fix.md` P3 line 174 "(Cut a new module tag, e.g. `v0.2.0`.)" and line 176 "bump the module `ref` and switch the KV value." The fix correctly recognizes that editing the module worktree alone is inert until a new tag is cut AND `app-config.tf:2` `ref=v0.1.0` is bumped. **Confirmed handled.**

---

## Claim 5 — other Terraform gotchas the RCA/fix missed

**VERDICT: THREE additional gotchas found (1 MEDIUM, 2 LOW). None invalidate the fix; all are worth a line in the PR.**

### Gotcha A — MEDIUM: cutting v0.2.0 from `main` HEAD bundles unrelated module drift

`git diff v0.1.0 HEAD` shows **both** pinned modules have already diverged from the tag the FBE runs:

- **appconfig** (`terraform/modules/appconfig/main.tf`): dropped `lifecycle { ignore_changes = [tags] }`, **added** `tags = var.tags`, **added** `azurerm_role_assignment.data_owners` (for_each `var.data_owners`, default `[]`), **added** `providers.tf` pinning `azurerm ~> 4.0` + `required_version >= 1.12.0`, and `tags`/`data_owners` variables.
- **keyvaultsecret** (`terraform/modules/keyvaultsecret/main.tf`): dropped `lifecycle { ignore_changes = [tags] }`, added `providers.tf` (`azurerm ~> 4.0`, `required_version >= 1.12.0`).

Consequences if v0.2.0 is cut from current HEAD and the FBE bumps to it:
1. **Tags no longer ignored** on the App Config store AND the KV secret. If the Sandbox subscription applies Azure Policy tag inheritance (common in Eneco managed cloud), existing FBE resources can show a **perpetual/in-place tag diff** on every apply. Not ForceNew, not destructive to keys — but a surprise diff and possible drift noise.
2. **`required_version >= 1.12.0`** module constraint — if the FBE pipeline's Terraform is older than 1.12.0, `terraform init` on the bumped module **fails**.
3. `data_owners` defaults `[]` → the new role_assignment is a no-op unless populated. Harmless but new surface.

**Recommendation:** cut v0.2.0 as a **minimal branch off the v0.1.0 tag** adding ONLY the read-key output, OR explicitly review/accept the bundled HEAD changes (tags handling + TF version pin) before tagging. The how-to-fix says "add output, cut v0.2.0, bump ref" but does **not** warn that HEAD ≠ v0.1.0. This is the one item I'd add to the PR checklist.

### Gotcha B — LOW / latent: `local_auth_enabled` is unset (defaults `true`)

Neither v0.1.0 nor HEAD sets `local_auth_enabled` on `azurerm_app_configuration` → it **defaults to `true`** (HMAC access keys enabled). The entire browser-HMAC flow — and the P3 read-key hardening — **depend** on local auth staying enabled. If a future security pass sets `local_auth_enabled = false` (Azure `disableLocalAuth`), **both** read and write connection strings stop authenticating → the exact fleet-wide 401 returns and P3 is moot. Worth one line in the P3 note: "read-key hardening assumes local auth remains enabled." (PROVIDER-DOCUMENTED; `local_auth_enabled` is updatable in place, not ForceNew.)

### Gotcha C — LOW: "30-day purge lockout" on the store is imprecise

`how-to-fix.md` "One-way doors" says renaming the store = "ForceNew destroy + **30-day** purge lockout." For `azurerm_app_configuration`, `soft_delete_retention_days` range is **1-7** (default 7) and `purge_protection_enabled` **defaults false** — and the v0.1.0 module sets **neither**. So a soft-deleted App Config store can be **purged immediately** and retention is ≤7 days, not 30. Additionally, because each recreate uses a **new random suffix**, there is no same-name collision to lock on in the first place. The "30-day" figure looks borrowed from Key Vault (7-90 day range). The **direction** of the warning (store rename = ForceNew = destroy/recreate) is correct; only the "30-day" number is wrong for the store. Low severity — does not change the fix.

### Checked and found clean (no gotcha)

- **No hidden key-rotation resource** — keys are provider-exported attributes, no `azurerm_app_configuration_key`/azapi regen resource. Consistent with the RCA's "store/keys are fine."
- **SKU `standard`** (`terraform.tfvars:20`) exposes read+write keys — the P3 read-key output is valid on this SKU.
- **KV secret name unchanged** in P3 (`connectionstrings-app-config`) → no ForceNew on `azurerm_key_vault_secret.name`.

---

## Summary verdict table

| # | Claim | Verdict | Strongest evidence |
|---|-------|---------|--------------------|
| 1 | store name embeds random; keeper stable per slot; teardown regenerates | **CONFIRMED** | `app-config.tf:7`, `common.tf:6-8` (A1) |
| 2 | name change ForceNew → new store → new HMAC keys | **CONFIRMED** | azurerm 4.x `name` ForceNew (PROVIDER-DOCUMENTED); destroy→create yields new keys regardless |
| 3 | module outputs ONLY write key; read-key attr exists | **CONFIRMED** | `git show v0.1.0:.../output.tf`; `app-config.tf:15` (A1); `primary_read_key[0].connection_string` valid |
| 4 | read-key switch = value update, not ForceNew, safe; pinning stated | **CONFIRMED** | keyvaultsecret v0.1.0 `value=var...`; `value` not ForceNew (PROVIDER-DOCUMENTED); how-to-fix P3 L174/176 states tag+ref bump |
| 5 | other gotchas | **3 FOUND** | module drift `git diff v0.1.0 HEAD` (MEDIUM); `local_auth_enabled` default (LOW); "30-day" imprecision (LOW) |

**Confidence:** HCL-structure claims 1/3/4 (file:line + pinned-tag) = ~99%. Provider-behavior
facets of 2/3/4 (ForceNew, attribute existence, defaults) = PROVIDER-DOCUMENTED ~90%, not
PLAN-VERIFIED — recommend one `terraform plan` on a throwaway slot to promote to PLAN-VERIFIED
before shipping P3. No claim REFUTED. No blocker to the fix.
