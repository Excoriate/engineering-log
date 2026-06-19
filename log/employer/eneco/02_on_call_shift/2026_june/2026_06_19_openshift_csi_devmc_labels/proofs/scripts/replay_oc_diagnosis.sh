#!/usr/bin/env bash
set -euo pipefail

NS="${1:-eneco-vpp}"

printf '\n== Cluster identity ==\n'
# WHY: Prove the oc context is the incident cluster before interpreting any resource state.
oc whoami --show-server

printf '\n== OpenShift version ==\n'
# WHY: Match the cluster behavior to the correct OpenShift documentation version.
oc version

printf '\n== Deployment summary in namespace %s ==\n' "$NS"
# WHY: Check the Kubernetes controller state instead of relying only on Argo UI health.
oc get deploy -n "$NS"

printf '\n== AssetPlanning deployment details ==\n'
# WHY: Read the controller reason, pod template, and admission error for AssetPlanning in one place.
oc describe deploy assetplanning-eneco-vpp -n "$NS"

printf '\n== FleetOptimizer solver deployment details ==\n'
# WHY: Confirm whether FleetOptimizer solver fails for the same admission reason.
oc describe deploy fleetoptimizersolver-eneco-vpp -n "$NS"

printf '\n== Namespace security labels and annotations ==\n'
# WHY: Show the namespace security profile that admission compares against the pod request.
oc describe ns "$NS"

printf '\n== Secrets Store CSIDriver metadata ==\n'
# WHY: Check whether the named CSI driver has the OpenShift security profile label admission expects.
oc describe csidriver secrets-store.csi.k8s.io

if command -v jq >/dev/null 2>&1; then
  printf '\n== Optional cluster-wide inline Secrets Store CSI Deployment scan ==\n'
  # WHY: Find other Deployments that declare the same inline CSI driver in their pod template.
  oc get deploy -A -o json | jq -r '
    .items[]
    | .metadata as $m
    | [(.spec.template.spec.volumes // [])[]?.csi?.driver]
    | unique
    | select(index("secrets-store.csi.k8s.io"))
    | "\($m.namespace)\t\($m.name)\tsecrets-store.csi.k8s.io"
  '
else
  printf '\n== Optional scan skipped: jq is not installed ==\n'
  printf 'Install jq or run: oc get deploy -A -o yaml | grep -n "secrets-store.csi.k8s.io"\n'
fi
