# Netgrif Application Engine

Data of the local Netgrif stack and notes about the stack itself. The stack is defined in
[`docker-compose.yaml`](../docker-compose.yaml) in the repository root: engine, frontend, Petriflow MCP and databases.
For the overall project, see the [main README](../README.md). It also describes the folders the stack shares with your
machine and their permissions.

| Path                                 | Purpose                                     |
|--------------------------------------|---------------------------------------------|
| [`engine/modules/`](engine/modules/) | Built modules loaded by the engine at start |
| `engine/logs/`                       | Engine logs, mounted from the container     |
| `engine/storage/`                    | Engine storage, mounted from the container  |

## The stack

Run from the repository root:

```bash
docker compose up -d                  # start everything
docker compose ps                     # service status and health
docker compose logs engine            # engine logs
docker compose restart engine         # reload, e.g. after changing modules
docker compose down                   # stop and remove containers
```

| Service             | Image                                       | Ports      | Purpose                                                  |
|---------------------|---------------------------------------------|------------|----------------------------------------------------------|
| `petriflow-mcp`     | `netgrif/petriflow-mcp:1.0.0`               | 3000       | Petriflow validation and docs for AI agents              |
| `builder`           | `netgrif/application-builder:2.1.1-rc.3`    | 4300 → 80  | Visual editor of the files in `processes/`               |
| `init-perms`        | `busybox:1.37`                              | none       | One-off job: owner of `engine/logs` and `engine/storage` |
| `frontend`          | `netgrif/application-engine-frontend:7.0.3` | 4200 → 80  | Standard Netgrif frontend (single-page app)              |
| `engine`            | `netgrif/application-engine-with-mcp:7.0.3` | 8080       | Application Engine, REST API and MCP server              |
| `nae-mongodb`       | `mongo:8.0.3` (replica set `rs0`)           | 27017      | Database                                                 |
| `nae-elasticsearch` | `elasticsearch:8.19.15`                     | 9200, 9300 | Search index                                             |
| `nae-redis`         | `redis:8`                                   | 6379       | Cache                                                    |

The frontend is served to your browser as a single-page app, so the browser calls the engine on
`http://localhost:8080` directly. It is a prebuilt image: there are no frontend sources in this repository. The
frontend starts after the engine is healthy. The engine starts after `init-perms` has finished.

The builder is published on `127.0.0.1` only, because it can write process files without a login. It reads and writes
`../processes/` directly, so changes show up in your files at once.

The engine is configured through environment variables in [`docker-compose.yaml`](../docker-compose.yaml). Once it is
ready, `curl http://localhost:8080/manage/health` returns status `UP`. Log in at <http://localhost:4200> as `admin`; its
password is set in `docker-compose.yaml` (`netgrif.engine.security.auth.admin-password`), a local dev default. Change it
before you share the machine with anyone.

The database services have no volumes configured, so their data is removed together with the containers
(`docker compose down`).

## Extending your instance

- **Processes:** [`../processes/`](../processes/README.md). Forms and the application menu are defined in processes.
- **Modules:** source code lives in [`../modules/`](../modules/README.md) (building needs Java 21 and Maven). Built
  output is unzipped into [`engine/modules/`](engine/modules/README.md), which is mounted into the engine container.
