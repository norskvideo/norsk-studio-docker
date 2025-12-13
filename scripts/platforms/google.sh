#!/usr/bin/env bash

# Google Cloud Platform configuration
# Sourced by bootstrap.sh via 20-platform.sh

platform_setup() {
  export PLATFORM_DIR="$REPO_DIR/deployed/Google"
  mkdir -p "$PLATFORM_DIR"

  # Get public IP from metadata service
  export DEPLOY_PUBLIC_IP="$(curl -fsH "Metadata-Flavor: Google" \
    http://metadata/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)"

  # Generate norsk-config.sh (runtime configuration)
  cat > "$PLATFORM_DIR/norsk-config.sh" <<'HEREDOC'
#!/usr/bin/env bash
export DEPLOY_PUBLIC_IP="$(curl -fsH "Metadata-Flavor: Google" \
  http://metadata/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)"
export DEPLOY_DOMAIN_NAME="$(curl -fsH 'Metadata-Flavor: Google' \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/deploy_domain_name 2>/dev/null || echo '')"
export DEPLOY_CERTBOT_EMAIL="$(curl -fsH 'Metadata-Flavor: Google' \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/deploy_certbot_email 2>/dev/null || echo '')"
if [[ -z "$DEPLOY_DOMAIN_NAME" ]]; then
  export DEPLOY_HOSTNAME="$DEPLOY_PUBLIC_IP"
else
  export DEPLOY_HOSTNAME="$DEPLOY_DOMAIN_NAME"
fi
HEREDOC

  chmod +x "$PLATFORM_DIR/norsk-config.sh"
  chown norsk:norsk "$PLATFORM_DIR/norsk-config.sh"

  # Write vendor file for detection
  printf 'Google\n' > "$REPO_DIR/deployed/vendor"

  echo "Platform IP: $DEPLOY_PUBLIC_IP"
  if [[ -n "${DOMAIN_NAME:-}" ]]; then
    echo "Domain: $DOMAIN_NAME"
  fi
}
