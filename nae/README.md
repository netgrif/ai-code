# nae

Everything needed to run the application locally: the Docker Compose stack (engine, frontend, Petriflow MCP and
databases) and the folder where built modules are loaded from. For the overall project, see the
[main README](../README.md).

| Path                                           | Purpose                                                                          |
|------------------------------------------------|----------------------------------------------------------------------------------|
| [`docker-compose.yaml`](docker-compose.yaml)   | The stack: Application Engine, frontend, Petriflow MCP, MongoDB, Elasticsearch, Redis |
| [`nae-backend/modules/`](nae-backend/modules/) | Built modules loaded by the engine at start                                      |
| `nae-backend/logs/`                            | Engine logs, mounted from the container                                          |
| `nae-backend/storage/`                         | Engine storage, mounted from the container                                       |

## The stack

Run from this folder:

```bash
docker compose up -d                  # start everything
docker compose ps                     # service status and health
docker compose logs nae-worker        # engine logs
docker compose restart nae-worker     # reload, e.g. after changing modules
docker compose down                   # stop and remove containers
```

| Service             | Image                                          | Ports      | Purpose                                      |
|---------------------|------------------------------------------------|------------|----------------------------------------------|
| `petriflow-mcp`     | `netgrif/petriflow-mcp:1.0.0`                  | 3000       | Petriflow validation and docs for AI agents  |
| `nae-frontend`      | `netgrif/application-engine-frontend:7.0.3`    | 4200 → 80  | Standard Netgrif frontend (single-page app)  |
| `nae-worker`        | `netgrif/application-engine-with-mcp:7.0.3`    | 8080       | Application Engine, REST API and MCP server  |
| `nae-mongodb`       | `mongo:8.0.3` (replica set `rs0`)              | 27017      | Database                                     |
| `nae-elasticsearch` | `elasticsearch:8.19.15`                        | 9200, 9300 | Search index                                 |
| `nae-redis`         | `redis:8`                                      | 6379       | Cache                                        |

The frontend is served to your browser as a single-page app, so the browser calls the engine on
`http://localhost:8080` directly. It is a prebuilt image: there are no frontend sources in this repository. The
frontend starts after the engine is healthy.

The engine is configured through environment variables in `docker-compose.yaml`. Once it is ready,
`curl http://localhost:8080/manage/health` returns status `UP`. On the first run it creates the super admin
`super@netgrif.com` and prints a generated password to `nae-backend/logs/nae.log`. Log in at
<http://localhost:4200>.

The database services have no volumes configured, so their data is removed together with the containers
(`docker compose down`).

## Extending your instance

- **Processes:** [`../processes/`](../processes/README.md). Forms and the application menu are defined in processes.
- **Modules:** source code lives in [`../modules/`](../modules/README.md) (building needs Java 21 and Maven). Built
  output is unzipped into [`nae-backend/modules/`](nae-backend/modules/README.md), which is mounted into the engine
  container.
