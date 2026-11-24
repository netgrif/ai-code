# Workarounds (BYPASS) for platform 1.1.0

The template runs the released images unchanged where it can. The gaps below
were found in an agent test run on the local cluster 1.1.0 (NAE 7.1.0, frontend
7.1.0, `netgrif-nae-mcp-plugin` 1.0.0) on 2026-11-24. Each one is bypassed here
so that a fresh `docker compose up -d` and the agent skills work for any
developer. Every bypass is marked `BYPASS Wn` in the file that applies it, so a
search for `BYPASS` finds all of them. Remove a bypass when the image named under
"Proper fix" ships the fix.

| Id | Problem | Bypass | Where | Proper fix |
|----|---------|--------|-------|------------|
| W1 | Nobody can sign in at http://localhost:4200, not even `admin`: the frontend 7.1.0 sends `GET /api/auth/login`, the admin 1.1.0 accepts only `POST` and answers 405, shown as "Wrong credentials!". The stored session is also verified with that GET, so after a restart a stale token is never cleared and the login page hangs | Before nginx starts, the compiled config in `main*.js` is switched from `"authentication":"Basic"` to `"BasicWithRealm"` (a strategy already in the bundle that POSTs `{username, password}`) and gets `"verification":"/users/me"` (200 or 401). The patched file gets a checksum name, so no browser keeps the old one from its cache | `frontend-login.sh`, service `frontend` in `docker-compose.yaml` | Frontend image that signs in with POST, or admin that accepts the GET Basic login |
| W1b | The frontend ignores `DEFAULT_REALM` (the variable is in no file of the image) and has no realm field, so it signs in to the default realm | Covered by W2: `app-users` is the default realm | `realm-init.sh` | Frontend that reads `DEFAULT_REALM` |
| W2 | The cluster has only the realm `Admin`. A new realm has no sign-in method (nobody can log in), and the worker looks users up without a realm, so `change <actorList> value { [userId] }` fails for any user outside the default realm (`Group [...] does not exist`) | One-shot job `realm-init` creates `app-users`, adds Basic sign-in and makes it the default realm (Admin first loses the flag: the admin accepts a new default only when none is set). `admin` still signs in, because the admin UI and the MCP plugin name the realm `Admin` | `realm-init.sh`, service `realm-init` | Admin setup that creates the application realm; engine that looks users up in their own realm |
| W3 | `engine-mcp` (plugin 1.0.0) has none of the realm tools and no `list_process_roles` / `list_global_roles` that `AGENTS.md` describes; `create_user` makes a user without password in the realm `Admin` (every user there is an administrator); impersonated calls do not enforce role permissions | `nae.sh`: admin REST as `admin` (users, roles, realms) and gateway REST as a real test user of `app-users` | `nae.sh`, `.agents/skills/test-process/references/role-scenarios.md` | MCP plugin with realm and role tools and a `realm`/`password` on `create_user` |
| W5 | The MCP plugin signs in to the admin REST API with Basic auth and no realm, so the admin uses the default realm. With W2 that is `app-users`, where `admin` does not exist: `deploy_process` fails with "NAE admin login failed with HTTP 401" | Service `admin-realm-proxy` (nginx) between the plugin and the admin adds `X-Realm-Id: Admin` to requests without a realm header; the plugin's `NETGRIF_ENGINE_MCP_PLUGIN_ADMIN_BASE_URL` points to it | `admin-realm-proxy.conf`, services `admin-realm-proxy` and `nae-mcp-plugin` | Plugin that sends the realm of its admin account (it already has `default-realm-id`) |
| W4 | An upload event runs in one MongoDB transaction; with the default 60 s limit a menu import of about 10 items is rolled back in MongoDB, its cases stay in Elasticsearch (ghost menu items) and the admin still registers the process | MongoDB starts with `transactionLifetimeLimitSeconds=300`; the menu skill keeps at most four items per import | `docker-compose.yaml` (service `nae-mongodb`), `.agents/skills/generate-menu-import/SKILL.md` | Faster menu item creation; Elasticsearch indexing after commit; admin that rolls back a failed import |

## Not bypassed (to report upstream)

- The engine REST API returns task data (`GET /api/task/{id}/data`) and cases
  (`GET /api/workflow/case/{id}`) to any signed-in user who knows the id,
  without checking roles. Hidden fields are hidden only in the forms.
- `delete_process` (MCP) and `DELETE /api/petrinet/{id}` (admin) report success
  but leave the admin registration of a process whose import failed on the
  worker. Redeploy a fixed version with `replaceExisting` instead.
- The MCP plugin's HTTP client gives up after 30 s ("Read timed out") while the
  deploy keeps running; check `list_processes` and the engine log.
- `validate_action` does not know engine classes such as `ActorListFieldValue`.
- Opening any menu item takes 1.5 to 2 s: the frontend first reads the item's
  configuration task (`GET /api/task/<menu item task>/data`, 102 fields), and
  the worker resolves it with about 300 role lookups and 160 process lookups to
  the admin over gRPC, without a cache (measured on the worker directly: 1.7 to
  2.1 s; the case search behind the item takes 30 ms). Needs caching in the
  worker.
- The single-task view of a menu item draws an empty button for a Finish whose
  title is empty (task lists hide it); see the `generate-process` skill,
  "Read-only tasks".
- The theme in the frontend's compiled config (`theme.pallets`) is not applied;
  the look comes from the compiled CSS (primary `#0f4c81`, accent `#ffab40`).
  Restyling needs a custom frontend.

## Checking the bypasses

```bash
docker compose logs realm-init frontend | grep 'BYPASS'
workarounds/nae.sh realms
```

`realm-init` must end with `realm app-users ready`, the frontend log must show
`switched ... to BasicWithRealm` (or `already patched`), and
`docker compose ps admin-realm-proxy` must be healthy. A browser that still
hangs on the login page has a token from before W1: clear the site data of
localhost:4200 once.
