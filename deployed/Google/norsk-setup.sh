#!/usr/bin/env bash

# Google Cloud Platform first-boot setup
# Sourced by norsk-containers.sh if present for the detected platform

setup() {
  local htpasswd_file="/opt/norsk-studio/support/oauth2/secrets/.htpasswd"

  # Only run if the htpasswd file still contains the image build-time placeholder
  if grep -q "gcp-marketplace" "$htpasswd_file" 2>/dev/null; then
    local admin_password
    admin_password="$(curl -fsH 'Metadata-Flavor: Google' \
      http://metadata.google.internal/computeMetadata/v1/instance/attributes/norsk-studio-admin-password 2>/dev/null || echo '')"

    if [[ -n "$admin_password" ]]; then
      printf '%s' "$admin_password" \
        | docker run --rm -i xmartlabs/htpasswd@sha256:fac862e543f80d72386492aa87b0f6f3c1c06a49a845e553ebea91750ce6320c -i norsk-studio-admin \
        > "$htpasswd_file"
      chown norsk:norsk "$htpasswd_file"
      echo "Admin password configured from GCP metadata"
    fi
  fi
}
