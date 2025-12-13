#!/usr/bin/env bash
source "$(dirname "$0")/norsk-config.sh"
source "$(dirname "$0")/versions"
cd "$(dirname "$0")/../support" || exit 1

if [[ "${1:-}" = "up" || "${1:-}" = "start" ]]; then
  # Rotate OAuth2 cookie secret (invalidates old sessions)
  ./oauth2/oauth2-proxy.cfg.sh

  # Generate nginx domain redirect config
  ./nginx/generate-domain-redirect.sh

  # Check/generate SSL certificates
  ../deployed/check-certs.sh

  # Make oauth2-proxy logs writable by nonroot user (UID 65532)
  chmod -R 777 "${DEPLOY_LOGS}/oauth2-proxy"
fi

export AUTH_METHOD=oauth2
docker compose -f nginx.yaml -f oauth2.yaml -f logs.yaml "$@"
