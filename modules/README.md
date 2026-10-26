# Module sources

Source code of custom modules for the Application Engine. Create one Maven project per module, in a folder named after
the module's `artifactId`:

```
modules/
└── myExampleModule/
    ├── pom.xml
    └── src/
```

A module is a Java 21 Spring Boot project that is loaded into the Application Engine at start. Its `@Service` beans
annotated with `@ModuleService("<group>")` can be called from process actions as
`Module.<group>.<serviceBeanName>.<method>(...)`. Use a module only when the logic cannot be expressed as a process or
action. For the full guide, see the
[custom module documentation](https://platform.netgrif.cloud/ecosystem/modules/custom-module).

> **Requirement:** developing a module needs **Java 21 and Maven** installed on your machine. They are not needed to
> write processes only.

## Build and deploy

```bash
mvn -f modules/<artifactId>/pom.xml clean package
```

The project is packaged with `nae-module-maven-plugin` into a ZIP in `target/`. Unzip it into
[`../nae/engine/modules/<artifactId>/`](../nae/engine/modules/README.md) and restart the engine, as described
there. A module cannot be changed at runtime, so every change needs a restart.

Build output (`target/`, jars, ZIPs) is ignored by git. Do not commit it.
