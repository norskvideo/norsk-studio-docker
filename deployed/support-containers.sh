#!/usr/bin/env bash
source "$(dirname "$0")/norsk-config.sh"
source "$(dirname "$0")/versions"
cd "$(dirname "$0")/../support" || exit 1

# Handle --no-detach flag
detach_flag="-d"
if [[ "$*" == *"--no-detach"* ]]; then
  detach_flag=""
  # Remove --no-detach from args as docker compose doesn't understand it
  set -- "${@/--no-detach/}"
fi

if [[ "${1:-}" = "up" || "${1:-}" = "start" ]]; then
  bash ../deployed/check-setup.sh
  bash ../deployed/check-certs.sh

  # Create log directories with correct permissions
  mkdir -p "${DEPLOY_LOGS}/nginx-proxy" "${DEPLOY_LOGS}/oauth2-proxy"

  # Make oauth2-proxy logs writable by nonroot user (UID 65532)
  chmod -R 777 "${DEPLOY_LOGS}/oauth2-proxy"

  # Add detach flag to up command
  set -- "$1" $detach_flag "${@:2}"
fi

export AUTH_METHOD=oauth2
docker compose -f nginx.yaml -f oauth2.yaml -f logs.yaml "$@"
