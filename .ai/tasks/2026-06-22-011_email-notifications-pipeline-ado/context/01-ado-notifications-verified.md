---
task_id: 2026-06-22-011
agent: librarian
status: complete
timestamp: 2026-06-22
summary: >
  Microsoft Learn-verified facts for an Azure DevOps "build completes" email
  notification how-to (org enecomanagedcloud, project Myriad - VPP, build def 8951).
  CONFIRMED from PRIMARY docs: personal vs shared subscription UI paths and that
  personal subscriptions need NO elevated permission (Project member only); the
  permission ladder for project/team shared subscriptions (Project Administrators
  for project; Team Administrator role for team-level, least-privilege); the
  Notifications REST create endpoint (POST _apis/notification/subscriptions),
  api-version 7.1, full request-body schema, channel EmailHtml with address +
  useCustomAddress; the build-completed event type id ms.vss-build.build-completed-event
  and the GET _apis/notification/eventtypes listing endpoint; and the Azure DevOps
  AAD resource GUID 499b84ac-1321-427f-aa17-267ca6975798 for az rest / token audience.
  UNVERIFIED: the exact az devops invoke --area/--resource names for the notification
  area, and whether the build-completed filter supports a definition-id criterion
  clause (Definition name is a documented filter FIELD, but the REST clause
  fieldName/value for a specific pipeline id is not shown in first-party docs).
---

# Azure DevOps Email Notifications — Microsoft Learn Verified Facts

Context: An Azure DevOps user (org `enecomanagedcloud`, project `Myriad - VPP`) wants
email notifications when a specific pipeline (build definition id `8951`) completes.
They lack edit rights for Project Settings → Notifications. This document verifies the
load-bearing facts for a how-to covering both the self-serve personal route and the
shared admin route, with portal steps and `az`/REST commands.

Evidence labels: `A1 FACT` = externally witnessed (here: Microsoft Learn page content
retrieved via the Microsoft Docs MCP). `A2 INFER` = derived from A1 by named reasoning.
`A3 UNVERIFIED` = could not confirm from a first-party Microsoft source.

All claims below are CONFIRMED against Microsoft Learn unless explicitly marked
UNVERIFIED. Authority tier: 1 (official Microsoft Learn). Freshness: CURRENT (pages
carry the `view=azure-devops` current channel and the live REST 7.1 reference).

---

## 1. Personal notification subscriptions (self-serve route)

**Where to create them (modern UI):** `User settings` (the gear icon, top-right) →
`Notifications` (also labeled `Notification settings` in earlier nav). This opens the
personal `User settings > Notifications` page where you select `New subscription`. (A1 FACT)

> "To open your personal notifications, select the **User settings** icon in Azure
> DevOps, and then select **Notifications** or **Notification settings**."
> — https://learn.microsoft.com/azure/devops/organizations/notifications/unsubscribe-default-notification?view=azure-devops

> "From your Notifications page, select **New subscription** … Select the **Category**
> and the **Template** type … The following example shows a subscription to receive
> notifications when a pull request is created **within a specific project**."
> — https://learn.microsoft.com/azure/devops/organizations/notifications/manage-your-personal-notifications?view=azure-devops#add-custom-notification-subscription

**Can a personal "A build completes" subscription be scoped to a specific project?**
Yes. (A1 FACT) The "Build completes" template is explicitly listed among the templates
that can be used "for yourself, a team, or a group," and the custom-subscription dialog
lets you scope to a specific project (the doc's worked example scopes a personal
subscription "within a specific project"). The build "Completed" event type also exposes
a **Definition name** filter field.

> Supported templates "for yourself, a team, or a group" include Build → "A build
> completes." — https://learn.microsoft.com/azure/devops/organizations/notifications/oob-built-in-notifications?view=azure-devops#supported-subscriptions

> Build "Completed" event type filterable **Fields** include: "Build controller, Build
> reason, Compilation status, **Definition name**, Requested by, Requested for, Status,
> Team project, Test status."
> — https://learn.microsoft.com/azure/devops/organizations/notifications/oob-supported-event-types?view=azure-devops

**Scoping to a specific build pipeline (definition id 8951):**
- Project scoping: CONFIRMED (A1 FACT, via the project-scoped subscription example and
  the `scope` field in REST, see §4).
- Pipeline/definition filtering: the **Definition name** filter field is documented
  (A1 FACT above), so the portal "New subscription" dialog for the build "Completed"
  template lets you add a filter clause on the definition. UNVERIFIED whether the field
  matches on definition **name** vs **id 8951** in the criteria clause — the docs name
  the field as "Definition name," not a numeric id. (A3 UNVERIFIED — see GAPS.)

**Does creating a PERSONAL subscription require elevated permission?**
No. Any project member can create their own personal subscription. (A1 FACT) The role
required to manage **Personal notifications** is simply "User," and the prerequisite for
the personal-notifications article is only "Project member."

> Notification types table — "Personal notifications | Role required to manage: **User**."
> — https://learn.microsoft.com/azure/devops/organizations/notifications/about-notifications?view=azure-devops#notification-types

> Manage your personal notifications — Prerequisites: "Project access | **Project member**."
> — https://learn.microsoft.com/azure/devops/organizations/notifications/manage-your-personal-notifications?view=azure-devops

> Default permissions quick reference — "Set personal notifications or alerts" is checked
> for Readers, Contributors, and Team admins (i.e. no admin role needed).
> — https://learn.microsoft.com/azure/devops/organizations/security/permissions-access?view=azure-devops#notifications,-alerts,-and-team-collaboration-tools

**Bottom line for Q1:** The user does NOT need the admin to grant anything for the
self-serve route. They can create a personal "A build completes" subscription scoped to
the `Myriad - VPP` project today, filtered by Definition name, delivered to their email.

---

## 2. Shared subscriptions — PROJECT level (admin route)

**Where managed:** `Project Settings` → `Notifications`, then `New subscription`. (A1 FACT)

> "Sign in to your organization … Select **Project settings > Notifications** … On the
> **Notifications** page for the project, select **New subscription**. Select the
> **Category** and the **Template** type."
> — https://learn.microsoft.com/azure/devops/organizations/notifications/manage-team-group-global-organization-notifications?view=azure-devops#create-email-subscription

**Exact permission/group required:** Member of the **Project Administrators** group
(or Project Collection Administrators). (A1 FACT)

> Notification types table — "**Project notifications** | Role required to manage:
> Member of the **Project Administrators** group or **Project Collection Administrators**
> group." — https://learn.microsoft.com/azure/devops/organizations/notifications/about-notifications?view=azure-devops#notification-types

> Manage-team article Prerequisites — "**Project notifications**: Member of the
> **Project Administrators** group."
> — https://learn.microsoft.com/azure/devops/organizations/notifications/manage-team-group-global-organization-notifications?view=azure-devops

Note on the older permission model (A1 FACT, but framed as legacy): there is **no UI
permission** for notifications; the underlying grants map to "**Edit project-level
information**" (project) and "Edit collection-level information" (collection):

> "There are no UI permissions associated with managing email notifications … Members of
> the **Project Administrators** group, or users who have **Edit project-level
> information** permissions can set alerts in that project for others or for a team."
> — https://learn.microsoft.com/azure/devops/organizations/notifications/about-notifications?view=azure-devops#subscriptions

So: the admin grant the user asked for is effectively **adding them to Project
Administrators** (or the equivalent "Edit project-level information" permission). There
is no narrower named "Edit project-level notifications" toggle.

---

## 3. Shared subscriptions — TEAM level (least-privilege grant)

**Can a Team Administrator manage team-level subscriptions WITHOUT being a full Project
Administrator?** Yes. (A1 FACT) This is the least-privilege option.

> Notification types table — "**Team notifications** | Role required to manage:
> **Team Administrator**, or member of the Project Administrators group or Project
> Collection Administrators group."
> — https://learn.microsoft.com/azure/devops/organizations/notifications/about-notifications?view=azure-devops#notification-types

> Manage-team article Prerequisites — "**Team notifications**: Member of the Project
> Administrators group or **team administrator** role."
> — https://learn.microsoft.com/azure/devops/organizations/notifications/manage-team-group-global-organization-notifications?view=azure-devops

> Default permissions quick reference — "Set team notifications or alerts" is checked for
> **Team admins** and Project admins (not plain Contributors).
> — https://learn.microsoft.com/azure/devops/organizations/security/permissions-access?view=azure-devops#notifications,-alerts,-and-team-collaboration-tools

**Least-privilege recommendation (A2 INFER from the three A1 facts above):** If the team
genuinely needs a *shared* build-completes subscription, the admin should add the user as
a **Team Administrator** of the relevant team rather than to Project Administrators — it
is the minimum role that can create/edit team-scoped subscriptions. Team-level
subscriptions are managed the same way as project-level (Project Settings → Notifications;
Project Administrators manage project-level notifications "in the same way as team-level
notifications," per
https://learn.microsoft.com/azure/devops/organizations/settings/about-settings?view=azure-devops#project-administrator-role-and-managing-projects).

> How to add a team administrator:
> https://learn.microsoft.com/azure/devops/organizations/settings/add-team-administrator?view=azure-devops

---

## 4. Notifications REST API

Reference root:
https://learn.microsoft.com/rest/api/azure/devops/notification/?view=azure-devops-rest-7.1

### 4a. Create endpoint — CONFIRMED

```http
POST https://dev.azure.com/{organization}/_apis/notification/subscriptions?api-version=7.1
```

(A1 FACT) The literal template in the reference is
`POST https://{service}dev.azure.com/{organization}/_apis/notification/subscriptions?api-version=7.1`
where `{service}` is normally empty for `dev.azure.com`.
— https://learn.microsoft.com/rest/api/azure/devops/notification/subscriptions/create?view=azure-devops-rest-7.1

For org `enecomanagedcloud`:
`POST https://dev.azure.com/enecomanagedcloud/_apis/notification/subscriptions?api-version=7.1`

### 4b. Current stable api-version — CONFIRMED: `7.1`

(A1 FACT) The Create reference page states: "api-version … This should be set to **'7.1'**
to use this version of the api." `7.1` is the current generally-available REST version
(the REST root is also published under 7.2). The Notification create/list operations
are documented under `azure-devops-rest-7.1`.
- Create: https://learn.microsoft.com/rest/api/azure/devops/notification/subscriptions/create?view=azure-devops-rest-7.1
- Versioning rules: https://learn.microsoft.com/azure/devops/integrate/concepts/rest-api-versioning?view=azure-devops

Note (A1 FACT): The underlying .NET/JS clients label `CreateSubscriptionAsync` /
`createSubscription` as `[Preview API]`, but the REST surface itself is documented and
callable at `7.1` (non-preview). If a `7.1` call is rejected in a given org, the
documented fallback form is the preview revision `7.1-preview.1`.
— https://learn.microsoft.com/dotnet/api/microsoft.visualstudio.services.notifications.webapi.clients.notificationhttpclient.createsubscriptionasync?view=azure-devops-dotnet

### 4c. Request body JSON schema — CONFIRMED

(A1 FACT) Fields of `NotificationSubscriptionCreateParameters`:

| Field | Type | Meaning |
| --- | --- | --- |
| `description` | string | Brief description (typically the filter criteria). |
| `filter` | ISubscriptionFilter | Matching criteria. For event subscriptions, `type: "Expression"` with `eventType` + `criteria.clauses`. |
| `channel` | ISubscriptionChannel | Delivery channel (email — see §6). |
| `scope` | SubscriptionScope | Container the events must be published from. `scope.id` = project UUID; omit to default to the whole org/collection. |
| `subscriber` | IdentityRef | User or group that receives the notifications. Defaults to the **calling user** if omitted → that is exactly the personal-subscription case. |

— https://learn.microsoft.com/rest/api/azure/devops/notification/subscriptions/create?view=azure-devops-rest-7.1

**Documented example — personal subscription scoped to a project** (verbatim from the
reference, adapted to a build-completed event). The reference's own example uses
`ms.vss-work.workitem-changed-event`; here we substitute the build event id confirmed in
§4d and the project scope id:

```json
{
  "description": "Pipeline 8951 build completes (Myriad - VPP)",
  "filter": {
    "eventType": "ms.vss-build.build-completed-event",
    "criteria": {
      "clauses": [],
      "groups": [],
      "maxGroupLevel": 0
    },
    "type": "Expression"
  },
  "channel": {
    "type": "EmailHtml"
  },
  "scope": {
    "id": "<Myriad-VPP-project-UUID>"
  }
}
```

The verbatim Microsoft example body (work-item variant) for structure reference:

```json
{
  "description": "All changes to work items in the Fabrikam project",
  "filter": {
    "eventType": "ms.vss-work.workitem-changed-event",
    "criteria": { "clauses": [], "groups": [], "maxGroupLevel": 0 },
    "type": "Expression"
  },
  "channel": { "type": "EmailHtml" },
  "scope": { "id": "19980dff-b50a-463e-ad01-2c93628490ff" }
}
```

Documented **team** (shared) variant uses a `subscriber.id` (the team's identity) and a
custom email address:

```json
{
  "description": "A new work item enters our area path",
  "filter": { "eventType": "ms.vss-work.workitem-changed-event",
    "criteria": { "clauses": [], "groups": [], "maxGroupLevel": 0 }, "type": "Expression" },
  "subscriber": { "id": "552e2388-e9bb-429e-ad71-c2fef2ad085f" },
  "channel": { "type": "EmailHtml", "address": "myteam@fabrikam.org", "useCustomAddress": true }
}
```

(A1 FACT, both examples verbatim from the Create reference.)
The project UUID for `scope.id` is obtained from the Projects REST API
(`GET _apis/projects/{Myriad - VPP}`) — see
https://learn.microsoft.com/rest/api/azure/devops/core/projects.

### 4d. Build-completion event type id + how to list event types — CONFIRMED

(A1 FACT) The event type id is **`ms.vss-build.build-completed-event`**, name "Build
completed," publisher `ms.vss-build.build-event-publisher`, category
"Build" (`ms.vss-build.build-and-release-event-category`), `customSubscriptionsAllowed: true`,
supported scopes `project` and `collection`. This is the literal value in the List
sample response.

Listing endpoint:

```http
GET https://dev.azure.com/{organization}/_apis/notification/eventtypes?api-version=7.1
```

Optionally filter by publisher:

```http
GET https://dev.azure.com/{organization}/_apis/notification/eventtypes?publisherId=ms.vss-build.build-event-publisher&api-version=7.1
```

— https://learn.microsoft.com/rest/api/azure/devops/notification/event-types/list?view=azure-devops-rest-7.1

Verbatim from that page's sample response:

```json
{
  "id": "ms.vss-build.build-completed-event",
  "name": "Build completed",
  "eventPublisher": { "id": "ms.vss-build.build-event-publisher" },
  "category": { "id": "ms.vss-build.build-and-release-event-category", "name": "Build" },
  "supportedScopes": ["project", "collection"],
  "customSubscriptionsAllowed": true
}
```

(Beware near-neighbors in the same list: `ms.vss-build.build-completion-legacy-event` and
`...-legacy-event2` exist but have `customSubscriptionsAllowed: false` — do NOT use those
for a new custom subscription.)

---

## 5. az DevOps CLI

**Is there a NATIVE `az devops` notifications/subscriptions command group?**
UNVERIFIED-as-present → effectively **No** (A2 INFER). The Azure DevOps CLI reference for
`az devops` documents subgroups such as `admin`, `artifacts`, `banner`, `project`,
`security`, `team`, `user`, `wiki`, plus the generic `invoke` command — there is no
documented `az devops notification` / `az devops subscription` group.
— `az devops` reference: https://learn.microsoft.com/cli/azure/devops?view=azure-cli-latest

**Generic path 1 — `az devops invoke` (CONFIRMED the command exists):** (A1 FACT)

> "`az devops invoke` — This command will invoke request for any DevOps area and
> resource. Please use only json output … `--area` The area to find the resource.
> `--resource` The name of the resource to operate on. `--http-method` … `--in-file` …
> `--api-version` (default 5.0)."
> — https://learn.microsoft.com/cli/azure/devops?view=azure-cli-latest

So the shape `az devops invoke --area notification --resource subscriptions
--http-method POST --in-file body.json --api-version 7.1` is the correct generic *pattern*.
However, the literal strings `--area notification` and `--resource subscriptions` are
NOT enumerated in any first-party doc. (A3 UNVERIFIED — see GAPS. The area/resource map
to the REST route `_apis/notification/subscriptions`, which is a reasonable A2 INFER, but
`az devops invoke` resource names are sometimes singular/different from the URL segment;
this MUST be probed live with `az devops invoke --http-method GET --area notification
--resource eventtypes --api-version 7.1` before relying on it.) Also note the CLI default
`--api-version 5.0`, so `--api-version 7.1` must be passed explicitly.

**Generic path 2 — `az rest` against dev.azure.com (CONFIRMED the GUID):** (A1 FACT)
The Azure DevOps AAD resource/audience GUID **`499b84ac-1321-427f-aa17-267ca6975798`** is
correct and is the documented value used to acquire an Entra token for dev.azure.com.
Multiple first-party pages confirm it:

> "Generate a Microsoft Entra ID access token with the `az account get-access-token`
> command using the Azure DevOps resource ID: **`499b84ac-1321-427f-aa17-267ca6975798`**."
> — https://learn.microsoft.com/azure/devops/cli/entra-tokens?view=azure-devops

> "`# 499b84ac-1321-427f-aa17-267ca6975798` specifies azure devops as a resource
> `az rest -u https://app.vssps.visualstudio.com/_apis/profile/profiles/me --resource
> 499b84ac-1321-427f-aa17-267ca6975798`"
> — https://learn.microsoft.com/azure/devops/extend/publish/command-line?view=azure-devops#publish-with-a-microsoft-entra-token

> "Azure DevOps' resource identifier: **`499b84ac-1321-427f-aa17-267ca6975798`**;
> resource URI: `https://app.vssps.visualstudio.com`."
> — https://learn.microsoft.com/azure/devops/integrate/get-started/authentication/entra-oauth?view=azure-devops#resources-for-admins

A working `az rest` invocation pattern (A2 INFER, composed from the A1 GUID fact + the
A1 REST endpoint in §4a; the GUID + `az rest` pairing against dev.azure.com is itself
shown verbatim in the publish-from-CLI doc above):

```bash
az rest --method post \
  --uri "https://dev.azure.com/enecomanagedcloud/_apis/notification/subscriptions?api-version=7.1" \
  --resource 499b84ac-1321-427f-aa17-267ca6975798 \
  --headers "Content-Type=application/json" \
  --body @body.json
```

(The token-only alternative — `az account get-access-token --resource
499b84ac-1321-427f-aa17-267ca6975798` then pass as a `Bearer` header — is documented
verbatim at the entra-tokens page above.)

---

## 6. Email delivery channel — CONFIRMED

(A1 FACT) Email delivery uses `channel.type = "EmailHtml"`. Fields, from the
`EmailHtmlSubscriptionChannel` (which extends `SubscriptionChannelWithAddress`):

| Field | Type | Meaning |
| --- | --- | --- |
| `type` | string | `"EmailHtml"` (HTML email). A plaintext variant `"EmailPlaintext"` also exists. |
| `address` | string | The destination email address. |
| `useCustomAddress` | boolean | `true` to send to `address`; `false` (default) uses the subscriber's preferred email. |

Verbatim documented channel object (from the team example in the Create reference):

```json
"channel": { "type": "EmailHtml", "address": "myteam@fabrikam.org", "useCustomAddress": true }
```

For a personal subscription delivered to the user's preferred email, the minimal form is:

```json
"channel": { "type": "EmailHtml" }
```

and the response echoes `"channel": { "type": "EmailHtml", "useCustomAddress": false }`.

Sources:
- Create reference (channel examples + response): https://learn.microsoft.com/rest/api/azure/devops/notification/subscriptions/create?view=azure-devops-rest-7.1
- `EmailHtmlSubscriptionChannel` (type, address, useCustomAddress): https://learn.microsoft.com/javascript/api/azure-devops-extension-api/emailhtmlsubscriptionchannel
- `SubscriptionChannelWithAddress.UseCustomAddress`: https://learn.microsoft.com/dotnet/api/microsoft.visualstudio.services.notifications.webapi.subscriptionchannelwithaddress.usecustomaddress?view=azure-devops-dotnet
- `EmailPlaintextSubscriptionChannel` (plaintext alt): https://learn.microsoft.com/javascript/api/azure-devops-extension-api/emailplaintextsubscriptionchannel
- Recipient resolution (preferred vs custom address): https://learn.microsoft.com/azure/devops/organizations/notifications/concepts-email-recipients?view=azure-devops

---

## UNVERIFIED / GAPS

1. **Filtering a build-completed subscription to a specific pipeline by id (8951).**
   The build "Completed" event exposes a **Definition name** filter field (A1 FACT,
   oob-supported-event-types). What is NOT confirmed from first-party docs is the exact
   REST `criteria.clauses` entry (the `fieldName` string and whether `value` takes the
   definition **name** or the numeric **id 8951**). Microsoft's own REST examples all use
   empty `criteria.clauses`. RECOMMENDATION: build the filter in the **portal** "New
   subscription" dialog (which surfaces the Definition name field), then read the created
   subscription back via `GET _apis/notification/subscriptions/{id}?api-version=7.1` to
   capture the exact clause shape before reproducing it in code.

2. **`az devops invoke` literal `--area` / `--resource` for notifications.**
   The `az devops invoke` command is documented (A1 FACT) and the `--area`/`--resource`/
   `--in-file`/`--api-version` flags are real, but Microsoft does not publish the literal
   `notification` / `subscriptions` token values. Treat `--area notification --resource
   subscriptions` as an UNVERIFIED A2 INFER and probe it live first, e.g.
   `az devops invoke --http-method GET --area notification --resource eventtypes
   --api-version 7.1 -o json`. If `invoke` rejects the resource name, fall back to the
   CONFIRMED `az rest` path in §5.

3. **REST `7.1` vs preview for the create operation specifically.**
   The Create reference says set api-version to `7.1` (A1 FACT), yet the .NET/JS client
   methods are tagged `[Preview API]`. Not a contradiction at the REST layer, but if a
   live `7.1` POST returns a version error, the documented fallback is `7.1-preview.1`
   (UNVERIFIED whether your org requires it — probe).

4. **Whether a personal subscription can be scoped to a single pipeline AND deliver to a
   personal email simultaneously** is structurally supported (project `scope` + Definition
   name filter + `channel.EmailHtml`), but no single Microsoft example shows all three
   combined for the build event. Composition is an A2 INFER, not a verbatim A1 example.

5. **No `az devops notification` native command group** — searched the `az devops` CLI
   reference; only the generic `invoke` is available. Stated as UNVERIFIED-absent rather
   than proven-absent because CLI extension command lists can change between extension
   versions; confirm with `az devops -h` on the installed `azure-devops` extension.
