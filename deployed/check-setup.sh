#!/usr/bin/env bash
cd "$(dirname "$0")/../support" || exit 1

if [[ ! -f oauth2/secrets/.htpasswd || ! -f oauth2/secrets/oauth2-proxy.cfg ]]; then
  bash ../deployed/setup.sh
fi

# TODO: check for customization
if [[ -z "$DEPLOY_DOMAIN_NAME" ]]; then
  echo "" > ./extras/http.conf
else
  cat - > ./extras/http.conf <<TEMPLATE
    server {
        listen 80;
        listen 443;
        listen [::]:80;
        listen [::]:443;
        server_name $DEPLOY_PUBLIC_IP;
        return 302 https://$DEPLOY_DOMAIN_NAME\$request_uri;
    }
TEMPLATE
fi
