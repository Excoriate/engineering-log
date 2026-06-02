---
task_id: 2026-05-13-001
agent: pi
status: initial
summary: Identify which Sandbox VPP FBE Logic App asks Slack users whether to keep FBE enabled, then return that Logic App JSON definition.
---
TASK ANALYSIS
- Phase: Acquire | Brain: [v] | task_id: 2026-05-13-001
- Request: Use az CLI against Sandbox subscription to query vpp-fbe-autodelete-trigger, vpp-fbe-delete-handler, and vpp-fbe-deletion-trigger Logic Apps; identify which asks a Slack user whether they want to keep their FBE enabled; provide that Logic App JSON description.
- USER PRE-FRAMING: "You have az cli" + MY READ: user expects live Azure read-only query; no urgency/tone waiver.
- DOMAIN-CLASS: investigation
- CONTROL-PLANE-ARTIFACT: n
- OPS-SHAPE-ATTRIBUTE: read-only ops (az show/list queries); no mutation requested.
- CRUBVG: C/R/U/B/V/G = 1/0/1/0/1/1 -> 5 [MID:C because three Logic Apps may call each other] [ZERO:R evidence="read-only az queries"] [MID:U because resource group/API shape unknown] [ZERO:B evidence="no writes"] [MID:V because JSON can be inspected but Slack behavior may be indirect] [MID:G because subscription/resource group not yet verified] +1 for G>=1
- Phase Compression Mode: Normal + reason: investigation with live cloud context and CRUBVG 5.
- System view + Frames: Primary frame: process (Logic App trigger/action flow -> Slack prompt). Secondary frame: Sherlock hypothesis elimination + Operator read-only cloud safety. Unknown-unknown probe: resource group or workflow kind may differ; query Azure resource inventory first.
- Counterfactual: Returning the wrong Logic App JSON would mislead the user's FBE automation understanding.
- Success Criteria: Externally-witnessable: az CLI output from Sandbox subscription identifies target Logic App and JSON definition is saved under outcome and summarized; falsifier: searched definitions for Slack/user keep/enable prompt and only selected matching workflow.
- Hypotheses: H1 vpp-fbe-autodelete-trigger asks Slack before deletion [A3: inspect definition]. H2 vpp-fbe-deletion-trigger asks Slack before invoking handler [A3]. H3 vpp-fbe-delete-handler only performs deletion after a response [A3].
- SPECIALTY: eneco-fbe-troubleshoot / eneco-tools-connect-mc-environments skills likely relevant; no executable typed subagent available in visible PI tools.
- Triggers: LIBRARIAN:n | FRAME-PRIMARY:Sherlock | EVALUATOR:y | DOMAIN:y+eneco-fbe-troubleshoot | TOOLS:y
- BRAIN SCAN: dangerous assumption: Sandbox subscription is accessible and contains these exact Logic App resources; falsifier/probe: az account set + az resource/list/show; likely failure: querying wrong subscription or only workflow metadata without definition; Roster:[UNVERIFIED[blocked]: companion surface present:/Users/alextorresruiz/.pi/agent/subagents (probed ~/.pi/agent/subagents/)]
