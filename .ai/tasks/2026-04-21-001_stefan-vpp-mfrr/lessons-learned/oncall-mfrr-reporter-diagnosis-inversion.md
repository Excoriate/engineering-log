---
task_id: 2026-04-21-001
agent: claude-code
status: complete
summary: Six memory-worthy lessons from the Stefan VPP mFRR-Activation on-call investigation
---

# Task-local lessons (candidates for llm-wiki promotion)

## 1. Reporter self-diagnoses are INFER, not FACT — even when they read precisely

Stefan filed a Slack Lists ticket saying "mFRR-Activation on Sandbox is missing EventHub consumer" and "crash looping due to missing consumer group". The pod's actual stack trace showed `Azure.RequestFailedException: ContainerNotFound` inside `BlobCheckpointStoreInternal.ListOwnershipAsync(fullyQualifiedNamespace, eventHubName, consumerGroup, cancellationToken)`. Stefan saw "consumerGroup" as a parameter and inferred the CG was missing — but the exception class named Blob Storage's `ContainerNotFound`, not Event Hub's `ResourceNotFound`. The missing entity was the *checkpoint blob container*, not the *CG entity*. Both needed to be created, but conflating them would pick the wrong target for IaC. Treat every reporter-authored "cause" as a symptom description until independent stack-trace probe confirms the exception class.

## 2. Kubernetes `Running 1/1, 0 restarts` does NOT imply functional

The "healthy" R145 pod was `Running 1/1` with 12 days of uptime — and simultaneously logging `4/4 brokers are down` against Eneco ESP Kafka brokers every 5 minutes. The readiness probe at `/readiness` tested process wiring, not upstream connectivity. Never accept "healthy pod" framing in outage triage without positive-signal probing the pod's actual work (expected log classes: message processing, partition init, successful publish). K8s health probes are proxy signals.

## 3. "SDK convention" is not "SDK guarantee"

Azure EventHubs `BlobCheckpointStore` accepts arbitrary container names via the caller-constructed `BlobContainerClient`. The pattern of naming the container after the consumer group is a *team-level convention*, not an SDK contract. IaC PRs targeting such resources must use the exact string the service reads from config, not the SDK-expected shape. When authoring a Terraform resource whose name is read from dynamic config (App Config, KV), read the config first, then write the resource — do not guess from convention.

## 4. When a Terraform PR's names come from Azure App Configuration, read App Config first

For VPP workloads that source EH CG/container/SA settings from `vpp-appconfig-d` at runtime, the IaC PR's `name` fields must match App Config values byte-exact (case-sensitive). Authoring the PR from convention-guess is a classic silent-failure trap: PR merges, applies cleanly, creates an orphan resource, pod still crash-loops with an identical-looking error. Command pattern: `az appconfig kv list --name <config> --key "*EventHub*|*Checkpoint*" -o table` (read-only, cheap, highest-information-per-token probe for this class).

## 5. Sandbox AKS ≠ dev-mc/acc/prd OpenShift — topology asymmetry

Eneco VPP's Sandbox runs on Azure AKS (`vpp-aks01-d`, RG `rg-vpp-app-sb-401`, namespace `eneco-vpp` / `vpp`). dev-mc, acc, prd run on OpenShift on MC (Managed Cloud). Kubectl works on Sandbox; `oc` + MC auth + subscription switch is required for MC envs. Runbooks that conflate the two silently fail on the wrong-env probe. State env explicitly in each step.

## 6. ArgoCD helm OCI sync + Azure App Configuration + KV CSI = dynamic three-layer config stack

VPP workloads deployed by ArgoCD helm OCI (naming pattern `vpp-<service>-helm-oci-<revision>-<hash>`) inject only App Config connection string + KV client credentials + tenant IDs + `DOTNET_GCHeapHardLimitPercent` as env vars. All CG names, container names, storage account URIs, connection strings, and service-specific config are loaded from `vpp-appconfig-d` (endpoint `https://vpp-appconfig-d.azconfig.io`) at startup using the user-assigned MI client credentials. This means "same env vars + different image → different behavior" is the norm, not an anomaly. When diagnosing a rolling-deployment regression where K8s env-diff is empty, the change is in the image's App Config key set or its config-resolution code path, not in K8s.

## References

- `verification/enrich-results.md` — source probes (P1–P18)
- `verification/socrates-contrarian-review.md` — independent adversarial review
- `verification/phase-8-results.md` — adversarial integration summary
- `outcome/diagnosis.md` — final outcome with fix runbook
