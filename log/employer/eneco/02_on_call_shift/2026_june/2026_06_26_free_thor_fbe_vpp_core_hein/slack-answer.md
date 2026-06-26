Hey Hein 👋 — sorted, `thor` is freed. You can take the slot now.

**What was wrong (answers to your two questions):**
1. **"Can I just remove the table entry?"** — Yes, that's effectively what frees the slot (set the `featurebranchenvdetails` row to `active=unused`, which is what the pipeline's final "release environment" step does). But `thor` was *not* actually all gone — the Key Vault `vpp-fbe-thor-vuo` was still live and the Terraform state still referenced it, so it needed a proper teardown, not just a row edit.
2. **"Why didn't auto-cleanup remove it?"** — The auto-evict (`vpp-fbe-autodelete-trigger`) is enabled and runs fine daily, but it just re-triggers the normal delete pipeline — which can't complete for `thor`. Your runs died at the owner check (`createdby` was Tiago, not you, and `bypassEnvironmentOwnerValidation` was `false`); Roel's runs got past that and died at `DestroyAppConfiguration` (the App Config store was already gone → `az appconfig feature list -n ""`). The slot-release step is after both walls, so it was never reached.

**What I did (Sandbox, verified live):**
- Deleted the leftover Key Vault `vpp-fbe-thor-vuo` and the orphan smart-detector alert → **zero `thor` resources left** in the sub.
- Released the slot in `featurebranchenvdetails` (`active=unused`, owner/branch cleared, the fixed `queue` binding preserved). Verified the row reads `unused`.

**One thing to know before the next `thor` create:** I left the old `terraform.thor` state blob in place on purpose (backed it up). It's stale, and clearing it needs a quick check I couldn't run from my account — whether any `thor`-named **AAD app registration** survived (needs `Application.Read.All`). Before someone next spins up `thor`, run `az ad app list --filter "startswith(displayName,'thor')"`: if it's empty, delete the `terraform.thor` blob for a clean start; if it returns something, delete that app reg first (otherwise the create hits "already exists"). Not urgent — the slot is free to use now.

Root cause for the platform: the FBE delete pipeline is non-idempotent (dies on a partial teardown) and never reaches the slot-release step — that's why `thor` was stuck for a week and why auto-cleanup couldn't clear it. The durable fix is the idempotency guard from last week's incident (`2026_06_22_004_tiago_thor_fbe_failed_deletion/`).
