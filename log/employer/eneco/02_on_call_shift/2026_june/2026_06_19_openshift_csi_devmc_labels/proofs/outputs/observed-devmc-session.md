---
task_id: 2026-06-19-openshift-csi-devmc-labels
agent: codex
status: review
summary: Observed Dev-MC oc outputs from live troubleshooting session.
---

# Observed Dev-MC Session Output Summary

This file records the live observations used for the RCA. It is not a byte-for-byte terminal transcript. To reproduce the current state, run `proofs/scripts/replay_oc_diagnosis.sh` while logged into the target cluster.

## Cluster Identity

Command:

```bash
oc whoami --show-server
```

Observed output:

```text
https://api.eneco-vpp-dev.ceap.nl:6443
```

Command:

```bash
oc version
```

Observed output included:

```text
Client Version: 4.8.11
Server Version: 4.20.16
Kubernetes Version: v1.33.8
```

## Deployment Summary

Command:

```bash
oc get deploy -n eneco-vpp
```

Relevant observed rows included:

```text
assetplanning-eneco-vpp                 2/2   2   2
fleetoptimizergateway-eneco-vpp         2/2   2   2
fleetoptimizersolver-eneco-vpp          0/1   0   0
```

## AssetPlanning Deployment

Command:

```bash
oc describe deploy assetplanning-eneco-vpp -n eneco-vpp
```

Relevant observed facts:

```text
Mounts:
  /mnt/secrets-store from secrets-store-inline
Volumes:
  secrets-store-inline:
    Type: CSI
    Driver: secrets-store.csi.k8s.io
    ReadOnly: true
    VolumeAttributes:
      secretProviderClass=secret-provider-kv
Conditions:
  Available=True MinimumReplicasAvailable
  Progressing=False ReplicaSetCreateError
Events:
  Error creating: pods ... is forbidden: ... uses an inline volume provided by CSIDriver secrets-store.csi.k8s.io and namespace eneco-vpp has a pod security enforce level that is lower than privileged
```

## FleetOptimizer Solver Deployment

Command:

```bash
oc describe deploy fleetoptimizersolver-eneco-vpp -n eneco-vpp
```

Relevant observed facts:

```text
Replicas: 1 desired | 0 updated | 0 total | 0 available | 0 unavailable
Mounts:
  /mnt/secrets-store from secrets-store-inline
Volumes:
  secrets-store-inline:
    Type: CSI
    Driver: secrets-store.csi.k8s.io
    ReadOnly: true
    VolumeAttributes:
      secretProviderClass=secret-provider-keyvault-fleetoptimizer
Conditions:
  Available=False MinimumReplicasUnavailable
  Progressing=False ReplicaSetCreateError
Events:
  Error creating: pods ... is forbidden: ... uses an inline volume provided by CSIDriver secrets-store.csi.k8s.io and namespace eneco-vpp has a pod security enforce level that is lower than privileged
```

## Namespace State

Command:

```bash
oc describe ns eneco-vpp
```

Relevant observed labels/annotations included:

```text
Labels:
  argocd.argoproj.io/managed-by=eneco-vpp-argocd
  goldilocks.fairwinds.com/enabled=true
  kubernetes.io/metadata.name=eneco-vpp
  pod-security.kubernetes.io/audit=restricted
  pod-security.kubernetes.io/audit-version=latest
  pod-security.kubernetes.io/warn=restricted
  pod-security.kubernetes.io/warn-version=latest
Annotations:
  openshift.io/node-selector=org=vpp
  security.openshift.io/MinimallySufficientPodSecurityStandard: restricted
```

## CSIDriver State

Command:

```bash
oc describe csidriver secrets-store.csi.k8s.io
```

Relevant observed facts:

```text
Name: secrets-store.csi.k8s.io
Labels: <none>
Annotations:
  argocd.argoproj.io/tracking-id: cmc-secrets-store-csi-driver:storage.k8s.io/CSIDriver:secrets-store-csi-driver/secrets-store.csi.k8s.io
Spec:
  Attach Required: false
  Pod Info On Mount: true
  Requires Republish: false
  Storage Capacity: false
  SELinux Mount: false
  Token Requests:
    Audience: api://AzureADTokenExchange
  Volume Lifecycle Modes:
    Ephemeral
```
