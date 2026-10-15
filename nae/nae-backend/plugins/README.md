# Built plugins

This folder is mounted into the Application Engine container (`/opt/netgrif/engine/modules/custom`). The engine loads
every plugin found here when it starts.

It holds **built output only**. Plugin source code belongs in [`../../../plugins/`](../../../plugins/README.md).

## Layout

Each plugin is unzipped into a folder named after its `artifactId`:

```
nae-backend/plugins/
└── myExamplePlugin/
    ├── myExamplePlugin-1.0.0.jar
    └── libs/
```

The ZIP is produced by `nae-module-maven-plugin` during `mvn clean package` in the plugin project (see
[`../../../plugins/README.md`](../../../plugins/README.md)).

## Deploying a plugin

1. Build the plugin and locate the ZIP in its `target/` folder.
2. Delete the old `nae-backend/plugins/<artifactId>/` folder, if there is one.
3. Unzip the new ZIP into `nae-backend/plugins/<artifactId>/`.
4. Restart the engine from the `nae` folder: `docker compose restart nae`.
5. Check `docker compose logs nae` for loading errors.

Jars and ZIPs are ignored by git. Do not commit them.
