# Built modules

This folder is mounted into the root worker container (`/opt/netgrif/engine/modules/custom`). The worker scans it
recursively and loads every module found here when it starts. In a cluster a module runs only in the worker that has
it; put it into every worker that needs it.

It holds **built output only**. Module source code belongs in [`../../../modules/`](../../../modules/README.md).

## Layout

Each module is unzipped into a folder named after its `artifactId`:

```
nae/engine/modules/
└── myExampleModule/
    ├── myExampleModule-1.0.0.jar
    └── libs/
```

The ZIP is produced by `nae-module-maven-plugin` during `mvn clean package` in the module project (see
[`../../../modules/README.md`](../../../modules/README.md)). Building a module requires Java 21 and Maven, and the
engine dependency must match NAE `7.1.0`.

## Deploying a module

1. Build the module and locate the ZIP in its `target/` folder.
2. Delete the old `nae/engine/modules/<artifactId>/` folder, if there is one.
3. Unzip the new ZIP into `nae/engine/modules/<artifactId>/`.
4. Restart the engine from the repository root: `docker compose restart engine`.
5. Check `docker compose logs engine` for loading errors.

Jars and ZIPs are ignored by git. Do not commit them.
