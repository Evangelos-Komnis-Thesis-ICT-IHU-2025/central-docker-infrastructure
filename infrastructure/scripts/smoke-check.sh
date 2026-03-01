#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_INFRA_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
INFRA_DIR="${1:-${DEFAULT_INFRA_DIR}}"
if [ "${INFRA_DIR}" = "." ]; then
  INFRA_DIR="$(pwd)"
fi

if [ ! -f "${INFRA_DIR}/docker-compose.yml" ]; then
  echo "Could not find docker-compose.yml in ${INFRA_DIR}"
  exit 1
fi

COMPOSE_ARGS=()
if [ -n "${COMPOSE_FILE:-}" ]; then
  IFS=':' read -r -a compose_files <<< "${COMPOSE_FILE}"
  for compose_file in "${compose_files[@]}"; do
    COMPOSE_ARGS+=(-f "${compose_file}")
  done
else
  COMPOSE_ARGS=(-f "${INFRA_DIR}/docker-compose.yml")
fi
if [ -f "${INFRA_DIR}/.env" ]; then
  COMPOSE_ARGS+=(--env-file "${INFRA_DIR}/.env")
fi

compose() {
  docker compose "${COMPOSE_ARGS[@]}" "$@"
}

dump_compose_diagnostics() {
  echo "=== docker compose ps ==="
  compose ps || true
  echo "=== docker compose logs (tail 250) ==="
  compose logs --no-color --tail=250 || true
}

retry() {
  local name="$1"
  local attempts="$2"
  local sleep_seconds="$3"
  shift 3

  local i=1
  until "$@"; do
    if [ "${i}" -ge "${attempts}" ]; then
      echo "Service check failed: ${name}"
      dump_compose_diagnostics
      return 1
    fi
    echo "Waiting for ${name} (attempt ${i}/${attempts})..."
    i=$((i + 1))
    sleep "${sleep_seconds}"
  done
  echo "Service is ready: ${name}"
}

service_running() {
  local service="$1"
  compose ps --status running --services | grep -qx "${service}"
}

# Pull curl image once for internal network checks.
docker pull curlimages/curl:8.12.1 >/dev/null

# Elasticsearch is internal only; check from a container on scorm-network.
retry "Elasticsearch internal reachability" 40 3 \
  docker run --rm --network scorm-network curlimages/curl:8.12.1 \
  sh -c "curl -fsS http://elasticsearch:9200 >/dev/null"

# Verify services are running before endpoint probes.
retry "Engine container running" 90 2 service_running engine
retry "Player container running" 90 2 service_running player
retry "LMS container running" 120 2 service_running lms
retry "Kibana container running" 120 2 service_running kibana
retry "MinIO container running" 60 2 service_running minio

# Probe service endpoints from inside the compose network.
retry "Engine API" 80 5 \
  docker run --rm --network scorm-network curlimages/curl:8.12.1 \
  sh -c "curl -fsS -o /dev/null http://engine:8080/api/v1/health"
retry "Player API" 80 5 \
  docker run --rm --network scorm-network curlimages/curl:8.12.1 \
  sh -c "curl -fsS -o /dev/null http://player:3000/health"
retry "LMS API" 120 5 \
  docker run --rm --network scorm-network curlimages/curl:8.12.1 \
  sh -c "curl -fsS -o /dev/null http://lms:8000/up"
retry "Kibana API" 90 5 \
  docker run --rm --network scorm-network curlimages/curl:8.12.1 \
  sh -c "curl -fsS -o /dev/null http://kibana:5601/api/status"
retry "MinIO API" 40 3 \
  docker run --rm --network scorm-network curlimages/curl:8.12.1 \
  sh -c "curl -fsS -o /dev/null http://minio:9000/minio/health/live"
