#!/usr/bin/env bash
source "$(dirname "$0")/norsk-config.sh"
cd "$(dirname "$0")/../support" || exit 1

mkdir -p certs

if [[ -z "$DEPLOY_DOMAIN_NAME" || "$DEPLOY_DOMAIN_NAME" = "localhost" ]]; then
  if [[ ! -f certs/nginx.ec.key ]]; then
    (set -x; ./generate-self-signed-certs.sh)
  fi
  exit 0
fi

if [[ "$UID" != "0" ]]; then
  if [[ -f certs/nginx.ec.crt && -f certs/nginx.ec.key ]]; then
    exit 0
  else
    echo "Cannot run certbot --standalone as non-root user" >&2
    exit 1
  fi
fi

CERTS=/etc/letsencrypt/live/$DEPLOY_DOMAIN_NAME

rm certs/nginx.ec.{crt,key}
ln -s "$CERTS"/fullchain.pem certs/nginx.ec.crt
ln -s "$CERTS"/privkey.pem certs/nginx.ec.key

if [[ ! -f $CERTS/privkey.pem ]]; then
  (set -x; ./certbot-wait-for-dns.sh "$DEPLOY_DOMAIN_NAME" "$DEPLOY_PUBLIC_IP" "$DEPLOY_CERTBOT_EMAIL")
else
  (set -x; certbot -q renew --no-random-sleep-on-renew)
fi
