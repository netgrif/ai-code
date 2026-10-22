# Menu API reference (NAE 7.0.3)

Extract of the menu part of `ActionDelegate` and the body classes it uses.
Source: `../application-engine` at tag `v7.0.3`. Line numbers point into
`application-engine/src/main/groovy/com/netgrif/application/engine/petrinet/domain/dataset/logic/action/ActionDelegate.groovy`.
Body classes live in `nae-object-library`, package
`com.netgrif.application.engine.objects.workflow.domain.menu`. When the NAE
image version in `nae/docker-compose.yaml` changes, re-check this file
against the source.

## Contents

- Process template
- Menu item methods
- View helpers
- Roles
- MenuItemBody
- View bodies
- Deprecated, do not use

## Process template

Validated with `validate_process` (Petriflow 1.0.9). `action1` follows
`processes/menu_import.xml` (items that open frontend custom views),
`action2` shows a folder with a case list of one process for given roles.
Replace `hello_world`, the role ids and the headers with real ones.

```xml
<document xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="https://petriflow.com/petriflow.schema.xsd">
    <id>hello_world/menu_import</id>
    <version>1.0.0</version>
    <initials>HMI</initials>
    <title>Hello World menu import</title>
    <icon>device_hub</icon>
    <defaultRole>false</defaultRole>
    <anonymousRole>false</anonymousRole>
    <transitionRole>false</transitionRole>
    <processEvents>
        <event type="upload">
            <id>menu_import_upload</id>
            <actions phase="post">
                <action id="action1">
                    <![CDATA[
                    // Default views: menu items that open a frontend custom view
                    def allCases = new com.netgrif.application.engine.objects.workflow.domain.menu.MenuItemBody("/", "all_cases", i18n("All cases", ["sk": "Všetky prípady", "en": "All cases"]), "assignment")
                    allCases.setAutoSelect(true)
                    allCases.setUseCustomView(true)
                    allCases.setCustomViewSelector("all-cases")
                    createOrUpdateMenuItem(allCases)

                    def myTasks = new com.netgrif.application.engine.objects.workflow.domain.menu.MenuItemBody("/", "my_tasks", i18n("My tasks", ["sk": "Moje úlohy", "en": "My tasks"]), "library_add_check")
                    myTasks.setUseCustomView(true)
                    myTasks.setCustomViewSelector("my-tasks")
                    createOrUpdateMenuItem(myTasks)
                    ]]>
                </action>
                <action id="action2">
                    <![CDATA[
                    // Folder /hello with the cases of one process, for the given roles
                    def roles = collectRolesForPreferenceItem(["agent": "hello_world/hello_world", "admin": GLOBAL_ROLE])

                    def folder = new com.netgrif.application.engine.objects.workflow.domain.menu.MenuItemBody("/", "hello", i18n("Hello", ["sk": "Hello", "en": "Hello"]), "folder")
                    folder.setOrder(10d)
                    folder.setAllowedRoles(roles)
                    createOrUpdateMenuItem(folder)

                    def item = new com.netgrif.application.engine.objects.workflow.domain.menu.MenuItemBody("/hello", "hello_world_cases", i18n("Hello cases", ["sk": "Hello prípady", "en": "Hello cases"]), "emoji_people")
                    item.setOrder(10d)
                    item.setAllowedRoles(roles)
                    def view = createDefaultViewBody(item, "processIdentifier:\"hello_world/hello_world\"", ["hello_world/hello_world"], ["meta-title", "meta-creationDate", "hello_world/hello_world-decision"])
                    view.setShowCreateCaseButton(true)
                    view.setCreateCaseButtonTitle(i18n("New case", ["sk": "Nový prípad", "en": "New case"]))
                    view.setRequireTitleInCreation(false)
                    item.setView(view)
                    createOrUpdateMenuItem(item)
                    ]]>
                </action>
            </actions>
        </event>
    </processEvents>
    <transition>
        <id>noop</id>
        <x>100</x>
        <y>100</y>
        <label>Menu import</label>
    </transition>
</document>
```

Notes:
- The schema requires at least one `<transition>`; `noop` has no roles, and
  `defaultRole`/`anonymousRole` are `false`, so no one can create a case of
  the menu import.
- Folders before their children; the parent path must match the folder's
  path plus identifier (`/` + `hello` = `/hello`).
- `processes/menu_import.xml` uses `createMenuItem(body)`; the template uses
  `createOrUpdateMenuItem(body)` so a re-deploy updates instead of failing.

## Menu item methods

Identifiers are sanitized (`MenuItemUtils.sanitize`) and unique across the
whole deployment.

| Line | Signature | Behavior |
|------|-----------|----------|
| 2876 | `Case createOrUpdateMenuItem(MenuItemBody body)` | Upsert by identifier. Update rewrites name, icons, roles, view and flags. To change the path of an existing item use `moveMenuItem`. **Default choice.** |
| 2346 | `Case getOrCreateMenuItem(MenuItemBody body)` | Returns the existing item unchanged, or creates it. |
| 2921 | `Case createOrIgnoreMenuItem(MenuItemBody body)` | Same effect as `getOrCreateMenuItem`. |
| 2342 | `Case createMenuItem(MenuItemBody body)` | Creates; throws `IllegalArgumentException` if the identifier exists. Avoid in menu imports. |
| 2960 | `Case updateMenuItem(Case item, MenuItemBody body)` | Updates a found item. |
| 2530 | `Case findMenuItem(String identifier)` | Item by identifier, or null. |
| 2550 | `boolean existsMenuItem(String identifier)` | Existence check. |
| 2539 | `Case findFolderCase(String path)` | Folder item for a path. |
| 2490 | `void moveMenuItem(Case item, String destUri)` | Moves the item, creates missing folders. Cyclic moves throw. |
| 2051 | `changeMenuItem item <attr> { value }` | DSL; attributes `allowedRoles`, `bannedRoles`, `uri`, `title`, `menuIcon`, `tabIcon`, `order`, `useCustomView`, `customViewSelector`. |
| 2113, 2130 | `changeMenuItemOrder(Case item or String identifier, order)` | Sets `order`; null clears it. |
| 2188 | `deleteMenuItem(Case item)` | Deletes the item (asynchronously). |
| 2701 | `I18nString i18n(String value, Map<String,String> translations)` | Builds a translated name. |

Creating an item whose path has no folder yet creates the folder
automatically (named after the last path segment, icon `folder`). Create
folders explicitly to give them a name, translations, icon, roles and order.

## View helpers

Both are `protected static` in `ActionDelegate` and callable from actions.
They return a `TabbedCaseViewBody` (typed as `ViewBody`); configure it, then
`body.setView(view)`.

| Line | Signature | Result |
|------|-----------|--------|
| 2390 | `createDefaultViewBody(MenuItemBody body, String filterQuery, List<String> filterAllowedNets = [], List<String> defaultHeaders = null, String filterType = "Case", String filterVisibility = "private", def filterMetadata = null)` | Case list filtered by `filterQuery`, chained to a task list of the opened case. |
| 2355 | `createSingleTaskViewBody(MenuItemBody body, String filterQuery, String transitionId, List<String> filterAllowedNets = [], List<String> defaultHeaders = null, String filterType = "Case", String filterVisibility = "private", def filterMetadata = null)` | Case list chained to a single task (`transitionId`) of the opened case. |

Both set `showCreateCaseButton = false`, `showMoreMenu = true`,
`allowHeaderTableMode = true`. `defaultHeaders = null` means no default
headers; otherwise each header is `<process_id>-<field_id>` or a meta header
(`meta-title`, `meta-creationDate`, `meta-author`, `meta-visualId`,
`meta-lastModified`). `filterQuery` is an Elasticsearch query string, e.g.
`processIdentifier:"app/process" AND dataSet.<field>.booleanValue:true`.
`filterAllowedNets` lists the process ids that can be created from the view.

## Roles

`Map<String, I18nString> collectRolesForPreferenceItem(Map<String, String> roles)` (line 2672)

- Map `roleId → processId`, e.g. `["approver": "leave/leave_request"]`.
- Global role: `["admin": GLOBAL_ROLE]` (`ActionDelegate.GLOBAL_ROLE`, line
  122). Give the bare id; the method adds the `global_` prefix itself.
- Unknown global role: silently skipped.
- Unknown process: `IllegalArgumentException`.
- Known process without that role: `NullPointerException`.
- Result goes to `body.setAllowedRoles(...)` or `body.setBannedRoles(...)`.
  A banned role wins over an allowed one; no allowed roles means no
  restriction.

## MenuItemBody

`com.netgrif.application.engine.objects.workflow.domain.menu.MenuItemBody`
(Lombok `@Data`, setters for every field).

Constructors:
- `(String path, String identifier, I18nString name, String icon)`: name and
  icon are used for both the menu entry and the tab. Preferred.
- `(String path, String identifier, String name, String icon)`
- `(String path, String identifier, I18nString menuName, I18nString tabName, String menuIcon, String tabIcon)`

| Field | Default | Setter | Meaning |
|-------|---------|--------|---------|
| `path` | | `setPath` | Parent folder path, `/` for top level. |
| `identifier` | | `setIdentifier` | Unique id, snake_case. |
| `menuName`, `tabName` | | `setMenuName`, `setTabName` | `I18nString` or `String`. |
| `menuIcon`, `tabIcon` | `filter_none` | `setMenuIcon`, `setTabIcon` | Material icon names. |
| `useTabIcon` | `true` | `setUseTabIcon` | Show the icon on the tab. |
| `order` | null | `setOrder(Double)` | Sort order among siblings; must be finite. Pass `10d`. |
| `allowedRoles`, `bannedRoles` | empty | `setAllowedRoles`, `setBannedRoles` | From `collectRolesForPreferenceItem`. |
| `useCustomView` | `false` | `setUseCustomView` | Open a frontend custom view instead of `view`. |
| `customViewSelector` | | `setCustomViewSelector` | Selector of that frontend view. |
| `isAutoSelect` | `false` | `setAutoSelect` | Open this item after login. |
| `view` | null | `setView(ViewBody)` | Also sets `useTabbedView` from the view type. |

## View bodies

Package `...objects.workflow.domain.menu.configurations`.

`TabbedCaseViewBody`:

| Field | Default |
|-------|---------|
| `showCreateCaseButton` | `true` (helpers set `false`) |
| `createCaseButtonTitle` | `""` (`I18nString`) |
| `createCaseButtonIcon` | `add` |
| `requireTitleInCreation` | `true` |
| `bannedNetsInCreation` | null (comma-separated process ids) |
| `showMoreMenu` | `false` (helpers set `true`) |
| `viewSearchType` | `fulltext_advanced` (also `fulltext`, `hidden`) |
| `defaultHeaders`, `useDefaultHeaders` | null, `true` |
| `headersMode`, `headersDefaultMode`, `isHeaderModeChangeable`, `allowHeaderTableMode` | `[sort, edit, search]`, `sort`, `true`, `true` |
| `chainedView` | view opened from a case |

`TabbedTaskViewBody`: `mergeFilters`, `viewSearchType`, `defaultHeaders`,
`useDefaultHeaders`, `showMoreMenu`, header mode fields.
`TabbedSingleTaskViewBody`: `transitionId`.

Allowed chaining (`MenuItemView`): case view → task view or single task view;
ticket view → single task view; task view and single task view chain nothing.
A single task view cannot be the primary view.

## Deprecated, do not use

Still present in 7.0.3 but deprecated; group arguments are ignored:
`createOrUpdateMenuItemAndFilter` (both overloads),
`createOrIgnoreMenuItemAndFilter`, `createOrUpdateMenuItem(uri, identifier, name, icon, filter, ...)`,
`createOrUpdateMenuItem(id, uri, type, query, ...)`,
`createOrUpdateCaseMenuItem`, `createOrUpdateTaskMenuItem`,
`createMenuItem(uri, identifier, filter, ...)` overloads,
`createMenuItem(id, uri, query, ...)`, `createTaskMenuItem`,
group-based `createFilterInMenu`, `findMenuItem(uri, name, groupName)`,
`findMenuItemInGroup`.

Removed in 7.x (NAE 6 code that will not run): `getUri`, `createUri`,
`moveUri`, `findMenuItemByUriAndIdentifier`, `getFilterFromMenuItem`, the
package `com.netgrif.application.engine.workflow.domain.menu`, the process
`preference_item`.
