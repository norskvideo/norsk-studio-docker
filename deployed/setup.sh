#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/norsk-config.sh"
cd "$(dirname "$0")/../support" || exit 1

# Ensure logs directory exists and is owned by norsk user
mkdir -p "${DEPLOY_LOGS}"
chown -R norsk:norsk "${DEPLOY_LOGS}"

HTPASSWD=oauth2/secrets/.htpasswd
touch $HTPASSWD
# If the password file was not already customized and we have a method to generate it
if [[ "$(grep -cvEe '^$|^norsk-studio-admin:' $HTPASSWD)" -eq 0 && -f "../deployed/$DEPLOY_PLATFORM/admin-password.sh" ]]; then
  # grab the password from instance metadata
  IMAGE=xmartlabs/htpasswd@sha256:fac862e543f80d72386492aa87b0f6f3c1c06a49a845e553ebea91750ce6320c
  # would be nice to skip updating the file if the bash fails ...
  bash "../deployed/$DEPLOY_PLATFORM/admin-password.sh" \
    | docker run --rm -i $IMAGE -i norsk-studio-admin > $HTPASSWD
fi

./oauth2/oauth2-proxy.cfg.sh # will refresh cookie secret
