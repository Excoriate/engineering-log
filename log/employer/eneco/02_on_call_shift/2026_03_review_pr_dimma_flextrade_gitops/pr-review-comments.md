# PR Review: feat(816448) — Configurations for dev-mc, acc and prod

**PR**: [#169088](https://dev.azure.com/enecomanagedcloud/VPP%20-%20Asset%20Optimisation/_git/flex-trade-optimizer-gitops/pullrequest/169088)
**Author**: Ivanchyshyn, D (Dmytro)
**Branch**: `feature/816448-add-configuration-for-upper-environments` -> `main`
**Scope**: 24 new files — Helm values for frontend, gateway, solver across dev, acc, prd environments

---

## Summary

The service-level values files are well-structured and follow the established sandbox pattern for ACR registries, AppConfig endpoints, and ingress hosts. However, there are items that need attention before merging — one likely copy-paste error in identity configuration, and questions about completeness of the deployment chain.

---

## Comments

### 1. CRITICAL — Solver `AZURE_CLIENT_ID` is identical for dev and acc

**Files**:
- `services/solver/dev/values.yaml` — `AZURE_CLIENT_ID: a9bed5e6-0ee4-48f3-a40e-80a2bcc0ec73`
- `services/solver/acc/values.yaml` — `AZURE_CLIENT_ID: a9bed5e6-0ee4-48f3-a40e-80a2bcc0ec73`

**Evidence**: Every other service has unique Client IDs per environment:
- Gateway: dev=`2d2be79e`, acc=`8025ef67`, prd=`ecc68805` (all unique)
- Frontend MSAL: dev=`6474428c`, acc=`2263b5a2`, prd=`b3651f39` (all unique)
- Solver prd=`5040750d` (different from dev/acc)

Additionally, the AppConfig endpoints differ between environments (`appconfig-fto-d` vs `appconfig-fto-a`), which means these are intended to be separate environments with separate identities.

**Action**: Please verify whether the acc solver should have a different `AZURE_CLIENT_ID`. If dev and acc genuinely share an app registration, this should be documented with a comment explaining why. Otherwise, update acc with the correct Client ID.

---

### 2. QUESTION — Missing `app-of-apps/values.{dev,acc,prd}.yaml`

**Evidence**: The feature branch file listing (via Azure DevOps Items API) shows only `app-of-apps/values.sandbox.yaml` and `app-of-apps/values.yaml`. No `values.dev.yaml`, `values.acc.yaml`, or `values.prd.yaml` exist.

The sandbox environment is deployed because `values.sandbox.yaml` defines the ArgoCD `Application` resources that reference the service values files:
```yaml
# app-of-apps/values.sandbox.yaml
apps:
  - name: frontend
    chart:
      valueFiles:
        - $values/services/frontend/sandbox/values.yaml
        - $values/services/frontend/sandbox/values-static-configuration.yaml
        # ...
```

Without equivalent files for dev/acc/prd, ArgoCD has no Application manifests pointing to the new service configs.

**Action**: Is this intentional phasing (app-of-apps values coming in a follow-up PR)? If so, consider noting this in the PR description. If these are meant to be included, they are missing from this PR.

---

### 3. QUESTION — Missing `secretprovider/overlays/{dev,acc,prd}/`

**Evidence**: The feature branch only has `secretprovider/overlays/sandbox/`. The base `secretproviderclass.yaml` has empty placeholders:
```yaml
# secretprovider/base/secretproviderclass.yaml
spec:
  parameters:
    keyvaultName: ""
    resourceGroup: ""
    subscriptionId: ""
    userAssignedIdentityID: ""
```

The sandbox overlay fills these with environment-specific values (`kv-fto-sb`, `rg-vpp-app-sb-401`, etc.). Gateway and solver pods reference `secret-provider-flex-trade-optimizer-keyvault` in their volume mounts, meaning they depend on a properly configured SecretProviderClass to access Key Vault secrets.

**Action**: Same question as above — are these planned for a follow-up, or should they be included here?

---

### 4. OBSERVATION — All `values-override.yaml` files have empty image tags

**Files**: All 8 `values-override.yaml` files (dev/acc/prd for all 3 services) contain:
```yaml
image:
  tag: ""
```

This is consistent with the pattern where CI/CD pipelines update the tag during deployment. Just confirming this is the expected initial state for environments that haven't received their first deployment yet.

---

### 5. OBSERVATION — Production `replicaCount: 1`

**Files**: All `prd/values.yaml` files have `replicaCount: 1`.

This is fine for initial setup, but worth flagging: before production traffic, this should be increased for high availability (at minimum 2 replicas for zero-downtime deployments).

---

### 6. OBSERVATION — No PR description

The PR description field is empty. For a change touching production infrastructure across 3 environments and 3 services (24 files), a brief description of the deployment plan and any prerequisites (Key Vault setup, app registrations, ArgoCD project configuration) would help reviewers.

---

## What Looks Good

- **ACR registries** correctly follow the naming convention: `vppacrd` (dev), `vppacra` (acc), `vppacrp` (prd)
- **AppConfig endpoints** are correctly environment-specific: `appconfig-fto-d`, `appconfig-fto-a`, `appconfig-fto-p`
- **Ingress hosts** correctly use `dev-mc.vpp.eneco.com`, `acc.vpp.eneco.com`, `vpp.eneco.com` (prd)
- **Frontend API scopes** correctly reference the gateway's `AZURE_CLIENT_ID` per environment
- **Frontend MSAL redirect URLs** correctly match their environment's ingress host
- **Frontend BASE_URL** correctly routes through `/api/gateway` path on the main domain for all new envs
- **Gateway `AzureAdAuthentication__TenantID`** is present in all gateway configs (consistent with sandbox pattern)
- **Solver ingress disabled** in all envs (consistent with sandbox — solver is internal-only)

---

## Branch Policy Recommendation

Currently, `main` branch has these policies:
1. All PR comments must be resolved
2. Work item linking required
3. Minimum 1 reviewer (creator vote doesn't count)
4. Required reviewer: `asset-optimization-backend-engineers`

**Missing**: No build validation policy (CI/CD pipeline gate) and no platform team in required reviewers.

For a gitops repo that controls deployments to dev, acc, and production:
- **Recommend adding a build validation policy** — at minimum YAML lint / Helm template validation
- **Recommend adding platform team as optional/required reviewer** for changes touching production environment configurations or secretprovider manifests
