---
task_id: unspecified
agent: librarian
timestamp: 2026-06-24T00:00:00Z
status: complete

summary: |
  Microsoft Learn confirms project-scoped build-completion notifications filter by **Definition name** (string/path), not definition ID. Official REST uses POST /subscriptionquery (singular), GET eventtypes/{eventType} for filter metadata; no published `inputfilters` REST page. Spec should fix subscriptionquery URL/body and use Definition name = "B2B Behind The Meter - E2E tests" for pipeline 8951.

key_findings:
  - pipeline_filter_project_scope: CONFIRMED via Definition name field (project scope only)
  - definition_id_filter: REFUTED — not in supported fields or event type metadata
  - subscriptionsquery_url: REFUTED — official path is subscriptionquery (singular), api-version 7.1
  - inputfilters_rest: NOT PUBLISHED — use GET eventtypes/{eventType} instead
---

# ADO notification subscriptions — Microsoft docs research

**Use case:** `enecomanagedcloud` / `Myriad - VPP` / pipeline `8951` / `gp_teamAgg@eneco.com`

---

## 1. Build completed — filter fields (project / team scope)

### UI / product reference (Tier 1)

**Event:** Build → **Completed** (portal: “A build completes”)

**Filter fields (Completed):**

| Field | In official field list |
| --- | --- |
| Build controller | Yes |
| Build reason | Yes |
| Compilation status | Yes |
| **Definition name** | Yes |
| Requested by | Yes |
| Requested for | Yes |
| Status | Yes |
| Team project | Yes |
| Test status | Yes |
| **Definition ID / definitionId** | **No** |

**Source:** [Supported event types — Build events](https://learn.microsoft.com/en-us/azure/devops/organizations/notifications/oob-supported-event-types#build-events)

### REST event type metadata (Tier 1)

**Event type ID:** `ms.vss-build.build-completed-event`

**Supported scopes (event):** `project`, `collection`

**Definition name field (authoritative detail):**

| Property | Value |
| --- | --- |
| Field id | `ms.vss-build.definition-name-event-field` |
| Display name | `Definition name` |
| Operators | `=`, `<>`, `Contains` |
| Event path | `tb1:Definition/@FullPath` |
| **supportedScopes** | **`project` only** |

**Other build-completed filter fields** (same GET): Build controller, Build reason, Compilation status, Requested by, Requested for, Status, Team project (collection scope only), Test status — each with operators as returned by GET.

**Source:** [Event Types - Get](https://learn.microsoft.com/en-us/rest/api/azure/devops/notification/event-types/get?view=azure-devops-rest-7.1) (sample response for `ms.vss-build.build-completed-event`)

### Project Settings supports pipeline filter

**FACT:** Project Settings → Notifications → New subscription supports **Filter criteria** clauses (including pipeline-specific).

**Source:** [Manage notifications — Create email subscription](https://learn.microsoft.com/en-us/azure/devops/organizations/notifications/manage-team-group-global-organization-notifications#create-email-subscription) — Project Administrators; “Filter criteria section to configure conditional clauses”; delivery option **Custom email address**.

**Permissions:** Project notifications require **Project Administrators** ([Prerequisites table](https://learn.microsoft.com/en-us/azure/devops/organizations/notifications/manage-team-group-global-organization-notifications#prerequisites)).

---

## 2. POST create subscription — body schema

**Endpoint:** `POST https://dev.azure.com/{organization}/_apis/notification/subscriptions?api-version=7.1`

**OAuth scope:** `vso.notification_write` — “read/write access to subscriptions and read access to event metadata, including filterable field values.”

**Request body (NotificationSubscriptionCreateParameters):**

| Property | Type | Notes |
| --- | --- | --- |
| `description` | string | Subscription label |
| `filter` | ISubscriptionFilter / ExpressionFilter | `type: "Expression"`, `eventType`, `criteria.clauses[]` |
| `channel` | ISubscriptionChannel | See EmailHtml below |
| `scope` | SubscriptionScope | `{ "id": "<uuid>", "type": "project" }` — events must publish from this container |
| `subscriber` | IdentityRef | Optional; **defaults to calling user** if omitted |

**Filter clause shape** (from List/Create examples): `{ "logicalOperator": "", "fieldName": "<display name>", "operator": "=", "value": "<string>", "index": 1 }`

**EmailHtml channel (team + custom address example):**

```json
"channel": {
  "type": "EmailHtml",
  "address": "myteam@fabrikam.org",
  "useCustomAddress": true
}
```

**Project-scoped create example (scope only, personal):**

```json
"scope": { "id": "19980dff-b50a-463e-ad01-2c93628490ff" }
```

(Response may show `scope.type: "none"` while `id` is project GUID.)

**Suggested body for Myriad use case (structure only — copy exact clause from portal GET read-back):**

```json
{
  "description": "Build completes — B2B BTM E2E (8951) → gp_teamAgg",
  "filter": {
    "eventType": "ms.vss-build.build-completed-event",
    "type": "Expression",
    "criteria": {
      "clauses": [
        {
          "logicalOperator": "",
          "fieldName": "Definition name",
          "operator": "=",
          "value": "B2B Behind The Meter - E2E tests",
          "index": 1
        }
      ],
      "groups": [],
      "maxGroupLevel": 0
    }
  },
  "channel": {
    "type": "EmailHtml",
    "address": "gp_teamAgg@eneco.com",
    "useCustomAddress": true
  },
  "scope": {
    "id": "a7ef9a24-213c-4c4c-85f4-c20a7db60c43",
    "type": "project"
  }
}
```

**Caution:** Official samples redact/empty `fieldName` in responses; **verify clause via GET after portal create** before scripting POST.

**Sources:**

- [Subscriptions - Create](https://learn.microsoft.com/en-us/rest/api/azure/devops/notification/subscriptions/create?view=azure-devops-rest-7.1)
- [Subscriptions overview](https://learn.microsoft.com/en-us/rest/api/azure/devops/notification/subscriptions?view=azure-devops-rest-7.1)

---

## 3. Query project-scoped subscriptions

### Official endpoint (corrects spec typo)

| Spec currently has | Official |
| --- | --- |
| `POST .../_apis/notification/subscriptionsquery?api-version=7.1-preview.1` | `POST .../_apis/notification/subscriptionquery?api-version=7.1` |

**Body type:** `SubscriptionQuery` — not a bare `{ "scope": { ... } }` object.

| Property | Type | Description |
| --- | --- | --- |
| `conditions` | SubscriptionQueryCondition[] | OR’d when >2 conditions |
| `queryFlags` | SubscriptionQueryFlags | e.g. `includeFilterDetails` |

**SubscriptionQueryCondition fields:**

| Field | Type | Purpose |
| --- | --- | --- |
| `scope` | **string** | Scope matching subscriptions must have |
| `subscriberId` | uuid | Filter by subscriber |
| `subscriptionId` | string | Single sub |
| `filter` | ISubscriptionFilter | Match filter type/eventType |
| `flags` | SubscriptionFlags | e.g. teamSubscription |

**Example (by subscriber — official):**

```http
POST https://dev.azure.com/fabrikam/_apis/notification/subscriptionquery?api-version=7.1

{
  "conditions": [
    { "subscriber": "552e2388-e9bb-429e-ad71-c2fef2ad085f" }
  ]
}
```

**Project-scoped query (inferred from schema — not in official example):**

```json
{
  "conditions": [
    { "scope": "a7ef9a24-213c-4c4c-85f4-c20a7db60c43" }
  ],
  "queryFlags": "includeFilterDetails"
}
```

**OAuth scope:** `vso.notification`

**Source:** [Subscriptions - Query](https://learn.microsoft.com/en-us/rest/api/azure/devops/notification/subscriptions/query?view=azure-devops-rest-7.1)

---

## 4. “inputfilters” / filter metadata for `ms.vss-build.build-completed-event`

### No published REST operation named `inputfilters`

[Event Types REST](https://learn.microsoft.com/en-us/rest/api/azure/devops/notification/event-types?view=azure-devops-rest-7.1) documents only:

- **Get** — `GET /_apis/notification/eventtypes/{eventType}?api-version=7.1`
- **List** — `GET /_apis/notification/eventtypes?api-version=7.1`

**Use Get for filter field catalog** (replaces informal “inputfilters” probe):

```http
GET https://dev.azure.com/enecomanagedcloud/_apis/notification/eventtypes/ms.vss-build.build-completed-event?api-version=7.1
```

**Field dropdown values:** JS SDK `NotificationRestClient.queryEventTypes(FieldValuesQuery, eventType)` — [NotificationRestClient](https://learn.microsoft.com/en-us/javascript/api/azure-devops-extension-api/notificationrestclient#azure-devops-extension-api-notificationrestclient-queryeventtypes) — **no matching learn.microsoft.com REST page** found (Tier 2 / SDK-only).

**Related but different API (Service Hooks, not email notifications):** `POST /_apis/hooks/publishers/tfs/inputValuesQuery` uses `publisherInputs.definitionName` for `build.complete` — [Publishers - Query Input Values](https://learn.microsoft.com/en-us/rest/api/azure/devops/hooks/publishers/query-input-values?view=azure-devops-rest-7.1). Do not conflate with Notification subscriptions.

---

## 5. Confirm / refute spec claims

| Claim | Verdict | Evidence |
| --- | --- | --- |
| Pipeline-specific filter at **Project Settings** | **CONFIRMED** | Manage notifications + Definition name field with `supportedScopes: ["project"]` |
| Filter field is **Definition name**, not definition ID | **CONFIRMED** | oob-supported-event-types + Event Types Get field list (no id field) |
| Filter by numeric **8951** in notification UI/API | **REFUTED** | No definition-id field; Service Hooks use `definitionName` string in separate API |
| `subscriptionsquery` endpoint | **REFUTED** | Official: `subscriptionquery` |
| `inputfilters` as documented Notification REST | **NOT FOUND** | Use `GET eventtypes/{eventType}` |
| Empty `criteria.clauses` matches all builds | **CONFIRMED (mechanism)** | Troubleshooting: all filter conditions must match; empty = no restriction — [Troubleshoot notification emails](https://learn.microsoft.com/en-us/azure/devops/organizations/notifications/troubleshoot-not-getting-email#inspect-subscription-filter-conditions) |

---

## 6. Spec update checklist (for coordinator)

1. Fix REST list URL: `subscriptionquery` + `api-version=7.1` + `conditions[]` body.
2. Keep portal path: Definition name = `B2B Behind The Meter - E2E tests` (map from definitionId 8951 operationally, not in filter).
3. Replace “probe inputfilters” with `GET .../eventtypes/ms.vss-build.build-completed-event`.
4. REST create: keep EmailHtml + useCustomAddress + project scope; copy clauses from GET read-back after portal proof.
5. Optional failed-only: add clause on **Status** field (`= Failed`) per Event Types Get operators.

---

## Source index (Tier 1)

| Topic | URL |
| --- | --- |
| Build filter fields (UI) | https://learn.microsoft.com/en-us/azure/devops/organizations/notifications/oob-supported-event-types#build-events |
| Project notifications UI | https://learn.microsoft.com/en-us/azure/devops/organizations/notifications/manage-team-group-global-organization-notifications |
| Create subscription REST | https://learn.microsoft.com/en-us/rest/api/azure/devops/notification/subscriptions/create?view=azure-devops-rest-7.1 |
| Query subscriptions REST | https://learn.microsoft.com/en-us/rest/api/azure/devops/notification/subscriptions/query?view=azure-devops-rest-7.1 |
| Get event type (filter metadata) | https://learn.microsoft.com/en-us/rest/api/azure/devops/notification/event-types/get?view=azure-devops-rest-7.1 |
| Event types list | https://learn.microsoft.com/en-us/rest/api/azure/devops/notification/event-types/list?view=azure-devops-rest-7.1 |
| Filter troubleshooting | https://learn.microsoft.com/en-us/azure/devops/organizations/notifications/troubleshoot-not-getting-email |
| Service Hooks definitionName (separate API) | https://learn.microsoft.com/en-us/rest/api/azure/devops/hooks/subscriptions/create?view=azure-devops-rest-7.1 |

**Confidence:** High (90–95%) on filter fields, event type id, create/query endpoints — all Tier 1 Microsoft Learn. Medium on exact `fieldName` string in POST clauses until live GET read-back.
