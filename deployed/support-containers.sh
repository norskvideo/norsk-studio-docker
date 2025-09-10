#!/usr/bin/env bash
source "$(dirname "$0")/norsk-config.sh"
source "$(dirname "$0")/versions"
cd "$(dirname "$0")/../support" || exit 1

if [[ "${1:-}" = "up" || "${1:-}" = "start" ]]; then
  bash ../deployed/check-setup.sh
  bash ../deployed/check-certs.sh
fi

export AUTH_METHOD=oauth2
docker compose -f nginx.yaml -f oauth2.yaml -f logs.yaml "$@"
