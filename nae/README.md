# Netgrif Application Engine

Data of the local Netgrif stack and notes about the stack itself. The stack is defined in
[`docker-compose.yaml`](../docker-compose.yaml) in the repository root: platform admin, gateway, root worker, search
node, frontend, Petriflow MCP, engine MCP plugin and databases.
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
docker compose logs nae-engine        # engine logs
docker compose restart nae-engine     # reload, e.g. after changing modules
docker compose down                   # stop and remove containers
```

| Service             | Image                                       | Ports      | Purpose                                                  |
|---------------------|---------------------------------------------|------------|----------------------------------------------------------|
| `petriflow-mcp`     | `netgrif/petriflow-mcp:1.1.1`               | 3000       | Petriflow validation and docs for AI agents              |
| `builder`           | `netgrif/application-builder:2.1.1-rc.3`    | 4300 → 80  | Visual editor of the files in `processes/`               |
| `nae-admin`         | `docker.nexus.netgrif.com/netgrif-admin:1.1.0` | 8888, 9999 (this machine only) | Cluster admin: users, processes, nodes, applications     |
| `nae-gateway`       | `docker.nexus.netgrif.com/netgrif-gateway:1.1.0` | 8080 → 8800, 8800 → 8800 | Cluster entry point; the frontend calls it             |
| `nae-engine`        | `docker.nexus.netgrif.com/netgrif-nae-worker:1.1.0` | 8082 → 8080 | NAE 7.1.0 root worker                              |
| `nae-search`        | `docker.nexus.netgrif.com/netgrif-search:1.1.0` | 8600, 9600 | Cluster search node (zone `z1`) over Elasticsearch  |
| `nae-mcp-plugin`    | `docker.nexus.netgrif.com/netgrif-nae-mcp-plugin:1.0.0` | 8700 → 8700 | Engine MCP server as a cluster plugin         |
| `init-perms`        | `busybox:1.37`                              | none       | One-off job: owner of `engine/logs` and `engine/storage` |
| `frontend`          | `netgrif/application-engine-frontend:7.1.0` | 4200 → 80  | Standard Netgrif frontend (single-page app)              |
| `nae-mongodb`       | `mongo:8.0.3` (replica set `rs0`)           | 27017      | Database                                                 |
| `nae-elasticsearch` | `elasticsearch:8.19.15`                     | 9200, 9300 | Search index                                             |
| `nae-redis`         | `redis:8`                                   | 6379       | Cache                                                    |

The frontend is served to your browser as a single-page app, so the browser calls the gateway on
`http://localhost:8080` directly. It is a prebuilt image: there are no frontend sources in this repository. The
frontend starts after the gateway is healthy. The gateway and the search node start after the admin and root worker
are healthy; the root worker starts after `init-perms` has finished.

The builder is published on `127.0.0.1` only, because it can write process files without a login. It reads and writes
`../processes/` directly, so changes show up in your files at once.

The cluster is configured through environment variables in [`docker-compose.yaml`](../docker-compose.yaml). Once it is
ready, `curl http://localhost:8080/manage/health` (gateway), `curl http://localhost:8888/manage/health` (admin),
`curl http://localhost:8600/manage/health` (search node) and `curl http://localhost:8700/manage/health` (MCP plugin)
return status `UP`. Log in at <http://localhost:4200> as
`admin`; its password is set in `docker-compose.yaml` (`netgrif.admin.setup.admin.password`), a local dev default.
Change it before you share the machine with anyone.

The database services have no volumes configured, so their data is removed together with the containers
(`docker compose down`).

## Extending your instance

- **Processes:** [`../processes/`](../processes/README.md). Forms and the application menu are defined in processes.
- **Plugins:** the default way to add Java code. Source code lives in [`../plugins/`](../plugins/README.md)
  (building needs Java 21 and Maven 3+); each plugin runs as its own service, pulled into the stack with `include:` in
  `docker-compose.yaml`.
- **Modules:** only when a plugin cannot do it. Source code lives in [`../modules/`](../modules/README.md) (building
  needs Java 21 and Maven). Built output is unzipped into [`engine/modules/`](engine/modules/README.md), which is
  mounted into the root worker.
