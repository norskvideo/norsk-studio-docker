#!/usr/bin/env bash

# Google Cloud Platform first-boot setup
# Sourced by norsk-containers.sh if present for the detected platform

setup() {
  local htpasswd_file="/opt/norsk-studio/support/oauth2/secrets/.htpasswd"

  if [[ ! -f "$htpasswd_file" ]]; then
    local admin_password
    admin_password="$(curl -fsH 'Metadata-Flavor: Google' \
      http://metadata.google.internal/computeMetadata/v1/instance/attributes/norsk-studio-admin-password 2>/dev/null || echo '')"

    if [[ -n "$admin_password" ]]; then
      source "$(dirname "$BASH_SOURCE")/../../scripts/lib/10-secrets.sh"
      REPO_DIR=/opt/norsk-studio STUDIO_PASSWORD="$admin_password" setup_password
    fi
  fi
}
