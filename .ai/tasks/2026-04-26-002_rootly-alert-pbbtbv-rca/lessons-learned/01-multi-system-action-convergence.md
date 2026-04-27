---
task_id: 2026-04-26-002
agent: claude-opus-4-7
status: complete
type: finding
summary: Every on-call RCA Recommended-Action step that touches multiple systems must drive each system to a terminal state explicitly, not assume cross-system convergence.
---

# Multi-system action convergence (on-call RCAs)

**Rule**: When an alert spans more than one system of record (e.g., Rootly downstream + Azure Monitor upstream), the Recommended-Action section must enumerate the close-path in **each** system separately. "Resolve in Rootly" is not equivalent to "close the alert in Azure".

**Why**: Rootly resolutions only close the Rootly notification record. They do not call back to mutate `Microsoft.AlertsManagement/alerts/...` resources. An on-call engineer following a one-step "resolve in Rootly" recommendation will leave the upstream Azure alert in `Fired` state indefinitely (especially when `auto_mitigate` cannot evaluate without new metric samples), where it remains visible to dashboards, secondary downstream consumers, and any future re-paging path. Caught in this task by socrates-contrarian (verification/01-adversarial-review.md, finding F1).

**How to apply**: For any RCA covering an Azure Monitor → Rootly path, include in Recommended Action:
1. Rootly close (CLI/UI) with comment.
2. Azure-side state change to `Closed` via Portal (*Investigate → Change alert state → Closed*) or `az rest POST .../Microsoft.AlertsManagement/alerts/<id>/changestate?api-version=2018-05-05&newState=Closed`.

Same pattern applies any time alert lifecycle spans plane boundaries — same shape as the AAD + Enterprise App + AppProject convergence rule already in engineering-log memory (`feedback_oncall_argocd_three_plane.md`). Distributed-state convergence requires acting at every plane that holds the state.

**Falsifier**: After the engineer follows the RCA, run `az rest GET .../alerts/<id>?api-version=2018-05-05` and assert `properties.essentials.alertState == "Closed"`. If it isn't, the RCA missed a plane.

**Promote to durable memory**: yes — this is reusable across every Eneco on-call RCA touching Rootly + Azure Monitor.
