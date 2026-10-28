# Dashboard API reference (NAE 7.0.3)

Extract of the dashboard part of `ActionDelegate` and the body classes it uses.
Source: `../application-engine` at tag `v7.0.3`. Line numbers point into
`application-engine/src/main/groovy/com/netgrif/application/engine/petrinet/domain/dataset/logic/action/ActionDelegate.groovy`.
Body classes live in `nae-object-library`, package
`com.netgrif.application.engine.objects.workflow.domain.menu.dashboard`. When
the NAE image version in `docker-compose.yaml` changes, re-check this file
against the source.

## Contents

- Process template
- Dashboard methods
- DashboardItemBody
- DashboardManagementBody
- Constants
- Engine quirks
- Deprecated, do not use

## Process template

Passes `validate_process` (Petriflow 1.0.9, schema and semantic rules). The
Groovy of `action1` is not compiled or run yet (`validate_action` was not
available). `action1` creates or updates one tile that points to a menu item and
lists it in the dashboard `main_dashboard`, keeping the tiles already there.
Replace `hello_world`, the identifiers, names and icons with real ones.

```xml
<document xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="https://petriflow.com/petriflow.schema.xsd">
    <id>hello_world/dashboard_import</id>
    <version>1.0.0</version>
    <initials>HDI</initials>
    <title>Hello World dashboard import</title>
    <icon>device_hub</icon>
    <defaultRole>false</defaultRole>
    <anonymousRole>false</anonymousRole>
    <transitionRole>false</transitionRole>
    <processEvents>
        <event type="upload">
            <id>dashboard_import_upload</id>
            <actions phase="post">
                <action id="action1">
                    <![CDATA[
                    // Tile that opens the menu item hello_world_cases
                    def menuItem = findMenuItem("hello_world_cases")

                    def tile = new com.netgrif.application.engine.objects.workflow.domain.menu.dashboard.DashboardItemBody(
                            "hello_world_tile", menuItem.stringId, "emoji_people", i18n("Hello cases", ["sk": "Hello prípady", "en": "Hello cases"]), true)
                    tile.setActive(false) // the engine sets it to true when the item is finished
                    tile.setIconColor("blue")

                    // get-or-create: a re-deploy returns the existing item unchanged
                    def tileCase = createDashboardItem(tile)

                    // Dashboard: create when missing, then merge the tile into the existing ones
                    def dashboardCase = findDashboardManagement("main_dashboard")
                    if (dashboardCase == null) {
                        dashboardCase = createDashboardManagement(new com.netgrif.application.engine.objects.workflow.domain.menu.dashboard.DashboardManagementBody("main_dashboard", i18n("Main", ["sk": "Hlavná", "en": "Main"])))
                    }
                    def items = new LinkedHashMap(dashboardCase.dataSet["dashboard_item_list"].options ?: [:])
                    items[tileCase.stringId] = tileCase.title

                    def dashboard = new com.netgrif.application.engine.objects.workflow.domain.menu.dashboard.DashboardManagementBody()
                    dashboard.setDashboardItems(items)
                    dashboard.setSimpleDashboard(true)
                    dashboard.setProfileDashboard(true)
                    dashboard.setLogoutDashboard(true)
                    updateDashboardManagement(dashboardCase, dashboard)
                    ]]>
                </action>
            </actions>
        </event>
    </processEvents>
    <transition>
        <id>noop</id>
        <x>100</x>
        <y>100</y>
        <label>Dashboard import</label>
    </transition>
</document>
```

Notes:
- The schema requires at least one `<transition>`; `noop` has no roles, and
  `defaultRole`/`anonymousRole` are `false`, so no one can create a case of
  the import.
- `dashboardCase.dataSet["dashboard_item_list"].options` is the map
  `item stringId -> I18nString` of the current tiles; its key order is the
  tile order. `tileCase.title` is the tile name as set on creation.
- `updateDashboardManagement` computes `menuItemsToDashboardItems` itself from
  the item cases; do not set it.
- To manage several dashboards use one action per dashboard.
- The engine test resource `dashboard_management_test.xml` shows the same flow
  with the NAE 6 package names; do not copy them.

## Dashboard methods

| Line | Signature                                                           | Behavior                                                                                                                      |
|------|---------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------|
| 2592 | `Case createDashboardItem(DashboardItemBody body)`                  | Get-or-create by `body.id`: returns the existing item unchanged, or creates it and sets its data. Id is sanitized.            |
| 2600 | `Case findDashboardItem(String identifier)`                         | Item by `item_id`, or null (Elasticsearch search, so a just-created item may appear with a short delay).                      |
| 2608 | `Case updateDashboardItem(Case itemCase, DashboardItemBody body)`   | Writes all body fields into the item. **Fails on an existing item in 7.0.3 and leaves it stuck, see live test findings. Do not use.** |
| 2588 | `Case createDashboardManagement(DashboardManagementBody body)`      | Get-or-create by `body.id`. Fills `menuItemsToDashboardItems` from the item cases in `dashboardItems`.                        |
| 2596 | `Case findDashboardManagement(String identifier)`                   | Dashboard by `dashboard_id`, or null.                                                                                         |
| 2604 | `Case updateDashboardManagement(Case managementCase, DashboardManagementBody body)` | Replaces item list, item order and toolbar flags with the body values. Fills `menuItemsToDashboardItems`. |
| 2701 | `I18nString i18n(String value, Map<String,String> translations)`    | Builds a translated name.                                                                                                     |

Menu item methods used with tiles (`findMenuItem`, `createOrUpdateMenuItem`)
are in `generate-menu-import/references/menu-api.md`.

## DashboardItemBody

`@Data @Builder @AllArgsConstructor`, plus a 5-argument constructor. Lombok
names the setters of `boolean isX` fields `setInternal` and `setActive`.

| Field          | Type         | Dataset field   | Meaning                                                                    |
|----------------|--------------|-----------------|----------------------------------------------------------------------------|
| `id`           | `String`     | `item_id`       | Identifier, snake_case, unique in the deployment.                          |
| `menuItems`    | `String`     | `menu_items_list` | `stringId` of the target `menu_item` case (internal tiles).              |
| `isInternal`   | `boolean`    | `is_internal`   | `true`: opens a menu item; `false`: opens `externalUrl`.                   |
| `externalUrl`  | `String`     | `external_url`  | URL of an external tile.                                                   |
| `externalIcon` | `String`     | `external_icon` | See quirks; leave unset.                                                   |
| `iconColor`    | `String`     | `icon_color`    | Icon color.                                                                |
| `itemIcon`     | `String`     | `item_icon`     | Material icon name.                                                        |
| `fontColor`    | `String`     | `font_color`    | Title color.                                                               |
| `fontWeight`   | `String`     | `font_weight`   | Title weight.                                                              |
| `name`         | `I18nString` | `item_name`     | Title; its default value becomes the case title.                           |
| `inheritIcon`  | `boolean`    | `inherit_icon`  | Take the icon from the menu item.                                          |
| `inheritName`  | `boolean`    | `inherit_name`  | Take the name from the menu item.                                          |
| `isActive`     | `boolean`    | `is_active`     | Shown on the dashboard.                                                    |

Constructor: `DashboardItemBody(String id, String menuItems, String itemIcon, I18nString name, boolean isInternal)`.
Other fields default to `null` / `false`, so set `setActive(true)`.

## DashboardManagementBody

`@Data @Builder @AllArgsConstructor @NoArgsConstructor`.

| Field                      | Type                       | Dataset field                  | Meaning                                                                       |
|----------------------------|----------------------------|--------------------------------|-------------------------------------------------------------------------------|
| `id`                       | `String`                   | `dashboard_id`                 | Dashboard identifier.                                                         |
| `name`                     | `I18nString`               | `dashboard_name`               | Dashboard title.                                                              |
| `logo`                     | `String`                   | `dashboard_logo`               | Logo path from the frontend assets.                                           |
| `dashboardItems`           | `HashMap<String,I18nString>` | `dashboard_item_list`        | `item stringId -> title`, in display order. Also writes `items_order`.        |
| `menuItemsToDashboardItems`| `HashMap<String,I18nString>` | `dashboard_item_to_menu_item`| Computed by the service; do not set.                                          |
| `simpleDashboard`          | `boolean`                  | `simple_dashboard_toolbar`     | Toolbar with a menu of options.                                               |
| `profileDashboard`         | `boolean`                  | `profile_dashboard_toolbar`    | Toolbar with the profile menu.                                                |
| `languageDashboard`        | `boolean`                  | `language_dashboard_toolbar`   | Toolbar with language selection. See quirks.                                  |
| `logoutDashboard`          | `boolean`                  | `logout_dashboard_toolbar`     | Toolbar with a logout button.                                                 |

Constructor: `DashboardManagementBody(String id, I18nString name)`. The toolbar
flags default to `false` and are always written, `name` is written only when
`id` is set, `logo` only when not null, `dashboardItems` only when not null.

## Constants

| Process                | Process id             | Task        | Fields                                  |
|------------------------|------------------------|-------------|-----------------------------------------|
| `dashboard_item`       | `dashboard_item`       | `configuration` | see DashboardItemBody table         |
| `dashboard_management` | `dashboard_management` | `configure` | see DashboardManagementBody table, plus `add_new_item` |

Both processes ship with the engine (`petriNets/engine-processes/`); they are
not part of the application and must not be redeployed.

## Engine quirks

Read from the 7.0.3 source, not yet confirmed on a running NAE. Confirm them in
Stage 2 and update this section.

- `DashboardItemBody.toDataSet` writes `externalIcon` (a `String`) into the
  `external_icon` field as `BOOLEAN`. Leave `externalIcon` unset.
- `DashboardManagementBody.toDataSet` writes `languageDashboard` from the
  `profileDashboard` value, so `setLanguageDashboard` has no effect. Use
  `setProfileDashboard` knowing that it also drives the language toolbar, and
  tell the user.
- `createDashboardManagement` and `createDashboardItem` return the existing
  case without applying the body.

## Live test findings (NAE 7.0.3, starter, 2026-10-28)

- The engine imports `dashboard_item` and `dashboard_management` only when
  `netgrif.engine.dashboard.enabled=true`. The starter `docker-compose.yaml`
  does not set it, so without it `createDashboardItem` fails with
  `Could not find the process for the Case from provided inputs on case creation`.
- First deploy of the template works: item created, `main_dashboard` created
  and updated (items, toolbar flags set).
- **`createDashboardItem` alone is idempotent.** Deployed 3 times on a clean
  database: still one item, existing item returned unchanged. Use it
  as in the template.
- **`updateDashboardItem` on an existing item does not work in the released
  7.0.3.** Two defects, both found by test:
  1. `DashboardItemBody.toDataSet()` always writes `item_id`, which fires the
     `item_id` set event, and `setId(null)` writes an empty id. Unlike
     `DashboardManagementBody`, it has no `id != null` guard.
  2. The `item_id` set event and the `configuration_finish` pre-action in
     `dashboard_item.xml` throw `Dashboard item with given ID already exists`
     when an active item with that id is found in Elasticsearch, and it finds
     the item itself (the search runs before the item is reindexed as
     inactive after assign).
  A failed update leaves the item with its `configuration` task assigned and
  `is_active=false`, so later updates fail with `Not all arcs can be executed`.
  With the stock engine do not use `updateDashboardItem` in an import.
- **`itemIcon` and `name` from the body are ignored by the stock 7.0.3
  engine (tested, create and update).** `DashboardItemServiceImpl` writes the
  whole body in one `setData`, and the set events of `dashboard_item.xml`
  run afterwards and overwrite the values: for an internal tile
  `menu_items_list_set` forces `inherit_icon=true` and `inherit_icon_set`
  copies the menu item's icon (the tile got `emoji_people`, never the body's
  `star` or `home`); for an external tile (`setInternal(false)`)
  `is_internal_set` / `external_icon_set` clear `item_icon`; `inherit_name`
  does the same to `item_name`. With the stock engine a tile shows the icon and
  name of its menu item: set them on the `MenuItemBody`.
- Set `setActive(false)` also on create: `configuration_finish` sets it to true
  itself. With `setActive(true)` the finish check can find the new item itself
  (seen once as `already exists` on the first create).
- A case deleted with `delete_case` can stay in Elasticsearch as a ghost
  document. While a ghost with the same `item_id` exists, `createDashboardItem`
  does not find the item and creates a duplicate on every deploy (seen: 1 to 4
  items). Delete the ghost in Elasticsearch, or reset the database.
- `delete_case` of the engine MCP needs the full case id including the
  process prefix (`<shortProcessId>-<objectId>`).

## Deprecated, do not use

- NAE 6 package `com.netgrif.application.engine.menu.domain.dashboard`
  (`DashboardItemBody`, `DashboardManagementBody`).
- Setting `menuItemsToDashboardItems` by hand.
- Case ids copied from a local database; look the cases up by identifier.
