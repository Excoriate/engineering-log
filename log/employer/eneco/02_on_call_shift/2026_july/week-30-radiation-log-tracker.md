# Week 30 radiation log tracker

2026-07-20 — 2026-07-24

## Table of contents

- [Monday 2026-07-20](#monday-2026-07-20)
- [Tuesday 2026-07-21](#tuesday-2026-07-21)
- [Wednesday 2026-07-22](#wednesday-2026-07-22)
- [Thursday 2026-07-23](#thursday-2026-07-23)
- [Friday 2026-07-24](#friday-2026-07-24)

## Monday 2026-07-20

- Work on troubleshooting a failed release process due to missing variables in the variable group. Related to this documentation, which isn't clear whether it's up to date or not. https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_wiki/wikis/Myriad---VPP.wiki/53234/Release-Process
- The ArgoCD replica increase in the dev environment went smoothly. I provided feedback to Joel, a person on the other side of the fence (CMC), in the Microsoft Teams chat. I ran some proofs, and the work for this Wednesday for the acceptance environment is already confirmed. The next maintenance and the next ArgoCD replica increase will occur on Wednesday.
- I reviewed one PR that was tackling a redirect issue using Azure CLI in our pipelines. An observation about how flaky our pipelines are and how dependent on scripts they are creates a lot of friction and unnecessary issues. https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/Myriad%20-%20VPP/pullrequest/188251
- I noticed that the teams doesnt' know our pipeilnes. There was a request from one persion, regarding an alert that was expected to be deleted; bnut the pipeline never run (or it was notr ran on purpose, since it requires a manual execution). Lack of platfomr knowedlge —and perhaps documentation— makes hard to reason about our overall systems.

## Tuesday 2026-07-21

## Wednesday 2026-07-22

## Thursday 2026-07-23

## Friday 2026-07-24
