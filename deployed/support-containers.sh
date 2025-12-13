#!/usr/bin/env bash
source "$(dirname "$0")/norsk-config.sh"
source "$(dirname "$0")/versions"
cd "$(dirname "$0")/../support" || exit 1

if [[ "${1:-}" = "up" || "${1:-}" = "start" ]]; then
  bash ../deployed/check-setup.sh
  bash ../deployed/check-certs.sh

  # Make oauth2-proxy logs writable by nonroot user (UID 65532)
  chmod -R 777 "${DEPLOY_LOGS}/oauth2-proxy"
fi

export AUTH_METHOD=oauth2
docker compose -f nginx.yaml -f oauth2.yaml -f logs.yaml "$@"
