---
name: generate-dashboard-items
description: Generates and maintains dashboard items, the tiles of the application dashboard, as a dashboard import process, a Petriflow process whose only logic is an upload event action that creates dashboard items (DashboardItemBody) and lists them in the dashboard management case (DashboardManagementBody) through the NAE dashboard API. Use when the user wants to add, change, reorder or remove dashboard items, tiles or shortcuts on the dashboard, link a tile to a menu item or an external URL, or mentions "dashboard", "dashboard item", "createDashboardItem" or "main_dashboard". Not for menu items or views (use generate-menu-import), not for designing business processes (use generate-process) and not for only validating or deploying (use test-process).
compatibility: Requires the petriflow-mcp MCP server (http://localhost:3000/mcp). Live tests also need a running local NAE with the engine-mcp MCP (http://localhost:8080/mcp).
metadata:
  tested: false
  mcp-server: petriflow-mcp, engine-mcp
  version: 0.1.0
---

# Generate Dashboard Items

## Overview

In NAE 7 the dashboard is data, like the menu. Every tile is a case of the
engine process `dashboard_item`; the dashboard itself is a case of the engine
process `dashboard_management` that lists the tiles. An internal tile points to
a menu item (a case of `menu_item`), an external tile to a URL.

A **dashboard import** is a separate process in the application whose only job
is to create and update those cases. It has:

- one `<processEvents>` block with a single `<event type="upload">` and
  `<actions phase="post">`, so its actions run every time the process is
  deployed (re-deploy = dashboard update);
- one `<action>` per dashboard, which builds `DashboardItemBody` objects,
  passes them to the dashboard API of `ActionDelegate`, then lists the items
  in the dashboard management case;
- one placeholder `<transition>` (the schema requires one) and no roles, so
  nobody can create cases of it.

Default location: `processes/<app_name>/dashboard_import.xml`, deployed after
the menu import. If the user prefers it, the actions can instead go into the
existing `menu_import.xml`, after the menu item each tile points to. Ask when a
menu import already exists.

Template and API reference: `references/dashboard-api.md`.

## Critical rules 

- Never write API calls from memory. Methods the Petriflow MCP lists
  (`createDashboardItem`, `findDashboardItem`, `updateDashboardItem`,
  `createDashboardManagement`, `findDashboardManagement`,
  `updateDashboardManagement`, `createOrUpdateMenuItem`, `i18n`, ...) are
  checked with `list_actions` / `get_action`. Body classes and their setters
  come only from `references/dashboard-api.md`. If the MCP does not list a
  dashboard method, say so in the report and rely on the reference.
- NAE 7 classes only:
  `com.netgrif.application.engine.objects.workflow.domain.menu.dashboard...`.
  Never the NAE 6 package `com.netgrif.application.engine.menu.domain.dashboard`
  (the example in the engine test resources uses it).
- `createDashboardItem(body)` returns an existing item with the same id
  **unchanged**, so it is safe on every re-deploy. Do not call
  `updateDashboardItem` on an existing item: in NAE 7.0.3 it fails with
  `Dashboard item with given ID already exists` and leaves the item stuck (see
  "Live test findings" in the reference). To change a tile, tell the user it
  cannot be updated by an import yet.
- The engine imports the dashboard processes only with
  `netgrif.engine.dashboard.enabled=true` (set in the starter
  `docker-compose.yaml`). Check it before the first deploy.
- `updateDashboardManagement` replaces the whole item list and resets the
  toolbar flags (`simpleDashboard`, `profileDashboard`, `languageDashboard`,
  `logoutDashboard`) to `false` unless set. Always merge the existing items
  with the new ones and set the flags explicitly.
- A tile needs the `stringId` of its menu item, so the menu item must exist
  before the tile: create it earlier in the same action or deploy the menu
  import first. Never hard-code a case id.
- Identifiers (snake_case) are unique across the whole deployment.
- Do not wrap calls in empty `try/catch`. A broken tile must fail the upload
  visibly, not disappear from the dashboard.

## Steps

1. **Collect the tiles.** From the user, per tile: identifier, name with
   translations (`sk`, `en`, plus any other locale the user names), Material
   icon, target (menu item identifier, or external URL), icon color, font color
   and weight, whether it inherits name and icon from the menu item, active or
   not, position. Also the dashboard: id (existing one such as `main_dashboard`
   or a new one), name, logo, toolbar parts. Ask when the target is unclear; do
   not guess.
2. **Read the application.** Read `processes/<app_name>/menu_import.xml` and
   the README. Every menu item identifier a tile points to must be created
   there (or by the same action). Check ids of referenced processes.
3. **Look up the API.** Latest Petriflow version via `list_versions`, then
   `get_action` for each MCP-listed method you use, then
   `references/dashboard-api.md` for the rest.
4. **Write the process** `processes/<app_name>/dashboard_import.xml` with id
   `<app_name>/dashboard_import`, from the template in the reference. Write and
   check the Groovy by the rules of the `generate-action` skill (the upload
   event follows the same rules).
5. **Application README.** Add the dashboard import to
   `processes/<app_name>/README.md` (template in `generate-process`) and put it
   last under "Deploy order", after the menu import. Add it to the process map
   as a node with a `-.->` arrow labelled `dashboard` to the menu import.
6. **Validate and test** with the `test-process` skill: Stage 1
   (`validate_process` until clean); Stage 2 only with the user's approval,
   deploying referenced processes and the menu import first. Then check the
   dashboard at http://localhost:4200 and errors in `nae/engine/logs/nae.log`.

## Quick reference

| Need                        | How                                                                                         | Note                                                                                             |
|-----------------------------|---------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------|
| Tile to a menu item         | `new DashboardItemBody(id, menuItem.stringId, icon, name, true)`, `setActive(true)`         | `menuItems` holds one menu item `stringId`.                                                      |
| Tile to an external URL     | `body.setInternal(false)`, `body.setExternalUrl("https://...")`                             | Use `setInternal`, not `setIsInternal`. See the quirk about `externalIcon` in the reference.     |
| Name and icon from the menu | `body.setInheritName(true)`, `body.setInheritIcon(true)`                                    | Stock 7.0.3 ignores `itemIcon` and `name` anyway: the tile shows those of its menu item.         |
| Look                        | `setIconColor`, `setFontColor`, `setFontWeight`                                             | Strings, CSS values.                                                                             |
| Hide a tile                 | `body.setActive(false)`                                                                     | Default for a body built without `setActive(true)` is inactive.                                  |
| New dashboard               | `createDashboardManagement(new DashboardManagementBody(id, name))`                          | Returns the existing one when the id exists.                                                     |
| Add tiles to a dashboard    | merge existing options with `[(item.stringId): item.title]`, `updateDashboardManagement`    | Existing options: `mgmt.dataSet["dashboard_item_list"].options`. Key order is the tile order.    |
| Change an existing tile     | not possible by import yet                                                                  | `updateDashboardItem` fails in 7.0.3 (see reference). Do not use it.                             |
| Remove a tile               | drop it from the merged map and call `updateDashboardManagement`                            | The `dashboard_item` case stays; there is no delete method.                                      |

## Example

User says: "Put a Leave requests tile on the main dashboard, blue icon, only
active."
Actions: read `processes/leave/menu_import.xml` (menu item `leave_requests`) →
`get_action` for `createDashboardItem`, `findMenuItem`,
`updateDashboardManagement` → write
`processes/leave/dashboard_import.xml`: find the menu item `leave_requests`,
body `leave_requests_tile` (icon and name come from the menu item, so set
`event_available` on its `MenuItemBody`), `setIconColor("blue")`,
`setActive(false)` (the engine activates it), `createDashboardItem`, merge into `main_dashboard` keeping the existing tiles
and flags → README deploy order → `validate_process` clean → deploy after
approval → tile checked in the UI.
Result: one validated dashboard import, the README and a report.

## References

- `references/dashboard-api.md`: the dashboard part of `ActionDelegate` for NAE
  7.0.3 (signatures, body classes, constants, engine quirks) and the process
  template. Read it before step 4.
- Source of truth when the reference is not enough:
  `../application-engine` at tag `v7.0.3`, the dashboard methods in
  `application-engine/src/main/groovy/com/netgrif/application/engine/petrinet/domain/dataset/logic/action/ActionDelegate.groovy`,
  services `DashboardItemServiceImpl` and `DashboardManagementServiceImpl`, body
  classes in `nae-object-library`, package
  `com.netgrif.application.engine.objects.workflow.domain.menu.dashboard`, and
  the processes `petriNets/engine-processes/dashboard_item.xml` and
  `dashboard_management.xml`. Check the version matches the NAE image in
  `docker-compose.yaml`.

## Troubleshooting

**Upload fails with `NullPointerException` on `menuItem.stringId`.**
Cause: the menu item does not exist yet (`findMenuItem` returned null).
Solution: deploy the menu import first, or create the menu item in the same action.

**A re-deploy does not change the tile.**
Cause: `createDashboardItem` returns the existing item unchanged.
Solution: none by import in 7.0.3; `updateDashboardItem` fails (see reference).
Say so to the user.

**A re-deploy creates a duplicate tile, or the tile is stuck inactive.**
Cause: a ghost document of a deleted case in Elasticsearch hides the existing
item from `createDashboardItem`; or `updateDashboardItem` was called and left
the item with an assigned task.
Solution: remove the ghost or the stuck case, never call `updateDashboardItem`.

**Tiles or toolbar parts disappear after adding one tile.**
Cause: `updateDashboardManagement` was called with only the new tile, or without
the toolbar flags.
Solution: merge the existing options and set the four flags explicitly.

**`updateDashboardManagement` fails with a null case.**
Cause: `findDashboardManagement(id)` found nothing (wrong id, or the dashboard
was never created).
Solution: use `createDashboardManagement` when the find returns null.

**The tile is not visible.**
Cause: the item is inactive, it is not in the dashboard management list, or the
user cannot see its menu item (roles).
Solution: `setActive(true)`, check the merged list, check the roles of the menu item.

**Petriflow MCP does not answer.**
Cause: the server is not running or not configured.
Solution: tell the user and stop. Do not write the action from memory.

## Output

The file written and its process id; the dashboard as a list (dashboard id,
tile identifier, name, target, active); the API methods used; the README
change; the `validate_process` result; the Stage 2 result or why it did not run.

## Common mistakes

- NAE 6 package `...menu.domain.dashboard` instead of `...objects.workflow.domain.menu.dashboard`.
- `createDashboardItem(body)` on a re-deploy and expecting an update.
- `updateDashboardManagement` with only the new tile, dropping the others and the toolbar flags.
- `setIsActive` / `setIsInternal` instead of `setActive` / `setInternal`.
- A tile created before its menu item exists, or a hard-coded menu item case id.
- Deploying the dashboard import before the menu import.
- No placeholder transition: the schema rejects a document without one.
- `defaultRole` or `anonymousRole` left `true`, so users can create cases of the import.
- Empty `try/catch` around items, hiding failures.
- Unused leftovers from copied examples (debug logs, unused variables).
