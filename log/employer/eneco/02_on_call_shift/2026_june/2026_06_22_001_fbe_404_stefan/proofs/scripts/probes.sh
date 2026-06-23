#!/usr/bin/env bash
# probes.sh — the exact read-only probes + the two fix patches for the
# FBE operations-slot 404 (finalizer-wedged app-of-apps) incident.
#
# Transcribed verbatim from:
#   - ../../antecedents/probe-results.md   (live read-only diagnosis ledger)
#   - ../../antecedents/fix-result.md      (applied fix + verification)
#   - ../../output/how-to-fix.md           (gated repair spec P1-P6 + patches)
#
# Raw captured outputs for each block live in ../outputs/.
#
# This is a documentation/replay artifact. Do NOT execute it blindly:
# blocks 5 and 6 are read-write GitOps mutations on a one-way door and require
# explicit current-turn authorization + a passing P2/P3 (wedge real, workloads
# gone). The original incident is resolved; live probes will no longer show the
# wedge — re-witness the wedge from ../outputs/ and prefix-snapshot YAMLs.

set -eu

CTX="vpp-aks01-d"   # FBE Sandbox AKS, rg-vpp-app-sb-401 — direct kubectl, no AVD

# ---------------------------------------------------------------------------
# CLUSTER-CONFIRM
# Answers: am I bound to the right cluster before reading or writing?
# Expected: the context is listed. Absent -> fix kubeconfig, do not guess.
# Output: ../outputs/ (no dedicated file; gating step)
# ---------------------------------------------------------------------------
kubectl config get-contexts | grep "$CTX"

# ---------------------------------------------------------------------------
# DIAGNOSIS PROBE 1 — namespace (the trap)
# Answers: does `get ns` reveal the wedge? (It does NOT — the Application CR does.)
# Expected: phase Active, NO ns deletionTimestamp.
# Output: ../outputs/01-ns-operations.json
# ---------------------------------------------------------------------------
kubectl --context "$CTX" get ns operations -o json | \
  jq '{phase:.status.phase, deletionTimestamp:.metadata.deletionTimestamp}'

# ---------------------------------------------------------------------------
# DIAGNOSIS PROBE 2 — app-of-apps deletionTimestamp (the decisive probe)
# Answers: is the slot's app-of-apps wedged mid-deletion?
# Expected: non-empty deletionTimestamp (2026-06-01T10:50:12Z in snapshot) +
#           [resources-finalizer.argocd.argoproj.io], owner = ApplicationSet
#           controller:true. Empty deletionTimestamp -> NOT this class, STOP.
# Output: ../outputs/03-app-of-apps.json
# ---------------------------------------------------------------------------
kubectl --context "$CTX" -n argocd \
  get application operations-app-of-apps -o json | \
  jq '{deletionTimestamp:.metadata.deletionTimestamp,
       finalizers:.metadata.finalizers,
       owner:.metadata.ownerReferences}'

# ---------------------------------------------------------------------------
# DIAGNOSIS PROBE 3 — child Applications present in the slot
# Answers: is the slot undeployed (only assetmonitor), matching the wedge?
# Expected: only assetmonitor; no frontend/gateway-nl/clientgateway.
# Output: ../outputs/02-all-applications.txt
# ---------------------------------------------------------------------------
kubectl --context "$CTX" -n operations get applications

# ---------------------------------------------------------------------------
# DIAGNOSIS PROBE 4 — ApplicationSet generator health (rule out PAT expiry)
# Answers: is the generator healthy so self-heal will fire?
# Expected: ErrorOccurred=False, ParametersGenerated=True, ResourcesUpToDate=True.
#           ErrorOccurred=True + "authentication required" -> PAT expiry, STOP.
# Output: ../outputs/04-applicationset.json
# ---------------------------------------------------------------------------
kubectl --context "$CTX" -n argocd \
  get applicationset vpp-feature-branch-environments -o json | \
  jq -r '.status.conditions[]? | "\(.type)=\(.status)"'

# ---------------------------------------------------------------------------
# DIAGNOSIS PROBE 4b — per-Application credential-gap scan (rule out cred gap)
# Answers: does any operations app show a "source N of M ... authentication
#          required" comparison error?
# Expected: none for operations (only an unrelated loki helm-values error).
# Output: ../outputs/04b-credgap-scan.txt
# ---------------------------------------------------------------------------
kubectl --context "$CTX" -n operations get applications -o json | \
  jq -r '.items[] | "\(.metadata.name) sync=\(.status.sync.status) health=\(.status.health.status)"'

# ---------------------------------------------------------------------------
# DIAGNOSIS PROBE 5 — pods + ingress in the slot
# Answers: is there any live frontend backend, or only the stuck assetmonitor?
# Expected: only assetmonitor ingress; assetmonitor pods 0/1 (itself mid-deletion).
# Output: ../outputs/05-pods.txt, ../outputs/05-ingress.txt
# ---------------------------------------------------------------------------
kubectl --context "$CTX" -n operations get pods,ingress

# ---------------------------------------------------------------------------
# DIAGNOSIS PROBE 6 — curl the public URL (edge 404, no backend)
# Answers: is the 404 an undeployed backend or a routing misalignment?
# Expected: 404 from nginx, NO x-correlation-id -> edge 404, no backend.
#           404 WITH x-correlation-id -> backend exists, path misaligned, STOP.
# Output: ../outputs/06-curl.txt
# ---------------------------------------------------------------------------
curl -svk "https://operations.dev.vpp.eneco.com/" 2>&1 | \
  grep -iE "HTTP/|x-correlation-id|Request-Context|server"

# ===========================================================================
# FIX PATCHES — READ-WRITE, ONE-WAY DOOR.
# AUTHORIZATION REQUIRED: explicit current-turn user authorization (GitOps
# mutation + destructive-cleanup gate). Run ONLY after the probes above prove
# the wedge is real (probe 2) and the managed workloads are already gone
# (probes 3/5). Finalizer removal completes an irreversible deletion.
# Each returns: application.argoproj.io/<name> patched.
# Output: ../outputs/fix-apply.log
# ===========================================================================

# FIX PATCH 1 — clear the wedged finalizer on the slot's app-of-apps (ns argocd).
kubectl --context "$CTX" -n argocd \
  patch application operations-app-of-apps --type=merge \
  -p '{"metadata":{"finalizers":[]}}'

# FIX PATCH 2 — clear the wedged finalizer on the orphan child (ns operations).
kubectl --context "$CTX" -n operations \
  patch application assetmonitor --type=merge \
  -p '{"metadata":{"finalizers":[]}}'

# ---------------------------------------------------------------------------
# POST-FIX VERIFICATION — confirm self-heal + 404 -> 200
# Answers: did both wedged CRs delete, did the ApplicationSet regenerate a fresh
#          app-of-apps, did the child set sync, and does the URL serve 200?
# Expected: no CR carries a deletionTimestamp; fresh operations-app-of-apps with
#           a NEW creationTimestamp, Synced/Healthy; frontend/gateway-nl/
#           clientgateway Synced/Healthy; URL 200.
# Output: ../outputs/post-fix-verification.txt, ../outputs/convergence-poll.txt
# ---------------------------------------------------------------------------

# No CR still carries a deletionTimestamp (deletion completed).
kubectl --context "$CTX" get applications -A -o json | \
  jq -r '.items[] | select(.metadata.deletionTimestamp) | .metadata.name'

# Fresh app-of-apps: new creationTimestamp, Synced/Healthy, no deletionTimestamp.
kubectl --context "$CTX" -n argocd \
  get application operations-app-of-apps \
  -o jsonpath='{.metadata.creationTimestamp} {.status.sync.status}/{.status.health.status}'

# The slot's web backends now present and converging.
kubectl --context "$CTX" -n operations \
  get application frontend gateway-nl clientgateway

# Public URL now serves 200 (was 404).
curl -sk -o /dev/null -w '%{http_code}\n' "https://operations.dev.vpp.eneco.com/"
