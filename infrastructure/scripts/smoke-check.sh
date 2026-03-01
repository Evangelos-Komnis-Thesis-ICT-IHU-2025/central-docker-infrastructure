#!/usr/bin/env bash
set -euo pipefail

retry() {
  local name="$1"
  local attempts="$2"
  local sleep_seconds="$3"
  shift 3

  local i=1
  until "$@"; do
    if [ "${i}" -ge "${attempts}" ]; then
      echo "Service check failed: ${name}"
      return 1
    fi
    echo "Waiting for ${name} (attempt ${i}/${attempts})..."
    i=$((i + 1))
    sleep "${sleep_seconds}"
  done
  echo "Service is ready: ${name}"
}

# Pull curl image once for internal network checks.
docker pull curlimages/curl:8.12.1 >/dev/null

# Elasticsearch is internal only; check from a container on scorm-network.
retry "Elasticsearch internal reachability" 40 3 \
  docker run --rm --network scorm-network curlimages/curl:8.12.1 \
  sh -c "curl -fsS http://elasticsearch:9200 >/dev/null"

# Publicly exposed services.
retry "Engine API" 80 5 curl -fsS -o /dev/null http://127.0.0.1:8080/api/v1/health
retry "Player API" 80 5 curl -fsS -o /dev/null http://127.0.0.1:3000/health
retry "LMS API" 120 5 curl -fsS -o /dev/null http://127.0.0.1:8000/up
retry "Kibana" 60 5 curl -fsS -o /dev/null http://127.0.0.1:5601/api/status
retry "MinIO API" 40 3 curl -fsS -o /dev/null http://127.0.0.1:9000/minio/health/live
