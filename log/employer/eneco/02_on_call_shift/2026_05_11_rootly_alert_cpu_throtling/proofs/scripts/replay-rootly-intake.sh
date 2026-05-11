#!/usr/bin/env bash
# replay-rootly-intake.sh — reproduce the L-ROOTLY-* lane probes that drove
# this RCA from cold, with explicit freshness ordering.
#
# Usage: ROOTLY_API_KEY=<key> ./replay-rootly-intake.sh
#
# Each step prints a header explaining the question it answers and what the
# decision rule on its output is.

set -euo pipefail

: "${ROOTLY_API_KEY:?Set ROOTLY_API_KEY first — see eneco-tools-rootly skill}"

SCRIPTS_DIR="${HOME}/.claude/skills/eneco-tools-rootly/scripts"
SHORT_ID="ln2I9h"

echo "::1/4 — Question: what alert is ${SHORT_ID}? (canonical Rootly probe)"
echo "    Authority: Rootly v1 /alerts/{short_id} — the system that emitted the page."
echo "    Decision: HTTP 200 + non-empty payload ⇒ proceed; any error ⇒ pivot to short-id verification."
"${SCRIPTS_DIR}/rootly-alert-decode.sh" --short-id "${SHORT_ID}"
echo

echo "::2/4 — Question: is CPUThrottlingHigh in namespace eneco-vpp known-recurring?"
echo "    Authority: Rootly v1 /alerts filter:search — same source as the page."
echo "    Decision: count of firings in last 30d; per-container breakdown."
"${SCRIPTS_DIR}/rootly-api.sh" GET "/v1/alerts?filter[search]=CPUThrottlingHigh&page[size]=30" \
  | jq -r '.data[] | [.attributes.short_id, .attributes.created_at, .attributes.status, (.attributes.data.commonLabels.namespace // "?"), (.attributes.data.commonLabels.container // "?")] | @tsv'
echo

echo "::3/4 — Question: has otc-container ever fired ANY alert in this workspace?"
echo "    Authority: same /alerts filter, different search term."
echo "    Decision: enumerate all firings on the OTel Collector container — CPU + memory + others."
"${SCRIPTS_DIR}/rootly-api.sh" GET "/v1/alerts?filter[search]=otc-container&page[size]=20" \
  | jq -r '.data[] | [.attributes.short_id, .attributes.created_at, .attributes.summary] | @tsv'
echo

echo "::4/4 — Question: is this alert acked, resolved, or still open?"
echo "    Authority: Rootly v1 /alerts/{short_id} attributes.status."
echo "    Decision: triggered ⇒ live; acknowledged ⇒ someone is on it; resolved ⇒ done."
"${SCRIPTS_DIR}/rootly-api.sh" GET "/v1/alerts/${SHORT_ID}" \
  | jq -r '.data.attributes | "status=" + .status + " urgency=" + .alert_urgency.urgency + " started=" + .started_at'
