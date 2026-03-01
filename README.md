# central-docker-infrastructure

## Scope
Docker Compose orchestration for the SCORM platform:
- `engine` (Spring Boot)
- `player` (Node.js/TypeScript)
- `lms` (Laravel example client)
- `postgres`, `redis`, `minio`, `elasticsearch`, `logstash`, `kibana`

## Runtime
- Compose file: `infrastructure/docker-compose.yml`
- Shared network: `scorm-network`

## Host Ports
| Component | Host Port | Container Port | Notes |
| --- | --- | --- | --- |
| LMS | `8000` | `8000` | Laravel app UI/API |
| Player | `3000` | `3000` | Launch page + SCO content + internal runtime endpoints |
| Engine | `8080` | `8080` | SCORM engine REST API |
| Postgres | `5432` | `5432` | Engine relational persistence |
| Redis | `6379` | `6379` | Runtime launch state |
| MinIO API | `9000` | `9000` | Object storage |
| MinIO Console | `9001` | `9001` | MinIO admin UI |
| Elasticsearch | `9200` | `9200` | Log indexing |
| Logstash (GELF UDP) | `12201/udp` | `12201/udp` | Container log ingestion |
| Kibana | `5601` | `5601` | Log UI |

## Architecture
```mermaid
graph LR
  Browser[Browser] --> LMS[LMS :8000]
  LMS --> Engine[Engine :8080]
  LMS --> Player[Player :3000]
  Player --> Engine
  Engine --> Postgres[Postgres :5432]
  Engine --> Redis[Redis :6379]
  Engine --> MinIO[MinIO :9000]
  Player --> MinIO
  Engine --> Logstash[Logstash :12201/udp]
  Player --> Logstash
  LMS --> Logstash
  Logstash --> Elasticsearch[Elasticsearch :9200]
  Elasticsearch --> Kibana[Kibana :5601]
```

## Request Flow (Launch + Runtime)
```mermaid
sequenceDiagram
  participant B as Browser
  participant L as LMS
  participant E as Engine
  participant P as Player
  participant M as MinIO
  participant R as Redis
  participant D as Postgres

  B->>L: Open learner launch page
  L->>E: POST /api/v1/launches
  E-->>L: launchUrl + launchToken + attemptId
  L-->>B: HTML with iframe(player launchUrl)
  B->>P: GET /launch/{launchId}?token=...
  P->>E: GET /api/v1/launches/{launchId}
  E-->>P: launch context + content source URL
  P->>M: Download package zip
  P-->>B: Serve /content/{launchId}/...

  loop periodic commit
    B->>P: SCORM Commit
    P->>E: POST /api/v1/runtime/launches/{launchId}/commit
    E->>R: update launch runtime state
  end

  B->>P: SCORM Terminate/Finish
  P->>E: POST /api/v1/launches/{launchId}/terminate
  E->>D: flush snapshots/progress + close launch
```

## Start
```bash
cd infrastructure
cp .env.example .env
docker compose up --build
```

## Validation
```bash
cd infrastructure
bash scripts/validate-env.sh .
bash scripts/smoke-check.sh
```
