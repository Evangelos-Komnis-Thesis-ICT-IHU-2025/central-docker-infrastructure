# SCORM Platform Infrastructure

Docker Compose stack for:
- `engine` (Spring Boot)
- `player` (Node/TypeScript)
- `lms` (Laravel example client)
- Postgres
- Redis
- MinIO (+ bucket init)
- Elasticsearch
- Logstash
- Kibana

All services run on Docker network `scorm-network`.

## Quick start

```bash
cp .env.example .env
docker compose up --build
```

## Local validation helpers

```bash
# Validate env structure and required keys
bash scripts/validate-env.sh .

# Smoke-check exposed and internal services after compose up
bash scripts/smoke-check.sh
```

## CI modes

- `push` to `master`: full integration using real `scorm-engine`, `player`, and `example-lms-client` repositories.
- `pull_request`: mock integration using `docker-compose.mock.yml` to avoid cross-repo checkout dependency.

Run mock mode locally:

```bash
COMPOSE_FILE=docker-compose.yml:docker-compose.mock.yml docker compose up -d --remove-orphans
COMPOSE_FILE=docker-compose.yml:docker-compose.mock.yml bash scripts/smoke-check.sh .
```

## Service URLs

- Engine: `http://localhost:8080`
- Engine Swagger: `http://localhost:8080/swagger-ui`
- Player: `http://localhost:3000`
- LMS: `http://localhost:8000`
- Postgres: `localhost:5432`
- Redis: `localhost:6379`
- MinIO API: `http://localhost:9000`
- MinIO Console: `http://localhost:9001`
- Elasticsearch: `http://localhost:9200`
- Kibana: `http://localhost:5601`

## Logs

`engine`, `player`, and `lms` containers use GELF docker logging driver to send logs to Logstash (`udp://127.0.0.1:12201` from Docker host), then to Elasticsearch index `scorm-logs-YYYY.MM.dd`.

## Data volumes

- `scorm_postgres_data`
- `scorm_redis_data`
- `scorm_minio_data`
- `scorm_es_data`
- `scorm_player_cache`

## LMS notes

- The `lms` service mounts:
  - `../../example-lms-client/lms-laravel`
- The SCORM SDK dependency is resolved by Composer from GitHub (`ihu/scorm-engine-sdk`), pinned by the LMS `composer.lock`.
- On startup it will:
  - install Composer dependencies (if missing),
  - auto-discover Laravel packages,
  - run migrations on local SQLite file,
  - auto-mint `SCORM_ENGINE_ADMIN_TOKEN` from `engine` via `/api/v1/auth/dev-token` when token is not provided.
