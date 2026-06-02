---
task_id: 2026-06-02-002
agent: claude-opus-4-8
status: partial
summary: Topology + auth findings for vpp-agg-sb Kafka cert retrieval (dev/test). Evidence-labeled.
timestamp: 2026-06-02
---

# Topology & Auth Findings — vpp-agg-sb Kafka certs (dev/test)

## The Request (verbatim, from slack-intake.md)

> "Can you provide us the Kafka certificate for dev and test. We tried to read the PEM content from key vault. it looks like it is not in good format."
> Keyvault: `vpp-agg-sb.vault.azure.net`
> Keys: `kafka-cacert`, `kafka-clientcert`, `kafka-sslkey`
> "Dev and Test, means you have to get this information from the MC Dev, and MC Test environments."

Mandated skills: `eneco-context-repos`, `eneco-context-docs`, `eneco-tools-connect-mc-environments`.
Explicit op note: turn OFF whitelisting after the task (drift prevention).
UAC: (1) certs downloaded into this repo first; (2) final `how-to-feynman` explainer doc.

## Evidence Ledger

| # | Label | Claim | Source |
|---|-------|-------|--------|
| E1 | A1 FACT | `az` logged in as `Alex.Torres@eneco.com`; default sub = `sub-cf-lz-tradeplatform-iactest-401` (`aaf82ea7-...`) | `az account show` |
| E2 | A1 FACT | `AZURE_DEVOPS_PAT` is set (len 84) → ADO API reachable | `printenv` presence check (value NOT printed) |
| E3 | A1 FACT | No "VPP Test" subscription exists. VPP = Development/Acceptance/Production only. A "Test" sub exists only for Workload **BTM** (`Eneco MCC - Test - Workload BTM`). | `az account list` |
| E4 | A1 FACT | Sandbox sub is named `Eneco Cloud Foundation - Sandbox-Development-Test` (dev+test combined). | `az account list` |
| E5 | A2 INFER | `vpp-agg-sb` KV → "sb" = Sandbox per identity map (`savppftobootstrapsb`, `rg-vpp-app-sb-401`, SA suffix `sb`). So the KV likely lives in the Sandbox sub, possibly serving both dev+test. | identity map `mc-environments.md:13-24` + name pattern |
| E6 | A1 FACT | MC-VPP-Infrastructure repo = FleetOptimizer (FTO) infra (`savppftobootstrap*`); does NOT define `vpp-agg-sb`. The Aggregation Layer has separate IaC (repo TBD). | `eneco-platform-mc-vpp-infra/SKILL.md` |
| E7 | A1 FACT | MFA expired (`AADSTS50078`) on ARM/Resource-Graph calls → interactive `az login` refresh required (user action). | `az graph query` error |
| E8 | A1 FACT | Whitelist aliases key on operator public IP and cover storage + KV + SQL; whitelist-off removes that IP rule. Concurrency hazard if another agent shares this public IP on the same MC env. | `mc-environments.md:133-151` |

## Open Questions (route-flip)

1. **Env mapping**: what does requester's "MC Test" mean for a `vpp-agg` (VPP-prefixed) component when no VPP Test sub exists? Candidates: Sandbox (dev+test in one), VPP Dev+Acc, or BTM Dev+Test. → resolve empirically post-login (locate the real KV + siblings), else confirm with user.
2. **Secret encoding (the actual bug)**: why does the stored PEM look "not in good format"? Hypotheses (to confirm by inspecting KV secret `contentType`/`tags`/raw value, read-only):
   - H-FMT-1: stored base64-encoded (double-encoded) → needs `base64 -d`.
   - H-FMT-2: stored fine, mangled on portal copy (newlines collapsed / shown single-line).
   - H-FMT-3: stored as KV **certificate** object → reading the secret returns PKCS#12/PFX (base64 DER), not PEM.
   - H-FMT-4: literal `\n` escape sequences (JSON-encoded at write time via a `keyvaultsecret` TF module).
3. **Private-key persistence**: `kafka-clientcert` + `kafka-sslkey` are private keys; repo is Dropbox-synced + target folder NOT gitignored (`git check-ignore` confirms). How to persist safely.

## Connection plan (pending env confirmation + login refresh)

- Locate `vpp-agg-sb` (control-plane, read-only): per-sub `az keyvault show -n vpp-agg-sb` or Resource Graph once MFA refreshed.
- Retrieve secrets: `az keyvault secret show` (data-plane) — may require IP whitelist if KV has network ACLs. Read values into `/tmp` ONLY; never echo private-key values into the transcript or non-/tmp files.
- Diagnose format with `openssl x509 -noout -text` (certs) / `openssl pkey -noout` (key) / `base64 -d` probes.
- whitelist-OFF + logout + cleanup at task end (H-FINALLY) — even on failure.
