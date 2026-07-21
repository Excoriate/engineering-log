# Requirements — INC0264497 (raw harvest)

Source: ServiceNow ticket activity + operator screenshots gathered 2026-07-21.
Fill / amend later as investigation proceeds.

## Ticket

- **Number:** INC0264497
- **Title:** Eneco EET - VPP - Your connection isn't private (vpp.eneco.com)
- **URL:** https://eneco.service-now.com/esc?id=ticket&sys_id=246b4c90c3d20b10478b409dc0013146&table=incident&view=ess
- **Priority:** 2 - High
- **State (at intake):** In Progress
- **sys_id:** `246b4c90c3d20b10478b409dc0013146`

## Activity (verbatim, newest → oldest as pasted)

Alex Torres — Additional comments:

> I've been assigned to investigate this issue. Currently, troubleshooting it and checking whether it's in our end. I'll post updates in ~30 minutes or so.

Conclusion Integration — Work notes:

> Below linked flow chart is confirming that VPP Platform Foundations Team needs to be involved on this.

> https://conclusioncritical.atlassian.net/wiki/spaces/ENECO1/pages/6735134721/VPP+Incident+Intake+On-call+Routing

> In my opinion this incident needs to be investigated by VPP Platform Foundations Team(Virtual Power Plant Foundation – NL – Support)

> We observed that the certificate linked in ServiceNow is valid from May 2026 until 30-Nov-2026.
> Therefore, it is unclear why the certificate is being reported as expired on 21-Jul-2026. This behavior appears unexpected and requires further investigation.
> We also asked what happens when the user selects "Advanced" and then "Proceed to website" in the browser.
> The OC team has indicated that this workaround does not work. They are currently obtaining a screenshot of the exact error message to provide additional details for further analysis.

> At the engineer's request for additional screenshots showing what happens when selecting "Continue" and ignoring the message, the operator initially became stuck in a loop and was redirected to the same page. They are now receiving a different message.

> CMC OC has asked the engineer for an update.

> CMC OC called CMC Energy Integration EET. They are going to investigate the issue.

> Informed CAM Teams channel.

> Major incident state automatically set to accepted

> INC0264497 Created

## Screenshots (local copies)

| File | Content |
|------|---------|
| `proofs/screenshots/01-err-cert-date-invalid-optimizations.png` | Chrome: `https://vpp.eneco.com/optimizations` → NET::ERR_CERT_DATE_INVALID |
| `proofs/screenshots/02-err-cert-date-invalid-advanced-home-oauth.png` | Advanced: cert "expired in the last day"; clock Tue Jul 21 2026; URL has `#code=` OAuth fragment on `/home` |
| `proofs/screenshots/03-forbidden-after-continue-unsafe.png` | After Continue (unsafe): `/forbidden` — "Missing permissions…"; HTTPS still struck through |
| `proofs/screenshots/04-servicenow-inc0264497-activity.png` | ServiceNow activity / metadata screenshot |

## Open questions for later fill

- Exact leaf `notAfter` / thumbprint on the wire (AVD openssl)
- Which AGW listener + KV object serves apex `vpp.eneco.com`
- Whether ServiceNow-linked cert (May→30-Nov-2026) is a different object than the served leaf
