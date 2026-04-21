---
task_id: 2026-04-21-001
agent: claude-code
status: complete
summary: Durable runbook — three-plane check for "access works in env A, not env B" ArgoCD tickets at Eneco.
---

# Lesson — ArgoCD "works env A, not env B" = three-plane alignment problem

When an engineer reports ArgoCD access missing in one environment and present in another, **always check three planes in order**:

1. **AAD group membership** (Azure AD). `az ad group member check --group <name> --member-id <user-object-id>` → must return `true`. Self-service PR in `Eneco.Infrastructure/terraform/platform/aad/` typically handles this.

2. **Enterprise App assignment** (Azure AD → Graph API). With `groupMembershipClaims: ApplicationGroup` on the app registration (which is the Eneco default for VPP ArgoCD app regs), **ONLY groups explicitly assigned to the Enterprise App flow into the `groups` claim** in the user's ID token. Verify:
   ```
   SP_ID=$(az ad sp list --filter "appId eq '<clientID>'" --query "[0].id" -o tsv)
   az rest --url "https://graph.microsoft.com/v1.0/servicePrincipals/$SP_ID/appRoleAssignedTo?\$top=999" \
     --query "value[?principalType=='Group'].principalDisplayName"
   ```
   Group must appear in the result. Missing = silent denial — the user's token won't carry the group even if AAD membership is correct.

3. **ArgoCD AppProject role binding** (cluster-local). `kubectl -n argocd get appproject <name> -o jsonpath='{.spec.roles[*].groups}'` → must contain the group's object GUID. AppProject roles provide `proj:<project>:<role>` effective role that bypasses the global `argocd-rbac-cm` deny-all default.

**All three planes must align.** Miss one = silent denial. The ArgoCD UI does not explain which plane failed; `argocd account can-i get applications <project>/*` is the cheapest runtime truth test.

## Casbin correction

Don't describe ArgoCD RBAC as "any ALLOW wins." Its Casbin model is `some(allow) && !some(deny)` — **a matching DENY vetoes allows**. Eneco sandbox's pattern works because `role:authenticated` is a Go-code `defaultRole` fallback (from `util/rbac/rbac.go::defaultRole`), **not a transitive Casbin role bound via `g, <user-group>, role:authenticated`**. If someone ever adds `g, <any-group>, role:authenticated` to argocd-rbac-cm, the blanket DENY would fire for every member of that group and break project grants. Preserve the current shape.

## Canonical probe set (copy-pasta for next ticket)

```bash
# Plane 1 — AAD membership
UPN=<user@eneco.com>
GROUP=<sg-vpp-...-developers>
USER_ID=$(az ad user show --id "$UPN" --query id -o tsv)
az ad group member check --group "$GROUP" --member-id "$USER_ID"

# Plane 2 — Enterprise App assignment
APP_CLIENT_ID=$(kubectl -n argocd get cm argocd-cm -o jsonpath='{.data.oidc\.config}' | awk '/clientID/ {print $2}')
SP_ID=$(az ad sp list --filter "appId eq '$APP_CLIENT_ID'" --query "[0].id" -o tsv)
az rest --url "https://graph.microsoft.com/v1.0/servicePrincipals/$SP_ID/appRoleAssignedTo?\$top=999" \
  --query "value[?principalType=='Group'].principalDisplayName"

# Plane 3 — AppProject binding
kubectl -n argocd get appproject <project> -o jsonpath='{.spec.roles[*].groups}'
az ad group show --group <guid-from-above> --query displayName

# Runtime truth
argocd account can-i get applications "<project>/*"
```

## Signed-out test (load-bearing)

Azure AD embeds the `groups` claim at token-issuance time. ArgoCD sessions default to 24h TTL. Group membership changes propagate only after **sign-out + sign-in** (not silent refresh). Skipping this = new member sees "doesn't work" for ≤24h post-merge.
