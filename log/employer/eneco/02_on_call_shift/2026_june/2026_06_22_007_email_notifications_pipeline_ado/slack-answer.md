# Slack reply (ready to paste)

> _Tier: high confidence on mechanics (verified against Microsoft Learn). Offers both routes because the only open variable is "who receives it". Add the filer's @name._

---

Hey @<filer> :wave: — happy to help with the access. Before we grant anything though: for emails **to yourself you don't actually need any extra rights**. The Project Settings → Notifications page you found is for *shared* (team/project-wide) subscriptions, which is why it's locked down. There's a personal route that any project member can self-serve:

**User settings (gear, top-right) → `Notifications` → `New subscription` → `Build` → "A build completes"** — scope it to **Myriad - VPP** and add a filter on **Build pipeline = your pipeline (`8951`)**. That delivers to your inbox, no grant needed. :white_check_mark:

If you instead want it going to a **whole team or a shared distribution list**, tell me the team + the address and we'll set up a shared subscription for you — for that we'd add you as **Team Administrator** of your team (the minimum right needed; not full project admin).

I've written up both routes + the CLI/REST equivalent here if useful: `how-to-enable-ado-build-email-notifications`. Let me know which one fits and I'll confirm it's firing. :slightly_smiling_face:
