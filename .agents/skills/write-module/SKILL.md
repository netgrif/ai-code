---
name: write-module
description: Builds, packages and deploys custom NAE modules, Spring Boot code loaded into the Application Engine, whose services Petriflow actions call as Module.group.bean.method. Use when creating, changing, building or deploying a module in modules/, or when a Petriflow action needs Java functionality or a whole service that cannot be a process or action (e.g. OCR, an external system integration). Not for logic that fits in an action (use generate-action).
compatibility: Requires Java 21, Maven and Docker with Compose; deploying needs the local NAE stack from nae/docker-compose.yaml.
metadata:
  tested: false
  version: 0.3.0
---

# Implement NAE Module

## Overview

A module is a Spring Boot project that is loaded into the Application Engine
(NAE) at start, in the engine's own classloader. It can inject any engine
service, and its `@ModuleService` beans are callable from Petriflow actions.
The module's main class is **not executed** when NAE loads it: only the beans
found by component scanning are registered. Sources live in
`modules/<artifactId>/` (one Maven project per module). The build
(`nae-module-maven-plugin`) produces a ZIP with the module jar and a `libs/`
directory. The ZIP is unzipped into `nae/nae-backend/modules/<artifactId>/`,
which the compose file mounts into the engine container. A module cannot be
changed at runtime: every change needs an engine restart.
Reference: https://platform.netgrif.cloud/ecosystem/modules/custom-module

**Approval rule:** writing sources and running `mvn` need no approval. Removing
or unzipping into `nae/nae-backend/modules/` and restarting the container change
the local instance and need user approval first.

## Steps

0. **Preflight:** run `java -version` and `mvn -v`. Developing a module needs
   **Java 21 and Maven**. If either is missing or Java is not 21, stop and tell
   the developer to install it. Do not continue without them.
1. **Sources:** create or edit `modules/<artifactId>/`. The directory name equals
   the artifactId. Never put sources under `nae/`.
2. **Project:** standard Maven layout, Java 21. Add the engine as a dependency
   with `provided` scope (the engine itself must not be packaged), at the
   version of the engine image in `nae/docker-compose.yaml` (the current
   reference is 7.0.3). Import the Spring Boot BOM matching that engine version.
   Fill in `name`, `description`, `groupId`, `artifactId` and `version`: the
   packaging plugin copies them into the jar manifest.
   Working reference: https://platform.netgrif.cloud/ecosystem/modules/custom-module
3. **Packaging:** add `nae-module-maven-plugin` (version 1.3.0, goal `build`,
   `singleOutput` true, `forceEnableWorkerProfile` true, `hostApp` =
   `com.netgrif:application-engine` at the same engine version, excludes
   `*log4j`, `*logback*`, `*lombok*`). Do not use the Spring Boot repackage
   goal: the jar must be a plain jar, not a fat jar.
4. **Component scan:** the main class is used only to run the module locally.
   Add a configuration class in the root package so the beans are registered
   when NAE loads the module:

   ```java
   @Configuration
   @ComponentScan("org.example.module")
   public class ExampleModuleConfiguration {
   }
   ```

   The main class for local runs scans the engine too:

   ```java
   @EnableAsync
   @EnableCaching
   @SpringBootApplication
   @ComponentScan({"com.netgrif.application.engine", "org.example.module"})
   public class ExampleModuleApplication {
       public static void main(String[] args) {
           new SpringApplicationBuilder()
                   .sources(ApplicationEngine.class, ExampleModuleApplication.class)
                   .run(args);
       }
   }
   ```

5. **Service for actions:** a `@Service` annotated with `@ModuleService("<group>")`.
   Its public methods are callable from actions. Engine services (for example
   `WorkflowService`, `UserService`) can be injected.
6. **Startup logic (optional):** a bean implementing
   `ProcessApplicationStartupRunner` annotated with `@RunnerOrder(<int>)`;
   smaller values run first.
7. **Build:** `mvn -f modules/<artifactId>/pom.xml clean package`. Tests must
   pass. The ZIP is in `modules/<artifactId>/target/`.
8. **Deploy (approval):** show the user the ZIP path, the directory that will be
   replaced, and the restart command. After approval: delete
   `nae/nae-backend/modules/<artifactId>/`, unzip the ZIP into it (jar and
   `libs/` directly inside), run
   `docker compose -f nae/docker-compose.yaml restart nae`, then check
   `docker compose -f nae/docker-compose.yaml logs nae` for load errors.
   NAE scans the folder recursively.
9. **Use in Petriflow:** call from an action as
   `Module.<group>.<serviceBeanName>.<method>(args)`. The bean name is the
   default Spring name of the service class (class name with a lowercase first
   letter). Verify end-to-end with the `test-process` skill. `petriflow-mcp`
   validates the process XML that calls the module, not the module itself.

## Java and Spring practice

Use standard Java and Spring practice: constructor injection, `@ConfigurationProperties`
for settings, no hardcoded hosts or secrets, SLF4J logging, unit tests with
`spring-boot-starter-test`. Service classes carry the logic; keep what the action
calls thin.

## Example

```java
@Service
@ModuleService("example")
public class ExampleService {

    public String getHelloWorld() {
        return "Hello World";
    }
}
```

```groovy
// println only to show the call; in a real action use the result (e.g. in a `change` call)
println Module.example.exampleService.getHelloWorld()
```

## Git hygiene

ZIPs, jars and `target/` never go into git; `.gitignore` already covers them.
Before finishing, run `git status --short` and confirm none appear. If one does,
fix `.gitignore`. Never use `git add -f`.

## Common mistakes

- Java or Maven missing, or a Java version other than 21.
- Fat jar from the Spring Boot plugin instead of the module ZIP.
- Engine dependency without `provided` scope, so the engine is packaged into the module.
- No `@Configuration` with `@ComponentScan`: works locally, but no beans load in NAE.
- Missing `@ModuleService` on the service, so actions cannot see it.
- Module and engine versions differ from the running engine image.
- Copying the ZIP without unzipping it.
- Sources placed in `nae/nae-backend/modules/` (that folder is for built output only).
- Unzipping over an old version so stale `libs/` jars remain.
- Restarting the container before unzipping.
- Compose volume path not matching the real folder name.
- Committing built artifacts.
