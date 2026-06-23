<!--
slack-answer.md — DRAFT reply, NOT posted by the intake agent.
The FIX-AGENT (or the on-call human) posts this when they pick up the ticket; the
"within the hour" line is THEN their commitment. Confidence tier ~80% on the class →
"taking it + likely cause + next" (3-5 sentences), no fix claim. Ping the filer once.
No AI-tells, no @channel, EN, code-format IDs. Final gate before posting:
"would I be embarrassed to post this under my own name in #myriad-platform?"
Harvest note: nobody else is on THIS filing (the "I'm on it" thread is a separate
ArgoCDSyncAlert-noise incident — do not reference it here).
-->

<@stefan.klopf> Picking up the `operations` FBE. The facts so far: the create build (`1685434`) came back green but with infra tests at 2/4, and in ArgoCD the `operations-app-of-apps` is `OutOfSync` and showing **`Deleting`** with its last successful sync 23 days old. My **leading hypothesis — which I'm verifying read-only before I claim it** — is that this morning's terminate→recreate left the app-of-apps wedged mid-deletion rather than freshly deployed, which would explain the 404 better than the build itself.

Verifying read-only now: whether the `operations-app-of-apps` is stuck on a finalizer (a `deletionTimestamp` on the Application — what the `Deleting` badge implies), and whether any child app is hitting the source-credential gap the slot saw before. I'll follow up here within the hour with either the unstick/sync step or a clear next move — and I'm explicitly **not** re-running the destroy pipeline to "reset" it (that's not a rollback). Anything you tried before filing that I should know about?
