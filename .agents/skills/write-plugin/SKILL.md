---
name: write-plugin
description: Builds, runs and wires custom Netgrif Platform plugins, standalone Spring Boot services registered with the admin node, whose entry points Petriflow actions call as Plugin.registrationName.entryPoint.method. Use when a requirement needs Java code, a Java library or a whole service that an action cannot provide (e.g. PDF generation, OCR, an external system integration or SDK), or when creating, changing, building, running or removing a plugin in plugins/. This is the default way to extend the platform; a module (write-module) only when a plugin cannot do it.
compatibility: Requires Java 21, Maven 3+ and Docker with Compose; running it needs the local platform cluster from docker-compose.yaml (nae-admin and the root worker nae-engine).
metadata:
  tested: false
  version: 0.1.0
---

# Implement a Netgrif Platform plugin

## Overview

A plugin is a standalone Spring Boot service (a node of the platform cluster).
At start it opens a gRPC server and registers with the admin node; from then
on any Petriflow action can call its entry points:

```groovy
Plugin.<registrationName>.<entryPoint>.<method>(args)
```

The plugin works with cases, tasks, data and users through
`PluginActionApi` (gRPC back to the workers). Because it is a separate
process, it brings its own libraries, runs, scales and is replaced without
restarting the engine.

Sources live in `plugins/<artifactId>/`, one Maven project per plugin, with a
`Dockerfile` and a `compose.yaml`. The root `docker-compose.yaml` pulls each
plugin in with `include:`, so `docker compose up -d` starts the plugins with
the cluster.

Reference repository: `example-nae-plugin` (Netgrif). **The web docs
(platform.netgrif.cloud, plugin-client 5.0.0, Spring Boot 3.2.5,
`registration-server.*`) and the example's `application.properties` and test
process are outdated.** Use the versions, keys and pom in this skill and in
[references/project-template.md](references/project-template.md); they were
verified against `plugin-client` 1.1.0.

**Approval rule:** writing sources and running `mvn` need no approval. Editing
the root `docker-compose.yaml`, building or starting the plugin image,
removing it, deploying a process and running test cases change the local
machine or NAE and need user approval first.

## Plugin or module?

Use a plugin unless one of these is true; then use `write-module` and tell the
user which condition applied:

| The code must...                                                               | Use    |
|--------------------------------------------------------------------------------|--------|
| call a library or service, compute, generate or integrate, called from actions | plugin |
| read or change cases, tasks, data, files or users (`PluginActionApi` covers it) | plugin |
| call another plugin or a module's services (a plugin cannot)                    | module |
| use engine internals that `PluginActionApi` does not expose                     | module |
| run inside the worker's own call (same thread or transaction as the action)    | module |

Logic that fits into a short action stays an action (`generate-action`).
Reacting to platform events (listeners) is **not** covered by this version
of the skill: it is not verified for plugins yet. Tell the user instead of
improvising.

## Steps

0. **Preflight.** Run `java -version` and `mvn -v`. A plugin needs **Java 21
   and Maven 3+**. If either is missing or Java is not 21, stop and tell the
   developer to install it. `mvn -v` shows the JDK Maven runs on; a newer JDK
   is fine because the build targets release 21. Check that the cluster is
   up: `curl -s http://localhost:8888/manage/health` returns `UP`. If not,
   say so; the steps up to the build can still run.
1. **Names.** Choose:
   - `artifactId`: kebab-case, also the folder name and compose service name
     (e.g. `invoice-pdf-plugin`).
   - `registrationName`: camelCase, a valid Groovy identifier, unique in the
     cluster (e.g. `invoicePdf`). Actions use it. If it is missing, the
     artifactId is used, which is not a valid identifier when it has a dash.
   - Java package: your own (e.g. `com.<company>.<plugin>`), never
     `org.example.demo`.
   - Ports: REST from 8701 and gRPC from 9701, one higher than the highest
     used by another `plugins/*/compose.yaml`.
2. **Project.** Create `plugins/<artifactId>/` from
   [references/project-template.md](references/project-template.md): pom,
   main class, entry point, service, test, `application.properties`,
   `Dockerfile`, `.dockerignore`, `compose.yaml`, `README.md`. Keep the pom's
   build section exactly as in the template (see Common mistakes).
3. **Entry points.** A class annotated `@EntryPoint("<entryPoint>")` (it is a
   Spring `@Component`, so constructor injection works) with public methods
   annotated `@EntryPointMethod(name = "<method>")`. Keep them thin; the logic
   goes into `@Service` classes. Arguments and return values travel over gRPC:
   use non-primitive types (`String`, `Long`, `Boolean`, `List`, `Map`) or the
   engine's domain classes (`Case`, `Task`, ...). Overloads need different
   `name`s.
4. **Working with NAE data.** Inject `PluginActionApi`
   (`com.netgrif.plugin.client.actions`): `findCase`, `searchCases`,
   `createCaseByIdentifier`, `getData`, `setData`, `assignTask`, `finishTask`,
   `saveFile(caseId, fieldId, ActionFileHolder)`, `getFile`, `findUser`, ...
   For system operations use `actionApi.getSystemUserDto()` as principal.
   Prefer returning a value to the action and letting the action write it into
   the case (`change field value { ... }`); use `PluginActionApi` when the
   plugin itself must write (e.g. a generated file into a file field).
5. **Configuration.** `plugin-client` ships an `application.yaml` with
   defaults read from env variables. The plugin adds only
   `src/main/resources/application.properties` (never an `application.yaml`:
   it would hide the client's file). Keys:

   | Key                                          | Env                                          | Local value          |
   |----------------------------------------------|----------------------------------------------|----------------------|
   | `netgrif.plugin.service.host`                | `NETGRIF_PLUGIN_SERVICE_HOST`                | `<artifactId>`       |
   | `netgrif.plugin.service.grpc.port`           | `NETGRIF_PLUGIN_SERVICE_GRPC_PORT`           | `97xx`               |
   | `netgrif.plugin.service.admin-node.host`     | `NETGRIF_PLUGIN_SERVICE_ADMIN_NODE_HOST`     | `nae-admin`          |
   | `netgrif.plugin.service.admin-node.grpc-port`| `NETGRIF_PLUGIN_SERVICE_ADMIN_NODE_GRPC_PORT`| `9999`               |
   | `netgrif.plugin.service.search.default-zone` | `NETGRIF_PLUGIN_SERVICE_SEARCH_DEFAULT_ZONE` | `z1` (default `private`) |
   | `server.port`                                | `SERVER_PORT`                                | `87xx`               |

   `service.host` is the name the cluster calls the plugin by, so it must be
   the compose service name, never `localhost`. Own settings go under
   `netgrif.plugin.<registrationName>.*` with `@ConfigurationProperties`;
   secrets come from env variables, never from files in git.
6. **Build.** `mvn -f plugins/<artifactId>/pom.xml clean package`. Tests must
   pass. The output must say `Total entry points found: N -> [...]`; if it says
   `No entry points (@EntryPoint) found`, the build section is wrong. The jar
   to run is `target/<artifactId>-<version>-exec.jar`.
7. **Wire into compose (approval).** Show the user the change, then add the
   plugin to the `include:` list at the top of the root `docker-compose.yaml`
   (create the list before `x-admin-password` if it does not exist):

   ```yaml
   include:
     - plugins/<artifactId>/compose.yaml
   ```

   Run `docker compose config --quiet` (no output means valid).
8. **Run (approval).** From the repository root:
   `docker compose up -d --build <artifactId>`. After a code change: rebuild
   with Maven first, then the same command (it rebuilds the image).
9. **Verify registration.** `engine-mcp` does not list plugins yet. Check:
   - `docker compose ps <artifactId>` shows `healthy`;
   - `docker compose logs <artifactId>` shows the registration with the admin
     and no gRPC errors;
   - the admin UI http://localhost:8888/cluster/plugins lists the plugin as
     RUNNING (ask the user to look, or use the browser panel).
10. **Call it from a process.** In an action:
    `Plugin.<registrationName>.<entryPoint>.<method>(args)`. Write the action
    with `generate-action`; `petriflow-mcp` validates the process XML, not the
    plugin. Deploy and run it with `test-process`; the definition of done is a
    real call from a task with the expected result.
11. **Remove a plugin (approval).** `docker compose rm -sf <artifactId>`,
    remove its line from `include:` (and the `include:` key when the list is
    empty), then `docker compose config --quiet`. Delete
    `plugins/<artifactId>/` only when the user asks. Processes calling it fail
    at runtime afterwards: list them (`grep -rn "Plugin.<registrationName>" processes/`).

## Java and Spring practice

Constructor injection, `@ConfigurationProperties` for settings, no hardcoded
hosts or secrets, SLF4J logging, unit tests with JUnit for services and
entry points (construct them directly). Do **not** add a `@SpringBootTest`
context test: starting the context runs the registration against whatever
admin answers on `localhost:9999`.

## Git hygiene

`target/`, jars and logs never go into git; `.gitignore` covers them. Commit
the sources, `Dockerfile`, `.dockerignore`, `compose.yaml` and `README.md`.
Before finishing, run `git status --short` and confirm no build output
appears. Never use `git add -f`.

## Common mistakes

- Choosing a module because "actions cannot call a plugin": they can, through
  `Plugin.<registrationName>`.
- Copying the web docs or the example's `application.properties`
  (`registration-server.*`, `admin-node.port`, `grpc.host`, `PLUGIN_URL`,
  `REGISTRATION_SERVER_*`): the plugin never registers.
- `nae-plugin-maven-plugin` bound to `generate-sources` (as in the example):
  on a clean build it finds no compiled classes and silently skips the
  registration. Bind it to `process-classes` with the second compiler
  execution from the template.
- No `registrationName`, or one with a dash: the action cannot address the
  plugin.
- `netgrif.plugin.service.host=localhost` or a host that is not the compose
  service name: the cluster cannot call the plugin back.
- `search.default-zone` left at `private`: searches go to a zone without
  workers.
- Missing `spring-boot-starter-actuator`: no `/manage/health`, the container
  never becomes healthy.
- Missing `url`, `scm` and `licenses` in the pom: the registration metadata
  shows Spring Boot's values.
- An `application.yaml` in the plugin, which hides the client's defaults.
- Primitive arguments in entry point methods.
- Two plugins with the same ports or `registrationName`.
- `@SpringBootTest` context test registering a test plugin with the local admin.
- Plugin calling another plugin or a module: not possible, redesign or use a module.
- Running `docker compose` from the plugin folder instead of the repository
  root (the plugin's `depends_on` refers to services of the root file).
