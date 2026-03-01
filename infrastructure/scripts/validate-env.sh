#!/usr/bin/env bash
set -euo pipefail

INFRA_DIR="${1:-infrastructure}"
ENV_FILE="${INFRA_DIR}/.env"
ENV_EXAMPLE_FILE="${INFRA_DIR}/.env.example"

if [ ! -f "${ENV_FILE}" ]; then
  if [ -f "${ENV_EXAMPLE_FILE}" ]; then
    cp "${ENV_EXAMPLE_FILE}" "${ENV_FILE}"
    echo "Created ${ENV_FILE} from ${ENV_EXAMPLE_FILE}"
  else
    echo "Missing ${ENV_FILE} and ${ENV_EXAMPLE_FILE}"
    exit 1
  fi
fi

# Reject malformed non-comment, non-empty lines.
if grep -nEv '^[[:space:]]*(#.*)?$|^[A-Za-z_][A-Za-z0-9_]*=.*$' "${ENV_FILE}"; then
  echo "Invalid line(s) found in ${ENV_FILE}"
  exit 1
fi

required_keys=(
  ELASTIC_VERSION
  POSTGRES_DB
  POSTGRES_USER
  POSTGRES_PASSWORD
  MINIO_IMAGE
  MINIO_ROOT_USER
  MINIO_ROOT_PASSWORD
  ENGINE_JWT_SECRET
  LAUNCH_JWT_SECRET
  LMS_PORT
)

for key in "${required_keys[@]}"; do
  value="$(grep -E "^${key}=" "${ENV_FILE}" | tail -n1 | cut -d'=' -f2- || true)"
  if [ -z "${value}" ]; then
    echo "Missing or empty required key in ${ENV_FILE}: ${key}"
    exit 1
  fi
done

echo "Environment file validation passed: ${ENV_FILE}"
