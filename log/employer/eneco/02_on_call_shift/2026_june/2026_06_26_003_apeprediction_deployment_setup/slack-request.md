Hi Platform Team,
We are planning to introduce some significant changes to the APE-Prediction application in the coming weeks, including a few breaking changes. Before proceeding, we would like to verify that the deployment configuration is set up correctly.

In the past, we have observed instances where changes intended for Acceptance (ACC) appeared to be deployed to Production (PROD).

As a precaution, could you please help us review the deployment setup and confirm:
ACC and PROD are using separate configuration paths and deployment targets.
Changes deployed to ACC cannot automatically propagate to PROD.
Whether there are any automated promotion or synchronization mechanisms between ACC and PROD that we should be aware of (e.g Helm).
We want to make sure the deployment process is fully understood and avoid any unintended impact on the production environment when rolling out these upcoming changes.

Thanks for your help.

https://grid-eneco.enterprise.slack.com/lists/T039G7V20/F0ACUPDV7HU?record_id=Rec0BDMTM2WKA

--
Extra context:

Let me search Slack for information about ape-prediction in that channel.

Found several mentions. Let me dig into the key threads for more detail.

Let me also check for IoT platform and config-related threads to round out the picture.

Here’s everything I found about ape-prediction in #myriad-platform:

Repos

The app lives in the Myriad - VPP Azure DevOps project. Three related Python repos were mentioned together:

- ‎⁠https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/ape-prediction⁠

- ‎⁠https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/FleetOptimizer⁠

- ‎⁠https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/APE-Solar-Trainer⁠

Ownership

- Team: Asset Scheduling (also referred to as “Team Green” / part of Optimum)

- Contact: Izi Hitimana confirmed ownership (Nov 2025).

- Thomas O’Brien pointed to Ricardo as a contact.

- Current Python devs (Team Green, as of Nov 2024): Satyabrat Sahoo, Sunil Soolibhavi, Sreejith Cherukandy.

- Maintenance was confirmed shared with FleetOptimizer by the same group.

Past requests & activity

- Jun 2026 — Two filed requests from the same user (U09F33W00QG, likely Santosh Phape based on the Snyk thread) via the Slack request form.

- Dec 2025 — Roel offered a 30-min session to integrate Snyk into the ape-prediction CI pipeline. Santosh accepted.

- May 2025 — Quinten (PM) requested repo access for Jaykumar Anbu to set up SonarQube pipelines across all three Python repos. Access granted via the “python devs” group in Optimum.

- Sep–Oct 2024 — Vasil submitted PRs updating ape-prediction configs and alert mailing lists.

- Sep 2024 — Artem flagged that packages in BTM, ape-prediction, and FleetOptimizer need migration to Azure Monitor OpenTelemetry Python Distro (retirement of old App Insights SDK).

- Apr 2024 — Vasil updated configs to support publishing predictions to both the new and current IoT platform (Event Hub connection strings in prod Key Vault ‎⁠vpp-appsec-p⁠).

- Mar 2024 — SonarCloud pipeline issue in the ape-prediction build, resolved by Roel.

Key infra notes

- The app uses ArgoCD for deployment (dev/acc/prd)

- Secrets in prod Key Vault ‎⁠vpp-appsec-p⁠ — devs had direct access removed at some point; changes go through CMC

- Publishes to Event Hub (IoT platform namespace)

- CI integrations: SonarCloud/SonarQube, Snyk (offered, unclear if fully integrated)

- OpenTelemetry migration flagged but no follow-up visible in the channel

Links of Slack converations related to APE preoduction
Ownership

- https://grid-eneco.slack.com/archives/C063SNM8PK5/p1762250263216059

Maintenance

- https://grid-eneco.slack.com/archives/C063SNM8PK5/p1732086417542969

Repo access & SonarQube setup

- https://grid-eneco.slack.com/archives/C063SNM8PK5/p1747307471071739

Snyk CI integration

- https://grid-eneco.slack.com/archives/C063SNM8PK5/p1765363252264929

Config & IoT Platform

- https://grid-eneco.slack.com/archives/C063SNM8PK5/p1713359884796009

- https://grid-eneco.slack.com/archives/C063SNM8PK5/p1713445583055859

Alert mailing list & config PRs

- https://grid-eneco.slack.com/archives/C063SNM8PK5/p1726755712696969

- https://grid-eneco.slack.com/archives/C063SNM8PK5/p1727692301802769

OpenTelemetry migration

- https://grid-eneco.slack.com/archives/C063SNM8PK5/p1727354225914069

SonarCloud pipeline issue

- https://grid-eneco.slack.com/archives/C063SNM8PK5/p1709559362542029

Recent filed requests

- https://grid-eneco.slack.com/archives/C063SNM8PK5/p1782293787363769

- https://grid-eneco.slack.com/archives/C063SNM8PK5/p1775804238019649
