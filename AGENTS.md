# AGENTS.md

This repository is a **template for applications on the Netgrif Platform (NAE)**.
It is not a Java or Angular project with business logic in code. The application
logic lives in **Petriflow processes** that run on the Netgrif Application Engine.
Reply in the language the user writes in.

## Repository layout

| Path                       | Purpose                                                                          |
|----------------------------|----------------------------------------------------------------------------------|
| `nae/docker-compose.yaml`  | Local stack: NAE (:8080), MongoDB, Elasticsearch, Redis                          |
| `nae/nae-backend/modules/` | Built modules, unzipped here, loaded by NAE at start. Output only, never sources |
| `nae/nae-backend/logs/`    | NAE logs (mounted from the container), including `nae.log`                       |
| `nae/nae-frontend/`        | Angular 17 frontend (`@netgrif/components`), configured by `nae.json`            |
| `processes/<app_name>/`    | One folder per application: Petriflow process XMLs and a `README.md`             |
| `modules/<artifactId>/`    | Java/Spring module sources, one Maven project per module                         |
| `.agents/skills/`          | Task playbooks for agents (see below)                                            |
| `.mcp.json`                | MCP servers: `petriflow-mcp` (local docker) and `engine-mcp` (needs running NAE) |

## How to implement a requirement

Choose the first option that works. Move down only when the one above cannot do it:

1. **Petriflow process** (data, transitions, roles, actions). Default for all app logic.
2. **Existing component** from `@netgrif/components`, configured via `nae.json` views.
3. **Custom frontend component**, only if the library has no component that the
   process logic needs. Use the `write-component` skill.
4. **Module**, only if the logic cannot be a process or action (a whole service,
   e.g. OCR). Use the `write-module` skill.

Explain to the user why you moved down a level before doing it.

## Skills

Load the matching skill before the task:

- `generate-process`: create or change a Petriflow process.
- `generate-action`: write Groovy action code inside a process.
- `generate-menu-import`: menu import process (menu items, folders, views).
- `test-process`: validate a process and run it on the local NAE.
- `write-component`: custom Angular component for the frontend.
- `write-module`: custom NAE module (Java/Spring).

Do not run IDE "reformat code" on files in `.agents/skills/`: it breaks the code blocks
inside the Markdown. Keep `name` equal to the folder name, and no `<` or `>` in
the frontmatter.

## MCP servers

- `petriflow-mcp` is run locally `localhost:3000`. Use it to validate (`validate_process`) and to look up Petriflow
  versions
  and Action API.
  Never write Petriflow or Action API syntax from memory.
- `engine-mcp` works only while NAE runs on `localhost:8080`.
  If it is not reachable, say so and stop. Do not fake results.

## Project setup

Prerequisites: Docker with Compose, Node.js 22+ (prefer the current LTS), and (only when developing modules) Java 21 and
Maven. **Warn the developer** that developing a module requires Java 21 and Maven installed; if they are missing, say so
and stop before module work.

1. Start the backend: `cd nae && docker compose up -d`.
2. Wait until NAE is healthy: `curl http://localhost:8080/manage/health` returns
   status `UP` (no authentication needed). If it does not, read
   `nae/nae-backend/logs/nae.log`.
3. Install the frontend: `cd nae/nae-frontend && npm install --legacy-peer-deps`.
4. Run the frontend: `npm start` (http://localhost:4200). It talks to
   `http://localhost:8080/api` (see `nae.json`).
5. Log in as `super@netgrif.com` (super admin). Its password is generated on the
   first run and printed in `nae/nae-backend/logs/nae.log`.
6. Deploy the processes from `processes/`: with the `engine-mcp` MCP (`deploy_process`), or in the UI via the "more"
   icon (bottom left) →
   view **Workflow** → **+** → select the XML file → **Upload**.
   Then create a case to try the process.

Before the first run, confirm that the `from` paths in `nae.json` point to
existing files (e.g. `views/dashboard/` and `views/side-nav/` use different
file names than the config). Fix paths or ask the user.

## Rules

**Approval.** Anything that changes the local NAE or the machine needs user
approval first: deploying a process, creating a case, executing a task,
copying/removing a module, restarting or recreating containers. Read-only calls (validate, list) don't. Never delete
Docker volumes or data.

**Credentials.** The generated super admin password is a secret. Read it from the
log only when needed, and never write it into files, commits, reports or chat
output.

**Processes.**

- An application is a folder `processes/<app_name>/` with process XMLs and a
  short `README.md`. Applications only separate business logic; all deployed
  processes can reference each other.
- `app_name` and process names are snake_case. The process `id` is
  `<app_name>/<process_name>` (e.g. `hello_world/hello_world`), unique across
  the whole NAE deployment. The file is `processes/<app_name>/<process_name>.xml`.
- Use the latest Petriflow version from the Petriflow MCP unless pinned.
- Every process change must pass `validate_process`. Do not hand-wave around errors.
- Actions are short, use Action API methods, one concern each. Never use Grape,
  meta-classes or other reflection. Longer or reusable code becomes a Petriflow
  function. Whole services become modules.

**Frontend.**

- Add a view in three places: `views` in `nae.json`, `TemplateFrontendViewService`,
  and `declarations` in `AppModule`. Prefer the schematics (`create-view`) over
  hand edits of `TemplateFrontendViewService`.
- Component behavior is configured through the DI tokens (`NAE_BASE_FILTER`,
  `NAE_VIEW_ID_SEGMENT`, …); follow `views/side-nav/cases/` as the pattern.
- Backend URLs, theme and languages (`sk-SK`, `de-DE`, `en-US`) live in `nae.json`.
  Do not hardcode them in components.
- `nae/nae-frontend/README.md` is outdated (Angular 13). `package.json` is the
  source of truth.

**Modules.**

- Sources in `modules/<artifactId>/`, built with `nae-module-maven-plugin`,
  ZIP unzipped into `nae/nae-backend/modules/<artifactId>/`, then restart `nae`.
- Actions call a module as `Module.<group>.<serviceBeanName>.<method>(args)`. `petriflow-mcp` validates the process
  XML, not the module. Otherwise use standard Java and Spring practice.

**Git.**

- Never commit jars, zips, `target/`, `node_modules/`, `dist/`, logs, `.env`, or
  secrets. `.gitignore` already covers them; never use `git add -f`.
- Do not change the NAE image version in `docker-compose.yaml` without asking.

## Testing and definition of done

A change is done only when the relevant checks pass and you have seen the output:

| Change           | Check                                                                                                             |
|------------------|-------------------------------------------------------------------------------------------------------------------|
| Process / action | `validate_process`, then a live scenario with the `test-process` skill                                            |
| Frontend         | `npm run lint`, `npm run build`, `npm test` (Karma, needs a browser) in `nae/nae-frontend`                        |
| Module           | `mvn -f modules/<artifactId>/pom.xml clean package`, deploy with approval, check NAE logs, call it from an action |

Report what was run and the results. If a check cannot run (NAE or MCP down),
say that instead of claiming success.
