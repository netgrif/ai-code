# Plugin sources

Source code of your own plugins for the Netgrif Platform. A plugin is a standalone Java 21 Spring Boot service that
registers with the platform admin node; process actions call its entry points as
`Plugin.<registrationName>.<entryPoint>.<method>(...)`. It brings its own libraries, runs in its own container and is
replaced without restarting the engine, so it is the default way to add Java code. Use a
[module](../modules/README.md) only when a plugin cannot do it.

Create one Maven project per plugin, in a folder named after its `artifactId`:

```
plugins/
└── invoice-pdf-plugin/
    ├── pom.xml
    ├── Dockerfile
    ├── compose.yaml
    ├── README.md
    └── src/
```

> **Requirement:** developing a plugin needs **Java 21 and Maven 3+** installed on your machine. They are not needed to
> write processes only.

## Build and run

From the repository root:

```bash
mvn -f plugins/<artifactId>/pom.xml clean package
docker compose up -d --build <artifactId>
```

Each plugin's `compose.yaml` is listed under `include:` at the top of [`../docker-compose.yaml`](../docker-compose.yaml),
so `docker compose up -d` starts it together with the cluster. Once it runs, the platform admin lists it at
<http://localhost:8888/cluster/plugins>.

The AI assistant follows [`.agents/skills/write-plugin/`](../.agents/skills/write-plugin/SKILL.md), which holds the
project template and the settings that work with this platform version. The public plugin documentation and older
example plugins use outdated versions and property names.

Build output (`target/`, jars) is ignored by git. Do not commit it.
