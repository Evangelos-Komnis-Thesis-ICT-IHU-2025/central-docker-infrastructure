#!/bin/sh
set -eu

APP_DIR="/workspace/example-lms-client/lms-laravel"
ENGINE_BASE_URL="${SCORM_ENGINE_BASE_URL:-http://engine:8080/api/v1}"

cd "${APP_DIR}"

if [ ! -f .env ]; then
  cp .env.example .env
fi

set_env_key() {
  key="$1"
  value="$2"

  if grep -q "^${key}=" .env; then
    sed -i "s|^${key}=.*|${key}=${value}|" .env
  else
    printf '\n%s=%s\n' "${key}" "${value}" >> .env
  fi
}

set_env_key "SESSION_DRIVER" "${SESSION_DRIVER:-file}"
set_env_key "CACHE_STORE" "${CACHE_STORE:-file}"
set_env_key "QUEUE_CONNECTION" "${QUEUE_CONNECTION:-sync}"
set_env_key "SCORM_ENGINE_BASE_URL" "${ENGINE_BASE_URL}"
set_env_key "SCORM_PLAYER_BASE_URL" "${SCORM_PLAYER_BASE_URL:-http://player:3000}"

if [ "${DB_CONNECTION:-sqlite}" = "sqlite" ]; then
  mkdir -p database
  touch database/database.sqlite
fi

if [ ! -f vendor/autoload.php ]; then
  composer install --no-dev --prefer-dist --no-interaction --no-progress --optimize-autoloader --no-scripts
fi

php artisan package:discover --ansi

APP_KEY_VALUE="${APP_KEY:-}"
if [ -z "${APP_KEY_VALUE}" ]; then
  APP_KEY_VALUE="$(grep '^APP_KEY=' .env | cut -d= -f2- || true)"
fi

if [ -z "${APP_KEY_VALUE}" ]; then
  php artisan key:generate --force --ansi
fi

if [ -z "${SCORM_ENGINE_ADMIN_TOKEN:-}" ]; then
  TOKEN=""
  ATTEMPT=1

  while [ ${ATTEMPT} -le 30 ]; do
    UUID="$(cat /proc/sys/kernel/random/uuid)"
    TOKEN_RESPONSE="$(curl -fsS --connect-timeout 2 --max-time 5 -X POST "${ENGINE_BASE_URL}/auth/dev-token" \
      -H 'Content-Type: application/json' \
      -d "{\"userId\":\"${UUID}\",\"roles\":[\"ADMIN\"]}" || true)"
    TOKEN="$(printf '%s' "${TOKEN_RESPONSE}" | sed -n 's/.*"token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"

    if [ -n "${TOKEN}" ]; then
      break
    fi

    ATTEMPT=$((ATTEMPT + 1))
    sleep 2
  done

  if [ -n "${TOKEN}" ]; then
    export SCORM_ENGINE_ADMIN_TOKEN="${TOKEN}"
    set_env_key "SCORM_ENGINE_ADMIN_TOKEN" "${TOKEN}"
  else
    echo "Warning: could not auto-generate SCORM_ENGINE_ADMIN_TOKEN from ${ENGINE_BASE_URL}/auth/dev-token after retries" >&2
  fi
else
  set_env_key "SCORM_ENGINE_ADMIN_TOKEN" "${SCORM_ENGINE_ADMIN_TOKEN}"
fi

php artisan migrate --force --ansi

exec php artisan serve --host=0.0.0.0 --port=8000
