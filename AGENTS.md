# AGENTS.md

This repository is a **template for applications on the Netgrif Platform (NAE)**.
It is not a code project: the application logic lives in **Petriflow processes**
that run on the Netgrif Application Engine, and the user interface is the
standard Netgrif frontend, which runs as a container. This repository has no
frontend sources.
Reply in the language the user writes in.

## Repository layout

| Path                    | Purpose                                                                                                                      |
|-------------------------|------------------------------------------------------------------------------------------------------------------------------|
| `docker-compose.yaml`   | Local platform cluster: `nae-admin` (:8888), `nae-gateway` (:8080, :8800), root worker `engine` (:8082), `frontend` (:4200), `builder` (:4300), `petriflow-mcp` (:3000), `nae-mcp-plugin` (:8700), MongoDB, Elasticsearch, Redis |
| `nae/engine/modules/`   | Built modules, unzipped here, loaded by NAE at start. Output only, never sources                                             |
| `nae/engine/logs/`      | NAE logs (mounted from the container), including `nae.log`                                                                   |
| `nae/engine/storage/`   | NAE storage (mounted from the container)                                                                                     |
| `processes/<app_name>/` | One folder per application: Petriflow process XMLs and a `README.md`. Shared live with the builder (read-write)              |
| `modules/<artifactId>/` | Java/Spring module sources, one Maven project per module                                                                     |
| `.agents/skills/`       | Task playbooks for agents (see below)                                                                                        |
| `.mcp.json`             | MCP servers: `petriflow-mcp` (:3000) and `engine-mcp` (cluster plugin, :8700; needs the running cluster)                    |
| `.env.example`          | Optional settings (`PUID`, `PGID` for the builder); a real `.env` is git-ignored                                             |

## How to implement a requirement

Choose the first option that works. Move down only when the one above cannot do it:

1. **Petriflow process** (data, transitions, roles, actions, forms). Default for all
   app logic. The application menu is also a process (`generate-menu-import`).
2. **Module**, only if the logic cannot be a process or action (a whole service,
   e.g. OCR). Use the `write-module` skill.

Explain to the user why you moved down a level before doing it.

Do not create or change frontend code. If a requirement needs a user interface
that forms in processes and the menu cannot provide, tell the user instead of
working around it.

## Skills

Load the matching skill before the task:

- `generate-process`: create or change a Petriflow process.
- `generate-action`: write Groovy action code inside a process.
- `generate-menu-import`: menu import process (menu items, folders, views).
- `test-process`: validate a process and run it on the local NAE.
- `write-module`: custom NAE module (Java/Spring).

Do not run IDE "reformat code" on files in `.agents/skills/`: it breaks the code blocks
inside the Markdown. Keep `name` equal to the folder name, and no `<` or `>` in
the frontmatter.

## MCP servers

- `petriflow-mcp` is the `petriflow-mcp` container of the compose stack, on
  `localhost:3000` (image 1.1.1). Use it to validate (`validate_process` with
  `appId`, `validate_action`), to look up Petriflow versions, components and the
  Action API, and to generate an application manifest (`generate_app_manifest`).
  Never write Petriflow or Action API syntax from memory.
- `engine-mcp` is the cluster MCP plugin `nae-mcp-plugin`, on
  `localhost:8700`. It needs the running cluster (admin, root worker and plugin).
  If it is not reachable, say so and stop. Do not fake results.
  The plugin's `/mcp` is unauthenticated and acts as the admin account; keep it
  on localhost and never expose it.

## Project setup

Prerequisites: Docker with Compose, and (only when developing modules) Java 21 and
Maven. The platform images are in `docker.nexus.netgrif.com`, so log in first:
`docker login docker.nexus.netgrif.com`. **Warn the developer** that developing a
module requires Java 21 and Maven installed; if they are missing, say so and stop
before module work.

1. Start the cluster from the repository root: `docker compose up -d`
   (Docker Compose v2). It starts the platform admin, gateway, root worker,
   frontend, builder, Petriflow MCP, the MCP plugin and the databases. A short
   `init-perms` job fixes the owner of `nae/engine/logs` and `storage` first.
   The gateway waits for a healthy admin and root worker; the frontend waits for
   the gateway; the plugin waits for the admin and root worker.
2. Wait until the cluster is healthy (no authentication needed). If not, read
   `nae/engine/logs/nae.log` and the container logs.
   - `curl http://localhost:8888/manage/health` — admin.
   - `curl http://localhost:8080/manage/health` — gateway (the browser entry point).
   - `curl http://localhost:8700/manage/health` — MCP plugin.
   - `curl http://localhost:8082/manage/health` — root worker (debug only).
3. Open the frontend at http://localhost:4200 and log in as `admin`. Its
   password is set in `docker-compose.yaml`
   (`netgrif.admin.setup.admin.password`, a local dev default). The frontend is a
   single-page app: the browser calls the gateway on `localhost:8080`. The
   builder, a visual editor of the files in `processes/`, is at
   http://localhost:4300. The platform admin UI is at http://localhost:8888.
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
executing a task, creating or deleting users, assigning roles,
copying/removing a module, restarting or recreating containers. Read-only
calls (validate, list) don't. Never delete
Docker volumes or data.

**Credentials.** The `admin` password is a secret. Read it from
`docker-compose.yaml` (`netgrif.admin.setup.admin.password`) only when needed,
and never write it into other files, commits or reports. The one exception is
the hand-off message to the user (see "Hand-off to the user"), where you give it
as the login. The same value is used by the MCP plugin.

**Test users.** Role tests use disposable users that you create (with the
`mcptest_` prefix) and their impersonation tokens. Never test with the `admin`
user or existing users. Treat tokens like the password: never write them into
files, commits, reports or chat output. After every test scenario delete the
test cases you created; deployed processes and the menu stay.

**Known gap: deleting test users.** The plugin runtime cannot delete users: the
admin REST API has no user-delete route, so `delete_user` returns an error. Test
users therefore stay behind; list them in the report and do not claim cleanup
that did not happen. Future fix: add a user-delete endpoint to the admin image,
then implement `delete_user` in the plugin. This is tracked in `TODOs.md`.

**Processes.**

- An application is a folder `processes/<app_name>/` with process XMLs and a
  short `README.md` that includes a process map (Mermaid diagram). Applications
  only separate business logic; all deployed processes can reference each other.
- `app_name` and process names are snake_case. The process `id` is
  `<app_name>/<process_name>` (e.g. `hello_world/hello_world`), unique across
  the whole NAE deployment. The file is `processes/<app_name>/<process_name>.xml`.
- Use the latest Petriflow version from the Petriflow MCP unless pinned.
- Pass `appId` (`<app_name>`) to `validate_process`; Petriflow 1.1.1 enforces
  that the root process id is `<appId>/<processId>`.
- The user can edit the same files in the builder. Before you edit or deploy a
  process file, compare `git hash-object <file>` (first 8 characters) with the
  value you noted when you last read or wrote it in this session, or with the
  `Hash` column of the application `README.md` if you did not read it this
  session. Re-read only files that differ, keep the user's changes and never
  revert them. After your last write of a task, put the new hashes in the README.
- Every process change must pass `validate_process`. Do not hand-wave around errors.
- Actions are validated with `validate_action` (Petriflow MCP 1.1.1) before the
  process is validated. Actions are short, use Action API methods, one concern each. Never use Grape,
  meta-classes or other reflection. Longer or reusable code becomes a Petriflow
  function. Whole services become modules.

**NAE data folders.** `nae/engine/logs` and `nae/engine/storage` belong to the
engine container (owned by its user). Read logs from there, never write there.

**Modules.**

- Sources in `modules/<artifactId>/`, built with `nae-module-maven-plugin`
  against NAE `7.1.0`, ZIP unzipped into `nae/engine/modules/<artifactId>/`,
  then restart the root worker (`docker compose restart engine` in the
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
2. **Sign in:** user `admin`, password = the value of
   `netgrif.admin.setup.admin.password` in `docker-compose.yaml`, which
   you read and write out. `admin` has every role, so you can do every step, but
   you will not see role restrictions this way. This is the only message where you
   may write the password.
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
| Cluster config   | `docker compose config`; admin (:8888), gateway (:8080) and plugin (:8700) health return `UP`; `list_nodes` returns `NETGRIF Admin`, `NETGRIF Root Worker` and `Netgrif Gateway`, all RUNNING |
| Process / action | `validate_process` (with `appId`) and `validate_action`, then a live scenario with the `test-process` skill       |
| Module           | `mvn -f modules/<artifactId>/pom.xml clean package`, deploy with approval, check NAE logs, call it from an action |

Report what was run and the results. If a check cannot run (NAE or MCP down),
say that instead of claiming success.
