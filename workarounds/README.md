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
| W1 | Nobody can sign in at http://localhost:4200, not even `admin`: the frontend 7.1.0 sends `GET /api/auth/login`, the admin 1.1.0 accepts only `POST` and answers 405, shown as "Wrong credentials!" | Before nginx starts, the compiled config in `main*.js` is switched from `"authentication":"Basic"` to `"BasicWithRealm"` (a strategy already in the bundle that POSTs `{username, password}`) | `frontend-login.sh`, service `frontend` in `docker-compose.yaml` | Frontend image that signs in with POST, or admin that accepts the GET Basic login |
| W1b | The frontend ignores `DEFAULT_REALM` (the variable is in no file of the image) and has no realm field, so it signs in to the default realm | Covered by W2: `app-users` is the default realm | `realm-init.sh` | Frontend that reads `DEFAULT_REALM` |
| W2 | The cluster has only the realm `Admin`. A new realm has no sign-in method (nobody can log in), and the worker looks users up without a realm, so `change <actorList> value { [userId] }` fails for any user outside the default realm (`Group [...] does not exist`) | One-shot job `realm-init` creates `app-users`, adds Basic sign-in and makes it the default realm (Admin first loses the flag: the admin accepts a new default only when none is set). `admin` still signs in, because the admin UI and the MCP plugin name the realm `Admin` | `realm-init.sh`, service `realm-init` | Admin setup that creates the application realm; engine that looks users up in their own realm |
| W3 | `engine-mcp` (plugin 1.0.0) has none of the realm tools and no `list_process_roles` / `list_global_roles` that `AGENTS.md` describes; `create_user` makes a user without password in the realm `Admin` (every user there is an administrator); impersonated calls do not enforce role permissions | `nae.sh`: admin REST as `admin` (users, roles, realms) and gateway REST as a real test user of `app-users` | `nae.sh`, `.agents/skills/test-process/references/role-scenarios.md` | MCP plugin with realm and role tools and a `realm`/`password` on `create_user` |
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

## Checking the bypasses

```bash
docker compose logs realm-init frontend | grep 'BYPASS'
workarounds/nae.sh realms
```

`realm-init` must end with `realm app-users ready`, the frontend log must show
`switched ... to BasicWithRealm` (or `already uses`). A browser that loaded the
frontend before W1 keeps the old cached `main*.js`: reload it with Ctrl+F5.
