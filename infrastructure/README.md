# SCORM Engine Central Infrastructure

Production-ready Docker Compose foundation for SCORM Engine platform services:
- Jenkins (LTS)
- Elasticsearch (single node, dev profile)
- Kibana
- MinIO (S3-compatible object storage)
- Nginx reverse proxy

All services join the shared external network `scorm-network` so external repositories (backend, player, future microservices) can communicate using container DNS names.

## Repository Structure

```text
infrastructure/
  docker-compose.yml
  .env
  nginx/
    nginx.conf
  jenkins/
    Dockerfile
  README.md
```

## Prerequisites

- Linux host
- Docker Engine v24+
- Docker Compose v2+

## Quick Start

1. Create the shared external network once:

```bash
docker network create scorm-network
```

2. Review and adjust environment variables:

```bash
cd infrastructure
cat .env
```

3. Start the stack:

```bash
docker compose up -d --build
```

4. Verify running services:

```bash
docker compose ps
```

## Service Endpoints

- Jenkins UI: `http://localhost:8080`
- Kibana UI: `http://localhost:5601`
- MinIO API: `http://localhost:9000`
- MinIO Console: `http://localhost:9001`
- Nginx gateway: `http://localhost`

Notes:
- Elasticsearch is intentionally internal-only and is not bound to host ports.
- Nginx includes proxy routes for future backend/player integration.

## Connecting External Repositories

In backend/player (separate repositories), attach services to the same external network:

```yaml
networks:
  scorm-network:
    external: true
    name: scorm-network
```

Then join the service:

```yaml
services:
  backend:
    image: your-org/scorm-backend:latest
    networks:
      - scorm-network
```

Service-to-service calls use container DNS names, for example:
- Backend -> Elasticsearch: `http://elasticsearch:9200`
- Backend -> MinIO: `http://minio:9000`
- Nginx -> Backend: `http://backend:8080`
- Nginx -> Player: `http://player:3000`

## Jenkins Notes

- Jenkins data persists in named volume `scorm_jenkins_home`.
- Docker socket is mounted for pipeline image builds:
  - `/var/run/docker.sock:/var/run/docker.sock`
- Set `DOCKER_GID` in `.env` to match your host docker group id:

```bash
getent group docker | cut -d: -f3
```

## Logging Strategy (Structured Logs -> Elasticsearch)

Recommended approach for backend and future services:

1. Emit structured JSON logs from application code.
2. Use consistent fields (example):
   - `@timestamp`
   - `service.name`
   - `service.version`
   - `environment`
   - `trace.id`
   - `span.id`
   - `log.level`
   - `message`
3. Ship logs with one of these patterns:
   - Direct application appenders/clients to Elasticsearch (`http://elasticsearch:9200`)
   - Sidecar/agent forwarder (Fluent Bit, Filebeat, Vector)
4. Create Kibana index patterns/data views (for example `scorm-*`).

Example index naming convention:
- `scorm-backend-YYYY.MM.DD`
- `scorm-player-YYYY.MM.DD`

## Scaling

Horizontal scaling examples:

```bash
# Scale stateless services if enabled
docker compose up -d --scale backend=3 --scale player=2
```

Scaling considerations:
- Keep Nginx as the single ingress or place it behind a cloud load balancer.
- Run Elasticsearch as multi-node cluster in production.
- Use external managed object storage or distributed MinIO for HA.
- Jenkins controller should remain singleton; use distributed agents for build scale.

## Production Considerations

- Enable TLS termination (Nginx + certificates).
- Enable authentication and authorization for Elasticsearch/Kibana.
- Use strong secrets from a secret manager (not plaintext `.env`).
- Restrict MinIO and Jenkins exposure via firewall/VPN.
- Add backup policies for `scorm_jenkins_home`, Elasticsearch data, and MinIO buckets.
- Add observability: metrics, tracing, alerting, log retention lifecycle.
- Pin and regularly patch container image versions.

## Stop / Cleanup

```bash
docker compose down
```

Remove volumes only if you want to delete persisted data:

```bash
docker compose down -v
```
