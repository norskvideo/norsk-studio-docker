#!/usr/bin/env bash
export DEPLOY_PUBLIC_IP=${DEPLOY_PUBLIC_IP:-"127.0.0.1"}
export DEPLOY_DOMAIN_NAME=""
export DEPLOY_HOSTNAME=${DEPLOY_HOSTNAME:-"localhost"}

# We can make it a little more forgiving of, e.g., port forwarding, at the
# expense of still not handling reverse proxying from a non-root URL
export PUBLIC_URL_PREFIX="/norsk"
export STUDIO_URL_PREFIX="/studio"
# Work around a bug that is fixed but not released
export STUDIO_DOCS_URL="https://docs.norsk.video/studio/latest/index.html"

# Better for port forwarding
echo "absolute_redirect off;" > "$(dirname "$BASH_SOURCE")/../../support/extras/server.conf"
