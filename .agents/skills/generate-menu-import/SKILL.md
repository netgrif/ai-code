---
name: generate-menu-import
description: Generates a menu import process, a Petriflow process whose only logic is an upload event action that creates the application menu (menu items, folders and their views) through the NAE menu API. Use when the user wants to create or change the app menu, menu items, side navigation entries, folders in the menu, which processes or views appear in the menu and for which roles, or mentions "menu import" or MenuItemBody. Not for designing business processes (use generate-process) or for only validating or deploying (use test-process).
compatibility: Requires the petriflow-mcp MCP server (http://localhost:3000/mcp). Live tests also need a running local NAE with the engine-mcp MCP (http://localhost:8080/mcp).
metadata:
  tested: false
  mcp-server: petriflow-mcp, engine-mcp
  version: 0.1.0
---

# Generate Menu Import

## Overview

In NAE 7 the menu is data: every entry is a case of the engine process
`menu_item`, and its view (case list, task list, single task) is a case of a
view configuration process. A **menu import** is a separate process in the
application whose only job is to create those cases. It has:

- one `<processEvents>` block with a single `<event type="upload">` and
  `<actions phase="post">`, so its actions run every time the process is
  deployed (re-deploy = menu update);
- several `<action>` elements, one per menu section, that build
  `MenuItemBody` objects and pass them to the menu API of `ActionDelegate`;
- one placeholder `<transition>` (the schema requires one) and no roles, so
  nobody can create cases of it.

Template and API reference: `references/menu-api.md`.

## Critical rules

- Never write API calls from memory. Menu methods exposed by the Petriflow MCP (`createOrUpdateMenuItem`,
  `getOrCreateMenuItem`, `findMenuItem`,
  `changeMenuItem`, `moveMenuItem`, `i18n`, ...) are checked with
  `list_actions` / `get_action`. Helpers the MCP does not list (`createDefaultViewBody`, `createSingleTaskViewBody`,
  `collectRolesForPreferenceItem`, `MenuItemBody` and view body setters) come
  only from `references/menu-api.md`.
- NAE 7 classes only: `com.netgrif.application.engine.objects.workflow.domain.menu...`.
  Never the NAE 6 package `com.netgrif.application.engine.workflow.domain.menu`,
  never deprecated `*AndFilter`, `createOrUpdateCaseMenuItem`,
  `createFilterInMenu` or group-based overloads.
- Idempotent: use `createOrUpdateMenuItem(body)` (upsert by identifier). Use
  `getOrCreateMenuItem(body)` only when a re-deploy must not overwrite
  changes made in the UI. Never `createMenuItem(body)`: the second deploy
  fails on the duplicate identifier.
- The menu import is deployed last. Every process and role passed to
  `collectRolesForPreferenceItem` must already be deployed, otherwise the
  upload fails.
- Do not wrap calls in empty `try/catch`. A broken item must fail the upload
  visibly, not disappear from the menu.

## Steps

1. **Collect the menu.** From the user, per item: folder path (`/`,
   `/registers`, ...), identifier (snake_case, unique across the whole
   deployment), name with translations (`sk`, `en`, plus any other locale the
   user names), Material icon, content type (see
   Quick reference), allowed and banned roles, order, auto-select. Ask when
   the content or the roles are unclear; do not guess roles.
2. **Read the referenced processes.** List `processes/*/` and read the
   application `README.md` files and the XMLs the menu points to. Check every
   process id, role id, transition id (single-task view) and field id used in
   headers and queries.
3. **Look up the API.** Latest Petriflow version via `list_versions`, then
   `get_action` for each MCP-listed method you use, then
   `references/menu-api.md` for the rest.
4. **Write the process** `processes/<app_name>/menu_import.xml` with id
   `<app_name>/menu_import`, from the template in the reference. One action
   per top-level menu section, folders before their children. Write and
   check the Groovy by the rules of the `generate-action` skill (that skill
   covers data and task events; the upload event here follows the same
   rules).
5. **Application README.** Add the menu import to
   `processes/<app_name>/README.md` (template in `generate-process`) and put
   it last under "Deploy order".
6. **Validate and test** with the `test-process` skill: Stage 1 (`validate_process` until clean); Stage 2 only with the
   user's approval,
   deploying referenced processes first. Then check the menu at
   http://localhost:4200 and errors in `nae/nae-backend/logs/nae.log`.

## Quick reference

| Need                           | How                                                                                                             | Note                                                                                                                                                        |
|--------------------------------|-----------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Folder                         | Item with path `/` and identifier `x`; children use path `/x`                                                   | A missing folder is created automatically, named after its path segment (`x`) with icon `folder`, no translations and no roles. Create it explicitly first. |
| Frontend custom view           | `setUseCustomView(true)`, `setCustomViewSelector("...")`                                                        | Selector of a view built into the frontend container (e.g. `all-cases`, `my-tasks`); it is not created by the menu item.                                                                                         |
| Cases of a process             | `createDefaultViewBody(body, query, allowedNets, headers)`, `body.setView(view)`                                | Case list chained to a task list.                                                                                                                           |
| Open one task of a case        | `createSingleTaskViewBody(body, query, transitionId, allowedNets, headers)`                                     | Transition id must exist in the target process.                                                                                                             |
| Create button in the case list | `view.setShowCreateCaseButton(true)`, `setCreateCaseButtonTitle(i18n(...))`, `setRequireTitleInCreation(false)` | Helpers turn it off by default.                                                                                                                             |
| Roles                          | `body.setAllowedRoles(collectRolesForPreferenceItem([role: processId]))`, same for `setBannedRoles`             | Global role: value `GLOBAL_ROLE`. Empty allowed roles = no role restriction.                                                                                |
| Order                          | `body.setOrder(10d)`                                                                                            | A `Double`; leave gaps (10, 20, ...).                                                                                                                       |
| Default item after login       | `body.setAutoSelect(true)`                                                                                      | One item only.                                                                                                                                              |
| Change an existing item        | `changeMenuItem`, `moveMenuItem`, `changeMenuItemOrder`, `deleteMenuItem`                                       | Usually simpler to change the body and re-deploy.                                                                                                           |

## Example

User says: "Add the leave requests to the menu under Requests, only for the
role approver, with a button to create a request."
Actions: read `processes/leave/leave_request.xml` (id
`leave/leave_request`, role `approver`, fields for headers) → `get_action`
for `createOrUpdateMenuItem` and `i18n` → write
`processes/leave/menu_import.xml`: action 1 folder `requests`, action 2 item
`leave_requests` in `/requests` with `createDefaultViewBody`, create button on,
allowed roles `["approver": "leave/leave_request"]` → README deploy order →
`validate_process` clean → deploy after approval → menu checked in the UI.
Result: one validated menu import, the README and a report.

## References

- `references/menu-api.md`: the menu part of `ActionDelegate` for NAE 7.0.3 (signatures, body classes, role map format,
  deprecated methods) and the
  process template. Read it before step 4.
- Source of truth when the reference is not enough:
  `../application-engine` at tag `v7.0.3`, file
  `application-engine/src/main/groovy/com/netgrif/application/engine/petrinet/domain/dataset/logic/action/ActionDelegate.groovy`
  and package `com.netgrif.application.engine.objects.workflow.domain.menu` in
  `nae-object-library`. Check the version matches the NAE image in
  `nae/docker-compose.yaml`.

## Troubleshooting

**Upload fails with `IllegalArgumentException ... could not be found when collecting roles`.**
Cause: the process in the role map is not deployed, or its id is wrong.
Solution: deploy it first, use the full id `<app_name>/<process_name>`.

**Upload fails with `NullPointerException` in `collectRolesForPreferenceItem`.**
Cause: the process exists but has no role with that id.
Solution: use the role `<id>` from the process XML.

**Upload fails on a duplicate identifier.**
Cause: `createMenuItem(body)` on a re-deploy, or the same identifier twice.
Solution: `createOrUpdateMenuItem(body)`, unique identifiers.

**An item is missing in the menu.**
Cause: the user has none of the allowed roles, a banned role, or the custom
view selector is not a view built into the frontend container.
Solution: check the roles of the logged-in user and the selector.

**The case list is empty.**
Cause: the Elasticsearch query does not match, often because the process id
contains `/`.
Solution: quote the id in the query (`processIdentifier:"app/process"`), and
check that `allowedNets` holds the same id.

**Petriflow MCP does not answer.**
Cause: the server is not running or not configured.
Solution: tell the user and stop. Do not write the action from memory.

## Output

The file written and its process id; the menu as a tree (path, identifier,
name, view type, roles); the API methods used; the README change; the
`validate_process` result; the Stage 2 result or why it did not run.

## Common mistakes

- `createMenuItem(body)` instead of `createOrUpdateMenuItem(body)`.
- NAE 6 package or deprecated `createOrUpdateMenuItemAndFilter`.
- Short process ids (`leave_request`) instead of `leave/leave_request` in
  role maps, queries and `allowedNets`.
- Deploying the menu import before the processes it refers to.
- Roles guessed instead of taken from the process XML.
- No placeholder transition: the schema rejects a document without one.
- `defaultRole` or `anonymousRole` left `true`, so users can create cases of
  the menu import.
- Empty `try/catch` around items, hiding failures.
- Unused leftovers from copied examples (debug logs, unused variables).
