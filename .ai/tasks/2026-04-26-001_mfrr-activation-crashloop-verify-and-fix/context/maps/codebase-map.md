---
task_id: 2026-04-26-001
agent: coordinator
status: complete
summary: Codebase map across the four VPP repos with focus on the fix-relevant surfaces
---

# Codebase map — four-repo system

## Topology

```
~/Dropbox/@AZUREDEVOPS/eneco-src/enecomanagedcloud/myriad-vpp/
├── VPP%20-%20Infrastructure/                      (bare-repo + worktrees layout)
│   ├── .bare                                      authoritative bare clone
│   ├── 2026-04-24-ootw-fix-mfrr-activation-crashloop/    fix worktree → branch fix/NOTICKET/mfrr-activation-crashloop
│   ├── boyscout/                                  parallel worktree
│   ├── hotfix/                                    parallel worktree
│   └── main/                                      tracking origin/main
├── VPP - Infrastructure/                          (separate plain clone, also on main @ 4dbaf72)
├── Eneco.Vpp.Core.Dispatching/                    C# service + helm
│   └── helm/activationmfrr/                       chart for the failing service
├── VPP.GitOps/                                    ArgoCD config + sandbox overlays
└── VPP-Configuration/                             Helm app-of-apps + values.vppcore.sandbox.yaml
    └── Helm/activationmfrr/
```

## VPP-Infrastructure worktree — fix-relevant tree

```
2026-04-24-ootw-fix-mfrr-activation-crashloop/    (HEAD=4dbaf72, branch=fix/NOTICKET/mfrr-activation-crashloop, clean)
├── configuration/terraform/sandbox/
│   ├── sandbox.tfvars                             935 lines — env-specific values consumed by terraform/sandbox
│   └── sandbox.backend.config                     tfstate backend
├── terraform/fbe/                                 SHARED module code, instantiated per FBE
│   ├── event-hub.premium.tf                       150 lines — defines CG + storage container modules (DIAGNOSIS CITES)
│   ├── locals.tf                                  125 lines — eventhub_premium_attributes flattening
│   ├── app-config.tf, app-insights.tf, …
│   └── modules/key_vault/                         vendored sub-module
└── terraform/sandbox/
    ├── event-hub.premium.tf                       sandbox-specific module wiring (separate file from fbe/)
    ├── locals.tf, data.tf, provider.tf
    └── …                                          14 .tf files
```

## Phase-2 hypothesis on instantiation

- `terraform/fbe/` defines reusable resource collections (modules, locals).
- `terraform/sandbox/event-hub.premium.tf` likely instantiates the FBE module for the sandbox-only Event Hub namespace `vpp-evh-premium-sbx` — Phase 4 will confirm the `for_each` keying and whether it consumes `eventhub_premium_attributes` from `sandbox.tfvars`.
- The sandbox.tfvars is the *only* tfvars listed under `configuration/terraform/sandbox/` — single-source for env-specific consumer-group declarations (no _common.tfvars override observed in tree).

## Worktree quirk (route-relevant)

The bare-repo path uses literal `%20` characters as part of directory names (not URL encoding at runtime). All `cd`/`-C` invocations must keep those literal `%`s.
