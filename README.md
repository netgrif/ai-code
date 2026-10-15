# Netgrif Platform Starter

A template for building applications on the [Netgrif Platform](https://platform.netgrif.cloud).
It gives you a local Netgrif Application Engine (NAE) stack, an Angular frontend, and a place for your
[Petriflow](https://github.com/petriflow/petriflow) processes, so you can go from an empty folder to a running
workflow application quickly.

In a Netgrif application the business logic lives in **Petriflow processes** (Petri net based workflows described in
XML, with Groovy actions). The engine runs them, and the frontend lets users work with cases and tasks. Custom frontend
components and backend plugins are available for the cases where a process alone is not enough.

## What's inside

| Path                           | Purpose                                                                      |
|--------------------------------|------------------------------------------------------------------------------|
| `nae/docker-compose.yaml`      | Local stack: Application Engine (`:8080`), MongoDB, Elasticsearch, Redis     |
| `nae/nae-frontend/`            | Angular 17 frontend built on `@netgrif/components`, configured by `nae.json` |
| `nae/nae-backend/plugins/`     | Built plugins, loaded by the engine at start                                 |
| `nae/nae-backend/logs/`        | Engine logs, mounted from the container                                      |
| `processes/`                   | Petriflow processes, one subfolder per application (includes `hello_world`)  |
| `plugins/`                     | Source code of custom plugins, one Maven project per plugin                  |
| `.agents/skills/`, `AGENTS.md` | Optional instructions for AI coding agents (see below)                       |

## Requirements

- Docker with Docker Compose
- Node.js 22 or newer (current LTS recommended) and npm
- Java 21 and Maven, only if you write plugins

## Getting started

1. Create your own repository from this template (**Use this template** on GitHub) or clone it.

2. Start the backend:

   ```bash
   cd nae
   docker compose up -d
   ```

   Wait until the engine is up. This returns status `UP` when it is ready:

   ```bash
   curl http://localhost:8080/manage/health
   ```

3. Start the frontend:

   ```bash
   cd nae/nae-frontend
   npm install --legacy-peer-deps
   npm start
   ```

   The application is served at <http://localhost:4200> and talks to the engine at `http://localhost:8080/api`.

4. Log in as `super@netgrif.com`. The password is generated on the first run and printed in
   `nae/nae-backend/logs/nae.log`.

5. Import the example process. In the UI, open the "more" icon (bottom left), choose the **Workflow** view, click **+**,
   select `processes/hello_world/hello_world.xml` and click **Upload**. Then create a case from it and work through its
   tasks.

To stop the stack, run `docker compose down` in the `nae` folder.

## Developing your application

Implement a requirement with the first of these that works:

1. **Petriflow process.** Add your XML under `processes/<your-app>/`. Data, tasks, roles, and Groovy actions all live
   there. This is the default for application logic.
2. **Existing components.** The frontend views and their navigation are configured in
   `nae/nae-frontend/nae.json` and use components from `@netgrif/components`.
3. **Custom frontend component.** Only if the library has no component that your process needs. Views are registered in
   `nae.json`, `TemplateFrontendViewService`, and `AppModule`.
4. **Plugin.** Only if the logic cannot be a process or action, for example a whole service such as OCR. Plugins are
   Java
   Spring Boot applications that use the Netgrif Plugin SDK. Put the source in `plugins/<plugin-name>/` and the built
   output in `nae/nae-backend/plugins/`, then restart the engine. See the
   [plugin guide](https://platform.netgrif.cloud/ecosystem/plugins/custom-plugin).

Built artifacts (jars, zips, `target/`, `node_modules/`, `dist/`) are ignored by git and should not be committed.

## Working with AI agents

The repository is prepared for AI coding agents that support `AGENTS.md`, skills, and MCP:

- `AGENTS.md` explains the project, setup, and rules for development and testing.
- `.agents/skills/` contains playbooks for generating processes and actions, testing a process, and writing frontend
  components
  and plugins.
- `.mcp.json` registers two MCP servers: the public Petriflow server (`https://localhost:3000/mcp`) for validation
  and the Action API reference, and a local one (`http://localhost:8080/mcp`) for deploying and running processes on
  your engine.

Using an agent is optional. Everything above works without one.

## Learn more

- [Netgrif Platform documentation](https://platform.netgrif.cloud)
- [Petriflow](https://github.com/petriflow/petriflow), the process language and its action API docs
- [Netgrif Application Engine](https://github.com/netgrif/application-engine)
- [Netgrif Components](https://github.com/netgrif/components), the Angular library used by the frontend
- [Community](https://community.netgrif.com)

## License

Licensed under the Apache License 2.0. See [LICENSE.txt](LICENSE.txt).
