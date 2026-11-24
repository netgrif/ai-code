# AGENTS.md

This repository is a **template for applications on the Netgrif Platform (NAE)**.
It is not a code project: the application logic lives in **Petriflow processes**
that run on the Netgrif Application Engine, and the user interface is the
standard Netgrif frontend, which runs as a container. Custom frontend
components are the exception (see "How to implement a requirement").
Reply in the language the user writes in.

## Repository layout

| Path                    | Purpose                                                                                                                      |
|-------------------------|------------------------------------------------------------------------------------------------------------------------------|
| `docker-compose.yaml`   | Local platform cluster: `nae-admin` (:8888), `nae-gateway` (:8080, :8800), root worker `nae-engine` (:8082), search node `nae-search` (:8600), `frontend` (:4200), `builder` (:4300), `petriflow-mcp` (:3000), `nae-mcp-plugin` (:8700), MongoDB, Elasticsearch, Redis; your plugins via `include:` |
| `nae/engine/modules/`   | Built modules, unzipped here, loaded by NAE at start. Output only, never sources                                             |
| `nae/engine/logs/`      | NAE logs (mounted from the container), including `nae.log`                                                                   |
| `nae/engine/storage/`   | NAE storage (mounted from the container)                                                                                     |
| `processes/<app_name>/` | One folder per application: Petriflow process XMLs and a `README.md`. Shared live with the builder (read-write)              |
| `plugins/<artifactId>/` | Plugin sources, one Maven project per plugin, with its `Dockerfile` and `compose.yaml`                                       |
| `modules/<artifactId>/` | Java/Spring module sources, one Maven project per module                                                                     |
| `.agents/skills/`       | Task playbooks for agents (see below)                                                                                        |
| `workarounds/`          | Marked bypasses (`BYPASS W1`–`W4`) for gaps of platform 1.1.0 and `nae.sh`, the REST helper for realms, users, roles and role tests; see its `README.md` |
| `.mcp.json`             | MCP servers: `petriflow-mcp` (:3000) and `engine-mcp` (cluster plugin, :8700; needs the running cluster)                    |
| `.env.example`          | Optional settings (`PUID`, `PGID` for the builder, `DEFAULT_REALM` (not read by frontend 7.1.0), memory limits of the Java services); a real `.env` is git-ignored |

## How to implement a requirement

Choose the first option that works. Move down only when the one above cannot do it:

1. **Petriflow process** (data, transitions, roles, actions, forms). Default for all
   app logic. The application menu is also a process (`generate-menu-import`).
2. **Plugin**, when the logic needs Java code, a Java library or a whole service
   that an action cannot provide (e.g. PDF generation, OCR, an external system
   integration). Actions call it as
   `Plugin.<registrationName>.<entryPoint>.<method>(args)`. Use the
   `write-plugin` skill. This is the default way to extend the platform.
   It needs Java 21, Maven 3+ **and an account for the Netgrif Nexus**
   (`plugin-client` and `nae-plugin-maven-plugin` are only in
   `https://nexus.netgrif.com/repository/maven-public`, which answers 401
   without credentials in `~/.m2/settings.xml`). If any of them is missing, say
   so and offer the fallback: a separate service in its own container, built
   in Docker and called from an action over HTTP. Tell the user it is a
   fallback, not a plugin (no registration in the cluster).
3. **Module**, only when a plugin cannot do it: the code must call another
   plugin or a module, use engine internals that `PluginActionApi` does not
   expose, or run inside the worker's own call. Use the `write-module` skill.

Explain to the user why you moved down a level before doing it.

Custom frontend components are allowed when a requirement needs a user
interface that forms in processes, the menu and the dashboard cannot provide
(for example a document viewer next to the extracted data). Build them as an
Angular project in `frontend/` on the public npm package `@netgrif/components`,
served by its own container listed under `include:`, and leave the stock
`frontend` service unchanged. Tell the user first why the stock frontend is not
enough, and ask for approval before adding or changing the frontend container.
Keep the look of the stock frontend (theme, fonts, wording).

## Skills

Load the matching skill before the task:

- `generate-process`: create or change a Petriflow process.
- `generate-action`: write Groovy action code inside a process.
- `generate-menu-import`: menu import process (menu items, folders, views).
- `generate-dashboard-items`: dashboard import process (dashboard items and the dashboard that lists them).
- `test-process`: validate a process and run it on the local NAE.
- `write-plugin`: custom platform plugin (Java/Spring service called from actions).
- `write-module`: custom NAE module (Java/Spring), only when a plugin cannot do it.

For any design or change of Petriflow processes, load `generate-process` first,
before brainstorming or any planning skill. Its architecture steps decide which
processes exist; a design document or plan is written from that architecture,
not the other way round.

Do not run IDE "reformat code" on files in `.agents/skills/`: it breaks the code blocks
inside the Markdown. Keep `name` equal to the folder name, and no `<` or `>` in
the frontmatter.

## MCP servers

**Check first.** Before any process work, check that the tools of both
servers are available to you as MCP tools (not over `curl`). `.mcp.json` is
loaded only when the assistant is started in the repository root (the folder
with this file) and the user approved the project MCP servers. If the tools are
missing but the containers run, tell the user to restart the assistant in the
repository root and approve the servers; do not build your own MCP client.

- `petriflow-mcp` is the `petriflow-mcp` container of the compose stack, on
  `localhost:3000` (image 1.1.2). Use it to validate (`validate_process` with
  `appId`, `validate_action`), to look up Petriflow versions, components and the
  Action API, and to generate an application manifest (`generate_app_manifest`).
  Never write Petriflow or Action API syntax from memory. Two separate versions:
  1.1.2 is the MCP server (image); the Petriflow language has its own version
  (e.g. 1.0.9), which you read from the MCP and pass to `validate_process`.
- `engine-mcp` is the cluster MCP plugin `nae-mcp-plugin`, on
  `localhost:8700`. It needs the running cluster (admin, root worker and plugin).
  If it is not reachable, say so and stop. Do not fake results.
  The plugin's `/mcp` is unauthenticated and acts as the admin account; keep it
  on localhost and never expose it.
  Use it for processes (`deploy_process`, `list_processes`, `get_process`),
  cases (`create_case`, `get_case`, `delete_case`), tasks and nodes
  (`list_nodes`). The image in this template is `netgrif-nae-mcp-plugin:1.0.0`:
  it has no realm tools and no `list_process_roles` / `list_global_roles`, its
  `create_user` makes users without a password in the realm `Admin` (where every
  user is an administrator), and impersonated calls do not enforce role
  permissions. **BYPASS W3:** do users, roles, realms and every permission check
  with `workarounds/nae.sh` instead (see `workarounds/README.md` and the
  `test-process` skill). Role ids are the `stringId` values from
  `workarounds/nae.sh roles`; a global role declared in a process XML as
  `<id>x</id>` is listed with `importId` `global_x`. `get_process` shows roles
  only by `importId`, which is not an id you can assign. Its HTTP client gives
  up after 30 s ("Read timed out") while a long deploy keeps running: check
  `list_processes` and the engine log before you deploy again.

## Project setup

Prerequisites: Docker with Compose, and (only when developing plugins or modules)
Java 21 and Maven 3+. The platform images are in `docker.nexus.netgrif.com`, so log in first:
`docker login docker.nexus.netgrif.com`. **Warn the developer** that developing a
plugin or module requires Java 21 and Maven 3+ installed and Netgrif Nexus
credentials for Maven; if they are missing, say so and stop before plugin or
module work.

1. Start the cluster from the repository root: `docker compose up -d`
   (Docker Compose v2). It starts the platform admin, gateway, root worker,
   search node, frontend, builder, Petriflow MCP, the MCP plugin and the
   databases. A short `init-perms` job fixes the owner of `nae/engine/logs` and
   `storage` first. The gateway waits for a healthy admin and root worker; the
   search node waits for the admin and root worker; the frontend waits for the
   gateway and the `realm-init` job; the plugin waits for the admin and root
   worker. The stack carries marked workarounds for gaps of platform 1.1.0
   (`BYPASS W1`–`W4`, listed in `workarounds/README.md`): `realm-init` sets up
   the realm `app-users`, the frontend gets a sign-in fix, MongoDB a longer
   transaction limit. Check them with
   `docker compose logs realm-init frontend | grep BYPASS`.
2. Wait until the cluster is healthy (no authentication needed). If not, read
   `nae/engine/logs/nae.log` and the container logs.
   - `curl http://localhost:8888/manage/health` — admin.
   - `curl http://localhost:8080/manage/health` — gateway (the browser entry point).
   - `curl http://localhost:8600/manage/health` — search node.
   - `curl http://localhost:8700/manage/health` — MCP plugin.
   - `curl http://localhost:8082/manage/health` — root worker (debug only).
3. The cluster has two realms (see "Realms" under Rules): `Admin` for the
   administrators and `app-users` for the users of the application. The
   frontend at http://localhost:4200 is for application users only: it has no
   realm choice on its login screen and signs in to the default realm,
   `app-users` (see "Realms"). The administrator `admin` signs in to the platform admin UI
   at http://localhost:8888 and chooses the realm there. Its password is set in
   `docker-compose.yaml` (`netgrif.admin.setup.admin.password`, a local dev
   default). The frontend is a single-page app: the browser calls the gateway on
   `localhost:8080`. The builder, a visual editor of the files in `processes/`,
   is at http://localhost:4300.
4. Deploy the processes from `processes/`: with the `engine-mcp` MCP
   (`deploy_process`; the default worker is `NETGRIF Root Worker`), or as an
   application package (`upload_application` + `deploy_application`). The
   frontend's Workflow view upload is not the primary path in a cluster; do not
   present it as working without checking it.
   Then create a case to try the process.

## Rules

**Approval.** Anything that changes the local NAE or the machine needs user
approval first: deploying a process, uploading or deploying an application
package (`upload_application`, `deploy_application`), creating a case,
executing a task, creating or deleting users, assigning roles, writing `.env`,
copying/removing a module, adding/removing a plugin in `include:`, building or
starting plugin images, restarting or recreating containers. Read-only
calls (validate, list) don't. Never delete
Docker volumes or data. One exception: the final "Admin roles" step below needs
no approval (role assignment for the `admin` account only).

**Credentials.** The `admin` password is a secret. Read it from
`docker-compose.yaml` (`netgrif.admin.setup.admin.password`) only when needed,
and never write it into other files, commits or reports. The one exception is
the hand-off message to the user (see "Hand-off to the user"), where you give it
as the login. The same value is used by the MCP plugin.

**Test users.** Role tests use disposable users that you create (with the
`mcptest_` prefix) in the realm `app-users` (see "Realms") with
`workarounds/nae.sh create-user` (password `password`, the local dev password,
unless the user names another one), and act as them with
`workarounds/nae.sh as <user> ...` (a real sign-in through the gateway, so role
permissions apply). Do not create test users with the MCP `create_user` (BYPASS
W3). Never test with the `admin` user or existing users. Never write session
tokens into files, commits, reports or chat output (`nae.sh` never prints
them). After every test scenario delete the test cases you created; deployed
processes and the menu stay.

**Realms.** The cluster ends with exactly two realms: `Admin` (administrators;
every user in it is an administrator, so role assignments there have no effect
on a test) and `app-users` (the users of the application, and the default realm).

- The compose job `realm-init` (BYPASS W2) creates `app-users`, gives it Basic
  sign-in and makes it the default realm, on every `docker compose up`. You do
  not create realms. Check with `workarounds/nae.sh realms`: `app-users` must
  have `"defaultRealm":true`. If not, read `docker compose logs realm-init`.
- Why the default realm matters: the worker looks users up without a realm, so
  an `actorList` or `actor` value set from a user id (for example
  `[useCase.author.id]`) works only for users of the default realm; others fail
  with `Group [...] does not exist`. The frontend 7.1.0 has no realm field and
  ignores `DEFAULT_REALM`, so it also signs in to the default realm (with the
  sign-in fix BYPASS W1). `admin` still signs in, because the admin UI and the
  MCP plugin name the realm `Admin`.
- Do not change `NETGRIF_ENGINE_MCP_PLUGIN_ADMIN_DEFAULT_REALM_ID` of the MCP
  plugin: it is the realm of the admin account.
- Never create another realm and delete no realm.

**Admin roles.** The `admin` account does not get the roles of processes
automatically. As the last step of an implementation (after the last deploy and
test, not after every replacement of a process), and only if its roles changed:

1. Collect the `stringId` of the roles of all deployed processes of the
   application and of the global roles they use (`workarounds/nae.sh roles`).
2. Read the roles of `admin`: `workarounds/nae.sh users Admin` gives its id,
   `workarounds/nae.sh user Admin <id>` its `processRoles`.
3. If `admin` already has all these `stringId` values, change nothing. A
   replaced process has new `stringId` values for its local roles, so a
   replacement counts as a change.
4. Otherwise `workarounds/nae.sh assign-roles Admin <id> <ids...>` with the
   union of its existing roles and these roles (it replaces the whole set).

This step needs no approval. Say in the report whether the roles were assigned
or left unchanged.

**Known gap: deleting test users.** The plugin runtime cannot delete users: the
admin REST API has no user-delete route. The tool `delete_user` exists, but it
reports the failure inside a normal result with `isError` false, as
`{"error": "Deleting users is not supported by the NAE admin REST API ..."}`: read
the text of the result, not the flag. Test users therefore stay behind; list them in the report (with their realm
`app-users`) and do not claim cleanup that did not happen. Future fix: add a
user-delete endpoint to the admin image, then implement `delete_user` in the
plugin. This is tracked in `TODOs.md`.

**Known gap: data by id.** The engine REST API returns task data
(`GET /api/task/{id}/data`) and cases (`GET /api/workflow/case/{id}`) to any
signed-in user who knows the id, without checking roles (cluster 1.1.0). A
field hidden from a role is hidden in its forms, not on the API. Say so in the
report when a requirement asks to hide data from a role.

**Processes.**

- An application is a folder `processes/<app_name>/` with process XMLs and a
  short `README.md` that includes a process map (Mermaid diagram). Applications
  only separate business logic; all deployed processes can reference each other.
- `app_name` and process names are snake_case. The process `id` is
  `<app_name>/<process_name>` (e.g. `hello_world/hello_world`), unique across
  the whole NAE deployment. The file is `processes/<app_name>/<process_name>.xml`.
- Use the latest Petriflow version from the Petriflow MCP unless pinned.
- Pass `appId` (`<app_name>`) to `validate_process`; Petriflow MCP enforces
  that the root process id is `<appId>/<processId>`.
- The user can edit the same files in the builder. Before you edit or deploy a
  process file, compare `git hash-object <file>` (first 8 characters) with the
  value you noted when you last read or wrote it in this session, or with the
  `Hash` column of the application `README.md` if you did not read it this
  session. Re-read only files that differ, keep the user's changes and never
  revert them. After your last write of a task, put the new hashes in the README.
- Every process change must pass `validate_process`. Do not hand-wave around errors.
- Actions are validated with `validate_action` (Petriflow MCP 1.1.2 or newer) before the
  process is validated. Actions are short, use Action API methods, one concern each. Never use Grape,
  meta-classes or other reflection. Longer or reusable code becomes a Petriflow
  function. Java libraries and whole services become plugins.

**NAE data folders.** `nae/engine/logs` and `nae/engine/storage` belong to the
engine container (owned by its user). Read logs from there, never write there.

**Plugins.**

- Building a plugin needs access to the Netgrif Nexus (see "How to implement a
  requirement"); check it before writing code.
- Sources in `plugins/<artifactId>/`: Spring Boot 4.1, `plugin-client` 1.1.0,
  `nae-plugin-maven-plugin` 1.0.2, built with
  `mvn -f plugins/<artifactId>/pom.xml clean package`. Each plugin has its own
  `compose.yaml`, listed under `include:` in the root `docker-compose.yaml`;
  run it with `docker compose up -d --build <artifactId>` from the repository root.
- Actions call a plugin as `Plugin.<registrationName>.<entryPoint>.<method>(args)`.
  The web docs and the example plugin's properties are outdated; follow the
  `write-plugin` skill. A plugin cannot call another plugin or a module.
- `engine-mcp` lists plugins with `list_plugins` and `get_plugin` (registered
  plugins and their status); also check `docker compose ps`, the plugin's logs
  and the admin UI (`/cluster/plugins`).

**Modules.**

- Sources in `modules/<artifactId>/`, built with `nae-module-maven-plugin`
  against NAE `7.1.0`, ZIP unzipped into `nae/engine/modules/<artifactId>/`,
  then restart the root worker (`docker compose restart nae-engine` in the
  repository root). Modules load into a worker, so with more workers every
  worker that needs the module must have it.
- Actions call a module as `NaeModule.<group>.<serviceBeanName>.<method>(args)`. `petriflow-mcp` validates the process
  XML, not the module. Otherwise use standard Java and Spring practice.

**Git.**

- Never commit jars, zips, `target/`, logs, `.env`, or
  secrets. `.gitignore` already covers them; never use `git add -f`.
- Do not change image versions in `docker-compose.yaml` without asking. The
  platform images (admin, gateway, root worker) and the frontend are released
  together; keep them on the matching versions. The MCP plugin version is
  independent (`netgrif-nae-mcp-plugin`).

## Hand-off to the user

When you finish building or changing processes (or the menu), end your last
message with a **Try it now** block. Write it in the user's language, in plain
words. The user may not be technical: no ports, logs or commands except the one
named below.

1. **Open the app:** open http://localhost:4200 in your browser.
2. **Sign in:** with a test user of the application (realm `app-users`), for
   example `mcptest_<name>` with the password `password`. List the users you
   created, the roles each has and what that user can do, so the person can sign
   in as the role they want to try. The frontend is for these users only. If no
   test user exists yet, say so and offer to create one. The administrator
   `admin` signs in to the platform admin UI at http://localhost:8888 (choose the
   realm there), with the password from `netgrif.admin.setup.admin.password` in
   `docker-compose.yaml`, which you read and write out. This is the only message
   where you may write the admin password.
3. **Try it:** steps for this application with real names: which menu item to
   open, how to start a new case, which task is first and what to fill in, and
   what should happen. Describe only steps you checked in the process or in your
   live test.
4. **Change it:** tell me what to change, in plain words, or open the builder at
   http://localhost:4300 to see and edit the processes visually. Reload the
   builder after I change a process, and do not edit the same process in both
   places. The platform admin UI is at http://localhost:8888.

If the processes are not deployed, do not write step 3 as if they were. Say they
are not deployed yet and why. Offer: "ask me to deploy them" (the MCP plugin
`deploy_process` or an application package). Do not offer the Workflow upload
unless you checked it. If the app is not running, the one step is: start Docker,
log in to `docker.nexus.netgrif.com`, then run `docker compose up -d` in the
project folder.

## Testing and definition of done

A change is done only when the relevant checks pass and you have seen the output:

| Change           | Check                                                                                                             |
|------------------|-------------------------------------------------------------------------------------------------------------------|
| Cluster config   | `docker compose config`; admin (:8888), gateway (:8080), search node (:8600) and plugin (:8700) health return `UP`; `list_nodes` returns `NETGRIF Admin`, `NETGRIF Root Worker` and `Netgrif Gateway`, all RUNNING; the memory limits and `JAVA_TOOL_OPTIONS` of the Java services show in `docker compose config`, and after the start no container has `State.OOMKilled` true (`docker inspect`); `docker compose logs realm-init frontend` shows the `BYPASS W1`/`W2` lines and `workarounds/nae.sh realms` shows `app-users` as the default realm |
| Process / action | `validate_process` (with `appId`) and `validate_action`, then a live scenario with the `test-process` skill       |
| Plugin           | `mvn -f plugins/<artifactId>/pom.xml clean package` (entry points found), `docker compose config --quiet`, run with approval, container `healthy` and registered, call it from an action |
| Module           | `mvn -f modules/<artifactId>/pom.xml clean package`, deploy with approval, check NAE logs, call it from an action |

Report what was run and the results. If a check cannot run (NAE or MCP down),
say that instead of claiming success.
