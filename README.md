# Netgrif Platform Starter

A template for building applications on the [Netgrif Platform](https://platform.netgrif.cloud).
It gives you a local Netgrif Application Engine (NAE) stack with the standard Netgrif frontend, and a place for your
[Petriflow](https://github.com/petriflow/petriflow) processes, so you can go from an empty folder to a running
workflow application quickly.

In a Netgrif application the business logic lives in **Petriflow processes** (Petri net based workflows described in
XML, with Groovy actions). The engine runs them, and the frontend lets users work with cases and tasks. Backend
modules are available for the cases where a process alone is not enough.

## What's inside

| Path                           | Purpose                                                                                                          |
|--------------------------------|------------------------------------------------------------------------------------------------------------------|
| `nae/docker-compose.yaml`      | Local stack: Application Engine (`:8080`), frontend (`:4200`), Petriflow MCP (`:3000`), MongoDB, Elasticsearch, Redis |
| `nae/nae-backend/modules/`     | Built modules, loaded by the engine at start                                                                     |
| `nae/nae-backend/logs/`        | Engine logs, mounted from the container                                                                          |
| `nae/nae-backend/storage/`     | Engine storage, mounted from the container                                                                       |
| `processes/`                   | Petriflow processes, one subfolder per application (includes `hello_world`)                                      |
| `modules/`                     | Source code of custom modules, one Maven project per module                                                      |
| `.agents/skills/`, `AGENTS.md` | Optional instructions for AI coding agents (see below)                                                           |

The frontend is a prebuilt container image, so there are no frontend sources in this repository.

## Requirements

- Docker with Docker Compose
- Java 21 and Maven, **required only if you develop custom modules** (not needed to write processes)

## Getting started

1. Create your own repository from this template (**Use this template** on GitHub) or clone it.

2. Start the stack:

   ```bash
   cd nae
   docker compose up -d
   ```

   Wait until the engine is up. This returns status `UP` when it is ready:

   ```bash
   curl http://localhost:8080/manage/health
   ```

   The frontend container starts after the engine is healthy.

3. Open <http://localhost:4200> and log in as `super@netgrif.com`. The password is generated on the first run and
   printed in `nae/nae-backend/logs/nae.log`. The frontend is a single-page app, so your browser calls the engine on
   `http://localhost:8080` directly.

4. Import the example process. In the UI, open the "more" icon (bottom left), choose the **Workflow** view, click **+**,
   select `processes/hello_world/hello_world.xml` and click **Upload**. Then create a case from it and work through its
   tasks.

To stop the stack, run `docker compose down` in the `nae` folder.

## Developing your application

Implement a requirement with the first of these that works:

1. **Petriflow process.** Add your XML under `processes/<your-app>/`. Data, tasks, forms, roles, and Groovy actions all
   live there. The application menu is a process too. This is the default for application logic.
2. **Module.** Only if the logic cannot be a process or action, for example a whole service such as OCR. Modules are
   Java Spring Boot projects loaded into the engine at start; their services are called from actions as
   `Module.<group>.<bean>.<method>()`. Developing one requires Java 21 and Maven. Put the source in
   `modules/<module-name>/` and the built output in `nae/nae-backend/modules/`, then restart the engine
   (`docker compose restart nae-worker`). See the
   [module guide](https://platform.netgrif.cloud/ecosystem/modules/custom-module).

The user interface is the standard Netgrif frontend. It is not customized in this repository.

Built artifacts (jars, zips, `target/`) are ignored by git and should not be committed.

## Working with AI agents

The repository is prepared for AI coding agents that support `AGENTS.md`, skills, and MCP:

- `AGENTS.md` explains the project, setup, and rules for development and testing.
- `.agents/skills/` contains playbooks for generating processes, actions and the application menu, testing a process,
  and writing modules.
- `.mcp.json` registers two MCP servers: `petriflow-mcp` (`http://localhost:3000/mcp`, run locally by Docker Compose) for validation
  and the Action API reference, and `engine-mcp` (`http://localhost:8080/mcp`, needs the running engine) for deploying and running processes on
  your engine.

Using an agent is optional. Everything above works without one.

## Learn more

- [Netgrif Platform documentation](https://platform.netgrif.cloud)
- [Petriflow](https://github.com/petriflow/petriflow), the process language and its action API docs
- [Netgrif Application Engine](https://github.com/netgrif/application-engine)
- [Community](https://community.netgrif.com)

## License

Licensed under the Apache License 2.0. See [LICENSE.txt](LICENSE.txt).
