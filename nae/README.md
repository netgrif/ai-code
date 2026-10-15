# nae

Everything needed to run the application locally: the backend stack, the frontend, and the folder where built plugins
are loaded from. For the overall project, see the [main README](../README.md).

| Path                              | Purpose                                                      |
|-----------------------------------|--------------------------------------------------------------|
| [`docker-compose.yaml`](docker-compose.yaml) | Backend stack: Application Engine, MongoDB, Elasticsearch, Redis |
| [`nae-frontend/`](nae-frontend/)  | Angular frontend                                             |
| [`nae-backend/plugins/`](nae-backend/plugins/) | Built plugins loaded by the engine at start     |
| `nae-backend/logs/`               | Engine logs, mounted from the container                      |

## Backend stack

Run from this folder:

```bash
docker compose up -d      # start
docker compose logs nae   # engine logs
docker compose restart nae  # reload, e.g. after changing plugins
docker compose down       # stop and remove containers
```

| Service             | Image                                | Ports        |
|---------------------|--------------------------------------|--------------|
| `nae`               | `netgrif/application-engine:7.0.3`   | 8080         |
| `nae-mongodb`       | `mongo:8.0.3` (replica set `rs0`)    | 27017        |
| `nae-elasticsearch` | `elasticsearch:8.19.15`              | 9200, 9300   |
| `nae-redis`         | `redis:8`                            | 6379         |

The engine is configured through environment variables in `docker-compose.yaml`. Once it is ready,
`curl http://localhost:8080/manage/health` returns status `UP`. On the first run it creates the super admin
`super@netgrif.com` and prints a generated password to `nae-backend/logs/nae.log`.

The database services have no volumes configured, so their data is removed together with the containers
(`docker compose down`).

## Extending your instance

- **Frontend components and views:** see [`nae-frontend/README.md`](nae-frontend/README.md).
- **Plugins:** source code lives in [`../plugins/`](../plugins/README.md). Built output is unzipped into
  [`nae-backend/plugins/`](nae-backend/plugins/README.md), which is mounted into the engine container.
