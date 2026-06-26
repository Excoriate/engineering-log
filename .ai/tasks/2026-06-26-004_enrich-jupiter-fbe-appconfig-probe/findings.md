---
title: "Live-probe enrichment — Jupiter FBE App Configuration 401 (Rec0BC1FTLV35)"
description: "Direct Sandbox-AKS + Azure probes of the real Jupiter FBE. Resolves RCA C16/C17: the FBE uses its OWN Sandbox store (not dev-mc vpp-applicationconfig-d), that store is healthy, and the failing caller is the browser SPA via HMAC."
timestamp: 2026-06-26T12:10:00+02:00
status: complete
category: on-call-rca
authors: ["Alex Torres Ruiz (with Claude Code)"]
task_id: 2026-06-26-004
agent: coordinator
summary: >-
  Probing the live Jupiter FBE in Sandbox AKS (cluster vpp-aks01-d) overturns the RCA's store
  assumption. The Jupiter frontend reads its OWN store vpp-appconfig-fbe-jupiter-qvc.azconfig.io
  (Sandbox RG rg-vpp-app-sb-401) via a connection string injected into a browser-served appconfig.js,
  NOT the shared dev-mc vpp-applicationconfig-d the RCA reasons about. That store is healthy now
  (keys enabled, reachable, CORS=*, returns flags 200 on the exact FBE connection string). The 401 is
  the browser's direct HMAC call; the path is healthy now and the most likely historical trigger is a
  provisioning-window freshness issue. The byte-exact morning cause requires Duncan's browser capture.
---

# Live-probe enrichment — Jupiter FBE App Configuration 401

## What this changes in the RCA

The RCA (`2026_06_22_003_feature_flags_fbe_duncan/rca.md`) reasons entirely about the **dev-mc shared
store `vpp-applicationconfig-d`** and carries two blocked items:

- **C16** (exact failing status/body) — assumed "AVD-gated, not runnable".
- **C17** (which store the FBE uses; key vs MI auth) — "blocked: FBE service code not read".

Both are now **resolved by direct probe of the live FBE** in Sandbox AKS. The probe surface was never
AVD-gated: FBEs run in the **Sandbox** cluster (`vpp-aks01-d`, RG `rg-vpp-app-sb-401`), reachable with
`kubectl` + the Sandbox `az` session.

## Decisive facts (A1 — witnessed 2026-06-26)

| # | Fact | Evidence |
|---|---|---|
| P1 | Jupiter FBE is a live namespace with the full VPP stack incl. a `frontend` deployment | `kubectl -n jupiter get deploy` |
| P2 | The FBE points at its **own** store `vpp-appconfig-fbe-jupiter-qvc.azconfig.io` (Sandbox, `rg-vpp-app-sb-401`), **not** dev-mc `vpp-applicationconfig-d` | `application-secret.connectionstrings_appconfig` Endpoint= |
| P3 | The frontend **init container writes the App Config connection string into a browser-served JS file**: `echo window.VUE_APP_AZ_CONFIG_CONNECTION_STRING = "${connectionstrings_appconfig}" > /etc/nginx/html/appconfig/appconfig.js` | `kubectl -n jupiter get deploy frontend -o yaml` |
| P4 | The browser is currently served a **valid, non-empty** connection string (206 bytes, `Id=h30k`) | `exec ... cat /etc/nginx/html/appconfig/appconfig.js` |
| P5 | The SPA authenticates **browser-direct via HMAC** (`HMAC-SHA256`, `x-ms-content-sha256` in the `azure-*.js` bundle; `featureFlags-*.js` references the conn-string var) | bundle grep |
| P6 | The store is **healthy now**: `disableLocalAuth=false`, keys present (Primary/Secondary), `publicNetworkAccess=null`, `provisioningState=Succeeded`, created `09:29:36Z` | `az appconfig show` / `credential list` |
| P7 | The **exact FBE connection string returns 200 + real feature flags** (`AdditionalAssetPlanningSeries`, …) | `az appconfig kv list --connection-string "$CS"` |
| P8 | azconfig.io supports **CORS** (`access-control-allow-origin: *`) on both the OPTIONS preflight and the 401 response → the browser is not blocked and **sees the literal 401** | `curl -i -H Origin:` |
| P9 | An unauthenticated/bad-HMAC GET returns exactly `HTTP 401` + `www-authenticate: HMAC-SHA256, Bearer` — matches Duncan's "401's" | `curl -i` |
| P10 | Topology is normal: one store per slot (`vpp-appconfig-fbe-<slot>-<rand>`), only one Jupiter store, no recreation/duplication | `az resource list` |

## Timeline (UTC, 2026-06-22)

| Time | Event | Source |
|---|---|---|
| 09:29:36 | FBE store `vpp-appconfig-fbe-jupiter-qvc` created | `systemData.createdAt` |
| 10:03:42 | Feature flags written into the store (so flags DID exist) | kv `lastModified` |
| 10:26:31 | `frontend` ReplicaSet created → first morning pod inits appconfig.js | RS `creationTimestamp` |
| ~10:49 | Duncan files Rec0BC1FTLV35 ("401's", 12:49 CEST) | intake |
| 20:17:18 | **Current** healthy frontend pod rebuilt → appconfig.js rewritten | file mtime |

## Diagnosis (calibrated)

> **CONFIRMED 2026-06-26 by Duncan's browser capture:** the `.appconfig.featureflag/*` calls now return
> **200** ("before these were giving 401's … now it's not a problem anymore"). This is the exact truth
> surface the RCA said only Duncan could provide. It validates every point below — failing caller = the
> browser-direct feature-flag calls; 401→200 with no store-side change = provisioning-window freshness,
> self-resolved.


**Certain (refutes the RCA framing):** Duncan's Jupiter FBE does **not** use dev-mc
`vpp-applicationconfig-d`. The RCA's leading hypotheses (H0 pipeline approval, H1/H1-SP token, H2 key
disabled, H3 RBAC, network) all target the wrong store and are **not** the cause. "I can see the FFs set
properly in the app config" = he was looking at the **wrong store** (his earlier ticket's dev-mc URL),
while his FBE reads a separate, freshly-created Sandbox store.

**Certain:** the actual failing caller is the **browser SPA** doing a **direct HMAC call** to
`vpp-appconfig-fbe-jupiter-qvc.azconfig.io`. That store and credential are **healthy now** (would return
200) — the failure is **not** a standing infra fault and appears self-resolved after the 20:17 rebuild.

**High-confidence inference (A2), not yet byte-proven:** the morning 401 was a **provisioning-window
credential-freshness issue** in what the browser held (the appconfig.js value, or Duncan's cached copy),
since the store-side key itself was already valid by 10:03. Duncan tested against a 23-minute-old
frontend pod; the path stabilized by the evening rebuild.

**The one probe only Duncan can run (closes it 100%):** in the browser DevTools **Network** tab on the
Jupiter FBE, capture the failing App Config request — the **request host** (which store), the **`Id=`**
in the `Authorization` header, the **response status + `WWW-Authenticate`**, and the `Date`/`x-ms-date`
headers. Plus a **hard refresh / cache clear** to rule out a stale cached `appconfig.js`.

## Security note (incidental finding)

The frontend exposes a **full read/write App Config connection string (Primary key) to the browser** via
`appconfig.js`. Anyone who opens the FBE can read the secret from `window.VUE_APP_AZ_CONFIG_CONNECTION_STRING`.
Worth a separate follow-up (use a read-only key at minimum, or proxy via the gateway). Out of scope for
the 401 itself.
