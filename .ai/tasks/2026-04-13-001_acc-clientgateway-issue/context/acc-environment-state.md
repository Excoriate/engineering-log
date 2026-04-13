---
task_id: 2026-04-13-001
agent: acc-env-checker
status: draft
summary: ACC environment state check results
---

# ACC Environment State Check Results

**Date**: 2026-04-13
**Investigator**: acc-env-checker (Claude Code agent)
**Incident**: ClientGateway ArgoCD sync failure due to erased Helm values-override.yaml version

---

## 1. Azure CLI Authentication

**Status: NOT AUTHENTICATED**

- `az account show` returns: `Please run 'az login' to setup account.`
- Azure profile (`~/.azure/azureProfile.json`) has empty subscriptions: `{"subscriptions": []}`
- MSAL token cache exists (27KB, last modified 2026-04-12 21:05) but session is expired
- 1Password CLI (`op`) is installed (v2.33.1) but **not signed in**: `account is not signed in`
- VPP credential env vars (`_VPP_DTA_KV_APP_ID`, `_VPP_DTA_KV_SECRET`, `_VPP_MGMT_SUB_DTA`) are NOT set

**Available login functions** (require interactive auth):
- `enecotfvppmcloginacc` -- uses 1Password (`op`) to fetch "ARM Creds VPP MC Acceptance"
- `enecotfvppmcacc` -- uses env vars (SP credentials) for direct login

**ACC Azure Subscription**: `b524d084-edf5-449d-8e92-999ebbaf485e`
**ACC Tenant**: `eca36054-49a9-4731-a42f-8400670fc022`
**ACC Resource Group (network)**: `mcdta-rg-vpp-a-network-jyfc`
**ACC MC Landing Zone RG**: `mcc-rg-vpp-a-network-zkol`

---

## 2. AKS / ArgoCD State

**Status: NO ACCESS TO ACC CLUSTER**

- kubectl contexts available: `vpp-aks01-d` (dev sandbox only), `docker-desktop`, `rancher-desktop`
- **No ACC AKS context** configured in kubeconfig
- ArgoCD CLI installed (v3.3.6) with cached config for `argocd.dev.vpp.eneco.com` (sandbox only)
- Cannot check ArgoCD application state without cluster access

**Conclusion**: Live ArgoCD state cannot be verified. Diagnosis is based on gitops repository state (see Section 5).

---

## 3. App Configuration / Key Vault

**Status: NOT ACCESSIBLE** (no Azure auth)

- ACC Key Vault (from gitops config): `kv-vppcre-bootstrap-a` in RG `rg-vppcre-bootstrap-a`
- ACC Container Registry: `vppacra.azurecr.io`
- ClientGateway image path: `vppacra.azurecr.io/eneco-vpp/clientgateway`

---

## 4. Recent Activity (from Git)

**Status: CONFIRMED ISSUE VIA GIT**

Successfully fetched latest from VPP-Configuration remote via HTTPS+PAT.

### The Breaking Commit

| Field | Value |
|-------|-------|
| **Commit** | `25d008a143a240d7b254582c803a9a096237bd11` |
| **Message** | `build 20260413.1` |
| **Author** | `azurepipelines <azurepipeline@eneco-myriad.com>` |
| **Date** | 2026-04-13 07:34:17 UTC |
| **Effect** | Erased clientgateway image tag to empty string for ACC and DEV |

**Diff for clientgateway:**
```diff
# ACC: Helm/clientgateway/acc/values-override.yaml
 image:
-  tag: "0.144.0"
+  tag: ""

# DEV: Helm/clientgateway/dev/values-override.yaml
 image:
-  tag: "0.145.0"
+  tag: ""
```

**Same commit correctly updated other services:**
- asset ACC: `0.144.1` -> `0.145.0` (correct)
- frontend ACC: `0.144.0` -> `0.145.0` (correct)
- monitor ACC: `0.144.0` -> `0.145.0` (correct)
- All other services: updated correctly to `0.145.0`

### Previous Successful ClientGateway Update

| Field | Value |
|-------|-------|
| **Commit** | `bf24ca198` |
| **Message** | `Updated image tag for clientgateway to 0.145.0` |
| **Date** | 2026-04-10 08:14:47 UTC |
| **Effect** | Updated DEV only from `0.144.0` to `0.145.0` |

---

## 5. Current State of ALL Services (Remote HEAD)

### ACC Environment

| Service | Image Tag | Status |
|---------|-----------|--------|
| activationmfrr | 0.145.0 | OK |
| asset | 0.145.0 | OK |
| assetmonitor | 0.145.1 | OK |
| assetplanning | 0.145.0 | OK |
| **clientgateway** | **""** | **BROKEN** |
| dataprep | 0.145.0 | OK |
| dispatcherafrr | 0.145.0 | OK |
| dispatchermanual | 0.145.0 | OK |
| dispatchermfrr | 0.145.0 | OK |
| dispatcherscheduled | 0.145.0 | OK |
| dispatchersimulator | 0.145.0 | OK |
| frontend | 0.145.0 | OK |
| integration-tests | 0.145.0 | OK |
| marketinteraction | 0.145.0 | OK |
| monitor | 0.145.0 | OK |
| telemetry | 0.145.0 | OK |
| tenant-gateway | "" | Pre-existing (never deployed to ACC) |

### DEV Environment

| Service | Image Tag | Status |
|---------|-----------|--------|
| **clientgateway** | **""** | **BROKEN** |
| All other services | 0.145.0 | OK |

### PROD Environment

| Service | Image Tag | Status |
|---------|-----------|--------|
| clientgateway | 0.144.0 | OK |

### SANDBOX Environment

| Service | Image Tag | Status |
|---------|-----------|--------|
| clientgateway | 0.145.dev.6c4e74e | OK |

---

## 6. Release Configuration State

From `Release/release-version.yaml` (remote HEAD):
```yaml
variables:
  release_version: "0.145"
  dev_version: "0.146"
  test: "true"
  acc: "false"    # ACC deployments DISABLED
  prod: "false"   # PROD deployments DISABLED
```

**Note**: ACC deployment is currently disabled in the release trigger.

---

## 7. Root Cause Analysis

### Mechanism

The build pipeline (`build 20260413.1`) runs a batch update of image tags in VPP-Configuration for all services. For clientgateway, the pipeline failed to determine the correct version to set, resulting in an empty string being written to both ACC and DEV `values-override.yaml` files.

All other services in the same commit were correctly updated to `0.145.0`, confirming the pipeline logic specifically failed for clientgateway.

### Expected Versions (pre-incident)

- **ACC clientgateway**: `0.144.0` (should remain or be updated to `0.145.0`)
- **DEV clientgateway**: `0.145.0` (should remain at `0.145.0`)

### Impact

1. ArgoCD reads `values-override.yaml` from VPP-Configuration repo
2. Empty `image.tag: ""` causes Helm to render an invalid or missing image reference
3. ArgoCD sync fails because Kubernetes cannot pull the container image
4. **Both ACC and DEV** environments affected
5. PROD is unaffected (tag remains `0.144.0`)

---

## 8. Immediate Fix Options

### Option A: Direct Git Fix (Recommended)
Push a commit to VPP-Configuration/main restoring the correct tags:
```yaml
# ACC: Helm/clientgateway/acc/values-override.yaml
image:
  tag: "0.145.0"

# DEV: Helm/clientgateway/dev/values-override.yaml
image:
  tag: "0.145.0"
```

### Option B: Re-run Pipeline
Investigate why the build pipeline wrote an empty tag for clientgateway and fix the pipeline logic, then re-run.

### Option C: Rollback
Revert commit `25d008a14` -- but this would also revert all OTHER services back to their pre-0.145.0 versions.

**Recommendation**: Option A is safest -- surgically fix only the broken clientgateway tags.

---

## 9. Investigation Limitations

- **No live Azure/AKS access**: Could not verify actual ArgoCD application state, pod status, or deployment events
- **Local VPP-Configuration repo is stale**: Local copy was at Nov 2025 state; used `git fetch` + `git show FETCH_HEAD:` to inspect remote state
- **Pipeline source not fully traced**: The exact script/task within the CD pipeline that writes image tags was not inspected (it runs in Azure DevOps, not locally accessible)
- **SSH key not configured**: Had to use HTTPS+PAT fallback for git operations
