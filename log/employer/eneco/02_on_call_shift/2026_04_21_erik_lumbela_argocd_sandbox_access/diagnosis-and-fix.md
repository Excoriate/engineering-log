---
task_id: 2026-04-21-001
agent: claude-code
status: complete
summary: Final diagnosis + step-by-step fix for Erik Lumbela's ArgoCD Sandbox FTO access. PR 173958 closed the gap; sign-out+in + mandatory verify command required. All reviewer edits integrated.
---

# Diagnosis & Fix — Erik Lumbela, ArgoCD Sandbox FTO access

**Ticket**: `Rec0AUE5HU5MJ` (Erik Lumbela, 2026-04-21 15:42 CEST, `#myriad-platform`)
**Final confidence**: 95% (one INFER remains: Erik must re-authenticate to trigger fresh token issuance).
**Verdict**: **Already resolved by Erik's own PR 173958 deployed at 17:58 CEST today.** Erik needs one action (sign out + in) and must verify with one command regardless of whether UI appears to work.

---

## 1. Bottom line

Erik opened `Eneco.Infrastructure` PR **173958** at 13:37 UTC (15:37 CEST), which adds him to the AAD security group `sg-vpp-flex-trade-optimizer-developers`. The PR merged and deployed at **15:58 UTC (17:58 CEST)**. The sandbox ArgoCD `flex-trade-optimizer` AppProject binds that exact group to the `app-manager` role (`get/create/update/sync/override/delete` on `flex-trade-optimizer/*`). Erik is currently a member of the group (`az ad group member check` → `true`). The Enterprise App for sandbox ArgoCD (`appreg-vpp-argocd-id-d`, appId `504b5d75-…`) has `groupMembershipClaims: ApplicationGroup` AND the FTO developers group IS explicitly assigned to that Enterprise App — so Erik's next ID token will carry the `036bd5f7-…` group claim.

One residual UNVERIFIED claim remains: that Erik actually re-authenticates. Cached ArgoCD session tokens (default 24h TTL) do NOT carry the new claim retroactively. Azure AD group claims are snapshotted at token-issuance time.

---

## 2. Step-by-step for Erik

### Step A — Sign out of sandbox ArgoCD

- **Web UI**: top-right user menu → *Sign Out*. Close the browser tab. Clear the ArgoCD cookie if the menu doesn't appear (dev-tools → Storage → delete `argocd.token` cookie for the domain).
- **CLI**: `argocd logout argocd.dev.vpp.eneco.com`.

### Step B — Sign back in

- **Web UI**: navigate to the sandbox ArgoCD URL you normally use (see §4 URL-check if uncertain). Click *LOG IN VIA AZURE*. Complete the Azure redirect.
- **CLI**: `argocd login argocd.dev.vpp.eneco.com --sso`.

### Step C — Verify (mandatory, regardless of whether the UI appears to work)

```
argocd account can-i get applications "flex-trade-optimizer/*"
argocd account can-i sync applications "flex-trade-optimizer/*"
```

Expected: both return `yes`. Paste the output into the ticket thread.

**Why mandatory even if UI looks right**: if the UI shows apps but `can-i` says `no`, a coincident cause (UI filter, cached view, different project permission) is masking the real state. If `can-i` says `yes` without UI showing apps, the issue is UI-side (browser cache, dropdown filter) — trivial.

### Step D (contingent, run only if Step C returns `no`)

In order:

1. **URL check**: from your machine, run
   ```
   curl -sI https://argocd.dev.vpp.eneco.com | grep -iE 'server|x-argocd'
   ```
   Compare the IP/address with what is expected. If the DNS resolution on your machine differs from `20.76.210.221`, you may be on a split-DNS VPN rule and reaching a different ArgoCD instance than the one diagnosed here — post the `curl` output to the thread.
2. **Fresh token claims**: `argocd account get-user-info` (after fresh login). Check the `groups` list contains `036bd5f7-78b6-4f5f-8db9-943e7254646d`.
3. **Escalate**: paste both outputs in the thread; coordinator re-opens diagnosis against the actual ArgoCD instance your session hits.

---

## 3. Evidence block (6 FACTs)

| # | Claim | Probe | Evidence |
|---|---|---|---|
| E1 | PR 173958 merged + deployed | `az repos pr show --id 173958` | `status: completed`, `mergeStatus: succeeded`, `closedDate: 2026-04-21T15:58:15Z` (17:58 CEST), single commit `34377a84…`, single file `terraform/platform/aad/groups-flex-trade-optimizer-teams.tf` |
| E2 | Erik is in sg-vpp-flex-trade-optimizer-developers | `az ad group member check` | `{"value": true}` |
| E3 | Sandbox ArgoCD AppProject binds that group to `app-manager` | `kubectl -n argocd get appproject flex-trade-optimizer -o yaml` | `spec.roles[0].groups = [036bd5f7-…, 2aef53bb-…]`; policies include `applications {get/create/update/sync/override/delete}` on `flex-trade-optimizer/*` |
| E4 | OIDC groups claim flows to ArgoCD | `kubectl get cm argocd-cm` + `az ad app show` | `requestedIDTokenClaims.groups.essential: true`; `groupMembershipClaims: ApplicationGroup`; **`sg-vpp-flex-trade-optimizer-developers` IS assigned to the Enterprise App** (Graph API `appRoleAssignedTo` confirms) |
| E5 | No AAD groups overage | `az ad user get-member-groups --id Erik.Lumbela@eneco.com \| wc -l` | **169 groups** — under the JWT 200-group overage threshold per Microsoft Docs |
| E6 | No UserInfo cache between Erik and his groups | `argocd-cm` has no `enableUserInfoGroups` key | Groups flow from ID token directly; no Redis cache staleness risk |

---

## 4. URL ambiguity — named residual risk (not blocking)

- Ingress on the sandbox cluster (`vpp-aks01-d`, sub `iactest-401`) declares host `argocd.dev.vpp.eneco.com` with ingress-controller IP `50.85.91.121`.
- Public DNS resolves `argocd.dev.vpp.eneco.com` to `20.76.210.221` (a different IP).
- No DNS entry exists for `argocd.sandbox.vpp.eneco.com`, `argocd.sb.vpp.eneco.com`, `argocd.acc.vpp.eneco.com`, `argocd.prd.vpp.eneco.com`, or `argocd.iactest.vpp.eneco.com`.
- **Implication**: the sandbox cluster's ArgoCD may not be publicly resolvable via DNS; Erik may be reaching it via Eneco VPN split-DNS (which would map the name to `50.85.91.121`), via direct IP, or via port-forward. OR he may be reaching the MC-Dev ArgoCD (at `20.76.210.221`) for ALL environments, distinguishing "Dev/Acc/sandbox" by AppProject names within a single ArgoCD.
- **Impact on diagnosis**: if Erik's "sandbox ArgoCD" is actually the MC-Dev instance, my probes against the sandbox cluster are irrelevant. His Step-D probe `curl -sI https://argocd.dev.vpp.eneco.com` will surface which instance he hits.
- **Most likely reality (INFER)**: Erik is on Eneco VPN; internal DNS routes him to `50.85.91.121` (the sandbox cluster's ingress). This makes the entire diagnosis precise. The contingent Step D catches the exception.

---

## 5. Slack reply — ready to paste

> `<@U0AAFHJGHDM>` Access is unlocked as of **17:58 CEST today** — your PR ([Eneco.Infrastructure #173958](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/Eneco.Infrastructure/pullrequest/173958)) merged and deployed, you are now a member of `sg-vpp-flex-trade-optimizer-developers`, and sandbox ArgoCD's `flex-trade-optimizer` AppProject binds that group to `app-manager` (get/create/update/sync/override/delete on `flex-trade-optimizer/*`).
>
> Azure AD embeds the `groups` claim at token-issuance time, so your cached ArgoCD session doesn't carry the new membership yet. **Sign out of sandbox ArgoCD and sign back in.** Then, **regardless of what the UI shows**, run:
>
> ```
> argocd account can-i get applications "flex-trade-optimizer/*"
> argocd account can-i sync applications "flex-trade-optimizer/*"
> ```
>
> Both should return `yes`. Paste the output here so we close this with evidence, not just a "looks good".
>
> If either returns `no`, also post:
>
> ```
> curl -sI https://argocd.dev.vpp.eneco.com | grep -iE 'server|x-argocd'
> argocd account get-user-info
> ```
>
> — there is a known DNS ambiguity between the sandbox-cluster and MC-Dev ArgoCD (same hostname, different IPs per resolver); the `curl` and `get-user-info` outputs tell me which instance your session hit and whether your token carries the `036bd5f7-…` group.

Register audit: pings filer once (top); no banned phrases ("I hope", "feel free", "happy to", "let me know if", "please don't hesitate"); links are load-bearing (PR URL, docs by reference); prose tight; bullets only for the command blocks; evidence-first.

---

## 6. Contingent branches (if verification fails)

| Symptom | Probe | Likely cause | Remediation |
|---|---|---|---|
| `can-i` → `no`, `get-user-info` groups missing `036bd5f7-…` | `az ad app show --id 504b5d75-… --query groupMembershipClaims` + re-check `appRoleAssignedTo` | Enterprise App assignment rolled back or pending AAD sync | Re-verify with Graph API; open Platform ticket if drift |
| `can-i` → `no`, token groups include `036bd5f7-…` | `kubectl -n argocd logs deployment/argocd-server \| grep -i rbac \| tail -50` | AppProject drift or enforcer cache | Compare current AppProject to PR-era version; bounce `argocd-server` pod (needs authorization) |
| `curl` IP ≠ `20.76.210.221` AND ≠ `50.85.91.121` | DNS / VPN resolver inspection | Split DNS routing through a third instance | Re-open diagnosis against that ArgoCD |
| `curl` IP = `20.76.210.221` | Cross-check MC-Dev cluster's FTO AppProject bindings | Sandbox vs Dev ArgoCD confusion | Pivot to MC-Dev cluster (different kubectl context required) |

---

## 7. Doctrine correction (for institutional memory)

Earlier reasoning framed ArgoCD RBAC as "any ALLOW wins; DENY never fires if an ALLOW matches." **This is wrong** per ArgoCD's Casbin model (`assets/model.conf`): the effect is `some(where (p.eft == allow)) && !some(where (p.eft == deny))` — a matching DENY vetoes allows. The diagnosis still holds only because `role:authenticated` in `argocd-rbac-cm` is a Go-code default fallback (`util/rbac/rbac.go::defaultRole`), NOT a transitive Casbin role attached via `g, <user-group>, role:authenticated`. If anyone ever adds `g, <group>, role:authenticated` citing my earlier prose as authority, every authenticated member of that group would be globally denied even with project grants. **Do not propagate that prose.**

---

## 8. What to keep as runbook pattern

1. **Access ticket against ArgoCD + "works env A, not env B"** → three-plane model: (i) AAD group membership, (ii) Enterprise App `groupMembershipClaims` + group-to-SP assignment, (iii) AppProject `spec.roles[].groups`. All three must align. Miss one = silent denial.
2. **Landed PR + filer reports it's still broken** → first falsifier is ALWAYS the deploy timestamp vs the ticket filing timestamp. If filing preceded deploy, the filer is reporting pre-deploy state; wait and re-ask. If filing followed deploy by > 15 minutes, investigate.
3. **"sign out + in" is load-bearing** when OIDC groups claim is used. Azure AD embeds groups at issuance. Cached tokens are a frozen snapshot.
4. **Never trust a "works now" without the `can-i` command.** UI-level confirmation is not the same as RBAC-level confirmation; we already got burned by this class once in this same session.
