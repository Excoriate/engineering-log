---
task_id: 2026-07-19-001
agent: librarian
status: complete
timestamp: 2026-07-19T00:00:00Z
summary: |
  Source-verified upstream facts for the TFLint attestation nil-pointer CI failure.
  All version/date/PR claims verified against live GitHub (gh CLI) and official docs on 2026-07-19.
  KEY: the fix first ships in TFLint v0.64.0 (2026-07-17), NOT a v0.63.2 (no such release);
  only PR #2600 merged (#2593 was closed unmerged, its commits folded into #2600).
  MAJOR NUANCE: tflint-ruleset-azurerm v0.28.0 has NO GitHub attestations (API 404) — attestations
  begin at v0.29.0 — so 0.28.0 would fall back to PGP and NOT hit the panic; the intake's
  "azurerm 0.28.0" attribution needs reconciliation. Null-bundle condition is intermittent
  (my 2026-07-19 probe shows bundle populated again).
---

# Upstream TFLint Attestation / PGP Facts — Source Verification

> **CORRECTION (2026-07-19, post-adversarial-review):** §5's conclusion "azurerm v0.28.0 has NO GitHub
> attestations (API 404)" is **WRONG** — it hashed the plugin **zip** digest. tflint's
> `fetchArtifactAttestations` hashes the **`checksums.txt` contents** (`install.go`: `hash.Write(artifact)`
> where `artifact` = checksums.txt bytes). azurerm 0.28.0's `checksums.txt` digest
> (`b48c684c…`) returns **HTTP 200 with 1 attestation, signed 2025-03-21** (release day). So **0.28.0 IS
> attested**, the intake's "azurerm 0.28.0" attribution is **correct**, and the panic needs no "transient
> anomaly": the window returned that attestation with a `null` bundle → nil deref. Verified in
> `../../../log/…/proofs/outputs/azurerm-attestation-CHECKSUMS-digest.out.txt`. Read §5 with this correction.

**Verifier:** librarian subagent · **Date of verification:** 2026-07-19
**Method:** `gh` CLI v2.96.0 (authenticated, live GitHub REST) + WebFetch of official docs.
**Epistemic note:** The load-bearing facts (July 2026 PR merges, release tags, dates) are
**after my training cutoff (Jan 2026)** — every one below is grounded in a live fetch, not memory.

**Evidence labels:** `A1` = fetched source + quoted/observed value · `A2` = inferred from A1s
(reasoning stated) · `A3` = could not verify (reason + resolving path stated).

---

## 0. TL;DR for the coordinator (decision-critical)

| Question | Answer | Label |
|---|---|---|
| Which release first contains the fix? | **TFLint `v0.64.0`**, published **2026-07-17T15:37:19Z** | A1 |
| Is there a v0.63.2 with the fix? | **No.** Latest release is v0.64.0; no v0.63.2 exists | A1 |
| Which PR actually merged? | **#2600 only** (merged 2026-07-17T15:14:36Z). #2593 was **closed unmerged** | A1 |
| Is #2600 a follow-up to #2593? | **Yes** — #2600 body: "Follow up of #2593 ... adds additional commits" | A1 |
| Does the workaround `signature = "pgp"` exist? | **Yes** — real `.tflint.hcl` plugin attribute (values auto/attestation/pgp/none) | A1 |
| Does azurerm **v0.28.0** publish a PGP path? | **Yes** (`checksums.txt` + `checksums.txt.sig`) | A1 |
| Does azurerm **v0.28.0** publish GitHub attestations? | **NO — API returns 404.** Attestations start at **v0.29.0** | A1 |
| Exit criterion to remove the workaround | Upgrade TFLint to **>= v0.64.0** (ruleset version unchanged) | A2 |

**Discrepancy to reconcile (negative information):** The intake attributes the panic to
`tflint-ruleset-azurerm 0.28.0`, but v0.28.0 has **no attestations** (§5). Under the default
`signature = "auto"`, a plugin with no attestations returns HTTP 404 → treated as ignorable →
falls back to PGP → **no panic**. The panic requires an attestation *entry with `bundle: null`*,
which only exists for a version that HAS attestations (azurerm **v0.29.0+**, or another ruleset
such as `aws` — issue #2591 itself reproduces on `tflint-ruleset-aws` 0.48.0, **not azurerm**).
Coordinator should confirm the CI's actual ruleset + version. (A2, reasoning in §1/§5.)

---

## 1. Issue #2591 & PRs #2593 / #2600

### Issue #2591 — A1
- URL: https://github.com/terraform-linters/tflint/issues/2591
- Title (verbatim): *"tflint --init panics (nil pointer in bundle.TlogEntries) verifying attestations for **tflint-ruleset-aws 0.48.0** when GITHUB_TOKEN is set"*
- Author: `rojspencer-e3` · State: **CLOSED** · Created **2026-07-16T19:22:05Z** · Closed **2026-07-17T15:14:37Z** · Label: `bug`
- **The reproducer uses `tflint-ruleset-aws` v0.48.0, NOT azurerm.** (A1 — from title + config block in body.)
- Reproduced on TFLint **v0.62.1 and v0.63.1** (A1, body: *"Reproduced on both v0.62.1 and v0.63.1"*).
- Trigger condition (A1, body): *"It only happens when `GITHUB_TOKEN` is set (authenticated client → attestation verification is preferred); without a token, or with `signature = "pgp"`, installation succeeds."*
- **Panic stack (verbatim key frames, A1):**
  ```
   -> 4: github.com/sigstore/sigstore-go/pkg/bundle.(*Bundle).TlogEntries: /bundle.go(300)
   -> 5: github.com/sigstore/sigstore-go/pkg/verify.VerifyTlogEntry: /tlog.go(40)
   -> 6: ...verify.(*Verifier).VerifyTransparencyLogInclusion: /signed_entity.go(809)
   -> 7: ...verify.(*Verifier).Verify: /signed_entity.go(606)
   -> 8: github.com/terraform-linters/tflint/plugin.(*SignatureChecker).VerifyAttestations: /signature.go(136)
   -> 9: github.com/terraform-linters/tflint/plugin.(*InstallConfig).Install: /install.go(134)
  ```
  This **exactly matches** the intake's described mechanism (nil deref in `TlogEntries` inside
  `VerifyAttestations`). (A1)

### PR #2593 — A1
- URL: https://github.com/terraform-linters/tflint/pull/2593 · Title: *"plugin: fetch attestation bundles from bundle_url"*
- Author: `Kunalbehbud` · Created **2026-07-16T23:16:17Z** · **State: CLOSED · mergedAt: null · mergeCommit: null → NOT MERGED** (closed by `wata727`, the maintainer). (A1: `gh pr view` + timeline `event=closed actor=wata727`.)
- Root-cause statement (verbatim, A1): *"GitHub stopped embedding sigstore bundles in attestation list responses ... this matches the documented breaking change ('Remove the bundle property from attestation list responses. ... Use `bundle_url` to retrieve the attestation bundle'), except it now applies to the `2022-11-28` API version as well."*
- Captured live API response (verbatim, A1) shows `"bundle": null` alongside a `"bundle_url"` (Azure blob, `tmaproduction.blob.core.windows.net`).
- Mechanism (verbatim, A1): *"`json.Unmarshal` unmarshals `null` into a `*bundle.Bundle` without error — it just sets the pointer to `nil` — and `VerifyAttestations` passes that `nil` straight to `verifier.Verify`, which dereferences it in `bundle.(*Bundle).TlogEntries`."*
- Fix approach (A1): (1) resolve `bundle_url`, download the bundle (served **snappy-compressed** JSON), using `http.DefaultClient` so API credentials are not sent to blob storage; (2) *"`VerifyAttestations` rejects empty bundles instead of crashing"* → returns `attestation contains an empty sigstore bundle` instead of SIGSEGV.

### PR #2600 — A1
- URL: https://github.com/terraform-linters/tflint/pull/2600 · Title: *"plugin: fetch attestation bundles from bundle_url"* (same title as #2593)
- Author: `wata727` (maintainer) · Created **2026-07-17T15:10:34Z** · **State: MERGED · mergedAt 2026-07-17T15:14:36Z** · mergeCommit **`9b811b1398da4599ee6b6ed1cbc21213bc4f21a2`** · base `master`. (A1)
- Body (verbatim, A1): *"Follow up of https://github.com/terraform-linters/tflint/pull/2593 · Fixes #2591 · To release a fixed version as soon as possible, open a new PR that adds additional commits. See ... #2593 for details."*
- **Relationship (A2):** #2600 is the maintainer's follow-up that *incorporates #2593's commits plus additional ones* and is the PR that actually merged; #2593 was closed unmerged in its favor. The v0.64.0 release notes credit both: *"...bundle_url by @Kunalbehbud in #2593 — Merged as #2600."* (A1)
- **Timing (A2):** issue #2591 closed at `15:14:37Z`, one second after #2600 merged at `15:14:36Z` → merging #2600 auto-closed the issue.

---

## 2. THE CRITICAL FACT — release tag containing the fix

- **Fix first ships in TFLint `v0.64.0`, published `2026-07-17T15:37:19Z`** (≈23 min after #2600 merged, same day). (A1: `gh api .../releases`.)
- **`v0.64.0` is the latest release.** Preceding releases: v0.63.1 (2026-06-03), v0.63.0 (2026-06-02). **There is no v0.63.2** — the fix did **not** ship as a 0.63.x patch. (A1)
- **Commit-ancestry proof (A1):**
  - `9b811b1...` vs `v0.64.0`: `status: "ahead", behind_by: 0` → the merge commit **is an ancestor of v0.64.0** (i.e., contained in that tag).
  - `9b811b1...` vs `v0.63.1`: `status: "behind", behind_by: 30` → the merge commit is **NOT** in v0.63.1.
- **Release-notes proof (A1, v0.64.0 body, "Bug Fixes"):** *"plugin: fetch attestation bundles from bundle_url by @Kunalbehbud in https://github.com/terraform-linters/tflint/pull/2593 · Merged as https://github.com/terraform-linters/tflint/pull/2600"*
- Corroborating (A1): v0.64.0 also bumped `github.com/sigstore/sigstore-go` (through 1.2.2) among its dependency chores.
- **Exit criterion (A2):** Removing the `signature = "pgp"` workaround is safe once CI runs **TFLint >= v0.64.0** (e.g., `setup-tflint` with `tflint_version: v0.64.0`). The ruleset version does not need to change.

---

## 3. The `signature` plugin attribute

Source (A1): `docs/user-guide/plugins.md` on `master`, fetched via GitHub contents API.

- **It is a real `.tflint.hcl` plugin-block attribute.** Verbatim doc:
  - `### signature` — *"Controls how TFLint verifies plugin releases. Valid values are:"*
  - `auto`: *"Prefer `attestation` when available, then fall back to `pgp`. **This is the default behavior.**"*
  - `attestation`: *"Require artifact attestations. Attestation verification in private repositories is not supported."*
  - `pgp`: *"Require PGP signature verification with `signing_key`."*
  - `none`: *"Skip plugin signature verification."*
  - Companion attribute `signing_key`: *"The signing key used when `signature = "pgp"` or `"auto"`."*
- **Default for the official azurerm ruleset:** `auto` (attestation-preferred when a token is present, PGP fallback). There is no ruleset-specific override of this default — `auto` is the global default. (A2, from the doc + issue #2591 behavior.)
- **Introduced:** by PR **#2483** *"plugin: Add signature mode to control plugin verifications"*, commit `7dabb6b4`, dated **2026-03-28**. First shipped in **`v0.62.0`** (2026-04-19): commit is `ahead/behind_by:0` vs v0.62.0 and `behind_by:24` vs v0.61.0. (A1)
- **When attestation verification itself was introduced:** TFLint v0.51.1 (2026... i.e. 2024-05-11) release notes: *"release: Introduce Artifact Attestations by @wata727 in #2038."* Attestation became the **preferred** path when authenticated well before the `signature` knob existed; #2483 (v0.62.0) formalized explicit modes. (A1 for the v0.51.1 note; A2 for "preferred when authenticated" from issue #2591 body.)
- **Why `auto` does NOT save you (important, A2):** the bug is a **panic/crash inside attestation verification**, not a graceful error, so `auto`'s "fall back to pgp" never executes — the process dies first. That is precisely why the effective workaround must be an **explicit** `signature = "pgp"` (skip attestation entirely). Confirmed by issue #2591: default+token → panic; `signature = "pgp"`+token → succeeds (with a legacy-signing-key deprecation warning).

---

## 4. First principles — GitHub Artifact Attestations / Sigstore (for the teaching RCA)

### (a) What a GitHub artifact attestation IS
- GitHub docs (A1, docs.github.com/.../using-artifact-attestations-to-establish-provenance-for-builds):
  *"Artifact attestations enable you to increase the supply chain security of your builds by
  establishing where and how your software was built"* and establish *"build provenance for
  artifacts such as binaries and container images."* Verified with *"`gh attestation verify`."*
  (Note: this particular page does **not** expose the crypto internals — those come from Sigstore.)
- Mechanism (A2, from Sigstore docs + the panic path): a GitHub artifact attestation is delivered
  as a **Sigstore bundle** wrapping a DSSE-enveloped SLSA build-provenance predicate, signed
  "keyless" via a Fulcio-issued short-lived cert tied to the GitHub Actions workflow identity, with
  the signing event recorded in the Rekor transparency log.

### (b) Sigstore bundle internals & why `TlogEntries` matters
- Sigstore docs (A1, docs.sigstore.dev/about/bundle):
  *"A Sigstore bundle is everything required to verify a signature on an artifact. This is
  satisfied by the Verification Material and signature Content."* Verification material includes
  *"a single X.509 leaf certificate conveying the signing key and containing extensions for
  identities consumed at verification time"* plus transparency-log entries and optional RFC3161
  timestamps.
- Keyless / Fulcio (A1): *"When using short lived Fulcio certificates where verification may occur
  after the certificate has expired, bundles must include at least one transparency log's signed
  entry timestamp or an RFC3161 timestamp to provide proof that signing occurred during the
  certificate's validity window."*
- Transparency log / tlog (A1): *"Transparency Log entries can provide proof that a signing event
  was written to a public log ... The embedded signed entry timestamp may be used to validate
  signing occurred during certificate validity."*
- **Why the panic (A2):** the verifier's `VerifyTransparencyLogInclusion` → `VerifyTlogEntry` reads
  `bundle.TlogEntries`. When the bundle pointer is `nil` (because the list API returned
  `"bundle": null`), the tlog-entries accessor dereferences nil → SIGSEGV. The tlog is central to
  keyless verification (it is the *only* proof the short-lived cert was valid at signing time),
  which is why the verifier reaches for it eagerly.

### (c) The actual GitHub API change (root cause, authoritative)
- GitHub REST breaking-changes (A1, docs.github.com/en/rest/about-the-rest-api/breaking-changes),
  entry **Version 2026-03-10**, verbatim: *"The `bundle` field is removed from repo, org, and user
  attestation list and bulk-list responses. Use `bundle_url` to retrieve the attestation bundle."*
  Affected endpoints (A1): `GET /orgs/{org}/attestations/{subject_digest}`,
  `GET /repos/{owner}/{repo}/attestations/{subject_digest}`,
  `GET /users/{username}/attestations/{subject_digest}`, and the `bulk-list` POST variants.
- **Timeline reconciliation (A2):** the removal was documented 2026-03-10 for newer API opt-ins, then
  (per PR #2593) began applying to the default `2022-11-28` API version around 2026-07-16, which is
  what suddenly broke `tflint --init` for authenticated users on TFLint <= v0.63.1.

### (d) Contrast: classic PGP/GPG detached-signature path
- (A2) `signature = "pgp"` verifies `checksums.txt` against a **detached** `checksums.txt.sig`
  using a **fixed, long-lived** public key (bundled/legacy key or user-supplied `signing_key`).
  No Fulcio short-lived cert, no Rekor transparency log, no DSSE/SLSA predicate, no dependency on
  GitHub's attestations API — which is exactly why it side-steps the null-bundle bug.

---

## 5. azurerm ruleset v0.28.0 release assets & attestation status

Source (A1): `gh release view v0.28.0 --repo terraform-linters/tflint-ruleset-azurerm` +
GitHub attestations API + `checksums.txt` (curl).
URL: https://github.com/terraform-linters/tflint-ruleset-azurerm/releases/tag/v0.28.0
Published **2025-03-21T15:06:42Z**.

### PGP path — EXISTS (A1)
Assets present:
- `checksums.txt` (1648 B) and **`checksums.txt.sig` (566 B)** → the GPG/PGP detached-signature path the workaround relies on. **Present.**
- `checksums.txt.keyless.sig` (96 B) + `checksums.txt.pem` (3432 B) → cosign **keyless** signature (a GoReleaser artifact; distinct from GitHub artifact attestations).
- Platform zips for darwin/linux/windows (amd64/arm64/386/arm).
- **Signing key identity:** not exposed in asset names. TFLint verifies official rulesets against a bundled signing key; issue #2591 notes a "legacy-signing-key deprecation warning" on the PGP path. Exact key fingerprint **not verified here** — A3 (resolve via TFLint's embedded keys in `plugin/` or the ruleset's published GPG key).

### GitHub artifact attestations for v0.28.0 — ABSENT (A1, decision-critical)
- `GET /repos/terraform-linters/tflint-ruleset-azurerm/attestations/sha256:<digest>` returns
  **HTTP 404 "Not Found"** for both the v0.28.0 **zip** digest
  (`efb963655ae41741082461aeb94339056ee8b814568bcf410a248575fe76d05d`) and the **binary** digest
  (`b3f7d5c472dae9f857764ded5f0df71add815f9d673566250ef5ccbf5506172b`). → **v0.28.0 has no attestations.**
- **Boundary (A1):** first azurerm ruleset release WITH attestations is **v0.29.0** (2025-07-27):
  its zip digest returns `count: 1`. v0.30.0, v0.31.1, v0.32.0 also return `count: 1`.
  `.github/workflows/release.yml` uses `actions/attest@59d89421...` (v4.1.0) with `attestations: write`
  — this attest step post-dates v0.28.0.
- **Consequence (A2):** for `tflint-ruleset-azurerm@0.28.0` under default `signature = "auto"`,
  `tflint --init` queries the attestations API, gets 404, treats it as ignorable (issue #2591 body:
  the code path *"keeps working for 403/404"*), and falls back to PGP. **It would NOT hit the
  nil-pointer panic.** The panic needs an attestation entry with `bundle: null`, which requires an
  attested version (azurerm **v0.29.0+**, or another ruleset like `aws`).

### Temporal nuance — null-bundle is intermittent (A1 + A2)
- As of my probe **2026-07-19**, the attestations list API returns **`bundle` populated (non-null)
  AND `bundle_url` present** for azurerm v0.29.0/v0.30.0/v0.31.1/v0.32.0 (keys observed:
  `["bundle","bundle_url","initiator","repository_id"]`, `bundle_is_null: false`).
- (A2) So the `bundle: null` condition was **transient/staged** on GitHub's side around
  2026-07-16/17 (captured in PR #2593's body), and is **not reproducible today** via the list API.
  This explains the abrupt onset and equally-abrupt "it works again for some" behavior, and means a
  live repro on 2026-07-19 may NOT panic even on an attested version.

---

## 6. Confidence, gaps, and belief revisions

**CONFIRMED (A1, live primary sources):** issue/PR states, authors, dates, merge status, merge
commit, commit-ancestry into v0.64.0, v0.64.0 as fix release + no v0.63.2, `signature` attribute
values/default/introduction version, GitHub breaking-change wording, Sigstore bundle internals,
azurerm v0.28.0 asset list, v0.28.0 attestation 404, attestation boundary at v0.29.0.

**INFER (A2):** exit criterion (upgrade >= v0.64.0); `auto` doesn't prevent the panic; the
azurerm-0.28.0-would-not-panic conclusion; the intermittency interpretation.

**Could not verify (A3):** exact PGP signing-key fingerprint/identity for the azurerm ruleset;
whether the coordinator's CI truly pins azurerm 0.28.0 vs a newer/attested version or a different
ruleset (out of scope for upstream verification — needs the CI config/logs).

**Belief revision log:**
- Intake framed the bug as "azurerm 0.28.0". Live evidence shows the canonical repro is
  `aws 0.48.0` (issue #2591) and azurerm 0.28.0 has **no attestations** → cannot panic on the
  attestation path. **REVISED:** treat the ruleset/version attribution as unverified; the mechanism
  is correct but the specific "azurerm 0.28.0 panics" claim is likely inaccurate.
- Intake framed `bundle` as "now null". Live probe (2026-07-19) shows `bundle` populated again.
  **REFINED:** the null-bundle was a transient/staged GitHub API state (documented breaking change
  2026-03-10, hitting the default API version ~2026-07-16), not a permanent one.
