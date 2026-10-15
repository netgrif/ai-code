---
name: write-plugin
description: Builds, packages and deploys custom NAE plugins, Spring Boot modules using the Netgrif plugin-client, that Petriflow actions call. Use when creating, changing, building or deploying a plugin in plugins/, or when a Petriflow action needs Java functionality or a whole service that cannot be a process or action (e.g. OCR, an external system integration). Not for logic that fits in an action (use generate-action).
compatibility: Requires Java 21, Maven and Docker with Compose; deploying needs the local NAE stack from nae/docker-compose.yaml.
metadata:
  tested: false
  version: 0.2.0
---

# Implement NAE Plugin

## Overview

A plugin is a Spring Boot application using the Netgrif Plugin SDK, loaded by
NAE as a module at start. Sources live in `plugins/<artifactId>/` (one Maven
project per plugin). The build (`nae-module-maven-plugin`) produces a ZIP with
a plain jar and a `libs/` directory. The ZIP is unzipped into
`nae/nae-backend/plugins/<artifactId>/`, which the compose file mounts into the
engine container. Reference:
https://platform.netgrif.cloud/ecosystem/plugins/custom-plugin

**Approval rule:** writing sources and running `mvn` need no approval. Removing
or unzipping into `nae/nae-backend/plugins/` and restarting the container change
the local instance and need user approval first.

## Steps

1. **Sources:** create or edit `plugins/<artifactId>/`. The directory name equals
   the artifactId, which becomes the plugin name in Petriflow (`Plugin.<artifactId>`), so use a valid Groovy identifier
   such as
   `myExamplePlugin`. Never put sources under `nae/`.
2. **Project:** standard Maven Spring Boot layout, Java 21, Spring Boot 3.2.5,
   dependency `com.netgrif:plugin-client:5.0.0`. Application sources must include
   `PluginLibraryApplication`, with package scan and property scan configured.
   Set `netgrif.plugin.groupId/artifactId/version` (defaults come from the pom).
   Do not set `registration-server.*` or `grpc.*` properties: they don't apply
   when the plugin is loaded as a module.
   <!-- TODO: add working package scan / property scan example -->
3. **Packaging:** the pom uses `nae-module-maven-plugin` (goal `build`,
   `singleOutput` true, `hostApp` = `com.netgrif:application-engine` at the
   version of the engine image in `nae/docker-compose.yaml`, excludes
   `*log4j`, `*logback*`, `*lombok*`). Engine classes are `provided` scope.
   Do not use the Spring Boot repackage goal: the jar must be a plain jar.
4. **Entry points:** a class annotated `@EntryPoint("<name>")` (already a Spring
   bean, no `@Component` needed) with methods annotated `@EntryPointMethod`.
   Arguments and return types must not be primitives; engine domain classes (`com.netgrif.engine.application.engine`)
   are allowed.
5. **Events (optional):** extend `Listener`, register with a dispatcher; see
   docs "Event listener".
6. **Build:** `mvn -f plugins/<artifactId>/pom.xml clean package`. Tests must
   pass. The ZIP is in `plugins/<artifactId>/target/`.
7. **Deploy (approval):** show the user the ZIP path, the directory that will be
   replaced, and the restart command. After approval: delete
   `nae/nae-backend/plugins/<artifactId>/`, unzip the ZIP into it (jar and
   `libs/` directly inside), run
   `docker compose -f nae/docker-compose.yaml restart nae`, then check
   `docker compose -f nae/docker-compose.yaml logs nae` for load errors.
8. **Use in Petriflow:** call from an action as
   `Plugin.<artifactId>.<entryPointName>.<method>(args)`. Verify end-to-end with
   the `test-process` skill.

## Spring conventions

- Constructor injection, `@Service` for logic. Entry point classes only delegate.
- Configuration via `@ConfigurationProperties` or `application.properties`;
  no hardcoded hosts or secrets.
- SLF4J logging, no `System.out`.
- Unit tests with `spring-boot-starter-test`.

## Example

```java
@EntryPoint("greeter")
@RequiredArgsConstructor
public class Greeter {
    private final GreetingService service;

    @EntryPointMethod
    public String getMessage(String name) {
        return service.greet(name);
    }
}
```

```groovy
// println only to show the call; in a real action use the result (e.g. in a `change` call)
println Plugin.myExamplePlugin.greeter.getMessage("John")
```

## Git hygiene

ZIPs, jars and `target/` never go into git; `.gitignore` already covers them.
Before finishing, run `git status --short` and confirm none appear. If one does,
fix `.gitignore`. Never use `git add -f`.

## Common mistakes

- Fat jar from the Spring Boot plugin instead of the module ZIP.
- Copying the ZIP without unzipping it.
- Sources placed in `nae/nae-backend/plugins/` (that folder is for built output only).
- Unzipping over an old version so stale `libs/` jars remain.
- Restarting the container before unzipping.
- Compose volume path not matching the real folder name.
- Primitive-typed entry point arguments.
- Configuring registration-server/grpc properties for a module-loaded plugin.
- Committing built artifacts.
