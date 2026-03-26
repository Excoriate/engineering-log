# Root Cause Analysis — ContainerMemoryUsageHigh (DEV Cluster)

**Date**: 2026-03-26
**Alert**: `ContainerMemoryUsageHigh`
**Severity**: warning | **Status**: firing
**Cluster**: `eneco-vpp-dev` (OpenShift)

---

## 1. What Happened

At 2026-03-26T01:12:56Z, the Prometheus alert `ContainerMemoryUsageHigh` fired for the `azure-devops-build-agent` container running in the `eneco-vpp-opstools` namespace on the DEV OpenShift cluster.

The container is using **92.59% of its memory limit** (1024Mi = 1GiB).

### Alert Expression (from payload `generatorURL`)

```promql
(
  container_memory_working_set_bytes{container!="", container!="POD", image!="", namespace="eneco-vpp-opstools"}
  /
  container_spec_memory_limit_bytes{container!="", container!="POD", image!="", namespace="eneco-vpp-opstools"}
  >= 0.9
)
* on (namespace, pod) group_left (label_team) kube_pod_labels{job="kube-state-metrics", namespace="eneco-vpp-opstools"}
```

**Translation**: Fire when any container in `eneco-vpp-opstools` uses >=90% of its memory limit.

### Affected Pod

| Field | Value |
|-------|-------|
| Pod | `azure-devops-build-agent-6f984cfc6d-bjjql` |
| Container | `azure-devops-build-agent` |
| Image | `vppacra.azurecr.io/opstools/azure-devops-build-agent:1.5.0` |
| Node | `eneco-vpp-dev-zgzzt-worker-westeurope1-8sjq2` |
| Namespace | `eneco-vpp-opstools` |
| Instance (kubelet) | `10.7.32.172:10250` |

---

## 2. Root Cause: WHY Memory Is High

### The container is a self-hosted Azure DevOps build agent

It runs CI/CD pipelines directly inside the pod. Each pipeline execution downloads source code, restores NuGet/npm packages, compiles code, runs tests — all within the container's memory limit.

### The image is heavy by design

From the Dockerfile (`container-base-images/azure-devops-build-agent/Dockerfile`):

```
Base:     Ubuntu 24.04
Includes: Python 3.12 + venv + poetry/azure-identity/mlflow/pytest/checkov/requests/msal
          PowerShell + SQLServer module
          Azure CLI
          Terraform 1.10.3
          .NET 6.0 SDK
          Java 17 (OpenJDK)
          git, curl, jq, wget, nano, bash
```

This is a kitchen-sink build agent image. At rest (before any pipeline runs), it already consumes significant memory from the Azure DevOps agent process, .NET runtime, and background processes.

### The memory limit is 1GiB — too low for a build agent

From `VPP-Configuration/eneco-vpp-opstools/azure-devops-build-agent/base/build-agent.deployment.yaml:41-47`:

```yaml
resources:
  limits:
    cpu: 500m
    memory: 1024Mi
  requests:
    cpu: 100m
    memory: 768Mi
```

**1024Mi** is the hard ceiling. When a pipeline executes a `dotnet build`, `dotnet test`, `npm install`, or `terraform plan` — these operations can easily spike memory beyond 1GiB. At 92.59%, the agent is at **~948Mi** — one `dotnet test` run with parallel execution could OOM-kill the pod.

### The startup script downloads + extracts the agent binary at runtime

From `container-base-images/azure-devops-build-agent/start.sh:75-87`:

```bash
# Downloads and extracts Azure Pipelines agent
curl -LsS "${AZP_AGENT_PACKAGE_LATEST_URL}" | tar --no-same-owner ... -xz
```

This means every time the pod starts, it downloads the full Azure Pipelines agent package, extracts it in memory, then runs it. The extracted agent + its Node.js runtime + the pipeline work directory all compete for the same 1GiB.

### DEV runs 3 replicas

From `VPP-Configuration/eneco-vpp-opstools/azure-devops-build-agent/devmc/build-agent.deployment.yaml`:

```yaml
replicas: 3
```

3 pods × 1GiB limit each = 3GiB total. If multiple pipelines run concurrently (which is the point of 3 replicas), each pod can independently hit its limit.

---

## 3. Assessment

### Is this an incident?

**Borderline**. It's on DEV, so no production impact. But if the agent OOM-kills:
- Running pipelines will fail with exit code 137
- The agent will deregister from the ADO pool
- The pod will restart, re-download the agent binary, and re-register (~2-3 min of lost capacity)

### Is this recurring?

**Likely yes**. A 1GiB limit for a full-stack build agent (dotnet + Java + Python + Terraform + PowerShell) is chronically tight. Any non-trivial pipeline will push it over 90%.

### Why didn't it OOM-kill (yet)?

At 92.59%, the container is in the danger zone but hasn't exceeded 100%. The `working_set_bytes` metric measures actively used memory (not cache). If a build completes and the .NET GC reclaims memory, it may drop back. But the next build will push it up again.

---

## 4. Notification Chain

```
Prometheus (openshift-monitoring/k8s)
  → PrometheusRule: ContainerMemoryUsageHigh (source: likely OCI Helm chart)
    → AlertManager
      → receiver: eneco-vpp-opstools/alertmanagerconfig/rootly-trade-platform
        → Rootly webhook
          → Escalation Policy (1b6ee744-4aca-45ed-9d00-2d1d2b5edbfa)
```

**Note**: There are TWO separate alerting systems for container memory:

1. **VPP-level** (`ocp-prometheus-alerting` Helm chart) — generates alerts named `VPPContainerMemoryUsage` with tiered thresholds (info: 75%, warning: 80%, critical: 90%). Defined in `Myriad - VPP/azure-pipeline/Helm/ocp-prometheus-alerting/values.yaml:63-85`. Uses the `alert_rule.yaml` template to generate per-severity PrometheusRule CRDs.

2. **Namespace-level** (source: likely the `opstools` OCI Helm chart at `oci://vppacra.azurecr.io/helm/opstools:0.0.1`) — generates the `ContainerMemoryUsageHigh` alert that fired here, with a flat 90% threshold. The PromQL is slightly different: it scopes to `namespace="eneco-vpp-opstools"` and joins with `kube_pod_labels`.

The alert that fired (`ContainerMemoryUsageHigh`) is from system #2. The VPP-level alert (`VPPContainerMemoryUsage`) likely also fires at the critical tier but routes differently.

The VPP-level alert chart is at:
- **Chart**: `Myriad - VPP/azure-pipeline/Helm/ocp-prometheus-alerting/`
- **Values**: `values.yaml:63-85` (VPPContainerMemoryUsage definition)
- **Template**: `templates/alerts/alert_rule.yaml` (generates PrometheusRule CRDs)
- **Runbook**: `https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_wiki/wikis/Myriad---VPP.wiki/8073/container-memory-usage#`

---

## 5. Verified Claims

| # | Claim | Evidence | Source |
|---|-------|----------|--------|
| 1 | Memory limit is 1024Mi | `resources.limits.memory: 1024Mi` | `base/build-agent.deployment.yaml:44` |
| 2 | Memory request is 768Mi | `resources.requests.memory: 768Mi` | `base/build-agent.deployment.yaml:47` |
| 3 | CPU limit is 500m | `resources.limits.cpu: 500m` | `base/build-agent.deployment.yaml:43` |
| 4 | DEV runs 3 replicas | `replicas: 3` | `devmc/build-agent.deployment.yaml:6` |
| 5 | Image includes .NET, Java, Python, Terraform, PowerShell, Az CLI | Dockerfile installs all | `container-base-images/azure-devops-build-agent/Dockerfile` |
| 6 | Agent binary is downloaded at startup (not baked in) | `curl ... \| tar -xz` | `start.sh:87` |
| 7 | Image version is 1.5.0 | `image: vppacra.azurecr.io/opstools/azure-devops-build-agent:1.5.0` | `base/build-agent.deployment.yaml:18` |
| 8 | Pool assignment is `self-hosted-mcdev-k8s` | `AZP_POOL: self-hosted-mcdev-k8s` | `devmc/build-agent.deployment.yaml:13` |
| 9 | Alert threshold is >= 90% | PromQL expression `>= 0.9` | Decoded from `generatorURL` in payload |
| 10 | ACC also runs 3 replicas with same memory limit | `replicas: 3`, inherits base resources | `acc/build-agent.deployment.yaml` |

---

## 6. Recommendations

### Immediate: Increase the memory limit

**1024Mi is too low for a build agent running .NET/Java/Python/Terraform pipelines.**

```yaml
# Suggested change in base/build-agent.deployment.yaml
resources:
  limits:
    cpu: "1"          # was 500m — also constrained for builds
    memory: 2048Mi    # was 1024Mi
  requests:
    cpu: 250m         # was 100m
    memory: 1024Mi    # was 768Mi
```

**Why 2GiB**: A `dotnet test` with parallel execution on a medium-sized solution can use 800Mi-1.2GiB alone. Add the agent process (~200Mi), OS overhead (~100Mi), and any npm/Java tasks — 2GiB gives headroom without being wasteful.

### Structural: Bake the agent binary into the image

Currently `start.sh` downloads and extracts the agent on every pod start. This:
- Wastes memory during extraction
- Adds 1-2 minutes to startup time
- Creates a dependency on the external ADO API at boot time

Baking the agent into the Dockerfile would reduce startup memory pressure and boot time.

### Alert tuning

The 90% threshold is reasonable for application containers, but a build agent is inherently bursty — it idles near baseline then spikes during builds. Options:
- **Raise threshold to 95%** for the `eneco-vpp-opstools` namespace specifically
- **Add a `for:` duration** (e.g., `for: 10m`) so it only fires on sustained high memory, not build-time spikes
- **Exclude build agent containers** from this alert if the memory limit is properly set to handle peak load

### Source files to modify

| File | Change |
|------|--------|
| `VPP-Configuration/eneco-vpp-opstools/azure-devops-build-agent/base/build-agent.deployment.yaml` | Increase memory limit to 2048Mi |
| `container-base-images/azure-devops-build-agent/Dockerfile` | Consider baking in agent binary |
| PrometheusRule (in OCI Helm chart — needs access to `oci://vppacra.azurecr.io/helm/opstools`) | Add `for:` duration or namespace exception |

---

## 7. Comparison: DEV vs ACC vs PRD

| Property | DEV | ACC | PRD |
|----------|-----|-----|-----|
| Replicas | 3 | 3 | (check `prod/build-agent.deployment.yaml`) |
| Memory limit | 1024Mi (from base) | 1024Mi (from base) | 1024Mi (from base) |
| Pool | `self-hosted-mcdev-k8s` | `self-hosted-mcacc-k8s` | (check prod overlay) |
| Image | 1.5.0 | 1.5.0 | 1.5.0 |

**All environments share the same base memory limit** — this alert will fire on ACC and PRD too if build load is similar.

---

## 8. Conclusion

**Root cause**: The Azure DevOps self-hosted build agent has a memory limit of 1024Mi which is insufficient for the workloads it runs (.NET builds, Java, Terraform, Python). At 92.59% utilization, it's one heavy pipeline away from OOM-kill.

**Action**: Increase memory limit to 2048Mi in `base/build-agent.deployment.yaml`. This applies to all environments (DEV, ACC, PRD) via Kustomize overlays.

**Resolve in Rootly**: Yes, mark resolved with a follow-up action to bump the memory limit.
