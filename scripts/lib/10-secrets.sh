#!/usr/bin/env bash

# Secrets setup: License and admin password
# Sourced by bootstrap.sh

setup_secrets() {
  local repo_dir="$INSTALL_DIR/norsk-studio-docker"

  echo "Writing license file..."
  mkdir -p "$repo_dir/secrets"
  (set +x; printf '%s\n' "$NORSK_LICENSE") > "$repo_dir/secrets/license.json"
  chown norsk:norsk "$repo_dir/secrets/license.json"
  chmod 600 "$repo_dir/secrets/license.json"

  echo "Generating password hash..."
  local htp_dir="$repo_dir/support/oauth2/secrets"
  local htpasswd_file="$htp_dir/.htpasswd"
  mkdir -p "$htp_dir"
  (set +x; printf '%s' "$STUDIO_PASSWORD") \
    | docker run --rm -i xmartlabs/htpasswd@sha256:fac862e543f80d72386492aa87b0f6f3c1c06a49a845e553ebea91750ce6320c -i norsk-studio-admin \
    > "$htpasswd_file"
  chown norsk:norsk "$htpasswd_file"
  chmod 644 "$htpasswd_file"
}
