---
task_id: 2026-07-20-002
agent: codex
status: complete
summary: |
  Read-only prior-knowledge search found a May 2026 FBE failure pattern that explicitly affected marketinteraction: child service builds failed, the branch image tag was not created in ACR, and Argo CD could then deploy a fallback image or leave pods in ImagePullBackOff. No exact prior incident was found for espmessageproducer, an absent ACR latest tag, or the Argo CD state pairing Synced plus Degraded. All operational content below is memory-derived and potentially stale; it is historical hypothesis input, not proof of the current DEV failures.
---

# Vault context: DEV unhealthy applications correlation

> **Evidence boundary:** The configured second brain at `/Users/alextorresruiz/Documents/obsidian` was read-only and valid (`llm-wiki/_index.md` present). Searches covered 1,321 Markdown files on 2026-07-20. **Every operational finding below is memory-derived and potentially stale.** `CONFIRMED` means the cited vault file currently contains the statement or the current search produced the result; it does not mean the historical claim or present cluster state was independently reverified.

## Highest-value prior pattern

### MarketInteraction was part of a recorded missing-branch-image failure class

- **CONFIRMED retrieval; internal secondary source; potentially stale; DIRECT:** A 2026-05-11 FBE incident note records `marketinteraction` among 6 of 13 Myriad VPP service builds affected by a transitive-CVE restore failure. The same note lists the concrete branch and ADO build IDs: branch `feature/fbe-821600-date-selector-flex-reservation-dashboard`, `marketinteraction` among the failing services, child builds including `1639197`, and parent build `1639150`. Sources: `/Users/alextorresruiz/Documents/obsidian/2-areas/work-eneco/eneco-vpp-platform/fbe-errors/pattern-fbe-service-build-blocked-by-transitive-cve.md:96`, `:107`, `:219`.
- **CONFIRMED retrieval; internal secondary source; potentially stale; DIRECT:** The recorded delivery mechanism was: child Docker build fails -> ACR has no image for that branch tag -> Argo CD resolves whatever the chart policy permits, often a `:latest` or `:development` fallback; with no fallback, the pod reaches `ImagePullBackOff`. Source: the same pattern note at `:110`.
- **CONFIRMED retrieval; internal secondary source; potentially stale; DIRECT:** The parent FBE pipeline could still look successful because `failTaskIfBuildsNotSuccessful: false` allowed `succeededWithIssues`; the note explicitly warns that Argo CD could then reference stale or missing images. Source: the same pattern note at `:185` and `:213`.

**Route impact (INFER, not current-state proof):** If the live `marketinteraction` failure shows a pull error for a branch-specific tag, the May pattern is a strong historical analogue. If it shows `:latest` specifically, this note supports only the broader missing-build/fallback mechanism; it does **not** establish that `latest` was absent in the historical incident.

## Adjacent but distinct image-tag failure class

- **CONFIRMED retrieval; internal secondary source; potentially stale; DIRECT:** The platform troubleshooting guide records a different mechanism: the One-For-All pipeline reads image tags from the ADO variable group `Release-<version>`; a missing service variable is interpreted by Bash as command substitution, exits 127, and leaves an empty tag. The guide says to inspect the release variable group, confirm the Helm directory exists, add the missing variable, and rerun. Source: `/Users/alextorresruiz/Documents/obsidian/2-areas/work-eneco/eneco-vpp-platform/eneco-vpp-platform-troubleshooting.md:120-127`.
- **CONFIRMED retrieval; internal secondary source; potentially stale; DIRECT:** The same guide routes an Argo CD sync failure involving an empty or missing image tag to that One-For-All diagnosis. Source: the troubleshooting guide at `:161-164`.

**Discriminator:** “branch image never built/pushed” and “release variable expanded to an empty tag” are separate mechanisms. Current child-build outcome, rendered image reference, pod event text, and ACR tag existence must distinguish them before remediation.

## Safe historical triage recipe

- **CONFIRMED retrieval; internal secondary source; potentially stale; DIRECT:** A read-only OpenShift rule-out playbook treats any non-Running pod—including `ImagePullBackOff`—as evidence of current degradation and pairs the current snapshot with abnormal namespace events. It names `ImagePullBackOff`/`ErrImagePull` among stop-closing signals. Source: `/Users/alextorresruiz/Documents/obsidian/2-areas/work-eneco/eneco-vpp-platform/eneco-openshift-sanity-check-azure-alert-rule-out.md:70-97`, `:99-122`.
- **Operational boundary:** That playbook is for falsifying “no workload impact,” not diagnosing the root cause. A live `ImagePullBackOff` event still needs its exact image repository/tag and registry error checked.

## espmessageproducer: no matching incident found

- **CONFIRMED negative search; current vault scan:** No vault line matched `espmessageproducer` within the same incident/failure context as `ImagePullBackOff`, `ErrImagePull`, missing tag, `Synced`, or `Degraded`.
- **CONFIRMED retrieval; internal secondary source; potentially stale; TANGENTIAL:** The service catalogue only identifies `espmessageproducer` as an ESP integration support workload selected for sandbox/dev (`S/D`), with source/config at `Myriad - VPP:/VPP/src/Local/EspMessageProducer` and `VPP-Configuration:/Helm/espmessageproducer`. The note explicitly says runtime was **NOT CHECKED** and its exact current operational purpose was not established. Source: `/Users/alextorresruiz/Documents/obsidian/2-areas/work-eneco/eneco-vpp-platform/vpp-myriad-services-catalog.md:164-170`.
- **CONFIRMED retrieval; internal secondary source; potentially stale; TANGENTIAL:** By contrast, the same catalogue maps `market-interaction` as a service selected for `S/D/A/P`, while warning its current lifecycle is unresolved because code/config remain but newer documentation omits or deprecates it. Source: the catalogue at `:149` and `:234`.

**Route impact (INFER):** A common pull error across these two differently scoped workloads would point more strongly toward shared delivery/image policy than shared application logic. That inference must be tested against the live rendered image references; the vault provides no direct espmessageproducer incident precedent.

## Argo CD Synced + Degraded: no exact precedent found

- **CONFIRMED negative search; current vault scan:** No exact `Synced + Degraded`, `Synced/Degraded`, or equivalent same-line state pairing was found.
- **CONFIRMED retrieval; internal secondary source; potentially stale; BACKGROUND:** The closest state guidance is an upgrade-monitoring checklist that expects cluster operators to be healthy/not degraded and Argo CD applications to be `Synced + Healthy` after nodes return. This is a recovery criterion, not a prior `Synced + Degraded` incident. Source: `/Users/alextorresruiz/Documents/obsidian/2-areas/work-eneco/eneco-howto/eneco-howto-monitor-cmc-cluster-upgrade.md:83-86`.
- **Interpretation ceiling:** `Synced` only establishes desired-state reconciliation; `Degraded` can still arise from workload health. The vault search did not find a prior record tying that exact pairing to these two applications or to a missing `latest` tag.

## Explicit negative information

The current vault scan found:

- no exact `espmessageproducer` incident involving image pull, ACR, or Argo degradation;
- no exact record stating that the ACR tag `latest` was missing;
- no exact Argo CD `Synced + Degraded` pairing;
- one direct `marketinteraction` missing-branch-image analogue, but not evidence that today’s two apps share its root cause.

## Runbook safety warning

- **CONFIRMED retrieval; internal secondary source; potentially stale; DIRECT:** The linked `recipe-resolve-nu1902-nu1903-build-failure.md` must **not** be executed as written. Its own frontmatter records an adversarial rejection: the proposed dependency bump was wrong, the assumed `development` branch did not exist, the transitive-package probe could depend on the failing restore, and variables/path logic were incomplete. Source: `/Users/alextorresruiz/Documents/obsidian/2-areas/work-eneco/eneco-vpp-platform/fbe-errors/recipe-resolve-nu1902-nu1903-build-failure.md:2-9`.
- Use the May pattern as a hypothesis generator only. Do not copy the invalidated remediation route into the current incident.

## Coordinator handoff: cheapest route-flipping observations

These are not performed by this read-only prior-knowledge lane:

1. Compare each live pod’s exact rendered image repository and tag with its pull-event message.
2. Check whether the corresponding service child build produced/pushed that exact tag; do not infer from the parent FBE pipeline’s top-level status.
3. Check ACR for the exact referenced tag. A missing branch tag supports the May failure class; an empty rendered tag supports the release-variable class; an absent `latest` with otherwise successful builds is a third route not established by vault history.
4. Treat `espmessageproducer` and `marketinteraction` as correlated only if the live image policy, registry error, or shared delivery step is actually identical.

## Source-quality summary

| Source class | Authority | Freshness | Relevance | Confidence boundary |
|---|---|---|---|---|
| May FBE pattern note | Internal secondary; cites ADO builds but not re-opened here | Potentially stale (2026-05-11) | Direct for `marketinteraction`, ACR, fallback, `ImagePullBackOff` | Confirmed note content; historical and current runtime claims unverified this turn |
| Platform troubleshooting guide | Internal secondary | Potentially stale (updated 2026-05-29) | Direct for missing/empty tag route | Confirmed note content; current pipeline implementation unverified |
| OpenShift rule-out playbook | Internal secondary | Potentially stale (2026-05-11) | Direct for read-only degradation detection | Confirmed note content; current access and cluster state unverified |
| Myriad service catalogue | Internal secondary | Potentially stale; runtime explicitly not checked | Tangential identity/lifecycle context | Not evidence of present health |

**Completeness:** PARTIAL by design. The prior-knowledge question is answered, including negative matches, but no live OpenShift, Argo CD, ACR, or ADO verification was authorized or performed.
