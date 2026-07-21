---
task_id: 2026-07-20-002
agent: codex
status: complete
summary: "Read-only Slack evidence indicates the two DEV unhealthy applications were an image-pull/latest-tag problem, not caused by the Argo CD replica maintenance; only espmessageproducer is directly identified in Slack."
---

# Slack context: DEV unhealthy applications versus Argo CD replica increase

## Bottom line

**Slack evidence weighs against a causal relationship to the Argo CD replica increase.** In the maintenance thread, Fabrizio Zavalloni explicitly states, "This is not related to this maintenance" after identifying the symptom as an attempt to pull the latest pod image in DEV. The same thread links the DEV configuration for `espmessageproducer`, directly identifying that application as part of the investigation.

This is **source-verified organizational evidence**, not independent runtime proof. Slack does **not** directly name `marketinteraction-eneco-vpp` in the thread, so the conclusion that it was the second unhealthy application comes from the parent investigation/runtime context, not from Slack. Slack also does not prove why the image pull failed.

## Direct messages and chronology

All messages below are in [`#myriad-platform`, maintenance thread](https://grid-eneco.enterprise.slack.com/archives/C063SNM8PK5/p1784533620910639?thread_ts=1784533620.910639&cid=C063SNM8PK5), on 2026-07-20 CEST.

| Time | Direct message evidence | What it proves |
|---|---|---|
| 09:47 | Alex Torres announces the VPP-DEV Argo CD replica increase, scheduled 10:30-11:30, and says workload impact is not expected. | Planned scope and stated expectation; not proof of actual absence of impact. |
| 11:01:57 | [Completion update](https://grid-eneco.enterprise.slack.com/archives/C063SNM8PK5/p1784538117948119?thread_ts=1784533620.910639&cid=C063SNM8PK5): repo server 1→2, Argo CD server 1→3, Redis 1→HA; application controller and Dex unchanged. All Argo CD pods reported Ready/Running with zero restarts and no namespace warning events observed. | Direct contemporaneous maintenance report. It narrows the changed components and reports a green Argo CD control plane immediately after the change. |
| 11:33:36 | [Tiago Santos Rios reports](https://grid-eneco.enterprise.slack.com/archives/C063SNM8PK5/p1784540016893419?thread_ts=1784533620.910639&cid=C063SNM8PK5) two applications as unhealthy and asks whether they are related to the maintenance. | Direct report of the symptom and the causal question. The application names are not in this message. |
| 11:38:20 | [Alex Torres replies](https://grid-eneco.enterprise.slack.com/archives/C063SNM8PK5/p1784540300491139?thread_ts=1784533620.910639&cid=C063SNM8PK5) that it does not seem related because the error is "Back-off Pulling Image," while explicitly saying he will cross-check. | Direct preliminary diagnosis; appropriately provisional at this point. |
| 11:39:23 | [Fabrizio Zavalloni states](https://grid-eneco.enterprise.slack.com/archives/C063SNM8PK5/p1784540363971819?thread_ts=1784533620.910639&cid=C063SNM8PK5), "It is trying to pull latest version of the pod in dev." | Direct image/tag observation in DEV. |
| 11:39:40 | [Fabrizio Zavalloni states](https://grid-eneco.enterprise.slack.com/archives/C063SNM8PK5/p1784540380760209?thread_ts=1784533620.910639&cid=C063SNM8PK5), "This is not related to this maintenance." | Direct operator conclusion rejecting the causal relationship. |
| 11:40:55 | [Fabrizio links](https://grid-eneco.enterprise.slack.com/archives/C063SNM8PK5/p1784540455147239?thread_ts=1784533620.910639&cid=C063SNM8PK5) `VPP-Configuration/Helm/espmessageproducer/dev/values-override.yaml`. | Directly associates the investigation with `espmessageproducer` DEV configuration. It does not itself show the file contents or identify `marketinteraction`. |

The full thread contains six replies and no later correction or contradiction.

## 11:15 CEST window

A direct read of `#myriad-platform` from approximately 10:45 to 12:01 CEST found the 11:01:57 completion update and an unrelated CICD request at 11:17:19. No top-level application-failure report appeared near 11:15. The unhealthy-app report arrived in the maintenance thread at 11:33:36.

Therefore, **Slack does not support an exact 11:15 report time**. The closest load-bearing Slack events are the maintenance completion at 11:01:57 and the unhealthy-app report at 11:33:36.

## Search coverage

Read-only all-channel searches, including accessible private channels and DMs, were run with bot messages included.

| Search | Result |
|---|---|
| `espmessageproducer-eneco-vpp after:2026-07-18` | No exact hit. |
| `espmessageproducer` | Surfaced the 2026-07-20 maintenance thread via Fabrizio's `espmessageproducer/dev/values-override.yaml` link; older unrelated alert-bot hits also existed. |
| `marketinteraction-eneco-vpp after:2026-07-18` | No exact hit. |
| `marketinteraction latest/dev/values-override.yaml after:2026-07-20` | No hit. |
| `marketinteraction` without a date filter | Older, unrelated service/release discussions; no evidence connecting it to the 2026-07-20 maintenance. |
| `ImagePullBackOff after:2026-07-18` and `latest ImagePullBackOff after:2026-07-18` | No exact hit. The thread uses the human-readable phrase "Back-off Pulling Image" instead. |
| `unhealthy dev after:2026-07-18` / `apps unhealthy after:2026-07-18` | One result: Tiago's 11:33:36 report, with the full maintenance thread in context. |
| `argocd replica after:2026-07-18` / `replicas after:2026-07-18` | Four results, including the maintenance announcement, completion update, and the unhealthy-app discussion. |

Zero exact-term hits were treated as search-syntax/indexing signals rather than absence of an event; broader term searches and full-thread expansion recovered the relevant evidence.

## Direct evidence versus inference

### Directly supported by Slack

- The Argo CD replica increase completed at 11:01:57 CEST with the application controller unchanged and a contemporaneously green Argo CD control plane.
- Two DEV applications were reported unhealthy at 11:33:36 CEST.
- The observed failure class was "Back-off Pulling Image."
- A platform engineer said DEV was trying to pull the latest pod image and explicitly said the problem was unrelated to the maintenance.
- `espmessageproducer` DEV configuration was linked immediately afterward.

### Inference, not direct Slack fact

- **Likely mechanism:** an image-reference, image-publication, or registry-pull problem is a better fit than an Argo CD replica/control-plane failure. Slack identifies the pull symptom and `latest`, but does not distinguish among missing tag, registry authentication, registry reachability, or pull-policy behavior.
- **Second application identity:** Slack does not name `marketinteraction-eneco-vpp` in this thread. Treating it as the second unhealthy application depends on runtime evidence outside Slack.
- **Causal certainty:** the explicit operator statement is strong contextual evidence, but Slack alone does not independently prove non-causality. A runtime timeline showing image digest/tag availability, pod events, and workload rollout timestamps would be the behavioral proof surface.

## Attempted attack ledger

| Attack on the "unrelated" conclusion | Observation | Disposition |
|---|---|---|
| The maintenance may have restarted/reconciled workloads and thereby exposed a latent missing `latest` image, making it an indirect trigger. | The completion update says the application controller was unchanged; Slack does not provide workload pod-event or rollout timestamps. | **Residual risk:** possible indirect trigger is not falsified by Slack alone. Check pod `creationTimestamp`, `ImagePullBackOff` event timestamps, and ReplicaSet revisions against the maintenance timeline. |
| The direct "not related" statement may be a premature assertion. | It follows the pull-error observation and latest-image statement; the thread has no later correction. | **Survives context attack, not runtime attack.** Treat as strong operator evidence, not behavioral proof. |
| Both apps may share a separate bad image/tag rollout. | Slack directly links only `espmessageproducer`; no dated `marketinteraction` hit exists. | **Unverified.** Compare both deployments' image references/digests and registry availability. |
| A broad Argo CD failure would explain the two unhealthy apps. | Argo CD pods were reported Ready/Running, zero restarts, no warning events; other degraded-app reports were not found in the relevant Slack sweep. | **Weakened**, but absence of Slack reports is not cluster-wide runtime proof. |

## Evidence ceiling

- Highest achieved proof tier: **SOURCE-VERIFIED** (live Slack messages and thread expansion).
- Not achieved: **BEHAVIORAL-ACTIVATED** cluster proof for the two workloads, their image tags/digests, registry pulls, or exact pod-event timeline.
- Slack retrieval was available. No Slack messages were posted, edited, reacted to, or otherwise mutated.

