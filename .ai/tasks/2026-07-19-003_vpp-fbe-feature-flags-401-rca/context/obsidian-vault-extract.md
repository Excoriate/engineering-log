---
title: Obsidian vault extract — VPP FBE feature-flag 401 / per-slot App Configuration
type: research
agent: general-purpose
status: complete
source: agent
task_id: 2026-07-19-003
timestamp: 2026-07-19T00:00:00Z
summary: Vault has rich prior knowledge on FBE feature-flag 401. It is documented as a TRANSIENT, SELF-HEALING provisioning-window browser-HMAC race (catalog entry F22). NO permanent pipeline/GitOps/readiness-gate fix is documented — the fix of record is "wait for / force a frontend pod rebuild."
---

# Obsidian vault extract — FBE feature-flag 401 & per-slot App Configuration

Vault root: `$SECOND_BRAIN_PATH=/Users/alextorresruiz/Documents/obsidian`. Vault reachable (obsidian MCP). Read in full: the 4 notes cited below. Evidence: A1 = quoted verbatim from a vault note; A2 = my inference from A1; A3 = not found / blocked.

## Headline answer (read this first)

**The vault treats "FBE feature-flag 401" as a transient, self-healing provisioning-window race — NOT a bug with a permanent pipeline fix.** (A1, F22 + lesson note + June RCA all agree.) The fix of record is: **do nothing structural; wait for (or force) a frontend pod rebuild**, which re-injects a fresh `appconfig.js`. The vault explicitly warns AGAINST rotating keys, re-running App Config IaC, or granting Data roles. There is **no documented permanent remediation** (no GitOps ordering fix, no init-container re-run recipe, no readiness gate) for the 401 itself. A separate "incidental hardening" follow-up (read-only key / gateway-proxy the flag fetch) is noted but was never implemented (A1 + A3).

## Source notes (paths for the coordinator to cite)

| # | Path (relative to vault root) | What it gives |
|---|---|---|
| N1 | `llm-wiki/learnings/lessons/fbe-feature-flags-browser-direct-appconfig-per-slot-store.md` | THE canonical lesson. Mechanism, live-probe recipe, root cause, hardening finding. Maps to repo `LL-036`. |
| N2 | `2-areas/work-eneco/eneco-vpp-platform/fbe/fbe-failure-modes-catalog.md` | Failure-mode **F22** (browser-HMAC provisioning-window 401, self-heals) + **F8** (config-not-refreshed, the adjacent manual-pipeline mode) + symptom→F# matrix. |
| N3 | `.ai/tasks/2026-06-30-001_eneco-opsoftheweek-knowledge-build/evidence/fbe-cluster-digest.md` | June incident digest; the `2026_06_22_003_feature_flags_fbe_duncan` block has the exact timeline + identifiers + ApplicationSet + dependency edges. |
| N4 | `llm-wiki/learnings/lessons/eneco-appconfig-401-vs-403-caller-discrimination.md` | The 401-vs-403-vs-timeout decision rule + the three-caller/three-credential axis. |
| N5 | `.ai/tasks/2026-06-30-001_.../drafts/fbe-june-delta.md` | Dedup analysis confirming F22 is a NEW, small, self-healing mode (F8 is the opposite: stale value persists, NO self-heal). |
| N6 | `llm-wiki/patterns/workflows/argocd-helm-oci-plus-appconfig-plus-kv-csi-three-layer-config-stack.md` | Broader 3-layer config stack (ArgoCD helm OCI → KV CSI → App Config) — backend pods read App Config via MI, distinct from the browser HMAC path. |

Original incident RCA referenced by N1: `log/employer/eneco/02_on_call_shift/2026_june/2026_06_22_003_feature_flags_fbe_duncan/rca.md` (in the engineering-log repo, not the vault).

## 1. The mechanism + fix, quoted

**Mechanism (A1, N1):** "The frontend init container writes the store's **access-key connection string** into a browser-served file: `window.VUE_APP_AZ_CONFIG_CONNECTION_STRING` in `/etc/nginx/html/appconfig/appconfig.js`. The Vue SPA then calls `…/.appconfig.featureflag%2F*` **directly over HMAC** — so the 401 is visible in the browser DevTools Network tab, not in any pod log."

**Root cause (A1, N1, Jupiter Rec0BC1FTLV35):** "The 401 was a **provisioning-window credential-freshness** condition: store created 09:29Z, flags written 10:03Z, frontend RS created 10:26Z, Duncan tested ~10:49Z against a 23-minute-old pod; the healthy pod serving a valid `appconfig.js` was rebuilt at 20:17Z, after which the calls return 200. **Self-resolved.**" The store + key were healthy throughout (`disableLocalAuth=false`, keys present, CORS `*`).

**Fix (A1, N2 / F22):** "**NONE needed — wait for / force a frontend pod rebuild.** Do NOT rotate keys, re-run App Config IaC, or grant Data roles (those target the wrong store — the per-slot `vpp-appconfig-fbe-<slot>-*`, NOT shared dev-mc)."

**Live-probe recipe (A1, N1)** — identify which store the slot uses + prove the key is valid:
```bash
kubectl config use-context vpp-aks01-d          # Sandbox AKS — FBEs live here, NOT dev-mc
kubectl -n <slot> get secret application-secret \
  -o jsonpath='{.data.connectionstrings_appconfig}' | base64 -d | grep -oiE 'Endpoint=[^;]+'
CS=$(kubectl -n <slot> get secret application-secret -o jsonpath='{.data.connectionstrings_appconfig}' | base64 -d)
az appconfig kv list --connection-string "$CS" --top 1 -o table   # never echo $CS
```
Then have the user **hard-refresh** and capture the failing request in DevTools (request host = which store; `Authorization Id=`; status + `WWW-Authenticate`; `Date` skew). NOTE: `az appconfig kv list --auth-mode login` tests the **Entra arm ONLY** and **cannot reproduce the browser HMAC failure** (A1, N2/N4).

## 2. Permanent fix vs "wait it out" — explicit finding

- **Documented answer = WAIT IT OUT / self-heals.** (A1, N2 F22 `recurrence_status: active` "transient, self-heals"; N3 "Fix steps: None — self-resolved when the frontend pod rebuilt".)
- **No permanent GitOps/pipeline/readiness-gate fix is documented for F22.** (A3 — searched; `appconfig.js`/`HMAC`/`provisioning race` had "ZERO hits" outside these notes per N5. No note proposes an init-container readiness gate or ordering change for the 401.)
- **Adjacent mode F8 ("Per-FBE config not picked up after change", A1, N2)** is the closest thing to a config-pipeline fix, but it is a DIFFERENT failure (stale *value* persists, no self-heal): "Configuration applied via separate 'App Configuration FBE pipeline', not auto-triggered by every push… **Fix**: Run AppConfiguration FBE pipeline manually for the FBE; OR delete & recreate entire FBE." N5 stresses F8 is "the opposite" of F22.
- **Incidental hardening follow-up (A1, N1), never implemented (A3):** "The frontend exposes a full read/write App Config **connection string (Primary key) to the browser** via `appconfig.js`… Worth a separate follow-up (read-only key, or proxy the flag fetch through the gateway)." This is a security hardening, not the 401 fix.

## 3. Exact identifiers

| Thing | Value (A1) | Source |
|---|---|---|
| Per-slot App Config store | `vpp-appconfig-fbe-<slot>-<rand>.azconfig.io` (e.g. `vpp-appconfig-fbe-jupiter-qvc.azconfig.io`); one store per slot, random suffix per creation | N1, N3 |
| Resource group | `rg-vpp-app-sb-401` (shared by all FBEs; sub `7b1ba02e-…`) | N1, N3 |
| AKS cluster / context | `vpp-aks01-d` (Sandbox; direct kubectl, no AVD) | N1, N3 |
| Namespace | `<slot>` (e.g. `jupiter`) | N1 |
| Browser-served file | `/etc/nginx/html/appconfig/appconfig.js` | N1, N2 |
| Browser JS global | `window.VUE_APP_AZ_CONFIG_CONNECTION_STRING` | N1, N2 |
| Browser call path | `…/.appconfig.featureflag%2F*` over HMAC (`WWW-Authenticate: HMAC-SHA256, Bearer`) | N1, N2, N3 |
| In-cluster secret holding the connection string | `application-secret`, key `connectionstrings_appconfig` | N1 |
| ApplicationSet (GitOps) | `vpp-feature-branch-environments` → `<slot>-app-of-apps` (ns `argocd`) → ~21 child Applications; `frontend` child serves `/` | N3 |
| Create / delete pipelines | create **2412**, delete **2629** | N3 |
| Init container | Named only as "the frontend init container" — **NO specific container name is recorded in the vault** (A3). | N1, N2, N3 |
| Wrong store to NOT chase | shared dev-mc `vpp-applicationconfig-d` (private-endpoint-only, AVD-gated) | N1, N4 |
| Example real flag returned on 200 | `AdditionalAssetPlanningSeries` | N3 |

## 4. WHY the frontend pod serves a stale appconfig.js + how a pipeline/GitOps change could avoid the manual delete

**WHY (A1, N1/N3):** `appconfig.js` is generated **once, by the init container, at pod start**, then served statically by nginx. If the pod initialised during the provisioning window — before the per-slot store/key had fully settled — it captured a stale/invalid connection string into `appconfig.js`, and nginx keeps serving that same file until the pod is rebuilt. Nothing re-reads or refreshes the file mid-life. Timeline proof: store 09:29Z → flags 10:03Z → frontend pod ~10:26Z, tested 10:49Z (23-min-old stale pod) → pod rebuilt 20:17Z → 200. So the "manual pod delete" works because it forces a fresh init-container run against the now-settled store.

**How it could be avoided (A2 — my inference from the A1 mechanism; NOT documented as implemented in the vault):**
- Add a **readiness/ordering gate** so the frontend init container writes `appconfig.js` only after the per-slot App Config store + access key are provably live (init-container probe against the HMAC endpoint; retry/fail-fast until 200) — closes the window instead of relying on a later rebuild.
- Or make the ApplicationSet/app-of-apps sequence the **frontend child to sync AFTER** the App Config store + flag-write pipeline complete (dependency ordering), so the pod never initialises against an unsettled store.
- Or the N1 hardening direction: **proxy the flag fetch through the gateway** (server-side, re-fetchable) with a **read-only key**, removing the browser's dependence on a build-time static `appconfig.js` entirely.

These are candidate remediations consistent with the documented mechanism; the vault's own position remains "transient, self-heals, do not over-engineer."

## Caveats / blocked

- **A3 — init-container name unknown.** The vault consistently says "the frontend init container" with no container name; not recoverable from these notes.
- **A3 — no permanent-fix note exists.** The dedup pass (N5) confirms F22 was filed precisely because it was a *new, small, self-healing* mode; no runbook prescribes a structural fix. Any "permanent fix" the coordinator wants to propose is net-new engineering, not a retrieval from the vault.
- The `fbe/` and `fbe-errors/` folders live under `2-areas/work-eneco/eneco-vpp-platform/`, NOT under `llm-wiki/` (the task brief's assumed location). `fbe-errors/_index.md` catalogues delete-pipeline/finalizer/PAT failure classes — none is the feature-flag 401 (that lives in `fbe/fbe-failure-modes-catalog.md` F22).
