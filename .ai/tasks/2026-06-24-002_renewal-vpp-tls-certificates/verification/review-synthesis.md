---
title: Adversarial review synthesis + receipts — PROD wildcard TLS rotation
task_id: 2026-06-24-002
agent: claude-opus-4-8
status: complete
summary: Consolidates socrates + el-demoledor + sre-maniac reviews into classified receipts (RESOLVE/REBUT/DEFER). Key outcome — el-demoledor V4 CONFIRMED by Microsoft docs (empty AGW update does NOT refresh the cert); draft force-propagation rewritten. Prod scope completeness closed (only consumer = vpp-ag-p). Cross-sub completeness DEFERRED as bounded low-risk.
timestamp: 2026-06-24T00:00:00Z
---

# Adversarial Review Synthesis — Receipts

Three typed reviewers (socrates-contrarian, el-demoledor, sre-maniac) attacked scope + spec on distinct lanes. Their output was INFER until source-verified below. Microsoft Docs MCP used to settle el-demoledor's two THEORETICAL findings.

## Source verification of THEORETICAL findings (the coordinator's job)

- **V4 — CONFIRMED (Microsoft docs, A1)**: `learn.microsoft.com/troubleshoot/azure/application-gateway/troubleshoot-application-gateway-key-vault-certificate#resolution-e` — "Application Gateway refetches the certificate from Key Vault only when the configured `keyVaultSecretId` changes. If you reapply the same versionless secret URI or run an empty `az network application-gateway update` command, the action finishes successfully but doesn't force the gateway to pull the newer Key Vault version." → the draft's empty-update force-refresh is INEFFECTIVE. Documented force = repoint to versioned URI, then back to versionless.
- **Versionless polling (A1)**: `key-vault-certs` doc — AGW polls KV every 4h on a versionless secret id and auto-rotates. So even without a force, the new version is picked up within ~4h.
- **Listener auto-disable (A1)**: `application-gateway-key-vault-common-errors` — "If your Application Gateway can't fetch the certificate, it disables the associated HTTPS listeners." → confirms rollback must always leave a resolvable+enabled version (sre-maniac R2/R6).
- **V5 resolution (A2, doc-aligned)**: KV secret GET without version returns the latest **enabled** value; doc says "ensure the certificate's status is Enabled." Rollback redesigned to **repoint AGW to the OLD versioned URI** (a `keyVaultSecretId` change that forces an immediate, deterministic re-pull) — this sidesteps reliance on disable/resolution timing.

## Receipts

| ID | Finding | Class | Evidence / spec change |
|----|---------|-------|------------------------|
| SOC-F1 | AGW-only enumeration blind to non-AGW consumers | **RESOLVE (prod)** | Ran Resource-Graph sweep in prod sub: `count=0` for frontdoors/cdn/apim/web-sites/AKS; only 1 AGW (`vpp-ag-p`). Prod has a single consumer. |
| SOC-F2 | Sandbox sub `7b1ba02e` never enumerated | **DEFER** | Cross-sub needs multi-sub identity (SP is prod-scoped). Bounded low-risk: dev/acc pattern = env-specific wildcards (`*.dev-mc`, `*.acc`) + Kafka mTLS (`esp-eet-vpp`), not `*.vpp.eneco.com`. Condition to revisit: before claiming ORG-wide completeness, run the cross-sub sweep as the user (offered). NOT blocking for the prod rotation. |
| SOC-F3 | 7 single-label hosts, 4 mapped | **RESOLVE (prod)** | All prod `*.vpp.eneco.com` listeners on `vpp-ag-p` resolve to `wildcard-vpp-eneco-com`. The other hosts (`dev/dev-mc/acc/iactest/sandbox/sb`) are other envs → DEFER per F2. |
| SOC-F4 | Apex exclusion correct but spec internally inconsistent | **RESOLVE** | User decision: **wildcard only**. Final spec states apex out unambiguously (no "open" contradiction). |
| SOC-F5 | SP-visible ≠ human-visible | **REBUT (mostly)** | The prd SP holds cert `Get`+`List`+`Import` (verified, context/02 §5) → its inventory read is authoritative for listing. Residual (a human-only-visible object) is low; folded into F2's optional human-identity re-confirm. |
| SRE-R1 | Schedule ≤ Jun 27 (old dies Jul 1) | **RESOLVE** | Spec adds hard scheduling gate + "post-Jun-29 = fix-forward-only". |
| SRE-R2 | Rollback must keep an enabled resolvable version | **RESOLVE** | Rollback redesigned (repoint to OLD versioned URI); pre-stage step added. |
| SRE-R3 | GO needs handshake-level served-cert witness | **RESOLVE** | Spec adds tiered witness: AVD openssl (primary) OR public `gurobi.vpp.eneco.com` handshake (same shared cert) + control-plane confirm; **NO-GO if no handshake path**. |
| SRE-R4 | No in-flight prd terraform apply during window | **RESOLVE** | Precondition added (check open prd PRs / ADO env; `trigger:none` confirmed so no auto-apply). |
| SRE-R5 | `$MYIP` once + loud-fail residual | **RESOLVE** | Merged with V8. |
| SRE-R6 | Watch AGW Resource Health live | **RESOLVE** | Monitoring step added. |
| SRE-R7 | Don't delete/recreate listener as refresh | **RESOLVE** | Noted; force = versioned-toggle only. |
| SRE-R8 | Apex separate window | **RESOLVE** | User: wildcard only; apex deferred to its own pre-Jul-20 window. |
| DEM-V1 | Step 2.1 re-encode premise misplaced (client never parses PFX) | **RESOLVE** | Reframed: import ORIGINAL bytes; re-encode only if KV SERVICE returns a parse error (HTTP 400). |
| DEM-V2 | `$NEWPW` unset across paste-blocks | **RESOLVE** | Guard `: "${NEWPW:?}"`; spec is one trapped script. |
| DEM-V3 | Thumbprint compare case-sensitive | **RESOLVE** | Normalize both sides via `tr A-Z a-z` (steps 4/6/8). |
| DEM-V4 | Empty AGW update doesn't refresh | **RESOLVE (doc-confirmed)** | Force-refresh rewritten to versioned-URI repoint → verify → restore versionless. |
| DEM-V5 | Rollback resolution unconfirmed | **RESOLVE** | Rollback = repoint to OLD versioned URI (deterministic) + pre-staged baseline; no reliance on disable timing. |
| DEM-V6 | Password in `ps` argv; newline latent | **DEFER** | Accept on single-operator laptop; add length assertion (`[ ${#PW_VAL} -eq 12 ]`) to catch newline contamination. Condition: if run on shared host, revisit. |
| DEM-V7 | Verify-after-live ordering | **RESOLVE** | Import with `--disabled`; verify thumbprint; then `--enabled true`; then force-refresh. Gate runs before exposure. |
| DEM-V8 | `$MYIP` empty / `contains('')` / fake finally | **RESOLVE** | `${MYIP:?}` guard; exact-match `?value=='${MYIP}/32'`; real `trap … EXIT`. |
| OR-1 | Terraform drift | **RESOLVE** | No `azurerm_key_vault_certificate` (cert not TF-managed); AGW binding versionless → import causes no plan diff (context/03). |

## Gate status

- Systematic-Defer check: 3 DEFER of 20 (F2, F5-partial, V6) — all bounded low-risk with named revisit conditions; no DEFER on a BLOCKING/HIGH finding. PASS.
- Rebut-without-evidence check: F5 REBUT backed by the verified SP permission set. PASS.
- All HIGH findings RESOLVED with concrete spec changes. Spec is cleared to finalize for GO/NO-GO (subject to the user's go).
