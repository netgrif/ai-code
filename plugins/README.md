# Plugin sources

Source code of custom plugins for the Application Engine. Create one Maven project per plugin, in a folder named after
the plugin's `artifactId`:

```
plugins/
└── myExamplePlugin/
    ├── pom.xml
    └── src/
```

A plugin is a Java 21 Spring Boot application that uses the Netgrif Plugin SDK (`com.netgrif:plugin-client`). Its
`@EntryPoint` classes can be called from process actions as `Plugin.<artifactId>.<entryPoint>.<method>(...)`. Use a
plugin only when the logic cannot be expressed as a process or action. For the full guide, see the
[custom plugin documentation](https://platform.netgrif.cloud/ecosystem/plugins/custom-plugin).

## Build and deploy

```bash
mvn -f plugins/<artifactId>/pom.xml clean package
```

The project is packaged with `nae-module-maven-plugin` into a ZIP in `target/`. Unzip it into
[`../nae/nae-backend/plugins/<artifactId>/`](../nae/nae-backend/plugins/README.md) and restart the engine, as described
there.

Build output (`target/`, jars, ZIPs) is ignored by git. Do not commit it.
