#!/usr/bin/env bash
set -euo pipefail

: "${STASHSPHERE_CONFIG_DIR:=/config}"
: "${STASHSPHERE_CONFIG_FILE:=stashsphere.yaml}"
: "${STASHSPHERE_SECRETS_FILE:=secrets.yaml}"
: "${STASHSPHERE_AUTO_CREATE_CONFIG:=true}"
: "${STASHSPHERE_AUTO_MIGRATE:=true}"
: "${STASHSPHERE_MIGRATE_MAX_RETRIES:=45}"
: "${STASHSPHERE_MIGRATE_RETRY_DELAY_SECONDS:=2}"

: "${STASHSPHERE_DB_HOST:=127.0.0.1}"
: "${STASHSPHERE_DB_PORT:=5432}"
: "${STASHSPHERE_DB_USER:=stashsphere}"
: "${STASHSPHERE_DB_NAME:=stashsphere}"
: "${STASHSPHERE_DB_PASSWORD:=stashsphere}"
: "${STASHSPHERE_DB_SSLMODE:=disable}"

: "${STASHSPHERE_FRONTEND_URL:=http://localhost:3000}"
: "${STASHSPHERE_ALLOWED_ORIGIN:=http://localhost:3000}"
: "${STASHSPHERE_API_DOMAIN:=localhost}"
: "${STASHSPHERE_INSTANCE_NAME:=StashSphere}"
: "${STASHSPHERE_LISTEN_ADDRESS:=:8081}"

: "${STATE_DIRECTORY:=/data}"
: "${CACHE_DIRECTORY:=/data}"

MAIN_CONFIG="${STASHSPHERE_CONFIG_DIR}/${STASHSPHERE_CONFIG_FILE}"
SECRETS_CONFIG="${STASHSPHERE_CONFIG_DIR}/${STASHSPHERE_SECRETS_FILE}"
DEFAULT_TEMPLATE="/usr/local/share/stashsphere/default-config.yaml"

escape_sed() {
  printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'
}

generate_private_key() {
  stashsphere genkey | sed -n 's/^Generated Private Key: //p' | head -n1
}

create_default_config() {
  if [[ ! -f "${DEFAULT_TEMPLATE}" ]]; then
    echo "Default config template missing at ${DEFAULT_TEMPLATE}" >&2
    exit 1
  fi

  local key
  key="$(generate_private_key)"
  if [[ -z "${key}" ]]; then
    echo "Failed to generate auth.privateKey" >&2
    exit 1
  fi

  cp "${DEFAULT_TEMPLATE}" "${MAIN_CONFIG}"

  sed -i \
    -e "s/__PRIVATE_KEY__/$(escape_sed "${key}")/" \
    -e "s/__DB_HOST__/$(escape_sed "${STASHSPHERE_DB_HOST}")/" \
    -e "s/__DB_PORT__/$(escape_sed "${STASHSPHERE_DB_PORT}")/" \
    -e "s/__DB_USER__/$(escape_sed "${STASHSPHERE_DB_USER}")/" \
    -e "s/__DB_NAME__/$(escape_sed "${STASHSPHERE_DB_NAME}")/" \
    -e "s/__DB_PASSWORD__/$(escape_sed "${STASHSPHERE_DB_PASSWORD}")/" \
    -e "s/__DB_SSLMODE__/$(escape_sed "${STASHSPHERE_DB_SSLMODE}")/" \
    -e "s/__FRONTEND_URL__/$(escape_sed "${STASHSPHERE_FRONTEND_URL}")/" \
    -e "s/__ALLOWED_ORIGIN__/$(escape_sed "${STASHSPHERE_ALLOWED_ORIGIN}")/" \
    -e "s/__API_DOMAIN__/$(escape_sed "${STASHSPHERE_API_DOMAIN}")/" \
    -e "s/__INSTANCE_NAME__/$(escape_sed "${STASHSPHERE_INSTANCE_NAME}")/" \
    -e "s/__LISTEN_ADDRESS__/$(escape_sed "${STASHSPHERE_LISTEN_ADDRESS}")/" \
    "${MAIN_CONFIG}"

  echo "Generated default config at ${MAIN_CONFIG}" >&2
}

mkdir -p "${STASHSPHERE_CONFIG_DIR}" "${STATE_DIRECTORY}/image_store" "${CACHE_DIRECTORY}/image_cache"

if [[ ! -f "${MAIN_CONFIG}" && "${STASHSPHERE_AUTO_CREATE_CONFIG}" == "true" ]]; then
  create_default_config
fi

CONF_ARGS=()
if [[ -f "${MAIN_CONFIG}" ]]; then
  CONF_ARGS+=(--conf "${MAIN_CONFIG}")
fi
if [[ -f "${SECRETS_CONFIG}" ]]; then
  CONF_ARGS+=(--conf "${SECRETS_CONFIG}")
fi

require_config() {
  if [[ ${#CONF_ARGS[@]} -eq 0 ]]; then
    echo "No config found. Expected ${MAIN_CONFIG} (and optional ${SECRETS_CONFIG})." >&2
    exit 1
  fi
}

CMD=("$@")
if [[ ${#CMD[@]} -eq 0 ]]; then
  CMD=(serve)
fi
if [[ "${CMD[0]}" == -* ]]; then
  CMD=(serve "${CMD[@]}")
fi

case "${CMD[0]}" in
  serve)
    require_config
    if [[ "${STASHSPHERE_AUTO_MIGRATE}" == "true" ]]; then
      attempt=1
      while true; do
        if stashsphere migrate "${CONF_ARGS[@]}"; then
          break
        fi
        if [[ ${attempt} -ge ${STASHSPHERE_MIGRATE_MAX_RETRIES} ]]; then
          echo "Migration failed after ${STASHSPHERE_MIGRATE_MAX_RETRIES} attempts." >&2
          exit 1
        fi
        attempt=$((attempt + 1))
        sleep "${STASHSPHERE_MIGRATE_RETRY_DELAY_SECONDS}"
      done
    fi
    exec stashsphere serve "${CONF_ARGS[@]}" "${CMD[@]:1}"
    ;;
  migrate)
    require_config
    exec stashsphere migrate "${CONF_ARGS[@]}" "${CMD[@]:1}"
    ;;
  *)
    exec stashsphere "${CMD[@]}"
    ;;
esac
